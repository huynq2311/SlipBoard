import Foundation

enum CompanionBridgeImportSource: String, CaseIterable, Codable, Sendable {
    case manualClipboard
    case shareExtension
    case widgetShortcut
}

enum CompanionBridgePayloadKind: String, CaseIterable, Codable, Sendable {
    case text
    case url
    case code
}

struct CompanionImportDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: CompanionBridgeImportSource
    let payloadKind: CompanionBridgePayloadKind
    let payloadText: String
    let normalizedHash: String
    let capturedAt: Date
    let sourceAppName: String?
}

struct CompanionInboundReviewItem: Identifiable, Equatable, Sendable {
    let id: String
    let payloadKind: CompanionBridgePayloadKind
    let payloadText: String
    let normalizedHash: String
    let sourceDeviceName: String
    let createdAt: Date
    let expiresAt: Date
}

enum CompanionClipboardConfirmationState: Equatable, Sendable {
    case idle
    case readyToConfirm(CompanionInboundReviewItem)
    case confirming
    case confirmed(Date)
    case failed(String)
}

enum CompanionBridgeAccountStatus: String, Codable, Sendable {
    case off, unavailable, restricted, ready, syncing, error
}

struct CompanionBridgeSnapshot: Equatable, Sendable {
    var accountStatus: CompanionBridgeAccountStatus
    var pendingInboundItems: [CompanionInboundReviewItem]
    var clipboardConfirmation: CompanionClipboardConfirmationState
    var lastImportedAt: Date?
    var lastClipboardSetAt: Date?
    var lastErrorText: String?
    var isForegroundImportRequired: Bool
}
