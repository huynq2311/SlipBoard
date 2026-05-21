enum AppSurface: Equatable, Sendable {
    case popup
    case settings(tab: SettingsTabID)
}

enum AppTheme: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

enum SlipBoardSessionPreset: String, CaseIterable, Sendable {
    case empty
    case popupDemo
    case settingsDemo
    case fullDemo
}

struct SlipBoardAppSession: Equatable, Sendable {
    let activeSurface: AppSurface
    let theme: AppTheme
    let clipboard: ClipboardFeedSnapshot
    let popupChrome: PopupChromeState
    let settings: SettingsSessionSnapshot
}
