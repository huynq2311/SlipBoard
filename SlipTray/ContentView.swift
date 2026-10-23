import Foundation
import SwiftUI

struct ContentView: View {
    @ObservedObject var runtime: ClipboardHistoryAppRuntime
    @State private var settingsPreviewSection: SettingsSectionID = .hotkeys
    @State private var securityPreviewSettings = SecuritySettings(
        isAppLockEnabled: true,
        unlockMethod: .biometricPreferred,
        autoLockInterval: .fiveMinutes,
        privacyMode: .standard
    )
    @State private var snippetRecords = SnippetsHotkeysMockFixtures.runtimeSnapshot.snippets
    @State private var globalHotkeyBindings = SnippetsHotkeysMockFixtures.runtimeSnapshot.globalBindings
    @State private var snippetEditorState = SnippetsHotkeysMockFixtures.runtimeSnapshot.snippetsSettingsState.editorState
    @State private var recorderSession = HotkeyRecorderSessionState()
    @State private var hotkeysInlineMessage = SnippetsHotkeysMockFixtures.hotkeysSettingsState.inlineMessage
    @State private var recorderSeed = 0

    let isPopupPresented: Bool
    let onTogglePopupPresentation: (Bool) -> Void
    let onShowSettings: () -> Void

    var body: some View {
        let theme = runtime.popupTheme

        ZStack {
            theme.palette.canvas
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.spacing.section24) {
                    runtimeHeader(theme: theme)
                    runtimeHost(theme: theme)
                    settingsShellPreview(theme: theme)
                    organizationDiagnostics(theme: theme)
                    retentionDiagnostics(theme: theme)
                    runtimeNotes(theme: theme)
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private func runtimeHeader(theme: SBTheme) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.section16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SlipTray Runtime Host")
                    .font(theme.typography.paneTitle)
                    .foregroundStyle(theme.palette.textPrimary)

                Text("The main window, floating popup, menu bar summary, and organization/search overlay all read from one live runtime path.")
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: theme.spacing.control12) {
                actionButton(
                    title: isPopupPresented ? "Hide Floating Popup" : "Show Floating Popup",
                    systemImage: isPopupPresented ? "rectangle.compress.vertical" : "menubar.rectangle",
                    theme: theme,
                    isPrimary: isPopupPresented
                ) {
                    onTogglePopupPresentation(isPopupPresented == false)
                }

                actionButton(
                    title: runtime.isMonitoring ? "Pause Monitoring" : "Start Monitoring",
                    systemImage: runtime.isMonitoring ? "pause.circle" : "play.circle",
                    theme: theme,
                    isPrimary: false
                ) {
                    runtime.isMonitoring ? runtime.stopMonitoring() : runtime.startMonitoring()
                }

                actionButton(
                    title: "Refresh Now",
                    systemImage: "arrow.clockwise",
                    theme: theme,
                    isPrimary: false,
                    action: runtime.refreshNow
                )

                actionButton(
                    title: "Open Settings",
                    systemImage: "gearshape",
                    theme: theme,
                    isPrimary: false,
                    action: onShowSettings
                )

                actionButton(
                    title: securityPreviewSettings.isAppLockEnabled
                        ? (securitySnapshot.lockState.revealsProtectedContent ? "Lock SlipTray" : "Unlock SlipTray")
                        : "App Lock Off",
                    systemImage: securityPreviewSettings.isAppLockEnabled
                        ? (securitySnapshot.lockState.revealsProtectedContent ? "lock" : "lock.open")
                        : "lock.slash",
                    theme: theme,
                    isPrimary: securityPreviewSettings.isAppLockEnabled && securitySnapshot.lockState.revealsProtectedContent == false
                ) {
                    guard securityPreviewSettings.isAppLockEnabled else {
                        settingsPreviewSection = .security
                        return
                    }

                    runtime.toggleSearchLockForQA()
                }
                .disabled(securityPreviewSettings.isAppLockEnabled == false)
                .opacity(securityPreviewSettings.isAppLockEnabled ? 1 : 0.5)

                Spacer(minLength: theme.spacing.control12)

                themePicker(theme: theme)
            }
        }
        .padding(theme.spacing.section24)
        .sbSurface(.window, theme: theme)
    }

    @ViewBuilder
    private func runtimeHost(theme: SBTheme) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.section16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Clipboard History")
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)

                    Text("This host mirrors the same live projection, note editing, group chips, paste execution wiring, and locked/redacted shell mapping used by the floating popup for QA visibility.")
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textSecondary)
                }

                Spacer(minLength: theme.spacing.control12)

                SBCountBadge(
                    text: runtime.menuBarSummary.badgeText,
                    theme: theme,
                    tone: runtime.isMonitoring ? .primary : .neutral,
                    compact: true
                )
            }

            ClipboardHistoryPopupView(
                theme: theme,
                filters: runtime.filterOptions,
                state: runtime.popupState,
                exclusionsPauseSnapshot: exclusionsPauseSnapshot,
                searchNotesState: runtime.searchNotesState,
                securitySnapshot: securitySnapshot,
                pasteOverlayState: runtime.pasteOverlayState,
                supportedTransformActionIDs: runtime.supportedTransformActionIDs,
                onToggleSearchPresented: runtime.setSearchPresented,
                onSearchQueryChange: runtime.updateSearchQuery,
                onSelectFilter: runtime.selectFilter,
                onSelectThemePreview: runtime.selectThemePreview,
                onSelectClipID: runtime.selectClip,
                onMoveSelection: runtime.moveSelection,
                onToggleNoteEditor: runtime.toggleNoteEditor,
                onUpdateNoteDraft: runtime.updateNoteDraft,
                onSaveNoteDraft: runtime.saveNoteDraft,
                onCancelNoteEditing: runtime.cancelNoteEditing,
                onOpenContextMenu: runtime.openContextMenu,
                onOpenPasteTransformMenu: runtime.openPasteTransformMenu,
                onCloseActiveOverlay: runtime.closeActiveOverlay,
                onHighlightContextAction: runtime.highlightContextAction,
                onPerformContextAction: runtime.performContextAction,
                onHighlightTransformAction: runtime.highlightTransformAction,
                onSelectTransformAction: runtime.selectTransformAction,
                onExecutePasteAction: { actionID, closeBehavior in
                    _ = runtime.performPasteAction(actionID, closeBehavior: closeBehavior)
                }
            )
            .frame(maxWidth: .infinity, alignment: .center)

            if let exclusionsPauseSnapshot {
                exclusionsPauseDiagnostics(snapshot: exclusionsPauseSnapshot, theme: theme)
            }

            if securitySnapshot.isPreviewRedactionActive || securitySnapshot.lockState.revealsProtectedContent == false {
                Text(
                    securitySnapshot.isPreviewRedactionActive
                        ? "Privacy mode is redacting previews on the existing popup and clip-card shell surfaces."
                        : "Locked state is replacing the rails with the approved in-shell security body while keeping the existing popup dimensions intact."
                )
                .font(theme.typography.meta)
                .foregroundStyle(theme.palette.textTertiary)
            }
        }
        .padding(theme.spacing.section24)
        .sbSurface(.subpanel, theme: theme)
    }

    @ViewBuilder
    private func exclusionsPauseDiagnostics(snapshot: ExclusionsPauseSnapshot, theme: SBTheme) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.control8) {
            HStack(alignment: .center, spacing: theme.spacing.control8) {
                Text("Exclusions / Pause")
                    .font(theme.typography.meta)
                    .foregroundStyle(theme.palette.textTertiary)
                    .textCase(.uppercase)

                Spacer(minLength: theme.spacing.control8)

                SBCountBadge(
                    text: snapshotBadgeText(snapshot),
                    theme: theme,
                    tone: snapshotBadgeTone(snapshot),
                    compact: true
                )
            }

            VStack(alignment: .leading, spacing: theme.spacing.control6) {
                diagnosticsRow(
                    title: "Capture",
                    value: captureDiagnosticsText(snapshot),
                    detail: captureDiagnosticsDetail(snapshot),
                    theme: theme
                )
                diagnosticsRow(
                    title: "Frontmost",
                    value: frontmostAppText(snapshot),
                    detail: frontmostAppDetail(snapshot),
                    theme: theme
                )
                diagnosticsRow(
                    title: "Popup",
                    value: popupDiagnosticsText(snapshot),
                    detail: popupDiagnosticsDetail(snapshot),
                    theme: theme
                )
            }
        }
        .padding(theme.spacing.control12)
        .sbSurface(.raised, theme: theme)
    }

    private func diagnosticsRow(
        title: String,
        value: String,
        detail: String,
        theme: SBTheme
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.control12) {
            Text(title)
                .font(theme.typography.meta)
                .foregroundStyle(theme.palette.textTertiary)
                .frame(width: 68, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textPrimary)
                    .lineLimit(1)

                Text(detail)
                    .font(theme.typography.meta)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.control8)
        }
    }

    @ViewBuilder
    private func settingsShellPreview(theme: SBTheme) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.section16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings Panes")
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)

                    Text("Hotkeys and Snippets now render on the approved settings shell path with compact inline help, lock-aware disabled states, and a split library/editor detail pane.")
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: theme.spacing.control12)

                SBCountBadge(
                    text: securitySnapshot.lockState.revealsProtectedContent ? "UNLOCKED" : "LOCKED",
                    theme: theme,
                    tone: securitySnapshot.lockState.revealsProtectedContent ? .success : .danger,
                    compact: true
                )
            }

            SBSettingsWindowShell(
                theme: runtime.settingsTheme,
                state: settingsPreviewState,
                securitySnapshot: securitySnapshot,
                onSelectSection: { settingsPreviewSection = $0 },
                onSelectChoice: handleSettingsPreviewChoice,
                onToggle: handleSettingsPreviewToggle,
                onAdjustSlider: runtime.handleSettingsSlider,
                onSelectAction: handleSettingsPreviewAction
            )
            .frame(height: 640)
            .overlay(alignment: .topLeading) {
                if settingsPreviewSection == .hotkeys || settingsPreviewSection == .snippets {
                    settingsCustomPaneOverlay(theme: runtime.settingsTheme)
                }
            }
        }
        .padding(theme.spacing.section24)
        .sbSurface(.subpanel, theme: theme)
    }

    @ViewBuilder
    private func organizationDiagnostics(theme: SBTheme) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.section16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search, Notes, and Organization")
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)

                    Text("QA controls for the shared FTS/group runtime. The same state still drives popup chips, inline note editing, and disabled search while the security shell is locked.")
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: theme.spacing.control12)

                SBCountBadge(
                    text: securitySnapshot.lockState.revealsProtectedContent ? "UNLOCKED" : "LOCKED",
                    theme: theme,
                    tone: securitySnapshot.lockState.revealsProtectedContent ? .success : .danger,
                    compact: true
                )
            }

            HStack(alignment: .center, spacing: theme.spacing.control12) {
                TextField(
                    "New or selected group name",
                    text: Binding(
                        get: { runtime.organizationDraftName },
                        set: runtime.updateOrganizationDraftName
                    )
                )
                .textFieldStyle(.roundedBorder)

                actionButton(
                    title: "Add Group",
                    systemImage: "plus",
                    theme: theme,
                    isPrimary: false,
                    action: runtime.createOrganizationGroupFromDraft
                )

                actionButton(
                    title: "Rename",
                    systemImage: "pencil",
                    theme: theme,
                    isPrimary: false
                ) {
                    runtime.renameSelectedOrganizationGroupFromDraft()
                }
                .disabled(runtime.canRenameSelectedOrganizationGroup == false)
                .opacity(runtime.canRenameSelectedOrganizationGroup ? 1 : 0.45)

                actionButton(
                    title: "Delete",
                    systemImage: "trash",
                    theme: theme,
                    isPrimary: false
                ) {
                    runtime.deleteSelectedOrganizationGroup()
                }
                .disabled(runtime.canDeleteSelectedOrganizationGroup == false)
                .opacity(runtime.canDeleteSelectedOrganizationGroup ? 1 : 0.45)
            }

            HStack(alignment: .center, spacing: theme.spacing.control12) {
                actionButton(
                    title: "Assign Selected Clip",
                    systemImage: "folder.badge.plus",
                    theme: theme,
                    isPrimary: false,
                    action: runtime.assignSelectedClipToActiveGroup
                )
                .disabled(runtime.selectedClipIDForOrganization == nil)
                .opacity(runtime.selectedClipIDForOrganization == nil ? 0.45 : 1)

                actionButton(
                    title: "Clear Clip Groups",
                    systemImage: "folder.badge.minus",
                    theme: theme,
                    isPrimary: false,
                    action: runtime.clearSelectedClipGroups
                )
                .disabled(runtime.selectedClipIDForOrganization == nil)
                .opacity(runtime.selectedClipIDForOrganization == nil ? 0.45 : 1)

                Text(runtime.searchNotesState.searchDisabledMessage?.statusLabel ?? "Unlocked search mirrors note text and custom group names.")
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.control8) {
                    ForEach(runtime.organizationGroups) { group in
                        Button(action: {
                            runtime.selectOrganizationGroup(group.groupID)
                        }) {
                            HStack(spacing: theme.spacing.control6) {
                                Image(systemName: group.isSystem ? "square.stack.3d.up.fill" : "folder")
                                    .font(.system(size: 11, weight: .medium))

                                Text(group.name)
                                    .font(theme.typography.chip)
                                    .lineLimit(1)

                                SBCountBadge(
                                    text: "\(group.itemCount)",
                                    theme: theme,
                                    tone: runtime.selectedOrganizationGroupID == group.groupID ? .primary : .neutral,
                                    compact: true
                                )
                            }
                            .foregroundStyle(runtime.selectedOrganizationGroupID == group.groupID ? theme.palette.textPrimary : theme.palette.textSecondary)
                            .padding(.horizontal, theme.spacing.control10)
                            .padding(.vertical, theme.spacing.control6)
                            .background(runtime.selectedOrganizationGroupID == group.groupID ? theme.palette.panel : theme.palette.raised)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        runtime.selectedOrganizationGroupID == group.groupID ? theme.palette.accentPrimary : theme.palette.border,
                                        lineWidth: theme.border.hairline
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(theme.spacing.section24)
        .sbSurface(.subpanel, theme: theme)
    }

    @ViewBuilder
    private func retentionDiagnostics(theme: SBTheme) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.section16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Retention Diagnostics")
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)

                    Text("QA-visible runtime state for the shared retention path across launch, foreground cleanup, menu quick-retention, and the Retention settings pane.")
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: theme.spacing.control12)

                SBCountBadge(
                    text: runtime.retentionTTLText,
                    theme: theme,
                    tone: .neutral,
                    compact: true
                )
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 140), spacing: theme.spacing.control12),
                    GridItem(.flexible(minimum: 140), spacing: theme.spacing.control12),
                    GridItem(.flexible(minimum: 140), spacing: theme.spacing.control12),
                    GridItem(.flexible(minimum: 180), spacing: theme.spacing.control12)
                ],
                alignment: .leading,
                spacing: theme.spacing.control12
            ) {
                diagnosticMetricCard(
                    label: "TTL",
                    value: runtime.retentionTTLText,
                    detail: "Menu and settings stay synchronized."
                )
                diagnosticMetricCard(
                    label: "Max Items",
                    value: runtime.retentionMaxItemCountText,
                    detail: "Oldest unpinned clips prune first."
                )
                diagnosticMetricCard(
                    label: "Cache Usage",
                    value: runtime.retentionCacheUsageText,
                    detail: "Local asset cache ceiling."
                )
                diagnosticMetricCard(
                    label: "Latest Cleanup",
                    value: runtime.retentionLatestCleanupText,
                    detail: "Updated by launch, foreground, settings, and manual clear flows."
                )
            }
        }
        .padding(theme.spacing.section24)
        .sbSurface(.subpanel, theme: theme)
    }

    @ViewBuilder
    private func runtimeNotes(theme: SBTheme) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.section16) {
            placeholderCard(
                title: "Capture Status",
                detail: runtime.menuBarSummary.statusLabel
            )

            placeholderCard(
                title: "Floating Popup",
                detail: isPopupPresented
                    ? "The app shell is currently presenting the same live popup, group strip, note editor, and runtime-owned paste overlay state in its native panel."
                    : "The runtime host stays visible here even while the floating popup is hidden."
            )

            placeholderCard(
                title: "Retention Path",
                detail: "Menu quick retention, the Retention pane, and lifecycle cleanup triggers now flow through one persisted runtime controller."
            )

            placeholderCard(
                title: "Lock Seam",
                detail: securitySnapshot.lockState.revealsProtectedContent == false
                    ? "The popup shell is locked in place, search controls stay visible but disabled, and the Security pane reflects the locked runtime snapshot."
                    : "The runtime is unlocked, so the popup rails, notes, and Security pane all stay on the same view-composition path."
            )
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        theme: SBTheme,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.control8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))

                Text(title)
                    .font(theme.typography.rowPrimary)
            }
            .foregroundStyle(isPrimary ? Color.white : theme.palette.textPrimary)
            .padding(.horizontal, theme.spacing.control12)
            .padding(.vertical, theme.spacing.control8)
            .background(isPrimary ? theme.palette.accentPrimary : theme.palette.raised)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func themePicker(theme: SBTheme) -> some View {
        HStack(spacing: theme.spacing.control8) {
            Text("Preview Theme")
                .font(theme.typography.chip)
                .foregroundStyle(theme.palette.textTertiary)

            Picker("Preview Theme", selection: Binding(
                get: { runtime.popupState.themePreview.appearance },
                set: { appearance in
                    var selection = runtime.popupState.themePreview
                    selection.appearance = appearance
                    runtime.selectThemePreview(selection)
                }
            )) {
                Text("Auto").tag(PopupAppearance.system)
                Text("Dark").tag(PopupAppearance.dark)
                Text("Light").tag(PopupAppearance.light)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Picker("Theme", selection: Binding(
                get: { runtime.popupState.themePreview.themeID },
                set: { themeID in
                    var selection = runtime.popupState.themePreview
                    selection.themeID = themeID
                    runtime.selectThemePreview(selection)
                }
            )) {
                ForEach(SBThemeRegistry.themes) { definition in
                    Text(definition.name(in: runtime.appLanguage)).tag(definition.id)
                }
            }
            .frame(width: 160)
        }
    }

    private func placeholderCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: runtime.popupTheme.spacing.control8) {
            Text(title)
                .font(runtime.popupTheme.typography.rowPrimary)
                .foregroundStyle(runtime.popupTheme.palette.textPrimary)

            Text(detail)
                .font(runtime.popupTheme.typography.rowSecondary)
                .foregroundStyle(runtime.popupTheme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(runtime.popupTheme.spacing.control12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .sbSurface(.raised, theme: runtime.popupTheme)
    }

    private func diagnosticMetricCard(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: runtime.popupTheme.spacing.control8) {
            Text(label.uppercased())
                .font(runtime.popupTheme.typography.meta)
                .foregroundStyle(runtime.popupTheme.palette.textTertiary)

            Text(value)
                .font(runtime.popupTheme.typography.rowPrimary)
                .foregroundStyle(runtime.popupTheme.palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(runtime.popupTheme.typography.rowSecondary)
                .foregroundStyle(runtime.popupTheme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(runtime.popupTheme.spacing.control12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .sbSurface(.raised, theme: runtime.popupTheme)
    }

    private var wrappedPreviewKey: WrappedPayloadKey {
        WrappedPayloadKey(
            keyVersion: 1,
            wrappingPolicy: .secureEnclaveWrapped,
            wrappedKeyData: Data("sb-preview-key".utf8)
        )
    }

    private var securitySnapshot: SecurityRuntimeSnapshot {
        let isLocked = securityPreviewSettings.isAppLockEnabled && runtime.isSearchLockedForQA
        let effectiveSettings = SecuritySettings(
            isAppLockEnabled: securityPreviewSettings.isAppLockEnabled,
            unlockMethod: securityPreviewSettings.unlockMethod,
            autoLockInterval: securityPreviewSettings.autoLockInterval,
            privacyMode: securityPreviewSettings.isAppLockEnabled ? securityPreviewSettings.privacyMode : .standard,
            lastUpdatedAt: securityPreviewSettings.lastUpdatedAt
        )
        let keyMaterialState: PayloadKeyMaterialState

        if securityPreviewSettings.isAppLockEnabled == false {
            keyMaterialState = .absent
        } else if isLocked {
            keyMaterialState = .wrappedOnly(wrappedPreviewKey)
        } else {
            keyMaterialState = .unwrappedInMemory(wrappedPreviewKey, unwrappedAt: .now)
        }

        return SecurityRuntimeSnapshot(
            lockState: isLocked ? .locked : .unlocked,
            settings: effectiveSettings,
            migrationState: securityPreviewSettings.isAppLockEnabled ? .ready(lastCompletedAt: .now) : .notStarted,
            keyMaterialState: keyMaterialState,
            lockedVisibleReason: isLocked ? .authenticationRequired : nil,
            lastInteractionAt: .now
        )
    }

    private var settingsPreviewState: SettingsShellState {
        SettingsShellState(
            selectedSection: settingsPreviewSection,
            general: runtime.settingsState.general,
            retention: runtime.settingsState.retention,
            exclusions: runtime.settingsState.exclusions,
            hotkeys: hotkeysPaneState,
            snippets: snippetsPaneState,
            security: securityPaneState,
            bridge: runtime.settingsState.bridge,
            about: runtime.settingsState.about
        )
    }

    private var exclusionsPauseSnapshot: ExclusionsPauseSnapshot? {
        mirroredExclusionsPauseSnapshot(in: runtime)
    }

    private var hotkeysPaneState: SettingsPaneModel {
        SettingsPaneModel(
            id: .hotkeys,
            title: "Hotkeys",
            subtitle: "Assign the popup shortcut and snippet-specific shortcuts without leaving the existing settings shell."
        )
    }

    private var snippetsPaneState: SettingsPaneModel {
        SettingsPaneModel(
            id: .snippets,
            title: "Snippets",
            subtitle: "Manage local quick snippets and their optional per-snippet hotkeys in a compact split editor."
        )
    }

    private var securityPaneState: SettingsPaneModel {
        SettingsPaneModel(
            id: .security,
            title: "Security",
            subtitle: "Local app lock, preview privacy, and payload protection stay on the existing settings shell path.",
            sections: [
                SettingsPaneSection(
                    id: "security.app-lock",
                    title: "App Lock",
                    descriptionText: "Enable local protection before showing clip previews, notes, or search results again.",
                    rows: [
                        .toggle(
                            SettingsToggleItem(
                                id: "security.app-lock-toggle",
                                title: "Lock SlipTray",
                                detailText: "Protected previews remain hidden until unlock succeeds.",
                                isOn: securityPreviewSettings.isAppLockEnabled
                            )
                        ),
                        .action(
                            SettingsActionRow(
                                id: "security.current-state",
                                title: "Current state",
                                accessoryText: securitySnapshot.lockState.revealsProtectedContent ? "Lock" : "Unlock",
                                symbolName: "lock",
                                role: .standard
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "security.unlock-method",
                    title: "Unlock method",
                    descriptionText: "Use the current platform authentication path without adding a separate SlipTray password.",
                    rows: [
                        .choice(
                            SettingsChoiceItem(
                                id: "security.unlock-method",
                                title: "Preferred method",
                                selectedOptionID: securityPreviewSettings.unlockMethod.rawValue,
                                options: SecurityUnlockMethod.allCases.map { method in
                                    SettingsChoiceOption(
                                        id: method.rawValue,
                                        label: securityLabel(for: method),
                                        isSelected: method == securityPreviewSettings.unlockMethod
                                    )
                                },
                                style: .menu
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "security.auto-lock",
                    title: "Auto-lock",
                    descriptionText: "Measure inactivity from the shared popup, menu bar, and settings interactions.",
                    rows: [
                        .choice(
                            SettingsChoiceItem(
                                id: "security.auto-lock",
                                title: "Timeout",
                                selectedOptionID: securityPreviewSettings.autoLockInterval.rawValue,
                                options: SecurityAutoLockInterval.allCases.map { interval in
                                    SettingsChoiceOption(
                                        id: interval.rawValue,
                                        label: securityLabel(for: interval),
                                        isSelected: interval == securityPreviewSettings.autoLockInterval
                                    )
                                },
                                style: .menu
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "security.privacy",
                    title: "Privacy",
                    descriptionText: "Redact previews on the existing shell surfaces instead of presenting a detached privacy screen.",
                    rows: [
                        .toggle(
                            SettingsToggleItem(
                                id: "security.hide-previews",
                                title: "Hide previews in Mission Control / Expose",
                                detailText: "The popup and clip cards swap to redacted placeholders when privacy mode is active.",
                                isOn: securityPreviewSettings.privacyMode == .hidePreviewsInMissionControl
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "security.data-protection",
                    title: "Data protection",
                    descriptionText: "Inspect local encryption readiness, key storage policy, and whether decrypted content is still in memory.",
                    rows: [
                        .listEntry(
                            SettingsListEntry(
                                id: "security.encryption-status",
                                title: "Encryption status",
                                detailText: "Protected payloads stay local and only decrypt when the current session is allowed to reveal content.",
                                accessoryText: securityPreviewSettings.isAppLockEnabled ? "Ready" : "Disabled",
                                symbolName: "lock.doc"
                            )
                        ),
                        .listEntry(
                            SettingsListEntry(
                                id: "security.key-storage",
                                title: "Key storage",
                                detailText: "Payload keys stay wrapped on this Mac and never move into sync or export flows in this slice.",
                                accessoryText: "Secure Enclave",
                                symbolName: "key"
                            )
                        ),
                        .listEntry(
                            SettingsListEntry(
                                id: "security.decrypted-cache",
                                title: "Decrypted cache",
                                detailText: "Locking clears in-memory previews before the popup can show content again.",
                                accessoryText: securitySnapshot.hasUnwrappedPayloadKey ? "In memory" : "Cleared",
                                symbolName: "memorychip"
                            )
                        )
                    ]
                )
            ]
        )
    }

    private func snapshotBadgeText(_ snapshot: ExclusionsPauseSnapshot) -> String {
        if snapshot.pauseState.isPaused {
            return "PAUSED"
        }
        if snapshot.isFrontmostAppExcluded {
            return "EXCLUDED"
        }
        return "ACTIVE"
    }

    private func snapshotBadgeTone(_ snapshot: ExclusionsPauseSnapshot) -> SBAccentTone {
        if snapshot.pauseState.isPaused {
            return .info
        }
        if snapshot.isFrontmostAppExcluded {
            return .warning
        }
        return .success
    }

    private func captureDiagnosticsText(_ snapshot: ExclusionsPauseSnapshot) -> String {
        switch snapshot.capturePolicyDecision {
        case .allow:
            return snapshot.pauseState.isPaused ? "Paused" : "Capturing"
        case .ignoreBecausePaused:
            return "Paused"
        case .ignoreBecauseExcludedApp:
            return "Ignoring current app"
        }
    }

    private func captureDiagnosticsDetail(_ snapshot: ExclusionsPauseSnapshot) -> String {
        switch snapshot.capturePolicyDecision {
        case .allow:
            if let activePauseLabel = snapshot.activePauseLabel {
                return "Pause preset: \(activePauseLabel)"
            }
            return "\(snapshot.excludedApps.count) excluded app rules loaded."
        case .ignoreBecausePaused:
            if let resumeAt = snapshot.pauseState.resumeAt {
                return "Auto-resume \(relativeTimestamp(for: resumeAt))."
            }
            return "Paused until resume is triggered."
        case let .ignoreBecauseExcludedApp(match):
            return "Rule: \(match.rule.displayName)."
        }
    }

    private func frontmostAppText(_ snapshot: ExclusionsPauseSnapshot) -> String {
        snapshot.frontmostApp?.displayName ?? "Unavailable"
    }

    private func frontmostAppDetail(_ snapshot: ExclusionsPauseSnapshot) -> String {
        if let match = snapshot.matchedExcludedApp {
            return "Matches \(match.strategy == .bundleIDExact ? "bundle" : "display-name") exclusion."
        }

        if let bundleID = snapshot.frontmostApp?.bundleID, bundleID.isEmpty == false {
            return bundleID
        }

        return "No exclusion matched."
    }

    private func popupDiagnosticsText(_ snapshot: ExclusionsPauseSnapshot) -> String {
        switch snapshot.popupPolicyDecision {
        case .allow:
            return "Allowed"
        case .suppressBecauseExcludedApp:
            return "Suppressed"
        }
    }

    private func popupDiagnosticsDetail(_ snapshot: ExclusionsPauseSnapshot) -> String {
        if snapshot.behaviorSettings.hidePopupInsideExcludedApps {
            return snapshot.isFrontmostAppExcluded
                ? "Hidden while an excluded app is frontmost."
                : "Hide-popup policy is armed for excluded apps."
        }

        return "Hide-popup policy is off."
    }

    private func relativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func mirroredExclusionsPauseSnapshot(in runtime: ClipboardHistoryAppRuntime) -> ExclusionsPauseSnapshot? {
        let runtimeMirror = Mirror(reflecting: runtime)

        for child in runtimeMirror.children {
            if let snapshot = child.value as? ExclusionsPauseSnapshot {
                return snapshot
            }

            if let publisher = child.value as? any ExclusionsPauseRuntimePublishing {
                return publisher.latestSnapshot
            }
        }

        return nil
    }

    private func handleSettingsPreviewChoice(id: String, optionID: String) {
        switch id {
        case "security.unlock-method":
            guard let method = SecurityUnlockMethod(rawValue: optionID) else { return }
            securityPreviewSettings.unlockMethod = method
        case "security.auto-lock":
            guard let interval = SecurityAutoLockInterval(rawValue: optionID) else { return }
            securityPreviewSettings.autoLockInterval = interval
        default:
            runtime.handleSettingsChoice(id: id, optionID: optionID)
        }
    }

    private func handleSettingsPreviewToggle(id: String, isOn: Bool) {
        switch id {
        case "security.app-lock-toggle":
            securityPreviewSettings.isAppLockEnabled = isOn
            if isOn == false {
                runtime.setSearchLockForQA(false)
            }
        case "security.hide-previews":
            securityPreviewSettings.privacyMode = isOn ? .hidePreviewsInMissionControl : .standard
        default:
            runtime.handleSettingsToggle(id: id, isOn: isOn)
        }
    }

    private func handleSettingsPreviewAction(id: String) {
        switch id {
        case "security.current-state":
            guard securityPreviewSettings.isAppLockEnabled else { return }
            runtime.toggleSearchLockForQA()
        default:
            runtime.handleSettingsAction(id: id)
        }
    }

    @ViewBuilder
    private func settingsCustomPaneOverlay(theme: SBTheme) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 172)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.spacing.section24) {
                    settingsPaneHeader(theme: theme)

                    if settingsPreviewSection == .hotkeys {
                        hotkeysPane(theme: theme)
                    } else {
                        snippetsPane(theme: theme)
                    }
                }
                .padding(.horizontal, theme.spacing.settingsPaneHorizontal)
                .padding(.vertical, theme.spacing.settingsPaneVertical)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.palette.panel)
        }
        .padding(.top, 36)
    }

    private func settingsPaneHeader(theme: SBTheme) -> some View {
        let pane = settingsPreviewState.pane(for: settingsPreviewSection)

        return HStack(alignment: .top, spacing: theme.spacing.section16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pane.title)
                    .font(theme.typography.paneTitle)
                    .foregroundStyle(theme.palette.textPrimary)

                Text(pane.subtitle)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.section16)

            if settingsPreviewSection == .hotkeys {
                SBCountBadge(
                    text: "\(snippetBindingsForView.count + 1) ACTIVE",
                    theme: theme,
                    tone: securitySnapshot.lockState.revealsProtectedContent ? .primary : .danger,
                    compact: true
                )
            } else {
                HStack(spacing: theme.spacing.control8) {
                    SBControlPillButton(
                        title: "New Snippet",
                        theme: theme,
                        tone: .primary,
                        isEnabled: snippetsStateForView.canCreateSnippet,
                        action: startNewSnippetDraft
                    )

                    SBCountBadge(
                        text: "\(snippetRecords.count) SNIPPETS",
                        theme: theme,
                        tone: .neutral,
                        compact: true
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func hotkeysPane(theme: SBTheme) -> some View {
        let state = hotkeysStateForView

        VStack(alignment: .leading, spacing: theme.spacing.section24) {
            if let inlineMessage = state.inlineMessage, inlineMessage.isEmpty == false {
                SBSettingsConflictCallout(
                    title: securitySnapshot.lockState.revealsProtectedContent ? "Shortcut info" : "Shortcut access is locked",
                    detailText: inlineMessage,
                    theme: theme,
                    tone: securitySnapshot.lockState.revealsProtectedContent ? .info : .warning
                )
            }

            SBPaneSection(
                title: "Global shortcuts",
                descriptionText: "Keep the popup command editable, keep popup-scoped commands visible, and reserve future commands in place.",
                theme: theme
            ) {
                ForEach(state.globalBindings) { binding in
                    SBShortcutAssignmentRow(
                        title: binding.title,
                        detailText: binding.detailText,
                        shortcutLabel: shortcutLabel(for: binding),
                        theme: theme,
                        state: shortcutVisualState(
                            for: binding.target,
                            availability: binding.availability,
                            hasAssignedShortcut: binding.hotkey != nil
                        ),
                        helperText: helperText(for: binding),
                        showsClearAction: binding.availability == .enabled,
                        isPopupScoped: binding.isPopupScoped,
                        onRecord: { handleHotkeyRowRecord(for: binding.target) },
                        onClear: { clearSavedBinding(for: binding.target) }
                    )
                }
            }

            SBPaneSection(
                title: "Snippet hotkeys",
                descriptionText: "Each saved snippet can keep a dedicated shortcut while conflicts stay inline and compact.",
                theme: theme
            ) {
                ForEach(state.snippetBindings) { binding in
                    SBShortcutAssignmentRow(
                        title: binding.title,
                        detailText: binding.detailText,
                        shortcutLabel: shortcutLabel(for: binding),
                        theme: theme,
                        state: shortcutVisualState(
                            for: binding.target,
                            availability: binding.availability,
                            hasAssignedShortcut: binding.hotkey != nil
                        ),
                        helperText: helperText(for: binding),
                        showsClearAction: binding.availability == .enabled,
                        onRecord: { handleHotkeyRowRecord(for: binding.target) },
                        onClear: { clearSavedBinding(for: binding.target) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func snippetsPane(theme: SBTheme) -> some View {
        let state = snippetsStateForView

        SBSettingsSplitEditorShell(theme: theme) {
            snippetLibraryColumn(theme: theme, state: state)
        } detail: {
            snippetDetailColumn(theme: theme, state: state)
        }
    }

    @ViewBuilder
    private func snippetLibraryColumn(theme: SBTheme, state: SnippetsSettingsState) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Library")
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)

                Text("Saved snippets stay local to this Mac.")
                    .font(theme.typography.meta)
                    .foregroundStyle(theme.palette.textSecondary)
            }

            Spacer(minLength: theme.spacing.control12)

            SBCountBadge(
                text: "\(state.libraryEntries.count)",
                theme: theme,
                tone: .neutral,
                compact: true
            )
        }

        if state.libraryEntries.isEmpty {
            SBEmptyStateCard(
                title: state.emptyStateTitle ?? "No snippets yet",
                detailText: state.emptyStateDetailText ?? "Create a local snippet to keep one-click paste templates and optional dedicated hotkeys in the same shell.",
                theme: theme,
                badgeText: "EMPTY"
            )
        } else {
            ForEach(state.libraryEntries) { entry in
                SBSnippetLibraryRow(entry: entry, theme: theme) {
                    selectSnippet(entry.snippetID)
                }
            }
        }
    }

    @ViewBuilder
    private func snippetDetailColumn(theme: SBTheme, state: SnippetsSettingsState) -> some View {
        let editorState = state.editorState
        let draft = editorState.draft

        if editorState.mode == .noSelection && state.libraryEntries.isEmpty == false {
            SBEmptyStateCard(
                title: "Select a snippet",
                detailText: "Choose a saved snippet from the left to edit its content and optional shortcut.",
                theme: theme,
                badgeText: "DETAIL"
            )
        } else {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(editorTitle(for: editorState))
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)

                    Text(editorSubtitle(for: editorState))
                        .font(theme.typography.meta)
                        .foregroundStyle(theme.palette.textSecondary)
                }

                Spacer(minLength: theme.spacing.control12)

                SBCountBadge(
                    text: draft.kind == .code ? "CODE" : "TEXT",
                    theme: theme,
                    tone: draft.kind == .code ? .primary : .info,
                    compact: true
                )
            }

            VStack(alignment: .leading, spacing: theme.spacing.control8) {
                Text("Title")
                    .font(theme.typography.uppercaseLabel)
                    .foregroundStyle(theme.palette.textTertiary)

                TextField(
                    "Snippet title",
                    text: Binding(
                        get: { draft.title },
                        set: updateSnippetDraftTitle
                    )
                )
                .textFieldStyle(.roundedBorder)
                .disabled(editorState.availability.isInteractive == false)
            }

            VStack(alignment: .leading, spacing: theme.spacing.control8) {
                HStack {
                    Text("Content")
                        .font(theme.typography.uppercaseLabel)
                        .foregroundStyle(theme.palette.textTertiary)

                    Spacer(minLength: theme.spacing.control8)

                    Toggle(
                        "Pinned",
                        isOn: Binding(
                            get: { draft.isPinned },
                            set: updateSnippetDraftPinned
                        )
                    )
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(editorState.availability.isInteractive == false)
                }

                TextEditor(
                    text: Binding(
                        get: { draft.content },
                        set: updateSnippetDraftContent
                    )
                )
                .font(draft.kind == .code ? theme.typography.monoMeta : theme.typography.rowPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180, maxHeight: 220, alignment: .topLeading)
                .padding(theme.spacing.control10)
                .background(theme.palette.raised)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous)
                        .stroke(theme.palette.border, lineWidth: theme.border.hairline)
                )
                .disabled(editorState.availability.isInteractive == false)
            }

            SBPaneSection(
                title: "Shortcut",
                descriptionText: "Keep shortcut assignment inline with the draft so conflict feedback stays in the same editor surface.",
                theme: theme
            ) {
                SBShortcutAssignmentRow(
                    title: "Snippet shortcut",
                    detailText: editorShortcutDetailText,
                    shortcutLabel: draft.hotkey?.displayLabel ?? "No hotkey",
                    theme: theme,
                    state: editorShortcutVisualState,
                    helperText: snippetEditorHelperText,
                    showsClearAction: editorState.availability == .enabled,
                    onRecord: handleSnippetEditorShortcutRecord,
                    onClear: clearSnippetDraftHotkey
                )
            }

            if let editorCallout = snippetEditorCallout {
                SBSettingsConflictCallout(
                    title: editorCallout.title,
                    detailText: editorCallout.detailText,
                    theme: theme,
                    tone: editorCallout.tone
                )
            }

            HStack(spacing: theme.spacing.control8) {
                SBControlPillButton(
                    title: "Save",
                    theme: theme,
                    tone: .primary,
                    isEnabled: editorState.canSave,
                    action: saveSnippetDraft
                )

                SBControlPillButton(
                    title: "Cancel",
                    theme: theme,
                    tone: .neutral,
                    isEnabled: editorState.availability.isInteractive,
                    action: cancelSnippetEditing
                )

                Spacer(minLength: theme.spacing.control12)

                Picker(
                    "Kind",
                    selection: Binding(
                        get: { draft.kind },
                        set: updateSnippetDraftKind
                    )
                ) {
                    Text("Text").tag(SnippetContentKind.plainText)
                    Text("Code").tag(SnippetContentKind.code)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .disabled(editorState.availability.isInteractive == false)

                SBControlPillButton(
                    title: "Delete",
                    theme: theme,
                    tone: .danger,
                    isEnabled: editorState.canDelete,
                    action: deleteSelectedSnippet
                )
            }
        }
    }

    private var snippetsStateForView: SnippetsSettingsState {
        SnippetsSettingsState(
            libraryEntries: snippetRecords.map { snippet in
                SnippetLibraryEntry(
                    snippetID: snippet.id,
                    title: snippet.title,
                    subtitle: snippet.hotkey?.displayLabel ?? "No hotkey",
                    hotkeyLabel: snippet.hotkey?.displayLabel ?? "No hotkey",
                    kind: snippet.kind,
                    isPinned: snippet.isPinned,
                    isSelected: snippet.id == snippetEditorState.selectedSnippetID
                )
            },
            editorState: snippetEditorStateForCurrentLockState,
            canCreateSnippet: securitySnapshot.lockState.revealsProtectedContent,
            emptyStateTitle: snippetRecords.isEmpty ? "No snippets yet" : nil,
            emptyStateDetailText: snippetRecords.isEmpty ? "Create your first snippet to populate the library and the hotkeys pane." : nil
        )
    }

    private var hotkeysStateForView: HotkeysSettingsState {
        HotkeysSettingsState(
            globalBindings: globalBindingsForView,
            snippetBindings: snippetBindingsForView,
            recorderSession: recorderSessionForCurrentLockState,
            inlineMessage: hotkeysInlineMessageForCurrentLockState
        )
    }

    private var globalBindingsForView: [HotkeyBindingSummary] {
        globalHotkeyBindings.map { binding in
            HotkeyBindingSummary(
                target: .globalCommand(binding.commandID),
                title: binding.commandID.displayTitle,
                detailText: detailText(for: binding),
                hotkey: binding.hotkey,
                availability: effectiveAvailability(for: binding.availability),
                isPopupScoped: binding.commandID == .pasteAs,
                latestConflict: recorderConflict(for: .globalCommand(binding.commandID))
            )
        }
    }

    private var snippetBindingsForView: [HotkeyBindingSummary] {
        snippetRecords.map { snippet in
            HotkeyBindingSummary(
                target: .snippet(snippet.id),
                title: snippet.title,
                detailText: effectiveAvailability(for: .enabled) == .lockedDisabled
                    ? "Snippet paste is disabled while locked."
                    : (snippet.hotkey == nil ? "No hotkey assigned yet." : "Paste this saved snippet directly."),
                hotkey: snippet.hotkey,
                availability: effectiveAvailability(for: .enabled),
                latestConflict: recorderConflict(for: .snippet(snippet.id))
            )
        }
    }

    private var snippetEditorStateForCurrentLockState: SnippetEditorState {
        var state = snippetEditorState
        state.availability = effectiveAvailability(for: .enabled)
        return state
    }

    private var recorderSessionForCurrentLockState: HotkeyRecorderSessionState {
        guard securitySnapshot.lockState.revealsProtectedContent else {
            return HotkeyRecorderSessionState(
                target: recorderSession.target,
                phase: .disabled,
                previouslyAssignedHotkey: recorderSession.previouslyAssignedHotkey,
                candidateHotkey: recorderSession.candidateHotkey,
                conflictResult: recorderSession.conflictResult,
                availability: .lockedDisabled
            )
        }

        return recorderSession
    }

    private var hotkeysInlineMessageForCurrentLockState: String {
        securitySnapshot.lockState.revealsProtectedContent
            ? (hotkeysInlineMessage ?? "Conflicts are validated when a shortcut is assigned, not when it fires.")
            : "Unlock SlipTray to edit snippet or popup shortcuts."
    }

    private var editorShortcutVisualState: SBShortcutAssignmentVisualState {
        let target = HotkeyBindingTarget.snippet(snippetEditorState.selectedSnippetID ?? draftSnippetID)

        if snippetEditorStateForCurrentLockState.availability == .lockedDisabled {
            return .disabledUnavailable
        }
        if recorderSession.target == target {
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
        return snippetEditorState.draft.hotkey == nil ? .idleUnassigned : .idleAssigned
    }

    private var snippetEditorHelperText: String? {
        if let conflict = currentEditorConflict {
            return conflict.message
        }
        let target = HotkeyBindingTarget.snippet(snippetEditorState.selectedSnippetID ?? draftSnippetID)
        if recorderSession.target == target, recorderSession.phase == .recording {
            return "Recording is mocked in this UI slice. Press the action again to assign the next suggested shortcut."
        }
        return editorShortcutDetailText
    }

    private var editorShortcutDetailText: String {
        securitySnapshot.lockState.revealsProtectedContent
            ? "Optional per-snippet hotkeys reuse the same conflict rules as the Hotkeys pane."
            : "Unlock SlipTray to assign or clear snippet shortcuts."
    }

    private var snippetEditorCallout: (title: String, detailText: String, tone: SBInlineCalloutTone)? {
        switch snippetEditorState.validationState {
        case .missingTitle:
            return ("Title required", "Give the snippet a short title before saving.", .warning)
        case .missingContent:
            return ("Content required", "Add content before saving the snippet draft.", .warning)
        case let .hotkeyConflict(conflict):
            return ("Shortcut conflict", conflict.message, .warning)
        case .valid:
            if snippetEditorState.availability == .lockedDisabled {
                return ("Editing disabled", "Locked state keeps the editor visible but disables save, delete, and shortcut edits in-pane.", .info)
            }
            return nil
        }
    }

    private var currentEditorConflict: HotkeyConflictResult? {
        if case let .hotkeyConflict(conflict) = snippetEditorState.validationState {
            return conflict
        }

        let target = HotkeyBindingTarget.snippet(snippetEditorState.selectedSnippetID ?? draftSnippetID)
        if recorderSession.target == target, recorderSession.phase == .conflict {
            return recorderSession.conflictResult
        }
        return nil
    }

    private func shortcutVisualState(
        for target: HotkeyBindingTarget,
        availability: HotkeyRuntimeAvailability,
        hasAssignedShortcut: Bool
    ) -> SBShortcutAssignmentVisualState {
        if availability.isInteractive == false {
            return .disabledUnavailable
        }
        if recorderSession.target == target {
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
        return hasAssignedShortcut ? .idleAssigned : .idleUnassigned
    }

    private func shortcutLabel(for binding: HotkeyBindingSummary) -> String {
        if recorderSession.target == binding.target,
           recorderSession.phase == .recording,
           let candidate = recorderSession.candidateHotkey {
            return candidate.displayLabel
        }
        return binding.hotkey?.displayLabel ?? "No hotkey"
    }

    private func helperText(for binding: HotkeyBindingSummary) -> String? {
        if recorderSession.target == binding.target {
            switch recorderSession.phase {
            case .recording:
                return "Recording is mocked in this UI slice. Press the action again to apply the suggested shortcut."
            case .conflict:
                return recorderSession.conflictResult?.message ?? binding.detailText
            case .disabled:
                return "Unlock SlipTray to edit this shortcut."
            case .idle, .saved:
                break
            }
        }
        return binding.latestConflict?.message ?? binding.detailText
    }

    private func recorderConflict(for target: HotkeyBindingTarget) -> HotkeyConflictResult? {
        recorderSession.target == target && recorderSession.phase == .conflict ? recorderSession.conflictResult : nil
    }

    private func detailText(for binding: GlobalHotkeyBinding) -> String {
        switch binding.commandID {
        case .openSlipTray:
            return securitySnapshot.lockState.revealsProtectedContent
                ? "Open the popup shell from anywhere."
                : "Disabled while SlipTray is locked."
        case .pasteAs:
            return "Popup-scoped only in this slice."
        case .pauseCapturing:
            return "Reserved until exclusions and pause controls are implemented."
        }
    }

    private func effectiveAvailability(for base: HotkeyRuntimeAvailability) -> HotkeyRuntimeAvailability {
        guard securitySnapshot.lockState.revealsProtectedContent == false else {
            return base
        }
        switch base {
        case .enabled:
            return .lockedDisabled
        case .lockedDisabled, .futureCommandUnavailable, .registrationUnavailable:
            return base
        }
    }

    private func startNewSnippetDraft() {
        guard securitySnapshot.lockState.revealsProtectedContent else { return }
        recorderSession = HotkeyRecorderSessionState()
        snippetEditorState = SnippetEditorState(
            mode: .newDraft,
            savedRecord: nil,
            draft: SnippetEditorDraft(),
            validationState: .missingTitle,
            availability: .enabled
        )
    }

    private func selectSnippet(_ snippetID: SnippetID) {
        guard let record = snippetRecords.first(where: { $0.id == snippetID }) else { return }
        recorderSession = HotkeyRecorderSessionState()
        snippetEditorState = SnippetEditorState(
            mode: .editing(snippetID),
            savedRecord: record,
            draft: SnippetEditorDraft(
                title: record.title,
                content: record.content,
                kind: record.kind,
                hotkey: record.hotkey,
                isPinned: record.isPinned
            ),
            validationState: .valid,
            availability: .enabled
        )
    }

    private func updateSnippetDraftTitle(_ title: String) {
        snippetEditorState.draft.title = title
        refreshSnippetDraftValidation()
    }

    private func updateSnippetDraftContent(_ content: String) {
        snippetEditorState.draft.content = content
        refreshSnippetDraftValidation()
    }

    private func updateSnippetDraftKind(_ kind: SnippetContentKind) {
        snippetEditorState.draft.kind = kind
        refreshSnippetDraftValidation()
    }

    private func updateSnippetDraftPinned(_ isPinned: Bool) {
        snippetEditorState.draft.isPinned = isPinned
        refreshSnippetDraftValidation()
    }

    private func handleSnippetEditorShortcutRecord() {
        guard snippetEditorState.availability == .enabled else { return }

        let target = HotkeyBindingTarget.snippet(snippetEditorState.selectedSnippetID ?? draftSnippetID)
        if recorderSession.target == target, recorderSession.phase == .recording {
            let candidate = nextSuggestedHotkey(for: target)
            recorderSession.candidateHotkey = candidate
            applyDraftHotkeyCandidate(candidate, target: target)
            return
        }

        recorderSession = HotkeyRecorderSessionState(
            target: target,
            phase: .recording,
            previouslyAssignedHotkey: snippetEditorState.draft.hotkey,
            candidateHotkey: snippetEditorState.draft.hotkey,
            conflictResult: nil,
            availability: .enabled
        )
    }

    private func applyDraftHotkeyCandidate(_ descriptor: HotkeyDescriptor, target: HotkeyBindingTarget) {
        if let conflict = conflictResult(for: target, descriptor: descriptor, ignoring: snippetEditorState.savedRecord?.id) {
            recorderSession.phase = .conflict
            recorderSession.conflictResult = conflict
            snippetEditorState.validationState = .hotkeyConflict(conflict)
            hotkeysInlineMessage = conflict.message
            return
        }

        recorderSession.phase = .saved
        recorderSession.conflictResult = nil
        snippetEditorState.draft.hotkey = descriptor
        hotkeysInlineMessage = "Shortcut saved to the draft. Use Save to persist the snippet change."
        refreshSnippetDraftValidation()
    }

    private func clearSnippetDraftHotkey() {
        guard snippetEditorState.availability == .enabled else { return }
        recorderSession = HotkeyRecorderSessionState()
        snippetEditorState.draft.hotkey = nil
        refreshSnippetDraftValidation()
    }

    private func saveSnippetDraft() {
        guard snippetEditorState.availability == .enabled else { return }
        refreshSnippetDraftValidation()
        guard snippetEditorState.validationState.isValid else { return }

        let trimmedTitle = snippetEditorState.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = snippetEditorState.draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()

        let record = SnippetRecord(
            id: snippetEditorState.savedRecord?.id ?? draftSnippetID,
            title: trimmedTitle,
            content: trimmedContent,
            kind: snippetEditorState.draft.kind,
            hotkey: snippetEditorState.draft.hotkey,
            createdAt: snippetEditorState.savedRecord?.createdAt ?? now,
            updatedAt: now,
            isPinned: snippetEditorState.draft.isPinned
        )

        if let existingIndex = snippetRecords.firstIndex(where: { $0.id == record.id }) {
            snippetRecords[existingIndex] = record
        } else {
            snippetRecords.insert(record, at: 0)
        }

        recorderSession = HotkeyRecorderSessionState()
        snippetEditorState = SnippetEditorState(
            mode: .editing(record.id),
            savedRecord: record,
            draft: SnippetEditorDraft(
                title: record.title,
                content: record.content,
                kind: record.kind,
                hotkey: record.hotkey,
                isPinned: record.isPinned
            ),
            validationState: .valid,
            availability: .enabled
        )
        hotkeysInlineMessage = "Snippet saved. Hotkey rows stay in sync with the library."
    }

    private func cancelSnippetEditing() {
        recorderSession = HotkeyRecorderSessionState()

        if let savedRecord = snippetEditorState.savedRecord {
            selectSnippet(savedRecord.id)
        } else if let firstRecord = snippetRecords.first {
            selectSnippet(firstRecord.id)
        } else {
            snippetEditorState = SnippetEditorState()
        }
    }

    private func deleteSelectedSnippet() {
        guard snippetEditorState.canDelete, let savedRecord = snippetEditorState.savedRecord else { return }
        snippetRecords.removeAll { $0.id == savedRecord.id }
        recorderSession = HotkeyRecorderSessionState()
        hotkeysInlineMessage = "Snippet deleted. Any assigned shortcut is removed with it."

        if let nextRecord = snippetRecords.first {
            selectSnippet(nextRecord.id)
        } else {
            snippetEditorState = SnippetEditorState()
        }
    }

    private func handleHotkeyRowRecord(for target: HotkeyBindingTarget) {
        guard availability(for: target) == .enabled else { return }

        if recorderSession.target == target, recorderSession.phase == .recording {
            let candidate = nextSuggestedHotkey(for: target)
            recorderSession.candidateHotkey = candidate
            applySavedHotkeyCandidate(candidate, target: target)
            return
        }

        recorderSession = HotkeyRecorderSessionState(
            target: target,
            phase: .recording,
            previouslyAssignedHotkey: currentHotkey(for: target),
            candidateHotkey: currentHotkey(for: target),
            conflictResult: nil,
            availability: .enabled
        )
    }

    private func applySavedHotkeyCandidate(_ descriptor: HotkeyDescriptor, target: HotkeyBindingTarget) {
        if let conflict = conflictResult(for: target, descriptor: descriptor, ignoring: savedSnippetID(for: target)) {
            recorderSession.phase = .conflict
            recorderSession.conflictResult = conflict
            hotkeysInlineMessage = conflict.message
            return
        }

        switch target {
        case let .globalCommand(commandID):
            guard let index = globalHotkeyBindings.firstIndex(where: { $0.commandID == commandID }) else { return }
            globalHotkeyBindings[index].hotkey = descriptor
        case let .snippet(snippetID):
            guard let index = snippetRecords.firstIndex(where: { $0.id == snippetID }) else { return }
            snippetRecords[index].hotkey = descriptor
            if snippetEditorState.selectedSnippetID == snippetID {
                snippetEditorState.savedRecord = snippetRecords[index]
                snippetEditorState.draft.hotkey = descriptor
            }
        case .reservedFutureCommand:
            return
        }

        recorderSession.phase = .saved
        recorderSession.conflictResult = nil
        hotkeysInlineMessage = "Shortcut saved. Conflict checks happen at assignment time."
    }

    private func clearSavedBinding(for target: HotkeyBindingTarget) {
        guard availability(for: target) == .enabled else { return }

        switch target {
        case let .globalCommand(commandID):
            guard let index = globalHotkeyBindings.firstIndex(where: { $0.commandID == commandID }) else { return }
            globalHotkeyBindings[index].hotkey = nil
        case let .snippet(snippetID):
            guard let index = snippetRecords.firstIndex(where: { $0.id == snippetID }) else { return }
            snippetRecords[index].hotkey = nil
            if snippetEditorState.selectedSnippetID == snippetID {
                snippetEditorState.savedRecord = snippetRecords[index]
                snippetEditorState.draft.hotkey = nil
            }
        case .reservedFutureCommand:
            return
        }

        recorderSession = HotkeyRecorderSessionState()
        hotkeysInlineMessage = "Shortcut cleared."
        refreshSnippetDraftValidation()
    }

    private func refreshSnippetDraftValidation() {
        let title = snippetEditorState.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = snippetEditorState.draft.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            snippetEditorState.validationState = .missingTitle
            return
        }
        if content.isEmpty {
            snippetEditorState.validationState = .missingContent
            return
        }
        if let hotkey = snippetEditorState.draft.hotkey,
           let conflict = conflictResult(
            for: .snippet(snippetEditorState.selectedSnippetID ?? draftSnippetID),
            descriptor: hotkey,
            ignoring: snippetEditorState.savedRecord?.id
           ) {
            snippetEditorState.validationState = .hotkeyConflict(conflict)
            return
        }

        snippetEditorState.validationState = .valid
    }

    private func conflictResult(
        for target: HotkeyBindingTarget,
        descriptor: HotkeyDescriptor,
        ignoring ignoredSnippetID: SnippetID?
    ) -> HotkeyConflictResult? {
        for binding in globalHotkeyBindings {
            let candidateTarget = HotkeyBindingTarget.globalCommand(binding.commandID)
            if candidateTarget != target,
               binding.hotkey?.normalizedIdentity == descriptor.normalizedIdentity {
                return HotkeyConflictResult(
                    target: target,
                    candidate: descriptor,
                    conflictingTarget: candidateTarget,
                    kind: .duplicateGlobal,
                    message: "This shortcut is already assigned to \(binding.commandID.displayTitle)."
                )
            }
        }

        for snippet in snippetRecords where snippet.id != ignoredSnippetID {
            if target != .snippet(snippet.id),
               snippet.hotkey?.normalizedIdentity == descriptor.normalizedIdentity {
                return HotkeyConflictResult(
                    target: target,
                    candidate: descriptor,
                    conflictingTarget: .snippet(snippet.id),
                    kind: .duplicateSnippet,
                    message: "This shortcut is already assigned to \(snippet.title)."
                )
            }
        }

        return nil
    }

    private func nextSuggestedHotkey(for target: HotkeyBindingTarget) -> HotkeyDescriptor {
        let suggestions: [HotkeyDescriptor] = [
            HotkeyDescriptor(keyCode: 18, keyEquivalent: "1", modifiers: [.control, .option]),
            HotkeyDescriptor(keyCode: 19, keyEquivalent: "2", modifiers: [.control, .option]),
            HotkeyDescriptor(keyCode: 20, keyEquivalent: "3", modifiers: [.control, .option]),
            HotkeyDescriptor(keyCode: 21, keyEquivalent: "4", modifiers: [.control, .option]),
            HotkeyDescriptor(keyCode: 22, keyEquivalent: "6", modifiers: [.command, .shift])
        ]

        recorderSeed += 1

        if case .globalCommand(.openSlipTray) = target, recorderSeed % 3 == 0 {
            return SnippetsHotkeysMockFixtures.openPopupHotkey
        }

        return suggestions[recorderSeed % suggestions.count]
    }

    private func availability(for target: HotkeyBindingTarget) -> HotkeyRuntimeAvailability {
        switch target {
        case let .globalCommand(commandID):
            return effectiveAvailability(for: globalHotkeyBindings.first(where: { $0.commandID == commandID })?.availability ?? .enabled)
        case .snippet:
            return effectiveAvailability(for: .enabled)
        case .reservedFutureCommand:
            return .futureCommandUnavailable
        }
    }

    private func currentHotkey(for target: HotkeyBindingTarget) -> HotkeyDescriptor? {
        switch target {
        case let .globalCommand(commandID):
            return globalHotkeyBindings.first(where: { $0.commandID == commandID })?.hotkey
        case let .snippet(snippetID):
            return snippetRecords.first(where: { $0.id == snippetID })?.hotkey
        case .reservedFutureCommand:
            return nil
        }
    }

    private func savedSnippetID(for target: HotkeyBindingTarget) -> SnippetID? {
        if case let .snippet(snippetID) = target {
            return snippetID
        }
        return nil
    }

    private var draftSnippetID: SnippetID {
        SnippetID(rawValue: "draft-\(recorderSeed)")
    }

    private func editorTitle(for state: SnippetEditorState) -> String {
        switch state.mode {
        case .newDraft:
            return "New Snippet"
        case .editing:
            return state.savedRecord?.title ?? "Snippet"
        case .deleteConfirmation:
            return "Delete Snippet"
        case .noSelection:
            return "Snippet Detail"
        }
    }

    private func editorSubtitle(for state: SnippetEditorState) -> String {
        switch state.mode {
        case .newDraft:
            return "Draft a local snippet and optionally assign a dedicated hotkey."
        case .editing:
            return state.isDirty ? "Unsaved changes stay inline until you save or cancel." : "Saved snippet details stay editable in place."
        case .deleteConfirmation:
            return "Confirm destructive changes inline."
        case .noSelection:
            return "Select a snippet from the library."
        }
    }

    private func securityLabel(for method: SecurityUnlockMethod) -> String {
        switch method {
        case .biometricPreferred:
            return "Touch ID / Face ID"
        case .systemPassword:
            return "System Password"
        }
    }

    private func securityLabel(for interval: SecurityAutoLockInterval) -> String {
        switch interval {
        case .never:
            return "Never"
        case .oneMinute:
            return "1 min"
        case .fiveMinutes:
            return "5 min"
        case .fifteenMinutes:
            return "15 min"
        case .oneHour:
            return "1 hour"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            runtime: ClipboardHistoryAppRuntime(),
            isPopupPresented: false,
            onTogglePopupPresentation: { _ in },
            onShowSettings: {}
        )
        .frame(width: 1120, height: 780)
    }
}
