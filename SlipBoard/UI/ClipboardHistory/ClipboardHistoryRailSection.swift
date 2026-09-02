import SwiftUI

enum ClipboardHistoryRailKind: String, Identifiable, Hashable {
    case pinned
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinned:
            return "Pinned"
        case .recent:
            return "Recent"
        }
    }

    var symbolName: String {
        switch self {
        case .pinned:
            return "pin.fill"
        case .recent:
            return "clock"
        }
    }
}

struct ClipboardHistoryRailSection: View {
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
    var cardHeight: CGFloat = 128
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
            SBSectionHeader(
                title: kind.title,
                theme: theme,
                symbolName: kind.symbolName
            )
            .padding(.horizontal, theme.spacing.popupPadding)
            .padding(.top, kind == .pinned ? 6 : 3)
            .padding(.bottom, 3)

            if kind == .pinned && displayedClips.isEmpty {
                HStack(spacing: theme.spacing.control6) {
                    Image(systemName: "pin.slash")
                        .font(.system(size: 10, weight: .medium))
                    Text("No pinned clips")
                        .font(theme.typography.meta)
                }
                .foregroundStyle(theme.palette.textTertiary)
                .padding(.horizontal, theme.spacing.popupPadding)
                .padding(.bottom, theme.spacing.control8)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    cardHeight: cardHeight,
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

    private var emptyStateTitle: String {
        if let searchDisabledMessage = resolvedSearchDisabledMessage {
            return searchDisabledMessage.title
        }

        switch kind {
        case .pinned:
            return "No pinned clips"
        case .recent:
            return trimmedSearchQuery.isEmpty ? "Clipboard history is empty" : "No matching clips"
        }
    }

    private var emptyStateDetail: String {
        if let searchDisabledMessage = resolvedSearchDisabledMessage {
            return searchDisabledMessage.detailText
        }

        switch kind {
        case .pinned:
            return filteredStateDetail(
                defaultText: "Pinned items stay visible here so primary references always remain first."
            )
        case .recent:
            return trimmedSearchQuery.isEmpty
                ? "Recent captures will appear here once the runtime begins projecting clipboard activity."
                : filteredStateDetail(
                    defaultText: "Try a broader query or switch the active filter to reveal more results."
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
        let filterText = activeFilterLabel.flatMap { label in
            label.isEmpty ? nil : " filter \(label.lowercased())"
        } ?? ""
        let groupText = activeGroupLabel.flatMap { label in
            label.isEmpty ? nil : " group \(label)"
        } ?? ""

        guard filterText.isEmpty == false || groupText.isEmpty == false else {
            return defaultText
        }

        return "\(defaultText) Current\(filterText)\(groupText)."
    }
}

struct ClipboardHistoryEmptyRailCard: View {
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
            return searchDisabledMessage.title
        }

        switch kind {
        case .pinned:
            return "Pinned rail ready"
        case .recent:
            return hasSearchQuery ? "No results in recent" : "Recent rail waiting"
        }
    }

    private var detailText: String {
        if let searchDisabledMessage {
            return searchDisabledMessage.detailText
        }

        switch kind {
        case .pinned:
            return "Pinned items stay separated from recent history and keep their position when duplicate copies arrive."
        case .recent:
            if hasSearchQuery {
                return "Search is active\(filterSuffix)\(groupSuffix). Clear the query or change filters to restore visible results."
            }

            return "Recent captures remain in a dedicated horizontal rail, even when the live slice has nothing visible yet."
        }
    }

    private var badgeText: String? {
        if searchDisabledMessage != nil {
            return "LOCKED"
        }

        switch kind {
        case .pinned:
            return "PINNED"
        case .recent:
            return hasSearchQuery ? "FILTERED" : "RECENT"
        }
    }

    private var hasSearchQuery: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var filterSuffix: String {
        guard let activeFilterLabel, activeFilterLabel.isEmpty == false else {
            return ""
        }

        return " for \(activeFilterLabel.lowercased())"
    }

    private var groupSuffix: String {
        guard let activeGroupLabel, activeGroupLabel.isEmpty == false else {
            return ""
        }

        return " in \(activeGroupLabel)"
    }
}
