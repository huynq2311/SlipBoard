import Foundation

enum SecurityLockState: String, CaseIterable, Identifiable, Hashable {
    case unlocked
    case locked
    case unlocking
    case unlockFailed

    var id: String { rawValue }

    var revealsProtectedContent: Bool {
        self == .unlocked
    }
}

enum SecurityUnlockMethod: String, CaseIterable, Identifiable, Hashable {
    case biometricPreferred
    case systemPassword

    var id: String { rawValue }
}

enum SecurityAutoLockInterval: String, CaseIterable, Identifiable, Hashable {
    case never
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case oneHour

    var id: String { rawValue }

    var duration: TimeInterval? {
        switch self {
        case .never:
            return nil
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 5 * 60
        case .fifteenMinutes:
            return 15 * 60
        case .oneHour:
            return 60 * 60
        }
    }
}

enum SecurityPrivacyMode: String, CaseIterable, Identifiable, Hashable {
    case standard
    case hidePreviewsInMissionControl

    var id: String { rawValue }

    var hidesPreviewsOutsideUnlockedWindows: Bool {
        self == .hidePreviewsInMissionControl
    }
}

enum SecurityLockedVisibleReason: String, CaseIterable, Identifiable, Hashable {
    case manual
    case autoLockTimeout
    case backgroundTransition
    case authenticationRequired
    case keyUnavailable
    case migrationRequired

    var id: String { rawValue }
}

enum SecurityFailureKind: String, CaseIterable, Identifiable, Hashable {
    case keyProvisioningFailed
    case authenticationFailed
    case keyWrapFailed
    case keyUnwrapFailed
    case migrationFailed
    case itemDecryptFailed

    var id: String { rawValue }
}

struct SecurityFailureState: Identifiable, Hashable {
    var kind: SecurityFailureKind
    var title: String
    var detailText: String
    var failedItemID: String?
    var occurredAt: Date
    var isRecoverable: Bool

    var id: String {
        [
            kind.rawValue,
            failedItemID ?? "none",
            String(Int(occurredAt.timeIntervalSince1970))
        ].joined(separator: ":")
    }

    init(
        kind: SecurityFailureKind,
        title: String,
        detailText: String,
        failedItemID: String? = nil,
        occurredAt: Date = .now,
        isRecoverable: Bool = true
    ) {
        self.kind = kind
        self.title = title
        self.detailText = detailText
        self.failedItemID = failedItemID
        self.occurredAt = occurredAt
        self.isRecoverable = isRecoverable
    }
}

struct SecurityMigrationProgress: Hashable {
    var completedItemCount: Int
    var totalItemCount: Int
    var currentItemID: String?
    var startedAt: Date

    init(
        completedItemCount: Int = 0,
        totalItemCount: Int,
        currentItemID: String? = nil,
        startedAt: Date = .now
    ) {
        self.completedItemCount = max(completedItemCount, 0)
        self.totalItemCount = max(totalItemCount, 0)
        self.currentItemID = currentItemID
        self.startedAt = startedAt
    }

    var fractionCompleted: Double {
        guard totalItemCount > 0 else { return 0 }
        return min(Double(completedItemCount) / Double(totalItemCount), 1)
    }
}

enum SecurityMigrationState: Hashable {
    case notStarted
    case migrating(SecurityMigrationProgress)
    case ready(lastCompletedAt: Date?)
    case failed(SecurityFailureState)

    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }
}

struct SecuritySettings: Hashable {
    var isAppLockEnabled: Bool
    var unlockMethod: SecurityUnlockMethod
    var autoLockInterval: SecurityAutoLockInterval
    var privacyMode: SecurityPrivacyMode
    var lastUpdatedAt: Date

    init(
        isAppLockEnabled: Bool = false,
        unlockMethod: SecurityUnlockMethod = .biometricPreferred,
        autoLockInterval: SecurityAutoLockInterval = .never,
        privacyMode: SecurityPrivacyMode = .standard,
        lastUpdatedAt: Date = .now
    ) {
        self.isAppLockEnabled = isAppLockEnabled
        self.unlockMethod = unlockMethod
        self.autoLockInterval = autoLockInterval
        self.privacyMode = privacyMode
        self.lastUpdatedAt = lastUpdatedAt
    }
}

enum SecurityKeyWrappingPolicy: String, CaseIterable, Identifiable, Hashable {
    case secureEnclaveWrapped
    case keychainThisDeviceOnly

    var id: String { rawValue }
}

struct WrappedPayloadKey: Hashable {
    var keyVersion: Int
    var wrappingPolicy: SecurityKeyWrappingPolicy
    var wrappedKeyData: Data
    var createdAt: Date
    var lastWrappedAt: Date

    init(
        keyVersion: Int = 1,
        wrappingPolicy: SecurityKeyWrappingPolicy,
        wrappedKeyData: Data,
        createdAt: Date = .now,
        lastWrappedAt: Date = .now
    ) {
        self.keyVersion = keyVersion
        self.wrappingPolicy = wrappingPolicy
        self.wrappedKeyData = wrappedKeyData
        self.createdAt = createdAt
        self.lastWrappedAt = lastWrappedAt
    }
}

enum PayloadKeyMaterialState: Hashable {
    case absent
    case wrappedOnly(WrappedPayloadKey)
    case unwrappedInMemory(WrappedPayloadKey, unwrappedAt: Date)

    var activeWrappedKey: WrappedPayloadKey? {
        switch self {
        case .absent:
            return nil
        case let .wrappedOnly(wrappedKey),
             let .unwrappedInMemory(wrappedKey, _):
            return wrappedKey
        }
    }

    var hasUnwrappedKeyInMemory: Bool {
        if case .unwrappedInMemory = self {
            return true
        }
        return false
    }
}

struct ProtectedClipPayload: Identifiable, Hashable {
    var itemID: String
    var primaryText: String
    var secondaryText: String?
    var noteText: String?
    var redactedPreviewText: String?
    var updatedAt: Date

    var id: String { itemID }

    init(
        itemID: String,
        primaryText: String,
        secondaryText: String? = nil,
        noteText: String? = nil,
        redactedPreviewText: String? = nil,
        updatedAt: Date = .now
    ) {
        self.itemID = itemID
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.noteText = noteText
        self.redactedPreviewText = redactedPreviewText
        self.updatedAt = updatedAt
    }
}

enum EncryptedPayloadAlgorithm: String, CaseIterable, Identifiable, Hashable {
    case aes256GCM

    var id: String { rawValue }
}

enum EncryptedPayloadCompressionMode: String, CaseIterable, Identifiable, Hashable {
    case none
    case lzfse

    var id: String { rawValue }
}

struct EncryptedPayloadEnvelope: Identifiable, Hashable {
    var itemID: String
    var keyVersion: Int
    var algorithm: EncryptedPayloadAlgorithm
    var compressionMode: EncryptedPayloadCompressionMode
    var ciphertext: Data
    var nonce: Data
    var authenticationTag: Data
    var updatedAt: Date

    var id: String { itemID }

    init(
        itemID: String,
        keyVersion: Int = 1,
        algorithm: EncryptedPayloadAlgorithm = .aes256GCM,
        compressionMode: EncryptedPayloadCompressionMode = .lzfse,
        ciphertext: Data,
        nonce: Data,
        authenticationTag: Data,
        updatedAt: Date = .now
    ) {
        self.itemID = itemID
        self.keyVersion = keyVersion
        self.algorithm = algorithm
        self.compressionMode = compressionMode
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.authenticationTag = authenticationTag
        self.updatedAt = updatedAt
    }
}

struct SecurityRuntimeSnapshot: Hashable {
    var lockState: SecurityLockState
    var settings: SecuritySettings
    var migrationState: SecurityMigrationState
    var keyMaterialState: PayloadKeyMaterialState
    var lockedVisibleReason: SecurityLockedVisibleReason?
    var lastFailure: SecurityFailureState?
    var lastInteractionAt: Date?

    init(
        lockState: SecurityLockState,
        settings: SecuritySettings,
        migrationState: SecurityMigrationState = .notStarted,
        keyMaterialState: PayloadKeyMaterialState = .absent,
        lockedVisibleReason: SecurityLockedVisibleReason? = nil,
        lastFailure: SecurityFailureState? = nil,
        lastInteractionAt: Date? = nil
    ) {
        self.lockState = lockState
        self.settings = settings
        self.migrationState = migrationState
        self.keyMaterialState = keyMaterialState
        self.lockedVisibleReason = lockedVisibleReason
        self.lastFailure = lastFailure
        self.lastInteractionAt = lastInteractionAt
    }

    var hasUnwrappedPayloadKey: Bool {
        keyMaterialState.hasUnwrappedKeyInMemory
    }

    var isSearchAvailable: Bool {
        lockState.revealsProtectedContent
    }

    var isPreviewRedactionActive: Bool {
        settings.privacyMode.hidesPreviewsOutsideUnlockedWindows
    }
}
