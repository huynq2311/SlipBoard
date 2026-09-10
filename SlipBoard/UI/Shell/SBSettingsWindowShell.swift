import SwiftUI

struct SBSettingsWindowShell: View {
    let theme: SBTheme
    let state: SettingsShellState
    @SBLocalizedCopy private var copy
    @Environment(\.sbLocalizationLanguage) private var localizationLanguage
    var securitySnapshot: Any? = nil
    var bridgeSnapshot: BridgeRuntimeSnapshot? = nil
    var exclusionsPauseSnapshot: ExclusionsPauseSnapshot? = nil
    var snippetsHotkeysSnapshot: SnippetsHotkeysRuntimeSnapshot? = nil
    var onSelectSection: (SettingsSectionID) -> Void = { _ in }
    var onSelectChoice: (String, String) -> Void = { _, _ in }
    var onToggle: (String, Bool) -> Void = { _, _ in }
    var onAdjustSlider: (String, Double) -> Void = { _, _ in }
    var onSelectAction: (String) -> Void = { _ in }
    var onBeginHotkeyRecording: (HotkeyBindingTarget) -> Void = { _ in }
    var onClearHotkeyBinding: (HotkeyBindingTarget) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            contentPane
        }
        .frame(minHeight: 560)
        .frame(minWidth: 960, minHeight: 620, alignment: .topLeading)
        .sbSurface(.window, theme: theme)
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
        let pane = localizedPane(state.pane(for: state.selectedSection))

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
        .focusEffectDisabled()
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
            SBPaneSection(title: copy.text(.popupPinned), theme: theme) {
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
            title: copy.text(.settingsClearHistoryAfter),
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
            return copy.text(.retentionNever)
        default:
            return fallback
        }
    }

    private func sidebarTitle(for pane: SettingsPaneModel) -> String {
        switch pane.id {
        case .general: copy.text(.sidebarOrganization)
        case .bridge: copy.text(.sidebarBridge)
        case .retention: copy.text(.sidebarRetention)
        case .exclusions: copy.text(.sidebarExclusions)
        case .hotkeys: copy.text(.sidebarHotkeys)
        case .snippets: copy.text(.sidebarSnippets)
        case .security: copy.text(.sidebarSecurity)
        }
    }

    private func sidebarSymbolName(for pane: SettingsPaneModel) -> String {
        if isOrganizationPane(pane) {
            return "square.grid.2x2"
        }

        return pane.id.symbolName
    }

    private func isOrganizationPane(_ pane: SettingsPaneModel) -> Bool {
        pane.id == .general
    }

    private func localizedPane(_ pane: SettingsPaneModel) -> SettingsPaneModel {
        var localized = pane

        switch pane.id {
        case .general:
            localized.title = copy.text(.settingsOrganization)
            localized.subtitle = copy.text(.settingsOrganizationDescription)
        case .bridge:
            localized.title = copy.text(.settingsBridge)
            localized.subtitle = copy.text(.bridgeDescription)
        case .retention:
            localized.title = copy.text(.settingsRetention)
            localized.subtitle = copy.text(.settingsRetentionDescription)
        case .exclusions:
            localized.title = copy.text(.settingsExclusions)
            localized.subtitle = copy.text(.settingsExclusionsDescription)
        case .hotkeys:
            localized.title = copy.text(.settingsHotkeys)
            localized.subtitle = copy.text(.settingsHotkeysDescription)
        case .snippets:
            localized.title = copy.text(.settingsSnippets)
            localized.subtitle = copy.text(.settingsSnippetsDescription)
        case .security:
            localized.title = copy.text(.settingsSecurity)
            localized.subtitle = copy.text(.settingsSecurityDescription)
        }

        localized.sections = pane.sections.map(localizedSection)
        return localized
    }

    private func localizedSection(_ section: SettingsPaneSection) -> SettingsPaneSection {
        var localized = section

        switch section.id {
        case "startup":
            localized.title = copy.text(.settingsStartupHeading)
        case "organization.search":
            localized.title = copy.text(.settingsSearchHeading)
            localized.descriptionText = copy.text(.settingsSearchDescription)
        case "organization.collections":
            localized.title = copy.text(.settingsCollectionsHeading)
            localized.descriptionText = copy.text(.settingsCollectionsDescription)
        case "organization.locked":
            localized.title = copy.text(.settingsLockedStateHeading)
        case "retention.history-limit":
            localized.title = copy.text(.settingsHistoryLimit)
            localized.descriptionText = copy.text(.settingsHistoryLimitDescription)
        case "retention.paste-behavior":
            localized.title = copy.text(.settingsPasteBehavior)
            localized.descriptionText = copy.text(.settingsPasteBehaviorDescription)
        case "retention.ttl":
            localized.title = copy.text(.settingsAutoClear)
            localized.descriptionText = copy.text(.settingsAutoClearDescription)
        case "retention.pinned-callout":
            localized.title = copy.text(.settingsPinnedItems)
        case "retention.asset-cache":
            localized.title = copy.text(.settingsAssetCache)
            localized.descriptionText = copy.text(.settingsAssetCacheDescription)
        case "exclusions.apps":
            localized.title = copy.text(.settingsExcludedApps)
            localized.descriptionText = copy.text(.settingsExcludedAppsDescription)
        case "exclusions.behavior":
            localized.title = copy.text(.settingsCaptureBehavior)
            localized.descriptionText = copy.text(.settingsCaptureBehaviorDescription)
        case "exclusions.pause":
            localized.title = copy.text(.settingsPauseCapture)
            localized.descriptionText = copy.text(.settingsPauseDescription)
        case "hotkeys.global":
            localized.title = copy.text(.settingsGlobalShortcuts)
            localized.descriptionText = copy.text(.settingsGlobalHotkeysDescription)
        case "hotkeys.snippets":
            localized.title = copy.text(.settingsSnippetHotkeys)
            localized.descriptionText = copy.text(.settingsSnippetHotkeysDescription)
        case "hotkeys.status":
            localized.title = copy.text(.settingsRuntimeStatus)
        case "snippets.library":
            localized.title = copy.text(.settingsSnippetLibrary)
            localized.descriptionText = copy.text(.settingsSnippetLibraryDescription)
        case "snippets.editor":
            localized.title = copy.text(.settingsEditorState)
        case "security.app-lock":
            localized.title = copy.text(.settingsSecurity)
            localized.descriptionText = copy.text(.securityAppLockDescription)
        case "security.unlock-method":
            localized.title = copy.text(.securityUnlockMethod)
            localized.descriptionText = copy.text(.securityUnlockMethodDescription)
        case "security.auto-lock":
            localized.title = copy.text(.securityAutoLock)
            localized.descriptionText = copy.text(.securityAutoLockDescription)
        case "security.privacy":
            localized.title = copy.text(.securityPrivacy)
            localized.descriptionText = copy.text(.securityPrivacyDescription)
        case "security.data-protection":
            localized.title = copy.text(.securityDataProtection)
            localized.descriptionText = copy.text(.securityDataProtectionDescription)
        case "bridge.behavior":
            localized.title = copy.text(.bridgeBehavior)
            localized.descriptionText = copy.text(.bridgeBehaviorDescription)
        case "bridge.devices":
            localized.title = copy.text(.bridgeDevices)
            localized.descriptionText = copy.text(
                bridgeSnapshot?.devices.isEmpty == false
                    ? .bridgeObservedDevicesDescription
                    : .bridgeDevicesDescription
            )
        case "bridge.activity":
            localized.title = copy.text(.bridgeLastActivity)
            localized.descriptionText = copy.text(.bridgeActivityDescription)
        case "bridge.note":
            localized.title = copy.text(.bridgeLocalOnlyPolicy)
        case "bridge.stop":
            localized.title = copy.text(.bridgeStop)
            localized.descriptionText = copy.text(.bridgeStopDescription)
        default:
            break
        }

        localized.rows = section.rows.map(localizedRow)
        if var placeholder = localized.placeholder {
            if placeholder.id == "organization.collections.empty" {
                placeholder.title = copy.text(.settingsCreateFirstGroup)
                placeholder.detailText = copy.text(.settingsCollectionsEmptyDetail)
            } else if placeholder.id == "organization.locked.callout" {
                let isLocked = (securitySnapshot as? SecurityRuntimeSnapshot)?.lockState.revealsProtectedContent == false
                placeholder.title = copy.text(isLocked ? .settingsSearchDisabledTitle : .settingsAppLockLiveTitle)
                placeholder.detailText = copy.text(isLocked ? .settingsSearchLockedDetail : .settingsSearchUnlockedLockDetail)
                placeholder.badgeText = localizedUppercase(copy.text(isLocked ? .locked : .unlocked))
            } else if placeholder.id == "retention.pinned-callout.note" {
                placeholder.title = copy.text(.settingsPinnedPreserved)
                placeholder.detailText = copy.text(.settingsPinnedPreservedDetail)
            } else if placeholder.id == "hotkeys.snippets.empty" {
                placeholder.title = copy.text(.settingsNoSnippetShortcuts)
                placeholder.detailText = copy.text(.settingsNoSnippetShortcutsDetail)
            } else if placeholder.id == "hotkeys.status.callout" {
                placeholder.title = localizedRuntimeAvailabilityTitle
                placeholder.detailText = copy.text(.settingsHotkeyConflictTiming)
                placeholder.badgeText = localizedCountBadge(
                    snippetsHotkeysSnapshot?.registeredBindings.count ?? 0,
                    suffix: .settingsActiveBadge
                )
            } else if placeholder.id == "snippets.library.empty" {
                placeholder.title = copy.text(.settingsNoSnippets)
                placeholder.detailText = copy.text(.settingsNoSnippetsDetail)
            } else if placeholder.id == "exclusions.apps.empty" {
                placeholder.title = copy.text(.settingsNoExcludedApps)
                placeholder.detailText = copy.text(.settingsNoExcludedAppsDetail)
            } else if placeholder.id == "exclusions.behavior.active-app" {
                placeholder.title = copy.text(.settingsExcludedAppActive)
                let hidePopup = exclusionsPauseSnapshot?.behaviorSettings.hidePopupInsideExcludedApps ?? false
                placeholder.badgeText = localizedUppercase(copy.text(hidePopup ? .settingsHidePopupBadge : .settingsCaptureOnlyBadge))
            } else if placeholder.id == "snippets.editor.status" {
                placeholder.title = localizedRuntimeAvailabilityTitle
                placeholder.detailText = copy.text(.settingsSnippetEditingDetail)
                placeholder.badgeText = localizedCountBadge(
                    snippetsHotkeysSnapshot?.assignedSnippetCount ?? 0,
                    suffix: .settingsAssignedBadge
                )
            } else if placeholder.id == "bridge.note.local-only" {
                placeholder.title = copy.text(
                    bridgeSnapshot?.accountStatus == .unavailable
                        ? .bridgeUnavailable
                        : .bridgeLocalHistoryTitle
                )
                placeholder.detailText = copy.text(.bridgeLocalOnlyPolicy)
            }
            localized.placeholder = placeholder
        }
        return localized
    }

    private func localizedRow(_ row: SettingsRowModel) -> SettingsRowModel {
        switch row {
        case .toggle(var item):
            switch item.id {
            case "startup.launch-at-login":
                item.title = copy.text(.settingsLaunchAtLogin)
                item.detailText = copy.text(.settingsLaunchAtLoginDetail)
            case "clear-on-quit": item.title = copy.text(.settingsClearOnQuit)
                item.detailText = copy.text(.settingsClearOnQuitDetail)
            case "bump-pasted-item-to-front":
                item.title = copy.text(.settingsMovePastedToTop)
                item.detailText = copy.text(.settingsMovePastedToTopDetail)
            case "exclusions.hide-popup": item.title = copy.text(.settingsHidePopupInExcludedApps)
                item.detailText = copy.text(.settingsHidePopupDetail)
            case "security.app-lock-toggle":
                item.title = copy.text(.securityLockToggleTitle)
                item.detailText = copy.text(.securityLockToggleDetail)
            case "security.hide-previews":
                item.title = copy.text(.securityHidePreviews)
                item.detailText = copy.text(.securityHidePreviewsDetail)
            case "enable-bridge":
                item.title = copy.text(.bridgeEnable)
                item.detailText = copy.text(.bridgeEnableDetail)
            case "bridge.publish-on-paste":
                item.title = copy.text(.bridgePublishOnPaste)
                item.detailText = copy.text(.bridgePublishDetail)
            case "bridge.receive":
                item.title = copy.text(.bridgeReceive)
                item.detailText = copy.text(.bridgeReceiveDetail)
            default: break
            }
            return .toggle(item)
        case .slider(var item):
            switch item.id {
            case "max-items":
                item.title = copy.text(.settingsMaxItems)
                item.detailText = copy.text(.settingsRetentionPinnedNote)
                if localizationLanguage == .vietnamese {
                    item.valueLabel = item.valueLabel?.replacingOccurrences(of: " items", with: " mục")
                }
            case "cache-size":
                item.title = copy.text(.settingsMaxCacheSize)
                item.detailText = copy.text(.settingsCacheRefreshDetail)
            default: break
            }
            return .slider(item)
        case .action(var item):
            switch item.id {
            case "clear-cache": item.title = copy.text(.settingsClearNow)
            case "exclusions.add-app": item.title = copy.text(.settingsAddApp)
                item.detailText = copy.text(.settingsAddAppDetail)
            case "exclusions.resume-capturing":
                item.title = copy.text(.settingsResumeCapturing)
                item.detailText = copy.text(.settingsResumeCapturingDetail)
            case "bridge.stop": item.title = copy.text(.bridgeStop)
            default: break
            }
            return .action(item)
        case .listEntry(var item):
            switch item.id {
            case "organization.search-status":
                item.title = copy.text(.settingsSearchVisibility)
                let isUnlocked = (securitySnapshot as? SecurityRuntimeSnapshot)?.lockState.revealsProtectedContent ?? true
                if isUnlocked {
                    item.detailText = copy.text(.settingsSearchUnlockedDetail)
                } else {
                    item.detailText = copy.text(.popupSearchLockedDetail)
                }
                item.accessoryText = copy.text(isUnlocked ? .unlocked : .locked)
            case "organization.note-source":
                item.title = copy.text(.settingsNoteSource)
                item.detailText = copy.text(.settingsNoteSourceDetail)
            case let id where id.hasPrefix("organization.group."):
                let isSelected = item.accessoryText != nil
                item.detailText = copy.text(isSelected ? .settingsGroupActiveDetail : .settingsGroupAvailableDetail)
                item.accessoryText = isSelected ? copy.text(.settingsSelected) : nil
            case let id where id.hasPrefix("exclusions.remove."):
                item.accessoryText = copy.text(.settingsRemoveApp)
            case "global:openSlipboard":
                item.title = copy.text(.menuOpenSlipBoard)
                localizeHotkeyState(&item)
            case "global:pasteAs":
                item.title = copy.text(.actionPasteAs)
                localizeHotkeyState(&item)
            case "global:pauseCapturing":
                item.title = copy.text(.menuPauseCapture)
                localizeHotkeyState(&item)
            case let id where id.hasPrefix("future:") || id.hasPrefix("snippet:"):
                localizeHotkeyState(&item)
            case "security.current-state":
                item.title = copy.text(.securityCurrentState)
                let isUnlocked = (securitySnapshot as? SecurityRuntimeSnapshot)?.lockState.revealsProtectedContent ?? true
                item.accessoryText = copy.text(isUnlocked ? .securityLockSlipBoard : .securityUnlock)
            case "security.encryption-status":
                item.title = copy.text(.securityEncryptionStatus)
                item.detailText = copy.text(.securityEncryptionDetail)
                let isEnabled = (securitySnapshot as? SecurityRuntimeSnapshot)?.settings.isAppLockEnabled ?? false
                item.accessoryText = copy.text(isEnabled ? .enabled : .disabled)
            case "security.key-storage":
                item.title = copy.text(.securityKeyStorage)
                item.detailText = copy.text(.securityKeyStorageDetail)
            case "security.decrypted-cache":
                item.title = copy.text(.securityDecryptedCache)
                item.detailText = copy.text(.securityDecryptedCacheDetail)
                let isInMemory = (securitySnapshot as? SecurityRuntimeSnapshot)?.hasUnwrappedPayloadKey ?? false
                item.accessoryText = copy.text(isInMemory ? .securityInMemory : .securityCleared)
            case "bridge.activity.last-sent":
                item.title = copy.text(.bridgeLastSent)
                if bridgeSnapshot?.activity.lastPublishedAt == nil {
                    item.detailText = copy.text(.bridgeNoMacPastes)
                    item.accessoryText = copy.text(.retentionNever)
                } else if let date = bridgeSnapshot?.activity.lastPublishedAt {
                    item.detailText = copy.text(.bridgeSentSupportedDetail)
                    item.accessoryText = localizedRelativeTimestamp(for: date)
                    item.badgeText = Date().timeIntervalSince(date) < 60 ? copy.text(.commonNow) : nil
                }
            case "bridge.activity.last-received":
                item.title = copy.text(.bridgeLastReceived)
                if bridgeSnapshot?.activity.lastImportedAt == nil {
                    item.detailText = copy.text(.bridgeNoCompanionImports)
                    item.accessoryText = copy.text(.retentionNever)
                } else if let date = bridgeSnapshot?.activity.lastImportedAt {
                    item.detailText = copy.text(.bridgeReceivedLocalDetail)
                    item.accessoryText = localizedRelativeTimestamp(for: date)
                    item.badgeText = Date().timeIntervalSince(date) < 60 ? copy.text(.commonNow) : nil
                }
            case "bridge.activity.pending-imports":
                item.title = copy.text(.bridgePendingImports)
                let pendingCount = bridgeSnapshot?.activity.pendingImportCount ?? 0
                item.detailText = copy.text(pendingCount > 0 ? .bridgeEligiblePendingDetail : .bridgePendingImportsDetail)
                item.badgeText = pendingCount > 0 ? copy.text(.commonPending) : nil
            case "bridge.activity.last-error":
                item.title = copy.text(.bridgeLastError)
                item.accessoryText = copy.text(.commonError)
                item.badgeText = copy.text(.commonError)
            case let id where id.hasPrefix("snippet.library."):
                let entryID = String(id.dropFirst("snippet.library.".count))
                let entry = snippetsHotkeysSnapshot?.snippetsSettingsState.libraryEntries.first { $0.id == entryID }
                if entry?.subtitle == nil {
                    item.detailText = copy.text(.settingsSavedLocallyDetail)
                }
                item.badgeText = entry?.isPinned == true
                    ? copy.text(.settingsPinnedBadge)
                    : (entry?.isSelected == true ? copy.text(.settingsOpenBadge) : nil)
            case "snippets.editor.selection":
                let editorState = snippetsHotkeysSnapshot?.snippetsSettingsState.editorState
                if editorState?.savedRecord == nil {
                    item.title = copy.text(.settingsNoSnippetSelected)
                }
                if let editorState {
                    switch editorState.validationState {
                    case .valid:
                        item.detailText = copy.text(
                            editorState.savedRecord == nil
                                ? .settingsCreateOrSelectSnippetDetail
                                : .settingsCurrentSnippetDraftDetail
                        )
                    case .missingTitle:
                        item.detailText = copy.text(.settingsSnippetMissingTitle)
                    case .missingContent:
                        item.detailText = copy.text(.settingsSnippetMissingContent)
                    case .hotkeyConflict:
                        break
                    }
                }
                item.badgeText = editorState?.isDirty == true
                    ? copy.text(.settingsDirtyBadge)
                    : (editorState?.canSave == true ? copy.text(.settingsReadyBadge) : nil)
            default:
                break
            }
            return .listEntry(item)
        case .choice(var item):
            switch item.id {
            case "ttl":
                item.title = copy.text(.settingsClearHistoryAfter)
                item.detailText = copy.text(.settingsRetentionPeriodDetail)
            case "exclusions.pause": item.title = copy.text(.settingsPausePreset)
                item.detailText = copy.text(.settingsPausePresetDetail)
                item.options = item.options.map { option in
                    var option = option
                    if option.id == CapturePauseDurationOption.untilResume.rawValue {
                        option.label = copy.text(.menuPausedUntilResume)
                    }
                    return option
                }
            case "security.unlock-method":
                item.title = copy.text(.securityPreferredMethod)
                item.options = item.options.map { option in
                    var option = option
                    option.label = option.id.localizedCaseInsensitiveContains("biometric")
                        ? "Touch ID / Face ID"
                        : copy.text(.securitySystemPassword)
                    return option
                }
            case "security.auto-lock": item.title = copy.text(.securityTimeout)
            default: break
            }
            return .choice(item)
        }
    }

    private func localizedUppercase(_ value: String) -> String {
        value.uppercased(with: Locale(identifier: localizationLanguage.localeIdentifier))
    }

    private func localizedRelativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: localizationLanguage.localeIdentifier)
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private var localizedRuntimeAvailabilityTitle: String {
        let stateText: String
        switch snippetsHotkeysSnapshot?.runtimeAvailability ?? .enabled {
        case .enabled:
            stateText = copy.text(.commonActive)
        case .lockedDisabled:
            stateText = copy.text(.locked)
        case .futureCommandUnavailable:
            stateText = copy.text(.commonFuture)
        case .registrationUnavailable:
            stateText = copy.text(.commonUnavailable)
        }
        return "\(copy.text(.settingsHotkeys)): \(stateText)"
    }

    private func localizedCountBadge(_ count: Int, suffix: LocalizationKey) -> String {
        "\(count) \(localizedUppercase(copy.text(suffix)))"
    }

    private func localizeHotkeyState(_ item: inout SettingsListEntry) {
        guard let snapshot = snippetsHotkeysSnapshot else { return }
        let bindings = snapshot.hotkeysSettingsState.globalBindings + snapshot.hotkeysSettingsState.snippetBindings
        guard let binding = bindings.first(where: { $0.id == item.id }) else { return }

        if binding.hotkey == nil {
            switch binding.availability {
            case .enabled:
                item.accessoryText = copy.text(.commonNotSet)
            case .lockedDisabled:
                item.accessoryText = copy.text(.locked)
            case .futureCommandUnavailable:
                item.accessoryText = copy.text(.commonFuture)
            case .registrationUnavailable:
                item.accessoryText = copy.text(.commonUnavailable)
            }
        }

        switch binding.availability {
        case .enabled:
            item.badgeText = localizedUppercase(copy.text(.commonActive))
        case .lockedDisabled:
            item.badgeText = localizedUppercase(copy.text(.locked))
        case .futureCommandUnavailable:
            item.badgeText = localizedUppercase(copy.text(.commonFuture))
        case .registrationUnavailable:
            item.badgeText = localizedUppercase(copy.text(.commonUnavailable))
        }
    }

    @ViewBuilder
    private func bridgePaneSections(for pane: SettingsPaneModel) -> some View {
        let behaviorSection = bridgeSection(in: pane, matching: ["bridge.behavior", "behavior"])
        let devicesSection = bridgeSection(in: pane, matching: ["bridge.devices", "devices"])
        let activitySection = bridgeSection(in: pane, matching: ["bridge.activity", "activity"])
        let noteSection = bridgeSection(in: pane, matching: ["bridge.note", "note", "policy"])
        let stopSection = bridgeSection(in: pane, matching: ["bridge.stop", "danger", "stop"])

        SBPaneSection(
            title: behaviorSection?.title ?? copy.text(.bridgeBehavior),
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
                title: copy.text(.bridgeScopeLabel),
                valueText: "Text / URL / Code",
                detailText: copy.text(.bridgeSupportedPastesV1Detail),
                theme: theme,
                tone: .info
            )
        }

        SBPaneSection(title: copy.text(.bridgePasteFlow), theme: theme) {
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
            title: devicesSection?.title ?? copy.text(.bridgeDevices),
            descriptionText: devicesSection?.descriptionText,
            theme: theme
        ) {
            let deviceRows = bridgeDeviceRows(in: devicesSection)
            if deviceRows.isEmpty {
                SBEmptyStateCard(
                    title: copy.text(.bridgeNoDevices),
                    detailText: copy.text(.bridgeNoDevicesDetail),
                    theme: theme
                )
            } else {
                ForEach(deviceRows) { item in
                    SBBridgeDeviceRow(
                        title: item.title,
                        detailText: bridgeDeviceDetail(for: item),
                        statusText: bridgeDeviceStatusText(),
                        symbolName: bridgeDeviceSymbolName(for: item),
                        theme: theme,
                        tone: bridgeDeviceTone(for: item)
                    )
                }
            }
        }

        SBPaneSection(
            title: activitySection?.title ?? copy.text(.bridgeLastActivity),
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
            title: noteSection?.placeholder?.id == "bridge.placeholder" ? nil : noteSection?.placeholder?.title,
            detailText: bridgePolicyNoteText(from: noteSection),
            theme: theme,
            symbolName: "shield"
        )

        SBPaneSection(
            title: stopSection?.title ?? copy.text(.bridgeStop),
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
        let searchSection = pane.sections.first { $0.id == "organization.search" }
        let collectionsSection = pane.sections.first { $0.id == "organization.collections" }
        let calloutPlaceholder = pane.sections.compactMap(\.placeholder).first

        SBPaneSection(
            title: copy.text(.settingsLanguageTitle),
            descriptionText: copy.text(.settingsLanguageDescription),
            theme: theme
        ) {
            InteractiveChoiceRow(
                item: SettingsChoiceItem(
                    id: "app-language",
                    title: copy.text(.language),
                    selectedOptionID: localizationLanguage.rawValue,
                    options: AppLanguage.allCases.map { language in
                        SettingsChoiceOption(
                            id: language.rawValue,
                            label: copy.text(language == .english ? .languageEnglish : .languageVietnamese),
                            isSelected: language == localizationLanguage
                        )
                    },
                    style: .segmented
                ),
                theme: theme,
                onSelect: { onSelectChoice("app-language", $0) }
            )
        }

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
            SBPaneSection(title: copy.text(.settingsLockedStateHeading), theme: theme) {
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

        if hotkeysState.inlineMessage?.isEmpty == false {
            SBSettingsConflictCallout(
                title: snapshot.runtimeAvailability == .lockedDisabled
                    ? copy.text(.hotkeyAccessLocked)
                    : copy.text(.hotkeyInfo),
                detailText: snapshot.runtimeAvailability == .lockedDisabled
                    ? copy.text(.hotkeyAccessLockedDetail)
                    : copy.text(.hotkeyInfoDetail),
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
            SBPaneSection(title: copy.text(.menuStatus), theme: theme) {
                SBSettingsSectionPlaceholder(placeholder: statusPlaceholder, theme: theme)
            }
        }
    }

    private func shortcutAssignmentRow(
        for binding: HotkeyBindingSummary,
        recorderSession: HotkeyRecorderSessionState
    ) -> some View {
        SBShortcutAssignmentRow(
            title: shortcutTitle(for: binding),
            detailText: shortcutDetailText(for: binding),
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
                return copy.text(.hotkeyRecorderInstruction)
            case .conflict:
                return copy.text(.hotkeyConflictDetail)
            case .disabled:
                return copy.text(.hotkeyUnlockToEdit)
            case .idle, .saved:
                break
            }
        }

        if binding.latestConflict != nil {
            return copy.text(.hotkeyConflictDetail)
        }

        return shortcutDetailText(for: binding)
    }

    private func shortcutTitle(for binding: HotkeyBindingSummary) -> String {
        switch binding.target {
        case let .globalCommand(commandID):
            switch commandID {
            case .openSlipboard: return copy.text(.menuOpenSlipBoard)
            case .pasteAs: return copy.text(.actionPasteAs)
            case .pauseCapturing: return copy.text(.menuPauseCapture)
            }
        case .snippet, .reservedFutureCommand:
            return binding.title
        }
    }

    private func shortcutDetailText(for binding: HotkeyBindingSummary) -> String {
        switch binding.availability {
        case .lockedDisabled:
            return copy.text(.hotkeyUnlockToEdit)
        case .registrationUnavailable:
            return copy.text(.commonUnavailable)
        case .futureCommandUnavailable:
            return copy.text(.hotkeyFutureCommandDetail)
        case .enabled:
            break
        }

        switch binding.target {
        case let .globalCommand(commandID):
            switch commandID {
            case .openSlipboard: return copy.text(.hotkeyOpenSlipBoardDetail)
            case .pasteAs: return copy.text(.hotkeyPasteAsDetail)
            case .pauseCapturing: return copy.text(.hotkeyPauseCaptureDetail)
            }
        case .snippet:
            return copy.text(.hotkeySnippetDetail)
        case .reservedFutureCommand:
            return copy.text(.hotkeyFutureCommandDetail)
        }
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
        if action.role == .standard, action.id == "exclusions.add-app" {
            return .primary
        }

        return tone(for: action.role)
    }

    private func bridgeSubtitle(for pane: SettingsPaneModel) -> String {
        return pane.subtitle
    }

    private func bridgeHeaderStatus(for pane: SettingsPaneModel) -> (title: String, tone: SBAccentTone, symbolName: String?) {
        if let bridgeSnapshot {
            switch bridgeSnapshot.accountStatus {
            case .error:
                return (copy.text(.commonError), .danger, "exclamationmark.circle")
            case .restricted:
                return (copy.text(.commonRestricted), .warning, "lock")
            case .unavailable:
                return (copy.text(.commonUnavailable), .warning, "icloud.slash")
            case .syncing:
                return (copy.text(.bridgeSyncing), .info, "arrow.triangle.2.circlepath")
            case .ready:
                return (copy.text(.bridgeReady), .success, "checkmark.circle")
            case .disabled:
                return (copy.text(.commonOff), .neutral, "pause.circle")
            }
        }

        if isBridgeEnabled(for: pane) {
            return (copy.text(.bridgeReady), .success, "checkmark.circle")
        }

        return (copy.text(.commonOff), .neutral, "pause.circle")
    }

    private func bridgeSection(
        in pane: SettingsPaneModel,
        matching tokens: [String]
    ) -> SettingsPaneSection? {
        pane.sections.first { section in
            tokens.contains { token in
                section.id == token || section.id.hasSuffix(".\(token)")
            }
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
                title: copy.text(.bridgeEnable),
                detailText: copy.text(.bridgeEnableDetail),
                isOn: false
            ),
            SettingsToggleItem(
                id: "bridge.publish-on-paste",
                title: copy.text(.bridgePublishOnPaste),
                detailText: copy.text(.bridgePublishDetail),
                isOn: false,
                isEnabled: false
            ),
            SettingsToggleItem(
                id: "bridge.receive",
                title: copy.text(.bridgeReceive),
                detailText: copy.text(.bridgeReceiveDetail),
                isOn: false,
                isEnabled: false
            )
        ]
    }

    private func bridgeFlowRows(isEnabled: Bool) -> [BridgeFlowStepPresentation] {
        [
            BridgeFlowStepPresentation(
                title: copy.text(.bridgePickOnMac),
                detailText: copy.text(.bridgePickOnMacDetail),
                symbolName: "cursorarrow.click",
                trailingAccessory: .keyboardHint("↵")
            ),
            BridgeFlowStepPresentation(
                title: copy.text(.bridgePasteOnMac),
                detailText: copy.text(.bridgePasteOnMacDetail),
                symbolName: "laptopcomputer",
                trailingAccessory: .badge(copy.text(.commonLocal), tone: .success),
                isEmphasized: isEnabled
            ),
            BridgeFlowStepPresentation(
                title: copy.text(.bridgePublishOneShot),
                detailText: copy.text(.bridgePublishOneShotDetail),
                symbolName: "icloud.and.arrow.up",
                trailingAccessory: .badge(copy.text(.bridgeOneShotTTL, ["minutes": "10"]), tone: .info)
            ),
            BridgeFlowStepPresentation(
                title: copy.text(.bridgeReceiveOnIPhone),
                detailText: copy.text(.bridgeReceiveOnIPhoneDetail),
                symbolName: "iphone",
                trailingAccessory: .badge(isEnabled ? copy.text(.bridgeReady) : copy.text(.commonOff), tone: isEnabled ? .success : .neutral)
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
        switch bridgeDevice(for: item)?.platform {
        case .mac: return "laptopcomputer"
        case .ipad: return "ipad"
        case .iphone: return "iphone"
        case .unknown, .none:
            return item.symbolName ?? "iphone"
        }
    }

    private func bridgeDeviceDetail(for item: SettingsListEntry) -> String {
        if let lastSeenAt = bridgeDevice(for: item)?.lastSeenAt {
            return copy.text(
                .bridgeDeviceLastSeenDetail,
                ["time": localizedRelativeTimestamp(for: lastSeenAt)]
            )
        }

        return copy.text(.bridgeSameICloudAccount)
    }

    private func bridgeDeviceTone(for item: SettingsListEntry) -> SBAccentTone {
        switch bridgeSnapshot?.accountStatus {
        case .ready: return .success
        case .syncing: return .info
        case .restricted, .unavailable: return .warning
        case .error: return .danger
        case .disabled, .none: return .neutral
        }
    }

    private func bridgeDeviceStatusText() -> String {
        switch bridgeSnapshot?.accountStatus {
        case .ready: return copy.text(.bridgeReady)
        case .syncing: return copy.text(.bridgeSyncing)
        case .restricted: return copy.text(.commonRestricted)
        case .unavailable: return copy.text(.commonUnavailable)
        case .error: return copy.text(.commonError)
        case .disabled, .none: return copy.text(.commonOff)
        }
    }

    private func bridgeDevice(for item: SettingsListEntry) -> BridgeDeviceSummary? {
        let prefix = "bridge.device."
        guard item.id.hasPrefix(prefix) else { return nil }
        let deviceID = String(item.id.dropFirst(prefix.count))
        return bridgeSnapshot?.devices.first { $0.id == deviceID }
    }

    private func bridgeActivityRows(in section: SettingsPaneSection?) -> [BridgeActivityRowPresentation] {
        let rows = section?.rows.compactMap { row -> BridgeActivityRowPresentation? in
            switch row {
            case let .listEntry(item):
                return BridgeActivityRowPresentation(
                    title: item.title,
                    valueText: item.badgeText ?? item.accessoryText ?? copy.text(.retentionNever),
                    detailText: item.detailText,
                    tone: bridgeActivityTone(for: item)
                )
            case let .action(item):
                return BridgeActivityRowPresentation(
                    title: item.title,
                    valueText: item.accessoryText ?? copy.text(.bridgeReview),
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
            BridgeActivityRowPresentation(title: copy.text(.bridgeLastSent), valueText: copy.text(.retentionNever), detailText: copy.text(.bridgeNoMacPastes), tone: .neutral),
            BridgeActivityRowPresentation(title: copy.text(.bridgeLastReceived), valueText: copy.text(.retentionNever), detailText: copy.text(.bridgeNoCompanionImports), tone: .neutral),
            BridgeActivityRowPresentation(title: copy.text(.bridgePendingImports), valueText: "0", detailText: copy.text(.bridgePendingImportsDetail), tone: .info)
        ]
    }

    private func bridgeActivityTone(for item: SettingsListEntry) -> SBAccentTone {
        if item.id == "bridge.activity.last-error" {
            return .danger
        }
        if item.id == "bridge.activity.pending-imports" {
            return .info
        }
        return item.badgeText == nil && item.accessoryText == nil ? .neutral : .success
    }

    private func bridgePolicyNoteText(from section: SettingsPaneSection?) -> String {
        return copy.text(.bridgeLocalOnlyPolicy)
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
            title: copy.text(.bridgeStop),
            detailText: copy.text(.bridgeStopDescription),
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
            .first { $0.id == "enable-bridge" }?
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
