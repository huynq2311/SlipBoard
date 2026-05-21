import Foundation

// MARK: - Engine Fixtures
// Mock data for engine-layer type-checking and future unit tests.
// All values use a fixed reference date so tests are deterministic.

enum EngineFixtures {

    // MARK: - Fixed Reference Date

    /// Fixed anchor so all fixture dates are deterministic.
    static let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func date(daysAgo: Double) -> Date {
        referenceDate.addingTimeInterval(-daysAgo * 86_400)
    }

    private static func date(hoursAgo: Double) -> Date {
        referenceDate.addingTimeInterval(-hoursAgo * 3_600)
    }

    // MARK: - RawPasteboardSnapshot Fixtures

    /// A simple plain-text snapshot from a notes app.
    static let plainTextSnapshot = RawPasteboardSnapshot(
        plainText: "Hello, this is a plain text clipboard item.",
        attributedStringData: nil,
        fileURLs: nil,
        imageData: nil,
        sourceBundleID: "com.apple.Notes",
        sourceAppName: "Notes",
        capturedAt: date(hoursAgo: 0.5)
    )

    /// A URL snapshot from Safari.
    static let urlSnapshot = RawPasteboardSnapshot(
        plainText: "https://example.com/bridge-preview",
        attributedStringData: nil,
        fileURLs: nil,
        imageData: nil,
        sourceBundleID: "com.apple.Safari",
        sourceAppName: "Safari",
        capturedAt: date(hoursAgo: 1)
    )

    /// An email-address plain-text snapshot.
    static let emailSnapshot = RawPasteboardSnapshot(
        plainText: "hello@example.com",
        attributedStringData: nil,
        fileURLs: nil,
        imageData: nil,
        sourceBundleID: "com.apple.mail",
        sourceAppName: "Mail",
        capturedAt: date(hoursAgo: 2)
    )

    /// A hex-color snapshot from Figma.
    static let hexColorSnapshot = RawPasteboardSnapshot(
        plainText: "#D08C34",
        attributedStringData: nil,
        fileURLs: nil,
        imageData: nil,
        sourceBundleID: "com.figma.Desktop",
        sourceAppName: "Figma",
        capturedAt: date(hoursAgo: 3)
    )

    /// A Swift code snippet from Xcode.
    static let codeSnapshot = RawPasteboardSnapshot(
        plainText: "func publishSelection() {\n    // local bridge stub\n    let result = bridge.flush()\n    guard result.isSuccess else { return }\n    delegate?.didPublish(result)\n}",
        attributedStringData: nil,
        fileURLs: nil,
        imageData: nil,
        sourceBundleID: "com.apple.dt.Xcode",
        sourceAppName: "Xcode",
        capturedAt: date(hoursAgo: 4)
    )

    /// A file URL snapshot from Finder.
    static let fileSnapshot = RawPasteboardSnapshot(
        plainText: nil,
        attributedStringData: nil,
        fileURLs: [URL(fileURLWithPath: "/Users/user/Documents/popup-layout.pdf")],
        imageData: nil,
        sourceBundleID: "com.apple.finder",
        sourceAppName: "Finder",
        capturedAt: date(hoursAgo: 5)
    )

    /// A snapshot with image data.
    static let imageSnapshot = RawPasteboardSnapshot(
        plainText: nil,
        attributedStringData: nil,
        fileURLs: nil,
        imageData: Data([0x89, 0x50, 0x4E, 0x47]), // PNG header stub
        sourceBundleID: "com.apple.Preview",
        sourceAppName: "Preview",
        capturedAt: date(hoursAgo: 6)
    )

    /// Snapshot from an excluded app (1Password).
    static let excludedAppSnapshot = RawPasteboardSnapshot(
        plainText: "super-secret-password-123",
        attributedStringData: nil,
        fileURLs: nil,
        imageData: nil,
        sourceBundleID: "com.agilebits.onepassword7-osx",
        sourceAppName: "1Password 7",
        capturedAt: date(hoursAgo: 0.1)
    )

    static let allSnapshots: [RawPasteboardSnapshot] = [
        plainTextSnapshot,
        urlSnapshot,
        emailSnapshot,
        hexColorSnapshot,
        codeSnapshot,
        fileSnapshot,
        imageSnapshot,
        excludedAppSnapshot
    ]

    // MARK: - SourceAppContext Fixtures

    static let notesContext = SourceAppContext(bundleID: "com.apple.Notes", appName: "Notes")
    static let safariContext = SourceAppContext(bundleID: "com.apple.Safari", appName: "Safari")
    static let xcodeContext = SourceAppContext(bundleID: "com.apple.dt.Xcode", appName: "Xcode")
    static let onePasswordContext = SourceAppContext(
        bundleID: "com.agilebits.onepassword7-osx",
        appName: "1Password 7"
    )
    static let unknownContext = SourceAppContext(bundleID: nil, appName: nil)

    // MARK: - AppFilterConfig Fixtures

    /// Default config: no exclusions, capturing active.
    static let defaultFilterConfig = AppFilterConfig(
        excludedBundleIDs: [],
        pauseState: .active
    )

    /// Config excluding 1Password and a banking app.
    static let exclusionFilterConfig = AppFilterConfig(
        excludedBundleIDs: [
            "com.agilebits.onepassword7-osx",
            "com.apple.banking"
        ],
        pauseState: .active
    )

    /// Config with capture paused for 1 hour.
    static let pausedUntilConfig = AppFilterConfig(
        excludedBundleIDs: [],
        pauseState: .pausedUntil(referenceDate.addingTimeInterval(3_600))
    )

    /// Config with capture paused indefinitely.
    static let pausedIndefinitelyConfig = AppFilterConfig(
        excludedBundleIDs: [],
        pauseState: .pausedIndefinitely
    )

    // MARK: - RetentionConfig Fixtures

    /// Default retention: max 2000 items, keep 30 days.
    static let defaultRetentionConfig = RetentionConfig(
        maxItemCount: 2000,
        ttlPolicy: .days(30),
        clearOnQuit: false
    )

    /// Aggressive retention: max 100 items, keep 7 days.
    static let aggressiveRetentionConfig = RetentionConfig(
        maxItemCount: 100,
        ttlPolicy: .days(7),
        clearOnQuit: true
    )

    /// Unlimited retention: max 2000 items, never clear by age.
    static let unlimitedRetentionConfig = RetentionConfig(
        maxItemCount: 2000,
        ttlPolicy: .never,
        clearOnQuit: false
    )

    // MARK: - ItemRetentionSnapshot Fixtures

    /// A recent non-pinned item within all limits.
    static let recentItem = ItemRetentionSnapshot(
        itemID: "item-recent",
        createdAt: date(daysAgo: 1),
        isPinned: false,
        rankIndex: 0
    )

    /// An old item exceeding a 7-day TTL.
    static let oldItem = ItemRetentionSnapshot(
        itemID: "item-old",
        createdAt: date(daysAgo: 45),
        isPinned: false,
        rankIndex: 10
    )

    /// A pinned item — always kept regardless of age or rank.
    static let pinnedItem = ItemRetentionSnapshot(
        itemID: "item-pinned",
        createdAt: date(daysAgo: 120),
        isPinned: true,
        rankIndex: 5
    )

    /// An item ranked beyond the max-item-count limit.
    static let overLimitItem = ItemRetentionSnapshot(
        itemID: "item-over-limit",
        createdAt: date(daysAgo: 2),
        isPinned: false,
        rankIndex: 200
    )
}
