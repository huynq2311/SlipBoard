import SwiftUI

struct BridgeSettingsTab: View {
    let summary: BridgeSettingsShellSummary

    var body: some View {
        SettingsSectionsView(sections: summary.sections)
    }
}
