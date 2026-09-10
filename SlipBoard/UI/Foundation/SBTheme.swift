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

/// How a theme paints its surfaces: flat fills, or the macOS 26 glass
/// treatment where the popup shell becomes a raised piece of glass.
enum SBSurfaceTreatment: Hashable {
    case solid
    case liquidGlass
}

/// Colors and shadows come from bundled `*.theme.json` files via
/// `SBThemeRegistry`; typography, spacing and radii stay in code so no theme
/// file can change layout.
struct SBTheme {
    struct Palette {
        var canvas: Color
        var panel: Color
        var subpanel: Color
        var raised: Color
        /// Clip card body fill. Separate from `subpanel` so a glass theme can
        /// keep cards reading as solid surfaces while controls go translucent.
        var cardBase: Color
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
        let popupPadding: CGFloat = 20
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
        let shell: CGFloat = 20
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

    struct Shadow: Decodable {
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
    /// Present only for glass themes.
    var glassRim: SBGlassRim? = nil

    var treatment: SBSurfaceTreatment {
        glassRim == nil ? .solid : .liquidGlass
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
