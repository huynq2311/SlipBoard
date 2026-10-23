import Foundation

enum ICloudBridgeMockFixtures {
    static let baseDate = Date(timeIntervalSince1970: 1_787_155_200)

    static let readyAccountStatus: BridgeAccountStatus = .ready
    static let unavailableAccountStatus: BridgeAccountStatus = .unavailable

    static let enabledSettings = BridgeSettings(
        isBridgeEnabled: true,
        isPublishOnPasteEnabled: true,
        isReceiveEnabled: true,
        ttlMinutes: 10,
        allowedKinds: [.text, .url, .code],
        lastUpdatedAt: baseDate.addingTimeInterval(-900)
    )

    static let disabledUnavailableSettings = BridgeSettings(
        isBridgeEnabled: false,
        isPublishOnPasteEnabled: false,
        isReceiveEnabled: false,
        ttlMinutes: 10,
        allowedKinds: [.text, .url, .code],
        lastUpdatedAt: baseDate.addingTimeInterval(-1_800)
    )

    static let knownIPhoneDevice = BridgeDeviceSummary(
        id: "device-iphone-ana",
        displayName: "Ana's iPhone",
        platform: .iphone,
        statusText: "Ready to receive pasted clips",
        badgeText: "Ready",
        lastSeenAt: baseDate.addingTimeInterval(-120)
    )

    static let emptyDeviceState: [BridgeDeviceSummary] = []

    static let successfulOutboundEnvelope = BridgeTransferEnvelope(
        recordID: "bridge-outbound-001",
        origin: .macPastedItem,
        payloadKind: .code,
        payloadText: "swiftc -typecheck SlipTray/Models/ICloudBridgeMac/ICloudBridgeModels.swift",
        normalizedHash: "hash-bridge-outbound-001",
        sourceDeviceName: "Ana's MacBook Pro",
        createdAt: baseDate.addingTimeInterval(-60),
        expiresAt: baseDate.addingTimeInterval(540)
    )

    static let companionImportedInboundEnvelope = BridgeTransferEnvelope(
        recordID: "bridge-inbound-001",
        origin: .companionImportedItem,
        payloadKind: .url,
        payloadText: "https://developer.apple.com/icloud/",
        normalizedHash: "hash-bridge-inbound-001",
        sourceDeviceName: "Ana's iPhone",
        createdAt: baseDate.addingTimeInterval(-300),
        expiresAt: baseDate.addingTimeInterval(300)
    )

    static let readyActivity = BridgeActivitySnapshot(
        lastPublishedAt: successfulOutboundEnvelope.createdAt,
        lastImportedAt: companionImportedInboundEnvelope.createdAt.addingTimeInterval(90),
        pendingImportCount: 1,
        lastErrorText: nil
    )

    static let readyRuntimeSnapshot = BridgeRuntimeSnapshot(
        accountStatus: readyAccountStatus,
        settings: enabledSettings,
        devices: [knownIPhoneDevice],
        activity: readyActivity
    )

    static let unavailableRuntimeSnapshot = BridgeRuntimeSnapshot(
        accountStatus: unavailableAccountStatus,
        settings: disabledUnavailableSettings,
        devices: [],
        activity: BridgeActivitySnapshot(
            lastPublishedAt: nil,
            lastImportedAt: nil,
            pendingImportCount: 0,
            lastErrorText: "iCloud account unavailable on this Mac."
        ),
        isBridgeAvailable: false,
        isBridgeEnabledEffective: false
    )

    static let emptyDevicesRuntimeSnapshot = BridgeRuntimeSnapshot(
        accountStatus: readyAccountStatus,
        settings: enabledSettings,
        devices: emptyDeviceState,
        activity: BridgeActivitySnapshot(
            lastPublishedAt: successfulOutboundEnvelope.createdAt,
            lastImportedAt: nil,
            pendingImportCount: 0,
            lastErrorText: nil
        )
    )

    static let eligibleOutboundResult = BridgeEligibilityResult.eligible(.code)
    static let duplicateInboundResult = BridgeEligibilityResult.ineligible(
        "The inbound envelope has already been consumed locally."
    )
}
