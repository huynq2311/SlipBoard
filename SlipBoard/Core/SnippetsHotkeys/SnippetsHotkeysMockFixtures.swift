import Foundation

enum SnippetsHotkeysMockFixtures {
    static let baseDate = Date(timeIntervalSince1970: 1_787_290_200)

    static let openPopupHotkey = HotkeyDescriptor(
        keyCode: 9,
        keyEquivalent: "v",
        modifiers: [.command, .shift]
    )

    static let snippetReplyHotkey = HotkeyDescriptor(
        keyCode: 18,
        keyEquivalent: "1",
        modifiers: [.control, .option]
    )

    static let conflictingSnippetCandidate = HotkeyDescriptor(
        keyCode: 9,
        keyEquivalent: "v",
        modifiers: [.command, .shift]
    )

    static let popupBinding = GlobalHotkeyBinding(
        commandID: .openSlipboard,
        hotkey: openPopupHotkey,
        availability: .enabled,
        detailText: "Open the popup shell from anywhere."
    )

    static let pasteAsBinding = GlobalHotkeyBinding(
        commandID: .pasteAs,
        hotkey: nil,
        availability: .registrationUnavailable,
        detailText: "Popup-scoped only in this slice."
    )

    static let pauseBinding = GlobalHotkeyBinding(
        commandID: .pauseCapturing,
        hotkey: nil,
        availability: .futureCommandUnavailable,
        detailText: "Reserved until the pause-capturing feature lands."
    )

    static let assignedSnippet = SnippetRecord(
        id: "01J7SNIPPETREPLY000000000001",
        title: "Email reply template",
        content: "Thanks for the report. We traced the runtime dependency and isolated the failing path.",
        kind: .plainText,
        hotkey: snippetReplyHotkey,
        createdAt: baseDate.addingTimeInterval(-3_600),
        updatedAt: baseDate.addingTimeInterval(-300),
        isPinned: true
    )

    static let codeSnippet = SnippetRecord(
        id: "01J7SNIPPETHEADER00000000002",
        title: "API header",
        content: "Authorization: Bearer <token>\nX-Client: slipboard",
        kind: .code,
        hotkey: HotkeyDescriptor(
            keyCode: 19,
            keyEquivalent: "2",
            modifiers: [.control, .option]
        ),
        createdAt: baseDate.addingTimeInterval(-5_400),
        updatedAt: baseDate.addingTimeInterval(-900),
        isPinned: false
    )

    static let unassignedSnippet = SnippetRecord(
        id: "01J7SNIPPETSIGNAT00000000003",
        title: "Signature",
        content: "Best,\nSlipBoard QA",
        kind: .plainText,
        hotkey: nil,
        createdAt: baseDate.addingTimeInterval(-1_800),
        updatedAt: baseDate.addingTimeInterval(-1_200),
        isPinned: false
    )

    static let conflictResult = HotkeyConflictResult(
        target: .snippet(unassignedSnippet.id),
        candidate: conflictingSnippetCandidate,
        conflictingTarget: .globalCommand(.openSlipboard),
        kind: .duplicateGlobal,
        message: "This shortcut is already assigned to Open Slipboard.",
        severity: .error
    )

    static let recorderConflictState = HotkeyRecorderSessionState(
        target: .snippet(unassignedSnippet.id),
        phase: .conflict,
        previouslyAssignedHotkey: nil,
        candidateHotkey: conflictingSnippetCandidate,
        conflictResult: conflictResult,
        availability: .enabled
    )

    static let registeredBindings: [HotkeyRegistrationRecord] = [
        HotkeyRegistrationRecord(
            target: .globalCommand(.openSlipboard),
            descriptor: openPopupHotkey,
            registeredAt: baseDate.addingTimeInterval(-600),
            availability: .enabled
        ),
        HotkeyRegistrationRecord(
            target: .snippet(assignedSnippet.id),
            descriptor: snippetReplyHotkey,
            registeredAt: baseDate.addingTimeInterval(-480),
            availability: .enabled
        )
    ]

    static let hotkeysSettingsState = HotkeysSettingsState(
        globalBindings: [
            HotkeyBindingSummary(
                target: .globalCommand(.openSlipboard),
                title: GlobalHotkeyCommandID.openSlipboard.displayTitle,
                detailText: "Open the popup shell.",
                hotkey: openPopupHotkey,
                availability: .enabled
            ),
            HotkeyBindingSummary(
                target: .globalCommand(.pasteAs),
                title: GlobalHotkeyCommandID.pasteAs.displayTitle,
                detailText: "Open the transform menu from the popup context.",
                hotkey: nil,
                availability: .registrationUnavailable,
                isPopupScoped: true
            ),
            HotkeyBindingSummary(
                target: .globalCommand(.pauseCapturing),
                title: GlobalHotkeyCommandID.pauseCapturing.displayTitle,
                detailText: "Reserved until exclusions and pause controls are implemented.",
                hotkey: nil,
                availability: .futureCommandUnavailable
            )
        ],
        snippetBindings: [
            HotkeyBindingSummary(
                target: .snippet(assignedSnippet.id),
                title: assignedSnippet.title,
                detailText: "Paste saved customer response.",
                hotkey: assignedSnippet.hotkey,
                availability: .enabled
            ),
            HotkeyBindingSummary(
                target: .snippet(unassignedSnippet.id),
                title: unassignedSnippet.title,
                detailText: "No hotkey assigned yet.",
                hotkey: nil,
                availability: .enabled,
                latestConflict: conflictResult
            )
        ],
        recorderSession: recorderConflictState,
        inlineMessage: "Conflicts are validated when a shortcut is assigned, not when it fires."
    )

    static let snippetsSettingsState = SnippetsSettingsState(
        libraryEntries: [
            SnippetLibraryEntry(
                snippetID: assignedSnippet.id,
                title: assignedSnippet.title,
                subtitle: "Saved customer response",
                hotkeyLabel: assignedSnippet.hotkey?.displayLabel ?? "No hotkey",
                kind: assignedSnippet.kind,
                isPinned: assignedSnippet.isPinned,
                isSelected: true
            ),
            SnippetLibraryEntry(
                snippetID: codeSnippet.id,
                title: codeSnippet.title,
                subtitle: "Authorization boilerplate",
                hotkeyLabel: codeSnippet.hotkey?.displayLabel ?? "No hotkey",
                kind: codeSnippet.kind,
                isPinned: codeSnippet.isPinned,
                isSelected: false
            ),
            SnippetLibraryEntry(
                snippetID: unassignedSnippet.id,
                title: unassignedSnippet.title,
                subtitle: "No hotkey",
                hotkeyLabel: "No hotkey",
                kind: unassignedSnippet.kind,
                isPinned: unassignedSnippet.isPinned,
                isSelected: false
            )
        ],
        editorState: SnippetEditorState(
            mode: .editing(assignedSnippet.id),
            savedRecord: assignedSnippet,
            draft: SnippetEditorDraft(
                title: assignedSnippet.title,
                content: assignedSnippet.content,
                kind: assignedSnippet.kind,
                hotkey: assignedSnippet.hotkey,
                isPinned: assignedSnippet.isPinned
            ),
            validationState: .valid,
            availability: .enabled
        ),
        canCreateSnippet: true
    )

    static let runtimeSnapshot = SnippetsHotkeysRuntimeSnapshot(
        snippets: [assignedSnippet, codeSnippet, unassignedSnippet],
        globalBindings: [popupBinding, pasteAsBinding, pauseBinding],
        registeredBindings: registeredBindings,
        hotkeysSettingsState: hotkeysSettingsState,
        snippetsSettingsState: snippetsSettingsState,
        runtimeAvailability: .enabled,
        lastUpdatedAt: baseDate.addingTimeInterval(-60)
    )

    static let lockedRuntimeSnapshot = SnippetsHotkeysRuntimeSnapshot(
        snippets: [assignedSnippet, codeSnippet, unassignedSnippet],
        globalBindings: [
            GlobalHotkeyBinding(
                commandID: .openSlipboard,
                hotkey: openPopupHotkey,
                availability: .lockedDisabled,
                detailText: "App Lock currently blocks popup opening."
            ),
            pasteAsBinding,
            pauseBinding
        ],
        registeredBindings: [],
        hotkeysSettingsState: HotkeysSettingsState(
            globalBindings: [
                HotkeyBindingSummary(
                    target: .globalCommand(.openSlipboard),
                    title: GlobalHotkeyCommandID.openSlipboard.displayTitle,
                    detailText: "Disabled while SlipBoard is locked.",
                    hotkey: openPopupHotkey,
                    availability: .lockedDisabled
                )
            ],
            snippetBindings: [
                HotkeyBindingSummary(
                    target: .snippet(assignedSnippet.id),
                    title: assignedSnippet.title,
                    detailText: "Snippet paste is disabled while locked.",
                    hotkey: assignedSnippet.hotkey,
                    availability: .lockedDisabled
                )
            ],
            recorderSession: HotkeyRecorderSessionState(
                phase: .disabled,
                availability: .lockedDisabled
            ),
            inlineMessage: "Unlock SlipBoard to use snippet hotkeys."
        ),
        snippetsSettingsState: SnippetsSettingsState(
            libraryEntries: snippetsSettingsState.libraryEntries,
            editorState: SnippetEditorState(
                mode: .editing(assignedSnippet.id),
                savedRecord: assignedSnippet,
                draft: SnippetEditorDraft(
                    title: assignedSnippet.title,
                    content: assignedSnippet.content,
                    kind: assignedSnippet.kind,
                    hotkey: assignedSnippet.hotkey,
                    isPinned: assignedSnippet.isPinned
                ),
                validationState: .valid,
                availability: .lockedDisabled
            ),
            canCreateSnippet: false,
            emptyStateTitle: nil,
            emptyStateDetailText: nil
        ),
        runtimeAvailability: .lockedDisabled,
        lastUpdatedAt: baseDate
    )
}
