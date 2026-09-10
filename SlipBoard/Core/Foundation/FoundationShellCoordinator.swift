import Combine
import Foundation

@MainActor
final class FoundationShellCoordinator: ObservableObject, PopupShellRouting {
    @Published var popupShellState: PopupShellViewState
    @Published var popupFilterOptions: [PopupFilterOption]
    @Published var settingsShellState: SettingsShellState
    @Published private var baseMenuBarSummaryState: MenuBarSummaryState
    @Published var presentationState: FoundationShellPresentationState
    @Published var securitySnapshot: SecurityRuntimeSnapshot?
    @Published var exclusionsPauseSnapshot: ExclusionsPauseSnapshot?

    init(
        popupShellState: PopupShellViewState? = nil,
        popupFilterOptions: [PopupFilterOption]? = nil,
        settingsShellState: SettingsShellState? = nil,
        menuBarSummaryState: MenuBarSummaryState? = nil,
        presentationState: FoundationShellPresentationState? = nil,
        securitySnapshot: SecurityRuntimeSnapshot? = nil,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot? = nil
    ) {
        self.popupShellState = popupShellState ?? MockFoundationFixtures.popupShellState
        self.popupFilterOptions = popupFilterOptions ?? MockFoundationFixtures.popupFilterOptions
        self.settingsShellState = settingsShellState ?? MockFoundationFixtures.settingsShellState
        self.baseMenuBarSummaryState = menuBarSummaryState ?? MockFoundationFixtures.menuBarSummaryState
        self.presentationState = presentationState ?? FoundationShellPresentationState()
        self.securitySnapshot = securitySnapshot
        self.exclusionsPauseSnapshot = exclusionsPauseSnapshot
    }

    var menuBarSummaryState: MenuBarSummaryState {
        makeEffectiveMenuBarSummaryState()
    }

    var isPopupPresented: Bool {
        presentationState.isPopupPresented
    }

    var isMenuBarDropdownPresented: Bool {
        presentationState.isMenuBarDropdownPresented
    }

    var isSettingsPresented: Bool {
        presentationState.isSettingsPresented
    }

    var selectedSettingsSection: SettingsSectionID {
        settingsShellState.selectedSection
    }

    var selectedSettingsPane: SettingsPaneModel {
        settingsShellState.pane(for: settingsShellState.selectedSection)
    }

    func applyRuntimeState(
        popupShellState: PopupShellViewState,
        popupFilterOptions: [PopupFilterOption],
        settingsShellState: SettingsShellState,
        menuBarSummaryState: MenuBarSummaryState,
        securitySnapshot: SecurityRuntimeSnapshot?,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot?
    ) {
        self.popupShellState = popupShellState
        self.popupFilterOptions = popupFilterOptions
        self.settingsShellState = settingsShellState
        self.baseMenuBarSummaryState = menuBarSummaryState
        self.securitySnapshot = securitySnapshot
        self.exclusionsPauseSnapshot = exclusionsPauseSnapshot

        if isPopupSuppressedByExclusions {
            setPopupPresented(false)
        }
    }

    func setPopupPresented(_ isPresented: Bool) {
        guard isPresented == false || isPopupSuppressedByExclusions == false else {
            presentationState.isPopupPresented = false
            popupShellState.activeOverlay = nil
            return
        }

        presentationState.isPopupPresented = isPresented
        if isPresented == false {
            popupShellState.activeOverlay = nil
        }
    }

    func setSettingsPresented(_ isPresented: Bool) {
        presentationState.isSettingsPresented = isPresented
    }

    func setMenuBarDropdownPresented(_ isPresented: Bool) {
        presentationState.isMenuBarDropdownPresented = isPresented
        if isPresented == false {
            baseMenuBarSummaryState.highlightedCommandID = nil
        }
    }

    func selectPopupClip(id: String?) {
        guard id == nil || clipPreview(for: id) != nil else { return }
        popupShellState.selectedClipID = id
    }

    func setPopupSearchPresented(_ isPresented: Bool) {
        popupShellState.isSearchPresented = isPresented
        if isPresented == false && popupShellState.searchQuery.isEmpty {
            popupShellState.activeOverlay = nil
        }
    }

    func setPopupSearchQuery(_ query: String) {
        popupShellState.searchQuery = query
        if query.isEmpty == false {
            popupShellState.isSearchPresented = true
        }
    }

    func selectPopupFilter(id: String) {
        guard popupFilterOptions.contains(where: { $0.id == id }) else { return }
        popupShellState.activeFilterID = id
    }

    func setPopupThemePreview(_ preview: PopupThemeSelection) {
        popupShellState.themePreview = preview
    }

    func showOverlay(
        kind: PopupOverlayKind,
        anchoredTo clipID: String,
        highlightedRowID: String? = nil
    ) {
        guard clipPreview(for: clipID) != nil else { return }
        popupShellState.activeOverlay = PopupOverlayState(
            kind: kind,
            anchorClipID: clipID,
            highlightedRowID: highlightedRowID
        )
        presentationState.isPopupPresented = true
    }

    func hideOverlay() {
        popupShellState.activeOverlay = nil
    }

    func selectSettingsSection(_ section: SettingsSectionID) {
        settingsShellState.selectedSection = section
    }

    func selectQuickRetentionOption(id: String) {
        guard baseMenuBarSummaryState.quickRetentionOptions.contains(where: { $0.id == id }) else { return }

        baseMenuBarSummaryState.quickRetentionSelectionID = id
        baseMenuBarSummaryState.quickRetentionOptions = baseMenuBarSummaryState.quickRetentionOptions.map { option in
            var updatedOption = option
            updatedOption.isSelected = option.id == id
            return updatedOption
        }
    }

    func highlightMenuCommand(id: String?) {
        guard id == nil || menuBarSummaryState.commands.contains(where: { $0.id == id }) else { return }
        baseMenuBarSummaryState.highlightedCommandID = id
    }

    func showPopup(selecting clipID: String? = nil) {
        guard isPopupSuppressedByExclusions == false else {
            presentationState.isPopupPresented = false
            popupShellState.activeOverlay = nil
            return
        }

        if let clipID {
            selectPopupClip(id: clipID)
        }

        presentationState.isPopupPresented = true
    }

    func closePopup() {
        presentationState.isPopupPresented = false
        popupShellState.activeOverlay = nil
    }

    func showSettings(selecting section: SettingsSectionID? = nil) {
        if let section {
            selectSettingsSection(section)
        }

        presentationState.isSettingsPresented = true
    }

    func closeSettings() {
        presentationState.isSettingsPresented = false
    }

    func showMenuBarDropdown() {
        presentationState.isMenuBarDropdownPresented = true
    }

    func closeMenuBarDropdown() {
        presentationState.isMenuBarDropdownPresented = false
        baseMenuBarSummaryState.highlightedCommandID = nil
    }

    func toggleMenuBarDropdown() {
        if presentationState.isMenuBarDropdownPresented {
            closeMenuBarDropdown()
        } else {
            showMenuBarDropdown()
        }
    }

    private func makeEffectiveMenuBarSummaryState() -> MenuBarSummaryState {
        guard let securitySnapshot else {
            return baseMenuBarSummaryState
        }

        var summary = baseMenuBarSummaryState
        summary.statusLabel = menuStatusLabel(for: securitySnapshot)

        if securitySnapshot.lockState.revealsProtectedContent == false {
            summary.commands = lockedMenuCommands(from: baseMenuBarSummaryState.commands, snapshot: securitySnapshot)
            summary.highlightedCommandID = normalizedHighlightedCommandID(
                currentID: baseMenuBarSummaryState.highlightedCommandID,
                commands: summary.commands
            )
        } else if securitySnapshot.settings.isAppLockEnabled {
            summary.commands = unlockedMenuCommands(from: baseMenuBarSummaryState.commands)
            summary.highlightedCommandID = normalizedHighlightedCommandID(
                currentID: baseMenuBarSummaryState.highlightedCommandID,
                commands: summary.commands
            )
        }

        return summary
    }

    private func menuStatusLabel(for snapshot: SecurityRuntimeSnapshot) -> String {
        switch snapshot.lockState {
        case .locked:
            return "Locked"
        case .unlocking:
            return "Unlocking"
        case .unlockFailed:
            return "Unlock failed"
        case .unlocked:
            return baseMenuBarSummaryState.statusLabel
        }
    }

    private func lockedMenuCommands(
        from existingCommands: [MenuBarCommandRow],
        snapshot: SecurityRuntimeSnapshot
    ) -> [MenuBarCommandRow] {
        let refreshCommand = existingCommands.first(where: { $0.id == "capture-status" })
        let quitCommand = existingCommands.first(where: { $0.id == "quit-slipboard" })

        var commands: [MenuBarCommandRow] = [
            MenuBarCommandRow(
                id: "unlock-slipboard",
                title: snapshot.lockState == .unlocking ? "Unlocking Slipboard" : "Unlock Slipboard",
                subtitle: unlockSubtitle(for: snapshot),
                symbolName: "lock.open",
                role: .standard
            ),
            MenuBarCommandRow(
                id: "security-settings",
                title: "Open Security Settings",
                subtitle: "Adjust App Lock, privacy, and local protection.",
                symbolName: "gearshape",
                role: .standard
            ),
            MenuBarCommandRow(
                id: "open-slipboard",
                title: "Show Locked Popup",
                subtitle: "Open the redacted popup shell without revealing content.",
                symbolName: "menubar.rectangle",
                role: .secondary
            )
        ]

        if let refreshCommand {
            commands.append(refreshCommand)
        }

        if let quitCommand {
            commands.append(quitCommand)
        }

        return commands
    }

    private func unlockedMenuCommands(from existingCommands: [MenuBarCommandRow]) -> [MenuBarCommandRow] {
        var commands = existingCommands.filter { $0.id != "unlock-slipboard" && $0.id != "security-settings" && $0.id != "lock-slipboard" }

        if let openSettingsIndex = commands.firstIndex(where: { $0.id == "open-settings" }) {
            commands.insert(
                MenuBarCommandRow(
                    id: "lock-slipboard",
                    title: "Lock Slipboard",
                    subtitle: "Hide protected previews and disable search until unlock.",
                    symbolName: "lock",
                    role: .secondary
                ),
                at: openSettingsIndex
            )
        } else {
            commands.append(
                MenuBarCommandRow(
                    id: "lock-slipboard",
                    title: "Lock Slipboard",
                    subtitle: "Hide protected previews and disable search until unlock.",
                    symbolName: "lock",
                    role: .secondary
                )
            )
        }

        return commands
    }

    private func unlockSubtitle(for snapshot: SecurityRuntimeSnapshot) -> String {
        if let failure = snapshot.lastFailure {
            return failure.detailText
        }

        switch snapshot.lockState {
        case .locked:
            return "Use the approved local unlock path before previews or search return."
        case .unlocking:
            return "System authentication is in progress for local protected content."
        case .unlockFailed:
            return "Retry the local unlock flow or open Security settings for status."
        case .unlocked:
            return "Protected content is already available in the current session."
        }
    }

    private func normalizedHighlightedCommandID(
        currentID: String?,
        commands: [MenuBarCommandRow]
    ) -> String? {
        guard let currentID else { return nil }
        return commands.contains(where: { $0.id == currentID }) ? currentID : nil
    }

    private func clipPreview(for id: String?) -> ClipPreviewSummary? {
        guard let id else { return nil }
        return popupShellState.allClips.first(where: { $0.id == id })
    }

    private var isPopupSuppressedByExclusions: Bool {
        guard let exclusionsPauseSnapshot else {
            return false
        }

        switch exclusionsPauseSnapshot.popupPolicyDecision {
        case .allow:
            return false
        case .suppressBecauseExcludedApp:
            return true
        }
    }
}

struct FoundationShellPresentationState: Hashable {
    var isPopupPresented: Bool
    var isMenuBarDropdownPresented: Bool
    var isSettingsPresented: Bool

    init(
        isPopupPresented: Bool = false,
        isMenuBarDropdownPresented: Bool = false,
        isSettingsPresented: Bool = false
    ) {
        self.isPopupPresented = isPopupPresented
        self.isMenuBarDropdownPresented = isMenuBarDropdownPresented
        self.isSettingsPresented = isSettingsPresented
    }
}
