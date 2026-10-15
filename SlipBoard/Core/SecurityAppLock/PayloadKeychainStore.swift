import Foundation
import LocalAuthentication
import OSLog
import Security

final class PayloadKeychainStore: PayloadKeyWrapping {
    private enum Constants {
        static let metadataService = "com.slipboard.security.payload-key"
        static let metadataAccount = "wrapped-metadata"
        static let fallbackKeyService = "com.slipboard.security.payload-key"
        static let fallbackKeyAccount = "raw-key"
        static let secureEnclaveKeyTag = "com.slipboard.security.secureenclave.payload-key"
        static let backendProbeService = "com.slipboard.security.keychain-probe"
        static let backendProbeAccount = "never-written"
        static let unlockPrompt = "Unlock SlipBoard protected payload"
        static let payloadKeySize = 32
    }

    /// Keys wrapped from this version on can be unwrapped without Touch ID, so
    /// SlipBoard opens unlocked after launch. App Lock then only locks within a
    /// session, and unlocking asks for Touch ID through LocalAuthentication.
    /// Version 1 keys still need user presence to unwrap; they are rewrapped as
    /// version 2 after the first successful unlock.
    static let sessionOnlyKeyVersion = 2

    /// Where the key material lives, decided once per launch.
    ///
    /// Team-signed builds carry `keychain-access-groups` and keep the key in the
    /// Data Protection keychain, wrapped by a Secure Enclave key.
    ///
    /// Ad-hoc builds cannot carry that entitlement (macOS kills them at launch),
    /// so every Data Protection call fails with errSecMissingEntitlement. They
    /// use the login keychain instead: the raw key is a generic password there,
    /// encrypted with the login password and readable without a prompt only by
    /// this app's signature. There is no Secure Enclave wrapping, which App Lock
    /// can afford because it hides the window and does not encrypt the disk.
    private enum KeychainBackend {
        case dataProtection
        case login
    }

    private static let logger = Logger(subsystem: "huynq.SlipBoard", category: "AppLock")

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let backend: KeychainBackend

    private(set) var keyMaterialState: PayloadKeyMaterialState
    /// True only when the keychain reported that no key record exists. A record
    /// that could not be read (for example, keychain access was denied) is not
    /// missing, so it is never replaced.
    private(set) var isKeyRecordMissing: Bool
    private var activeKeyData: Data?

    init() {
        let backend = Self.resolveBackend()
        self.backend = backend
        let storageName = backend == .dataProtection ? "data protection keychain" : "login keychain"
        Self.logger.info("App Lock key storage: \(storageName, privacy: .public)")

        let lookup = Self.loadWrappedKeyRecord(decoder: decoder, backend: backend)
        isKeyRecordMissing = lookup.status == errSecItemNotFound
        if let wrappedKey = lookup.wrappedKey {
            keyMaterialState = .wrappedOnly(wrappedKey)
        } else {
            keyMaterialState = .absent
            if lookup.status != errSecItemNotFound {
                Self.logger.error("App Lock key record unreadable: \(lookup.status, privacy: .public)")
            }
        }
    }

    var activeWrappedKey: WrappedPayloadKey? {
        keyMaterialState.activeWrappedKey
    }

    var unwrappedPayloadKeyData: Data? {
        activeKeyData
    }

    @discardableResult
    func provisionPayloadKey(
        preferredPolicy: SecurityKeyWrappingPolicy,
        authenticationMethod: SecurityUnlockMethod,
        at date: Date
    ) -> PayloadKeyMaterialState {
        guard let payloadKeyData = Self.randomPayloadKeyData() else {
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }

        let wrappedKey: WrappedPayloadKey?
        switch preferredPolicy {
        case .secureEnclaveWrapped:
            wrappedKey = wrapWithSecureEnclave(payloadKeyData, at: date)
                ?? wrapWithFallbackKeychain(payloadKeyData, at: date)
        case .keychainThisDeviceOnly:
            wrappedKey = wrapWithFallbackKeychain(payloadKeyData, at: date)
        }

        guard let wrappedKey else {
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }

        guard persistWrappedKey(wrappedKey) else {
            return discardUnrecordedKey()
        }

        isKeyRecordMissing = false
        activeKeyData = payloadKeyData
        keyMaterialState = .unwrappedInMemory(wrappedKey, unwrappedAt: date)
        return keyMaterialState
    }

    @discardableResult
    func unwrapPayloadKey(
        authenticationMethod: SecurityUnlockMethod,
        at date: Date
    ) -> PayloadKeyMaterialState {
        guard let wrappedKey = activeWrappedKey else {
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }

        let keyData: Data?
        switch wrappedKey.wrappingPolicy {
        case .secureEnclaveWrapped:
            keyData = unwrapSecureEnclaveWrappedKey(wrappedKey)
        case .keychainThisDeviceOnly:
            keyData = loadFallbackKeychainKeyData()
        }

        guard let keyData else {
            activeKeyData = nil
            keyMaterialState = .wrappedOnly(wrappedKey)
            return keyMaterialState
        }

        activeKeyData = keyData
        keyMaterialState = .unwrappedInMemory(wrappedKey, unwrappedAt: date)
        return keyMaterialState
    }

    @discardableResult
    func rewrapPayloadKey(
        using policy: SecurityKeyWrappingPolicy,
        at date: Date
    ) -> PayloadKeyMaterialState {
        let keyData = activeKeyData ?? {
            let nextState = unwrapPayloadKey(authenticationMethod: .systemPassword, at: date)
            guard case .unwrappedInMemory = nextState else {
                return nil
            }
            return activeKeyData
        }()

        guard let keyData else {
            return keyMaterialState
        }

        _ = deleteSecureEnclaveKey()
        _ = deleteFallbackKeychainItem()

        let wrappedKey: WrappedPayloadKey?
        switch policy {
        case .secureEnclaveWrapped:
            wrappedKey = wrapWithSecureEnclave(keyData, at: date)
                ?? wrapWithFallbackKeychain(keyData, at: date)
        case .keychainThisDeviceOnly:
            wrappedKey = wrapWithFallbackKeychain(keyData, at: date)
        }

        guard let wrappedKey else {
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }

        guard persistWrappedKey(wrappedKey) else {
            return discardUnrecordedKey()
        }

        activeKeyData = keyData
        keyMaterialState = .unwrappedInMemory(wrappedKey, unwrappedAt: date)
        return keyMaterialState
    }

    @discardableResult
    func clearUnwrappedPayloadKey() -> PayloadKeyMaterialState {
        activeKeyData = nil
        if let wrappedKey = activeWrappedKey {
            keyMaterialState = .wrappedOnly(wrappedKey)
        } else {
            keyMaterialState = .absent
        }
        return keyMaterialState
    }

    /// Without its record a relaunch cannot find the key, so the key must not be
    /// reported as stored, and the raw key is not left behind in the keychain.
    private func discardUnrecordedKey() -> PayloadKeyMaterialState {
        Self.logger.error("App Lock key record could not be saved")
        _ = deleteFallbackKeychainItem()
        keyMaterialState = .absent
        activeKeyData = nil
        return keyMaterialState
    }

    private func wrapWithSecureEnclave(_ payloadKeyData: Data, at date: Date) -> WrappedPayloadKey? {
        // A Secure Enclave key can only be persisted in the Data Protection keychain.
        guard backend == .dataProtection else {
            return nil
        }

        guard
            let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .privateKeyUsage,
                nil
            ),
            let privateKey = createOrLoadSecureEnclavePrivateKey(accessControl: accessControl),
            let publicKey = SecKeyCopyPublicKey(privateKey)
        else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard
            let encryptedData = SecKeyCreateEncryptedData(
                publicKey,
                .eciesEncryptionCofactorVariableIVX963SHA256AESGCM,
                payloadKeyData as CFData,
                &error
            ) as Data?
        else {
            return nil
        }

        return WrappedPayloadKey(
            keyVersion: Self.sessionOnlyKeyVersion,
            wrappingPolicy: .secureEnclaveWrapped,
            wrappedKeyData: encryptedData,
            createdAt: date,
            lastWrappedAt: date
        )
    }

    private func wrapWithFallbackKeychain(_ payloadKeyData: Data, at date: Date) -> WrappedPayloadKey? {
        let query = Self.keychainQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount,
            kSecValueData: payloadKeyData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ], backend: backend)

        _ = deleteFallbackKeychainItem()
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            return nil
        }

        return WrappedPayloadKey(
            keyVersion: Self.sessionOnlyKeyVersion,
            wrappingPolicy: .keychainThisDeviceOnly,
            wrappedKeyData: Data("keychain:this-device-only".utf8),
            createdAt: date,
            lastWrappedAt: date
        )
    }

    private func unwrapSecureEnclaveWrappedKey(_ wrappedKey: WrappedPayloadKey) -> Data? {
        guard let privateKey = loadSecureEnclavePrivateKey() else {
            return nil
        }

        var error: Unmanaged<CFError>?
        return SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionCofactorVariableIVX963SHA256AESGCM,
            wrappedKey.wrappedKeyData as CFData,
            &error
        ) as Data?
    }

    private func loadFallbackKeychainKeyData() -> Data? {
        let context = makeAuthenticationContext()
        let query = Self.keychainQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount,
            kSecReturnData: true,
            kSecUseAuthenticationContext: context
        ], backend: backend)

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        return item as? Data
    }

    private func persistWrappedKey(_ wrappedKey: WrappedPayloadKey) -> Bool {
        let record = WrappedPayloadKeyRecord(wrappedKey: wrappedKey)
        guard let data = try? encoder.encode(record) else {
            return false
        }

        let baseQuery = Self.keychainQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.metadataService,
            kSecAttrAccount: Constants.metadataAccount
        ], backend: backend)
        let addQuery: [CFString: Any] = baseQuery.merging([
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]) { _, replacement in replacement }
        let update: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    private func createOrLoadSecureEnclavePrivateKey(accessControl: SecAccessControl) -> SecKey? {
        if let existingKey = loadSecureEnclavePrivateKey() {
            return existingKey
        }

        let tagData = Data(Constants.secureEnclaveKeyTag.utf8)
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecUseDataProtectionKeychain: true,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: tagData,
                kSecAttrAccessControl: accessControl
            ]
        ]

        var error: Unmanaged<CFError>?
        return SecKeyCreateRandomKey(attributes as CFDictionary, &error)
    }

    private func loadSecureEnclavePrivateKey() -> SecKey? {
        guard backend == .dataProtection else {
            return nil
        }

        let tagData = Data(Constants.secureEnclaveKeyTag.utf8)
        let context = makeAuthenticationContext()
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecUseDataProtectionKeychain: true,
            kSecAttrApplicationTag: tagData,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef: true,
            kSecUseAuthenticationContext: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        return (item as! SecKey)
    }

    @discardableResult
    private func deleteSecureEnclaveKey() -> Bool {
        guard backend == .dataProtection else {
            return true
        }

        let tagData = Data(Constants.secureEnclaveKeyTag.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecUseDataProtectionKeychain: true,
            kSecAttrApplicationTag: tagData,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    @discardableResult
    private func deleteFallbackKeychainItem() -> Bool {
        let query = Self.keychainQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount
        ], backend: backend)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func randomPayloadKeyData() -> Data? {
        var bytes = [UInt8](repeating: 0, count: Constants.payloadKeySize)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return nil
        }
        return Data(bytes)
    }

    private static func loadWrappedKeyRecord(
        decoder: JSONDecoder,
        backend: KeychainBackend
    ) -> (wrappedKey: WrappedPayloadKey?, status: OSStatus) {
        let query = keychainQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.metadataService,
            kSecAttrAccount: Constants.metadataAccount,
            kSecReturnData: true
        ], backend: backend)

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return (nil, status)
        }

        return (try? decoder.decode(WrappedPayloadKeyRecord.self, from: data).materialize(), status)
    }

    /// Falls back to the login keychain only on errSecMissingEntitlement. Any
    /// other status keeps the Data Protection keychain, so a team-signed build
    /// never reads or writes key material outside it. Deleting an item that is
    /// never written has no effect; only the status matters.
    private static func resolveBackend() -> KeychainBackend {
        let probe: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain: true,
            kSecAttrService: Constants.backendProbeService,
            kSecAttrAccount: Constants.backendProbeAccount
        ]
        return SecItemDelete(probe as CFDictionary) == errSecMissingEntitlement ? .login : .dataProtection
    }

    /// Without `kSecUseDataProtectionKeychain`, macOS uses the login keychain.
    private static func keychainQuery(_ query: [CFString: Any], backend: KeychainBackend) -> [CFString: Any] {
        guard backend == .dataProtection else {
            return query
        }
        return query.merging([kSecUseDataProtectionKeychain: true]) { _, flag in flag }
    }

    private func makeAuthenticationContext() -> LAContext {
        let context = LAContext()
        context.localizedReason = Constants.unlockPrompt
        return context
    }
}

private struct WrappedPayloadKeyRecord: Codable {
    var keyVersion: Int
    var wrappingPolicyRawValue: String
    var wrappedKeyData: Data
    var createdAt: Date
    var lastWrappedAt: Date

    init(wrappedKey: WrappedPayloadKey) {
        keyVersion = wrappedKey.keyVersion
        wrappingPolicyRawValue = wrappedKey.wrappingPolicy.rawValue
        wrappedKeyData = wrappedKey.wrappedKeyData
        createdAt = wrappedKey.createdAt
        lastWrappedAt = wrappedKey.lastWrappedAt
    }

    func materialize() -> WrappedPayloadKey {
        WrappedPayloadKey(
            keyVersion: keyVersion,
            wrappingPolicy: SecurityKeyWrappingPolicy(rawValue: wrappingPolicyRawValue) ?? .keychainThisDeviceOnly,
            wrappedKeyData: wrappedKeyData,
            createdAt: createdAt,
            lastWrappedAt: lastWrappedAt
        )
    }
}
