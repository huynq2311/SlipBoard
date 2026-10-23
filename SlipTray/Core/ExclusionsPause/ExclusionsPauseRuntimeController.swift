import Foundation

enum CapturePauseHotkeyResult {
    case pausedManually
    case resumed
    case timedPauseStillActive
    case unavailable

    var statusMessage: String {
        switch self {
        case .pausedManually:
            return "Capture paused until you resume it."
        case .resumed:
            return "Capture resumed."
        case .timedPauseStillActive:
            return "Timed pause remains active until it expires or you resume manually."
        case .unavailable:
            return "Pause capture is unavailable until the runtime is ready."
        }
    }
}

final class ExclusionsPauseRuntimeController: ExclusionsPauseRuntimeProviding {
    private let store: ExclusionsPauseSettingsStoring
    private let tracker: FrontmostApplicationObserving
    private let evaluator: ExclusionsPausePolicyEvaluator
    private let now: () -> Date

    private var resumeTimer: Timer?
    private var lastCapturePolicyDecision: CapturePolicyDecision

    private(set) var latestSnapshot: ExclusionsPauseSnapshot
    var onSnapshotChange: ((ExclusionsPauseSnapshot) -> Void)?

    var settingsSnapshot: ExclusionsPauseSettingsSnapshot {
        store.snapshot
    }

    init(
        store: ExclusionsPauseSettingsStoring = ExclusionsPauseSettingsStore(),
        tracker: FrontmostApplicationObserving = FrontmostApplicationTracker(),
        evaluator: ExclusionsPausePolicyEvaluator = ExclusionsPausePolicyEvaluator(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.tracker = tracker
        self.evaluator = evaluator
        self.now = now

        let initialReferenceDate = now()
        let initialSettings = store.snapshot
        let frontmostApp = tracker.latestContext
        let matchedExcludedApp = evaluator.matchExcludedApp(
            for: frontmostApp,
            rules: initialSettings.excludedApps
        )
        let initialCaptureDecision = evaluator.evaluateCapturePolicy(
            CapturePolicyEvaluationRequest(
                sourceApp: frontmostApp,
                settings: initialSettings,
                referenceDate: initialReferenceDate
            )
        )
        let initialPopupDecision = evaluator.evaluatePopupPolicy(
            PopupPolicyEvaluationRequest(
                frontmostApp: frontmostApp,
                settings: initialSettings,
                referenceDate: initialReferenceDate
            )
        )

        self.lastCapturePolicyDecision = initialCaptureDecision
        self.latestSnapshot = evaluator.makeSnapshot(
            settings: initialSettings,
            frontmostApp: frontmostApp,
            matchedExcludedApp: matchedExcludedApp,
            capturePolicyDecision: initialCaptureDecision,
            popupPolicyDecision: initialPopupDecision,
            lastUpdatedAt: initialReferenceDate
        )

        tracker.onContextChange = { [weak self] _ in
            self?.refreshSnapshot(referenceDate: self?.now() ?? .now)
        }

        tracker.start()
        refreshSnapshot(referenceDate: initialReferenceDate)
    }

    deinit {
        resumeTimer?.invalidate()
        tracker.stop()
    }

    func refreshSnapshot(referenceDate: Date) {
        let normalizedSettings = normalizedSettingsSnapshot(referenceDate: referenceDate)
        let frontmostApp = tracker.latestContext
        let matchedExcludedApp = evaluator.matchExcludedApp(
            for: frontmostApp,
            rules: normalizedSettings.excludedApps
        )
        let capturePolicyDecision = evaluator.evaluateCapturePolicy(
            CapturePolicyEvaluationRequest(
                sourceApp: frontmostApp,
                settings: normalizedSettings,
                referenceDate: referenceDate
            )
        )
        let popupPolicyDecision = evaluator.evaluatePopupPolicy(
            PopupPolicyEvaluationRequest(
                frontmostApp: frontmostApp,
                settings: normalizedSettings,
                referenceDate: referenceDate
            )
        )

        lastCapturePolicyDecision = capturePolicyDecision
        publishSnapshot(
            settings: normalizedSettings,
            frontmostApp: frontmostApp,
            matchedExcludedApp: matchedExcludedApp,
            capturePolicyDecision: capturePolicyDecision,
            popupPolicyDecision: popupPolicyDecision,
            referenceDate: referenceDate
        )
    }

    func replaceExcludedApps(_ rules: [ExcludedAppRule], lastUpdatedAt: Date) {
        _ = store.saveExcludedApps(rules, lastUpdatedAt: lastUpdatedAt)
        refreshSnapshot(referenceDate: lastUpdatedAt)
    }

    func removeExcludedApp(id: String, lastUpdatedAt: Date) {
        let rules = store.snapshot.excludedApps.filter { $0.id != id }
        _ = store.saveExcludedApps(rules, lastUpdatedAt: lastUpdatedAt)
        refreshSnapshot(referenceDate: lastUpdatedAt)
    }

    func updateBehaviorSettings(_ settings: ExclusionsBehaviorSettings, lastUpdatedAt: Date) {
        _ = store.saveBehaviorSettings(settings, lastUpdatedAt: lastUpdatedAt)
        refreshSnapshot(referenceDate: lastUpdatedAt)
    }

    func setManualPause(startedAt: Date) {
        _ = store.savePauseState(.manual(startedAt: startedAt), lastUpdatedAt: startedAt)
        refreshSnapshot(referenceDate: startedAt)
    }

    func applyPauseOption(_ option: CapturePauseDurationOption, startedAt: Date) {
        _ = store.savePauseState(option.makePauseState(startedAt: startedAt), lastUpdatedAt: startedAt)
        refreshSnapshot(referenceDate: startedAt)
    }

    func resumeCapturing(resumedAt: Date) {
        _ = store.savePauseState(.inactive, lastUpdatedAt: resumedAt)
        refreshSnapshot(referenceDate: resumedAt)
    }

    func evaluateCapturePolicy(
        for sourceApp: ClipboardSourceAppSummary?,
        referenceDate: Date
    ) -> CapturePolicyDecision {
        let normalizedSettings = normalizedSettingsSnapshot(referenceDate: referenceDate)
        let sourceAppContext = sourceApp.map {
            FrontmostAppContext(
                bundleID: $0.bundleID,
                displayName: $0.displayName,
                symbolName: $0.symbolName,
                accentToken: $0.accentToken,
                observedAt: referenceDate
            )
        }

        let capturePolicyDecision = evaluator.evaluateCapturePolicy(
            CapturePolicyEvaluationRequest(
                sourceApp: sourceAppContext,
                settings: normalizedSettings,
                referenceDate: referenceDate
            )
        )
        let frontmostApp = tracker.latestContext
        let matchedExcludedApp = evaluator.matchExcludedApp(
            for: frontmostApp,
            rules: normalizedSettings.excludedApps
        )
        let popupPolicyDecision = evaluator.evaluatePopupPolicy(
            PopupPolicyEvaluationRequest(
                frontmostApp: frontmostApp,
                settings: normalizedSettings,
                referenceDate: referenceDate
            )
        )

        lastCapturePolicyDecision = capturePolicyDecision
        publishSnapshot(
            settings: normalizedSettings,
            frontmostApp: frontmostApp,
            matchedExcludedApp: matchedExcludedApp,
            capturePolicyDecision: capturePolicyDecision,
            popupPolicyDecision: popupPolicyDecision,
            referenceDate: referenceDate
        )

        return capturePolicyDecision
    }

    @discardableResult
    func handlePauseHotkey(triggeredAt: Date) -> CapturePauseHotkeyResult {
        let normalizedSettings = normalizedSettingsSnapshot(referenceDate: triggeredAt)

        switch normalizedSettings.pauseState {
        case .inactive:
            setManualPause(startedAt: triggeredAt)
            return .pausedManually
        case .manual:
            resumeCapturing(resumedAt: triggeredAt)
            return .resumed
        case .timed:
            refreshSnapshot(referenceDate: triggeredAt)
            return .timedPauseStillActive
        }
    }

    private func normalizedSettingsSnapshot(referenceDate: Date) -> ExclusionsPauseSettingsSnapshot {
        let effectivePauseState = evaluator.effectivePauseState(
            store.snapshot.pauseState,
            referenceDate: referenceDate
        )

        if effectivePauseState != store.snapshot.pauseState {
            return store.savePauseState(effectivePauseState, lastUpdatedAt: referenceDate)
        }

        scheduleResumeTimer(for: effectivePauseState)
        return store.snapshot
    }

    private func publishSnapshot(
        settings: ExclusionsPauseSettingsSnapshot,
        frontmostApp: FrontmostAppContext?,
        matchedExcludedApp: ExcludedAppMatch?,
        capturePolicyDecision: CapturePolicyDecision,
        popupPolicyDecision: PopupPolicyDecision,
        referenceDate: Date
    ) {
        scheduleResumeTimer(for: settings.pauseState)

        let nextSnapshot = evaluator.makeSnapshot(
            settings: settings,
            frontmostApp: frontmostApp,
            matchedExcludedApp: matchedExcludedApp,
            capturePolicyDecision: capturePolicyDecision,
            popupPolicyDecision: popupPolicyDecision,
            lastUpdatedAt: referenceDate
        )

        guard latestSnapshot != nextSnapshot else {
            return
        }

        latestSnapshot = nextSnapshot
        onSnapshotChange?(nextSnapshot)
    }

    private func scheduleResumeTimer(for pauseState: CapturePauseState) {
        resumeTimer?.invalidate()
        resumeTimer = nil

        guard case let .timed(_, resumeAt, _) = pauseState else {
            return
        }

        let interval = max(0, resumeAt.timeIntervalSince(now()))
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.resumeCapturing(resumedAt: self.now())
        }

        resumeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
