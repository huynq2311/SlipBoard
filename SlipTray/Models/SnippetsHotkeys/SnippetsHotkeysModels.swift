import Foundation

struct SnippetID: RawRepresentable, Hashable, Identifiable, ExpressibleByStringLiteral {
    var rawValue: String

    var id: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        rawValue = value
    }
}

enum SnippetContentKind: String, CaseIterable, Identifiable, Hashable {
    case plainText
    case code

    var id: String { rawValue }
}

enum HotkeyModifier: String, CaseIterable, Identifiable, Hashable {
    case command
    case shift
    case option
    case control
    case function

    var id: String { rawValue }

    var displaySymbol: String {
        switch self {
        case .command:
            return "\u{2318}"
        case .shift:
            return "\u{21E7}"
        case .option:
            return "\u{2325}"
        case .control:
            return "\u{2303}"
        case .function:
            return "fn"
        }
    }

    var sortRank: Int {
        switch self {
        case .control:
            return 0
        case .option:
            return 1
        case .shift:
            return 2
        case .command:
            return 3
        case .function:
            return 4
        }
    }
}

struct HotkeyDescriptor: Identifiable, Hashable {
    var keyCode: Int
    var keyEquivalent: String
    var modifiers: [HotkeyModifier]
    var displayLabel: String

    var id: String { normalizedIdentity }

    init(
        keyCode: Int,
        keyEquivalent: String,
        modifiers: [HotkeyModifier],
        displayLabel: String? = nil
    ) {
        self.keyCode = keyCode
        self.keyEquivalent = keyEquivalent
        self.modifiers = HotkeyDescriptor.normalizeModifiers(modifiers)
        self.displayLabel = displayLabel ?? HotkeyDescriptor.makeDisplayLabel(
            modifiers: self.modifiers,
            keyEquivalent: keyEquivalent
        )
    }

    var normalizedIdentity: String {
        let modifierIdentity = modifiers.map(\.rawValue).joined(separator: "+")
        return "\(modifierIdentity)|\(keyCode)|\(keyEquivalent.lowercased())"
    }

    private static func normalizeModifiers(_ modifiers: [HotkeyModifier]) -> [HotkeyModifier] {
        Array(Set(modifiers)).sorted { lhs, rhs in
            lhs.sortRank < rhs.sortRank
        }
    }

    private static func makeDisplayLabel(
        modifiers: [HotkeyModifier],
        keyEquivalent: String
    ) -> String {
        let modifierText = modifiers.map(\.displaySymbol).joined()
        return modifierText + keyEquivalent.uppercased()
    }
}

enum GlobalHotkeyCommandID: String, CaseIterable, Identifiable, Hashable {
    case openSlipTray
    case pasteAs
    case pauseCapturing

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .openSlipTray:
            return "Open SlipTray"
        case .pasteAs:
            return "Paste As..."
        case .pauseCapturing:
            return "Pause Capturing"
        }
    }

    var isBackgroundGlobalCommand: Bool {
        switch self {
        case .openSlipTray, .pauseCapturing:
            return true
        case .pasteAs:
            return false
        }
    }
}

enum HotkeyBindingTarget: Hashable, Identifiable {
    case globalCommand(GlobalHotkeyCommandID)
    case snippet(SnippetID)
    case reservedFutureCommand(String)

    var id: String {
        switch self {
        case let .globalCommand(commandID):
            return "global:\(commandID.rawValue)"
        case let .snippet(snippetID):
            return "snippet:\(snippetID.rawValue)"
        case let .reservedFutureCommand(commandID):
            return "future:\(commandID)"
        }
    }
}

enum HotkeyConflictKind: String, CaseIterable, Identifiable, Hashable {
    case duplicateGlobal
    case duplicateSnippet
    case reservedUnavailableCommand

    var id: String { rawValue }
}

enum HotkeyConflictSeverity: String, CaseIterable, Identifiable, Hashable {
    case warning
    case error

    var id: String { rawValue }
}

struct HotkeyConflictResult: Identifiable, Hashable {
    var target: HotkeyBindingTarget
    var candidate: HotkeyDescriptor
    var conflictingTarget: HotkeyBindingTarget
    var kind: HotkeyConflictKind
    var message: String
    var severity: HotkeyConflictSeverity

    var id: String {
        "\(target.id)|\(candidate.id)|\(conflictingTarget.id)|\(kind.rawValue)"
    }

    init(
        target: HotkeyBindingTarget,
        candidate: HotkeyDescriptor,
        conflictingTarget: HotkeyBindingTarget,
        kind: HotkeyConflictKind,
        message: String,
        severity: HotkeyConflictSeverity = .error
    ) {
        self.target = target
        self.candidate = candidate
        self.conflictingTarget = conflictingTarget
        self.kind = kind
        self.message = message
        self.severity = severity
    }
}

struct SnippetRecord: Identifiable, Hashable {
    var id: SnippetID
    var title: String
    var content: String
    var kind: SnippetContentKind
    var hotkey: HotkeyDescriptor?
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(
        id: SnippetID,
        title: String,
        content: String,
        kind: SnippetContentKind = .plainText,
        hotkey: HotkeyDescriptor? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.kind = kind
        self.hotkey = hotkey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    var hasAssignedHotkey: Bool {
        hotkey != nil
    }
}

struct GlobalHotkeyBinding: Identifiable, Hashable {
    var commandID: GlobalHotkeyCommandID
    var hotkey: HotkeyDescriptor?
    var availability: HotkeyRuntimeAvailability
    var detailText: String?

    var id: String { commandID.rawValue }

    init(
        commandID: GlobalHotkeyCommandID,
        hotkey: HotkeyDescriptor? = nil,
        availability: HotkeyRuntimeAvailability = .enabled,
        detailText: String? = nil
    ) {
        self.commandID = commandID
        self.hotkey = hotkey
        self.availability = availability
        self.detailText = detailText
    }
}

enum HotkeyRuntimeAvailability: String, CaseIterable, Identifiable, Hashable {
    case enabled
    case lockedDisabled
    case futureCommandUnavailable
    case registrationUnavailable

    var id: String { rawValue }

    var isInteractive: Bool {
        self == .enabled
    }
}

struct HotkeyBindingSummary: Identifiable, Hashable {
    var target: HotkeyBindingTarget
    var title: String
    var detailText: String?
    var hotkey: HotkeyDescriptor?
    var availability: HotkeyRuntimeAvailability
    var isPopupScoped: Bool
    var latestConflict: HotkeyConflictResult?

    var id: String { target.id }

    init(
        target: HotkeyBindingTarget,
        title: String,
        detailText: String? = nil,
        hotkey: HotkeyDescriptor? = nil,
        availability: HotkeyRuntimeAvailability = .enabled,
        isPopupScoped: Bool = false,
        latestConflict: HotkeyConflictResult? = nil
    ) {
        self.target = target
        self.title = title
        self.detailText = detailText
        self.hotkey = hotkey
        self.availability = availability
        self.isPopupScoped = isPopupScoped
        self.latestConflict = latestConflict
    }

    var shortcutLabel: String {
        hotkey?.displayLabel ?? "No hotkey"
    }
}

enum HotkeyRecorderPhase: String, CaseIterable, Identifiable, Hashable {
    case idle
    case recording
    case saved
    case conflict
    case disabled

    var id: String { rawValue }
}

struct HotkeyRecorderSessionState: Hashable {
    var target: HotkeyBindingTarget?
    var phase: HotkeyRecorderPhase
    var previouslyAssignedHotkey: HotkeyDescriptor?
    var candidateHotkey: HotkeyDescriptor?
    var conflictResult: HotkeyConflictResult?
    var availability: HotkeyRuntimeAvailability

    init(
        target: HotkeyBindingTarget? = nil,
        phase: HotkeyRecorderPhase = .idle,
        previouslyAssignedHotkey: HotkeyDescriptor? = nil,
        candidateHotkey: HotkeyDescriptor? = nil,
        conflictResult: HotkeyConflictResult? = nil,
        availability: HotkeyRuntimeAvailability = .enabled
    ) {
        self.target = target
        self.phase = phase
        self.previouslyAssignedHotkey = previouslyAssignedHotkey
        self.candidateHotkey = candidateHotkey
        self.conflictResult = conflictResult
        self.availability = availability
    }

    var isRecording: Bool {
        phase == .recording
    }
}

struct SnippetEditorDraft: Hashable {
    var title: String
    var content: String
    var kind: SnippetContentKind
    var hotkey: HotkeyDescriptor?
    var isPinned: Bool

    init(
        title: String = "",
        content: String = "",
        kind: SnippetContentKind = .plainText,
        hotkey: HotkeyDescriptor? = nil,
        isPinned: Bool = false
    ) {
        self.title = title
        self.content = content
        self.kind = kind
        self.hotkey = hotkey
        self.isPinned = isPinned
    }
}

enum SnippetEditorValidationState: Hashable {
    case valid
    case missingTitle
    case missingContent
    case hotkeyConflict(HotkeyConflictResult)

    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
}

enum SnippetEditorMode: Hashable {
    case noSelection
    case newDraft
    case editing(SnippetID)
    case deleteConfirmation(SnippetID)

    var selectedSnippetID: SnippetID? {
        switch self {
        case .noSelection, .newDraft:
            return nil
        case let .editing(snippetID),
             let .deleteConfirmation(snippetID):
            return snippetID
        }
    }
}

struct SnippetEditorState: Hashable {
    var mode: SnippetEditorMode
    var savedRecord: SnippetRecord?
    var draft: SnippetEditorDraft
    var validationState: SnippetEditorValidationState
    var availability: HotkeyRuntimeAvailability

    init(
        mode: SnippetEditorMode = .noSelection,
        savedRecord: SnippetRecord? = nil,
        draft: SnippetEditorDraft = SnippetEditorDraft(),
        validationState: SnippetEditorValidationState = .valid,
        availability: HotkeyRuntimeAvailability = .enabled
    ) {
        self.mode = mode
        self.savedRecord = savedRecord
        self.draft = draft
        self.validationState = validationState
        self.availability = availability
    }

    var selectedSnippetID: SnippetID? {
        mode.selectedSnippetID ?? savedRecord?.id
    }

    var isDirty: Bool {
        guard let savedRecord else {
            return mode != .noSelection && draft.title.isEmpty == false || draft.content.isEmpty == false || draft.hotkey != nil || draft.isPinned
        }
        return draft != SnippetEditorDraft(
            title: savedRecord.title,
            content: savedRecord.content,
            kind: savedRecord.kind,
            hotkey: savedRecord.hotkey,
            isPinned: savedRecord.isPinned
        )
    }

    var canSave: Bool {
        availability.isInteractive && validationState.isValid && isDirty
    }

    var canDelete: Bool {
        savedRecord != nil && availability.isInteractive
    }
}

struct SnippetLibraryEntry: Identifiable, Hashable {
    var snippetID: SnippetID
    var title: String
    var subtitle: String?
    var hotkeyLabel: String
    var kind: SnippetContentKind
    var isPinned: Bool
    var isSelected: Bool

    var id: String { snippetID.rawValue }

    init(
        snippetID: SnippetID,
        title: String,
        subtitle: String? = nil,
        hotkeyLabel: String,
        kind: SnippetContentKind,
        isPinned: Bool = false,
        isSelected: Bool = false
    ) {
        self.snippetID = snippetID
        self.title = title
        self.subtitle = subtitle
        self.hotkeyLabel = hotkeyLabel
        self.kind = kind
        self.isPinned = isPinned
        self.isSelected = isSelected
    }
}

struct HotkeysSettingsState: Hashable {
    var globalBindings: [HotkeyBindingSummary]
    var snippetBindings: [HotkeyBindingSummary]
    var recorderSession: HotkeyRecorderSessionState
    var inlineMessage: String?

    init(
        globalBindings: [HotkeyBindingSummary] = [],
        snippetBindings: [HotkeyBindingSummary] = [],
        recorderSession: HotkeyRecorderSessionState = HotkeyRecorderSessionState(),
        inlineMessage: String? = nil
    ) {
        self.globalBindings = globalBindings
        self.snippetBindings = snippetBindings
        self.recorderSession = recorderSession
        self.inlineMessage = inlineMessage
    }
}

struct SnippetsSettingsState: Hashable {
    var libraryEntries: [SnippetLibraryEntry]
    var editorState: SnippetEditorState
    var canCreateSnippet: Bool
    var emptyStateTitle: String?
    var emptyStateDetailText: String?

    init(
        libraryEntries: [SnippetLibraryEntry] = [],
        editorState: SnippetEditorState = SnippetEditorState(),
        canCreateSnippet: Bool = true,
        emptyStateTitle: String? = nil,
        emptyStateDetailText: String? = nil
    ) {
        self.libraryEntries = libraryEntries
        self.editorState = editorState
        self.canCreateSnippet = canCreateSnippet
        self.emptyStateTitle = emptyStateTitle
        self.emptyStateDetailText = emptyStateDetailText
    }

    var selectedSnippetID: SnippetID? {
        editorState.selectedSnippetID
    }
}

struct HotkeyConflictCheckRequest: Hashable {
    var target: HotkeyBindingTarget
    var candidate: HotkeyDescriptor
    var globalBindings: [GlobalHotkeyBinding]
    var snippets: [SnippetRecord]

    init(
        target: HotkeyBindingTarget,
        candidate: HotkeyDescriptor,
        globalBindings: [GlobalHotkeyBinding],
        snippets: [SnippetRecord]
    ) {
        self.target = target
        self.candidate = candidate
        self.globalBindings = globalBindings
        self.snippets = snippets
    }
}

struct HotkeyConflictCheckOutcome: Hashable {
    var target: HotkeyBindingTarget
    var candidate: HotkeyDescriptor
    var conflicts: [HotkeyConflictResult]

    init(
        target: HotkeyBindingTarget,
        candidate: HotkeyDescriptor,
        conflicts: [HotkeyConflictResult] = []
    ) {
        self.target = target
        self.candidate = candidate
        self.conflicts = conflicts
    }

    var canAssign: Bool {
        conflicts.isEmpty
    }
}

struct HotkeyRegistrationRequest: Hashable {
    var target: HotkeyBindingTarget
    var descriptor: HotkeyDescriptor
    var availability: HotkeyRuntimeAvailability

    init(
        target: HotkeyBindingTarget,
        descriptor: HotkeyDescriptor,
        availability: HotkeyRuntimeAvailability = .enabled
    ) {
        self.target = target
        self.descriptor = descriptor
        self.availability = availability
    }
}

struct HotkeyRegistrationRecord: Identifiable, Hashable {
    var target: HotkeyBindingTarget
    var descriptor: HotkeyDescriptor
    var registeredAt: Date
    var availability: HotkeyRuntimeAvailability

    var id: String { target.id }

    init(
        target: HotkeyBindingTarget,
        descriptor: HotkeyDescriptor,
        registeredAt: Date = .now,
        availability: HotkeyRuntimeAvailability = .enabled
    ) {
        self.target = target
        self.descriptor = descriptor
        self.registeredAt = registeredAt
        self.availability = availability
    }
}

enum SnippetPasteTriggerSource: String, CaseIterable, Identifiable, Hashable {
    case globalHotkey
    case settingsPreview
    case debug

    var id: String { rawValue }
}

enum SnippetPasteDisposition: String, CaseIterable, Identifiable, Hashable {
    case pasted
    case blocked
    case missingSnippet

    var id: String { rawValue }
}

struct SnippetPasteExecutionRequest: Hashable {
    var snippet: SnippetRecord
    var triggerSource: SnippetPasteTriggerSource
    var invokedHotkey: HotkeyDescriptor?
    var requestedAt: Date

    init(
        snippet: SnippetRecord,
        triggerSource: SnippetPasteTriggerSource,
        invokedHotkey: HotkeyDescriptor? = nil,
        requestedAt: Date = .now
    ) {
        self.snippet = snippet
        self.triggerSource = triggerSource
        self.invokedHotkey = invokedHotkey
        self.requestedAt = requestedAt
    }
}

struct SnippetPasteExecutionResult: Hashable {
    var snippetID: SnippetID
    var disposition: SnippetPasteDisposition
    var statusMessage: String
    var pastedPreviewText: String
    var executedAt: Date

    init(
        snippetID: SnippetID,
        disposition: SnippetPasteDisposition,
        statusMessage: String,
        pastedPreviewText: String,
        executedAt: Date = .now
    ) {
        self.snippetID = snippetID
        self.disposition = disposition
        self.statusMessage = statusMessage
        self.pastedPreviewText = pastedPreviewText
        self.executedAt = executedAt
    }
}

struct SnippetsHotkeysRuntimeSnapshot: Hashable {
    var snippets: [SnippetRecord]
    var globalBindings: [GlobalHotkeyBinding]
    var registeredBindings: [HotkeyRegistrationRecord]
    var hotkeysSettingsState: HotkeysSettingsState
    var snippetsSettingsState: SnippetsSettingsState
    var runtimeAvailability: HotkeyRuntimeAvailability
    var lastUpdatedAt: Date

    init(
        snippets: [SnippetRecord] = [],
        globalBindings: [GlobalHotkeyBinding] = [],
        registeredBindings: [HotkeyRegistrationRecord] = [],
        hotkeysSettingsState: HotkeysSettingsState = HotkeysSettingsState(),
        snippetsSettingsState: SnippetsSettingsState = SnippetsSettingsState(),
        runtimeAvailability: HotkeyRuntimeAvailability = .enabled,
        lastUpdatedAt: Date = .now
    ) {
        self.snippets = snippets
        self.globalBindings = globalBindings
        self.registeredBindings = registeredBindings
        self.hotkeysSettingsState = hotkeysSettingsState
        self.snippetsSettingsState = snippetsSettingsState
        self.runtimeAvailability = runtimeAvailability
        self.lastUpdatedAt = lastUpdatedAt
    }

    var assignedSnippetCount: Int {
        snippets.filter(\.hasAssignedHotkey).count
    }
}
