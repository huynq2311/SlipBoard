import SwiftUI

struct SnippetsSettingsTab: View {
    let summary: SnippetsSettingsShellSummary

    var body: some View {
        SettingsSectionsView(sections: summary.sections)
    }
}
