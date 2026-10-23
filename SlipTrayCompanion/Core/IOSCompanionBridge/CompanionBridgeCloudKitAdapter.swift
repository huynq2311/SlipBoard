import Foundation

actor CompanionBridgeCloudKitAdapter: CompanionBridgeReceiving {
    private var inbound: [CompanionInboundReviewItem] = []
    private(set) var publishedDrafts: [CompanionImportDraft] = []

    func publish(_ draft: CompanionImportDraft) { publishedDrafts.append(draft) }
    func seedInbound(_ item: CompanionInboundReviewItem) { inbound.append(item) }
    func refreshPendingItems() async throws -> [CompanionInboundReviewItem] { inbound.filter { $0.expiresAt > .now } }
    func dismiss(_ item: CompanionInboundReviewItem) async { inbound.removeAll { $0.id == item.id } }
}
