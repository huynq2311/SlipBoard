import Foundation

enum LocalizationKey: String, CaseIterable, Sendable {
    case appName
    case language
    case languageEnglish
    case languageVietnamese
    case search
    case searchPlaceholder
    case save
    case cancel
    case done
    case close
    case add
    case remove
    case edit
    case delete
    case enabled
    case disabled
    case locked
    case unlocked
    case loading
    case none
    case menuAppearanceAuto
    case menuAppearanceDark
    case menuAppearanceLight
    case menuPauseCapture
    case menuResumeCapture
    case menuClearHistory
    case menuSettings
    case menuQuit
    case menuOpenSlipBoard
    case menuCaptureStatus
    case menuRetention
    case historyItemCount
    case sidebarGeneral
    case sidebarOrganization
    case sidebarBridge
    case sidebarRetention
    case sidebarExclusions
    case sidebarHotkeys
    case sidebarSnippets
    case sidebarSecurity
    case popupPinned
    case popupRecent
    case popupCollections
    case popupNoItems
    case actionCopy
    case actionPaste
    case actionPasteAs
    case actionPin
    case actionUnpin
    case actionDelete
    case actionClear
    case statusActive
    case statusPaused
    case statusPausedUntil
    case statusResumes
    case statusAutoResumes
    case settingsLanguageTitle
    case settingsLanguageDescription
    case settingsAppearance
    case settingsTheme
    case settingsGeneral
    case settingsSecurity
    case settingsOrganization
    case settingsStartupHeading
    case settingsLaunchAtLogin
    case settingsLaunchAtLoginDetail
    case settingsBridge
    case settingsRetention
    case settingsExclusions
    case settingsHotkeys
    case settingsSnippets
    case securityLockSlipBoard
    case securityCurrentState
    case securityUnlock
    case securityAutoLockOneMinute
    case securityAutoLockFiveMinutes
    case securityAutoLockFifteenMinutes
    case securityAutoLockOneHour
    case retentionNever
    case retentionOneWeek
    case retentionTwoWeeks
    case retentionOneMonth
    case retentionThreeMonths
    case retentionForever
    case alertClearHistoryTitle
    case alertClearHistoryMessage
    case alertConfirm
    case alertDelete
    case accessibilitySettings
    case accessibilityClose
    case commonOn
    case commonOff
    case commonActive
    case commonAvailable
    case commonUnavailable
    case commonError
    case commonReady
    case commonPending
    case commonRestricted
    case commonFuture
    case commonLive
    case commonLocal
    case commonAll
    case commonStatus
    case commonSource
    case commonKind
    case commonTitle
    case commonContent
    case commonName
    case commonDetails
    case commonMore
    case commonRetry
    case commonRefreshNow
    case commonNotNow
    case commonNotSet
    case commonOpen
    case commonNow
    case contentText
    case contentCode
    case contentImage
    case contentFile
    case contentURL
    case contentColor
    case contentRichText
    case menuStatus
    case menuSecurity
    case menuPauseFor
    case menuPausedUntilResume
    case menuPauseMonitoring
    case menuShowFloatingPopup
    case menuHideFloatingPopup
    case menuOpenSettings
    case menuStartMonitoring
    case menuOpenSecuritySettings
    case menuShowLockedPopup
    case menuSecuritySettingsDetail
    case menuShowLockedPopupDetail
    case menuCaptureStatusEmpty
    case menuPauseOptions
    case popupNoPinnedClips
    case popupNoMatchingClips
    case popupHistoryEmpty
    case popupSearchLockedTitle
    case popupSearchLockedDetail
    case popupPinnedEmptyDetail
    case popupRecentEmptyDetail
    case popupNoMatchDetail
    case popupCurrentFilter
    case popupCurrentGroup
    case popupCurrentFilterAndGroup
    case popupPinnedRailReady
    case popupNoResultsInRecent
    case popupRecentRailWaiting
    case popupPinnedRailDetail
    case popupRecentSearchDetail
    case popupRecentRailDetail
    case popupFiltered
    case popupVisibleCount
    case popupResultCount
    case popupReturnToPaste
    case popupCopyToBegin
    case popupCommandSearch
    case popupSupportedTypes
    case popupResumeMonitoring
    case popupShowPinned
    case popupHidePinned
    case popupMoreActions
    case popupClipFrom
    case popupUnlockRequired
    case popupPreviewHidden
    case popupRichContent
    case popupAddNote
    case popupUpdateNote
    case popupNotesLocked
    case popupSearchDisabled
    case popupLocked
    case popupPrivate
    case popupTransformUnavailable
    case popupPasteAsOnlyText
    case popupExecutingPaste
    case overlayEscapeCancel
    case overlayPlainText
    case overlayConvertMarkdown
    case overlayStripUnicode
    case overlayUppercase
    case overlayLowercase
    case overlayRemoveRichFormatting
    case statusCaptureActive
    case statusWaitingForCopy
    case statusUnsupportedIgnored
    case statusCapturePaused
    case statusPauseMode
    case statusResumeFromMenu
    case statusExcludedAppActive
    case statusExcludedIn
    case statusCaptureIgnored
    case statusCaptureIgnoredThisApp
    case statusPopupHidesInExcludedApps
    case statusPopupShowsInExcludedApps
    case statusHidePopupOn
    case statusHidePopupOff
    case statusAutoResume
    case statusManualPauseInfo
    case statusPauseTimedInfo
    case statusRelativeSeconds
    case statusRelativeMinutes
    case statusRelativeHours
    case statusYesterday
    case statusRelativeDays
    case statusCaptureResumed
    case statusExcludedAppRemoved
    case statusDeletedHistoryItem
    case statusClearedHistory
    case statusCopiedToClipboard
    case statusSelectedUnavailableToCopy
    case statusUnpinnedItem
    case statusPinnedItem
    case statusCommandUnavailable
    case statusPasteTargetUnavailable
    case statusNoEligibleApp
    case statusAddedExcludedApp
    case statusPausedFifteenMinutes
    case statusPausedOneHour
    case statusPausedUntilResume
    case settingsGeneralDescription
    case settingsOrganizationDescription
    case settingsSearchHeading
    case settingsSearchDescription
    case settingsSearchVisibility
    case settingsNoteSource
    case settingsCollectionsHeading
    case settingsCollectionsDescription
    case settingsCreateFirstGroup
    case settingsLockedStateHeading
    case settingsSearchUnlockedDetail
    case settingsNoteSourceDetail
    case settingsGroupActiveDetail
    case settingsGroupAvailableDetail
    case settingsSelected
    case settingsCollectionsEmptyDetail
    case settingsSearchDisabledTitle
    case settingsAppLockLiveTitle
    case settingsSearchLockedDetail
    case settingsSearchUnlockedLockDetail
    case settingsRetentionDescription
    case settingsHistoryLimit
    case settingsMaxItems
    case settingsAssetCache
    case settingsMaxCacheSize
    case settingsClearNow
    case settingsClearOnQuit
    case settingsRetentionPinnedNote
    case settingsHistoryLimitDescription
    case settingsPasteBehavior
    case settingsPasteBehaviorDescription
    case settingsMovePastedToTop
    case settingsMovePastedToTopDetail
    case settingsAutoClear
    case settingsAutoClearDescription
    case settingsRetentionPeriodDetail
    case settingsClearOnQuitDetail
    case settingsPinnedItems
    case settingsPinnedPreserved
    case settingsPinnedPreservedDetail
    case settingsAssetCacheDescription
    case settingsCacheRefreshDetail
    case settingsExclusionsDescription
    case settingsExcludedApps
    case settingsAddApp
    case settingsNoExcludedApps
    case settingsHidePopupInExcludedApps
    case settingsPauseCapture
    case settingsPausePreset
    case settingsExcludedAppsDescription
    case settingsAddAppDetail
    case settingsRemoveApp
    case settingsNoExcludedAppsDetail
    case settingsCaptureBehavior
    case settingsCaptureBehaviorDescription
    case settingsHidePopupDetail
    case settingsExcludedAppActive
    case settingsHidePopupBadge
    case settingsCaptureOnlyBadge
    case settingsPauseDescription
    case settingsPausePresetDetail
    case settingsResumeCapturing
    case settingsResumeCapturingDetail
    case settingsHotkeysDescription
    case settingsGlobalShortcuts
    case settingsSnippetsDescription
    case settingsSnippetLibrary
    case settingsSnippetHotkeys
    case settingsSnippetHotkeysDescription
    case settingsRuntimeStatus
    case settingsNoSnippetShortcuts
    case settingsNoSnippetShortcutsDetail
    case settingsHotkeyConflictTiming
    case settingsLibrary
    case settingsEditorState
    case settingsNoSnippets
    case settingsNoSnippetsDetail
    case settingsNoSnippetSelected
    case settingsSavedLocallyDetail
    case settingsPinnedBadge
    case settingsOpenBadge
    case settingsDirtyBadge
    case settingsReadyBadge
    case settingsActiveBadge
    case settingsAssignedBadge
    case settingsGlobalHotkeysDescription
    case settingsSnippetLibraryDescription
    case settingsCreateOrSelectSnippetDetail
    case settingsCurrentSnippetDraftDetail
    case settingsSnippetMissingTitle
    case settingsSnippetMissingContent
    case settingsSnippetEditingDetail
    case settingsSecurityDescription
    case securityAppLockDescription
    case securityUnlockMethod
    case securityAutoLock
    case securityPrivacy
    case securityDataProtection
    case securityEncryptionStatus
    case securityKeyStorage
    case securityDecryptedCache
    case securityHidePreviews
    case securityProtectedStorageUnavailable
    case securityUnlocking
    case securityUnlockFailed
    case securityUnlockUnavailable
    case securityUnlockInProgress
    case securityLockToggleTitle
    case securityLockToggleDetail
    case securityUnlockMethodDescription
    case securityPreferredMethod
    case securitySystemPassword
    case securityAutoLockDescription
    case securityTimeout
    case securityPrivacyDescription
    case securityHidePreviewsDetail
    case securityDataProtectionDescription
    case securityEncryptionDetail
    case securityKeyStorageDetail
    case securityDecryptedCacheDetail
    case securityInMemory
    case securityCleared
    case bridgeDescription
    case bridgeEnable
    case bridgePublishOnPaste
    case bridgeReceive
    case bridgeDevices
    case bridgeNoDevices
    case bridgeLastActivity
    case bridgeLastSent
    case bridgeLastReceived
    case bridgeLastError
    case bridgePendingImports
    case bridgeLocalOnlyPolicy
    case bridgeStop
    case bridgeStopDescription
    case bridgeUnavailable
    case bridgeReady
    case bridgeSyncing
    case bridgeError
    case alertClearClipboardHistoryTitle
    case alertClearClipboardHistoryMessage
    case alertAccessibilityTitle
    case alertAccessibilityMessage
    case alertOpenAccessibilitySettings
    case alertDeleteSnippet
    case alertDeleteSnippetMessage
    case alertConfirmDestructive
    case accessibilityMoreActions
    case accessibilityClipFrom
    case popupSort
    case popupSortNewestFirst
    case settingsClearHistoryAfter
    case overlayOpenTransformPreview
    case overlayMarkdownDescription
    case overlayStripUnicodeDescription
    case overlayUppercaseDescription
    case overlayLowercaseDescription
    case securityStateLocked
    case securityStateUnlocked
    case securityStateUnavailable
    case securityMenuLocked
    case securityMenuUnlocked
    case securityMenuUnavailable
    case securityLockDetailManual
    case securityLockDetailAutoLock
    case securityLockDetailBackground
    case securityLockDetailAuthentication
    case securityLockDetailKeyUnavailable
    case securityLockDetailMigration
    case securityLockDetailUnlocking
    case securityLockDetailFailed
    case securityLockDetailUnlocked
    case securityLockDetailUnknown
    case clipRedactionNoSnapshot
    case clipRedactionLocked
    case clipRedactionPrivacy
    case popupLockTitleLocked
    case popupLockTitleUnlocking
    case popupLockTitleFailed
    case popupLockTitleUnlocked
    case popupLockDetailLocked
    case popupLockDetailUnlocking
    case popupLockDetailFailed
    case popupLockDetailUnlocked
    case popupLockHintLocked
    case popupLockHintUnlocking
    case popupLockHintFailed
    case popupLockHintUnlocked
    case bridgeBehavior
    case bridgeScope
    case bridgeScopeDetail
    case bridgeEnableDetail
    case bridgePublishDetail
    case bridgeReceiveDetail
    case bridgePasteFlow
    case bridgePickOnMac
    case bridgePickOnMacDetail
    case bridgePasteOnMac
    case bridgePasteOnMacDetail
    case bridgePublishOneShot
    case bridgePublishOneShotDetail
    case bridgeReceiveOnIPhone
    case bridgeReceiveOnIPhoneDetail
    case bridgeSameICloudAccount
    case bridgeReview
    case bridgeNoMacPastes
    case bridgeNoCompanionImports
    case bridgeSentSupportedDetail
    case bridgeReceivedLocalDetail
    case bridgeEligiblePendingDetail
    case bridgeBehaviorDescription
    case bridgeDevicesDescription
    case bridgeObservedDevicesDescription
    case bridgeActivityDescription
    case bridgeLocalHistoryTitle
    case bridgePendingImportsDetail
    case bridgeOneShotTTL
    case hotkeyRecorderInstruction
    case hotkeyAccessLocked
    case hotkeyInfo
    case hotkeyAccessLockedDetail
    case hotkeyInfoDetail
    case hotkeyOpenSlipBoardDetail
    case hotkeyPasteAsDetail
    case hotkeyPauseCaptureDetail
    case hotkeySnippetDetail
    case hotkeyFutureCommandDetail
    case hotkeyConflictDetail
    case hotkeyUnlockToEdit
    case bridgeScopeLabel
    case bridgeSupportedPastesV1Detail
    case bridgeNoDevicesDetail
    case bridgeSubtitleFallback
    case bridgeDeviceLastSeenDetail

    var englishFallback: String {
        switch self {
        case .appName: "SlipBoard"
        case .language: "Language"
        case .languageEnglish: "English"
        case .languageVietnamese: "Tiếng Việt"
        case .search: "Search"
        case .searchPlaceholder: "Search clipboard history"
        case .save: "Save"
        case .cancel: "Cancel"
        case .done: "Done"
        case .close: "Close"
        case .add: "Add"
        case .remove: "Remove"
        case .edit: "Edit"
        case .delete: "Delete"
        case .enabled: "Enabled"
        case .disabled: "Disabled"
        case .locked: "Locked"
        case .unlocked: "Unlocked"
        case .loading: "Loading"
        case .none: "None"
        case .menuAppearanceAuto: "Auto"
        case .menuAppearanceDark: "Dark"
        case .menuAppearanceLight: "Light"
        case .menuPauseCapture: "Pause Clipboard Capture"
        case .menuResumeCapture: "Resume Clipboard Capture"
        case .menuClearHistory: "Clear History"
        case .menuSettings: "Settings..."
        case .menuQuit: "Quit SlipBoard"
        case .menuOpenSlipBoard: "Open SlipBoard"
        case .menuCaptureStatus: "Capture Status"
        case .menuRetention: "Retention"
        case .historyItemCount: "item"
        case .sidebarGeneral: "General"
        case .sidebarOrganization: "Organization"
        case .sidebarBridge: "Bridge"
        case .sidebarRetention: "Retention"
        case .sidebarExclusions: "Exclusions"
        case .sidebarHotkeys: "Hotkeys"
        case .sidebarSnippets: "Snippets"
        case .sidebarSecurity: "Security"
        case .popupPinned: "Pinned"
        case .popupRecent: "Recent"
        case .popupCollections: "Collections"
        case .popupNoItems: "No clipboard items"
        case .actionCopy: "Copy"
        case .actionPaste: "Paste"
        case .actionPasteAs: "Paste As"
        case .actionPin: "Pin"
        case .actionUnpin: "Unpin"
        case .actionDelete: "Delete"
        case .actionClear: "Clear"
        case .statusActive: "Active %{value}"
        case .statusPaused: "Paused"
        case .statusPausedUntil: "Paused until %{value}"
        case .statusResumes: "Resumes %{value}"
        case .statusAutoResumes: "Auto-resumes %{value}"
        case .settingsLanguageTitle: "Display Language"
        case .settingsLanguageDescription: "Choose the language used across SlipBoard."
        case .settingsAppearance: "Appearance"
        case .settingsTheme: "Theme"
        case .settingsGeneral: "General"
        case .settingsSecurity: "Security"
        case .settingsOrganization: "Organization"
        case .settingsStartupHeading: "Startup"
        case .settingsLaunchAtLogin: "Launch at login"
        case .settingsLaunchAtLoginDetail: "Open SlipBoard automatically when you sign in."
        case .settingsBridge: "Bridge"
        case .settingsRetention: "Retention"
        case .settingsExclusions: "Exclusions"
        case .settingsHotkeys: "Hotkeys"
        case .settingsSnippets: "Snippets"
        case .securityLockSlipBoard: "Lock SlipBoard"
        case .securityCurrentState: "Current state"
        case .securityUnlock: "Unlock"
        case .securityAutoLockOneMinute: "1 min"
        case .securityAutoLockFiveMinutes: "5 min"
        case .securityAutoLockFifteenMinutes: "15 min"
        case .securityAutoLockOneHour: "1 hour"
        case .retentionNever: "Never"
        case .retentionOneWeek: "1w"
        case .retentionTwoWeeks: "2w"
        case .retentionOneMonth: "1mo"
        case .retentionThreeMonths: "3mo"
        case .retentionForever: "∞"
        case .alertClearHistoryTitle: "Clear History?"
        case .alertClearHistoryMessage: "This permanently removes all clipboard history."
        case .alertConfirm: "Confirm"
        case .alertDelete: "Delete"
        case .accessibilitySettings: "Settings"
        case .accessibilityClose: "Close"
        case .commonOn: "On"
        case .commonOff: "Off"
        case .commonActive: "Active"
        case .commonAvailable: "Available"
        case .commonUnavailable: "Unavailable"
        case .commonError: "Error"
        case .commonReady: "Ready"
        case .commonPending: "Pending"
        case .commonRestricted: "Restricted"
        case .commonFuture: "Future"
        case .commonLive: "Live"
        case .commonLocal: "Local"
        case .commonAll: "All"
        case .commonStatus: "Status"
        case .commonSource: "Source"
        case .commonKind: "Kind"
        case .commonTitle: "Title"
        case .commonContent: "Content"
        case .commonName: "Name"
        case .commonDetails: "Details"
        case .commonMore: "More"
        case .commonRetry: "Retry"
        case .commonRefreshNow: "Refresh Now"
        case .commonNotNow: "Not Now"
        case .commonNotSet: "Not set"
        case .commonOpen: "Open"
        case .commonNow: "Now"
        case .contentText: "Text"
        case .contentCode: "Code"
        case .contentImage: "Image"
        case .contentFile: "File"
        case .contentURL: "URL"
        case .contentColor: "Color"
        case .contentRichText: "Rich Text"
        case .menuStatus: "Status"
        case .menuSecurity: "Security"
        case .menuPauseFor: "Pause for %{duration}"
        case .menuPausedUntilResume: "Paused until resume"
        case .menuPauseMonitoring: "Pause Monitoring"
        case .menuShowFloatingPopup: "Show Floating Popup"
        case .menuHideFloatingPopup: "Hide Floating Popup"
        case .menuOpenSettings: "Open Settings"
        case .menuStartMonitoring: "Start Monitoring"
        case .menuOpenSecuritySettings: "Open Security Settings"
        case .menuShowLockedPopup: "Show Locked Popup"
        case .menuSecuritySettingsDetail: "Adjust App Lock, privacy, and local protection."
        case .menuShowLockedPopupDetail: "Open the redacted popup shell without revealing content."
        case .menuCaptureStatusEmpty: "Empty"
        case .menuPauseOptions: "15 min | 1 hour | Until Resume"
        case .popupNoPinnedClips: "No pinned clips"
        case .popupNoMatchingClips: "No matching clips"
        case .popupHistoryEmpty: "Clipboard history is empty"
        case .popupSearchLockedTitle: "Search disabled while locked"
        case .popupSearchLockedDetail: "Unlock SlipBoard to search clipboard content, notes, and collections again."
        case .popupPinnedEmptyDetail: "Pinned items stay visible here so primary references always remain first."
        case .popupRecentEmptyDetail: "Recent captures will appear here once the runtime begins projecting clipboard activity."
        case .popupNoMatchDetail: "Try a broader query or switch the active filter to reveal more results."
        case .popupCurrentFilter: "Current filter %{filter}."
        case .popupCurrentGroup: "Current group %{group}."
        case .popupCurrentFilterAndGroup: "Current filter %{filter}, group %{group}."
        case .popupPinnedRailReady: "Pinned rail ready"
        case .popupNoResultsInRecent: "No results in recent"
        case .popupRecentRailWaiting: "Recent rail waiting"
        case .popupPinnedRailDetail: "Pinned items stay separated from recent history and keep their position when duplicate copies arrive."
        case .popupRecentSearchDetail: "Search is active%{context}. Clear the query or change filters to restore visible results."
        case .popupRecentRailDetail: "Recent captures remain in a dedicated horizontal rail, even when the live slice has nothing visible yet."
        case .popupFiltered: "Filtered"
        case .popupVisibleCount: "%{count} visible"
        case .popupResultCount: "%{count} results"
        case .popupReturnToPaste: "Return to paste"
        case .popupCopyToBegin: "Copy something to begin"
        case .popupCommandSearch: "Command / to search"
        case .popupSupportedTypes: "Copy text, image, file, URL, color, or rich text"
        case .popupResumeMonitoring: "Resume monitoring to capture new clips"
        case .popupShowPinned: "Show pinned"
        case .popupHidePinned: "Hide pinned"
        case .popupMoreActions: "More actions"
        case .popupClipFrom: "Clip from %{app}"
        case .popupUnlockRequired: "Unlock required"
        case .popupPreviewHidden: "Preview hidden"
        case .popupRichContent: "Rich content"
        case .popupAddNote: "Add note"
        case .popupUpdateNote: "Update note"
        case .popupNotesLocked: "Notes stay hidden while search is locked."
        case .popupSearchDisabled: "Search is currently disabled"
        case .popupLocked: "Locked"
        case .popupPrivate: "Private"
        case .popupTransformUnavailable: "Transform preview is unavailable for this item."
        case .popupPasteAsOnlyText: "Paste As is only available for text clips."
        case .popupExecutingPaste: "Pasting…"
        case .overlayEscapeCancel: "ESC cancel"
        case .overlayPlainText: "Plain Text"
        case .overlayConvertMarkdown: "Convert to Markdown"
        case .overlayStripUnicode: "Strip Unicode / Accent"
        case .overlayUppercase: "UPPERCASE"
        case .overlayLowercase: "lowercase"
        case .overlayRemoveRichFormatting: "Remove rich formatting"
        case .statusCaptureActive: "Capture Active"
        case .statusWaitingForCopy: "Waiting for Copy"
        case .statusUnsupportedIgnored: "Unsupported Ignored"
        case .statusCapturePaused: "Capture Paused"
        case .statusPauseMode: "Pause mode: %{value}"
        case .statusResumeFromMenu: "Resume capturing from the menu"
        case .statusExcludedAppActive: "Excluded App Active"
        case .statusExcludedIn: "Excluded in %{app}"
        case .statusCaptureIgnored: "Capture ignored for %{app}"
        case .statusCaptureIgnoredThisApp: "Capture ignored for this app"
        case .statusPopupHidesInExcludedApps: "Popup hides in excluded apps"
        case .statusPopupShowsInExcludedApps: "Popup still shows in excluded apps"
        case .statusHidePopupOn: "Hide popup is on"
        case .statusHidePopupOff: "Hide popup is off"
        case .statusAutoResume: "Auto-resume %{value}"
        case .statusManualPauseInfo: "Manual pause remains active until you resume."
        case .statusPauseTimedInfo: "Timed pause remains active until it expires or you resume manually."
        case .statusRelativeSeconds: "%{count}s"
        case .statusRelativeMinutes: "%{count}m"
        case .statusRelativeHours: "%{count}h"
        case .statusYesterday: "Yesterday"
        case .statusRelativeDays: "%{count}d"
        case .statusCaptureResumed: "Capture resumed."
        case .statusExcludedAppRemoved: "Excluded app removed."
        case .statusDeletedHistoryItem: "Deleted item from history."
        case .statusClearedHistory: "Cleared clipboard history."
        case .statusCopiedToClipboard: "Copied item to clipboard."
        case .statusSelectedUnavailableToCopy: "Selected item is unavailable to copy."
        case .statusUnpinnedItem: "Unpinned item."
        case .statusPinnedItem: "Pinned item."
        case .statusCommandUnavailable: "This command is not wired in the current runtime slice."
        case .statusPasteTargetUnavailable: "Could not return to the previous app. Focus its input, then open SlipBoard again."
        case .statusNoEligibleApp: "No eligible app was available to add."
        case .statusAddedExcludedApp: "Added %{app} to excluded apps."
        case .statusPausedFifteenMinutes: "Capture paused for 15 minutes."
        case .statusPausedOneHour: "Capture paused for 1 hour."
        case .statusPausedUntilResume: "Capture paused until you resume it."
        case .settingsGeneralDescription: "Startup, appearance, and lightweight popup defaults."
        case .settingsOrganizationDescription: "Local search, note mirrors, and collections stay on the same runtime path as the popup and menu bar shell."
        case .settingsSearchHeading: "Search"
        case .settingsSearchDescription: "FTS5 queries, note mirrors, and collection terms stay local. The runtime disables search entirely whenever App Lock is holding protected content."
        case .settingsSearchVisibility: "Search visibility"
        case .settingsNoteSource: "Note source of truth"
        case .settingsCollectionsHeading: "Collections"
        case .settingsCollectionsDescription: "Custom groups remain local-only and feed the popup chip strip plus the shared search filter path."
        case .settingsCreateFirstGroup: "Create first group"
        case .settingsLockedStateHeading: "Locked state"
        case .settingsSearchUnlockedDetail: "Clipboard content, notes, and collections are searchable while the runtime is unlocked."
        case .settingsNoteSourceDetail: "Note bodies stay behind the protected payload seam; this pane only reflects the unlocked mirror used for local search."
        case .settingsGroupActiveDetail: "Active group filter in the shared popup runtime."
        case .settingsGroupAvailableDetail: "Available in the popup organization strip."
        case .settingsSelected: "Selected"
        case .settingsCollectionsEmptyDetail: "Add collections from the runtime host, then use this pane and the popup chips to inspect the shared organization state."
        case .settingsSearchDisabledTitle: "Search is currently disabled"
        case .settingsAppLockLiveTitle: "Live App Lock integration"
        case .settingsSearchLockedDetail: "Search results, note drafts, and unlocked mirrors are cleared while locked. The popup, menu bar, and Security pane all route through the same local lock state."
        case .settingsSearchUnlockedLockDetail: "Search, notes, and groups remain on the same runtime path as the App Lock controller, encrypted payload store, and popup/menu shell."
        case .settingsRetentionDescription: "Set local limits, auto-clear rules, and asset-cache maintenance for one shared runtime path."
        case .settingsHistoryLimit: "History limit"
        case .settingsMaxItems: "Maximum items"
        case .settingsAssetCache: "Asset cache"
        case .settingsMaxCacheSize: "Max cache size"
        case .settingsClearNow: "Clear now"
        case .settingsClearOnQuit: "Clear on app quit"
        case .settingsRetentionPinnedNote: "Pinned clips stay exempt from count-based cleanup."
        case .settingsHistoryLimitDescription: "Keep local clips up to the configured limit before pruning the oldest unpinned entries."
        case .settingsPasteBehavior: "Paste behavior"
        case .settingsPasteBehaviorDescription: "Control how pasting a clip affects its position in Recent."
        case .settingsMovePastedToTop: "Move pasted item to top"
        case .settingsMovePastedToTopDetail: "When enabled, pasting a clip moves it to the front of Recent."
        case .settingsAutoClear: "Auto-clear"
        case .settingsAutoClearDescription: "Choose how long local history is retained before age-based cleanup runs."
        case .settingsRetentionPeriodDetail: "Quick retention in the menu bar mirrors this setting immediately."
        case .settingsClearOnQuitDetail: "When enabled, quitting wipes local history and clears cached assets together."
        case .settingsPinnedItems: "Pinned items"
        case .settingsPinnedPreserved: "Pinned clips are preserved"
        case .settingsPinnedPreservedDetail: "TTL sweeps and max-item pruning skip pinned clips until you unpin or delete them manually."
        case .settingsAssetCacheDescription: "Large previews and file-backed assets stay local and can be trimmed automatically or cleared on demand."
        case .settingsCacheRefreshDetail: "The runtime refreshes usage on launch, foreground, and after cleanup."
        case .settingsExclusionsDescription: "Excluded apps, popup-hide behavior, and pause state stay local to this Mac and route through the same live runtime used by the popup, menu bar, and pause hotkey."
        case .settingsExcludedApps: "Excluded apps"
        case .settingsAddApp: "Add App"
        case .settingsNoExcludedApps: "No excluded apps yet"
        case .settingsHidePopupInExcludedApps: "Hide popup inside excluded apps"
        case .settingsPauseCapture: "Pause capture"
        case .settingsPausePreset: "Pause preset"
        case .settingsExcludedAppsDescription: "Add the current or recently observed source app to skip capture before history insertion."
        case .settingsAddAppDetail: "Add the frontmost non-SlipBoard app or the newest observed source app from history."
        case .settingsRemoveApp: "Remove"
        case .settingsNoExcludedAppsDetail: "Use Add App to keep sensitive sources out of history and reuse the same exclusion path for capture and popup rules."
        case .settingsCaptureBehavior: "Capture behavior"
        case .settingsCaptureBehaviorDescription: "Popup suppression is optional and only applies while an excluded app is frontmost."
        case .settingsHidePopupDetail: "When on, the popup will not open and any visible popup is dismissed when an excluded app becomes frontmost."
        case .settingsExcludedAppActive: "Excluded app is currently active"
        case .settingsHidePopupBadge: "Hide popup"
        case .settingsCaptureOnlyBadge: "Capture only"
        case .settingsPauseDescription: "Manual and scheduled pauses share the same runtime path as the menu pause row and pause hotkey."
        case .settingsPausePresetDetail: "Choose a timed pause or keep capture paused until you resume manually."
        case .settingsResumeCapturing: "Resume capturing"
        case .settingsResumeCapturingDetail: "Resume immediately and clear any scheduled pause."
        case .settingsHotkeysDescription: "Assign the popup shortcut and snippet-specific shortcuts without leaving the existing settings shell."
        case .settingsGlobalShortcuts: "Global shortcuts"
        case .settingsSnippetsDescription: "Manage local quick snippets and their optional per-snippet hotkeys in a compact split editor."
        case .settingsSnippetLibrary: "Snippet library"
        case .settingsSnippetHotkeys: "Snippet hotkeys"
        case .settingsSnippetHotkeysDescription: "Assigned snippet shortcuts paste through the shared engine and are disabled while protected content is locked."
        case .settingsRuntimeStatus: "Runtime status"
        case .settingsNoSnippetShortcuts: "No snippet shortcuts yet"
        case .settingsNoSnippetShortcutsDetail: "Create snippets, then assign per-snippet hotkeys without leaving the live settings path."
        case .settingsHotkeyConflictTiming: "Conflicts are validated when a shortcut is assigned, not when it fires."
        case .settingsLibrary: "Library"
        case .settingsEditorState: "Editor state"
        case .settingsNoSnippets: "No snippets yet"
        case .settingsNoSnippetsDetail: "Create your first saved snippet to keep reusable text local to this Mac."
        case .settingsNoSnippetSelected: "No snippet selected"
        case .settingsSavedLocallyDetail: "Saved locally for direct paste and popup-side reuse."
        case .settingsPinnedBadge: "Pinned"
        case .settingsOpenBadge: "Open"
        case .settingsDirtyBadge: "Dirty"
        case .settingsReadyBadge: "Ready"
        case .settingsActiveBadge: "Active"
        case .settingsAssignedBadge: "Assigned"
        case .settingsGlobalHotkeysDescription: "The popup hotkey stays global. Paste As remains popup-scoped, and future commands stay unavailable until implemented."
        case .settingsSnippetLibraryDescription: "Each snippet keeps local title, content, optional hotkey, and pin state without a second store or cloud sync path."
        case .settingsCreateOrSelectSnippetDetail: "Create or select a snippet to edit its title, content, and hotkey assignment."
        case .settingsCurrentSnippetDraftDetail: "The current draft shares the popup hotkey and direct-paste runtime path."
        case .settingsSnippetMissingTitle: "Add a title before saving this snippet."
        case .settingsSnippetMissingContent: "Add snippet content before saving."
        case .settingsSnippetEditingDetail: "Snippet editing shares registration, conflict checking, and direct paste."
        case .settingsSecurityDescription: "Local app lock, preview privacy, and payload protection all flow through the live runtime path."
        case .securityAppLockDescription: "Use the current system authentication flow without creating a second SlipBoard password."
        case .securityUnlockMethod: "Unlock method"
        case .securityAutoLock: "Auto-lock"
        case .securityPrivacy: "Privacy"
        case .securityDataProtection: "Data protection"
        case .securityEncryptionStatus: "Encryption status"
        case .securityKeyStorage: "Key storage"
        case .securityDecryptedCache: "Decrypted cache"
        case .securityHidePreviews: "Hide previews in Mission Control / Expose"
        case .securityProtectedStorageUnavailable: "Protected storage unavailable"
        case .securityUnlocking: "Unlocking"
        case .securityUnlockFailed: "Unlock failed"
        case .securityUnlockUnavailable: "Unlock unavailable"
        case .securityUnlockInProgress: "Unlock in progress"
        case .securityLockToggleTitle: "Lock SlipBoard"
        case .securityLockToggleDetail: "The popup shell, menu bar summary, and search runtime stay redacted until unlock succeeds."
        case .securityUnlockMethodDescription: "Secure Enclave is preferred when available, with local password fallback on the current Mac."
        case .securityPreferredMethod: "Preferred method"
        case .securitySystemPassword: "System Password"
        case .securityAutoLockDescription: "Measure inactivity from the shared popup, menu bar, and settings interactions."
        case .securityTimeout: "Timeout"
        case .securityPrivacyDescription: "Redact previews on the existing shell surfaces instead of opening a detached privacy screen."
        case .securityHidePreviewsDetail: "Protected previews stay hidden outside the unlocked session while App Lock is active."
        case .securityDataProtectionDescription: "Inspect local encryption readiness, key wrapping policy, and whether decrypted content is still in memory."
        case .securityEncryptionDetail: "Protected payloads stay local and only decrypt on demand inside an unlocked session."
        case .securityKeyStorageDetail: "Payload keys remain local-only and never enter sync, export, or recovery flows."
        case .securityDecryptedCacheDetail: "Locking clears in-memory previews before the popup can show protected content again."
        case .securityInMemory: "In memory"
        case .securityCleared: "Cleared"
        case .bridgeDescription: "Bridge through your CloudKit private database while keeping Mac history local."
        case .bridgeEnable: "Enable iCloud Bridge"
        case .bridgePublishOnPaste: "Publish pasted item to devices"
        case .bridgeReceive: "Receive from iPhone"
        case .bridgeDevices: "Devices"
        case .bridgeNoDevices: "No companion devices yet"
        case .bridgeLastActivity: "Last activity"
        case .bridgeLastSent: "Last sent"
        case .bridgeLastReceived: "Last received"
        case .bridgeLastError: "Last error"
        case .bridgePendingImports: "Pending imports"
        case .bridgeLocalOnlyPolicy: "Local-only policy"
        case .bridgeStop: "Stop Bridge"
        case .bridgeStopDescription: "Turn off bridge activity on this Mac and keep existing local history intact."
        case .bridgeUnavailable: "iCloud Bridge unavailable"
        case .bridgeReady: "Ready"
        case .bridgeSyncing: "Syncing"
        case .bridgeError: "Error"
        case .alertClearClipboardHistoryTitle: "Clear Clipboard History?"
        case .alertClearClipboardHistoryMessage: "This removes every clip from SlipBoard, including pinned items. This can't be undone."
        case .alertAccessibilityTitle: "Allow SlipBoard to paste for you"
        case .alertAccessibilityMessage: "SlipBoard needs Accessibility permission to return focus and paste the selected clip into the app you were using."
        case .alertOpenAccessibilitySettings: "Open Accessibility Settings"
        case .alertDeleteSnippet: "Delete Snippet"
        case .alertDeleteSnippetMessage: "Snippet deleted. Any assigned shortcut is removed with it."
        case .alertConfirmDestructive: "Confirm destructive changes inline."
        case .accessibilityMoreActions: "More actions"
        case .accessibilityClipFrom: "Clip from %{app}"
        case .popupSort: "Sort"
        case .popupSortNewestFirst: "Newest First"
        case .settingsClearHistoryAfter: "Clear history after"
        case .overlayOpenTransformPreview: "Open transform preview"
        case .overlayMarkdownDescription: "Map clipboard text into markdown-friendly output"
        case .overlayStripUnicodeDescription: "Normalize special characters for plain transport"
        case .overlayUppercaseDescription: "Convert output to upper case"
        case .overlayLowercaseDescription: "Convert output to lower case"
        case .securityStateLocked: "SlipBoard is locked"
        case .securityStateUnlocked: "SlipBoard is unlocked"
        case .securityStateUnavailable: "SlipBoard status unavailable"
        case .securityMenuLocked: "SlipBoard locked"
        case .securityMenuUnlocked: "SlipBoard unlocked"
        case .securityMenuUnavailable: "SlipBoard security status unavailable"
        case .securityLockDetailManual: "Protected previews stay hidden until SlipBoard is unlocked again."
        case .securityLockDetailAutoLock: "Auto-lock hid your previews and disabled search until you unlock."
        case .securityLockDetailBackground: "Previews are hidden after leaving the active session."
        case .securityLockDetailAuthentication: "Use the approved system method from Settings to reveal protected content."
        case .securityLockDetailKeyUnavailable: "Protected storage is unavailable until the payload key can be unwrapped."
        case .securityLockDetailMigration: "Finish the current migration before protected content can be shown."
        case .securityLockDetailUnlocking: "SlipBoard is waiting for the current system authentication flow to finish."
        case .securityLockDetailFailed: "Use Unlock Slipboard or open Security settings to retry."
        case .securityLockDetailUnlocked: "Protected content is available."
        case .securityLockDetailUnknown: "Protected previews remain hidden until security state is available."
        case .clipRedactionNoSnapshot: "Protected previews stay hidden in this shell."
        case .clipRedactionLocked: "SlipBoard is locked, so clip previews and note bodies stay hidden until unlock succeeds."
        case .clipRedactionPrivacy: "Privacy mode is redacting this preview on the existing shell surface."
        case .popupLockTitleLocked: "SlipBoard is locked"
        case .popupLockTitleUnlocking: "Unlocking SlipBoard"
        case .popupLockTitleFailed: "SlipBoard stayed locked"
        case .popupLockTitleUnlocked: "SlipBoard is unlocked"
        case .popupLockDetailLocked: "Previews and search stay hidden inside this popup until you unlock from the menu or Security settings."
        case .popupLockDetailUnlocking: "SlipBoard is waiting for the current system authentication step to complete before showing protected content."
        case .popupLockDetailFailed: "Protected previews remain hidden after the last unlock attempt. Retry from the menu bar or open Security settings."
        case .popupLockDetailUnlocked: "Protected content is visible."
        case .popupLockHintLocked: "Unlock from menu or settings"
        case .popupLockHintUnlocking: "Waiting for system auth"
        case .popupLockHintFailed: "Retry unlock from menu"
        case .popupLockHintUnlocked: "Protected content visible"
        case .bridgeBehavior: "Bridge behavior"
        case .bridgeScope: "Scope"
        case .bridgeScopeDetail: "Bridge through CloudKit private database without uploading full SlipBoard history."
        case .bridgeEnableDetail: "Bridge through CloudKit private database without uploading full SlipBoard history."
        case .bridgePublishDetail: "Double-click or Enter on Mac pastes locally and publishes that same item to devices on the same iCloud account."
        case .bridgeReceiveDetail: "Companion imports from iPhone appear in SlipBoard on Mac."
        case .bridgePasteFlow: "Paste flow"
        case .bridgePickOnMac: "Pick on Mac"
        case .bridgePickOnMacDetail: "Double-click or press Enter from the popup grid."
        case .bridgePasteOnMac: "Paste on Mac"
        case .bridgePasteOnMacDetail: "SlipBoard still pastes into the current app as usual."
        case .bridgePublishOneShot: "Publish one-shot bridge record"
        case .bridgePublishOneShotDetail: "Only the item just pasted is sent with a short TTL and cleanup after use."
        case .bridgeReceiveOnIPhone: "Receive on iPhone"
        case .bridgeReceiveOnIPhoneDetail: "The iPhone companion receives the item so the user can paste again there."
        case .bridgeSameICloudAccount: "Same iCloud account"
        case .bridgeReview: "Review"
        case .bridgeNoMacPastes: "No intentional Mac paste has been bridged yet."
        case .bridgeNoCompanionImports: "No companion import has been added to local Mac history yet."
        case .bridgeSentSupportedDetail: "Only successful local paste actions of supported kinds are published."
        case .bridgeReceivedLocalDetail: "Companion-created records enter Mac history through the existing local history path."
        case .bridgeEligiblePendingDetail: "Eligible companion records are waiting to enter local Mac history."
        case .bridgeBehaviorDescription: "Paste on Mac, then paste on iPhone. Mac history stays local and no full-history upload is performed."
        case .bridgeDevicesDescription: "Bridge can stay enabled on Mac before a companion signs into the same iCloud account."
        case .bridgeObservedDevicesDescription: "Observed devices on the same iCloud account from bridge activity."
        case .bridgeActivityDescription: "Outbound publish is one-shot with a 10-minute TTL; inbound imports remain explicit companion records."
        case .bridgeLocalHistoryTitle: "Local history stays local"
        case .bridgePendingImportsDetail: "Incoming bridge records waiting for Mac import."
        case .bridgeOneShotTTL: "TTL %{minutes} min"
        case .hotkeyRecorderInstruction: "Press the shortcut you want to assign. Press Escape to cancel."
        case .hotkeyAccessLocked: "Shortcut access is locked"
        case .hotkeyInfo: "Shortcut info"
        case .hotkeyAccessLockedDetail: "Unlock SlipBoard to view and edit shortcuts."
        case .hotkeyInfoDetail: "Review or update the shortcuts available on this Mac."
        case .hotkeyOpenSlipBoardDetail: "Open SlipBoard from anywhere."
        case .hotkeyPasteAsDetail: "Open Paste As for the selected clip."
        case .hotkeyPauseCaptureDetail: "Pause or resume clipboard capture."
        case .hotkeySnippetDetail: "Use this shortcut to paste the snippet."
        case .hotkeyFutureCommandDetail: "This shortcut will become available in a future update."
        case .hotkeyConflictDetail: "This shortcut is already assigned. Choose another shortcut."
        case .hotkeyUnlockToEdit: "Unlock SlipBoard to edit this shortcut."
        case .bridgeScopeLabel: "Scope"
        case .bridgeSupportedPastesV1Detail: "Only successful local pastes of supported kinds are bridged in v1."
        case .bridgeNoDevicesDetail: "Bridge can stay enabled on Mac before an iPhone companion signs into the same iCloud account."
        case .bridgeSubtitleFallback: "Paste on Mac, then paste on iPhone. Mac history stays local."
        case .bridgeDeviceLastSeenDetail: "Same iCloud account · Last seen %{time}"
        }
    }
}

struct LocalizationCatalog: Sendable {
    private let english: [LocalizationKey: String]
    private let vietnamese: [LocalizationKey: String]

    init(
        english: [LocalizationKey: String] = LocalizationCatalog.defaultEnglish,
        vietnamese: [LocalizationKey: String] = LocalizationCatalog.defaultVietnamese
    ) {
        self.english = english
        self.vietnamese = vietnamese
    }

    func template(for key: LocalizationKey, language: AppLanguage) -> String? {
        switch language {
        case .english:
            english[key]
        case .vietnamese:
            vietnamese[key]
        }
    }

    func englishTemplate(for key: LocalizationKey) -> String? {
        english[key]
    }

    func missingKeys() -> [LocalizationKey] {
        LocalizationKey.allCases.filter {
            englishTemplate(for: $0) == nil || template(for: $0, language: .vietnamese) == nil
        }
    }

    static var defaultMissingKeys: [LocalizationKey] {
        LocalizationCatalog().missingKeys()
    }

    private static let defaultEnglish = Dictionary(
        uniqueKeysWithValues: LocalizationKey.allCases.map { ($0, $0.englishFallback) }
    )

    private static let defaultVietnamese: [LocalizationKey: String] = [
        .appName: "SlipBoard",
        .language: "Ngôn ngữ",
        .languageEnglish: "English",
        .languageVietnamese: "Tiếng Việt",
        .search: "Tìm kiếm",
        .searchPlaceholder: "Tìm lịch sử clipboard",
        .save: "Lưu",
        .cancel: "Hủy",
        .done: "Xong",
        .close: "Đóng",
        .add: "Thêm",
        .remove: "Xóa",
        .edit: "Sửa",
        .delete: "Xóa",
        .enabled: "Bật",
        .disabled: "Tắt",
        .locked: "Đã khóa",
        .unlocked: "Đã mở khóa",
        .loading: "Đang tải",
        .none: "Không có",
        .menuAppearanceAuto: "Tự động",
        .menuAppearanceDark: "Tối",
        .menuAppearanceLight: "Sáng",
        .menuPauseCapture: "Tạm dừng ghi clipboard",
        .menuResumeCapture: "Tiếp tục ghi clipboard",
        .menuClearHistory: "Xóa lịch sử",
        .menuSettings: "Cài đặt...",
        .menuQuit: "Thoát SlipBoard",
        .menuOpenSlipBoard: "Mở SlipBoard",
        .menuCaptureStatus: "Trạng thái ghi",
        .menuRetention: "Lưu giữ",
        .historyItemCount: "mục",
        .sidebarGeneral: "Chung",
        .sidebarOrganization: "Tổ chức",
        .sidebarBridge: "Cầu nối",
        .sidebarRetention: "Lưu giữ",
        .sidebarExclusions: "Loại trừ",
        .sidebarHotkeys: "Phím tắt",
        .sidebarSnippets: "Đoạn mã",
        .sidebarSecurity: "Bảo mật",
        .popupPinned: "Đã ghim",
        .popupRecent: "Gần đây",
        .popupCollections: "Bộ sưu tập",
        .popupNoItems: "Không có mục clipboard",
        .actionCopy: "Sao chép",
        .actionPaste: "Dán",
        .actionPasteAs: "Dán dưới dạng",
        .actionPin: "Ghim",
        .actionUnpin: "Bỏ ghim",
        .actionDelete: "Xóa",
        .actionClear: "Xóa",
        .statusActive: "Hoạt động %{value}",
        .statusPaused: "Đã tạm dừng",
        .statusPausedUntil: "Tạm dừng đến %{value}",
        .statusResumes: "Tiếp tục %{value}",
        .statusAutoResumes: "Tự tiếp tục %{value}",
        .settingsLanguageTitle: "Ngôn ngữ hiển thị",
        .settingsLanguageDescription: "Chọn ngôn ngữ dùng trong SlipBoard.",
        .settingsAppearance: "Giao diện",
        .settingsTheme: "Chủ đề",
        .settingsGeneral: "Chung",
        .settingsSecurity: "Bảo mật",
        .settingsOrganization: "Tổ chức",
        .settingsStartupHeading: "Khởi động",
        .settingsLaunchAtLogin: "Mở khi đăng nhập",
        .settingsLaunchAtLoginDetail: "Tự động mở SlipBoard khi bạn đăng nhập vào máy.",
        .settingsBridge: "Cầu nối",
        .settingsRetention: "Lưu giữ",
        .settingsExclusions: "Loại trừ",
        .settingsHotkeys: "Phím tắt",
        .settingsSnippets: "Đoạn mã",
        .securityLockSlipBoard: "Khóa SlipBoard",
        .securityCurrentState: "Trạng thái hiện tại",
        .securityUnlock: "Mở khóa",
        .securityAutoLockOneMinute: "1 phút",
        .securityAutoLockFiveMinutes: "5 phút",
        .securityAutoLockFifteenMinutes: "15 phút",
        .securityAutoLockOneHour: "1 giờ",
        .retentionNever: "Không bao giờ",
        .retentionOneWeek: "1 tuần",
        .retentionTwoWeeks: "2 tuần",
        .retentionOneMonth: "1 tháng",
        .retentionThreeMonths: "3 tháng",
        .retentionForever: "∞",
        .alertClearHistoryTitle: "Xóa lịch sử?",
        .alertClearHistoryMessage: "Thao tác này sẽ xóa vĩnh viễn toàn bộ lịch sử clipboard.",
        .alertConfirm: "Xác nhận",
        .alertDelete: "Xóa",
        .accessibilitySettings: "Cài đặt",
        .accessibilityClose: "Đóng",
        .commonOn: "Bật",
        .commonOff: "Tắt",
        .commonActive: "Hoạt động",
        .commonAvailable: "Khả dụng",
        .commonUnavailable: "Không khả dụng",
        .commonError: "Lỗi",
        .commonReady: "Sẵn sàng",
        .commonPending: "Đang chờ",
        .commonRestricted: "Bị hạn chế",
        .commonFuture: "Tương lai",
        .commonLive: "Trực tiếp",
        .commonLocal: "Cục bộ",
        .commonAll: "Tất cả",
        .commonStatus: "Trạng thái",
        .commonSource: "Nguồn",
        .commonKind: "Loại",
        .commonTitle: "Tiêu đề",
        .commonContent: "Nội dung",
        .commonName: "Tên",
        .commonDetails: "Chi tiết",
        .commonMore: "Thêm",
        .commonRetry: "Thử lại",
        .commonRefreshNow: "Làm mới ngay",
        .commonNotNow: "Không phải bây giờ",
        .commonNotSet: "Chưa đặt",
        .commonOpen: "Mở",
        .commonNow: "Bây giờ",
        .contentText: "Văn bản",
        .contentCode: "Mã",
        .contentImage: "Hình ảnh",
        .contentFile: "Tệp",
        .contentURL: "URL",
        .contentColor: "Màu",
        .contentRichText: "Văn bản có định dạng",
        .menuStatus: "Trạng thái",
        .menuSecurity: "Bảo mật",
        .menuPauseFor: "Tạm dừng trong %{duration}",
        .menuPausedUntilResume: "Tạm dừng đến khi tiếp tục",
        .menuPauseMonitoring: "Tạm dừng theo dõi",
        .menuShowFloatingPopup: "Hiện popup nổi",
        .menuHideFloatingPopup: "Ẩn popup nổi",
        .menuOpenSettings: "Mở cài đặt",
        .menuStartMonitoring: "Bắt đầu theo dõi",
        .menuOpenSecuritySettings: "Mở Cài đặt Bảo mật",
        .menuShowLockedPopup: "Hiện popup đã khóa",
        .menuSecuritySettingsDetail: "Điều chỉnh Khóa ứng dụng, quyền riêng tư và bảo vệ cục bộ.",
        .menuShowLockedPopupDetail: "Mở giao diện popup đã che mà không hiện nội dung.",
        .menuCaptureStatusEmpty: "Trống",
        .menuPauseOptions: "15 phút | 1 giờ | Đến khi tiếp tục",
        .popupNoPinnedClips: "Không có clip đã ghim",
        .popupNoMatchingClips: "Không có clip phù hợp",
        .popupHistoryEmpty: "Lịch sử clipboard trống",
        .popupSearchLockedTitle: "Tìm kiếm bị tắt khi đang khóa",
        .popupSearchLockedDetail: "Mở khóa SlipBoard để tìm lại nội dung clipboard, ghi chú và bộ sưu tập.",
        .popupPinnedEmptyDetail: "Các mục đã ghim vẫn hiển thị ở đây để nội dung quan trọng luôn ở đầu.",
        .popupRecentEmptyDetail: "Các nội dung mới sao chép sẽ xuất hiện ở đây khi runtime bắt đầu ghi nhận hoạt động clipboard.",
        .popupNoMatchDetail: "Hãy thử từ khóa rộng hơn hoặc đổi bộ lọc đang dùng để xem thêm kết quả.",
        .popupCurrentFilter: "Bộ lọc hiện tại: %{filter}.",
        .popupCurrentGroup: "Nhóm hiện tại: %{group}.",
        .popupCurrentFilterAndGroup: "Bộ lọc hiện tại: %{filter}, nhóm: %{group}.",
        .popupPinnedRailReady: "Dải đã ghim đã sẵn sàng",
        .popupNoResultsInRecent: "Không có kết quả trong mục gần đây",
        .popupRecentRailWaiting: "Dải gần đây đang chờ",
        .popupPinnedRailDetail: "Các mục đã ghim được tách khỏi lịch sử gần đây và giữ nguyên vị trí khi có bản sao trùng lặp.",
        .popupRecentSearchDetail: "Tìm kiếm đang hoạt động%{context}. Xóa từ khóa hoặc đổi bộ lọc để hiện lại kết quả.",
        .popupRecentRailDetail: "Các nội dung mới sao chép vẫn nằm trong một dải ngang riêng, kể cả khi lát cắt trực tiếp chưa có mục nào hiển thị.",
        .popupFiltered: "Đã lọc",
        .popupVisibleCount: "%{count} hiển thị",
        .popupResultCount: "%{count} kết quả",
        .popupReturnToPaste: "Quay lại để dán",
        .popupCopyToBegin: "Sao chép nội dung để bắt đầu",
        .popupCommandSearch: "Command / để tìm kiếm",
        .popupSupportedTypes: "Sao chép văn bản, hình ảnh, tệp, URL, màu hoặc văn bản có định dạng",
        .popupResumeMonitoring: "Tiếp tục theo dõi để ghi clip mới",
        .popupShowPinned: "Hiện mục đã ghim",
        .popupHidePinned: "Ẩn mục đã ghim",
        .popupMoreActions: "Thao tác khác",
        .popupClipFrom: "Clip từ %{app}",
        .popupUnlockRequired: "Cần mở khóa",
        .popupPreviewHidden: "Đã ẩn xem trước",
        .popupRichContent: "Nội dung có định dạng",
        .popupAddNote: "Thêm ghi chú",
        .popupUpdateNote: "Cập nhật ghi chú",
        .popupNotesLocked: "Ghi chú được ẩn khi tìm kiếm bị khóa.",
        .popupSearchDisabled: "Tìm kiếm hiện bị tắt",
        .popupLocked: "Đã khóa",
        .popupPrivate: "Riêng tư",
        .popupTransformUnavailable: "Không có bản xem trước chuyển đổi cho mục này.",
        .popupPasteAsOnlyText: "Dán dưới dạng chỉ khả dụng cho clip văn bản.",
        .popupExecutingPaste: "Đang dán…",
        .overlayEscapeCancel: "ESC để hủy",
        .overlayPlainText: "Văn bản thuần",
        .overlayConvertMarkdown: "Chuyển sang Markdown",
        .overlayStripUnicode: "Bỏ Unicode / dấu",
        .overlayUppercase: "CHỮ HOA",
        .overlayLowercase: "chữ thường",
        .overlayRemoveRichFormatting: "Xóa định dạng phong phú",
        .statusCaptureActive: "Đang ghi clipboard",
        .statusWaitingForCopy: "Đang chờ sao chép",
        .statusUnsupportedIgnored: "Đã bỏ qua nội dung không hỗ trợ",
        .statusCapturePaused: "Đã tạm dừng ghi",
        .statusPauseMode: "Chế độ tạm dừng: %{value}",
        .statusResumeFromMenu: "Tiếp tục ghi từ menu",
        .statusExcludedAppActive: "Ứng dụng loại trừ đang hoạt động",
        .statusExcludedIn: "Đã loại trừ trong %{app}",
        .statusCaptureIgnored: "Đã bỏ qua ghi từ %{app}",
        .statusCaptureIgnoredThisApp: "Đã bỏ qua ghi từ ứng dụng này",
        .statusPopupHidesInExcludedApps: "Popup sẽ ẩn trong ứng dụng loại trừ",
        .statusPopupShowsInExcludedApps: "Popup vẫn hiển thị trong ứng dụng loại trừ",
        .statusHidePopupOn: "Đang bật ẩn popup",
        .statusHidePopupOff: "Đang tắt ẩn popup",
        .statusAutoResume: "Tự tiếp tục %{value}",
        .statusManualPauseInfo: "Tạm dừng thủ công tiếp tục cho đến khi bạn bật lại.",
        .statusPauseTimedInfo: "Tạm dừng theo thời gian tiếp tục đến khi hết hạn hoặc bạn bật lại thủ công.",
        .statusRelativeSeconds: "%{count}gi",
        .statusRelativeMinutes: "%{count}ph",
        .statusRelativeHours: "%{count}giờ",
        .statusYesterday: "Hôm qua",
        .statusRelativeDays: "%{count}ng",
        .statusCaptureResumed: "Đã tiếp tục ghi clipboard.",
        .statusExcludedAppRemoved: "Đã xóa ứng dụng khỏi danh sách loại trừ.",
        .statusDeletedHistoryItem: "Đã xóa mục khỏi lịch sử.",
        .statusClearedHistory: "Đã xóa lịch sử clipboard.",
        .statusCopiedToClipboard: "Đã sao chép mục vào clipboard.",
        .statusSelectedUnavailableToCopy: "Không thể sao chép mục đã chọn.",
        .statusUnpinnedItem: "Đã bỏ ghim mục.",
        .statusPinnedItem: "Đã ghim mục.",
        .statusCommandUnavailable: "Lệnh này chưa được nối trong runtime hiện tại.",
        .statusPasteTargetUnavailable: "Không thể quay lại ứng dụng trước. Hãy đặt con trỏ vào ô nhập rồi mở lại SlipBoard.",
        .statusNoEligibleApp: "Không có ứng dụng phù hợp để thêm.",
        .statusAddedExcludedApp: "Đã thêm %{app} vào ứng dụng loại trừ.",
        .statusPausedFifteenMinutes: "Đã tạm dừng ghi trong 15 phút.",
        .statusPausedOneHour: "Đã tạm dừng ghi trong 1 giờ.",
        .statusPausedUntilResume: "Đã tạm dừng ghi cho đến khi bạn tiếp tục.",
        .settingsGeneralDescription: "Khởi động, giao diện và các mặc định nhẹ cho popup.",
        .settingsOrganizationDescription: "Tìm kiếm cục bộ, bản sao ghi chú và bộ sưu tập đi cùng luồng runtime của popup và menu bar.",
        .settingsSearchHeading: "Tìm kiếm",
        .settingsSearchDescription: "Truy vấn FTS5, bản sao ghi chú và thuật ngữ bộ sưu tập luôn cục bộ. Runtime tắt hoàn toàn tìm kiếm khi App Lock giữ nội dung được bảo vệ.",
        .settingsSearchVisibility: "Hiển thị tìm kiếm",
        .settingsNoteSource: "Nguồn dữ liệu ghi chú",
        .settingsCollectionsHeading: "Bộ sưu tập",
        .settingsCollectionsDescription: "Nhóm tùy chỉnh chỉ lưu cục bộ và cấp dữ liệu cho dải chip popup cùng bộ lọc tìm kiếm chung.",
        .settingsCreateFirstGroup: "Tạo nhóm đầu tiên",
        .settingsLockedStateHeading: "Trạng thái khóa",
        .settingsSearchUnlockedDetail: "Có thể tìm kiếm nội dung clipboard, ghi chú và bộ sưu tập khi runtime đã mở khóa.",
        .settingsNoteSourceDetail: "Nội dung ghi chú nằm sau lớp dữ liệu được bảo vệ; khung này chỉ phản ánh bản sao đã mở khóa dùng cho tìm kiếm cục bộ.",
        .settingsGroupActiveDetail: "Bộ lọc nhóm đang hoạt động trong runtime popup dùng chung.",
        .settingsGroupAvailableDetail: "Có trong dải tổ chức của popup.",
        .settingsSelected: "Đã chọn",
        .settingsCollectionsEmptyDetail: "Thêm bộ sưu tập từ runtime host, rồi dùng khung này và các chip popup để xem trạng thái tổ chức dùng chung.",
        .settingsSearchDisabledTitle: "Tìm kiếm hiện đang bị tắt",
        .settingsAppLockLiveTitle: "Tích hợp Khóa ứng dụng trực tiếp",
        .settingsSearchLockedDetail: "Kết quả tìm kiếm, bản nháp ghi chú và bản sao đã mở khóa sẽ bị xóa khi khóa. Popup, menu bar và khung Bảo mật đều dùng chung trạng thái khóa cục bộ.",
        .settingsSearchUnlockedLockDetail: "Tìm kiếm, ghi chú và nhóm dùng chung runtime với bộ điều khiển Khóa ứng dụng, kho dữ liệu mã hóa và giao diện popup/menu.",
        .settingsRetentionDescription: "Đặt giới hạn cục bộ, quy tắc tự dọn và bảo trì bộ nhớ đệm tài sản cho một luồng runtime chung.",
        .settingsHistoryLimit: "Giới hạn lịch sử",
        .settingsMaxItems: "Số mục tối đa",
        .settingsAssetCache: "Bộ nhớ đệm tài sản",
        .settingsMaxCacheSize: "Kích thước đệm tối đa",
        .settingsClearNow: "Xóa ngay",
        .settingsClearOnQuit: "Xóa khi thoát ứng dụng",
        .settingsRetentionPinnedNote: "Clip đã ghim không bị dọn theo số lượng.",
        .settingsHistoryLimitDescription: "Giữ clip cục bộ đến giới hạn đã cấu hình trước khi dọn các mục cũ nhất chưa ghim.",
        .settingsPasteBehavior: "Hành vi dán",
        .settingsPasteBehaviorDescription: "Kiểm soát việc dán clip ảnh hưởng thế nào đến vị trí trong mục Gần đây.",
        .settingsMovePastedToTop: "Đưa mục vừa dán lên đầu",
        .settingsMovePastedToTopDetail: "Khi bật, clip vừa dán sẽ được đưa lên đầu mục Gần đây.",
        .settingsAutoClear: "Tự động xóa",
        .settingsAutoClearDescription: "Chọn thời gian giữ lịch sử cục bộ trước khi chạy dọn theo tuổi dữ liệu.",
        .settingsRetentionPeriodDetail: "Mức lưu giữ nhanh trên menu bar phản ánh cài đặt này ngay lập tức.",
        .settingsClearOnQuitDetail: "Khi bật, thoát ứng dụng sẽ xóa lịch sử cục bộ và tài sản đã lưu đệm.",
        .settingsPinnedItems: "Mục đã ghim",
        .settingsPinnedPreserved: "Clip đã ghim được giữ lại",
        .settingsPinnedPreservedDetail: "Dọn TTL và giới hạn số mục sẽ bỏ qua clip đã ghim đến khi bạn bỏ ghim hoặc xóa thủ công.",
        .settingsAssetCacheDescription: "Bản xem trước lớn và tài sản từ tệp luôn ở cục bộ, có thể tự thu gọn hoặc xóa theo yêu cầu.",
        .settingsCacheRefreshDetail: "Runtime cập nhật dung lượng khi mở app, trở lại foreground và sau khi dọn.",
        .settingsExclusionsDescription: "Ứng dụng loại trừ, hành vi ẩn popup và trạng thái tạm dừng chỉ lưu trên máy Mac này, dùng chung runtime với popup, menu bar và phím tắt tạm dừng.",
        .settingsExcludedApps: "Ứng dụng loại trừ",
        .settingsAddApp: "Thêm ứng dụng",
        .settingsNoExcludedApps: "Chưa có ứng dụng loại trừ",
        .settingsHidePopupInExcludedApps: "Ẩn popup trong ứng dụng loại trừ",
        .settingsPauseCapture: "Tạm dừng ghi",
        .settingsPausePreset: "Mức tạm dừng",
        .settingsExcludedAppsDescription: "Thêm ứng dụng nguồn hiện tại hoặc vừa quan sát để bỏ qua ghi trước khi đưa vào lịch sử.",
        .settingsAddAppDetail: "Thêm ứng dụng không phải SlipBoard đang ở trước hoặc ứng dụng nguồn mới nhất trong lịch sử.",
        .settingsRemoveApp: "Xóa",
        .settingsNoExcludedAppsDetail: "Dùng Thêm ứng dụng để loại nguồn nhạy cảm khỏi lịch sử và dùng chung quy tắc loại trừ cho ghi và popup.",
        .settingsCaptureBehavior: "Hành vi ghi",
        .settingsCaptureBehaviorDescription: "Ẩn popup là tùy chọn và chỉ áp dụng khi ứng dụng loại trừ đang ở trước.",
        .settingsHidePopupDetail: "Khi bật, popup sẽ không mở và popup đang hiện sẽ đóng khi ứng dụng loại trừ lên trước.",
        .settingsExcludedAppActive: "Ứng dụng loại trừ đang hoạt động",
        .settingsHidePopupBadge: "Ẩn popup",
        .settingsCaptureOnlyBadge: "Chỉ bỏ ghi",
        .settingsPauseDescription: "Tạm dừng thủ công và theo lịch dùng chung runtime với hàng tạm dừng trên menu và phím tắt.",
        .settingsPausePresetDetail: "Chọn tạm dừng theo thời gian hoặc giữ tạm dừng đến khi bạn tiếp tục thủ công.",
        .settingsResumeCapturing: "Tiếp tục ghi",
        .settingsResumeCapturingDetail: "Tiếp tục ngay và xóa lịch tạm dừng hiện tại.",
        .settingsHotkeysDescription: "Gán phím tắt popup và phím tắt riêng cho snippet mà không rời cửa sổ cài đặt hiện tại.",
        .settingsGlobalShortcuts: "Phím tắt toàn cục",
        .settingsSnippetsDescription: "Quản lý snippet nhanh cục bộ và phím tắt tùy chọn của chúng trong trình soạn thảo tách gọn.",
        .settingsSnippetLibrary: "Thư viện snippet",
        .settingsSnippetHotkeys: "Phím tắt snippet",
        .settingsSnippetHotkeysDescription: "Phím tắt snippet dán qua engine dùng chung và bị tắt khi nội dung được bảo vệ đang khóa.",
        .settingsRuntimeStatus: "Trạng thái runtime",
        .settingsNoSnippetShortcuts: "Chưa có phím tắt snippet",
        .settingsNoSnippetShortcutsDetail: "Tạo snippet rồi gán phím tắt riêng mà không rời luồng cài đặt trực tiếp.",
        .settingsHotkeyConflictTiming: "Xung đột được kiểm tra khi gán phím tắt, không phải lúc kích hoạt.",
        .settingsLibrary: "Thư viện",
        .settingsEditorState: "Trạng thái trình soạn thảo",
        .settingsNoSnippets: "Chưa có snippet",
        .settingsNoSnippetsDetail: "Tạo snippet đầu tiên để giữ văn bản tái sử dụng cục bộ trên máy Mac này.",
        .settingsNoSnippetSelected: "Chưa chọn snippet",
        .settingsSavedLocallyDetail: "Được lưu cục bộ để dán trực tiếp và tái sử dụng trong popup.",
        .settingsPinnedBadge: "Đã ghim",
        .settingsOpenBadge: "Đang mở",
        .settingsDirtyBadge: "Chưa lưu",
        .settingsReadyBadge: "Sẵn sàng",
        .settingsActiveBadge: "Hoạt động",
        .settingsAssignedBadge: "Đã gán",
        .settingsGlobalHotkeysDescription: "Phím tắt popup hoạt động toàn cục. Dán dưới dạng chỉ trong popup và lệnh tương lai chưa khả dụng đến khi được triển khai.",
        .settingsSnippetLibraryDescription: "Mỗi snippet giữ tiêu đề, nội dung, phím tắt tùy chọn và trạng thái ghim cục bộ mà không có kho thứ hai hay đồng bộ đám mây.",
        .settingsCreateOrSelectSnippetDetail: "Tạo hoặc chọn snippet để sửa tiêu đề, nội dung và phím tắt.",
        .settingsCurrentSnippetDraftDetail: "Bản nháp hiện tại dùng chung runtime với phím tắt popup và dán trực tiếp.",
        .settingsSnippetMissingTitle: "Thêm tiêu đề trước khi lưu snippet này.",
        .settingsSnippetMissingContent: "Thêm nội dung snippet trước khi lưu.",
        .settingsSnippetEditingDetail: "Chỉnh sửa snippet dùng chung luồng đăng ký, kiểm tra xung đột và dán trực tiếp.",
        .settingsSecurityDescription: "Khóa ứng dụng cục bộ, quyền riêng tư xem trước và bảo vệ payload đều đi qua luồng runtime đang hoạt động.",
        .securityAppLockDescription: "Dùng quy trình xác thực hệ thống hiện có mà không tạo mật khẩu SlipBoard thứ hai.",
        .securityUnlockMethod: "Phương thức mở khóa",
        .securityAutoLock: "Tự động khóa",
        .securityPrivacy: "Quyền riêng tư",
        .securityDataProtection: "Bảo vệ dữ liệu",
        .securityEncryptionStatus: "Trạng thái mã hóa",
        .securityKeyStorage: "Lưu trữ khóa",
        .securityDecryptedCache: "Bộ nhớ đệm đã giải mã",
        .securityHidePreviews: "Ẩn xem trước trong Mission Control / Expose",
        .securityProtectedStorageUnavailable: "Không thể dùng bộ nhớ bảo vệ",
        .securityUnlocking: "Đang mở khóa",
        .securityUnlockFailed: "Mở khóa thất bại",
        .securityUnlockUnavailable: "Không thể mở khóa",
        .securityUnlockInProgress: "Đang xử lý mở khóa",
        .securityLockToggleTitle: "Khóa SlipBoard",
        .securityLockToggleDetail: "Popup, tóm tắt menu bar và tìm kiếm vẫn bị che cho đến khi mở khóa thành công.",
        .securityUnlockMethodDescription: "Ưu tiên Secure Enclave khi khả dụng, với mật khẩu cục bộ dự phòng trên máy Mac hiện tại.",
        .securityPreferredMethod: "Phương thức ưu tiên",
        .securitySystemPassword: "Mật khẩu hệ thống",
        .securityAutoLockDescription: "Đo thời gian không hoạt động từ các tương tác popup, menu bar và cài đặt dùng chung.",
        .securityTimeout: "Thời gian chờ",
        .securityPrivacyDescription: "Che bản xem trước ngay trên giao diện hiện có thay vì mở một màn hình riêng tư tách biệt.",
        .securityHidePreviewsDetail: "Bản xem trước được bảo vệ sẽ ẩn ngoài phiên đã mở khóa khi Khóa ứng dụng đang bật.",
        .securityDataProtectionDescription: "Kiểm tra trạng thái mã hóa cục bộ, chính sách bọc khóa và việc nội dung đã giải mã còn trong bộ nhớ hay không.",
        .securityEncryptionDetail: "Dữ liệu được bảo vệ luôn ở cục bộ và chỉ giải mã theo yêu cầu trong phiên đã mở khóa.",
        .securityKeyStorageDetail: "Khóa dữ liệu chỉ ở cục bộ và không bao giờ đi vào luồng đồng bộ, xuất hoặc khôi phục.",
        .securityDecryptedCacheDetail: "Khi khóa, bản xem trước trong bộ nhớ bị xóa trước khi popup có thể hiện lại nội dung được bảo vệ.",
        .securityInMemory: "Trong bộ nhớ",
        .securityCleared: "Đã xóa",
        .bridgeDescription: "Kết nối qua cơ sở dữ liệu iCloud riêng tư trong khi vẫn giữ lịch sử Mac cục bộ.",
        .bridgeEnable: "Bật iCloud Bridge",
        .bridgePublishOnPaste: "Gửi mục đã dán đến thiết bị",
        .bridgeReceive: "Nhận từ iPhone",
        .bridgeDevices: "Thiết bị",
        .bridgeNoDevices: "Chưa có thiết bị đồng hành",
        .bridgeLastActivity: "Hoạt động gần nhất",
        .bridgeLastSent: "Gửi gần nhất",
        .bridgeLastReceived: "Nhận gần nhất",
        .bridgeLastError: "Lỗi gần nhất",
        .bridgePendingImports: "Đang chờ nhập",
        .bridgeLocalOnlyPolicy: "Chính sách chỉ cục bộ",
        .bridgeStop: "Dừng Bridge",
        .bridgeStopDescription: "Tắt hoạt động bridge trên máy Mac này và giữ nguyên lịch sử cục bộ hiện có.",
        .bridgeUnavailable: "Không thể dùng iCloud Bridge",
        .bridgeReady: "Sẵn sàng",
        .bridgeSyncing: "Đang đồng bộ",
        .bridgeError: "Lỗi",
        .alertClearClipboardHistoryTitle: "Xóa lịch sử clipboard?",
        .alertClearClipboardHistoryMessage: "Thao tác này xóa vĩnh viễn mọi clip khỏi SlipBoard, gồm cả mục đã ghim. Không thể hoàn tác.",
        .alertAccessibilityTitle: "Cho phép SlipBoard dán thay bạn",
        .alertAccessibilityMessage: "SlipBoard cần quyền Trợ năng để trả tiêu điểm và dán clip đã chọn vào ứng dụng bạn đang dùng.",
        .alertOpenAccessibilitySettings: "Mở cài đặt Trợ năng",
        .alertDeleteSnippet: "Xóa snippet",
        .alertDeleteSnippetMessage: "Đã xóa snippet. Mọi phím tắt được gán cũng bị xóa theo.",
        .alertConfirmDestructive: "Xác nhận thay đổi có tính hủy trực tiếp.",
        .accessibilityMoreActions: "Thao tác khác",
        .accessibilityClipFrom: "Clip từ %{app}",
        .popupSort: "Sắp xếp",
        .popupSortNewestFirst: "Mới nhất trước",
        .settingsClearHistoryAfter: "Xóa lịch sử sau",
        .overlayOpenTransformPreview: "Mở xem trước chuyển đổi",
        .overlayMarkdownDescription: "Chuyển văn bản clipboard sang đầu ra thân thiện với Markdown",
        .overlayStripUnicodeDescription: "Chuẩn hóa ký tự đặc biệt để truyền văn bản thuần",
        .overlayUppercaseDescription: "Chuyển đầu ra thành chữ hoa",
        .overlayLowercaseDescription: "Chuyển đầu ra thành chữ thường",
        .securityStateLocked: "SlipBoard đã khóa",
        .securityStateUnlocked: "SlipBoard đã mở khóa",
        .securityStateUnavailable: "Không có trạng thái SlipBoard",
        .securityMenuLocked: "SlipBoard đã khóa",
        .securityMenuUnlocked: "SlipBoard đã mở khóa",
        .securityMenuUnavailable: "Không có trạng thái bảo mật SlipBoard",
        .securityLockDetailManual: "Xem trước được bảo vệ sẽ ẩn cho đến khi SlipBoard được mở khóa lại.",
        .securityLockDetailAutoLock: "Tự động khóa đã ẩn xem trước và tắt tìm kiếm cho đến khi bạn mở khóa.",
        .securityLockDetailBackground: "Xem trước bị ẩn sau khi rời phiên hoạt động.",
        .securityLockDetailAuthentication: "Dùng phương thức hệ thống đã duyệt trong Cài đặt để hiển thị nội dung được bảo vệ.",
        .securityLockDetailKeyUnavailable: "Bộ nhớ bảo vệ không khả dụng đến khi khóa payload được mở bọc.",
        .securityLockDetailMigration: "Hoàn tất migration hiện tại trước khi có thể hiển thị nội dung được bảo vệ.",
        .securityLockDetailUnlocking: "SlipBoard đang chờ quy trình xác thực hệ thống hiện tại hoàn tất.",
        .securityLockDetailFailed: "Dùng Mở khóa SlipBoard hoặc mở Cài đặt bảo mật để thử lại.",
        .securityLockDetailUnlocked: "Nội dung được bảo vệ đang khả dụng.",
        .securityLockDetailUnknown: "Xem trước được bảo vệ vẫn ẩn cho đến khi trạng thái bảo mật khả dụng.",
        .clipRedactionNoSnapshot: "Xem trước được bảo vệ vẫn ẩn trong shell này.",
        .clipRedactionLocked: "SlipBoard đã khóa, nên xem trước clip và nội dung ghi chú vẫn ẩn đến khi mở khóa thành công.",
        .clipRedactionPrivacy: "Chế độ riêng tư đang che xem trước này trên bề mặt shell hiện có.",
        .popupLockTitleLocked: "SlipBoard đã khóa",
        .popupLockTitleUnlocking: "Đang mở khóa SlipBoard",
        .popupLockTitleFailed: "SlipBoard vẫn khóa",
        .popupLockTitleUnlocked: "SlipBoard đã mở khóa",
        .popupLockDetailLocked: "Xem trước và tìm kiếm bị ẩn trong popup này đến khi bạn mở khóa từ menu hoặc Cài đặt bảo mật.",
        .popupLockDetailUnlocking: "SlipBoard đang chờ bước xác thực hệ thống hiện tại hoàn tất trước khi hiển thị nội dung được bảo vệ.",
        .popupLockDetailFailed: "Xem trước được bảo vệ vẫn ẩn sau lần mở khóa gần nhất. Hãy thử lại từ menu bar hoặc mở Cài đặt bảo mật.",
        .popupLockDetailUnlocked: "Nội dung được bảo vệ đang hiển thị.",
        .popupLockHintLocked: "Mở khóa từ menu hoặc cài đặt",
        .popupLockHintUnlocking: "Đang chờ xác thực hệ thống",
        .popupLockHintFailed: "Thử mở khóa từ menu",
        .popupLockHintUnlocked: "Nội dung được bảo vệ hiển thị",
        .bridgeBehavior: "Hành vi Bridge",
        .bridgeScope: "Phạm vi",
        .bridgeScopeDetail: "Kết nối qua cơ sở dữ liệu CloudKit riêng tư mà không tải toàn bộ lịch sử SlipBoard lên.",
        .bridgeEnableDetail: "Kết nối qua cơ sở dữ liệu CloudKit riêng tư mà không tải toàn bộ lịch sử SlipBoard lên.",
        .bridgePublishDetail: "Nhấp đúp hoặc Enter trên Mac sẽ dán cục bộ và gửi chính mục đó đến thiết bị cùng tài khoản iCloud.",
        .bridgeReceiveDetail: "Nội dung nhập từ iPhone xuất hiện trong SlipBoard trên Mac.",
        .bridgePasteFlow: "Luồng dán",
        .bridgePickOnMac: "Chọn trên Mac",
        .bridgePickOnMacDetail: "Nhấp đúp hoặc nhấn Enter từ lưới popup.",
        .bridgePasteOnMac: "Dán trên Mac",
        .bridgePasteOnMacDetail: "SlipBoard vẫn dán vào ứng dụng hiện tại như bình thường.",
        .bridgePublishOneShot: "Gửi một bản ghi bridge duy nhất",
        .bridgePublishOneShotDetail: "Chỉ mục vừa dán được gửi với TTL ngắn và được dọn sau khi dùng.",
        .bridgeReceiveOnIPhone: "Nhận trên iPhone",
        .bridgeReceiveOnIPhoneDetail: "Ứng dụng đồng hành iPhone nhận mục để người dùng có thể dán lại ở đó.",
        .bridgeSameICloudAccount: "Cùng tài khoản iCloud",
        .bridgeReview: "Xem lại",
        .bridgeNoMacPastes: "Chưa có thao tác dán có chủ ý trên Mac nào được bridge.",
        .bridgeNoCompanionImports: "Chưa có nội dung nhập nào từ thiết bị đồng hành được thêm vào lịch sử Mac cục bộ.",
        .bridgeSentSupportedDetail: "Chỉ các thao tác dán cục bộ thành công thuộc loại được hỗ trợ mới được gửi.",
        .bridgeReceivedLocalDetail: "Bản ghi từ thiết bị đồng hành đi vào lịch sử Mac qua luồng lịch sử cục bộ hiện có.",
        .bridgeEligiblePendingDetail: "Các bản ghi phù hợp từ thiết bị đồng hành đang chờ vào lịch sử Mac cục bộ.",
        .bridgeBehaviorDescription: "Dán trên Mac rồi dán trên iPhone. Lịch sử Mac vẫn cục bộ và không tải toàn bộ lịch sử lên.",
        .bridgeDevicesDescription: "Bridge vẫn có thể bật trên Mac trước khi thiết bị đồng hành đăng nhập cùng tài khoản iCloud.",
        .bridgeObservedDevicesDescription: "Các thiết bị cùng tài khoản iCloud được quan sát từ hoạt động Bridge.",
        .bridgeActivityDescription: "Gửi ra theo từng lần với TTL 10 phút; dữ liệu nhận vào vẫn là bản ghi rõ ràng từ thiết bị đồng hành.",
        .bridgeLocalHistoryTitle: "Lịch sử cục bộ vẫn ở cục bộ",
        .bridgePendingImportsDetail: "Bản ghi bridge đến đang chờ nhập vào lịch sử Mac cục bộ.",
        .bridgeOneShotTTL: "TTL %{minutes} phút",
        .hotkeyRecorderInstruction: "Nhấn phím tắt bạn muốn gán. Nhấn Escape để hủy.",
        .hotkeyAccessLocked: "Quyền truy cập phím tắt đã bị khóa",
        .hotkeyInfo: "Thông tin phím tắt",
        .hotkeyAccessLockedDetail: "Mở khóa SlipBoard để xem và chỉnh sửa phím tắt.",
        .hotkeyInfoDetail: "Xem hoặc cập nhật các phím tắt khả dụng trên máy Mac này.",
        .hotkeyOpenSlipBoardDetail: "Mở SlipBoard từ bất kỳ đâu.",
        .hotkeyPasteAsDetail: "Mở Dán dưới dạng cho clip đã chọn.",
        .hotkeyPauseCaptureDetail: "Tạm dừng hoặc tiếp tục thu thập clipboard.",
        .hotkeySnippetDetail: "Dùng phím tắt này để dán snippet.",
        .hotkeyFutureCommandDetail: "Phím tắt này sẽ khả dụng trong bản cập nhật sau.",
        .hotkeyConflictDetail: "Phím tắt này đã được gán. Hãy chọn phím tắt khác.",
        .hotkeyUnlockToEdit: "Mở khóa SlipBoard để chỉnh sửa phím tắt này.",
        .bridgeScopeLabel: "Phạm vi",
        .bridgeSupportedPastesV1Detail: "Chỉ các lần dán cục bộ thành công của loại được hỗ trợ mới được Bridge trong v1.",
        .bridgeNoDevicesDetail: "Bridge vẫn có thể bật trên Mac trước khi ứng dụng đồng hành iPhone đăng nhập cùng tài khoản iCloud.",
        .bridgeSubtitleFallback: "Dán trên Mac, rồi dán trên iPhone. Lịch sử Mac cục bộ vẫn được giữ tại máy.",
        .bridgeDeviceLastSeenDetail: "Cùng tài khoản iCloud · Hoạt động %{time}"
    ]
}
