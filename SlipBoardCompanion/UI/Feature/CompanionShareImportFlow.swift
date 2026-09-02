import SwiftUI

struct CompanionShareImportFlow: View {
    let payload: String
    @ObservedObject var model: CompanionBridgeScreenModel
    var body: some View { CompanionShareImportView(payloadText: payload, isSupported: !payload.isEmpty) }
}
