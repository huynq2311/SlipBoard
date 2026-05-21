import Foundation

enum SettingsMenuShellPreset: String, CaseIterable, Sendable {
    case empty
    case settingsDemo
    case pausedCapture
}

enum SettingsShellTabID: String, CaseIterable, Sendable {
    case general
    case bridge
    case retention
    case exclusions
    case hotkeys
    case snippets
    case security
}

struct SettingsTabSummary: Equatable, Identifiable, Sendable {
    let id: SettingsShellTabID
    let title: String
    let symbolName: String
}

enum QuickRetentionOptionID: String, CaseIterable, Sendable {
    case days7
    case days14
    case days30
    case days90
    case forever
}

struct QuickRetentionOption: Equatable, Identifiable, Sendable {
    let id: QuickRetentionOptionID
    let title: String
    let isSelected: Bool
}

enum PauseCaptureOptionID: String, CaseIterable, Sendable {
    case minutes15
    case hour1
    case untilTomorrow
    case resume
}

struct PauseCaptureOption: Equatable, Identifiable, Sendable {
    let id: PauseCaptureOptionID
    let title: String
    let isSelected: Bool
    let resumesAtLabel: String?
}

struct MenuBarSnapshot: Equatable, Sendable {
    let itemCountLabel: String
    let retentionLabel: String
    let isCapturePaused: Bool
    let pauseSummary: String?
    let quickRetentionOptions: [QuickRetentionOption]
    let pauseOptions: [PauseCaptureOption]
}

struct SettingsShellSection: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let helperText: String?
    let rows: [SettingsShellRow]
}

enum SettingsShellRow: Equatable, Sendable {
    case toggle(SettingsShellToggleRow)
    case value(SettingsShellValueRow)
    case segmented(SettingsShellSegmentedRow)
    case slider(SettingsShellSliderRow)
    case action(SettingsShellActionRow)
    case list(SettingsShellListRow)
    case callout(SettingsShellCalloutRow)
}

struct SettingsShellToggleRow: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let isOn: Bool
}

struct SettingsShellValueRow: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let value: String
}

struct SettingsShellSegmentOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let isSelected: Bool
}

struct SettingsShellSegmentedRow: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let options: [SettingsShellSegmentOption]
}

struct SettingsShellSliderRow: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueLabel: String
}

enum SettingsShellActionRole: String, Sendable {
    case standard
    case quiet
    case destructive
}

struct SettingsShellActionRow: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let buttonTitle: String
    let role: SettingsShellActionRole
    let isEnabled: Bool
}

struct SettingsShellListItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let symbolName: String?
    let accessoryLabel: String?
}

struct SettingsShellListRow: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let items: [SettingsShellListItem]
    let emptyStateTitle: String
    let actionTitle: String?
}

enum SettingsShellCalloutStyle: String, Sendable {
    case info
    case warning
}

struct SettingsShellCalloutRow: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let message: String
    let style: SettingsShellCalloutStyle
}

struct GeneralSettingsShellSummary: Equatable, Sendable {
    let sections: [SettingsShellSection]
}

struct BridgeSettingsShellSummary: Equatable, Sendable {
    let sections: [SettingsShellSection]
}

struct RetentionSettingsShellSummary: Equatable, Sendable {
    let sections: [SettingsShellSection]
}

struct ExclusionsSettingsShellSummary: Equatable, Sendable {
    let sections: [SettingsShellSection]
}

struct HotkeysSettingsShellSummary: Equatable, Sendable {
    let sections: [SettingsShellSection]
}

struct SnippetsSettingsShellSummary: Equatable, Sendable {
    let sections: [SettingsShellSection]
}

struct SecuritySettingsShellSummary: Equatable, Sendable {
    let sections: [SettingsShellSection]
}

struct SettingsMenuShellSnapshot: Equatable, Sendable {
    let selectedTab: SettingsShellTabID
    let lastOpenedTab: SettingsShellTabID
    let menuBar: MenuBarSnapshot
    let tabs: [SettingsTabSummary]
    let general: GeneralSettingsShellSummary
    let bridge: BridgeSettingsShellSummary
    let retention: RetentionSettingsShellSummary
    let exclusions: ExclusionsSettingsShellSummary
    let hotkeys: HotkeysSettingsShellSummary
    let snippets: SnippetsSettingsShellSummary
    let security: SecuritySettingsShellSummary
}
