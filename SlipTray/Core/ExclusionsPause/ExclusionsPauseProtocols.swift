import Foundation

protocol ExclusionsPauseSettingsStoreQuerying {
    var snapshot: ExclusionsPauseSettingsSnapshot { get }
}

protocol ExclusionsPauseSettingsStoreMutating: AnyObject {
    @discardableResult
    func saveExcludedApps(
        _ rules: [ExcludedAppRule],
        lastUpdatedAt: Date
    ) -> ExclusionsPauseSettingsSnapshot

    @discardableResult
    func savePauseState(
        _ pauseState: CapturePauseState,
        lastUpdatedAt: Date
    ) -> ExclusionsPauseSettingsSnapshot

    @discardableResult
    func saveBehaviorSettings(
        _ settings: ExclusionsBehaviorSettings,
        lastUpdatedAt: Date
    ) -> ExclusionsPauseSettingsSnapshot

    @discardableResult
    func replaceSnapshot(_ snapshot: ExclusionsPauseSettingsSnapshot) -> ExclusionsPauseSettingsSnapshot
}

typealias ExclusionsPauseSettingsStoring = ExclusionsPauseSettingsStoreQuerying & ExclusionsPauseSettingsStoreMutating

protocol FrontmostApplicationObserving: AnyObject {
    var latestContext: FrontmostAppContext? { get }
    var onContextChange: ((FrontmostAppContext?) -> Void)? { get set }

    func start()
    func stop()
    func refreshNow()
}

protocol ExclusionsPausePolicyEvaluating {
    func matchExcludedApp(
        for appContext: FrontmostAppContext?,
        rules: [ExcludedAppRule]
    ) -> ExcludedAppMatch?

    func evaluateCapturePolicy(_ request: CapturePolicyEvaluationRequest) -> CapturePolicyDecision
    func evaluatePopupPolicy(_ request: PopupPolicyEvaluationRequest) -> PopupPolicyDecision

    func makeSnapshot(
        settings: ExclusionsPauseSettingsSnapshot,
        frontmostApp: FrontmostAppContext?,
        matchedExcludedApp: ExcludedAppMatch?,
        capturePolicyDecision: CapturePolicyDecision,
        popupPolicyDecision: PopupPolicyDecision,
        lastUpdatedAt: Date
    ) -> ExclusionsPauseSnapshot
}

protocol ExclusionsPauseRuntimePublishing: AnyObject {
    var latestSnapshot: ExclusionsPauseSnapshot { get }
    var onSnapshotChange: ((ExclusionsPauseSnapshot) -> Void)? { get set }
}

protocol ExclusionsPauseRuntimeProviding: ExclusionsPauseRuntimePublishing {
    var settingsSnapshot: ExclusionsPauseSettingsSnapshot { get }

    func refreshSnapshot(referenceDate: Date)
    func replaceExcludedApps(_ rules: [ExcludedAppRule], lastUpdatedAt: Date)
    func removeExcludedApp(id: String, lastUpdatedAt: Date)
    func updateBehaviorSettings(_ settings: ExclusionsBehaviorSettings, lastUpdatedAt: Date)
    func setManualPause(startedAt: Date)
    func applyPauseOption(_ option: CapturePauseDurationOption, startedAt: Date)
    func resumeCapturing(resumedAt: Date)
}
