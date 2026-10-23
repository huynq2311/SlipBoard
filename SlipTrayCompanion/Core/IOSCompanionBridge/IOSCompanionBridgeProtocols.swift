import Foundation

protocol CompanionBridgeImporting: Sendable {
    func normalize(payload: String, source: CompanionBridgeImportSource, sourceAppName: String?) throws -> CompanionImportDraft
}

protocol CompanionBridgeReceiving: Sendable {
    func refreshPendingItems() async throws -> [CompanionInboundReviewItem]
    func dismiss(_ item: CompanionInboundReviewItem) async
}

protocol CompanionClipboardSetting: Sendable {
    func setClipboard(from item: CompanionInboundReviewItem) async throws
}

@MainActor
protocol CompanionBridgeRuntimeProviding: AnyObject {
    var snapshot: CompanionBridgeSnapshot { get }
    func importPayload(_ payload: String, source: CompanionBridgeImportSource, sourceAppName: String?) async
    func refreshInboundRecords() async
    func requestClipboardConfirmation(for item: CompanionInboundReviewItem)
    func confirmClipboardSet() async
}
