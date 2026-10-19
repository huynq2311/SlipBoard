import Foundation

enum SearchLockState: String, CaseIterable, Identifiable, Hashable {
    case unlocked
    case locked

    var id: String { rawValue }

    var isSearchAvailable: Bool {
        self == .unlocked
    }
}

enum SearchDisabledReason: String, CaseIterable, Identifiable, Hashable {
    case locked

    var id: String { rawValue }
}

struct SearchDisabledMessage: Hashable {
    var reason: SearchDisabledReason
    var title: String
    var detailText: String
    var statusLabel: String

    init(
        reason: SearchDisabledReason = .locked,
        title: String,
        detailText: String,
        statusLabel: String
    ) {
        self.reason = reason
        self.title = title
        self.detailText = detailText
        self.statusLabel = statusLabel
    }

    static let lockedDefault = SearchDisabledMessage(
        title: "Search disabled while locked",
        detailText: "Unlock SlipBoard to search clipboard content, notes, and collections again.",
        statusLabel: "Search disabled while locked"
    )
}

enum OrganizationGroupID: Hashable, Identifiable {
    case all
    case ungrouped
    case custom(String)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .ungrouped:
            return "ungrouped"
        case let .custom(rawID):
            return "custom:\(rawID)"
        }
    }

    var isSystem: Bool {
        switch self {
        case .all, .ungrouped:
            return true
        case .custom:
            return false
        }
    }
}

struct OrganizationGroupSummary: Identifiable, Hashable {
    var groupID: OrganizationGroupID
    var name: String
    var accentToken: String?
    var itemCount: Int

    var id: String { groupID.id }
    var isSystem: Bool { groupID.isSystem }

    init(
        id groupID: OrganizationGroupID,
        name: String,
        accentToken: String? = nil,
        itemCount: Int = 0
    ) {
        self.groupID = groupID
        self.name = name
        self.accentToken = accentToken
        self.itemCount = max(itemCount, 0)
    }
}

struct OrganizationChipSummary: Identifiable, Hashable {
    var groupID: OrganizationGroupID
    var label: String
    var accentToken: String?
    var count: Int
    var isSelected: Bool
    var isDisabled: Bool

    var id: String { groupID.id }
    var isSystem: Bool { groupID.isSystem }

    init(
        id groupID: OrganizationGroupID,
        label: String,
        accentToken: String? = nil,
        count: Int = 0,
        isSelected: Bool = false,
        isDisabled: Bool = false
    ) {
        self.groupID = groupID
        self.label = label
        self.accentToken = accentToken
        self.count = max(count, 0)
        self.isSelected = isSelected
        self.isDisabled = isDisabled
    }
}

struct ClipNoteEditorState: Hashable {
    /// Notes are short labels shown on one footer line.
    static let characterLimit = 28

    var clipID: String
    var isPresented: Bool
    var draftText: String
    var persistedText: String?
    var isEditable: Bool

    var hasPersistedNote: Bool {
        persistedText?.isEmpty == false
    }

    var isDirty: Bool {
        draftText != (persistedText ?? "")
    }

    var canSave: Bool {
        isEditable && isDirty
    }

    var canClear: Bool {
        isEditable && (draftText.isEmpty == false || hasPersistedNote)
    }

    init(
        clipID: String,
        isPresented: Bool = false,
        draftText: String? = nil,
        persistedText: String? = nil,
        isEditable: Bool = true
    ) {
        self.clipID = clipID
        self.isPresented = isPresented
        self.persistedText = persistedText
        self.draftText = draftText ?? persistedText ?? ""
        self.isEditable = isEditable
    }
}

enum SearchIndexedField: String, CaseIterable, Identifiable, Hashable {
    case plainText
    case note
    case group

    var id: String { rawValue }
}

struct SearchResultMatch: Identifiable, Hashable {
    var itemID: String
    var matchedFields: [SearchIndexedField]
    var matchedGroupIDs: [OrganizationGroupID]
    var isPinned: Bool
    var rank: Int

    var id: String { itemID }

    init(
        itemID: String,
        matchedFields: [SearchIndexedField],
        matchedGroupIDs: [OrganizationGroupID] = [],
        isPinned: Bool,
        rank: Int = 0
    ) {
        self.itemID = itemID
        self.matchedFields = matchedFields
        self.matchedGroupIDs = matchedGroupIDs
        self.isPinned = isPinned
        self.rank = max(rank, 0)
    }
}

struct SearchResultMetadata: Hashable {
    var query: String
    var totalResultCount: Int
    var pinnedResultCount: Int
    var recentResultCount: Int
    var matchedNoteCount: Int
    var matchedGroupCount: Int

    var hasResults: Bool {
        totalResultCount > 0
    }

    init(
        query: String,
        totalResultCount: Int = 0,
        pinnedResultCount: Int = 0,
        recentResultCount: Int = 0,
        matchedNoteCount: Int = 0,
        matchedGroupCount: Int = 0
    ) {
        self.query = query
        self.totalResultCount = max(totalResultCount, 0)
        self.pinnedResultCount = max(pinnedResultCount, 0)
        self.recentResultCount = max(recentResultCount, 0)
        self.matchedNoteCount = max(matchedNoteCount, 0)
        self.matchedGroupCount = max(matchedGroupCount, 0)
    }

    init(query: String, matches: [SearchResultMatch]) {
        self.query = query
        totalResultCount = matches.count
        pinnedResultCount = matches.filter(\.isPinned).count
        recentResultCount = matches.count - pinnedResultCount
        matchedNoteCount = matches.filter { $0.matchedFields.contains(.note) }.count
        matchedGroupCount = matches.filter { $0.matchedFields.contains(.group) }.count
    }
}

struct SearchQueryRequest: Hashable {
    var query: String
    var selectedGroupID: OrganizationGroupID
    var maximumResultCount: Int?

    init(
        query: String = "",
        selectedGroupID: OrganizationGroupID = .all,
        maximumResultCount: Int? = nil
    ) {
        self.query = query
        self.selectedGroupID = selectedGroupID
        self.maximumResultCount = maximumResultCount
    }

    var normalizedQuery: String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var isEmptyQuery: Bool {
        normalizedQuery.isEmpty
    }
}

struct SearchQueryResult: Hashable {
    var request: SearchQueryRequest
    var matches: [SearchResultMatch]
    var metadata: SearchResultMetadata

    init(
        request: SearchQueryRequest,
        matches: [SearchResultMatch] = [],
        metadata: SearchResultMetadata? = nil
    ) {
        self.request = request
        self.matches = matches
        self.metadata = metadata ?? SearchResultMetadata(query: request.query, matches: matches)
    }
}

struct SearchIndexDocument: Identifiable, Hashable {
    var itemID: String
    var normalizedPlainText: String
    var noteMirror: String?
    var groupTerms: [String]
    var isPinned: Bool

    var id: String { itemID }

    init(
        itemID: String,
        normalizedPlainText: String,
        noteMirror: String? = nil,
        groupTerms: [String] = [],
        isPinned: Bool = false
    ) {
        self.itemID = itemID
        self.normalizedPlainText = normalizedPlainText
        self.noteMirror = noteMirror
        self.groupTerms = groupTerms
        self.isPinned = isPinned
    }
}

struct GroupMembershipChange: Hashable {
    var itemID: String
    var groupIDs: [OrganizationGroupID]

    init(itemID: String, groupIDs: [OrganizationGroupID]) {
        self.itemID = itemID
        self.groupIDs = groupIDs
    }
}

struct ProtectedNotePayload: Identifiable, Hashable {
    var itemID: String
    var noteText: String
    var updatedAt: Date

    var id: String { itemID }

    init(itemID: String, noteText: String, updatedAt: Date = .now) {
        self.itemID = itemID
        self.noteText = noteText
        self.updatedAt = updatedAt
    }
}

struct SearchIndexSnapshot: Hashable {
    var documents: [SearchIndexDocument]
    var groups: [OrganizationGroupSummary]
    var memberships: [GroupMembershipChange]

    init(
        documents: [SearchIndexDocument] = [],
        groups: [OrganizationGroupSummary] = [],
        memberships: [GroupMembershipChange] = []
    ) {
        self.documents = documents
        self.groups = groups
        self.memberships = memberships
    }

    func document(for itemID: String) -> SearchIndexDocument? {
        documents.first(where: { $0.itemID == itemID })
    }

    func groupSummary(for groupID: OrganizationGroupID) -> OrganizationGroupSummary? {
        groups.first(where: { $0.groupID == groupID })
    }

    func groupIDs(for itemID: String) -> [OrganizationGroupID] {
        memberships.first(where: { $0.itemID == itemID })?.groupIDs ?? []
    }
}

struct SearchNotesProjectionState: Hashable {
    var lockState: SearchLockState
    var searchQuery: String
    var groupChips: [OrganizationChipSummary]
    var activeGroupID: OrganizationGroupID
    var activeEditor: ClipNoteEditorState?
    var searchDisabledMessage: SearchDisabledMessage?
    var searchResultMetadata: SearchResultMetadata

    var searchResultCount: Int {
        searchResultMetadata.totalResultCount
    }

    var isSearchEnabled: Bool {
        lockState.isSearchAvailable && searchDisabledMessage == nil
    }

    init(
        lockState: SearchLockState = .unlocked,
        searchQuery: String = "",
        groupChips: [OrganizationChipSummary] = [],
        activeGroupID: OrganizationGroupID = .all,
        activeEditor: ClipNoteEditorState? = nil,
        searchDisabledMessage: SearchDisabledMessage? = nil,
        searchResultMetadata: SearchResultMetadata = SearchResultMetadata(query: "")
    ) {
        self.lockState = lockState
        self.searchQuery = searchQuery
        self.groupChips = groupChips
        self.activeGroupID = activeGroupID
        self.activeEditor = activeEditor
        self.searchDisabledMessage = searchDisabledMessage ?? (lockState == .locked ? .lockedDefault : nil)
        self.searchResultMetadata = searchResultMetadata
    }
}
