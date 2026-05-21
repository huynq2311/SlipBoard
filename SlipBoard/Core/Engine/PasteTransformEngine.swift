import Foundation

// MARK: - Paste Transform

/// The named transforms that can be applied to clipboard content before pasting.
/// Maps to the UI-facing `PasteTransformOptionID` in PopupShellModels.swift
/// without importing or depending on it — the mapping is performed at the adapter layer.
enum PasteTransform: String, CaseIterable, Equatable, Sendable {
    /// Strip any RTF/HTML wrappers and return normalised plain text.
    case plainText
    /// Convert all characters to uppercase.
    case uppercased
    /// Convert all characters to lowercase.
    case lowercased
    /// Remove diacritical marks (strip Unicode accents).
    case stripAccents
    /// Remove common Markdown syntax characters.
    case markdownStripped
}

// MARK: - Transformed Content

/// The result of applying a PasteTransform.
struct TransformedContent: Equatable, Sendable {
    /// The transformed text ready for pasting.
    let value: String
    /// The transform that was applied.
    let appliedTransform: PasteTransform
}

// MARK: - PasteTransformEngine

/// Applies a named PasteTransform to a plain-text input.
///
/// Each transform is a pure function — no mutable state, no I/O.
enum PasteTransformEngine {

    // MARK: - Public Interface

    /// Apply a transform to a plain-text string.
    ///
    /// - Parameters:
    ///   - text: The input plain text. RTF/HTML wrappers should be stripped before
    ///           calling this method; use `.plainText` to perform that stripping.
    ///   - transform: The transform to apply.
    /// - Returns: A `TransformedContent` with the result and the applied transform.
    static func apply(_ transform: PasteTransform, to text: String) -> TransformedContent {
        let result: String
        switch transform {
        case .plainText:
            result = applyPlainText(text)
        case .uppercased:
            result = text.uppercased()
        case .lowercased:
            result = text.lowercased()
        case .stripAccents:
            result = applyStripAccents(text)
        case .markdownStripped:
            result = applyMarkdownStripped(text)
        }
        return TransformedContent(value: result, appliedTransform: transform)
    }

    // MARK: - Individual Transform Implementations

    /// Strips common RTF/HTML wrapper patterns and normalises whitespace.
    private static func applyPlainText(_ text: String) -> String {
        // Remove basic HTML tags
        var result = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Normalise line endings
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Folds diacritics so accented characters become their base ASCII equivalents.
    private static func applyStripAccents(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: .current)
    }

    /// Removes common Markdown syntax characters while preserving content readability.
    private static func applyMarkdownStripped(_ text: String) -> String {
        var result = text
        // Remove heading markers
        result = result.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: [.regularExpression, .anchored])
        result = result.components(separatedBy: "\n").map { line in
            var l = line
            l = l.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
            return l
        }.joined(separator: "\n")
        // Remove bold/italic markers: **, __, *, _
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        result = result.replacingOccurrences(of: "_", with: "")
        // Remove inline code backticks
        result = result.replacingOccurrences(of: "`", with: "")
        // Remove blockquote markers
        result = result.replacingOccurrences(of: #"^>\s?"#, with: "", options: .regularExpression)
        result = result.components(separatedBy: "\n").map { line in
            line.replacingOccurrences(of: #"^>\s?"#, with: "", options: .regularExpression)
        }.joined(separator: "\n")
        // Remove horizontal rules
        result = result.replacingOccurrences(of: #"^[-*_]{3,}\s*$"#, with: "", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
