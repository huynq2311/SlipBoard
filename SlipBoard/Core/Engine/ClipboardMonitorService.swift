import Foundation

// MARK: - ClipboardMonitorServiceProtocol

/// The service boundary for NSPasteboard polling.
///
/// This protocol defines the contract without committing to any implementation.
/// The real polling loop requires explicit system-access and hotkey approval
/// (`gate-hotkey-implementation`) and is out of scope for this feature.
///
/// Consumers depend only on this protocol so the real implementation can be
/// swapped in without touching call sites.
protocol ClipboardMonitorServiceProtocol: AnyObject {
    /// Whether the monitor is currently active and polling the pasteboard.
    var isMonitoring: Bool { get }

    /// Start polling the pasteboard. No-op if already monitoring.
    func startMonitoring()

    /// Stop polling the pasteboard. No-op if not monitoring.
    func stopMonitoring()

    /// Called by the monitor each time a new distinct item is detected.
    /// Set this before calling `startMonitoring()`.
    var onNewItem: ((RawPasteboardSnapshot) -> Void)? { get set }
}

// MARK: - NoOpClipboardMonitor

/// A no-op stub that satisfies `ClipboardMonitorServiceProtocol` without starting
/// any real NSPasteboard polling loop.
///
/// Use this in:
/// - Fixture-backed session providers (static UI phase)
/// - Unit type-checking
/// - Any context where real capture is intentionally disabled
final class NoOpClipboardMonitor: ClipboardMonitorServiceProtocol {

    // MARK: - ClipboardMonitorServiceProtocol

    /// Always `false` — the no-op monitor never polls.
    private(set) var isMonitoring: Bool = false

    /// Stored but never invoked by this stub.
    var onNewItem: ((RawPasteboardSnapshot) -> Void)?

    /// No-op — does not start any timer or NSPasteboard change-count polling.
    func startMonitoring() {
        // Intentionally empty. Real implementation is gated behind
        // gate-hotkey-implementation and gate-xcode-project-config.
    }

    /// No-op — nothing to stop.
    func stopMonitoring() {
        // Intentionally empty.
    }

    // MARK: - Lifecycle

    init() {}
}
