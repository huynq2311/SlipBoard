import Foundation

public enum ClipType: String, Codable, CaseIterable {
    case text = "Text"
    case code = "Code"
    case image = "Image"
    case file = "File"
    case url = "URL"
}

public struct ClipItem: Identifiable, Hashable, Codable {
    public let id: UUID
    public let contentType: ClipType
    public let contentString: String
    public let sourceApp: String
    public let sourceAppIcon: String
    public let timestamp: Date
    public var isPinned: Bool
    public var note: String?
    public var tags: [String]
    public var folder: String?
    
    public init(
        id: UUID = UUID(),
        contentType: ClipType,
        contentString: String,
        sourceApp: String,
        sourceAppIcon: String,
        timestamp: Date = Date(),
        isPinned: Bool = false,
        note: String? = nil,
        tags: [String] = [],
        folder: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.contentString = contentString
        self.sourceApp = sourceApp
        self.sourceAppIcon = sourceAppIcon
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.note = note
        self.tags = tags
        self.folder = folder
    }
    
    public var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
