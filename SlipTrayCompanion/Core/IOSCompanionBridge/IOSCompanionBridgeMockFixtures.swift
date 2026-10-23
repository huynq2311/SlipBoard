import Foundation

enum IOSCompanionBridgeMockFixtures {
    static let inboundItem = CompanionInboundReviewItem(
        id: "mac-paste-001", payloadKind: .text, payloadText: "Ready to paste", normalizedHash: "fixture-hash",
        sourceDeviceName: "MacBook Pro", createdAt: .now, expiresAt: .now.addingTimeInterval(600)
    )

    static let manualImport = CompanionImportDraft(
        id: UUID(), source: .manualClipboard, payloadKind: .text, payloadText: "Manual import", normalizedHash: "manual-hash",
        capturedAt: .now, sourceAppName: nil
    )

    static let shareImport = CompanionImportDraft(
        id: UUID(), source: .shareExtension, payloadKind: .url, payloadText: "https://example.com", normalizedHash: "share-hash",
        capturedAt: .now, sourceAppName: "Safari"
    )

    static let widgetShortcutImport = CompanionImportDraft(
        id: UUID(), source: .widgetShortcut, payloadKind: .code, payloadText: "let value = 1", normalizedHash: "shortcut-hash",
        capturedAt: .now, sourceAppName: nil
    )

    static let emptyClipboardPayload = ""
    static let unsupportedPayload = "image/png"
    static let pendingInboundReview = inboundItem

    static let snapshot = CompanionBridgeSnapshot(
        accountStatus: .ready, pendingInboundItems: [inboundItem], clipboardConfirmation: .idle,
        lastImportedAt: nil, lastClipboardSetAt: nil, lastErrorText: nil, isForegroundImportRequired: true
    )
}
