import SwiftUI

struct SBMenuBarLabel: View {
    let title: String
    let badgeText: String
    let theme: SBTheme
    var securitySnapshot: Any? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(theme.palette.textSecondary)

            Text(title)
                .font(theme.typography.rowPrimary)
                .foregroundStyle(theme.palette.textSecondary)

            SBCountBadge(text: badgeText, theme: theme, compact: true)

            if isLocked {
                SBMenuBarLockBadge(
                    theme: theme,
                    lockState: securitySnapshot.map(securityVisualState(from:)) ?? .locked
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .sbSurface(.raised, theme: theme)
        .fixedSize()
    }

    private var isLocked: Bool {
        guard let securitySnapshot else { return false }
        return securityVisualState(from: securitySnapshot).revealsProtectedContent == false
    }
}

struct SBMenuBarDropdownShell: View {
    let theme: SBTheme
    let summary: MenuBarSummaryState
    @SBLocalizedCopy private var copy
    var securitySnapshot: Any? = nil
    var onSelectQuickRetention: (String) -> Void = { _ in }
    var onSelectCommand: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            header
            retentionSection
            if let pauseCommandRow {
                divider
                pauseCommandBlock(row: pauseCommandRow)
            }
            if let securitySnapshot, securityVisualState(from: securitySnapshot).revealsProtectedContent == false {
                lockedSummarySection(snapshot: securitySnapshot)
                divider
            }
            commandGroup(rows: primaryRows)

            if secondaryRows.isEmpty == false {
                divider
                commandGroup(rows: secondaryRows)
            }

            if destructiveRows.isEmpty == false {
                divider
                commandGroup(rows: destructiveRows)
            }
        }
        .frame(width: 232, alignment: .topLeading)
        .sbSurface(.dropdown, theme: theme)
        .environment(\.controlActiveState, .key)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(summary.itemCount))
                    .font(theme.typography.paneTitle)
                    .foregroundStyle(theme.palette.textPrimary)

                Text(summary.itemCountLabel)
                    .font(theme.typography.chip)
                    .foregroundStyle(theme.palette.textTertiary)
            }

            Spacer(minLength: theme.spacing.control12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(copy.text(.menuStatus))
                    .font(theme.typography.chip)
                    .foregroundStyle(theme.palette.textTertiary)

                HStack(spacing: theme.spacing.control6) {
                    if let securitySnapshot, securityVisualState(from: securitySnapshot).revealsProtectedContent == false {
                        SBMenuBarLockBadge(theme: theme, lockState: securityVisualState(from: securitySnapshot))
                    }

                    Text(headerStatusText)
                        .font(theme.typography.rowSecondary)
                        .foregroundStyle(theme.palette.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, theme.spacing.dropdownPadding)
        .padding(.vertical, theme.spacing.control12)
    }

    private var retentionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control6) {
            Text(copy.text(.menuRetention))
                .font(theme.typography.chip)
                .foregroundStyle(theme.palette.textTertiary)

            SBSegmentedControl(
                options: normalizedQuickRetentionOptions,
                selection: normalizedQuickRetentionSelectionID,
                theme: theme,
                label: { $0.label },
                action: onSelectQuickRetention
            )
            .disabled(isRetentionLocked)
            .opacity(isRetentionLocked ? 0.48 : 1)
        }
        .padding(.horizontal, theme.spacing.dropdownPadding)
        .padding(.top, theme.spacing.control8)
        .padding(.bottom, theme.spacing.control6)
    }

    private func commandGroup(rows: [MenuBarCommandRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                commandRow(row)
            }
        }
        .padding(.vertical, 3)
    }

    private func commandRow(_ row: MenuBarCommandRow) -> some View {
        Button {
            onSelectCommand(row.id)
        } label: {
            HStack(spacing: theme.spacing.control8) {
                HStack(spacing: theme.spacing.control8) {
                    if let symbolName = row.symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(iconColor(for: row.role))
                            .frame(width: 16)
                    }

                    VStack(alignment: .leading, spacing: row.subtitle == nil ? 0 : 2) {
                        Text(row.title)
                            .font(theme.typography.rowPrimary)
                            .foregroundStyle(textColor(for: row.role))

                        if let subtitle = row.subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(theme.typography.meta)
                                .foregroundStyle(theme.palette.textTertiary)
                                .lineLimit(2)
                        }
                    }
                }

                Spacer(minLength: theme.spacing.control8)

                if let accessoryText = row.accessoryText {
                    Text(accessoryText)
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(theme.palette.textTertiary)
                        .lineLimit(1)
                } else if let shortcutLabel = row.shortcutLabel {
                    Text(shortcutLabel)
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(theme.palette.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, theme.spacing.dropdownPadding)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                .fill(summary.highlightedCommandID == row.id ? theme.palette.subpanel : Color.clear)
        )
        .padding(.horizontal, 3)
        .buttonStyle(.plain)
    }

    private func pauseCommandBlock(row: MenuBarCommandRow) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.control6) {
            commandRow(row)

            if pauseDetailIsVisible(for: row) {
                Button {
                    onSelectCommand(row.id)
                } label: {
                    HStack(spacing: theme.spacing.control8) {
                        HStack(spacing: theme.spacing.control8) {
                            Image(systemName: pauseDetailSymbolName(for: row))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.palette.textSecondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pauseDetailTitle(for: row) ?? row.title)
                                    .font(theme.typography.rowSecondary)
                                    .foregroundStyle(theme.palette.textSecondary)
                                    .lineLimit(1)

                                if let subtitle = pauseDetailSubtitle(for: row) {
                                    Text(subtitle)
                                        .font(theme.typography.meta)
                                        .foregroundStyle(theme.palette.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Spacer(minLength: theme.spacing.control8)

                        if let detailText = pauseDetailAccessoryText(for: row) {
                            Text(detailText)
                                .font(theme.typography.monoMeta)
                                .foregroundStyle(theme.palette.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, theme.spacing.dropdownPadding)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                        .fill(summary.highlightedCommandID == row.id ? theme.palette.subpanel.opacity(0.65) : Color.clear)
                )
                .padding(.horizontal, 3)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }

    private var primaryRows: [MenuBarCommandRow] {
        summary.commands.filter { $0.role == .standard && $0.id != pauseCommandRow?.id }
    }

    private var secondaryRows: [MenuBarCommandRow] {
        summary.commands.filter { $0.role == .secondary }
    }

    private var destructiveRows: [MenuBarCommandRow] {
        summary.commands.filter { $0.role == .destructive }
    }

    private var pauseCommandRow: MenuBarCommandRow? {
        summary.commands.first { row in
            row.id == "pause-capturing"
                || row.symbolName == "pause.circle"
                || row.symbolName == "play.circle"
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.palette.border)
            .frame(height: theme.border.hairline)
            .padding(.vertical, 3)
    }

    private func lockedSummarySection(snapshot: Any) -> some View {
        let lockState = securityVisualState(from: snapshot)

        return VStack(alignment: .leading, spacing: theme.spacing.control8) {
            Text(copy.text(.menuSecurity))
                .font(theme.typography.chip)
                .foregroundStyle(theme.palette.textTertiary)

            SBMenuBarSecurityCallout(
                theme: theme,
                title: lockTitle(for: lockState),
                detailText: lockDetailText(for: snapshot),
                symbolName: lockSymbolName(for: lockState),
                tone: lockTone(for: lockState)
            )
        }
        .padding(.horizontal, theme.spacing.dropdownPadding)
        .padding(.top, theme.spacing.control8)
        .padding(.bottom, theme.spacing.control6)
    }

    private func textColor(for role: MenuBarCommandRole) -> Color {
        switch role {
        case .standard, .secondary:
            return theme.palette.textPrimary
        case .destructive:
            return theme.accent(for: .danger)
        }
    }

    private func iconColor(for role: MenuBarCommandRole) -> Color {
        switch role {
        case .standard, .secondary:
            return theme.palette.textSecondary
        case .destructive:
            return theme.accent(for: .danger)
        }
    }

    private var normalizedQuickRetentionSelectionID: String {
        normalizedRetentionID(summary.quickRetentionSelectionID)
    }

    private var normalizedQuickRetentionOptions: [MenuBarRetentionOption] {
        summary.quickRetentionOptions.map { option in
            let normalizedID = normalizedRetentionID(option.id)

            return MenuBarRetentionOption(
                id: normalizedID,
                label: compactRetentionLabel(for: normalizedID, fallback: option.label),
                isSelected: normalizedID == normalizedQuickRetentionSelectionID
            )
        }
    }

    private func normalizedRetentionID(_ id: String) -> String {
        switch id {
        case "7d":
            return "1w"
        case "14d":
            return "2w"
        case "30d":
            return "1mo"
        case "90d":
            return "3mo"
        case "forever":
            return "never"
        default:
            return id
        }
    }

    private func compactRetentionLabel(for id: String, fallback: String) -> String {
        switch id {
        case "1w", "2w", "1mo", "3mo":
            return id
        case "never":
            return "∞"
        default:
            return fallback
        }
    }

    private var headerStatusText: String {
        guard let securitySnapshot else {
            return summary.statusLabel
        }

        let lockState = securityVisualState(from: securitySnapshot)
        guard lockState.revealsProtectedContent == false else {
            return summary.statusLabel
        }

        switch lockState {
        case .locked:
            return copy.text(.locked)
        case .unlocking:
            return copy.text(.securityUnlocking)
        case .unlockFailed:
            return copy.text(.securityUnlockFailed)
        case .unlocked:
            return summary.statusLabel
        case .unknown:
            return copy.text(.locked)
        }
    }

    private var isRetentionLocked: Bool {
        guard let securitySnapshot else { return false }
        return securityVisualState(from: securitySnapshot).revealsProtectedContent == false
    }

    private func lockTitle(for state: SBMenuBarSecurityState) -> String {
        switch state {
        case .locked:
            return copy.text(.securityStateLocked)
        case .unlocking:
            return copy.text(.securityUnlockInProgress)
        case .unlockFailed:
            return copy.text(.securityUnlockUnavailable)
        case .unlocked:
            return copy.text(.securityStateUnlocked)
        case .unknown:
            return copy.text(.securityStateUnavailable)
        }
    }

    private func lockDetailText(for snapshot: Any) -> String {
        if let failure = (snapshot as? SecurityRuntimeSnapshot)?.lastFailure {
            switch failure.kind {
            case .authenticationFailed:
                return copy.text(.securityLockDetailFailed)
            case .migrationFailed:
                return copy.text(.securityLockDetailMigration)
            case .keyProvisioningFailed, .keyWrapFailed, .keyUnwrapFailed, .itemDecryptFailed:
                return copy.text(.securityLockDetailKeyUnavailable)
            }
        }

        switch securityVisualState(from: snapshot) {
        case .locked:
            if let reason = securityLockedReason(from: snapshot) {
                switch reason {
                case .manual:
                    return copy.text(.securityLockDetailManual)
                case .autoLockTimeout:
                    return copy.text(.securityLockDetailAutoLock)
                case .backgroundTransition:
                    return copy.text(.securityLockDetailBackground)
                case .authenticationRequired:
                    return copy.text(.securityLockDetailAuthentication)
                case .keyUnavailable:
                    return copy.text(.securityLockDetailKeyUnavailable)
                case .migrationRequired:
                    return copy.text(.securityLockDetailMigration)
                }
            }

            return copy.text(.securityLockDetailManual)
        case .unlocking:
            return copy.text(.securityLockDetailUnlocking)
        case .unlockFailed:
            return copy.text(.securityLockDetailFailed)
        case .unlocked:
            return copy.text(.securityLockDetailUnlocked)
        case .unknown:
            return copy.text(.securityLockDetailUnknown)
        }
    }

    private func lockSymbolName(for state: SBMenuBarSecurityState) -> String {
        switch state {
        case .locked:
            return "lock.fill"
        case .unlocking:
            return "lock.rotation"
        case .unlockFailed:
            return "exclamationmark.lock.fill"
        case .unlocked:
            return "lock.open.fill"
        case .unknown:
            return "lock.slash.fill"
        }
    }

    private func lockTone(for state: SBMenuBarSecurityState) -> SBAccentTone {
        switch state {
        case .locked:
            return .danger
        case .unlocking:
            return .warning
        case .unlockFailed:
            return .danger
        case .unlocked:
            return .success
        case .unknown:
            return .warning
        }
    }

    private func pauseDetailIsVisible(for row: MenuBarCommandRow) -> Bool {
        pauseDetailTitle(for: row) != nil
            || pauseDetailSubtitle(for: row) != nil
            || pauseDetailAccessoryText(for: row) != nil
    }

    private func pauseDetailTitle(for row: MenuBarCommandRow) -> String? {
        if let accessoryText = row.accessoryText, accessoryText.isEmpty == false {
            if row.symbolName == "play.circle" {
                return copy.text(.menuPausedUntilResume)
            }
            return copy.text(.menuPauseFor, ["duration": accessoryText])
        }

        if let subtitle = row.subtitle, subtitle.isEmpty == false {
            return subtitle
        }

        return nil
    }

    private func pauseDetailSubtitle(for row: MenuBarCommandRow) -> String? {
        guard let subtitle = row.subtitle, subtitle.isEmpty == false else {
            return nil
        }

        if subtitle == pauseDetailTitle(for: row) {
            return nil
        }

        return subtitle
    }

    private func pauseDetailAccessoryText(for row: MenuBarCommandRow) -> String? {
        if let shortcutLabel = row.shortcutLabel, shortcutLabel.isEmpty == false {
            return shortcutLabel
        }

        return nil
    }

    private func pauseDetailSymbolName(for row: MenuBarCommandRow) -> String {
        if row.symbolName == "play.circle" {
            return "play.circle"
        }

        if row.accessoryText != nil {
            return "clock.badge"
        }

        return "clock.pause"
    }
}

private struct SBMenuBarLockBadge: View {
    let theme: SBTheme
    let lockState: SBMenuBarSecurityState
    @SBLocalizedCopy private var copy

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: 18, height: 18)
            .background(backgroundColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(foregroundColor.opacity(theme.mode == .dark ? 0.32 : 0.22), lineWidth: theme.border.hairline)
            )
            .accessibilityLabel(accessibilityText)
    }

    private var symbolName: String {
        switch lockState {
        case .locked:
            return "lock.fill"
        case .unlocking:
            return "lock.rotation"
        case .unlockFailed:
            return "exclamationmark.lock.fill"
        case .unlocked:
            return "lock.open.fill"
        case .unknown:
            return "lock.slash.fill"
        }
    }

    private var foregroundColor: Color {
        switch lockState {
        case .locked, .unlockFailed:
            return theme.accent(for: .danger)
        case .unlocking:
            return theme.accent(for: .warning)
        case .unlocked:
            return theme.accent(for: .success)
        case .unknown:
            return theme.accent(for: .warning)
        }
    }

    private var backgroundColor: Color {
        switch lockState {
        case .locked, .unlockFailed:
            return theme.accentBackground(for: .danger)
        case .unlocking:
            return theme.accentBackground(for: .warning)
        case .unlocked:
            return theme.accentBackground(for: .success)
        case .unknown:
            return theme.accentBackground(for: .warning)
        }
    }

    private var accessibilityText: String {
        switch lockState {
        case .locked:
            return copy.text(.securityMenuLocked)
        case .unlocking:
            return copy.text(.securityUnlocking)
        case .unlockFailed:
            return copy.text(.securityUnlockFailed)
        case .unlocked:
            return copy.text(.securityMenuUnlocked)
        case .unknown:
            return copy.text(.securityMenuUnavailable)
        }
    }
}

private struct SBMenuBarSecurityCallout: View {
    let theme: SBTheme
    let title: String
    let detailText: String
    let symbolName: String
    let tone: SBAccentTone

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.control10) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent(for: tone))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)

                Text(detailText)
                    .font(theme.typography.meta)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
    }
}

private enum SBMenuBarSecurityState: String {
    case locked
    case unlocking
    case unlockFailed
    case unlocked
    case unknown

    var revealsProtectedContent: Bool {
        switch self {
        case .unlocked:
            return true
        case .locked, .unlocking, .unlockFailed, .unknown:
            return false
        }
    }
}

private enum SBMenuBarLockedReason: String {
    case manual
    case autoLockTimeout
    case backgroundTransition
    case authenticationRequired
    case keyUnavailable
    case migrationRequired
}

private func securityVisualState(from snapshot: Any) -> SBMenuBarSecurityState {
    let rawValue = String(describing: mirroredChild(named: "lockState", in: snapshot) ?? "")
    return SBMenuBarSecurityState(rawValue: rawValue) ?? .unknown
}

private func securityLockedReason(from snapshot: Any) -> SBMenuBarLockedReason? {
    guard let reason = mirroredChild(named: "lockedVisibleReason", in: snapshot) else {
        return nil
    }

    return SBMenuBarLockedReason(rawValue: String(describing: reason))
}

private func mirroredChild(named key: String, in value: Any) -> Any? {
    Mirror(reflecting: value).children.first { $0.label == key }?.value
}
