import Foundation

enum ClipKind: String, CaseIterable, Identifiable, Hashable {
    case text
    case code
    case image
    case file
    case url
    case color
    case richText

    var id: String { rawValue }
}

struct ClipSourceAppSummary: Identifiable, Hashable {
    let id: String
    var displayName: String
    var symbolName: String?
    var accentToken: String

    init(
        id: String,
        displayName: String,
        symbolName: String? = nil,
        accentToken: String = "accent.primary"
    ) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
        self.accentToken = accentToken
    }
}

enum ClipPreviewStyle: Hashable {
    case text
    case code(languageHint: String? = nil)
    case image
    case file(fileExtension: String? = nil)
    case url
    case color(swatches: [String] = [])
    case richText
}

struct ClipPreviewSummary: Identifiable, Hashable {
    let id: String
    var kind: ClipKind
    var titleText: String
    var bodyText: String?
    var metadataText: String
    var isPinned: Bool
    var noteText: String?
    var sourceApp: ClipSourceAppSummary
    var createdLabel: String
    var previewStyle: ClipPreviewStyle
    var secondaryBadgeText: String?
    var richTextRTFData: Data?
    var filePaths: [String]

    var hasNote: Bool {
        guard let noteText else { return false }
        return noteText.isEmpty == false
    }

    init(
        id: String,
        kind: ClipKind,
        titleText: String,
        bodyText: String? = nil,
        metadataText: String,
        isPinned: Bool = false,
        noteText: String? = nil,
        sourceApp: ClipSourceAppSummary,
        createdLabel: String,
        previewStyle: ClipPreviewStyle,
        secondaryBadgeText: String? = nil,
        richTextRTFData: Data? = nil,
        filePaths: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.titleText = titleText
        self.bodyText = bodyText
        self.metadataText = metadataText
        self.isPinned = isPinned
        self.noteText = noteText
        self.sourceApp = sourceApp
        self.createdLabel = createdLabel
        self.previewStyle = previewStyle
        self.secondaryBadgeText = secondaryBadgeText
        self.richTextRTFData = richTextRTFData
        self.filePaths = filePaths
    }
}

struct PopupFilterOption: Identifiable, Hashable {
    let id: String
    var label: String
    var iconName: String
    var count: Int?

    init(
        id: String,
        label: String,
        iconName: String,
        count: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.iconName = iconName
        self.count = count
    }
}

enum PopupAppearance: String, CaseIterable, Identifiable, Hashable {
    case system
    case dark
    case light

    var id: String { rawValue }
}

/// Which bundled theme file the popup uses, and whether it follows the system
/// appearance or pins light/dark.
struct PopupThemeSelection: Hashable {
    static let defaultThemeID = "default"
    static let fallback = PopupThemeSelection(themeID: defaultThemeID, appearance: .light)

    var themeID: String
    var appearance: PopupAppearance
}

enum PopupStatusTone: String, Hashable {
    case normal
    case success
    case warning
    case paused
    case locked
}

struct PopupStatusSummary: Hashable {
    var statusLabel: String
    var statusTone: PopupStatusTone
    var primaryHint: String
    var secondaryHint: String
    var itemCountText: String

    init(
        statusLabel: String,
        statusTone: PopupStatusTone = .normal,
        primaryHint: String,
        secondaryHint: String,
        itemCountText: String
    ) {
        self.statusLabel = statusLabel
        self.statusTone = statusTone
        self.primaryHint = primaryHint
        self.secondaryHint = secondaryHint
        self.itemCountText = itemCountText
    }
}

enum PopupOverlayKind: String, Hashable {
    case contextMenu
    case pasteTransformMenu
}

struct PopupOverlayState: Hashable {
    var kind: PopupOverlayKind
    var anchorClipID: String
    var highlightedRowID: String?

    init(
        kind: PopupOverlayKind,
        anchorClipID: String,
        highlightedRowID: String? = nil
    ) {
        self.kind = kind
        self.anchorClipID = anchorClipID
        self.highlightedRowID = highlightedRowID
    }
}

struct PopupShellViewState: Hashable {
    var selectedClipID: String?
    var searchQuery: String
    var isSearchPresented: Bool
    var activeFilterID: String
    var themePreview: PopupThemeSelection
    var pinnedClips: [ClipPreviewSummary]
    var recentClips: [ClipPreviewSummary]
    var status: PopupStatusSummary
    var activeOverlay: PopupOverlayState?

    var allClips: [ClipPreviewSummary] {
        pinnedClips + recentClips
    }

    init(
        selectedClipID: String? = nil,
        searchQuery: String = "",
        isSearchPresented: Bool = false,
        activeFilterID: String = "all",
        themePreview: PopupThemeSelection = .fallback,
        pinnedClips: [ClipPreviewSummary] = [],
        recentClips: [ClipPreviewSummary] = [],
        status: PopupStatusSummary,
        activeOverlay: PopupOverlayState? = nil
    ) {
        self.selectedClipID = selectedClipID
        self.searchQuery = searchQuery
        self.isSearchPresented = isSearchPresented
        self.activeFilterID = activeFilterID
        self.themePreview = themePreview
        self.pinnedClips = pinnedClips
        self.recentClips = recentClips
        self.status = status
        self.activeOverlay = activeOverlay
    }
}

struct MenuBarRetentionOption: Identifiable, Hashable {
    let id: String
    var label: String
    var isSelected: Bool

    init(
        id: String,
        label: String,
        isSelected: Bool = false
    ) {
        self.id = id
        self.label = label
        self.isSelected = isSelected
    }
}

enum MenuBarCommandRole: String, Hashable {
    case standard
    case secondary
    case destructive
}

struct MenuBarCommandRow: Identifiable, Hashable {
    let id: String
    var title: String
    var subtitle: String?
    var symbolName: String?
    var shortcutLabel: String?
    var accessoryText: String?
    var role: MenuBarCommandRole

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        symbolName: String? = nil,
        shortcutLabel: String? = nil,
        accessoryText: String? = nil,
        role: MenuBarCommandRole = .standard
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.shortcutLabel = shortcutLabel
        self.accessoryText = accessoryText
        self.role = role
    }
}

/// The popup panel's geometry and chrome inputs, kept apart from the popup's
/// content so a content-only change does not re-present the panel.
struct SBPopupWindowKey: Hashable {
    var isPresented: Bool
    var isSuppressed: Bool
    var revealsProtectedContent: Bool
    var isPinnedCollapsed: Bool
    var reservesOverlayHeadroom: Bool
    var usesGlassShellMargin: Bool
}

struct MenuBarSummaryState: Hashable {
    var itemCount: Int
    var itemCountLabel: String
    var statusLabel: String
    var quickRetentionSelectionID: String
    var quickRetentionOptions: [MenuBarRetentionOption]
    var commands: [MenuBarCommandRow]
    var highlightedCommandID: String?

    var badgeText: String {
        if itemCount > 999 {
            return "999+"
        }

        return String(itemCount)
    }

    init(
        itemCount: Int,
        itemCountLabel: String = "items",
        statusLabel: String,
        quickRetentionSelectionID: String,
        quickRetentionOptions: [MenuBarRetentionOption],
        commands: [MenuBarCommandRow],
        highlightedCommandID: String? = nil
    ) {
        self.itemCount = itemCount
        self.itemCountLabel = itemCountLabel
        self.statusLabel = statusLabel
        self.quickRetentionSelectionID = quickRetentionSelectionID
        self.quickRetentionOptions = quickRetentionOptions
        self.commands = commands
        self.highlightedCommandID = highlightedCommandID
    }
}
