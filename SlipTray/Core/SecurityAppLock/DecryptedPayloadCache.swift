import Foundation

final class DecryptedPayloadCache: DecryptedPayloadCaching {
    private var payloadsByItemID: [String: ProtectedClipPayload]
    private var cachedDatesByItemID: [String: Date]
    private var draftsByItemID: [String: String]
    private var activeEditorItemID: String?

    init(payloads: [ProtectedClipPayload] = []) {
        self.payloadsByItemID = Dictionary(uniqueKeysWithValues: payloads.map { ($0.itemID, $0) })
        self.cachedDatesByItemID = Dictionary(uniqueKeysWithValues: payloads.map { ($0.itemID, $0.updatedAt) })
        self.draftsByItemID = Dictionary(uniqueKeysWithValues: payloads.map { ($0.itemID, $0.noteText ?? "") })
    }

    var cachedPayloads: [ProtectedClipPayload] {
        payloadsByItemID.values.sorted { $0.updatedAt > $1.updatedAt }
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

    func cachedPayload(for itemID: String) -> ProtectedClipPayload? {
        payloadsByItemID[itemID]
    }

    @discardableResult
    func cachePayload(_ payload: ProtectedClipPayload, cachedAt: Date) -> ProtectedClipPayload {
        payloadsByItemID[payload.itemID] = payload
        cachedDatesByItemID[payload.itemID] = cachedAt
        if activeEditorItemID != payload.itemID || draftsByItemID[payload.itemID] == nil {
            draftsByItemID[payload.itemID] = payload.noteText ?? ""
        }
        return payload
    }

    @discardableResult
    func removeCachedPayload(for itemID: String) -> ProtectedClipPayload? {
        cachedDatesByItemID.removeValue(forKey: itemID)
        draftsByItemID.removeValue(forKey: itemID)
        if activeEditorItemID == itemID {
            activeEditorItemID = nil
        }
        return payloadsByItemID.removeValue(forKey: itemID)
    }

    @discardableResult
    func clearAllCachedPayloads() -> Int {
        let removedCount = payloadsByItemID.count
        payloadsByItemID.removeAll()
        cachedDatesByItemID.removeAll()
        return removedCount
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

    func replaceDraft(for itemID: String, with draftText: String) {
        draftsByItemID[itemID] = draftText
    }

    func removeItems(ids: [String]) {
        for itemID in ids {
            _ = removeCachedPayload(for: itemID)
        }
    }

    func clearAll() {
        _ = clearAllCachedPayloads()
        draftsByItemID.removeAll()
        activeEditorItemID = nil
    }
}

