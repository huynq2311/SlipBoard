import SwiftUI

struct ExclusionsSettingsTab: View {
    let summary: ExclusionsSettingsShellSummary

    var body: some View {
        SettingsSectionsView(sections: summary.sections)
    }
}
