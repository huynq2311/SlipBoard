import Foundation

final class RetentionRuntimeController: RetentionRuntimeControlling {
    private let retentionStore: RetentionSettingsStoring
    private let cleanupCoordinator: RetentionCleanupCoordinating
    private let assetCacheCoordinator: AssetCacheAccounting
    private weak var historyStore: (any ClipboardHistoryRetentionBacking)?
    private let periodicSweepInterval: TimeInterval
    private var periodicSweepTimer: Timer?

    private(set) var latestSnapshot: RetentionRuntimeSnapshot
    var onSnapshotChange: ((RetentionRuntimeSnapshot) -> Void)?
    var onCleanupResult: ((RetentionCleanupResult) -> Void)?

    init(
        retentionStore: RetentionSettingsStoring = RetentionSettingsStore(),
        assetCacheCoordinator: AssetCacheAccounting? = nil,
        cleanupCoordinator: RetentionCleanupCoordinating? = nil,
        historyStore: (any ClipboardHistoryRetentionBacking)? = nil,
        periodicSweepInterval: TimeInterval = 30 * 60
    ) {
        let resolvedAssetCacheCoordinator = assetCacheCoordinator ?? AssetCacheCoordinator()
        let resolvedCleanupCoordinator = cleanupCoordinator
            ?? RetentionCleanupCoordinator(
                retentionStore: retentionStore,
                assetCacheCoordinator: resolvedAssetCacheCoordinator
            )

        self.retentionStore = retentionStore
        self.assetCacheCoordinator = resolvedAssetCacheCoordinator
        self.cleanupCoordinator = resolvedCleanupCoordinator
        self.historyStore = historyStore
        self.periodicSweepInterval = periodicSweepInterval
        self.latestSnapshot = Self.makeRuntimeSnapshot(from: retentionStore.snapshot)
    }

    deinit {
        periodicSweepTimer?.invalidate()
    }

    func attachHistoryStore(_ historyStore: any ClipboardHistoryRetentionBacking) {
        self.historyStore = historyStore
    }

    func bootstrap() {
        synchronizeHistoryStoreWithPersistence()
        refreshCacheUsage()
        _ = handleCleanupTrigger(.appLaunch)
        startPeriodicSweepTimer()
        publishSnapshot()
    }

    @discardableResult
    func handleCleanupTrigger(_ trigger: RetentionCleanupTrigger) -> RetentionCleanupResult? {
        synchronizeHistoryIntoPersistence()

        let persistedSnapshot = retentionStore.snapshot
        let request = RetentionCleanupRequest(
            trigger: trigger,
            retentionSettings: persistedSnapshot.retentionSettings,
            assetCacheSettings: persistedSnapshot.assetCacheSettings,
            storedClips: persistedSnapshot.storedClips
        )
        let result = cleanupCoordinator.executeCleanup(for: request)
        applyPersistenceBackIntoHistoryStore()
        publishSnapshot()
        onCleanupResult?(result)
        return result
    }

    func updateRetentionSettings(_ settings: RetentionSettings) {
        _ = retentionStore.saveRetentionSettings(settings)
        _ = handleCleanupTrigger(.settingsChanged)
    }

    func updateAssetCacheSettings(_ settings: AssetCacheSettings) {
        _ = retentionStore.saveAssetCacheSettings(settings)
        _ = handleCleanupTrigger(.settingsChanged)
    }

    func refreshCacheUsage() {
        let persistedSettings = retentionStore.snapshot.assetCacheSettings
        let refreshedSettings = assetCacheCoordinator.refreshUsage()
        _ = retentionStore.saveAssetCacheSettings(
            persistedSettings.updating(
                currentUsageBytes: refreshedSettings.currentUsageBytes,
                lastSweepAt: refreshedSettings.lastSweepAt
            )
        )
        publishSnapshot()
    }

    func clearCacheNow() -> RetentionCleanupResult {
        handleCleanupTrigger(.manualCacheClear)
            ?? RetentionCleanupResult(trigger: .manualCacheClear, statusMessage: "Asset cache clear was skipped.")
    }

    func prepareForAppQuit() -> RetentionCleanupResult? {
        guard retentionStore.snapshot.retentionSettings.clearOnQuit else {
            return nil
        }
        return handleCleanupTrigger(.appQuit)
    }

    func recordHistoryMutation() {
        synchronizeHistoryIntoPersistence()
        publishSnapshot()
    }

    private func synchronizeHistoryStoreWithPersistence() {
        guard let historyStore else {
            return
        }

        let persistedSnapshot = retentionStore.snapshot
        if historyStore.snapshot.allItems.isEmpty && persistedSnapshot.storedClips.isEmpty == false {
            _ = historyStore.replaceRetentionManagedClips(
                persistedSnapshot.storedClips,
                captureStatus: historyStore.snapshot.captureStatus
            )
            return
        }

        synchronizeHistoryIntoPersistence()
    }

    private func synchronizeHistoryIntoPersistence() {
        guard let historyStore else {
            return
        }

        let managedClips = historyStore.retentionManagedClips
        if retentionStore.snapshot.storedClips != managedClips {
            _ = retentionStore.replaceStoredClips(managedClips)
        }
    }

    private func applyPersistenceBackIntoHistoryStore() {
        guard let historyStore else {
            return
        }

        let persistedClips = retentionStore.snapshot.storedClips
        if historyStore.retentionManagedClips != persistedClips {
            _ = historyStore.replaceRetentionManagedClips(
                persistedClips,
                captureStatus: historyStore.snapshot.captureStatus
            )
        }
    }

    private func startPeriodicSweepTimer() {
        periodicSweepTimer?.invalidate()
        periodicSweepTimer = Timer.scheduledTimer(withTimeInterval: periodicSweepInterval, repeats: true) { [weak self] _ in
            _ = self?.handleCleanupTrigger(.periodicSweep)
        }
        RunLoop.main.add(periodicSweepTimer!, forMode: .common)
    }

    private func publishSnapshot() {
        latestSnapshot = Self.makeRuntimeSnapshot(from: retentionStore.snapshot)
        onSnapshotChange?(latestSnapshot)
    }

    private static func makeRuntimeSnapshot(from snapshot: RetentionPersistenceSnapshot) -> RetentionRuntimeSnapshot {
        RetentionRuntimeSnapshot(
            retentionSettings: snapshot.retentionSettings,
            assetCacheSettings: snapshot.assetCacheSettings,
            latestCleanupResult: snapshot.latestCleanupResult,
            storedClipCount: snapshot.storedClips.count,
            pinnedClipCount: snapshot.storedClips.filter(\.isPinned).count
        )
    }
}
