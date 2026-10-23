import Foundation

enum ClipboardHistoryMockFixtures {
    static let terminalApp = ClipboardSourceAppSummary(
        bundleID: "com.apple.Terminal",
        displayName: "Terminal",
        symbolName: "terminal",
        accentToken: "accent.info"
    )

    static let xcodeApp = ClipboardSourceAppSummary(
        bundleID: "com.apple.dt.Xcode",
        displayName: "Xcode",
        symbolName: "hammer",
        accentToken: "accent.primary"
    )

    static let safariApp = ClipboardSourceAppSummary(
        bundleID: "com.apple.Safari",
        displayName: "Safari",
        symbolName: "safari",
        accentToken: "accent.success"
    )

    static let finderApp = ClipboardSourceAppSummary(
        bundleID: "com.apple.finder",
        displayName: "Finder",
        symbolName: "folder",
        accentToken: "accent.warning"
    )

    static let baseDate = Date(timeIntervalSince1970: 1_785_584_400)

    static let pinnedItems: [ClipboardHistoryItem] = [
        ClipboardHistoryItem(
            id: "clip-pinned-url-01",
            capturedAt: baseDate.addingTimeInterval(-1_800),
            lastCopiedAt: baseDate.addingTimeInterval(-120),
            kind: .url,
            normalizedHash: "hash-pinned-launch",
            primaryText: "https://sliptray.local/launch-checklist",
            secondaryText: "Launch checklist and shipping notes",
            metadataText: "Safari",
            secondaryBadgeText: "Pinned",
            previewStyle: .url,
            sourceApp: safariApp,
            isPinned: true
        ),
        ClipboardHistoryItem(
            id: "clip-pinned-color-01",
            capturedAt: baseDate.addingTimeInterval(-3_200),
            lastCopiedAt: baseDate.addingTimeInterval(-640),
            kind: .color,
            normalizedHash: "hash-brand-swatch",
            primaryText: "#7C6EF8",
            secondaryText: "Brand accent swatch",
            metadataText: "Figma export",
            secondaryBadgeText: "Brand",
            previewStyle: .color(swatches: ["#7C6EF8", "#38BDF8", "#3ECF8E"]),
            sourceApp: ClipboardSourceAppSummary(
                bundleID: "com.figma.Desktop",
                displayName: "Figma",
                symbolName: "paintpalette",
                accentToken: "accent.primary"
            ),
            isPinned: true,
            colorSwatches: ["#7C6EF8", "#38BDF8", "#3ECF8E"]
        )
    ]

    static let recentItems: [ClipboardHistoryItem] = [
        ClipboardHistoryItem(
            id: "clip-recent-code-01",
            capturedAt: baseDate.addingTimeInterval(-90),
            lastCopiedAt: baseDate.addingTimeInterval(-90),
            kind: .code,
            normalizedHash: "hash-swift-build-command",
            primaryText: "swift build --configuration release",
            secondaryText: "Release build command",
            metadataText: "Terminal",
            secondaryBadgeText: "Swift",
            previewStyle: .code(languageHint: "sh"),
            sourceApp: terminalApp
        ),
        ClipboardHistoryItem(
            id: "clip-recent-file-01",
            capturedAt: baseDate.addingTimeInterval(-240),
            lastCopiedAt: baseDate.addingTimeInterval(-240),
            kind: .file,
            normalizedHash: "hash-release-notes-pdf",
            primaryText: "Release Notes.pdf",
            secondaryText: "/Users/demo/Desktop/Release Notes.pdf",
            metadataText: "Finder",
            secondaryBadgeText: "PDF",
            previewStyle: .file(fileExtension: "pdf"),
            sourceApp: finderApp,
            filePaths: ["/Users/demo/Desktop/Release Notes.pdf"]
        ),
        ClipboardHistoryItem(
            id: "clip-recent-text-01",
            capturedAt: baseDate.addingTimeInterval(-420),
            lastCopiedAt: baseDate.addingTimeInterval(-420),
            kind: .text,
            normalizedHash: "hash-qa-summary",
            primaryText: "QA ready after live popup wiring and selection audit.",
            secondaryText: "Clipboard history checklist",
            metadataText: "Xcode",
            previewStyle: .text,
            sourceApp: xcodeApp
        )
    ]

    static let duplicateContentSamples: [ClipboardCaptureSample] = [
        ClipboardCaptureSample(
            changeCount: 211,
            capturedAt: baseDate.addingTimeInterval(-40),
            kind: .code,
            rawString: "swift build --configuration release\n",
            normalizedText: "swift build --configuration release",
            normalizedHash: "hash-swift-build-command",
            sourceApp: terminalApp
        ),
        ClipboardCaptureSample(
            changeCount: 212,
            capturedAt: baseDate.addingTimeInterval(-10),
            kind: .code,
            rawString: "swift build --configuration release",
            normalizedText: "swift build --configuration release",
            normalizedHash: "hash-swift-build-command",
            sourceApp: xcodeApp
        )
    ]

    static let recentCaptureSamples: [ClipboardCaptureSample] = [
        ClipboardCaptureSample(
            changeCount: 205,
            capturedAt: baseDate.addingTimeInterval(-240),
            kind: .file,
            rawString: "/Users/demo/Desktop/Release Notes.pdf",
            filePaths: ["/Users/demo/Desktop/Release Notes.pdf"],
            normalizedText: "/Users/demo/Desktop/Release Notes.pdf",
            normalizedHash: "hash-release-notes-pdf",
            sourceApp: finderApp
        ),
        ClipboardCaptureSample(
            changeCount: 206,
            capturedAt: baseDate.addingTimeInterval(-90),
            kind: .code,
            rawString: "swift build --configuration release",
            normalizedText: "swift build --configuration release",
            normalizedHash: "hash-swift-build-command",
            sourceApp: terminalApp
        )
    ]

    static let snapshot = ClipboardHistorySnapshot(
        selectedItemID: recentItems.first?.id,
        searchQuery: "",
        activeFilter: .all,
        captureStatus: .active(latestCaptureAt: baseDate.addingTimeInterval(-10)),
        pinnedItems: pinnedItems,
        recentItems: recentItems
    )

    static let searchFocusedSnapshot = ClipboardHistorySnapshot(
        selectedItemID: pinnedItems.first?.id,
        searchQuery: "launch",
        activeFilter: .url,
        captureStatus: .active(latestCaptureAt: baseDate.addingTimeInterval(-10)),
        pinnedItems: pinnedItems,
        recentItems: recentItems
    )

    static let unsupportedSampleStatus: ClipboardCaptureStatus = .unsupportedSampleIgnored(
        reason: "Binary payload omitted from the in-memory fixture set.",
        lastChangeCount: 213
    )
}
