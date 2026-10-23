import Foundation

final class CloudBridgeRecordStore: BridgeTransporting {
    private static let logger = DiagnosticLogger(category: "Bridge")

    private enum DefaultsKey {
        static let state = "SlipTray.ICloudBridgeMac.RecordStore"
    }

    private struct PersistedState: Codable {
        var accountStatusRawValue: String
        var knownDevices: [BridgeDeviceSummary]
        var envelopes: [BridgeTransferEnvelope]
        var consumedRecordIDs: [String: Date]
        var activity: BridgeActivitySnapshot
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let bookkeepingTTL: TimeInterval

    private var state: PersistedState

    var activitySnapshot: BridgeActivitySnapshot {
        pruneConsumedBookkeeping(asOf: Date())
        return state.activity
    }

    var consumedRecordIDs: Set<String> {
        pruneConsumedBookkeeping(asOf: Date())
        return Set(state.consumedRecordIDs.keys)
    }

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = DefaultsKey.state,
        defaultAccountStatus: BridgeAccountStatus = .ready,
        bookkeepingTTLMinutes: Int = 10
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.bookkeepingTTL = TimeInterval(max(bookkeepingTTLMinutes, 1) * 60)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        var persistedState: PersistedState?
        if let data = defaults.data(forKey: storageKey) {
            do {
                persistedState = try decoder.decode(PersistedState.self, from: data)
            } catch {
                Self.logger.error("Bridge record state unreadable, starting empty: \(DiagnosticLogger.describe(error))")
            }
        }

        if let persistedState {
            self.state = persistedState
        } else {
            self.state = PersistedState(
                accountStatusRawValue: defaultAccountStatus.rawValue,
                knownDevices: [],
                envelopes: [],
                consumedRecordIDs: [:],
                activity: BridgeActivitySnapshot()
            )
        }

        pruneConsumedBookkeeping(asOf: Date())
    }

    func fetchAccountStatus() -> BridgeAccountStatus {
        BridgeAccountStatus(rawValue: state.accountStatusRawValue) ?? .unavailable
    }

    func fetchKnownDevices() -> [BridgeDeviceSummary] {
        let persistedDevices = state.knownDevices
        let derivedInboundDevices = Dictionary(grouping: state.envelopes.filter {
            $0.origin == .companionImportedItem
        }, by: \.sourceDeviceName)
            .compactMap { deviceName, envelopes -> BridgeDeviceSummary? in
                let lastSeenAt = envelopes
                    .flatMap { [$0.createdAt, $0.consumedAt].compactMap { $0 } }
                    .max()

                return BridgeDeviceSummary(
                    id: "bridge-device-\(deviceName.lowercased().replacingOccurrences(of: " ", with: "-"))",
                    displayName: deviceName,
                    platform: .iphone,
                    statusText: "Recent bridge activity on this iCloud account",
                    badgeText: envelopes.contains(where: { $0.isConsumed == false }) ? "Pending" : "Ready",
                    lastSeenAt: lastSeenAt
                )
            }

        let mergedDevices = persistedDevices + derivedInboundDevices
        return Dictionary(grouping: mergedDevices, by: \.id)
            .values
            .compactMap { deviceGroup in
                deviceGroup.max { lhs, rhs in
                    (lhs.lastSeenAt ?? .distantPast) < (rhs.lastSeenAt ?? .distantPast)
                }
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    func fetchPendingEnvelopes(asOf referenceDate: Date) -> [BridgeTransferEnvelope] {
        _ = deleteExpiredRecords(asOf: referenceDate)
        return state.envelopes
            .filter { $0.isExpired(relativeTo: referenceDate) == false && $0.isConsumed == false }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func publish(_ envelope: BridgeTransferEnvelope) -> BridgeTransferEnvelope {
        upsertEnvelope(envelope)
        state.activity.lastPublishedAt = envelope.createdAt
        state.activity.lastErrorText = nil
        persist()
        return envelope
    }

    @discardableResult
    func markConsumed(recordIDs: [String], consumedAt: Date) -> [BridgeTransferEnvelope] {
        let recordIDSet = Set(recordIDs)
        guard recordIDSet.isEmpty == false else {
            return []
        }

        var consumedEnvelopes: [BridgeTransferEnvelope] = []
        state.envelopes = state.envelopes.map { envelope in
            guard recordIDSet.contains(envelope.recordID) else {
                return envelope
            }

            let consumedEnvelope = envelope.markingConsumed(at: consumedAt)
            consumedEnvelopes.append(consumedEnvelope)
            state.consumedRecordIDs[envelope.recordID] = consumedAt
            return consumedEnvelope
        }

        if consumedEnvelopes.contains(where: { $0.origin == .companionImportedItem }) {
            state.activity.lastImportedAt = consumedAt
        }
        state.activity.lastErrorText = nil
        pruneConsumedBookkeeping(asOf: consumedAt)
        persist()
        return consumedEnvelopes
    }

    @discardableResult
    func deleteExpiredRecords(asOf referenceDate: Date) -> [String] {
        let expiredRecordIDs = state.envelopes
            .filter { $0.isExpired(relativeTo: referenceDate) }
            .map(\.recordID)

        guard expiredRecordIDs.isEmpty == false || state.consumedRecordIDs.isEmpty == false else {
            return []
        }

        state.envelopes.removeAll { envelope in
            envelope.isExpired(relativeTo: referenceDate)
        }
        pruneConsumedBookkeeping(asOf: referenceDate)
        persist()
        return expiredRecordIDs
    }

    func replaceKnownDevices(_ devices: [BridgeDeviceSummary]) {
        state.knownDevices = devices
        persist()
    }

    func setAccountStatus(_ status: BridgeAccountStatus) {
        state.accountStatusRawValue = status.rawValue
        persist()
    }

    func recordFailure(_ message: String, at _: Date) {
        state.activity.lastErrorText = message
        persist()
    }

    private func upsertEnvelope(_ envelope: BridgeTransferEnvelope) {
        if let existingIndex = state.envelopes.firstIndex(where: { $0.recordID == envelope.recordID }) {
            state.envelopes[existingIndex] = envelope
        } else {
            state.envelopes.append(envelope)
        }
    }

    private func pruneConsumedBookkeeping(asOf referenceDate: Date) {
        let retainedRemoteRecordIDs = Set(state.envelopes.map(\.recordID))
        let cutoffDate = referenceDate.addingTimeInterval(-bookkeepingTTL)

        state.consumedRecordIDs = state.consumedRecordIDs.filter { recordID, consumedAt in
            retainedRemoteRecordIDs.contains(recordID) || consumedAt >= cutoffDate
        }
    }

    private func persist() {
        let data: Data
        do {
            data = try encoder.encode(state)
        } catch {
            Self.logger.error("Bridge record state could not be saved: \(DiagnosticLogger.describe(error))")
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}
