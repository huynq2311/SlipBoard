import SwiftUI

struct GeneralSettingsTab: View {
    let summary: GeneralSettingsShellSummary

    var body: some View {
        SettingsSectionsView(sections: summary.sections)
    }
}
