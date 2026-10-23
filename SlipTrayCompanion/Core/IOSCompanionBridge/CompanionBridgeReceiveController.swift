import Foundation

actor CompanionBridgeReceiveController {
    private let transport: CompanionBridgeReceiving
    private let ledger: CompanionBridgeLocalLedger
    init(transport: CompanionBridgeReceiving, ledger: CompanionBridgeLocalLedger) { self.transport = transport; self.ledger = ledger }
    func refresh() async throws -> [CompanionInboundReviewItem] {
        let records = try await transport.refreshPendingItems()
        var accepted: [CompanionInboundReviewItem] = []
        for record in records where await ledger.accepts(record) { accepted.append(record) }
        return accepted
    }
    func dismiss(_ item: CompanionInboundReviewItem) async { await ledger.dismiss(item); await transport.dismiss(item) }
}
