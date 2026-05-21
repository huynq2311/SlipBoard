import Foundation

// MARK: - ContentClassifier

/// Classifies a RawPasteboardSnapshot into a ClipboardContentKind and optional
/// DetectedSubType, and produces a normalised plain-text string for future FTS5 indexing.
///
/// Classification is a pure function of the snapshot value — no I/O, no mutable state.
/// First match in the priority order wins.
enum ContentClassifier {

    // MARK: - Public Interface

    /// Classify a raw pasteboard snapshot.
    /// - Parameter snapshot: The raw content captured from NSPasteboard.
    /// - Returns: A `ClassifiedContent` value carrying the item type, optional sub-type,
    ///            and a normalised plain-text string (nil when no text content is present).
    static func classify(_ snapshot: RawPasteboardSnapshot) -> ClassifiedContent {

        // Priority 1: file URLs
        if let urls = snapshot.fileURLs, !urls.isEmpty {
            return ClassifiedContent(
                itemType: .file,
                detectedSubType: nil,
                normalizedPlainText: urls.map(\.path).joined(separator: "\n")
            )
        }

        // Priority 2: image data
        if let data = snapshot.imageData, !data.isEmpty {
            return ClassifiedContent(
                itemType: .image,
                detectedSubType: nil,
                normalizedPlainText: nil
            )
        }

        // Priority 3: plain text — classify by content heuristics
        if let raw = snapshot.plainText, !raw.isEmpty {
            let normalised = normalise(raw)

            if isHexColor(normalised) {
                return ClassifiedContent(
                    itemType: .color,
                    detectedSubType: .hexColor,
                    normalizedPlainText: normalised
                )
            }

            if isURL(normalised) {
                return ClassifiedContent(
                    itemType: .url,
                    detectedSubType: .urlScheme,
                    normalizedPlainText: normalised
                )
            }

            if isEmail(normalised) {
                return ClassifiedContent(
                    itemType: .text,
                    detectedSubType: .email,
                    normalizedPlainText: normalised
                )
            }

            if isPhone(normalised) {
                return ClassifiedContent(
                    itemType: .text,
                    detectedSubType: .phone,
                    normalizedPlainText: normalised
                )
            }

            if isFilePath(normalised) {
                return ClassifiedContent(
                    itemType: .text,
                    detectedSubType: .filePath,
                    normalizedPlainText: normalised
                )
            }

            if looksLikeCode(normalised) {
                return ClassifiedContent(
                    itemType: .code,
                    detectedSubType: .codeLanguageHint,
                    normalizedPlainText: normalised
                )
            }

            return ClassifiedContent(
                itemType: .text,
                detectedSubType: nil,
                normalizedPlainText: normalised
            )
        }

        // Priority 4: attributed / RTF data
        if let data = snapshot.attributedStringData, !data.isEmpty {
            return ClassifiedContent(
                itemType: .code, // richText is not in ClipboardContentKind; use .text for RTF fallback
                detectedSubType: nil,
                normalizedPlainText: nil
            )
        }

        // Fallback: return plain text with empty normalised value
        return ClassifiedContent(
            itemType: .text,
            detectedSubType: nil,
            normalizedPlainText: nil
        )
    }

    // MARK: - Normalisation

    /// Produces a deterministic, Unicode-NFC, whitespace-trimmed plain-text string.
    static func normalise(_ raw: String) -> String {
        let newlineCanonicalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let trimmed = newlineCanonicalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.precomposedStringWithCanonicalMapping // Unicode NFC
    }

    // MARK: - Pattern Matchers (pure functions)

    private static func isHexColor(_ s: String) -> Bool {
        // Matches #RGB, #RRGGBB, #AARRGGBB
        let pattern = #"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isURL(_ s: String) -> Bool {
        guard let url = URL(string: s), url.scheme != nil else { return false }
        let knownSchemes: Set<String> = ["http", "https", "ftp", "ftps", "mailto", "file"]
        return knownSchemes.contains(url.scheme?.lowercased() ?? "")
    }

    private static func isEmail(_ s: String) -> Bool {
        // RFC-5322 simplified pattern — single-line, no whitespace
        guard !s.contains("\n") else { return false }
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isPhone(_ s: String) -> Bool {
        // Accepts common phone formats: +1-800-555-0100, (800) 555-0100, etc.
        guard !s.contains("\n") else { return false }
        let stripped = s.filter { $0.isNumber || $0 == "+" }
        return stripped.count >= 7 && stripped.count <= 15
            && s.range(of: #"^[\d\s\(\)\+\-\.]{7,20}$"#, options: .regularExpression) != nil
    }

    private static func isFilePath(_ s: String) -> Bool {
        guard !s.contains("\n") else { return false }
        return s.hasPrefix("/") || s.hasPrefix("~/") || s.hasPrefix("./")
    }

    private static func looksLikeCode(_ s: String) -> Bool {
        let lines = s.components(separatedBy: "\n")
        guard lines.count >= 3 else { return false }
        let indentedLines = lines.filter { line in
            line.prefix(while: { $0 == " " || $0 == "\t" }).count >= 2
        }
        return Double(indentedLines.count) / Double(lines.count) >= 0.4
    }
}
