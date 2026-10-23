import Foundation

protocol SnippetStoring: AnyObject {
    var snippets: [SnippetRecord] { get }
    var globalBindings: [GlobalHotkeyBinding] { get }

    func snippet(id: SnippetID) -> SnippetRecord?

    @discardableResult
    func replaceSnippets(_ snippets: [SnippetRecord]) -> [SnippetRecord]

    @discardableResult
    func saveSnippet(_ snippet: SnippetRecord) -> SnippetRecord

    @discardableResult
    func deleteSnippet(id: SnippetID) -> SnippetRecord?

    @discardableResult
    func replaceGlobalBindings(_ bindings: [GlobalHotkeyBinding]) -> [GlobalHotkeyBinding]

    @discardableResult
    func saveGlobalBinding(_ binding: GlobalHotkeyBinding) -> GlobalHotkeyBinding
}

protocol HotkeyRegistering: AnyObject {
    var registeredBindings: [HotkeyRegistrationRecord] { get }
    var onBindingTriggered: ((HotkeyBindingTarget, HotkeyDescriptor) -> Void)? { get set }

    @discardableResult
    func registerBinding(_ request: HotkeyRegistrationRequest) -> HotkeyRegistrationRecord?

    @discardableResult
    func registerBindings(_ requests: [HotkeyRegistrationRequest]) -> [HotkeyRegistrationRecord]

    @discardableResult
    func unregisterBinding(for target: HotkeyBindingTarget) -> HotkeyRegistrationRecord?

    @discardableResult
    func clearRegisteredBindings() -> Int
}

protocol HotkeyConflictChecking {
    func evaluateConflict(_ request: HotkeyConflictCheckRequest) -> HotkeyConflictCheckOutcome
}

protocol SnippetPasteExecuting: AnyObject {
    func executeSnippetPaste(_ request: SnippetPasteExecutionRequest) -> SnippetPasteExecutionResult
}

protocol SnippetsHotkeysRuntimeProviding: AnyObject {
    var latestSnapshot: SnippetsHotkeysRuntimeSnapshot { get }
    var onSnapshotChange: ((SnippetsHotkeysRuntimeSnapshot) -> Void)? { get set }

    func selectSnippet(id: SnippetID?)
    func createSnippetDraft()
    func discardActiveDraft()
    func updateEditorDraft(_ draft: SnippetEditorDraft)

    @discardableResult
    func saveActiveDraft() -> SnippetRecord?

    @discardableResult
    func deleteSelectedSnippet() -> SnippetRecord?

    func beginRecorderSession(for target: HotkeyBindingTarget)
    func cancelRecorderSession()

    @discardableResult
    func commitRecorderCandidate(_ descriptor: HotkeyDescriptor) -> HotkeyRecorderSessionState

    func clearBinding(for target: HotkeyBindingTarget)
    func refreshRuntimeAvailability(_ availability: HotkeyRuntimeAvailability)
}
