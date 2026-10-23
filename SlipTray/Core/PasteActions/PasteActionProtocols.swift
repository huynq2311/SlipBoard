import Foundation

protocol PasteActionTransforming {
    func supportedActions(for sourceItem: PasteActionSourceItem) -> [PasteActionID]
    func preview(for actionID: PasteActionID, sourceItem: PasteActionSourceItem) -> PasteActionPreviewState
    func payload(for actionID: PasteActionID, sourceItem: PasteActionSourceItem) -> PasteActionPayload
}

protocol PasteActionExecuting: AnyObject {
    func execute(_ request: PasteActionExecutionRequest) -> PasteActionExecutionResult
    func copyToPasteboard(_ sourceItem: PasteActionSourceItem) -> Bool
}

protocol PasteActionRuntimeCoordinating: AnyObject {
    var selectedSourceItem: PasteActionSourceItem? { get }
    var overlayState: PasteActionOverlayState { get }
    var lastExecutionResult: PasteActionExecutionResult? { get }

    func openContextMenu(for clipID: String)
    func openPasteTransformMenu(for clipID: String, highlightedActionID: PasteActionID) -> Bool
    func highlightTransformAction(_ actionID: PasteActionID)
    func closeActiveOverlay()
    func performAction(
        _ actionID: PasteActionID,
        closeBehavior: PasteActionCloseBehavior
    ) -> PasteActionExecutionResult?
}
