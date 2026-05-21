import Foundation

struct StorageConfig: Sendable {
    let baseDirectory: URL
    let dbURL: URL
    let payloadsDirectory: URL
    let assetsDirectory: URL
    let thumbnailsDirectory: URL
    
    let maxThumbnailPixelSize: Int
    let maxThumbnailCacheMB: Int
    let maxPreviewMemoryCostMB: Int
    let maxConcurrentPreviews: Int
    
    static var defaultConfiguration: StorageConfig {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("Slipboard", isDirectory: true)
        
        return StorageConfig(
            baseDirectory: baseDir,
            dbURL: baseDir.appendingPathComponent("slipboard.db"),
            payloadsDirectory: baseDir.appendingPathComponent("Payloads", isDirectory: true),
            assetsDirectory: baseDir.appendingPathComponent("Assets", isDirectory: true),
            thumbnailsDirectory: baseDir.appendingPathComponent("Cache/Thumbnails", isDirectory: true),
            maxThumbnailPixelSize: 1024,
            maxThumbnailCacheMB: 200,
            maxPreviewMemoryCostMB: 50,
            maxConcurrentPreviews: 20
        )
    }
}

