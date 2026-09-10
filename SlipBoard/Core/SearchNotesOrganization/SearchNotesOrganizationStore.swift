import Foundation

final class SearchNotesOrganizationStore: SearchNotesOrganizationStoring {
    private let indexStore: SearchIndexStoring & OrganizationGroupStoring
    private let payloadStore: ProtectedPayloadManaging
    private let decryptedPayloadCache: DecryptedPayloadCache
    private var historyItemsByID: [String: ClipboardHistoryItem]

    init(
        indexStore: (SearchIndexStoring & OrganizationGroupStoring) = SQLiteSearchIndexStore(),
        payloadStore: ProtectedPayloadManaging = EncryptedPayloadStore(),
        decryptedPayloadCache: DecryptedPayloadCache = DecryptedPayloadCache()
    ) {
        self.indexStore = indexStore
        self.payloadStore = payloadStore
        self.decryptedPayloadCache = decryptedPayloadCache
        self.historyItemsByID = [:]
    }

    var snapshot: SearchIndexSnapshot {
        indexStore.snapshot
    }

    var latestGroups: [OrganizationGroupSummary] {
        indexStore.latestGroups
    }

    var activeEditor: ClipNoteEditorState? {
        decryptedPayloadCache.activeEditor
    }

    var latestMigrationState: SecurityMigrationState {
        payloadStore.latestMigrationState
    }

    func document(for itemID: String) -> SearchIndexDocument? {
        indexStore.document(for: itemID)
    }

    func membershipChange(for itemID: String) -> GroupMembershipChange? {
        indexStore.membershipChange(for: itemID)
    }

    @discardableResult
    func replaceDocuments(_ documents: [SearchIndexDocument]) -> SearchIndexSnapshot {
        indexStore.replaceDocuments(documents)
    }

    @discardableResult
    func upsertDocuments(_ documents: [SearchIndexDocument]) -> SearchIndexSnapshot {
        indexStore.upsertDocuments(documents)
    }

    @discardableResult
    func removeDocuments(ids: [String]) -> SearchIndexSnapshot {
        decryptedPayloadCache.removeItems(ids: ids)
        return indexStore.removeDocuments(ids: ids)
    }

    @discardableResult
    func upsertGroups(_ groups: [OrganizationGroupSummary]) -> SearchIndexSnapshot {
        indexStore.upsertGroups(groups)
    }

    @discardableResult
    func removeGroups(ids: [OrganizationGroupID]) -> SearchIndexSnapshot {
        indexStore.removeGroups(ids: ids)
    }

    @discardableResult
    func saveMembershipChanges(_ changes: [GroupMembershipChange]) -> SearchIndexSnapshot {
        indexStore.saveMembershipChanges(changes)
    }

    func search(_ request: SearchQueryRequest) -> SearchQueryResult {
        indexStore.search(request)
    }

    func synchronizeHistoryItems(_ items: [ClipboardHistoryItem]) {
        synchronizeHistoryItems(items, includeProtectedContent: true)
    }

    func synchronizeHistoryItems(_ items: [ClipboardHistoryItem], includeProtectedContent: Bool) {
        historyItemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        let nextIDs = Set(items.map(\.id))
        let staleIDs = snapshot.documents
            .map(\.itemID)
            .filter { nextIDs.contains($0) == false }

        if staleIDs.isEmpty == false {
            for itemID in staleIDs {
                historyItemsByID.removeValue(forKey: itemID)
                _ = payloadStore.removeProtectedPayload(for: itemID)
            }
            decryptedPayloadCache.removeItems(ids: staleIDs)
            _ = indexStore.removeDocuments(ids: staleIDs)
        }

        if includeProtectedContent,
           payloadStore.activeWrappedKey != nil,
           payloadStore.keyMaterialState.hasUnwrappedKeyInMemory
        {
            _ = migrateProtectedPayloadsIfNeeded()
        }

        let documents = items.map { makeDocument(from: $0, includeProtectedContent: includeProtectedContent) }
        _ = indexStore.upsertDocuments(documents)
    }

    func refreshProtectedContentMirrors(includeProtectedContent: Bool) {
        if includeProtectedContent,
           payloadStore.activeWrappedKey != nil,
           payloadStore.keyMaterialState.hasUnwrappedKeyInMemory
        {
            _ = migrateProtectedPayloadsIfNeeded()
        }

        let documents = historyItemsByID.values.map {
            makeDocument(from: $0, includeProtectedContent: includeProtectedContent)
        }
        _ = indexStore.replaceDocuments(documents)
    }

    @discardableResult
    func migrateProtectedPayloadsIfNeeded() -> SecurityMigrationState {
        guard
            payloadStore.activeWrappedKey != nil,
            payloadStore.keyMaterialState.hasUnwrappedKeyInMemory
        else {
            return payloadStore.latestMigrationState
        }

        let payloadCandidates = historyItemsByID.values
            .sorted { lhs, rhs in
                if lhs.lastCopiedAt == rhs.lastCopiedAt {
                    return lhs.id < rhs.id
                }
                return lhs.lastCopiedAt < rhs.lastCopiedAt
            }
            .compactMap(makePayloadCandidate(from:))

        guard payloadCandidates.isEmpty == false else {
            return payloadStore.latestMigrationState
        }

        let migrationState = payloadStore.saveProtectedPayloads(payloadCandidates)
        if payloadStore.keyMaterialState.hasUnwrappedKeyInMemory {
            for itemID in payloadCandidates.map(\.itemID) {
                if let payload = payloadStore.protectedPayload(for: itemID) {
                    _ = decryptedPayloadCache.cachePayload(payload, cachedAt: payload.updatedAt)
                }
            }
        }
        return migrationState
    }

    func removeItems(ids: [String]) {
        for itemID in ids {
            historyItemsByID.removeValue(forKey: itemID)
            _ = payloadStore.removeEnvelope(for: itemID)
        }
        decryptedPayloadCache.removeItems(ids: ids)
        _ = indexStore.removeDocuments(ids: ids)
    }

    func protectedNotePayload(for itemID: String) -> ProtectedNotePayload? {
        guard
            let payload = protectedPayload(for: itemID),
            let noteText = payload.noteText,
            noteText.isEmpty == false
        else {
            return nil
        }

        return ProtectedNotePayload(
            itemID: itemID,
            noteText: noteText,
            updatedAt: payload.updatedAt
        )
    }

    @discardableResult
    func saveProtectedNote(_ payload: ProtectedNotePayload) -> ProtectedNotePayload {
        let trimmedNote = payload.noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPayload = protectedPayload(for: payload.itemID)
            ?? fallbackPayload(for: payload.itemID)
            ?? ProtectedClipPayload(itemID: payload.itemID, primaryText: "", updatedAt: payload.updatedAt)
        let nextPayload = ProtectedClipPayload(
            itemID: currentPayload.itemID,
            primaryText: currentPayload.primaryText,
            secondaryText: currentPayload.secondaryText,
            noteText: trimmedNote.isEmpty ? nil : trimmedNote,
            redactedPreviewText: currentPayload.redactedPreviewText ?? defaultRedactedPreviewText(for: currentPayload),
            updatedAt: payload.updatedAt
        )
        guard let savedPayload = payloadStore.saveProtectedPayload(nextPayload) else {
            return ProtectedNotePayload(
                itemID: payload.itemID,
                noteText: trimmedNote,
                updatedAt: payload.updatedAt
            )
        }

        _ = decryptedPayloadCache.cachePayload(savedPayload, cachedAt: payload.updatedAt)
        syncNoteMirror(for: payload.itemID)
        return ProtectedNotePayload(
            itemID: payload.itemID,
            noteText: trimmedNote,
            updatedAt: payload.updatedAt
        )
    }

    @discardableResult
    func clearProtectedNote(for itemID: String, clearedAt: Date) -> ProtectedNotePayload? {
        let currentPayload = protectedPayload(for: itemID) ?? fallbackPayload(for: itemID)
        if var currentPayload {
            currentPayload.noteText = nil
            currentPayload.updatedAt = clearedAt
            guard let savedPayload = payloadStore.saveProtectedPayload(currentPayload) else {
                return nil
            }
            _ = decryptedPayloadCache.cachePayload(savedPayload, cachedAt: clearedAt)
            decryptedPayloadCache.replaceDraft(for: itemID, with: "")
        } else {
            _ = decryptedPayloadCache.removeCachedPayload(for: itemID)
        }
        syncNoteMirror(for: itemID)
        return ProtectedNotePayload(itemID: itemID, noteText: "", updatedAt: clearedAt)
    }

    func noteText(for itemID: String) -> String? {
        if let noteText = decryptedPayloadCache.noteText(for: itemID), noteText.isEmpty == false {
            return noteText
        }

        guard let payload = protectedPayload(for: itemID) else {
            return nil
        }

        syncNoteMirror(for: itemID)
        return payload.noteText
    }

    func protectedPayload(for itemID: String) -> ProtectedClipPayload? {
        if let cachedPayload = decryptedPayloadCache.cachedPayload(for: itemID) {
            return cachedPayload
        }

        if let persistedPayload = payloadStore.protectedPayload(for: itemID) {
            _ = decryptedPayloadCache.cachePayload(persistedPayload, cachedAt: persistedPayload.updatedAt)
            return persistedPayload
        }

        return nil
    }

    func clearUnlockedSession() {
        decryptedPayloadCache.clearAll()
        let clearedDocuments = snapshot.documents.map { document in
            SearchIndexDocument(
                itemID: document.itemID,
                normalizedPlainText: "",
                noteMirror: nil,
                groupTerms: document.groupTerms,
                isPinned: document.isPinned
            )
        }
        _ = indexStore.replaceDocuments(clearedDocuments)
        _ = payloadStore.clearAccessKeyMaterial()
    }

    func dismissEditor() {
        decryptedPayloadCache.dismissEditor()
    }

    @discardableResult
    func presentEditor(for itemID: String, isEditable: Bool) -> ClipNoteEditorState {
        if let payload = protectedPayload(for: itemID) {
            _ = decryptedPayloadCache.cachePayload(payload, cachedAt: payload.updatedAt)
        }
        return decryptedPayloadCache.presentEditor(for: itemID, isEditable: isEditable)
    }

    @discardableResult
    func updateActiveDraft(_ draftText: String) -> ClipNoteEditorState? {
        decryptedPayloadCache.updateActiveDraft(draftText)
    }

    @discardableResult
    func createGroup(name: String, accentToken: String?) -> OrganizationGroupSummary? {
        indexStore.createGroup(name: name, accentToken: accentToken)
    }

    @discardableResult
    func updateGroup(
        id: OrganizationGroupID,
        name: String,
        accentToken: String?
    ) -> OrganizationGroupSummary? {
        indexStore.updateGroup(id: id, name: name, accentToken: accentToken)
    }

    @discardableResult
    func deleteGroup(id: OrganizationGroupID) -> SearchIndexSnapshot {
        indexStore.deleteGroup(id: id)
    }

    @discardableResult
    func setMembership(for itemID: String, groupIDs: [OrganizationGroupID]) -> SearchIndexSnapshot {
        indexStore.setMembership(for: itemID, groupIDs: groupIDs)
    }

    private func syncNoteMirror(for itemID: String) {
        guard let existingDocument = indexStore.document(for: itemID) else {
            return
        }

        let mirroredDocument = SearchIndexDocument(
            itemID: existingDocument.itemID,
            normalizedPlainText: existingDocument.normalizedPlainText,
            noteMirror: protectedPayload(for: itemID)?.noteText,
            groupTerms: existingDocument.groupTerms,
            isPinned: existingDocument.isPinned
        )
        _ = indexStore.upsertDocuments([mirroredDocument])
    }

    private func makeDocument(
        from item: ClipboardHistoryItem,
        includeProtectedContent: Bool
    ) -> SearchIndexDocument {
        guard includeProtectedContent else {
            return SearchIndexDocument(
                itemID: item.id,
                normalizedPlainText: "",
                noteMirror: nil,
                groupTerms: indexStore.document(for: item.id)?.groupTerms ?? [],
                isPinned: item.isPinned
            )
        }

        let protectedPayload = protectedPayload(for: item.id)
        let visibleSegments = [
            protectedPayload?.primaryText ?? item.primaryText,
            protectedPayload?.secondaryText ?? item.secondaryText,
            item.metadataText,
            item.sourceApp.displayName
        ]
        let normalizedPlainText = visibleSegments
            .compactMap { $0 }
            .map(normalizedSearchText)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        return SearchIndexDocument(
            itemID: item.id,
            normalizedPlainText: normalizedPlainText,
            noteMirror: protectedPayload?.noteText,
            groupTerms: indexStore.document(for: item.id)?.groupTerms ?? [],
            isPinned: item.isPinned
        )
    }

    private func makePayloadCandidate(from item: ClipboardHistoryItem) -> ProtectedClipPayload? {
        if payloadStore.containsEnvelope(for: item.id), payloadStore.protectedPayload(for: item.id) == nil {
            return nil
        }

        let existingPayload = protectedPayload(for: item.id)
        let nextPayload = ProtectedClipPayload(
            itemID: item.id,
            primaryText: item.primaryText,
            secondaryText: item.secondaryText,
            noteText: existingPayload?.noteText,
            redactedPreviewText: existingPayload?.redactedPreviewText ?? defaultRedactedPreviewText(for: item),
            updatedAt: max(item.lastCopiedAt, existingPayload?.updatedAt ?? item.lastCopiedAt)
        )

        guard existingPayload != nextPayload || payloadStore.containsEnvelope(for: item.id) == false else {
            return nil
        }

        return nextPayload
    }

    private func fallbackPayload(for itemID: String) -> ProtectedClipPayload? {
        guard let item = historyItemsByID[itemID] else {
            return nil
        }

        return ProtectedClipPayload(
            itemID: item.id,
            primaryText: item.primaryText,
            secondaryText: item.secondaryText,
            noteText: nil,
            redactedPreviewText: defaultRedactedPreviewText(for: item),
            updatedAt: item.lastCopiedAt
        )
    }

    private func defaultRedactedPreviewText(for item: ClipboardHistoryItem) -> String {
        if let secondaryText = item.secondaryText, secondaryText.isEmpty == false {
            return "Unlock SlipBoard to reveal this preview"
        }
        return "Hidden while SlipBoard is locked"
    }

    private func defaultRedactedPreviewText(for payload: ProtectedClipPayload) -> String {
        if let redactedPreviewText = payload.redactedPreviewText, redactedPreviewText.isEmpty == false {
            return redactedPreviewText
        }
        if let secondaryText = payload.secondaryText, secondaryText.isEmpty == false {
            return "Unlock SlipBoard to reveal this preview"
        }
        return "Hidden while SlipBoard is locked"
    }

    private func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
