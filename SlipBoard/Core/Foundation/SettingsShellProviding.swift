import Foundation

protocol SettingsShellProviding {
    var settingsShellState: SettingsShellState { get set }
}

extension SettingsShellProviding {
    func pane(for section: SettingsSectionID) -> SettingsPaneModel {
        settingsShellState.pane(for: section)
    }

    var selectedPane: SettingsPaneModel {
        pane(for: settingsShellState.selectedSection)
    }
}
