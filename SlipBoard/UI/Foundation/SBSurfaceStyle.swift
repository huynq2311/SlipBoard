import SwiftUI

enum SBSurfaceRole: Hashable {
    case popup
    case dropdown
    case window
    case overlay
    case card
    case subpanel
    case raised
}

struct SBSurfaceStyle: Hashable {
    var background: Color
    var border: Color
    var shadow: Color
    var radius: CGFloat
    var borderWidth: CGFloat
    var shadowRadius: CGFloat
    var shadowYOffset: CGFloat

    static func make(role: SBSurfaceRole, theme: SBTheme, emphasized: Bool = false) -> SBSurfaceStyle {
        switch role {
        case .popup:
            return SBSurfaceStyle(
                background: theme.palette.panel,
                border: emphasized ? theme.palette.borderStrong : theme.palette.borderStrong,
                shadow: theme.palette.shadowPrimary,
                radius: theme.radius.shell,
                borderWidth: theme.border.hairline,
                shadowRadius: theme.shadow.popupRadius,
                shadowYOffset: theme.shadow.popupYOffset
            )
        case .dropdown:
            return SBSurfaceStyle(
                background: theme.palette.panel,
                border: theme.palette.borderStrong,
                shadow: theme.palette.shadowPrimary,
                radius: theme.radius.window,
                borderWidth: theme.border.hairline,
                shadowRadius: 48,
                shadowYOffset: 18
            )
        case .window:
            return SBSurfaceStyle(
                background: theme.palette.panel,
                border: theme.palette.borderStrong,
                shadow: theme.palette.shadowPrimary,
                radius: theme.radius.window,
                borderWidth: theme.border.hairline,
                shadowRadius: theme.shadow.windowRadius,
                shadowYOffset: theme.shadow.windowYOffset
            )
        case .overlay:
            return SBSurfaceStyle(
                background: theme.mode == .dark ? theme.palette.subpanel.opacity(0.92) : theme.palette.panel.opacity(0.9),
                border: theme.palette.borderStrong,
                shadow: theme.palette.shadowPrimary,
                radius: theme.radius.panel,
                borderWidth: theme.border.hairline,
                shadowRadius: theme.shadow.overlayRadius,
                shadowYOffset: theme.shadow.overlayYOffset
            )
        case .card:
            return SBSurfaceStyle(
                background: emphasized ? theme.accentBackground(for: .primary) : theme.palette.subpanel,
                border: emphasized ? theme.palette.accentPrimary : theme.palette.border,
                shadow: theme.palette.shadowSecondary,
                radius: theme.radius.panel,
                borderWidth: theme.border.hairline,
                shadowRadius: 0,
                shadowYOffset: 0
            )
        case .subpanel:
            return SBSurfaceStyle(
                background: theme.palette.subpanel,
                border: theme.palette.border,
                shadow: .clear,
                radius: theme.radius.panel,
                borderWidth: theme.border.hairline,
                shadowRadius: 0,
                shadowYOffset: 0
            )
        case .raised:
            return SBSurfaceStyle(
                background: theme.palette.raised,
                border: theme.palette.borderStrong,
                shadow: .clear,
                radius: theme.radius.control,
                borderWidth: theme.border.hairline,
                shadowRadius: 0,
                shadowYOffset: 0
            )
        }
    }
}

struct SBSurfaceModifier: ViewModifier {
    let style: SBSurfaceStyle

    func body(content: Content) -> some View {
        content
            .background(style.background)
            .clipShape(RoundedRectangle(cornerRadius: style.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: style.radius, style: .continuous)
                    .stroke(style.border, lineWidth: style.borderWidth)
            )
            .shadow(
                color: style.shadow,
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowYOffset
            )
    }
}

extension View {
    func sbSurface(_ role: SBSurfaceRole, theme: SBTheme, emphasized: Bool = false) -> some View {
        modifier(SBSurfaceModifier(style: .make(role: role, theme: theme, emphasized: emphasized)))
    }
}
