import SwiftUI

struct HotkeysSettingsTab: View {
    let summary: HotkeysSettingsShellSummary

    var body: some View {
        SettingsSectionsView(sections: summary.sections)
    }
}
