import SwiftUI

struct CompanionReceiveReviewFlow: View {
    let item: CompanionInboundReviewItem
    @ObservedObject var model: CompanionBridgeScreenModel
    var body: some View {
        CompanionReceiveReviewSheet(item: item)
            .task { model.review(item) }
    }
}
