import Foundation

final class SecurityRuntimeController: SecurityStateProviding, SearchLockStateProviding {
    private let settingsStore: SecuritySettingsStoring
    private let payloadStore: ProtectedPayloadManaging
    private let searchNotesStore: SearchNotesOrganizationStoring?
    private let decryptedPayloadCache: DecryptedPayloadCache
    private let now: () -> Date

    private(set) var latestSnapshot: SecurityRuntimeSnapshot
    var onSnapshotChange: ((SecurityRuntimeSnapshot) -> Void)?
    var onLockStateChange: ((SearchLockState) -> Void)?

    var currentLockState: SearchLockState {
        latestSnapshot.isSearchAvailable ? .unlocked : .locked
    }

    init(
        settingsStore: SecuritySettingsStoring = SecuritySettingsStore(),
        keyStore: PayloadKeyWrapping = PayloadKeychainStore(),
        payloadStore: ProtectedPayloadManaging? = nil,
        decryptedPayloadCache: DecryptedPayloadCache = DecryptedPayloadCache(),
        searchNotesStore: SearchNotesOrganizationStoring? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.settingsStore = settingsStore
        let resolvedPayloadStore = payloadStore ?? EncryptedPayloadStore(keyStore: keyStore)
        self.payloadStore = resolvedPayloadStore
        self.decryptedPayloadCache = decryptedPayloadCache
        self.searchNotesStore = searchNotesStore
            ?? SearchNotesOrganizationStore(
                payloadStore: resolvedPayloadStore,
                decryptedPayloadCache: decryptedPayloadCache
            )
        self.now = now
        let currentSettings = settingsStore.currentSettings
        self.latestSnapshot = SecurityRuntimeSnapshot(
            lockState: currentSettings.isAppLockEnabled ? .locked : .unlocked,
            settings: currentSettings,
            migrationState: resolvedPayloadStore.latestMigrationState,
            keyMaterialState: resolvedPayloadStore.keyMaterialState,
            lockedVisibleReason: currentSettings.isAppLockEnabled ? .authenticationRequired : nil
        )
    }

    func bootstrap() {
        let settings = settingsStore.currentSettings
        let lockState: SecurityLockState
        let lockedReason: SecurityLockedVisibleReason?

        if settings.isAppLockEnabled {
            lockState = payloadStore.keyMaterialState.hasUnwrappedKeyInMemory ? .unlocked : .locked
            lockedReason = payloadStore.keyMaterialState.hasUnwrappedKeyInMemory ? nil : .authenticationRequired
        } else {
            lockState = .unlocked
            lockedReason = nil
        }

        publishSnapshot(
            SecurityRuntimeSnapshot(
                lockState: lockState,
                settings: settings,
                migrationState: payloadStore.latestMigrationState,
                keyMaterialState: payloadStore.keyMaterialState,
                lockedVisibleReason: lockedReason,
                lastFailure: latestSnapshot.lastFailure,
                lastInteractionAt: latestSnapshot.lastInteractionAt
            )
        )
    }

    func recordInteraction(at date: Date) {
        if shouldAutoLock(before: date) {
            lock(reason: .autoLockTimeout)
            return
        }

        guard latestSnapshot.lockState == .unlocked else {
            return
        }

        var snapshot = latestSnapshot
        snapshot.lastInteractionAt = date
        // Interaction heartbeats drive auto-lock timing but do not change visible security state.
        latestSnapshot = snapshot
    }

    func updateSettings(_ settings: SecuritySettings) {
        let currentSettings = settingsStore.currentSettings
        let isEnablingLock = settings.isAppLockEnabled && currentSettings.isAppLockEnabled == false
        let isDisablingLock = settings.isAppLockEnabled == false && currentSettings.isAppLockEnabled

        if isEnablingLock {
            let provisionedState = payloadStore.provisionAccessKey(
                preferredPolicy: .secureEnclaveWrapped,
                authenticationMethod: settings.unlockMethod,
                at: settings.lastUpdatedAt
            )

            guard case .unwrappedInMemory = provisionedState else {
                let failure = SecurityFailureState(
                    kind: .keyProvisioningFailed,
                    title: "Protected storage unavailable",
                    detailText: "SlipBoard could not provision the local payload key on this device.",
                    occurredAt: settings.lastUpdatedAt
                )
                failUnlock(failure)
                return
            }
        }

        let savedSettings = settingsStore.saveSecuritySettings(settings)
        let nextLockState: SecurityLockState
        let lockedReason: SecurityLockedVisibleReason?
        var migrationState = payloadStore.latestMigrationState

        if savedSettings.isAppLockEnabled {
            ensureKeyProvisionedIfNeeded(settings: savedSettings, at: savedSettings.lastUpdatedAt)
            if payloadStore.keyMaterialState.hasUnwrappedKeyInMemory {
                migrationState = searchNotesStore?.migrateProtectedPayloadsIfNeeded() ?? payloadStore.latestMigrationState
                searchNotesStore?.refreshProtectedContentMirrors(includeProtectedContent: true)
            }

            nextLockState = payloadStore.keyMaterialState.hasUnwrappedKeyInMemory ? .unlocked : .locked
            lockedReason = payloadStore.keyMaterialState.hasUnwrappedKeyInMemory ? nil : .authenticationRequired
        } else {
            if isDisablingLock {
                _ = payloadStore.clearAccessKeyMaterial()
            }
            nextLockState = .unlocked
            lockedReason = nil
        }

        publishSnapshot(
            SecurityRuntimeSnapshot(
                lockState: nextLockState,
                settings: savedSettings,
                migrationState: migrationState,
                keyMaterialState: payloadStore.keyMaterialState,
                lockedVisibleReason: lockedReason,
                lastFailure: nextLockState == .unlocked ? nil : latestSnapshot.lastFailure,
                lastInteractionAt: nextLockState == .unlocked ? now() : latestSnapshot.lastInteractionAt
            )
        )
    }

    func lock(reason: SecurityLockedVisibleReason) {
        guard latestSnapshot.settings.isAppLockEnabled else {
            return
        }

        clearUnlockedStateForLockTransition()
        publishSnapshot(
            SecurityRuntimeSnapshot(
                lockState: .locked,
                settings: latestSnapshot.settings,
                migrationState: payloadStore.latestMigrationState,
                keyMaterialState: payloadStore.keyMaterialState,
                lockedVisibleReason: reason,
                lastFailure: latestSnapshot.lastFailure,
                lastInteractionAt: latestSnapshot.lastInteractionAt
            )
        )
    }

    func beginUnlock(using method: SecurityUnlockMethod) {
        guard latestSnapshot.settings.isAppLockEnabled else {
            completeUnlock(at: now())
            return
        }

        publishSnapshot(
            SecurityRuntimeSnapshot(
                lockState: .unlocking,
                settings: latestSnapshot.settings,
                migrationState: payloadStore.latestMigrationState,
                keyMaterialState: payloadStore.keyMaterialState,
                lockedVisibleReason: latestSnapshot.lockedVisibleReason ?? .authenticationRequired,
                lastFailure: nil,
                lastInteractionAt: latestSnapshot.lastInteractionAt
            )
        )

        let nextState = payloadStore.unlockAccessKey(authenticationMethod: method, at: now())
        if case .unwrappedInMemory = nextState {
            completeUnlock(at: now())
        } else {
            failUnlock(
                SecurityFailureState(
                    kind: .keyUnwrapFailed,
                    title: "Unlock unavailable",
                    detailText: "SlipBoard could not unwrap the protected payload key for this device.",
                    occurredAt: now()
                )
            )
        }
    }

    func completeUnlock(at date: Date) {
        let migrationState = searchNotesStore?.migrateProtectedPayloadsIfNeeded() ?? payloadStore.latestMigrationState
        searchNotesStore?.refreshProtectedContentMirrors(includeProtectedContent: true)
        publishSnapshot(
            SecurityRuntimeSnapshot(
                lockState: .unlocked,
                settings: latestSnapshot.settings,
                migrationState: migrationState,
                keyMaterialState: payloadStore.keyMaterialState,
                lockedVisibleReason: nil,
                lastFailure: nil,
                lastInteractionAt: date
            )
        )
    }

    func failUnlock(_ failure: SecurityFailureState) {
        publishSnapshot(
            SecurityRuntimeSnapshot(
                lockState: .unlockFailed,
                settings: latestSnapshot.settings,
                migrationState: payloadStore.latestMigrationState,
                keyMaterialState: payloadStore.keyMaterialState,
                lockedVisibleReason: failure.kind == .keyUnwrapFailed ? .keyUnavailable : .authenticationRequired,
                lastFailure: failure,
                lastInteractionAt: latestSnapshot.lastInteractionAt
            )
        )
    }

    func clearFailure() {
        var snapshot = latestSnapshot
        snapshot.lastFailure = nil
        if snapshot.lockState == .unlockFailed {
            snapshot.lockState = snapshot.settings.isAppLockEnabled ? .locked : .unlocked
            snapshot.lockedVisibleReason = snapshot.settings.isAppLockEnabled ? .authenticationRequired : nil
        }
        publishSnapshot(snapshot)
    }

    private func ensureKeyProvisionedIfNeeded(settings: SecuritySettings, at date: Date) {
        guard payloadStore.activeWrappedKey == nil else {
            return
        }

        let nextState = payloadStore.provisionAccessKey(
            preferredPolicy: .secureEnclaveWrapped,
            authenticationMethod: settings.unlockMethod,
            at: date
        )

        if case .absent = nextState {
            failUnlock(
                SecurityFailureState(
                    kind: .keyProvisioningFailed,
                    title: "Protected storage unavailable",
                    detailText: "SlipBoard could not provision the local payload key on this device.",
                    occurredAt: date
                )
            )
        }
    }

    private func clearUnlockedStateForLockTransition() {
        decryptedPayloadCache.clearAll()
        searchNotesStore?.clearUnlockedSession()
        _ = payloadStore.clearAccessKeyMaterial()
    }

    private func shouldAutoLock(before date: Date) -> Bool {
        guard
            latestSnapshot.settings.isAppLockEnabled,
            latestSnapshot.lockState == .unlocked,
            let timeout = latestSnapshot.settings.autoLockInterval.duration,
            let lastInteractionAt = latestSnapshot.lastInteractionAt
        else {
            return false
        }

        return date.timeIntervalSince(lastInteractionAt) >= timeout
    }

    private func publishSnapshot(_ snapshot: SecurityRuntimeSnapshot) {
        let previousSearchLockState = currentLockState
        latestSnapshot = snapshot
        onSnapshotChange?(latestSnapshot)

        let nextSearchLockState = currentLockState
        if previousSearchLockState != nextSearchLockState {
            onLockStateChange?(nextSearchLockState)
        }
    }
}
