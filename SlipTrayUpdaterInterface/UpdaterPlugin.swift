import Foundation

/// What SlipTray calls on the updater plug-in
/// (Contents/PlugIns/SlipTrayUpdater.bundle), the only code that links
/// Sparkle. Compiled into both targets; the app finds the conformance at
/// runtime by the Objective-C name.
@objc(SBUpdaterPlugin)
@MainActor
protocol UpdaterPlugin: NSObjectProtocol {
    /// Called when Sparkle's automatic-check setting changes, including when
    /// the user answers its permission prompt.
    var onAutomaticChecksChange: ((Bool) -> Void)? { get set }
    var automaticallyChecksForUpdates: Bool { get set }
    func checkForUpdates()
    func showDeferredUpdate()
}
