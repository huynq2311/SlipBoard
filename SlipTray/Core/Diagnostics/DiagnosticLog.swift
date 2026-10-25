import Foundation
import OSLog

/// The one logging entry point. Every entry goes to the unified log and, while
/// the user has "Record diagnostic log" on, to a file they can export.
///
/// HARD RULE: a message must never contain clipboard content, note or snippet
/// text, clip file paths, content hashes (clip IDs embed one), or anything else
/// the user copied or typed. Log only random IDs, kinds, counts, sizes,
/// settings values and error domains/codes (use `describe(_:)` for errors:
/// their descriptions can quote the data involved).
nonisolated struct DiagnosticLogger: Sendable {
    let category: String
    private let logger: Logger

    init(category: String) {
        self.category = category
        logger = Logger(subsystem: "huynq.SlipTray", category: category)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        DiagnosticLogFileSink.shared.appendIfRecording(level: "INFO", category: category, message: message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        DiagnosticLogFileSink.shared.appendIfRecording(level: "ERROR", category: category, message: message)
    }

    /// Domain and code only.
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code)"
    }
}

/// Appends log lines to rotating files under Application Support. Writes run
/// on a serial queue; each line is written straight to the file descriptor,
/// so the lines before a crash are already on disk.
nonisolated final class DiagnosticLogFileSink: @unchecked Sendable {
    static let recordingDefaultsKey = "SlipTray.Diagnostics.recordLog"
    static let shared = DiagnosticLogFileSink()
    private static let maxMessageLength = 2_000
    /// A single character can take many bytes (combining marks).
    private static let maxMessageBytes = 8_000

    let directoryURL: URL
    private let maxFileBytes: UInt64
    private let maxFileCount: Int
    private let queue = DispatchQueue(label: "huynq.SlipTray.DiagnosticLog")
    private let fileManager = FileManager.default
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter
    }()
    private var handle: FileHandle?
    private var currentSize: UInt64 = 0

    init(
        directoryURL: URL = DiagnosticLogFileSink.defaultDirectoryURL,
        maxFileBytes: UInt64 = 2 * 1_024 * 1_024,
        maxFileCount: Int = 3
    ) {
        self.directoryURL = directoryURL
        self.maxFileBytes = maxFileBytes
        self.maxFileCount = maxFileCount
    }

    static var defaultDirectoryURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL
            .appendingPathComponent("SlipTray", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    var isRecording: Bool {
        UserDefaults.standard.bool(forKey: Self.recordingDefaultsKey)
    }

    func appendIfRecording(level: String, category: String, message: String) {
        guard isRecording else { return }
        append(level: level, category: category, message: message, requiresRecording: true)
    }

    /// `requiresRecording` checks again on the queue, so a line that raced a
    /// switch-off cannot recreate the deleted log.
    func append(
        level: String,
        category: String,
        message: String,
        at date: Date = Date(),
        requiresRecording: Bool = false
    ) {
        let singleLine = String(decoding: message.prefix(Self.maxMessageLength).utf8.prefix(Self.maxMessageBytes), as: UTF8.self)
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        queue.async { [self] in
            guard requiresRecording == false || isRecording else { return }
            let line = "\(timestampFormatter.string(from: date)) \(level) [\(category)] \(singleLine)\n"
            write(Data(line.utf8))
        }
    }

    /// Off deletes what was recorded.
    func setRecording(_ isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: Self.recordingDefaultsKey)
        if isOn {
            append(level: "INFO", category: "Diagnostics", message: "Recording started; \(Self.environmentSummary)")
        } else {
            removeAll()
        }
    }

    /// Recorded files, oldest first, once pending writes are done.
    func logFileURLs() -> [URL] {
        queue.sync {
            (0..<maxFileCount).reversed()
                .map(fileURL(index:))
                .filter { fileManager.fileExists(atPath: $0.path) }
        }
    }

    /// Synchronous, so quitting right after a switch-off cannot leave the log behind.
    func removeAll() {
        queue.sync { [self] in
            closeHandle()
            do {
                try fileManager.removeItem(at: directoryURL)
            } catch {
                let nsError = error as NSError
                guard nsError.code != NSFileNoSuchFileError else { return }
                Logger(subsystem: "huynq.SlipTray", category: "Diagnostics")
                    .error("Could not delete the diagnostic log: \(nsError.domain, privacy: .public) \(nsError.code)")
            }
        }
    }

    /// Clears a log left behind when the app quit before a switch-off finished.
    func removeAllIfNotRecording() {
        guard isRecording == false else { return }
        removeAll()
    }

    static var environmentSummary: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "-"
        let build = info["CFBundleVersion"] as? String ?? "-"
        return "SlipTray \(version) (\(build)), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }

    // MARK: - Queue only

    private func fileURL(index: Int) -> URL {
        directoryURL.appendingPathComponent(index == 0 ? "diagnostic.log" : "diagnostic.\(index).log")
    }

    private func write(_ data: Data) {
        guard var handle = openHandleIfNeeded() else { return }
        if currentSize > 0, currentSize + UInt64(data.count) > maxFileBytes {
            rotate()
            guard let reopened = openHandleIfNeeded() else { return }
            handle = reopened
        }
        do {
            try handle.write(contentsOf: data)
            currentSize += UInt64(data.count)
        } catch {
            closeHandle()
        }
    }

    private func openHandleIfNeeded() -> FileHandle? {
        let url = fileURL(index: 0)
        // Reopen if the file was deleted under the open handle.
        if let handle {
            if fileManager.fileExists(atPath: url.path) { return handle }
            closeHandle()
        }
        try? fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // Refuse a symlinked Logs folder (switching off would only remove the
        // link), and tighten one that already existed with wider permissions.
        guard let attributes = try? fileManager.attributesOfItem(atPath: directoryURL.path),
              attributes[.type] as? FileAttributeType == .typeDirectory else {
            return nil
        }
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        // O_NOFOLLOW: never append through a symlink in place of the log file.
        let descriptor = open(url.path, O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { return nil }
        fchmod(descriptor, 0o600)
        let opened = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        guard let size = try? opened.seekToEnd() else {
            try? opened.close()
            return nil
        }
        handle = opened
        currentSize = size
        return opened
    }

    private func rotate() {
        closeHandle()
        try? fileManager.removeItem(at: fileURL(index: maxFileCount - 1))
        for index in stride(from: maxFileCount - 2, through: 0, by: -1) {
            try? fileManager.moveItem(at: fileURL(index: index), to: fileURL(index: index + 1))
        }
    }

    private func closeHandle() {
        try? handle?.close()
        handle = nil
        currentSize = 0
    }
}
