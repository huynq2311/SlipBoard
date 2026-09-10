import Foundation

final class RetentionCleanupCoordinator: RetentionCleanupCoordinating {
    private let retentionStore: RetentionSettingsStoring
    private let assetCacheCoordinator: AssetCacheAccounting

    init(
        retentionStore: RetentionSettingsStoring,
        assetCacheCoordinator: AssetCacheAccounting
    ) {
        self.retentionStore = retentionStore
        self.assetCacheCoordinator = assetCacheCoordinator
    }

    func makeCleanupPlan(for request: RetentionCleanupRequest) -> RetentionCleanupPlan {
        if request.shouldWipeAllHistory {
            return RetentionCleanupPlan(
                trigger: request.trigger,
                clipIDsToRemove: request.storedClips.map(\.id),
                assetCacheKeysToRemove: request.storedClips.compactMap(\.assetCacheKey),
                skippedPinnedClipIDs: [],
                shouldWipeAllHistory: true
            )
        }

        let pinnedIDs = request.storedClips.filter(\.isPinned).map(\.id)
        var clipIDsToRemove = Set<String>()
        var assetCacheKeysToRemove = Set<String>()

        if let cutoffDate = request.ttlCutoffDate {
            for clip in request.storedClips where clip.isPinned == false && clip.lastCopiedAt < cutoffDate {
                clipIDsToRemove.insert(clip.id)
                if let assetCacheKey = clip.assetCacheKey {
                    assetCacheKeysToRemove.insert(assetCacheKey)
                }
            }
        }

        let survivingUnpinned = request.storedClips
            .filter { $0.isPinned == false && clipIDsToRemove.contains($0.id) == false }
            .sorted(by: Self.sortNewestFirst)

        if survivingUnpinned.count > request.retentionSettings.maxItemCount {
            for clip in survivingUnpinned.dropFirst(request.retentionSettings.maxItemCount) {
                clipIDsToRemove.insert(clip.id)
                if let assetCacheKey = clip.assetCacheKey {
                    assetCacheKeysToRemove.insert(assetCacheKey)
                }
            }
        }

        return RetentionCleanupPlan(
            trigger: request.trigger,
            clipIDsToRemove: Array(clipIDsToRemove).sorted(),
            assetCacheKeysToRemove: Array(assetCacheKeysToRemove).sorted(),
            skippedPinnedClipIDs: pinnedIDs,
            shouldWipeAllHistory: false
        )
    }

    func executeCleanup(for request: RetentionCleanupRequest) -> RetentionCleanupResult {
        if request.trigger == .manualCacheClear {
            return executeManualCacheClear(for: request)
        }

        let plan = makeCleanupPlan(for: request)

        if plan.shouldWipeAllHistory == false && plan.clipIDsToRemove.isEmpty && request.assetCacheSettings.exceedsConfiguredLimit == false {
            let usage = assetCacheCoordinator.refreshUsage()
            let assetSettings = request.assetCacheSettings.updating(
                currentUsageBytes: usage.currentUsageBytes,
                lastSweepAt: usage.lastSweepAt
            )
            _ = retentionStore.saveAssetCacheSettings(assetSettings)
            return finalizeResult(
                RetentionCleanupResult(
                    trigger: request.trigger,
                    skippedPinnedClipCount: plan.skippedPinnedClipIDs.count,
                    remainingClipCount: request.storedClips.count,
                    remainingPinnedClipCount: request.storedClips.filter(\.isPinned).count,
                    completedAt: .now,
                    statusMessage: plan.skippedPinnedClipIDs.isEmpty
                        ? "No cleanup was needed."
                        : "Pinned items were preserved and no cleanup was needed."
                )
            )
        }

        let clipsByID = Dictionary(uniqueKeysWithValues: request.storedClips.map { ($0.id, $0) })
        let removedClips = plan.clipIDsToRemove.compactMap { clipsByID[$0] }

        _ = retentionStore.removeStoredClips(ids: plan.clipIDsToRemove)

        var removedAssetCount = 0
        var freedBytes: Int64 = 0
        var latestAssetSettings = request.assetCacheSettings
        var statusFragments: [String] = []

        if plan.shouldWipeAllHistory {
            let cacheResult = assetCacheCoordinator.clearCache(trigger: request.trigger)
            removedAssetCount += cacheResult.removedAssetCount
            freedBytes += cacheResult.freedBytes
            latestAssetSettings = latestAssetSettings.updating(
                currentUsageBytes: 0,
                lastClearedAt: cacheResult.completedAt,
                lastSweepAt: cacheResult.completedAt
            )
            statusFragments.append(cacheResult.statusMessage ?? "")
        } else {
            if let removedAssetResult = assetCacheCoordinator.removeAssets(
                withKeys: plan.assetCacheKeysToRemove,
                trigger: request.trigger
            ) {
                removedAssetCount += removedAssetResult.removedAssetCount
                freedBytes += removedAssetResult.freedBytes
                statusFragments.append(removedAssetResult.statusMessage ?? "")
            }

            let refreshedUsage = assetCacheCoordinator.refreshUsage()
            latestAssetSettings = latestAssetSettings.updating(
                currentUsageBytes: refreshedUsage.currentUsageBytes,
                lastSweepAt: refreshedUsage.lastSweepAt
            )

            if let trimResult = assetCacheCoordinator.trimIfNeeded(
                using: latestAssetSettings,
                trigger: request.trigger
            ) {
                removedAssetCount += trimResult.removedAssetCount
                freedBytes += trimResult.freedBytes
                let usageAfterTrim = assetCacheCoordinator.refreshUsage()
                latestAssetSettings = latestAssetSettings.updating(
                    currentUsageBytes: usageAfterTrim.currentUsageBytes,
                    lastClearedAt: trimResult.completedAt,
                    lastSweepAt: usageAfterTrim.lastSweepAt
                )
                statusFragments.append(trimResult.statusMessage ?? "")
            }
        }

        _ = retentionStore.saveAssetCacheSettings(latestAssetSettings)

        let remainingSnapshot = retentionStore.snapshot
        let result = RetentionCleanupResult(
            trigger: request.trigger,
            removedClipCount: removedClips.count,
            removedAssetCount: removedAssetCount,
            freedBytes: freedBytes,
            skippedPinnedClipCount: plan.skippedPinnedClipIDs.count,
            remainingClipCount: remainingSnapshot.storedClips.count,
            remainingPinnedClipCount: remainingSnapshot.storedClips.filter(\.isPinned).count,
            didWipeAllHistory: plan.shouldWipeAllHistory,
            completedAt: .now,
            statusMessage: statusMessage(
                trigger: request.trigger,
                removedClipCount: removedClips.count,
                removedAssetCount: removedAssetCount,
                skippedPinnedClipCount: plan.skippedPinnedClipIDs.count,
                didWipeAllHistory: plan.shouldWipeAllHistory,
                fragments: statusFragments
            )
        )

        return finalizeResult(result)
    }

    private func executeManualCacheClear(for request: RetentionCleanupRequest) -> RetentionCleanupResult {
        let cacheResult = assetCacheCoordinator.clearCache(trigger: request.trigger)
        let updatedSettings = request.assetCacheSettings.updating(
            currentUsageBytes: 0,
            lastClearedAt: cacheResult.completedAt,
            lastSweepAt: cacheResult.completedAt
        )
        _ = retentionStore.saveAssetCacheSettings(updatedSettings)

        let result = RetentionCleanupResult(
            trigger: request.trigger,
            removedClipCount: 0,
            removedAssetCount: cacheResult.removedAssetCount,
            freedBytes: cacheResult.freedBytes,
            skippedPinnedClipCount: 0,
            remainingClipCount: request.storedClips.count,
            remainingPinnedClipCount: request.storedClips.filter(\.isPinned).count,
            didWipeAllHistory: false,
            completedAt: cacheResult.completedAt,
            statusMessage: cacheResult.statusMessage
        )

        return finalizeResult(result)
    }

    private func finalizeResult(_ result: RetentionCleanupResult) -> RetentionCleanupResult {
        _ = retentionStore.saveLatestCleanupResult(result)
        return result
    }

    private func statusMessage(
        trigger: RetentionCleanupTrigger,
        removedClipCount: Int,
        removedAssetCount: Int,
        skippedPinnedClipCount: Int,
        didWipeAllHistory: Bool,
        fragments: [String]
    ) -> String {
        if didWipeAllHistory {
            return "Cleared history and asset cache on app quit."
        }

        var parts: [String] = []

        if removedClipCount > 0 {
            switch trigger {
            case .settingsChanged:
                parts.append("Trimmed \(removedClipCount) old item\(removedClipCount == 1 ? "" : "s").")
            case .periodicSweep, .appLaunch, .appBecameActive:
                parts.append("Removed \(removedClipCount) expired item\(removedClipCount == 1 ? "" : "s").")
            case .manualCacheClear, .appQuit:
                parts.append("Removed \(removedClipCount) item\(removedClipCount == 1 ? "" : "s").")
            }
        }

        if skippedPinnedClipCount > 0 {
            parts.append("Pinned items were preserved.")
        }

        if removedAssetCount > 0 {
            if let fragment = fragments.first(where: { $0.isEmpty == false }) {
                parts.append(fragment)
            } else {
                parts.append("Cleared \(removedAssetCount) cached asset\(removedAssetCount == 1 ? "" : "s").")
            }
        }

        if parts.isEmpty {
            return "No cleanup was needed."
        }

        return parts.joined(separator: " ")
    }

    private nonisolated static func sortNewestFirst(_ lhs: RetentionManagedClip, _ rhs: RetentionManagedClip) -> Bool {
        if lhs.lastCopiedAt == rhs.lastCopiedAt {
            return lhs.id > rhs.id
        }

        return lhs.lastCopiedAt > rhs.lastCopiedAt
    }
}
