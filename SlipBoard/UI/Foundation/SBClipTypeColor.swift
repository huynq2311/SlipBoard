import SwiftUI

/// Semantic accent color per clipboard content type, shared by filter chips,
/// type icons/labels, and clip card headers so they all agree visually.
enum SBClipTypeColor {
    static func base(for kind: ClipKind) -> Color {
        switch kind {
        case .text:
            return Color(red: 209 / 255, green: 154 / 255, blue: 0)
        case .richText:
            return Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255)
        case .code:
            return Color(red: 47 / 255, green: 124 / 255, blue: 246 / 255)
        case .image:
            return Color(red: 239 / 255, green: 83 / 255, blue: 80 / 255)
        case .file:
            return Color(red: 240 / 255, green: 138 / 255, blue: 36 / 255)
        case .url:
            return Color(red: 15 / 255, green: 154 / 255, blue: 168 / 255)
        case .color:
            return Color(red: 236 / 255, green: 95 / 255, blue: 183 / 255)
        }
    }

    static func base(forFilterID id: String) -> Color? {
        switch id {
        case "text":
            return base(for: .text)
        case "richText":
            return base(for: .richText)
        case "code":
            return base(for: .code)
        case "image":
            return base(for: .image)
        case "file":
            return base(for: .file)
        case "url":
            return base(for: .url)
        case "color":
            return base(for: .color)
        default:
            return nil
        }
    }
}
