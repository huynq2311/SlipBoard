import Foundation

final class PasteActionCoordinator: PasteActionRuntimeCoordinating {
    var selectedSourceItem: PasteActionSourceItem? {
        historyController.selectedPasteActionSourceItem()
    }

    private(set) var overlayState: PasteActionOverlayState = .hidden
    private(set) var lastExecutionResult: PasteActionExecutionResult?

    private unowned let historyController: ClipboardHistoryController
    private let transformer: PasteActionTransforming
    private let executor: PasteActionExecuting

    init(
        historyController: ClipboardHistoryController,
        transformer: PasteActionTransforming = PasteActionTransformer(),
        executor: PasteActionExecuting = PasteActionExecutor()
    ) {
        self.historyController = historyController
        self.transformer = transformer
        self.executor = executor
    }

    func openContextMenu(for clipID: String) {
        guard isSelectedClip(clipID) else { return }

        overlayState = PasteActionOverlayState(
            isPresented: true,
            kind: .contextMenu,
            anchorClipID: clipID,
            highlightedTarget: .contextCommand("paste"),
            preview: .empty,
            isExecuting: false
        )
    }

    @discardableResult
    func openPasteTransformMenu(for clipID: String, highlightedActionID: PasteActionID) -> Bool {
        guard let sourceItem = selectedSourceItem,
              sourceItem.id == clipID,
              sourceItem.supportsTextTransforms else {
            overlayState = .hidden
            return false
        }

        let supportedActions = transformer.supportedActions(for: sourceItem)
        let actionID = preferredTransformAction(
            requestedActionID: highlightedActionID,
            supportedActions: supportedActions
        )

        overlayState = PasteActionOverlayState(
            isPresented: true,
            kind: .pasteTransformMenu,
            anchorClipID: clipID,
            highlightedTarget: .action(actionID),
            preview: transformer.preview(for: actionID, sourceItem: sourceItem),
            isExecuting: false
        )
        return true
    }

    func highlightTransformAction(_ actionID: PasteActionID) {
        guard
            overlayState.kind == .pasteTransformMenu,
            let sourceItem = selectedSourceItem,
            let anchorClipID = overlayState.anchorClipID,
            anchorClipID == sourceItem.id
        else {
            return
        }

        let supportedActions = transformer.supportedActions(for: sourceItem)
        let highlightedActionID = preferredTransformAction(
            requestedActionID: actionID,
            supportedActions: supportedActions
        )

        overlayState.highlightedTarget = .action(highlightedActionID)
        overlayState.preview = transformer.preview(for: highlightedActionID, sourceItem: sourceItem)
        overlayState.isExecuting = false
    }

    func closeActiveOverlay() {
        overlayState = .hidden
    }

    func copySelectedItemAgain() -> Bool {
        guard let sourceItem = selectedSourceItem else { return false }
        return executor.copyToPasteboard(sourceItem)
    }

    func performAction(
        _ actionID: PasteActionID,
        closeBehavior: PasteActionCloseBehavior
    ) -> PasteActionExecutionResult? {
        guard let sourceItem = selectedSourceItem else { return nil }

        let supportedActions = transformer.supportedActions(for: sourceItem)
        let effectiveActionID = resolvedActionID(
            requestedActionID: actionID,
            closeBehavior: closeBehavior
        )

        guard isActionSupported(effectiveActionID, supportedActions: supportedActions) else {
            let result = PasteActionExecutionResult(
                actionID: effectiveActionID,
                closeBehavior: closeBehavior,
                popupTransition: .stayOpen,
                didSucceed: false,
                statusMessage: "This transform is unavailable for the selected clip.",
                pastedPreviewText: ""
            )
            lastExecutionResult = result
            return result
        }

        let payload = transformer.payload(for: effectiveActionID, sourceItem: sourceItem)
        let request = PasteActionExecutionRequest(
            clipID: sourceItem.id,
            actionID: effectiveActionID,
            closeBehavior: closeBehavior,
            sourceItem: sourceItem,
            previewText: payload.stringValue ?? payload.previewText,
            imageData: effectiveActionID.resolvedTransformID == .original ? sourceItem.imageData : nil
        )

        overlayState.isExecuting = true
        let result = executor.execute(request)
        overlayState.isExecuting = false
        lastExecutionResult = result

        historyController.registerProgrammaticPasteSuppressionToken(result.captureSuppressionToken)

        if result.didSucceed {
            historyController.handleSuccessfulPasteActionResult(
                actionID: effectiveActionID,
                sourceItem: sourceItem,
                result: result,
                completedAt: Date()
            )
            overlayState = .hidden
        } else if overlayState.kind == .pasteTransformMenu {
            overlayState.highlightedTarget = .action(effectiveActionID.resolvedTransformID)
            overlayState.preview = transformer.preview(
                for: effectiveActionID.resolvedTransformID,
                sourceItem: sourceItem
            )
        }

        return result
    }

    private func isSelectedClip(_ clipID: String) -> Bool {
        selectedSourceItem?.id == clipID
    }

    private func preferredTransformAction(
        requestedActionID: PasteActionID,
        supportedActions: [PasteActionID]
    ) -> PasteActionID {
        let resolvedActionID = requestedActionID.resolvedTransformID
        if supportedActions.contains(resolvedActionID) {
            return resolvedActionID
        }

        return supportedActions.first(where: \.isTransformAction) ?? .plainText
    }

    private func resolvedActionID(
        requestedActionID: PasteActionID,
        closeBehavior: PasteActionCloseBehavior
    ) -> PasteActionID {
        switch (requestedActionID, closeBehavior) {
        case (.original, .closePopup):
            return .pasteAndClose
        case (.original, .keepPopupOpen):
            return .pasteAndKeepOpen
        default:
            return requestedActionID
        }
    }

    private func isActionSupported(
        _ actionID: PasteActionID,
        supportedActions: [PasteActionID]
    ) -> Bool {
        supportedActions.contains(actionID) || supportedActions.contains(actionID.resolvedTransformID)
    }
}
