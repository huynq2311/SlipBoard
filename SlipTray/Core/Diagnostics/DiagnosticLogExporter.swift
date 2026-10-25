import AppKit
import Foundation
import UniformTypeIdentifiers

/// Writes one zip with an environment header, the recorded log files and
/// SlipTray's crash reports, for the user to send to the developer.
enum DiagnosticLogExporter {
    private nonisolated static let logger = DiagnosticLogger(category: "Diagnostics")

    /// Returns false when the user picked a destination but the export failed.
    /// Copying and zipping run off the main thread.
    static func exportWithSavePanel(settingsSummary: [String]) async -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "SlipTray-diagnostics-\(fileDateStamp()).zip"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return true }

        let summary = settingsSummary + [
            "Accessibility: \(AccessibilityPermission.isTrusted ? "granted" : "not granted")",
        ]
        do {
            try await Task.detached(priority: .userInitiated) {
                try export(settingsSummary: summary, to: destinationURL)
            }.value
            return true
        } catch {
            logger.error("Export failed: \(DiagnosticLogger.describe(error))")
            return false
        }
    }

    nonisolated static func export(settingsSummary: [String], to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let stagingParentURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let stagingURL = stagingParentURL
            .appendingPathComponent(destinationURL.deletingPathExtension().lastPathComponent, isDirectory: true)
        defer { try? fileManager.removeItem(at: stagingParentURL) }
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)

        let logFiles = try copy(
            DiagnosticLogFileSink.shared.logFileURLs(),
            into: stagingURL.appendingPathComponent("logs", isDirectory: true)
        )
        let crashReports = try copy(
            crashReportURLs(),
            into: stagingURL.appendingPathComponent("crash-reports", isDirectory: true)
        )

        let header = headerText(
            settingsSummary: settingsSummary,
            logFileCount: logFiles.count,
            crashReportNames: crashReports.map(\.lastPathComponent)
        )
        try Data(header.utf8).write(to: stagingURL.appendingPathComponent("header.txt"))

        // `.forUploading` hands back a zip of the directory.
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: stagingURL,
            options: .forUploading,
            error: &coordinatorError
        ) { zipURL in
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    // Keep the old file until the new one is complete.
                    let replacementURL = stagingParentURL.appendingPathComponent("export.zip")
                    try fileManager.copyItem(at: zipURL, to: replacementURL)
                    _ = try fileManager.replaceItemAt(destinationURL, withItemAt: replacementURL)
                } else {
                    try fileManager.copyItem(at: zipURL, to: destinationURL)
                }
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError ?? copyError {
            throw error
        }
        logger.info("Exported \(logFiles.count) log files and \(crashReports.count) crash reports")
    }

    private nonisolated static func headerText(
        settingsSummary: [String],
        logFileCount: Int,
        crashReportNames: [String]
    ) -> String {
        var lines = [
            "SlipTray diagnostic report",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            DiagnosticLogFileSink.environmentSummary,
        ]
        lines += settingsSummary
        lines.append("Log files: \(logFileCount)")
        lines.append("Crash reports: \(crashReportNames.isEmpty ? "none" : crashReportNames.joined(separator: ", "))")
        return lines.joined(separator: "\n") + "\n"
    }

    /// "SlipTray-<date>.ips" only, not other apps whose names start the same way.
    private nonisolated static func crashReportURLs() -> [URL] {
        let reportsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        let urls = (try? FileManager.default.contentsOfDirectory(at: reportsURL, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.lastPathComponent.hasPrefix("SlipTray-") && $0.pathExtension == "ips" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Skips files that vanished meanwhile (a log rotating); any other copy
    /// error fails the export. Returns the ones copied.
    private nonisolated static func copy(_ urls: [URL], into directoryURL: URL) throws -> [URL] {
        guard urls.isEmpty == false else { return [] }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        var copied: [URL] = []
        for url in urls {
            do {
                try FileManager.default.copyItem(at: url, to: directoryURL.appendingPathComponent(url.lastPathComponent))
                copied.append(url)
            } catch {
                if FileManager.default.fileExists(atPath: url.path) { throw error }
            }
        }
        return copied
    }

    private static func fileDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: Date())
    }
}
