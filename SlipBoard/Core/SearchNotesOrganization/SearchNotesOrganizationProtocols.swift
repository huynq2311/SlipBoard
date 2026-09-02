import Foundation

protocol SearchLockStateProviding: AnyObject {
    var currentLockState: SearchLockState { get }
    var onLockStateChange: ((SearchLockState) -> Void)? { get set }
}

protocol ProtectedNotePayloadProviding: AnyObject {
    func protectedNotePayload(for itemID: String) -> ProtectedNotePayload?

    @discardableResult
    func saveProtectedNote(_ payload: ProtectedNotePayload) -> ProtectedNotePayload

    @discardableResult
    func clearProtectedNote(for itemID: String, clearedAt: Date) -> ProtectedNotePayload?
}

protocol OrganizationGroupStoring: AnyObject {
    var latestGroups: [OrganizationGroupSummary] { get }

    @discardableResult
    func createGroup(name: String, accentToken: String?) -> OrganizationGroupSummary?

    @discardableResult
    func updateGroup(
        id: OrganizationGroupID,
        name: String,
        accentToken: String?
    ) -> OrganizationGroupSummary?

    @discardableResult
    func deleteGroup(id: OrganizationGroupID) -> SearchIndexSnapshot

    @discardableResult
    func setMembership(for itemID: String, groupIDs: [OrganizationGroupID]) -> SearchIndexSnapshot
}

protocol SearchIndexStoring: AnyObject {
    var snapshot: SearchIndexSnapshot { get }

    func document(for itemID: String) -> SearchIndexDocument?
    func membershipChange(for itemID: String) -> GroupMembershipChange?

    @discardableResult
    func replaceDocuments(_ documents: [SearchIndexDocument]) -> SearchIndexSnapshot

    @discardableResult
    func upsertDocuments(_ documents: [SearchIndexDocument]) -> SearchIndexSnapshot

    @discardableResult
    func removeDocuments(ids: [String]) -> SearchIndexSnapshot

    @discardableResult
    func upsertGroups(_ groups: [OrganizationGroupSummary]) -> SearchIndexSnapshot

    @discardableResult
    func removeGroups(ids: [OrganizationGroupID]) -> SearchIndexSnapshot

    @discardableResult
    func saveMembershipChanges(_ changes: [GroupMembershipChange]) -> SearchIndexSnapshot

    func search(_ request: SearchQueryRequest) -> SearchQueryResult
}

protocol SearchNotesOrganizationStoring: SearchIndexStoring, OrganizationGroupStoring, ProtectedNotePayloadProviding {
    var activeEditor: ClipNoteEditorState? { get }
    var latestMigrationState: SecurityMigrationState { get }

    func synchronizeHistoryItems(_ items: [ClipboardHistoryItem])
    func synchronizeHistoryItems(_ items: [ClipboardHistoryItem], includeProtectedContent: Bool)
    func refreshProtectedContentMirrors(includeProtectedContent: Bool)
    @discardableResult
    func migrateProtectedPayloadsIfNeeded() -> SecurityMigrationState
    func removeItems(ids: [String])
    func noteText(for itemID: String) -> String?
    func protectedPayload(for itemID: String) -> ProtectedClipPayload?
    func clearUnlockedSession()
    func dismissEditor()

    @discardableResult
    func presentEditor(for itemID: String, isEditable: Bool) -> ClipNoteEditorState

    @discardableResult
    func updateActiveDraft(_ draftText: String) -> ClipNoteEditorState?
}

protocol SearchNotesRuntimeProviding: AnyObject {
    var latestProjectionState: SearchNotesProjectionState { get }
    var latestQueryResult: SearchQueryResult { get }
    var latestGroups: [OrganizationGroupSummary] { get }
    var onProjectionChange: ((SearchNotesProjectionState) -> Void)? { get set }

    func synchronizeHistoryItems(_ items: [ClipboardHistoryItem])
    func removeItems(ids: [String])
    func visibleItemIDs(
        in items: [ClipboardHistoryItem],
        activeFilter: ClipboardHistoryFilter
    ) -> [String]
    func noteText(for itemID: String) -> String?
    func protectedPayload(for itemID: String) -> ProtectedClipPayload?

    func updateSearchQuery(_ query: String)
    func selectGroup(id: OrganizationGroupID)
    func createGroup(name: String, accentToken: String?) -> OrganizationGroupSummary?
    func updateGroup(
        id: OrganizationGroupID,
        name: String,
        accentToken: String?
    ) -> OrganizationGroupSummary?
    func deleteGroup(id: OrganizationGroupID)
    func updateMembership(for itemID: String, groupIDs: [OrganizationGroupID])
    func presentNoteEditor(for itemID: String)
    func dismissNoteEditor()
    func updateNoteDraft(_ draftText: String)
    func saveActiveNote()
    func clearNote(for itemID: String)
}
