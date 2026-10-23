import Foundation

enum BridgePayloadKind: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case text
    case url
    case code

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .text:
            return "Text"
        case .url:
            return "URL"
        case .code:
            return "Code"
        }
    }
}

enum BridgeAccountStatus: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case disabled
    case unavailable
    case restricted
    case ready
    case syncing
    case error

    var id: String { rawValue }

    var isBridgeAvailable: Bool {
        switch self {
        case .ready, .syncing:
            return true
        case .disabled, .unavailable, .restricted, .error:
            return false
        }
    }

    var badgeText: String {
        switch self {
        case .disabled:
            return "Off"
        case .unavailable:
            return "Unavailable"
        case .restricted:
            return "Restricted"
        case .ready:
            return "Ready"
        case .syncing:
            return "Syncing"
        case .error:
            return "Error"
        }
    }
}

enum BridgeDevicePlatform: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case mac
    case iphone
    case ipad
    case unknown

    var id: String { rawValue }
}

struct BridgeSettings: Hashable, Codable, Sendable {
    var isBridgeEnabled: Bool
    var isPublishOnPasteEnabled: Bool
    var isReceiveEnabled: Bool
    var ttlMinutes: Int
    var allowedKinds: [BridgePayloadKind]
    var lastUpdatedAt: Date

    init(
        isBridgeEnabled: Bool = false,
        isPublishOnPasteEnabled: Bool = true,
        isReceiveEnabled: Bool = true,
        ttlMinutes: Int = 10,
        allowedKinds: [BridgePayloadKind] = BridgePayloadKind.allCases,
        lastUpdatedAt: Date = Date()
    ) {
        self.isBridgeEnabled = isBridgeEnabled
        self.isPublishOnPasteEnabled = isPublishOnPasteEnabled
        self.isReceiveEnabled = isReceiveEnabled
        self.ttlMinutes = max(ttlMinutes, 1)
        self.allowedKinds = BridgeSettings.uniqueKinds(from: allowedKinds)
        self.lastUpdatedAt = lastUpdatedAt
    }

    var isAnyDirectionEnabled: Bool {
        isPublishOnPasteEnabled || isReceiveEnabled
    }

    func updating(
        isBridgeEnabled: Bool? = nil,
        isPublishOnPasteEnabled: Bool? = nil,
        isReceiveEnabled: Bool? = nil,
        ttlMinutes: Int? = nil,
        allowedKinds: [BridgePayloadKind]? = nil,
        lastUpdatedAt: Date = Date()
    ) -> BridgeSettings {
        BridgeSettings(
            isBridgeEnabled: isBridgeEnabled ?? self.isBridgeEnabled,
            isPublishOnPasteEnabled: isPublishOnPasteEnabled ?? self.isPublishOnPasteEnabled,
            isReceiveEnabled: isReceiveEnabled ?? self.isReceiveEnabled,
            ttlMinutes: ttlMinutes ?? self.ttlMinutes,
            allowedKinds: allowedKinds ?? self.allowedKinds,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    private static func uniqueKinds(from kinds: [BridgePayloadKind]) -> [BridgePayloadKind] {
        var seen = Set<BridgePayloadKind>()
        let resolvedKinds = kinds.isEmpty ? BridgePayloadKind.allCases : kinds

        return resolvedKinds.filter { kind in
            seen.insert(kind).inserted
        }
    }
}

struct BridgeDeviceSummary: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var displayName: String
    var platform: BridgeDevicePlatform
    var statusText: String
    var badgeText: String
    var lastSeenAt: Date?

    init(
        id: String,
        displayName: String,
        platform: BridgeDevicePlatform,
        statusText: String,
        badgeText: String,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.platform = platform
        self.statusText = statusText
        self.badgeText = badgeText
        self.lastSeenAt = lastSeenAt
    }
}

enum BridgeTransferDirection: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case outbound
    case inbound

    var id: String { rawValue }
}

enum BridgeTransferOrigin: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case macPastedItem
    case companionImportedItem

    var id: String { rawValue }

    var direction: BridgeTransferDirection {
        switch self {
        case .macPastedItem:
            return .outbound
        case .companionImportedItem:
            return .inbound
        }
    }
}

struct BridgeTransferEnvelope: Identifiable, Hashable, Codable, Sendable {
    var recordID: String
    var origin: BridgeTransferOrigin
    var payloadKind: BridgePayloadKind
    var payloadText: String
    var normalizedHash: String
    var sourceDeviceName: String
    var createdAt: Date
    var expiresAt: Date
    var consumedAt: Date?

    var id: String { recordID }

    init(
        recordID: String,
        origin: BridgeTransferOrigin,
        payloadKind: BridgePayloadKind,
        payloadText: String,
        normalizedHash: String,
        sourceDeviceName: String,
        createdAt: Date,
        expiresAt: Date,
        consumedAt: Date? = nil
    ) {
        self.recordID = recordID
        self.origin = origin
        self.payloadKind = payloadKind
        self.payloadText = payloadText
        self.normalizedHash = normalizedHash
        self.sourceDeviceName = sourceDeviceName
        self.createdAt = createdAt
        self.expiresAt = max(expiresAt, createdAt)
        self.consumedAt = consumedAt
    }

    var direction: BridgeTransferDirection {
        origin.direction
    }

    var isConsumed: Bool {
        consumedAt != nil
    }

    func isExpired(relativeTo referenceDate: Date) -> Bool {
        expiresAt <= referenceDate
    }

    func markingConsumed(at date: Date) -> BridgeTransferEnvelope {
        var copy = self
        copy.consumedAt = date
        return copy
    }
}

struct BridgeActivitySnapshot: Hashable, Codable, Sendable {
    var lastPublishedAt: Date?
    var lastImportedAt: Date?
    var pendingImportCount: Int
    var lastErrorText: String?

    init(
        lastPublishedAt: Date? = nil,
        lastImportedAt: Date? = nil,
        pendingImportCount: Int = 0,
        lastErrorText: String? = nil
    ) {
        self.lastPublishedAt = lastPublishedAt
        self.lastImportedAt = lastImportedAt
        self.pendingImportCount = max(pendingImportCount, 0)
        self.lastErrorText = lastErrorText
    }
}

struct BridgeRuntimeSnapshot: Hashable, Codable, Sendable {
    var accountStatus: BridgeAccountStatus
    var settings: BridgeSettings
    var devices: [BridgeDeviceSummary]
    var activity: BridgeActivitySnapshot
    var isBridgeAvailable: Bool
    var isBridgeEnabledEffective: Bool

    init(
        accountStatus: BridgeAccountStatus,
        settings: BridgeSettings,
        devices: [BridgeDeviceSummary] = [],
        activity: BridgeActivitySnapshot = BridgeActivitySnapshot(),
        isBridgeAvailable: Bool? = nil,
        isBridgeEnabledEffective: Bool? = nil
    ) {
        self.accountStatus = accountStatus
        self.settings = settings
        self.devices = devices
        self.activity = activity

        let resolvedAvailability = isBridgeAvailable ?? accountStatus.isBridgeAvailable
        self.isBridgeAvailable = resolvedAvailability
        self.isBridgeEnabledEffective = isBridgeEnabledEffective ?? (
            settings.isBridgeEnabled && resolvedAvailability
        )
    }
}

struct BridgeEligibilityResult: Hashable, Codable, Sendable {
    var isEligible: Bool
    var payloadKind: BridgePayloadKind?
    var reason: String?

    init(
        isEligible: Bool,
        payloadKind: BridgePayloadKind? = nil,
        reason: String? = nil
    ) {
        self.isEligible = isEligible
        self.payloadKind = payloadKind
        self.reason = reason
    }

    static func eligible(_ payloadKind: BridgePayloadKind) -> BridgeEligibilityResult {
        BridgeEligibilityResult(isEligible: true, payloadKind: payloadKind)
    }

    static func ineligible(_ reason: String) -> BridgeEligibilityResult {
        BridgeEligibilityResult(isEligible: false, payloadKind: nil, reason: reason)
    }
}
