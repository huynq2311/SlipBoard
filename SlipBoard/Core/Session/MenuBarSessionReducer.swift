import Foundation

final class MenuBarSessionReducer {
    private(set) var snapshot: MenuBarSnapshot

    init(snapshot: MenuBarSnapshot) {
        let quickRetentionSelection = SettingsMenuShellProjection.selectedQuickRetention(in: snapshot)
        let pauseSelection = SettingsMenuShellProjection.selectedPauseCapture(in: snapshot)
        self.snapshot = SettingsMenuShellProjection.materializeMenuBar(
            base: snapshot,
            quickRetentionSelection: quickRetentionSelection,
            pauseSelection: pauseSelection
        )
    }

    func selectQuickRetention(_ option: QuickRetentionOptionID) {
        snapshot = SettingsMenuShellProjection.materializeMenuBar(
            base: snapshot,
            quickRetentionSelection: option,
            pauseSelection: SettingsMenuShellProjection.selectedPauseCapture(in: snapshot)
        )
    }

    func selectPauseCapture(_ option: PauseCaptureOptionID) {
        snapshot = SettingsMenuShellProjection.materializeMenuBar(
            base: snapshot,
            quickRetentionSelection: SettingsMenuShellProjection.selectedQuickRetention(in: snapshot),
            pauseSelection: option
        )
    }
}
