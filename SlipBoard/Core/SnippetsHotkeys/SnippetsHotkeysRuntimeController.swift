import Foundation

final class SnippetsHotkeysRuntimeController: SnippetsHotkeysRuntimeProviding {
    private let store: SnippetStoring
    private let registrar: HotkeyRegistering
    private let conflictResolver: HotkeyConflictChecking
    private let pasteExecutor: SnippetPasteExecuting
    private let router: PopupShellRouting?
    private let securityStateProvider: SecurityStatePublishing?
    private let now: () -> Date

    private var requestedRuntimeAvailability: HotkeyRuntimeAvailability
    private var selectedSnippetID: SnippetID?
    private var editorState: SnippetEditorState
    private var recorderSession: HotkeyRecorderSessionState
    private var latestConflictsByTargetID: [String: HotkeyConflictResult]
    private var systemUnavailableTargets: Set<String>
    private var registrationsSuspendedForRecorder: Bool
    private var inlineMessage: String?

    private(set) var latestSnapshot: SnippetsHotkeysRuntimeSnapshot
    var onSnapshotChange: ((SnippetsHotkeysRuntimeSnapshot) -> Void)?

    init(
        store: SnippetStoring = CoreDataSnippetsStore(),
        registrar: HotkeyRegistering = GlobalHotkeyRegistrar(),
        conflictResolver: HotkeyConflictChecking = HotkeyConflictResolver(),
        pasteExecutor: SnippetPasteExecuting = SnippetPasteExecutor(),
        router: PopupShellRouting? = nil,
        securityStateProvider: SecurityStatePublishing? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.registrar = registrar
        self.conflictResolver = conflictResolver
        self.pasteExecutor = pasteExecutor
        self.router = router
        self.securityStateProvider = securityStateProvider
        self.now = now
        self.requestedRuntimeAvailability = .enabled
        self.selectedSnippetID = store.snippets.first?.id
        self.editorState = SnippetEditorState()
        self.recorderSession = HotkeyRecorderSessionState()
        self.latestConflictsByTargetID = [:]
        self.systemUnavailableTargets = []
        self.registrationsSuspendedForRecorder = false
        self.inlineMessage = nil
        self.latestSnapshot = SnippetsHotkeysRuntimeSnapshot()

        registrar.onBindingTriggered = { [weak self] target, descriptor in
            self?.handleRegisteredBindingTrigger(target, descriptor: descriptor)
        }

        ensureDefaultGlobalBindings()
        editorState = makeEditorState(for: selectedSnippetID)
        synchronizeRegistrationState()
        latestSnapshot = makeSnapshot()
    }

    func selectSnippet(id: SnippetID?) {
        selectedSnippetID = id
        editorState = makeEditorState(for: id)
        publishSnapshot()
    }

    func createSnippetDraft() {
        selectedSnippetID = nil
        editorState = SnippetEditorState(
            mode: .newDraft,
            savedRecord: nil,
            draft: SnippetEditorDraft(),
            validationState: .missingTitle,
            availability: effectiveRuntimeAvailability()
        )
        inlineMessage = defaultInlineMessage(for: effectiveRuntimeAvailability())
        publishSnapshot()
    }

    func discardActiveDraft() {
        if let selectedSnippetID {
            editorState = makeEditorState(for: selectedSnippetID)
        } else if store.snippets.isEmpty {
            editorState = SnippetEditorState(
                mode: .noSelection,
                savedRecord: nil,
                draft: SnippetEditorDraft(),
                validationState: .valid,
                availability: effectiveRuntimeAvailability()
            )
        } else {
            selectedSnippetID = store.snippets.first?.id
            editorState = makeEditorState(for: selectedSnippetID)
        }

        inlineMessage = defaultInlineMessage(for: effectiveRuntimeAvailability())
        publishSnapshot()
    }

    func updateEditorDraft(_ draft: SnippetEditorDraft) {
        editorState.draft = draft
        editorState.validationState = validateDraft(
            draft,
            target: editorTarget(),
            snippets: store.snippets,
            globalBindings: store.globalBindings
        )
        publishSnapshot()
    }

    @discardableResult
    func saveActiveDraft() -> SnippetRecord? {
        let availability = effectiveRuntimeAvailability()
        guard availability.isInteractive else {
            inlineMessage = "Unlock SlipBoard to edit snippets or hotkeys."
            publishSnapshot()
            return nil
        }

        let draft = editorState.draft
        let validationState = validateDraft(
            draft,
            target: editorTarget(),
            snippets: store.snippets,
            globalBindings: store.globalBindings
        )
        editorState.validationState = validationState

        guard validationState.isValid else {
            inlineMessage = validationMessage(for: validationState)
            publishSnapshot()
            return nil
        }

        let timestamp = now()
        let savedRecord: SnippetRecord

        switch editorState.mode {
        case let .editing(existingID), let .deleteConfirmation(existingID):
            guard let existingRecord = store.snippet(id: existingID) else {
                inlineMessage = "The selected snippet no longer exists."
                publishSnapshot()
                return nil
            }

            savedRecord = SnippetRecord(
                id: existingRecord.id,
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: draft.content,
                kind: draft.kind,
                hotkey: draft.hotkey,
                createdAt: existingRecord.createdAt,
                updatedAt: timestamp,
                isPinned: draft.isPinned
            )
        case .newDraft, .noSelection:
            savedRecord = SnippetRecord(
                id: makeSnippetID(),
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: draft.content,
                kind: draft.kind,
                hotkey: draft.hotkey,
                createdAt: timestamp,
                updatedAt: timestamp,
                isPinned: draft.isPinned
            )
        }

        _ = store.saveSnippet(savedRecord)
        selectedSnippetID = savedRecord.id
        latestConflictsByTargetID.removeValue(forKey: HotkeyBindingTarget.snippet(savedRecord.id).id)
        synchronizeRegistrationState()
        editorState = makeEditorState(for: selectedSnippetID)
        inlineMessage = "Snippet changes saved locally on this device."
        publishSnapshot()
        return savedRecord
    }

    @discardableResult
    func deleteSelectedSnippet() -> SnippetRecord? {
        let snippetID = selectedSnippetID ?? editorState.selectedSnippetID
        guard let snippetID else {
            return nil
        }

        let deletedRecord = store.deleteSnippet(id: snippetID)
        _ = registrar.unregisterBinding(for: .snippet(snippetID))
        latestConflictsByTargetID.removeValue(forKey: HotkeyBindingTarget.snippet(snippetID).id)

        let remainingSnippets = store.snippets
        selectedSnippetID = nextSelectedSnippetID(
            afterDeleting: snippetID,
            from: remainingSnippets
        )
        editorState = makeEditorState(for: selectedSnippetID)
        synchronizeRegistrationState()
        inlineMessage = deletedRecord == nil ? nil : "Snippet deleted from local storage."
        publishSnapshot()
        return deletedRecord
    }

    func beginRecorderSession(for target: HotkeyBindingTarget) {
        let availability = effectiveAvailability(for: target)
        if availability.isInteractive {
            suspendRegistrationsForRecorderIfNeeded()
        }

        recorderSession = HotkeyRecorderSessionState(
            target: target,
            phase: availability.isInteractive ? .recording : .disabled,
            previouslyAssignedHotkey: assignedHotkey(for: target),
            candidateHotkey: nil,
            conflictResult: nil,
            availability: availability
        )

        if availability.isInteractive == false {
            inlineMessage = detailText(for: target, availability: availability)
        }

        publishSnapshot()
    }

    func cancelRecorderSession() {
        recorderSession = HotkeyRecorderSessionState(
            phase: .idle,
            availability: effectiveRuntimeAvailability()
        )
        synchronizeRecorderExitRegistrationState()
        publishSnapshot()
    }

    @discardableResult
    func commitRecorderCandidate(_ descriptor: HotkeyDescriptor) -> HotkeyRecorderSessionState {
        guard let target = recorderSession.target else {
            return recorderSession
        }

        let availability = effectiveAvailability(for: target)
        guard availability.isInteractive else {
            synchronizeRecorderExitRegistrationState()
            recorderSession = HotkeyRecorderSessionState(
                target: target,
                phase: .disabled,
                previouslyAssignedHotkey: assignedHotkey(for: target),
                candidateHotkey: descriptor,
                conflictResult: nil,
                availability: effectiveAvailability(for: target)
            )
            inlineMessage = detailText(for: target, availability: availability)
            publishSnapshot()
            return recorderSession
        }

        let outcome = conflictResolver.evaluateConflict(
            HotkeyConflictCheckRequest(
                target: target,
                candidate: descriptor,
                globalBindings: store.globalBindings,
                snippets: currentSnippetsForConflictChecks(target: target)
            )
        )

        guard outcome.canAssign else {
            let conflict = outcome.conflicts[0]
            latestConflictsByTargetID[target.id] = conflict
            synchronizeRecorderExitRegistrationState()
            recorderSession = HotkeyRecorderSessionState(
                target: target,
                phase: .conflict,
                previouslyAssignedHotkey: assignedHotkey(for: target),
                candidateHotkey: descriptor,
                conflictResult: conflict,
                availability: effectiveAvailability(for: target)
            )
            if case .snippet = target, target == editorTarget() {
                editorState.validationState = .hotkeyConflict(conflict)
            }
            inlineMessage = conflict.message
            publishSnapshot()
            return recorderSession
        }

        apply(descriptor, to: target)
        latestConflictsByTargetID.removeValue(forKey: target.id)
        synchronizeRecorderExitRegistrationState()

        recorderSession = HotkeyRecorderSessionState(
            target: target,
            phase: .saved,
            previouslyAssignedHotkey: assignedHotkey(for: target),
            candidateHotkey: descriptor,
            conflictResult: nil,
            availability: effectiveAvailability(for: target)
        )

        if case .snippet = target, target == editorTarget() {
            editorState.validationState = validateDraft(
                editorState.draft,
                target: target,
                snippets: store.snippets,
                globalBindings: store.globalBindings
            )
        }

        inlineMessage = "Shortcut saved without conflicts."
        publishSnapshot()
        return recorderSession
    }

    func clearBinding(for target: HotkeyBindingTarget) {
        switch target {
        case let .globalCommand(commandID):
            guard let existingBinding = store.globalBindings.first(where: { $0.commandID == commandID }) else {
                return
            }

            _ = store.saveGlobalBinding(
                GlobalHotkeyBinding(
                    commandID: existingBinding.commandID,
                    hotkey: nil,
                    availability: existingBinding.availability,
                    detailText: existingBinding.detailText
                )
            )
        case let .snippet(snippetID):
            guard let existingSnippet = store.snippet(id: snippetID) else {
                return
            }

            _ = store.saveSnippet(
                SnippetRecord(
                    id: existingSnippet.id,
                    title: existingSnippet.title,
                    content: existingSnippet.content,
                    kind: existingSnippet.kind,
                    hotkey: nil,
                    createdAt: existingSnippet.createdAt,
                    updatedAt: now(),
                    isPinned: existingSnippet.isPinned
                )
            )

            if selectedSnippetID == snippetID {
                editorState = makeEditorState(for: selectedSnippetID)
            }
        case .reservedFutureCommand:
            break
        }

        latestConflictsByTargetID.removeValue(forKey: target.id)
        _ = registrar.unregisterBinding(for: target)
        synchronizeRegistrationState()
        inlineMessage = "Shortcut cleared."
        publishSnapshot()
    }

    func refreshRuntimeAvailability(_ availability: HotkeyRuntimeAvailability) {
        requestedRuntimeAvailability = availability
        let effectiveAvailability = effectiveRuntimeAvailability()
        if effectiveAvailability.isInteractive == false {
            let activeRecorderTarget = recorderSession.target
            let wasRecordingInteractively = registrationsSuspendedForRecorder || recorderSession.phase == .recording
            if wasRecordingInteractively, let activeRecorderTarget {
                synchronizeRecorderExitRegistrationState()
                recorderSession = HotkeyRecorderSessionState(
                    target: activeRecorderTarget,
                    phase: .disabled,
                    previouslyAssignedHotkey: assignedHotkey(for: activeRecorderTarget),
                    candidateHotkey: recorderSession.candidateHotkey,
                    conflictResult: recorderSession.conflictResult,
                    availability: effectiveAvailability
                )
                inlineMessage = detailText(for: activeRecorderTarget, availability: effectiveAvailability)
            } else {
                recorderSession = HotkeyRecorderSessionState(
                    phase: .disabled,
                    availability: effectiveAvailability
                )
            }
        }

        if registrationsSuspendedForRecorder == false {
            synchronizeRegistrationState()
        }

        if effectiveAvailability.isInteractive == false, registrationsSuspendedForRecorder == false, recorderSession.target == nil {
            recorderSession = HotkeyRecorderSessionState(
                phase: .disabled,
                availability: effectiveAvailability
            )
        }
        editorState.availability = effectiveAvailability
        if effectiveAvailability.isInteractive {
            inlineMessage = defaultInlineMessage(for: effectiveAvailability)
        }
        publishSnapshot()
    }

    func handleRegisteredBindingTrigger(
        _ target: HotkeyBindingTarget,
        descriptor: HotkeyDescriptor?
    ) {
        guard effectiveRuntimeAvailability().isInteractive else {
            inlineMessage = "Unlock SlipBoard to use snippet hotkeys."
            publishSnapshot()
            return
        }

        switch target {
        case let .globalCommand(commandID):
            handleGlobalCommand(commandID)
            publishSnapshot()
        case let .snippet(snippetID):
            guard let snippet = store.snippet(id: snippetID) else {
                inlineMessage = "The selected snippet could not be found."
                publishSnapshot()
                return
            }

            let result = pasteExecutor.executeSnippetPaste(
                SnippetPasteExecutionRequest(
                    snippet: snippet,
                    triggerSource: .globalHotkey,
                    invokedHotkey: descriptor,
                    requestedAt: now()
                )
            )
            inlineMessage = result.statusMessage
            publishSnapshot()
        case .reservedFutureCommand:
            inlineMessage = "This command is reserved for a future feature."
            publishSnapshot()
        }
    }

    private func handleGlobalCommand(_ commandID: GlobalHotkeyCommandID) {
        switch commandID {
        case .openSlipboard:
            router?.handleGlobalHotkeyCommand(commandID)
            inlineMessage = "Popup hotkey is ready."
        case .pasteAs:
            inlineMessage = "Paste As... remains popup-scoped in this slice."
        case .pauseCapturing:
            inlineMessage = FoundationShellRuntimeHooks
                .togglePauseCapture(at: now())
                .statusMessage
        }
    }

    private func ensureDefaultGlobalBindings() {
        let existingBindings = Dictionary(
            uniqueKeysWithValues: store.globalBindings.map { ($0.commandID, $0) }
        )

        let mergedBindings = defaultGlobalBindings().map { fallback in
            guard let existingBinding = existingBindings[fallback.commandID] else {
                return fallback
            }

            switch fallback.commandID {
            case .openSlipboard:
                return GlobalHotkeyBinding(
                    commandID: .openSlipboard,
                    hotkey: existingBinding.hotkey ?? fallback.hotkey,
                    availability: .enabled,
                    detailText: existingBinding.detailText ?? fallback.detailText
                )
            case .pasteAs:
                return GlobalHotkeyBinding(
                    commandID: .pasteAs,
                    hotkey: existingBinding.hotkey,
                    availability: fallback.availability,
                    detailText: existingBinding.detailText ?? fallback.detailText
                )
            case .pauseCapturing:
                return GlobalHotkeyBinding(
                    commandID: .pauseCapturing,
                    hotkey: existingBinding.hotkey ?? fallback.hotkey,
                    availability: .enabled,
                    detailText: fallback.detailText
                )
            }
        }

        if mergedBindings != store.globalBindings {
            _ = store.replaceGlobalBindings(mergedBindings)
        }
    }

    private func synchronizeRegistrationState() {
        latestConflictsByTargetID = latestConflictsByTargetID.filter { key, _ in
            key.hasPrefix("global:") || store.snippets.contains(where: { HotkeyBindingTarget.snippet($0.id).id == key })
        }

        if registrationsSuspendedForRecorder {
            _ = registrar.clearRegisteredBindings()
            return
        }

        if effectiveRuntimeAvailability().isInteractive == false {
            systemUnavailableTargets.removeAll()
            _ = registrar.clearRegisteredBindings()
            return
        }

        _ = registrar.clearRegisteredBindings()
        systemUnavailableTargets.removeAll()

        let requests = registrationRequests()
        for request in requests {
            if registrar.registerBinding(request) == nil {
                systemUnavailableTargets.insert(request.target.id)
            }
        }
    }

    private func suspendRegistrationsForRecorderIfNeeded() {
        guard registrationsSuspendedForRecorder == false else {
            return
        }

        registrationsSuspendedForRecorder = true
        _ = registrar.clearRegisteredBindings()
    }

    private func synchronizeRecorderExitRegistrationState() {
        registrationsSuspendedForRecorder = false
        synchronizeRegistrationState()
    }

    private func registrationRequests() -> [HotkeyRegistrationRequest] {
        var requests: [HotkeyRegistrationRequest] = []
        var reservedIdentities: [String: HotkeyBindingTarget] = [:]

        for binding in store.globalBindings where binding.availability == .enabled {
            guard let hotkey = binding.hotkey else { continue }
            let target = HotkeyBindingTarget.globalCommand(binding.commandID)

            if let conflictingTarget = reservedIdentities[hotkey.normalizedIdentity] {
                latestConflictsByTargetID[target.id] = HotkeyConflictResult(
                    target: target,
                    candidate: hotkey,
                    conflictingTarget: conflictingTarget,
                    kind: .duplicateGlobal,
                    message: conflictMessage(for: conflictingTarget)
                )
                continue
            }

            reservedIdentities[hotkey.normalizedIdentity] = target
            requests.append(
                HotkeyRegistrationRequest(
                    target: target,
                    descriptor: hotkey,
                    availability: .enabled
                )
            )
        }

        for snippet in store.snippets {
            guard let hotkey = snippet.hotkey else { continue }
            let target = HotkeyBindingTarget.snippet(snippet.id)

            if let conflictingTarget = reservedIdentities[hotkey.normalizedIdentity] {
                latestConflictsByTargetID[target.id] = HotkeyConflictResult(
                    target: target,
                    candidate: hotkey,
                    conflictingTarget: conflictingTarget,
                    kind: conflictingTarget.id.hasPrefix("global:") ? .duplicateGlobal : .duplicateSnippet,
                    message: conflictMessage(for: conflictingTarget)
                )
                continue
            }

            reservedIdentities[hotkey.normalizedIdentity] = target
            requests.append(
                HotkeyRegistrationRequest(
                    target: target,
                    descriptor: hotkey,
                    availability: .enabled
                )
            )
        }

        return requests
    }

    private func apply(_ descriptor: HotkeyDescriptor, to target: HotkeyBindingTarget) {
        switch target {
        case let .globalCommand(commandID):
            if let existingBinding = store.globalBindings.first(where: { $0.commandID == commandID }) {
                _ = store.saveGlobalBinding(
                    GlobalHotkeyBinding(
                        commandID: commandID,
                        hotkey: descriptor,
                        availability: existingBinding.availability,
                        detailText: existingBinding.detailText
                    )
                )
            }
        case let .snippet(snippetID):
            guard let existingSnippet = store.snippet(id: snippetID) else {
                return
            }

            let updatedSnippet = SnippetRecord(
                id: existingSnippet.id,
                title: existingSnippet.title,
                content: existingSnippet.content,
                kind: existingSnippet.kind,
                hotkey: descriptor,
                createdAt: existingSnippet.createdAt,
                updatedAt: now(),
                isPinned: existingSnippet.isPinned
            )
            _ = store.saveSnippet(updatedSnippet)

            if selectedSnippetID == snippetID {
                editorState = makeEditorState(for: selectedSnippetID)
            }
        case .reservedFutureCommand:
            break
        }
    }

    private func currentSnippetsForConflictChecks(target: HotkeyBindingTarget) -> [SnippetRecord] {
        store.snippets.map { snippet in
            guard target == .snippet(snippet.id), selectedSnippetID == snippet.id else {
                return snippet
            }

            return SnippetRecord(
                id: snippet.id,
                title: editorState.draft.title.isEmpty ? snippet.title : editorState.draft.title,
                content: editorState.draft.content.isEmpty ? snippet.content : editorState.draft.content,
                kind: editorState.draft.kind,
                hotkey: snippet.hotkey,
                createdAt: snippet.createdAt,
                updatedAt: snippet.updatedAt,
                isPinned: editorState.draft.isPinned
            )
        }
    }

    private func validateDraft(
        _ draft: SnippetEditorDraft,
        target: HotkeyBindingTarget?,
        snippets: [SnippetRecord],
        globalBindings: [GlobalHotkeyBinding]
    ) -> SnippetEditorValidationState {
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .missingTitle
        }

        if draft.content.isEmpty {
            return .missingContent
        }

        guard let hotkey = draft.hotkey, let target else {
            return .valid
        }

        let outcome = conflictResolver.evaluateConflict(
            HotkeyConflictCheckRequest(
                target: target,
                candidate: hotkey,
                globalBindings: globalBindings,
                snippets: snippets
            )
        )

        if let conflict = outcome.conflicts.first {
            return .hotkeyConflict(conflict)
        }

        return .valid
    }

    private func makeEditorState(for snippetID: SnippetID?) -> SnippetEditorState {
        let availability = effectiveRuntimeAvailability()

        guard let snippetID, let snippet = store.snippet(id: snippetID) else {
            return SnippetEditorState(
                mode: .noSelection,
                savedRecord: nil,
                draft: SnippetEditorDraft(),
                validationState: store.snippets.isEmpty ? .valid : .missingTitle,
                availability: availability
            )
        }

        let draft = SnippetEditorDraft(
            title: snippet.title,
            content: snippet.content,
            kind: snippet.kind,
            hotkey: snippet.hotkey,
            isPinned: snippet.isPinned
        )

        return SnippetEditorState(
            mode: .editing(snippetID),
            savedRecord: snippet,
            draft: draft,
            validationState: validateDraft(
                draft,
                target: .snippet(snippetID),
                snippets: store.snippets,
                globalBindings: store.globalBindings
            ),
            availability: availability
        )
    }

    private func makeSnapshot() -> SnippetsHotkeysRuntimeSnapshot {
        let availability = effectiveRuntimeAvailability()
        let hotkeysState = HotkeysSettingsState(
            globalBindings: globalBindingSummaries(for: availability),
            snippetBindings: snippetBindingSummaries(for: availability),
            recorderSession: recorderSession,
            inlineMessage: inlineMessage ?? defaultInlineMessage(for: availability)
        )

        let snippetsState = SnippetsSettingsState(
            libraryEntries: makeLibraryEntries(),
            editorState: editorState,
            canCreateSnippet: availability.isInteractive,
            emptyStateTitle: store.snippets.isEmpty ? "No snippets yet" : nil,
            emptyStateDetailText: store.snippets.isEmpty
                ? "Create your first saved snippet to keep reusable text local to this Mac."
                : nil
        )

        return SnippetsHotkeysRuntimeSnapshot(
            snippets: store.snippets,
            globalBindings: store.globalBindings,
            registeredBindings: registrar.registeredBindings,
            hotkeysSettingsState: hotkeysState,
            snippetsSettingsState: snippetsState,
            runtimeAvailability: availability,
            lastUpdatedAt: now()
        )
    }

    private func makeLibraryEntries() -> [SnippetLibraryEntry] {
        store.snippets.map { snippet in
            SnippetLibraryEntry(
                snippetID: snippet.id,
                title: snippet.title,
                subtitle: snippet.content
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmpty,
                hotkeyLabel: snippet.hotkey?.displayLabel ?? "No hotkey",
                kind: snippet.kind,
                isPinned: snippet.isPinned,
                isSelected: selectedSnippetID == snippet.id
            )
        }
    }

    private func globalBindingSummaries(
        for runtimeAvailability: HotkeyRuntimeAvailability
    ) -> [HotkeyBindingSummary] {
        store.globalBindings.map { binding in
            let target = HotkeyBindingTarget.globalCommand(binding.commandID)
            return HotkeyBindingSummary(
                target: target,
                title: binding.commandID.displayTitle,
                detailText: detailText(for: target, availability: effectiveAvailability(for: target)),
                hotkey: binding.hotkey,
                availability: effectiveAvailability(for: target),
                isPopupScoped: binding.commandID.isBackgroundGlobalCommand == false,
                latestConflict: latestConflictsByTargetID[target.id]
            )
        }
    }

    private func snippetBindingSummaries(
        for runtimeAvailability: HotkeyRuntimeAvailability
    ) -> [HotkeyBindingSummary] {
        store.snippets.map { snippet in
            let target = HotkeyBindingTarget.snippet(snippet.id)
            return HotkeyBindingSummary(
                target: target,
                title: snippet.title,
                detailText: detailText(for: target, availability: effectiveAvailability(for: target)),
                hotkey: snippet.hotkey,
                availability: effectiveAvailability(for: target),
                isPopupScoped: false,
                latestConflict: latestConflictsByTargetID[target.id]
            )
        }
    }

    private func effectiveAvailability(for target: HotkeyBindingTarget) -> HotkeyRuntimeAvailability {
        let runtimeAvailability = effectiveRuntimeAvailability()
        if runtimeAvailability != .enabled {
            return runtimeAvailability
        }

        if systemUnavailableTargets.contains(target.id) {
            return .registrationUnavailable
        }

        switch target {
        case let .globalCommand(commandID):
            return store.globalBindings.first(where: { $0.commandID == commandID })?.availability ?? .enabled
        case .snippet:
            return .enabled
        case .reservedFutureCommand:
            return .futureCommandUnavailable
        }
    }

    private func effectiveRuntimeAvailability() -> HotkeyRuntimeAvailability {
        if securityStateProvider?.isProtectedContentAvailable == false {
            return .lockedDisabled
        }

        return requestedRuntimeAvailability
    }

    private func defaultInlineMessage(for availability: HotkeyRuntimeAvailability) -> String {
        switch availability {
        case .enabled:
            return "Conflicts are validated when a shortcut is assigned, not when it fires."
        case .lockedDisabled:
            return "Unlock SlipBoard to use snippet hotkeys."
        case .futureCommandUnavailable:
            return "This command is reserved for a future feature."
        case .registrationUnavailable:
            return "Some rows remain unavailable until their owning feature or runtime scope is ready."
        }
    }

    private func detailText(
        for target: HotkeyBindingTarget,
        availability: HotkeyRuntimeAvailability
    ) -> String {
        switch target {
        case let .globalCommand(commandID):
            switch availability {
            case .enabled:
                return store.globalBindings.first(where: { $0.commandID == commandID })?.detailText
                    ?? commandID.displayTitle
            case .lockedDisabled:
                return "Disabled while SlipBoard is locked."
            case .futureCommandUnavailable:
                return "Reserved until the pause and exclusions feature lands."
            case .registrationUnavailable:
                return commandID == .pasteAs
                    ? "Popup-scoped only in this slice."
                    : "This shortcut could not be registered with the current system event tap."
            }
        case let .snippet(snippetID):
            switch availability {
            case .enabled:
                return store.snippet(id: snippetID)?.hotkey == nil
                    ? "No hotkey assigned yet."
                    : "Pastes this snippet directly through the shared paste path."
            case .lockedDisabled:
                return "Snippet paste is disabled while SlipBoard is locked."
            case .futureCommandUnavailable:
                return "Reserved for a future feature."
            case .registrationUnavailable:
                return "SlipBoard could not register this snippet hotkey with the current system state."
            }
        case .reservedFutureCommand:
            return "Reserved for a future feature."
        }
    }

    private func validationMessage(for state: SnippetEditorValidationState) -> String {
        switch state {
        case .valid:
            return defaultInlineMessage(for: effectiveRuntimeAvailability())
        case .missingTitle:
            return "Add a title before saving this snippet."
        case .missingContent:
            return "Add snippet content before saving."
        case let .hotkeyConflict(conflict):
            return conflict.message
        }
    }

    private func assignedHotkey(for target: HotkeyBindingTarget) -> HotkeyDescriptor? {
        switch target {
        case let .globalCommand(commandID):
            return store.globalBindings.first(where: { $0.commandID == commandID })?.hotkey
        case let .snippet(snippetID):
            if target == editorTarget() {
                return editorState.draft.hotkey
            }
            return store.snippet(id: snippetID)?.hotkey
        case .reservedFutureCommand:
            return nil
        }
    }

    private func editorTarget() -> HotkeyBindingTarget? {
        if let snippetID = selectedSnippetID {
            return .snippet(snippetID)
        }

        return nil
    }

    private func nextSelectedSnippetID(
        afterDeleting deletedID: SnippetID,
        from snippets: [SnippetRecord]
    ) -> SnippetID? {
        guard snippets.isEmpty == false else {
            return nil
        }

        if let sameIndexSnippet = snippets.first(where: { $0.id != deletedID }) {
            return sameIndexSnippet.id
        }

        return snippets.first?.id
    }

    private func makeSnippetID() -> SnippetID {
        SnippetID(rawValue: UUID().uuidString.lowercased())
    }

    private func defaultGlobalBindings() -> [GlobalHotkeyBinding] {
        [
            GlobalHotkeyBinding(
                commandID: .openSlipboard,
                hotkey: HotkeyDescriptor(
                    keyCode: 9,
                    keyEquivalent: "v",
                    modifiers: [.command, .shift]
                ),
                availability: .enabled,
                detailText: "Open the popup shell from anywhere."
            ),
            GlobalHotkeyBinding(
                commandID: .pasteAs,
                hotkey: nil,
                availability: .registrationUnavailable,
                detailText: "Popup-scoped only in this slice."
            ),
            GlobalHotkeyBinding(
                commandID: .pauseCapturing,
                hotkey: HotkeyDescriptor(
                    keyCode: 35,
                    keyEquivalent: "p",
                    modifiers: [.command, .shift]
                ),
                availability: .enabled,
                detailText: "Toggle manual capture pause on this Mac."
            )
        ]
    }

    private func conflictMessage(for target: HotkeyBindingTarget) -> String {
        switch target {
        case let .globalCommand(commandID):
            return "This shortcut is already assigned to \(commandID.displayTitle)."
        case let .snippet(snippetID):
            let title = store.snippet(id: snippetID)?.title ?? "another snippet"
            return "This shortcut is already assigned to the snippet \"\(title)\"."
        case .reservedFutureCommand:
            return "This shortcut is reserved for a future command."
        }
    }

    private func publishSnapshot() {
        latestSnapshot = makeSnapshot()
        onSnapshotChange?(latestSnapshot)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
