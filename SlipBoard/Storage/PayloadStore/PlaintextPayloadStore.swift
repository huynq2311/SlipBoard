import Foundation

final class PlaintextPayloadStore: PayloadStoreProtocol, @unchecked Sendable {
    private let directoryURL: URL
    private let fileManager = FileManager.default
    
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    func url(for hash: String) -> URL {
        // Payloads/<xx>/<yy>/<sha256>.payload
        // hash is expected to be a sha256 hex string (at least 4 characters long)
        let xx = hash.count >= 2 ? String(hash.prefix(2)) : "00"
        let yy: String
        if hash.count >= 4 {
            let start = hash.index(hash.startIndex, offsetBy: 2)
            let end = hash.index(hash.startIndex, offsetBy: 4)
            yy = String(hash[start..<end])
        } else {
            yy = "00"
        }
        
        return directoryURL
            .appendingPathComponent(xx, isDirectory: true)
            .appendingPathComponent(yy, isDirectory: true)
            .appendingPathComponent("\(hash).payload")
    }
    
    func write(_ data: Data, hash: String) throws -> URL {
        let fileURL = url(for: hash)
        let folderURL = fileURL.deletingLastPathComponent()
        
        if !fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw StorageError.writeFailed(reason: "Failed to create payload directory: \(error.localizedDescription)")
            }
        }
        
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        let tempURL = directoryURL.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            try fileManager.moveItem(at: tempURL, to: fileURL)
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw StorageError.writeFailed(reason: "Failed to write payload file: \(error.localizedDescription)")
        }
        
        return fileURL
    }
    
    func read(hash: String) throws -> Data {
        let fileURL = url(for: hash)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw StorageError.payloadNotFound(hash: hash)
        }
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw StorageError.readFailed(reason: "Failed to read payload file: \(error.localizedDescription)")
        }
    }
    
    func delete(hash: String) throws {
        let fileURL = url(for: hash)
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                throw StorageError.writeFailed(reason: "Failed to delete payload file: \(error.localizedDescription)")
            }
        }
    }
    
    func exists(hash: String) -> Bool {
        return fileManager.fileExists(atPath: url(for: hash).path)
    }
}

