import SwiftUI

struct CompanionBridgeScreen: View {
    @ObservedObject var model: CompanionBridgeScreenModel

    var body: some View {
        CompanionBridgeRootView(snapshot: model.snapshot)
            .task { await model.refresh() }
            .sheet(item: $model.reviewItem) { item in
                CompanionReceiveReviewFlow(item: item, model: model)
            }
    }
}

@MainActor
final class CompanionBridgeScreenModel: ObservableObject {
    @Published private(set) var snapshot: CompanionBridgeSnapshot
    @Published var reviewItem: CompanionInboundReviewItem?
    let runtime: CompanionBridgeRuntimeController
    init(runtime: CompanionBridgeRuntimeController) { self.runtime = runtime; snapshot = runtime.snapshot }
    func refresh() async { await runtime.refreshInboundRecords(); snapshot = runtime.snapshot }
    func importClipboard(_ text: String) async { await runtime.importPayload(text, source: .manualClipboard); snapshot = runtime.snapshot }
    func review(_ item: CompanionInboundReviewItem) { runtime.requestClipboardConfirmation(for: item); reviewItem = item; snapshot = runtime.snapshot }
}
