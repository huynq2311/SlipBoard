import SwiftUI

struct CompanionWidgetShortcutFlow: View {
    @ObservedObject var model: CompanionBridgeScreenModel
    var body: some View { CompanionBridgeWidgetEntryView() }
}
