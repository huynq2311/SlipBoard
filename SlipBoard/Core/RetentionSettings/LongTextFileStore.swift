import Foundation

/// Very long clips (page source, minified code) used to sit inside the Core Data
/// row and the encrypted payload file in full, which made both slow to load and
/// to rewrite. Past `characterLimit` the full text lives in its own file and the
/// stores keep only the first `characterLimit` characters.
nonisolated struct LongTextFileStore {
    static let characterLimit = 100_000

    let directoryURL: URL

    private var fileManager: FileManager { .default }

    static func head(of text: String) -> String {
        String(text.prefix(characterLimit))
    }

    /// Returns the text to store inline: the full text when it is short or the
    /// file could not be written, otherwise its head.
    func spillIfNeeded(id: String, text: String) -> String {
        guard text.count > Self.characterLimit else {
            return text
        }

        let fileURL = url(for: id)
        let existingSize = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? nil
        if existingSize != text.utf8.count {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            guard (try? text.write(to: fileURL, atomically: true, encoding: .utf8)) != nil else {
                return text
            }
        }
        return Self.head(of: text)
    }

    /// Restores the full text when `storedText` is a head with a file behind it.
    func restore(id: String, storedText: String) -> String {
        guard storedText.count == Self.characterLimit,
              let fullText = try? String(contentsOf: url(for: id), encoding: .utf8),
              fullText.hasPrefix(storedText)
        else {
            return storedText
        }
        return fullText
    }

    func remove(ids: [String]) {
        for id in ids {
            try? fileManager.removeItem(at: url(for: id))
        }
    }

    func prune(keeping ids: Set<String>) {
        let names = (try? fileManager.contentsOfDirectory(atPath: directoryURL.path)) ?? []
        let keptNames = Set(ids.map(fileName(for:)))
        for name in names where keptNames.contains(name) == false {
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(name))
        }
    }

    private func url(for id: String) -> URL {
        directoryURL.appendingPathComponent(fileName(for: id))
    }

    private func fileName(for id: String) -> String {
        let safe = id.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" }
        return String(safe) + ".txt"
    }
}
