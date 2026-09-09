import Foundation

enum ClipboardHistoryKind: String, CaseIterable, Identifiable, Hashable {
    case text
    case code
    case image
    case file
    case url
    case color
    case richText

    var id: String { rawValue }
}

enum ClipboardHistoryFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case text
    case code
    case image
    case file
    case url
    case color
    case richText

    var id: String { rawValue }

    func matches(_ kind: ClipboardHistoryKind) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            return kind == .text
        case .code:
            return kind == .code
        case .image:
            return kind == .image
        case .file:
            return kind == .file
        case .url:
            return kind == .url
        case .color:
            return kind == .color
        case .richText:
            return kind == .richText
        }
    }
}

struct ClipboardSourceAppSummary: Hashable {
    var bundleID: String?
    var displayName: String
    var symbolName: String?
    var accentToken: String

    init(
        bundleID: String? = nil,
        displayName: String,
        symbolName: String? = nil,
        accentToken: String = "accent.primary"
    ) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.symbolName = symbolName
        self.accentToken = accentToken
    }
}

typealias ClipboardSourceApplication = ClipboardSourceAppSummary

enum ClipboardHistoryPreviewStyle: Hashable {
    case text
    case code(languageHint: String? = nil)
    case image
    case file(fileExtension: String? = nil)
    case url
    case color(swatches: [String] = [])
    case richText
}

struct ClipboardCaptureSample: Hashable {
    var changeCount: Int
    var capturedAt: Date
    var kind: ClipboardHistoryKind
    var rawString: String?
    var rawURL: URL?
    var filePaths: [String]
    var imageAvailable: Bool
    var imageData: Data?
    var richTextAvailable: Bool
    var richTextRTFData: Data?
    var normalizedText: String?
    var normalizedHash: String?
    var sourceApp: ClipboardSourceAppSummary

    init(
        changeCount: Int,
        capturedAt: Date,
        kind: ClipboardHistoryKind,
        rawString: String? = nil,
        rawURL: URL? = nil,
        filePaths: [String] = [],
        imageAvailable: Bool = false,
        imageData: Data? = nil,
        richTextAvailable: Bool = false,
        richTextRTFData: Data? = nil,
        normalizedText: String? = nil,
        normalizedHash: String? = nil,
        sourceApp: ClipboardSourceAppSummary
    ) {
        self.changeCount = changeCount
        self.capturedAt = capturedAt
        self.kind = kind
        self.rawString = rawString
        self.rawURL = rawURL
        self.filePaths = filePaths
        self.imageAvailable = imageAvailable
        self.imageData = imageData
        self.richTextAvailable = richTextAvailable
        self.richTextRTFData = richTextRTFData
        self.normalizedText = normalizedText
        self.normalizedHash = normalizedHash
        self.sourceApp = sourceApp
    }
}

struct ClipboardHistoryItem: Identifiable, Hashable {
    let id: String
    var capturedAt: Date
    var lastCopiedAt: Date
    var kind: ClipboardHistoryKind
    var normalizedHash: String
    var primaryText: String
    var secondaryText: String?
    var metadataText: String
    var secondaryBadgeText: String?
    var previewStyle: ClipboardHistoryPreviewStyle
    var sourceApp: ClipboardSourceAppSummary
    var isPinned: Bool
    var filePaths: [String]
    var colorSwatches: [String]
    var richTextAvailable: Bool
    var richTextRTFData: Data?

    init(
        id: String,
        capturedAt: Date,
        lastCopiedAt: Date,
        kind: ClipboardHistoryKind,
        normalizedHash: String,
        primaryText: String,
        secondaryText: String? = nil,
        metadataText: String,
        secondaryBadgeText: String? = nil,
        previewStyle: ClipboardHistoryPreviewStyle,
        sourceApp: ClipboardSourceAppSummary,
        isPinned: Bool = false,
        filePaths: [String] = [],
        colorSwatches: [String] = [],
        richTextAvailable: Bool = false,
        richTextRTFData: Data? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.lastCopiedAt = lastCopiedAt
        self.kind = kind
        self.normalizedHash = normalizedHash
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.metadataText = metadataText
        self.secondaryBadgeText = secondaryBadgeText
        self.previewStyle = previewStyle
        self.sourceApp = sourceApp
        self.isPinned = isPinned
        self.filePaths = filePaths
        self.colorSwatches = colorSwatches
        self.richTextAvailable = richTextAvailable
        self.richTextRTFData = richTextRTFData
    }

    var dedupeKey: String {
        "\(kind.rawValue):\(normalizedHash)"
    }

    func matches(filter: ClipboardHistoryFilter) -> Bool {
        filter.matches(kind)
    }

    func matches(searchQuery: String) -> Bool {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return true }

        let haystacks = [
            primaryText,
            secondaryText,
            sourceApp.displayName
        ]

        return haystacks
            .compactMap { $0?.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
            .contains(where: {
                $0.contains(trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
            })
    }
}

enum ClipboardCaptureStatus: Hashable {
    case active(latestCaptureAt: Date?)
    case idleEmpty
    case unsupportedSampleIgnored(reason: String, lastChangeCount: Int?)
    case paused(reason: String)
}

enum ClipboardHistoryPartition: String, CaseIterable, Identifiable, Hashable {
    case pinned
    case recent

    var id: String { rawValue }
}

struct ClipboardHistoryPartitionSnapshot: Identifiable, Hashable {
    var partition: ClipboardHistoryPartition
    var items: [ClipboardHistoryItem]

    var id: String { partition.id }

    init(partition: ClipboardHistoryPartition, items: [ClipboardHistoryItem]) {
        self.partition = partition
        self.items = items
    }
}

struct ClipboardHistorySnapshot: Hashable {
    var selectedItemID: String?
    var searchQuery: String
    var activeFilter: ClipboardHistoryFilter
    var captureStatus: ClipboardCaptureStatus
    var pinnedItems: [ClipboardHistoryItem]
    var recentItems: [ClipboardHistoryItem]

    init(
        selectedItemID: String? = nil,
        searchQuery: String = "",
        activeFilter: ClipboardHistoryFilter = .all,
        captureStatus: ClipboardCaptureStatus = .idleEmpty,
        pinnedItems: [ClipboardHistoryItem] = [],
        recentItems: [ClipboardHistoryItem] = []
    ) {
        self.selectedItemID = selectedItemID
        self.searchQuery = searchQuery
        self.activeFilter = activeFilter
        self.captureStatus = captureStatus
        self.pinnedItems = pinnedItems
        self.recentItems = recentItems
    }

    var totalCount: Int {
        pinnedItems.count + recentItems.count
    }

    var allItems: [ClipboardHistoryItem] {
        pinnedItems + recentItems
    }

    var partitions: [ClipboardHistoryPartitionSnapshot] {
        [
            ClipboardHistoryPartitionSnapshot(partition: .pinned, items: pinnedItems),
            ClipboardHistoryPartitionSnapshot(partition: .recent, items: recentItems)
        ]
    }

    var visiblePinnedItems: [ClipboardHistoryItem] {
        pinnedItems.filter {
            $0.matches(filter: activeFilter) && $0.matches(searchQuery: searchQuery)
        }
    }

    var visibleRecentItems: [ClipboardHistoryItem] {
        recentItems.filter {
            $0.matches(filter: activeFilter) && $0.matches(searchQuery: searchQuery)
        }
    }

    var visibleItems: [ClipboardHistoryItem] {
        visiblePinnedItems + visibleRecentItems
    }
}
