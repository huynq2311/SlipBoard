import Foundation

protocol FTSIndexProtocol: Sendable {
    func insert(clipID: String, normalizedText: String, note: String) throws
    func update(clipID: String, normalizedText: String, note: String) throws
    func delete(clipID: String) throws
    func search(query: String) throws -> [(clipID: String, matchScore: Double)]
    func clearNotes() throws
    func clearAll() throws
}

