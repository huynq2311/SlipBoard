import SwiftUI

enum SBThemeMode: String, CaseIterable, Identifiable, Hashable {
    case dark
    case light

    var id: String { rawValue }
}

enum SBAccentTone: String, Hashable {
    case primary
    case success
    case warning
    case info
    case danger
    case neutral
}

struct SBTheme {
    struct Palette {
        var canvas: Color
        var panel: Color
        var subpanel: Color
        var raised: Color
        var border: Color
        var borderStrong: Color
        var textPrimary: Color
        var textSecondary: Color
        var textTertiary: Color
        var accentPrimary: Color
        var accentPrimaryMuted: Color
        var accentSuccess: Color
        var accentWarning: Color
        var accentInfo: Color
        var accentDanger: Color
        var shadowPrimary: Color
        var shadowSecondary: Color
    }

    struct Typography {
        let paneTitle: Font
        let rowPrimary: Font
        let rowSecondary: Font
        let chip: Font
        let menu: Font
        let meta: Font
        let monoMeta: Font
        let uppercaseLabel: Font
        let keyboard: Font

        static let shared = Typography(
            paneTitle: .system(size: 22, weight: .medium, design: .default),
            rowPrimary: .system(size: 13, weight: .medium, design: .default),
            rowSecondary: .system(size: 12, weight: .regular, design: .default),
            chip: .system(size: 11, weight: .medium, design: .default),
            menu: .system(size: 11, weight: .regular, design: .default),
            meta: .system(size: 10, weight: .regular, design: .default),
            monoMeta: .system(size: 10, weight: .regular, design: .monospaced),
            uppercaseLabel: .system(size: 9, weight: .semibold, design: .default),
            keyboard: .system(size: 9, weight: .medium, design: .monospaced)
        )
    }

    struct Spacing {
        let control4: CGFloat = 4
        let control6: CGFloat = 6
        let control8: CGFloat = 8
        let control10: CGFloat = 10
        let control12: CGFloat = 12
        let popupPadding: CGFloat = 14
        let dropdownPadding: CGFloat = 14
        let settingsPaneHorizontal: CGFloat = 26
        let settingsPaneVertical: CGFloat = 22
        let railGap: CGFloat = 10
        let section8: CGFloat = 8
        let section12: CGFloat = 12
        let section16: CGFloat = 16
        let section24: CGFloat = 24
    }

    struct Radius {
        let shell: CGFloat = 14
        let window: CGFloat = 12
        let panel: CGFloat = 10
        let control: CGFloat = 7
        let chip: CGFloat = 20
        let badge: CGFloat = 999
        let keycap: CGFloat = 4
    }

    struct Border {
        let hairline: CGFloat = 0.5
        let standard: CGFloat = 1
    }

    struct Shadow {
        var popupRadius: CGFloat
        var popupYOffset: CGFloat
        var overlayRadius: CGFloat
        var overlayYOffset: CGFloat
        var windowRadius: CGFloat
        var windowYOffset: CGFloat
    }

    let mode: SBThemeMode
    let palette: Palette
    let typography: Typography
    let spacing: Spacing
    let radius: Radius
    let border: Border
    let shadow: Shadow

    static let dark = SBTheme(
        mode: .dark,
        palette: Palette(
            canvas: Color(hex: 0x0A0A0B),
            panel: Color(hex: 0x161618),
            subpanel: Color(hex: 0x1E1E21),
            raised: Color(hex: 0x2A2A2D),
            border: Color(hex: 0x2E2E33),
            borderStrong: Color(hex: 0x3D3D44),
            textPrimary: Color(hex: 0xF0F0F2),
            textSecondary: Color(hex: 0x8E8E9F),
            textTertiary: Color(hex: 0x50505F),
            accentPrimary: Color(hex: 0x7C6EF8),
            accentPrimaryMuted: Color(red: 124 / 255, green: 110 / 255, blue: 248 / 255, opacity: 0.12),
            accentSuccess: Color(hex: 0x3ECF8E),
            accentWarning: Color(hex: 0xF59E0B),
            accentInfo: Color(hex: 0x38BDF8),
            accentDanger: Color(hex: 0xF87171),
            shadowPrimary: Color.black.opacity(0.6),
            shadowSecondary: Color.black.opacity(0.3)
        ),
        typography: .shared,
        spacing: Spacing(),
        radius: Radius(),
        border: Border(),
        shadow: Shadow(
            popupRadius: 64,
            popupYOffset: 24,
            overlayRadius: 32,
            overlayYOffset: 8,
            windowRadius: 64,
            windowYOffset: 24
        )
    )

    static let light = SBTheme(
        mode: .light,
        palette: Palette(
            canvas: Color(hex: 0xE4E4E8),
            panel: Color(hex: 0xFFFFFF),
            subpanel: Color(hex: 0xF0F0F3),
            raised: Color(hex: 0xE4E4EA),
            border: Color(hex: 0xDDDDE5),
            borderStrong: Color(hex: 0xC5C5D0),
            textPrimary: Color(hex: 0x111114),
            textSecondary: Color(hex: 0x5A5A6B),
            textTertiary: Color(hex: 0x9898A8),
            accentPrimary: Color(hex: 0x6558F5),
            accentPrimaryMuted: Color(red: 101 / 255, green: 88 / 255, blue: 245 / 255, opacity: 0.08),
            accentSuccess: Color(hex: 0x3ECF8E),
            accentWarning: Color(hex: 0xF59E0B),
            accentInfo: Color(hex: 0x38BDF8),
            accentDanger: Color(hex: 0xF87171),
            shadowPrimary: Color.black.opacity(0.12),
            shadowSecondary: Color.black.opacity(0.08)
        ),
        typography: .shared,
        spacing: Spacing(),
        radius: Radius(),
        border: Border(),
        shadow: Shadow(
            popupRadius: 40,
            popupYOffset: 12,
            overlayRadius: 24,
            overlayYOffset: 4,
            windowRadius: 64,
            windowYOffset: 24
        )
    )

    static func theme(for mode: SBThemeMode) -> SBTheme {
        switch mode {
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    func accent(for tone: SBAccentTone) -> Color {
        switch tone {
        case .primary:
            return palette.accentPrimary
        case .success:
            return palette.accentSuccess
        case .warning:
            return palette.accentWarning
        case .info:
            return palette.accentInfo
        case .danger:
            return palette.accentDanger
        case .neutral:
            return palette.textSecondary
        }
    }

    func accentBackground(for tone: SBAccentTone) -> Color {
        switch tone {
        case .primary:
            return palette.accentPrimaryMuted
        case .success:
            return accent(for: .success).opacity(mode == .dark ? 0.14 : 0.1)
        case .warning:
            return accent(for: .warning).opacity(mode == .dark ? 0.14 : 0.1)
        case .info:
            return accent(for: .info).opacity(mode == .dark ? 0.14 : 0.1)
        case .danger:
            return accent(for: .danger).opacity(mode == .dark ? 0.12 : 0.08)
        case .neutral:
            return palette.raised
        }
    }

    func accent(for token: String) -> Color {
        switch token {
        case "accent.primary":
            return accent(for: .primary)
        case "accent.success":
            return accent(for: .success)
        case "accent.warning":
            return accent(for: .warning)
        case "accent.info":
            return accent(for: .info)
        case "accent.danger":
            return accent(for: .danger)
        default:
            return accent(for: .primary)
        }
    }
}

extension Color {
    fileprivate init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
