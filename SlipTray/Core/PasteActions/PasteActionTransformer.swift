import Foundation

struct PasteActionTransformer: PasteActionTransforming {
    func supportedActions(for sourceItem: PasteActionSourceItem) -> [PasteActionID] {
        var actions: [PasteActionID] = [
            .original,
            .pasteAndClose,
            .pasteAndKeepOpen
        ]

        guard sourceItem.kind.allowsTextTransforms else {
            return actions
        }

        guard plainTextSeed(for: sourceItem)?.isEmpty == false else {
            return actions
        }

        actions.append(contentsOf: PasteActionID.transformMenuOrder)
        return actions
    }

    func preview(for actionID: PasteActionID, sourceItem: PasteActionSourceItem) -> PasteActionPreviewState {
        let payload = payload(for: actionID, sourceItem: sourceItem)
        let resolvedActionID = actionID.resolvedTransformID

        if resolvedActionID.isTransformAction, sourceItem.kind.allowsTextTransforms == false {
            return PasteActionPreviewState(
                kind: .unsupported,
                titleText: "Paste As...",
                previewText: "",
                placeholderText: "This clip does not expose text transforms in the first slice.",
                statusText: "Original paste remains available."
            )
        }

        if payload.previewText.isEmpty {
            return PasteActionPreviewState(
                kind: .empty,
                titleText: "Paste As...",
                previewText: "",
                placeholderText: placeholderText(for: resolvedActionID),
                statusText: statusText(for: resolvedActionID)
            )
        }

        return PasteActionPreviewState(
            kind: .text,
            titleText: "Paste As...",
            previewText: payload.previewText,
            statusText: statusText(for: resolvedActionID)
        )
    }

    func payload(for actionID: PasteActionID, sourceItem: PasteActionSourceItem) -> PasteActionPayload {
        let resolvedActionID = actionID.resolvedTransformID

        switch resolvedActionID {
        case .original:
            let originalText = originalText(for: sourceItem)
            return PasteActionPayload(
                actionID: actionID,
                origin: .original,
                stringValue: originalText,
                previewText: originalText ?? sourceItem.primaryText,
                isTextual: originalText != nil,
                sourceHash: sourceItem.normalizedHash
            )
        case .plainText:
            let value = plainTextSeed(for: sourceItem)
            return makeTransformPayload(
                actionID: actionID,
                stringValue: value,
                sourceItem: sourceItem
            )
        case .markdown:
            let value = plainTextSeed(for: sourceItem).map { markdownText(from: $0, sourceItem: sourceItem) }
            return makeTransformPayload(
                actionID: actionID,
                stringValue: value,
                sourceItem: sourceItem
            )
        case .stripUnicodeAccent:
            let value = plainTextSeed(for: sourceItem).map(stripUnicodeAccent)
            return makeTransformPayload(
                actionID: actionID,
                stringValue: value,
                sourceItem: sourceItem
            )
        case .uppercase:
            let value = plainTextSeed(for: sourceItem)?.uppercased(with: .current)
            return makeTransformPayload(
                actionID: actionID,
                stringValue: value,
                sourceItem: sourceItem
            )
        case .lowercase:
            let value = plainTextSeed(for: sourceItem)?.lowercased(with: .current)
            return makeTransformPayload(
                actionID: actionID,
                stringValue: value,
                sourceItem: sourceItem
            )
        case .pasteAndClose, .pasteAndKeepOpen:
            let originalText = originalText(for: sourceItem)
            return PasteActionPayload(
                actionID: actionID,
                origin: .original,
                stringValue: originalText,
                previewText: originalText ?? sourceItem.primaryText,
                isTextual: originalText != nil,
                sourceHash: sourceItem.normalizedHash
            )
        }
    }

    private func makeTransformPayload(
        actionID: PasteActionID,
        stringValue: String?,
        sourceItem: PasteActionSourceItem
    ) -> PasteActionPayload {
        PasteActionPayload(
            actionID: actionID,
            origin: .transformed,
            stringValue: stringValue,
            previewText: stringValue ?? "",
            isTextual: stringValue != nil,
            sourceHash: sourceItem.normalizedHash
        )
    }

    private func originalText(for sourceItem: PasteActionSourceItem) -> String? {
        if let rawText = sourceItem.rawText, rawText.isEmpty == false {
            return rawText
        }

        if let plainText = sourceItem.plainText, plainText.isEmpty == false {
            return plainText
        }

        return sourceItem.primaryText.isEmpty ? nil : sourceItem.primaryText
    }

    private func plainTextSeed(for sourceItem: PasteActionSourceItem) -> String? {
        guard sourceItem.kind.allowsTextTransforms else {
            return nil
        }

        if let plainText = sourceItem.plainText, plainText.isEmpty == false {
            return normalizedLineEndings(in: plainText)
        }

        if let rawText = sourceItem.rawText, rawText.isEmpty == false {
            return normalizedLineEndings(in: rawText)
        }

        return sourceItem.primaryText.isEmpty ? nil : normalizedLineEndings(in: sourceItem.primaryText)
    }

    private func normalizedLineEndings(in text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private func markdownText(from text: String, sourceItem: PasteActionSourceItem) -> String {
        let normalized = normalizedLineEndings(in: text)

        if sourceItem.kind == .code {
            return fencedCodeBlock(for: normalized)
        }

        if sourceItem.kind == .url, let url = URL(string: normalized), url.scheme?.isEmpty == false {
            return "[\(normalized)](\(normalized))"
        }

        let paragraphs = normalized.components(separatedBy: "\n\n")
        return paragraphs
            .map { paragraph in
                paragraph
                    .components(separatedBy: "\n")
                    .map(escapeMarkdownLine)
                    .joined(separator: "\n")
            }
            .joined(separator: "\n\n")
    }

    private func fencedCodeBlock(for text: String) -> String {
        let fenceLength = max(3, longestBacktickRun(in: text) + 1)
        let fence = String(repeating: "`", count: fenceLength)
        return "\(fence)\n\(text)\n\(fence)"
    }

    private func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0

        for character in text {
            if character == "`" {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }

    private func escapeMarkdownLine(_ line: String) -> String {
        var escaped = ""
        let markdownSpecials: Set<Character> = ["\\", "`", "*", "_", "[", "]", "#", ">", "|"]

        for character in line {
            if markdownSpecials.contains(character) {
                escaped.append("\\")
            }
            escaped.append(character)
        }

        return escaped
    }

    private func stripUnicodeAccent(_ text: String) -> String {
        let replacements: [(String, String)] = [
            ("đ", "d"),
            ("Đ", "D"),
            ("’", "'"),
            ("‘", "'"),
            ("“", "\""),
            ("”", "\""),
            ("–", "-"),
            ("—", "-"),
            ("…", "..."),
            ("•", "*")
        ]

        let replaced = replacements.reduce(text) { partial, replacement in
            partial.replacingOccurrences(of: replacement.0, with: replacement.1)
        }

        let latin = replaced.applyingTransform(.toLatin, reverse: false) ?? replaced
        let stripped = latin.applyingTransform(.stripCombiningMarks, reverse: false) ?? latin

        let allowedScalars = stripped.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x09, 0x0A:
                return true
            case 0x20...0x7E:
                return true
            default:
                return false
            }
        }

        return String(String.UnicodeScalarView(allowedScalars))
    }

    private func placeholderText(for actionID: PasteActionID) -> String {
        switch actionID {
        case .original:
            return "The selected clip does not expose a local paste payload in this slice."
        default:
            return "This transform produced an empty result."
        }
    }

    private func statusText(for actionID: PasteActionID) -> String {
        switch actionID {
        case .original:
            return "Original clipboard payload preview."
        case .pasteAndClose:
            return "Original clipboard payload preview."
        case .pasteAndKeepOpen:
            return "Original clipboard payload preview."
        case .plainText:
            return "Plain text preview removes rich formatting when available."
        case .markdown:
            return "Markdown preview uses a best-effort local conversion."
        case .stripUnicodeAccent:
            return "Accent marks and non-ASCII characters are stripped."
        case .uppercase:
            return "Preview converts the outgoing text to uppercase."
        case .lowercase:
            return "Preview converts the outgoing text to lowercase."
        }
    }
}

private extension PasteActionSourceKind {
    var allowsTextTransforms: Bool {
        switch self {
        case .text, .code, .url, .color, .richText:
            return true
        case .image, .file, .unknown:
            return false
        }
    }
}
