import Foundation

protocol StorageCoordinatorProtocol: Sendable {
    func capture(_ snapshot: RawPasteboardSnapshot) async throws
    func runRetentionSweep(config: RetentionConfig) async throws
    func search(query: String) async throws -> [ClipRecord]
    func timeline(limit: Int, before: Date?) async throws -> [ClipEventRecord]
    func dedupedFeed(limit: Int, before: Date?) async throws -> [ClipRecord]
}

