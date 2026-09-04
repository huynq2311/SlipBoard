import SwiftUI

struct SBPopupShellFrame<Content: View>: View {
    let theme: SBTheme
    @ViewBuilder var content: Content

    init(theme: SBTheme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sbSurface(.popup, theme: theme)
    }
}

struct SBPopupTopBar: View {
    let theme: SBTheme
    let filters: [PopupFilterOption]
    let state: PopupShellViewState
    var isSearchEnabled: Bool = true
    var searchFocusRequestToken: Int = 0
    var onToggleSearchPresented: (Bool) -> Void = { _ in }
    var onSearchQueryChange: (String) -> Void = { _ in }
    var onSelectFilter: (String) -> Void = { _ in }
    var onSelectThemePreview: (PopupThemePreview) -> Void = { _ in }

    @State private var searchText: String

    init(
        theme: SBTheme,
        filters: [PopupFilterOption],
        state: PopupShellViewState,
        isSearchEnabled: Bool = true,
        searchFocusRequestToken: Int = 0,
        onToggleSearchPresented: @escaping (Bool) -> Void = { _ in },
        onSearchQueryChange: @escaping (String) -> Void = { _ in },
        onSelectFilter: @escaping (String) -> Void = { _ in },
        onSelectThemePreview: @escaping (PopupThemePreview) -> Void = { _ in }
    ) {
        self.theme = theme
        self.filters = filters
        self.state = state
        self.isSearchEnabled = isSearchEnabled
        self.searchFocusRequestToken = searchFocusRequestToken
        self.onToggleSearchPresented = onToggleSearchPresented
        self.onSearchQueryChange = onSearchQueryChange
        self.onSelectFilter = onSelectFilter
        self.onSelectThemePreview = onSelectThemePreview
        _searchText = State(initialValue: state.searchQuery)
    }

    var body: some View {
        HStack(spacing: theme.spacing.control8) {
            SBIconButton(
                symbolName: "magnifyingglass",
                theme: theme,
                isActive: state.isSearchPresented,
                accessibilityLabel: "Search",
                action: {
                    guard isSearchEnabled else { return }
                    onToggleSearchPresented(state.isSearchPresented == false)
                }
            )
            .disabled(isSearchEnabled == false)
            .opacity(isSearchEnabled ? 1 : 0.55)

            SBSearchFieldShell(
                text: $searchText,
                theme: theme,
                isPresented: state.isSearchPresented,
                trailingHint: "ESC",
                focusRequestToken: searchFocusRequestToken
            )
            .disabled(isSearchEnabled == false)
            .opacity(isSearchEnabled ? 1 : 0.55)

            Rectangle()
                .fill(theme.palette.borderStrong)
                .frame(width: theme.border.hairline, height: 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(filters) { filter in
                        SBFilterChip(
                            title: filter.label,
                            systemImage: filter.iconName,
                            countText: filter.count.map(String.init),
                            theme: theme,
                            isSelected: filter.id == state.activeFilterID,
                            action: {
                                onSelectFilter(filter.id)
                            }
                        )
                        .disabled(isSearchEnabled == false)
                        .opacity(isSearchEnabled ? 1 : 0.55)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            SBSegmentedControl(
                options: PopupThemePreview.allCases,
                selection: state.themePreview.id,
                theme: theme,
                label: { _ in "" },
                icon: { $0.segmentIcon },
                action: { previewID in
                    guard let preview = PopupThemePreview(rawValue: previewID) else { return }
                    onSelectThemePreview(preview)
                }
            )
            .frame(width: 96)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Theme")
        }
        .padding(.horizontal, theme.spacing.popupPadding)
        .padding(.vertical, 5)
        .frame(minHeight: 34)
        .background(theme.palette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.palette.border)
                .frame(height: theme.border.hairline)
        }
        .onChange(of: searchText) { _, newValue in
            onSearchQueryChange(newValue)
        }
        .onChange(of: state.searchQuery) { _, newValue in
            if searchText != newValue {
                searchText = newValue
            }
        }
    }
}

struct SBPopupShell: View {
    let theme: SBTheme
    let filters: [PopupFilterOption]
    let state: PopupShellViewState
    var searchNotesState: SearchNotesProjectionState = SearchNotesProjectionState()
    var securitySnapshot: SecurityRuntimeSnapshot? = nil
    var showOverlayPreview: Bool = true
    var pasteOverlayState: PasteActionOverlayState = .hidden
    var supportedTransformActionIDs: Set<PasteActionID> = Set(PasteActionID.transformMenuOrder)
    var searchFocusRequestToken: Int = 0
    var onToggleSearchPresented: (Bool) -> Void = { _ in }
    var onSearchQueryChange: (String) -> Void = { _ in }
    var onSelectFilter: (String) -> Void = { _ in }
    var onSelectThemePreview: (PopupThemePreview) -> Void = { _ in }
    var onSelectOrganizationGroup: (OrganizationGroupID) -> Void = { _ in }
    var onSelectClip: (String) -> Void = { _ in }
    var onToggleNoteEditor: (String) -> Void = { _ in }
    var onUpdateNoteDraft: (String, String) -> Void = { _, _ in }
    var onSaveNoteDraft: (String) -> Void = { _ in }
    var onCancelNoteEditing: (String) -> Void = { _ in }
    var onClearNote: (String) -> Void = { _ in }
    var onPrimaryAction: (String) -> Void = { _ in }
    var onOpenContextMenu: (String) -> Void = { _ in }
    var onPerformContextAction: (String) -> Void = { _ in }
    var onHighlightContextAction: (String) -> Void = { _ in }
    var onOpenPasteTransformMenu: (String, PasteActionID) -> Void = { _, _ in }
    var onHighlightTransformAction: (PasteActionID) -> Void = { _ in }
    var onSelectTransformAction: (PasteActionID) -> Void = { _ in }
    var onConfirmTransformAction: () -> Void = {}
    var onCloseActiveOverlay: () -> Void = {}

    // nil = no manual override yet, follow whether pinned has any clips.
    @State private var manualPinnedCollapsed: Bool? = nil

    private static let recentCardHeight: CGFloat = 148
    private static let recentCardHeightPinnedCollapsed: CGFloat = 260

    private var isPinnedCollapsed: Bool {
        manualPinnedCollapsed ?? state.pinnedClips.isEmpty
    }

    private func togglePinnedCollapsed() {
        manualPinnedCollapsed = !isPinnedCollapsed
    }

    var body: some View {
        SBPopupShellFrame(theme: theme) {
            VStack(spacing: 0) {
                SBPopupTopBar(
                    theme: theme,
                    filters: filters,
                    state: state,
                    isSearchEnabled: isSearchEnabled,
                    searchFocusRequestToken: searchFocusRequestToken,
                    onToggleSearchPresented: onToggleSearchPresented,
                    onSearchQueryChange: onSearchQueryChange,
                    onSelectFilter: onSelectFilter,
                    onSelectThemePreview: onSelectThemePreview
                )

                if searchNotesState.groupChips.isEmpty == false {
                    SearchNotesOrganizationStrip(
                        chips: searchNotesState.groupChips,
                        theme: theme,
                        isEnabled: isSearchEnabled,
                        onSelectGroup: onSelectOrganizationGroup
                    )
                }

                if let securitySnapshot, securitySnapshot.lockState.revealsProtectedContent == false {
                    SBLockedPopupStateCard(
                        theme: theme,
                        snapshot: securitySnapshot
                    )
                    .padding(.horizontal, theme.spacing.popupPadding)
                    .padding(.vertical, theme.spacing.control12)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ClipboardHistoryRailSection(
                                kind: .pinned,
                                clips: state.pinnedClips,
                                theme: theme,
                                selectedClipID: state.selectedClipID,
                                searchQuery: state.searchQuery,
                                activeFilterLabel: activeFilterLabel,
                                activeGroupLabel: activeGroupLabel,
                                noteEditorState: searchNotesState.activeEditor,
                                searchDisabledMessage: searchNotesState.searchDisabledMessage,
                                isCollapsed: isPinnedCollapsed,
                                onToggleCollapse: togglePinnedCollapsed,
                                onSelectClip: onSelectClip,
                                onToggleNoteEditor: onToggleNoteEditor,
                                onUpdateNoteDraft: onUpdateNoteDraft,
                                onSaveNoteDraft: onSaveNoteDraft,
                                onCancelNoteEditing: onCancelNoteEditing,
                                onClearNote: onClearNote,
                                onPrimaryAction: onPrimaryAction,
                                onOpenContextMenu: onOpenContextMenu,
                                onPerformContextAction: onPerformContextAction
                            )

                            ClipboardHistoryRailSection(
                                kind: .recent,
                                clips: state.recentClips,
                                theme: theme,
                                selectedClipID: state.selectedClipID,
                                searchQuery: state.searchQuery,
                                activeFilterLabel: activeFilterLabel,
                                activeGroupLabel: activeGroupLabel,
                                noteEditorState: searchNotesState.activeEditor,
                                searchDisabledMessage: searchNotesState.searchDisabledMessage,
                                cardHeight: isPinnedCollapsed ? Self.recentCardHeightPinnedCollapsed : Self.recentCardHeight,
                                onSelectClip: onSelectClip,
                                onToggleNoteEditor: onToggleNoteEditor,
                                onUpdateNoteDraft: onUpdateNoteDraft,
                                onSaveNoteDraft: onSaveNoteDraft,
                                onCancelNoteEditing: onCancelNoteEditing,
                                onClearNote: onClearNote,
                                onPrimaryAction: onPrimaryAction,
                                onOpenContextMenu: onOpenContextMenu,
                                onPerformContextAction: onPerformContextAction
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .overlay {
            if pasteOverlayState.isPresented {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onCloseActiveOverlay)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showContextOverlay {
                SBContextMenuShell(
                    theme: theme,
                    highlightedActionID: contextHighlightedActionID,
                    isPinned: selectedClip?.isPinned == true,
                    onSelectAction: onPerformContextAction,
                    onHoverAction: { actionID in
                        guard let actionID else { return }
                        onHighlightContextAction(actionID)
                    }
                )
                    .offset(x: 18, y: 118)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showPasteOverlay {
                SBPasteTransformMenuShell(
                    theme: theme,
                    highlightedActionID: transformHighlightedActionID,
                    previewState: pasteOverlayState.preview,
                    supportedActionIDs: supportedTransformActionIDs,
                    isExecuting: pasteOverlayState.isExecuting,
                    onHighlightAction: onHighlightTransformAction,
                    onSelectAction: onSelectTransformAction,
                    onConfirm: onConfirmTransformAction,
                    onCancel: onCloseActiveOverlay
                )
                    .offset(x: -24, y: -22)
            }
        }
    }

    private var activeFilterLabel: String? {
        filters.first(where: { $0.id == state.activeFilterID })?.label
    }

    private var activeGroupLabel: String? {
        searchNotesState.groupChips.first(where: { $0.groupID == searchNotesState.activeGroupID })?.label
    }

    private var showContextOverlay: Bool {
        if isLocked {
            return false
        }

        if pasteOverlayState.isPresented {
            return pasteOverlayState.kind == .contextMenu
        }

        if let activeOverlay = state.activeOverlay {
            return activeOverlay.kind == .contextMenu
        }

        return showOverlayPreview
    }

    private var showPasteOverlay: Bool {
        if isLocked {
            return false
        }

        if pasteOverlayState.isPresented {
            return pasteOverlayState.kind == .pasteTransformMenu
        }

        if let activeOverlay = state.activeOverlay {
            return activeOverlay.kind == .pasteTransformMenu
        }

        return showOverlayPreview
    }

    private var selectedClip: ClipPreviewSummary? {
        state.allClips.first(where: { $0.id == state.selectedClipID })
    }

    private var contextHighlightedActionID: String? {
        guard case let .contextCommand(actionID)? = pasteOverlayState.highlightedTarget else {
            return state.activeOverlay?.highlightedRowID ?? "paste"
        }

        return actionID
    }

    private var transformHighlightedActionID: String? {
        guard case let .action(actionID)? = pasteOverlayState.highlightedTarget else {
            return state.activeOverlay?.highlightedRowID ?? PasteActionID.plainText.id
        }

        return actionID.id
    }

    private var isLocked: Bool {
        guard let securitySnapshot else { return false }
        return securitySnapshot.lockState.revealsProtectedContent == false
    }

    private var isSearchEnabled: Bool {
        searchNotesState.isSearchEnabled && isLocked == false
    }
}

private struct SearchNotesOrganizationStrip: View {
    let chips: [OrganizationChipSummary]
    let theme: SBTheme
    var isEnabled: Bool = true
    let onSelectGroup: (OrganizationGroupID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(chips) { chip in
                    OrganizationChipButton(
                        chip: chip,
                        theme: theme,
                        isEnabled: isEnabled,
                        action: {
                            onSelectGroup(chip.groupID)
                        }
                    )
                }
            }
            .padding(.horizontal, theme.spacing.popupPadding)
            .padding(.vertical, 8)
        }
        .background(theme.palette.panel)
        .opacity(isEnabled ? 1 : 0.55)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.palette.border)
                .frame(height: theme.border.hairline)
        }
    }
}

private struct OrganizationChipButton: View {
    let chip: OrganizationChipSummary
    let theme: SBTheme
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.control4) {
                if let accentToken = chip.accentToken, chip.isSystem == false {
                    Circle()
                        .fill(theme.accent(for: accentToken))
                        .frame(width: 6, height: 6)
                }

                Text(chip.label)
                    .font(theme.typography.chip)
                    .lineLimit(1)

                SBCountBadge(
                    text: String(chip.count),
                    theme: theme,
                    tone: chip.isSelected ? resolvedTone : .neutral,
                    compact: true
                )
            }
            .foregroundStyle(chip.isSelected ? theme.accent(for: resolvedTone) : theme.palette.textSecondary)
            .padding(.horizontal, theme.spacing.control10)
            .padding(.vertical, theme.spacing.control4)
            .background(chip.isSelected ? theme.accentBackground(for: resolvedTone) : theme.palette.subpanel)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        chip.isSelected ? theme.accent(for: resolvedTone) : theme.palette.border,
                        lineWidth: theme.border.hairline
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(chip.isDisabled || isEnabled == false)
        .opacity(chip.isDisabled || isEnabled == false ? 0.45 : 1)
    }

    private var resolvedTone: SBAccentTone {
        if chip.isSystem {
            return .primary
        }

        switch chip.accentToken {
        case "accent.success":
            return .success
        case "accent.warning":
            return .warning
        case "accent.info":
            return .info
        case "accent.danger":
            return .danger
        default:
            return .primary
        }
    }
}

private struct SBLockedPopupStateCard: View {
    let theme: SBTheme
    let snapshot: SecurityRuntimeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control10) {
            HStack(alignment: .top, spacing: theme.spacing.control10) {
                lockAvatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(theme.typography.paneTitle)
                        .foregroundStyle(theme.palette.textPrimary)

                    Text(detailText)
                        .font(theme.typography.rowSecondary)
                        .foregroundStyle(theme.palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: theme.spacing.control10)
            }

            HStack(spacing: theme.spacing.control8) {
                SBStatusPill(
                    title: footerStatusText,
                    theme: theme,
                    tone: statusTone
                )

                Text(hintText)
                    .font(theme.typography.meta)
                    .foregroundStyle(theme.palette.textTertiary)
                    .lineLimit(1)
            }

            if let failureText {
                SBSecurityStatusCallout(
                    theme: theme,
                    title: "Protected content unavailable",
                    detailText: failureText,
                    symbolName: "exclamationmark.lock.fill",
                    tone: .danger
                )
            }
        }
        .padding(theme.spacing.control12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.subpanel)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous)
                .stroke(borderColor, lineWidth: theme.border.hairline)
        )
    }

    private var lockAvatar: some View {
        Circle()
            .fill(theme.accentBackground(for: statusTone))
            .frame(width: 36, height: 36)
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accent(for: statusTone))
            }
    }

    private var titleText: String {
        switch snapshot.lockState {
        case .locked:
            return "SlipBoard is locked"
        case .unlocking:
            return "Unlocking SlipBoard"
        case .unlockFailed:
            return "SlipBoard stayed locked"
        case .unlocked:
            return "SlipBoard is unlocked"
        }
    }

    private var detailText: String {
        if let failure = snapshot.lastFailure {
            return failure.detailText
        }

        switch snapshot.lockState {
        case .locked:
            return "Previews and search stay hidden inside this popup until you unlock from the menu or Security settings."
        case .unlocking:
            return "SlipBoard is waiting for the current system authentication step to complete before showing protected content."
        case .unlockFailed:
            return "Protected previews remain hidden after the last unlock attempt. Retry from the menu bar or open Security settings."
        case .unlocked:
            return "Protected content is visible."
        }
    }

    private var hintText: String {
        switch snapshot.lockState {
        case .locked:
            return "Unlock from menu or settings"
        case .unlocking:
            return "Waiting for system auth"
        case .unlockFailed:
            return "Retry unlock from menu"
        case .unlocked:
            return "Protected content visible"
        }
    }

    private var footerStatusText: String {
        switch snapshot.lockState {
        case .locked:
            return "Locked"
        case .unlocking:
            return "Unlocking"
        case .unlockFailed:
            return "Unlock failed"
        case .unlocked:
            return "Unlocked"
        }
    }

    private var statusTone: SBAccentTone {
        switch snapshot.lockState {
        case .locked:
            return .danger
        case .unlocking:
            return .warning
        case .unlockFailed:
            return .danger
        case .unlocked:
            return .success
        }
    }

    private var symbolName: String {
        switch snapshot.lockState {
        case .locked:
            return "lock.fill"
        case .unlocking:
            return "lock.rotation"
        case .unlockFailed:
            return "exclamationmark.lock.fill"
        case .unlocked:
            return "lock.open.fill"
        }
    }

    private var borderColor: Color {
        theme.accent(for: statusTone).opacity(theme.mode == .dark ? 0.42 : 0.24)
    }

    private var failureText: String? {
        guard case let .failed(failure) = snapshot.migrationState else {
            return snapshot.lastFailure?.detailText
        }

        return failure.detailText
    }
}

private extension PopupThemePreview {
    var segmentLabel: String {
        switch self {
        case .system:
            return "Auto"
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        }
    }

    var segmentIcon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .dark:
            return "moon.fill"
        case .light:
            return "sun.max.fill"
        }
    }
}

private struct SBOverlayPreviewShell: View {
    let theme: SBTheme
    let width: CGFloat
    let headerTitle: String?
    let headerPreview: String?
    let rows: [SBOverlayPreviewRow]
    let footerHint: String?
    let footerActionTitle: String?

    var body: some View {
        VStack(spacing: 0) {
            if let headerTitle {
                VStack(alignment: .leading, spacing: theme.spacing.control8) {
                    Text(headerTitle)
                        .font(theme.typography.uppercaseLabel)
                        .foregroundStyle(theme.palette.textTertiary)

                    if let headerPreview {
                        Text(headerPreview)
                            .font(theme.typography.monoMeta)
                            .foregroundStyle(theme.palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(theme.spacing.control8)
                            .sbSurface(.raised, theme: theme)
                    }
                }
                .padding(.horizontal, theme.spacing.control12)
                .padding(.top, theme.spacing.control10)
                .padding(.bottom, theme.spacing.control8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.palette.border)
                        .frame(height: theme.border.hairline)
                }
            }

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    SBListRow(
                        title: row.title,
                        detailText: row.subtitle,
                        accessoryText: row.shortcut,
                        badgeText: nil,
                        symbolName: row.symbolName,
                        theme: theme,
                        tone: row.tone,
                        isHighlighted: row.isHighlighted
                    )
                }
            }
            .padding(.vertical, 4)

            if footerHint != nil || footerActionTitle != nil {
                HStack(spacing: theme.spacing.control8) {
                    if let footerHint {
                        HStack(spacing: theme.spacing.control4) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(theme.palette.textTertiary)

                            Text(footerHint)
                                .font(theme.typography.meta)
                                .foregroundStyle(theme.palette.textTertiary)
                        }
                    }

                    Spacer(minLength: theme.spacing.control8)

                    if let footerActionTitle {
                        Text(footerActionTitle)
                            .font(theme.typography.chip)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, theme.spacing.control10)
                            .padding(.vertical, theme.spacing.control6)
                            .background(theme.palette.accentPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .padding(.horizontal, theme.spacing.control12)
                .padding(.vertical, theme.spacing.control8)
                .background(theme.palette.canvas)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.palette.border)
                        .frame(height: theme.border.hairline)
                }
            }
        }
        .frame(width: width, alignment: .topLeading)
        .sbSurface(.overlay, theme: theme)
    }

    static func context(theme: SBTheme) -> SBOverlayPreviewShell {
        SBOverlayPreviewShell(
            theme: theme,
            width: 220,
            headerTitle: nil,
            headerPreview: nil,
            rows: [
                SBOverlayPreviewRow(title: "Paste", subtitle: nil, symbolName: "doc.on.clipboard", shortcut: "↩", tone: .neutral, isHighlighted: true),
                SBOverlayPreviewRow(title: "Paste As…", subtitle: "Open transform menu shell", symbolName: "arrowshape.turn.up.right", shortcut: "⌘↩", tone: .neutral, isHighlighted: false),
                SBOverlayPreviewRow(title: "Copy Again", subtitle: nil, symbolName: "square.on.square", shortcut: "⌘C", tone: .neutral, isHighlighted: false),
                SBOverlayPreviewRow(title: "Pin Item", subtitle: nil, symbolName: "pin", shortcut: "⌘P", tone: .neutral, isHighlighted: false),
                SBOverlayPreviewRow(title: "Delete", subtitle: nil, symbolName: "trash", shortcut: "⌫", tone: .danger, isHighlighted: false)
            ],
            footerHint: nil,
            footerActionTitle: nil
        )
    }

    static func paste(theme: SBTheme) -> SBOverlayPreviewShell {
        SBOverlayPreviewShell(
            theme: theme,
            width: 260,
            headerTitle: "Paste As…",
            headerPreview: "Authorization: Bearer <token>\nX-Client: slipboard",
            rows: [
                SBOverlayPreviewRow(title: "Plain Text", subtitle: "Remove rich formatting", symbolName: "textformat", shortcut: "↵", tone: .primary, isHighlighted: true),
                SBOverlayPreviewRow(title: "Convert to Markdown", subtitle: "Map clipboard text into markdown-friendly output", symbolName: "chevron.left.forwardslash.chevron.right", shortcut: "⌘1", tone: .neutral, isHighlighted: false),
                SBOverlayPreviewRow(title: "Strip Unicode / Accent", subtitle: "Normalize special characters for plain transport", symbolName: "eraser", shortcut: "⌘2", tone: .neutral, isHighlighted: false),
                SBOverlayPreviewRow(title: "UPPERCASE", subtitle: "Convert output to upper case", symbolName: "textformat.size.larger", shortcut: "⌘3", tone: .neutral, isHighlighted: false)
            ],
            footerHint: "ESC cancel",
            footerActionTitle: "Paste"
        )
    }
}

private struct SBOverlayPreviewRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let symbolName: String
    let shortcut: String?
    let tone: SBAccentTone
    let isHighlighted: Bool
}
