import SwiftUI

enum CompanionBridgeTheme {
    static let screenPadding: CGFloat = 20
    static let sectionGap: CGFloat = 24
    static let rowPadding: CGFloat = 12
    static let previewInset: CGFloat = 14
    static let groupRadius: CGFloat = 12
    static let badgeRadius: CGFloat = 999

    static let surfaceBase = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let surfaceRaised = Color.white
    static let borderSubtle = Color.black.opacity(0.08)
    static let textPrimary = Color(red: 0.09, green: 0.10, blue: 0.14)
    static let textSecondary = Color(red: 0.37, green: 0.39, blue: 0.46)
    static let accentInfo = Color(red: 0.22, green: 0.55, blue: 0.95)
    static let accentSuccess = Color(red: 0.12, green: 0.64, blue: 0.42)
    static let accentWarning = Color(red: 0.89, green: 0.55, blue: 0.11)
    static let accentDanger = Color(red: 0.82, green: 0.25, blue: 0.24)
    static let accentMuted = Color(red: 0.58, green: 0.62, blue: 0.70)
}

extension Font {
    static let companionScreenTitle = Font.title2.weight(.semibold)
    static let companionSectionTitle = Font.headline.weight(.semibold)
    static let companionBody = Font.body
    static let companionCaption = Font.caption
    static let companionBadge = Font.caption.weight(.semibold)
}

extension CompanionBridgeAccountStatus {
    var badgeTitle: String {
        switch self {
        case .off: return "Off"
        case .unavailable: return "Unavailable"
        case .restricted: return "Restricted"
        case .ready: return "Ready"
        case .syncing: return "Syncing"
        case .error: return "Error"
        }
    }

    var badgeTint: Color {
        switch self {
        case .off:
            return CompanionBridgeTheme.accentMuted
        case .unavailable, .restricted:
            return CompanionBridgeTheme.accentWarning
        case .ready:
            return CompanionBridgeTheme.accentSuccess
        case .syncing:
            return CompanionBridgeTheme.accentInfo
        case .error:
            return CompanionBridgeTheme.accentDanger
        }
    }
}

extension CompanionBridgePayloadKind {
    var badgeTitle: String {
        switch self {
        case .text: return "Text"
        case .url: return "URL"
        case .code: return "Code"
        }
    }

    var symbolName: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .code: return "curlybraces"
        }
    }

    var tint: Color {
        switch self {
        case .text:
            return CompanionBridgeTheme.accentInfo
        case .url:
            return CompanionBridgeTheme.accentSuccess
        case .code:
            return CompanionBridgeTheme.accentWarning
        }
    }
}
