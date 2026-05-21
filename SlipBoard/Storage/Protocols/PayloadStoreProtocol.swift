import Foundation

protocol PayloadStoreProtocol: Sendable {
    func write(_ data: Data, hash: String) throws -> URL
    func read(hash: String) throws -> Data
    func delete(hash: String) throws
    func exists(hash: String) -> Bool
    func url(for hash: String) -> URL
}

