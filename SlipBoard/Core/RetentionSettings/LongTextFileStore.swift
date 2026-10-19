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

    // Every history change rewrites and reloads all stored clips. Without this,
    // each copy re-hashed and re-read every multi-megabyte file. Entries are
    // keyed by the content-addressed file name, so a match is the same text.
    private final class Memo: @unchecked Sendable {
        let lock = NSLock()
        var textByFileName: [String: String] = [:]
        var fileNameByID: [String: (text: String, fileName: String, head: String)] = [:]
        /// Clips whose stored text is over `characterLimit` bytes but not over
        /// it in characters (multi-byte scripts), by id and byte count.
        var shortByID: [String: Int] = [:]
    }

    private static let memo = Memo()

    private static func memoized(_ name: String) -> String? {
        memo.lock.lock(); defer { memo.lock.unlock() }
        return memo.textByFileName[name]
    }

    /// Comparing against the remembered text is a pointer check when the caller
    /// passes the same string again, which is the common case.
    private static func knownEntry(id: String, text: String) -> (fileName: String, head: String)? {
        memo.lock.lock(); defer { memo.lock.unlock() }
        guard let entry = memo.fileNameByID[id], entry.text == text else { return nil }
        return (entry.fileName, entry.head)
    }

    private static func isKnownShort(id: String, byteCount: Int) -> Bool {
        memo.lock.lock(); defer { memo.lock.unlock() }
        return memo.shortByID[id] == byteCount
    }

    private static func rememberShort(id: String, byteCount: Int) {
        memo.lock.lock(); defer { memo.lock.unlock() }
        memo.shortByID[id] = byteCount
    }

    /// The remembered full text for `id` when its head is `storedText`.
    private static func knownText(id: String, head: String) -> String? {
        memo.lock.lock(); defer { memo.lock.unlock() }
        guard let entry = memo.fileNameByID[id], entry.head == head else { return nil }
        return entry.text
    }

    private static func remember(id: String, text: String, fileName: String) {
        memo.lock.lock(); defer { memo.lock.unlock() }
        memo.fileNameByID[id] = (text, fileName, head(of: text))
        memo.textByFileName[fileName] = text
    }

    private static func forget(_ name: String) {
        memo.lock.lock(); defer { memo.lock.unlock() }
        memo.textByFileName.removeValue(forKey: name)
        memo.fileNameByID = memo.fileNameByID.filter { $0.value.fileName != name }
    }

    /// True when `text` has more than `characterLimit` characters, without
    /// counting all of a multi-megabyte string.
    private static func exceedsLimit(_ text: String) -> Bool {
        guard text.utf8.count > characterLimit else { return false }
        return text.index(text.startIndex, offsetBy: characterLimit, limitedBy: text.endIndex)
            .map { $0 < text.endIndex } ?? false
    }

    static func head(of text: String) -> String {
        String(text.prefix(characterLimit))
    }

    /// `storedText` is what to store inline: the full text when it is short or
    /// the file could not be written, otherwise its head. `fileName` is the file
    /// that holds the full text, if any.
    func spillIfNeeded(id: String, text: String) -> (storedText: String, fileName: String?) {
        // A text seen before is known to be long; skip measuring it and cutting
        // its head again, which walks 100,000 characters per clip per save.
        let known = Self.knownEntry(id: id, text: text)
        guard known != nil || Self.exceedsLimit(text) else {
            return (text, nil)
        }

        let name = known?.fileName ?? fileName(for: id, text: text)
        let fileURL = directoryURL.appendingPathComponent(name)
        let existingSize = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? nil
        if existingSize != text.utf8.count {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            guard (try? text.write(to: fileURL, atomically: true, encoding: .utf8)) != nil else {
                return (text, nil)
            }
        }
        if let known {
            return (known.head, name)
        }
        Self.remember(id: id, text: text, fileName: name)
        return (Self.head(of: text), name)
    }

    /// Restores the full text when `storedText` is a head with a matching file
    /// behind it. A missing or damaged file leaves the head.
    func restore(id: String, storedText: String) -> String {
        // A head of `characterLimit` characters has at least that many bytes;
        // the O(1) byte count rules out almost every clip.
        let byteCount = storedText.utf8.count
        guard byteCount >= Self.characterLimit,
              Self.isKnownShort(id: id, byteCount: byteCount) == false else {
            return storedText
        }

        // Same clip as last time: no directory listing, no file read. Checked
        // before the character count below, which is slow on the bridged
        // strings Core Data returns; a match is a head of the right length.
        if let fullText = Self.knownText(id: id, head: storedText) {
            return fullText
        }

        guard storedText.count == Self.characterLimit else {
            Self.rememberShort(id: id, byteCount: byteCount)
            return storedText
        }

        let candidates = files(forIDHash: idHash(id))
            .sorted { modificationDate($0) > modificationDate($1) }
        for url in candidates {
            if let fullText = Self.memoized(url.lastPathComponent), fullText.hasPrefix(storedText) {
                Self.remember(id: id, text: fullText, fileName: url.lastPathComponent)
                return fullText
            }
            guard let fullText = try? String(contentsOf: url, encoding: .utf8),
                  fullText.hasPrefix(storedText),
                  url.lastPathComponent == fileName(for: id, text: fullText)
            else {
                continue
            }
            Self.remember(id: id, text: fullText, fileName: url.lastPathComponent)
            return fullText
        }

        // Files written before they were content-addressed are named `<hash of id>.txt`
        // and carry no checksum; the next save rewrites them under the new name.
        if let fullText = try? String(contentsOf: legacyURL(for: id), encoding: .utf8),
           fullText.hasPrefix(storedText) {
            return fullText
        }
        return storedText
    }

    func remove(ids: [String]) {
        for id in ids {
            for url in files(forIDHash: idHash(id)) {
                try? fileManager.removeItem(at: url)
                Self.forget(url.lastPathComponent)
            }
            try? fileManager.removeItem(at: legacyURL(for: id))
        }
    }

    /// Deletes every file not in `keeping`, or only those of `ids` when given.
    /// Files of `protectedIDs` stay: those clips were loaded as a bare head
    /// (a restore that failed), and saving that head must not destroy the file.
    func prune(keeping fileNames: Set<String>, protecting protectedIDs: Set<String> = [], forIDs ids: [String]? = nil) {
        let scope = ids.map { Set($0.map(idHash(_:))) }
        let protectedHashes = Set(protectedIDs.map(idHash(_:)))
        for name in (try? fileManager.contentsOfDirectory(atPath: directoryURL.path)) ?? [] {
            guard fileNames.contains(name) == false else { continue }
            let nameHash = String(name.prefix(Self.hashLength))
            if protectedHashes.contains(nameHash) { continue }
            if let scope, scope.contains(nameHash) == false { continue }
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(name))
            Self.forget(name)
        }
    }

    private static let hashLength = 32

    private func files(forIDHash hash: String) -> [URL] {
        ((try? fileManager.contentsOfDirectory(atPath: directoryURL.path)) ?? [])
            .filter { $0.hasPrefix(hash + "-") }
            .map { directoryURL.appendingPathComponent($0) }
    }

    private func legacyURL(for id: String) -> URL {
        directoryURL.appendingPathComponent(idHash(id) + ".txt")
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
