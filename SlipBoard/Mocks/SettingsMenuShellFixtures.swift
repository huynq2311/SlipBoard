import Foundation

struct SettingsMenuShellFixture: Equatable, Sendable {
    let preset: SettingsMenuShellPreset
    let snapshot: SettingsMenuShellSnapshot
}

enum SettingsMenuShellFixtures {
    static let empty = SettingsMenuShellFixture(
        preset: .empty,
        snapshot: SettingsMenuShellSnapshot(
            selectedTab: .general,
            lastOpenedTab: .general,
            menuBar: MenuBarSnapshot(
                itemCountLabel: "0 items",
                retentionLabel: "Forever",
                isCapturePaused: false,
                pauseSummary: nil,
                quickRetentionOptions: quickRetentionOptions(selectedID: .forever),
                pauseOptions: activePauseOptions(selectedID: nil, resumesAtLabel: nil)
            ),
            tabs: defaultTabs,
            general: GeneralSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "general-startup",
                        title: "Startup",
                        helperText: "Shell-only defaults with no system integration.",
                        rows: [
                            .toggle(
                                SettingsShellToggleRow(
                                    id: "launch-at-login",
                                    title: "Launch at Login",
                                    detail: "Disabled until the local shell is wired to system behavior.",
                                    isOn: false
                                )
                            ),
                            .toggle(
                                SettingsShellToggleRow(
                                    id: "start-paused",
                                    title: "Start Paused",
                                    detail: "Keeps the menu bar snapshot static for preview mode.",
                                    isOn: false
                                )
                            )
                        ]
                    ),
                    SettingsShellSection(
                        id: "general-appearance",
                        title: "Appearance",
                        helperText: nil,
                        rows: [
                            .value(
                                SettingsShellValueRow(
                                    id: "appearance-theme",
                                    title: "Theme",
                                    detail: "Matches the current system appearance.",
                                    value: "System"
                                )
                            ),
                            .value(
                                SettingsShellValueRow(
                                    id: "menu-bar-style",
                                    title: "Menu Bar",
                                    detail: "Badge and status indicators remain shell-only.",
                                    value: "Icon Only"
                                )
                            )
                        ]
                    )
                ]
            ),
            bridge: BridgeSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "bridge-status",
                        title: "Bridge",
                        helperText: "The bridge remains informational in this phase.",
                        rows: [
                            .value(
                                SettingsShellValueRow(
                                    id: "bridge-publish-mode",
                                    title: "Publish on Paste",
                                    detail: "Mac history stays local until the user intentionally publishes an item.",
                                    value: "Unavailable"
                                )
                            ),
                            .callout(
                                SettingsShellCalloutRow(
                                    id: "bridge-empty-note",
                                    title: "Bridge is not configured",
                                    message: "Capability work and device sync setup stay out of scope for the shell slice.",
                                    style: .info
                                )
                            )
                        ]
                    )
                ]
            ),
            retention: RetentionSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "retention-window",
                        title: "History",
                        helperText: "Quick controls are local-only and do not touch persistence yet.",
                        rows: [
                            .segmented(
                                SettingsShellSegmentedRow(
                                    id: "retention-window-options",
                                    title: "Keep History",
                                    detail: "Mirrors the quick choices shown in the menu bar shell.",
                                    options: retentionSegments(selectedID: .forever)
                                )
                            ),
                            .toggle(
                                SettingsShellToggleRow(
                                    id: "clear-on-quit",
                                    title: "Clear on Quit",
                                    detail: "Placeholder only; no storage behavior is implemented.",
                                    isOn: false
                                )
                            )
                        ]
                    ),
                    SettingsShellSection(
                        id: "retention-callout",
                        title: "Pinned Items",
                        helperText: nil,
                        rows: [
                            .callout(
                                SettingsShellCalloutRow(
                                    id: "retention-pinned-note",
                                    title: "Pinned items stay visible",
                                    message: "Pinned-item preservation is a shell message only until the local engine foundations land.",
                                    style: .info
                                )
                            )
                        ]
                    )
                ]
            ),
            exclusions: ExclusionsSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "exclusions-apps",
                        title: "Excluded Apps",
                        helperText: "No app exclusions are configured in the minimal fixture.",
                        rows: [
                            .list(
                                SettingsShellListRow(
                                    id: "excluded-apps-list",
                                    title: "Applications",
                                    detail: "Exclude apps from local capture later.",
                                    items: [],
                                    emptyStateTitle: "No excluded apps",
                                    actionTitle: "Add App"
                                )
                            )
                        ]
                    )
                ]
            ),
            hotkeys: HotkeysSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "hotkeys-summary",
                        title: "Hotkeys",
                        helperText: "Summaries only; no registration or recorder behavior exists yet.",
                        rows: [
                            .value(
                                SettingsShellValueRow(
                                    id: "hotkey-popup",
                                    title: "Open Popup",
                                    detail: "Configured later by the hotkeys feature.",
                                    value: "Not configured"
                                )
                            ),
                            .action(
                                SettingsShellActionRow(
                                    id: "hotkey-edit-popup",
                                    title: "Edit Shortcut",
                                    detail: "Shell action placeholder only.",
                                    buttonTitle: "Edit",
                                    role: .quiet,
                                    isEnabled: false
                                )
                            )
                        ]
                    )
                ]
            ),
            snippets: SnippetsSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "snippets-library",
                        title: "Snippets",
                        helperText: "The shell preserves the list shape even when no snippets exist.",
                        rows: [
                            .list(
                                SettingsShellListRow(
                                    id: "snippets-list",
                                    title: "Saved Snippets",
                                    detail: "Editor behavior is deferred to a later slice.",
                                    items: [],
                                    emptyStateTitle: "No snippets saved yet",
                                    actionTitle: "Create Snippet"
                                )
                            )
                        ]
                    )
                ]
            ),
            security: SecuritySettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "security-placeholder",
                        title: "Security",
                        helperText: "Privacy and lock flows stay shell-only here.",
                        rows: [
                            .callout(
                                SettingsShellCalloutRow(
                                    id: "security-phase-note",
                                    title: "Security settings are placeholders",
                                    message: "No authentication, encryption, or Keychain behavior is introduced by this interface task.",
                                    style: .warning
                                )
                            )
                        ]
                    )
                ]
            )
        )
    )

    static let settingsDemo = SettingsMenuShellFixture(
        preset: .settingsDemo,
        snapshot: SettingsMenuShellSnapshot(
            selectedTab: .bridge,
            lastOpenedTab: .retention,
            menuBar: MenuBarSnapshot(
                itemCountLabel: "42 items",
                retentionLabel: "30 Days",
                isCapturePaused: false,
                pauseSummary: nil,
                quickRetentionOptions: quickRetentionOptions(selectedID: .days30),
                pauseOptions: activePauseOptions(selectedID: nil, resumesAtLabel: nil)
            ),
            tabs: defaultTabs,
            general: GeneralSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "general-startup",
                        title: "Startup",
                        helperText: "Matches the approved static settings shell taxonomy.",
                        rows: [
                            .toggle(
                                SettingsShellToggleRow(
                                    id: "launch-at-login",
                                    title: "Launch at Login",
                                    detail: "Starts the menu bar shell when the user session begins.",
                                    isOn: true
                                )
                            ),
                            .toggle(
                                SettingsShellToggleRow(
                                    id: "start-paused",
                                    title: "Start Paused",
                                    detail: "Leave capture live for the demo fixture.",
                                    isOn: false
                                )
                            )
                        ]
                    ),
                    SettingsShellSection(
                        id: "general-appearance",
                        title: "Appearance",
                        helperText: nil,
                        rows: [
                            .value(
                                SettingsShellValueRow(
                                    id: "appearance-theme",
                                    title: "Theme",
                                    detail: "Expresses the current shell presentation only.",
                                    value: "Warm Light"
                                )
                            ),
                            .value(
                                SettingsShellValueRow(
                                    id: "menu-bar-style",
                                    title: "Menu Bar",
                                    detail: "Count badge and pause indicators remain local UI state.",
                                    value: "Icon + Count"
                                )
                            )
                        ]
                    )
                ]
            ),
            bridge: BridgeSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "bridge-summary",
                        title: "Bridge Status",
                        helperText: "The UI explains the privacy-first publish-on-paste direction without enabling capabilities.",
                        rows: [
                            .value(
                                SettingsShellValueRow(
                                    id: "bridge-mode",
                                    title: "Publish Mode",
                                    detail: "Only the item the user pastes would be eligible for bridge handoff later.",
                                    value: "On Demand"
                                )
                            ),
                            .value(
                                SettingsShellValueRow(
                                    id: "bridge-last-publish",
                                    title: "Last Publish",
                                    detail: "Fixture-only status messaging.",
                                    value: "3 minutes ago"
                                )
                            ),
                            .list(
                                SettingsShellListRow(
                                    id: "bridge-devices",
                                    title: "Recent Targets",
                                    detail: "Reachability is informational only in the shell phase.",
                                    items: [
                                        SettingsShellListItem(
                                            id: "device-iphone",
                                            title: "Huyn iPhone",
                                            detail: "Ready for one-shot paste handoff",
                                            symbolName: "iphone",
                                            accessoryLabel: "Online"
                                        ),
                                        SettingsShellListItem(
                                            id: "device-ipad",
                                            title: "Design iPad",
                                            detail: "Offline until unlocked",
                                            symbolName: "ipad",
                                            accessoryLabel: "Offline"
                                        )
                                    ],
                                    emptyStateTitle: "No recent bridge targets",
                                    actionTitle: nil
                                )
                            )
                        ]
                    )
                ]
            ),
            retention: RetentionSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "retention-window",
                        title: "Retention Window",
                        helperText: "The menu bar and settings shell share the same local retention choices.",
                        rows: [
                            .segmented(
                                SettingsShellSegmentedRow(
                                    id: "retention-window-options",
                                    title: "Keep History",
                                    detail: "Static shell values only.",
                                    options: retentionSegments(selectedID: .days30)
                                )
                            ),
                            .slider(
                                SettingsShellSliderRow(
                                    id: "retention-size-limit",
                                    title: "History Limit",
                                    detail: "Illustrative capacity control for the settings shell.",
                                    value: 500,
                                    range: 100...1_000,
                                    step: 100,
                                    valueLabel: "500 items"
                                )
                            ),
                            .toggle(
                                SettingsShellToggleRow(
                                    id: "clear-on-quit",
                                    title: "Clear on Quit",
                                    detail: "This toggle does not affect persistence yet.",
                                    isOn: false
                                )
                            )
                        ]
                    ),
                    SettingsShellSection(
                        id: "retention-pinned",
                        title: "Pinned Item Policy",
                        helperText: nil,
                        rows: [
                            .callout(
                                SettingsShellCalloutRow(
                                    id: "retention-pinned-note",
                                    title: "Pinned items are preserved",
                                    message: "The approved shell communicates that pinned items bypass cleanup once real retention logic exists.",
                                    style: .info
                                )
                            ),
                            .value(
                                SettingsShellValueRow(
                                    id: "retention-cache-summary",
                                    title: "Cache Summary",
                                    detail: "Static preview data only.",
                                    value: "42 local items"
                                )
                            )
                        ]
                    )
                ]
            ),
            exclusions: ExclusionsSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "exclusions-apps",
                        title: "Excluded Apps",
                        helperText: "Shell rows for suppression and exclusions only.",
                        rows: [
                            .list(
                                SettingsShellListRow(
                                    id: "excluded-apps-list",
                                    title: "Applications",
                                    detail: "Apps that should not contribute items to local history.",
                                    items: [
                                        SettingsShellListItem(
                                            id: "app-1password",
                                            title: "1Password",
                                            detail: "Password fields remain excluded",
                                            symbolName: "lock.shield",
                                            accessoryLabel: nil
                                        ),
                                        SettingsShellListItem(
                                            id: "app-terminal",
                                            title: "Terminal",
                                            detail: "Secure sessions can be suppressed",
                                            symbolName: "terminal",
                                            accessoryLabel: nil
                                        )
                                    ],
                                    emptyStateTitle: "No excluded apps",
                                    actionTitle: "Add App"
                                )
                            ),
                            .toggle(
                                SettingsShellToggleRow(
                                    id: "popup-suppression",
                                    title: "Suppress Popup In Excluded Apps",
                                    detail: "Keeps the approved popup shell dependency separate from this interface task.",
                                    isOn: true
                                )
                            )
                        ]
                    )
                ]
            ),
            hotkeys: HotkeysSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "hotkeys-shortcuts",
                        title: "Shortcut Summaries",
                        helperText: "The shell shows intent without implementing global registration.",
                        rows: [
                            .value(
                                SettingsShellValueRow(
                                    id: "hotkey-popup",
                                    title: "Open Popup",
                                    detail: "Later owned by the hotkeys feature.",
                                    value: "Option-Shift-Space"
                                )
                            ),
                            .value(
                                SettingsShellValueRow(
                                    id: "hotkey-quick-paste",
                                    title: "Quick Paste",
                                    detail: "Visible here as placeholder summary only.",
                                    value: "Option-Shift-V"
                                )
                            ),
                            .action(
                                SettingsShellActionRow(
                                    id: "hotkey-edit-popup",
                                    title: "Edit Shortcut",
                                    detail: "Non-destructive shell affordance.",
                                    buttonTitle: "Edit",
                                    role: .quiet,
                                    isEnabled: false
                                )
                            )
                        ]
                    )
                ]
            ),
            snippets: SnippetsSettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "snippets-library",
                        title: "Snippets",
                        helperText: "Preview rows keep the list/editor shell visible without persistence.",
                        rows: [
                            .list(
                                SettingsShellListRow(
                                    id: "snippets-list",
                                    title: "Saved Snippets",
                                    detail: "Fixture-only snippet previews.",
                                    items: [
                                        SettingsShellListItem(
                                            id: "snippet-review-copy",
                                            title: "Review Copy",
                                            detail: "Status update for product review messages",
                                            symbolName: "text.badge.star",
                                            accessoryLabel: "Pinned"
                                        ),
                                        SettingsShellListItem(
                                            id: "snippet-bridge-note",
                                            title: "Bridge Note",
                                            detail: "Explains publish-on-paste behavior",
                                            symbolName: "arrow.triangle.branch",
                                            accessoryLabel: "Recent"
                                        )
                                    ],
                                    emptyStateTitle: "No snippets saved yet",
                                    actionTitle: "New Snippet"
                                )
                            )
                        ]
                    )
                ]
            ),
            security: SecuritySettingsShellSummary(
                sections: [
                    SettingsShellSection(
                        id: "security-summary",
                        title: "Privacy Shell",
                        helperText: "Security stays descriptive until storage/search/security work is approved.",
                        rows: [
                            .toggle(
                                SettingsShellToggleRow(
                                    id: "security-lock-ui",
                                    title: "Lock on Idle",
                                    detail: "Placeholder toggle for shell presentation only.",
                                    isOn: true
                                )
                            ),
                            .value(
                                SettingsShellValueRow(
                                    id: "security-protection-level",
                                    title: "Protection",
                                    detail: "No encryption or Keychain behavior is introduced here.",
                                    value: "Local Preview"
                                )
                            ),
                            .callout(
                                SettingsShellCalloutRow(
                                    id: "security-phase-note",
                                    title: "Security is not active yet",
                                    message: "Authentication, encryption policy, and secure storage remain owned by the later storage and security feature.",
                                    style: .warning
                                )
                            )
                        ]
                    )
                ]
            )
        )
    )

    static let pausedCapture = SettingsMenuShellFixture(
        preset: .pausedCapture,
        snapshot: SettingsMenuShellSnapshot(
            selectedTab: .retention,
            lastOpenedTab: .retention,
            menuBar: MenuBarSnapshot(
                itemCountLabel: "42 items",
                retentionLabel: "30 Days",
                isCapturePaused: true,
                pauseSummary: "Paused for 1 hour",
                quickRetentionOptions: quickRetentionOptions(selectedID: .days30),
                pauseOptions: activePauseOptions(
                    selectedID: .hour1,
                    resumesAtLabel: "Resumes at 2:30 PM"
                )
            ),
            tabs: defaultTabs,
            general: settingsDemo.snapshot.general,
            bridge: settingsDemo.snapshot.bridge,
            retention: settingsDemo.snapshot.retention,
            exclusions: settingsDemo.snapshot.exclusions,
            hotkeys: settingsDemo.snapshot.hotkeys,
            snippets: settingsDemo.snapshot.snippets,
            security: settingsDemo.snapshot.security
        )
    )

    static let all: [SettingsMenuShellFixture] = [
        empty,
        settingsDemo,
        pausedCapture
    ]

    static func fixture(named preset: SettingsMenuShellPreset) -> SettingsMenuShellFixture {
        switch preset {
        case .empty:
            return empty
        case .settingsDemo:
            return settingsDemo
        case .pausedCapture:
            return pausedCapture
        }
    }

    static func snapshot(named preset: SettingsMenuShellPreset) -> SettingsMenuShellSnapshot {
        fixture(named: preset).snapshot
    }

    private static let defaultTabs: [SettingsTabSummary] = [
        SettingsTabSummary(id: .general, title: "General", symbolName: "gearshape"),
        SettingsTabSummary(id: .bridge, title: "Bridge", symbolName: "arrow.triangle.branch"),
        SettingsTabSummary(id: .retention, title: "Retention", symbolName: "clock.arrow.circlepath"),
        SettingsTabSummary(id: .exclusions, title: "Exclusions", symbolName: "hand.raised.slash"),
        SettingsTabSummary(id: .hotkeys, title: "Hotkeys", symbolName: "keyboard"),
        SettingsTabSummary(id: .snippets, title: "Snippets", symbolName: "text.badge.plus"),
        SettingsTabSummary(id: .security, title: "Security", symbolName: "lock.shield")
    ]

    private static func quickRetentionOptions(
        selectedID: QuickRetentionOptionID
    ) -> [QuickRetentionOption] {
        [
            QuickRetentionOption(id: .days7, title: "7d", isSelected: selectedID == .days7),
            QuickRetentionOption(id: .days14, title: "14d", isSelected: selectedID == .days14),
            QuickRetentionOption(id: .days30, title: "30d", isSelected: selectedID == .days30),
            QuickRetentionOption(id: .days90, title: "90d", isSelected: selectedID == .days90),
            QuickRetentionOption(id: .forever, title: "Forever", isSelected: selectedID == .forever)
        ]
    }

    private static func activePauseOptions(
        selectedID: PauseCaptureOptionID?,
        resumesAtLabel: String?
    ) -> [PauseCaptureOption] {
        [
            PauseCaptureOption(
                id: .minutes15,
                title: "15 Minutes",
                isSelected: selectedID == .minutes15,
                resumesAtLabel: selectedID == .minutes15 ? resumesAtLabel : nil
            ),
            PauseCaptureOption(
                id: .hour1,
                title: "1 Hour",
                isSelected: selectedID == .hour1,
                resumesAtLabel: selectedID == .hour1 ? resumesAtLabel : nil
            ),
            PauseCaptureOption(
                id: .untilTomorrow,
                title: "Until Tomorrow",
                isSelected: selectedID == .untilTomorrow,
                resumesAtLabel: selectedID == .untilTomorrow ? resumesAtLabel : nil
            ),
            PauseCaptureOption(
                id: .resume,
                title: "Resume",
                isSelected: selectedID == .resume,
                resumesAtLabel: nil
            )
        ]
    }

    private static func retentionSegments(
        selectedID: QuickRetentionOptionID
    ) -> [SettingsShellSegmentOption] {
        quickRetentionOptions(selectedID: selectedID).map { option in
            SettingsShellSegmentOption(
                id: option.id.rawValue,
                title: option.title,
                isSelected: option.isSelected
            )
        }
    }
}
