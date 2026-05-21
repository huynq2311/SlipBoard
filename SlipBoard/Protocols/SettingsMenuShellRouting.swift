protocol SettingsMenuShellRouting {
    func selectSettingsTab(_ tab: SettingsShellTabID)
    func selectQuickRetention(_ option: QuickRetentionOptionID)
    func selectPauseCapture(_ option: PauseCaptureOptionID)
    func openSettings()
}
