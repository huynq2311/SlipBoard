import Foundation

final class SearchNotesRuntimeController: SearchNotesRuntimeProviding {
    private let store: SearchNotesOrganizationStoring
    private weak var lockStateProvider: SearchLockStateProviding?

    private var searchQuery: String
    private var selectedGroupID: OrganizationGroupID
    private var lockState: SearchLockState

    private(set) var latestProjectionState: SearchNotesProjectionState
    private(set) var latestQueryResult: SearchQueryResult

    var latestGroups: [OrganizationGroupSummary] {
        store.latestGroups
    }

    var onProjectionChange: ((SearchNotesProjectionState) -> Void)?

    init(
        store: SearchNotesOrganizationStoring = SearchNotesOrganizationStore(),
        lockStateProvider: SearchLockStateProviding? = nil,
        initialQuery: String = "",
        initialGroupID: OrganizationGroupID = .all
    ) {
        self.store = store
        self.lockStateProvider = lockStateProvider
        self.searchQuery = initialQuery
        self.selectedGroupID = initialGroupID
        self.lockState = lockStateProvider?.currentLockState ?? .unlocked
        self.latestQueryResult = SearchQueryResult(request: SearchQueryRequest(query: initialQuery))
        self.latestProjectionState = SearchNotesProjectionState(
            lockState: self.lockState,
            searchQuery: initialQuery,
            activeGroupID: initialGroupID
        )

        lockStateProvider?.onLockStateChange = { [weak self] nextState in
            self?.handleLockStateChange(nextState)
        }

        refreshProjection()
    }

    func synchronizeHistoryItems(_ items: [ClipboardHistoryItem]) {
        let previousDocumentIDs = Set(store.snapshot.documents.map(\.itemID))
        store.synchronizeHistoryItems(items, includeProtectedContent: lockState.isSearchAvailable)

        let survivingIDs = Set(items.map(\.id))
        let removedIDs = previousDocumentIDs.subtracting(survivingIDs)
        if let activeEditor = store.activeEditor, removedIDs.contains(activeEditor.clipID) {
            store.dismissEditor()
        }

        refreshProjection()
    }

    func removeItems(ids: [String]) {
        guard ids.isEmpty == false else {
            return
        }

        store.removeItems(ids: ids)
        if let activeEditor = store.activeEditor, ids.contains(activeEditor.clipID) {
            store.dismissEditor()
        }
        refreshProjection()
    }

    func visibleItemIDs(
        in items: [ClipboardHistoryItem],
        activeFilter: ClipboardHistoryFilter
    ) -> [String] {
        guard lockState.isSearchAvailable else {
            return []
        }

        let filteredItems = items.filter { activeFilter.matches($0.kind) }
        let matchingIDs: Set<String>

        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            matchingIDs = Set(latestQueryResult.matches.map(\.itemID))
        } else if selectedGroupID == .all {
            // Every filtered item matches, so the Set round trip below would
            // hand back the same list.
            return filteredItems.map(\.id)
        } else {
            matchingIDs = Set(
                filteredItems
                    .filter { matchesSelectedGroup(itemID: $0.id) }
                    .map(\.id)
            )
        }

        return filteredItems
            .map(\.id)
            .filter { matchingIDs.contains($0) }
    }

    func noteText(for itemID: String) -> String? {
        guard lockState.isSearchAvailable else {
            return nil
        }

        return store.noteText(for: itemID)
    }

    func protectedPayload(for itemID: String) -> ProtectedClipPayload? {
        guard lockState.isSearchAvailable else {
            return nil
        }

        return store.protectedPayload(for: itemID)
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        refreshProjection()
    }

    func selectGroup(id: OrganizationGroupID) {
        selectedGroupID = resolvedGroupID(id)
        refreshProjection()
    }

    func createGroup(name: String, accentToken: String?) -> OrganizationGroupSummary? {
        let group = store.createGroup(name: name, accentToken: accentToken)
        refreshProjection()
        return group
    }

    func updateGroup(
        id: OrganizationGroupID,
        name: String,
        accentToken: String?
    ) -> OrganizationGroupSummary? {
        let group = store.updateGroup(id: id, name: name, accentToken: accentToken)
        refreshProjection()
        return group
    }

    func deleteGroup(id: OrganizationGroupID) {
        _ = store.deleteGroup(id: id)
        if selectedGroupID == id {
            selectedGroupID = .all
        }
        refreshProjection()
    }

    func updateMembership(for itemID: String, groupIDs: [OrganizationGroupID]) {
        _ = store.setMembership(for: itemID, groupIDs: groupIDs)
        refreshProjection()
    }

    func presentNoteEditor(for itemID: String) {
        guard lockState.isSearchAvailable else {
            return
        }

        _ = store.presentEditor(for: itemID, isEditable: true)
        refreshProjection()
    }

    func dismissNoteEditor() {
        store.dismissEditor()
        refreshProjection()
    }

    func updateNoteDraft(_ draftText: String) {
        _ = store.updateActiveDraft(draftText)
        refreshProjection()
    }

    func saveActiveNote() {
        guard
            lockState.isSearchAvailable,
            let activeEditor = store.activeEditor
        else {
            return
        }

        let trimmedDraft = activeEditor.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDraft.isEmpty {
            _ = store.clearProtectedNote(for: activeEditor.clipID, clearedAt: .now)
        } else {
            _ = store.saveProtectedNote(
                ProtectedNotePayload(
                    itemID: activeEditor.clipID,
                    noteText: activeEditor.draftText,
                    updatedAt: .now
                )
            )
        }

        refreshProjection()
    }

    func clearNote(for itemID: String) {
        guard lockState.isSearchAvailable else {
            return
        }

        _ = store.clearProtectedNote(for: itemID, clearedAt: .now)
        refreshProjection()
    }

    private func handleLockStateChange(_ nextState: SearchLockState) {
        guard lockState != nextState else {
            return
        }

        lockState = nextState
        if nextState == .locked {
            store.clearUnlockedSession()
            store.dismissEditor()
        } else {
            _ = store.migrateProtectedPayloadsIfNeeded()
            store.refreshProtectedContentMirrors(includeProtectedContent: true)
        }

        refreshProjection()
    }

    private func refreshProjection() {
        selectedGroupID = resolvedGroupID(selectedGroupID)

        let request = SearchQueryRequest(
            query: searchQuery,
            selectedGroupID: selectedGroupID,
            maximumResultCount: nil
        )

        if lockState.isSearchAvailable {
            latestQueryResult = store.search(request)
        } else {
            latestQueryResult = SearchQueryResult(request: request)
        }

        latestProjectionState = SearchNotesProjectionState(
            lockState: lockState,
            searchQuery: searchQuery,
            groupChips: makeGroupChips(),
            activeGroupID: selectedGroupID,
            activeEditor: lockState.isSearchAvailable ? store.activeEditor : nil,
            searchDisabledMessage: lockState.isSearchAvailable ? nil : .lockedDefault,
            searchResultMetadata: latestQueryResult.metadata
        )

        onProjectionChange?(latestProjectionState)
    }

    private func makeGroupChips() -> [OrganizationChipSummary] {
        latestGroups.map { group in
            OrganizationChipSummary(
                id: group.groupID,
                label: group.name,
                accentToken: group.accentToken,
                count: group.itemCount,
                isSelected: group.groupID == selectedGroupID,
                isDisabled: lockState == .locked
            )
        }
    }

    private func resolvedGroupID(_ groupID: OrganizationGroupID) -> OrganizationGroupID {
        if groupID == .all || groupID == .ungrouped {
            return groupID
        }

        return latestGroups.contains(where: { $0.groupID == groupID }) ? groupID : .all
    }

    private func matchesSelectedGroup(itemID: String) -> Bool {
        switch selectedGroupID {
        case .all:
            return true
        case .ungrouped:
            return (store.membershipChange(for: itemID)?.groupIDs ?? []).isEmpty
        case .custom:
            return (store.membershipChange(for: itemID)?.groupIDs ?? []).contains(selectedGroupID)
        }
    }
}
