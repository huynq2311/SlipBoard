import AppKit
import ApplicationServices
import CryptoKit
import Foundation

final class PasteActionExecutor: PasteActionExecuting {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func execute(_ request: PasteActionExecutionRequest) -> PasteActionExecutionResult {
        let payloadText = request.previewText
        let imageData = request.imageData

        guard imageData?.isEmpty == false || payloadText.isEmpty == false else {
            return PasteActionExecutionResult(
                actionID: request.actionID,
                closeBehavior: request.closeBehavior,
                popupTransition: .stayOpen,
                didSucceed: false,
                statusMessage: "Selected clip does not expose a pasteable payload in this slice.",
                pastedPreviewText: ""
            )
        }

        guard AXIsProcessTrusted() else {
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
            return PasteActionExecutionResult(
                actionID: request.actionID,
                closeBehavior: request.closeBehavior,
                popupTransition: .stayOpen,
                didSucceed: false,
                statusMessage: "Enable Accessibility for SlipBoard to paste into another app.",
                pastedPreviewText: payloadText
            )
        }

        let directPasteResult: DirectPasteDispatchResult
        if let imageData {
            directPasteResult = executeDirectImagePaste(
                imageData: imageData,
                sourceHash: request.sourceItem.normalizedHash,
                previewText: payloadText
            )
        } else {
            directPasteResult = executeDirectPaste(
                payloadText: payloadText,
                sourceHash: request.sourceItem.normalizedHash
            )
        }

        guard directPasteResult.didWrite else {
            return PasteActionExecutionResult(
                actionID: request.actionID,
                closeBehavior: request.closeBehavior,
                popupTransition: .stayOpen,
                didSucceed: false,
                statusMessage: "Pasteboard write failed. Popup stayed open for retry.",
                pastedPreviewText: payloadText,
                captureSuppressionToken: directPasteResult.captureSuppressionToken
            )
        }

        return PasteActionExecutionResult(
            actionID: request.actionID,
            closeBehavior: request.closeBehavior,
            popupTransition: directPasteResult.didDispatchPasteShortcut
                ? request.closeBehavior.popupTransition
                : .stayOpen,
            didSucceed: directPasteResult.didDispatchPasteShortcut,
            statusMessage: statusMessage(
                for: request.actionID,
                closeBehavior: request.closeBehavior,
                didSucceed: directPasteResult.didDispatchPasteShortcut
            ),
            pastedPreviewText: payloadText,
            captureSuppressionToken: directPasteResult.captureSuppressionToken
        )
    }

    func executeDirectPaste(
        payloadText: String,
        sourceHash: String
    ) -> DirectPasteDispatchResult {
        let didWrite = writeToPasteboard(payloadText)
        let suppressionToken = didWrite
            ? makeCaptureSuppressionToken(for: payloadText, fallbackHash: sourceHash)
            : nil

        guard didWrite else {
            return DirectPasteDispatchResult(
                didWrite: false,
                didDispatchPasteShortcut: false,
                pastedPreviewText: payloadText,
                captureSuppressionToken: suppressionToken
            )
        }

        return DirectPasteDispatchResult(
            didWrite: true,
            didDispatchPasteShortcut: postPasteShortcut(),
            pastedPreviewText: payloadText,
            captureSuppressionToken: suppressionToken
        )
    }

    func copyToPasteboard(_ sourceItem: PasteActionSourceItem) -> Bool {
        if let imageData = sourceItem.imageData {
            return writeImageToPasteboard(imageData)
        }

        guard let text = sourceItem.preferredTextValue, text.isEmpty == false else {
            return false
        }
        return writeToPasteboard(text)
    }

    private func executeDirectImagePaste(
        imageData: Data,
        sourceHash: String,
        previewText: String
    ) -> DirectPasteDispatchResult {
        let didWrite = writeImageToPasteboard(imageData)
        let suppressionToken = didWrite
            ? makeCaptureSuppressionToken(for: previewText, fallbackHash: sourceHash)
            : nil

        return DirectPasteDispatchResult(
            didWrite: didWrite,
            didDispatchPasteShortcut: didWrite && postPasteShortcut(),
            pastedPreviewText: previewText,
            captureSuppressionToken: suppressionToken
        )
    }

    private func writeToPasteboard(_ string: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(string, forType: .string)
    }

    private func writeImageToPasteboard(_ data: Data) -> Bool {
        guard let image = NSImage(data: data) else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    private func postPasteShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }

        source.localEventsSuppressionInterval = 0

        let keyCode = CGKeyCode(9) // V
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    private func makeCaptureSuppressionToken(for payloadText: String, fallbackHash: String) -> String {
        let normalized = payloadText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.isEmpty == false else {
            return "programmatic-write:\(fallbackHash)"
        }

        let digest = SHA256.hash(data: Data(normalized.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "programmatic-write:\(hash)"
    }

    private func statusMessage(
        for actionID: PasteActionID,
        closeBehavior: PasteActionCloseBehavior,
        didSucceed: Bool
    ) -> String {
        guard didSucceed else {
            return "Paste failed. Popup stayed open for retry."
        }

        switch closeBehavior {
        case .closePopup:
            if actionID.resolvedTransformID == .original {
                return "Pasted and closed popup."
            }

            return "Transformed paste completed and closed popup."
        case .keepPopupOpen:
            return "Pasted and kept popup open."
        }
    }
}

struct DirectPasteDispatchResult: Hashable {
    var didWrite: Bool
    var didDispatchPasteShortcut: Bool
    var pastedPreviewText: String
    var captureSuppressionToken: String?
}

private extension PasteActionCloseBehavior {
    var popupTransition: PasteActionPopupTransition {
        switch self {
        case .closePopup:
            return .closePopup
        case .keepPopupOpen:
            return .keepPopupOpen
        }
    }
}
