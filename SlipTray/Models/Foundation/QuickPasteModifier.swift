import SwiftUI

/// The key held while clicking a clip card to paste it at once.
enum QuickPasteModifier: String, CaseIterable, Identifiable {
    case command
    case option
    case shift
    case off

    static let storageKey = "SlipTray.QuickPaste.modifier"

    var id: String { rawValue }

    var eventModifiers: EventModifiers? {
        switch self {
        case .command: .command
        case .option: .option
        case .shift: .shift
        case .off: nil
        }
    }

    var symbolLabel: String {
        switch self {
        case .command: "⌘ Command"
        case .option: "⌥ Option"
        case .shift: "⇧ Shift"
        case .off: ""
        }
    }
}
