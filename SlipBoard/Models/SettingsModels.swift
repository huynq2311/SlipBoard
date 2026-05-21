import Foundation

enum SettingsTabID: String, CaseIterable, Sendable {
    case general
    case bridge
    case retention
    case exclusions
    case hotkeys
    case snippets
}

struct PreferenceToggleState: Equatable, Sendable {
    let title: String
    let isOn: Bool
    let detail: String?
}

struct PreferenceValueSummary: Equatable, Sendable {
    let title: String
    let value: String
    let detail: String?
}

struct BridgeDeviceSummary: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let detail: String
    let isReachable: Bool
    let lastPublishedLabel: String?
}

struct GeneralSettingsSummary: Equatable, Sendable {
    let launchAtLogin: PreferenceToggleState
    let startPaused: PreferenceToggleState
    let interfaceTheme: PreferenceValueSummary
    let menuBarSummary: PreferenceValueSummary
}

struct BridgeSettingsSummary: Equatable, Sendable {
    let isEnabled: Bool
    let receiveFromPhoneEnabled: Bool
    let lastPublishedLabel: String?
    let devices: [BridgeDeviceSummary]
}

struct RetentionSettingsSummary: Equatable, Sendable {
    let autoCleanupEnabled: PreferenceToggleState
    let keepPinnedItems: PreferenceToggleState
    let retentionWindow: PreferenceValueSummary
}

struct ExclusionsSettingsSummary: Equatable, Sendable {
    let excludedApps: [SourceAppSummary]
    let captureSensitiveContent: PreferenceToggleState
}

struct HotkeysSettingsSummary: Equatable, Sendable {
    let popupShortcut: PreferenceValueSummary
    let quickPasteShortcut: PreferenceValueSummary
    let conflictSummary: String?
}

struct SnippetsSettingsSummary: Equatable, Sendable {
    let snippetsEnabled: PreferenceToggleState
    let defaultCollection: PreferenceValueSummary
    let totalCount: Int
}

struct SettingsSessionSnapshot: Equatable, Sendable {
    let selectedTab: SettingsTabID
    let general: GeneralSettingsSummary
    let bridge: BridgeSettingsSummary
    let retention: RetentionSettingsSummary
    let exclusions: ExclusionsSettingsSummary
    let hotkeys: HotkeysSettingsSummary
    let snippets: SnippetsSettingsSummary
}
