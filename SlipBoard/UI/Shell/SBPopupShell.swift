import SwiftUI

// Native SwiftUI `Menu` popups don't reliably show inside the app's
// borderless `.nonactivatingPanel` popup window, so the header's dropdown
// controls use this hand-rolled overlay state instead (same reasoning as
// the existing custom SBContextMenuShell/SBPasteTransformMenuShell overlays).
enum SBHeaderMenuKind: Equatable {
    case overflow
    case source
}

/// Shared timing for popup motion.
enum SBMotion {
    static let menu = Animation.easeOut(duration: 0.14)
    static let rail = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let list = Animation.easeOut(duration: 0.22)
    static let listTransition = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .offset(x: 16)),
        removal: .opacity
    )

    static func menuTransition(anchor: UnitPoint) -> AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96, anchor: anchor))
    }
}

enum SBPopupLayoutMetrics {
    /// Width of a clip card when the pinned rail is open.
    static let cardWidth: CGFloat = 216
    static let expandedContentHeight: CGFloat = 430
    static let pinnedCollapsedHeightReduction: CGFloat = 93
    /// Transparent room around a glass shell so the borderless panel does not
    /// clip its shadow and rim into square corners. Bottom stays below the
    /// Dock reveal inset.
    static let glassShellMargin = EdgeInsets(top: 32, leading: 32, bottom: 12, trailing: 32)

    static func contentHeight(isPinnedCollapsed: Bool) -> CGFloat {
        expandedContentHeight - (isPinnedCollapsed ? pinnedCollapsedHeightReduction : 0)
    }
}

struct SBPopupShellFrame<Content: View>: View {
    let theme: SBTheme
    let contentHeight: CGFloat
    @ViewBuilder var content: Content

    init(
        theme: SBTheme,
        contentHeight: CGFloat = SBPopupLayoutMetrics.expandedContentHeight,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.contentHeight = contentHeight
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        // The hosting panel may reserve transparent space above this surface
        // while an action menu is open. Keep the visible shell at its normal
        // height so that spare area becomes real overlay headroom instead of
        // stretching the rails.
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: contentHeight, alignment: .topLeading)
        .sbSurface(.popup, theme: theme)
    }
}

struct SBPopupTopBar: View {
    let theme: SBTheme
    let filters: [PopupFilterOption]
    let state: PopupShellViewState
    @SBLocalizedCopy private var copy
    var isSearchEnabled: Bool = true
    var searchFocusRequestToken: Int = 0
    var onSearchQueryChange: (String) -> Void = { _ in }
    var onSelectFilter: (String) -> Void = { _ in }
    var onSelectSource: (String?) -> Void = { _ in }
    var onSelectThemePreview: (PopupThemeSelection) -> Void = { _ in }
    var onPauseCapture: () -> Void = {}
    var onClearHistory: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}
    @Binding var activeMenu: SBHeaderMenuKind?

    @State private var searchText: String
    /// Queries handed to `onSearchQueryChange` whose results have not come
    /// back yet, oldest first. The last one is the query last sent.
    @State private var sentSearchQueries: [String]
    @State private var pendingSearch: Task<Void, Never>?

    /// Each query reprojects and redraws the whole list, so typing only
    /// searches once the keys stop for this long.
    private static let searchDebounce: Duration = .milliseconds(200)

    init(
        theme: SBTheme,
        filters: [PopupFilterOption],
        state: PopupShellViewState,
        isSearchEnabled: Bool = true,
        searchFocusRequestToken: Int = 0,
        activeMenu: Binding<SBHeaderMenuKind?>,
        onSearchQueryChange: @escaping (String) -> Void = { _ in },
        onSelectFilter: @escaping (String) -> Void = { _ in },
        onSelectSource: @escaping (String?) -> Void = { _ in },
        onSelectThemePreview: @escaping (PopupThemeSelection) -> Void = { _ in },
        onPauseCapture: @escaping () -> Void = {},
        onClearHistory: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.theme = theme
        self.filters = filters
        self.state = state
        self.isSearchEnabled = isSearchEnabled
        self.searchFocusRequestToken = searchFocusRequestToken
        _activeMenu = activeMenu
        self.onSearchQueryChange = onSearchQueryChange
        self.onSelectFilter = onSelectFilter
        self.onSelectSource = onSelectSource
        self.onSelectThemePreview = onSelectThemePreview
        self.onPauseCapture = onPauseCapture
        self.onClearHistory = onClearHistory
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        _searchText = State(initialValue: state.searchQuery)
        _sentSearchQueries = State(initialValue: [state.searchQuery])
    }

    var body: some View {
        HStack(spacing: theme.spacing.control8) {
            SBSearchFieldShell(
                text: $searchText,
                theme: theme,
                isPresented: state.isSearchPresented,
                placeholder: copy.text(.searchPlaceholder),
                trailingHint: "ESC",
                focusRequestToken: searchFocusRequestToken,
                collapsesWhenHidden: false
            )
            .disabled(isSearchEnabled == false)
            .opacity(isSearchEnabled ? 1 : 0.55)

            SBUtilityDropdown(
                label: copy.text(.commonSource),
                selectionText: sourceSelectionText,
                options: sourceMenuOptions,
                theme: theme,
                isEnabled: isSearchEnabled,
                isOpen: activeMenu == .source,
                optionLabel: { $0.label },
                optionIcon: { AnyView(sourceMenuIcon($0)) },
                isOptionSelected: { $0.id == (state.activeSourceID ?? "") },
                buttonWidth: 170,
                maxVisibleRows: 6,
                onToggle: { toggleMenu(.source) },
                action: { option in
                    onSelectSource(option.id.isEmpty ? nil : option.id)
                    activeMenu = nil
                }
            )
            // Its popout drops over the chips to its right.
            .zIndex(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.control6) {
                    ForEach(filters) { filter in
                        SBFilterChip(
                            title: filter.label,
                            systemImage: filter.iconName,
                            countText: filter.count.map(String.init),
                            theme: theme,
                            isSelected: filter.id == state.activeFilterID,
                            tintColor: SBClipTypeColor.base(forFilterID: filter.id),
                            action: {
                                onSelectFilter(filter.id)
                            }
                        )
                        .disabled(isSearchEnabled == false)
                        .opacity(isSearchEnabled ? 1 : 0.55)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: theme.spacing.control8)

            HStack(spacing: 4) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)

                Text(copy.text(.appName))
                    .font(theme.typography.chip)
            }
            .foregroundStyle(theme.palette.textSecondary)
            .fixedSize()

            overflowMenu
        }
        .padding(.horizontal, theme.spacing.popupPadding)
        .padding(.vertical, 15)
        .animation(SBMotion.menu, value: activeMenu)
        .background(SBPopupToolbarBackground(theme: theme))
        .background {
            // The open menu sits above the clip list through this view's zIndex,
            // so a clear layer behind the header (still above the list) catches
            // the click that should dismiss it.
            if activeMenu != nil {
                Color.clear
                    .frame(width: 4000, height: 4000)
                    .contentShape(Rectangle())
                    .onTapGesture { activeMenu = nil }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.palette.border)
                .frame(height: theme.border.hairline)
        }
        .onChange(of: searchText) { _, newValue in
            pendingSearch?.cancel()
            pendingSearch = nil
            guard newValue != sentSearchQueries.last else { return }
            // Clearing the field shows the full list at once.
            guard newValue.isEmpty == false else {
                sendSearchQuery(newValue)
                return
            }
            pendingSearch = Task { @MainActor in
                try? await Task.sleep(for: Self.searchDebounce)
                guard Task.isCancelled == false else { return }
                sendSearchQuery(newValue)
            }
        }
        .onChange(of: state.searchQuery) { _, newValue in
            // A query this field sent comes back with its results, possibly
            // after more keys were typed; copying it back would undo them.
            if let index = sentSearchQueries.firstIndex(of: newValue) {
                sentSearchQueries.removeFirst(index)
                return
            }
            // Set by the runtime (type-to-search, clearing on close).
            pendingSearch?.cancel()
            pendingSearch = nil
            sentSearchQueries = [newValue]
            searchText = newValue
        }
    }

    private func sendSearchQuery(_ query: String) {
        pendingSearch = nil
        sentSearchQueries.append(query)
        onSearchQueryChange(query)
    }

    /// "All" first, then each source app with how many clips it has. The "All"
    /// row uses an empty id, which `onSelectSource` turns back into `nil`.
    private var sourceMenuOptions: [SBUtilityDropdownOption] {
        guard state.sourceOptions.isEmpty == false else { return [] }
        // The list is capped, so the total comes from the "All" type filter.
        let total = filters.first(where: { $0.id == "all" })?.count ?? 0
        let all = SBUtilityDropdownOption(id: "", label: "\(copy.text(.commonAll)) (\(total))")
        // The selected app goes right under "All" so it is always in view.
        let ordered = state.sourceOptions.filter { $0.id == state.activeSourceID }
            + state.sourceOptions.filter { $0.id != state.activeSourceID }
        return [all] + ordered.map {
            SBUtilityDropdownOption(id: $0.id, label: "\($0.label) (\($0.count))")
        }
    }

    @ViewBuilder
    private func sourceMenuIcon(_ option: SBUtilityDropdownOption) -> some View {
        if option.id.isEmpty {
            Image(systemName: "square.stack")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.palette.textSecondary)
                .frame(width: 16, height: 16)
        } else {
            SBSourceAppAvatar(appID: option.id, symbolName: nil, accentToken: "accent.primary", theme: theme, size: 16)
        }
    }

    private var sourceSelectionText: String {
        state.sourceOptions.first(where: { $0.id == state.activeSourceID })?.label ?? copy.text(.commonAll)
    }

    private func toggleMenu(_ kind: SBHeaderMenuKind) {
        activeMenu = activeMenu == kind ? nil : kind
    }

    private var overflowMenu: some View {
        Button {
            toggleMenu(.overflow)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.palette.textSecondary)
                .frame(width: 32, height: 32)
                .background(theme.palette.subpanel.opacity(theme.headerControlFillOpacity))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(theme.palette.borderStrong, lineWidth: theme.border.hairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copy.text(.accessibilityMoreActions))
        .overlay(alignment: .topTrailing) {
            if activeMenu == .overflow {
                overflowMenuContent
                    .offset(y: 34)
                    .transition(SBMotion.menuTransition(anchor: .topTrailing))
            }
        }
    }

    private var overflowMenuContent: some View {
        SBOverlayMenuShell(
            theme: theme,
            width: 220,
            actions: overflowActions,
            onSelectAction: handleOverflowAction
        ) {
            VStack(spacing: 0) {
                ForEach(PopupAppearance.allCases) { appearance in
                    themeMenuRow(
                        title: appearanceLabel(for: appearance),
                        isSelected: appearance == state.themePreview.appearance
                    ) {
                        var selection = state.themePreview
                        selection.appearance = appearance
                        onSelectThemePreview(selection)
                    }
                }

                Rectangle()
                    .fill(theme.palette.border)
                    .frame(height: theme.border.hairline)
                    .padding(.vertical, 3)

                ForEach(SBThemeRegistry.themes) { definition in
                    themeMenuRow(
                        title: definition.name(in: copy.currentLanguage),
                        isSelected: definition.id == state.themePreview.themeID
                    ) {
                        var selection = state.themePreview
                        selection.themeID = definition.id
                        onSelectThemePreview(selection)
                    }
                }

                Rectangle()
                    .fill(theme.palette.border)
                    .frame(height: theme.border.hairline)
                    .padding(.top, 3)
            }
            .padding(.top, theme.spacing.control6)
        }
    }

    private var overflowActions: [SBOverlayMenuAction] {
        [
            SBOverlayMenuAction(id: "pause", title: copy.text(.menuPauseCapture), symbolName: "pause.circle"),
            SBOverlayMenuAction(id: "clear-history", title: copy.text(.menuClearHistory), symbolName: "trash", tone: .danger),
            SBOverlayMenuAction(id: "settings", title: copy.text(.menuSettings), symbolName: "gearshape"),
            SBOverlayMenuAction(id: "quit", title: copy.text(.menuQuit), symbolName: "power")
        ]
    }

    private func handleOverflowAction(_ actionID: String) {
        activeMenu = nil
        switch actionID {
        case "pause":
            onPauseCapture()
        case "clear-history":
            onClearHistory()
        case "settings":
            onOpenSettings()
        case "quit":
            onQuit()
        default:
            break
        }
    }

    private func themeMenuRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            activeMenu = nil
        } label: {
            HStack(spacing: theme.spacing.control8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? theme.palette.accentPrimary : theme.palette.textTertiary)

                Text(title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.control12)
            .padding(.vertical, theme.spacing.control6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func appearanceLabel(for appearance: PopupAppearance) -> String {
        switch appearance {
        case .system:
            return copy.text(.menuAppearanceAuto)
        case .dark:
            return copy.text(.menuAppearanceDark)
        case .light:
            return copy.text(.menuAppearanceLight)
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
    /// Whether the popup panel is on screen; header menus close with it.
    var isPresented: Bool = true
    var onSearchQueryChange: (String) -> Void = { _ in }
    var onSelectFilter: (String) -> Void = { _ in }
    var onSelectSource: (String?) -> Void = { _ in }
    var onSelectThemePreview: (PopupThemeSelection) -> Void = { _ in }
    var onPauseCapture: () -> Void = {}
    var onClearHistory: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}
    var onSelectClip: (String) -> Void = { _ in }
    var onToggleNoteEditor: (String) -> Void = { _ in }
    var onUpdateNoteDraft: (String, String) -> Void = { _, _ in }
    var onSaveNoteDraft: (String) -> Void = { _ in }
    var onCancelNoteEditing: (String) -> Void = { _ in }
    var onPrimaryAction: (String) -> Void = { _ in }
    var onOpenContextMenu: (String) -> Void = { _ in }
    var onPerformContextAction: (String) -> Void = { _ in }
    var onHighlightContextAction: (String) -> Void = { _ in }
    var onOpenPasteTransformMenu: (String, PasteActionID) -> Void = { _, _ in }
    var onHighlightTransformAction: (PasteActionID) -> Void = { _ in }
    var onSelectTransformAction: (PasteActionID) -> Void = { _ in }
    var onConfirmTransformAction: () -> Void = {}
    var onCloseActiveOverlay: () -> Void = {}
    var isPinnedCollapsed: Bool = false
    var onTogglePinnedCollapsed: () -> Void = {}

    @State private var activeHeaderMenu: SBHeaderMenuKind? = nil

    private static let recentCardWidth: CGFloat = SBPopupLayoutMetrics.cardWidth
    private static let recentCardWidthPinnedCollapsed: CGFloat = 264
    private static let recentCardHeight: CGFloat = 148
    private static let recentCardHeightPinnedCollapsed: CGFloat = 190

    private func togglePinnedCollapsed() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            onTogglePinnedCollapsed()
        }
    }

    var body: some View {
        SBPopupShellFrame(
            theme: theme,
            contentHeight: SBPopupLayoutMetrics.contentHeight(isPinnedCollapsed: isPinnedCollapsed)
        ) {
            VStack(spacing: 0) {
                SBPopupTopBar(
                    theme: theme,
                    filters: filters,
                    state: state,
                    isSearchEnabled: isSearchEnabled,
                    searchFocusRequestToken: searchFocusRequestToken,
                    activeMenu: $activeHeaderMenu,
                    onSearchQueryChange: onSearchQueryChange,
                    onSelectFilter: onSelectFilter,
                    onSelectSource: onSelectSource,
                    onSelectThemePreview: onSelectThemePreview,
                    onPauseCapture: onPauseCapture,
                    onClearHistory: onClearHistory,
                    onOpenSettings: onOpenSettings,
                    onQuit: onQuit
                )
                // The header's dropdown popouts render as overlays that
                // visually extend down into this ScrollView's territory;
                // without a higher zIndex, this later sibling would paint
                // (and hit-test) on top of them, per SwiftUI's normal
                // declaration-order stacking.
                .zIndex(1)
                // The panel is only ordered out on close, so its state survives;
                // a menu left open would still be open on the next show.
                .onChange(of: isPresented) { _, isShown in
                    if isShown == false { activeHeaderMenu = nil }
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
                        // Keyed by filter, source and whether a search is
                        // active, so switching any of them crossfades the
                        // whole list instead of cards popping in place. The
                        // ZStack overlaps the outgoing and incoming lists
                        // rather than stacking them.
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: theme.spacing.control8) {
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
                                    isEmphasized: true,
                                    isCollapsed: isPinnedCollapsed,
                                    onToggleCollapse: togglePinnedCollapsed,
                                    onSelectClip: onSelectClip,
                                    onToggleNoteEditor: onToggleNoteEditor,
                                    onUpdateNoteDraft: onUpdateNoteDraft,
                                    onSaveNoteDraft: onSaveNoteDraft,
                                    onCancelNoteEditing: onCancelNoteEditing,
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
                                    cardWidth: isPinnedCollapsed ? Self.recentCardWidthPinnedCollapsed : Self.recentCardWidth,
                                    cardHeight: isPinnedCollapsed ? Self.recentCardHeightPinnedCollapsed : Self.recentCardHeight,
                                    onSelectClip: onSelectClip,
                                    onToggleNoteEditor: onToggleNoteEditor,
                                    onUpdateNoteDraft: onUpdateNoteDraft,
                                    onSaveNoteDraft: onSaveNoteDraft,
                                    onCancelNoteEditing: onCancelNoteEditing,
                                    onPrimaryAction: onPrimaryAction,
                                    onOpenContextMenu: onOpenContextMenu,
                                    onPerformContextAction: onPerformContextAction
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            // Inside the ZStack the rails were handed the
                            // viewport height and the pinned rail grew, pushing
                            // the recent cards past the bottom edge.
                            .fixedSize(horizontal: false, vertical: true)
                            .id(listTransitionKey)
                            .transition(SBMotion.listTransition)
                        }
                    }
                    .animation(SBMotion.list, value: listTransitionKey)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .overlayPreferenceValue(SBClipCardAnchorPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                if pasteOverlayState.isPresented {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onCloseActiveOverlay)
                        .zIndex(0)
                }

                if showContextOverlay {
                    SBContextMenuShell(
                        theme: theme,
                        highlightedActionID: contextHighlightedActionID,
                        isPinned: selectedClip?.isPinned == true,
                        clipKind: selectedClip?.kind,
                        onSelectAction: onPerformContextAction,
                        onHoverAction: { actionID in
                            guard let actionID else { return }
                            onHighlightContextAction(actionID)
                        }
                    )
                    .offset(contextMenuOffset(in: proxy, anchors: anchors))
                    .transition(SBMotion.menuTransition(anchor: .top))
                    .zIndex(1)
                }

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
                    .offset(pasteTransformMenuOffset(in: proxy, anchors: anchors))
                    .transition(SBMotion.menuTransition(anchor: .bottom))
                    .zIndex(1)
                }
            }
            .animation(SBMotion.menu, value: showContextOverlay)
            .animation(SBMotion.menu, value: showPasteOverlay)
            }
        }
    }

    // Starting or clearing a search also swaps the list. Updated in place,
    // clearing a search put hundreds of cards back into the rail, and the
    // lazy stack built every card up to where the old results moved to
    // (about 0.5 s with 700 clips); a new list only builds what is on screen.
    private var listTransitionKey: String {
        let isSearching = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return "\(state.activeFilterID)|\(state.activeSourceID ?? "")|\(isSearching)"
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

    private func contextMenuOffset(
        in proxy: GeometryProxy,
        anchors: [String: Anchor<CGRect>]
    ) -> CGSize {
        let menuWidth: CGFloat = 220
        let menuHeight: CGFloat = 238
        let gap: CGFloat = 8
        let rect = anchoredClipRect(in: proxy, anchors: anchors)
        let x = rect.maxX + menuWidth + gap <= proxy.size.width
            ? rect.maxX + gap
            : max(gap, rect.minX - menuWidth - gap)
        let y = min(max(gap, rect.minY), max(gap, proxy.size.height - menuHeight - gap))
        return CGSize(width: x, height: y)
    }

    private func pasteTransformMenuOffset(
        in proxy: GeometryProxy,
        anchors: [String: Anchor<CGRect>]
    ) -> CGSize {
        let menuWidth: CGFloat = 260
        let menuHeight: CGFloat = 412
        let gap: CGFloat = 10
        let rect = anchoredClipRect(in: proxy, anchors: anchors)
        let x = rect.maxX + menuWidth + gap <= proxy.size.width
            ? rect.maxX + gap
            : max(gap, rect.minX - menuWidth - gap)
        // The expanded panel gives this negative offset room to render above
        // the normal popup surface rather than clipping at its top edge.
        let y = max(-menuHeight + gap, rect.maxY - menuHeight)
        return CGSize(width: x, height: y)
    }

    private func anchoredClipRect(
        in proxy: GeometryProxy,
        anchors: [String: Anchor<CGRect>]
    ) -> CGRect {
        guard let anchorClipID = pasteOverlayState.anchorClipID,
              let anchor = anchors[anchorClipID] else {
            return CGRect(x: theme.spacing.popupPadding, y: 42, width: SBPopupLayoutMetrics.cardWidth, height: 148)
        }

        return proxy[anchor]
    }
}


private struct SBLockedPopupStateCard: View {
    let theme: SBTheme
    let snapshot: SecurityRuntimeSnapshot
    @SBLocalizedCopy private var copy

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
                    title: copy.text(.securityProtectedStorageUnavailable),
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
            return copy.text(.popupLockTitleLocked)
        case .unlocking:
            return copy.text(.popupLockTitleUnlocking)
        case .unlockFailed:
            return copy.text(.popupLockTitleFailed)
        case .unlocked:
            return copy.text(.popupLockTitleUnlocked)
        }
    }

    private var detailText: String {
        if let failure = snapshot.lastFailure {
            return failure.detailText
        }

        switch snapshot.lockState {
        case .locked:
            return copy.text(.popupLockDetailLocked)
        case .unlocking:
            return copy.text(.popupLockDetailUnlocking)
        case .unlockFailed:
            return copy.text(.popupLockDetailFailed)
        case .unlocked:
            return copy.text(.popupLockDetailUnlocked)
        }
    }

    private var hintText: String {
        switch snapshot.lockState {
        case .locked:
            return copy.text(.popupLockHintLocked)
        case .unlocking:
            return copy.text(.popupLockHintUnlocking)
        case .unlockFailed:
            return copy.text(.popupLockHintFailed)
        case .unlocked:
            return copy.text(.popupLockHintUnlocked)
        }
    }

    private var footerStatusText: String {
        switch snapshot.lockState {
        case .locked:
            return copy.text(.locked)
        case .unlocking:
            return copy.text(.securityUnlocking)
        case .unlockFailed:
            return copy.text(.securityUnlockFailed)
        case .unlocked:
            return copy.text(.unlocked)
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
