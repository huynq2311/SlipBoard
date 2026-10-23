import Foundation

final class SecuritySettingsStore: SecuritySettingsStoring {
    private enum Keys {
        static let settings = "sliptray.security.settings"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var currentSettings: SecuritySettings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        if
            let data = defaults.data(forKey: Keys.settings),
            let record = try? decoder.decode(SettingsRecord.self, from: data)
        {
            currentSettings = record.materialize()
        } else {
            currentSettings = SecuritySettings()
        }
    }

    @discardableResult
    func saveSecuritySettings(_ settings: SecuritySettings) -> SecuritySettings {
        currentSettings = settings
        let record = SettingsRecord(settings: settings)
        if let data = try? encoder.encode(record) {
            defaults.set(data, forKey: Keys.settings)
        }
        return currentSettings
    }
}

private struct SettingsRecord: Codable {
    var isAppLockEnabled: Bool
    var unlockMethodRawValue: String
    var autoLockIntervalRawValue: String
    var privacyModeRawValue: String
    var lastUpdatedAt: Date

    init(settings: SecuritySettings) {
        isAppLockEnabled = settings.isAppLockEnabled
        unlockMethodRawValue = settings.unlockMethod.rawValue
        autoLockIntervalRawValue = settings.autoLockInterval.rawValue
        privacyModeRawValue = settings.privacyMode.rawValue
        lastUpdatedAt = settings.lastUpdatedAt
    }

    func materialize() -> SecuritySettings {
        SecuritySettings(
            isAppLockEnabled: isAppLockEnabled,
            unlockMethod: SecurityUnlockMethod(rawValue: unlockMethodRawValue) ?? .biometricPreferred,
            autoLockInterval: SecurityAutoLockInterval(rawValue: autoLockIntervalRawValue) ?? .never,
            privacyMode: SecurityPrivacyMode(rawValue: privacyModeRawValue) ?? .standard,
            lastUpdatedAt: lastUpdatedAt
        )
    }
}

