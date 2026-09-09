import Foundation

final class ExclusionsPauseSettingsStore: ExclusionsPauseSettingsStoring {
    private struct PersistedSnapshot: Codable {
        var excludedApps: [PersistedExcludedAppRule]
        var pauseState: PersistedPauseState
        var behaviorSettings: PersistedBehaviorSettings
        var lastUpdatedAt: Date
    }

    private struct PersistedExcludedAppRule: Codable {
        var id: String
        var bundleID: String?
        var displayName: String
        var symbolName: String?
        var detailText: String
        var matchStrategy: String
    }

    private struct PersistedBehaviorSettings: Codable {
        var hidePopupInsideExcludedApps: Bool
    }

    private enum PersistedPauseState: Codable {
        case inactive
        case manual(startedAt: Date)
        case timed(startedAt: Date, resumeAt: Date, presetRawValue: String)

        private enum CodingKeys: String, CodingKey {
            case kind
            case startedAt
            case resumeAt
            case presetRawValue
        }

        private enum Kind: String, Codable {
            case inactive
            case manual
            case timed
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Kind.self, forKey: .kind)

            switch kind {
            case .inactive:
                self = .inactive
            case .manual:
                self = .manual(
                    startedAt: try container.decode(Date.self, forKey: .startedAt)
                )
            case .timed:
                self = .timed(
                    startedAt: try container.decode(Date.self, forKey: .startedAt),
                    resumeAt: try container.decode(Date.self, forKey: .resumeAt),
                    presetRawValue: try container.decode(String.self, forKey: .presetRawValue)
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .inactive:
                try container.encode(Kind.inactive, forKey: .kind)
            case let .manual(startedAt):
                try container.encode(Kind.manual, forKey: .kind)
                try container.encode(startedAt, forKey: .startedAt)
            case let .timed(startedAt, resumeAt, presetRawValue):
                try container.encode(Kind.timed, forKey: .kind)
                try container.encode(startedAt, forKey: .startedAt)
                try container.encode(resumeAt, forKey: .resumeAt)
                try container.encode(presetRawValue, forKey: .presetRawValue)
            }
        }
    }

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var snapshot: ExclusionsPauseSettingsSnapshot

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "SlipBoard.ExclusionsPause.Settings"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        if
            let data = userDefaults.data(forKey: storageKey),
            let persistedSnapshot = try? decoder.decode(PersistedSnapshot.self, from: data)
        {
            self.snapshot = Self.makeSnapshot(from: persistedSnapshot)
        } else {
            self.snapshot = ExclusionsPauseSettingsSnapshot()
        }

        self.snapshot = Self.normalizedSnapshot(self.snapshot)
    }

    @discardableResult
    func saveExcludedApps(
        _ rules: [ExcludedAppRule],
        lastUpdatedAt: Date
    ) -> ExclusionsPauseSettingsSnapshot {
        var nextSnapshot = snapshot
        nextSnapshot.excludedApps = rules
        nextSnapshot.lastUpdatedAt = lastUpdatedAt
        return replaceSnapshot(nextSnapshot)
    }

    @discardableResult
    func savePauseState(
        _ pauseState: CapturePauseState,
        lastUpdatedAt: Date
    ) -> ExclusionsPauseSettingsSnapshot {
        var nextSnapshot = snapshot
        nextSnapshot.pauseState = pauseState
        nextSnapshot.lastUpdatedAt = lastUpdatedAt
        return replaceSnapshot(nextSnapshot)
    }

    @discardableResult
    func saveBehaviorSettings(
        _ settings: ExclusionsBehaviorSettings,
        lastUpdatedAt: Date
    ) -> ExclusionsPauseSettingsSnapshot {
        var nextSnapshot = snapshot
        nextSnapshot.behaviorSettings = settings
        nextSnapshot.lastUpdatedAt = lastUpdatedAt
        return replaceSnapshot(nextSnapshot)
    }

    @discardableResult
    func replaceSnapshot(_ snapshot: ExclusionsPauseSettingsSnapshot) -> ExclusionsPauseSettingsSnapshot {
        self.snapshot = Self.normalizedSnapshot(snapshot)
        persistSnapshot()
        return self.snapshot
    }

    private func persistSnapshot() {
        let persistedSnapshot = Self.makePersistedSnapshot(from: snapshot)

        guard let data = try? encoder.encode(persistedSnapshot) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }

    private static func normalizedSnapshot(
        _ snapshot: ExclusionsPauseSettingsSnapshot
    ) -> ExclusionsPauseSettingsSnapshot {
        let rules = Dictionary(grouping: snapshot.excludedApps) { $0.id }
            .values
            .compactMap(\.last)
            .map(normalizedRule(_:))
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

        return ExclusionsPauseSettingsSnapshot(
            excludedApps: rules,
            pauseState: snapshot.pauseState,
            behaviorSettings: snapshot.behaviorSettings,
            lastUpdatedAt: snapshot.lastUpdatedAt
        )
    }

    private static func normalizedRule(_ rule: ExcludedAppRule) -> ExcludedAppRule {
        let trimmedDisplayName = rule.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedDisplayName.isEmpty ? "Unknown App" : trimmedDisplayName
        let detailText = rule.detailText.trimmingCharacters(in: .whitespacesAndNewlines)

        return ExcludedAppRule(
            id: rule.id,
            bundleID: rule.bundleID,
            displayName: displayName,
            symbolName: rule.symbolName,
            detailText: detailText.isEmpty ? nil : detailText,
            matchStrategy: rule.matchStrategy
        )
    }

    private static func makePersistedSnapshot(
        from snapshot: ExclusionsPauseSettingsSnapshot
    ) -> PersistedSnapshot {
        PersistedSnapshot(
            excludedApps: snapshot.excludedApps.map { rule in
                PersistedExcludedAppRule(
                    id: rule.id,
                    bundleID: rule.bundleID,
                    displayName: rule.displayName,
                    symbolName: rule.symbolName,
                    detailText: rule.detailText,
                    matchStrategy: rule.matchStrategy.rawValue
                )
            },
            pauseState: makePersistedPauseState(from: snapshot.pauseState),
            behaviorSettings: PersistedBehaviorSettings(
                hidePopupInsideExcludedApps: snapshot.behaviorSettings.hidePopupInsideExcludedApps
            ),
            lastUpdatedAt: snapshot.lastUpdatedAt
        )
    }

    private static func makeSnapshot(
        from persistedSnapshot: PersistedSnapshot
    ) -> ExclusionsPauseSettingsSnapshot {
        ExclusionsPauseSettingsSnapshot(
            excludedApps: persistedSnapshot.excludedApps.compactMap { persistedRule in
                guard
                    let matchStrategy = ExcludedAppMatchStrategy(rawValue: persistedRule.matchStrategy)
                else {
                    return nil
                }

                return ExcludedAppRule(
                    id: persistedRule.id,
                    bundleID: persistedRule.bundleID,
                    displayName: persistedRule.displayName,
                    symbolName: persistedRule.symbolName,
                    detailText: persistedRule.detailText,
                    matchStrategy: matchStrategy
                )
            },
            pauseState: makePauseState(from: persistedSnapshot.pauseState),
            behaviorSettings: ExclusionsBehaviorSettings(
                hidePopupInsideExcludedApps: persistedSnapshot.behaviorSettings.hidePopupInsideExcludedApps
            ),
            lastUpdatedAt: persistedSnapshot.lastUpdatedAt
        )
    }

    private static func makePersistedPauseState(
        from pauseState: CapturePauseState
    ) -> PersistedPauseState {
        switch pauseState {
        case .inactive:
            return .inactive
        case let .manual(startedAt):
            return .manual(startedAt: startedAt)
        case let .timed(startedAt, resumeAt, preset):
            return .timed(
                startedAt: startedAt,
                resumeAt: resumeAt,
                presetRawValue: preset.rawValue
            )
        }
    }

    private static func makePauseState(
        from persistedPauseState: PersistedPauseState
    ) -> CapturePauseState {
        switch persistedPauseState {
        case .inactive:
            return .inactive
        case let .manual(startedAt):
            return .manual(startedAt: startedAt)
        case let .timed(startedAt, resumeAt, presetRawValue):
            guard let preset = CapturePauseDurationOption(rawValue: presetRawValue) else {
                return .inactive
            }

            return .timed(
                startedAt: startedAt,
                resumeAt: resumeAt,
                preset: preset
            )
        }
    }
}
