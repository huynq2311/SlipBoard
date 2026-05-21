import Foundation

final class SettingsMenuShellReducer: SettingsMenuShellRouting {
    private var menuBarReducer: MenuBarSessionReducer
    private(set) var snapshot: SettingsMenuShellSnapshot

    init(snapshot: SettingsMenuShellSnapshot) {
        let normalizedSnapshot = SettingsMenuShellProjection.materializeSnapshot(
            baseSnapshot: snapshot,
            selectedTab: snapshot.selectedTab,
            lastOpenedTab: snapshot.lastOpenedTab,
            quickRetentionSelection: SettingsMenuShellProjection.selectedQuickRetention(in: snapshot.menuBar),
            pauseSelection: SettingsMenuShellProjection.selectedPauseCapture(in: snapshot.menuBar)
        )

        self.snapshot = normalizedSnapshot
        self.menuBarReducer = MenuBarSessionReducer(snapshot: normalizedSnapshot.menuBar)
    }

    func selectSettingsTab(_ tab: SettingsShellTabID) {
        snapshot = SettingsMenuShellProjection.selectTab(
            tab,
            in: snapshot,
            updateLastOpenedTab: true
        )
    }

    func selectQuickRetention(_ option: QuickRetentionOptionID) {
        menuBarReducer.selectQuickRetention(option)
        snapshot = materializeSnapshot(using: menuBarReducer.snapshot)
    }

    func selectPauseCapture(_ option: PauseCaptureOptionID) {
        menuBarReducer.selectPauseCapture(option)
        snapshot = materializeSnapshot(using: menuBarReducer.snapshot)
    }

    func openSettings() {
        snapshot = SettingsMenuShellProjection.openSettings(from: snapshot)
    }

    private func materializeSnapshot(using menuBar: MenuBarSnapshot) -> SettingsMenuShellSnapshot {
        SettingsMenuShellSnapshot(
            selectedTab: snapshot.selectedTab,
            lastOpenedTab: snapshot.lastOpenedTab,
            menuBar: menuBar,
            tabs: snapshot.tabs,
            general: snapshot.general,
            bridge: snapshot.bridge,
            retention: SettingsMenuShellProjection.materializeRetentionSummary(
                base: snapshot.retention,
                quickRetentionSelection: SettingsMenuShellProjection.selectedQuickRetention(in: menuBar)
            ),
            exclusions: snapshot.exclusions,
            hotkeys: snapshot.hotkeys,
            snippets: snapshot.snippets,
            security: snapshot.security
        )
    }
}
