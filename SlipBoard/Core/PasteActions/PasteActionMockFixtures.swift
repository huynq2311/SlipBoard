import Foundation

enum PasteActionMockFixtures {
    static let textSourceItem = PasteActionSourceItem(
        id: "clip-recent-text-01",
        kind: .text,
        primaryText: "Authorization: Bearer NOT_A_REAL_TOKEN_PLACEHOLDER",
        secondaryText: "API request header",
        rawText: "Authorization: Bearer NOT_A_REAL_TOKEN_PLACEHOLDER",
        plainText: "Authorization: Bearer NOT_A_REAL_TOKEN_PLACEHOLDER",
        sourceAppDisplayName: "Terminal",
        normalizedHash: "hash-api-header"
    )

    static let codeSourceItem = PasteActionSourceItem(
        id: "clip-recent-code-01",
        kind: .code,
        primaryText: "curl -X POST https://api.slipboard.local/v1/paste",
        secondaryText: "Release tooling snippet",
        rawText: "curl -X POST https://api.slipboard.local/v1/paste",
        plainText: "curl -X POST https://api.slipboard.local/v1/paste",
        sourceAppDisplayName: "Xcode",
        normalizedHash: "hash-curl-command"
    )

    static let fileSourceItem = PasteActionSourceItem(
        id: "clip-recent-file-01",
        kind: .file,
        primaryText: "Release Notes.pdf",
        secondaryText: "/Users/demo/Desktop/Release Notes.pdf",
        rawText: nil,
        plainText: nil,
        sourceAppDisplayName: "Finder",
        normalizedHash: "hash-release-notes-pdf"
    )

    static let defaultPreview = PasteActionPreviewState(
        kind: .text,
        titleText: "Paste As...",
        previewText: textSourceItem.primaryText,
        statusText: "Original clipboard text preview."
    )

    static let unsupportedPreview = PasteActionPreviewState(
        kind: .unsupported,
        titleText: "Paste As...",
        previewText: "",
        placeholderText: "This clip does not expose text transforms in the first slice.",
        statusText: "Original paste remains available."
    )

    static let contextMenuOverlay = PasteActionOverlayState(
        isPresented: true,
        kind: .contextMenu,
        anchorClipID: textSourceItem.id,
        highlightedTarget: .contextCommand("paste"),
        preview: .empty,
        isExecuting: false
    )

    static let pasteTransformOverlay = PasteActionOverlayState(
        isPresented: true,
        kind: .pasteTransformMenu,
        anchorClipID: textSourceItem.id,
        highlightedTarget: .action(.plainText),
        preview: defaultPreview,
        isExecuting: false
    )

    static let keepOpenRequest = PasteActionExecutionRequest(
        clipID: textSourceItem.id,
        actionID: .pasteAndKeepOpen,
        closeBehavior: .keepPopupOpen,
        sourceItem: textSourceItem,
        previewText: textSourceItem.primaryText
    )

    static let successfulKeepOpenResult = PasteActionExecutionResult(
        actionID: .pasteAndKeepOpen,
        closeBehavior: .keepPopupOpen,
        popupTransition: .keepPopupOpen,
        didSucceed: true,
        statusMessage: "Pasted and kept popup open.",
        pastedPreviewText: textSourceItem.primaryText,
        captureSuppressionToken: "programmatic-write:hash-api-header"
    )

    static let failedTransformResult = PasteActionExecutionResult(
        actionID: .markdown,
        closeBehavior: .closePopup,
        popupTransition: .stayOpen,
        didSucceed: false,
        statusMessage: "Paste failed. Popup stayed open for retry.",
        pastedPreviewText: "",
        captureSuppressionToken: nil
    )

    static let supportedTextActions: [PasteActionID] = [
        .original,
        .pasteAndClose,
        .pasteAndKeepOpen
    ] + PasteActionID.transformMenuOrder
}
