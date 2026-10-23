import Foundation

struct ExclusionsPausePolicyEvaluator: ExclusionsPausePolicyEvaluating {
    func matchExcludedApp(
        for appContext: FrontmostAppContext?,
        rules: [ExcludedAppRule]
    ) -> ExcludedAppMatch? {
        guard let appContext else {
            return nil
        }

        if
            let bundleID = normalizedBundleID(appContext.bundleID),
            let bundleRule = rules.first(where: { rule in
                rule.matchStrategy == .bundleIDExact
                    && normalizedBundleID(rule.bundleID) == bundleID
            })
        {
            return ExcludedAppMatch(
                rule: bundleRule,
                appContext: appContext,
                strategy: .bundleIDExact
            )
        }

        let matchKey = appContext.displayNameMatchKey
        guard matchKey.isEmpty == false else {
            return nil
        }

        guard let displayNameRule = rules.first(where: { rule in
            rule.matchStrategy == .displayNameFallback
                && normalizedBundleID(rule.bundleID) == nil
                && rule.displayNameMatchKey == matchKey
        }) else {
            return nil
        }

        return ExcludedAppMatch(
            rule: displayNameRule,
            appContext: appContext,
            strategy: .displayNameFallback
        )
    }

    func evaluateCapturePolicy(_ request: CapturePolicyEvaluationRequest) -> CapturePolicyDecision {
        let pauseState = effectivePauseState(request.settings.pauseState, referenceDate: request.referenceDate)
        if pauseState.isPaused {
            return .ignoreBecausePaused(state: pauseState)
        }

        if let match = matchExcludedApp(for: request.sourceApp, rules: request.settings.excludedApps) {
            return .ignoreBecauseExcludedApp(match: match)
        }

        return .allow
    }

    func evaluatePopupPolicy(_ request: PopupPolicyEvaluationRequest) -> PopupPolicyDecision {
        guard request.settings.behaviorSettings.hidePopupInsideExcludedApps else {
            return .allow
        }

        guard let match = matchExcludedApp(
            for: request.frontmostApp,
            rules: request.settings.excludedApps
        ) else {
            return .allow
        }

        return .suppressBecauseExcludedApp(match: match)
    }

    func makeSnapshot(
        settings: ExclusionsPauseSettingsSnapshot,
        frontmostApp: FrontmostAppContext?,
        matchedExcludedApp: ExcludedAppMatch?,
        capturePolicyDecision: CapturePolicyDecision,
        popupPolicyDecision: PopupPolicyDecision,
        lastUpdatedAt: Date
    ) -> ExclusionsPauseSnapshot {
        let normalizedSettings = ExclusionsPauseSettingsSnapshot(
            excludedApps: settings.excludedApps,
            pauseState: effectivePauseState(settings.pauseState, referenceDate: lastUpdatedAt),
            behaviorSettings: settings.behaviorSettings,
            lastUpdatedAt: settings.lastUpdatedAt
        )

        return ExclusionsPauseSnapshot(
            settings: normalizedSettings,
            frontmostApp: frontmostApp,
            matchedExcludedApp: matchedExcludedApp,
            capturePolicyDecision: capturePolicyDecision,
            popupPolicyDecision: popupPolicyDecision,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    func effectivePauseState(
        _ pauseState: CapturePauseState,
        referenceDate: Date
    ) -> CapturePauseState {
        switch pauseState {
        case .inactive, .manual:
            return pauseState
        case let .timed(startedAt, resumeAt, preset):
            guard resumeAt > referenceDate else {
                return .inactive
            }

            return .timed(
                startedAt: startedAt,
                resumeAt: resumeAt,
                preset: preset
            )
        }
    }

    private func normalizedBundleID(_ bundleID: String?) -> String? {
        guard let bundleID else {
            return nil
        }

        let trimmedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedBundleID.isEmpty == false else {
            return nil
        }

        return trimmedBundleID.lowercased()
    }
}
