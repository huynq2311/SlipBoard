import SwiftUI

enum SBShortcutAssignmentVisualState: Hashable {
    case idleAssigned
    case idleUnassigned
    case recording
    case conflictWarning
    case disabledUnavailable

    var pillTone: SBAccentTone {
        switch self {
        case .idleAssigned:
            return .primary
        case .idleUnassigned, .disabledUnavailable:
            return .neutral
        case .recording:
            return .info
        case .conflictWarning:
            return .warning
        }
    }

    var showsEmphasizedPill: Bool {
        switch self {
        case .idleAssigned, .recording, .conflictWarning:
            return true
        case .idleUnassigned, .disabledUnavailable:
            return false
        }
    }

    var isInteractive: Bool {
        switch self {
        case .disabledUnavailable, .recording:
            return false
        case .idleAssigned, .idleUnassigned, .conflictWarning:
            return true
        }
    }
}

struct SBListRow: View {
    let title: String
    let detailText: String?
    let accessoryText: String?
    let badgeText: String?
    let symbolName: String?
    let theme: SBTheme
    var tone: SBAccentTone = .neutral
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: theme.spacing.control8) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tone == .neutral ? theme.palette.textSecondary : theme.accent(for: tone))
                    .frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(tone == .danger ? theme.accent(for: .danger) : theme.palette.textPrimary)
                    .lineLimit(1)

                if let detailText, detailText.isEmpty == false {
                    Text(detailText)
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: theme.spacing.control8)

            if let badgeText {
                SBCountBadge(text: badgeText, theme: theme, tone: tone, compact: true)
            }

            if let accessoryText {
                Text(accessoryText)
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(theme.palette.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, theme.spacing.control12)
        .padding(.vertical, theme.spacing.control8)
        .background(isHighlighted ? theme.palette.subpanel : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
    }
}

struct SBExcludedAppRow: View {
    let item: SettingsListEntry
    let theme: SBTheme
    var removeTitle: String = "Remove"
    var onRemove: () -> Void = {}

    var body: some View {
        HStack(spacing: theme.spacing.control12) {
            SBIconAvatar(
                symbolName: item.symbolName ?? "app.dashed",
                accentToken: accentToken,
                theme: theme,
                size: 18
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)
                    .lineLimit(1)

                if let detailText = detailLine, detailText.isEmpty == false {
                    Text(detailText)
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: theme.spacing.control12)

            SBControlPillButton(
                title: removeTitle,
                theme: theme,
                tone: .danger,
                action: onRemove
            )
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
    }

    private var detailLine: String? {
        if let accessoryText = item.accessoryText, accessoryText.isEmpty == false {
            return accessoryText
        }

        return item.detailText
    }

    private var accentToken: String {
        if let symbolName = item.symbolName, symbolName.contains("lock") || symbolName.contains("key") {
            return "accent.warning"
        }

        return "accent.info"
    }
}

struct SBBridgeFlowStepRow: View {
    enum TrailingAccessory: Hashable {
        case badge(String, tone: SBAccentTone)
        case keyboardHint(String)
        case text(String)
    }

    let title: String
    let detailText: String
    let symbolName: String
    let theme: SBTheme
    var trailingAccessory: TrailingAccessory? = nil
    var isEmphasized: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.control10) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)
                    .lineLimit(1)

                Text(detailText)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.control8)

            trailingAccessoryView
        }
        .padding(.horizontal, theme.spacing.control12)
        .padding(.vertical, theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
        .overlay {
            if isEmphasized {
                RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous)
                    .stroke(theme.palette.accentPrimary, lineWidth: theme.border.hairline)
            }
        }
    }

    @ViewBuilder
    private var trailingAccessoryView: some View {
        switch trailingAccessory {
        case let .badge(text, tone):
            SBSettingsStatusBadge(title: text, theme: theme, tone: tone)
        case let .keyboardHint(text):
            SBKeyboardHint(text: text, theme: theme)
        case let .text(text):
            Text(text)
                .font(theme.typography.monoMeta)
                .foregroundStyle(theme.palette.textTertiary)
                .lineLimit(1)
        case .none:
            EmptyView()
        }
    }

    private var iconColor: Color {
        isEmphasized ? theme.palette.accentPrimary : theme.palette.textSecondary
    }
}

struct SBBridgeDeviceRow: View {
    let title: String
    let detailText: String
    let statusText: String?
    let symbolName: String
    let theme: SBTheme
    var tone: SBAccentTone = .neutral

    var body: some View {
        HStack(spacing: theme.spacing.control10) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tone == .neutral ? theme.palette.textSecondary : theme.accent(for: tone))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)
                    .lineLimit(1)

                Text(detailText)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.control8)

            if let statusText, statusText.isEmpty == false {
                SBSettingsStatusBadge(title: statusText, theme: theme, tone: tone)
            }
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
    }
}

struct SBBridgeActivitySummaryRow: View {
    let title: String
    let valueText: String
    let detailText: String?
    let theme: SBTheme
    var tone: SBAccentTone = .neutral

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.control8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)

                if let detailText, detailText.isEmpty == false {
                    Text(detailText)
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: theme.spacing.control8)

            Text(valueText)
                .font(theme.typography.monoMeta)
                .foregroundStyle(tone == .neutral ? theme.palette.textSecondary : theme.accent(for: tone))
                .lineLimit(1)
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
    }
}

struct SBToggleRow: View {
    let item: SettingsToggleItem
    let theme: SBTheme

    var body: some View {
        HStack(spacing: theme.spacing.control12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)

                if let detailText = item.detailText, detailText.isEmpty == false {
                    Text(detailText)
                        .font(theme.typography.rowSecondary)
                        .foregroundStyle(theme.palette.textSecondary)
                }
            }

            Spacer(minLength: theme.spacing.control12)

            Toggle("", isOn: .constant(item.isOn))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(true)
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
        .opacity(item.isEnabled ? 1 : 0.5)
    }
}

struct SBSliderRow: View {
    let item: SettingsSliderItem
    let theme: SBTheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)

                    if let detailText = item.detailText, detailText.isEmpty == false {
                        Text(detailText)
                            .font(theme.typography.rowSecondary)
                            .foregroundStyle(theme.palette.textSecondary)
                    }
                }

                Spacer(minLength: theme.spacing.control8)

                if let valueLabel = item.valueLabel {
                    Text(valueLabel)
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(theme.palette.textSecondary)
                }
            }

            Slider(
                value: .constant(item.value),
                in: item.range,
                step: item.step
            )
            .tint(theme.palette.accentPrimary)
            .disabled(true)
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
    }
}

struct SBSettingsRow: View {
    let row: SettingsRowModel
    let theme: SBTheme

    var body: some View {
        switch row {
        case let .toggle(item):
            SBToggleRow(item: item, theme: theme)
        case let .slider(item):
            SBSliderRow(item: item, theme: theme)
        case let .action(item):
            SBListRow(
                title: item.title,
                detailText: item.detailText,
                accessoryText: item.accessoryText,
                badgeText: nil,
                symbolName: item.symbolName,
                theme: theme,
                tone: tone(for: item.role)
            )
            .sbSurface(.subpanel, theme: theme)
        case let .listEntry(item):
            SBListRow(
                title: item.title,
                detailText: item.detailText,
                accessoryText: item.accessoryText,
                badgeText: item.badgeText,
                symbolName: item.symbolName,
                theme: theme
            )
            .sbSurface(.subpanel, theme: theme)
        case let .choice(item):
            VStack(alignment: .leading, spacing: theme.spacing.control8) {
                Text(item.title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)

                if let detailText = item.detailText, detailText.isEmpty == false {
                    Text(detailText)
                        .font(theme.typography.rowSecondary)
                        .foregroundStyle(theme.palette.textSecondary)
                }

                SBSegmentedControl(
                    options: item.options,
                    selection: item.selectedOptionID,
                    theme: theme,
                    label: { $0.label }
                )
            }
            .padding(theme.spacing.control12)
            .sbSurface(.subpanel, theme: theme)
        }
    }

    private func tone(for role: SettingsActionRole) -> SBAccentTone {
        switch role {
        case .standard:
            return .neutral
        case .primary:
            return .primary
        case .danger:
            return .danger
        }
    }
}

struct SBShortcutAssignmentRow: View {
    let title: String
    let detailText: String?
    let shortcutLabel: String
    let theme: SBTheme
    var state: SBShortcutAssignmentVisualState = .idleAssigned
    var helperText: String? = nil
    var showsClearAction: Bool = true
    var isPopupScoped: Bool = false
    var onRecord: () -> Void = {}
    var onClear: () -> Void = {}

    @SBLocalizedCopy private var copy

    private var actionTitle: String {
        switch state {
        case .idleAssigned: copy.text(.hotkeyActionEdit)
        case .idleUnassigned: copy.text(.hotkeyActionRecord)
        case .recording: copy.text(.hotkeyActionRecording)
        case .conflictWarning: copy.text(.hotkeyActionRetry)
        case .disabledUnavailable: copy.text(.hotkeyActionUnavailable)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control8) {
            HStack(alignment: .center, spacing: theme.spacing.control12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: theme.spacing.control6) {
                        Text(title)
                            .font(theme.typography.rowPrimary)
                            .foregroundStyle(theme.palette.textPrimary)
                            .lineLimit(1)

                        if isPopupScoped {
                            SBCountBadge(
                                text: "Popup",
                                theme: theme,
                                tone: .neutral,
                                compact: true
                            )
                        }
                    }

                    if let detailText, detailText.isEmpty == false {
                        Text(detailText)
                            .font(theme.typography.rowSecondary)
                            .foregroundStyle(theme.palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: theme.spacing.control12)

                HStack(spacing: theme.spacing.control8) {
                    SBKeyboardShortcutPill(
                        // The runtime's placeholder label is English.
                        text: shortcutLabel == "No hotkey" ? copy.text(.hotkeyNoShortcut) : shortcutLabel,
                        theme: theme,
                        tone: state.pillTone,
                        isEmphasized: state.showsEmphasizedPill
                    )

                    SBControlPillButton(
                        title: actionTitle,
                        theme: theme,
                        tone: state.pillTone,
                        isEnabled: state.isInteractive,
                        action: onRecord
                    )

                    if showsClearAction && state != .disabledUnavailable {
                        SBControlPillButton(
                            title: copy.text(.hotkeyActionClear),
                            theme: theme,
                            tone: .neutral,
                            isEnabled: shortcutLabel != "No hotkey",
                            action: onClear
                        )
                    }
                }
            }

            if let helperText, helperText.isEmpty == false {
                SBSettingsConflictCallout(
                    title: state == .conflictWarning ? copy.text(.hotkeyConflictTitle) : copy.text(.hotkeyInfo),
                    detailText: helperText,
                    theme: theme,
                    tone: state == .conflictWarning ? .warning : .info
                )
            }
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
        .opacity(state == .disabledUnavailable ? 0.62 : 1)
    }
}

struct SBSnippetLibraryRow: View {
    let entry: Any
    let theme: SBTheme
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.control10) {
                SBIconAvatar(
                    symbolName: iconName,
                    accentToken: accentToken,
                    theme: theme,
                    size: 18
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: theme.spacing.control6) {
                        Text(entryTitle)
                            .font(theme.typography.rowPrimary)
                            .foregroundStyle(theme.palette.textPrimary)
                            .lineLimit(1)

                        if entryIsPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.accent(for: .warning))
                        }
                    }

                    Text(entrySubtitle ?? fallbackSubtitle)
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: theme.spacing.control10)

                SBKeyboardShortcutPill(
                    text: entryHotkeyLabel,
                    theme: theme,
                    tone: entryHotkeyLabel == "No hotkey" ? .neutral : .primary,
                    isEmphasized: entryHotkeyLabel != "No hotkey"
                )
            }
            .padding(.horizontal, theme.spacing.control12)
            .padding(.vertical, theme.spacing.control10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(entryIsSelected ? theme.accentBackground(for: .primary) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                    .stroke(entryIsSelected ? theme.palette.accentPrimary : theme.palette.border, lineWidth: theme.border.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    private var entryTitle: String {
        reflectedString("title") ?? "Snippet"
    }

    private var entrySubtitle: String? {
        reflectedString("subtitle")
    }

    private var entryHotkeyLabel: String {
        reflectedString("hotkeyLabel") ?? "No hotkey"
    }

    private var entryIsPinned: Bool {
        reflectedBool("isPinned") ?? false
    }

    private var entryIsSelected: Bool {
        reflectedBool("isSelected") ?? false
    }

    private var iconName: String {
        switch entryKind {
        case "plainText":
            return "text.alignleft"
        case "code":
            return "curlybraces"
        default:
            return "text.alignleft"
        }
    }

    private var accentToken: String {
        switch entryKind {
        case "plainText":
            return "accent.info"
        case "code":
            return "accent.primary"
        default:
            return "accent.info"
        }
    }

    private var fallbackSubtitle: String {
        entryHotkeyLabel == "No hotkey" ? "No hotkey" : entryHotkeyLabel
    }

    private var entryKind: String {
        String(describing: reflectedValue("kind") ?? "")
    }

    private func reflectedString(_ key: String) -> String? {
        reflectedValue(key) as? String
    }

    private func reflectedBool(_ key: String) -> Bool? {
        reflectedValue(key) as? Bool
    }

    private func reflectedValue(_ key: String) -> Any? {
        Mirror(reflecting: entry).children.first { $0.label == key }?.value
    }
}
