import SwiftUI

struct RetentionSettingsTab: View {
    let summary: RetentionSettingsShellSummary

    var body: some View {
        SettingsSectionsView(sections: summary.sections)
    }
}
