import Foundation

protocol BridgeSettingsStoreQuerying {
    var storedSettings: BridgeSettings { get }
}

protocol BridgeSettingsStoreMutating: AnyObject {
    @discardableResult
    func saveSettings(_ settings: BridgeSettings) -> BridgeSettings
}

typealias BridgeSettingsStoring = BridgeSettingsStoreQuerying & BridgeSettingsStoreMutating

protocol BridgeTransporting: AnyObject {
    func fetchAccountStatus() -> BridgeAccountStatus
    func fetchKnownDevices() -> [BridgeDeviceSummary]
    func fetchPendingEnvelopes(asOf referenceDate: Date) -> [BridgeTransferEnvelope]

    @discardableResult
    func publish(_ envelope: BridgeTransferEnvelope) -> BridgeTransferEnvelope

    @discardableResult
    func markConsumed(recordIDs: [String], consumedAt: Date) -> [BridgeTransferEnvelope]

    @discardableResult
    func deleteExpiredRecords(asOf referenceDate: Date) -> [String]
}

protocol BridgeEligibilityEvaluating {
    func evaluateOutboundEligibility(
        payloadKind: BridgePayloadKind?,
        payloadText: String?,
        didLocalPasteSucceed: Bool,
        actionIdentifier: String,
        normalizedHash: String?
    ) -> BridgeEligibilityResult

    func evaluateInboundEligibility(
        envelope: BridgeTransferEnvelope,
        now: Date,
        knownConsumedRecordIDs: Set<String>
    ) -> BridgeEligibilityResult
}

protocol BridgeRuntimeProviding: AnyObject {
    var latestSnapshot: BridgeRuntimeSnapshot { get }
    var onSnapshotChange: ((BridgeRuntimeSnapshot) -> Void)? { get set }

    func bootstrap()
    func refreshSnapshot()
    func updateBridgeEnabled(_ isEnabled: Bool)
    func updatePublishOnPasteEnabled(_ isEnabled: Bool)
    func updateReceiveEnabled(_ isEnabled: Bool)
    func stopBridge()
}
