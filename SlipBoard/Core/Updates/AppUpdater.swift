import AppKit
import Combine

/// Front for the updater plug-in, the only code that links Sparkle. The
/// plug-in is loaded on first need: when the user clicks Check for Updates, when
/// Sparkle's daily check is due, or to show its one-time permission prompt on
/// the second launch. Before loading, UpdaterSignatureCheck confirms that the
/// plug-in and Sparkle.framework carry the app's own signature; if not, they are
/// never loaded and updates stay off.
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    @Published private(set) var automaticallyChecksForUpdates: Bool
    @Published private(set) var isUnavailable = false

    private enum State {
        case idle
        case loading
        case loaded(UpdaterPlugin)
        case unavailable
    }

    // Sparkle's own user defaults keys, read so the app can tell when Sparkle
    // needs to run without loading it (SPUUpdater.startUpdateCycle).
    private static let automaticChecksKey = "SUEnableAutomaticChecks"
    private static let hasLaunchedBeforeKey = "SUHasLaunchedBefore"
    private static let lastCheckTimeKey = "SULastCheckTime"
    private static let checkIntervalKey = "SUScheduledCheckInterval"

    private static let plugInName = "SlipBoardUpdater.bundle"
    private static let plugInIdentifier = "huynq.SlipBoard.Updater"
    private static let logger = DiagnosticLogger(category: "Updates")

    private let defaults = UserDefaults.standard
    private var state = State.idle
    private var pendingActions: [(UpdaterPlugin) -> Void] = []
    private var scheduledLoad: DispatchSourceTimer?

    private init() {
        automaticallyChecksForUpdates = defaults.bool(forKey: Self.automaticChecksKey)
        scheduleLoadIfNeeded()
    }

    func checkForUpdates() {
        withPlugin { $0.checkForUpdates() }
    }

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {
        switch state {
        case .loaded(let plugin):
            plugin.automaticallyChecksForUpdates = isOn
        case .idle, .loading:
            // Sparkle reads this key when it starts.
            defaults.set(isOn, forKey: Self.automaticChecksKey)
            automaticallyChecksForUpdates = isOn
            scheduleLoadIfNeeded()
        case .unavailable:
            break
        }
    }

    /// Shows an update Sparkle held back until the user was done; nothing to
    /// show if Sparkle hasn't run.
    func showDeferredUpdate() {
        if case .loaded(let plugin) = state {
            plugin.showDeferredUpdate()
        }
    }

    /// Mirrors SPUUpdater.startUpdateCycle: Sparkle asks for permission from
    /// the second launch until answered, and otherwise only acts when a
    /// scheduled check is due.
    private func scheduleLoadIfNeeded() {
        scheduledLoad?.cancel()
        scheduledLoad = nil
        guard case .idle = state else { return }

        guard let isOn = defaults.object(forKey: Self.automaticChecksKey) as? Bool else {
            if defaults.bool(forKey: Self.hasLaunchedBeforeKey) {
                load()
            } else {
                defaults.set(true, forKey: Self.hasLaunchedBeforeKey)
            }
            return
        }
        guard isOn else { return }

        let interval = max(defaults.object(forKey: Self.checkIntervalKey) as? Double ?? 86_400, 3_600)
        // Sparkle treats a check date in the future as now.
        let lastCheck = min(defaults.object(forKey: Self.lastCheckTimeKey) as? Date ?? .distantPast, Date())
        let delay = max(lastCheck.addingTimeInterval(interval).timeIntervalSinceNow, 0)
        // Wall clock, like Sparkle's own timer, so time asleep counts. Once
        // loaded, Sparkle runs the check itself because it is due.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(wallDeadline: .now() + delay)
        timer.setEventHandler {
            Task { @MainActor in AppUpdater.shared.load() }
        }
        timer.resume()
        scheduledLoad = timer
    }

    private func withPlugin(_ action: @escaping (UpdaterPlugin) -> Void) {
        switch state {
        case .loaded(let plugin):
            action(plugin)
        case .idle:
            pendingActions.append(action)
            load()
        case .loading:
            pendingActions.append(action)
        case .unavailable:
            break
        }
    }

    private func load() {
        guard case .idle = state else { return }
        state = .loading
        scheduledLoad?.cancel()
        scheduledLoad = nil

        guard let plugInURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent(Self.plugInName) else {
            fail("the app bundle has no PlugIns folder")
            return
        }
        let frameworkURL = plugInURL.appendingPathComponent("Contents/Frameworks/Sparkle.framework")

        // The plug-in goes last: its nested-code check hashes Sparkle again,
        // so both are checked just before loading.
        let items = [
            (url: frameworkURL, identifier: "org.sparkle-project.Sparkle"),
            (url: plugInURL, identifier: Self.plugInIdentifier),
        ]
        let plugInName = Self.plugInName
        Task {
            // Hashing every file takes a moment, so check and load off the
            // main thread, one right after the other. Both read the files by
            // path; in self-signed releases, a file swapped in between still
            // fails to load, because the app's library load constraint
            // (build_release.sh) lists the exact plug-in and Sparkle builds.
            let result = await Task.detached(priority: .userInitiated) {
                Result { () throws -> Bundle in
                    try UpdaterSignatureCheck.verify(items)
                    // The plug-in finds Sparkle through its only rpath,
                    // @loader_path/../Frameworks: the copy checked above.
                    guard let bundle = Bundle(url: plugInURL) else {
                        throw UpdaterSignatureCheck.Failure(description: "could not open \(plugInName)")
                    }
                    try bundle.loadAndReturnError()
                    return bundle
                }
            }.value

            let bundle: Bundle
            switch result {
            case .success(let loaded):
                bundle = loaded
            case .failure(let error):
                fail(String(describing: error))
                return
            }
            guard
                let pluginClass = bundle.principalClass as? NSObject.Type,
                let plugin = pluginClass.init() as? UpdaterPlugin
            else {
                fail("\(Self.plugInName) has no updater class")
                return
            }

            plugin.onAutomaticChecksChange = { [weak self] isOn in
                self?.automaticallyChecksForUpdates = isOn
            }
            automaticallyChecksForUpdates = plugin.automaticallyChecksForUpdates
            state = .loaded(plugin)
            let actions = pendingActions
            pendingActions = []
            actions.forEach { $0(plugin) }
        }
    }

    private func fail(_ reason: String) {
        Self.logger.error("Updates are off: \(reason)")
        state = .unavailable
        pendingActions = []
        isUnavailable = true
    }
}
