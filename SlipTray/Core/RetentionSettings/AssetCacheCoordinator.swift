import Foundation

final class AssetCacheCoordinator: AssetCacheAccounting {
    private let fileManager: FileManager
    private let cacheDirectoryURL: URL

    init(
        configuration: RetentionStoreConfiguration = .default(),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.cacheDirectoryURL = configuration.assetCacheDirectoryURL
        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
    }

    func refreshUsage() -> AssetCacheSettings {
        AssetCacheSettings(
            currentUsageBytes: currentUsageBytes(),
            lastSweepAt: .now
        )
    }

    func trimIfNeeded(using settings: AssetCacheSettings, trigger: RetentionCleanupTrigger) -> RetentionCleanupResult? {
        var usage = currentUsageBytes()
        guard usage > settings.maxCacheSizeBytes else {
            return nil
        }

        let files = cachedFileEntries().sorted {
            ($0.modifiedAt, $0.url.lastPathComponent) < ($1.modifiedAt, $1.url.lastPathComponent)
        }

        var removedAssetCount = 0
        var freedBytes: Int64 = 0

        for file in files where usage > settings.maxCacheSizeBytes {
            if removeItem(at: file.url) {
                removedAssetCount += 1
                freedBytes += file.size
                usage = max(0, usage - file.size)
            }
        }

        guard removedAssetCount > 0 else {
            return nil
        }

        return RetentionCleanupResult(
            trigger: trigger,
            removedAssetCount: removedAssetCount,
            freedBytes: freedBytes,
            completedAt: .now,
            statusMessage: "Cleared \(removedAssetCount) cached asset\(removedAssetCount == 1 ? "" : "s") to stay within the cache limit."
        )
    }

    func clearCache(trigger: RetentionCleanupTrigger) -> RetentionCleanupResult {
        let files = cachedFileEntries()
        let removedAssetCount = files.count
        let freedBytes = files.reduce(Int64(0)) { $0 + $1.size }

        for file in files {
            _ = removeItem(at: file.url)
        }

        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)

        return RetentionCleanupResult(
            trigger: trigger,
            removedAssetCount: removedAssetCount,
            freedBytes: freedBytes,
            completedAt: .now,
            statusMessage: freedBytes > 0
                ? "Cleared \(Self.formattedMegabytes(freedBytes)) of local asset cache."
                : "Local asset cache was already empty."
        )
    }

    func removeAssets(withKeys keys: [String], trigger: RetentionCleanupTrigger) -> RetentionCleanupResult? {
        let uniqueKeys = Array(Set(keys)).filter { $0.isEmpty == false }
        guard uniqueKeys.isEmpty == false else {
            return nil
        }

        var removedAssetCount = 0
        var freedBytes: Int64 = 0

        for key in uniqueKeys {
            let url = cacheDirectoryURL.appendingPathComponent(Self.sanitizedFileName(for: key))
            let size = itemSize(at: url)
            if removeItem(at: url) {
                removedAssetCount += 1
                freedBytes += size
            }
        }

        guard removedAssetCount > 0 else {
            return nil
        }

        return RetentionCleanupResult(
            trigger: trigger,
            removedAssetCount: removedAssetCount,
            freedBytes: freedBytes,
            completedAt: .now,
            statusMessage: "Removed \(removedAssetCount) cached asset\(removedAssetCount == 1 ? "" : "s")."
        )
    }

    private func currentUsageBytes() -> Int64 {
        cachedFileEntries().reduce(Int64(0)) { $0 + $1.size }
    }

    private func cachedFileEntries() -> [CachedFileEntry] {
        let fileURLs = (try? fileManager.contentsOfDirectory(
            at: cacheDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return fileURLs.compactMap { url in
            guard
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                values.isDirectory != true
            else {
                return nil
            }

            return CachedFileEntry(
                url: url,
                modifiedAt: values.contentModificationDate ?? .distantPast,
                size: itemSize(at: url)
            )
        }
    }

    private func itemSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
        if let allocatedSize = values?.totalFileAllocatedSize {
            return Int64(allocatedSize)
        }
        if let fileSize = values?.fileSize {
            return Int64(fileSize)
        }
        return 0
    }

    private func removeItem(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }

        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    private static func sanitizedFileName(for key: String) -> String {
        key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    private static func formattedMegabytes(_ bytes: Int64) -> String {
        let megabytes = Double(bytes) / (1_024 * 1_024)
        return String(format: "%.0f MB", megabytes)
    }
}

private struct CachedFileEntry {
    var url: URL
    var modifiedAt: Date
    var size: Int64
}
