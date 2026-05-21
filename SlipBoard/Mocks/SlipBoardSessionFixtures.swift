import Foundation

struct SlipBoardSessionFixture: Equatable, Sendable {
    let preset: SlipBoardSessionPreset
    let session: SlipBoardAppSession
}

enum SlipBoardSessionFixtures {
    static let empty = SlipBoardSessionFixture(
        preset: .empty,
        session: SlipBoardAppSession(
            activeSurface: .popup,
            theme: .system,
            clipboard: emptyClipboard,
            popupChrome: PopupChromeState(
                searchQuery: "",
                activeFilter: .all,
                selectedItemID: nil,
                pasteMenuItemID: nil
            ),
            settings: emptySettings(selectedTab: .general)
        )
    )

    static let popupDemo = SlipBoardSessionFixture(
        preset: .popupDemo,
        session: SlipBoardAppSession(
            activeSurface: .popup,
            theme: .dark,
            clipboard: demoClipboardFeed,
            popupChrome: PopupChromeState(
                searchQuery: "",
                activeFilter: .all,
                selectedItemID: demoClipboardFeed.recentItems.first?.id,
                pasteMenuItemID: nil
            ),
            settings: demoSettings(selectedTab: .general)
        )
    )

    static let settingsDemo = SlipBoardSessionFixture(
        preset: .settingsDemo,
        session: SlipBoardAppSession(
            activeSurface: .settings(tab: .bridge),
            theme: .system,
            clipboard: demoClipboardFeed,
            popupChrome: PopupChromeState(
                searchQuery: "",
                activeFilter: .all,
                selectedItemID: nil,
                pasteMenuItemID: nil
            ),
            settings: demoSettings(selectedTab: .bridge)
        )
    )

    static let fullDemo = SlipBoardSessionFixture(
        preset: .fullDemo,
        session: SlipBoardAppSession(
            activeSurface: .popup,
            theme: .light,
            clipboard: filteredClipboardFeed,
            popupChrome: PopupChromeState(
                searchQuery: "bridge",
                activeFilter: .text,
                selectedItemID: filteredClipboardFeed.pinnedItems.first?.id,
                pasteMenuItemID: filteredClipboardFeed.recentItems.first?.id
            ),
            settings: demoSettings(selectedTab: .retention)
        )
    )

    static let all: [SlipBoardSessionFixture] = [
        empty,
        popupDemo,
        settingsDemo,
        fullDemo
    ]

    static func fixture(named preset: SlipBoardSessionPreset) -> SlipBoardSessionFixture {
        switch preset {
        case .empty:
            return empty
        case .popupDemo:
            return popupDemo
        case .settingsDemo:
            return settingsDemo
        case .fullDemo:
            return fullDemo
        }
    }

    static func session(named preset: SlipBoardSessionPreset) -> SlipBoardAppSession {
        fixture(named: preset).session
    }

    private static let emptyClipboard = ClipboardFeedSnapshot(
        totalCount: 0,
        filteredCount: 0,
        pinnedItems: [],
        recentItems: [],
        availableFilters: ClipboardFilter.allCases,
        lastCapturedAt: nil
    )

    private static let demoClipboardFeed = ClipboardFeedSnapshot(
        totalCount: 5,
        filteredCount: 5,
        pinnedItems: [
            clipboardItem(
                id: "item-release-note",
                kind: .text,
                sourceApp: SourceAppSummary(displayName: "Notes", symbolName: "note.text"),
                capturedAt: fixtureDate(hoursAgo: 1.5),
                isPinned: true,
                note: "Weekly launch checklist",
                preview: .text("Bridge launch copy is ready for review."),
                pasteAction: PasteActionSummary(
                    isAvailable: true,
                    label: "Paste",
                    hint: "Return to the last app"
                )
            ),
            clipboardItem(
                id: "item-paste-transform",
                kind: .code,
                sourceApp: SourceAppSummary(displayName: "Xcode", symbolName: "hammer"),
                capturedAt: fixtureDate(hoursAgo: 2.75),
                isPinned: true,
                note: nil,
                preview: .code(
                    language: "swift",
                    snippet: "func publishSelection() { /* local bridge */ }"
                ),
                pasteAction: PasteActionSummary(
                    isAvailable: true,
                    label: "Paste as Code",
                    hint: "Preserve formatting"
                )
            )
        ],
        recentItems: [
            clipboardItem(
                id: "item-bridge-url",
                kind: .url,
                sourceApp: SourceAppSummary(displayName: "Safari", symbolName: "safari"),
                capturedAt: fixtureDate(minutesAgo: 12),
                isPinned: false,
                note: "Open before the review",
                preview: .url("https://example.com/bridge-preview"),
                pasteAction: PasteActionSummary(
                    isAvailable: true,
                    label: "Paste Link",
                    hint: "Use the original URL"
                )
            ),
            clipboardItem(
                id: "item-color-token",
                kind: .color,
                sourceApp: SourceAppSummary(displayName: "Figma", symbolName: "paintpalette"),
                capturedAt: fixtureDate(minutesAgo: 25),
                isPinned: false,
                note: nil,
                preview: .color(hex: "#D08C34"),
                pasteAction: PasteActionSummary(
                    isAvailable: true,
                    label: "Paste Color",
                    hint: "HEX and swatch preview"
                )
            ),
            clipboardItem(
                id: "item-diagram-export",
                kind: .file,
                sourceApp: SourceAppSummary(displayName: "Finder", symbolName: "folder"),
                capturedAt: fixtureDate(minutesAgo: 43),
                isPinned: false,
                note: nil,
                preview: .file(name: "popup-layout.pdf", detail: "2.4 MB PDF"),
                pasteAction: PasteActionSummary(
                    isAvailable: false,
                    label: "Paste File",
                    hint: "Unavailable in the current destination"
                )
            )
        ],
        availableFilters: ClipboardFilter.allCases,
        lastCapturedAt: fixtureDate(minutesAgo: 12)
    )

    private static let filteredClipboardFeed = ClipboardFeedSnapshot(
        totalCount: 5,
        filteredCount: 2,
        pinnedItems: [
            clipboardItem(
                id: "item-bridge-copy",
                kind: .text,
                sourceApp: SourceAppSummary(displayName: "Messages", symbolName: "message"),
                capturedAt: fixtureDate(minutesAgo: 8),
                isPinned: true,
                note: "Bridge copy variant",
                preview: .text("Paste to iPhone only when the user confirms."),
                pasteAction: PasteActionSummary(
                    isAvailable: true,
                    label: "Paste",
                    hint: "Most recent approved text"
                )
            )
        ],
        recentItems: [
            clipboardItem(
                id: "item-bridge-note",
                kind: .text,
                sourceApp: SourceAppSummary(displayName: "Drafts", symbolName: "doc.plaintext"),
                capturedAt: fixtureDate(minutesAgo: 4),
                isPinned: false,
                note: nil,
                preview: .text("Bridge status copy for the popup empty state."),
                pasteAction: PasteActionSummary(
                    isAvailable: true,
                    label: "Paste",
                    hint: "Matches the active search"
                )
            )
        ],
        availableFilters: ClipboardFilter.allCases,
        lastCapturedAt: fixtureDate(minutesAgo: 4)
    )

    private static func emptySettings(selectedTab: SettingsTabID) -> SettingsSessionSnapshot {
        SettingsSessionSnapshot(
            selectedTab: selectedTab,
            general: GeneralSettingsSummary(
                launchAtLogin: PreferenceToggleState(
                    title: "Launch at Login",
                    isOn: false,
                    detail: "Disabled until the shell is wired."
                ),
                startPaused: PreferenceToggleState(
                    title: "Start Paused",
                    isOn: true,
                    detail: "Shows placeholder paused state."
                ),
                interfaceTheme: PreferenceValueSummary(
                    title: "Appearance",
                    value: "System",
                    detail: "No custom theme chosen."
                ),
                menuBarSummary: PreferenceValueSummary(
                    title: "Menu Bar",
                    value: "Icon Only",
                    detail: "Prototype default."
                )
            ),
            bridge: BridgeSettingsSummary(
                isEnabled: false,
                receiveFromPhoneEnabled: false,
                lastPublishedLabel: nil,
                devices: []
            ),
            retention: RetentionSettingsSummary(
                autoCleanupEnabled: PreferenceToggleState(
                    title: "Auto Cleanup",
                    isOn: false,
                    detail: "Retention rules are not active."
                ),
                keepPinnedItems: PreferenceToggleState(
                    title: "Keep Pinned Items",
                    isOn: true,
                    detail: "Pinned items are always preserved."
                ),
                retentionWindow: PreferenceValueSummary(
                    title: "Keep History",
                    value: "Not configured",
                    detail: "Choose a duration later."
                )
            ),
            exclusions: ExclusionsSettingsSummary(
                excludedApps: [],
                captureSensitiveContent: PreferenceToggleState(
                    title: "Capture Sensitive Content",
                    isOn: false,
                    detail: "No overrides configured."
                )
            ),
            hotkeys: HotkeysSettingsSummary(
                popupShortcut: PreferenceValueSummary(
                    title: "Open Popup",
                    value: "Not configured",
                    detail: "Hotkeys are out of scope for this phase."
                ),
                quickPasteShortcut: PreferenceValueSummary(
                    title: "Quick Paste",
                    value: "Not configured",
                    detail: "No shortcut registered."
                ),
                conflictSummary: nil
            ),
            snippets: SnippetsSettingsSummary(
                snippetsEnabled: PreferenceToggleState(
                    title: "Enable Snippets",
                    isOn: false,
                    detail: "Snippets have no stored content yet."
                ),
                defaultCollection: PreferenceValueSummary(
                    title: "Default Collection",
                    value: "Inbox",
                    detail: "Placeholder collection only."
                ),
                totalCount: 0
            )
        )
    }

    private static func demoSettings(selectedTab: SettingsTabID) -> SettingsSessionSnapshot {
        SettingsSessionSnapshot(
            selectedTab: selectedTab,
            general: GeneralSettingsSummary(
                launchAtLogin: PreferenceToggleState(
                    title: "Launch at Login",
                    isOn: true,
                    detail: "Starts SlipBoard with the current user session."
                ),
                startPaused: PreferenceToggleState(
                    title: "Start Paused",
                    isOn: false,
                    detail: "Begin capturing immediately."
                ),
                interfaceTheme: PreferenceValueSummary(
                    title: "Appearance",
                    value: "Warm Light",
                    detail: "Matches the menu bar shell prototype."
                ),
                menuBarSummary: PreferenceValueSummary(
                    title: "Menu Bar",
                    value: "Icon + Status Dot",
                    detail: "Pause state remains visible at a glance."
                )
            ),
            bridge: BridgeSettingsSummary(
                isEnabled: true,
                receiveFromPhoneEnabled: true,
                lastPublishedLabel: "Published 3 minutes ago",
                devices: [
                    BridgeDeviceSummary(
                        id: "device-iphone-15",
                        displayName: "Huyn iPhone",
                        detail: "Ready for one-shot paste handoff",
                        isReachable: true,
                        lastPublishedLabel: "Last used today"
                    ),
                    BridgeDeviceSummary(
                        id: "device-ipad-air",
                        displayName: "Design iPad",
                        detail: "Offline until unlocked",
                        isReachable: false,
                        lastPublishedLabel: "Yesterday"
                    )
                ]
            ),
            retention: RetentionSettingsSummary(
                autoCleanupEnabled: PreferenceToggleState(
                    title: "Auto Cleanup",
                    isOn: true,
                    detail: "Applies only to non-pinned items."
                ),
                keepPinnedItems: PreferenceToggleState(
                    title: "Keep Pinned Items",
                    isOn: true,
                    detail: "Pinned items bypass cleanup."
                ),
                retentionWindow: PreferenceValueSummary(
                    title: "Keep History",
                    value: "30 Days",
                    detail: "Quick retention control for the prototype."
                )
            ),
            exclusions: ExclusionsSettingsSummary(
                excludedApps: [
                    SourceAppSummary(displayName: "1Password", symbolName: "lock.shield"),
                    SourceAppSummary(displayName: "Terminal", symbolName: "terminal")
                ],
                captureSensitiveContent: PreferenceToggleState(
                    title: "Capture Sensitive Content",
                    isOn: false,
                    detail: "Trusted apps remain excluded."
                )
            ),
            hotkeys: HotkeysSettingsSummary(
                popupShortcut: PreferenceValueSummary(
                    title: "Open Popup",
                    value: "Option-Shift-Space",
                    detail: "Approved concept, not implemented yet."
                ),
                quickPasteShortcut: PreferenceValueSummary(
                    title: "Quick Paste",
                    value: "Option-Shift-V",
                    detail: "Visible in settings only for now."
                ),
                conflictSummary: "No conflicts detected in fixtures."
            ),
            snippets: SnippetsSettingsSummary(
                snippetsEnabled: PreferenceToggleState(
                    title: "Enable Snippets",
                    isOn: true,
                    detail: "Quick insert favorites are available."
                ),
                defaultCollection: PreferenceValueSummary(
                    title: "Default Collection",
                    value: "Frequent Replies",
                    detail: "Most recently used collection for demo data."
                ),
                totalCount: 12
            )
        )
    }

    private static func clipboardItem(
        id: String,
        kind: ClipboardContentKind,
        sourceApp: SourceAppSummary,
        capturedAt: Date,
        isPinned: Bool,
        note: String?,
        preview: ClipboardPreview,
        pasteAction: PasteActionSummary
    ) -> ClipboardItem {
        ClipboardItem(
            id: ClipboardItemID(rawValue: id),
            kind: kind,
            sourceApp: sourceApp,
            capturedAt: capturedAt,
            isPinned: isPinned,
            note: note,
            preview: preview,
            pasteAction: pasteAction
        )
    }

    private static func fixtureDate(hoursAgo: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: 800_000_000 - (hoursAgo * 3_600))
    }

    private static func fixtureDate(minutesAgo: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: 800_000_000 - (minutesAgo * 60))
    }
}
