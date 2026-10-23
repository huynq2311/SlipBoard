import Foundation

final class UnlockedNoteSessionCache {
    private var payloadsByItemID: [String: ProtectedNotePayload]
    private var draftsByItemID: [String: String]
    private var activeEditorItemID: String?

    init(payloads: [ProtectedNotePayload] = []) {
        self.payloadsByItemID = Dictionary(uniqueKeysWithValues: payloads.map { ($0.itemID, $0) })
        self.draftsByItemID = Dictionary(uniqueKeysWithValues: payloads.map { ($0.itemID, $0.noteText) })
    }

    var activeEditor: ClipNoteEditorState? {
        guard let activeEditorItemID else {
            return nil
        }

        let persistedText = payloadsByItemID[activeEditorItemID]?.noteText
        let draftText = draftsByItemID[activeEditorItemID] ?? persistedText ?? ""

        return ClipNoteEditorState(
            clipID: activeEditorItemID,
            isPresented: true,
            draftText: draftText,
            persistedText: persistedText,
            isEditable: true
        )
    }

    func protectedNotePayload(for itemID: String) -> ProtectedNotePayload? {
        payloadsByItemID[itemID]
    }

    @discardableResult
    func saveProtectedNote(_ payload: ProtectedNotePayload) -> ProtectedNotePayload {
        payloadsByItemID[payload.itemID] = payload
        draftsByItemID[payload.itemID] = payload.noteText
        return payload
    }

    @discardableResult
    func clearProtectedNote(for itemID: String, clearedAt: Date) -> ProtectedNotePayload? {
        let removed = payloadsByItemID.removeValue(forKey: itemID)
        draftsByItemID[itemID] = ""
        if activeEditorItemID == itemID {
            activeEditorItemID = itemID
        }
        guard removed != nil else {
            return nil
        }

        return ProtectedNotePayload(itemID: itemID, noteText: "", updatedAt: clearedAt)
    }

    func noteText(for itemID: String) -> String? {
        if let draftText = draftsByItemID[itemID], draftText.isEmpty == false {
            return draftText
        }

        return payloadsByItemID[itemID]?.noteText
    }

    @discardableResult
    func presentEditor(for itemID: String, isEditable: Bool) -> ClipNoteEditorState {
        activeEditorItemID = itemID

        let persistedText = payloadsByItemID[itemID]?.noteText
        let draftText = draftsByItemID[itemID] ?? persistedText ?? ""
        draftsByItemID[itemID] = draftText

        return ClipNoteEditorState(
            clipID: itemID,
            isPresented: true,
            draftText: draftText,
            persistedText: persistedText,
            isEditable: isEditable
        )
    }

    @discardableResult
    func updateActiveDraft(_ draftText: String) -> ClipNoteEditorState? {
        guard let activeEditorItemID else {
            return nil
        }

        draftsByItemID[activeEditorItemID] = draftText
        return activeEditor
    }

    func dismissEditor() {
        activeEditorItemID = nil
    }

    func removeItems(ids: [String]) {
        for itemID in ids {
            payloadsByItemID.removeValue(forKey: itemID)
            draftsByItemID.removeValue(forKey: itemID)
            if activeEditorItemID == itemID {
                activeEditorItemID = nil
            }
        }
    }

    func clearAll() {
        payloadsByItemID.removeAll()
        draftsByItemID.removeAll()
        activeEditorItemID = nil
    }
}
