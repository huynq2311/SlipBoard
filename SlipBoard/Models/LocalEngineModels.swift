import Foundation

// MARK: - Raw Pasteboard Snapshot

/// A value-type snapshot of what was found on NSPasteboard at capture time.
/// Carries raw content representations; no NSPasteboard reference is retained.
/// Used as the input contract for ContentClassifier and ClipboardMonitorServiceProtocol.
struct RawPasteboardSnapshot: Equatable, Sendable {
    /// Plain text from the pasteboard, if present.
    let plainText: String?
    /// Raw attributed-string data (RTF/RTFD), if present.
    let attributedStringData: Data?
    /// File URLs from the pasteboard, if present.
    let fileURLs: [URL]?
    /// Raw image data (TIFF/PNG/JPEG), if present.
    let imageData: Data?
    /// The bundle identifier of the source application, if available.
    let sourceBundleID: String?
    /// The display name of the source application, if available.
    let sourceAppName: String?
    /// The time at which this snapshot was taken.
    let capturedAt: Date

    init(
        plainText: String? = nil,
        attributedStringData: Data? = nil,
        fileURLs: [URL]? = nil,
        imageData: Data? = nil,
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.plainText = plainText
        self.attributedStringData = attributedStringData
        self.fileURLs = fileURLs
        self.imageData = imageData
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.capturedAt = capturedAt
    }
}

// MARK: - Detected Sub-Type

/// Fine-grained sub-classification derived from the plain-text content.
enum DetectedSubType: String, Equatable, CaseIterable, Sendable {
    case email
    case phone
    case hexColor
    case filePath
    case urlScheme
    case codeLanguageHint
}

// MARK: - Classified Content

/// Output of ContentClassifier — the type + optional sub-type + normalised plain text
/// ready for FTS indexing when the engine layer is wired to storage.
struct ClassifiedContent: Equatable, Sendable {
    let itemType: ClipboardContentKind
    let detectedSubType: DetectedSubType?
    /// Whitespace-normalised, Unicode-NFC plain-text representation, used for FTS5 later.
    let normalizedPlainText: String?
}

// MARK: - Source App Context

/// The source-application identity extracted from a raw pasteboard snapshot.
struct SourceAppContext: Equatable, Sendable {
    let bundleID: String?
    let appName: String?

    init(bundleID: String? = nil, appName: String? = nil) {
        self.bundleID = bundleID
        self.appName = appName
    }
}

// MARK: - Pause State

/// Whether clipboard capture is currently paused and until when.
enum PauseState: Equatable, Sendable {
    case active
    case pausedUntil(Date)
    case pausedIndefinitely
}

// MARK: - App Filter Config

/// Runtime configuration for AppFilter: which bundle IDs are excluded and
/// whether capture is paused.
struct AppFilterConfig: Equatable, Sendable {
    /// Bundle IDs that should never be captured (case-insensitive comparison).
    let excludedBundleIDs: [String]
    let pauseState: PauseState

    init(excludedBundleIDs: [String] = [], pauseState: PauseState = .active) {
        self.excludedBundleIDs = excludedBundleIDs
        self.pauseState = pauseState
    }
}

// MARK: - Capture Decision

/// The result of AppFilter evaluation.
enum CaptureSkipReason: String, Equatable, Sendable {
    case appExcluded
    case paused
}

enum CaptureDecision: Equatable, Sendable {
    case capture
    case skip(reason: CaptureSkipReason)
}

// MARK: - TTL Policy

/// How long items are retained before automatic cleanup.
enum TTLPolicy: Equatable, Sendable {
    /// Retain items for the given number of days.
    case days(Int)
    /// Never automatically remove items by age.
    case never
}

// MARK: - Retention Config

/// User-configured retention rules used by RetentionEvaluator.
struct RetentionConfig: Equatable, Sendable {
    /// Maximum number of items to keep (100 – 2000). Items beyond this rank are removed.
    let maxItemCount: Int
    /// Age-based cleanup policy.
    let ttlPolicy: TTLPolicy
    /// Whether to clear all non-pinned items when the app quits.
    let clearOnQuit: Bool

    init(maxItemCount: Int = 2000, ttlPolicy: TTLPolicy = .days(30), clearOnQuit: Bool = false) {
        self.maxItemCount = maxItemCount
        self.ttlPolicy = ttlPolicy
        self.clearOnQuit = clearOnQuit
    }
}

// MARK: - Item Retention Snapshot

/// Lightweight view of a single item's metadata needed by RetentionEvaluator.
struct ItemRetentionSnapshot: Equatable, Sendable {
    let itemID: String
    let createdAt: Date
    let isPinned: Bool
    /// Zero-based position in the timeline sorted by `last_copied_at` descending (0 = most recent).
    let rankIndex: Int
}

// MARK: - Retention Verdict

/// Whether an item should be kept or removed, and why.
enum RetentionVerdict: Equatable, Sendable {
    case keep
    case removeByAge
    case removeByCount
}
