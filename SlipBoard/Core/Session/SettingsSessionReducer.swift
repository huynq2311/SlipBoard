final class SettingsSessionReducer: SettingsSessionRouting {
    private(set) var session: SlipBoardAppSession

    init(session: SlipBoardAppSession) {
        self.session = session
    }

    func selectTab(_ tab: SettingsTabID) {
        let updatedSettings = SettingsSessionSnapshot(
            selectedTab: tab,
            general: session.settings.general,
            bridge: session.settings.bridge,
            retention: session.settings.retention,
            exclusions: session.settings.exclusions,
            hotkeys: session.settings.hotkeys,
            snippets: session.settings.snippets
        )

        session = SlipBoardAppSession(
            activeSurface: .settings(tab: tab),
            theme: session.theme,
            clipboard: session.clipboard,
            popupChrome: session.popupChrome,
            settings: updatedSettings
        )
    }
}
