import Foundation

public struct ExcludedApp: Hashable, Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String
    public let category: String
    
    public init(id: UUID = UUID(), name: String, bundleIdentifier: String, category: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.category = category
    }
}
