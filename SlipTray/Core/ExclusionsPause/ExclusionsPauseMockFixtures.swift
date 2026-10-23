import Foundation

enum ExclusionsPauseMockFixtures {
    static let baseDate = Date(timeIntervalSince1970: 1_787_290_200)

    static let onePasswordRule = ExcludedAppRule(
        id: "excluded.1password",
        bundleID: "com.1password.1password7",
        displayName: "1Password",
        symbolName: "lock.shield",
        detailText: "com.1password.1password7",
        matchStrategy: .bundleIDExact
    )

    static let bankingFallbackRule = ExcludedAppRule(
        id: "excluded.banking-fallback",
        bundleID: nil,
        displayName: "Banking App",
        symbolName: "building.columns",
        detailText: "Fallback display-name match",
        matchStrategy: .displayNameFallback
    )

    static let excludedApps: [ExcludedAppRule] = [
        onePasswordRule,
        bankingFallbackRule
    ]

    static let hidePopupEnabledSettings = ExclusionsBehaviorSettings(
        hidePopupInsideExcludedApps: true
    )

    static let activeSettingsSnapshot = ExclusionsPauseSettingsSnapshot(
        excludedApps: excludedApps,
        pauseState: .inactive,
        behaviorSettings: hidePopupEnabledSettings,
        lastUpdatedAt: baseDate.addingTimeInterval(-900)
    )

    static let timedPauseState = CapturePauseState.timed(
        startedAt: baseDate.addingTimeInterval(-300),
        resumeAt: baseDate.addingTimeInterval(3_300),
        preset: .oneHour
    )

    static let timedPauseSettingsSnapshot = ExclusionsPauseSettingsSnapshot(
        excludedApps: excludedApps,
        pauseState: timedPauseState,
        behaviorSettings: hidePopupEnabledSettings,
        lastUpdatedAt: baseDate.addingTimeInterval(-300)
    )

    static let manualPauseState = CapturePauseState.manual(
        startedAt: baseDate.addingTimeInterval(-600)
    )

    static let manualPauseSettingsSnapshot = ExclusionsPauseSettingsSnapshot(
        excludedApps: excludedApps,
        pauseState: manualPauseState,
        behaviorSettings: hidePopupEnabledSettings,
        lastUpdatedAt: baseDate.addingTimeInterval(-600)
    )

    static let onePasswordApp = FrontmostAppContext(
        bundleID: "com.1password.1password7",
        displayName: "1Password",
        symbolName: "lock.shield",
        accentToken: "accent.warning",
        observedAt: baseDate.addingTimeInterval(-30)
    )

    static let bankingAppWithoutBundleID = FrontmostAppContext(
        bundleID: nil,
        displayName: "Banking App",
        symbolName: "building.columns",
        accentToken: "accent.danger",
        observedAt: baseDate.addingTimeInterval(-15)
    )

    static let terminalApp = FrontmostAppContext(
        bundleID: "com.apple.Terminal",
        displayName: "Terminal",
        symbolName: "terminal",
        accentToken: "accent.info",
        observedAt: baseDate
    )

    static let onePasswordMatch = ExcludedAppMatch(
        rule: onePasswordRule,
        appContext: onePasswordApp
    )

    static let bankingFallbackMatch = ExcludedAppMatch(
        rule: bankingFallbackRule,
        appContext: bankingAppWithoutBundleID
    )

    static let excludedCaptureRequest = CapturePolicyEvaluationRequest(
        sourceApp: onePasswordApp,
        settings: activeSettingsSnapshot,
        referenceDate: baseDate
    )

    static let pausedCaptureRequest = CapturePolicyEvaluationRequest(
        sourceApp: terminalApp,
        settings: timedPauseSettingsSnapshot,
        referenceDate: baseDate
    )

    static let popupSuppressionRequest = PopupPolicyEvaluationRequest(
        frontmostApp: onePasswordApp,
        settings: activeSettingsSnapshot,
        referenceDate: baseDate
    )

    static let fallbackPopupSuppressionRequest = PopupPolicyEvaluationRequest(
        frontmostApp: bankingAppWithoutBundleID,
        settings: activeSettingsSnapshot,
        referenceDate: baseDate
    )

    static let excludedCaptureDecision = CapturePolicyDecision.ignoreBecauseExcludedApp(
        match: onePasswordMatch
    )

    static let pausedCaptureDecision = CapturePolicyDecision.ignoreBecausePaused(
        state: timedPauseState
    )

    static let popupSuppressedDecision = PopupPolicyDecision.suppressBecauseExcludedApp(
        match: onePasswordMatch
    )

    static let fallbackPopupSuppressedDecision = PopupPolicyDecision.suppressBecauseExcludedApp(
        match: bankingFallbackMatch
    )

    static let activeSnapshot = ExclusionsPauseSnapshot(
        settings: activeSettingsSnapshot,
        frontmostApp: terminalApp,
        matchedExcludedApp: nil,
        capturePolicyDecision: .allow,
        popupPolicyDecision: .allow,
        lastUpdatedAt: baseDate
    )

    static let timedPauseSnapshot = ExclusionsPauseSnapshot(
        settings: timedPauseSettingsSnapshot,
        frontmostApp: terminalApp,
        matchedExcludedApp: nil,
        capturePolicyDecision: pausedCaptureDecision,
        popupPolicyDecision: .allow,
        lastUpdatedAt: baseDate
    )

    static let manualPauseSnapshot = ExclusionsPauseSnapshot(
        settings: manualPauseSettingsSnapshot,
        frontmostApp: terminalApp,
        matchedExcludedApp: nil,
        capturePolicyDecision: .ignoreBecausePaused(state: manualPauseState),
        popupPolicyDecision: .allow,
        lastUpdatedAt: baseDate
    )

    static let excludedFrontmostSnapshot = ExclusionsPauseSnapshot(
        settings: activeSettingsSnapshot,
        frontmostApp: onePasswordApp,
        matchedExcludedApp: onePasswordMatch,
        capturePolicyDecision: excludedCaptureDecision,
        popupPolicyDecision: popupSuppressedDecision,
        lastUpdatedAt: baseDate
    )
}
