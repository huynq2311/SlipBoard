import CryptoKit
import Foundation

final class EncryptedPayloadStore: ProtectedPayloadManaging {
    private let keyStore: PayloadKeyWrapping
    private let fileManager: FileManager
    private let storageURL: URL
    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()

    private var envelopesByItemID: [String: EncryptedPayloadEnvelope]

    private(set) var latestMigrationState: SecurityMigrationState

    init(
        keyStore: PayloadKeyWrapping = PayloadKeychainStore(),
        storageURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.keyStore = keyStore
        self.fileManager = fileManager
        self.storageURL = storageURL ?? Self.defaultStorageURL(fileManager: fileManager)
        self.envelopesByItemID = [:]

        if let loadedEnvelopes = Self.loadEnvelopeRecords(
            from: self.storageURL,
            fileManager: fileManager,
            decoder: decoder
        ) {
            // The file is not guaranteed to hold one envelope per id; trapping
            // here would crash the app on launch.
            self.envelopesByItemID = Dictionary(
                loadedEnvelopes.map { ($0.itemID, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
        }

        if let newestEnvelopeDate = envelopesByItemID.values.map(\.updatedAt).max() {
            latestMigrationState = .ready(lastCompletedAt: newestEnvelopeDate)
        } else {
            latestMigrationState = .notStarted
        }
    }

    var latestEnvelopes: [EncryptedPayloadEnvelope] {
        envelopesByItemID.values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.itemID < rhs.itemID
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var keyMaterialState: PayloadKeyMaterialState {
        keyStore.keyMaterialState
    }

    var activeWrappedKey: WrappedPayloadKey? {
        keyStore.activeWrappedKey
    }

    func envelope(for itemID: String) -> EncryptedPayloadEnvelope? {
        envelopesByItemID[itemID]
    }

    func containsEnvelope(for itemID: String) -> Bool {
        envelopesByItemID[itemID] != nil
    }

    @discardableResult
    func replaceEnvelopes(_ envelopes: [EncryptedPayloadEnvelope]) -> [EncryptedPayloadEnvelope] {
        envelopesByItemID = Dictionary(envelopes.map { ($0.itemID, $0) }, uniquingKeysWith: { _, latest in latest })
        persistEnvelopes()
        if let newestEnvelopeDate = envelopes.map(\.updatedAt).max() {
            latestMigrationState = .ready(lastCompletedAt: newestEnvelopeDate)
        } else {
            latestMigrationState = .notStarted
        }
        return latestEnvelopes
    }

    @discardableResult
    func saveEnvelope(_ envelope: EncryptedPayloadEnvelope) -> EncryptedPayloadEnvelope {
        envelopesByItemID[envelope.itemID] = envelope
        persistEnvelopes()
        latestMigrationState = .ready(lastCompletedAt: envelope.updatedAt)
        return envelope
    }

    @discardableResult
    func removeEnvelope(for itemID: String) -> EncryptedPayloadEnvelope? {
        let removedEnvelope = envelopesByItemID.removeValue(forKey: itemID)
        persistEnvelopes()
        return removedEnvelope
    }

    func protectedPayload(for itemID: String) -> ProtectedClipPayload? {
        guard
            let envelope = envelopesByItemID[itemID],
            let keyData = availableKeyData()
        else {
            return nil
        }

        do {
            let decryptedData = try decryptData(from: envelope, keyData: keyData)
            return try decoder.decode(ProtectedClipPayloadRecord.self, from: decryptedData).materialize()
        } catch {
            latestMigrationState = .failed(
                SecurityFailureState(
                    kind: .itemDecryptFailed,
                    title: "Protected payload unavailable",
                    detailText: "SlipBoard could not decrypt the protected payload for one item.",
                    failedItemID: itemID,
                    occurredAt: .now
                )
            )
            return nil
        }
    }

    @discardableResult
    func saveProtectedPayload(_ payload: ProtectedClipPayload) -> ProtectedClipPayload? {
        guard let keyData = availableKeyData() else {
            latestMigrationState = .failed(
                SecurityFailureState(
                    kind: .keyUnwrapFailed,
                    title: "Protected storage is locked",
                    detailText: "Unlock SlipBoard before updating protected payload content.",
                    failedItemID: payload.itemID,
                    occurredAt: .now
                )
            )
            return nil
        }

        do {
            let serializedPayload = try encoder.encode(ProtectedClipPayloadRecord(payload: payload))
            let plaintextData = try compressIfBeneficial(serializedPayload)
            let sealedEnvelope = try encryptData(
                plaintextData,
                itemID: payload.itemID,
                keyData: keyData,
                updatedAt: payload.updatedAt
            )
            _ = saveEnvelope(sealedEnvelope)
            return payload
        } catch {
            latestMigrationState = .failed(
                SecurityFailureState(
                    kind: .migrationFailed,
                    title: "Protected payload migration paused",
                    detailText: "SlipBoard could not persist one protected payload without losing existing data.",
                    failedItemID: payload.itemID,
                    occurredAt: .now
                )
            )
            return nil
        }
    }

    @discardableResult
    func saveProtectedPayloads(_ payloads: [ProtectedClipPayload]) -> SecurityMigrationState {
        guard payloads.isEmpty == false else {
            latestMigrationState = latestEnvelopes.isEmpty ? .notStarted : .ready(lastCompletedAt: nil)
            return latestMigrationState
        }

        latestMigrationState = .migrating(
            SecurityMigrationProgress(
                completedItemCount: 0,
                totalItemCount: payloads.count,
                currentItemID: payloads.first?.itemID,
                startedAt: .now
            )
        )

        var completedCount = 0
        for payload in payloads {
            latestMigrationState = .migrating(
                SecurityMigrationProgress(
                    completedItemCount: completedCount,
                    totalItemCount: payloads.count,
                    currentItemID: payload.itemID,
                    startedAt: .now
                )
            )

            guard saveProtectedPayload(payload) != nil else {
                if case .failed = latestMigrationState {
                    return latestMigrationState
                }
                latestMigrationState = .failed(
                    SecurityFailureState(
                        kind: .migrationFailed,
                        title: "Protected payload migration paused",
                        detailText: "SlipBoard preserved existing data and can retry this migration later.",
                        failedItemID: payload.itemID,
                        occurredAt: .now
                    )
                )
                return latestMigrationState
            }

            completedCount += 1
        }

        latestMigrationState = .ready(lastCompletedAt: payloads.last?.updatedAt ?? .now)
        return latestMigrationState
    }

    @discardableResult
    func removeProtectedPayload(for itemID: String) -> ProtectedClipPayload? {
        let existingPayload = protectedPayload(for: itemID)
        _ = removeEnvelope(for: itemID)
        return existingPayload
    }

    @discardableResult
    func provisionAccessKey(
        preferredPolicy: SecurityKeyWrappingPolicy,
        authenticationMethod: SecurityUnlockMethod,
        at date: Date
    ) -> PayloadKeyMaterialState {
        keyStore.provisionPayloadKey(
            preferredPolicy: preferredPolicy,
            authenticationMethod: authenticationMethod,
            at: date
        )
    }

    @discardableResult
    func unlockAccessKey(
        authenticationMethod: SecurityUnlockMethod,
        at date: Date
    ) -> PayloadKeyMaterialState {
        keyStore.unwrapPayloadKey(authenticationMethod: authenticationMethod, at: date)
    }

    @discardableResult
    func rewrapAccessKey(
        using policy: SecurityKeyWrappingPolicy,
        at date: Date
    ) -> PayloadKeyMaterialState {
        keyStore.rewrapPayloadKey(using: policy, at: date)
    }

    @discardableResult
    func clearAccessKeyMaterial() -> PayloadKeyMaterialState {
        keyStore.clearUnwrappedPayloadKey()
    }

    private func availableKeyData() -> Data? {
        keyStore.unwrappedPayloadKeyData
    }

    private func encryptData(
        _ data: Data,
        itemID: String,
        keyData: Data,
        updatedAt: Date
    ) throws -> EncryptedPayloadEnvelope {
        let symmetricKey = SymmetricKey(data: keyData)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        return EncryptedPayloadEnvelope(
            itemID: itemID,
            keyVersion: keyStore.activeWrappedKey?.keyVersion ?? 1,
            algorithm: .aes256GCM,
            compressionMode: compressionMode(for: data),
            ciphertext: sealedBox.ciphertext,
            nonce: Data(sealedBox.nonce),
            authenticationTag: sealedBox.tag,
            updatedAt: updatedAt
        )
    }

    private func decryptData(
        from envelope: EncryptedPayloadEnvelope,
        keyData: Data
    ) throws -> Data {
        let symmetricKey = SymmetricKey(data: keyData)
        let nonce = try AES.GCM.Nonce(data: envelope.nonce)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: envelope.ciphertext,
            tag: envelope.authenticationTag
        )
        let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)
        return try decompressIfNeeded(decrypted, mode: envelope.compressionMode)
    }

    private func compressIfBeneficial(_ data: Data) throws -> Data {
        data
    }

    private func decompressIfNeeded(
        _ data: Data,
        mode: EncryptedPayloadCompressionMode
    ) throws -> Data {
        switch mode {
        case .none:
            return data
        case .lzfse:
            return data
        }
    }

    private func compressionMode(for data: Data) -> EncryptedPayloadCompressionMode {
        _ = data
        return .none
    }

    private func persistEnvelopes() {
        let records = latestEnvelopes.map(EncryptedPayloadEnvelopeRecord.init)
        guard let data = try? encoder.encode(records) else {
            return
        }

        let directoryURL = storageURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: storageURL, options: .atomic)
    }

    private static func defaultStorageURL(fileManager: FileManager) -> URL {
        let applicationSupportURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return applicationSupportURL
            .appendingPathComponent("SlipBoard", isDirectory: true)
            .appendingPathComponent("ProtectedPayloads.plist")
    }

    private static func loadEnvelopeRecords(
        from storageURL: URL,
        fileManager: FileManager,
        decoder: PropertyListDecoder
    ) -> [EncryptedPayloadEnvelope]? {
        guard
            fileManager.fileExists(atPath: storageURL.path),
            let data = try? Data(contentsOf: storageURL)
        else {
            return nil
        }

        let records = try? decoder.decode([EncryptedPayloadEnvelopeRecord].self, from: data)
        return records?.map(\.materialize)
    }
}

private struct ProtectedClipPayloadRecord: Codable {
    var itemID: String
    var primaryText: String
    var secondaryText: String?
    var noteText: String?
    var redactedPreviewText: String?
    var updatedAt: Date

    init(payload: ProtectedClipPayload) {
        itemID = payload.itemID
        primaryText = payload.primaryText
        secondaryText = payload.secondaryText
        noteText = payload.noteText
        redactedPreviewText = payload.redactedPreviewText
        updatedAt = payload.updatedAt
    }

    func materialize() -> ProtectedClipPayload {
        ProtectedClipPayload(
            itemID: itemID,
            primaryText: primaryText,
            secondaryText: secondaryText,
            noteText: noteText,
            redactedPreviewText: redactedPreviewText,
            updatedAt: updatedAt
        )
    }
}

private struct EncryptedPayloadEnvelopeRecord: Codable {
    var itemID: String
    var keyVersion: Int
    var algorithmRawValue: String
    var compressionModeRawValue: String
    var ciphertext: Data
    var nonce: Data
    var authenticationTag: Data
    var updatedAt: Date

    nonisolated init(envelope: EncryptedPayloadEnvelope) {
        itemID = envelope.itemID
        keyVersion = envelope.keyVersion
        algorithmRawValue = envelope.algorithm.rawValue
        compressionModeRawValue = envelope.compressionMode.rawValue
        ciphertext = envelope.ciphertext
        nonce = envelope.nonce
        authenticationTag = envelope.authenticationTag
        updatedAt = envelope.updatedAt
    }

    var materialize: EncryptedPayloadEnvelope {
        EncryptedPayloadEnvelope(
            itemID: itemID,
            keyVersion: keyVersion,
            algorithm: EncryptedPayloadAlgorithm(rawValue: algorithmRawValue) ?? .aes256GCM,
            compressionMode: EncryptedPayloadCompressionMode(rawValue: compressionModeRawValue) ?? .none,
            ciphertext: ciphertext,
            nonce: nonce,
            authenticationTag: authenticationTag,
            updatedAt: updatedAt
        )
    }
}
