import Foundation

enum PasteActionID: String, CaseIterable, Identifiable, Hashable {
    case original
    case pasteAndClose
    case pasteAndKeepOpen
    case plainText
    case markdown
    case stripUnicodeAccent
    case uppercase
    case lowercase

    var id: String { rawValue }

    var resolvedTransformID: PasteActionID {
        switch self {
        case .pasteAndClose, .pasteAndKeepOpen:
            return .original
        default:
            return self
        }
    }

    var defaultCloseBehavior: PasteActionCloseBehavior {
        switch self {
        case .pasteAndKeepOpen:
            return .keepPopupOpen
        default:
            return .closePopup
        }
    }

    var isTransformAction: Bool {
        switch self {
        case .plainText, .markdown, .stripUnicodeAccent, .uppercase, .lowercase:
            return true
        default:
            return false
        }
    }

    static let transformMenuOrder: [PasteActionID] = [
        .plainText,
        .markdown,
        .stripUnicodeAccent,
        .uppercase,
        .lowercase
    ]
}

enum PasteActionCloseBehavior: String, Hashable {
    case closePopup
    case keepPopupOpen
}

enum PasteActionPopupTransition: String, Hashable {
    case closePopup
    case keepPopupOpen
    case stayOpen
}

enum PasteActionSourceKind: String, Hashable {
    case text
    case code
    case image
    case file
    case url
    case color
    case richText
    case unknown
}

struct PasteActionSourceItem: Identifiable, Hashable {
    let id: String
    var kind: PasteActionSourceKind
    var primaryText: String
    var secondaryText: String?
    var rawText: String?
    var plainText: String?
    var imageData: Data?
    var sourceAppDisplayName: String
    var normalizedHash: String
    var richTextAvailable: Bool

    init(
        id: String,
        kind: PasteActionSourceKind,
        primaryText: String,
        secondaryText: String? = nil,
        rawText: String? = nil,
        plainText: String? = nil,
        imageData: Data? = nil,
        sourceAppDisplayName: String,
        normalizedHash: String,
        richTextAvailable: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.rawText = rawText
        self.plainText = plainText
        self.imageData = imageData
        self.sourceAppDisplayName = sourceAppDisplayName
        self.normalizedHash = normalizedHash
        self.richTextAvailable = richTextAvailable
    }

    var preferredTextValue: String? {
        plainText ?? rawText
    }

    var supportsTextTransforms: Bool {
        guard let preferredTextValue else { return false }
        return preferredTextValue.isEmpty == false
    }
}

enum PasteActionPayloadOrigin: String, Hashable {
    case original
    case transformed
}

struct PasteActionPayload: Hashable {
    var actionID: PasteActionID
    var origin: PasteActionPayloadOrigin
    var stringValue: String?
    var previewText: String
    var isTextual: Bool
    var sourceHash: String

    init(
        actionID: PasteActionID,
        origin: PasteActionPayloadOrigin,
        stringValue: String?,
        previewText: String,
        isTextual: Bool,
        sourceHash: String
    ) {
        self.actionID = actionID
        self.origin = origin
        self.stringValue = stringValue
        self.previewText = previewText
        self.isTextual = isTextual
        self.sourceHash = sourceHash
    }
}

enum PasteActionPreviewKind: String, Hashable {
    case text
    case empty
    case unsupported
}

struct PasteActionPreviewState: Hashable {
    var kind: PasteActionPreviewKind
    var titleText: String
    var previewText: String
    var placeholderText: String?
    var statusText: String?

    init(
        kind: PasteActionPreviewKind,
        titleText: String,
        previewText: String,
        placeholderText: String? = nil,
        statusText: String? = nil
    ) {
        self.kind = kind
        self.titleText = titleText
        self.previewText = previewText
        self.placeholderText = placeholderText
        self.statusText = statusText
    }

    static let empty = PasteActionPreviewState(
        kind: .empty,
        titleText: "Paste As...",
        previewText: "",
        placeholderText: "Select a transform to preview the outgoing text."
    )
}

enum PasteActionOverlayKind: String, Hashable {
    case contextMenu
    case pasteTransformMenu
}

enum PasteActionOverlayHighlight: Hashable {
    case contextCommand(String)
    case action(PasteActionID)
}

struct PasteActionOverlayState: Hashable {
    var isPresented: Bool
    var kind: PasteActionOverlayKind?
    var anchorClipID: String?
    var highlightedTarget: PasteActionOverlayHighlight?
    var preview: PasteActionPreviewState
    var isExecuting: Bool

    init(
        isPresented: Bool = false,
        kind: PasteActionOverlayKind? = nil,
        anchorClipID: String? = nil,
        highlightedTarget: PasteActionOverlayHighlight? = nil,
        preview: PasteActionPreviewState = .empty,
        isExecuting: Bool = false
    ) {
        self.isPresented = isPresented
        self.kind = kind
        self.anchorClipID = anchorClipID
        self.highlightedTarget = highlightedTarget
        self.preview = preview
        self.isExecuting = isExecuting
    }

    static let hidden = PasteActionOverlayState()
}

struct PasteActionExecutionRequest: Hashable {
    var clipID: String
    var actionID: PasteActionID
    var closeBehavior: PasteActionCloseBehavior
    var sourceItem: PasteActionSourceItem
    var previewText: String
    var imageData: Data?

    init(
        clipID: String,
        actionID: PasteActionID,
        closeBehavior: PasteActionCloseBehavior,
        sourceItem: PasteActionSourceItem,
        previewText: String,
        imageData: Data? = nil
    ) {
        self.clipID = clipID
        self.actionID = actionID
        self.closeBehavior = closeBehavior
        self.sourceItem = sourceItem
        self.previewText = previewText
        self.imageData = imageData
    }
}

struct PasteActionExecutionResult: Hashable {
    var actionID: PasteActionID
    var closeBehavior: PasteActionCloseBehavior
    var popupTransition: PasteActionPopupTransition
    var didSucceed: Bool
    var statusMessage: String
    var pastedPreviewText: String
    var captureSuppressionToken: String?

    init(
        actionID: PasteActionID,
        closeBehavior: PasteActionCloseBehavior,
        popupTransition: PasteActionPopupTransition,
        didSucceed: Bool,
        statusMessage: String,
        pastedPreviewText: String,
        captureSuppressionToken: String? = nil
    ) {
        self.actionID = actionID
        self.closeBehavior = closeBehavior
        self.popupTransition = popupTransition
        self.didSucceed = didSucceed
        self.statusMessage = statusMessage
        self.pastedPreviewText = pastedPreviewText
        self.captureSuppressionToken = captureSuppressionToken
    }
}
