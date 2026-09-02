import Foundation

struct HotkeyConflictResolver: HotkeyConflictChecking {
    func evaluateConflict(_ request: HotkeyConflictCheckRequest) -> HotkeyConflictCheckOutcome {
        var conflicts: [HotkeyConflictResult] = []

        if let reservedConflict = reservedConflictIfNeeded(for: request) {
            conflicts.append(reservedConflict)
        }

        conflicts.append(contentsOf: globalConflicts(for: request))
        conflicts.append(contentsOf: snippetConflicts(for: request))

        return HotkeyConflictCheckOutcome(
            target: request.target,
            candidate: request.candidate,
            conflicts: uniqueConflicts(conflicts)
        )
    }

    private func reservedConflictIfNeeded(
        for request: HotkeyConflictCheckRequest
    ) -> HotkeyConflictResult? {
        switch request.target {
        case .reservedFutureCommand:
            return HotkeyConflictResult(
                target: request.target,
                candidate: request.candidate,
                conflictingTarget: request.target,
                kind: .reservedUnavailableCommand,
                message: "This command is reserved for a future feature and cannot accept a global shortcut yet."
            )
        case let .globalCommand(commandID):
            guard
                let binding = request.globalBindings.first(where: { $0.commandID == commandID }),
                binding.availability != .enabled
            else {
                return nil
            }

            return HotkeyConflictResult(
                target: request.target,
                candidate: request.candidate,
                conflictingTarget: request.target,
                kind: .reservedUnavailableCommand,
                message: unavailableCommandMessage(for: binding)
            )
        case .snippet:
            return nil
        }
    }

    private func globalConflicts(
        for request: HotkeyConflictCheckRequest
    ) -> [HotkeyConflictResult] {
        request.globalBindings.compactMap { binding in
            guard
                let hotkey = binding.hotkey,
                hotkey.normalizedIdentity == request.candidate.normalizedIdentity,
                request.target != .globalCommand(binding.commandID)
            else {
                return nil
            }

            return HotkeyConflictResult(
                target: request.target,
                candidate: request.candidate,
                conflictingTarget: .globalCommand(binding.commandID),
                kind: .duplicateGlobal,
                message: "This shortcut is already assigned to \(binding.commandID.displayTitle)."
            )
        }
    }

    private func snippetConflicts(
        for request: HotkeyConflictCheckRequest
    ) -> [HotkeyConflictResult] {
        request.snippets.compactMap { snippet in
            guard
                let hotkey = snippet.hotkey,
                hotkey.normalizedIdentity == request.candidate.normalizedIdentity,
                request.target != .snippet(snippet.id)
            else {
                return nil
            }

            return HotkeyConflictResult(
                target: request.target,
                candidate: request.candidate,
                conflictingTarget: .snippet(snippet.id),
                kind: .duplicateSnippet,
                message: "This shortcut is already assigned to the snippet \"\(snippet.title)\"."
            )
        }
    }

    private func uniqueConflicts(
        _ conflicts: [HotkeyConflictResult]
    ) -> [HotkeyConflictResult] {
        var seen: Set<String> = []

        return conflicts.filter { conflict in
            seen.insert(conflict.id).inserted
        }
    }

    private func unavailableCommandMessage(for binding: GlobalHotkeyBinding) -> String {
        if let detailText = binding.detailText, detailText.isEmpty == false {
            return detailText
        }

        switch binding.commandID {
        case .pasteAs:
            return "Paste As... remains popup-scoped in this slice and cannot be registered as a background hotkey."
        case .pauseCapturing:
            return "Pause Capturing is reserved until the pause and exclusions feature lands."
        case .openSlipboard:
            return "This command is temporarily unavailable."
        }
    }
}
