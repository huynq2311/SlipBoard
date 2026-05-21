protocol ClipboardFeedRouting {
    func selectItem(id: ClipboardItemID?)
    func changeFilter(to filter: ClipboardFilter)
    func updateSearchQuery(_ query: String)
    func openPasteMenu(for itemID: ClipboardItemID)
    func dismissPasteMenu()
}

protocol ClipboardItemMutating {
    func togglePin(for itemID: ClipboardItemID)
    func updateNote(for itemID: ClipboardItemID, note: String?)
}

typealias ClipboardSessionRouting = ClipboardFeedRouting & ClipboardItemMutating
