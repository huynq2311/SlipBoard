import Foundation
import SQLite3

final class SQLiteSearchIndexStore: SearchIndexStoring, OrganizationGroupStoring {
    private let databaseURL: URL
    private let fileManager: FileManager
    private var database: OpaquePointer?

    private(set) var snapshot: SearchIndexSnapshot

    init(
        databaseURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL(fileManager: fileManager)
        self.snapshot = SearchIndexSnapshot(
            groups: [
                OrganizationGroupSummary(id: .all, name: "All"),
                OrganizationGroupSummary(id: .ungrouped, name: "Ungrouped")
            ]
        )

        openDatabaseIfPossible()
        createSchemaIfPossible()
        if let loadedSnapshot = loadSnapshotFromDatabase() {
            snapshot = loadedSnapshot
        }
    }

    deinit {
        guard let database else { return }
        sqlite3_close(database)
    }

    var latestGroups: [OrganizationGroupSummary] {
        snapshot.groups
    }

    func document(for itemID: String) -> SearchIndexDocument? {
        snapshot.document(for: itemID)
    }

    func membershipChange(for itemID: String) -> GroupMembershipChange? {
        snapshot.memberships.first(where: { $0.itemID == itemID })
    }

    @discardableResult
    func replaceDocuments(_ documents: [SearchIndexDocument]) -> SearchIndexSnapshot {
        let currentMemberships = snapshot.memberships.filter { membership in
            documents.contains(where: { $0.itemID == membership.itemID })
        }
        snapshot = normalizedSnapshot(
            documents: documents,
            customGroups: customGroups(from: snapshot.groups),
            memberships: currentMemberships
        )
        persistSnapshot()
        return snapshot
    }

    @discardableResult
    func upsertDocuments(_ documents: [SearchIndexDocument]) -> SearchIndexSnapshot {
        var documentsByID = Dictionary(uniqueKeysWithValues: snapshot.documents.map { ($0.itemID, $0) })
        for document in documents {
            documentsByID[document.itemID] = sanitizedDocument(document)
        }

        snapshot = normalizedSnapshot(
            documents: Array(documentsByID.values),
            customGroups: customGroups(from: snapshot.groups),
            memberships: snapshot.memberships
        )
        persistSnapshot()
        return snapshot
    }

    @discardableResult
    func removeDocuments(ids: [String]) -> SearchIndexSnapshot {
        let removedIDs = Set(ids)
        snapshot = normalizedSnapshot(
            documents: snapshot.documents.filter { removedIDs.contains($0.itemID) == false },
            customGroups: customGroups(from: snapshot.groups),
            memberships: snapshot.memberships.filter { removedIDs.contains($0.itemID) == false }
        )
        persistSnapshot()
        return snapshot
    }

    @discardableResult
    func upsertGroups(_ groups: [OrganizationGroupSummary]) -> SearchIndexSnapshot {
        var groupsByID = Dictionary(
            uniqueKeysWithValues: customGroups(from: snapshot.groups).map { ($0.groupID, $0) }
        )

        for group in groups where group.groupID.isSystem == false {
            groupsByID[group.groupID] = sanitizedCustomGroup(group)
        }

        snapshot = normalizedSnapshot(
            documents: snapshot.documents,
            customGroups: Array(groupsByID.values),
            memberships: snapshot.memberships
        )
        persistSnapshot()
        return snapshot
    }

    @discardableResult
    func removeGroups(ids: [OrganizationGroupID]) -> SearchIndexSnapshot {
        let removedIDs = Set(ids.filter { $0.isSystem == false })

        let nextGroups = customGroups(from: snapshot.groups).filter { removedIDs.contains($0.groupID) == false }
        let nextMemberships = snapshot.memberships.map { membership in
            GroupMembershipChange(
                itemID: membership.itemID,
                groupIDs: membership.groupIDs.filter { removedIDs.contains($0) == false }
            )
        }

        snapshot = normalizedSnapshot(
            documents: snapshot.documents,
            customGroups: nextGroups,
            memberships: nextMemberships
        )
        persistSnapshot()
        return snapshot
    }

    @discardableResult
    func saveMembershipChanges(_ changes: [GroupMembershipChange]) -> SearchIndexSnapshot {
        let validCustomIDs = Set(customGroups(from: snapshot.groups).map(\.groupID))
        var membershipByItemID = Dictionary(uniqueKeysWithValues: snapshot.memberships.map { ($0.itemID, $0) })

        for change in changes where snapshot.document(for: change.itemID) != nil {
            let filteredIDs = change.groupIDs
                .filter { validCustomIDs.contains($0) }
                .uniqued()
            membershipByItemID[change.itemID] = GroupMembershipChange(
                itemID: change.itemID,
                groupIDs: filteredIDs
            )
        }

        snapshot = normalizedSnapshot(
            documents: snapshot.documents,
            customGroups: customGroups(from: snapshot.groups),
            memberships: Array(membershipByItemID.values)
        )
        persistSnapshot()
        return snapshot
    }

    func search(_ request: SearchQueryRequest) -> SearchQueryResult {
        let groupFilteredDocuments = applyGroupFilter(
            to: snapshot.documents,
            selectedGroupID: request.selectedGroupID
        )

        guard request.isEmptyQuery == false else {
            return queryResult(
                request: request,
                documents: groupFilteredDocuments,
                orderedMatches: groupFilteredDocuments.map { document in
                    SearchResultMatch(
                        itemID: document.itemID,
                        matchedFields: request.selectedGroupID == .all ? [] : [.group],
                        matchedGroupIDs: membershipChange(for: document.itemID)?.groupIDs ?? [],
                        isPinned: document.isPinned
                    )
                }
            )
        }

        let matchedDocuments = searchDocumentsUsingSQLite(request)
            ?? inMemoryQueryDocuments(for: request)

        let filteredMatches = applyGroupFilter(
            to: matchedDocuments,
            selectedGroupID: request.selectedGroupID
        )

        let matches = filteredMatches.map { document in
            let matchedFields = matchedFields(
                for: document,
                normalizedQuery: request.normalizedQuery
            )

            return SearchResultMatch(
                itemID: document.itemID,
                matchedFields: matchedFields,
                matchedGroupIDs: matchedGroupIDs(
                    for: document.itemID,
                    normalizedQuery: request.normalizedQuery
                ),
                isPinned: document.isPinned
            )
        }

        return queryResult(request: request, documents: filteredMatches, orderedMatches: matches)
    }

    @discardableResult
    func createGroup(name: String, accentToken: String?) -> OrganizationGroupSummary? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return nil
        }

        let summary = OrganizationGroupSummary(
            id: .custom(UUID().uuidString.lowercased()),
            name: trimmedName,
            accentToken: accentToken,
            itemCount: 0
        )
        _ = upsertGroups([summary])
        return snapshot.groupSummary(for: summary.groupID)
    }

    @discardableResult
    func updateGroup(
        id: OrganizationGroupID,
        name: String,
        accentToken: String?
    ) -> OrganizationGroupSummary? {
        guard id.isSystem == false else {
            return snapshot.groupSummary(for: id)
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return nil
        }

        let summary = OrganizationGroupSummary(
            id: id,
            name: trimmedName,
            accentToken: accentToken,
            itemCount: snapshot.groupSummary(for: id)?.itemCount ?? 0
        )
        _ = upsertGroups([summary])
        return snapshot.groupSummary(for: id)
    }

    @discardableResult
    func deleteGroup(id: OrganizationGroupID) -> SearchIndexSnapshot {
        removeGroups(ids: [id])
    }

    @discardableResult
    func setMembership(for itemID: String, groupIDs: [OrganizationGroupID]) -> SearchIndexSnapshot {
        saveMembershipChanges([GroupMembershipChange(itemID: itemID, groupIDs: groupIDs)])
    }

    private func searchDocumentsUsingSQLite(_ request: SearchQueryRequest) -> [SearchIndexDocument]? {
        guard
            let database,
            let matchExpression = makeFTSMatchExpression(from: request.normalizedQuery)
        else {
            return nil
        }

        let sql = """
        SELECT item_id, normalized_plain_text, note_mirror, group_terms, is_pinned
        FROM fts_index
        WHERE fts_index MATCH ?
        ORDER BY bm25(fts_index), is_pinned DESC, rowid DESC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        bindText(matchExpression, at: 1, in: statement)

        var documents: [SearchIndexDocument] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let itemID = String(cString: sqlite3_column_text(statement, 0))
            let plainText = String(cString: sqlite3_column_text(statement, 1))
            let noteMirror = sqlite3_column_type(statement, 2) == SQLITE_NULL
                ? nil
                : String(cString: sqlite3_column_text(statement, 2))
            let rawGroupTerms = sqlite3_column_type(statement, 3) == SQLITE_NULL
                ? ""
                : String(cString: sqlite3_column_text(statement, 3))
            let groupTerms = rawGroupTerms
                .split(separator: "|")
                .map(String.init)
                .filter { $0.isEmpty == false }
            let isPinned = sqlite3_column_int(statement, 4) != 0

            documents.append(
                SearchIndexDocument(
                    itemID: itemID,
                    normalizedPlainText: plainText,
                    noteMirror: noteMirror,
                    groupTerms: groupTerms,
                    isPinned: isPinned
                )
            )
        }

        return documents
    }

    private func inMemoryQueryDocuments(for request: SearchQueryRequest) -> [SearchIndexDocument] {
        let tokens = queryTokens(from: request.normalizedQuery)
        guard tokens.isEmpty == false else {
            return snapshot.documents
        }

        return snapshot.documents.filter { document in
            let normalizedNote = normalizedSearchText(document.noteMirror)
            let normalizedGroups = document.groupTerms.map(normalizedSearchText).joined(separator: " ")
            let haystacks = [
                document.normalizedPlainText,
                normalizedNote,
                normalizedGroups
            ]
            return tokens.allSatisfy { token in
                haystacks.contains(where: { $0.contains(token) })
            }
        }
    }

    private func queryResult(
        request: SearchQueryRequest,
        documents: [SearchIndexDocument],
        orderedMatches: [SearchResultMatch]
    ) -> SearchQueryResult {
        let limitedMatches: [SearchResultMatch]
        if let maximumResultCount = request.maximumResultCount {
            limitedMatches = Array(orderedMatches.prefix(maximumResultCount))
        } else {
            limitedMatches = orderedMatches
        }

        let metadata = SearchResultMetadata(query: request.query, matches: limitedMatches)
        return SearchQueryResult(
            request: request,
            matches: limitedMatches,
            metadata: metadata
        )
    }

    private func matchedFields(
        for document: SearchIndexDocument,
        normalizedQuery: String
    ) -> [SearchIndexedField] {
        let tokens = queryTokens(from: normalizedQuery)
        guard tokens.isEmpty == false else {
            return []
        }

        var fields: [SearchIndexedField] = []

        if tokens.allSatisfy({ document.normalizedPlainText.contains($0) }) {
            fields.append(.plainText)
        }

        let normalizedNote = normalizedSearchText(document.noteMirror)
        if normalizedNote.isEmpty == false && tokens.allSatisfy({ normalizedNote.contains($0) }) {
            fields.append(.note)
        }

        let normalizedGroups = document.groupTerms.map(normalizedSearchText).joined(separator: " ")
        if normalizedGroups.isEmpty == false && tokens.allSatisfy({ normalizedGroups.contains($0) }) {
            fields.append(.group)
        }

        if fields.isEmpty {
            fields.append(.plainText)
        }

        return fields
    }

    private func matchedGroupIDs(for itemID: String, normalizedQuery: String) -> [OrganizationGroupID] {
        let tokens = queryTokens(from: normalizedQuery)
        guard tokens.isEmpty == false else {
            return membershipChange(for: itemID)?.groupIDs ?? []
        }

        return (membershipChange(for: itemID)?.groupIDs ?? []).filter { groupID in
            guard let name = snapshot.groupSummary(for: groupID)?.name else {
                return false
            }
            let normalizedName = normalizedSearchText(name)
            return tokens.allSatisfy { normalizedName.contains($0) }
        }
    }

    private func applyGroupFilter(
        to documents: [SearchIndexDocument],
        selectedGroupID: OrganizationGroupID
    ) -> [SearchIndexDocument] {
        switch selectedGroupID {
        case .all:
            return documents
        case .ungrouped:
            return documents.filter { (membershipChange(for: $0.itemID)?.groupIDs ?? []).isEmpty }
        case .custom(let rawID):
            return documents.filter { document in
                (membershipChange(for: document.itemID)?.groupIDs ?? []).contains(.custom(rawID))
            }
        }
    }

    private func openDatabaseIfPossible() {
        let directoryURL = databaseURL.deletingLastPathComponent()
        try? fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        var openedDatabase: OpaquePointer?
        if sqlite3_open(databaseURL.path, &openedDatabase) == SQLITE_OK {
            database = openedDatabase
        } else if let openedDatabase {
            sqlite3_close(openedDatabase)
        }
    }

    private func createSchemaIfPossible() {
        guard let database else { return }

        let statements = [
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS fts_index USING fts5(
                item_id UNINDEXED,
                normalized_plain_text,
                note_mirror,
                group_terms,
                is_pinned UNINDEXED,
                tokenize = 'unicode61 remove_diacritics 2'
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS group_record (
                group_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                accent_token TEXT,
                is_system INTEGER NOT NULL DEFAULT 0
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS group_membership (
                item_id TEXT NOT NULL,
                group_id TEXT NOT NULL,
                PRIMARY KEY (item_id, group_id)
            );
            """
        ]

        for statement in statements {
            sqlite3_exec(database, statement, nil, nil, nil)
        }
    }

    private func loadSnapshotFromDatabase() -> SearchIndexSnapshot? {
        guard let database else {
            return nil
        }

        let documents = queryDocuments(database: database)
        let customGroups = queryGroups(database: database)
        let memberships = queryMemberships(database: database)

        return normalizedSnapshot(
            documents: documents,
            customGroups: customGroups,
            memberships: memberships
        )
    }

    private func queryDocuments(database: OpaquePointer) -> [SearchIndexDocument] {
        let sql = """
        SELECT item_id, normalized_plain_text, note_mirror, group_terms, is_pinned
        FROM fts_index
        ORDER BY rowid DESC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var documents: [SearchIndexDocument] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let itemID = String(cString: sqlite3_column_text(statement, 0))
            let plainText = String(cString: sqlite3_column_text(statement, 1))
            let noteMirror = sqlite3_column_type(statement, 2) == SQLITE_NULL
                ? nil
                : String(cString: sqlite3_column_text(statement, 2))
            let rawGroupTerms = sqlite3_column_type(statement, 3) == SQLITE_NULL
                ? ""
                : String(cString: sqlite3_column_text(statement, 3))
            let groupTerms = rawGroupTerms
                .split(separator: "|")
                .map(String.init)
                .filter { $0.isEmpty == false }
            let isPinned = sqlite3_column_int(statement, 4) != 0

            documents.append(
                SearchIndexDocument(
                    itemID: itemID,
                    normalizedPlainText: plainText,
                    noteMirror: noteMirror,
                    groupTerms: groupTerms,
                    isPinned: isPinned
                )
            )
        }

        return documents
    }

    private func queryGroups(database: OpaquePointer) -> [OrganizationGroupSummary] {
        let sql = """
        SELECT group_id, name, accent_token
        FROM group_record
        WHERE is_system = 0
        ORDER BY name COLLATE NOCASE ASC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var groups: [OrganizationGroupSummary] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let rawID = String(cString: sqlite3_column_text(statement, 0))
            let name = String(cString: sqlite3_column_text(statement, 1))
            let accentToken = sqlite3_column_type(statement, 2) == SQLITE_NULL
                ? nil
                : String(cString: sqlite3_column_text(statement, 2))

            groups.append(
                OrganizationGroupSummary(
                    id: .custom(rawID),
                    name: name,
                    accentToken: accentToken,
                    itemCount: 0
                )
            )
        }

        return groups
    }

    private func queryMemberships(database: OpaquePointer) -> [GroupMembershipChange] {
        let sql = """
        SELECT item_id, group_id
        FROM group_membership
        ORDER BY item_id ASC, group_id ASC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var membershipsByItemID: [String: [OrganizationGroupID]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let itemID = String(cString: sqlite3_column_text(statement, 0))
            let rawGroupID = String(cString: sqlite3_column_text(statement, 1))
            membershipsByItemID[itemID, default: []].append(.custom(rawGroupID))
        }

        return membershipsByItemID
            .map { itemID, groupIDs in
                GroupMembershipChange(itemID: itemID, groupIDs: groupIDs.sorted(by: sortGroupIDs))
            }
            .sorted { $0.itemID < $1.itemID }
    }

    private func persistSnapshot() {
        guard let database else { return }

        sqlite3_exec(database, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil)
        sqlite3_exec(database, "DELETE FROM fts_index;", nil, nil, nil)
        sqlite3_exec(database, "DELETE FROM group_record;", nil, nil, nil)
        sqlite3_exec(database, "DELETE FROM group_membership;", nil, nil, nil)

        persistDocuments(database: database)
        persistGroups(database: database)
        persistMemberships(database: database)

        sqlite3_exec(database, "COMMIT TRANSACTION;", nil, nil, nil)
    }

    private func persistDocuments(database: OpaquePointer) {
        let sql = """
        INSERT INTO fts_index (
            item_id,
            normalized_plain_text,
            note_mirror,
            group_terms,
            is_pinned
        ) VALUES (?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(statement) }

        for document in snapshot.documents {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bindText(document.itemID, at: 1, in: statement)
            bindText(document.normalizedPlainText, at: 2, in: statement)

            if let noteMirror = document.noteMirror, noteMirror.isEmpty == false {
                bindText(noteMirror, at: 3, in: statement)
            } else {
                sqlite3_bind_null(statement, 3)
            }

            let groupTerms = document.groupTerms.joined(separator: "|")
            bindText(groupTerms, at: 4, in: statement)
            sqlite3_bind_int(statement, 5, document.isPinned ? 1 : 0)
            sqlite3_step(statement)
        }
    }

    private func persistGroups(database: OpaquePointer) {
        let sql = """
        INSERT INTO group_record (
            group_id,
            name,
            accent_token,
            is_system
        ) VALUES (?, ?, ?, 0)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(statement) }

        for group in customGroups(from: snapshot.groups) {
            guard case let .custom(rawID) = group.groupID else {
                continue
            }

            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bindText(rawID, at: 1, in: statement)
            bindText(group.name, at: 2, in: statement)

            if let accentToken = group.accentToken, accentToken.isEmpty == false {
                bindText(accentToken, at: 3, in: statement)
            } else {
                sqlite3_bind_null(statement, 3)
            }

            sqlite3_step(statement)
        }
    }

    private func persistMemberships(database: OpaquePointer) {
        let sql = """
        INSERT INTO group_membership (item_id, group_id)
        VALUES (?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(statement) }

        for membership in snapshot.memberships {
            for groupID in membership.groupIDs {
                guard case let .custom(rawID) = groupID else {
                    continue
                }

                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                bindText(membership.itemID, at: 1, in: statement)
                bindText(rawID, at: 2, in: statement)
                sqlite3_step(statement)
            }
        }
    }

    private func normalizedSnapshot(
        documents rawDocuments: [SearchIndexDocument],
        customGroups rawCustomGroups: [OrganizationGroupSummary],
        memberships rawMemberships: [GroupMembershipChange]
    ) -> SearchIndexSnapshot {
        let documentsByID = Dictionary(uniqueKeysWithValues: rawDocuments.map { ($0.itemID, sanitizedDocument($0)) })
        let documents = documentsByID.values.sorted { lhs, rhs in
            if lhs.isPinned == rhs.isPinned {
                return lhs.itemID > rhs.itemID
            }
            return lhs.isPinned && (rhs.isPinned == false)
        }

        let customGroupsByID = Dictionary(
            uniqueKeysWithValues: rawCustomGroups
                .filter { $0.groupID.isSystem == false }
                .map { ($0.groupID, sanitizedCustomGroup($0)) }
        )
        let customGroups = customGroupsByID.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let validCustomIDs = Set(customGroups.map(\.groupID))
        let memberships = rawMemberships
            .filter { documentsByID[$0.itemID] != nil }
            .map { membership in
                GroupMembershipChange(
                    itemID: membership.itemID,
                    groupIDs: membership.groupIDs
                        .filter { validCustomIDs.contains($0) }
                        .sorted(by: sortGroupIDs)
                )
            }
            .sorted { $0.itemID < $1.itemID }

        let membershipByItemID = Dictionary(uniqueKeysWithValues: memberships.map { ($0.itemID, $0.groupIDs) })
        let customGroupNameByID = Dictionary(uniqueKeysWithValues: customGroups.map { ($0.groupID, $0.name) })

        let normalizedDocuments = documents.map { document in
            let groupNames = (membershipByItemID[document.itemID] ?? [])
                .compactMap { customGroupNameByID[$0] }

            return SearchIndexDocument(
                itemID: document.itemID,
                normalizedPlainText: normalizedSearchText(document.normalizedPlainText),
                noteMirror: sanitizedNoteMirror(document.noteMirror),
                groupTerms: groupNames,
                isPinned: document.isPinned
            )
        }

        let customGroupsWithCounts = customGroups.map { group in
            OrganizationGroupSummary(
                id: group.groupID,
                name: group.name,
                accentToken: group.accentToken,
                itemCount: memberships.filter { $0.groupIDs.contains(group.groupID) }.count
            )
        }

        let allSummary = OrganizationGroupSummary(
            id: .all,
            name: "All",
            itemCount: normalizedDocuments.count
        )
        let ungroupedSummary = OrganizationGroupSummary(
            id: .ungrouped,
            name: "Ungrouped",
            itemCount: normalizedDocuments.filter {
                (membershipByItemID[$0.itemID] ?? []).isEmpty
            }.count
        )

        return SearchIndexSnapshot(
            documents: normalizedDocuments,
            groups: [allSummary, ungroupedSummary] + customGroupsWithCounts,
            memberships: memberships.filter { $0.groupIDs.isEmpty == false || documentsByID[$0.itemID] != nil }
        )
    }

    private func sanitizedDocument(_ document: SearchIndexDocument) -> SearchIndexDocument {
        SearchIndexDocument(
            itemID: document.itemID,
            normalizedPlainText: normalizedSearchText(document.normalizedPlainText),
            noteMirror: sanitizedNoteMirror(document.noteMirror),
            groupTerms: document.groupTerms
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false },
            isPinned: document.isPinned
        )
    }

    private func sanitizedCustomGroup(_ group: OrganizationGroupSummary) -> OrganizationGroupSummary {
        OrganizationGroupSummary(
            id: group.groupID,
            name: group.name.trimmingCharacters(in: .whitespacesAndNewlines),
            accentToken: group.accentToken?.trimmingCharacters(in: .whitespacesAndNewlines),
            itemCount: group.itemCount
        )
    }

    private func customGroups(from groups: [OrganizationGroupSummary]) -> [OrganizationGroupSummary] {
        groups.filter { $0.groupID.isSystem == false }
    }

    private func normalizedSearchText(_ text: String?) -> String {
        guard let text else {
            return ""
        }

        return text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedNoteMirror(_ noteMirror: String?) -> String? {
        guard let noteMirror else {
            return nil
        }

        let trimmed = noteMirror.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func queryTokens(from normalizedQuery: String) -> [String] {
        normalizedQuery
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private func makeFTSMatchExpression(from normalizedQuery: String) -> String? {
        let tokens = queryTokens(from: normalizedQuery)
        guard tokens.isEmpty == false else {
            return nil
        }

        return tokens.map { "\($0)*" }.joined(separator: " AND ")
    }

    private static func defaultDatabaseURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseURL
            .appendingPathComponent("SlipBoard", isDirectory: true)
            .appendingPathComponent("SearchNotesOrganization", isDirectory: true)
            .appendingPathComponent("search-index.sqlite", isDirectory: false)
    }

    private func bindText(_ text: String, at index: Int32, in statement: OpaquePointer?) {
        _ = text.withCString { rawText in
            sqlite3_bind_text(statement, index, rawText, -1, sqliteTransientDestructor)
        }
    }
}

private func sortGroupIDs(_ lhs: OrganizationGroupID, _ rhs: OrganizationGroupID) -> Bool {
    lhs.id < rhs.id
}

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
