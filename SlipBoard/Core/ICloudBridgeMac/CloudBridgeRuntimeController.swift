import Foundation

final class CloudBridgeRuntimeController: BridgeRuntimeProviding {
    private let settingsStore: BridgeSettingsStoring
    private let transport: BridgeTransporting
    private let evaluator: BridgeEligibilityEvaluating
    private let now: () -> Date
    private let localDeviceName: () -> String

    private(set) var latestSnapshot: BridgeRuntimeSnapshot
    var onSnapshotChange: ((BridgeRuntimeSnapshot) -> Void)?
    var onEligibleInboundImport: ((BridgeTransferEnvelope) -> Bool)?

    init(
        settingsStore: BridgeSettingsStoring = BridgeSettingsStore(),
        transport: BridgeTransporting = CloudBridgeRecordStore(),
        evaluator: BridgeEligibilityEvaluating = CloudBridgeEligibilityEvaluator(),
        now: @escaping () -> Date = Date.init,
        localDeviceName: (() -> String)? = nil
    ) {
        self.settingsStore = settingsStore
        self.transport = transport
        self.evaluator = evaluator
        self.now = now
        self.localDeviceName = localDeviceName ?? Self.defaultLocalDeviceName

        let settings = settingsStore.storedSettings
        self.latestSnapshot = BridgeRuntimeSnapshot(
            accountStatus: settings.isBridgeEnabled ? transport.fetchAccountStatus() : .disabled,
            settings: settings,
            devices: transport.fetchKnownDevices(),
            activity: Self.activitySnapshot(from: transport, fallback: BridgeActivitySnapshot())
        )
    }

    func bootstrap() {
        refreshSnapshot()
    }

    func refreshSnapshot() {
        publishSnapshot(referenceDate: now(), processInboundImports: true)
    }

    func updateBridgeEnabled(_ isEnabled: Bool) {
        let referenceDate = now()
        var settings = settingsStore.storedSettings
        settings = settings.updating(
            isBridgeEnabled: isEnabled,
            isPublishOnPasteEnabled: isEnabled && settings.isAnyDirectionEnabled == false
                ? true
                : settings.isPublishOnPasteEnabled,
            isReceiveEnabled: isEnabled && settings.isAnyDirectionEnabled == false
                ? true
                : settings.isReceiveEnabled,
            lastUpdatedAt: referenceDate
        )
        _ = settingsStore.saveSettings(settings)
        publishSnapshot(referenceDate: referenceDate, processInboundImports: true)
    }

    func updatePublishOnPasteEnabled(_ isEnabled: Bool) {
        let referenceDate = now()
        let settings = settingsStore.storedSettings.updating(
            isPublishOnPasteEnabled: isEnabled,
            lastUpdatedAt: referenceDate
        )
        _ = settingsStore.saveSettings(settings)
        publishSnapshot(referenceDate: referenceDate, processInboundImports: false)
    }

    func updateReceiveEnabled(_ isEnabled: Bool) {
        let referenceDate = now()
        let settings = settingsStore.storedSettings.updating(
            isReceiveEnabled: isEnabled,
            lastUpdatedAt: referenceDate
        )
        _ = settingsStore.saveSettings(settings)
        publishSnapshot(referenceDate: referenceDate, processInboundImports: true)
    }

    func stopBridge() {
        let referenceDate = now()
        let settings = settingsStore.storedSettings.updating(
            isBridgeEnabled: false,
            lastUpdatedAt: referenceDate
        )
        _ = settingsStore.saveSettings(settings)
        publishSnapshot(referenceDate: referenceDate, processInboundImports: false)
    }

    @discardableResult
    func recordSuccessfulLocalPaste(
        sourceItem: PasteActionSourceItem,
        actionID: PasteActionID,
        pastedText: String,
        completedAt: Date
    ) -> BridgeEligibilityResult {
        let settings = settingsStore.storedSettings
        let accountStatus = resolvedAccountStatus(settings: settings)
        let payloadKind = bridgePayloadKind(for: sourceItem.kind)
        let eligibility = evaluator.evaluateOutboundEligibility(
            payloadKind: payloadKind,
            payloadText: pastedText,
            didLocalPasteSucceed: true,
            actionIdentifier: actionID.rawValue,
            normalizedHash: sourceItem.normalizedHash
        )

        guard settings.isBridgeEnabled else {
            return .ineligible("Bridge publish is disabled on this Mac.")
        }

        guard accountStatus.isBridgeAvailable else {
            return .ineligible("Bridge publish is unavailable until iCloud Bridge is ready.")
        }

        guard settings.isPublishOnPasteEnabled else {
            return .ineligible("Publish-on-paste is disabled.")
        }

        guard let eligiblePayloadKind = eligibility.payloadKind, eligibility.isEligible else {
            return eligibility
        }

        let normalizedText = normalizedPayloadText(pastedText)
        let envelope = BridgeTransferEnvelope(
            recordID: UUID().uuidString,
            origin: .macPastedItem,
            payloadKind: eligiblePayloadKind,
            payloadText: normalizedText,
            normalizedHash: sourceItem.normalizedHash,
            sourceDeviceName: localDeviceName(),
            createdAt: completedAt,
            expiresAt: completedAt.addingTimeInterval(TimeInterval(settings.ttlMinutes * 60))
        )

        _ = transport.publish(envelope)
        _ = transport.deleteExpiredRecords(asOf: completedAt)
        publishSnapshot(referenceDate: completedAt, processInboundImports: false)
        return eligibility
    }

    private func publishSnapshot(referenceDate: Date, processInboundImports: Bool) {
        _ = transport.deleteExpiredRecords(asOf: referenceDate)

        let settings = settingsStore.storedSettings
        let accountStatus = resolvedAccountStatus(settings: settings)

        if processInboundImports {
            consumeEligibleInboundEnvelopes(
                settings: settings,
                accountStatus: accountStatus,
                referenceDate: referenceDate
            )
        }

        let pendingImportCount = pendingInboundImportCount(
            settings: settings,
            accountStatus: accountStatus,
            referenceDate: referenceDate
        )
        let snapshot = BridgeRuntimeSnapshot(
            accountStatus: accountStatus,
            settings: settings,
            devices: transport.fetchKnownDevices(),
            activity: Self.activitySnapshot(
                from: transport,
                fallback: latestSnapshot.activity,
                pendingImportCount: pendingImportCount
            )
        )

        latestSnapshot = snapshot
        onSnapshotChange?(snapshot)
    }

    private func consumeEligibleInboundEnvelopes(
        settings: BridgeSettings,
        accountStatus: BridgeAccountStatus,
        referenceDate: Date
    ) {
        guard settings.isBridgeEnabled, settings.isReceiveEnabled, accountStatus.isBridgeAvailable else {
            return
        }

        let pendingEnvelopes = transport.fetchPendingEnvelopes(asOf: referenceDate)
        var knownConsumedRecordIDs = consumedRecordIDs()
        var consumedRecordIDsToMark: [String] = []

        for envelope in pendingEnvelopes {
            let eligibility = evaluator.evaluateInboundEligibility(
                envelope: envelope,
                now: referenceDate,
                knownConsumedRecordIDs: knownConsumedRecordIDs
            )

            guard eligibility.isEligible else {
                continue
            }

            guard let onEligibleInboundImport else {
                continue
            }

            if onEligibleInboundImport(envelope) {
                consumedRecordIDsToMark.append(envelope.recordID)
                knownConsumedRecordIDs.insert(envelope.recordID)
            } else if let transport = transport as? CloudBridgeRecordStore {
                transport.recordFailure(
                    "Bridge import could not enter local history.",
                    at: referenceDate
                )
            }
        }

        guard consumedRecordIDsToMark.isEmpty == false else {
            return
        }

        _ = transport.markConsumed(recordIDs: consumedRecordIDsToMark, consumedAt: referenceDate)
        _ = transport.deleteExpiredRecords(asOf: referenceDate)
    }

    private func pendingInboundImportCount(
        settings: BridgeSettings,
        accountStatus: BridgeAccountStatus,
        referenceDate: Date
    ) -> Int {
        guard settings.isBridgeEnabled, settings.isReceiveEnabled, accountStatus.isBridgeAvailable else {
            return 0
        }

        let knownConsumedRecordIDs = consumedRecordIDs()
        return transport.fetchPendingEnvelopes(asOf: referenceDate)
            .filter {
                evaluator.evaluateInboundEligibility(
                    envelope: $0,
                    now: referenceDate,
                    knownConsumedRecordIDs: knownConsumedRecordIDs
                ).isEligible
            }
            .count
    }

    private func consumedRecordIDs() -> Set<String> {
        if let transport = transport as? CloudBridgeRecordStore {
            return transport.consumedRecordIDs
        }

        return []
    }

    private func resolvedAccountStatus(settings: BridgeSettings) -> BridgeAccountStatus {
        settings.isBridgeEnabled ? transport.fetchAccountStatus() : .disabled
    }

    private func bridgePayloadKind(for sourceKind: PasteActionSourceKind) -> BridgePayloadKind? {
        switch sourceKind {
        case .text:
            return .text
        case .url:
            return .url
        case .code:
            return .code
        case .image, .file, .color, .richText, .unknown:
            return nil
        }
    }

    private func normalizedPayloadText(_ payloadText: String) -> String {
        payloadText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func activitySnapshot(
        from transport: BridgeTransporting,
        fallback: BridgeActivitySnapshot,
        pendingImportCount: Int? = nil
    ) -> BridgeActivitySnapshot {
        var baseActivity = fallback
        if let transport = transport as? CloudBridgeRecordStore {
            baseActivity = transport.activitySnapshot
        }

        baseActivity.pendingImportCount = pendingImportCount ?? baseActivity.pendingImportCount
        return baseActivity
    }

    private nonisolated static func defaultLocalDeviceName() -> String {
        Host.current().localizedName ?? "This Mac"
    }
}
