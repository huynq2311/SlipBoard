import Foundation

struct ClipRecord: Equatable, Sendable {
    let id: String
    let contentHash: String
    let contentKind: ClipboardContentKind
    let firstSeenAt: Date
    let lastCopiedAt: Date
    let totalCopyCount: Int
    let isPinned: Bool
    let pinnedAt: Date?
    let sourceAppBundle: String?
    let payloadHash: String?
    let syncState: String

    init(
        id: String,
        contentHash: String,
        contentKind: ClipboardContentKind,
        firstSeenAt: Date,
        lastCopiedAt: Date,
        totalCopyCount: Int,
        isPinned: Bool,
        pinnedAt: Date?,
        sourceAppBundle: String?,
        payloadHash: String?,
        syncState: String = "pending"
    ) {
        self.id = id
        self.contentHash = contentHash
        self.contentKind = contentKind
        self.firstSeenAt = firstSeenAt
        self.lastCopiedAt = lastCopiedAt
        self.totalCopyCount = totalCopyCount
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.sourceAppBundle = sourceAppBundle
        self.payloadHash = payloadHash
        self.syncState = syncState
    }
}

struct ClipEventRecord: Equatable, Sendable {
    let eventID: String
    let clipID: String
    let copiedAt: Date
    let sourceAppBundle: String?

    init(
        eventID: String,
        clipID: String,
        copiedAt: Date,
        sourceAppBundle: String?
    ) {
        self.eventID = eventID
        self.clipID = clipID
        self.copiedAt = copiedAt
        self.sourceAppBundle = sourceAppBundle
    }
}

struct SourceAppRecord: Equatable, Sendable {
    let bundleID: String
    let appName: String
    let iconCachePath: String?
    let lastSeenAt: Date

    init(
        bundleID: String,
        appName: String,
        iconCachePath: String?,
        lastSeenAt: Date
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.iconCachePath = iconCachePath
        self.lastSeenAt = lastSeenAt
    }
}

struct SettingsRecord: Equatable, Sendable {
    let id: String
    let maxItemCount: Int
    let ttlDays: Int
    let clearOnQuit: Bool
    let excludedBundleIDs: String
    let hotkeysJSON: String?
    let pauseStateJSON: String?
    let appLockEnabled: Bool
    let autoLockMinutes: Int
    let privacyModeEnabled: Bool

    init(
        id: String = "settings-v1",
        maxItemCount: Int = 2000,
        ttlDays: Int = 30,
        clearOnQuit: Bool = false,
        excludedBundleIDs: String = "[]",
        hotkeysJSON: String? = nil,
        pauseStateJSON: String? = nil,
        appLockEnabled: Bool = false,
        autoLockMinutes: Int = 0,
        privacyModeEnabled: Bool = false
    ) {
        self.id = id
        self.maxItemCount = maxItemCount
        self.ttlDays = ttlDays
        self.clearOnQuit = clearOnQuit
        self.excludedBundleIDs = excludedBundleIDs
        self.hotkeysJSON = hotkeysJSON
        self.pauseStateJSON = pauseStateJSON
        self.appLockEnabled = appLockEnabled
        self.autoLockMinutes = autoLockMinutes
        self.privacyModeEnabled = privacyModeEnabled
    }
}

struct SnippetRecord: Equatable, Sendable {
    let id: String
    let title: String
    let contentEncryptedPath: String?
    let contentKind: String
    let hotkeyJSON: String?
    let createdAt: Date
    let updatedAt: Date
    let isPinned: Bool

    init(
        id: String,
        title: String,
        contentEncryptedPath: String?,
        contentKind: String = "text",
        hotkeyJSON: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.contentEncryptedPath = contentEncryptedPath
        self.contentKind = contentKind
        self.hotkeyJSON = hotkeyJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }
}

