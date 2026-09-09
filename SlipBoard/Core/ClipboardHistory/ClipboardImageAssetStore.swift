import Foundation

final class ClipboardImageAssetStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let memoryCache = NSCache<NSString, NSData>()

    init(
        configuration: RetentionStoreConfiguration = .default(),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = configuration.assetCacheDirectoryURL
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func save(_ data: Data, for clipID: String) -> Bool {
        guard data.isEmpty == false else { return false }
        do {
            try data.write(to: url(for: clipID), options: .atomic)
            memoryCache.setObject(data as NSData, forKey: clipID as NSString)
            return true
        } catch {
            return false
        }
    }

    nonisolated func data(for clipID: String) -> Data? {
        if let cached = memoryCache.object(forKey: clipID as NSString) {
            return cached as Data
        }

        guard let data = try? Data(contentsOf: url(for: clipID)) else { return nil }
        memoryCache.setObject(data as NSData, forKey: clipID as NSString)
        return data
    }

    private func url(for clipID: String) -> URL {
        directoryURL.appendingPathComponent("asset-\(clipID)")
    }
}
