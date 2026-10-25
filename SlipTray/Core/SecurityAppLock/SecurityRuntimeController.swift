import Foundation
import LocalAuthentication

final class SecurityRuntimeController: SecurityStateProviding, SearchLockStateProviding {
    private nonisolated static let logger = DiagnosticLogger(category: "AppLock")
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
        keyStore: PayloadKeyWrapping? = nil,
        payloadStore: ProtectedPayloadManaging? = nil,
        decryptedPayloadCache: DecryptedPayloadCache = DecryptedPayloadCache(),
        searchNotesStore: SearchNotesOrganizationStoring? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.settingsStore = settingsStore
        // Only build a key store when none is passed in.
        let resolvedPayloadStore = payloadStore ?? EncryptedPayloadStore(keyStore: keyStore ?? PayloadKeychainStore())
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
        // The key is only read when App Lock needs it, so a launch without App
        // Lock never touches the keychain or the key file. The lookup never
        // asks the user; Unlock tries again with prompts allowed. Unwrapping a
        // key the previous release left in the login keychain asks once, below,
        // because that key is the only way to read existing notes.
        if settings.isAppLockEnabled {
            payloadStore.loadAccessKeyIfNeeded(allowsUserInteraction: false)
        }

        // App Lock is on but this keychain has no key: it was made by a build of
        // the other signing type, or removed. Make a new one instead of staying
        // locked for good; what the old key encrypted stays unreadable either
        // way. The app opens unlocked after launch anyway, so this shows nothing
        // a relaunch would not. A key that exists but cannot be read is kept.
        if settings.isAppLockEnabled,
           payloadStore.activeWrappedKey == nil,
           payloadStore.isKeyRecordMissing,
           case .unwrappedInMemory = payloadStore.provisionAccessKey(
               preferredPolicy: .secureEnclaveWrapped,
               authenticationMethod: settings.unlockMethod,
               at: now()
           )
        {
            completeUnlock(at: now())
            return
        }

        // App Lock only locks within a session: open unlocked when the key can
        // be unwrapped without Touch ID. An old key still needs it, so the app
        // stays locked until the first unlock rewraps it.
        if settings.isAppLockEnabled,
           payloadStore.keyMaterialState.hasUnwrappedKeyInMemory == false,
           hasSessionOnlyKey,
           case .unwrappedInMemory = payloadStore.unlockAccessKey(authenticationMethod: settings.unlockMethod, at: now())
        {
            completeUnlock(at: now())
            return
        }
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
                    detailText: "SlipTray could not provision the local payload key on this device.",
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

        // A key that could not be loaded at launch gets another try here. If
        // there turns out to be none, make one, as launch would have.
        payloadStore.loadAccessKeyIfNeeded(allowsUserInteraction: true)
        if payloadStore.activeWrappedKey == nil, payloadStore.isKeyRecordMissing {
            _ = payloadStore.provisionAccessKey(
                preferredPolicy: .secureEnclaveWrapped,
                authenticationMethod: method,
                at: now()
            )
        }

        // A session-only key unwraps without asking, so ask here first. An old
        // key asks for Touch ID itself while it is unwrapped.
        guard hasSessionOnlyKey else {
            unwrapKeyAndCompleteUnlock(using: method)
            return
        }

        let context = LAContext()
        context.localizedReason = "Unlock SlipTray"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock SlipTray") { [weak self] success, error in
            if let error {
                Self.logger.info("Unlock authentication did not succeed: \(DiagnosticLogger.describe(error))")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.unwrapKeyAndCompleteUnlock(using: method)
                } else {
                    self.failUnlock(
                        SecurityFailureState(
                            kind: .authenticationFailed,
                            title: "Unlock cancelled",
                            detailText: "SlipTray stays locked until you authenticate.",
                            occurredAt: self.now()
                        )
                    )
                }
            }
        }
    }

    private var hasSessionOnlyKey: Bool {
        (payloadStore.activeWrappedKey?.keyVersion ?? 0) >= PayloadKeychainStore.sessionOnlyKeyVersion
    }

    private func unwrapKeyAndCompleteUnlock(using method: SecurityUnlockMethod) {
        let nextState = payloadStore.unlockAccessKey(authenticationMethod: method, at: now())
        guard case let .unwrappedInMemory(wrappedKey, _) = nextState else {
            failUnlock(
                SecurityFailureState(
                    kind: .keyUnwrapFailed,
                    title: "Unlock unavailable",
                    detailText: "SlipTray could not unwrap the protected payload key for this device.",
                    occurredAt: now()
                )
            )
            return
        }

        if wrappedKey.keyVersion < PayloadKeychainStore.sessionOnlyKeyVersion,
           case .absent = payloadStore.rewrapAccessKey(using: wrappedKey.wrappingPolicy, at: now()) {
            failUnlock(
                SecurityFailureState(
                    kind: .keyWrapFailed,
                    title: "Protected storage unavailable",
                    detailText: "SlipTray could not store the payload key for session-only App Lock.",
                    occurredAt: now()
                )
            )
            return
        }
        completeUnlock(at: now())
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
        Self.logger.error("App Lock failure: \(failure.kind.rawValue)")
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
        // A key that exists but cannot be read may still protect notes, so a
        // settings change never replaces it. Turning App Lock off and on keeps
        // a readable key on ad-hoc builds and replaces only an unreadable key
        // file; team-signed builds still make a new key.
        guard payloadStore.activeWrappedKey == nil, payloadStore.isKeyRecordMissing else {
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
                    detailText: "SlipTray could not provision the local payload key on this device.",
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
