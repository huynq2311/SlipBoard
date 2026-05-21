import Foundation

struct PopupShellFixture: Equatable, Sendable {
    let preset: PopupShellPreset
    let snapshot: PopupPanelSnapshot
}

enum PopupShellFixtures {
    static let compactDemo = PopupShellFixture(
        preset: .compactDemo,
        snapshot: panelSnapshot(
            title: "Clipboard History",
            session: SlipBoardSessionFixtures.session(named: .popupDemo),
            searchField: PopupSearchFieldState(
                query: "",
                placeholder: "Search clipboard history",
                isActive: true
            ),
            activeContextMenu: contextMenuSnapshot(
                itemID: ClipboardItemID(rawValue: "item-bridge-url"),
                isPinned: false,
                hasNote: true,
                pasteActionAvailable: true
            ),
            activePasteMenu: nil,
            editingNoteItemID: nil,
            emptyRecentMessage: "Nothing has been captured yet."
        )
    )

    static let emptySearchResult = PopupShellFixture(
        preset: .emptySearchResult,
        snapshot: panelSnapshot(
            title: "Clipboard History",
            session: SlipBoardSessionFixtures.session(named: .popupDemo),
            searchField: PopupSearchFieldState(
                query: "archive",
                placeholder: "Search clipboard history",
                isActive: true
            ),
            activeContextMenu: nil,
            activePasteMenu: nil,
            editingNoteItemID: nil,
            pinnedOverride: [],
            recentOverride: [],
            activeFilter: .code,
            emptyRecentMessage: "No code clips match \"archive\"."
        )
    )

    static let noteEditing = PopupShellFixture(
        preset: .noteEditing,
        snapshot: panelSnapshot(
            title: "Clipboard History",
            session: SlipBoardSessionFixtures.session(named: .fullDemo),
            searchField: PopupSearchFieldState(
                query: "bridge",
                placeholder: "Search clipboard history",
                isActive: true
            ),
            activeContextMenu: nil,
            activePasteMenu: pasteTransformSnapshot(
                itemID: ClipboardItemID(rawValue: "item-bridge-copy"),
                previewText: "Paste to iPhone only when the user confirms.",
                selectedOptionID: .cleanRichText
            ),
            editingNoteItemID: ClipboardItemID(rawValue: "item-bridge-copy"),
            emptyRecentMessage: "No recent items match the current search."
        )
    )

    static let all: [PopupShellFixture] = [
        compactDemo,
        emptySearchResult,
        noteEditing
    ]

    static func fixture(named preset: PopupShellPreset) -> PopupShellFixture {
        switch preset {
        case .compactDemo:
            return compactDemo
        case .emptySearchResult:
            return emptySearchResult
        case .noteEditing:
            return noteEditing
        }
    }

    private static func panelSnapshot(
        title: String,
        session: SlipBoardAppSession,
        searchField: PopupSearchFieldState,
        activeContextMenu: ClipboardContextMenuSnapshot?,
        activePasteMenu: PasteTransformMenuSnapshot?,
        editingNoteItemID: ClipboardItemID?,
        pinnedOverride: [ClipboardItem]? = nil,
        recentOverride: [ClipboardItem]? = nil,
        activeFilter: ClipboardFilter? = nil,
        emptyRecentMessage: String
    ) -> PopupPanelSnapshot {
        let pinnedItems = pinnedOverride ?? session.clipboard.pinnedItems
        let recentItems = recentOverride ?? session.clipboard.recentItems
        let selectedItemID = activePasteMenu?.itemID ?? activeContextMenu?.itemID ?? session.popupChrome.selectedItemID
        let filter = activeFilter ?? session.popupChrome.activeFilter

        return PopupPanelSnapshot(
            title: title,
            searchField: searchField,
            filterPills: filterPills(
                availableFilters: session.clipboard.availableFilters,
                allItems: session.clipboard.pinnedItems + session.clipboard.recentItems,
                selectedFilter: filter
            ),
            pinnedRail: pinnedItems.isEmpty ? nil : PopupRailSnapshot(
                id: .pinned,
                title: "Pinned",
                items: cardSnapshots(
                    from: pinnedItems,
                    selectedItemID: selectedItemID,
                    editingNoteItemID: editingNoteItemID
                ),
                emptyMessage: nil
            ),
            recentRail: PopupRailSnapshot(
                id: .recent,
                title: "Recent",
                items: cardSnapshots(
                    from: recentItems,
                    selectedItemID: selectedItemID,
                    editingNoteItemID: editingNoteItemID
                ),
                emptyMessage: recentItems.isEmpty ? emptyRecentMessage : nil
            ),
            activeContextMenu: activeContextMenu,
            activePasteMenu: activePasteMenu,
            statusBar: statusBarSnapshot(
                filter: filter,
                filteredCount: pinnedItems.count + recentItems.count,
                totalCount: session.clipboard.totalCount,
                lastCapturedAt: session.clipboard.lastCapturedAt,
                searchQuery: searchField.query
            )
        )
    }

    private static func filterPills(
        availableFilters: [ClipboardFilter],
        allItems: [ClipboardItem],
        selectedFilter: ClipboardFilter
    ) -> [PopupFilterPillState] {
        let filters = availableFilters.isEmpty ? ClipboardFilter.allCases : availableFilters

        return filters.map { filter in
            PopupFilterPillState(
                id: filter,
                title: title(for: filter),
                countLabel: countLabel(for: filter, items: allItems),
                isSelected: filter == selectedFilter
            )
        }
    }

    private static func countLabel(for filter: ClipboardFilter, items: [ClipboardItem]) -> String? {
        if filter == .all {
            return "\(items.count)"
        }

        let count = items.filter { filter.matches($0.kind) }.count
        return count == 0 ? nil : "\(count)"
    }

    private static func cardSnapshots(
        from items: [ClipboardItem],
        selectedItemID: ClipboardItemID?,
        editingNoteItemID: ClipboardItemID?
    ) -> [PopupCardSnapshot] {
        items.map { item in
            PopupCardSnapshot(
                itemID: item.id,
                sourceLabel: item.sourceApp.displayName,
                typeLabel: title(for: ClipboardFilter(kind: item.kind)),
                isPinned: item.isPinned,
                noteSummary: item.note,
                preview: item.preview,
                captureTimeLabel: relativeCaptureLabel(for: item.capturedAt),
                pasteLabel: item.pasteAction.label,
                isSelected: item.id == selectedItemID,
                isEditingNote: item.id == editingNoteItemID
            )
        }
    }

    private static func contextMenuSnapshot(
        itemID: ClipboardItemID,
        isPinned: Bool,
        hasNote: Bool,
        pasteActionAvailable: Bool
    ) -> ClipboardContextMenuSnapshot {
        ClipboardContextMenuSnapshot(
            itemID: itemID,
            items: [
                ClipboardContextMenuItem(
                    id: .paste,
                    title: "Paste",
                    symbolName: "arrowshape.turn.up.forward",
                    role: .primary,
                    isEnabled: pasteActionAvailable
                ),
                ClipboardContextMenuItem(
                    id: .pasteTransforms,
                    title: "Paste with Transform",
                    symbolName: "wand.and.stars",
                    role: .standard,
                    isEnabled: true
                ),
                ClipboardContextMenuItem(
                    id: isPinned ? .unpin : .pin,
                    title: isPinned ? "Unpin" : "Pin",
                    symbolName: isPinned ? "pin.slash" : "pin",
                    role: .standard,
                    isEnabled: true
                ),
                ClipboardContextMenuItem(
                    id: hasNote ? .editNote : .addNote,
                    title: hasNote ? "Edit Note" : "Add Note",
                    symbolName: "note.text",
                    role: .standard,
                    isEnabled: true
                ),
                ClipboardContextMenuItem(
                    id: .deletePlaceholder,
                    title: "Delete from Mock List",
                    symbolName: "trash",
                    role: .destructive,
                    isEnabled: true
                )
            ]
        )
    }

    private static func pasteTransformSnapshot(
        itemID: ClipboardItemID,
        previewText: String,
        selectedOptionID: PasteTransformOptionID
    ) -> PasteTransformMenuSnapshot {
        PasteTransformMenuSnapshot(
            itemID: itemID,
            previewText: previewText,
            options: [
                PasteTransformOptionState(
                    id: .pasteAsPlainText,
                    title: "Paste as Plain Text",
                    detail: "Strip formatting and keep line breaks intact.",
                    isSelected: selectedOptionID == .pasteAsPlainText
                ),
                PasteTransformOptionState(
                    id: .cleanRichText,
                    title: "Clean Rich Text",
                    detail: "Normalize smart quotes, dashes, and list formatting.",
                    isSelected: selectedOptionID == .cleanRichText
                ),
                PasteTransformOptionState(
                    id: .preserveCodeFormatting,
                    title: "Preserve Code Formatting",
                    detail: "Keep indentation and monospaced whitespace for code blocks.",
                    isSelected: selectedOptionID == .preserveCodeFormatting
                ),
                PasteTransformOptionState(
                    id: .trimWhitespace,
                    title: "Trim Surrounding Whitespace",
                    detail: "Remove leading and trailing whitespace before paste.",
                    isSelected: selectedOptionID == .trimWhitespace
                )
            ],
            primaryActionLabel: "Paste and Close"
        )
    }

    private static func statusBarSnapshot(
        filter: ClipboardFilter,
        filteredCount: Int,
        totalCount: Int,
        lastCapturedAt: Date?,
        searchQuery: String
    ) -> PopupStatusBarSnapshot {
        PopupStatusBarSnapshot(
            availabilityLabel: "Local mock data available",
            filterSummary: searchQuery.isEmpty
                ? "Filter: \(title(for: filter))"
                : "Filter: \(title(for: filter)) | Search: \(searchQuery)",
            captureSummary: captureSummary(from: lastCapturedAt),
            countSummary: "\(filteredCount) of \(totalCount) items visible",
            keyboardHint: "Enter pastes and closes. Option+Enter keeps the popup open."
        )
    }

    private static func captureSummary(from date: Date?) -> String {
        guard let date else {
            return "No captures yet"
        }

        return "Latest capture \(relativeCaptureLabel(for: date))"
    }

    private static func relativeCaptureLabel(for date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        let minutes = max(1, seconds / 60)

        if minutes < 60 {
            return "\(minutes)m ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }

        let days = hours / 24
        return "\(days)d ago"
    }

    private static func title(for filter: ClipboardFilter) -> String {
        switch filter {
        case .all:
            return "All"
        case .text:
            return "Text"
        case .code:
            return "Code"
        case .image:
            return "Image"
        case .file:
            return "File"
        case .url:
            return "URL"
        case .color:
            return "Color"
        }
    }
}
