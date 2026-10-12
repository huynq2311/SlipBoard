import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

enum ClipboardClassificationResult {
    case sample(ClipboardCaptureSample)
    case ignored(reason: String)
}

struct ClipboardContentClassifier {
    func classify(
        pasteboard: NSPasteboard,
        changeCount: Int,
        capturedAt: Date,
        sourceApp: ClipboardSourceAppSummary
    ) -> ClipboardClassificationResult {
        if let fileSample = classifyFileURLs(
            from: pasteboard,
            changeCount: changeCount,
            capturedAt: capturedAt,
            sourceApp: sourceApp
        ) {
            return .sample(fileSample)
        }

        if let imageSample = classifyImage(
            from: pasteboard,
            changeCount: changeCount,
            capturedAt: capturedAt,
            sourceApp: sourceApp
        ) {
            return .sample(imageSample)
        }

        if let richTextSample = classifyRichText(
            from: pasteboard,
            changeCount: changeCount,
            capturedAt: capturedAt,
            sourceApp: sourceApp
        ) {
            return .sample(richTextSample)
        }

        if let stringSample = classifyStringPayload(
            from: pasteboard,
            changeCount: changeCount,
            capturedAt: capturedAt,
            sourceApp: sourceApp
        ) {
            return .sample(stringSample)
        }

        if let urlSample = classifyURLObject(
            from: pasteboard,
            changeCount: changeCount,
            capturedAt: capturedAt,
            sourceApp: sourceApp
        ) {
            return .sample(urlSample)
        }

        return .ignored(reason: "Unsupported pasteboard payload was ignored.")
    }

    func normalizedText(for text: String) -> String? {
        let standardizedNewlines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let trimmedLines = standardizedNewlines
            .components(separatedBy: "\n")
            .map { line in
                line.replacingOccurrences(
                    of: #"[ \t]+$"#,
                    with: "",
                    options: .regularExpression
                )
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping

        guard trimmedLines.isEmpty == false else {
            return nil
        }

        return trimmedLines
    }

    func normalizedHash(for text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func normalizedHash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Universal Clipboard (iPhone/iPad → Mac) hands an image over as a file in
    /// a temporary shared-pasteboard container that is deleted shortly after,
    /// so it has to be captured as image data rather than as a file path.
    private func handoffImageFileURL(in pasteboard: NSPasteboard) -> URL? {
        guard
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
            urls.count == 1,
            let url = urls.first,
            url.isFileURL,
            url.path.contains("/group.com.apple.coreservices.useractivityd/shared-pasteboard/"),
            UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
        else {
            return nil
        }

        return url
    }

    private func classifyFileURLs(
        from pasteboard: NSPasteboard,
        changeCount: Int,
        capturedAt: Date,
        sourceApp: ClipboardSourceAppSummary
    ) -> ClipboardCaptureSample? {
        // Leave Universal Clipboard images to `classifyImage`.
        guard handoffImageFileURL(in: pasteboard) == nil else {
            return nil
        }

        guard
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        else {
            return nil
        }

        let fileURLs = urls.filter(\.isFileURL)
        guard fileURLs.isEmpty == false else {
            return nil
        }

        let paths = fileURLs.map(\.path)
        let descriptor = paths.joined(separator: "\n")
        let normalizedText = normalizedText(for: descriptor)
        let hashSource = normalizedText ?? descriptor

        return ClipboardCaptureSample(
            changeCount: changeCount,
            capturedAt: capturedAt,
            kind: .file,
            rawString: descriptor,
            filePaths: paths,
            normalizedText: normalizedText,
            normalizedHash: normalizedHash(for: hashSource),
            sourceApp: sourceApp
        )
    }

    /// Image types kept exactly as the source app offered them, in order of
    /// preference. TIFF is compacted to PNG later, when the asset is saved.
    private static let storedImageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        NSPasteboard.PasteboardType(UTType.heic.identifier),
        NSPasteboard.PasteboardType(UTType.jpeg.identifier),
        .tiff
    ]

    /// Reads image bytes without re-encoding them, so capture stays cheap on
    /// the main thread and repeated copies of one image hash the same.
    private func originalImageData(in pasteboard: NSPasteboard) -> Data? {
        if let type = pasteboard.availableType(from: Self.storedImageTypes),
           let data = pasteboard.data(forType: type) {
            return data
        }

        if let handoffURL = handoffImageFileURL(in: pasteboard) {
            return try? Data(contentsOf: handoffURL)
        }

        return (pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage])?
            .first?
            .tiffRepresentation
    }

    private func classifyImage(
        from pasteboard: NSPasteboard,
        changeCount: Int,
        capturedAt: Date,
        sourceApp: ClipboardSourceAppSummary
    ) -> ClipboardCaptureSample? {
        guard
            let imageData = originalImageData(in: pasteboard),
            let image = NSImage(data: imageData)
        else {
            return nil
        }

        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        let descriptor = width > 0 && height > 0
            ? "image:\(width)x\(height)"
            : "image"

        return ClipboardCaptureSample(
            changeCount: changeCount,
            capturedAt: capturedAt,
            kind: .image,
            rawString: descriptor,
            imageAvailable: true,
            imageData: imageData,
            normalizedText: descriptor,
            normalizedHash: normalizedHash(for: imageData),
            sourceApp: sourceApp
        )
    }

    private func classifyRichText(
        from pasteboard: NSPasteboard,
        changeCount: Int,
        capturedAt: Date,
        sourceApp: ClipboardSourceAppSummary
    ) -> ClipboardCaptureSample? {
        guard pasteboardContainsRichText(pasteboard) else {
            return nil
        }

        let richTextRTFData = pasteboard.data(forType: .rtf)
        let rawString = richTextRTFData
            .flatMap(plainText(fromRTFData:))
            ?? pasteboard.string(forType: .string)

        guard let rawString, let normalizedText = normalizedText(for: rawString) else {
            return nil
        }

        return ClipboardCaptureSample(
            changeCount: changeCount,
            capturedAt: capturedAt,
            kind: .richText,
            rawString: rawString,
            richTextAvailable: true,
            richTextRTFData: richTextRTFData,
            normalizedText: normalizedText,
            normalizedHash: normalizedHash(for: normalizedText),
            sourceApp: sourceApp
        )
    }

    private func classifyStringPayload(
        from pasteboard: NSPasteboard,
        changeCount: Int,
        capturedAt: Date,
        sourceApp: ClipboardSourceAppSummary
    ) -> ClipboardCaptureSample? {
        guard
            let rawString = pasteboard.string(forType: .string),
            let normalizedText = normalizedText(for: rawString)
        else {
            return nil
        }

        let kind = detectKind(for: normalizedText)
        let rawURL = kind == .url ? URL(string: normalizedText) : nil

        return ClipboardCaptureSample(
            changeCount: changeCount,
            capturedAt: capturedAt,
            kind: kind,
            rawString: rawString,
            rawURL: rawURL,
            richTextAvailable: pasteboardContainsRichText(pasteboard),
            normalizedText: normalizedText,
            normalizedHash: normalizedHash(for: normalizedText),
            sourceApp: sourceApp
        )
    }

    private func classifyURLObject(
        from pasteboard: NSPasteboard,
        changeCount: Int,
        capturedAt: Date,
        sourceApp: ClipboardSourceAppSummary
    ) -> ClipboardCaptureSample? {
        guard
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
            let url = urls.first(where: { $0.isFileURL == false })
        else {
            return nil
        }

        let normalizedText = normalizedText(for: url.absoluteString) ?? url.absoluteString

        return ClipboardCaptureSample(
            changeCount: changeCount,
            capturedAt: capturedAt,
            kind: .url,
            rawString: url.absoluteString,
            rawURL: url,
            normalizedText: normalizedText,
            normalizedHash: normalizedHash(for: normalizedText),
            sourceApp: sourceApp
        )
    }

    private func detectKind(for normalizedText: String) -> ClipboardHistoryKind {
        if looksLikeHexColor(normalizedText) {
            return .color
        }

        if let url = URL(string: normalizedText), url.scheme?.isEmpty == false {
            return .url
        }

        if looksLikeCode(normalizedText) {
            return .code
        }

        return .text
    }

    private func pasteboardContainsRichText(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.pasteboardItems?.first?.types else {
            return false
        }

        return types.contains(.rtf) || types.contains(.html)
    }

    private func plainText(fromRTFData data: Data) -> String? {
        guard let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            return nil
        }

        return attributed.string
    }

    private func looksLikeHexColor(_ text: String) -> Bool {
        let pattern = #"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    // Judging the start of a clip is enough to tell code from prose. Scanning a
    // multi-megabyte clip once per keyword blocked the main thread for seconds
    // on every copy.
    private static let codeDetectionCharacterLimit = 20_000

    private func looksLikeCode(_ fullText: String) -> Bool {
        let text = fullText.utf8.count <= Self.codeDetectionCharacterLimit
            ? fullText
            : String(fullText.prefix(Self.codeDetectionCharacterLimit))
        let lowercased = text.lowercased()
        let keywords = [
            "func ", "class ", "struct ", "enum ", "protocol ", "import ",
            "let ", "var ", "guard ", "return ", "if ", "else", "switch ",
            "public ", "private ", "select ", "insert ", "update ", "delete ",
            "curl ", "http://", "https://", "<div", "</", "{", "}"
        ]

        var score = 0

        for keyword in keywords where lowercased.contains(keyword) {
            score += 1
        }

        if text.contains("\n") {
            score += 1
        }

        if text.contains("{") && text.contains("}") {
            score += 1
        }

        if text.contains(";") {
            score += 1
        }

        return score >= 2
    }
}
