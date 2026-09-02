import AppKit
import Foundation

enum ClipboardApplicationSummaryFactory {
    static func makeSummary(from app: NSRunningApplication?) -> ClipboardSourceAppSummary {
        guard let app else {
            return ClipboardSourceAppSummary(
                displayName: "System",
                symbolName: "square.stack.3d.up",
                accentToken: "accent.secondary"
            )
        }

        let bundleID = app.bundleIdentifier
        let displayName = app.localizedName ?? bundleID ?? "System"

        return ClipboardSourceAppSummary(
            bundleID: bundleID,
            displayName: displayName,
            symbolName: symbolName(for: bundleID, displayName: displayName),
            accentToken: accentToken(for: bundleID, displayName: displayName)
        )
    }

    static func symbolName(for bundleID: String?, displayName: String) -> String {
        let label = (bundleID ?? displayName).lowercased()

        if label.contains("terminal") {
            return "terminal"
        }
        if label.contains("xcode") {
            return "hammer"
        }
        if label.contains("safari") {
            return "safari"
        }
        if label.contains("finder") {
            return "folder"
        }
        if label.contains("figma") {
            return "paintpalette"
        }
        if label.contains("slack") {
            return "bubble.left.and.bubble.right"
        }

        return "app"
    }

    static func accentToken(for bundleID: String?, displayName: String) -> String {
        let label = (bundleID ?? displayName).lowercased()

        if label.contains("terminal") {
            return "accent.info"
        }
        if label.contains("finder") {
            return "accent.warning"
        }
        if label.contains("safari") || label.contains("slack") {
            return "accent.success"
        }

        return "accent.primary"
    }
}

final class PasteboardMonitor: ClipboardPasteboardMonitoring {
    typealias IgnoredSampleHandler = (_ changeCount: Int, _ reason: String) -> Void

    var latestChangeCount: Int
    var isRunning: Bool { timer != nil }
    var onSample: ((ClipboardCaptureSample) -> Void)?
    var onIgnoredSample: IgnoredSampleHandler?

    private let pasteboard: NSPasteboard
    private let workspace: NSWorkspace
    private let classifier: ClipboardContentClassifier
    private let pollInterval: TimeInterval
    private let timerQueue: DispatchQueue
    private var timer: DispatchSourceTimer?

    init(
        pasteboard: NSPasteboard = .general,
        workspace: NSWorkspace = .shared,
        classifier: ClipboardContentClassifier = ClipboardContentClassifier(),
        pollInterval: TimeInterval = 0.75,
        timerQueue: DispatchQueue = .main
    ) {
        self.pasteboard = pasteboard
        self.workspace = workspace
        self.classifier = classifier
        self.pollInterval = pollInterval
        self.timerQueue = timerQueue
        self.latestChangeCount = pasteboard.changeCount
    }

    deinit {
        stop()
    }

    func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            self?.pollNow()
        }
        timer.resume()

        self.timer = timer
    }

    func stop() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    func pollNow() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != latestChangeCount else { return }

        latestChangeCount = currentChangeCount
        let capturedAt = Date()
        let sourceApp = currentFrontmostApplication()

        switch classifier.classify(
            pasteboard: pasteboard,
            changeCount: currentChangeCount,
            capturedAt: capturedAt,
            sourceApp: sourceApp
        ) {
        case .sample(let sample):
            onSample?(sample)
        case .ignored(let reason):
            onIgnoredSample?(currentChangeCount, reason)
        }
    }

    // Best-effort only: this is sampled when the poll notices a new changeCount,
    // so focus may already have moved away from the original copy source.
    private func currentFrontmostApplication() -> ClipboardSourceAppSummary {
        ClipboardApplicationSummaryFactory.makeSummary(from: workspace.frontmostApplication)
    }
}
