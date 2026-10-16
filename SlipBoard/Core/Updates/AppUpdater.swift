import AppKit
import Combine
import Sparkle

/// Sparkle updater, created once at launch. Reads the feed only when the user
/// clicks Check for Updates, or on Sparkle's schedule after they accept the
/// automatic-check prompt it shows on the second launch.
@MainActor
final class AppUpdater: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    static let shared = AppUpdater()

    @Published private(set) var automaticallyChecksForUpdates = false

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )
    private var hasDeferredUpdate = false
    private var cancellables: Set<AnyCancellable> = []

    private override init() {
        super.init()
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .sink { [weak self] in self?.automaticallyChecksForUpdates = $0 }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.showDeferredUpdate() }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {
        controller.updater.automaticallyChecksForUpdates = isOn
    }

    // A menu bar app is rarely active, so a scheduled update alert would open
    // behind other windows. Show it when the user next opens SlipBoard instead
    // of taking focus from what they are doing.
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
        // Sparkle proposes immediate focus right after launch, when SlipBoard
        // may not be the active app yet.
        if handleShowingUpdate, state.userInitiated == false {
            NSApp.activate()
        }
    }

    private func showDeferredUpdate() {
        guard hasDeferredUpdate else { return }
        hasDeferredUpdate = false
        checkForUpdates()
    }
}
