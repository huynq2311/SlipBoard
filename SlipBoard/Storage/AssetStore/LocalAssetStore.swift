import Foundation

final class LocalAssetStore: AssetStoreProtocol, @unchecked Sendable {
    private let directoryURL: URL
    private let fileManager = FileManager.default
    
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    private func url(forItemID id: String, ext: String) -> URL {
        return directoryURL
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("original.\(ext)")
    }
    
    func write(_ data: Data, forItemID id: String, ext: String) throws -> URL {
        let fileURL = url(forItemID: id, ext: ext)
        let folderURL = fileURL.deletingLastPathComponent()
        
        if !fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw StorageError.writeFailed(reason: "Failed to create asset directory: \(error.localizedDescription)")
            }
        }
        
        let tempURL = directoryURL.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
            try fileManager.moveItem(at: tempURL, to: fileURL)
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw StorageError.writeFailed(reason: "Failed to write asset file: \(error.localizedDescription)")
        }
        
        return fileURL
    }
    
    func read(forItemID id: String, ext: String) throws -> Data {
        let fileURL = url(forItemID: id, ext: ext)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw StorageError.assetNotFound(itemID: id)
        }
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw StorageError.readFailed(reason: "Failed to read asset file: \(error.localizedDescription)")
        }
    }
    
    func delete(forItemID id: String) throws {
        let folderURL = directoryURL.appendingPathComponent(id, isDirectory: true)
        if fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.removeItem(at: folderURL)
            } catch {
                throw StorageError.writeFailed(reason: "Failed to delete asset directory: \(error.localizedDescription)")
            }
        }
    }
    
    func exists(forItemID id: String, ext: String) -> Bool {
        return fileManager.fileExists(atPath: url(forItemID: id, ext: ext).path)
    }
}
