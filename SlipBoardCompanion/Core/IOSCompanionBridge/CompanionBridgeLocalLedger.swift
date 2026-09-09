import Foundation

actor CompanionBridgeLocalLedger {
    private var recordIDs = Set<String>()
    private var hashes = Set<String>()
    private var dismissedIDs = Set<String>()

    func accepts(_ item: CompanionInboundReviewItem) -> Bool {
        guard item.expiresAt > .now, !recordIDs.contains(item.id), !hashes.contains(item.normalizedHash), !dismissedIDs.contains(item.id) else { return false }
        recordIDs.insert(item.id); hashes.insert(item.normalizedHash)
        return true
    }

    func dismiss(_ item: CompanionInboundReviewItem) { dismissedIDs.insert(item.id) }
}
