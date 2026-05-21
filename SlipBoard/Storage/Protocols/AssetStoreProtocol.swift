import Foundation

protocol AssetStoreProtocol: Sendable {
    func write(_ data: Data, forItemID id: String, ext: String) throws -> URL
    func read(forItemID id: String, ext: String) throws -> Data
    func delete(forItemID id: String) throws
    func exists(forItemID id: String, ext: String) -> Bool
}

