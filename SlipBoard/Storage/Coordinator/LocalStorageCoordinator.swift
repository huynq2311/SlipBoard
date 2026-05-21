import Foundation
import SQLite3
import CommonCrypto

actor LocalStorageCoordinator: StorageCoordinatorProtocol {
    private let db: SQLiteDatabase
    private let config: StorageConfig
    private let payloadStore: PayloadStoreProtocol
    private let assetStore: AssetStoreProtocol
    private let ftsIndex: FTSIndexProtocol
    private let thumbnailCache: ThumbnailCacheProtocol
    private var lockStateProvider: LockStateProviding
    
    private var pendingPayloadDeletions = Set<String>()
    private var pendingAssetDeletions = Set<String>()
    
    init(
        db: SQLiteDatabase,
        config: StorageConfig,
        payloadStore: PayloadStoreProtocol,
        assetStore: AssetStoreProtocol,
        ftsIndex: FTSIndexProtocol,
        thumbnailCache: ThumbnailCacheProtocol,
        lockStateProvider: LockStateProviding
    ) {
        self.db = db
        self.config = config
        self.payloadStore = payloadStore
        self.assetStore = assetStore
        self.ftsIndex = ftsIndex
        self.thumbnailCache = thumbnailCache
        self.lockStateProvider = lockStateProvider
        
        // Execute connection configurations
        try? db.execute("PRAGMA journal_mode=WAL;")
        try? db.execute("PRAGMA wal_autocheckpoint=1000;")
        try? db.execute("PRAGMA busy_timeout=5000;")
        try? db.execute("PRAGMA auto_vacuum=INCREMENTAL;")
        
        // Observe lock state changes to clear NSCache / thumbnails
        self.lockStateProvider.onLockStateChanged = { [weak self] isLocked in
            if isLocked {
                Task {
                    try? await self?.clearOnLock()
                }
            }
        }
    }
    
    private func clearOnLock() throws {
        try thumbnailCache.clearAll()
    }
    
    func capture(_ snapshot: RawPasteboardSnapshot) async throws {
        guard !lockStateProvider.isLocked else {
            throw StorageError.locked
        }
        
        let settings = try getSettings()
        
        // Parse excluded bundle IDs
        let excludedIDs: [String]
        if let data = settings.excludedBundleIDs.data(using: .utf8) {
            excludedIDs = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        } else {
            excludedIDs = []
        }
        
        let pauseState = decodePauseState(from: settings.pauseStateJSON)
        let filterConfig = AppFilterConfig(excludedBundleIDs: excludedIDs, pauseState: pauseState)
        let sourceApp = SourceAppContext(bundleID: snapshot.sourceBundleID, appName: snapshot.sourceAppName)
        
        guard AppFilter.shouldCapture(sourceApp, config: filterConfig, referenceDate: snapshot.capturedAt) else {
            return
        }
        
        let classified = ContentClassifier.classify(snapshot)
        let contentHash = computeContentHash(for: snapshot)
        
        // Check if existing record exists
        let existingInfo = try checkExisting(contentHash: contentHash)
        
        let clipID = existingInfo?.id ?? UUID().uuidString
        let eventID = UUID().uuidString
        
        // Extract payload data
        var payloadData: Data?
        if let text = snapshot.plainText, !text.isEmpty {
            payloadData = text.data(using: .utf8)
        } else if let imageData = snapshot.imageData, !imageData.isEmpty {
            payloadData = imageData
        } else if let fileURLs = snapshot.fileURLs, !fileURLs.isEmpty {
            let joined = fileURLs.map(\.path).joined(separator: "\n")
            payloadData = joined.data(using: .utf8)
        } else if let rtf = snapshot.attributedStringData, !rtf.isEmpty {
            payloadData = rtf
        }
        
        // 1. Filesystem write first
        var payloadHash: String? = nil
        if let pData = payloadData {
            _ = try payloadStore.write(pData, hash: contentHash)
            payloadHash = contentHash
        }
        
        if classified.itemType == .image, let imgData = snapshot.imageData {
            _ = try assetStore.write(imgData, forItemID: clipID, ext: "png")
            try? thumbnailCache.write(imgData, forItemID: clipID)
        }
        
        // 2. Database commit second
        try db.transaction {
            if let bundleID = snapshot.sourceBundleID {
                let appName = snapshot.sourceAppName ?? "Unknown App"
                let insertAppSQL = """
                INSERT INTO source_apps (bundle_id, app_name, last_seen_at)
                VALUES (?, ?, ?)
                ON CONFLICT(bundle_id) DO UPDATE SET
                    app_name = excluded.app_name,
                    last_seen_at = excluded.last_seen_at;
                """
                let appStmt = try db.prepare(insertAppSQL)
                defer { appStmt.finalize() }
                try appStmt.bindText(bundleID, at: 1)
                try appStmt.bindText(appName, at: 2)
                try appStmt.bindDouble(snapshot.capturedAt.timeIntervalSince1970, at: 3)
                _ = try appStmt.step()
            }
            
            if existingInfo != nil {
                // Update-in-place
                let updateClipSQL = """
                UPDATE clips SET
                    last_copied_at = ?,
                    total_copy_count = total_copy_count + 1,
                    source_app_bundle = ?
                WHERE id = ?;
                """
                let clipStmt = try db.prepare(updateClipSQL)
                defer { clipStmt.finalize() }
                try clipStmt.bindDouble(snapshot.capturedAt.timeIntervalSince1970, at: 1)
                if let bundleID = snapshot.sourceBundleID {
                    try clipStmt.bindText(bundleID, at: 2)
                } else {
                    try clipStmt.bindNull(at: 2)
                }
                try clipStmt.bindText(clipID, at: 3)
                _ = try clipStmt.step()
            } else {
                // Insert new
                let insertClipSQL = """
                INSERT INTO clips (id, content_hash, content_kind, first_seen_at, last_copied_at, total_copy_count, is_pinned, source_app_bundle, payload_hash, sync_state)
                VALUES (?, ?, ?, ?, ?, 1, 0, ?, ?, 'pending');
                """
                let clipStmt = try db.prepare(insertClipSQL)
                defer { clipStmt.finalize() }
                try clipStmt.bindText(clipID, at: 1)
                try clipStmt.bindText(contentHash, at: 2)
                try clipStmt.bindText(classified.itemType.rawValue, at: 3)
                try clipStmt.bindDouble(snapshot.capturedAt.timeIntervalSince1970, at: 4)
                try clipStmt.bindDouble(snapshot.capturedAt.timeIntervalSince1970, at: 5)
                if let bundleID = snapshot.sourceBundleID {
                    try clipStmt.bindText(bundleID, at: 6)
                } else {
                    try clipStmt.bindNull(at: 6)
                }
                if let pHash = payloadHash {
                    try clipStmt.bindText(pHash, at: 7)
                } else {
                    try clipStmt.bindNull(at: 7)
                }
                _ = try clipStmt.step()
                
                // Index in FTS
                let normText = FTSNormalizer.normalize(snapshot.plainText ?? "")
                try ftsIndex.insert(clipID: clipID, normalizedText: normText, note: "")
            }
            
            // Insert event
            let insertEventSQL = """
            INSERT INTO clip_events (event_id, clip_id, copied_at, source_app_bundle)
            VALUES (?, ?, ?, ?);
            """
            let eventStmt = try db.prepare(insertEventSQL)
            defer { eventStmt.finalize() }
            try eventStmt.bindText(eventID, at: 1)
            try eventStmt.bindText(clipID, at: 2)
            try eventStmt.bindDouble(snapshot.capturedAt.timeIntervalSince1970, at: 3)
            if let bundleID = snapshot.sourceBundleID {
                try eventStmt.bindText(bundleID, at: 4)
            } else {
                try eventStmt.bindNull(at: 4)
            }
            _ = try eventStmt.step()
        }
        
        // WAL check-pointing and vaccuuming
        performMaintenance()
    }
    
    func runRetentionSweep(config: RetentionConfig) async throws {
        guard !lockStateProvider.isLocked else {
            throw StorageError.locked
        }
        
        let selectSQL = "SELECT id, last_copied_at, is_pinned FROM clips ORDER BY last_copied_at DESC;"
        let stmt = try db.prepare(selectSQL)
        
        var items = [ItemRetentionSnapshot]()
        var index = 0
        while try stmt.step() {
            let id = stmt.columnText(at: 0) ?? ""
            let lastCopied = Date(timeIntervalSince1970: stmt.columnDouble(at: 1))
            let isPinned = stmt.columnInt(at: 2) != 0
            items.append(ItemRetentionSnapshot(itemID: id, createdAt: lastCopied, isPinned: isPinned, rankIndex: index))
            index += 1
        }
        stmt.finalize()
        
        let idsToRemove: [String]
        if config.clearOnQuit {
            idsToRemove = items.filter { !$0.isPinned }.map { $0.itemID }
        } else {
            idsToRemove = RetentionEvaluator.itemsToRemove(from: items, config: config, referenceDate: Date())
        }
        
        guard !idsToRemove.isEmpty else { return }
        
        // Fetch payload hashes to add to pending deletions
        let placeholders = Array(repeating: "?", count: idsToRemove.count).joined(separator: ", ")
        let fetchSQL = "SELECT id, payload_hash FROM clips WHERE id IN (\(placeholders));"
        let fetchStmt = try db.prepare(fetchSQL)
        for (index, id) in idsToRemove.enumerated() {
            try fetchStmt.bindText(id, at: index + 1)
        }
        while try fetchStmt.step() {
            let clipID = fetchStmt.columnText(at: 0) ?? ""
            if let payloadHash = fetchStmt.columnText(at: 1) {
                pendingPayloadDeletions.insert(payloadHash)
            }
            pendingAssetDeletions.insert(clipID)
        }
        fetchStmt.finalize()
        
        // Delete in transaction
        try db.transaction {
            let deleteSQL = "DELETE FROM clips WHERE id IN (\(placeholders));"
            let deleteStmt = try db.prepare(deleteSQL)
            for (index, id) in idsToRemove.enumerated() {
                try deleteStmt.bindText(id, at: index + 1)
            }
            _ = try deleteStmt.step()
            deleteStmt.finalize()
            
            for id in idsToRemove {
                try ftsIndex.delete(clipID: id)
            }
        }
        
        // Process orphans asynchronously
        await processPendingDeletions()
        
        performMaintenance()
    }
    
    func search(query: String) async throws -> [ClipRecord] {
        guard !lockStateProvider.isLocked else {
            throw StorageError.locked
        }
        
        let ftsResults = try ftsIndex.search(query: query)
        guard !ftsResults.isEmpty else { return [] }
        
        let clipIDs = ftsResults.map { $0.clipID }
        let placeholders = Array(repeating: "?", count: clipIDs.count).joined(separator: ", ")
        let sql = "SELECT id, content_hash, content_kind, first_seen_at, last_copied_at, total_copy_count, is_pinned, pinned_at, source_app_bundle, payload_hash, sync_state FROM clips WHERE id IN (\(placeholders));"
        
        let stmt = try db.prepare(sql)
        defer { stmt.finalize() }
        
        for (index, id) in clipIDs.enumerated() {
            try stmt.bindText(id, at: index + 1)
        }
        
        var clipsDict = [String: ClipRecord]()
        while try stmt.step() {
            let id = stmt.columnText(at: 0) ?? ""
            let contentHash = stmt.columnText(at: 1) ?? ""
            let contentKindStr = stmt.columnText(at: 2) ?? "text"
            let contentKind = ClipboardContentKind(rawValue: contentKindStr) ?? .text
            let firstSeenAt = Date(timeIntervalSince1970: stmt.columnDouble(at: 3))
            let lastCopiedAt = Date(timeIntervalSince1970: stmt.columnDouble(at: 4))
            let totalCopyCount = stmt.columnInt(at: 5)
            let isPinned = stmt.columnInt(at: 6) != 0
            let pinnedAtVal = stmt.columnDouble(at: 7)
            let pinnedAt = pinnedAtVal > 0 ? Date(timeIntervalSince1970: pinnedAtVal) : nil
            let sourceAppBundle = stmt.columnText(at: 8)
            let payloadHash = stmt.columnText(at: 9)
            let syncState = stmt.columnText(at: 10) ?? "pending"
            
            clipsDict[id] = ClipRecord(
                id: id,
                contentHash: contentHash,
                contentKind: contentKind,
                firstSeenAt: firstSeenAt,
                lastCopiedAt: lastCopiedAt,
                totalCopyCount: totalCopyCount,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                sourceAppBundle: sourceAppBundle,
                payloadHash: payloadHash,
                syncState: syncState
            )
        }
        
        return clipIDs.compactMap { clipsDict[$0] }
    }
    
    func timeline(limit: Int, before: Date?) async throws -> [ClipEventRecord] {
        guard !lockStateProvider.isLocked else {
            throw StorageError.locked
        }
        
        var sql = "SELECT event_id, clip_id, copied_at, source_app_bundle FROM clip_events"
        if before != nil {
            sql += " WHERE copied_at < ?"
        }
        sql += " ORDER BY copied_at DESC LIMIT ?;"
        
        let stmt = try db.prepare(sql)
        defer { stmt.finalize() }
        
        var bindIndex = 1
        if let before = before {
            try stmt.bindDouble(before.timeIntervalSince1970, at: bindIndex)
            bindIndex += 1
        }
        try stmt.bindInt(limit, at: bindIndex)
        
        var results = [ClipEventRecord]()
        while try stmt.step() {
            let eventID = stmt.columnText(at: 0) ?? ""
            let clipID = stmt.columnText(at: 1) ?? ""
            let copiedAt = Date(timeIntervalSince1970: stmt.columnDouble(at: 2))
            let sourceAppBundle = stmt.columnText(at: 3)
            results.append(ClipEventRecord(eventID: eventID, clipID: clipID, copiedAt: copiedAt, sourceAppBundle: sourceAppBundle))
        }
        return results
    }
    
    func dedupedFeed(limit: Int, before: Date?) async throws -> [ClipRecord] {
        guard !lockStateProvider.isLocked else {
            throw StorageError.locked
        }
        
        var sql = "SELECT id, content_hash, content_kind, first_seen_at, last_copied_at, total_copy_count, is_pinned, pinned_at, source_app_bundle, payload_hash, sync_state FROM clips"
        if before != nil {
            sql += " WHERE last_copied_at < ?"
        }
        sql += " ORDER BY last_copied_at DESC LIMIT ?;"
        
        let stmt = try db.prepare(sql)
        defer { stmt.finalize() }
        
        var bindIndex = 1
        if let before = before {
            try stmt.bindDouble(before.timeIntervalSince1970, at: bindIndex)
            bindIndex += 1
        }
        try stmt.bindInt(limit, at: bindIndex)
        
        var results = [ClipRecord]()
        while try stmt.step() {
            let id = stmt.columnText(at: 0) ?? ""
            let contentHash = stmt.columnText(at: 1) ?? ""
            let contentKindStr = stmt.columnText(at: 2) ?? "text"
            let contentKind = ClipboardContentKind(rawValue: contentKindStr) ?? .text
            let firstSeenAt = Date(timeIntervalSince1970: stmt.columnDouble(at: 3))
            let lastCopiedAt = Date(timeIntervalSince1970: stmt.columnDouble(at: 4))
            let totalCopyCount = stmt.columnInt(at: 5)
            let isPinned = stmt.columnInt(at: 6) != 0
            let pinnedAtVal = stmt.columnDouble(at: 7)
            let pinnedAt = pinnedAtVal > 0 ? Date(timeIntervalSince1970: pinnedAtVal) : nil
            let sourceAppBundle = stmt.columnText(at: 8)
            let payloadHash = stmt.columnText(at: 9)
            let syncState = stmt.columnText(at: 10) ?? "pending"
            
            results.append(ClipRecord(
                id: id,
                contentHash: contentHash,
                contentKind: contentKind,
                firstSeenAt: firstSeenAt,
                lastCopiedAt: lastCopiedAt,
                totalCopyCount: totalCopyCount,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                sourceAppBundle: sourceAppBundle,
                payloadHash: payloadHash,
                syncState: syncState
            ))
        }
        return results
    }
    
    // MARK: - Helpers
    
    private func getSettings() throws -> SettingsRecord {
        let sql = """
        SELECT id, max_item_count, ttl_days, clear_on_quit, excluded_bundle_ids, hotkeys_json, pause_state_json, app_lock_enabled, auto_lock_minutes, privacy_mode_enabled
        FROM settings
        WHERE id = 'settings-v1';
        """
        let stmt = try db.prepare(sql)
        defer { stmt.finalize() }
        if try stmt.step() {
            let id = stmt.columnText(at: 0) ?? "settings-v1"
            let maxItemCount = stmt.columnInt(at: 1)
            let ttlDays = stmt.columnInt(at: 2)
            let clearOnQuit = stmt.columnInt(at: 3) != 0
            let excludedBundleIDs = stmt.columnText(at: 4) ?? "[]"
            let hotkeysJSON = stmt.columnText(at: 5)
            let pauseStateJSON = stmt.columnText(at: 6)
            let appLockEnabled = stmt.columnInt(at: 7) != 0
            let autoLockMinutes = stmt.columnInt(at: 8)
            let privacyModeEnabled = stmt.columnInt(at: 9) != 0
            return SettingsRecord(
                id: id,
                maxItemCount: maxItemCount,
                ttlDays: ttlDays,
                clearOnQuit: clearOnQuit,
                excludedBundleIDs: excludedBundleIDs,
                hotkeysJSON: hotkeysJSON,
                pauseStateJSON: pauseStateJSON,
                appLockEnabled: appLockEnabled,
                autoLockMinutes: autoLockMinutes,
                privacyModeEnabled: privacyModeEnabled
            )
        }
        return SettingsRecord()
    }
    
    private func checkExisting(contentHash: String) throws -> (id: String, totalCopyCount: Int)? {
        let sql = "SELECT id, total_copy_count FROM clips WHERE content_hash = ?;"
        let stmt = try db.prepare(sql)
        defer { stmt.finalize() }
        try stmt.bindText(contentHash, at: 1)
        if try stmt.step() {
            let id = stmt.columnText(at: 0) ?? ""
            let count = stmt.columnInt(at: 1)
            return (id, count)
        }
        return nil
    }
    
    private func computeContentHash(for snapshot: RawPasteboardSnapshot) -> String {
        if let text = snapshot.plainText, !text.isEmpty {
            return sha256(text)
        } else if let imageData = snapshot.imageData, !imageData.isEmpty {
            return sha256(imageData)
        } else if let fileURLs = snapshot.fileURLs, !fileURLs.isEmpty {
            let joined = fileURLs.map(\.path).joined(separator: "\n")
            return sha256(joined)
        } else if let rtf = snapshot.attributedStringData, !rtf.isEmpty {
            return sha256(rtf)
        }
        return sha256(UUID().uuidString)
    }
    
    private func sha256(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return sha256(data)
    }
    
    private struct PauseStateCodable: Codable {
        let type: String
        let until: Date?
    }
    
    private func decodePauseState(from json: String?) -> PauseState {
        guard let json = json, let data = json.data(using: .utf8),
              let codable = try? JSONDecoder().decode(PauseStateCodable.self, from: data) else {
            return .active
        }
        switch codable.type {
        case "pausedUntil":
            if let date = codable.until {
                return .pausedUntil(date)
            } else {
                return .active
            }
        case "pausedIndefinitely":
            return .pausedIndefinitely
        default:
            return .active
        }
    }
    
    private func processPendingDeletions() async {
        let hashes = Array(pendingPayloadDeletions)
        pendingPayloadDeletions.removeAll()
        
        for hash in hashes {
            if !hasClipWithPayloadHash(hash) {
                try? payloadStore.delete(hash: hash)
            }
        }
        
        let clipIDs = Array(pendingAssetDeletions)
        pendingAssetDeletions.removeAll()
        
        for clipID in clipIDs {
            try? assetStore.delete(forItemID: clipID)
            try? thumbnailCache.delete(forItemID: clipID)
        }
    }
    
    private func hasClipWithPayloadHash(_ hash: String) -> Bool {
        let sql = "SELECT 1 FROM clips WHERE payload_hash = ? LIMIT 1;"
        guard let stmt = try? db.prepare(sql) else { return false }
        defer { stmt.finalize() }
        _ = try? stmt.bindText(hash, at: 1)
        return (try? stmt.step()) == true
    }
    
    private func performMaintenance() {
        try? db.execute("PRAGMA wal_checkpoint(PASSIVE);")
        try? db.execute("PRAGMA incremental_vacuum(50);")
    }
}
