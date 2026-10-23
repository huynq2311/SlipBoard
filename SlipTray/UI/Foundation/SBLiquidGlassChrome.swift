import SwiftUI

/// Edge and surface tokens for a glass theme, decoded from the `glass` block of
/// its `*.theme.json` file.
struct SBGlassRim {
    let tint: Color
    let facet: [Color]
    /// Light gathered inside the curved rim where it faces the light source.
    let lensTop: Color
    /// Secondary caustic where light exits the bottom of the rim — the cue
    /// that makes the edge read as a water droplet rather than a bevel.
    let lensBottom: Color
    /// Boundary where the droplet meets the desktop. It is also drawn over the
    /// light rim `.glassEffect` always renders, which has no API to turn off.
    let edgeOutline: Color
    let edgeOutlineWidth: CGFloat
    let specular: Color
    let toolbarTop: Color
    let toolbarBottom: Color
    let cardHighlight: Color
    let cardBorderOpacity: Double
    let selectionGlow: Color
    /// Neutral wash between the glass and the content. System glass lets a
    /// saturated wallpaper bleed straight through, which flattens everything
    /// sitting on it; this calms the ground so cards and chips separate.
    let contentScrim: Color
    let cardShadow: Color
    let opaquePanel: Color
    let opaqueCanvas: Color
    /// Menus floating over clip cards must stay fully opaque to remain readable.
    let overlaySurface: Color
}

/// Paints the popup shell as a water droplet of glass: clear system glass,
/// a rim band that stays clearer than the middle, light pooling inside the
/// curved edge top and bottom, and a specular streak following the top curve.
struct SBLiquidGlassPanel: ViewModifier {
    let theme: SBTheme
    let rim: SBGlassRim
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.shell, style: .continuous)

        content
            .clipShape(shape)
            .background { backdrop(shape: shape) }
            .overlay { edge(shape: shape) }
    }

    @ViewBuilder
    private func backdrop(shape: RoundedRectangle) -> some View {
        if reduceTransparency {
            shape.fill(rim.opaquePanel)
        } else {
            ZStack {
                // Glass themes are not offered below macOS 26 (SBThemeRegistry),
                // so this fallback only guards an unexpected selection.
                if #available(macOS 26.0, *) {
                    Color.clear.glassEffect(.clear.tint(rim.tint), in: shape)
                } else {
                    shape.fill(rim.opaquePanel)
                }

                // Feathered away from the edge so the rim band stays clear
                // like the thin edge of a droplet.
                shape
                    .inset(by: 16)
                    .fill(rim.contentScrim)
                    .blur(radius: 10)
                    .mask(shape)
            }
        }
    }

    @ViewBuilder
    private func edge(shape: RoundedRectangle) -> some View {
        if reduceTransparency {
            shape.strokeBorder(theme.palette.borderStrong, lineWidth: theme.border.standard)
        } else {
            ZStack {
                // Light pooling inside the curved rim. A wide stroke blurred
                // and masked to the shape fades inward instead of stopping at
                // a line, which is what makes the edge read as curved.
                shape
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: rim.lensTop, location: 0),
                                .init(color: rim.lensTop.opacity(0.3), location: 0.24),
                                .init(color: .clear, location: 0.5),
                                .init(color: rim.lensBottom.opacity(0.45), location: 0.76),
                                .init(color: rim.lensBottom, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 24
                    )
                    .blur(radius: 12)
                    .mask(shape)

                shape.strokeBorder(
                    LinearGradient(
                        colors: rim.facet,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: theme.border.standard
                )

                shape.strokeBorder(rim.edgeOutline, lineWidth: rim.edgeOutlineWidth)

                specular
            }
            .allowsHitTesting(false)
        }
    }

    /// Streak that hugs the top curve, strongest toward the leading corner
    /// where the light source sits.
    private var specular: some View {
        Capsule()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: rim.specular, location: 0.12),
                        .init(color: rim.specular.opacity(0.3), location: 0.45),
                        .init(color: .clear, location: 0.7)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2.5)
            .blur(radius: 1)
            .padding(.horizontal, theme.radius.shell)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 3)
    }
}

/// Toolbar surface. A glass theme uses a scrim over the shell's material
/// instead of a second glass layer, keeping the stack at two layers max.
struct SBPopupToolbarBackground: View {
    let theme: SBTheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if let rim = theme.glassRim {
            if reduceTransparency {
                rim.opaqueCanvas
            } else {
                LinearGradient(
                    colors: [rim.toolbarTop, rim.toolbarBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            theme.palette.canvas
        }
    }
}
