import Foundation
import ImageIO
import CoreGraphics

final class ThumbnailCache: ThumbnailCacheProtocol, @unchecked Sendable {
    private let directoryURL: URL
    private let config: StorageConfig
    private let fileManager = FileManager.default
    private let memoryCache = NSCache<NSString, NSData>()
    private let queue = DispatchQueue(label: "com.slipboard.thumbnailcache", qos: .utility)
    
    init(directoryURL: URL, config: StorageConfig) {
        self.directoryURL = directoryURL
        self.config = config
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        self.memoryCache.totalCostLimit = config.maxPreviewMemoryCostMB * 1024 * 1024 // e.g. 50MB
    }
    
    func write(_ data: Data, forItemID id: String) throws {
        // Downsample off main thread if it is an image
        let processedData = downsample(imageData: data)
        
        let key = id as NSString
        memoryCache.setObject(processedData as NSData, forKey: key, cost: processedData.count)
        
        try queue.sync {
            let fileURL = directoryURL.appendingPathComponent(id)
            do {
                try processedData.write(to: fileURL, options: .atomic)
            } catch {
                throw StorageError.writeFailed(reason: "Failed to write thumbnail: \(error.localizedDescription)")
            }
            
            // Trigger eviction
            evictIfNecessary()
        }
    }
    
    func read(forItemID id: String) throws -> Data {
        let key = id as NSString
        if let cached = memoryCache.object(forKey: key) {
            return cached as Data
        }
        
        return try queue.sync {
            let fileURL = directoryURL.appendingPathComponent(id)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw StorageError.readFailed(reason: "Thumbnail not found for ID: \(id)")
            }
            do {
                let data = try Data(contentsOf: fileURL)
                memoryCache.setObject(data as NSData, forKey: key, cost: data.count)
                return data
            } catch {
                throw StorageError.readFailed(reason: "Failed to read thumbnail: \(error.localizedDescription)")
            }
        }
    }
    
    func exists(forItemID id: String) -> Bool {
        let key = id as NSString
        if memoryCache.object(forKey: key) != nil {
            return true
        }
        return queue.sync {
            let fileURL = directoryURL.appendingPathComponent(id)
            return fileManager.fileExists(atPath: fileURL.path)
        }
    }
    
    func delete(forItemID id: String) throws {
        let key = id as NSString
        memoryCache.removeObject(forKey: key)
        
        try queue.sync {
            let fileURL = directoryURL.appendingPathComponent(id)
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    try fileManager.removeItem(at: fileURL)
                } catch {
                    throw StorageError.writeFailed(reason: "Failed to delete thumbnail: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAll() throws {
        memoryCache.removeAllObjects()
        
        queue.sync {
            guard let fileURLs = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: []) else {
                return
            }
            for url in fileURLs {
                try? fileManager.removeItem(at: url)
            }
        }
    }
    
    private func downsample(imageData: Data) -> Data {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return imageData
        }
        
        let maxPixelSize = config.maxThumbnailPixelSize
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return imageData
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.jpeg" as CFString, 1, nil) else {
            return imageData
        }
        
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else {
            return imageData
        }
        
        return mutableData as Data
    }
    
    private func evictIfNecessary() {
        let maxDiskBytes = config.maxThumbnailCacheMB * 1024 * 1024
        
        let resourceKeys: [URLResourceKey] = [.contentAccessDateKey, .fileSizeKey, .contentModificationDateKey]
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: resourceKeys, options: []) else {
            return
        }
        
        struct FileMetadata {
            let url: URL
            let size: Int
            let date: Date
        }
        
        var files = [FileMetadata]()
        var totalSize = 0
        
        for url in fileURLs {
            let values = try? url.resourceValues(forKeys: Set(resourceKeys))
            let size = values?.fileSize ?? 0
            let date = values?.contentAccessDate ?? values?.contentModificationDate ?? Date.distantPast
            files.append(FileMetadata(url: url, size: size, date: date))
            totalSize += size
        }
        
        if totalSize <= maxDiskBytes {
            return
        }
        
        files.sort { $0.date < $1.date }
        
        let targetBytes = Int(Double(maxDiskBytes) * 0.8)
        for file in files {
            if totalSize <= targetBytes {
                break
            }
            do {
                try fileManager.removeItem(at: file.url)
                totalSize -= file.size
            } catch {
                // Ignore delete error
            }
        }
    }
}
