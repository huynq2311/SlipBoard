import AppKit
import Foundation

final class FrontmostApplicationTracker: FrontmostApplicationObserving {
    var latestContext: FrontmostAppContext?
    var onContextChange: ((FrontmostAppContext?) -> Void)?

    private let workspace: NSWorkspace
    private let notificationCenter: NotificationCenter

    private var activationObserver: NSObjectProtocol?
    private var hideObserver: NSObjectProtocol?
    private var isStarted = false

    init(
        workspace: NSWorkspace = .shared,
        notificationCenter: NotificationCenter? = nil
    ) {
        self.workspace = workspace
        self.notificationCenter = notificationCenter ?? workspace.notificationCenter
        self.latestContext = Self.makeContext(from: workspace.frontmostApplication)
    }

    deinit {
        stop()
    }

    func start() {
        guard isStarted == false else { return }
        isStarted = true

        activationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.publishContext(Self.makeContext(from: application))
        }

        hideObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didHideApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            self?.refreshNow()
        }

        refreshNow()
    }

    func stop() {
        if let activationObserver {
            notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }

        if let hideObserver {
            notificationCenter.removeObserver(hideObserver)
            self.hideObserver = nil
        }

        isStarted = false
    }

    func refreshNow() {
        publishContext(Self.makeContext(from: workspace.frontmostApplication))
    }

    private func publishContext(_ context: FrontmostAppContext?) {
        guard hasContextChanged(comparedTo: latestContext, nextContext: context) else {
            return
        }

        latestContext = context
        onContextChange?(context)
    }

    private func hasContextChanged(
        comparedTo currentContext: FrontmostAppContext?,
        nextContext: FrontmostAppContext?
    ) -> Bool {
        switch (currentContext, nextContext) {
        case (nil, nil):
            return false
        case (nil, .some), (.some, nil):
            return true
        case let (.some(currentContext), .some(nextContext)):
            return currentContext.bundleID != nextContext.bundleID
                || currentContext.displayName != nextContext.displayName
                || currentContext.symbolName != nextContext.symbolName
                || currentContext.accentToken != nextContext.accentToken
        }
    }

    private static func makeContext(from application: NSRunningApplication?) -> FrontmostAppContext? {
        guard application != nil else {
            return nil
        }

        let summary = ClipboardApplicationSummaryFactory.makeSummary(from: application)

        return FrontmostAppContext(
            bundleID: summary.bundleID,
            displayName: summary.displayName,
            symbolName: summary.symbolName,
            accentToken: summary.accentToken,
            observedAt: .now
        )
    }
}
