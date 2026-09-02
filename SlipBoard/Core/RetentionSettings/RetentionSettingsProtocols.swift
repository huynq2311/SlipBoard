import Foundation

protocol RetentionSettingsStoreQuerying {
    var snapshot: RetentionPersistenceSnapshot { get }

    func storedClip(for id: String) -> RetentionManagedClip?
}

protocol RetentionSettingsStoreMutating: AnyObject {
    @discardableResult
    func saveRetentionSettings(_ settings: RetentionSettings) -> RetentionPersistenceSnapshot

    @discardableResult
    func saveAssetCacheSettings(_ settings: AssetCacheSettings) -> RetentionPersistenceSnapshot

    @discardableResult
    func replaceStoredClips(_ clips: [RetentionManagedClip]) -> RetentionPersistenceSnapshot

    @discardableResult
    func upsertStoredClips(_ clips: [RetentionManagedClip]) -> RetentionPersistenceSnapshot

    @discardableResult
    func removeStoredClips(ids: [String]) -> RetentionPersistenceSnapshot

    @discardableResult
    func saveLatestCleanupResult(_ result: RetentionCleanupResult?) -> RetentionPersistenceSnapshot
}

typealias RetentionSettingsStoring = RetentionSettingsStoreQuerying & RetentionSettingsStoreMutating

protocol RetentionCleanupCoordinating: AnyObject {
    func makeCleanupPlan(for request: RetentionCleanupRequest) -> RetentionCleanupPlan
    func executeCleanup(for request: RetentionCleanupRequest) -> RetentionCleanupResult
}

protocol AssetCacheAccounting: AnyObject {
    func refreshUsage() -> AssetCacheSettings
    func trimIfNeeded(using settings: AssetCacheSettings, trigger: RetentionCleanupTrigger) -> RetentionCleanupResult?
    func clearCache(trigger: RetentionCleanupTrigger) -> RetentionCleanupResult
    func removeAssets(withKeys keys: [String], trigger: RetentionCleanupTrigger) -> RetentionCleanupResult?
}

protocol RetentionRuntimePublishing: AnyObject {
    var latestSnapshot: RetentionRuntimeSnapshot { get }
    var onSnapshotChange: ((RetentionRuntimeSnapshot) -> Void)? { get set }
    var onCleanupResult: ((RetentionCleanupResult) -> Void)? { get set }
}

protocol RetentionRuntimeControlling: RetentionRuntimePublishing {
    func bootstrap()
    func handleCleanupTrigger(_ trigger: RetentionCleanupTrigger) -> RetentionCleanupResult?
    func updateRetentionSettings(_ settings: RetentionSettings)
    func updateAssetCacheSettings(_ settings: AssetCacheSettings)
    func refreshCacheUsage()
    func clearCacheNow() -> RetentionCleanupResult
}
