import Foundation

enum SearchNotesOrganizationMockFixtures {
    static let baseDate = Date(timeIntervalSince1970: 1_787_000_400)

    static let releaseGroupID = OrganizationGroupID.custom("release")
    static let researchGroupID = OrganizationGroupID.custom("research")

    static let groupSummaries: [OrganizationGroupSummary] = [
        OrganizationGroupSummary(id: .all, name: "All", itemCount: 3),
        OrganizationGroupSummary(id: .ungrouped, name: "Ungrouped", itemCount: 1),
        OrganizationGroupSummary(
            id: releaseGroupID,
            name: "Release",
            accentToken: "accent.warning",
            itemCount: 1
        ),
        OrganizationGroupSummary(
            id: researchGroupID,
            name: "Research",
            accentToken: "accent.info",
            itemCount: 1
        )
    ]

    static let releaseSelectedChips: [OrganizationChipSummary] = [
        OrganizationChipSummary(id: .all, label: "All", count: 3),
        OrganizationChipSummary(id: .ungrouped, label: "Ungrouped", count: 1),
        OrganizationChipSummary(
            id: releaseGroupID,
            label: "Release",
            accentToken: "accent.warning",
            count: 1,
            isSelected: true
        ),
        OrganizationChipSummary(
            id: researchGroupID,
            label: "Research",
            accentToken: "accent.info",
            count: 1
        )
    ]

    static let lockedChips: [OrganizationChipSummary] = releaseSelectedChips.map {
        OrganizationChipSummary(
            id: $0.groupID,
            label: $0.label,
            accentToken: $0.accentToken,
            count: $0.count,
            isSelected: $0.isSelected,
            isDisabled: true
        )
    }

    static let noteBearingItemID = "clip-note-grouped-01"
    static let ungroupedItemID = "clip-ungrouped-link-02"
    static let groupedItemID = "clip-grouped-research-03"

    static let indexDocuments: [SearchIndexDocument] = [
        SearchIndexDocument(
            itemID: noteBearingItemID,
            normalizedPlainText: "release checklist qa ship blocker review",
            noteMirror: "Ship after QA sign-off.",
            groupTerms: ["Release"],
            isPinned: true
        ),
        SearchIndexDocument(
            itemID: ungroupedItemID,
            normalizedPlainText: "https://developer.apple.com/documentation/swiftui",
            noteMirror: nil,
            groupTerms: [],
            isPinned: false
        ),
        SearchIndexDocument(
            itemID: groupedItemID,
            normalizedPlainText: "retrospective prompts for design review",
            noteMirror: "",
            groupTerms: ["Research"],
            isPinned: false
        )
    ]

    static let memberships: [GroupMembershipChange] = [
        GroupMembershipChange(itemID: noteBearingItemID, groupIDs: [releaseGroupID]),
        GroupMembershipChange(itemID: ungroupedItemID, groupIDs: []),
        GroupMembershipChange(itemID: groupedItemID, groupIDs: [researchGroupID])
    ]

    static let protectedPayloads: [ProtectedNotePayload] = [
        ProtectedNotePayload(
            itemID: noteBearingItemID,
            noteText: "Ship after QA sign-off.",
            updatedAt: baseDate.addingTimeInterval(-300)
        )
    ]

    static let noteEditorState = ClipNoteEditorState(
        clipID: noteBearingItemID,
        isPresented: true,
        draftText: "Ship after QA sign-off.",
        persistedText: "Ship after QA sign-off.",
        isEditable: true
    )

    static let noteQueryRequest = SearchQueryRequest(
        query: "qa",
        selectedGroupID: .all,
        maximumResultCount: 10
    )

    static let noteQueryResult = SearchQueryResult(
        request: noteQueryRequest,
        matches: [
            SearchResultMatch(
                itemID: noteBearingItemID,
                matchedFields: [.note, .plainText],
                matchedGroupIDs: [releaseGroupID],
                isPinned: true,
                rank: 1
            )
        ]
    )

    static let releaseQueryRequest = SearchQueryRequest(
        query: "release",
        selectedGroupID: releaseGroupID,
        maximumResultCount: 10
    )

    static let releaseQueryResult = SearchQueryResult(
        request: releaseQueryRequest,
        matches: [
            SearchResultMatch(
                itemID: noteBearingItemID,
                matchedFields: [.plainText, .group],
                matchedGroupIDs: [releaseGroupID],
                isPinned: true,
                rank: 1
            )
        ]
    )

    static let indexSnapshot = SearchIndexSnapshot(
        documents: indexDocuments,
        groups: groupSummaries,
        memberships: memberships
    )

    static let unlockedProjectionState = SearchNotesProjectionState(
        lockState: .unlocked,
        searchQuery: releaseQueryRequest.query,
        groupChips: releaseSelectedChips,
        activeGroupID: releaseGroupID,
        activeEditor: noteEditorState,
        searchDisabledMessage: nil,
        searchResultMetadata: releaseQueryResult.metadata
    )

    static let lockedProjectionState = SearchNotesProjectionState(
        lockState: .locked,
        searchQuery: releaseQueryRequest.query,
        groupChips: lockedChips,
        activeGroupID: releaseGroupID,
        activeEditor: nil,
        searchDisabledMessage: SearchDisabledMessage(
            title: "Search disabled while locked",
            detailText: "Unlock SlipTray to search notes, collections, and clipboard content.",
            statusLabel: "Search disabled while locked"
        ),
        searchResultMetadata: SearchResultMetadata(query: releaseQueryRequest.query)
    )
}
