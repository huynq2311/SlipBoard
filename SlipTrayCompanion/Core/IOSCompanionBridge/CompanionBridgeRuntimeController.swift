import Foundation

@MainActor
final class CompanionBridgeRuntimeController: CompanionBridgeRuntimeProviding {
    private let importer: CompanionBridgeImporting
    private let receiver: CompanionBridgeReceiveController
    private let clipboard: CompanionClipboardSetting
    private let publish: @Sendable (CompanionImportDraft) async -> Void
    private var selectedItem: CompanionInboundReviewItem?
    private(set) var snapshot = CompanionBridgeSnapshot(accountStatus: .ready, pendingInboundItems: [], clipboardConfirmation: .idle, lastImportedAt: nil, lastClipboardSetAt: nil, lastErrorText: nil, isForegroundImportRequired: true)

    init(importer: CompanionBridgeImporting, receiver: CompanionBridgeReceiveController, clipboard: CompanionClipboardSetting, publish: @escaping @Sendable (CompanionImportDraft) async -> Void) { self.importer = importer; self.receiver = receiver; self.clipboard = clipboard; self.publish = publish }

    func importPayload(_ payload: String, source: CompanionBridgeImportSource, sourceAppName: String? = nil) async {
        do { let draft = try importer.normalize(payload: payload, source: source, sourceAppName: sourceAppName); await publish(draft); snapshot.lastImportedAt = .now; snapshot.lastErrorText = nil }
        catch { snapshot.lastErrorText = error.localizedDescription }
    }
    func refreshInboundRecords() async {
        do { snapshot.pendingInboundItems = try await receiver.refresh(); snapshot.lastErrorText = nil }
        catch { snapshot.lastErrorText = error.localizedDescription }
    }
    func requestClipboardConfirmation(for item: CompanionInboundReviewItem) { selectedItem = item; snapshot.clipboardConfirmation = .readyToConfirm(item) }
    func confirmClipboardSet() async {
        guard let item = selectedItem else { return }; snapshot.clipboardConfirmation = .confirming
        do { try await clipboard.setClipboard(from: item); snapshot.pendingInboundItems.removeAll { $0.id == item.id }; snapshot.lastClipboardSetAt = .now; snapshot.clipboardConfirmation = .confirmed(.now); selectedItem = nil }
        catch { snapshot.clipboardConfirmation = .failed(error.localizedDescription) }
    }
}
