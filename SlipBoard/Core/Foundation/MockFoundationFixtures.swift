import Foundation

enum MockFoundationFixtures {
    static let popupFilterOptions: [PopupFilterOption] = [
        PopupFilterOption(id: "all", label: "All", iconName: "square.grid.2x2", count: 6),
        PopupFilterOption(id: "text", label: "Text", iconName: "text.alignleft", count: 2),
        PopupFilterOption(id: "code", label: "Code", iconName: "chevron.left.forwardslash.chevron.right", count: 1),
        PopupFilterOption(id: "image", label: "Image", iconName: "photo", count: 1),
        PopupFilterOption(id: "file", label: "File", iconName: "doc", count: 1),
        PopupFilterOption(id: "url", label: "URL", iconName: "link", count: 1)
    ]

    static let popupShellState = PopupShellViewState(
        selectedClipID: "clip.code.headers",
        searchQuery: "",
        isSearchPresented: false,
        activeFilterID: "all",
        themePreview: .fallback,
        pinnedClips: pinnedClips,
        recentClips: recentClips,
        status: PopupStatusSummary(
            statusLabel: "Capture Active",
            statusTone: .success,
            primaryHint: "Return to paste",
            secondaryHint: "Command / to search",
            itemCountText: "847 items"
        )
    )

    static let menuBarSummaryState = MenuBarSummaryState(
        itemCount: 847,
        itemCountLabel: "items",
        statusLabel: "Retention 30d",
        quickRetentionSelectionID: "30d",
        quickRetentionOptions: [
            MenuBarRetentionOption(id: "7d", label: "7d"),
            MenuBarRetentionOption(id: "14d", label: "14d"),
            MenuBarRetentionOption(id: "30d", label: "30d", isSelected: true),
            MenuBarRetentionOption(id: "90d", label: "90d"),
            MenuBarRetentionOption(id: "forever", label: "∞")
        ],
        commands: [
            MenuBarCommandRow(
                id: "open-slipboard",
                title: "Open Slipboard",
                symbolName: "menubar.rectangle",
                shortcutLabel: "⌘⇧V"
            ),
            MenuBarCommandRow(
                id: "pause-capturing",
                title: "Pause Capturing",
                subtitle: "15 minutes, 1 hour, until tomorrow",
                symbolName: "pause.circle",
                accessoryText: "›",
                role: .secondary
            ),
            MenuBarCommandRow(
                id: "open-settings",
                title: "Settings…",
                symbolName: "gearshape",
                shortcutLabel: "⌘,"
            ),
            MenuBarCommandRow(
                id: "quit-slipboard",
                title: "Quit Slipboard",
                symbolName: "power",
                shortcutLabel: "⌘Q",
                role: .destructive
            )
        ],
        highlightedCommandID: "open-slipboard"
    )

    static let settingsShellState = SettingsShellState(
        selectedSection: .general,
        general: generalPane,
        retention: retentionPane,
        exclusions: exclusionsPane,
        hotkeys: hotkeysPane,
        snippets: snippetsPane,
        security: securityPane,
        bridge: bridgePane
    )

    static let pinnedClips: [ClipPreviewSummary] = [
        ClipPreviewSummary(
            id: "clip.code.headers",
            kind: .code,
            titleText: "Authorization headers",
            bodyText: "curl -H \"Authorization: Bearer …\"",
            metadataText: "Swift · API helper",
            isPinned: true,
            noteText: "Pinned for weekly backend QA handoff.",
            sourceApp: ClipSourceAppSummary(
                id: "com.microsoft.VSCode",
                displayName: "VS Code",
                symbolName: "chevron.left.forwardslash.chevron.right",
                accentToken: "accent.info"
            ),
            createdLabel: "Pinned",
            previewStyle: .code(languageHint: "bash"),
            secondaryBadgeText: "code"
        ),
        ClipPreviewSummary(
            id: "clip.reply.template",
            kind: .text,
            titleText: "Customer reply template",
            bodyText: "Thanks for the report. We traced the auth path and isolated the runtime dependency.",
            metadataText: "Template · Support",
            isPinned: true,
            sourceApp: ClipSourceAppSummary(
                id: "com.openai.chatgpt",
                displayName: "ChatGPT",
                symbolName: "message",
                accentToken: "accent.primary"
            ),
            createdLabel: "Pinned",
            previewStyle: .text,
            secondaryBadgeText: "text"
        )
    ]

    static let recentClips: [ClipPreviewSummary] = [
        ClipPreviewSummary(
            id: "clip.text.summary",
            kind: .text,
            titleText: "Deployment summary",
            bodyText: "Production dry-run finished cleanly. Waiting for approval before the live write.",
            metadataText: "Slack draft",
            sourceApp: ClipSourceAppSummary(
                id: "com.tinyspeck.slackmacgap",
                displayName: "Slack",
                symbolName: "bubble.left.and.bubble.right",
                accentToken: "accent.success"
            ),
            createdLabel: "2m ago",
            previewStyle: .text,
            secondaryBadgeText: "text"
        ),
        ClipPreviewSummary(
            id: "clip.image.receipt",
            kind: .image,
            titleText: "Receipt screenshot",
            bodyText: "PNG preview placeholder",
            metadataText: "1440 × 900",
            sourceApp: ClipSourceAppSummary(
                id: "com.apple.Preview",
                displayName: "Preview",
                symbolName: "photo",
                accentToken: "accent.warning"
            ),
            createdLabel: "8m ago",
            previewStyle: .image,
            secondaryBadgeText: "image"
        ),
        ClipPreviewSummary(
            id: "clip.url.issue",
            kind: .url,
            titleText: "https://linear.app/slipboard/issue/SB-18",
            bodyText: "Slipboard shell integration tracker",
            metadataText: "Project link",
            sourceApp: ClipSourceAppSummary(
                id: "com.apple.Safari",
                displayName: "Safari",
                symbolName: "safari",
                accentToken: "accent.info"
            ),
            createdLabel: "11m ago",
            previewStyle: .url,
            secondaryBadgeText: "url"
        ),
        ClipPreviewSummary(
            id: "clip.file.spec",
            kind: .file,
            titleText: "shared-foundation-task.md",
            bodyText: "SlipBoard/design/shared-foundation/task.md",
            metadataText: "18 KB · Markdown",
            sourceApp: ClipSourceAppSummary(
                id: "com.apple.finder",
                displayName: "Finder",
                symbolName: "folder",
                accentToken: "accent.warning"
            ),
            createdLabel: "19m ago",
            previewStyle: .file(fileExtension: "md"),
            secondaryBadgeText: "file"
        )
    ]

    static let generalPane = SettingsPaneModel(
        id: .general,
        title: "General",
        subtitle: "Startup, appearance, and lightweight popup defaults.",
        sections: [
            SettingsPaneSection(
                id: "general.startup",
                title: "Startup",
                rows: [
                    .toggle(
                        SettingsToggleItem(
                            id: "launch-at-login",
                            title: "Launch at login",
                            isOn: false
                        )
                    ),
                    .toggle(
                        SettingsToggleItem(
                            id: "show-dock-icon",
                            title: "Show Dock icon while debugging",
                            isOn: true
                        )
                    )
                ]
            ),
            SettingsPaneSection(
                id: "general.appearance",
                title: "Appearance",
                rows: [
                    .choice(
                        SettingsChoiceItem(
                            id: "theme",
                            title: "Theme",
                            selectedOptionID: "system",
                            options: [
                                SettingsChoiceOption(id: "system", label: "System", isSelected: true),
                                SettingsChoiceOption(id: "light", label: "Light"),
                                SettingsChoiceOption(id: "dark", label: "Dark")
                            ],
                            style: .segmented
                        )
                    ),
                    .toggle(
                        SettingsToggleItem(
                            id: "menu-bar-badge",
                            title: "Menu bar badge",
                            isOn: true
                        )
                    )
                ]
            ),
            SettingsPaneSection(
                id: "general.behavior",
                title: "Behavior",
                rows: [
                    .toggle(
                        SettingsToggleItem(
                            id: "restore-last-filter",
                            title: "Restore last filter",
                            isOn: true
                        )
                    )
                ]
            )
        ]
    )

    static let retentionPane = SettingsPaneModel(
        id: .retention,
        title: "Retention",
        subtitle: "History limits, quick TTL presets, and cache placeholders.",
        sections: [
            SettingsPaneSection(
                id: "retention.history-limit",
                title: "History limit",
                rows: [
                    .slider(
                        SettingsSliderItem(
                            id: "max-items",
                            title: "Maximum items",
                            value: 2_000,
                            range: 100 ... 2_000,
                            step: 100,
                            valueLabel: "2,000"
                        )
                    )
                ]
            ),
            SettingsPaneSection(
                id: "retention.ttl",
                title: "Auto-clear",
                rows: [
                    .choice(
                        SettingsChoiceItem(
                            id: "ttl",
                            title: "Retention period",
                            selectedOptionID: "1mo",
                            options: [
                                SettingsChoiceOption(id: "1w", label: "1w"),
                                SettingsChoiceOption(id: "2w", label: "2w"),
                                SettingsChoiceOption(id: "1mo", label: "1mo", isSelected: true),
                                SettingsChoiceOption(id: "3mo", label: "3mo"),
                                SettingsChoiceOption(id: "never", label: "Never")
                            ],
                            style: .segmented
                        )
                    ),
                    .toggle(
                        SettingsToggleItem(
                            id: "clear-on-quit",
                            title: "Clear on app quit",
                            isOn: false
                        )
                    )
                ],
                placeholder: SettingsPanePlaceholder(
                    id: "retention.pinned-callout",
                    title: "Pinned items",
                    detailText: "Pinned clips stay excluded from mock TTL and count cleanup.",
                    badgeText: "TTL",
                    kind: .callout
                )
            ),
            SettingsPaneSection(
                id: "retention.asset-cache",
                title: "Asset cache",
                rows: [
                    .slider(
                        SettingsSliderItem(
                            id: "cache-size",
                            title: "Max cache size",
                            value: 500,
                            range: 100 ... 2_000,
                            step: 50,
                            valueLabel: "500 MB"
                        )
                    ),
                    .action(
                        SettingsActionRow(
                            id: "clear-cache",
                            title: "Clear now",
                            detailText: "Current mock usage: 128 MB",
                            role: .primary
                        )
                    )
                ]
            )
        ]
    )

    static let exclusionsPane = SettingsPaneModel(
        id: .exclusions,
        title: "Exclusions",
        subtitle: "Mock excluded apps and popup visibility controls.",
        sections: [
            SettingsPaneSection(
                id: "exclusions.apps",
                title: "Excluded apps",
                rows: [
                    .listEntry(
                        SettingsListEntry(
                            id: "excluded.1password",
                            title: "1Password",
                            detailText: "Sensitive credentials",
                            symbolName: "key"
                        )
                    ),
                    .listEntry(
                        SettingsListEntry(
                            id: "excluded.banking",
                            title: "Banking App",
                            detailText: "Protected finance session",
                            symbolName: "creditcard"
                        )
                    ),
                    .listEntry(
                        SettingsListEntry(
                            id: "excluded.keychain",
                            title: "Keychain Access",
                            detailText: "System secrets",
                            symbolName: "lock.shield"
                        )
                    ),
                    .action(
                        SettingsActionRow(
                            id: "excluded.add",
                            title: "Add App",
                            symbolName: "plus"
                        )
                    )
                ]
            ),
            SettingsPaneSection(
                id: "exclusions.behavior",
                title: "Behavior",
                rows: [
                    .toggle(
                        SettingsToggleItem(
                            id: "hide-popup-in-excluded",
                            title: "Hide popup inside excluded apps",
                            isOn: true
                        )
                    )
                ]
            )
        ]
    )

    static let hotkeysPane = SettingsPaneModel(
        id: .hotkeys,
        title: "Hotkeys",
        subtitle: "Static shortcut labels only. No recorder or global registration.",
        sections: [
            SettingsPaneSection(
                id: "hotkeys.global",
                title: "Global shortcuts",
                rows: [
                    .listEntry(
                        SettingsListEntry(
                            id: "hotkey.open",
                            title: "Open Slipboard",
                            detailText: "Open the popup shell.",
                            accessoryText: "⌘⇧V",
                            symbolName: "menubar.rectangle"
                        )
                    ),
                    .listEntry(
                        SettingsListEntry(
                            id: "hotkey.paste-as",
                            title: "Paste As…",
                            detailText: "Open the transform menu shell.",
                            accessoryText: "⌘↩",
                            symbolName: "arrowshape.turn.up.right"
                        )
                    ),
                    .listEntry(
                        SettingsListEntry(
                            id: "hotkey.pause",
                            title: "Pause Capturing",
                            detailText: "Pause the mock capture indicator.",
                            accessoryText: "⌘⇧P",
                            symbolName: "pause.circle"
                        )
                    )
                ]
            ),
            SettingsPaneSection(
                id: "hotkeys.snippets",
                title: "Snippet hotkeys",
                rows: [
                    .listEntry(
                        SettingsListEntry(
                            id: "hotkey.snippet.reply",
                            title: "Email reply template",
                            detailText: "Paste saved customer response.",
                            accessoryText: "⌃⌥1",
                            symbolName: "envelope"
                        )
                    ),
                    .listEntry(
                        SettingsListEntry(
                            id: "hotkey.snippet.header",
                            title: "API header",
                            detailText: "Paste code snippet quickly.",
                            accessoryText: "⌃⌥2",
                            symbolName: "curlybraces"
                        )
                    )
                ],
                placeholder: SettingsPanePlaceholder(
                    id: "hotkeys.placeholder",
                    title: "Recorder placeholder",
                    detailText: "Edit buttons stay visual-only until a later hotkey gate is approved.",
                    kind: .note
                )
            )
        ]
    )

    static let snippetsPane = SettingsPaneModel(
        id: .snippets,
        title: "Snippets",
        subtitle: "Reusable text and code placeholders with a preview shell.",
        sections: [
            SettingsPaneSection(
                id: "snippets.library",
                title: "Snippet library",
                rows: [
                    .listEntry(
                        SettingsListEntry(
                            id: "snippet.reply",
                            title: "Email reply",
                            detailText: "Saved customer response",
                            accessoryText: "⌃⌥1",
                            symbolName: "envelope"
                        )
                    ),
                    .listEntry(
                        SettingsListEntry(
                            id: "snippet.header",
                            title: "API header",
                            detailText: "Authorization boilerplate",
                            accessoryText: "⌃⌥2",
                            symbolName: "curlybraces"
                        )
                    ),
                    .listEntry(
                        SettingsListEntry(
                            id: "snippet.signature",
                            title: "Signature",
                            detailText: "No hotkey",
                            symbolName: "signature"
                        )
                    )
                ],
                placeholder: SettingsPanePlaceholder(
                    id: "snippets.preview",
                    title: "Editor preview",
                    detailText: "API header\nAuthorization: Bearer <token>\nX-Client: slipboard",
                    badgeText: "Mock",
                    kind: .editorPreview
                )
            )
        ]
    )

    static let securityPane = SettingsPaneModel(
        id: .security,
        title: "Security",
        subtitle: "Lock state controls only. No Keychain or encryption behavior is modeled here.",
        sections: [
            SettingsPaneSection(
                id: "security.app-lock",
                title: "App Lock",
                rows: [
                    .toggle(
                        SettingsToggleItem(
                            id: "lock-slipboard",
                            title: "Lock Slipboard",
                            isOn: false
                        )
                    )
                ]
            ),
            SettingsPaneSection(
                id: "security.unlock-method",
                title: "Unlock method",
                rows: [
                    .choice(
                        SettingsChoiceItem(
                            id: "unlock-method",
                            title: "Preferred unlock method",
                            selectedOptionID: "touch-id",
                            options: [
                                SettingsChoiceOption(id: "touch-id", label: "Touch ID / Face ID", isSelected: true),
                                SettingsChoiceOption(id: "system-password", label: "System Password")
                            ],
                            style: .menu
                        )
                    ),
                    .choice(
                        SettingsChoiceItem(
                            id: "auto-lock",
                            title: "Auto-lock",
                            selectedOptionID: "never",
                            options: [
                                SettingsChoiceOption(id: "never", label: "Never", isSelected: true),
                                SettingsChoiceOption(id: "1m", label: "1 min"),
                                SettingsChoiceOption(id: "5m", label: "5 min"),
                                SettingsChoiceOption(id: "15m", label: "15 min"),
                                SettingsChoiceOption(id: "1h", label: "1 hour")
                            ],
                            style: .menu
                        )
                    ),
                    .toggle(
                        SettingsToggleItem(
                            id: "hide-expose-previews",
                            title: "Hide previews in Mission Control / Exposé",
                            isOn: false
                        )
                    )
                ]
            )
        ]
    )

    static let bridgePane = SettingsPaneModel(
        id: .bridge,
        title: "iCloud Bridge",
        subtitle: "Device and bridge placeholders only. No sync wiring is implied.",
        sections: [
            SettingsPaneSection(
                id: "bridge.behavior",
                title: "Bridge behavior",
                rows: [
                    .toggle(
                        SettingsToggleItem(
                            id: "enable-bridge",
                            title: "Enable iCloud Bridge",
                            isOn: true
                        )
                    )
                ]
            ),
            SettingsPaneSection(
                id: "bridge.devices",
                title: "Connected devices",
                rows: [
                    .listEntry(
                        SettingsListEntry(
                            id: "bridge.device.iphone",
                            title: "iPhone 15 Pro",
                            detailText: "Bridge enabled · Last seen now",
                            badgeText: "Live",
                            symbolName: "iphone"
                        )
                    )
                ],
                placeholder: SettingsPanePlaceholder(
                    id: "bridge.placeholder",
                    title: "Bridge preview",
                    detailText: "Foundation keeps this pane mock-backed until a later bridge/runtime feature task.",
                    kind: .listPreview
                )
            )
        ]
    )
}

final class MockFoundationShellStore: ClipShellProviding, SettingsShellProviding, MenuBarShellProviding {
    var popupShellState: PopupShellViewState
    let popupFilterOptions: [PopupFilterOption]
    var settingsShellState: SettingsShellState
    var menuBarSummaryState: MenuBarSummaryState

    init(
        popupShellState: PopupShellViewState = MockFoundationFixtures.popupShellState,
        popupFilterOptions: [PopupFilterOption] = MockFoundationFixtures.popupFilterOptions,
        settingsShellState: SettingsShellState = MockFoundationFixtures.settingsShellState,
        menuBarSummaryState: MenuBarSummaryState = MockFoundationFixtures.menuBarSummaryState
    ) {
        self.popupShellState = popupShellState
        self.popupFilterOptions = popupFilterOptions
        self.settingsShellState = settingsShellState
        self.menuBarSummaryState = menuBarSummaryState
    }
}
