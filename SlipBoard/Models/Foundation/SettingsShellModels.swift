import Foundation

enum SettingsSectionID: String, CaseIterable, Identifiable, Hashable {
    case general
    case retention
    case exclusions
    case hotkeys
    case snippets
    case security
    case bridge
    case about

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .general:
            return "General"
        case .retention:
            return "Retention"
        case .exclusions:
            return "Exclusions"
        case .hotkeys:
            return "Hotkeys"
        case .snippets:
            return "Snippets"
        case .security:
            return "Security"
        case .bridge:
            return "Bridge"
        case .about:
            return "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .retention:
            return "clock"
        case .exclusions:
            return "nosign"
        case .hotkeys:
            return "keyboard"
        case .snippets:
            return "curlybraces"
        case .security:
            return "lock"
        case .bridge:
            return "icloud"
        case .about:
            return "info.circle"
        }
    }
}

enum SettingsChoiceStyle: String, Hashable {
    case segmented
    case menu
    case inline
}

struct SettingsChoiceOption: Identifiable, Hashable {
    let id: String
    var label: String
    var detailText: String?
    var isSelected: Bool

    init(
        id: String,
        label: String,
        detailText: String? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.label = label
        self.detailText = detailText
        self.isSelected = isSelected
    }
}

struct SettingsToggleItem: Identifiable, Hashable {
    let id: String
    var title: String
    var detailText: String?
    var isOn: Bool
    var isEnabled: Bool

    init(
        id: String,
        title: String,
        detailText: String? = nil,
        isOn: Bool,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.detailText = detailText
        self.isOn = isOn
        self.isEnabled = isEnabled
    }
}

struct SettingsSliderItem: Identifiable, Hashable {
    let id: String
    var title: String
    var detailText: String?
    var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var valueLabel: String?

    init(
        id: String,
        title: String,
        detailText: String? = nil,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        valueLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detailText = detailText
        self.value = value
        self.range = range
        self.step = step
        self.valueLabel = valueLabel
    }
}

enum SettingsActionRole: String, Hashable {
    case standard
    case primary
    case danger
}

struct SettingsActionRow: Identifiable, Hashable {
    let id: String
    var title: String
    var detailText: String?
    var accessoryText: String?
    var symbolName: String?
    var role: SettingsActionRole

    init(
        id: String,
        title: String,
        detailText: String? = nil,
        accessoryText: String? = nil,
        symbolName: String? = nil,
        role: SettingsActionRole = .standard
    ) {
        self.id = id
        self.title = title
        self.detailText = detailText
        self.accessoryText = accessoryText
        self.symbolName = symbolName
        self.role = role
    }
}

struct SettingsListEntry: Identifiable, Hashable {
    let id: String
    var title: String
    var detailText: String?
    var accessoryText: String?
    var badgeText: String?
    var symbolName: String?

    init(
        id: String,
        title: String,
        detailText: String? = nil,
        accessoryText: String? = nil,
        badgeText: String? = nil,
        symbolName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detailText = detailText
        self.accessoryText = accessoryText
        self.badgeText = badgeText
        self.symbolName = symbolName
    }
}

struct SettingsChoiceItem: Identifiable, Hashable {
    let id: String
    var title: String
    var detailText: String?
    var selectedOptionID: String
    var options: [SettingsChoiceOption]
    var style: SettingsChoiceStyle

    init(
        id: String,
        title: String,
        detailText: String? = nil,
        selectedOptionID: String,
        options: [SettingsChoiceOption],
        style: SettingsChoiceStyle = .segmented
    ) {
        self.id = id
        self.title = title
        self.detailText = detailText
        self.selectedOptionID = selectedOptionID
        self.options = options
        self.style = style
    }
}

enum SettingsPanePlaceholderKind: String, Hashable {
    case note
    case callout
    case editorPreview
    case listPreview
    case emptyState
}

struct SettingsPanePlaceholder: Identifiable, Hashable {
    let id: String
    var title: String
    var detailText: String
    var badgeText: String?
    var kind: SettingsPanePlaceholderKind

    init(
        id: String,
        title: String,
        detailText: String,
        badgeText: String? = nil,
        kind: SettingsPanePlaceholderKind = .note
    ) {
        self.id = id
        self.title = title
        self.detailText = detailText
        self.badgeText = badgeText
        self.kind = kind
    }
}

enum SettingsRowModel: Hashable {
    case toggle(SettingsToggleItem)
    case slider(SettingsSliderItem)
    case action(SettingsActionRow)
    case listEntry(SettingsListEntry)
    case choice(SettingsChoiceItem)
}

struct SettingsPaneSection: Identifiable, Hashable {
    let id: String
    var title: String
    var descriptionText: String?
    var rows: [SettingsRowModel]
    var placeholder: SettingsPanePlaceholder?

    init(
        id: String,
        title: String,
        descriptionText: String? = nil,
        rows: [SettingsRowModel] = [],
        placeholder: SettingsPanePlaceholder? = nil
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.rows = rows
        self.placeholder = placeholder
    }
}

struct SettingsPaneModel: Identifiable, Hashable {
    let id: SettingsSectionID
    var title: String
    var subtitle: String
    var sections: [SettingsPaneSection]

    init(
        id: SettingsSectionID,
        title: String,
        subtitle: String,
        sections: [SettingsPaneSection] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sections = sections
    }
}

struct SettingsShellState: Hashable {
    var selectedSection: SettingsSectionID
    var general: SettingsPaneModel
    var retention: SettingsPaneModel
    var exclusions: SettingsPaneModel
    var hotkeys: SettingsPaneModel
    var snippets: SettingsPaneModel
    var security: SettingsPaneModel
    var bridge: SettingsPaneModel
    var about: SettingsPaneModel

    // Bridge is hidden for v1.0: Universal Clipboard already covers iPhone <-> Mac
    // transfer and the bridge transport has no real CloudKit backend yet.
    var allSections: [SettingsPaneModel] {
        [general, retention, exclusions, hotkeys, snippets, security, about]
    }

    init(
        selectedSection: SettingsSectionID = .general,
        general: SettingsPaneModel,
        retention: SettingsPaneModel,
        exclusions: SettingsPaneModel,
        hotkeys: SettingsPaneModel,
        snippets: SettingsPaneModel,
        security: SettingsPaneModel,
        bridge: SettingsPaneModel,
        about: SettingsPaneModel
    ) {
        self.selectedSection = selectedSection
        self.general = general
        self.retention = retention
        self.exclusions = exclusions
        self.hotkeys = hotkeys
        self.snippets = snippets
        self.security = security
        self.bridge = bridge
        self.about = about
    }

    func pane(for section: SettingsSectionID) -> SettingsPaneModel {
        switch section {
        case .general:
            return general
        case .retention:
            return retention
        case .exclusions:
            return exclusions
        case .hotkeys:
            return hotkeys
        case .snippets:
            return snippets
        case .security:
            return security
        case .bridge:
            return bridge
        case .about:
            return about
        }
    }
}
