import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct CompanionBridgeClipboardAdapter: CompanionClipboardSetting {
    func setClipboard(from item: CompanionInboundReviewItem) async throws {
        #if canImport(UIKit)
        UIPasteboard.general.string = item.payloadText
        #endif
    }
}
