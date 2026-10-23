import Foundation

enum SecurityAppLockMockFixtures {
    static let baseDate = Date(timeIntervalSince1970: 1_787_290_200)

    static let secureEnclaveWrappedKey = WrappedPayloadKey(
        keyVersion: 1,
        wrappingPolicy: .secureEnclaveWrapped,
        wrappedKeyData: Data("wrapped-key-secure-enclave-v1".utf8),
        createdAt: baseDate.addingTimeInterval(-7_200),
        lastWrappedAt: baseDate.addingTimeInterval(-300)
    )

    static let keychainFallbackWrappedKey = WrappedPayloadKey(
        keyVersion: 1,
        wrappingPolicy: .keychainThisDeviceOnly,
        wrappedKeyData: Data("wrapped-key-keychain-fallback-v1".utf8),
        createdAt: baseDate.addingTimeInterval(-10_800),
        lastWrappedAt: baseDate.addingTimeInterval(-600)
    )

    static let protectedPayloads: [ProtectedClipPayload] = [
        ProtectedClipPayload(
            itemID: "clip-protected-001",
            primaryText: "launchctl bootout gui/501/com.sliptray.preview-agent",
            secondaryText: "Terminal release workflow snippet",
            noteText: "Use after the migration smoke test passes.",
            redactedPreviewText: "Hidden while SlipTray is locked",
            updatedAt: baseDate.addingTimeInterval(-120)
        ),
        ProtectedClipPayload(
            itemID: "clip-protected-002",
            primaryText: "https://internal.sliptray.local/notes/runtime",
            secondaryText: "Runtime notes dashboard",
            noteText: "Check decrypt failures before clearing the cache.",
            redactedPreviewText: "Unlock SlipTray to reveal this preview",
            updatedAt: baseDate.addingTimeInterval(-420)
        )
    ]

    static let encryptedEnvelopes: [EncryptedPayloadEnvelope] = [
        EncryptedPayloadEnvelope(
            itemID: "clip-protected-001",
            keyVersion: secureEnclaveWrappedKey.keyVersion,
            ciphertext: Data("ciphertext-payload-001".utf8),
            nonce: Data("nonce-001".utf8),
            authenticationTag: Data("tag-001".utf8),
            updatedAt: baseDate.addingTimeInterval(-120)
        ),
        EncryptedPayloadEnvelope(
            itemID: "clip-protected-002",
            keyVersion: secureEnclaveWrappedKey.keyVersion,
            ciphertext: Data("ciphertext-payload-002".utf8),
            nonce: Data("nonce-002".utf8),
            authenticationTag: Data("tag-002".utf8),
            updatedAt: baseDate.addingTimeInterval(-420)
        )
    ]

    static let unlockedReadySettings = SecuritySettings(
        isAppLockEnabled: true,
        unlockMethod: .biometricPreferred,
        autoLockInterval: .fiveMinutes,
        privacyMode: .hidePreviewsInMissionControl,
        lastUpdatedAt: baseDate.addingTimeInterval(-900)
    )

    static let lockedSettings = SecuritySettings(
        isAppLockEnabled: true,
        unlockMethod: .systemPassword,
        autoLockInterval: .oneMinute,
        privacyMode: .standard,
        lastUpdatedAt: baseDate.addingTimeInterval(-1_200)
    )

    static let unlockedReadySnapshot = SecurityRuntimeSnapshot(
        lockState: .unlocked,
        settings: unlockedReadySettings,
        migrationState: .ready(lastCompletedAt: baseDate.addingTimeInterval(-1_800)),
        keyMaterialState: .unwrappedInMemory(
            secureEnclaveWrappedKey,
            unwrappedAt: baseDate.addingTimeInterval(-240)
        ),
        lastInteractionAt: baseDate.addingTimeInterval(-30)
    )

    static let lockedSnapshot = SecurityRuntimeSnapshot(
        lockState: .locked,
        settings: lockedSettings,
        migrationState: .ready(lastCompletedAt: baseDate.addingTimeInterval(-3_600)),
        keyMaterialState: .wrappedOnly(keychainFallbackWrappedKey),
        lockedVisibleReason: .autoLockTimeout,
        lastInteractionAt: baseDate.addingTimeInterval(-120)
    )

    static let migrationInProgressSnapshot = SecurityRuntimeSnapshot(
        lockState: .unlocked,
        settings: unlockedReadySettings,
        migrationState: .migrating(
            SecurityMigrationProgress(
                completedItemCount: 18,
                totalItemCount: 42,
                currentItemID: "clip-protected-019",
                startedAt: baseDate.addingTimeInterval(-480)
            )
        ),
        keyMaterialState: .unwrappedInMemory(
            secureEnclaveWrappedKey,
            unwrappedAt: baseDate.addingTimeInterval(-470)
        ),
        lockedVisibleReason: .migrationRequired,
        lastInteractionAt: baseDate.addingTimeInterval(-12)
    )

    static let keyWrapFailure = SecurityFailureState(
        kind: .keyWrapFailed,
        title: "Protected storage unavailable",
        detailText: "SlipTray could not wrap the payload key into local secure storage.",
        occurredAt: baseDate.addingTimeInterval(-75),
        isRecoverable: true
    )

    static let keyWrapFailureSnapshot = SecurityRuntimeSnapshot(
        lockState: .unlockFailed,
        settings: unlockedReadySettings,
        migrationState: .failed(
            SecurityFailureState(
                kind: .migrationFailed,
                title: "Migration paused",
                detailText: "Existing payload migration paused until secure storage becomes available again.",
                failedItemID: "clip-protected-019",
                occurredAt: baseDate.addingTimeInterval(-70),
                isRecoverable: true
            )
        ),
        keyMaterialState: .absent,
        lockedVisibleReason: .keyUnavailable,
        lastFailure: keyWrapFailure,
        lastInteractionAt: baseDate.addingTimeInterval(-75)
    )
}
