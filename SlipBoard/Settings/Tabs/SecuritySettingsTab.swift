import SwiftUI

struct SecuritySettingsTab: View {
    let summary: SecuritySettingsShellSummary

    var body: some View {
        SettingsSectionsView(sections: summary.sections)
    }
}
