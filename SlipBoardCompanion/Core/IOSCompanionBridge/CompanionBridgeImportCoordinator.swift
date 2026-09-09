import Foundation

enum CompanionBridgeImportError: LocalizedError {
    case emptyPayload
    case unsupportedPayload

    var errorDescription: String? {
        switch self {
        case .emptyPayload: return "Nothing to import."
        case .unsupportedPayload: return "SlipBoard supports Text, URL, and Code only."
        }
    }
}

struct CompanionBridgeImportCoordinator: CompanionBridgeImporting {
    func normalize(payload: String, source: CompanionBridgeImportSource, sourceAppName: String?) throws -> CompanionImportDraft {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CompanionBridgeImportError.emptyPayload }
        guard !trimmed.hasPrefix("data:"), !trimmed.hasPrefix("file:") else { throw CompanionBridgeImportError.unsupportedPayload }
        let kind: CompanionBridgePayloadKind = URL(string: trimmed)?.scheme != nil ? .url : (trimmed.contains("\n") ? .code : .text)
        return CompanionImportDraft(id: UUID(), source: source, payloadKind: kind, payloadText: trimmed, normalizedHash: String(trimmed.hashValue), capturedAt: .now, sourceAppName: sourceAppName)
    }
}
