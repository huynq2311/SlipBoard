import Foundation

struct ClipboardHistoryProjector: ClipboardHistoryProjecting {
    typealias PopupState = PopupShellViewState
    typealias FilterOption = PopupFilterOption
    typealias MenuBarSummary = MenuBarSummaryState

    private let relativeFormatter: RelativeDateTimeFormatter

    init() {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        self.relativeFormatter = formatter
    }

    func project(
        _ snapshot: ClipboardHistorySnapshot,
        retentionSnapshot: RetentionRuntimeSnapshot?,
        searchRuntime: SearchNotesRuntimeProviding? = nil,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot? = nil
    ) -> ClipboardHistoryProjection<PopupShellViewState, PopupFilterOption, MenuBarSummaryState> {
        ClipboardHistoryProjection(
            popupState: projectPopupState(
                snapshot,
                searchRuntime: searchRuntime,
                exclusionsPauseSnapshot: exclusionsPauseSnapshot
            ),
            filterOptions: projectFilterOptions(snapshot),
            menuBarSummary: projectMenuBarSummary(
                snapshot,
                retentionSnapshot: retentionSnapshot,
                searchRuntime: searchRuntime,
                exclusionsPauseSnapshot: exclusionsPauseSnapshot
            )
        )
    }

    func project(
        _ snapshot: ClipboardHistorySnapshot
    ) -> ClipboardHistoryProjection<PopupShellViewState, PopupFilterOption, MenuBarSummaryState> {
        project(snapshot, retentionSnapshot: nil, searchRuntime: nil)
    }

    private func projectPopupState(
        _ snapshot: ClipboardHistorySnapshot,
        searchRuntime: SearchNotesRuntimeProviding?,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot?
    ) -> PopupShellViewState {
        let searchQuery = searchRuntime?.latestProjectionState.searchQuery ?? snapshot.searchQuery
        let isLocked = searchRuntime?.latestProjectionState.lockState == .locked
        let visibleItemIDs = Set(
            searchRuntime?.visibleItemIDs(in: snapshot.allItems, activeFilter: snapshot.activeFilter)
                ?? snapshot.visibleItems.map(\.id)
        )

        return PopupShellViewState(
            selectedClipID: snapshot.selectedItemID,
            searchQuery: searchQuery,
            isSearchPresented: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            activeFilterID: snapshot.activeFilter.id,
            themePreview: .fallback,
            pinnedClips: snapshot.pinnedItems
                .filter { visibleItemIDs.contains($0.id) }
                .map {
                    makeClipPreview(
                        from: $0,
                        protectedPayload: searchRuntime?.protectedPayload(for: $0.id),
                        isLocked: isLocked
                    )
                },
            recentClips: snapshot.recentItems
                .filter { visibleItemIDs.contains($0.id) }
                .map {
                    makeClipPreview(
                        from: $0,
                        protectedPayload: searchRuntime?.protectedPayload(for: $0.id),
                        isLocked: isLocked
                    )
                },
            status: makePopupStatus(
                snapshot,
                searchRuntime: searchRuntime,
                exclusionsPauseSnapshot: exclusionsPauseSnapshot
            )
        )
    }

    private func projectFilterOptions(_ snapshot: ClipboardHistorySnapshot) -> [PopupFilterOption] {
        let counts = Dictionary(grouping: snapshot.allItems, by: \.kind).mapValues(\.count)
        var filters: [ClipboardHistoryFilter] = [.all, .text, .image]

        if (counts[.richText] ?? 0) > 0 {
            filters.append(.richText)
        }

        filters.append(contentsOf: [.code, .file, .url])

        if (counts[.color] ?? 0) > 0 {
            filters.append(.color)
        }

        return filters.map { filter in
            let count: Int
            if filter == .all {
                count = snapshot.totalCount
            } else if let kind = kind(for: filter) {
                count = counts[kind] ?? 0
            } else {
                count = 0
            }

            return PopupFilterOption(
                id: filter.id,
                label: label(for: filter),
                iconName: iconName(for: filter),
                count: count
            )
        }
    }

    private func projectMenuBarSummary(
        _ snapshot: ClipboardHistorySnapshot,
        retentionSnapshot: RetentionRuntimeSnapshot?,
        searchRuntime: SearchNotesRuntimeProviding?,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot?
    ) -> MenuBarSummaryState {
        let selectedPolicy = retentionSnapshot?.retentionSettings.ttlPolicy ?? .oneMonth
        let isLocked = searchRuntime?.latestProjectionState.lockState == .locked
        var commands: [MenuBarCommandRow] = [
            MenuBarCommandRow(
                id: "open-slipboard",
                title: "Open Slipboard",
                symbolName: "menubar.rectangle"
            ),
            MenuBarCommandRow(
                id: "capture-status",
                title: "Capture Status",
                subtitle: captureStatusDetailText(
                    snapshot.captureStatus,
                    exclusionsPauseSnapshot: exclusionsPauseSnapshot
                ),
                symbolName: "waveform",
                accessoryText: snapshot.totalCount == 0 ? "Empty" : "\(snapshot.totalCount)",
                role: .secondary
            ),
            MenuBarCommandRow(
                id: "open-settings",
                title: "Settings…",
                symbolName: "gearshape"
            ),
            MenuBarCommandRow(
                id: "quit-slipboard",
                title: "Quit Slipboard",
                symbolName: "power",
                role: .destructive
            )
        ]

        if let pauseCommand = makePauseCommandRow(exclusionsPauseSnapshot) {
            commands.insert(pauseCommand, at: 2)
        }

        return MenuBarSummaryState(
            itemCount: snapshot.totalCount,
            itemCountLabel: snapshot.totalCount == 1 ? "item" : "items",
            statusLabel: isLocked ? "Locked" : menuBarStatusLabel(
                for: snapshot.captureStatus,
                exclusionsPauseSnapshot: exclusionsPauseSnapshot
            ),
            quickRetentionSelectionID: selectedPolicy.rawValue,
            quickRetentionOptions: RetentionTTLPolicy.allCases.map { policy in
                MenuBarRetentionOption(
                    id: policy.rawValue,
                    label: policy.menuBarLabel,
                    isSelected: policy == selectedPolicy
                )
            },
            commands: commands
        )
    }

    private func makeClipPreview(
        from item: ClipboardHistoryItem,
        protectedPayload: ProtectedClipPayload?,
        isLocked: Bool
    ) -> ClipPreviewSummary {
        let titleText = isLocked
            ? (protectedPayload?.redactedPreviewText ?? "Hidden while SlipBoard is locked")
            : (protectedPayload?.primaryText ?? item.primaryText)
        let bodyText = isLocked
            ? nil
            : (protectedPayload?.secondaryText ?? item.secondaryText)
        let noteText = isLocked ? nil : protectedPayload?.noteText

        return ClipPreviewSummary(
            id: item.id,
            kind: clipKind(for: item.kind),
            titleText: titleText,
            bodyText: bodyText,
            metadataText: item.metadataText,
            isPinned: item.isPinned,
            noteText: noteText,
            sourceApp: ClipSourceAppSummary(
                id: item.sourceApp.bundleID ?? item.sourceApp.displayName,
                displayName: item.sourceApp.displayName,
                symbolName: item.sourceApp.symbolName,
                accentToken: item.sourceApp.accentToken
            ),
            createdLabel: createdLabel(for: item),
            previewStyle: clipPreviewStyle(for: item.previewStyle),
            secondaryBadgeText: item.secondaryBadgeText,
            richTextRTFData: isLocked ? nil : item.richTextRTFData,
            filePaths: isLocked ? [] : item.filePaths
        )
    }

    private func makePopupStatus(
        _ snapshot: ClipboardHistorySnapshot,
        searchRuntime: SearchNotesRuntimeProviding?,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot?
    ) -> PopupStatusSummary {
        if let projectionState = searchRuntime?.latestProjectionState,
           let disabledMessage = projectionState.searchDisabledMessage {
            return PopupStatusSummary(
                statusLabel: disabledMessage.statusLabel,
                statusTone: .locked,
                primaryHint: disabledMessage.title,
                secondaryHint: disabledMessage.detailText,
                itemCountText: projectionState.searchResultCount == 1
                    ? "1 visible"
                    : "\(projectionState.searchResultCount) visible"
            )
        }

        let hasSearchOverlay = {
            guard let projectionState = searchRuntime?.latestProjectionState else {
                return false
            }

            return projectionState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                || projectionState.activeGroupID != .all
        }()

        let visibleCount = searchRuntime?.visibleItemIDs(
            in: snapshot.allItems,
            activeFilter: snapshot.activeFilter
        ).count ?? snapshot.visibleItems.count
        let itemCountText = hasSearchOverlay
            ? (visibleCount == 1 ? "1 result" : "\(visibleCount) results")
            : (snapshot.totalCount == 1 ? "1 item" : "\(snapshot.totalCount) items")

        if let exclusionsPauseStatus = popupStatusOverride(
            from: exclusionsPauseSnapshot,
            itemCountText: itemCountText
        ) {
            return exclusionsPauseStatus
        }

        switch snapshot.captureStatus {
        case .active:
            return PopupStatusSummary(
                statusLabel: "Capture Active",
                statusTone: .success,
                primaryHint: "Return to paste",
                secondaryHint: "Command / to search",
                itemCountText: itemCountText
            )
        case .idleEmpty:
            return PopupStatusSummary(
                statusLabel: "Waiting for Copy",
                statusTone: .normal,
                primaryHint: "Copy something to begin",
                secondaryHint: "Command / to search",
                itemCountText: itemCountText
            )
        case .unsupportedSampleIgnored(let reason, _):
            return PopupStatusSummary(
                statusLabel: "Unsupported Sample Ignored",
                statusTone: .warning,
                primaryHint: reason,
                secondaryHint: "Copy text, image, file, URL, color, or rich text",
                itemCountText: itemCountText
            )
        case .paused(let reason):
            return PopupStatusSummary(
                statusLabel: "Capture Paused",
                statusTone: .paused,
                primaryHint: reason,
                secondaryHint: "Resume monitoring to capture new clips",
                itemCountText: itemCountText
            )
        }
    }

    private func menuBarStatusLabel(
        for status: ClipboardCaptureStatus,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot?
    ) -> String {
        if let exclusionsPauseSnapshot {
            if exclusionsPauseSnapshot.pauseState.isPaused {
                return exclusionsPauseSnapshot.pauseState.resumeAt.map {
                    "Paused until \(relativeFormatter.localizedString(for: $0, relativeTo: Date()))"
                } ?? "Paused until resume"
            }

            if exclusionsPauseSnapshot.isFrontmostAppExcluded {
                let appName = exclusionsPauseSnapshot.frontmostApp?.displayName
                    ?? exclusionsPauseSnapshot.matchedExcludedApp?.appContext.displayName
                    ?? "excluded app"
                return "Excluded in \(appName)"
            }
        }

        switch status {
        case .active(let latestCaptureAt):
            guard let latestCaptureAt else {
                return "Capture Active"
            }
            return "Active \(relativeFormatter.localizedString(for: latestCaptureAt, relativeTo: Date()))"
        case .idleEmpty:
            return "Waiting for Copy"
        case .unsupportedSampleIgnored:
            return "Unsupported Ignored"
        case .paused:
            return "Capture Paused"
        }
    }

    private func captureStatusDetailText(
        _ status: ClipboardCaptureStatus,
        exclusionsPauseSnapshot: ExclusionsPauseSnapshot?
    ) -> String {
        if let exclusionsPauseSnapshot {
            if exclusionsPauseSnapshot.pauseState.isPaused {
                if let resumeAt = exclusionsPauseSnapshot.pauseState.resumeAt {
                    return "Auto-resumes \(relativeFormatter.localizedString(for: resumeAt, relativeTo: Date()))"
                }

                return "Manual pause remains active until you resume."
            }

            if case let .ignoreBecauseExcludedApp(match) = exclusionsPauseSnapshot.capturePolicyDecision {
                return "Capture ignored for \(match.appContext.displayName)."
            }
        }

        return menuBarStatusLabel(for: status, exclusionsPauseSnapshot: nil)
    }

    private func makePauseCommandRow(
        _ exclusionsPauseSnapshot: ExclusionsPauseSnapshot?
    ) -> MenuBarCommandRow? {
        guard let exclusionsPauseSnapshot else {
            return nil
        }

        if exclusionsPauseSnapshot.pauseState.isPaused {
            let subtitle: String
            if let resumeAt = exclusionsPauseSnapshot.pauseState.resumeAt {
                subtitle = "Resumes \(relativeFormatter.localizedString(for: resumeAt, relativeTo: Date()))"
            } else {
                subtitle = "Paused until resume"
            }

            return MenuBarCommandRow(
                id: "pause-capturing",
                title: "Resume Capturing",
                subtitle: subtitle,
                symbolName: "play.circle"
            )
        }

        return MenuBarCommandRow(
            id: "pause-capturing",
            title: "Pause Capturing",
            subtitle: "15 min | 1 hour | Until Resume",
            symbolName: "pause.circle"
        )
    }

    private func popupStatusOverride(
        from exclusionsPauseSnapshot: ExclusionsPauseSnapshot?,
        itemCountText: String
    ) -> PopupStatusSummary? {
        guard let exclusionsPauseSnapshot else {
            return nil
        }

        if exclusionsPauseSnapshot.pauseState.isPaused {
            return PopupStatusSummary(
                statusLabel: "Capture Paused",
                statusTone: .paused,
                primaryHint: pausePrimaryHint(for: exclusionsPauseSnapshot),
                secondaryHint: pauseSecondaryHint(for: exclusionsPauseSnapshot),
                itemCountText: itemCountText
            )
        }

        if exclusionsPauseSnapshot.isFrontmostAppExcluded {
            return PopupStatusSummary(
                statusLabel: excludedStatusLabel(for: exclusionsPauseSnapshot),
                statusTone: .warning,
                primaryHint: excludedPrimaryHint(for: exclusionsPauseSnapshot),
                secondaryHint: excludedSecondaryHint(for: exclusionsPauseSnapshot),
                itemCountText: itemCountText
            )
        }

        return nil
    }

    private func pausePrimaryHint(for snapshot: ExclusionsPauseSnapshot) -> String {
        if let resumeAt = snapshot.pauseState.resumeAt {
            return "Resumes \(relativeFormatter.localizedString(for: resumeAt, relativeTo: Date()))"
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

    private func createdLabel(for item: ClipboardHistoryItem) -> String {
        if item.isPinned {
            return "Pinned"
        }

        return Self.compactRelativeLabel(for: item.lastCopiedAt, relativeTo: Date())
    }

    // Compact, "ago"-free timestamp for card headers (15s / 4m / 2h / Yesterday).
    private static func compactRelativeLabel(for date: Date, relativeTo now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))

        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }

        // Yesterday is at most about two days back, so skip the Calendar
        // lookup for the long tail of older clips.
        if hours < 72, Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }

        let days = hours / 24
        if days < 7 {
            return "\(days)d"
        }

        return monthDayFormatter.string(from: date)
    }

    // Built once: creating a DateFormatter for every old clip on every
    // projection was a large share of the cost of changing the selection.
    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private func clipKind(for kind: ClipboardHistoryKind) -> ClipKind {
        switch kind {
        case .text:
            return .text
        case .code:
            return .code
        case .image:
            return .image
        case .file:
            return .file
        case .url:
            return .url
        case .color:
            return .color
        case .richText:
            return .richText
        }
    }

    private func clipPreviewStyle(for style: ClipboardHistoryPreviewStyle) -> ClipPreviewStyle {
        switch style {
        case .text:
            return .text
        case .code(let languageHint):
            return .code(languageHint: languageHint)
        case .image:
            return .image
        case .file(let fileExtension):
            return .file(fileExtension: fileExtension)
        case .url:
            return .url
        case .color(let swatches):
            return .color(swatches: swatches)
        case .richText:
            return .richText
        }
    }

    private func iconName(for filter: ClipboardHistoryFilter) -> String {
        switch filter {
        case .all:
            return "square.grid.2x2"
        case .text:
            return "text.alignleft"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .image:
            return "photo"
        case .file:
            return "doc"
        case .url:
            return "link"
        case .color:
            return "paintpalette"
        case .richText:
            return "text.badge.star"
        }
    }

    private func label(for filter: ClipboardHistoryFilter) -> String {
        switch filter {
        case .all:
            return "All"
        case .text:
            return "Text"
        case .code:
            return "Code"
        case .image:
            return "Image"
        case .file:
            return "File"
        case .url:
            return "URL"
        case .color:
            return "Color"
        case .richText:
            return "Rich Text"
        }
    }

    private func kind(for filter: ClipboardHistoryFilter) -> ClipboardHistoryKind? {
        switch filter {
        case .all:
            return nil
        case .text:
            return .text
        case .code:
            return .code
        case .image:
            return .image
        case .file:
            return .file
        case .url:
            return .url
        case .color:
            return .color
        case .richText:
            return .richText
        }
    }
}
