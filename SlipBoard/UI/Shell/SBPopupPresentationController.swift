import AppKit
import ApplicationServices
import SwiftUI

private final class SBPopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class SBPopupPresentationController: NSObject, NSWindowDelegate {
    private enum Layout {
        static let horizontalInset: CGFloat = 15
        static let verticalInset: CGFloat = 0
        // Keep the screen edge free so an auto-hidden Dock can be revealed.
        static let dockRevealInset: CGFloat = 15
        // Reserve room for the top chrome, a content-sized pinned rail, and the
        // recent rail, which stretches its card height to fill what's left.
        static let preferredHeight: CGFloat = SBPopupLayoutMetrics.expandedContentHeight
        // Enough room for the Paste As menu above a recent card. This region
        // stays transparent, allowing the menu to overlap the app underneath.
        static let overlayHeadroom: CGFloat = 420
        static let presentationDuration: TimeInterval = 0.18
        static let dismissalDuration: TimeInterval = 0.14
    }

    var onVisibilityChange: ((Bool) -> Void)?
    var onDeleteRequested: (() -> Void)?
    var onPrimaryPasteRequested: (() -> Void)?
    var onMoveSelectionRequested: ((Int) -> Void)?
    var onTypeToSearchCharacters: ((String) -> Void)?
    /// Returns true when it handled Escape itself, so the popup stays open.
    var onEscapeRequested: (() -> Bool)?

    private var panel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var isLockedPresentation = false
    private var escapeKeyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var applicationActivationObserver: NSObjectProtocol?
    private var pasteTargetApplication: NSRunningApplication?
    private var pendingPasteAction: (() -> Void)?
    private var transitionGeneration = 0
    private var isDismissing = false
    private var reservesOverlayHeadroom = false
    private var shellMargin = EdgeInsets()

    override init() {
        super.init()

        applicationActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self?.rememberPasteTarget(application)
            }
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
        reservesOverlayHeadroom: Bool = false,
        shellMargin: EdgeInsets = EdgeInsets(),
        @ViewBuilder content: () -> Content
    ) {
        let rootView = AnyView(content())
        isLockedPresentation = isLocked
        self.reservesOverlayHeadroom = reservesOverlayHeadroom
        self.shellMargin = shellMargin
        capturePasteTargetApplication()
        // `.nonactivatingPanel` + makeKeyAndOrderFront already grants this
        // panel keyboard focus without the app becoming frontmost. Forcing
        // NSApp.activate here made every reopen after an outside-click
        // dismissal pay for a real cross-app activation switch (the app that
        // was clicked into had to resign frontmost first) even though the
        // panel doesn't need it.
        installEscapeKeyMonitorIfNeeded()
        installOutsideClickMonitorIfNeeded()

        if hostingController != nil {
            // The installed root view observes the runtime, so it already
            // reflects the current state; re-pushing it here would make
            // SwiftUI rebuild and re-compare the whole popup graph.
            updatePanelAppearance(isLocked: isLocked)
            if let panel {
                if panel.isVisible {
                    transitionGeneration += 1
                    isDismissing = false
                    panel.alphaValue = 1
                    let newFrame = targetFrame(for: panel.screen ?? presentationScreen())
                    // Resized in one step: SwiftUI animates the content itself,
                    // and driving the window frame through an animation as well
                    // made the hosting view request another constraints pass on
                    // every frame until AppKit aborted with an exception.
                    panel.setFrame(newFrame, display: true)
                    panel.makeKeyAndOrderFront(nil)
                } else {
                    presentPanel(panel, on: presentationScreen())
                }
            }
            onVisibilityChange?(true)
            return
        }

        let panel = makePanel(rootView: rootView, isLocked: isLocked)
        presentPanel(panel, on: presentationScreen())
        onVisibilityChange?(true)
    }

    /// Builds the hosting panel ahead of the first real `present()` call so
    /// that heavy one-time work (NSHostingController construction, the
    /// SwiftUI hierarchy's first layout pass) happens quietly while the app
    /// launches instead of racing the user's first hotkey press + keystroke.
    /// Shown off-screen (never key, never activates the app) purely to force
    /// that first layout pass; a real `present()` later reuses it via the
    /// fast `hostingController != nil` path.
    func prewarm<Content: View>(@ViewBuilder content: () -> Content) {
        guard hostingController == nil else { return }

        let panel = makePanel(rootView: AnyView(content()), isLocked: false)
        panel.setFrame(NSRect(x: -10000, y: -10000, width: 716, height: 456), display: true)
        // Force the window to actually draw its content once (order in,
        // triggering the SwiftUI hierarchy's first real layout pass) then
        // hide it again immediately so `isVisible` reads false and the real
        // first `present()` still takes its normal animated "not visible"
        // path instead of the instant already-visible reposition path.
        panel.orderFrontRegardless()
        panel.orderOut(nil)
    }

    private func makePanel(rootView: AnyView, isLocked: Bool) -> NSPanel {
        // No Text in the popup may open a URL: clip content is untrusted.
        let hostingController = NSHostingController(rootView: AnyView(
            rootView.environment(\.openURL, OpenURLAction { _ in .discarded })
        ))
        hostingController.sizingOptions = []
        let panel = SBPopupPanel(
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
        return panel
    }

    func dismiss() {
        guard let panel else { return }
        guard panel.isVisible else {
            removeEscapeKeyMonitor()
            removeOutsideClickMonitor()
            onVisibilityChange?(false)
            return
        }
        dismissPanel(panel, notifyVisibilityChange: true)
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

        dismissPanel(panel, notifyVisibilityChange: notifyVisibilityChange)
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

        // Re-applied on every present(), not just the first: present() reuses
        // the same panel/hosting view across show/hide cycles, and both need
        // to stay transparent for the SwiftUI content's rounded-rect clip to
        // actually show rounded corners instead of a squared-off backing.
        panel?.isOpaque = false
        panel?.backgroundColor = .clear
        panel?.hasShadow = false
        // Keep the SwiftUI palette in the same working space when the popup
        // follows the pointer to an external display with its own ICC profile.
        panel?.colorSpace = .sRGB
        if let hostingView = panel?.contentViewController?.view {
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        }
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
        // Always the expanded height: collapsing the pinned rail shrinks the
        // shell inside a transparent window instead of resizing the window,
        // so SwiftUI can animate it without fighting a window resize.
        let requestedHeight = Layout.preferredHeight + (reservesOverlayHeadroom ? Layout.overlayHeadroom : 0)
        let height = max(1, min(requestedHeight, visibleFrame.height - Layout.dockRevealInset - (Layout.verticalInset * 2)))

        // The shell keeps its on-screen position; only the transparent window
        // grows around it.
        return NSRect(
            x: visibleFrame.minX + Layout.horizontalInset - shellMargin.leading,
            y: visibleFrame.minY + Layout.dockRevealInset + Layout.verticalInset - shellMargin.bottom,
            width: width + shellMargin.leading + shellMargin.trailing,
            height: height + shellMargin.top + shellMargin.bottom
        )
    }

    private func presentPanel(_ panel: NSPanel, on screen: NSScreen) {
        transitionGeneration += 1
        isDismissing = false

        // The window only fades; the shell's slide is a SwiftUI animation on
        // `isPresented`, which runs on the display link instead of moving the
        // whole window frame by frame.
        panel.alphaValue = 0
        panel.setFrame(targetFrame(for: screen), display: true)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.presentationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func dismissPanel(_ panel: NSPanel, notifyVisibilityChange: Bool) {
        guard isDismissing == false else { return }

        transitionGeneration += 1
        let generation = transitionGeneration
        isDismissing = true
        // The panel is only ordered out, so a focused search field would still
        // hold the keyboard the next time it opens.
        panel.makeFirstResponder(nil)
        removeEscapeKeyMonitor()
        removeOutsideClickMonitor()
        if notifyVisibilityChange {
            onVisibilityChange?(false)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.dismissalDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.finishDismissal(generation: generation)
            }
        }
    }

    private func finishDismissal(generation: Int) {
        guard let panel, generation == transitionGeneration else { return }

        panel.orderOut(nil)
        panel.alphaValue = 1
        isDismissing = false
    }

    private func installEscapeKeyMonitorIfNeeded() {
        guard escapeKeyMonitor == nil else { return }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isPresented else {
                return event
            }

            switch event.keyCode {
            case 53:
                if self.onEscapeRequested?() == true { return nil }
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
                guard self.isEditingText == false else { return event }
                guard event.modifierFlags.intersection([.command, .control, .function]).isEmpty else { return event }
                guard let characters = event.characters, characters.isEmpty == false else { return event }
                guard characters.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else { return event }
                self.onTypeToSearchCharacters?(characters)
                return nil
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
            let shellFrame = NSRect(
                x: panel.frame.minX + self.shellMargin.leading,
                y: panel.frame.minY + self.shellMargin.bottom,
                width: panel.frame.width - self.shellMargin.leading - self.shellMargin.trailing,
                height: panel.frame.height - self.shellMargin.top - self.shellMargin.bottom
            )
            guard shellFrame.contains(NSEvent.mouseLocation) == false else { return }
            self.dismiss()
        }
    }

    private func removeOutsideClickMonitor() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}
