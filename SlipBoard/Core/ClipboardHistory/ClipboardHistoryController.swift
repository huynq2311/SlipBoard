import Foundation

final class ClipboardHistoryController: ClipboardHistoryRuntimeProviding {
    typealias PopupState = PopupShellViewState
    typealias FilterOption = PopupFilterOption
    typealias MenuBarSummary = MenuBarSummaryState

    typealias Projection = ClipboardHistoryProjection<PopupShellViewState, PopupFilterOption, MenuBarSummaryState>

    var onSnapshotDidChange: ((ClipboardHistorySnapshot) -> Void)?
    var onProjectionDidChange: ((Projection) -> Void)?

    var latestSnapshot: ClipboardHistorySnapshot {
        store.snapshot
    }

    var latestExclusionsPauseSnapshot: ExclusionsPauseSnapshot {
        exclusionsPauseRuntime.latestSnapshot
    }

    var retentionSnapshot: RetentionRuntimeSnapshot {
        retentionRuntime.latestSnapshot
    }

    var projection: Projection {
        projector.project(
            store.snapshot,
            retentionSnapshot: retentionRuntime.latestSnapshot,
            searchRuntime: searchNotesRuntime,
            exclusionsPauseSnapshot: exclusionsPauseRuntime.latestSnapshot
        )
    }

    var isMonitoring: Bool {
        monitor.isRunning
    }

    lazy var pasteActions = PasteActionCoordinator(historyController: self)

    private let monitor: PasteboardMonitor
    private let store: InMemoryClipboardHistoryStore
    private let projector: ClipboardHistoryProjector
    private let imageAssetStore: ClipboardImageAssetStore
    private var bridgeRuntime: CloudBridgeRuntimeController?
    let exclusionsPauseRuntime: ExclusionsPauseRuntimeController
    let retentionRuntime: RetentionRuntimeController
    let searchNotesRuntime: SearchNotesRuntimeController
    private var pendingCaptureSuppression: PendingCaptureSuppression?
    var onRetentionSnapshotDidChange: ((RetentionRuntimeSnapshot) -> Void)?
    var onRetentionCleanupDidRun: ((RetentionCleanupResult) -> Void)?

    init(
        monitor: PasteboardMonitor = PasteboardMonitor(),
        store: InMemoryClipboardHistoryStore = InMemoryClipboardHistoryStore(),
        projector: ClipboardHistoryProjector = ClipboardHistoryProjector(),
        imageAssetStore: ClipboardImageAssetStore = ClipboardImageAssetStore(),
        exclusionsPauseRuntime: ExclusionsPauseRuntimeController? = nil,
        retentionRuntime: RetentionRuntimeController? = nil,
        searchNotesRuntime: SearchNotesRuntimeController? = nil,
        bridgeRuntime: CloudBridgeRuntimeController? = nil
    ) {
        self.monitor = monitor
        self.store = store
        self.projector = projector
        self.imageAssetStore = imageAssetStore
        self.bridgeRuntime = bridgeRuntime
        self.exclusionsPauseRuntime = exclusionsPauseRuntime ?? ExclusionsPauseRuntimeController()
        self.retentionRuntime = retentionRuntime ?? RetentionRuntimeController(historyStore: store)
        self.searchNotesRuntime = searchNotesRuntime ?? SearchNotesRuntimeController()
        self.retentionRuntime.attachHistoryStore(store)
        self.retentionRuntime.onSnapshotChange = { [weak self] snapshot in
            self?.onRetentionSnapshotDidChange?(snapshot)
            self?.synchronizeSearchNotesRuntime()
            self?.publishState()
        }
        self.retentionRuntime.onCleanupResult = { [weak self] result in
            self?.onRetentionCleanupDidRun?(result)
        }
        self.searchNotesRuntime.onProjectionChange = { [weak self] _ in
            self?.publishState()
        }
        self.exclusionsPauseRuntime.onSnapshotChange = { [weak self] _ in
            self?.publishState()
        }

        bindMonitor()
        FoundationShellRuntimeHooks.registerPauseCaptureHandler { [weak self] date in
            guard let self else {
                return .unavailable
            }

            return self.exclusionsPauseRuntime.handlePauseHotkey(triggeredAt: date)
        }
        self.retentionRuntime.bootstrap()
        self.exclusionsPauseRuntime.refreshSnapshot(referenceDate: Date())
        synchronizeSearchNotesRuntime()
        attachBridgeRuntime(bridgeRuntime)
        publishState()
    }

    deinit {
        FoundationShellRuntimeHooks.clearPauseCaptureHandler()
    }

    func startMonitoring() {
        exclusionsPauseRuntime.refreshSnapshot(referenceDate: Date())
        monitor.start()
        publishState()
    }

    func stopMonitoring() {
        monitor.stop()
        exclusionsPauseRuntime.refreshSnapshot(referenceDate: Date())
        publishState()
    }

    func refreshNow() {
        exclusionsPauseRuntime.refreshSnapshot(referenceDate: Date())
        monitor.pollNow()
    }

    func updateSearchQuery(_ query: String) {
        searchNotesRuntime.updateSearchQuery(query)
        publishState()
    }

    func updateActiveFilter(_ filter: ClipboardHistoryFilter) {
        store.setActiveFilter(filter)
        publishState()
    }

    func selectItem(id: String?) {
        guard store.snapshot.selectedItemID != id else {
            return
        }

        if let activeEditor = searchNotesRuntime.latestProjectionState.activeEditor,
           activeEditor.clipID != id {
            searchNotesRuntime.dismissNoteEditor()
        }

        applySelectedItemID(id)
        publishState()
    }

    func moveSelection(by delta: Int) {
        let visibleItems = visibleHistoryItems()
        guard visibleItems.isEmpty == false else {
            applySelectedItemID(nil)
            publishState()
            return
        }

        guard delta != 0 else {
            applySelectedItemID(visibleItems.first?.id)
            publishState()
            return
        }

        let currentSelectedID = store.snapshot.selectedItemID
        let currentIndex = currentSelectedID.flatMap { selectedID in
            visibleItems.firstIndex(where: { $0.id == selectedID })
        }

        let nextIndex: Int
        if let currentIndex {
            nextIndex = max(0, min(visibleItems.count - 1, currentIndex + delta))
        } else {
            nextIndex = delta > 0 ? 0 : visibleItems.count - 1
        }

        applySelectedItemID(visibleItems[nextIndex].id)
        publishState()
    }

    func setPinned(_ isPinned: Bool, for itemID: String) {
        store.setPinned(isPinned, for: itemID)
        synchronizeSearchNotesRuntime()
        retentionRuntime.recordHistoryMutation()
        publishState()
    }

    func deleteItem(id: String) {
        guard store.item(for: id) != nil else {
            return
        }

        let visibleItems = visibleHistoryItems()
        let deletedIndex = visibleItems.firstIndex(where: { $0.id == id })
        let fallbackSelectionID = deletedIndex.flatMap { index -> String? in
            if visibleItems.indices.contains(index + 1) {
                return visibleItems[index + 1].id
            }
            if index > 0 {
                return visibleItems[index - 1].id
            }
            return nil
        }

        store.removeItem(id: id, selecting: fallbackSelectionID)
        searchNotesRuntime.removeItems(ids: [id])
        retentionRuntime.recordHistoryMutation()
        publishState()
    }

    func selectOrganizationGroup(id: OrganizationGroupID) {
        searchNotesRuntime.selectGroup(id: id)
    }

    func createOrganizationGroup(name: String, accentToken: String?) -> OrganizationGroupSummary? {
        searchNotesRuntime.createGroup(name: name, accentToken: accentToken)
    }

    func updateOrganizationGroup(
        id: OrganizationGroupID,
        name: String,
        accentToken: String?
    ) -> OrganizationGroupSummary? {
        searchNotesRuntime.updateGroup(id: id, name: name, accentToken: accentToken)
    }

    func deleteOrganizationGroup(id: OrganizationGroupID) {
        searchNotesRuntime.deleteGroup(id: id)
    }

    func updateOrganizationMembership(for itemID: String, groupIDs: [OrganizationGroupID]) {
        searchNotesRuntime.updateMembership(for: itemID, groupIDs: groupIDs)
    }

    func presentNoteEditor(for itemID: String) {
        searchNotesRuntime.presentNoteEditor(for: itemID)
    }

    func dismissNoteEditor() {
        searchNotesRuntime.dismissNoteEditor()
    }

    func updateNoteDraft(_ draftText: String) {
        searchNotesRuntime.updateNoteDraft(draftText)
    }

    func saveActiveNote() {
        searchNotesRuntime.saveActiveNote()
    }

    func clearNote(for itemID: String) {
        searchNotesRuntime.clearNote(for: itemID)
    }

    func updateRetentionTTL(_ policy: RetentionTTLPolicy) {
        retentionRuntime.updateRetentionSettings(
            retentionSnapshot.retentionSettings.updating(ttlPolicy: policy)
        )
    }

    func updateRetentionMaxItemCount(_ maxItemCount: Int) {
        retentionRuntime.updateRetentionSettings(
            retentionSnapshot.retentionSettings.updating(maxItemCount: maxItemCount)
        )
    }

    func updateRetentionClearOnQuit(_ isEnabled: Bool) {
        retentionRuntime.updateRetentionSettings(
            retentionSnapshot.retentionSettings.updating(clearOnQuit: isEnabled)
        )
    }

    func updateBumpPastedItemToFront(_ isEnabled: Bool) {
        retentionRuntime.updateRetentionSettings(
            retentionSnapshot.retentionSettings.updating(bumpPastedItemToFront: isEnabled)
        )
    }

    func updateAssetCacheLimit(_ maxCacheSizeMB: Int) {
        retentionRuntime.updateAssetCacheSettings(
            retentionSnapshot.assetCacheSettings.updating(maxCacheSizeMB: maxCacheSizeMB)
        )
    }

    func refreshRetentionCacheUsage() {
        retentionRuntime.refreshCacheUsage()
    }

    @discardableResult
    func clearAssetCacheNow() -> RetentionCleanupResult {
        retentionRuntime.clearCacheNow()
    }

    @discardableResult
    func handleRetentionLifecycleTrigger(_ trigger: RetentionCleanupTrigger) -> RetentionCleanupResult? {
        retentionRuntime.handleCleanupTrigger(trigger)
    }

    @discardableResult
    func prepareForAppQuit() -> RetentionCleanupResult? {
        retentionRuntime.prepareForAppQuit()
    }

    private func bindMonitor() {
        monitor.onSample = { [weak self] sample in
            guard let self else { return }
            if self.shouldSuppressProgrammaticCapture(for: sample) {
                self.reconcileSuppressedCapture(with: sample)
                self.publishState()
                return
            }
            let capturePolicyDecision = self.exclusionsPauseRuntime.evaluateCapturePolicy(
                for: sample.sourceApp,
                referenceDate: sample.capturedAt
            )
            switch capturePolicyDecision {
            case .allow:
                break
            case .ignoreBecausePaused, .ignoreBecauseExcludedApp:
                self.publishState()
                return
            }
            let snapshot = self.store.apply(sample)
            self.persistImageAssetIfNeeded(from: sample, snapshot: snapshot)
            self.synchronizeSearchNotesRuntime()
            self.retentionRuntime.recordHistoryMutation()
            self.publishState()
        }

        monitor.onIgnoredSample = { [weak self] changeCount, reason in
            guard let self else { return }

            var snapshot = self.store.snapshot
            snapshot.captureStatus = .unsupportedSampleIgnored(
                reason: reason,
                lastChangeCount: changeCount
            )
            _ = self.store.reset(with: snapshot)
            self.publishState()
        }
    }

    private func publishState() {
        normalizeSelectionIfNeeded()
        let snapshot = store.snapshot
        onSnapshotDidChange?(snapshot)
        onProjectionDidChange?(
            projector.project(
                snapshot,
                retentionSnapshot: retentionRuntime.latestSnapshot,
                searchRuntime: searchNotesRuntime,
                exclusionsPauseSnapshot: exclusionsPauseRuntime.latestSnapshot
            )
        )
    }

    private func synchronizeSearchNotesRuntime() {
        searchNotesRuntime.synchronizeHistoryItems(store.snapshot.allItems)
    }

    private func visibleHistoryItems() -> [ClipboardHistoryItem] {
        let snapshot = store.snapshot
        let visibleIDs = searchNotesRuntime.visibleItemIDs(
            in: snapshot.allItems,
            activeFilter: snapshot.activeFilter
        )
        let itemByID = Dictionary(uniqueKeysWithValues: snapshot.allItems.map { ($0.id, $0) })
        return visibleIDs.compactMap { itemByID[$0] }
    }

    private func normalizeSelectionIfNeeded() {
        let visibleIDs = visibleHistoryItems().map(\.id)
        let nextSelectedID: String?

        if let currentSelectedID = store.snapshot.selectedItemID,
           visibleIDs.contains(currentSelectedID) {
            nextSelectedID = currentSelectedID
        } else {
            nextSelectedID = visibleIDs.first
        }

        guard store.snapshot.selectedItemID != nextSelectedID else {
            return
        }

        var snapshot = store.snapshot
        snapshot.selectedItemID = nextSelectedID
        _ = store.reset(with: snapshot)
    }

    private func applySelectedItemID(_ itemID: String?) {
        let visibleIDs = Set(visibleHistoryItems().map(\.id))
        var snapshot = store.snapshot

        if let itemID, visibleIDs.contains(itemID) {
            snapshot.selectedItemID = itemID
        } else if itemID == nil {
            snapshot.selectedItemID = nil
        }

        _ = store.reset(with: snapshot)
    }
}

extension ClipboardHistoryController {
    func attachBridgeRuntime(_ bridgeRuntime: CloudBridgeRuntimeController?) {
        if self.bridgeRuntime !== bridgeRuntime {
            self.bridgeRuntime?.onEligibleInboundImport = nil
            self.bridgeRuntime = bridgeRuntime
        }

        bridgeRuntime?.onEligibleInboundImport = { [weak self] envelope in
            self?.importBridgeEnvelope(envelope) ?? false
        }
        bridgeRuntime?.refreshSnapshot()
    }

    func handleSuccessfulPasteActionResult(
        actionID: PasteActionID,
        sourceItem: PasteActionSourceItem,
        result: PasteActionExecutionResult,
        completedAt: Date
    ) {
        guard result.didSucceed else {
            return
        }

        if retentionSnapshot.retentionSettings.bumpPastedItemToFront {
            store.touchItem(id: sourceItem.id, at: completedAt)
            retentionRuntime.recordHistoryMutation()
        }

        bridgeRuntime?.recordSuccessfulLocalPaste(
            sourceItem: sourceItem,
            actionID: actionID,
            pastedText: result.pastedPreviewText,
            completedAt: completedAt
        )
    }

    func selectedPasteActionSourceItem() -> PasteActionSourceItem? {
        guard let item = selectedHistoryItem else { return nil }

        let rawText: String?
        let plainText: String?

        switch item.kind {
        case .text, .code, .url, .color, .richText:
            rawText = item.primaryText
            plainText = item.primaryText
        case .file:
            let filePayload = item.filePaths.isEmpty == false
                ? item.filePaths.joined(separator: "\n")
                : item.secondaryText ?? item.primaryText
            rawText = filePayload
            plainText = filePayload
        case .image:
            rawText = nil
            plainText = nil
        }

        return PasteActionSourceItem(
            id: item.id,
            kind: pasteActionSourceKind(for: item.kind),
            primaryText: item.primaryText,
            secondaryText: item.secondaryText,
            rawText: rawText,
            plainText: plainText,
            imageData: item.kind == .image ? imageAssetStore.data(for: item.id) : nil,
            sourceAppDisplayName: item.sourceApp.displayName,
            normalizedHash: item.normalizedHash,
            richTextAvailable: item.richTextAvailable
        )
    }

    private func persistImageAssetIfNeeded(
        from sample: ClipboardCaptureSample,
        snapshot: ClipboardHistorySnapshot
    ) {
        guard let imageData = sample.imageData, imageData.isEmpty == false else { return }
        guard let item = snapshot.allItems.first(where: { $0.dedupeKey == "\(sample.kind.rawValue):\(sample.normalizedHash ?? "")" }) else {
            return
        }
        _ = imageAssetStore.save(imageData, for: item.id)
    }

    func registerProgrammaticPasteSuppressionToken(_ token: String?) {
        guard let token, token.isEmpty == false else {
            pendingCaptureSuppression = nil
            return
        }

        pendingCaptureSuppression = PendingCaptureSuppression(
            token: token,
            expiresAt: Date().addingTimeInterval(5),
            remainingMatches: 1
        )
    }

    var selectedHistoryItem: ClipboardHistoryItem? {
        if let selectedItemID = store.snapshot.selectedItemID,
           let selectedItem = visibleHistoryItems().first(where: { $0.id == selectedItemID }) {
            return selectedItem
        }

        return visibleHistoryItems().first
    }

    private func shouldSuppressProgrammaticCapture(for sample: ClipboardCaptureSample) -> Bool {
        clearExpiredCaptureSuppressionIfNeeded()

        guard
            var pendingCaptureSuppression,
            let sampleToken = captureSuppressionToken(for: sample),
            pendingCaptureSuppression.token == sampleToken
        else {
            return false
        }

        pendingCaptureSuppression.remainingMatches -= 1
        self.pendingCaptureSuppression = pendingCaptureSuppression.remainingMatches > 0
            ? pendingCaptureSuppression
            : nil

        return true
    }

    private func reconcileSuppressedCapture(with sample: ClipboardCaptureSample) {
        var snapshot = store.snapshot
        snapshot.captureStatus = .active(latestCaptureAt: sample.capturedAt)
        _ = store.reset(with: snapshot)
    }

    private func clearExpiredCaptureSuppressionIfNeeded() {
        guard let pendingCaptureSuppression else { return }
        if pendingCaptureSuppression.expiresAt <= Date() {
            self.pendingCaptureSuppression = nil
        }
    }

    private func captureSuppressionToken(for sample: ClipboardCaptureSample) -> String? {
        if let normalizedHash = sample.normalizedHash, normalizedHash.isEmpty == false {
            return "programmatic-write:\(normalizedHash)"
        }

        if let normalizedText = sample.normalizedText?.trimmingCharacters(in: .whitespacesAndNewlines),
           normalizedText.isEmpty == false {
            return "programmatic-write:\(normalizedText)"
        }

        return nil
    }

    private func pasteActionSourceKind(for kind: ClipboardHistoryKind) -> PasteActionSourceKind {
        switch kind {
        case .text:
            return .text
        case .code:
            return .code
        case .image:
            return .image
        case .file:
            return .file
        case .url:
            return .url
        case .color:
            return .color
        case .richText:
            return .richText
        }
    }

    private func importBridgeEnvelope(_ envelope: BridgeTransferEnvelope) -> Bool {
        let importedAt = Date()
        guard let sample = bridgeImportSample(from: envelope, importedAt: importedAt) else {
            return false
        }

        _ = store.apply(sample)
        annotateImportedBridgeItem(for: envelope)
        synchronizeSearchNotesRuntime()
        retentionRuntime.recordHistoryMutation()
        publishState()
        return true
    }

    private func bridgeImportSample(
        from envelope: BridgeTransferEnvelope,
        importedAt: Date
    ) -> ClipboardCaptureSample? {
        let normalizedText = envelope.payloadText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedText.isEmpty == false else {
            return nil
        }

        let sourceApp = ClipboardSourceAppSummary(
            displayName: envelope.sourceDeviceName,
            symbolName: "iphone",
            accentToken: "accent.secondary"
        )

        return ClipboardCaptureSample(
            changeCount: bridgeImportChangeCount(for: envelope, importedAt: importedAt),
            capturedAt: importedAt,
            kind: clipboardHistoryKind(for: envelope.payloadKind),
            rawString: normalizedText,
            rawURL: envelope.payloadKind == .url ? URL(string: normalizedText) : nil,
            normalizedText: normalizedText,
            normalizedHash: envelope.normalizedHash,
            sourceApp: sourceApp
        )
    }

    private func annotateImportedBridgeItem(for envelope: BridgeTransferEnvelope) {
        let importedMetadataText = "Imported from \(envelope.sourceDeviceName)"
        let importedBadgeText = "bridge"
        let importedSourceApp = ClipboardSourceAppSummary(
            displayName: envelope.sourceDeviceName,
            symbolName: "iphone",
            accentToken: "accent.secondary"
        )
        let dedupeKey = "\(clipboardHistoryKind(for: envelope.payloadKind).rawValue):\(envelope.normalizedHash)"

        var snapshot = store.snapshot
        var didMutateSnapshot = false

        snapshot.pinnedItems = snapshot.pinnedItems.map { item in
            guard item.dedupeKey == dedupeKey else {
                return item
            }

            didMutateSnapshot = true
            var updatedItem = item
            updatedItem.metadataText = importedMetadataText
            updatedItem.secondaryBadgeText = importedBadgeText
            updatedItem.sourceApp = importedSourceApp
            return updatedItem
        }

        snapshot.recentItems = snapshot.recentItems.map { item in
            guard item.dedupeKey == dedupeKey else {
                return item
            }

            didMutateSnapshot = true
            var updatedItem = item
            updatedItem.metadataText = importedMetadataText
            updatedItem.secondaryBadgeText = importedBadgeText
            updatedItem.sourceApp = importedSourceApp
            return updatedItem
        }

        if didMutateSnapshot {
            _ = store.reset(with: snapshot)
        }
    }

    private func clipboardHistoryKind(for payloadKind: BridgePayloadKind) -> ClipboardHistoryKind {
        switch payloadKind {
        case .text:
            return .text
        case .url:
            return .url
        case .code:
            return .code
        }
    }

    private func bridgeImportChangeCount(
        for envelope: BridgeTransferEnvelope,
        importedAt: Date
    ) -> Int {
        let timeComponent = Int(importedAt.timeIntervalSince1970.rounded(.towardZero))
        let recordComponent = abs(envelope.recordID.hashValue % 10_000)
        return timeComponent ^ recordComponent
    }
}

private struct PendingCaptureSuppression {
    let token: String
    let expiresAt: Date
    var remainingMatches: Int
}
