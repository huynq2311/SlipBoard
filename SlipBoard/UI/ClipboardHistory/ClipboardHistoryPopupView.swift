import AppKit
import SwiftUI

struct ClipboardHistoryPopupView: View {
    let theme: SBTheme
    let filters: [PopupFilterOption]
    let state: PopupShellViewState
    var exclusionsPauseSnapshot: ExclusionsPauseSnapshot? = nil
    var searchNotesState: SearchNotesProjectionState = SearchNotesProjectionState()
    var securitySnapshot: SecurityRuntimeSnapshot? = nil
    var showOverlayPreview: Bool = false
    var pasteOverlayState: PasteActionOverlayState = .hidden
    var supportedTransformActionIDs: Set<PasteActionID> = Set(PasteActionID.transformMenuOrder)
    var onToggleSearchPresented: (Bool) -> Void = { _ in }
    var onSearchQueryChange: (String) -> Void = { _ in }
    var onSelectFilter: (String) -> Void = { _ in }
    var onSelectThemePreview: (PopupThemePreview) -> Void = { _ in }
    var onSelectOrganizationGroup: (OrganizationGroupID) -> Void = { _ in }
    var onSelectClipID: (String?) -> Void = { _ in }
    var onMoveSelection: (Int) -> Void = { _ in }
    var onDeleteSelectedClip: () -> Void = {}
    var onToggleNoteEditor: (String) -> Void = { _ in }
    var onUpdateNoteDraft: (String, String) -> Void = { _, _ in }
    var onSaveNoteDraft: (String) -> Void = { _ in }
    var onCancelNoteEditing: (String) -> Void = { _ in }
    var onClearNote: (String) -> Void = { _ in }
    var onOpenContextMenu: (String) -> Void = { _ in }
    var onOpenPasteTransformMenu: (String, PasteActionID) -> Void = { _, _ in }
    var onCloseActiveOverlay: () -> Void = {}
    var onHighlightContextAction: (String) -> Void = { _ in }
    var onPerformContextAction: (String) -> Void = { _ in }
    var onHighlightTransformAction: (PasteActionID) -> Void = { _ in }
    var onSelectTransformAction: (PasteActionID) -> Void = { _ in }
    var onExecutePasteAction: (PasteActionID, PasteActionCloseBehavior) -> Void = { _, _ in }

    var body: some View {
        SBPopupShell(
            theme: theme,
            filters: filters,
            state: resolvedState,
            searchNotesState: resolvedSearchNotesState,
            securitySnapshot: securitySnapshot,
            showOverlayPreview: showOverlayPreview,
            pasteOverlayState: pasteOverlayState,
            supportedTransformActionIDs: supportedTransformActionIDs,
            onToggleSearchPresented: onToggleSearchPresented,
            onSearchQueryChange: onSearchQueryChange,
            onSelectFilter: onSelectFilter,
            onSelectThemePreview: onSelectThemePreview,
            onSelectOrganizationGroup: onSelectOrganizationGroup,
            onSelectClip: { clipID in
                onSelectClipID(clipID)
            },
            onToggleNoteEditor: onToggleNoteEditor,
            onUpdateNoteDraft: onUpdateNoteDraft,
            onSaveNoteDraft: onSaveNoteDraft,
            onCancelNoteEditing: onCancelNoteEditing,
            onClearNote: onClearNote,
            onPrimaryAction: handlePrimaryAction,
            onOpenContextMenu: { clipID in
                onSelectClipID(clipID)
                onOpenContextMenu(clipID)
            },
            onPerformContextAction: onPerformContextAction,
            onHighlightContextAction: onHighlightContextAction,
            onOpenPasteTransformMenu: onOpenPasteTransformMenu,
            onHighlightTransformAction: onHighlightTransformAction,
            onSelectTransformAction: onSelectTransformAction,
            onConfirmTransformAction: confirmHighlightedTransformAction,
            onCloseActiveOverlay: onCloseActiveOverlay
        )
        .focusable()
        .onMoveCommand(perform: handleMoveCommand)
        .onKeyPress(keys: [.delete, .deleteForward], action: handleDeleteKeyPress)
        .onExitCommand(perform: handleExitCommand)
        .background(shortcutBindings)
        .onAppear {
            repairSelectionIfNeeded()
        }
        .onChange(of: state.selectedClipID) { _, _ in
            repairSelectionIfNeeded()
        }
        .onChange(of: state.pinnedClips) { _, _ in
            repairSelectionIfNeeded()
        }
        .onChange(of: state.recentClips) { _, _ in
            repairSelectionIfNeeded()
        }
        .onChange(of: state.searchQuery) { _, _ in
            repairSelectionIfNeeded()
        }
        .onChange(of: state.activeFilterID) { _, _ in
            repairSelectionIfNeeded()
        }
    }

    private var resolvedState: PopupShellViewState {
        var resolved = state
        resolved.selectedClipID = resolvedSelectionID
        resolved.status = popupStatus(baseStatus: resolved.status)

        if securitySnapshot?.isPreviewRedactionActive == true {
            resolved.pinnedClips = resolved.pinnedClips.map(redactedClipSummary)
            resolved.recentClips = resolved.recentClips.map(redactedClipSummary)
        }

        return resolved
    }

    private var resolvedSearchNotesState: SearchNotesProjectionState {
        var resolved = searchNotesState

        if resolved.searchQuery != resolvedState.searchQuery {
            resolved.searchQuery = resolvedState.searchQuery
        }

        if isProtectedContentVisible == false {
            resolved.activeEditor = nil
            resolved.searchDisabledMessage = .lockedDefault
        }

        if let selectedClipID = resolvedState.selectedClipID,
           let activeEditor = resolved.activeEditor,
           activeEditor.clipID != selectedClipID,
           activeEditor.isPresented {
            resolved.activeEditor = nil
        }

        return resolved
    }

    private var resolvedSelectionID: String? {
        let visibleIDs = Set(state.allClips.map(\.id))

        if let selectedClipID = state.selectedClipID, visibleIDs.contains(selectedClipID) {
            return selectedClipID
        }

        return state.pinnedClips.first?.id ?? state.recentClips.first?.id
    }

    private var selectedClipID: String? {
        resolvedSelectionID
    }

    private var highlightedTransformActionID: PasteActionID {
        if case let .action(actionID)? = pasteOverlayState.highlightedTarget {
            return actionID
        }

        return PasteActionID.transformMenuOrder.first ?? .plainText
    }

    @ViewBuilder
    private var shortcutBindings: some View {
        VStack {
            Button(action: handleReturnShortcut) {
                Text("")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])

            Button(action: handleOptionReturnShortcut) {
                Text("")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.option])

            Button(action: handleCommandReturnShortcut) {
                Text("")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .allowsHitTesting(false)
    }

    private func repairSelectionIfNeeded() {
        guard state.selectedClipID != resolvedSelectionID else { return }
        onSelectClipID(resolvedSelectionID)
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard isProtectedContentVisible else { return }

        switch direction {
        case .left:
            onMoveSelection(-1)
        case .right:
            onMoveSelection(1)
        default:
            break
        }
    }

    private func handleDeleteKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard isProtectedContentVisible,
              selectedClipID != nil,
              resolvedSearchNotesState.activeEditor?.isPresented != true,
              press.modifiers.contains(.command) == false,
              press.modifiers.contains(.option) == false,
              press.modifiers.contains(.control) == false,
              isEditingText == false else {
            return .ignored
        }

        onDeleteSelectedClip()
        return .handled
    }

    private func handlePrimaryAction(_ clipID: String) {
        guard isProtectedContentVisible else { return }
        onSelectClipID(clipID)
        onExecutePasteAction(.original, .closePopup)
    }

    private func handleReturnShortcut() {
        guard isProtectedContentVisible else { return }
        guard selectedClipID != nil else { return }

        switch pasteOverlayState.kind {
        case .contextMenu:
            onPerformContextAction(resolvedContextActionID)
        case .pasteTransformMenu:
            confirmHighlightedTransformAction()
        case nil:
            onExecutePasteAction(.original, .closePopup)
        }
    }

    private func handleOptionReturnShortcut() {
        guard isProtectedContentVisible else { return }
        guard selectedClipID != nil else { return }
        onExecutePasteAction(.original, .keepPopupOpen)
    }

    private func handleCommandReturnShortcut() {
        guard isProtectedContentVisible else { return }
        guard let selectedClipID else { return }
        onOpenPasteTransformMenu(selectedClipID, highlightedTransformActionID)
    }

    private func confirmHighlightedTransformAction() {
        guard isProtectedContentVisible else { return }
        guard selectedClipID != nil else { return }
        onExecutePasteAction(highlightedTransformActionID, .closePopup)
    }

    private func handleExitCommand() {
        if pasteOverlayState.isPresented {
            onCloseActiveOverlay()
            return
        }

        if state.activeOverlay != nil {
            onCloseActiveOverlay()
            return
        }

        if state.isSearchPresented {
            onToggleSearchPresented(false)
        }
    }

    private var resolvedContextActionID: String {
        guard case let .contextCommand(actionID)? = pasteOverlayState.highlightedTarget else {
            return "paste"
        }

        return actionID
    }

    private var isProtectedContentVisible: Bool {
        securitySnapshot?.lockState.revealsProtectedContent ?? true
    }

    private var isEditingText: Bool {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }

        return textView.isEditable
    }

    private func redactedClipSummary(_ clip: ClipPreviewSummary) -> ClipPreviewSummary {
        var redacted = clip
        redacted.titleText = "Preview hidden"
        redacted.bodyText = "Privacy mode is redacting this clip preview."
        redacted.noteText = nil
        redacted.secondaryBadgeText = "PRIVATE"
        return redacted
    }

    private func popupStatus(baseStatus: PopupStatusSummary) -> PopupStatusSummary {
        guard let exclusionsPauseSnapshot else { return baseStatus }

        if exclusionsPauseSnapshot.pauseState.isPaused {
            return PopupStatusSummary(
                statusLabel: "Capture Paused",
                statusTone: .paused,
                primaryHint: pausePrimaryHint(for: exclusionsPauseSnapshot),
                secondaryHint: pauseSecondaryHint(for: exclusionsPauseSnapshot),
                itemCountText: baseStatus.itemCountText
            )
        }

        if exclusionsPauseSnapshot.isFrontmostAppExcluded {
            return PopupStatusSummary(
                statusLabel: excludedStatusLabel(for: exclusionsPauseSnapshot),
                statusTone: .warning,
                primaryHint: excludedPrimaryHint(for: exclusionsPauseSnapshot),
                secondaryHint: excludedSecondaryHint(for: exclusionsPauseSnapshot),
                itemCountText: baseStatus.itemCountText
            )
        }

        return baseStatus
    }

    private func pausePrimaryHint(for snapshot: ExclusionsPauseSnapshot) -> String {
        if let resumeAt = snapshot.pauseState.resumeAt {
            return "Resumes \(relativeTimestamp(for: resumeAt))"
        }

        return snapshot.activePauseLabel ?? "Resume capturing from the menu"
    }

    private func pauseSecondaryHint(for snapshot: ExclusionsPauseSnapshot) -> String {
        if let activePauseLabel = snapshot.activePauseLabel {
            return "Pause mode: \(activePauseLabel)"
        }

        return "Resume capturing from the menu"
    }

    private func excludedStatusLabel(for snapshot: ExclusionsPauseSnapshot) -> String {
        let appName = snapshot.frontmostApp?.displayName ?? snapshot.matchedExcludedApp?.appContext.displayName
        guard let appName, appName.isEmpty == false else {
            return "Excluded App Active"
        }

        return "Excluded in \(appName)"
    }

    private func excludedPrimaryHint(for snapshot: ExclusionsPauseSnapshot) -> String {
        switch snapshot.capturePolicyDecision {
        case .ignoreBecauseExcludedApp:
            return "Capture ignored for this app"
        case .ignoreBecausePaused:
            return pausePrimaryHint(for: snapshot)
        case .allow:
            return snapshot.behaviorSettings.hidePopupInsideExcludedApps
                ? "Popup hides in excluded apps"
                : "Popup still shows in excluded apps"
        }
    }

    private func excludedSecondaryHint(for snapshot: ExclusionsPauseSnapshot) -> String {
        if snapshot.behaviorSettings.hidePopupInsideExcludedApps {
            return "Hide popup is on"
        }

        return "Hide popup is off"
    }

    private func relativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
