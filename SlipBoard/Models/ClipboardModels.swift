import Foundation

struct ClipboardItemID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

enum ClipboardContentKind: String, CaseIterable, Sendable {
    case text
    case code
    case image
    case file
    case url
    case color
}

enum ClipboardFilter: String, CaseIterable, Sendable {
    case all
    case text
    case code
    case image
    case file
    case url
    case color

    init(kind: ClipboardContentKind) {
        switch kind {
        case .text:
            self = .text
        case .code:
            self = .code
        case .image:
            self = .image
        case .file:
            self = .file
        case .url:
            self = .url
        case .color:
            self = .color
        }
    }

    func matches(_ kind: ClipboardContentKind) -> Bool {
        self == .all || self == ClipboardFilter(kind: kind)
    }
}

struct SourceAppSummary: Equatable, Hashable, Sendable {
    let displayName: String
    let symbolName: String
}

enum ClipboardPreview: Equatable, Sendable {
    case text(String)
    case code(language: String?, snippet: String)
    case image(description: String)
    case file(name: String, detail: String)
    case url(String)
    case color(hex: String)
}

struct PasteActionSummary: Equatable, Sendable {
    let isAvailable: Bool
    let label: String
    let hint: String?
}

struct ClipboardItem: Equatable, Identifiable, Sendable {
    let id: ClipboardItemID
    let kind: ClipboardContentKind
    let sourceApp: SourceAppSummary
    let capturedAt: Date
    let isPinned: Bool
    let note: String?
    let preview: ClipboardPreview
    let pasteAction: PasteActionSummary
}

struct ClipboardFeedSnapshot: Equatable, Sendable {
    let totalCount: Int
    let filteredCount: Int
    let pinnedItems: [ClipboardItem]
    let recentItems: [ClipboardItem]
    let availableFilters: [ClipboardFilter]
    let lastCapturedAt: Date?
}

struct PopupChromeState: Equatable, Sendable {
    let searchQuery: String
    let activeFilter: ClipboardFilter
    let selectedItemID: ClipboardItemID?
    let pasteMenuItemID: ClipboardItemID?
}
