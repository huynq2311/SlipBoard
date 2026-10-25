import SwiftUI

/// One bundled `*.theme.json` file, resolved into its light and dark themes.
struct SBThemeDefinition: Identifiable {
    let id: String
    let order: Int
    let names: [String: String]
    let light: SBTheme
    let dark: SBTheme

    func name(in language: AppLanguage) -> String {
        names[language.rawValue] ?? names[AppLanguage.english.rawValue] ?? id
    }

    func theme(for mode: SBThemeMode) -> SBTheme {
        switch mode {
        case .light:
            return light
        case .dark:
            return dark
        }
    }
}

/// Themes are data: every `*.theme.json` in the app bundle becomes a menu
/// entry, so adding a theme means adding a file. A file that fails to decode
/// is skipped and logged rather than taking the app down.
enum SBThemeRegistry {
    static let themes: [SBThemeDefinition] = loadBundledThemes()

    static func definition(for id: String) -> SBThemeDefinition {
        if let match = themes.first(where: { $0.id == id }) {
            return match
        }
        guard let fallback = themes.first(where: { $0.id == PopupThemeSelection.defaultThemeID }) ?? themes.first else {
            fatalError("SlipTray bundle contains no valid *.theme.json file")
        }
        return fallback
    }

    private static let logger = DiagnosticLogger(category: "Themes")

    private static var isGlassAvailable: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }

    private static func loadBundledThemes() -> [SBThemeDefinition] {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasSuffix(".theme.json") }
        var definitions: [SBThemeDefinition] = []

        for url in urls {
            do {
                let file = try JSONDecoder().decode(SBThemeFile.self, from: Data(contentsOf: url))
                let definition = try file.makeDefinition()
                // Glass themes render with `.glassEffect`, which only exists on macOS 26.
                guard definition.light.treatment != .liquidGlass || isGlassAvailable else {
                    continue
                }
                guard definitions.contains(where: { $0.id == definition.id }) == false else {
                    logger.error("Skipping \(url.lastPathComponent): duplicate theme id \(definition.id)")
                    continue
                }
                definitions.append(definition)
            } catch {
                logger.error("Skipping \(url.lastPathComponent): \(String(describing: error))")
            }
        }

        return definitions.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }
}

private struct SBThemeFile: Decodable {
    enum Treatment: String, Decodable {
        case solid
        case liquidGlass
    }

    struct Variant: Decodable {
        let palette: SBTheme.Palette
        let shadow: SBTheme.Shadow
        let glass: SBGlassRim?
    }

    let id: String
    let order: Int
    let name: [String: String]
    let treatment: Treatment
    let light: Variant
    let dark: Variant

    func makeDefinition() throws -> SBThemeDefinition {
        SBThemeDefinition(
            id: id,
            order: order,
            names: name,
            light: try makeTheme(from: light, mode: .light),
            dark: try makeTheme(from: dark, mode: .dark)
        )
    }

    private func makeTheme(from variant: Variant, mode: SBThemeMode) throws -> SBTheme {
        // `treatment` is stated explicitly so a glass theme that forgets its
        // `glass` block fails loudly instead of silently rendering as solid.
        guard (treatment == .liquidGlass) == (variant.glass != nil) else {
            throw SBThemeFileError.glassBlockMismatch(treatment: treatment.rawValue, mode: mode.rawValue)
        }

        return SBTheme(
            mode: mode,
            palette: variant.palette,
            typography: .shared,
            spacing: SBTheme.Spacing(),
            radius: SBTheme.Radius(),
            border: SBTheme.Border(),
            shadow: variant.shadow,
            glassRim: variant.glass
        )
    }
}

private enum SBThemeFileError: Error {
    case glassBlockMismatch(treatment: String, mode: String)
}

/// `#RRGGBB` or `#RRGGBBAA`, sRGB.
private struct SBHexColor: Decodable {
    let color: Color

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let color = Self.parse(raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid color \"\(raw)\", expected #RRGGBB or #RRGGBBAA"
                )
            )
        }
        self.color = color
    }

    private static func parse(_ raw: String) -> Color? {
        guard raw.hasPrefix("#") else { return nil }
        let hex = raw.dropFirst()
        guard hex.count == 6 || hex.count == 8,
              hex.allSatisfy(\.isHexDigit),
              let value = UInt64(hex, radix: 16) else {
            return nil
        }

        let rgba = hex.count == 6 ? (value << 8) | 0xFF : value
        return Color(
            .sRGB,
            red: Double((rgba >> 24) & 0xFF) / 255,
            green: Double((rgba >> 16) & 0xFF) / 255,
            blue: Double((rgba >> 8) & 0xFF) / 255,
            opacity: Double(rgba & 0xFF) / 255
        )
    }
}

extension SBTheme.Palette: Decodable {
    private enum CodingKeys: String, CodingKey {
        case canvas, panel, subpanel, raised, cardBase, border, borderStrong
        case textPrimary, textSecondary, textTertiary
        case accentPrimary, accentPrimaryMuted, accentSuccess, accentWarning, accentInfo, accentDanger
        case shadowPrimary, shadowSecondary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func color(_ key: CodingKeys) throws -> Color {
            try container.decode(SBHexColor.self, forKey: key).color
        }

        self.init(
            canvas: try color(.canvas),
            panel: try color(.panel),
            subpanel: try color(.subpanel),
            raised: try color(.raised),
            cardBase: try color(.cardBase),
            border: try color(.border),
            borderStrong: try color(.borderStrong),
            textPrimary: try color(.textPrimary),
            textSecondary: try color(.textSecondary),
            textTertiary: try color(.textTertiary),
            accentPrimary: try color(.accentPrimary),
            accentPrimaryMuted: try color(.accentPrimaryMuted),
            accentSuccess: try color(.accentSuccess),
            accentWarning: try color(.accentWarning),
            accentInfo: try color(.accentInfo),
            accentDanger: try color(.accentDanger),
            shadowPrimary: try color(.shadowPrimary),
            shadowSecondary: try color(.shadowSecondary)
        )
    }
}

extension SBGlassRim: Decodable {
    private enum CodingKeys: String, CodingKey {
        case tint, facet, lensTop, lensBottom, edgeOutline, edgeOutlineWidth, specular
        case toolbarTop, toolbarBottom, cardHighlight, cardBorderOpacity, selectionGlow
        case contentScrim, cardShadow
        case opaquePanel, opaqueCanvas, overlaySurface
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func color(_ key: CodingKeys) throws -> Color {
            try container.decode(SBHexColor.self, forKey: key).color
        }

        let facet = try container.decode([SBHexColor].self, forKey: .facet).map(\.color)
        guard facet.count >= 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .facet,
                in: container,
                debugDescription: "facet needs at least 2 gradient stops"
            )
        }

        self.init(
            tint: try color(.tint),
            facet: facet,
            lensTop: try color(.lensTop),
            lensBottom: try color(.lensBottom),
            edgeOutline: try color(.edgeOutline),
            edgeOutlineWidth: try container.decode(CGFloat.self, forKey: .edgeOutlineWidth),
            specular: try color(.specular),
            toolbarTop: try color(.toolbarTop),
            toolbarBottom: try color(.toolbarBottom),
            cardHighlight: try color(.cardHighlight),
            cardBorderOpacity: try container.decode(Double.self, forKey: .cardBorderOpacity),
            selectionGlow: try color(.selectionGlow),
            contentScrim: try color(.contentScrim),
            cardShadow: try color(.cardShadow),
            opaquePanel: try color(.opaquePanel),
            opaqueCanvas: try color(.opaqueCanvas),
            overlaySurface: try color(.overlaySurface)
        )
    }
}
