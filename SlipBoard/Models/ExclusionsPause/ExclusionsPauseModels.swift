import Foundation

enum ExcludedAppMatchStrategy: String, CaseIterable, Identifiable, Hashable {
    case bundleIDExact
    case displayNameFallback

    var id: String { rawValue }
}

struct ExcludedAppRule: Identifiable, Hashable {
    let id: String
    var bundleID: String?
    var displayName: String
    var symbolName: String?
    var detailText: String
    var matchStrategy: ExcludedAppMatchStrategy

    init(
        id: String,
        bundleID: String? = nil,
        displayName: String,
        symbolName: String? = nil,
        detailText: String? = nil,
        matchStrategy: ExcludedAppMatchStrategy
    ) {
        let cleanedBundleID = Self.cleanOptionalText(bundleID)

        self.id = id
        self.bundleID = cleanedBundleID
        self.displayName = displayName
        self.symbolName = symbolName
        self.matchStrategy = matchStrategy
        self.detailText = detailText ?? Self.defaultDetailText(
            bundleID: cleanedBundleID,
            matchStrategy: matchStrategy
        )
    }

    var displayNameMatchKey: String {
        Self.makeDisplayNameMatchKey(displayName)
    }

    var usesDisplayNameFallback: Bool {
        matchStrategy == .displayNameFallback
    }

    static func makeDisplayNameMatchKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func cleanOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func defaultDetailText(
        bundleID: String?,
        matchStrategy: ExcludedAppMatchStrategy
    ) -> String {
        switch matchStrategy {
        case .bundleIDExact:
            return bundleID ?? "Exact bundle ID match"
        case .displayNameFallback:
            return "Fallback display-name match"
        }
    }
}

struct FrontmostAppContext: Hashable {
    var bundleID: String?
    var displayName: String
    var symbolName: String?
    var accentToken: String
    var observedAt: Date

    init(
        bundleID: String? = nil,
        displayName: String,
        symbolName: String? = nil,
        accentToken: String = "accent.primary",
        observedAt: Date = .now
    ) {
        self.bundleID = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = displayName
        self.symbolName = symbolName
        self.accentToken = accentToken
        self.observedAt = observedAt
    }

    var displayNameMatchKey: String {
        ExcludedAppRule.makeDisplayNameMatchKey(displayName)
    }
}

struct ExcludedAppMatch: Hashable {
    var rule: ExcludedAppRule
    var appContext: FrontmostAppContext
    var strategy: ExcludedAppMatchStrategy

    init(
        rule: ExcludedAppRule,
        appContext: FrontmostAppContext,
        strategy: ExcludedAppMatchStrategy? = nil
    ) {
        self.rule = rule
        self.appContext = appContext
        self.strategy = strategy ?? rule.matchStrategy
    }
}

enum CapturePauseDurationOption: String, CaseIterable, Identifiable, Hashable {
    case fifteenMinutes = "15m"
    case oneHour = "1h"
    case untilResume = "untilResume"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .fifteenMinutes:
            return "15 min"
        case .oneHour:
            return "1 hour"
        case .untilResume:
            return "Until Resume"
        }
    }

    var scheduledDuration: TimeInterval? {
        switch self {
        case .fifteenMinutes:
            return 15 * 60
        case .oneHour:
            return 60 * 60
        case .untilResume:
            return nil
        }
    }

    func makePauseState(startedAt: Date) -> CapturePauseState {
        guard let scheduledDuration else {
            return .manual(startedAt: startedAt)
        }

        return .timed(
            startedAt: startedAt,
            resumeAt: startedAt.addingTimeInterval(scheduledDuration),
            preset: self
        )
    }
}

enum CapturePauseState: Hashable {
    case inactive
    case manual(startedAt: Date)
    case timed(startedAt: Date, resumeAt: Date, preset: CapturePauseDurationOption)

    var isPaused: Bool {
        switch self {
        case .inactive:
            return false
        case .manual, .timed:
            return true
        }
    }

    var startedAt: Date? {
        switch self {
        case .inactive:
            return nil
        case let .manual(startedAt):
            return startedAt
        case let .timed(startedAt, _, _):
            return startedAt
        }
    }

    var resumeAt: Date? {
        switch self {
        case .inactive, .manual:
            return nil
        case let .timed(_, resumeAt, _):
            return resumeAt
        }
    }

    var selectedOption: CapturePauseDurationOption? {
        switch self {
        case .inactive:
            return nil
        case .manual:
            return .untilResume
        case let .timed(_, _, preset):
            return preset
        }
    }

    var activeLabel: String? {
        switch self {
        case .inactive:
            return nil
        case .manual:
            return CapturePauseDurationOption.untilResume.displayTitle
        case let .timed(_, _, preset):
            return preset.displayTitle
        }
    }
}

struct ExclusionsBehaviorSettings: Hashable {
    var hidePopupInsideExcludedApps: Bool

    init(hidePopupInsideExcludedApps: Bool = false) {
        self.hidePopupInsideExcludedApps = hidePopupInsideExcludedApps
    }
}

enum ExclusionsPauseDecisionReason: String, CaseIterable, Identifiable, Hashable {
    case paused
    case excludedApp
    case popupHiddenInsideExcludedApp

    var id: String { rawValue }
}

enum CapturePolicyDecision: Hashable {
    case allow
    case ignoreBecausePaused(state: CapturePauseState)
    case ignoreBecauseExcludedApp(match: ExcludedAppMatch)

    var reason: ExclusionsPauseDecisionReason? {
        switch self {
        case .allow:
            return nil
        case .ignoreBecausePaused:
            return .paused
        case .ignoreBecauseExcludedApp:
            return .excludedApp
        }
    }
}

enum PopupPolicyDecision: Hashable {
    case allow
    case suppressBecauseExcludedApp(match: ExcludedAppMatch)

    var reason: ExclusionsPauseDecisionReason? {
        switch self {
        case .allow:
            return nil
        case .suppressBecauseExcludedApp:
            return .popupHiddenInsideExcludedApp
        }
    }
}

struct ExclusionsPauseSettingsSnapshot: Hashable {
    var excludedApps: [ExcludedAppRule]
    var pauseState: CapturePauseState
    var behaviorSettings: ExclusionsBehaviorSettings
    var lastUpdatedAt: Date

    init(
        excludedApps: [ExcludedAppRule] = [],
        pauseState: CapturePauseState = .inactive,
        behaviorSettings: ExclusionsBehaviorSettings = ExclusionsBehaviorSettings(),
        lastUpdatedAt: Date = .now
    ) {
        self.excludedApps = excludedApps
        self.pauseState = pauseState
        self.behaviorSettings = behaviorSettings
        self.lastUpdatedAt = lastUpdatedAt
    }
}

struct CapturePolicyEvaluationRequest: Hashable {
    var sourceApp: FrontmostAppContext?
    var settings: ExclusionsPauseSettingsSnapshot
    var referenceDate: Date

    init(
        sourceApp: FrontmostAppContext?,
        settings: ExclusionsPauseSettingsSnapshot,
        referenceDate: Date = .now
    ) {
        self.sourceApp = sourceApp
        self.settings = settings
        self.referenceDate = referenceDate
    }
}

struct PopupPolicyEvaluationRequest: Hashable {
    var frontmostApp: FrontmostAppContext?
    var settings: ExclusionsPauseSettingsSnapshot
    var referenceDate: Date

    init(
        frontmostApp: FrontmostAppContext?,
        settings: ExclusionsPauseSettingsSnapshot,
        referenceDate: Date = .now
    ) {
        self.frontmostApp = frontmostApp
        self.settings = settings
        self.referenceDate = referenceDate
    }
}

struct ExclusionsPauseSnapshot: Hashable {
    var excludedApps: [ExcludedAppRule]
    var pauseState: CapturePauseState
    var behaviorSettings: ExclusionsBehaviorSettings
    var frontmostApp: FrontmostAppContext?
    var matchedExcludedApp: ExcludedAppMatch?
    var capturePolicyDecision: CapturePolicyDecision
    var popupPolicyDecision: PopupPolicyDecision
    var lastDecisionReason: ExclusionsPauseDecisionReason?
    var lastUpdatedAt: Date

    init(
        excludedApps: [ExcludedAppRule],
        pauseState: CapturePauseState,
        behaviorSettings: ExclusionsBehaviorSettings,
        frontmostApp: FrontmostAppContext? = nil,
        matchedExcludedApp: ExcludedAppMatch? = nil,
        capturePolicyDecision: CapturePolicyDecision = .allow,
        popupPolicyDecision: PopupPolicyDecision = .allow,
        lastDecisionReason: ExclusionsPauseDecisionReason? = nil,
        lastUpdatedAt: Date = .now
    ) {
        self.excludedApps = excludedApps
        self.pauseState = pauseState
        self.behaviorSettings = behaviorSettings
        self.frontmostApp = frontmostApp
        self.matchedExcludedApp = matchedExcludedApp
        self.capturePolicyDecision = capturePolicyDecision
        self.popupPolicyDecision = popupPolicyDecision
        self.lastDecisionReason = lastDecisionReason
            ?? capturePolicyDecision.reason
            ?? popupPolicyDecision.reason
        self.lastUpdatedAt = lastUpdatedAt
    }

    init(
        settings: ExclusionsPauseSettingsSnapshot,
        frontmostApp: FrontmostAppContext? = nil,
        matchedExcludedApp: ExcludedAppMatch? = nil,
        capturePolicyDecision: CapturePolicyDecision = .allow,
        popupPolicyDecision: PopupPolicyDecision = .allow,
        lastDecisionReason: ExclusionsPauseDecisionReason? = nil,
        lastUpdatedAt: Date = .now
    ) {
        self.init(
            excludedApps: settings.excludedApps,
            pauseState: settings.pauseState,
            behaviorSettings: settings.behaviorSettings,
            frontmostApp: frontmostApp,
            matchedExcludedApp: matchedExcludedApp,
            capturePolicyDecision: capturePolicyDecision,
            popupPolicyDecision: popupPolicyDecision,
            lastDecisionReason: lastDecisionReason,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    var isFrontmostAppExcluded: Bool {
        matchedExcludedApp != nil
    }

    var activePauseLabel: String? {
        pauseState.activeLabel
    }
}
