import Foundation

struct FTSNormalizer: Sendable {
    static func normalize(_ text: String) -> String {
        // Step 1: Unicode NFC
        var normalized = text.precomposedStringWithCanonicalMapping
        
        // Step 2: Lowercase
        normalized = normalized.lowercased()
        
        // Step 3: Smart quote normalization -> " / '
        let smartQuotes = [
            "“": "\"", "”": "\"", "„": "\"", "‟": "\"",
            "‘": "'", "’": "'", "‚": "'", "‛": "'"
        ]
        for (smart, replacement) in smartQuotes {
            normalized = normalized.replacingOccurrences(of: smart, with: replacement)
        }
        
        // Step 4: Strip zero-width characters (U+200B, U+200C, U+200D, U+FEFF, U+00AD)
        let zeroWidthChars = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}", "\u{00AD}"]
        for char in zeroWidthChars {
            normalized = normalized.replacingOccurrences(of: char, with: "")
        }
        
        // Step 6: URL token hint — host+path only
        var hints = [String]()
        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") {
            if let url = URL(string: normalized), let host = url.host {
                let path = url.path
                hints.append("\(host)\(path)")
            }
        }
        
        // Step 7: Code token hint — strip comments (//, --, #, /*, */)
        var codeCleaned = normalized
        
        // Remove block comments /* ... */
        while let startRange = codeCleaned.range(of: "/*") {
            if let endRange = codeCleaned.range(of: "*/", range: startRange.upperBound..<codeCleaned.endIndex) {
                codeCleaned.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            } else {
                codeCleaned.removeSubrange(startRange.lowerBound..<codeCleaned.endIndex)
                break
            }
        }
        
        // Remove line comments (//, --, #)
        let lineCommentPrefixes = ["//", "#", "--"]
        var lines = [String]()
        codeCleaned.enumerateLines { line, _ in
            var cleanedLine = line
            for prefix in lineCommentPrefixes {
                if let range = cleanedLine.range(of: prefix) {
                    cleanedLine = String(cleanedLine[..<range.lowerBound])
                    break
                }
            }
            lines.append(cleanedLine)
        }
        codeCleaned = lines.joined(separator: " ")
        
        // Combine code and hints
        let combined = codeCleaned + " " + hints.joined(separator: " ")
        
        // Step 5: Collapse whitespace runs to single space; trim
        let components = combined.components(separatedBy: .whitespacesAndNewlines)
        let filtered = components.filter { !$0.isEmpty }
        return filtered.joined(separator: " ")
    }
}

