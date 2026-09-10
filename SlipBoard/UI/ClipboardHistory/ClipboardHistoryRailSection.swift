import SwiftUI

enum ClipboardHistoryRailKind: String, Identifiable, Hashable {
    case pinned
    case recent

    var id: String { rawValue }

    var titleKey: LocalizationKey {
        switch self {
        case .pinned:
            return .popupPinned
        case .recent:
            return .popupRecent
        }
    }

    var symbolName: String {
        switch self {
        case .pinned:
            return "star.fill"
        case .recent:
            return "clock"
        }
    }
}

struct ClipboardHistoryRailSection: View {
    @SBLocalizedCopy private var copy

    let kind: ClipboardHistoryRailKind
    let clips: [ClipPreviewSummary]
    let theme: SBTheme
    var selectedClipID: String?
    var securitySnapshot: SecurityRuntimeSnapshot? = nil
    var searchQuery: String = ""
    var activeFilterLabel: String? = nil
    var activeGroupLabel: String? = nil
    var noteEditorState: ClipNoteEditorState? = nil
    var searchDisabledMessage: SearchDisabledMessage? = nil
    var cardWidth: CGFloat = 216
    var cardHeight: CGFloat = 128
    var isEmphasized: Bool = false
    var isCollapsed: Bool = false
    var onToggleCollapse: () -> Void = {}
    var onSelectClip: (String) -> Void = { _ in }
    var onToggleNoteEditor: (String) -> Void = { _ in }
    var onUpdateNoteDraft: (String, String) -> Void = { _, _ in }
    var onSaveNoteDraft: (String) -> Void = { _ in }
    var onCancelNoteEditing: (String) -> Void = { _ in }
    var onClearNote: (String) -> Void = { _ in }
    var onPrimaryAction: (String) -> Void = { _ in }
    var onOpenContextMenu: (String) -> Void = { _ in }
    var onPerformContextAction: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.spacing.control8) {
                SBSectionHeader(
                    title: copy.text(kind.titleKey),
                    theme: theme,
                    symbolName: kind.symbolName,
                    countText: String(clips.count),
                    isEmphasized: isEmphasized,
                    style: .popup,
                    disclosureSymbolName: kind == .pinned ? (isCollapsed ? "chevron.right" : "chevron.down") : nil,
                    disclosureAccessibilityLabel: kind == .pinned
                        ? copy.text(isCollapsed ? .popupShowPinned : .popupHidePinned)
                        : nil,
                    onDisclosure: kind == .pinned ? onToggleCollapse : nil
                )
            }
            .padding(.horizontal, theme.spacing.popupPadding)
            .padding(.top, kind == .pinned ? 6 : 4)
            .padding(.bottom, 2)

            if isCollapsed == false {
                if kind == .pinned && displayedClips.isEmpty {
                    HStack(spacing: theme.spacing.control6) {
                        Image(systemName: "pin.slash")
                            .font(.system(size: 10, weight: .medium))
                        Text(copy.text(.popupNoPinnedClips))
                            .font(theme.typography.meta)
                    }
                    .foregroundStyle(theme.palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, theme.spacing.popupPadding)
                    .frame(height: cardHeight + 7, alignment: .center)
                } else if displayedClips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacing.railGap) {
                            ClipboardHistoryEmptyRailCard(
                                kind: kind,
                                theme: theme,
                                searchQuery: searchQuery,
                                activeFilterLabel: activeFilterLabel,
                                activeGroupLabel: activeGroupLabel,
                                searchDisabledMessage: resolvedSearchDisabledMessage
                            )
                            .frame(width: 220, alignment: .leading)
                        }
                        .padding(.horizontal, theme.spacing.popupPadding)
                        .padding(.top, 6)
                        .padding(.bottom, theme.spacing.section16)
                    }
                } else {
                    SBHorizontalClipRail(
                        clips: displayedClips,
                        theme: theme,
                        emptyTitle: emptyStateTitle,
                        emptyDetail: emptyStateDetail,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        reservesScrollbarTrack: kind == .recent,
                        selectedClipID: selectedClipID,
                        securitySnapshot: securitySnapshot,
                        onSelectClip: onSelectClip,
                        noteEditorState: noteEditorState,
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
            }
        }
    }

    private var emptyStateTitle: String {
        if let searchDisabledMessage = resolvedSearchDisabledMessage {
            return localizedSearchDisabledTitle(searchDisabledMessage)
        }

        switch kind {
        case .pinned:
            return copy.text(.popupNoPinnedClips)
        case .recent:
            return copy.text(trimmedSearchQuery.isEmpty ? .popupHistoryEmpty : .popupNoMatchingClips)
        }
    }

    private var emptyStateDetail: String {
        if let searchDisabledMessage = resolvedSearchDisabledMessage {
            return localizedSearchDisabledDetail(searchDisabledMessage)
        }

        switch kind {
        case .pinned:
            return filteredStateDetail(
                defaultText: copy.text(.popupPinnedEmptyDetail)
            )
        case .recent:
            return trimmedSearchQuery.isEmpty
                ? copy.text(.popupRecentEmptyDetail)
                : filteredStateDetail(
                    defaultText: copy.text(.popupNoMatchDetail)
                )
        }
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedClips: [ClipPreviewSummary] {
        if resolvedSearchDisabledMessage != nil {
            return []
        }

        return clips
    }

    private var resolvedSearchDisabledMessage: SearchDisabledMessage? {
        if let searchDisabledMessage {
            return searchDisabledMessage
        }

        guard securitySnapshot?.lockState.revealsProtectedContent == false else {
            return nil
        }

        return .lockedDefault
    }

    private func filteredStateDetail(defaultText: String) -> String {
        let filter = activeFilterLabel.flatMap { $0.isEmpty ? nil : $0 }
        let group = activeGroupLabel.flatMap { $0.isEmpty ? nil : $0 }

        let context: String?
        switch (filter, group) {
        case let (.some(filter), .some(group)):
            context = copy.text(.popupCurrentFilterAndGroup, ["filter": filter, "group": group])
        case let (.some(filter), .none):
            context = copy.text(.popupCurrentFilter, ["filter": filter])
        case let (.none, .some(group)):
            context = copy.text(.popupCurrentGroup, ["group": group])
        case (.none, .none):
            context = nil
        }

        return context.map { "\(defaultText) \($0)" } ?? defaultText
    }

    private func localizedSearchDisabledTitle(_ message: SearchDisabledMessage) -> String {
        switch message.reason {
        case .locked:
            return copy.text(.popupSearchLockedTitle)
        }
    }

    private func localizedSearchDisabledDetail(_ message: SearchDisabledMessage) -> String {
        switch message.reason {
        case .locked:
            return copy.text(.popupSearchLockedDetail)
        }
    }
}

struct ClipboardHistoryEmptyRailCard: View {
    @SBLocalizedCopy private var copy
    @Environment(\.sbLocalizationLanguage) private var localizationLanguage

    let kind: ClipboardHistoryRailKind
    let theme: SBTheme
    var searchQuery: String = ""
    var activeFilterLabel: String? = nil
    var activeGroupLabel: String? = nil
    var searchDisabledMessage: SearchDisabledMessage? = nil

    var body: some View {
        SBEmptyStateCard(
            title: title,
            detailText: detailText,
            theme: theme,
            badgeText: badgeText
        )
    }

    private var title: String {
        if let searchDisabledMessage {
            return localizedSearchDisabledTitle(searchDisabledMessage)
        }

        switch kind {
        case .pinned:
            return copy.text(.popupPinnedRailReady)
        case .recent:
            return copy.text(hasSearchQuery ? .popupNoResultsInRecent : .popupRecentRailWaiting)
        }
    }

    private var detailText: String {
        if let searchDisabledMessage {
            return localizedSearchDisabledDetail(searchDisabledMessage)
        }

        switch kind {
        case .pinned:
            return copy.text(.popupPinnedRailDetail)
        case .recent:
            if hasSearchQuery {
                return copy.text(.popupRecentSearchDetail, ["context": searchContext])
            }

            return copy.text(.popupRecentRailDetail)
        }
    }

    private var badgeText: String? {
        if searchDisabledMessage != nil {
            return localizedUppercase(copy.text(.popupLocked))
        }

        switch kind {
        case .pinned:
            return localizedUppercase(copy.text(.popupPinned))
        case .recent:
            return localizedUppercase(copy.text(hasSearchQuery ? .popupFiltered : .popupRecent))
        }
    }

    private var hasSearchQuery: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var searchContext: String {
        let filter = activeFilterLabel.flatMap { $0.isEmpty ? nil : $0 }
        let group = activeGroupLabel.flatMap { $0.isEmpty ? nil : $0 }

        switch (filter, group) {
        case let (.some(filter), .some(group)):
            return "; " + copy.text(.popupCurrentFilterAndGroup, ["filter": filter, "group": group])
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        case let (.some(filter), .none):
            return "; " + copy.text(.popupCurrentFilter, ["filter": filter])
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        case let (.none, .some(group)):
            return "; " + copy.text(.popupCurrentGroup, ["group": group])
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        case (.none, .none):
            return ""
        }
    }

    private func localizedSearchDisabledTitle(_ message: SearchDisabledMessage) -> String {
        switch message.reason {
        case .locked:
            return copy.text(.popupSearchLockedTitle)
        }
    }

    private func localizedSearchDisabledDetail(_ message: SearchDisabledMessage) -> String {
        switch message.reason {
        case .locked:
            return copy.text(.popupSearchLockedDetail)
        }
    }

    private func localizedUppercase(_ value: String) -> String {
        value.uppercased(with: Locale(identifier: localizationLanguage.localeIdentifier))
    }
}
