import Foundation

final class PopupSessionReducer: ClipboardSessionRouting {
    private var seed: PopupSessionSeed
    private(set) var session: SlipBoardAppSession

    init(session: SlipBoardAppSession) {
        let seed = PopupSessionSeed(session: session)
        self.seed = seed
        self.session = Self.materialize(
            from: session,
            seed: seed,
            searchQuery: session.popupChrome.searchQuery,
            activeFilter: session.popupChrome.activeFilter,
            selectedItemID: session.popupChrome.selectedItemID,
            pasteMenuItemID: session.popupChrome.pasteMenuItemID
        )
    }

    func selectItem(id: ClipboardItemID?) {
        session = applyPopupInteraction(
            searchQuery: session.popupChrome.searchQuery,
            activeFilter: session.popupChrome.activeFilter,
            selectedItemID: seed.contains(id) ? id : nil,
            pasteMenuItemID: session.popupChrome.pasteMenuItemID
        )
    }

    func changeFilter(to filter: ClipboardFilter) {
        session = applyPopupInteraction(
            searchQuery: session.popupChrome.searchQuery,
            activeFilter: filter,
            selectedItemID: session.popupChrome.selectedItemID,
            pasteMenuItemID: session.popupChrome.pasteMenuItemID
        )
    }

    func updateSearchQuery(_ query: String) {
        session = applyPopupInteraction(
            searchQuery: query,
            activeFilter: session.popupChrome.activeFilter,
            selectedItemID: session.popupChrome.selectedItemID,
            pasteMenuItemID: session.popupChrome.pasteMenuItemID
        )
    }

    func openPasteMenu(for itemID: ClipboardItemID) {
        session = applyPopupInteraction(
            searchQuery: session.popupChrome.searchQuery,
            activeFilter: session.popupChrome.activeFilter,
            selectedItemID: session.popupChrome.selectedItemID,
            pasteMenuItemID: seed.contains(itemID) ? itemID : nil
        )
    }

    func dismissPasteMenu() {
        session = applyPopupInteraction(
            searchQuery: session.popupChrome.searchQuery,
            activeFilter: session.popupChrome.activeFilter,
            selectedItemID: session.popupChrome.selectedItemID,
            pasteMenuItemID: nil
        )
    }

    func togglePin(for itemID: ClipboardItemID) {
        seed.togglePin(for: itemID)
        session = applyPopupInteraction(
            searchQuery: session.popupChrome.searchQuery,
            activeFilter: session.popupChrome.activeFilter,
            selectedItemID: session.popupChrome.selectedItemID,
            pasteMenuItemID: session.popupChrome.pasteMenuItemID
        )
    }

    func updateNote(for itemID: ClipboardItemID, note: String?) {
        seed.updateNote(for: itemID, note: note)
        session = applyPopupInteraction(
            searchQuery: session.popupChrome.searchQuery,
            activeFilter: session.popupChrome.activeFilter,
            selectedItemID: session.popupChrome.selectedItemID,
            pasteMenuItemID: session.popupChrome.pasteMenuItemID
        )
    }

    private func applyPopupInteraction(
        searchQuery: String,
        activeFilter: ClipboardFilter,
        selectedItemID: ClipboardItemID?,
        pasteMenuItemID: ClipboardItemID?
    ) -> SlipBoardAppSession {
        var nextSession = Self.materialize(
            from: session,
            seed: seed,
            searchQuery: searchQuery,
            activeFilter: activeFilter,
            selectedItemID: selectedItemID,
            pasteMenuItemID: pasteMenuItemID
        )
        nextSession = SlipBoardAppSession(
            activeSurface: .popup,
            theme: nextSession.theme,
            clipboard: nextSession.clipboard,
            popupChrome: nextSession.popupChrome,
            settings: nextSession.settings
        )
        return nextSession
    }

    private static func materialize(
        from session: SlipBoardAppSession,
        seed: PopupSessionSeed,
        searchQuery: String,
        activeFilter: ClipboardFilter,
        selectedItemID: ClipboardItemID?,
        pasteMenuItemID: ClipboardItemID?
    ) -> SlipBoardAppSession {
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let pinnedItems = seed.pinnedItems(matching: normalizedQuery, filter: activeFilter)
        let recentItems = seed.recentItems(matching: normalizedQuery, filter: activeFilter)
        let visibleIDs = Set(pinnedItems.map(\.id) + recentItems.map(\.id))

        let popupChrome = PopupChromeState(
            searchQuery: normalizedQuery,
            activeFilter: activeFilter,
            selectedItemID: visibleID(from: selectedItemID, in: visibleIDs),
            pasteMenuItemID: visibleID(from: pasteMenuItemID, in: visibleIDs)
        )

        let clipboard = ClipboardFeedSnapshot(
            totalCount: seed.totalCount,
            filteredCount: visibleIDs.count,
            pinnedItems: pinnedItems,
            recentItems: recentItems,
            availableFilters: seed.availableFilters,
            lastCapturedAt: seed.lastCapturedAt
        )

        return SlipBoardAppSession(
            activeSurface: session.activeSurface,
            theme: session.theme,
            clipboard: clipboard,
            popupChrome: popupChrome,
            settings: session.settings
        )
    }

    private static func visibleID(
        from candidate: ClipboardItemID?,
        in visibleIDs: Set<ClipboardItemID>
    ) -> ClipboardItemID? {
        guard let candidate, visibleIDs.contains(candidate) else {
            return nil
        }
        return candidate
    }
}

private struct PopupSessionSeed {
    let availableFilters: [ClipboardFilter]
    let lastCapturedAt: Date?
    private var itemsByID: [ClipboardItemID: ClipboardItem]
    private var pinnedOrder: [ClipboardItemID]
    private var recentOrder: [ClipboardItemID]

    init(session: SlipBoardAppSession) {
        availableFilters = session.clipboard.availableFilters.isEmpty ? ClipboardFilter.allCases : session.clipboard.availableFilters
        let pinnedOrder = Self.uniqueIDs(from: session.clipboard.pinnedItems.map(\.id))
        let pinnedSet = Set(pinnedOrder)
        let recentOrder = Self.uniqueIDs(from: session.clipboard.recentItems.map(\.id)).filter { !pinnedSet.contains($0) }

        var itemsByID: [ClipboardItemID: ClipboardItem] = [:]
        for item in session.clipboard.recentItems {
            itemsByID[item.id] = Self.copy(item, isPinned: false, note: item.note)
        }
        for item in session.clipboard.pinnedItems {
            itemsByID[item.id] = Self.copy(item, isPinned: true, note: item.note)
        }

        self.itemsByID = itemsByID
        self.pinnedOrder = pinnedOrder
        self.recentOrder = recentOrder
        self.lastCapturedAt = session.clipboard.lastCapturedAt ?? itemsByID.values.map(\.capturedAt).max()
    }

    var totalCount: Int {
        itemsByID.count
    }

    func contains(_ id: ClipboardItemID?) -> Bool {
        guard let id else {
            return false
        }
        return itemsByID[id] != nil
    }

    func pinnedItems(matching query: String, filter: ClipboardFilter) -> [ClipboardItem] {
        items(for: pinnedOrder, matching: query, filter: filter)
    }

    func recentItems(matching query: String, filter: ClipboardFilter) -> [ClipboardItem] {
        items(for: recentOrder, matching: query, filter: filter)
    }

    mutating func togglePin(for itemID: ClipboardItemID) {
        guard let item = itemsByID[itemID] else {
            return
        }

        let toggled = Self.copy(item, isPinned: !item.isPinned, note: item.note)
        itemsByID[itemID] = toggled

        if toggled.isPinned {
            recentOrder.removeAll { $0 == itemID }
            pinnedOrder.append(itemID)
            pinnedOrder = sort(order: pinnedOrder)
        } else {
            pinnedOrder.removeAll { $0 == itemID }
            recentOrder.append(itemID)
            recentOrder = sort(order: recentOrder)
        }
    }

    mutating func updateNote(for itemID: ClipboardItemID, note: String?) {
        guard let item = itemsByID[itemID] else {
            return
        }

        let normalizedNote = Self.normalize(note: note)
        itemsByID[itemID] = Self.copy(item, isPinned: item.isPinned, note: normalizedNote)
    }

    private func items(for order: [ClipboardItemID], matching query: String, filter: ClipboardFilter) -> [ClipboardItem] {
        order.compactMap { id in
            guard let item = itemsByID[id], Self.matches(item, query: query, filter: filter) else {
                return nil
            }
            return item
        }
    }

    private func sort(order: [ClipboardItemID]) -> [ClipboardItemID] {
        order.sorted { lhs, rhs in
            guard let left = itemsByID[lhs], let right = itemsByID[rhs] else {
                return false
            }

            if left.capturedAt == right.capturedAt {
                return left.id.rawValue < right.id.rawValue
            }
            return left.capturedAt > right.capturedAt
        }
    }

    private static func copy(_ item: ClipboardItem, isPinned: Bool, note: String?) -> ClipboardItem {
        ClipboardItem(
            id: item.id,
            kind: item.kind,
            sourceApp: item.sourceApp,
            capturedAt: item.capturedAt,
            isPinned: isPinned,
            note: note,
            preview: item.preview,
            pasteAction: item.pasteAction
        )
    }

    private static func uniqueIDs(from ids: [ClipboardItemID]) -> [ClipboardItemID] {
        var seen: Set<ClipboardItemID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    private static func normalize(note: String?) -> String? {
        guard let note else {
            return nil
        }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func matches(_ item: ClipboardItem, query: String, filter: ClipboardFilter) -> Bool {
        guard filter.matches(item.kind) else {
            return false
        }

        guard !query.isEmpty else {
            return true
        }

        return searchableText(for: item).localizedCaseInsensitiveContains(query)
    }

    private static func searchableText(for item: ClipboardItem) -> String {
        [
            item.sourceApp.displayName,
            item.note ?? "",
            previewText(for: item.preview),
            item.pasteAction.label,
            item.pasteAction.hint ?? ""
        ].joined(separator: "\n")
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
}
