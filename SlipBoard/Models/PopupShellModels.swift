import Foundation

enum PopupShellPreset: String, CaseIterable, Sendable {
    case compactDemo
    case emptySearchResult
    case noteEditing
}

enum PopupRailID: String, CaseIterable, Sendable {
    case pinned
    case recent
}

enum PopupMenuItemRole: String, Sendable {
    case standard
    case primary
    case destructive
}

enum PopupContextMenuItemID: String, CaseIterable, Sendable {
    case paste
    case pasteTransforms
    case pin
    case unpin
    case addNote
    case editNote
    case deletePlaceholder
}

enum PasteTransformOptionID: String, CaseIterable, Sendable {
    case pasteAsPlainText
    case cleanRichText
    case preserveCodeFormatting
    case trimWhitespace
}

struct PopupSearchFieldState: Equatable, Sendable {
    let query: String
    let placeholder: String
    let isActive: Bool
}

struct PopupFilterPillState: Equatable, Identifiable, Sendable {
    let id: ClipboardFilter
    let title: String
    let countLabel: String?
    let isSelected: Bool
}

struct PopupCardSnapshot: Equatable, Identifiable, Sendable {
    let itemID: ClipboardItemID
    let sourceLabel: String
    let typeLabel: String
    let isPinned: Bool
    let noteSummary: String?
    let preview: ClipboardPreview
    let captureTimeLabel: String
    let pasteLabel: String
    let isSelected: Bool
    let isEditingNote: Bool

    var id: ClipboardItemID {
        itemID
    }
}

struct PopupRailSnapshot: Equatable, Identifiable, Sendable {
    let id: PopupRailID
    let title: String
    let items: [PopupCardSnapshot]
    let emptyMessage: String?
}

struct ClipboardContextMenuItem: Equatable, Identifiable, Sendable {
    let id: PopupContextMenuItemID
    let title: String
    let symbolName: String?
    let role: PopupMenuItemRole
    let isEnabled: Bool
}

struct ClipboardContextMenuSnapshot: Equatable, Sendable {
    let itemID: ClipboardItemID
    let items: [ClipboardContextMenuItem]
}

struct PasteTransformOptionState: Equatable, Identifiable, Sendable {
    let id: PasteTransformOptionID
    let title: String
    let detail: String
    let isSelected: Bool
}

struct PasteTransformMenuSnapshot: Equatable, Sendable {
    let itemID: ClipboardItemID
    let previewText: String
    let options: [PasteTransformOptionState]
    let primaryActionLabel: String
}

struct PopupStatusBarSnapshot: Equatable, Sendable {
    let availabilityLabel: String
    let filterSummary: String
    let captureSummary: String
    let countSummary: String
    let keyboardHint: String
}

struct PopupPanelSnapshot: Equatable, Sendable {
    let title: String
    let searchField: PopupSearchFieldState
    let filterPills: [PopupFilterPillState]
    let pinnedRail: PopupRailSnapshot?
    let recentRail: PopupRailSnapshot
    let activeContextMenu: ClipboardContextMenuSnapshot?
    let activePasteMenu: PasteTransformMenuSnapshot?
    let statusBar: PopupStatusBarSnapshot
}
