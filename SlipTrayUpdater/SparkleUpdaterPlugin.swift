import AppKit
import Combine
import Sparkle

/// The plug-in's principal class, holding Sparkle's updater. SlipTray creates
/// it once, after checking this bundle's and Sparkle's signatures (see
/// AppUpdater in the app).
@objc(SBSparkleUpdaterPlugin)
final class SparkleUpdaterPlugin: NSObject, UpdaterPlugin, SPUStandardUserDriverDelegate {
    var onAutomaticChecksChange: ((Bool) -> Void)?

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )
    private var hasDeferredUpdate = false
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        super.init()
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .sink { [weak self] in self?.onAutomaticChecksChange?($0) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.showDeferredUpdate() }
            .store(in: &cancellables)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    // A menu bar app is rarely active, so a scheduled update alert would open
    // behind other windows. Show it after the user next closes the popup, or
    // when SlipTray becomes active, instead of taking focus from what they
    // are doing.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        if immediateFocus == false {
            hasDeferredUpdate = true
        }
        return immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        // Sparkle proposes immediate focus right after launch, when SlipTray
        // may not be the active app yet.
        if handleShowingUpdate, state.userInitiated == false {
            NSApp.activate()
        }
    }

    func showDeferredUpdate() {
        guard hasDeferredUpdate else { return }
        hasDeferredUpdate = false
        checkForUpdates()
    }
}
