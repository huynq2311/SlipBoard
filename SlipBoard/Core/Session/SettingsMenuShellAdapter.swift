import Foundation

struct SettingsMenuShellAdapter: MenuBarSessionProviding {
    let initialPreset: SettingsMenuShellPreset
    private let sessionProvider: SlipBoardSessionProviding?

    init(
        initialPreset: SettingsMenuShellPreset = .settingsDemo,
        sessionProvider: SlipBoardSessionProviding? = nil
    ) {
        self.initialPreset = initialPreset
        self.sessionProvider = sessionProvider
    }

    func initialSettingsMenuShellSnapshot() -> SettingsMenuShellSnapshot {
        guard let sessionProvider else {
            return fixtureSettingsMenuShellSnapshot(named: initialPreset)
        }

        return adaptedSnapshot(from: sessionProvider.initialSession())
    }

    func fixtureSettingsMenuShellSnapshot(named preset: SettingsMenuShellPreset) -> SettingsMenuShellSnapshot {
        SettingsMenuShellFixtures.snapshot(named: preset)
    }

    func adaptedSnapshot(
        from session: SlipBoardAppSession,
        fallbackPreset: SettingsMenuShellPreset? = nil
    ) -> SettingsMenuShellSnapshot {
        let preset = fallbackPreset ?? SettingsMenuShellProjection.suggestedPreset(for: session)
        let baseSnapshot = fixtureSettingsMenuShellSnapshot(named: preset)
        let selectedTab = SettingsMenuShellProjection.selectedTab(from: session)
        let lastOpenedTab = SettingsMenuShellProjection.lastOpenedTab(from: session)
        let quickRetentionSelection = SettingsMenuShellProjection.quickRetentionSelection(
            from: session.settings.retention.retentionWindow.value
        ) ?? SettingsMenuShellProjection.selectedQuickRetention(in: baseSnapshot.menuBar)
        let pauseSelection = SettingsMenuShellProjection.pauseSelection(
            isStartPaused: session.settings.general.startPaused.isOn,
            fallback: SettingsMenuShellProjection.selectedPauseCapture(in: baseSnapshot.menuBar)
        )

        return SettingsMenuShellProjection.materializeSnapshot(
            baseSnapshot: baseSnapshot,
            selectedTab: selectedTab,
            lastOpenedTab: lastOpenedTab,
            itemCount: session.clipboard.totalCount,
            quickRetentionSelection: quickRetentionSelection,
            pauseSelection: pauseSelection
        )
    }

    func makeReducer() -> SettingsMenuShellReducer {
        SettingsMenuShellReducer(snapshot: initialSettingsMenuShellSnapshot())
    }

    func makeReducer(from session: SlipBoardAppSession) -> SettingsMenuShellReducer {
        SettingsMenuShellReducer(snapshot: adaptedSnapshot(from: session))
    }

    func makeMenuBarReducer(
        from session: SlipBoardAppSession,
        fallbackPreset: SettingsMenuShellPreset? = nil
    ) -> MenuBarSessionReducer {
        MenuBarSessionReducer(snapshot: adaptedSnapshot(from: session, fallbackPreset: fallbackPreset).menuBar)
    }
}

enum SettingsMenuShellProjection {
    static func suggestedPreset(for session: SlipBoardAppSession) -> SettingsMenuShellPreset {
        if session.clipboard.totalCount == 0 {
            return .empty
        }

        if session.settings.general.startPaused.isOn {
            return .pausedCapture
        }

        return .settingsDemo
    }

    static func selectedTab(from session: SlipBoardAppSession) -> SettingsShellTabID {
        switch session.activeSurface {
        case .popup:
            return shellTab(from: session.settings.selectedTab)
        case let .settings(tab):
            return shellTab(from: tab)
        }
    }

    static func lastOpenedTab(from session: SlipBoardAppSession) -> SettingsShellTabID {
        shellTab(from: session.settings.selectedTab)
    }

    static func shellTab(from tab: SettingsTabID) -> SettingsShellTabID {
        switch tab {
        case .general:
            return .general
        case .bridge:
            return .bridge
        case .retention:
            return .retention
        case .exclusions:
            return .exclusions
        case .hotkeys:
            return .hotkeys
        case .snippets:
            return .snippets
        }
    }

    static func quickRetentionSelection(from value: String) -> QuickRetentionOptionID? {
        switch normalizedToken(from: value) {
        case "7days", "7d":
            return .days7
        case "14days", "14d":
            return .days14
        case "30days", "30d":
            return .days30
        case "90days", "90d":
            return .days90
        case "forever":
            return .forever
        default:
            return nil
        }
    }

    static func pauseSelection(
        isStartPaused: Bool,
        fallback: PauseCaptureOptionID?
    ) -> PauseCaptureOptionID? {
        guard isStartPaused else {
            return nil
        }

        return fallback ?? .hour1
    }

    static func materializeSnapshot(
        baseSnapshot: SettingsMenuShellSnapshot,
        selectedTab: SettingsShellTabID,
        lastOpenedTab: SettingsShellTabID,
        itemCount: Int? = nil,
        quickRetentionSelection: QuickRetentionOptionID? = nil,
        pauseSelection: PauseCaptureOptionID? = nil
    ) -> SettingsMenuShellSnapshot {
        let resolvedQuickRetention = quickRetentionSelection ?? selectedQuickRetention(in: baseSnapshot.menuBar)
        let resolvedPauseSelection = normalizedPauseSelection(pauseSelection)

        return SettingsMenuShellSnapshot(
            selectedTab: selectedTab,
            lastOpenedTab: lastOpenedTab,
            menuBar: materializeMenuBar(
                base: baseSnapshot.menuBar,
                itemCount: itemCount,
                quickRetentionSelection: resolvedQuickRetention,
                pauseSelection: resolvedPauseSelection
            ),
            tabs: baseSnapshot.tabs,
            general: baseSnapshot.general,
            bridge: baseSnapshot.bridge,
            retention: materializeRetentionSummary(
                base: baseSnapshot.retention,
                quickRetentionSelection: resolvedQuickRetention
            ),
            exclusions: baseSnapshot.exclusions,
            hotkeys: baseSnapshot.hotkeys,
            snippets: baseSnapshot.snippets,
            security: baseSnapshot.security
        )
    }

    static func materializeMenuBar(
        base: MenuBarSnapshot,
        itemCount: Int? = nil,
        quickRetentionSelection: QuickRetentionOptionID,
        pauseSelection: PauseCaptureOptionID?
    ) -> MenuBarSnapshot {
        let normalizedPauseSelection = normalizedPauseSelection(pauseSelection)
        let pauseState = pauseState(for: normalizedPauseSelection)

        return MenuBarSnapshot(
            itemCountLabel: itemCount.map(itemCountLabel(for:)) ?? base.itemCountLabel,
            retentionLabel: retentionLabel(for: quickRetentionSelection),
            isCapturePaused: pauseState.isCapturePaused,
            pauseSummary: pauseState.pauseSummary,
            quickRetentionOptions: quickRetentionOptions(
                from: base.quickRetentionOptions,
                selected: quickRetentionSelection
            ),
            pauseOptions: pauseOptions(
                from: base.pauseOptions,
                selected: normalizedPauseSelection,
                resumesAtLabel: pauseState.resumesAtLabel
            )
        )
    }

    static func materializeRetentionSummary(
        base: RetentionSettingsShellSummary,
        quickRetentionSelection: QuickRetentionOptionID
    ) -> RetentionSettingsShellSummary {
        RetentionSettingsShellSummary(
            sections: base.sections.map { section in
                SettingsShellSection(
                    id: section.id,
                    title: section.title,
                    helperText: section.helperText,
                    rows: section.rows.map { row in
                        switch row {
                        case let .segmented(segmentedRow) where isRetentionSegmentedRow(segmentedRow):
                            return .segmented(
                                SettingsShellSegmentedRow(
                                    id: segmentedRow.id,
                                    title: segmentedRow.title,
                                    detail: segmentedRow.detail,
                                    options: segmentedOptions(
                                        from: segmentedRow.options,
                                        quickRetentionSelection: quickRetentionSelection
                                    )
                                )
                            )
                        default:
                            return row
                        }
                    }
                )
            }
        )
    }

    static func selectTab(
        _ tab: SettingsShellTabID,
        in snapshot: SettingsMenuShellSnapshot,
        updateLastOpenedTab: Bool
    ) -> SettingsMenuShellSnapshot {
        SettingsMenuShellSnapshot(
            selectedTab: tab,
            lastOpenedTab: updateLastOpenedTab ? tab : snapshot.lastOpenedTab,
            menuBar: snapshot.menuBar,
            tabs: snapshot.tabs,
            general: snapshot.general,
            bridge: snapshot.bridge,
            retention: snapshot.retention,
            exclusions: snapshot.exclusions,
            hotkeys: snapshot.hotkeys,
            snippets: snapshot.snippets,
            security: snapshot.security
        )
    }

    static func openSettings(from snapshot: SettingsMenuShellSnapshot) -> SettingsMenuShellSnapshot {
        selectTab(snapshot.lastOpenedTab, in: snapshot, updateLastOpenedTab: false)
    }

    static func selectedQuickRetention(in menuBar: MenuBarSnapshot) -> QuickRetentionOptionID {
        menuBar.quickRetentionOptions.first(where: \.isSelected)?.id ?? .forever
    }

    static func selectedPauseCapture(in menuBar: MenuBarSnapshot) -> PauseCaptureOptionID? {
        normalizedPauseSelection(menuBar.pauseOptions.first(where: \.isSelected)?.id)
    }

    private static func itemCountLabel(for itemCount: Int) -> String {
        itemCount == 1 ? "1 item" : "\(itemCount) items"
    }

    private static func retentionLabel(for option: QuickRetentionOptionID) -> String {
        switch option {
        case .days7:
            return "7 Days"
        case .days14:
            return "14 Days"
        case .days30:
            return "30 Days"
        case .days90:
            return "90 Days"
        case .forever:
            return "Forever"
        }
    }

    private static func quickRetentionOptions(
        from options: [QuickRetentionOption],
        selected: QuickRetentionOptionID
    ) -> [QuickRetentionOption] {
        if options.isEmpty {
            return defaultQuickRetentionOptions(selected: selected)
        }

        return options.map { option in
            QuickRetentionOption(
                id: option.id,
                title: option.title,
                isSelected: option.id == selected
            )
        }
    }

    private static func pauseOptions(
        from options: [PauseCaptureOption],
        selected: PauseCaptureOptionID?,
        resumesAtLabel: String?
    ) -> [PauseCaptureOption] {
        let source = options.isEmpty ? defaultPauseOptions : options

        return source.map { option in
            let isSelected = option.id == selected
            return PauseCaptureOption(
                id: option.id,
                title: option.title,
                isSelected: isSelected,
                resumesAtLabel: isSelected ? resumesAtLabel : nil
            )
        }
    }

    private static func segmentedOptions(
        from options: [SettingsShellSegmentOption],
        quickRetentionSelection: QuickRetentionOptionID
    ) -> [SettingsShellSegmentOption] {
        let source = options.isEmpty ? defaultSegmentedOptions : options

        return source.map { option in
            SettingsShellSegmentOption(
                id: option.id,
                title: option.title,
                isSelected: option.id == quickRetentionSelection.rawValue
            )
        }
    }

    private static func isRetentionSegmentedRow(_ row: SettingsShellSegmentedRow) -> Bool {
        row.id == "retention-window-options" || Set(row.options.map(\.id)).isSubset(of: retentionOptionIDs)
    }

    private static func pauseState(for selection: PauseCaptureOptionID?) -> (
        isCapturePaused: Bool,
        pauseSummary: String?,
        resumesAtLabel: String?
    ) {
        switch selection {
        case .minutes15:
            return (true, "Paused for 15 minutes", "Resumes in 15 minutes")
        case .hour1:
            return (true, "Paused for 1 hour", "Resumes in 1 hour")
        case .untilTomorrow:
            return (true, "Paused until tomorrow", "Resumes tomorrow morning")
        case .resume, .none:
            return (false, nil, nil)
        }
    }

    private static func normalizedPauseSelection(_ selection: PauseCaptureOptionID?) -> PauseCaptureOptionID? {
        guard let selection, selection != .resume else {
            return nil
        }

        return selection
    }

    private static func normalizedToken(from value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func defaultQuickRetentionOptions(
        selected: QuickRetentionOptionID
    ) -> [QuickRetentionOption] {
        [
            QuickRetentionOption(id: .days7, title: "7d", isSelected: selected == .days7),
            QuickRetentionOption(id: .days14, title: "14d", isSelected: selected == .days14),
            QuickRetentionOption(id: .days30, title: "30d", isSelected: selected == .days30),
            QuickRetentionOption(id: .days90, title: "90d", isSelected: selected == .days90),
            QuickRetentionOption(id: .forever, title: "Forever", isSelected: selected == .forever)
        ]
    }

    private static let defaultPauseOptions: [PauseCaptureOption] = [
        PauseCaptureOption(id: .minutes15, title: "15 Minutes", isSelected: false, resumesAtLabel: nil),
        PauseCaptureOption(id: .hour1, title: "1 Hour", isSelected: false, resumesAtLabel: nil),
        PauseCaptureOption(id: .untilTomorrow, title: "Until Tomorrow", isSelected: false, resumesAtLabel: nil),
        PauseCaptureOption(id: .resume, title: "Resume", isSelected: false, resumesAtLabel: nil)
    ]

    private static let defaultSegmentedOptions: [SettingsShellSegmentOption] = [
        SettingsShellSegmentOption(id: QuickRetentionOptionID.days7.rawValue, title: "7d", isSelected: false),
        SettingsShellSegmentOption(id: QuickRetentionOptionID.days14.rawValue, title: "14d", isSelected: false),
        SettingsShellSegmentOption(id: QuickRetentionOptionID.days30.rawValue, title: "30d", isSelected: false),
        SettingsShellSegmentOption(id: QuickRetentionOptionID.days90.rawValue, title: "90d", isSelected: false),
        SettingsShellSegmentOption(id: QuickRetentionOptionID.forever.rawValue, title: "Forever", isSelected: false)
    ]

    private static let retentionOptionIDs: Set<String> = Set(QuickRetentionOptionID.allCases.map(\.rawValue))
}
