protocol MenuBarSessionProviding {
    func initialSettingsMenuShellSnapshot() -> SettingsMenuShellSnapshot
    func fixtureSettingsMenuShellSnapshot(named preset: SettingsMenuShellPreset) -> SettingsMenuShellSnapshot
}
