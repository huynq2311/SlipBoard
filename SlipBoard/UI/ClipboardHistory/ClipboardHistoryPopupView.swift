import AppKit
import SwiftUI

struct ClipboardHistoryPopupView: View {
    @SBLocalizedCopy private var copy
    @Environment(\.sbLocalizationLanguage) private var localizationLanguage

    let theme: SBTheme
    let filters: [PopupFilterOption]
    let state: PopupShellViewState
    var exclusionsPauseSnapshot: ExclusionsPauseSnapshot? = nil
    var searchNotesState: SearchNotesProjectionState = SearchNotesProjectionState()
    var securitySnapshot: SecurityRuntimeSnapshot? = nil
    var showOverlayPreview: Bool = false
    var pasteOverlayState: PasteActionOverlayState = .hidden
    var supportedTransformActionIDs: Set<PasteActionID> = Set(PasteActionID.transformMenuOrder)
    var searchFocusRequestToken: Int = 0
    var isPresented: Bool = true
    var onToggleSearchPresented: (Bool) -> Void = { _ in }
    var onSearchQueryChange: (String) -> Void = { _ in }
    var onSelectFilter: (String) -> Void = { _ in }
    var onSelectSource: (String?) -> Void = { _ in }
    var onSelectThemePreview: (PopupThemeSelection) -> Void = { _ in }
    var onPauseCapture: () -> Void = {}
    var onClearHistory: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}
    var onSelectClipID: (String?) -> Void = { _ in }
    var onMoveSelection: (Int) -> Void = { _ in }
    var onDeleteSelectedClip: () -> Void = {}
    var onToggleNoteEditor: (String) -> Void = { _ in }
    var onUpdateNoteDraft: (String, String) -> Void = { _, _ in }
    var onSaveNoteDraft: (String) -> Void = { _ in }
    var onCancelNoteEditing: (String) -> Void = { _ in }
    var onOpenContextMenu: (String) -> Void = { _ in }
    var onOpenPasteTransformMenu: (String, PasteActionID) -> Void = { _, _ in }
    var onCloseActiveOverlay: () -> Void = {}
    var onHighlightContextAction: (String) -> Void = { _ in }
    var onPerformContextAction: (String) -> Void = { _ in }
    var onHighlightTransformAction: (PasteActionID) -> Void = { _ in }
    var onSelectTransformAction: (PasteActionID) -> Void = { _ in }
    var onExecutePasteAction: (PasteActionID, PasteActionCloseBehavior) -> Void = { _, _ in }
    var isPinnedCollapsed: Bool = false
    var onTogglePinnedCollapsed: () -> Void = {}
    var onPlacePinnedClip: (String, String?) -> Void = { _, _ in }
    var onPlaceRecentClip: (String, String?) -> Void = { _, _ in }
    var dragPasteboardWriter: (String) -> NSPasteboardWriting? = { _ in nil }

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
            searchFocusRequestToken: searchFocusRequestToken,
            isPresented: isPresented,
            onSearchQueryChange: onSearchQueryChange,
            onSelectFilter: onSelectFilter,
            onSelectSource: onSelectSource,
            onSelectThemePreview: onSelectThemePreview,
            onPauseCapture: onPauseCapture,
            onClearHistory: onClearHistory,
            onOpenSettings: onOpenSettings,
            onQuit: onQuit,
            onSelectClip: { clipID in
                onSelectClipID(clipID)
            },
            onToggleNoteEditor: onToggleNoteEditor,
            onUpdateNoteDraft: onUpdateNoteDraft,
            onSaveNoteDraft: onSaveNoteDraft,
            onCancelNoteEditing: onCancelNoteEditing,
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
            onCloseActiveOverlay: onCloseActiveOverlay,
            isPinnedCollapsed: isPinnedCollapsed,
            onTogglePinnedCollapsed: onTogglePinnedCollapsed,
            onPlacePinnedClip: onPlacePinnedClip,
            onPlaceRecentClip: onPlaceRecentClip,
            dragPasteboardWriter: dragPasteboardWriter
        )
        .focusable()
        .focusEffectDisabled()
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
        redacted.titleText = copy.text(.popupPreviewHidden)
        redacted.bodyText = copy.text(.clipRedactionPrivacy)
        redacted.noteText = nil
        redacted.secondaryBadgeText = localizedUppercase(copy.text(.popupPrivate))
        return redacted
    }

    private func popupStatus(baseStatus: PopupStatusSummary) -> PopupStatusSummary {
        guard let exclusionsPauseSnapshot else { return baseStatus }

        if exclusionsPauseSnapshot.pauseState.isPaused {
            return PopupStatusSummary(
                statusLabel: copy.text(.statusCapturePaused),
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
            return copy.text(.statusResumes, ["value": relativeTimestamp(for: resumeAt)])
        }

        return snapshot.activePauseLabel ?? copy.text(.statusResumeFromMenu)
    }

    private func pauseSecondaryHint(for snapshot: ExclusionsPauseSnapshot) -> String {
        if let activePauseLabel = snapshot.activePauseLabel {
            return copy.text(.statusPauseMode, ["value": activePauseLabel])
        }

        return copy.text(.statusResumeFromMenu)
    }

    private func excludedStatusLabel(for snapshot: ExclusionsPauseSnapshot) -> String {
        let appName = snapshot.frontmostApp?.displayName ?? snapshot.matchedExcludedApp?.appContext.displayName
        guard let appName, appName.isEmpty == false else {
            return copy.text(.statusExcludedAppActive)
        }

        return copy.text(.statusExcludedIn, ["app": appName])
    }

    private func excludedPrimaryHint(for snapshot: ExclusionsPauseSnapshot) -> String {
        switch snapshot.capturePolicyDecision {
        case .ignoreBecauseExcludedApp:
            return copy.text(.statusCaptureIgnoredThisApp)
        case .ignoreBecausePaused:
            return pausePrimaryHint(for: snapshot)
        case .allow:
            return snapshot.behaviorSettings.hidePopupInsideExcludedApps
                ? copy.text(.statusPopupHidesInExcludedApps)
                : copy.text(.statusPopupShowsInExcludedApps)
        }
    }

    private func excludedSecondaryHint(for snapshot: ExclusionsPauseSnapshot) -> String {
        if snapshot.behaviorSettings.hidePopupInsideExcludedApps {
            return copy.text(.statusHidePopupOn)
        }

        return copy.text(.statusHidePopupOff)
    }

    private func relativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: localizationLanguage.localeIdentifier)
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func localizedUppercase(_ value: String) -> String {
        value.uppercased(with: Locale(identifier: localizationLanguage.localeIdentifier))
    }
}
