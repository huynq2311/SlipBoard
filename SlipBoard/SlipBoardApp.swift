import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class ClipboardHistoryAppRuntime: ObservableObject {
    let localization: LocalizationStore
    @Published private(set) var appLanguage: AppLanguage
    @Published private(set) var popupState: PopupShellViewState
    @Published private(set) var filterOptions: [PopupFilterOption]
    @Published private(set) var menuBarSummary: MenuBarSummaryState
    @Published private(set) var isMonitoring: Bool
    @Published private(set) var pasteOverlayState: PasteActionOverlayState
    @Published private(set) var supportedTransformActionIDs: Set<PasteActionID>
    @Published private(set) var retentionSnapshot: RetentionRuntimeSnapshot
    @Published private(set) var searchNotesState: SearchNotesProjectionState
    @Published private(set) var settingsState: SettingsShellState
    @Published private(set) var securitySnapshot: SecurityRuntimeSnapshot
    @Published private(set) var qaLockState: SearchLockState
    @Published private(set) var isPopupPresented: Bool
    @Published private(set) var snippetsHotkeysSnapshot: SnippetsHotkeysRuntimeSnapshot
    @Published private(set) var exclusionsPauseSnapshot: ExclusionsPauseSnapshot
    @Published private(set) var bridgeSnapshot: BridgeRuntimeSnapshot
    @Published private(set) var isLaunchAtLoginEnabled: Bool
    @Published private(set) var searchFocusRequestToken: Int = 0
    /// Bumped each time the popup reopens from a closed state. The rails read
    /// it to reset their scroll offset.
    @Published private(set) var popupPresentationID: Int = 0
    // nil = no manual override yet, follow whether pinned has any clips.
    @Published private(set) var manualPinnedCollapsed: Bool? = nil
    @Published var organizationDraftName: String

    private let controller: ClipboardHistoryController
    private let bridgeRuntime: CloudBridgeRuntimeController
    private let securityRuntime: SecurityRuntimeController
    private let shellCoordinator: FoundationShellCoordinator
    private let snippetsHotkeysRuntime: SnippetsHotkeysRuntimeController
    private var baseMenuBarSummary: MenuBarSummaryState
    private var themePreview: PopupThemeSelection
    private var isSearchPresented: Bool
    private var runtimeStatusOverride: RuntimeStatusOverride?
    private var localizationCancellable: AnyCancellable?

    init(
        controller: ClipboardHistoryController? = nil,
        securityRuntime: SecurityRuntimeController? = nil,
        bridgeRuntime: CloudBridgeRuntimeController? = nil,
        shellCoordinator: FoundationShellCoordinator? = nil
    ) {
        let resolvedLocalization = LocalizationStore()
        let components = Self.resolveRuntimeComponents(
            controller: controller,
            securityRuntime: securityRuntime,
            bridgeRuntime: bridgeRuntime
        )
        let resolvedController = components.controller
        let resolvedShellCoordinator = shellCoordinator ?? FoundationShellCoordinator()
        let resolvedSnippetsHotkeysRuntime = SnippetsHotkeysRuntimeController(
            router: resolvedShellCoordinator,
            securityStateProvider: components.securityRuntime
        )

        self.localization = resolvedLocalization
        self.appLanguage = resolvedLocalization.language
        self.controller = resolvedController
        self.bridgeRuntime = components.bridgeRuntime
        self.securityRuntime = components.securityRuntime
        self.shellCoordinator = resolvedShellCoordinator
        self.snippetsHotkeysRuntime = resolvedSnippetsHotkeysRuntime
        self.securitySnapshot = components.securityRuntime.latestSnapshot
        self.qaLockState = components.securityRuntime.currentLockState
        self.isPopupPresented = resolvedShellCoordinator.isPopupPresented
        self.snippetsHotkeysSnapshot = resolvedSnippetsHotkeysRuntime.latestSnapshot
        self.exclusionsPauseSnapshot = resolvedController.latestExclusionsPauseSnapshot
        self.retentionSnapshot = resolvedController.retentionSnapshot
        self.searchNotesState = resolvedController.searchNotesRuntime.latestProjectionState
        self.bridgeSnapshot = components.bridgeRuntime.latestSnapshot
        let resolvedLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        self.isLaunchAtLoginEnabled = resolvedLaunchAtLoginEnabled
        self.organizationDraftName = ""
        self.settingsState = Self.makeSettingsState(
            retentionSnapshot: resolvedController.retentionSnapshot,
            searchProjection: resolvedController.searchNotesRuntime.latestProjectionState,
            groups: resolvedController.searchNotesRuntime.latestGroups,
            securitySnapshot: components.securityRuntime.latestSnapshot,
            snippetsSnapshot: resolvedSnippetsHotkeysRuntime.latestSnapshot,
            exclusionsPauseSnapshot: resolvedController.latestExclusionsPauseSnapshot,
            bridgeSnapshot: components.bridgeRuntime.latestSnapshot,
            isLaunchAtLoginEnabled: resolvedLaunchAtLoginEnabled,
            selectedSection: SettingsSectionID.general
        )

        let projection = resolvedController.projection
        self.themePreview = Self.loadThemeSelection()
        self.isSearchPresented = projection.popupState.isSearchPresented

        var popupState = projection.popupState
        popupState.themePreview = themePreview
        popupState.isSearchPresented = isSearchPresented

        self.popupState = popupState
        self.filterOptions = projection.filterOptions
        self.baseMenuBarSummary = projection.menuBarSummary
        self.menuBarSummary = projection.menuBarSummary
        self.isMonitoring = resolvedController.isMonitoring
        self.pasteOverlayState = resolvedController.pasteActions.overlayState
        self.supportedTransformActionIDs = Self.supportedTransformActionIDs(
            for: resolvedController.pasteActions.selectedSourceItem
        )

        resolvedController.onProjectionDidChange = { [weak self] projection in
            DispatchQueue.main.async {
                self?.apply(projection)
            }
        }
        resolvedController.onRetentionSnapshotDidChange = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.apply(retentionSnapshot: snapshot)
            }
        }
        resolvedController.onRetentionCleanupDidRun = { [weak self] result in
            DispatchQueue.main.async {
                self?.apply(cleanupResult: result)
            }
        }
        resolvedSnippetsHotkeysRuntime.onSnapshotChange = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.apply(snippetsSnapshot: snapshot)
            }
        }
        components.bridgeRuntime.onSnapshotChange = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.apply(bridgeSnapshot: snapshot)
            }
        }
        components.securityRuntime.onSnapshotChange = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.apply(securitySnapshot: snapshot)
            }
        }
        localizationCancellable = resolvedLocalization.languagePublisher
            .dropFirst()
            .sink { [weak self] language in
                self?.appLanguage = language
            }

        components.bridgeRuntime.bootstrap()
        components.securityRuntime.bootstrap()
        apply(securitySnapshot: components.securityRuntime.latestSnapshot)
    }

    var popupTheme: SBTheme {
        SBThemeRegistry.definition(for: themePreview.themeID).theme(for: popupThemeMode)
    }

    private var popupThemeMode: SBThemeMode {
        switch themePreview.appearance {
        case .dark:
            return .dark
        case .light:
            return .light
        case .system:
            return NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
        }
    }

    var settingsTheme: SBTheme {
        SBThemeRegistry.definition(for: PopupThemeSelection.defaultThemeID).theme(for: popupTheme.mode)
    }

    func setAppLanguage(_ language: AppLanguage) {
        localization.setLanguage(language)
    }

    var shouldSuppressPopupPresentation: Bool {
        switch exclusionsPauseSnapshot.popupPolicyDecision {
        case .allow:
            return false
        case .suppressBecauseExcludedApp:
            return true
        }
    }

    var totalCountText: String {
        localization.plural(.historyItemCount, count: menuBarSummary.itemCount)
    }

    var localizedFilterOptions: [PopupFilterOption] {
        filterOptions.map { option in
            var localized = option
            switch option.id {
            case "all": localized.label = localization.text(.commonAll)
            case "text": localized.label = localization.text(.contentText)
            case "code": localized.label = localization.text(.contentCode)
            case "image": localized.label = localization.text(.contentImage)
            case "file": localized.label = localization.text(.contentFile)
            case "url": localized.label = localization.text(.contentURL)
            case "color": localized.label = localization.text(.contentColor)
            case "richText", "rich-text": localized.label = localization.text(.contentRichText)
            default: break
            }
            return localized
        }
    }

    var localizedPopupState: PopupShellViewState {
        var localized = popupState
        var status = localized.status
        let visibleCount = searchNotesState.searchResultCount
        let hasSearchContext = searchNotesState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || searchNotesState.activeGroupID != .all

        if securitySnapshot.lockState.revealsProtectedContent == false {
            status.statusLabel = localization.text(.popupSearchLockedTitle)
            status.primaryHint = localization.text(.popupSearchLockedTitle)
            status.secondaryHint = localization.text(.popupSearchLockedDetail)
            status.itemCountText = localization.text(.popupVisibleCount, ["count": localization.format(number: visibleCount)])
        } else {
            switch status.statusTone {
            case .success:
                status.statusLabel = localization.text(.statusCaptureActive)
                status.primaryHint = localization.text(.popupReturnToPaste)
                status.secondaryHint = localization.text(.popupCommandSearch)
            case .normal:
                status.statusLabel = localization.text(.statusWaitingForCopy)
                status.primaryHint = localization.text(.popupCopyToBegin)
                status.secondaryHint = localization.text(.popupCommandSearch)
            case .warning:
                status.statusLabel = localization.text(.statusUnsupportedIgnored)
                status.secondaryHint = localization.text(.popupSupportedTypes)
            case .paused:
                status.statusLabel = localization.text(.statusCapturePaused)
                status.secondaryHint = localization.text(.popupResumeMonitoring)
            case .locked:
                status.statusLabel = localization.text(.popupSearchLockedTitle)
                status.primaryHint = localization.text(.popupSearchLockedTitle)
                status.secondaryHint = localization.text(.popupSearchLockedDetail)
            }

            status.itemCountText = hasSearchContext
                ? localization.text(.popupResultCount, ["count": localization.format(number: visibleCount)])
                : localization.plural(.historyItemCount, count: menuBarSummary.itemCount)
        }

        localized.status = status
        return localized
    }

    var localizedMenuBarSummary: MenuBarSummaryState {
        var localized = menuBarSummary
        localized.itemCountLabel = localization.text(.historyItemCount)
        localized.statusLabel = localizedPopupState.status.statusLabel
        localized.commands = menuBarSummary.commands.map { command in
            var command = command
            switch command.id {
            case "open-slipboard":
                command.title = securitySnapshot.lockState.revealsProtectedContent
                    ? localization.text(.menuOpenSlipBoard)
                    : localization.text(.menuShowLockedPopup)
                if securitySnapshot.lockState.revealsProtectedContent == false {
                    command.subtitle = localization.text(.menuShowLockedPopupDetail)
                }
            case "capture-status":
                command.title = localization.text(.menuCaptureStatus)
                command.subtitle = localizedPopupState.status.statusLabel
                if menuBarSummary.itemCount == 0 {
                    command.accessoryText = localization.text(.menuCaptureStatusEmpty)
                }
            case "pause-capturing":
                command.title = exclusionsPauseSnapshot.pauseState.isPaused
                    ? localization.text(.menuResumeCapture)
                    : localization.text(.menuPauseCapture)
                command.subtitle = exclusionsPauseSnapshot.pauseState.isPaused
                    ? localization.text(.menuPausedUntilResume)
                    : localization.text(.menuPauseOptions)
            case "open-settings":
                command.title = localization.text(.menuSettings)
            case "security-settings":
                command.title = localization.text(.menuOpenSecuritySettings)
                command.subtitle = localization.text(.menuSecuritySettingsDetail)
            case "lock-slipboard":
                command.title = localization.text(.securityLockSlipBoard)
                command.subtitle = localization.text(.securityLockDetailManual)
            case "unlock-slipboard":
                command.title = localization.text(.securityUnlock)
            case "quit-slipboard":
                command.title = localization.text(.menuQuit)
            default:
                break
            }
            return command
        }
        return localized
    }

    var retentionTTLText: String {
        retentionSnapshot.retentionSettings.ttlPolicy.settingsLabel
    }

    var retentionMaxItemCountText: String {
        "\(Self.formattedInteger(retentionSnapshot.retentionSettings.maxItemCount)) items"
    }

    var retentionCacheUsageText: String {
        let usage = ByteCountFormatter.string(
            fromByteCount: retentionSnapshot.assetCacheSettings.currentUsageBytes,
            countStyle: .file
        )
        return "\(usage) / \(retentionSnapshot.assetCacheSettings.maxCacheSizeMB) MB"
    }

    var retentionLatestCleanupText: String {
        retentionSnapshot.latestCleanupResult?.statusMessage ?? "Idle"
    }

    var isSearchLockedForQA: Bool {
        securitySnapshot.lockState.revealsProtectedContent == false
    }

    var organizationGroups: [OrganizationGroupSummary] {
        controller.searchNotesRuntime.latestGroups
    }

    var selectedOrganizationGroupID: OrganizationGroupID {
        searchNotesState.activeGroupID
    }

    var selectedClipIDForOrganization: String? {
        popupState.selectedClipID ?? popupState.allClips.first?.id
    }

    var canRenameSelectedOrganizationGroup: Bool {
        switch searchNotesState.activeGroupID {
        case .custom:
            return organizationDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .all, .ungrouped:
            return false
        }
    }

    var canDeleteSelectedOrganizationGroup: Bool {
        switch searchNotesState.activeGroupID {
        case .custom:
            return true
        case .all, .ungrouped:
            return false
        }
    }

    func startMonitoring() {
        controller.startMonitoring()
        isMonitoring = controller.isMonitoring
    }

    func stopMonitoring() {
        controller.stopMonitoring()
        isMonitoring = controller.isMonitoring
    }

    func refreshNow() {
        recordSecurityInteraction()
        controller.refreshNow()
        bridgeRuntime.refreshSnapshot()
    }

    func handleAppDidBecomeActive() {
        recordSecurityInteraction()
        controller.refreshRetentionCacheUsage()
        _ = controller.handleRetentionLifecycleTrigger(.appBecameActive)
        bridgeRuntime.refreshSnapshot()
    }

    func prepareForAppQuit() {
        if securitySnapshot.settings.isAppLockEnabled {
            securityRuntime.lock(reason: .manual)
        }
        snippetsHotkeysRuntime.refreshRuntimeAvailability(.lockedDisabled)
        _ = controller.prepareForAppQuit()
        stopMonitoring()
    }

    func focusSettings(on section: SettingsSectionID = .general) {
        recordSecurityInteraction()
        shellCoordinator.selectSettingsSection(section)
        settingsState.selectedSection = section
        settingsState = shellCoordinator.settingsShellState
    }

    func selectQuickRetention(_ optionID: String) {
        recordSecurityInteraction()
        guard let policy = RetentionTTLPolicy(rawValue: optionID) else { return }
        controller.updateRetentionTTL(policy)
        focusSettings(on: .retention)
    }

    func handleSettingsChoice(id: String, optionID: String) {
        recordSecurityInteraction()

        if id == "app-language", let language = AppLanguage(rawValue: optionID) {
            setAppLanguage(language)
            return
        }

        switch id {
        case "ttl":
            guard let policy = RetentionTTLPolicy(rawValue: optionID) else { return }
            controller.updateRetentionTTL(policy)
        case "security.unlock-method", "unlock-method":
            guard let method = SecurityUnlockMethod(rawValue: optionID) else { return }
            updateSecuritySettings { settings in
                settings.unlockMethod = method
            }
        case "security.auto-lock", "auto-lock":
            guard let interval = SecurityAutoLockInterval(rawValue: optionID) else { return }
            updateSecuritySettings { settings in
                settings.autoLockInterval = interval
            }
        case "exclusions.pause":
            guard let option = CapturePauseDurationOption(rawValue: optionID) else { return }
            controller.exclusionsPauseRuntime.applyPauseOption(option, startedAt: .now)
            runtimeStatusOverride = RuntimeStatusOverride(
                message: pauseStatusMessage(for: option),
                tone: .paused
            )
            publishCurrentProjection()
        default:
            break
        }
    }

    func handleSettingsToggle(id: String, isOn: Bool) {
        recordSecurityInteraction()

        switch id {
        case "startup.launch-at-login":
            updateLaunchAtLogin(isOn)
        case "clear-on-quit":
            controller.updateRetentionClearOnQuit(isOn)
        case "bump-pasted-item-to-front":
            controller.updateBumpPastedItemToFront(isOn)
        case "enable-bridge":
            bridgeRuntime.updateBridgeEnabled(isOn)
        case "exclusions.hide-popup":
            updateExclusionsBehaviorSettings(hidePopupInsideExcludedApps: isOn)
        case "bridge.publish-on-paste":
            bridgeRuntime.updatePublishOnPasteEnabled(isOn)
        case "bridge.receive":
            bridgeRuntime.updateReceiveEnabled(isOn)
        case "security.app-lock-toggle", "lock-slipboard":
            updateSecuritySettings { settings in
                settings.isAppLockEnabled = isOn
                if isOn == false {
                    settings.privacyMode = .standard
                }
            }
        case "security.hide-previews":
            updateSecuritySettings { settings in
                settings.privacyMode = isOn ? .hidePreviewsInMissionControl : .standard
            }
        default:
            break
        }
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Reflect whatever the OS actually did (e.g. the user changed
            // this from System Settings > Login Items) rather than trusting
            // the requested value.
        }

        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        settingsState = Self.makeSettingsState(
            retentionSnapshot: retentionSnapshot,
            searchProjection: searchNotesState,
            groups: organizationGroups,
            securitySnapshot: securitySnapshot,
            snippetsSnapshot: snippetsHotkeysSnapshot,
            exclusionsPauseSnapshot: exclusionsPauseSnapshot,
            bridgeSnapshot: bridgeSnapshot,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled,
            selectedSection: settingsState.selectedSection
        )
    }

    func handleSettingsSlider(id: String, value: Double) {
        recordSecurityInteraction()
        switch id {
        case "max-items":
            controller.updateRetentionMaxItemCount(Int(value.rounded()))
        case "cache-size":
            controller.updateAssetCacheLimit(Int(value.rounded()))
        default:
            break
        }
    }

    func handleSettingsAction(id: String) {
        recordSecurityInteraction()

        switch id {
        case "clear-cache":
            _ = controller.clearAssetCacheNow()
        case "bridge.stop":
            bridgeRuntime.stopBridge()
        case "exclusions.add-app":
            addExcludedAppFromRuntimeContext()
        case "exclusions.resume-capturing":
            controller.exclusionsPauseRuntime.resumeCapturing(resumedAt: .now)
            runtimeStatusOverride = RuntimeStatusOverride(
                message: localization.text(.statusCaptureResumed),
                tone: .success
            )
            publishCurrentProjection()
        case "security.current-state":
            guard securitySnapshot.settings.isAppLockEnabled else { return }
            if securitySnapshot.lockState.revealsProtectedContent {
                securityRuntime.lock(reason: .manual)
            } else {
                securityRuntime.beginUnlock(using: securitySnapshot.settings.unlockMethod)
            }
        default:
            if id.hasPrefix("exclusions.remove.") {
                let excludedAppID = String(id.dropFirst("exclusions.remove.".count))
                controller.exclusionsPauseRuntime.removeExcludedApp(id: excludedAppID, lastUpdatedAt: .now)
                runtimeStatusOverride = RuntimeStatusOverride(
                    message: localization.text(.statusExcludedAppRemoved),
                    tone: .success
                )
                publishCurrentProjection()
            }
            break
        }
    }

    func setSearchPresented(_ isPresented: Bool) {
        recordSecurityInteraction()
        let didChange = isSearchPresented != isPresented
        isSearchPresented = isPresented

        if isPresented == false, popupState.searchQuery.isEmpty == false {
            controller.updateSearchQuery("")
        } else if didChange {
            // Closing the popup calls this with search already dismissed, and
            // reprojecting the whole history then changes nothing.
            publishCurrentProjection()
        }
    }

    func updateSearchQuery(_ query: String) {
        recordSecurityInteraction()
        isSearchPresented = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || isSearchPresented
        controller.updateSearchQuery(query)
    }

    func appendTypedCharactersToSearch(_ characters: String) {
        guard securitySnapshot.lockState.revealsProtectedContent, searchNotesState.isSearchEnabled else { return }
        updateSearchQuery(popupState.searchQuery + characters)
        searchFocusRequestToken += 1
    }

    func selectFilter(id: String) {
        recordSecurityInteraction()
        guard let filter = ClipboardHistoryFilter(rawValue: id) else { return }
        controller.updateActiveFilter(filter)
    }

    func selectSource(id: String?) {
        recordSecurityInteraction()
        controller.updateActiveSource(id)
    }

    func selectThemePreview(_ preview: PopupThemeSelection) {
        recordSecurityInteraction()
        themePreview = preview
        UserDefaults.standard.set(preview.themeID, forKey: Self.themeIDDefaultsKey)
        UserDefaults.standard.set(preview.appearance.rawValue, forKey: Self.themeAppearanceDefaultsKey)
        publishCurrentProjection()
    }

    private static let themeIDDefaultsKey = "SlipBoard.Appearance.themeID"
    private static let themeAppearanceDefaultsKey = "SlipBoard.Appearance.mode"

    /// A stored id whose theme file is no longer bundled falls back to the
    /// default theme, so the menu checkmark always matches what is drawn.
    private static func loadThemeSelection() -> PopupThemeSelection {
        let defaults = UserDefaults.standard
        let themeID = defaults.string(forKey: themeIDDefaultsKey)
            .flatMap { id in SBThemeRegistry.themes.contains { $0.id == id } ? id : nil }
            ?? PopupThemeSelection.fallback.themeID
        let appearance = defaults.string(forKey: themeAppearanceDefaultsKey)
            .flatMap(PopupAppearance.init(rawValue:))
            ?? PopupThemeSelection.fallback.appearance
        return PopupThemeSelection(themeID: themeID, appearance: appearance)
    }

    /// Everything the popup panel's geometry and chrome depend on. The menu
    /// bar label observes this instead of the full view state so a content-only
    /// change no longer re-presents the panel or redraws the status item.
    var popupWindowKey: SBPopupWindowKey {
        SBPopupWindowKey(
            isPresented: isPopupPresented,
            isSuppressed: shouldSuppressPopupPresentation,
            revealsProtectedContent: securitySnapshot.lockState.revealsProtectedContent,
            isPinnedCollapsed: isPinnedCollapsed,
            reservesOverlayHeadroom: pasteOverlayState.isPresented
                && pasteOverlayState.kind == .pasteTransformMenu,
            usesGlassShellMargin: popupTheme.treatment == .liquidGlass
        )
    }

    var isPinnedCollapsed: Bool {
        // Based on every pinned clip, not the filtered ones: a filter with no
        // pinned matches must not fold the rail away.
        manualPinnedCollapsed ?? controller.latestSnapshot.pinnedItems.isEmpty
    }

    func togglePinnedCollapsed() {
        manualPinnedCollapsed = !isPinnedCollapsed
    }

    func selectClip(id: String?) {
        recordSecurityInteraction()
        controller.selectItem(id: id)
    }

    func deleteSelectedClip() {
        recordSecurityInteraction()
        // The controller's selection, not `popupState`: the published state
        // trails it by one main-queue turn, so right after a selection change
        // it still names the previous clip.
        guard securitySnapshot.lockState.revealsProtectedContent,
              let selectedClipID = controller.latestSnapshot.selectedItemID else {
            return
        }

        controller.pasteActions.closeActiveOverlay()
        syncPasteOverlayState()
        controller.deleteItem(id: selectedClipID)
        runtimeStatusOverride = RuntimeStatusOverride(
            message: localization.text(.statusDeletedHistoryItem),
            tone: .success
        )
        publishCurrentProjection()
    }

    func clearHistory() {
        recordSecurityInteraction()
        guard securitySnapshot.lockState.revealsProtectedContent else { return }

        controller.pasteActions.closeActiveOverlay()
        syncPasteOverlayState()

        controller.deleteAllItems()

        runtimeStatusOverride = RuntimeStatusOverride(
            message: localization.text(.statusClearedHistory),
            tone: .success
        )
        publishCurrentProjection()
    }

    func setSearchLockForQA(_ isLocked: Bool) {
        guard securitySnapshot.settings.isAppLockEnabled else {
            if isLocked == false {
                securityRuntime.clearFailure()
            }
            return
        }

        if isLocked {
            securityRuntime.lock(reason: .manual)
        } else {
            securityRuntime.beginUnlock(using: securitySnapshot.settings.unlockMethod)
        }
    }

    func toggleSearchLockForQA() {
        setSearchLockForQA(isSearchLockedForQA == false)
    }

    func selectOrganizationGroup(_ groupID: OrganizationGroupID) {
        recordSecurityInteraction()
        controller.selectOrganizationGroup(id: groupID)
        if case .custom = groupID,
           let matchingGroup = organizationGroups.first(where: { $0.groupID == groupID }) {
            organizationDraftName = matchingGroup.name
        }
    }

    func updateOrganizationDraftName(_ name: String) {
        recordSecurityInteraction()
        organizationDraftName = name
    }

    func createOrganizationGroupFromDraft() {
        recordSecurityInteraction()
        let name = organizationDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return }

        guard let group = controller.createOrganizationGroup(name: name, accentToken: "accent.info") else {
            return
        }

        organizationDraftName = ""
        controller.selectOrganizationGroup(id: group.groupID)
    }

    func renameSelectedOrganizationGroupFromDraft() {
        recordSecurityInteraction()
        let name = organizationDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return }

        switch searchNotesState.activeGroupID {
        case let .custom(groupID):
            let updatedGroupID = OrganizationGroupID.custom(groupID)
            _ = controller.updateOrganizationGroup(
                id: updatedGroupID,
                name: name,
                accentToken: "accent.info"
            )
        case .all, .ungrouped:
            break
        }
    }

    func deleteSelectedOrganizationGroup() {
        recordSecurityInteraction()
        switch searchNotesState.activeGroupID {
        case .custom:
            controller.deleteOrganizationGroup(id: searchNotesState.activeGroupID)
            organizationDraftName = ""
        case .all, .ungrouped:
            break
        }
    }

    func assignSelectedClipToActiveGroup() {
        recordSecurityInteraction()
        guard let selectedClipID = selectedClipIDForOrganization else { return }

        switch searchNotesState.activeGroupID {
        case let .custom(groupID):
            controller.updateOrganizationMembership(
                for: selectedClipID,
                groupIDs: [.custom(groupID)]
            )
        case .all, .ungrouped:
            break
        }
    }

    func clearSelectedClipGroups() {
        recordSecurityInteraction()
        guard let selectedClipID = selectedClipIDForOrganization else { return }
        controller.updateOrganizationMembership(for: selectedClipID, groupIDs: [])
    }

    func toggleNoteEditor(for clipID: String) {
        recordSecurityInteraction()
        if searchNotesState.activeEditor?.clipID == clipID,
           searchNotesState.activeEditor?.isPresented == true {
            controller.dismissNoteEditor()
            return
        }

        controller.selectItem(id: clipID)
        controller.presentNoteEditor(for: clipID)
    }

    func updateNoteDraft(for clipID: String, draftText: String) {
        recordSecurityInteraction()
        if searchNotesState.activeEditor?.clipID != clipID {
            controller.presentNoteEditor(for: clipID)
        }
        controller.updateNoteDraft(draftText)
    }

    func saveNoteDraft(for clipID: String) {
        recordSecurityInteraction()
        if searchNotesState.activeEditor?.clipID != clipID {
            controller.presentNoteEditor(for: clipID)
        }
        controller.saveActiveNote()
    }

    func cancelNoteEditing(for clipID: String) {
        recordSecurityInteraction()
        if searchNotesState.activeEditor?.clipID == clipID {
            controller.dismissNoteEditor()
        }
    }

    func moveSelection(by delta: Int) {
        recordSecurityInteraction()
        controller.moveSelection(by: delta)
    }

    func openContextMenu(for clipID: String) {
        recordSecurityInteraction()
        controller.selectItem(id: clipID)
        controller.pasteActions.openContextMenu(for: clipID)
        syncPasteOverlayState()
    }

    func openPasteTransformMenu(for clipID: String, highlightedActionID: PasteActionID) {
        recordSecurityInteraction()
        controller.selectItem(id: clipID)
        let didOpen = controller.pasteActions.openPasteTransformMenu(for: clipID, highlightedActionID: highlightedActionID)
        syncPasteOverlayState()
        if didOpen == false {
            runtimeStatusOverride = RuntimeStatusOverride(
                message: localization.text(.popupPasteAsOnlyText),
                tone: .warning
            )
            publishCurrentProjection()
        }
    }

    func closeActiveOverlay() {
        recordSecurityInteraction()
        controller.pasteActions.closeActiveOverlay()
        syncPasteOverlayState()
    }

    func highlightContextAction(_ actionID: String) {
        recordSecurityInteraction()
        guard pasteOverlayState.kind == .contextMenu else { return }
        pasteOverlayState.highlightedTarget = .contextCommand(actionID)
    }

    func performContextAction(_ actionID: String) {
        recordSecurityInteraction()
        switch actionID {
        case "paste-as":
            guard let selectedClipID = selectedClipID else { return }
            openPasteTransformMenu(for: selectedClipID, highlightedActionID: highlightedTransformActionID)
        case "copy":
            let didCopy = controller.pasteActions.copySelectedItemAgain()
            runtimeStatusOverride = RuntimeStatusOverride(
                message: localization.text(didCopy ? .statusCopiedToClipboard : .statusSelectedUnavailableToCopy),
                tone: didCopy ? .success : .warning
            )
            closeActiveOverlay()
            publishCurrentProjection()
        case "pin":
            guard let item = controller.selectedHistoryItem else { return }
            controller.setPinned(item.isPinned == false, for: item.id)
            runtimeStatusOverride = RuntimeStatusOverride(
                message: localization.text(item.isPinned ? .statusUnpinnedItem : .statusPinnedItem),
                tone: .success
            )
            closeActiveOverlay()
            publishCurrentProjection()
        case "add-note":
            guard let selectedClipID else { return }
            closeActiveOverlay()
            toggleNoteEditor(for: selectedClipID)
        case "delete":
            deleteSelectedClip()
        default:
            runtimeStatusOverride = RuntimeStatusOverride(
                message: localization.text(.statusCommandUnavailable),
                tone: .warning
            )
            closeActiveOverlay()
            publishCurrentProjection()
        }
    }

    func highlightTransformAction(_ actionID: PasteActionID) {
        recordSecurityInteraction()
        controller.pasteActions.highlightTransformAction(actionID)
        syncPasteOverlayState()
    }

    func selectTransformAction(_ actionID: PasteActionID) {
        recordSecurityInteraction()
        highlightTransformAction(actionID)
    }

    @discardableResult
    func performPasteAction(
        _ actionID: PasteActionID,
        closeBehavior: PasteActionCloseBehavior
    ) -> PasteActionExecutionResult? {
        recordSecurityInteraction()
        let result = controller.pasteActions.performAction(actionID, closeBehavior: closeBehavior)

        if let result {
            runtimeStatusOverride = RuntimeStatusOverride(
                message: result.statusMessage,
                tone: result.didSucceed ? .success : .warning
            )
        }

        syncPasteOverlayState()
        publishCurrentProjection()

        return result
    }

    var onAccessibilityPermissionRequired: (() -> Void)?

    func showPastePermissionRequired() {
        runtimeStatusOverride = RuntimeStatusOverride(
            message: localization.text(.alertAccessibilityMessage),
            tone: .warning
        )
        publishCurrentProjection()
        onAccessibilityPermissionRequired?()
    }

    func showPasteTargetUnavailable() {
        runtimeStatusOverride = RuntimeStatusOverride(
            message: localization.text(.statusPasteTargetUnavailable),
            tone: .warning
        )
        setPopupPresented(true)
        publishCurrentProjection()
    }

    func setPopupPresented(_ isPresented: Bool) {
        if isPresented {
            if isPopupPresented == false {
                popupPresentationID += 1
            }
            shellCoordinator.showPopup()
        } else {
            shellCoordinator.closePopup()
            controller.pasteActions.closeActiveOverlay()
            syncPasteOverlayState()
            if UserDefaults.standard.bool(forKey: Self.clearSearchOnCloseDefaultsKey) {
                setSearchPresented(false)
                let snapshot = controller.latestSnapshot
                if snapshot.activeFilter != .all { controller.updateActiveFilter(.all) }
                if snapshot.activeSourceID != nil { controller.updateActiveSource(nil) }
            }
        }
        isPopupPresented = shellCoordinator.isPopupPresented
    }

    /// Off by default: closing the popup keeps the search query and filters.
    static let clearSearchOnCloseDefaultsKey = "SlipBoard.Search.clearOnPopupClose"

    func showSettingsPresentation(selecting section: SettingsSectionID = .general) {
        recordSecurityInteraction()
        shellCoordinator.showSettings(selecting: section)
        settingsState = shellCoordinator.settingsShellState
    }

    func selectSnippet(id: SnippetID?) {
        recordSecurityInteraction()
        snippetsHotkeysRuntime.selectSnippet(id: id)
    }

    func createSnippetDraft() {
        recordSecurityInteraction()
        snippetsHotkeysRuntime.createSnippetDraft()
    }

    func discardSnippetDraft() {
        recordSecurityInteraction()
        snippetsHotkeysRuntime.discardActiveDraft()
    }

    func saveSnippet(_ draft: SnippetEditorDraft) {
        recordSecurityInteraction()
        snippetsHotkeysRuntime.updateEditorDraft(draft)
        snippetsHotkeysRuntime.saveActiveDraft()
    }

    func deleteSelectedSnippet() {
        recordSecurityInteraction()
        snippetsHotkeysRuntime.deleteSelectedSnippet()
    }

    func beginHotkeyRecorderSession(for target: HotkeyBindingTarget) {
        recordSecurityInteraction()
        snippetsHotkeysRuntime.beginRecorderSession(for: target)
    }

    @discardableResult
    func commitHotkeyRecorderCandidate(_ descriptor: HotkeyDescriptor) -> HotkeyRecorderSessionState {
        recordSecurityInteraction()
        return snippetsHotkeysRuntime.commitRecorderCandidate(descriptor)
    }

    func cancelHotkeyRecorderSession() {
        recordSecurityInteraction()
        snippetsHotkeysRuntime.cancelRecorderSession()
    }

    func clearHotkeyBinding(for target: HotkeyBindingTarget) {
        recordSecurityInteraction()
        snippetsHotkeysRuntime.clearBinding(for: target)
    }

    func handlePauseCaptureCommand() {
        let result = FoundationShellRuntimeHooks.togglePauseCapture(at: .now)
        runtimeStatusOverride = RuntimeStatusOverride(
            message: result.statusMessage,
            tone: pauseStatusTone(for: result)
        )
        publishCurrentProjection()
    }

    private func apply(
        _ projection: ClipboardHistoryProjection<PopupShellViewState, PopupFilterOption, MenuBarSummaryState>
    ) {
        let latestExclusionsPauseSnapshot = controller.latestExclusionsPauseSnapshot
        if exclusionsPauseSnapshot != latestExclusionsPauseSnapshot {
            apply(exclusionsPauseSnapshot: latestExclusionsPauseSnapshot)
        }

        let latestSearchProjection = controller.searchNotesRuntime.latestProjectionState
        if searchNotesState != latestSearchProjection {
            apply(searchProjection: latestSearchProjection)
        }

        var updatedPopupState = projection.popupState
        updatedPopupState.themePreview = themePreview
        updatedPopupState.isSearchPresented = isSearchPresented || updatedPopupState.searchQuery.isEmpty == false
        updatedPopupState.status = resolvedStatus(from: updatedPopupState.status)

        popupState = updatedPopupState
        filterOptions = projection.filterOptions
        baseMenuBarSummary = projection.menuBarSummary
        isMonitoring = controller.isMonitoring
        supportedTransformActionIDs = Self.supportedTransformActionIDs(
            for: controller.pasteActions.selectedSourceItem
        )
        if pasteOverlayState.isPresented == false {
            pasteOverlayState = controller.pasteActions.overlayState
        }
        synchronizeShellState()
    }

    private func apply(retentionSnapshot: RetentionRuntimeSnapshot) {
        self.retentionSnapshot = retentionSnapshot
        settingsState = Self.makeSettingsState(
            retentionSnapshot: retentionSnapshot,
            searchProjection: searchNotesState,
            groups: organizationGroups,
            securitySnapshot: securitySnapshot,
            snippetsSnapshot: snippetsHotkeysSnapshot,
            exclusionsPauseSnapshot: exclusionsPauseSnapshot,
            bridgeSnapshot: bridgeSnapshot,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled,
            selectedSection: settingsState.selectedSection
        )
        synchronizeShellState()
    }

    private func apply(cleanupResult: RetentionCleanupResult) {
        if let statusMessage = cleanupResult.statusMessage, statusMessage.isEmpty == false {
            runtimeStatusOverride = RuntimeStatusOverride(
                message: statusMessage,
                tone: Self.tone(for: cleanupResult)
            )
        }
    }

    private func publishCurrentProjection() {
        apply(controller.projection)
    }

    private func apply(searchProjection: SearchNotesProjectionState) {
        searchNotesState = searchProjection
        qaLockState = securityRuntime.currentLockState

        if case .custom = searchProjection.activeGroupID,
           organizationDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let matchingGroup = organizationGroups.first(where: { $0.groupID == searchProjection.activeGroupID }) {
            organizationDraftName = matchingGroup.name
        }

        settingsState = Self.makeSettingsState(
            retentionSnapshot: retentionSnapshot,
            searchProjection: searchProjection,
            groups: organizationGroups,
            securitySnapshot: securitySnapshot,
            snippetsSnapshot: snippetsHotkeysSnapshot,
            exclusionsPauseSnapshot: exclusionsPauseSnapshot,
            bridgeSnapshot: bridgeSnapshot,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled,
            selectedSection: settingsState.selectedSection
        )
    }

    private func apply(snippetsSnapshot: SnippetsHotkeysRuntimeSnapshot) {
        self.snippetsHotkeysSnapshot = snippetsSnapshot
        settingsState = Self.makeSettingsState(
            retentionSnapshot: retentionSnapshot,
            searchProjection: searchNotesState,
            groups: organizationGroups,
            securitySnapshot: securitySnapshot,
            snippetsSnapshot: snippetsSnapshot,
            exclusionsPauseSnapshot: exclusionsPauseSnapshot,
            bridgeSnapshot: bridgeSnapshot,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled,
            selectedSection: settingsState.selectedSection
        )
        synchronizeShellState()
    }

    private func apply(exclusionsPauseSnapshot: ExclusionsPauseSnapshot) {
        self.exclusionsPauseSnapshot = exclusionsPauseSnapshot
        settingsState = Self.makeSettingsState(
            retentionSnapshot: retentionSnapshot,
            searchProjection: searchNotesState,
            groups: organizationGroups,
            securitySnapshot: securitySnapshot,
            snippetsSnapshot: snippetsHotkeysSnapshot,
            exclusionsPauseSnapshot: exclusionsPauseSnapshot,
            bridgeSnapshot: bridgeSnapshot,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled,
            selectedSection: settingsState.selectedSection
        )
    }

    private func apply(bridgeSnapshot: BridgeRuntimeSnapshot) {
        self.bridgeSnapshot = bridgeSnapshot
        settingsState = Self.makeSettingsState(
            retentionSnapshot: retentionSnapshot,
            searchProjection: searchNotesState,
            groups: organizationGroups,
            securitySnapshot: securitySnapshot,
            snippetsSnapshot: snippetsHotkeysSnapshot,
            exclusionsPauseSnapshot: exclusionsPauseSnapshot,
            bridgeSnapshot: bridgeSnapshot,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled,
            selectedSection: settingsState.selectedSection
        )
        synchronizeShellState()
    }

    private func apply(securitySnapshot: SecurityRuntimeSnapshot) {
        self.securitySnapshot = securitySnapshot
        qaLockState = securityRuntime.currentLockState
        snippetsHotkeysRuntime.refreshRuntimeAvailability(
            securitySnapshot.lockState.revealsProtectedContent ? .enabled : .lockedDisabled
        )

        if securitySnapshot.lockState.revealsProtectedContent == false {
            controller.pasteActions.closeActiveOverlay()
            syncPasteOverlayState()
        }

        settingsState = Self.makeSettingsState(
            retentionSnapshot: retentionSnapshot,
            searchProjection: searchNotesState,
            groups: organizationGroups,
            securitySnapshot: securitySnapshot,
            snippetsSnapshot: snippetsHotkeysSnapshot,
            exclusionsPauseSnapshot: exclusionsPauseSnapshot,
            bridgeSnapshot: bridgeSnapshot,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled,
            selectedSection: settingsState.selectedSection
        )
        publishCurrentProjection()
    }

    private func syncPasteOverlayState() {
        pasteOverlayState = controller.pasteActions.overlayState
        supportedTransformActionIDs = Self.supportedTransformActionIDs(
            for: controller.pasteActions.selectedSourceItem
        )
    }

    private func synchronizeShellState() {
        shellCoordinator.applyRuntimeState(
            popupShellState: popupState,
            popupFilterOptions: filterOptions,
            settingsShellState: settingsState,
            menuBarSummaryState: baseMenuBarSummary,
            securitySnapshot: securitySnapshot,
            exclusionsPauseSnapshot: exclusionsPauseSnapshot
        )

        popupState = shellCoordinator.popupShellState
        filterOptions = shellCoordinator.popupFilterOptions
        settingsState = shellCoordinator.settingsShellState
        menuBarSummary = shellCoordinator.menuBarSummaryState
        isPopupPresented = shellCoordinator.isPopupPresented
    }

    private func updateSecuritySettings(_ mutate: (inout SecuritySettings) -> Void) {
        // `securitySnapshot` is mirrored onto the main queue asynchronously, so
        // two changes in one turn would have the second start from stale
        // settings and undo the first. The runtime's own copy is current.
        var settings = securityRuntime.latestSnapshot.settings
        mutate(&settings)
        settings.lastUpdatedAt = .now
        securityRuntime.updateSettings(settings)
    }

    private func updateExclusionsBehaviorSettings(hidePopupInsideExcludedApps: Bool) {
        controller.exclusionsPauseRuntime.updateBehaviorSettings(
            ExclusionsBehaviorSettings(hidePopupInsideExcludedApps: hidePopupInsideExcludedApps),
            lastUpdatedAt: .now
        )
        runtimeStatusOverride = RuntimeStatusOverride(
            message: hidePopupInsideExcludedApps
                ? "Popup will hide inside excluded apps."
                : "Popup remains available inside excluded apps.",
            tone: .warning
        )
        publishCurrentProjection()
    }

    private func addExcludedAppFromRuntimeContext() {
        guard let candidate = nextExcludedAppCandidate() else {
            runtimeStatusOverride = RuntimeStatusOverride(
                message: localization.text(.statusNoEligibleApp),
                tone: .warning
            )
            publishCurrentProjection()
            return
        }

        var updatedRules = exclusionsPauseSnapshot.excludedApps
        updatedRules.append(candidate)
        controller.exclusionsPauseRuntime.replaceExcludedApps(updatedRules, lastUpdatedAt: .now)
        runtimeStatusOverride = RuntimeStatusOverride(
            message: localization.text(.statusAddedExcludedApp, ["app": candidate.displayName]),
            tone: .success
        )
        publishCurrentProjection()
    }

    private func nextExcludedAppCandidate() -> ExcludedAppRule? {
        let candidates = exclusionCandidates()
        guard candidates.isEmpty == false else {
            return nil
        }

        let existingRules = exclusionsPauseSnapshot.excludedApps
        return candidates.first { candidate in
            existingRules.contains { rule in
                if let candidateBundleID = candidate.bundleID?.lowercased(),
                   let ruleBundleID = rule.bundleID?.lowercased(),
                   rule.matchStrategy == .bundleIDExact {
                    return candidateBundleID == ruleBundleID
                }

                return rule.displayNameMatchKey == candidate.displayNameMatchKey
            } == false
        }
    }

    private func exclusionCandidates() -> [ExcludedAppRule] {
        var candidates: [ExcludedAppRule] = []

        if let frontmostApp = exclusionsPauseSnapshot.frontmostApp,
           shouldOfferAsExclusionCandidate(frontmostApp) {
            candidates.append(excludedRule(from: frontmostApp))
        }

        var seenIDs = Set(candidates.map(\.id))
        for clip in popupState.allClips {
            let context = FrontmostAppContext(
                bundleID: inferredBundleID(from: clip.sourceApp),
                displayName: clip.sourceApp.displayName,
                symbolName: clip.sourceApp.symbolName,
                accentToken: clip.sourceApp.accentToken,
                observedAt: .now
            )

            guard shouldOfferAsExclusionCandidate(context) else {
                continue
            }

            let rule = excludedRule(from: context)
            guard seenIDs.insert(rule.id).inserted else {
                continue
            }

            candidates.append(rule)
        }

        return candidates
    }

    private func shouldOfferAsExclusionCandidate(_ app: FrontmostAppContext) -> Bool {
        let displayName = app.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard displayName.isEmpty == false else {
            return false
        }

        return displayName.caseInsensitiveCompare("SlipBoard") != .orderedSame
    }

    private func excludedRule(from app: FrontmostAppContext) -> ExcludedAppRule {
        if let bundleID = app.bundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
           bundleID.isEmpty == false {
            return ExcludedAppRule(
                id: "excluded.\(bundleID.lowercased())",
                bundleID: bundleID,
                displayName: app.displayName,
                symbolName: app.symbolName,
                matchStrategy: .bundleIDExact
            )
        }

        let displayNameKey = ExcludedAppRule.makeDisplayNameMatchKey(app.displayName)
        return ExcludedAppRule(
            id: "excluded.name.\(displayNameKey)",
            displayName: app.displayName,
            symbolName: app.symbolName,
            matchStrategy: .displayNameFallback
        )
    }

    private func inferredBundleID(from sourceApp: ClipSourceAppSummary) -> String? {
        if sourceApp.id == sourceApp.displayName {
            return nil
        }

        return sourceApp.id.contains(".") ? sourceApp.id : nil
    }

    private func recordSecurityInteraction() {
        securityRuntime.recordInteraction(at: .now)
    }

    private func pauseStatusMessage(for option: CapturePauseDurationOption) -> String {
        switch option {
        case .fifteenMinutes:
            return localization.text(.statusPausedFifteenMinutes)
        case .oneHour:
            return localization.text(.statusPausedOneHour)
        case .untilResume:
            return localization.text(.statusPausedUntilResume)
        }
    }

    private func pauseStatusTone(for result: CapturePauseHotkeyResult) -> PopupStatusTone {
        switch result {
        case .pausedManually, .timedPauseStillActive:
            return .paused
        case .resumed:
            return .success
        case .unavailable:
            return .warning
        }
    }

    private func resolvedStatus(from status: PopupStatusSummary) -> PopupStatusSummary {
        guard let runtimeStatusOverride else {
            return status
        }

        return PopupStatusSummary(
            statusLabel: runtimeStatusOverride.message,
            statusTone: runtimeStatusOverride.tone,
            primaryHint: status.primaryHint,
            secondaryHint: status.secondaryHint,
            itemCountText: status.itemCountText
        )
    }

    private var selectedClipID: String? {
        popupState.selectedClipID ?? popupState.allClips.first?.id
    }

    private var highlightedTransformActionID: PasteActionID {
        if case let .action(actionID)? = pasteOverlayState.highlightedTarget {
            return actionID
        }

        return PasteActionID.transformMenuOrder.first ?? .plainText
    }

    private static func makeSettingsState(
        retentionSnapshot: RetentionRuntimeSnapshot,
        searchProjection: SearchNotesProjectionState,
        groups: [OrganizationGroupSummary],
        securitySnapshot: SecurityRuntimeSnapshot,
        snippetsSnapshot: SnippetsHotkeysRuntimeSnapshot,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot,
        bridgeSnapshot: BridgeRuntimeSnapshot,
        isLaunchAtLoginEnabled: Bool,
        selectedSection: SettingsSectionID
    ) -> SettingsShellState {
        SettingsShellState(
            selectedSection: selectedSection,
            general: organizationPane(
                searchProjection: searchProjection,
                groups: groups,
                isLaunchAtLoginEnabled: isLaunchAtLoginEnabled
            ),
            retention: retentionPane(from: retentionSnapshot),
            exclusions: exclusionsPane(from: exclusionsPauseSnapshot),
            hotkeys: hotkeysPane(from: snippetsSnapshot),
            snippets: snippetsPane(from: snippetsSnapshot),
            security: securityPane(from: securitySnapshot),
            bridge: bridgePane(from: bridgeSnapshot)
        )
    }

    private static func pane(_ id: SettingsSectionID, subtitle: String) -> SettingsPaneModel {
        SettingsPaneModel(
            id: id,
            title: id.displayTitle,
            subtitle: subtitle
        )
    }

    private static func organizationPane(
        searchProjection: SearchNotesProjectionState,
        groups: [OrganizationGroupSummary],
        isLaunchAtLoginEnabled: Bool
    ) -> SettingsPaneModel {
        let lockLabel = searchProjection.lockState == .locked ? "Locked" : "Unlocked"

        return SettingsPaneModel(
            id: .general,
            title: "Organization",
            subtitle: "Local search, note mirrors, and collections stay on the same runtime path as the popup and menu bar shell.",
            sections: [
                SettingsPaneSection(
                    id: "startup",
                    title: "Startup",
                    rows: [
                        .toggle(
                            SettingsToggleItem(
                                id: "startup.launch-at-login",
                                title: "Launch at login",
                                isOn: isLaunchAtLoginEnabled
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "organization.search",
                    title: "Search",
                    descriptionText: "FTS5 queries, note mirrors, and collection terms stay local. The runtime disables search entirely whenever App Lock is holding protected content.",
                    rows: [
                        .listEntry(
                            SettingsListEntry(
                                id: "organization.search-status",
                                title: "Search visibility",
                                detailText: searchProjection.searchDisabledMessage?.detailText ?? "Clipboard content, notes, and collections are searchable while the runtime is unlocked.",
                                accessoryText: lockLabel,
                                badgeText: searchProjection.searchResultCount == 0 ? nil : "\(searchProjection.searchResultCount)",
                                symbolName: "magnifyingglass"
                            )
                        ),
                        .listEntry(
                            SettingsListEntry(
                                id: "organization.note-source",
                                title: "Note source of truth",
                                detailText: "Note bodies stay behind the protected payload seam; this pane only reflects the unlocked mirror used for local search.",
                                symbolName: "note.text"
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "organization.locked",
                    title: "Locked state",
                    placeholder: SettingsPanePlaceholder(
                        id: "organization.locked.callout",
                        title: searchProjection.lockState == .locked ? "Search is currently disabled" : "Live App Lock integration",
                        detailText: searchProjection.lockState == .locked
                            ? "Search results, note drafts, and unlocked mirrors are cleared while locked. The popup, menu bar, and Security pane all route through the same local lock state."
                            : "Search, notes, and groups remain on the same runtime path as the App Lock controller, encrypted payload store, and popup/menu shell.",
                        badgeText: lockLabel.uppercased(),
                        kind: .callout
                    )
                )
            ]
        )
    }

    private static func retentionPane(from snapshot: RetentionRuntimeSnapshot) -> SettingsPaneModel {
        let retentionSettings = snapshot.retentionSettings
        let assetCacheSettings = snapshot.assetCacheSettings
        // The settings shell appends the localized "pinned" label.
        let pinnedBadgeText = formattedInteger(snapshot.pinnedClipCount)

        return SettingsPaneModel(
            id: .retention,
            title: "Retention",
            subtitle: "Set local limits, auto-clear rules, and asset-cache maintenance for one shared runtime path.",
            sections: [
                SettingsPaneSection(
                    id: "retention.history-limit",
                    title: "History limit",
                    descriptionText: "Keep up to \(formattedInteger(RetentionSettingBounds.maxItemCount)) local clips before pruning the oldest unpinned entries.",
                    rows: [
                        .slider(
                            SettingsSliderItem(
                                id: "max-items",
                                title: "Maximum items",
                                detailText: "Pinned clips stay exempt from count-based cleanup.",
                                value: Double(retentionSettings.maxItemCount),
                                range: Double(RetentionSettingBounds.minItemCount)...Double(RetentionSettingBounds.maxItemCount),
                                step: Double(RetentionSettingBounds.itemCountStep),
                                valueLabel: "\(formattedInteger(retentionSettings.maxItemCount)) items"
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "retention.paste-behavior",
                    title: "Paste behavior",
                    descriptionText: "Control how pasting a clip affects its position in Recent.",
                    rows: [
                        .toggle(
                            SettingsToggleItem(
                                id: "bump-pasted-item-to-front",
                                title: "Move pasted item to top",
                                detailText: "When enabled, pasting a clip moves it to the front of Recent.",
                                isOn: retentionSettings.bumpPastedItemToFront
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "retention.ttl",
                    title: "Auto-clear",
                    descriptionText: "Choose how long local history is retained before age-based cleanup runs on launch, foreground, and periodic sweeps.",
                    rows: [
                        .choice(
                            SettingsChoiceItem(
                                id: "ttl",
                                title: "Retention period",
                                detailText: "Quick retention in the menu bar mirrors this setting immediately.",
                                selectedOptionID: retentionSettings.ttlPolicy.isCustom
                                    ? RetentionTTLPolicy.customOptionID
                                    : retentionSettings.ttlPolicy.rawValue,
                                options: RetentionTTLPolicy.presets.map { policy in
                                    SettingsChoiceOption(
                                        id: policy.rawValue,
                                        label: policy.settingsLabel,
                                        isSelected: policy == retentionSettings.ttlPolicy
                                    )
                                } + [
                                    // The detail carries the stored custom value so
                                    // the editor can start from it.
                                    SettingsChoiceOption(
                                        id: RetentionTTLPolicy.customOptionID,
                                        label: retentionSettings.ttlPolicy.isCustom
                                            ? retentionSettings.ttlPolicy.settingsLabel
                                            : "Custom",
                                        detailText: retentionSettings.ttlPolicy.isCustom
                                            ? retentionSettings.ttlPolicy.rawValue
                                            : nil,
                                        isSelected: retentionSettings.ttlPolicy.isCustom
                                    )
                                ]
                            )
                        ),
                        .toggle(
                            SettingsToggleItem(
                                id: "clear-on-quit",
                                title: "Clear on app quit",
                                detailText: "When enabled, quitting wipes local history and clears cached assets together.",
                                isOn: retentionSettings.clearOnQuit
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "retention.pinned-callout",
                    title: "Pinned items",
                    placeholder: SettingsPanePlaceholder(
                        id: "retention.pinned-callout.note",
                        title: "Pinned clips are preserved",
                        detailText: "TTL sweeps and max-item pruning skip pinned clips until you unpin or delete them manually.",
                        badgeText: pinnedBadgeText,
                        kind: .callout
                    )
                ),
                SettingsPaneSection(
                    id: "retention.asset-cache",
                    title: "Asset cache",
                    descriptionText: "Large previews and file-backed assets stay local and can be trimmed automatically or cleared on demand.",
                    rows: [
                        .slider(
                            SettingsSliderItem(
                                id: "cache-size",
                                title: "Max cache size",
                                detailText: "The runtime refreshes usage on launch, foreground, and after cleanup.",
                                value: Double(assetCacheSettings.maxCacheSizeMB),
                                range: Double(RetentionSettingBounds.minCacheSizeMB)...Double(RetentionSettingBounds.maxCacheSizeMB),
                                step: Double(RetentionSettingBounds.cacheSizeStepMB),
                                valueLabel: "\(assetCacheSettings.maxCacheSizeMB) MB"
                            )
                        ),
                        .action(
                            SettingsActionRow(
                                id: "clear-cache",
                                title: "Clear now",
                                accessoryText: ByteCountFormatter.string(
                                    fromByteCount: assetCacheSettings.currentUsageBytes,
                                    countStyle: .file
                                ),
                                symbolName: "trash",
                                role: .standard
                            )
                        )
                    ]
                )
            ]
        )
    }

    private static func exclusionsPane(from snapshot: ExclusionsPauseSnapshot) -> SettingsPaneModel {
        let sortedRules = snapshot.excludedApps.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        let pauseSelectionID = snapshot.pauseState.selectedOption?.rawValue ?? ""

        return SettingsPaneModel(
            id: .exclusions,
            title: "Exclusions",
            subtitle: "Excluded apps, popup-hide behavior, and pause state stay local to this Mac and route through the same live runtime used by the popup, menu bar, and pause hotkey.",
            sections: [
                SettingsPaneSection(
                    id: "exclusions.apps",
                    title: "Excluded apps",
                    descriptionText: "Add the current or recently observed source app to skip capture before history insertion.",
                    rows: [
                        .action(
                            SettingsActionRow(
                                id: "exclusions.add-app",
                                title: "Add App",
                                detailText: "Add the frontmost non-SlipBoard app or the newest observed source app from history.",
                                symbolName: "plus"
                            )
                        )
                    ] + sortedRules.map { rule in
                        .listEntry(
                            SettingsListEntry(
                                id: "exclusions.remove.\(rule.id)",
                                title: rule.displayName,
                                detailText: rule.detailText,
                                accessoryText: "Remove",
                                badgeText: rule.usesDisplayNameFallback ? "NAME" : nil,
                                symbolName: rule.symbolName
                            )
                        )
                    },
                    placeholder: sortedRules.isEmpty
                        ? SettingsPanePlaceholder(
                            id: "exclusions.apps.empty",
                            title: "No excluded apps yet",
                            detailText: "Use Add App to keep sensitive sources out of history and reuse the same exclusion match path for capture and popup rules.",
                            kind: .emptyState
                        )
                        : nil
                ),
                SettingsPaneSection(
                    id: "exclusions.behavior",
                    title: "Capture behavior",
                    descriptionText: "Popup suppression is optional and only applies while an excluded app is frontmost.",
                    rows: [
                        .toggle(
                            SettingsToggleItem(
                                id: "exclusions.hide-popup",
                                title: "Hide popup inside excluded apps",
                                detailText: "When on, the popup will not open and any visible popup is dismissed as soon as an excluded app becomes frontmost.",
                                isOn: snapshot.behaviorSettings.hidePopupInsideExcludedApps
                            )
                        )
                    ],
                    placeholder: snapshot.isFrontmostAppExcluded
                        ? SettingsPanePlaceholder(
                            id: "exclusions.behavior.active-app",
                            title: "Excluded app is currently active",
                            detailText: currentExcludedAppDetailText(for: snapshot),
                            badgeText: snapshot.behaviorSettings.hidePopupInsideExcludedApps ? "HIDE POPUP" : "CAPTURE ONLY",
                            kind: .callout
                        )
                        : nil
                ),
                SettingsPaneSection(
                    id: "exclusions.pause",
                    title: "Pause capture",
                    descriptionText: "Manual and scheduled pauses share the same runtime path as the menu pause row and the reserved pause hotkey.",
                    rows: [
                        .choice(
                            SettingsChoiceItem(
                                id: "exclusions.pause",
                                title: "Pause preset",
                                detailText: "Choose a timed pause or keep capture paused until you resume manually.",
                                selectedOptionID: pauseSelectionID,
                                options: CapturePauseDurationOption.allCases.map { option in
                                    SettingsChoiceOption(
                                        id: option.rawValue,
                                        label: option.displayTitle,
                                        isSelected: option.rawValue == pauseSelectionID
                                    )
                                },
                                style: .segmented
                            )
                        ),
                        .listEntry(
                            SettingsListEntry(
                                id: "exclusions.pause.status",
                                title: pauseStateTitle(for: snapshot.pauseState),
                                detailText: pauseStateDetailText(for: snapshot.pauseState),
                                accessoryText: pauseStateAccessoryText(for: snapshot.pauseState),
                                symbolName: snapshot.pauseState.isPaused ? "pause.circle" : "play.circle"
                            )
                        )
                    ] + (snapshot.pauseState.isPaused
                        ? [
                            .action(
                                SettingsActionRow(
                                    id: "exclusions.resume-capturing",
                                    title: "Resume capturing",
                                    detailText: "Resume immediately and clear any scheduled pause.",
                                    symbolName: "play.fill"
                                )
                            )
                        ]
                        : [])
                )
            ]
        )
    }

    private static func securityPane(from snapshot: SecurityRuntimeSnapshot) -> SettingsPaneModel {
        let isEnabled = snapshot.settings.isAppLockEnabled
        let selectedUnlockMethod = snapshot.settings.unlockMethod.rawValue
        let selectedAutoLock = snapshot.settings.autoLockInterval.rawValue

        return SettingsPaneModel(
            id: .security,
            title: "Security",
            subtitle: "Local app lock, preview privacy, and payload protection all flow through the live runtime path.",
            sections: [
                SettingsPaneSection(
                    id: "security.app-lock",
                    title: "App Lock",
                    descriptionText: "Use the current system authentication flow without creating a second SlipBoard password.",
                    rows: [
                        .toggle(
                            SettingsToggleItem(
                                id: "security.app-lock-toggle",
                                title: "Lock Slipboard",
                                detailText: "The popup shell, menu bar summary, and search runtime stay redacted until unlock succeeds.",
                                isOn: isEnabled
                            )
                        ),
                        .action(
                            SettingsActionRow(
                                id: "security.current-state",
                                title: "Current state",
                                detailText: nil,
                                accessoryText: snapshot.lockState.revealsProtectedContent ? "Lock" : "Unlock",
                                symbolName: "lock",
                                role: .standard
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "security.unlock-method",
                    title: "Unlock method",
                    descriptionText: "Secure Enclave is preferred when available, with local password fallback on the current Mac.",
                    rows: [
                        .choice(
                            SettingsChoiceItem(
                                id: "security.unlock-method",
                                title: "Preferred method",
                                selectedOptionID: selectedUnlockMethod,
                                options: SecurityUnlockMethod.allCases.map { method in
                                    SettingsChoiceOption(
                                        id: method.rawValue,
                                        label: method == .biometricPreferred ? "Touch ID / Face ID" : "System Password",
                                        isSelected: method.rawValue == selectedUnlockMethod
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
                                selectedOptionID: selectedAutoLock,
                                options: SecurityAutoLockInterval.allCases.map { interval in
                                    SettingsChoiceOption(
                                        id: interval.rawValue,
                                        label: securityAutoLockLabel(for: interval),
                                        isSelected: interval.rawValue == selectedAutoLock
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
                    descriptionText: "Redact previews on the existing shell surfaces instead of opening a detached privacy screen.",
                    rows: [
                        .toggle(
                            SettingsToggleItem(
                                id: "security.hide-previews",
                                title: "Hide previews in Mission Control / Expose",
                                detailText: "Protected previews stay hidden outside the unlocked session while App Lock is active.",
                                isOn: snapshot.settings.privacyMode == .hidePreviewsInMissionControl,
                                isEnabled: isEnabled
                            )
                        )
                    ]
                ),
                SettingsPaneSection(
                    id: "security.data-protection",
                    title: "Data protection",
                    descriptionText: "Inspect local encryption readiness, key wrapping policy, and whether decrypted content is still in memory.",
                    rows: [
                        .listEntry(
                            SettingsListEntry(
                                id: "security.encryption-status",
                                title: "Encryption status",
                                detailText: "Protected payloads stay local and only decrypt on demand inside an unlocked session.",
                                accessoryText: isEnabled ? "Enabled" : "Disabled",
                                symbolName: "lock.doc"
                            )
                        ),
                        .listEntry(
                            SettingsListEntry(
                                id: "security.key-storage",
                                title: "Key storage",
                                detailText: "Payload keys remain local-only and never enter sync, export, or recovery flows.",
                                accessoryText: keyStorageText(for: snapshot),
                                symbolName: "key"
                            )
                        ),
                        .listEntry(
                            SettingsListEntry(
                                id: "security.decrypted-cache",
                                title: "Decrypted cache",
                                detailText: "Locking clears in-memory previews before the popup can show protected content again.",
                                accessoryText: snapshot.hasUnwrappedPayloadKey ? "In memory" : "Cleared",
                                symbolName: "memorychip"
                            )
                        )
                    ]
                )
            ]
        )
    }

    private static func hotkeysPane(from snapshot: SnippetsHotkeysRuntimeSnapshot) -> SettingsPaneModel {
        let globalRows = snapshot.hotkeysSettingsState.globalBindings.map { binding in
            SettingsRowModel.listEntry(
                SettingsListEntry(
                    id: binding.id,
                    title: binding.title,
                    detailText: binding.latestConflict?.message ?? binding.detailText,
                    accessoryText: binding.hotkey?.displayLabel ?? hotkeyAccessoryText(for: binding.availability),
                    badgeText: bindingBadgeText(for: binding),
                    symbolName: binding.target.id.hasPrefix("global:") ? "keyboard" : "curlybraces"
                )
            )
        }
        let snippetRows = snapshot.hotkeysSettingsState.snippetBindings.map { binding in
            SettingsRowModel.listEntry(
                SettingsListEntry(
                    id: binding.id,
                    title: binding.title,
                    detailText: binding.latestConflict?.message ?? binding.detailText,
                    accessoryText: binding.hotkey?.displayLabel ?? hotkeyAccessoryText(for: binding.availability),
                    badgeText: bindingBadgeText(for: binding),
                    symbolName: "curlybraces"
                )
            )
        }

        return SettingsPaneModel(
            id: .hotkeys,
            title: "Hotkeys",
            subtitle: "Popup and snippet shortcuts stay local to this Mac and flow through the same package-free registrar, conflict rules, and App Lock policy.",
            sections: [
                SettingsPaneSection(
                    id: "hotkeys.global",
                    title: "Global shortcuts",
                    descriptionText: "The popup hotkey stays background-global. Paste As remains popup-scoped, and future commands remain visible but unavailable until their owning feature lands.",
                    rows: globalRows
                ),
                SettingsPaneSection(
                    id: "hotkeys.snippets",
                    title: "Snippet hotkeys",
                    descriptionText: "Assigned snippet shortcuts paste directly through the shared paste engine and are disabled whenever protected content is locked.",
                    rows: snippetRows,
                    placeholder: snippetRows.isEmpty
                        ? SettingsPanePlaceholder(
                            id: "hotkeys.snippets.empty",
                            title: "No snippet shortcuts yet",
                            detailText: "Create snippets from the shared runtime host, then assign per-snippet hotkeys without leaving the live shell path.",
                            kind: .emptyState
                        )
                        : nil
                ),
                SettingsPaneSection(
                    id: "hotkeys.status",
                    title: "Runtime status",
                    placeholder: SettingsPanePlaceholder(
                        id: "hotkeys.status.callout",
                        title: runtimeAvailabilityTitle(for: snapshot.runtimeAvailability),
                        detailText: snapshot.hotkeysSettingsState.inlineMessage ?? "Conflicts are validated when a shortcut is assigned, not when it fires.",
                        badgeText: "\(snapshot.registeredBindings.count) ACTIVE",
                        kind: .callout
                    )
                )
            ]
        )
    }

    private static func snippetsPane(from snapshot: SnippetsHotkeysRuntimeSnapshot) -> SettingsPaneModel {
        let snippetRows = snapshot.snippetsSettingsState.libraryEntries.map { entry in
            SettingsRowModel.listEntry(
                SettingsListEntry(
                    id: "snippet.library.\(entry.id)",
                    title: entry.title,
                    detailText: entry.subtitle ?? "Saved locally for direct paste and popup-side reuse.",
                    accessoryText: entry.hotkeyLabel,
                    badgeText: entry.isPinned ? "PINNED" : (entry.isSelected ? "OPEN" : nil),
                    symbolName: entry.kind == .code ? "curlybraces" : "text.alignleft"
                )
            )
        }

        let editorState = snapshot.snippetsSettingsState.editorState
        let editorDetailText: String
        switch editorState.validationState {
        case .valid:
            editorDetailText = editorState.savedRecord == nil
                ? "Create or select a snippet in the live runtime host to edit title, content, and hotkey assignment."
                : "The current draft stays on the same runtime path as the popup hotkeys and direct-paste engine."
        case .missingTitle:
            editorDetailText = "Add a title before saving this snippet."
        case .missingContent:
            editorDetailText = "Add snippet content before saving."
        case let .hotkeyConflict(conflict):
            editorDetailText = conflict.message
        }

        return SettingsPaneModel(
            id: .snippets,
            title: "Snippets",
            subtitle: "Saved snippets persist per device, reuse the shared paste path, and keep hotkey conflict rules aligned with the Hotkeys pane.",
            sections: [
                SettingsPaneSection(
                    id: "snippets.library",
                    title: "Library",
                    descriptionText: "Each snippet keeps local title, content, optional hotkey, and pin state without introducing a second store or cloud sync path.",
                    rows: snippetRows,
                    placeholder: snippetRows.isEmpty
                        ? SettingsPanePlaceholder(
                            id: "snippets.library.empty",
                            title: snapshot.snippetsSettingsState.emptyStateTitle ?? "No snippets yet",
                            detailText: snapshot.snippetsSettingsState.emptyStateDetailText
                                ?? "Create your first saved snippet to keep reusable text local to this Mac.",
                            kind: .emptyState
                        )
                        : nil
                ),
                SettingsPaneSection(
                    id: "snippets.editor",
                    title: "Editor state",
                    rows: [
                        .listEntry(
                            SettingsListEntry(
                                id: "snippets.editor.selection",
                                title: editorState.savedRecord?.title ?? "No snippet selected",
                                detailText: editorDetailText,
                                accessoryText: editorState.draft.hotkey?.displayLabel ?? hotkeyAccessoryText(for: editorState.availability),
                                badgeText: editorState.isDirty ? "DIRTY" : (editorState.canSave ? "READY" : nil),
                                symbolName: "square.and.pencil"
                            )
                        )
                    ],
                    placeholder: SettingsPanePlaceholder(
                        id: "snippets.editor.status",
                        title: runtimeAvailabilityTitle(for: snapshot.runtimeAvailability),
                        detailText: snapshot.hotkeysSettingsState.inlineMessage ?? "Snippet editing stays on the same runtime path as registration, conflict checks, and direct paste.",
                        badgeText: "\(snapshot.assignedSnippetCount) ASSIGNED",
                        kind: .callout
                    )
                )
            ]
        )
    }

    private static func bridgePane(from snapshot: BridgeRuntimeSnapshot) -> SettingsPaneModel {
        let statusText = snapshot.accountStatus.badgeText
        let behaviorRows = [
            SettingsRowModel.toggle(
                SettingsToggleItem(
                    id: "enable-bridge",
                    title: "Enable iCloud Bridge",
                    detailText: bridgeEnableDetailText(for: snapshot),
                    isOn: snapshot.settings.isBridgeEnabled
                )
            ),
            SettingsRowModel.toggle(
                SettingsToggleItem(
                    id: "bridge.publish-on-paste",
                    title: "Publish pasted item to devices",
                    detailText: "Only successful local pastes of text, URL, and code are published from this Mac.",
                    isOn: snapshot.settings.isPublishOnPasteEnabled,
                    isEnabled: snapshot.isBridgeEnabledEffective
                )
            ),
            SettingsRowModel.toggle(
                SettingsToggleItem(
                    id: "bridge.receive",
                    title: "Receive from iPhone",
                    detailText: "Companion-created imports land in local Mac history and follow the existing retention and security rules.",
                    isOn: snapshot.settings.isReceiveEnabled,
                    isEnabled: snapshot.isBridgeEnabledEffective
                )
            )
        ]

        let deviceRows = snapshot.devices.map { device in
            SettingsRowModel.listEntry(
                SettingsListEntry(
                    id: "bridge.device.\(device.id)",
                    title: device.displayName,
                    detailText: deviceDetailText(for: device),
                    accessoryText: device.lastSeenAt.map(relativeTimestamp(for:)),
                    badgeText: device.badgeText,
                    symbolName: bridgeSymbolName(for: device.platform)
                )
            )
        }

        let activityRows = [
            SettingsRowModel.listEntry(
                SettingsListEntry(
                    id: "bridge.activity.last-sent",
                    title: "Last sent",
                    detailText: lastSentDetailText(for: snapshot),
                    accessoryText: snapshot.activity.lastPublishedAt.map(relativeTimestamp(for:)) ?? "Never",
                    badgeText: activityBadgeText(for: snapshot.activity.lastPublishedAt)
                )
            ),
            SettingsRowModel.listEntry(
                SettingsListEntry(
                    id: "bridge.activity.last-received",
                    title: "Last received",
                    detailText: lastReceivedDetailText(for: snapshot),
                    accessoryText: snapshot.activity.lastImportedAt.map(relativeTimestamp(for:)) ?? "Never",
                    badgeText: activityBadgeText(for: snapshot.activity.lastImportedAt)
                )
            ),
            SettingsRowModel.listEntry(
                SettingsListEntry(
                    id: "bridge.activity.pending-imports",
                    title: "Pending imports",
                    detailText: pendingImportsDetailText(for: snapshot),
                    accessoryText: "\(snapshot.activity.pendingImportCount)",
                    badgeText: snapshot.activity.pendingImportCount > 0 ? "Pending" : nil
                )
            )
        ] + (snapshot.activity.lastErrorText.map { errorText in
            [
                SettingsRowModel.listEntry(
                    SettingsListEntry(
                        id: "bridge.activity.last-error",
                        title: "Last error",
                        detailText: errorText,
                        accessoryText: "Error",
                        badgeText: "Error",
                        symbolName: "exclamationmark.triangle"
                    )
                )
            ]
        } ?? [])

        return SettingsPaneModel(
            id: .bridge,
            title: "iCloud Bridge",
            subtitle: bridgeSubtitle(for: snapshot),
            sections: [
                SettingsPaneSection(
                    id: "bridge.behavior",
                    title: "Bridge behavior",
                    descriptionText: "Paste on Mac, then paste on iPhone. Mac history stays local and no full-history upload is performed.",
                    rows: behaviorRows
                ),
                SettingsPaneSection(
                    id: "bridge.devices",
                    title: "Devices",
                    descriptionText: snapshot.devices.isEmpty ? "Bridge can stay enabled on Mac before a companion signs into the same iCloud account." : "Observed devices on the same iCloud account from bridge activity.",
                    rows: deviceRows
                ),
                SettingsPaneSection(
                    id: "bridge.activity",
                    title: "Last activity",
                    descriptionText: "Outbound publish stays one-shot with a 10-minute TTL and inbound imports remain explicit companion records only.",
                    rows: activityRows
                ),
                SettingsPaneSection(
                    id: "bridge.note",
                    title: "Local-only policy",
                    placeholder: SettingsPanePlaceholder(
                        id: "bridge.note.local-only",
                        title: statusText == "Unavailable" ? "iCloud Bridge unavailable" : "Local history stays local",
                        detailText: bridgePolicyDetailText(for: snapshot),
                        badgeText: snapshot.settings.ttlMinutes == 10 ? "10 MIN TTL" : "\(snapshot.settings.ttlMinutes) MIN TTL",
                        kind: .callout
                    )
                ),
                SettingsPaneSection(
                    id: "bridge.stop",
                    title: "Stop Bridge",
                    descriptionText: "Disable new publish and receive activity without deleting imported local history.",
                    rows: [
                        .action(
                            SettingsActionRow(
                                id: "bridge.stop",
                                title: "Stop Bridge",
                                detailText: "Turn off bridge activity on this Mac and keep existing local history intact.",
                                symbolName: "stop.circle",
                                role: .danger
                            )
                        )
                    ]
                )
            ]
        )
    }

    private static func runtimeAvailabilityTitle(for availability: HotkeyRuntimeAvailability) -> String {
        switch availability {
        case .enabled:
            return "Hotkeys are active"
        case .lockedDisabled:
            return "Hotkeys are locked"
        case .futureCommandUnavailable:
            return "Future commands remain unavailable"
        case .registrationUnavailable:
            return "Some registrations are unavailable"
        }
    }

    private static func hotkeyAccessoryText(for availability: HotkeyRuntimeAvailability) -> String {
        switch availability {
        case .enabled:
            return "Not set"
        case .lockedDisabled:
            return "Locked"
        case .futureCommandUnavailable:
            return "Future"
        case .registrationUnavailable:
            return "Unavailable"
        }
    }

    private static func bindingBadgeText(for binding: HotkeyBindingSummary) -> String? {
        if binding.latestConflict != nil {
            return "CONFLICT"
        }

        switch binding.availability {
        case .enabled:
            return binding.isPopupScoped ? "POPUP" : nil
        case .lockedDisabled:
            return "LOCKED"
        case .futureCommandUnavailable:
            return "FUTURE"
        case .registrationUnavailable:
            return "UNAVAILABLE"
        }
    }

    private static func currentExcludedAppDetailText(for snapshot: ExclusionsPauseSnapshot) -> String {
        let appName = snapshot.frontmostApp?.displayName
            ?? snapshot.matchedExcludedApp?.appContext.displayName
            ?? "an excluded app"
        let behaviorText = snapshot.behaviorSettings.hidePopupInsideExcludedApps
            ? "The popup is currently hidden for this app."
            : "Capture is blocked, but the popup can still open here."
        return "\(appName) is frontmost. \(behaviorText)"
    }

    private static func pauseStateTitle(for pauseState: CapturePauseState) -> String {
        switch pauseState {
        case .inactive:
            return "Capture is active"
        case .manual:
            return "Paused until resume"
        case let .timed(_, _, preset):
            return "Paused for \(preset.displayTitle)"
        }
    }

    private static func pauseStateDetailText(for pauseState: CapturePauseState) -> String {
        switch pauseState {
        case .inactive:
            return "New clipboard samples will be evaluated immediately."
        case .manual(let startedAt):
            return "Manual pause started \(relativeTimestamp(for: startedAt))."
        case let .timed(startedAt, resumeAt, _):
            return "Paused \(relativeTimestamp(for: startedAt)); resumes \(relativeTimestamp(for: resumeAt))."
        }
    }

    private static func pauseStateAccessoryText(for pauseState: CapturePauseState) -> String? {
        guard let resumeAt = pauseState.resumeAt else {
            return pauseState.isPaused ? "Manual" : "Live"
        }

        return relativeTimestamp(for: resumeAt)
    }

    private static func supportedTransformActionIDs(
        for sourceItem: PasteActionSourceItem?
    ) -> Set<PasteActionID> {
        guard let sourceItem, sourceItem.supportsTextTransforms else {
            return []
        }

        return Set(PasteActionID.transformMenuOrder)
    }

    private static func tone(for cleanupResult: RetentionCleanupResult) -> PopupStatusTone {
        if cleanupResult.didWipeAllHistory {
            return .warning
        }

        if cleanupResult.removedClipCount > 0 || cleanupResult.removedAssetCount > 0 || cleanupResult.freedBytes > 0 {
            return .success
        }

        return .normal
    }

    private static func formattedInteger(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func resolveRuntimeComponents(
        controller: ClipboardHistoryController?,
        securityRuntime: SecurityRuntimeController?,
        bridgeRuntime: CloudBridgeRuntimeController?
    ) -> RuntimeComponents {
        // The bridge runtime is intentionally not attached to the history controller
        // while Bridge is hidden for v1.0, so pastes are never published and no
        // inbound records are imported.
        if let controller, let securityRuntime, let bridgeRuntime {
            return RuntimeComponents(
                controller: controller,
                securityRuntime: securityRuntime,
                bridgeRuntime: bridgeRuntime
            )
        }

        let payloadStore = EncryptedPayloadStore()
        let decryptedPayloadCache = DecryptedPayloadCache()
        let searchStore = SearchNotesOrganizationStore(
            payloadStore: payloadStore,
            decryptedPayloadCache: decryptedPayloadCache
        )
        let resolvedSecurityRuntime = SecurityRuntimeController(
            payloadStore: payloadStore,
            decryptedPayloadCache: decryptedPayloadCache,
            searchNotesStore: searchStore
        )
        let resolvedBridgeRuntime = bridgeRuntime ?? CloudBridgeRuntimeController()
        let searchRuntime = SearchNotesRuntimeController(
            store: searchStore,
            lockStateProvider: resolvedSecurityRuntime
        )
        let resolvedController = controller ?? ClipboardHistoryController(
            searchNotesRuntime: searchRuntime
        )
        return RuntimeComponents(
            controller: resolvedController,
            securityRuntime: resolvedSecurityRuntime,
            bridgeRuntime: resolvedBridgeRuntime
        )
    }

    private static func securityAutoLockLabel(for interval: SecurityAutoLockInterval) -> String {
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

    private static func keyStorageText(for snapshot: SecurityRuntimeSnapshot) -> String {
        guard let wrappedKey = snapshot.keyMaterialState.activeWrappedKey else {
            return snapshot.settings.isAppLockEnabled ? "Provisioning" : "Disabled"
        }

        switch wrappedKey.wrappingPolicy {
        case .secureEnclaveWrapped:
            return "Secure Enclave"
        case .keychainThisDeviceOnly:
            return "ThisDeviceOnly"
        }
    }

    private static func relativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private static func bridgeSubtitle(for snapshot: BridgeRuntimeSnapshot) -> String {
        switch snapshot.accountStatus {
        case .disabled:
            return "Paste on Mac, then paste on iPhone. Mac history stays local until you enable Bridge."
        case .unavailable:
            return "Paste on Mac, then paste on iPhone. Mac history stays local while iCloud Bridge is unavailable."
        case .restricted:
            return "Paste on Mac, then paste on iPhone. Mac history stays local while this account stays restricted."
        case .ready:
            return "Paste on Mac, then paste on iPhone. Mac history stays local and only intentional paste actions bridge."
        case .syncing:
            return "Paste on Mac, then paste on iPhone. Mac history stays local while bridge activity syncs."
        case .error:
            return "Paste on Mac, then paste on iPhone. Mac history stays local while the bridge reports an error."
        }
    }

    private static func bridgeEnableDetailText(for snapshot: BridgeRuntimeSnapshot) -> String {
        switch snapshot.accountStatus {
        case .disabled:
            return "Bridge through your CloudKit private database without uploading full SlipBoard history."
        case .unavailable:
            return "Signed out of iCloud or private database access is unavailable on this Mac."
        case .restricted:
            return "The current iCloud account cannot use the private bridge on this Mac."
        case .ready:
            return "Bridge through your CloudKit private database while keeping Mac history local."
        case .syncing:
            return "Bridge is active and processing eligible records through your CloudKit private database."
        case .error:
            return snapshot.activity.lastErrorText ?? "Bridge reported an error and needs attention before new activity resumes."
        }
    }

    private static func bridgePolicyDetailText(for snapshot: BridgeRuntimeSnapshot) -> String {
        switch snapshot.accountStatus {
        case .unavailable:
            return "Mac history stays local. Sign into iCloud and allow private database access before SlipBoard can publish one-shot bridge records."
        case .restricted:
            return "Mac history stays local. This Mac cannot bridge records for the current account, so publish and receive stay disabled."
        default:
            return "Mac history stays local. SlipBoard only bridges items you actually paste with double-click or Enter, never the full history, and imported local clips do not delete anything remotely."
        }
    }

    private static func deviceDetailText(for device: BridgeDeviceSummary) -> String {
        let lastSeenText = device.lastSeenAt.map(relativeTimestamp(for:))
        if let lastSeenText {
            return "\(device.statusText). Last seen \(lastSeenText)."
        }
        return device.statusText
    }

    private static func bridgeSymbolName(for platform: BridgeDevicePlatform) -> String {
        switch platform {
        case .mac:
            return "laptopcomputer"
        case .iphone:
            return "iphone"
        case .ipad:
            return "ipad"
        case .unknown:
            return "icloud"
        }
    }

    private static func lastSentDetailText(for snapshot: BridgeRuntimeSnapshot) -> String {
        if snapshot.activity.lastPublishedAt == nil {
            return "No intentional Mac paste has been bridged yet."
        }
        return "Only successful local paste actions of supported kinds are published."
    }

    private static func lastReceivedDetailText(for snapshot: BridgeRuntimeSnapshot) -> String {
        if snapshot.activity.lastImportedAt == nil {
            return "No companion import has been added to local Mac history yet."
        }
        return "Companion-created records enter Mac history through the existing local history path."
    }

    private static func pendingImportsDetailText(for snapshot: BridgeRuntimeSnapshot) -> String {
        if snapshot.activity.pendingImportCount == 0 {
            return "Incoming bridge records waiting for Mac import."
        }
        return "Eligible companion records are waiting to enter local Mac history."
    }

    private static func activityBadgeText(for date: Date?) -> String? {
        guard let date else {
            return nil
        }

        let elapsed = Date().timeIntervalSince(date)
        return elapsed < 60 ? "Now" : nil
    }
}

private struct RuntimeStatusOverride {
    let message: String
    let tone: PopupStatusTone
}

private struct RuntimeComponents {
    let controller: ClipboardHistoryController
    let securityRuntime: SecurityRuntimeController
    let bridgeRuntime: CloudBridgeRuntimeController
}

@main
struct SlipBoardApp: App {
    @StateObject private var runtime = ClipboardHistoryAppRuntime()
    @State private var popupPresentationController = SBPopupPresentationController()
    @State private var didInitializeShellLifecycle = false
    @State private var wasPopupPresented = false
    @State private var openSettingsAction: OpenSettingsAction?

    var body: some Scene {
        MenuBarExtra {
            SBMenuBarDropdownRuntimeView(
                runtime: runtime,
                onSelectCommand: handleMenuCommand
            )
        } label: {
            SlipBoardMenuBarLifecycleLabel(
                title: "SlipBoard",
                badgeText: runtime.menuBarSummary.badgeText,
                theme: runtime.popupTheme,
                securitySnapshot: runtime.securitySnapshot,
                windowKey: runtime.popupWindowKey,
                onInitialAppear: initializeShellLifecycleIfNeeded,
                onAppDidBecomeActive: handleAppDidBecomeActive,
                onAppWillTerminate: handleAppWillTerminate,
                onSyncPopupPresentation: syncPopupPresentation,
                onReceiveOpenSettings: { openSettingsAction = $0 }
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SlipBoardSettingsRuntimeView(
                runtime: runtime
            )
            .frame(minWidth: 960, minHeight: 620)
            .sbLocalization(runtime.localization, language: runtime.appLanguage)
        }
        .defaultSize(width: 960, height: 620)
        .windowResizability(.contentMinSize)
    }

    private func initializeShellLifecycleIfNeeded() {
        guard didInitializeShellLifecycle == false else {
            syncPopupPresentation()
            return
        }

        popupPresentationController.onVisibilityChange = { isVisible in
            if runtime.isPopupPresented != isVisible {
                runtime.setPopupPresented(isVisible)
            }
        }
        runtime.onAccessibilityPermissionRequired = {
            presentAccessibilityPermissionAlertIfNeeded()
        }
        popupPresentationController.onDeleteRequested = {
            runtime.deleteSelectedClip()
        }
        popupPresentationController.onPrimaryPasteRequested = {
            popupPresentationController.restorePasteTargetThen {
                guard let result = runtime.performPasteAction(.original, closeBehavior: .closePopup) else {
                    return
                }

                if result.popupTransition == .closePopup {
                    runtime.setPopupPresented(false)
                } else {
                    runtime.setPopupPresented(true)
                }
            } onPermissionDenied: {
                runtime.showPastePermissionRequired()
            } onTargetUnavailable: {
                runtime.showPasteTargetUnavailable()
            }
        }
        popupPresentationController.onMoveSelectionRequested = { delta in
            runtime.moveSelection(by: delta)
        }
        popupPresentationController.onTypeToSearchCharacters = { characters in
            runtime.appendTypedCharactersToSearch(characters)
        }
        runtime.focusSettings(on: .general)
        runtime.startMonitoring()
        didInitializeShellLifecycle = true
        popupPresentationController.prewarm(content: popupContent)
        syncPopupPresentation()
    }

    /// Shown when a paste actually fails for want of Accessibility access.
    /// At launch this ran a modal loop that blocked the whole app before the
    /// user had asked it to do anything.
    func presentAccessibilityPermissionAlertIfNeeded() {
        guard AXIsProcessTrusted() == false else { return }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = runtime.localization.text(.alertAccessibilityTitle)
            alert.informativeText = runtime.localization.text(.alertAccessibilityMessage)
            alert.alertStyle = .informational
            alert.addButton(withTitle: runtime.localization.text(.alertOpenAccessibilitySettings))
            alert.addButton(withTitle: runtime.localization.text(.commonNotNow))

            if alert.runModal() == .alertFirstButtonReturn,
               let accessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(accessibilityURL)
            }
        }
    }

    private func handleAppDidBecomeActive() {
        runtime.handleAppDidBecomeActive()
        syncPopupPresentation()
    }

    private func handleAppWillTerminate() {
        runtime.prepareForAppQuit()
        popupPresentationController.dismiss()
    }

    private func syncPopupPresentation() {
        guard runtime.isPopupPresented, runtime.shouldSuppressPopupPresentation == false else {
            wasPopupPresented = false
            popupPresentationController.dismissIfNeeded(notifyVisibilityChange: runtime.isPopupPresented)
            return
        }

        if wasPopupPresented == false {
            let firstClipID = runtime.popupState.recentClips.first?.id
            runtime.selectClip(id: firstClipID)
        }
        wasPopupPresented = true

        popupPresentationController.present(
            isLocked: runtime.securitySnapshot.lockState.revealsProtectedContent == false,
            reservesOverlayHeadroom: runtime.pasteOverlayState.isPresented
                && runtime.pasteOverlayState.kind == .pasteTransformMenu,
            shellMargin: popupShellMargin,
            content: popupContent
        )
    }

    private var popupShellMargin: EdgeInsets {
        runtime.popupTheme.treatment == .liquidGlass ? SBPopupLayoutMetrics.glassShellMargin : EdgeInsets()
    }

    private func popupContent() -> some View {
        SBPopupRootView(
            runtime: runtime,
            onPauseCapture: { handleMenuCommand("pause-capturing") },
            onClearHistory: handleClearHistoryCommand,
            onOpenSettings: {
                // Settings is a window of this app, so the outside-click
                // monitor never sees the click that moves focus there.
                runtime.setPopupPresented(false)
                handleMenuCommand("open-settings")
            },
            onPerformContextAction: handleContextAction,
            onExecutePasteAction: handlePasteAction
        )
    }

    private func handleMenuCommand(_ commandID: String) {
        switch commandID {
        case "open-slipboard":
            runtime.setPopupPresented(true)
        case "capture-status":
            runtime.refreshNow()
        case "pause-capturing":
            runtime.handlePauseCaptureCommand()
        case "open-settings":
            showSettingsWindow(selecting: .general)
        case "security-settings":
            showSettingsWindow(selecting: .security)
        case "unlock-slipboard":
            runtime.setSearchLockForQA(false)
        case "lock-slipboard":
            runtime.setSearchLockForQA(true)
        case "quit-slipboard":
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }

    private func handleClearHistoryCommand() {
        let alert = NSAlert()
        alert.messageText = runtime.localization.text(.alertClearClipboardHistoryTitle)
        alert.informativeText = runtime.localization.text(.alertClearClipboardHistoryMessage)
        alert.alertStyle = .warning
        alert.addButton(withTitle: runtime.localization.text(.menuClearHistory))
        alert.addButton(withTitle: runtime.localization.text(.cancel))
        alert.buttons.first?.hasDestructiveAction = true

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        runtime.clearHistory()
    }

    private func showSettingsWindow(selecting section: SettingsSectionID = .general) {
        runtime.showSettingsPresentation(selecting: section)
        NSApp.activate(ignoringOtherApps: true)
        // The private `showSettingsWindow:` selector is ignored since macOS 14;
        // SwiftUI only opens the Settings scene through `openSettings`.
        DispatchQueue.main.async {
            openSettingsAction?()
        }
    }

    private func handlePasteAction(_ actionID: PasteActionID, _ closeBehavior: PasteActionCloseBehavior) {
        popupPresentationController.restorePasteTargetThen {
            guard let result = runtime.performPasteAction(actionID, closeBehavior: closeBehavior) else {
                return
            }

            switch result.popupTransition {
            case .closePopup:
                runtime.setPopupPresented(false)
            case .keepPopupOpen:
                runtime.setPopupPresented(true)
            case .stayOpen:
                runtime.setPopupPresented(true)
            }
        } onPermissionDenied: {
            runtime.showPastePermissionRequired()
        } onTargetUnavailable: {
            runtime.showPasteTargetUnavailable()
        }
    }

    private func handleContextAction(_ actionID: String) {
        if actionID == "paste" {
            handlePasteAction(.original, .closePopup)
            return
        }

        runtime.performContextAction(actionID)
    }
}

private struct SlipBoardMenuBarLifecycleLabel: View {
    let title: String
    let badgeText: String?
    let theme: SBTheme
    let securitySnapshot: SecurityRuntimeSnapshot
    let windowKey: SBPopupWindowKey
    let onInitialAppear: () -> Void
    let onAppDidBecomeActive: () -> Void
    let onAppWillTerminate: () -> Void
    let onSyncPopupPresentation: () -> Void
    let onReceiveOpenSettings: (OpenSettingsAction) -> Void

    // `Scene` code has no environment, so the Settings opener is lifted out of
    // this always-alive label view for the App to call.
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        SBMenuBarLabel(
            title: title,
            badgeText: badgeText ?? "",
            theme: theme,
            securitySnapshot: securitySnapshot
        )
        .onAppear {
            onReceiveOpenSettings(openSettings)
            onInitialAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            onAppDidBecomeActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            onAppWillTerminate()
        }
        .onChange(of: windowKey) { _, _ in
            onSyncPopupPresentation()
        }
    }
}

/// Builds the dropdown's localized summary inside its own body so the work
/// only happens while the menu is actually on screen.
private struct SBMenuBarDropdownRuntimeView: View {
    @ObservedObject var runtime: ClipboardHistoryAppRuntime
    let onSelectCommand: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SBMenuBarDropdownShell(
            theme: runtime.popupTheme,
            summary: runtime.localizedMenuBarSummary,
            securitySnapshot: runtime.securitySnapshot,
            onSelectQuickRetention: runtime.selectQuickRetention,
            onSelectCommand: { commandID in
                // A `.window` menu bar extra stays open after a row is picked,
                // so it sat on top of the Settings window or popup it opened.
                dismiss()
                onSelectCommand(commandID)
            }
        )
        .padding(8)
        .background(runtime.popupTheme.palette.canvas)
        .preferredColorScheme(runtime.popupTheme.mode == .dark ? .dark : .light)
        .sbLocalization(runtime.localization, language: runtime.appLanguage)
    }
}

private struct SBPopupRootView: View {
    @ObservedObject var runtime: ClipboardHistoryAppRuntime
    let onPauseCapture: () -> Void
    let onClearHistory: () -> Void
    let onOpenSettings: () -> Void
    let onPerformContextAction: (String) -> Void
    let onExecutePasteAction: (PasteActionID, PasteActionCloseBehavior) -> Void

    var body: some View {
        ClipboardHistoryPopupView(
            theme: runtime.popupTheme,
            filters: runtime.localizedFilterOptions,
            state: runtime.localizedPopupState,
            exclusionsPauseSnapshot: runtime.exclusionsPauseSnapshot,
            searchNotesState: runtime.searchNotesState,
            securitySnapshot: runtime.securitySnapshot,
            pasteOverlayState: runtime.pasteOverlayState,
            supportedTransformActionIDs: runtime.supportedTransformActionIDs,
            searchFocusRequestToken: runtime.searchFocusRequestToken,
            isPresented: runtime.isPopupPresented,
            onToggleSearchPresented: runtime.setSearchPresented,
            onSearchQueryChange: runtime.updateSearchQuery,
            onSelectFilter: runtime.selectFilter,
            onSelectSource: runtime.selectSource,
            onSelectThemePreview: runtime.selectThemePreview,
            onPauseCapture: onPauseCapture,
            onClearHistory: onClearHistory,
            onOpenSettings: onOpenSettings,
            onQuit: { NSApplication.shared.terminate(nil) },
            onSelectClipID: runtime.selectClip,
            onMoveSelection: runtime.moveSelection,
            onDeleteSelectedClip: runtime.deleteSelectedClip,
            onToggleNoteEditor: runtime.toggleNoteEditor,
            onUpdateNoteDraft: runtime.updateNoteDraft,
            onSaveNoteDraft: runtime.saveNoteDraft,
            onCancelNoteEditing: runtime.cancelNoteEditing,
            onOpenContextMenu: runtime.openContextMenu,
            onOpenPasteTransformMenu: runtime.openPasteTransformMenu,
            onCloseActiveOverlay: runtime.closeActiveOverlay,
            onHighlightContextAction: runtime.highlightContextAction,
            onPerformContextAction: onPerformContextAction,
            onHighlightTransformAction: runtime.highlightTransformAction,
            onSelectTransformAction: runtime.selectTransformAction,
            onExecutePasteAction: onExecutePasteAction,
            isPinnedCollapsed: runtime.isPinnedCollapsed,
            onTogglePinnedCollapsed: runtime.togglePinnedCollapsed
        )
        .padding(runtime.popupTheme.treatment == .liquidGlass ? SBPopupLayoutMetrics.glassShellMargin : EdgeInsets())
        .environment(\.sbPopupPresentationID, runtime.popupPresentationID)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .sbLocalization(runtime.localization, language: runtime.appLanguage)
    }
}

private struct SlipBoardSettingsRuntimeView: View {
    @ObservedObject var runtime: ClipboardHistoryAppRuntime
    @State private var recorderMonitor: HotkeyRecorderKeyEventMonitor?

    var body: some View {
        SBSettingsWindowShell(
            theme: runtime.settingsTheme,
            state: runtime.settingsState,
            securitySnapshot: runtime.securitySnapshot,
            bridgeSnapshot: runtime.bridgeSnapshot,
            exclusionsPauseSnapshot: runtime.exclusionsPauseSnapshot,
            snippetsHotkeysSnapshot: runtime.snippetsHotkeysSnapshot,
            onSelectSection: runtime.focusSettings,
            onSelectChoice: runtime.handleSettingsChoice,
            onToggle: runtime.handleSettingsToggle,
            onAdjustSlider: runtime.handleSettingsSlider,
            onSelectAction: runtime.handleSettingsAction,
            onBeginHotkeyRecording: runtime.beginHotkeyRecorderSession,
            onClearHotkeyBinding: runtime.clearHotkeyBinding,
            onSelectSnippet: runtime.selectSnippet,
            onCreateSnippet: runtime.createSnippetDraft,
            onSaveSnippet: runtime.saveSnippet,
            onDiscardSnippet: runtime.discardSnippetDraft,
            onDeleteSnippet: runtime.deleteSelectedSnippet
        )
        .onAppear(perform: synchronizeRecorderMonitor)
        .onDisappear(perform: cancelRecordingAndStopMonitor)
        .onChange(of: runtime.settingsState.selectedSection) { _, selectedSection in
            if Self.recordsHotkeys(in: selectedSection) {
                synchronizeRecorderMonitor()
            } else {
                cancelRecordingAndStopMonitor()
            }
        }
        .onChange(of: runtime.snippetsHotkeysSnapshot.hotkeysSettingsState.recorderSession) { _, _ in
            synchronizeRecorderMonitor()
        }
    }

    private func synchronizeRecorderMonitor() {
        if Self.recordsHotkeys(in: runtime.settingsState.selectedSection),
           runtime.snippetsHotkeysSnapshot.hotkeysSettingsState.recorderSession.phase == .recording {
            if recorderMonitor == nil {
                recorderMonitor = HotkeyRecorderKeyEventMonitor(
                    onDescriptorCaptured: { descriptor in
                        _ = runtime.commitHotkeyRecorderCandidate(descriptor)
                    },
                    onCancel: runtime.cancelHotkeyRecorderSession
                )
            }
            recorderMonitor?.start()
        } else {
            stopRecorderMonitor()
        }
    }

    /// The Snippets pane assigns snippet shortcuts too.
    private static func recordsHotkeys(in section: SettingsSectionID) -> Bool {
        section == .hotkeys || section == .snippets
    }

    private func stopRecorderMonitor() {
        recorderMonitor?.stop()
        recorderMonitor = nil
    }

    private func cancelRecordingAndStopMonitor() {
        let wasRecording = runtime.snippetsHotkeysSnapshot.hotkeysSettingsState.recorderSession.phase == .recording
        stopRecorderMonitor()
        if wasRecording {
            runtime.cancelHotkeyRecorderSession()
        }
    }
}
