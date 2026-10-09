import CryptoKit
import Foundation

/// Very long clips (page source, minified code) used to sit inside the Core Data
/// row and the encrypted payload file in full, which made both slow to load and
/// to rewrite. Past `characterLimit` the full text lives in its own file and the
/// stores keep only the first `characterLimit` characters.
///
/// Files are content-addressed: `<hash of id>-<hash of text>.txt`. A changed text
/// gets a new file, the old one stays until the caller prunes it after the
/// Core Data save, and a file whose content no longer matches its name is ignored.
nonisolated struct LongTextFileStore {
    static let characterLimit = 100_000

    let directoryURL: URL

    private var fileManager: FileManager { .default }

    static func head(of text: String) -> String {
        String(text.prefix(characterLimit))
    }

    /// `storedText` is what to store inline: the full text when it is short or
    /// the file could not be written, otherwise its head. `fileName` is the file
    /// that holds the full text, if any.
    func spillIfNeeded(id: String, text: String) -> (storedText: String, fileName: String?) {
        guard text.count > Self.characterLimit else {
            return (text, nil)
        }

        let name = fileName(for: id, text: text)
        let fileURL = directoryURL.appendingPathComponent(name)
        if fileManager.fileExists(atPath: fileURL.path) == false {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            guard (try? text.write(to: fileURL, atomically: true, encoding: .utf8)) != nil else {
                return (text, nil)
            }
        }
        return (Self.head(of: text), name)
    }

    /// Restores the full text when `storedText` is a head with a matching file
    /// behind it. A missing or damaged file leaves the head.
    func restore(id: String, storedText: String) -> String {
        guard storedText.count == Self.characterLimit else {
            return storedText
        }

        let candidates = files(forIDHash: idHash(id))
            .sorted { modificationDate($0) > modificationDate($1) }
        for url in candidates {
            guard let fullText = try? String(contentsOf: url, encoding: .utf8),
                  fullText.hasPrefix(storedText),
                  url.lastPathComponent == fileName(for: id, text: fullText)
            else {
                continue
            }
            return fullText
        }

        // Files written before they were content-addressed are named `<hash of id>.txt`
        // and carry no checksum; the next save rewrites them under the new name.
        let legacyURL = directoryURL.appendingPathComponent(idHash(id) + ".txt")
        if let fullText = try? String(contentsOf: legacyURL, encoding: .utf8),
           fullText.hasPrefix(storedText) {
            return fullText
        }
        return storedText
    }

    func remove(ids: [String]) {
        for id in ids {
            for url in files(forIDHash: idHash(id)) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// Deletes every file not in `keeping`, or only those of `ids` when given.
    func prune(keeping fileNames: Set<String>, forIDs ids: [String]? = nil) {
        let scope = ids.map { Set($0.map(idHash(_:))) }
        for name in (try? fileManager.contentsOfDirectory(atPath: directoryURL.path)) ?? [] {
            guard fileNames.contains(name) == false else { continue }
            if let scope, scope.contains(String(name.prefix(Self.hashLength))) == false { continue }
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(name))
        }
    }

    private static let hashLength = 32

    private func files(forIDHash hash: String) -> [URL] {
        ((try? fileManager.contentsOfDirectory(atPath: directoryURL.path)) ?? [])
            .filter { $0.hasPrefix(hash + "-") }
            .map { directoryURL.appendingPathComponent($0) }
    }

    private func modificationDate(_ url: URL) -> Date {
        ((try? fileManager.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date) ?? .distantPast
    }

    private func idHash(_ id: String) -> String {
        Self.hex(SHA256.hash(data: Data(id.utf8)), count: Self.hashLength)
    }

    private func fileName(for id: String, text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return idHash(id) + "-" + Self.hex(digest, count: 32) + ".txt"
    }

    private static func hex(_ digest: SHA256.Digest, count: Int) -> String {
        String(digest.map { String(format: "%02x", $0) }.joined().prefix(count))
    }
}
