import Foundation

struct PopupShellLocalState {
    var activeContextMenuItemID: ClipboardItemID?
    var editingNoteItemID: ClipboardItemID?
    var selectedTransformOptions: [ClipboardItemID: PasteTransformOptionID] = [:]
}

struct PopupShellAdapter {
    let initialPreset: PopupShellPreset
    private let sessionProvider: SlipBoardSessionProviding?

    init(
        initialPreset: PopupShellPreset = .compactDemo,
        sessionProvider: SlipBoardSessionProviding? = nil
    ) {
        self.initialPreset = initialPreset
        self.sessionProvider = sessionProvider
    }

    func initialPopupPanelSnapshot() -> PopupPanelSnapshot {
        guard let sessionProvider else {
            return fixturePopupPanelSnapshot(named: initialPreset)
        }

        return adaptedSnapshot(
            from: sessionProvider.initialSession(),
            fallbackPreset: initialPreset
        )
    }

    func fixturePopupPanelSnapshot(named preset: PopupShellPreset) -> PopupPanelSnapshot {
        PopupShellFixtures.fixture(named: preset).snapshot
    }

    func adaptedSnapshot(
        from session: SlipBoardAppSession,
        localState: PopupShellLocalState = PopupShellLocalState(),
        fallbackPreset: PopupShellPreset? = nil
    ) -> PopupPanelSnapshot {
        let preset = fallbackPreset ?? PopupShellProjection.suggestedPreset(
            for: session,
            localState: localState
        )
        let baseSnapshot = fixturePopupPanelSnapshot(named: preset)

        return PopupShellProjection.materializeSnapshot(
            baseSnapshot: baseSnapshot,
            session: session,
            localState: localState
        )
    }

    func makeReducer() -> PopupSessionReducer {
        let session = sessionProvider?.initialSession() ?? PopupShellProjection.session(for: initialPreset)
        return PopupSessionReducer(
            session: session,
            adapter: self,
            fallbackPreset: initialPreset
        )
    }

    func makeReducer(
        from session: SlipBoardAppSession,
        fallbackPreset: PopupShellPreset? = nil
    ) -> PopupSessionReducer {
        PopupSessionReducer(
            session: session,
            adapter: self,
            fallbackPreset: fallbackPreset ?? initialPreset
        )
    }
}

enum PopupShellProjection {
    static func suggestedPreset(
        for session: SlipBoardAppSession,
        localState: PopupShellLocalState
    ) -> PopupShellPreset {
        if localState.editingNoteItemID != nil || session.popupChrome.pasteMenuItemID != nil {
            return .noteEditing
        }

        if !session.popupChrome.searchQuery.isEmpty && session.clipboard.filteredCount == 0 {
            return .emptySearchResult
        }

        return .compactDemo
    }

    static func sessionPreset(for preset: PopupShellPreset) -> SlipBoardSessionPreset {
        switch preset {
        case .compactDemo, .emptySearchResult:
            return .popupDemo
        case .noteEditing:
            return .fullDemo
        }
    }

    static func session(for preset: PopupShellPreset) -> SlipBoardAppSession {
        switch preset {
        case .compactDemo:
            return SlipBoardSessionFixtures.session(named: .popupDemo)
        case .emptySearchResult:
            let session = SlipBoardSessionFixtures.session(named: .popupDemo)
            return SlipBoardAppSession(
                activeSurface: .popup,
                theme: session.theme,
                clipboard: session.clipboard,
                popupChrome: PopupChromeState(
                    searchQuery: "archive",
                    activeFilter: .code,
                    selectedItemID: nil,
                    pasteMenuItemID: nil
                ),
                settings: session.settings
            )
        case .noteEditing:
            let session = SlipBoardSessionFixtures.session(named: .fullDemo)
            let selectedItemID = session.clipboard.pinnedItems.first?.id
            return SlipBoardAppSession(
                activeSurface: .popup,
                theme: session.theme,
                clipboard: session.clipboard,
                popupChrome: PopupChromeState(
                    searchQuery: session.popupChrome.searchQuery,
                    activeFilter: session.popupChrome.activeFilter,
                    selectedItemID: selectedItemID,
                    pasteMenuItemID: selectedItemID
                ),
                settings: session.settings
            )
        }
    }

    static func materializeSnapshot(
        baseSnapshot: PopupPanelSnapshot,
        session: SlipBoardAppSession,
        localState: PopupShellLocalState
    ) -> PopupPanelSnapshot {
        let itemsByID = itemLookup(in: session)
        let selectedItemID = visibleItemID(
            session.popupChrome.selectedItemID,
            itemsByID: itemsByID
        )
        let activeContextMenuItemID = visibleItemID(
            localState.activeContextMenuItemID,
            itemsByID: itemsByID
        )
        let activePasteMenuItemID = visibleItemID(
            session.popupChrome.pasteMenuItemID,
            itemsByID: itemsByID
        )
        let editingNoteItemID = visibleItemID(
            localState.editingNoteItemID,
            itemsByID: itemsByID
        )

        return PopupPanelSnapshot(
            title: baseSnapshot.title,
            searchField: PopupSearchFieldState(
                query: session.popupChrome.searchQuery,
                placeholder: baseSnapshot.searchField.placeholder,
                isActive: session.activeSurface == .popup || baseSnapshot.searchField.isActive
            ),
            filterPills: filterPills(
                availableFilters: session.clipboard.availableFilters,
                allItems: orderedItems(in: session),
                selectedFilter: session.popupChrome.activeFilter
            ),
            pinnedRail: pinnedRail(
                from: session.clipboard.pinnedItems,
                baseSnapshot: baseSnapshot,
                selectedItemID: selectedItemID,
                editingNoteItemID: editingNoteItemID
            ),
            recentRail: recentRail(
                from: session.clipboard.recentItems,
                baseSnapshot: baseSnapshot,
                session: session,
                selectedItemID: selectedItemID,
                editingNoteItemID: editingNoteItemID
            ),
            activeContextMenu: contextMenuSnapshot(
                itemID: activeContextMenuItemID,
                itemsByID: itemsByID
            ),
            activePasteMenu: pasteTransformSnapshot(
                itemID: activePasteMenuItemID,
                itemsByID: itemsByID,
                localState: localState,
                fallbackPrimaryActionLabel: baseSnapshot.activePasteMenu?.primaryActionLabel ?? "Paste and Close"
            ),
            statusBar: statusBarSnapshot(
                baseSnapshot: baseSnapshot,
                session: session
            )
        )
    }

    static func defaultTransformOption(for item: ClipboardItem) -> PasteTransformOptionID {
        switch item.kind {
        case .code:
            return .preserveCodeFormatting
        case .text:
            return .cleanRichText
        case .image, .file, .url, .color:
            return .pasteAsPlainText
        }
    }

    private static func filterPills(
        availableFilters: [ClipboardFilter],
        allItems: [ClipboardItem],
        selectedFilter: ClipboardFilter
    ) -> [PopupFilterPillState] {
        let filters = availableFilters.isEmpty ? ClipboardFilter.allCases : availableFilters

        return filters.map { filter in
            let count = filter == .all
                ? allItems.count
                : allItems.filter { filter.matches($0.kind) }.count

            return PopupFilterPillState(
                id: filter,
                title: title(for: filter),
                countLabel: countLabel(for: filter, count: count),
                isSelected: filter == selectedFilter
            )
        }
    }

    private static func countLabel(for filter: ClipboardFilter, count: Int) -> String? {
        if filter == .all {
            return "\(count)"
        }

        return count == 0 ? nil : "\(count)"
    }

    private static func pinnedRail(
        from items: [ClipboardItem],
        baseSnapshot: PopupPanelSnapshot,
        selectedItemID: ClipboardItemID?,
        editingNoteItemID: ClipboardItemID?
    ) -> PopupRailSnapshot? {
        guard !items.isEmpty else {
            return nil
        }

        return PopupRailSnapshot(
            id: .pinned,
            title: baseSnapshot.pinnedRail?.title ?? "Pinned",
            items: cardSnapshots(
                from: items,
                selectedItemID: selectedItemID,
                editingNoteItemID: editingNoteItemID
            ),
            emptyMessage: nil
        )
    }

    private static func recentRail(
        from items: [ClipboardItem],
        baseSnapshot: PopupPanelSnapshot,
        session: SlipBoardAppSession,
        selectedItemID: ClipboardItemID?,
        editingNoteItemID: ClipboardItemID?
    ) -> PopupRailSnapshot {
        PopupRailSnapshot(
            id: .recent,
            title: baseSnapshot.recentRail.title,
            items: cardSnapshots(
                from: items,
                selectedItemID: selectedItemID,
                editingNoteItemID: editingNoteItemID
            ),
            emptyMessage: items.isEmpty ? emptyRecentMessage(for: session) : nil
        )
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
                noteSummary: normalizedNote(item.note),
                preview: item.preview,
                captureTimeLabel: relativeCaptureLabel(for: item.capturedAt),
                pasteLabel: item.pasteAction.label,
                isSelected: item.id == selectedItemID,
                isEditingNote: item.id == editingNoteItemID
            )
        }
    }

    private static func contextMenuSnapshot(
        itemID: ClipboardItemID?,
        itemsByID: [ClipboardItemID: ClipboardItem]
    ) -> ClipboardContextMenuSnapshot? {
        guard let itemID, let item = itemsByID[itemID] else {
            return nil
        }

        let hasNote = normalizedNote(item.note) != nil

        return ClipboardContextMenuSnapshot(
            itemID: itemID,
            items: [
                ClipboardContextMenuItem(
                    id: .paste,
                    title: item.pasteAction.label,
                    symbolName: "arrowshape.turn.up.forward",
                    role: .primary,
                    isEnabled: item.pasteAction.isAvailable
                ),
                ClipboardContextMenuItem(
                    id: .pasteTransforms,
                    title: "Paste with Transform",
                    symbolName: "wand.and.stars",
                    role: .standard,
                    isEnabled: true
                ),
                ClipboardContextMenuItem(
                    id: item.isPinned ? .unpin : .pin,
                    title: item.isPinned ? "Unpin" : "Pin",
                    symbolName: item.isPinned ? "pin.slash" : "pin",
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
        itemID: ClipboardItemID?,
        itemsByID: [ClipboardItemID: ClipboardItem],
        localState: PopupShellLocalState,
        fallbackPrimaryActionLabel: String
    ) -> PasteTransformMenuSnapshot? {
        guard let itemID, let item = itemsByID[itemID] else {
            return nil
        }

        let selectedOptionID = localState.selectedTransformOptions[itemID] ?? defaultTransformOption(for: item)

        return PasteTransformMenuSnapshot(
            itemID: itemID,
            previewText: previewText(for: item.preview),
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
            primaryActionLabel: item.pasteAction.isAvailable ? fallbackPrimaryActionLabel : item.pasteAction.label
        )
    }

    private static func statusBarSnapshot(
        baseSnapshot: PopupPanelSnapshot,
        session: SlipBoardAppSession
    ) -> PopupStatusBarSnapshot {
        let query = session.popupChrome.searchQuery
        let filter = title(for: session.popupChrome.activeFilter)

        return PopupStatusBarSnapshot(
            availabilityLabel: baseSnapshot.statusBar.availabilityLabel,
            filterSummary: query.isEmpty ? "Filter: \(filter)" : "Filter: \(filter) | Search: \(query)",
            captureSummary: captureSummary(from: session.clipboard.lastCapturedAt),
            countSummary: "\(session.clipboard.filteredCount) of \(session.clipboard.totalCount) items visible",
            keyboardHint: baseSnapshot.statusBar.keyboardHint
        )
    }

    private static func emptyRecentMessage(for session: SlipBoardAppSession) -> String {
        let query = session.popupChrome.searchQuery
        let filter = session.popupChrome.activeFilter
        let filterLabel = title(for: filter).lowercased()

        if session.clipboard.totalCount == 0 {
            return "Nothing has been captured yet."
        }

        if !query.isEmpty && filter != .all {
            return "No \(filterLabel) clips match \"\(query)\"."
        }

        if !query.isEmpty {
            return "No clips match \"\(query)\"."
        }

        if filter != .all {
            return "No \(filterLabel) clips are available."
        }

        return "No recent items are available."
    }

    private static func captureSummary(from date: Date?) -> String {
        guard let date else {
            return "No captures yet"
        }

        return "Latest capture \(relativeCaptureLabel(for: date))"
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

    private static func previewText(for preview: ClipboardPreview) -> String {
        switch preview {
        case let .text(text):
            return text
        case let .code(language, snippet):
            return [language, snippet].compactMap { $0 }.joined(separator: " ")
        case let .image(description):
            return description
        case let .file(name, detail):
            return "\(name) \(detail)"
        case let .url(url):
            return url
        case let .color(hex):
            return hex
        }
    }

    private static func normalizedNote(_ note: String?) -> String? {
        guard let note else {
            return nil
        }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func orderedItems(in session: SlipBoardAppSession) -> [ClipboardItem] {
        uniqueItems(from: session.clipboard.pinnedItems + session.clipboard.recentItems)
    }

    private static func itemLookup(in session: SlipBoardAppSession) -> [ClipboardItemID: ClipboardItem] {
        Dictionary(uniqueKeysWithValues: orderedItems(in: session).map { ($0.id, $0) })
    }

    private static func uniqueItems(from items: [ClipboardItem]) -> [ClipboardItem] {
        var seen: Set<ClipboardItemID> = []
        return items.filter { seen.insert($0.id).inserted }
    }

    private static func visibleItemID(
        _ candidate: ClipboardItemID?,
        itemsByID: [ClipboardItemID: ClipboardItem]
    ) -> ClipboardItemID? {
        guard let candidate, itemsByID[candidate] != nil else {
            return nil
        }

        return candidate
    }
}
