import Foundation

final class CloudBridgeEligibilityEvaluator: BridgeEligibilityEvaluating {
    private let allowedKinds: Set<BridgePayloadKind>
    private let allowedOutboundActionIdentifiers: Set<String>

    init(
        allowedKinds: Set<BridgePayloadKind> = Set(BridgePayloadKind.allCases),
        allowedOutboundActionIdentifiers: Set<String> = [
            "original",
            "pasteAndClose",
            "pasteAndKeepOpen"
        ]
    ) {
        self.allowedKinds = allowedKinds
        self.allowedOutboundActionIdentifiers = allowedOutboundActionIdentifiers
    }

    func evaluateOutboundEligibility(
        payloadKind: BridgePayloadKind?,
        payloadText: String?,
        didLocalPasteSucceed: Bool,
        actionIdentifier: String,
        normalizedHash: String?
    ) -> BridgeEligibilityResult {
        guard didLocalPasteSucceed else {
            return .ineligible("Bridge publish requires a successful local paste.")
        }

        guard allowedOutboundActionIdentifiers.contains(actionIdentifier) else {
            return .ineligible("Bridge publish is limited to direct local paste actions.")
        }

        guard let payloadKind else {
            return .ineligible("Bridge publish is unavailable for unsupported payload kinds.")
        }

        guard allowedKinds.contains(payloadKind) else {
            return .ineligible("Bridge publish is limited to text, URL, and code payloads.")
        }

        guard normalizedPayloadText(payloadText) != nil else {
            return .ineligible("Bridge publish requires a non-empty payload.")
        }

        guard normalizedHash?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .ineligible("Bridge publish requires a stable dedupe hash.")
        }

        return .eligible(payloadKind)
    }

    func evaluateInboundEligibility(
        envelope: BridgeTransferEnvelope,
        now: Date,
        knownConsumedRecordIDs: Set<String>
    ) -> BridgeEligibilityResult {
        guard envelope.origin == .companionImportedItem else {
            return .ineligible("Only companion-marked inbound records may import into Mac history.")
        }

        guard allowedKinds.contains(envelope.payloadKind) else {
            return .ineligible("Inbound bridge records are limited to text, URL, and code.")
        }

        guard envelope.isExpired(relativeTo: now) == false else {
            return .ineligible("Expired bridge records are ignored.")
        }

        guard envelope.isConsumed == false else {
            return .ineligible("Consumed bridge records are ignored.")
        }

        guard knownConsumedRecordIDs.contains(envelope.recordID) == false else {
            return .ineligible("The inbound envelope has already been consumed locally.")
        }

        guard normalizedPayloadText(envelope.payloadText) != nil else {
            return .ineligible("Inbound bridge records require a non-empty payload.")
        }

        guard envelope.normalizedHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .ineligible("Inbound bridge records require a stable dedupe hash.")
        }

        return .eligible(envelope.payloadKind)
    }

    private func normalizedPayloadText(_ payloadText: String?) -> String? {
        guard let payloadText else {
            return nil
        }

        let normalized = payloadText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? nil : normalized
    }
}
