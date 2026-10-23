import Foundation

final class SnippetPasteExecutor: SnippetPasteExecuting {
    private let pasteExecutor: PasteActionExecutor

    init(pasteExecutor: PasteActionExecutor = PasteActionExecutor()) {
        self.pasteExecutor = pasteExecutor
    }

    func executeSnippetPaste(_ request: SnippetPasteExecutionRequest) -> SnippetPasteExecutionResult {
        guard request.snippet.content.isEmpty == false else {
            return SnippetPasteExecutionResult(
                snippetID: request.snippet.id,
                disposition: .blocked,
                statusMessage: "Snippet content is empty, so nothing was pasted.",
                pastedPreviewText: "",
                executedAt: request.requestedAt
            )
        }

        let directPasteResult = pasteExecutor.executeDirectPaste(
            payloadText: request.snippet.content,
            sourceHash: request.snippet.id.rawValue
        )

        guard directPasteResult.didWrite else {
            return SnippetPasteExecutionResult(
                snippetID: request.snippet.id,
                disposition: .blocked,
                statusMessage: "Pasteboard write failed for the selected snippet.",
                pastedPreviewText: directPasteResult.pastedPreviewText,
                executedAt: request.requestedAt
            )
        }

        guard directPasteResult.didDispatchPasteShortcut else {
            return SnippetPasteExecutionResult(
                snippetID: request.snippet.id,
                disposition: .blocked,
                statusMessage: "Snippet text reached the pasteboard, but SlipTray could not dispatch Command-V.",
                pastedPreviewText: directPasteResult.pastedPreviewText,
                executedAt: request.requestedAt
            )
        }

        return SnippetPasteExecutionResult(
            snippetID: request.snippet.id,
            disposition: .pasted,
            statusMessage: "Snippet pasted through the shared paste engine.",
            pastedPreviewText: directPasteResult.pastedPreviewText,
            executedAt: request.requestedAt
        )
    }
}
