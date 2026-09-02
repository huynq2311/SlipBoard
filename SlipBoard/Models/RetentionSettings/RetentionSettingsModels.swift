import Foundation

enum RetentionSettingBounds {
    static let minItemCount = 100
    static let maxItemCount = 2_000
    static let itemCountStep = 100
    static let defaultItemCount = 2_000

    static let minCacheSizeMB = 100
    static let maxCacheSizeMB = 2_000
    static let cacheSizeStepMB = 100
    static let defaultCacheSizeMB = 500
}

enum RetentionTTLPolicy: String, CaseIterable, Identifiable, Hashable {
    case oneWeek = "1w"
    case twoWeeks = "2w"
    case oneMonth = "1mo"
    case threeMonths = "3mo"
    case never = "never"

    var id: String { rawValue }

    var settingsLabel: String {
        switch self {
        case .oneWeek:
            return "1w"
        case .twoWeeks:
            return "2w"
        case .oneMonth:
            return "1mo"
        case .threeMonths:
            return "3mo"
        case .never:
            return "Never"
        }
    }

    var menuBarLabel: String {
        switch self {
        case .never:
            return "∞"
        default:
            return settingsLabel
        }
    }

    var retentionInterval: TimeInterval? {
        switch self {
        case .oneWeek:
            return 7 * 24 * 60 * 60
        case .twoWeeks:
            return 14 * 24 * 60 * 60
        case .oneMonth:
            return 30 * 24 * 60 * 60
        case .threeMonths:
            return 90 * 24 * 60 * 60
        case .never:
            return nil
        }
    }

    func cutoffDate(relativeTo referenceDate: Date) -> Date? {
        guard let retentionInterval else { return nil }
        return referenceDate.addingTimeInterval(-retentionInterval)
    }
}

struct RetentionSettings: Hashable {
    var maxItemCount: Int
    var ttlPolicy: RetentionTTLPolicy
    var clearOnQuit: Bool
    var lastUpdatedAt: Date

    init(
        maxItemCount: Int = RetentionSettingBounds.defaultItemCount,
        ttlPolicy: RetentionTTLPolicy = .oneMonth,
        clearOnQuit: Bool = false,
        lastUpdatedAt: Date = .now
    ) {
        self.maxItemCount = RetentionSettings.clampValue(
            maxItemCount,
            minimum: RetentionSettingBounds.minItemCount,
            maximum: RetentionSettingBounds.maxItemCount,
            step: RetentionSettingBounds.itemCountStep
        )
        self.ttlPolicy = ttlPolicy
        self.clearOnQuit = clearOnQuit
        self.lastUpdatedAt = lastUpdatedAt
    }

    func updating(
        maxItemCount: Int? = nil,
        ttlPolicy: RetentionTTLPolicy? = nil,
        clearOnQuit: Bool? = nil,
        lastUpdatedAt: Date = .now
    ) -> RetentionSettings {
        RetentionSettings(
            maxItemCount: maxItemCount ?? self.maxItemCount,
            ttlPolicy: ttlPolicy ?? self.ttlPolicy,
            clearOnQuit: clearOnQuit ?? self.clearOnQuit,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    private static func clampValue(
        _ value: Int,
        minimum: Int,
        maximum: Int,
        step: Int
    ) -> Int {
        let clampedValue = min(max(value, minimum), maximum)
        let steppedValue = (clampedValue / step) * step
        return max(steppedValue, minimum)
    }
}

struct AssetCacheSettings: Hashable {
    var maxCacheSizeMB: Int
    var currentUsageBytes: Int64
    var lastClearedAt: Date?
    var lastSweepAt: Date?

    init(
        maxCacheSizeMB: Int = RetentionSettingBounds.defaultCacheSizeMB,
        currentUsageBytes: Int64 = 0,
        lastClearedAt: Date? = nil,
        lastSweepAt: Date? = nil
    ) {
        self.maxCacheSizeMB = AssetCacheSettings.clampValue(
            maxCacheSizeMB,
            minimum: RetentionSettingBounds.minCacheSizeMB,
            maximum: RetentionSettingBounds.maxCacheSizeMB,
            step: RetentionSettingBounds.cacheSizeStepMB
        )
        self.currentUsageBytes = max(currentUsageBytes, 0)
        self.lastClearedAt = lastClearedAt
        self.lastSweepAt = lastSweepAt
    }

    var maxCacheSizeBytes: Int64 {
        Int64(maxCacheSizeMB) * 1_024 * 1_024
    }

    var exceedsConfiguredLimit: Bool {
        currentUsageBytes > maxCacheSizeBytes
    }

    func updating(
        maxCacheSizeMB: Int? = nil,
        currentUsageBytes: Int64? = nil,
        lastClearedAt: Date? = nil,
        lastSweepAt: Date? = nil
    ) -> AssetCacheSettings {
        AssetCacheSettings(
            maxCacheSizeMB: maxCacheSizeMB ?? self.maxCacheSizeMB,
            currentUsageBytes: currentUsageBytes ?? self.currentUsageBytes,
            lastClearedAt: lastClearedAt ?? self.lastClearedAt,
            lastSweepAt: lastSweepAt ?? self.lastSweepAt
        )
    }

    private static func clampValue(
        _ value: Int,
        minimum: Int,
        maximum: Int,
        step: Int
    ) -> Int {
        let clampedValue = min(max(value, minimum), maximum)
        let steppedValue = (clampedValue / step) * step
        return max(steppedValue, minimum)
    }
}

enum RetentionCleanupTrigger: String, CaseIterable, Identifiable, Hashable {
    case appLaunch
    case appBecameActive
    case periodicSweep
    case settingsChanged
    case manualCacheClear
    case appQuit

    var id: String { rawValue }
}

enum RetentionClipKind: String, CaseIterable, Identifiable, Hashable {
    case text
    case code
    case image
    case file
    case url
    case color
    case richText

    var id: String { rawValue }
}

struct RetentionManagedClip: Identifiable, Hashable {
    let id: String
    var normalizedHash: String
    var kind: RetentionClipKind
    var capturedAt: Date
    var lastCopiedAt: Date
    var isPinned: Bool
    var pinnedAt: Date?
    var titleText: String
    var secondaryText: String?
    var metadataText: String
    var secondaryBadgeText: String?
    var sourceAppBundleID: String?
    var sourceAppDisplayName: String
    var sourceAppSymbolName: String?
    var sourceAppAccentToken: String
    var previewStyleKey: String
    var previewStyleHint: String?
    var filePaths: [String]
    var colorSwatches: [String]
    var richTextAvailable: Bool
    var estimatedByteSize: Int64
    var assetCacheKey: String?

    init(
        id: String,
        normalizedHash: String,
        kind: RetentionClipKind,
        capturedAt: Date,
        lastCopiedAt: Date,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        titleText: String,
        secondaryText: String? = nil,
        metadataText: String,
        secondaryBadgeText: String? = nil,
        sourceAppBundleID: String? = nil,
        sourceAppDisplayName: String,
        sourceAppSymbolName: String? = nil,
        sourceAppAccentToken: String = "accent.primary",
        previewStyleKey: String,
        previewStyleHint: String? = nil,
        filePaths: [String] = [],
        colorSwatches: [String] = [],
        richTextAvailable: Bool = false,
        estimatedByteSize: Int64 = 0,
        assetCacheKey: String? = nil
    ) {
        self.id = id
        self.normalizedHash = normalizedHash
        self.kind = kind
        self.capturedAt = capturedAt
        self.lastCopiedAt = lastCopiedAt
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.titleText = titleText
        self.secondaryText = secondaryText
        self.metadataText = metadataText
        self.secondaryBadgeText = secondaryBadgeText
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppDisplayName = sourceAppDisplayName
        self.sourceAppSymbolName = sourceAppSymbolName
        self.sourceAppAccentToken = sourceAppAccentToken
        self.previewStyleKey = previewStyleKey
        self.previewStyleHint = previewStyleHint
        self.filePaths = filePaths
        self.colorSwatches = colorSwatches
        self.richTextAvailable = richTextAvailable
        self.estimatedByteSize = max(estimatedByteSize, 0)
        self.assetCacheKey = assetCacheKey
    }
}

struct RetentionPersistenceSnapshot: Hashable {
    var retentionSettings: RetentionSettings
    var assetCacheSettings: AssetCacheSettings
    var storedClips: [RetentionManagedClip]
    var latestCleanupResult: RetentionCleanupResult?

    init(
        retentionSettings: RetentionSettings = RetentionSettings(),
        assetCacheSettings: AssetCacheSettings = AssetCacheSettings(),
        storedClips: [RetentionManagedClip] = [],
        latestCleanupResult: RetentionCleanupResult? = nil
    ) {
        self.retentionSettings = retentionSettings
        self.assetCacheSettings = assetCacheSettings
        self.storedClips = storedClips
        self.latestCleanupResult = latestCleanupResult
    }
}

struct RetentionCleanupRequest: Hashable {
    var trigger: RetentionCleanupTrigger
    var executedAt: Date
    var retentionSettings: RetentionSettings
    var assetCacheSettings: AssetCacheSettings
    var storedClips: [RetentionManagedClip]

    init(
        trigger: RetentionCleanupTrigger,
        executedAt: Date = .now,
        retentionSettings: RetentionSettings,
        assetCacheSettings: AssetCacheSettings,
        storedClips: [RetentionManagedClip]
    ) {
        self.trigger = trigger
        self.executedAt = executedAt
        self.retentionSettings = retentionSettings
        self.assetCacheSettings = assetCacheSettings
        self.storedClips = storedClips
    }

    var shouldWipeAllHistory: Bool {
        trigger == .appQuit && retentionSettings.clearOnQuit
    }

    var ttlCutoffDate: Date? {
        retentionSettings.ttlPolicy.cutoffDate(relativeTo: executedAt)
    }
}

struct RetentionCleanupPlan: Hashable {
    var trigger: RetentionCleanupTrigger
    var clipIDsToRemove: [String]
    var assetCacheKeysToRemove: [String]
    var skippedPinnedClipIDs: [String]
    var shouldWipeAllHistory: Bool

    init(
        trigger: RetentionCleanupTrigger,
        clipIDsToRemove: [String] = [],
        assetCacheKeysToRemove: [String] = [],
        skippedPinnedClipIDs: [String] = [],
        shouldWipeAllHistory: Bool = false
    ) {
        self.trigger = trigger
        self.clipIDsToRemove = clipIDsToRemove
        self.assetCacheKeysToRemove = assetCacheKeysToRemove
        self.skippedPinnedClipIDs = skippedPinnedClipIDs
        self.shouldWipeAllHistory = shouldWipeAllHistory
    }
}

struct RetentionCleanupResult: Hashable {
    var trigger: RetentionCleanupTrigger
    var removedClipCount: Int
    var removedAssetCount: Int
    var freedBytes: Int64
    var skippedPinnedClipCount: Int
    var remainingClipCount: Int
    var remainingPinnedClipCount: Int
    var didWipeAllHistory: Bool
    var completedAt: Date
    var statusMessage: String?

    init(
        trigger: RetentionCleanupTrigger,
        removedClipCount: Int = 0,
        removedAssetCount: Int = 0,
        freedBytes: Int64 = 0,
        skippedPinnedClipCount: Int = 0,
        remainingClipCount: Int = 0,
        remainingPinnedClipCount: Int = 0,
        didWipeAllHistory: Bool = false,
        completedAt: Date = .now,
        statusMessage: String? = nil
    ) {
        self.trigger = trigger
        self.removedClipCount = max(removedClipCount, 0)
        self.removedAssetCount = max(removedAssetCount, 0)
        self.freedBytes = max(freedBytes, 0)
        self.skippedPinnedClipCount = max(skippedPinnedClipCount, 0)
        self.remainingClipCount = max(remainingClipCount, 0)
        self.remainingPinnedClipCount = max(remainingPinnedClipCount, 0)
        self.didWipeAllHistory = didWipeAllHistory
        self.completedAt = completedAt
        self.statusMessage = statusMessage
    }
}

struct RetentionRuntimeSnapshot: Hashable {
    var retentionSettings: RetentionSettings
    var assetCacheSettings: AssetCacheSettings
    var latestCleanupResult: RetentionCleanupResult?
    var storedClipCount: Int
    var pinnedClipCount: Int

    init(
        retentionSettings: RetentionSettings = RetentionSettings(),
        assetCacheSettings: AssetCacheSettings = AssetCacheSettings(),
        latestCleanupResult: RetentionCleanupResult? = nil,
        storedClipCount: Int = 0,
        pinnedClipCount: Int = 0
    ) {
        self.retentionSettings = retentionSettings
        self.assetCacheSettings = assetCacheSettings
        self.latestCleanupResult = latestCleanupResult
        self.storedClipCount = max(storedClipCount, 0)
        self.pinnedClipCount = max(pinnedClipCount, 0)
    }
}
