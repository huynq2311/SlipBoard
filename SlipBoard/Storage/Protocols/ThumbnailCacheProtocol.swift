import Foundation

protocol ThumbnailCacheProtocol: Sendable {
    func write(_ data: Data, forItemID id: String) throws
    func read(forItemID id: String) throws -> Data
    func exists(forItemID id: String) -> Bool
    func delete(forItemID id: String) throws
    func clearAll() throws
}

