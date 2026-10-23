import Foundation

final class BridgeSettingsStore: BridgeSettingsStoring {
    private enum DefaultsKey {
        static let settings = "SlipTray.ICloudBridgeMac.Settings"
    }

    private struct SettingsRecord: Codable {
        var isBridgeEnabled: Bool
        var isPublishOnPasteEnabled: Bool
        var isReceiveEnabled: Bool
        var ttlMinutes: Int
        var allowedKindRawValues: [String]
        var lastUpdatedAt: Date

        init(settings: BridgeSettings) {
            isBridgeEnabled = settings.isBridgeEnabled
            isPublishOnPasteEnabled = settings.isPublishOnPasteEnabled
            isReceiveEnabled = settings.isReceiveEnabled
            ttlMinutes = settings.ttlMinutes
            allowedKindRawValues = settings.allowedKinds.map(\.rawValue)
            lastUpdatedAt = settings.lastUpdatedAt
        }

        func materialize() -> BridgeSettings {
            BridgeSettings(
                isBridgeEnabled: isBridgeEnabled,
                isPublishOnPasteEnabled: isPublishOnPasteEnabled,
                isReceiveEnabled: isReceiveEnabled,
                ttlMinutes: ttlMinutes,
                allowedKinds: allowedKindRawValues.compactMap(BridgePayloadKind.init(rawValue:)),
                lastUpdatedAt: lastUpdatedAt
            )
        }
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var storedSettings: BridgeSettings

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = DefaultsKey.settings
    ) {
        self.defaults = defaults
        self.storageKey = storageKey

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        if
            let data = defaults.data(forKey: storageKey),
            let record = try? decoder.decode(SettingsRecord.self, from: data)
        {
            storedSettings = Self.normalized(record.materialize())
        } else {
            storedSettings = Self.normalized(BridgeSettings())
        }
    }

    @discardableResult
    func saveSettings(_ settings: BridgeSettings) -> BridgeSettings {
        storedSettings = Self.normalized(settings)
        persist()
        return storedSettings
    }

    private func persist() {
        guard let data = try? encoder.encode(SettingsRecord(settings: storedSettings)) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    private static func normalized(_ settings: BridgeSettings) -> BridgeSettings {
        BridgeSettings(
            isBridgeEnabled: settings.isBridgeEnabled,
            isPublishOnPasteEnabled: settings.isPublishOnPasteEnabled,
            isReceiveEnabled: settings.isReceiveEnabled,
            ttlMinutes: 10,
            allowedKinds: [.text, .url, .code],
            lastUpdatedAt: settings.lastUpdatedAt
        )
    }
}
