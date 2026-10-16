import Foundation

protocol SecurityStatePublishing: AnyObject {
    var latestSnapshot: SecurityRuntimeSnapshot { get }
    var onSnapshotChange: ((SecurityRuntimeSnapshot) -> Void)? { get set }
}

extension SecurityStatePublishing {
    var isProtectedContentAvailable: Bool {
        latestSnapshot.lockState.revealsProtectedContent
    }
}

protocol SecurityStateControlling: AnyObject {
    func bootstrap()
    func recordInteraction(at date: Date)
    func updateSettings(_ settings: SecuritySettings)
    func lock(reason: SecurityLockedVisibleReason)
    func beginUnlock(using method: SecurityUnlockMethod)
    func completeUnlock(at date: Date)
    func failUnlock(_ failure: SecurityFailureState)
    func clearFailure()
}

typealias SecurityStateProviding = SecurityStatePublishing & SecurityStateControlling

protocol SecuritySettingsStoring {
    var currentSettings: SecuritySettings { get }

    @discardableResult
    func saveSecuritySettings(_ settings: SecuritySettings) -> SecuritySettings
}

protocol PayloadKeyWrapping: AnyObject {
    var keyMaterialState: PayloadKeyMaterialState { get }
    var activeWrappedKey: WrappedPayloadKey? { get }
    var isKeyRecordMissing: Bool { get }
    var unwrappedPayloadKeyData: Data? { get }

    /// Reads the stored key record. Until then the state is `.absent`.
    func loadStoredKeyIfNeeded()

    @discardableResult
    func provisionPayloadKey(
        preferredPolicy: SecurityKeyWrappingPolicy,
        authenticationMethod: SecurityUnlockMethod,
        at date: Date
    ) -> PayloadKeyMaterialState

    @discardableResult
    func unwrapPayloadKey(
        authenticationMethod: SecurityUnlockMethod,
        at date: Date
    ) -> PayloadKeyMaterialState

    @discardableResult
    func rewrapPayloadKey(
        using policy: SecurityKeyWrappingPolicy,
        at date: Date
    ) -> PayloadKeyMaterialState

    @discardableResult
    func clearUnwrappedPayloadKey() -> PayloadKeyMaterialState
}

protocol ProtectedPayloadStoring: AnyObject {
    var latestEnvelopes: [EncryptedPayloadEnvelope] { get }

    func envelope(for itemID: String) -> EncryptedPayloadEnvelope?
    func containsEnvelope(for itemID: String) -> Bool

    @discardableResult
    func replaceEnvelopes(_ envelopes: [EncryptedPayloadEnvelope]) -> [EncryptedPayloadEnvelope]

    @discardableResult
    func saveEnvelope(_ envelope: EncryptedPayloadEnvelope) -> EncryptedPayloadEnvelope

    @discardableResult
    func removeEnvelope(for itemID: String) -> EncryptedPayloadEnvelope?
}

protocol ProtectedPayloadManaging: ProtectedPayloadStoring {
    var latestMigrationState: SecurityMigrationState { get }
    var keyMaterialState: PayloadKeyMaterialState { get }
    var activeWrappedKey: WrappedPayloadKey? { get }
    var isKeyRecordMissing: Bool { get }

    func protectedPayload(for itemID: String) -> ProtectedClipPayload?

    func loadAccessKeyIfNeeded()

    @discardableResult
    func saveProtectedPayload(_ payload: ProtectedClipPayload) -> ProtectedClipPayload?

    @discardableResult
    func saveProtectedPayloads(_ payloads: [ProtectedClipPayload]) -> SecurityMigrationState

    @discardableResult
    func removeProtectedPayload(for itemID: String) -> ProtectedClipPayload?

    @discardableResult
    func provisionAccessKey(
        preferredPolicy: SecurityKeyWrappingPolicy,
        authenticationMethod: SecurityUnlockMethod,
        at date: Date
    ) -> PayloadKeyMaterialState

    @discardableResult
    func unlockAccessKey(
        authenticationMethod: SecurityUnlockMethod,
        at date: Date
    ) -> PayloadKeyMaterialState

    @discardableResult
    func rewrapAccessKey(
        using policy: SecurityKeyWrappingPolicy,
        at date: Date
    ) -> PayloadKeyMaterialState

    @discardableResult
    func clearAccessKeyMaterial() -> PayloadKeyMaterialState
}

protocol DecryptedPayloadCaching: AnyObject {
    var cachedPayloads: [ProtectedClipPayload] { get }

    func cachedPayload(for itemID: String) -> ProtectedClipPayload?

    @discardableResult
    func cachePayload(_ payload: ProtectedClipPayload, cachedAt: Date) -> ProtectedClipPayload

    @discardableResult
    func removeCachedPayload(for itemID: String) -> ProtectedClipPayload?

    @discardableResult
    func clearAllCachedPayloads() -> Int
}
