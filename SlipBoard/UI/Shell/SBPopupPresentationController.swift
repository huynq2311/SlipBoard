import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class SBPopupPresentationController: NSObject, NSWindowDelegate {
    private enum Layout {
        static let horizontalInset: CGFloat = 0
        static let verticalInset: CGFloat = 0
        // Keep the screen edge free so an auto-hidden Dock can be revealed.
        static let dockRevealInset: CGFloat = 8
        // Reserve room for the top chrome, a content-sized pinned rail, and the
        // recent rail, which stretches its card height to fill what's left.
        static let preferredHeight: CGFloat = 380
        static let presentationDuration: TimeInterval = 0.28
    }

    var onVisibilityChange: ((Bool) -> Void)?
    var onDeleteRequested: (() -> Void)?
    var onPrimaryPasteRequested: (() -> Void)?
    var onMoveSelectionRequested: ((Int) -> Void)?

    private var panel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var isLockedPresentation = false
    private var escapeKeyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var applicationActivationObserver: NSObjectProtocol?
    private var pasteTargetApplication: NSRunningApplication?
    private var pendingPasteAction: (() -> Void)?

    override init() {
        super.init()

        applicationActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.rememberPasteTarget(application)
        }

        rememberPasteTarget(NSWorkspace.shared.frontmostApplication)
    }

    deinit {
        if let applicationActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(applicationActivationObserver)
        }
    }

    var isPresented: Bool {
        panel?.isVisible == true
    }

    func present<Content: View>(
        isLocked: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        let rootView = AnyView(content())
        isLockedPresentation = isLocked
        capturePasteTargetApplication()
        NSApp.activate(ignoringOtherApps: true)
        installEscapeKeyMonitorIfNeeded()
        installOutsideClickMonitorIfNeeded()

        if let hostingController {
            hostingController.rootView = rootView
            updatePanelAppearance(isLocked: isLocked)
            if let panel {
                if panel.isVisible {
                    panel.setFrame(targetFrame(for: panel.screen ?? presentationScreen()), display: true)
                    panel.makeKeyAndOrderFront(nil)
                } else {
                    presentPanel(panel, on: presentationScreen())
                }
            }
            onVisibilityChange?(true)
            return
        }

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = []
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 716, height: 456),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        // .floating (not .statusBar) so an auto-hidden Dock still draws above
        // us when revealed, instead of staying hidden behind the popup.
        panel.level = .floating
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self
        updatePanelAppearance(isLocked: isLocked, for: panel)

        self.panel = panel
        self.hostingController = hostingController

        presentPanel(panel, on: presentationScreen())
        onVisibilityChange?(true)
    }

    func dismiss() {
        guard let panel else { return }
        guard panel.isVisible else {
            removeEscapeKeyMonitor()
            removeOutsideClickMonitor()
            onVisibilityChange?(false)
            return
        }
        panel.orderOut(nil)
        removeEscapeKeyMonitor()
        removeOutsideClickMonitor()
        onVisibilityChange?(false)
    }

    func dismissIfNeeded(notifyVisibilityChange: Bool = true) {
        guard let panel, panel.isVisible else {
            removeEscapeKeyMonitor()
            removeOutsideClickMonitor()
            if notifyVisibilityChange {
                onVisibilityChange?(false)
            }
            return
        }

        panel.orderOut(nil)
        removeEscapeKeyMonitor()
        removeOutsideClickMonitor()

        if notifyVisibilityChange {
            onVisibilityChange?(false)
        }
    }

    func restorePasteTargetThen(
        _ action: @escaping () -> Void,
        onPermissionDenied: () -> Void,
        onTargetUnavailable: @escaping () -> Void
    ) {
        guard AXIsProcessTrusted() else {
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
            onPermissionDenied()
            return
        }

        let targetApplication = pasteTargetApplication
        pendingPasteAction = action
        dismiss()

        guard let targetApplication, targetApplication.isTerminated == false else {
            pendingPasteAction = nil
            onTargetUnavailable()
            return
        }

        targetApplication.activate()
        waitForPasteTargetActivation(
            targetApplication,
            attemptsRemaining: 30,
            onTargetUnavailable: onTargetUnavailable
        )
    }

    func windowWillClose(_ notification: Notification) {
        onVisibilityChange?(false)
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }

    private func updatePanelAppearance(isLocked: Bool, for panel: NSPanel? = nil) {
        let panel = panel ?? self.panel
        panel?.title = isLocked ? "SlipBoard Locked" : "SlipBoard"
        panel?.identifier = NSUserInterfaceItemIdentifier(isLocked ? "slipboard.popup.locked" : "slipboard.popup.unlocked")
    }

    private func capturePasteTargetApplication() {
        rememberPasteTarget(NSWorkspace.shared.frontmostApplication)
    }

    private func rememberPasteTarget(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != NSRunningApplication.current.processIdentifier else {
            return
        }

        pasteTargetApplication = application
    }

    private func schedulePendingPasteAction(after delay: TimeInterval) {
        Timer.scheduledTimer(
            timeInterval: delay,
            target: self,
            selector: #selector(runPendingPasteAction),
            userInfo: nil,
            repeats: false
        )
    }

    private func waitForPasteTargetActivation(
        _ targetApplication: NSRunningApplication,
        attemptsRemaining: Int,
        onTargetUnavailable: @escaping () -> Void
    ) {
        guard pendingPasteAction != nil else { return }

        if NSWorkspace.shared.frontmostApplication?.processIdentifier == targetApplication.processIdentifier {
            // Give the target window a run-loop turn to restore its first responder.
            schedulePendingPasteAction(after: 0.18)
            return
        }

        guard attemptsRemaining > 0, targetApplication.isTerminated == false else {
            // Do not send Cmd+V while SlipBoard is still frontmost.
            pendingPasteAction = nil
            onTargetUnavailable()
            return
        }

        // Re-issuing activate() on every poll fights the in-flight activation
        // and can make macOS take noticeably longer to bring the target forward.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak targetApplication] in
            guard let self, let targetApplication else { return }
            self.waitForPasteTargetActivation(
                targetApplication,
                attemptsRemaining: attemptsRemaining - 1,
                onTargetUnavailable: onTargetUnavailable
            )
        }
    }

    @objc private func runPendingPasteAction() {
        let action = pendingPasteAction
        pendingPasteAction = nil
        action?()
    }

    private func presentationScreen() -> NSScreen {
        NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func targetFrame(for screen: NSScreen) -> NSRect {
        let visibleFrame = screen.visibleFrame
        let width = max(1, visibleFrame.width - (Layout.horizontalInset * 2))
        let height = max(1, min(Layout.preferredHeight, visibleFrame.height - Layout.dockRevealInset - (Layout.verticalInset * 2)))

        return NSRect(
            x: visibleFrame.minX + Layout.horizontalInset,
            y: visibleFrame.minY + Layout.dockRevealInset + Layout.verticalInset,
            width: width,
            height: height
        )
    }

    private func presentPanel(_ panel: NSPanel, on screen: NSScreen) {
        let targetFrame = targetFrame(for: screen)
        var startFrame = targetFrame
        startFrame.origin.y = screen.visibleFrame.minY - targetFrame.height

        panel.setFrame(startFrame, display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.presentationDuration
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func installEscapeKeyMonitorIfNeeded() {
        guard escapeKeyMonitor == nil else { return }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isPresented else {
                return event
            }

            switch event.keyCode {
            case 53:
                self.dismiss()
                return nil
            case 51, 117:
                guard self.isEditingText == false else { return event }
                self.onDeleteRequested?()
                return nil
            case 36:
                guard self.isEditingText == false else { return event }
                self.onPrimaryPasteRequested?()
                return nil
            case 48:
                guard self.isEditingText == false else { return event }
                let delta = event.modifierFlags.contains(.shift) ? -1 : 1
                self.onMoveSelectionRequested?(delta)
                return nil
            case 123, 126:
                guard self.isEditingText == false else { return event }
                self.onMoveSelectionRequested?(-1)
                return nil
            case 124, 125:
                guard self.isEditingText == false else { return event }
                self.onMoveSelectionRequested?(1)
                return nil
            default:
                return event
            }
        }
    }

    private var isEditingText: Bool {
        (panel?.firstResponder as? NSTextView)?.isEditable == true
    }

    private func removeEscapeKeyMonitor() {
        guard let escapeKeyMonitor else { return }
        NSEvent.removeMonitor(escapeKeyMonitor)
        self.escapeKeyMonitor = nil
    }

    // A `.nonactivatingPanel` at `.statusBar` level does not reliably resign
    // key on an outside click (e.g. clicking the desktop or another app's
    // window), so windowDidResignKey alone cannot be trusted to dismiss us.
    // A global click monitor is the standard, reliable way status-item
    // popups handle "click outside to close".
    private func installOutsideClickMonitorIfNeeded() {
        guard outsideClickMonitor == nil else { return }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            guard panel.frame.contains(NSEvent.mouseLocation) == false else { return }
            self.dismiss()
        }
    }

    private func removeOutsideClickMonitor() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}
