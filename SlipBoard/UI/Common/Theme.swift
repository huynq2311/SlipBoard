import SwiftUI

#if os(macOS)
import AppKit
#endif

extension Color {
    /// Creates a Color from a Hex string (e.g. "#7c6ef8" or "7c6ef8").
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Generates an adaptive color that automatically changes between light and dark modes natively on macOS.
    public static func adaptive(light: String, dark: String) -> Color {
        #if os(macOS)
        Color(NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil {
                return NSColor(Color(hex: dark))
            } else {
                return NSColor(Color(hex: light))
            }
        })
        #else
        Color(hex: dark) // Default/Fallback to dark mode
        #endif
    }
}

/// The official SlipBoard design tokens palette.
public struct Theme {
    public static let bgPrimary = Color.adaptive(light: "#ffffff", dark: "#111114")
    public static let bgSecondary = Color.adaptive(light: "#f0f0f3", dark: "#1a1a1e")
    public static let bgTertiary = Color.adaptive(light: "#e4e4ea", dark: "#24242a")
    
    public static let borderPrimary = Color.adaptive(light: "#dddde5", dark: "#4b4b58")
    public static let borderSecondary = Color.adaptive(light: "#c5c5d0", dark: "#34343c")
    
    public static let textPrimary = Color.adaptive(light: "#111114", dark: "#f4f4f6")
    public static let textSecondary = Color.adaptive(light: "#5a5a6b", dark: "#b8b8c4")
    public static let textTertiary = Color.adaptive(light: "#9898a8", dark: "#747483")
    
    public static let accent = Color.adaptive(light: "#6558f5", dark: "#7c6ef8")
    public static let accentBg = Color.adaptive(light: "#6558f5", dark: "#7c6ef8").opacity(0.12)
}
