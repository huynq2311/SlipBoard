import Foundation

enum RetentionSettingsMockFixtures {
    static let baseDate = Date(timeIntervalSince1970: 1_785_584_400)

    static let defaultSettings = RetentionSettings(
        maxItemCount: 2_000,
        ttlPolicy: .oneMonth,
        clearOnQuit: false,
        lastUpdatedAt: baseDate.addingTimeInterval(-60)
    )

    static let overflowSettings = RetentionSettings(
        maxItemCount: 300,
        ttlPolicy: .oneMonth,
        clearOnQuit: false,
        lastUpdatedAt: baseDate.addingTimeInterval(-1_200)
    )

    static let pinnedImmunitySettings = RetentionSettings(
        maxItemCount: 500,
        ttlPolicy: .oneWeek,
        clearOnQuit: false,
        lastUpdatedAt: baseDate.addingTimeInterval(-2_400)
    )

    static let clearOnQuitSettings = RetentionSettings(
        maxItemCount: 1_000,
        ttlPolicy: .threeMonths,
        clearOnQuit: true,
        lastUpdatedAt: baseDate.addingTimeInterval(-300)
    )

    static let cacheSettings = AssetCacheSettings(
        maxCacheSizeMB: 500,
        currentUsageBytes: 734 * 1_024 * 1_024,
        lastClearedAt: nil,
        lastSweepAt: baseDate.addingTimeInterval(-1_800)
    )

    static let pinnedImmuneClip = RetentionManagedClip(
        id: "clip-pinned-retention-01",
        normalizedHash: "hash-pinned-release-checklist",
        kind: .text,
        capturedAt: baseDate.addingTimeInterval(-(90 * 24 * 60 * 60)),
        lastCopiedAt: baseDate.addingTimeInterval(-(60 * 24 * 60 * 60)),
        isPinned: true,
        pinnedAt: baseDate.addingTimeInterval(-(89 * 24 * 60 * 60)),
        titleText: "Release checklist",
        secondaryText: "Pinned operational note",
        metadataText: "Pinned in menu bar",
        secondaryBadgeText: "Pinned",
        sourceAppBundleID: "com.apple.dt.Xcode",
        sourceAppDisplayName: "Xcode",
        sourceAppSymbolName: "hammer",
        sourceAppAccentToken: "accent.primary",
        previewStyleKey: "text",
        estimatedByteSize: 2_048
    )

    static let overflowRecentClips: [RetentionManagedClip] = [
        RetentionManagedClip(
            id: "clip-overflow-01",
            normalizedHash: "hash-overflow-01",
            kind: .code,
            capturedAt: baseDate.addingTimeInterval(-14_400),
            lastCopiedAt: baseDate.addingTimeInterval(-14_400),
            titleText: "xcodebuild -scheme SlipTray",
            secondaryText: "Oldest unpinned command",
            metadataText: "Terminal",
            sourceAppBundleID: "com.apple.Terminal",
            sourceAppDisplayName: "Terminal",
            sourceAppSymbolName: "terminal",
            sourceAppAccentToken: "accent.info",
            previewStyleKey: "code",
            previewStyleHint: "sh",
            estimatedByteSize: 4_096,
            assetCacheKey: "asset-overflow-01"
        ),
        RetentionManagedClip(
            id: "clip-overflow-02",
            normalizedHash: "hash-overflow-02",
            kind: .file,
            capturedAt: baseDate.addingTimeInterval(-10_800),
            lastCopiedAt: baseDate.addingTimeInterval(-10_800),
            titleText: "Retention Spec.pdf",
            secondaryText: "/Users/demo/Desktop/Retention Spec.pdf",
            metadataText: "Finder",
            secondaryBadgeText: "PDF",
            sourceAppBundleID: "com.apple.finder",
            sourceAppDisplayName: "Finder",
            sourceAppSymbolName: "folder",
            sourceAppAccentToken: "accent.warning",
            previewStyleKey: "file",
            previewStyleHint: "pdf",
            filePaths: ["/Users/demo/Desktop/Retention Spec.pdf"],
            estimatedByteSize: 8_192,
            assetCacheKey: "asset-overflow-02"
        ),
        RetentionManagedClip(
            id: "clip-overflow-03",
            normalizedHash: "hash-overflow-03",
            kind: .url,
            capturedAt: baseDate.addingTimeInterval(-7_200),
            lastCopiedAt: baseDate.addingTimeInterval(-7_200),
            titleText: "https://sliptray.local/retention",
            secondaryText: "Retention settings prototype",
            metadataText: "Safari",
            sourceAppBundleID: "com.apple.Safari",
            sourceAppDisplayName: "Safari",
            sourceAppSymbolName: "safari",
            sourceAppAccentToken: "accent.success",
            previewStyleKey: "url",
            estimatedByteSize: 1_024
        ),
        RetentionManagedClip(
            id: "clip-overflow-04",
            normalizedHash: "hash-overflow-04",
            kind: .text,
            capturedAt: baseDate.addingTimeInterval(-1_800),
            lastCopiedAt: baseDate.addingTimeInterval(-900),
            titleText: "Retention cleanup summary",
            secondaryText: "Most recent item",
            metadataText: "Notes",
            sourceAppBundleID: "com.apple.Notes",
            sourceAppDisplayName: "Notes",
            sourceAppSymbolName: "note.text",
            sourceAppAccentToken: "accent.primary",
            previewStyleKey: "text",
            estimatedByteSize: 1_536
        )
    ]

    static let ttlMixedClips: [RetentionManagedClip] = [
        pinnedImmuneClip,
        RetentionManagedClip(
            id: "clip-expired-unpinned-01",
            normalizedHash: "hash-expired-unpinned-01",
            kind: .image,
            capturedAt: baseDate.addingTimeInterval(-(16 * 24 * 60 * 60)),
            lastCopiedAt: baseDate.addingTimeInterval(-(16 * 24 * 60 * 60)),
            titleText: "Sprint board screenshot",
            secondaryText: "Older than one week",
            metadataText: "Preview",
            sourceAppBundleID: "com.apple.Preview",
            sourceAppDisplayName: "Preview",
            sourceAppSymbolName: "photo",
            sourceAppAccentToken: "accent.warning",
            previewStyleKey: "image",
            estimatedByteSize: 512_000,
            assetCacheKey: "asset-expired-01"
        ),
        RetentionManagedClip(
            id: "clip-fresh-unpinned-01",
            normalizedHash: "hash-fresh-unpinned-01",
            kind: .text,
            capturedAt: baseDate.addingTimeInterval(-(2 * 24 * 60 * 60)),
            lastCopiedAt: baseDate.addingTimeInterval(-(2 * 24 * 60 * 60)),
            titleText: "Keep this recent note",
            secondaryText: "Still inside one-week TTL",
            metadataText: "Notes",
            sourceAppBundleID: "com.apple.Notes",
            sourceAppDisplayName: "Notes",
            sourceAppSymbolName: "note.text",
            sourceAppAccentToken: "accent.primary",
            previewStyleKey: "text",
            estimatedByteSize: 1_024
        )
    ]

    static let overflowSnapshot = RetentionPersistenceSnapshot(
        retentionSettings: overflowSettings,
        assetCacheSettings: cacheSettings,
        storedClips: [pinnedImmuneClip] + overflowRecentClips,
        latestCleanupResult: nil
    )

    static let pinnedImmunitySnapshot = RetentionPersistenceSnapshot(
        retentionSettings: pinnedImmunitySettings,
        assetCacheSettings: cacheSettings,
        storedClips: ttlMixedClips,
        latestCleanupResult: nil
    )

    static let overflowCleanupRequest = RetentionCleanupRequest(
        trigger: .settingsChanged,
        executedAt: baseDate,
        retentionSettings: overflowSettings,
        assetCacheSettings: cacheSettings,
        storedClips: overflowSnapshot.storedClips
    )

    static let pinnedImmunityCleanupRequest = RetentionCleanupRequest(
        trigger: .periodicSweep,
        executedAt: baseDate,
        retentionSettings: pinnedImmunitySettings,
        assetCacheSettings: cacheSettings,
        storedClips: pinnedImmunitySnapshot.storedClips
    )

    static let manualCacheClearRequest = RetentionCleanupRequest(
        trigger: .manualCacheClear,
        executedAt: baseDate,
        retentionSettings: defaultSettings,
        assetCacheSettings: cacheSettings,
        storedClips: ttlMixedClips
    )

    static let overflowCleanupPlan = RetentionCleanupPlan(
        trigger: .settingsChanged,
        clipIDsToRemove: ["clip-overflow-01", "clip-overflow-02"],
        assetCacheKeysToRemove: ["asset-overflow-01", "asset-overflow-02"],
        skippedPinnedClipIDs: ["clip-pinned-retention-01"],
        shouldWipeAllHistory: false
    )

    static let pinnedImmunityPlan = RetentionCleanupPlan(
        trigger: .periodicSweep,
        clipIDsToRemove: ["clip-expired-unpinned-01"],
        assetCacheKeysToRemove: ["asset-expired-01"],
        skippedPinnedClipIDs: ["clip-pinned-retention-01"],
        shouldWipeAllHistory: false
    )

    static let clearOnQuitPlan = RetentionCleanupPlan(
        trigger: .appQuit,
        clipIDsToRemove: ttlMixedClips.map(\.id),
        assetCacheKeysToRemove: ["asset-expired-01"],
        skippedPinnedClipIDs: [],
        shouldWipeAllHistory: true
    )

    static let overflowCleanupResult = RetentionCleanupResult(
        trigger: .settingsChanged,
        removedClipCount: 2,
        removedAssetCount: 2,
        freedBytes: 12_288,
        skippedPinnedClipCount: 1,
        remainingClipCount: 3,
        remainingPinnedClipCount: 1,
        didWipeAllHistory: false,
        completedAt: baseDate,
        statusMessage: "Trimmed 2 old items to stay within the maximum item limit."
    )

    static let pinnedImmunityCleanupResult = RetentionCleanupResult(
        trigger: .periodicSweep,
        removedClipCount: 1,
        removedAssetCount: 1,
        freedBytes: 512_000,
        skippedPinnedClipCount: 1,
        remainingClipCount: 2,
        remainingPinnedClipCount: 1,
        didWipeAllHistory: false,
        completedAt: baseDate,
        statusMessage: "Removed 1 expired item and preserved pinned clips."
    )

    static let manualCacheClearResult = RetentionCleanupResult(
        trigger: .manualCacheClear,
        removedClipCount: 0,
        removedAssetCount: 12,
        freedBytes: cacheSettings.currentUsageBytes,
        skippedPinnedClipCount: 0,
        remainingClipCount: manualCacheClearRequest.storedClips.count,
        remainingPinnedClipCount: manualCacheClearRequest.storedClips.filter(\.isPinned).count,
        didWipeAllHistory: false,
        completedAt: baseDate,
        statusMessage: "Cleared 734 MB of local asset cache."
    )

    static let clearOnQuitResult = RetentionCleanupResult(
        trigger: .appQuit,
        removedClipCount: ttlMixedClips.count,
        removedAssetCount: 1,
        freedBytes: 512_000,
        skippedPinnedClipCount: 0,
        remainingClipCount: 0,
        remainingPinnedClipCount: 0,
        didWipeAllHistory: true,
        completedAt: baseDate,
        statusMessage: "Cleared history and asset cache on app quit."
    )

    static let runtimeSnapshot = RetentionRuntimeSnapshot(
        retentionSettings: defaultSettings,
        assetCacheSettings: cacheSettings,
        latestCleanupResult: overflowCleanupResult,
        storedClipCount: overflowSnapshot.storedClips.count,
        pinnedClipCount: overflowSnapshot.storedClips.filter(\.isPinned).count
    )
}
