import CoreGraphics
import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

final class ClipboardImageAssetStore {
    private nonisolated static let logger = Logger(subsystem: "huynq.SlipBoard", category: "ImageAssets")

    /// Shared by every store instance so clip cards and paste actions do not
    /// each keep their own copy of the same image bytes.
    private nonisolated(unsafe) static let memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.totalCostLimit = 64 * 1_024 * 1_024
        return cache
    }()

    private nonisolated(unsafe) let fileManager: FileManager
    private let directoryURL: URL

    nonisolated init(
        configuration: RetentionStoreConfiguration = .default(),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = configuration.assetCacheDirectoryURL
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    /// Makes the image available immediately and writes it to disk off the
    /// main thread, compacting TIFF to lossless PNG first.
    func save(_ data: Data, for clipID: String) {
        guard data.isEmpty == false else { return }
        Self.memoryCache.setObject(data as NSData, forKey: clipID as NSString, cost: data.count)

        let fileURL = url(for: clipID)
        Task.detached(priority: .utility) {
            let storedData = Self.imageType(of: data) == .tiff
                ? Self.pngData(fromTIFF: data) ?? data
                : data
            guard (try? storedData.write(to: fileURL, options: .atomic)) != nil else { return }
            Self.memoryCache.setObject(storedData as NSData, forKey: clipID as NSString, cost: storedData.count)
        }
    }

    nonisolated func data(for clipID: String) -> Data? {
        if let cached = Self.memoryCache.object(forKey: clipID as NSString) {
            return cached as Data
        }

        guard let data = try? Data(contentsOf: url(for: clipID)) else { return nil }
        Self.memoryCache.setObject(data as NSData, forKey: clipID as NSString, cost: data.count)
        return data
    }

    /// Decodes a card-sized image without loading the full image into memory.
    nonisolated func thumbnail(for clipID: String, maxPixelSize: Int) -> CGImage? {
        let source = Self.memoryCache.object(forKey: clipID as NSString)
            .flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }
            ?? CGImageSourceCreateWithURL(url(for: clipID) as CFURL, nil)
        guard let source else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(
            source,
            CGImageSourceGetPrimaryImageIndex(source),
            options as CFDictionary
        )
    }

    /// Rewrites assets that earlier builds saved as uncompressed TIFF as
    /// lossless PNG. Files are handled one at a time and TIFF is detected from
    /// the bytes, so an interrupted pass simply continues on the next launch.
    nonisolated func compactLegacyTIFFAssets() {
        let fileURLs = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var compactedCount = 0
        var failedCount = 0
        var bytesBefore = 0
        var bytesAfter = 0

        for fileURL in fileURLs where fileURL.lastPathComponent.hasPrefix("asset-") {
            autoreleasepool {
                guard
                    let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
                    Self.imageType(of: data) == .tiff
                else {
                    return
                }

                // Hidden, so the cache size sweep never counts or trims it.
                let temporaryURL = directoryURL.appendingPathComponent(".\(fileURL.lastPathComponent).png")
                let modifiedAt = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

                guard
                    let pngData = Self.pngData(fromTIFF: data),
                    (try? pngData.write(to: temporaryURL, options: .atomic)) != nil
                else {
                    failedCount += 1
                    return
                }

                // Swap rather than move: the swap fails if retention cleanup
                // removed the asset meanwhile, so a deleted clip stays deleted.
                guard renamex_np(temporaryURL.path, fileURL.path, UInt32(RENAME_SWAP)) == 0 else {
                    try? fileManager.removeItem(at: temporaryURL)
                    failedCount += 1
                    return
                }

                // The temporary path now holds the old TIFF.
                try? fileManager.removeItem(at: temporaryURL)
                // Cache trimming evicts the oldest files first; keep their age.
                if let modifiedAt {
                    try? fileManager.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: fileURL.path)
                }
                compactedCount += 1
                bytesBefore += data.count
                bytesAfter += pngData.count
            }
        }

        guard compactedCount > 0 || failedCount > 0 else { return }
        Self.logger.info(
            "Compacted \(compactedCount) TIFF image assets from \(bytesBefore) to \(bytesAfter) bytes; \(failedCount) failed"
        )
    }

    nonisolated static func imageType(of data: Data) -> UTType? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let identifier = CGImageSourceGetType(source)
        else {
            return nil
        }

        return UTType(identifier as String)
    }

    private nonisolated static func pngData(fromTIFF data: Data) -> Data? {
        let pngData = NSMutableData()
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let destination = CGImageDestinationCreateWithData(pngData, UTType.png.identifier as CFString, 1, nil)
        else {
            return nil
        }

        CGImageDestinationAddImageFromSource(destination, source, CGImageSourceGetPrimaryImageIndex(source), nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return pngData as Data
    }

    private nonisolated func url(for clipID: String) -> URL {
        directoryURL.appendingPathComponent("asset-\(clipID)")
    }
}
