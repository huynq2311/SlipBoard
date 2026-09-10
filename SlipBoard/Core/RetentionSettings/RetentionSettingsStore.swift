import Foundation

struct RetentionStoreConfiguration: Hashable {
    var modelName: String
    var storeURL: URL
    var assetCacheDirectoryURL: URL

    nonisolated static func `default`(fileManager: FileManager = .default) -> RetentionStoreConfiguration {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let slipBoardURL = baseURL.appendingPathComponent("SlipBoard", isDirectory: true)
        let databaseURL = slipBoardURL.appendingPathComponent("Database", isDirectory: true)
        let cacheURL = slipBoardURL.appendingPathComponent("Cache", isDirectory: true)

        return RetentionStoreConfiguration(
            modelName: "SlipBoard",
            storeURL: databaseURL.appendingPathComponent("SlipBoard.sqlite"),
            assetCacheDirectoryURL: cacheURL
        )
    }
}

final class RetentionSettingsStore: RetentionSettingsStoring {
    private let backingStore: RetentionSettingsStoring
    private(set) var snapshot: RetentionPersistenceSnapshot

    init(backingStore: RetentionSettingsStoring = CoreDataRetentionStore()) {
        self.backingStore = backingStore
        self.snapshot = backingStore.snapshot
    }

    func storedClip(for id: String) -> RetentionManagedClip? {
        snapshot.storedClips.first(where: { $0.id == id }) ?? backingStore.storedClip(for: id)
    }

    @discardableResult
    func saveRetentionSettings(_ settings: RetentionSettings) -> RetentionPersistenceSnapshot {
        sync(backingStore.saveRetentionSettings(settings))
    }

    @discardableResult
    func saveAssetCacheSettings(_ settings: AssetCacheSettings) -> RetentionPersistenceSnapshot {
        sync(backingStore.saveAssetCacheSettings(settings))
    }

    @discardableResult
    func replaceStoredClips(_ clips: [RetentionManagedClip]) -> RetentionPersistenceSnapshot {
        sync(backingStore.replaceStoredClips(clips))
    }

    @discardableResult
    func upsertStoredClips(_ clips: [RetentionManagedClip]) -> RetentionPersistenceSnapshot {
        sync(backingStore.upsertStoredClips(clips))
    }

    @discardableResult
    func removeStoredClips(ids: [String]) -> RetentionPersistenceSnapshot {
        sync(backingStore.removeStoredClips(ids: ids))
    }

    @discardableResult
    func saveLatestCleanupResult(_ result: RetentionCleanupResult?) -> RetentionPersistenceSnapshot {
        sync(backingStore.saveLatestCleanupResult(result))
    }

    @discardableResult
    private func sync(_ snapshot: RetentionPersistenceSnapshot) -> RetentionPersistenceSnapshot {
        self.snapshot = snapshot
        return snapshot
    }
}
