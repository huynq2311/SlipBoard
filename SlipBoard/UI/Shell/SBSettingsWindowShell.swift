import SwiftUI

struct SBSettingsWindowShell: View {
    let theme: SBTheme
    let state: SettingsShellState
    var securitySnapshot: Any? = nil
    var snippetsHotkeysSnapshot: SnippetsHotkeysRuntimeSnapshot? = nil
    var onSelectSection: (SettingsSectionID) -> Void = { _ in }
    var onSelectChoice: (String, String) -> Void = { _, _ in }
    var onToggle: (String, Bool) -> Void = { _, _ in }
    var onAdjustSlider: (String, Double) -> Void = { _, _ in }
    var onSelectAction: (String) -> Void = { _ in }
    var onBeginHotkeyRecording: (HotkeyBindingTarget) -> Void = { _ in }
    var onClearHotkeyBinding: (HotkeyBindingTarget) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            titlebar

            HStack(spacing: 0) {
                sidebar
                contentPane
            }
            // The Settings scene keeps the native title bar above this custom shell.
            .padding(.top, 22)
            .frame(minHeight: 560)
        }
        .frame(minWidth: 960, minHeight: 620, alignment: .topLeading)
        .sbSurface(.window, theme: theme)
    }

    private var titlebar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                circle(Color(red: 226 / 255, green: 75 / 255, blue: 74 / 255))
                circle(Color(red: 239 / 255, green: 159 / 255, blue: 39 / 255))
                circle(Color(red: 99 / 255, green: 153 / 255, blue: 34 / 255))
            }

            Text("Settings")
                .font(theme.typography.rowPrimary)
                .foregroundStyle(theme.palette.textSecondary)
                .padding(.leading, 4)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.palette.panel)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.palette.border)
                .frame(height: theme.border.hairline)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(state.allSections) { pane in
                sidebarItem(for: pane)
            }

            Spacer()
        }
        .frame(width: 172, alignment: .topLeading)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(theme.palette.subpanel)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.palette.border)
                .frame(width: theme.border.hairline)
        }
    }

    private var contentPane: some View {
        let pane = state.pane(for: state.selectedSection)

        return ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.section24) {
                paneHeader(for: pane)

                if isOrganizationPane(pane) {
                    organizationPaneSections(for: pane)
                } else if pane.id == .hotkeys, let snippetsHotkeysSnapshot {
                    hotkeysPaneSections(for: pane, snapshot: snippetsHotkeysSnapshot)
                } else if pane.id == .bridge {
                    bridgePaneSections(for: pane)
                } else if pane.id == .security {
                    securityPaneSections(for: pane)
                } else if pane.id == .retention {
                    retentionPaneSections(for: pane)
                } else {
                    standardPaneSections(for: pane)
                }
            }
            .padding(.horizontal, theme.spacing.settingsPaneHorizontal)
            .padding(.vertical, theme.spacing.settingsPaneVertical)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.palette.panel)
    }

    private func paneHeader(for pane: SettingsPaneModel) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.section16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pane.title)
                    .font(theme.typography.paneTitle)
                    .foregroundStyle(theme.palette.textPrimary)

                Text(pane.id == .bridge ? bridgeSubtitle(for: pane) : pane.subtitle)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.section16)

            if pane.id == .bridge {
                let status = bridgeHeaderStatus(for: pane)
                SBSettingsStatusBadge(
                    title: status.title,
                    theme: theme,
                    tone: status.tone,
                    symbolName: status.symbolName
                )
            } else if let headerAction = paneHeaderAction(for: pane) {
                SBControlPillButton(
                    title: headerAction.title,
                    theme: theme,
                    tone: paneHeaderActionTone(for: headerAction),
                    action: { onSelectAction(headerAction.id) }
                )
            } else {
                SBCountBadge(
                    text: pane.title.uppercased(),
                    theme: theme,
                    tone: .neutral,
                    compact: true
                )
            }
        }
    }

    private func sidebarItem(for pane: SettingsPaneModel) -> some View {
        let isSelected = state.selectedSection == pane.id

        return Button(action: {
            onSelectSection(pane.id)
        }) {
            HStack(spacing: 9) {
                Image(systemName: sidebarSymbolName(for: pane))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.textSecondary)

                Text(sidebarTitle(for: pane))
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: theme.spacing.control8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                    .fill(isSelected ? theme.palette.panel : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                    .stroke(isSelected ? theme.palette.border : Color.clear, lineWidth: theme.border.hairline)
            }
        }
        .buttonStyle(.plain)
    }

    private func circle(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 11, height: 11)
    }

    @ViewBuilder
    private func standardPaneSections(for pane: SettingsPaneModel) -> some View {
        ForEach(pane.sections) { section in
            SBPaneSection(
                title: section.title,
                descriptionText: section.descriptionText,
                theme: theme
            ) {
                standardRows(for: section)

                if let placeholder = section.placeholder {
                    SBSettingsSectionPlaceholder(placeholder: placeholder, theme: theme)
                }
            }
        }
    }

    @ViewBuilder
    private func retentionPaneSections(for pane: SettingsPaneModel) -> some View {
        if let historySection = pane.sections.first(where: { $0.id == "retention.history-limit" }) {
            SBPaneSection(
                title: historySection.title,
                descriptionText: historySection.descriptionText,
                theme: theme
            ) {
                ForEach(Array(historySection.rows.enumerated()), id: \.offset) { _, row in
                    retentionRow(row)
                }
            }
        }

        if let autoClearSection = pane.sections.first(where: { $0.id == "retention.ttl" }) {
            SBPaneSection(
                title: autoClearSection.title,
                descriptionText: autoClearSection.descriptionText,
                theme: theme
            ) {
                ForEach(Array(autoClearSection.rows.enumerated()), id: \.offset) { _, row in
                    retentionRow(row)
                }
            }
        }

        if let pinnedPlaceholder = pane.sections.compactMap(\.placeholder).first {
            SBPaneSection(title: "Pinned items", theme: theme) {
                SBSettingsSectionPlaceholder(placeholder: pinnedPlaceholder, theme: theme)
            }
        }

        if let assetCacheSection = pane.sections.first(where: { $0.id == "retention.asset-cache" }) {
            SBPaneSection(
                title: assetCacheSection.title,
                descriptionText: assetCacheSection.descriptionText,
                theme: theme
            ) {
                ForEach(Array(assetCacheSection.rows.enumerated()), id: \.offset) { _, row in
                    retentionRow(row)
                }
            }
        }
    }

    @ViewBuilder
    private func retentionRow(_ row: SettingsRowModel) -> some View {
        switch row {
        case let .slider(item):
            InteractiveSliderRow(
                item: item,
                theme: theme,
                onChange: { onAdjustSlider(item.id, $0) }
            )
        case let .toggle(item):
            InteractiveToggleRow(
                item: item,
                theme: theme,
                onToggle: { onToggle(item.id, $0) }
            )
        case let .choice(item):
            InteractiveChoiceRow(
                item: normalizedRetentionChoiceItem(item),
                theme: theme,
                onSelect: { onSelectChoice(item.id, $0) }
            )
        case let .action(item):
            InteractiveActionRow(
                item: normalizedRetentionActionRow(item),
                theme: theme,
                onSelect: { onSelectAction(item.id) }
            )
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
        }
    }

    private func normalizedRetentionChoiceItem(_ item: SettingsChoiceItem) -> SettingsChoiceItem {
        guard item.id == "ttl" else { return item }

        let normalizedOptions = item.options.map { option in
            SettingsChoiceOption(
                id: normalizedRetentionID(option.id),
                label: retentionSettingsLabel(for: normalizedRetentionID(option.id), fallback: option.label),
                detailText: option.detailText,
                isSelected: normalizedRetentionID(option.id) == normalizedRetentionID(item.selectedOptionID)
            )
        }

        return SettingsChoiceItem(
            id: item.id,
            title: item.title == "Retention period" ? "Clear history after" : item.title,
            detailText: item.detailText,
            selectedOptionID: normalizedRetentionID(item.selectedOptionID),
            options: normalizedOptions,
            style: item.style
        )
    }

    private func normalizedRetentionActionRow(_ item: SettingsActionRow) -> SettingsActionRow {
        guard item.id == "clear-cache" else { return item }

        return SettingsActionRow(
            id: item.id,
            title: item.title,
            detailText: nil,
            accessoryText: item.accessoryText ?? item.detailText,
            symbolName: item.symbolName ?? "trash",
            role: item.role
        )
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

    private func retentionSettingsLabel(for id: String, fallback: String) -> String {
        switch id {
        case "1w", "2w", "1mo", "3mo":
            return id
        case "never":
            return "Never"
        default:
            return fallback
        }
    }

    private func sidebarTitle(for pane: SettingsPaneModel) -> String {
        pane.id == .bridge ? "Bridge" : pane.title
    }

    private func sidebarSymbolName(for pane: SettingsPaneModel) -> String {
        if isOrganizationPane(pane) {
            return "square.grid.2x2"
        }

        return pane.id.symbolName
    }

    private func isOrganizationPane(_ pane: SettingsPaneModel) -> Bool {
        pane.title.compare("Organization", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    @ViewBuilder
    private func bridgePaneSections(for pane: SettingsPaneModel) -> some View {
        let behaviorSection = bridgeSection(in: pane, matching: ["bridge.behavior", "behavior"])
        let devicesSection = bridgeSection(in: pane, matching: ["bridge.devices", "devices"])
        let activitySection = bridgeSection(in: pane, matching: ["bridge.activity", "activity"])
        let noteSection = bridgeSection(in: pane, matching: ["bridge.note", "note", "policy"])
        let stopSection = bridgeSection(in: pane, matching: ["bridge.stop", "danger", "stop"])

        SBPaneSection(
            title: behaviorSection?.title ?? "Bridge behavior",
            descriptionText: behaviorSection?.descriptionText,
            theme: theme
        ) {
            ForEach(bridgeBehaviorRows(in: behaviorSection), id: \.id) { item in
                InteractiveToggleRow(
                    item: item,
                    theme: theme,
                    onToggle: { onToggle(item.id, $0) }
                )
            }

            SBBridgeActivitySummaryRow(
                title: "Scope",
                valueText: "Text / URL / Code",
                detailText: "Only successful local pastes of supported kinds are bridged in v1.",
                theme: theme,
                tone: .info
            )
        }

        SBPaneSection(title: "Paste flow", theme: theme) {
            ForEach(bridgeFlowRows(isEnabled: isBridgeEnabled(for: pane))) { step in
                SBBridgeFlowStepRow(
                    title: step.title,
                    detailText: step.detailText,
                    symbolName: step.symbolName,
                    theme: theme,
                    trailingAccessory: step.trailingAccessory,
                    isEmphasized: step.isEmphasized
                )
            }
        }

        SBPaneSection(
            title: devicesSection?.title ?? "Devices",
            descriptionText: devicesSection?.descriptionText,
            theme: theme
        ) {
            let deviceRows = bridgeDeviceRows(in: devicesSection)
            if deviceRows.isEmpty {
                SBEmptyStateCard(
                    title: "No companion devices yet",
                    detailText: "Bridge can stay enabled on Mac before an iPhone companion signs into the same iCloud account.",
                    theme: theme
                )
            } else {
                ForEach(deviceRows) { item in
                    SBBridgeDeviceRow(
                        title: item.title,
                        detailText: bridgeDeviceDetail(for: item),
                        statusText: item.badgeText,
                        symbolName: bridgeDeviceSymbolName(for: item),
                        theme: theme,
                        tone: bridgeDeviceTone(for: item)
                    )
                }
            }
        }

        SBPaneSection(
            title: activitySection?.title ?? "Last activity",
            descriptionText: activitySection?.descriptionText,
            theme: theme
        ) {
            ForEach(bridgeActivityRows(in: activitySection), id: \.title) { row in
                SBBridgeActivitySummaryRow(
                    title: row.title,
                    valueText: row.valueText,
                    detailText: row.detailText,
                    theme: theme,
                    tone: row.tone
                )
            }
        }

        SBPolicyNoteRow(
            title: noteSection?.placeholder?.title == "Bridge preview" ? nil : noteSection?.placeholder?.title,
            detailText: bridgePolicyNoteText(from: noteSection),
            theme: theme,
            symbolName: "shield"
        )

        SBPaneSection(
            title: stopSection?.title ?? "Stop Bridge",
            descriptionText: stopSection?.descriptionText,
            theme: theme
        ) {
            let actionRow = bridgeStopAction(in: stopSection)
            InteractiveActionRow(
                item: actionRow,
                theme: theme,
                onSelect: { onSelectAction(actionRow.id) }
            )
        }
    }

    @ViewBuilder
    private func organizationPaneSections(for pane: SettingsPaneModel) -> some View {
        let searchSection = pane.sections.first { section in
            section.title.compare("Search", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        let collectionsSection = pane.sections.first { section in
            section.title.compare("Collections", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        let calloutPlaceholder = pane.sections.compactMap(\.placeholder).first

        if let searchSection {
            SBPaneSection(
                title: searchSection.title,
                descriptionText: searchSection.descriptionText,
                theme: theme
            ) {
                ForEach(Array(searchSection.rows.enumerated()), id: \.offset) { _, row in
                    SBSettingsRow(row: row, theme: theme)
                }

                if let placeholder = searchSection.placeholder {
                    SBSettingsSectionPlaceholder(placeholder: placeholder, theme: theme)
                }
            }
        }

        if let collectionsSection {
            SBPaneSection(
                title: collectionsSection.title,
                descriptionText: collectionsSection.descriptionText,
                theme: theme
            ) {
                ForEach(Array(collectionsSection.rows.enumerated()), id: \.offset) { _, row in
                    organizationRow(row)
                }

                if let placeholder = collectionsSection.placeholder {
                    SBSettingsSectionPlaceholder(placeholder: placeholder, theme: theme)
                }
            }
        }

        if let calloutPlaceholder {
            SBPaneSection(title: "Locked state", theme: theme) {
                SBSettingsSectionPlaceholder(placeholder: calloutPlaceholder, theme: theme)
            }
        }
    }

    @ViewBuilder
    private func organizationRow(_ row: SettingsRowModel) -> some View {
        switch row {
        case let .listEntry(item):
            OrganizationGroupRow(item: item, theme: theme)
        case let .action(item):
            InteractiveActionRow(
                item: item,
                theme: theme,
                onSelect: { onSelectAction(item.id) }
            )
        case let .choice(item):
            InteractiveChoiceRow(
                item: item,
                theme: theme,
                onSelect: { onSelectChoice(item.id, $0) }
            )
        case let .toggle(item):
            InteractiveToggleRow(
                item: item,
                theme: theme,
                onToggle: { onToggle(item.id, $0) }
            )
        case let .slider(item):
            InteractiveSliderRow(
                item: item,
                theme: theme,
                onChange: { onAdjustSlider(item.id, $0) }
            )
        }
    }

    @ViewBuilder
    private func securityPaneSections(for pane: SettingsPaneModel) -> some View {
        ForEach(pane.sections) { section in
            SBPaneSection(
                title: section.title,
                descriptionText: section.descriptionText,
                theme: theme
            ) {
                ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                    securityRow(row)
                }

                if let placeholder = section.placeholder {
                    SBSettingsSectionPlaceholder(placeholder: placeholder, theme: theme)
                }
            }
        }
    }

    @ViewBuilder
    private func securityRow(_ row: SettingsRowModel) -> some View {
        switch row {
        case let .toggle(item):
            InteractiveToggleRow(
                item: item,
                theme: theme,
                onToggle: { onToggle(item.id, $0) }
            )
        case let .choice(item):
            InteractiveChoiceRow(
                item: item,
                theme: theme,
                onSelect: { onSelectChoice(item.id, $0) }
            )
        case let .listEntry(item):
            SBListRow(
                title: item.title,
                detailText: item.detailText,
                accessoryText: item.accessoryText,
                badgeText: item.badgeText,
                symbolName: item.symbolName,
                theme: theme,
                tone: item.id == "security.reset-protected-content" ? .danger : .neutral
            )
            .sbSurface(.subpanel, theme: theme)
        case let .action(item):
            InteractiveActionRow(
                item: item,
                theme: theme,
                onSelect: { onSelectAction(item.id) }
            )
        case let .slider(item):
            InteractiveSliderRow(
                item: item,
                theme: theme,
                onChange: { onAdjustSlider(item.id, $0) }
            )
        }
    }

    @ViewBuilder
    private func standardRows(for section: SettingsPaneSection) -> some View {
        if isExclusionsAppsSection(section) {
            ForEach(exclusionListEntries(in: section)) { item in
                SBExcludedAppRow(
                    item: item,
                    theme: theme,
                    onRemove: { onSelectAction(item.id) }
                )
            }
        } else {
            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                SBSettingsRow(row: row, theme: theme)
            }
        }
    }

    @ViewBuilder
    private func hotkeysPaneSections(
        for pane: SettingsPaneModel,
        snapshot: SnippetsHotkeysRuntimeSnapshot
    ) -> some View {
        let hotkeysState = snapshot.hotkeysSettingsState

        if let inlineMessage = hotkeysState.inlineMessage, inlineMessage.isEmpty == false {
            SBSettingsConflictCallout(
                title: snapshot.runtimeAvailability == .lockedDisabled
                    ? "Shortcut access is locked"
                    : "Shortcut info",
                detailText: inlineMessage,
                theme: theme,
                tone: snapshot.runtimeAvailability == .lockedDisabled ? .warning : .info
            )
        }

        if let globalSection = pane.sections.first(where: { $0.id == "hotkeys.global" }) {
            SBPaneSection(
                title: globalSection.title,
                descriptionText: globalSection.descriptionText,
                theme: theme
            ) {
                ForEach(hotkeysState.globalBindings) { binding in
                    shortcutAssignmentRow(for: binding, recorderSession: hotkeysState.recorderSession)
                }
            }
        }

        if let snippetSection = pane.sections.first(where: { $0.id == "hotkeys.snippets" }) {
            SBPaneSection(
                title: snippetSection.title,
                descriptionText: snippetSection.descriptionText,
                theme: theme
            ) {
                if hotkeysState.snippetBindings.isEmpty {
                    if let placeholder = snippetSection.placeholder {
                        SBSettingsSectionPlaceholder(placeholder: placeholder, theme: theme)
                    }
                } else {
                    ForEach(hotkeysState.snippetBindings) { binding in
                        shortcutAssignmentRow(for: binding, recorderSession: hotkeysState.recorderSession)
                    }
                }
            }
        }

        if let statusPlaceholder = pane.sections
            .first(where: { $0.id == "hotkeys.status" })?
            .placeholder {
            SBPaneSection(title: "Runtime status", theme: theme) {
                SBSettingsSectionPlaceholder(placeholder: statusPlaceholder, theme: theme)
            }
        }
    }

    private func shortcutAssignmentRow(
        for binding: HotkeyBindingSummary,
        recorderSession: HotkeyRecorderSessionState
    ) -> some View {
        SBShortcutAssignmentRow(
            title: binding.title,
            detailText: binding.detailText,
            shortcutLabel: shortcutLabel(for: binding, recorderSession: recorderSession),
            theme: theme,
            state: shortcutVisualState(
                for: binding,
                recorderSession: recorderSession
            ),
            helperText: shortcutHelperText(for: binding, recorderSession: recorderSession),
            showsClearAction: true,
            isPopupScoped: binding.isPopupScoped,
            onRecord: { onBeginHotkeyRecording(binding.target) },
            onClear: { onClearHotkeyBinding(binding.target) }
        )
    }

    private func shortcutVisualState(
        for binding: HotkeyBindingSummary,
        recorderSession: HotkeyRecorderSessionState
    ) -> SBShortcutAssignmentVisualState {
        if binding.availability.isInteractive == false {
            return .disabledUnavailable
        }

        if recorderSession.target == binding.target {
            switch recorderSession.phase {
            case .recording:
                return .recording
            case .conflict:
                return .conflictWarning
            case .disabled:
                return .disabledUnavailable
            case .idle, .saved:
                break
            }
        }

        return binding.hotkey == nil ? .idleUnassigned : .idleAssigned
    }

    private func shortcutLabel(
        for binding: HotkeyBindingSummary,
        recorderSession: HotkeyRecorderSessionState
    ) -> String {
        if recorderSession.target == binding.target,
           recorderSession.phase == .recording,
           let candidate = recorderSession.candidateHotkey {
            return candidate.displayLabel
        }

        return binding.shortcutLabel
    }

    private func shortcutHelperText(
        for binding: HotkeyBindingSummary,
        recorderSession: HotkeyRecorderSessionState
    ) -> String? {
        if recorderSession.target == binding.target {
            switch recorderSession.phase {
            case .recording:
                return "Press the shortcut you want to assign. Press Escape to cancel."
            case .conflict:
                return recorderSession.conflictResult?.message ?? binding.detailText
            case .disabled:
                return binding.detailText ?? "Unlock SlipBoard to edit this shortcut."
            case .idle, .saved:
                break
            }
        }

        return binding.latestConflict?.message ?? binding.detailText
    }

    private func paneHeaderAction(for pane: SettingsPaneModel) -> SettingsActionRow? {
        guard pane.id == .exclusions else { return nil }

        return pane.sections
            .first(where: isExclusionsAppsSection)?
            .rows
            .compactMap { row -> SettingsActionRow? in
                guard case let .action(item) = row else { return nil }
                return item
            }
            .first
    }

    private func isExclusionsAppsSection(_ section: SettingsPaneSection) -> Bool {
        section.id == "exclusions.apps"
    }

    private func exclusionListEntries(in section: SettingsPaneSection) -> [SettingsListEntry] {
        section.rows.compactMap { row -> SettingsListEntry? in
            guard case let .listEntry(item) = row else { return nil }
            return item
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

    private func paneHeaderActionTone(for action: SettingsActionRow) -> SBAccentTone {
        if action.role == .standard, action.title.localizedCaseInsensitiveContains("add") {
            return .primary
        }

        return tone(for: action.role)
    }

    private func bridgeSubtitle(for pane: SettingsPaneModel) -> String {
        if pane.subtitle.localizedCaseInsensitiveContains("placeholder") ||
            pane.subtitle.localizedCaseInsensitiveContains("no sync wiring") {
            return "Paste on Mac, then paste on iPhone. Mac history stays local."
        }

        return pane.subtitle
    }

    private func bridgeHeaderStatus(for pane: SettingsPaneModel) -> (title: String, tone: SBAccentTone, symbolName: String?) {
        let aggregateText = pane.sections
            .flatMap(\.rows)
            .compactMap { row -> String? in
                switch row {
                case let .toggle(item):
                    return [item.title, item.detailText].compactMap { $0 }.joined(separator: " ")
                case let .slider(item):
                    return [item.title, item.detailText, item.valueLabel].compactMap { $0 }.joined(separator: " ")
                case let .action(item):
                    return [item.title, item.detailText, item.accessoryText].compactMap { $0 }.joined(separator: " ")
                case let .listEntry(item):
                    return [item.title, item.detailText, item.accessoryText, item.badgeText].compactMap { $0 }.joined(separator: " ")
                case let .choice(item):
                    return [item.title, item.detailText].compactMap { $0 }.joined(separator: " ")
                }
            }
            .joined(separator: " ")
            .lowercased()

        if aggregateText.contains("error") {
            return ("Error", .danger, "exclamationmark.circle")
        }

        if aggregateText.contains("restricted") {
            return ("Restricted", .warning, "lock")
        }

        if aggregateText.contains("unavailable") || aggregateText.contains("signed out") {
            return ("Unavailable", .warning, "icloud.slash")
        }

        if aggregateText.contains("syncing") || aggregateText.contains("pending") {
            return ("Syncing", .info, "arrow.triangle.2.circlepath")
        }

        if isBridgeEnabled(for: pane) {
            return ("Ready", .success, "checkmark.circle")
        }

        return ("Off", .neutral, "pause.circle")
    }

    private func bridgeSection(
        in pane: SettingsPaneModel,
        matching tokens: [String]
    ) -> SettingsPaneSection? {
        pane.sections.first { section in
            let haystacks = [section.id, section.title, section.descriptionText ?? ""]
                .joined(separator: " ")
                .lowercased()
            return tokens.contains { haystacks.contains($0.lowercased()) }
        }
    }

    private func bridgeBehaviorRows(in section: SettingsPaneSection?) -> [SettingsToggleItem] {
        let resolvedRows = section?.rows.compactMap { row -> SettingsToggleItem? in
            guard case let .toggle(item) = row else { return nil }
            return item
        } ?? []

        if resolvedRows.isEmpty == false {
            return resolvedRows
        }

        return [
            SettingsToggleItem(
                id: "enable-bridge",
                title: "Enable iCloud Bridge",
                detailText: "Bridge through CloudKit private database without uploading full SlipBoard history.",
                isOn: false
            ),
            SettingsToggleItem(
                id: "bridge.publish-on-paste",
                title: "Publish pasted item to devices",
                detailText: "Double-click or Enter on Mac pastes locally and publishes that same item to devices on the same iCloud account.",
                isOn: false,
                isEnabled: false
            ),
            SettingsToggleItem(
                id: "bridge.receive",
                title: "Receive from iPhone",
                detailText: "Companion imports from iPhone appear in SlipBoard on Mac.",
                isOn: false,
                isEnabled: false
            )
        ]
    }

    private func bridgeFlowRows(isEnabled: Bool) -> [BridgeFlowStepPresentation] {
        [
            BridgeFlowStepPresentation(
                title: "Pick on Mac",
                detailText: "Double-click or press Enter from the popup grid.",
                symbolName: "cursorarrow.click",
                trailingAccessory: .keyboardHint("↵")
            ),
            BridgeFlowStepPresentation(
                title: "Paste on Mac",
                detailText: "SlipBoard still pastes into the current app as usual.",
                symbolName: "laptopcomputer",
                trailingAccessory: .badge("Local", tone: .success),
                isEmphasized: isEnabled
            ),
            BridgeFlowStepPresentation(
                title: "Publish one-shot bridge record",
                detailText: "Only the item just pasted is sent with a short TTL and cleanup after use.",
                symbolName: "icloud.and.arrow.up",
                trailingAccessory: .badge("10 min", tone: .info)
            ),
            BridgeFlowStepPresentation(
                title: "Receive on iPhone",
                detailText: "The iPhone companion receives the item so the user can paste again there.",
                symbolName: "iphone",
                trailingAccessory: .badge(isEnabled ? "Ready" : "Off", tone: isEnabled ? .success : .neutral)
            )
        ]
    }

    private func bridgeDeviceRows(in section: SettingsPaneSection?) -> [SettingsListEntry] {
        section?.rows.compactMap { row -> SettingsListEntry? in
            guard case let .listEntry(item) = row else { return nil }
            return item
        } ?? []
    }

    private func bridgeDeviceSymbolName(for item: SettingsListEntry) -> String {
        if let symbolName = item.symbolName, symbolName.isEmpty == false {
            return symbolName
        }

        let haystack = [item.title, item.detailText ?? "", item.accessoryText ?? ""].joined(separator: " ").lowercased()
        if haystack.contains("ipad") {
            return "ipad"
        }
        if haystack.contains("mac") {
            return "laptopcomputer"
        }
        if haystack.contains("iphone") || haystack.contains("phone") {
            return "iphone"
        }
        return "iphone"
    }

    private func bridgeDeviceDetail(for item: SettingsListEntry) -> String {
        if let detailText = item.detailText, detailText.isEmpty == false {
            return detailText
        }

        if let accessoryText = item.accessoryText, accessoryText.isEmpty == false {
            return accessoryText
        }

        return "Same iCloud account"
    }

    private func bridgeDeviceTone(for item: SettingsListEntry) -> SBAccentTone {
        let status = [item.badgeText, item.accessoryText, item.detailText]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if status.contains("active") || status.contains("live") || status.contains("ready") {
            return .success
        }
        if status.contains("optional") {
            return .info
        }
        if status.contains("idle") {
            return .warning
        }
        return .neutral
    }

    private func bridgeActivityRows(in section: SettingsPaneSection?) -> [BridgeActivityRowPresentation] {
        let rows = section?.rows.compactMap { row -> BridgeActivityRowPresentation? in
            switch row {
            case let .listEntry(item):
                return BridgeActivityRowPresentation(
                    title: item.title,
                    valueText: item.badgeText ?? item.accessoryText ?? "Never",
                    detailText: item.detailText,
                    tone: bridgeActivityTone(for: item)
                )
            case let .action(item):
                return BridgeActivityRowPresentation(
                    title: item.title,
                    valueText: item.accessoryText ?? "Review",
                    detailText: item.detailText,
                    tone: item.role == .danger ? .danger : .neutral
                )
            default:
                return nil
            }
        } ?? []

        if rows.isEmpty == false {
            return rows
        }

        return [
            BridgeActivityRowPresentation(title: "Last sent", valueText: "Never", detailText: "No intentional Mac paste has been bridged yet.", tone: .neutral),
            BridgeActivityRowPresentation(title: "Last received", valueText: "Never", detailText: "No companion import has been added to local Mac history yet.", tone: .neutral),
            BridgeActivityRowPresentation(title: "Pending imports", valueText: "0", detailText: "Incoming bridge records waiting for Mac import.", tone: .info)
        ]
    }

    private func bridgeActivityTone(for item: SettingsListEntry) -> SBAccentTone {
        let value = [item.badgeText, item.accessoryText, item.detailText]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if value.contains("error") {
            return .danger
        }
        if value.contains("pending") || value.contains("now") || value.contains("just") {
            return .info
        }
        if value.contains("never") {
            return .neutral
        }
        return .success
    }

    private func bridgePolicyNoteText(from section: SettingsPaneSection?) -> String {
        if let detailText = section?.placeholder?.detailText, detailText.isEmpty == false {
            return detailText
        }

        return "Mac history stays local. SlipBoard only bridges items you actually paste with double-click or Enter, never the full history."
    }

    private func bridgeStopAction(in section: SettingsPaneSection?) -> SettingsActionRow {
        if let action = section?.rows.compactMap({ row -> SettingsActionRow? in
            guard case let .action(item) = row else { return nil }
            return item
        }).first {
            return action
        }

        return SettingsActionRow(
            id: "bridge.stop",
            title: "Stop Bridge",
            detailText: "Disable new publish and receive activity while keeping imported local history intact.",
            symbolName: "stop.circle",
            role: .danger
        )
    }

    private func isBridgeEnabled(for pane: SettingsPaneModel) -> Bool {
        pane.sections
            .flatMap(\.rows)
            .compactMap { row -> SettingsToggleItem? in
                guard case let .toggle(item) = row else { return nil }
                return item
            }
            .first { $0.id == "enable-bridge" || $0.title.localizedCaseInsensitiveContains("enable icloud bridge") }?
            .isOn ?? false
    }
}

private struct BridgeFlowStepPresentation: Identifiable {
    let title: String
    let detailText: String
    let symbolName: String
    let trailingAccessory: SBBridgeFlowStepRow.TrailingAccessory?
    var isEmphasized: Bool = false

    var id: String { title }
}

private struct BridgeActivityRowPresentation: Identifiable {
    let title: String
    let valueText: String
    let detailText: String?
    let tone: SBAccentTone

    var id: String { title }
}

struct SBSettingsSplitEditorShell<Library: View, Detail: View>: View {
    let theme: SBTheme
    var libraryMinWidth: CGFloat = 248
    var libraryIdealWidth: CGFloat = 272
    var detailMinWidth: CGFloat = 360
    @ViewBuilder var library: Library
    @ViewBuilder var detail: Detail

    init(
        theme: SBTheme,
        libraryMinWidth: CGFloat = 248,
        libraryIdealWidth: CGFloat = 272,
        detailMinWidth: CGFloat = 360,
        @ViewBuilder library: () -> Library,
        @ViewBuilder detail: () -> Detail
    ) {
        self.theme = theme
        self.libraryMinWidth = libraryMinWidth
        self.libraryIdealWidth = libraryIdealWidth
        self.detailMinWidth = detailMinWidth
        self.library = library()
        self.detail = detail()
    }

    var body: some View {
        HStack(spacing: theme.spacing.section12) {
            VStack(alignment: .leading, spacing: theme.spacing.control8) {
                library
            }
            .frame(minWidth: libraryMinWidth, idealWidth: libraryIdealWidth, maxWidth: libraryIdealWidth, maxHeight: .infinity, alignment: .topLeading)
            .padding(theme.spacing.control12)
            .sbSurface(.subpanel, theme: theme)

            VStack(alignment: .leading, spacing: theme.spacing.control12) {
                detail
            }
            .frame(minWidth: detailMinWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(theme.spacing.control12)
            .sbSurface(.subpanel, theme: theme)
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
    }
}

struct SBSettingsSectionPlaceholder: View {
    let placeholder: SettingsPanePlaceholder
    let theme: SBTheme

    var body: some View {
        switch placeholder.kind {
        case .note, .callout, .emptyState:
            SBEmptyStateCard(
                title: placeholder.title,
                detailText: placeholder.detailText,
                theme: theme,
                badgeText: placeholder.badgeText
            )
        case .editorPreview:
            VStack(alignment: .leading, spacing: theme.spacing.control8) {
                HStack {
                    Text(placeholder.title)
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)

                    Spacer()

                    if let badgeText = placeholder.badgeText {
                        SBCountBadge(text: badgeText, theme: theme, tone: .neutral, compact: true)
                    }
                }

                Text(placeholder.detailText)
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(theme.palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacing.control12)
                    .sbSurface(.raised, theme: theme)
            }
            .padding(theme.spacing.control12)
            .sbSurface(.subpanel, theme: theme)
        case .listPreview:
            VStack(alignment: .leading, spacing: theme.spacing.control8) {
                Text(placeholder.title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)

                Text(placeholder.detailText)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
            }
            .padding(theme.spacing.control12)
            .sbSurface(.subpanel, theme: theme)
        }
    }
}

private struct InteractiveToggleRow: View {
    let item: SettingsToggleItem
    let theme: SBTheme
    let onToggle: (Bool) -> Void

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

            Toggle("", isOn: Binding(
                get: { item.isOn },
                set: onToggle
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(item.isEnabled == false)
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
        .opacity(item.isEnabled ? 1 : 0.5)
    }
}

private struct InteractiveSliderRow: View {
    let item: SettingsSliderItem
    let theme: SBTheme
    let onChange: (Double) -> Void

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
                value: Binding(
                    get: { item.value },
                    set: onChange
                ),
                in: item.range,
                step: item.step
            )
            .tint(theme.palette.accentPrimary)
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
    }
}

private struct OrganizationGroupRow: View {
    let item: SettingsListEntry
    let theme: SBTheme

    var body: some View {
        HStack(spacing: theme.spacing.control10) {
            if let symbolName = item.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.palette.textSecondary)
                    .frame(width: 16)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(theme.palette.accentPrimary)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)
                    .lineLimit(1)

                if let detailText = item.detailText, detailText.isEmpty == false {
                    Text(detailText)
                        .font(theme.typography.rowSecondary)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: theme.spacing.control8)

            if let badgeText = item.badgeText {
                SBCountBadge(text: badgeText, theme: theme, tone: .neutral, compact: true)
            }

            if let accessoryText = item.accessoryText, accessoryText.isEmpty == false {
                Text(accessoryText)
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(theme.palette.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
    }
}

private struct InteractiveChoiceRow: View {
    let item: SettingsChoiceItem
    let theme: SBTheme
    let onSelect: (String) -> Void

    var body: some View {
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
                label: { $0.label },
                action: onSelect
            )
        }
        .padding(theme.spacing.control12)
        .sbSurface(.subpanel, theme: theme)
    }
}

private struct InteractiveActionRow: View {
    let item: SettingsActionRow
    let theme: SBTheme
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: theme.spacing.control8) {
                HStack(spacing: theme.spacing.control8) {
                    if let symbolName = item.symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(iconColor)
                            .frame(width: 16)
                    }

                    VStack(alignment: .leading, spacing: item.detailText == nil ? 0 : 2) {
                        Text(item.title)
                            .font(theme.typography.rowPrimary)
                            .foregroundStyle(textColor)

                        if let detailText = item.detailText, detailText.isEmpty == false {
                            Text(detailText)
                                .font(theme.typography.meta)
                                .foregroundStyle(theme.palette.textTertiary)
                                .lineLimit(2)
                        }
                    }
                }

                Spacer(minLength: theme.spacing.control8)

                if let accessoryText = item.accessoryText, accessoryText.isEmpty == false {
                    Text(accessoryText)
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(theme.palette.textSecondary)
                }
            }
            .padding(theme.spacing.control12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sbSurface(.subpanel, theme: theme)
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        switch item.role {
        case .danger:
            return theme.accent(for: .danger)
        case .standard, .primary:
            return theme.palette.textPrimary
        }
    }

    private var iconColor: Color {
        switch item.role {
        case .danger:
            return theme.accent(for: .danger)
        case .primary:
            return theme.accent(for: .primary)
        case .standard:
            return theme.palette.textSecondary
        }
    }
}
