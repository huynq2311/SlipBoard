protocol PopupShellRouting: ClipboardSessionRouting {
    func openContextMenu(for itemID: ClipboardItemID)
    func dismissContextMenu()
    func selectPasteTransformOption(_ optionID: PasteTransformOptionID, for itemID: ClipboardItemID)
    func beginInlineNoteEdit(for itemID: ClipboardItemID)
    func cancelInlineNoteEdit(for itemID: ClipboardItemID)
}
