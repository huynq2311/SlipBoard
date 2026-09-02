import Foundation

enum FoundationShellRuntimeHooks {
    private static var pauseCaptureHandler: ((Date) -> CapturePauseHotkeyResult)?

    static func registerPauseCaptureHandler(
        _ handler: @escaping (Date) -> CapturePauseHotkeyResult
    ) {
        pauseCaptureHandler = handler
    }

    static func clearPauseCaptureHandler() {
        pauseCaptureHandler = nil
    }

    static func togglePauseCapture(at date: Date = .now) -> CapturePauseHotkeyResult {
        pauseCaptureHandler?(date) ?? .unavailable
    }
}

protocol PopupShellRouting: AnyObject {
    func showPopup(selecting clipID: String?)
    func closePopup()

    func showSettings(selecting section: SettingsSectionID?)
    func closeSettings()

    func showMenuBarDropdown()
    func closeMenuBarDropdown()
    func toggleMenuBarDropdown()
}

extension PopupShellRouting {
    func handleGlobalHotkeyCommand(_ commandID: GlobalHotkeyCommandID) {
        switch commandID {
        case .openSlipboard:
            showPopup(selecting: nil)
        case .pasteAs:
            break
        case .pauseCapturing:
            _ = FoundationShellRuntimeHooks.togglePauseCapture()
            break
        }
    }
}
