import Foundation
import LocalAuthentication
import Security

final class PayloadKeychainStore: PayloadKeyWrapping {
    private enum Constants {
        static let metadataService = "com.slipboard.security.payload-key"
        static let metadataAccount = "wrapped-metadata"
        static let fallbackKeyService = "com.slipboard.security.payload-key"
        static let fallbackKeyAccount = "raw-key"
        static let secureEnclaveKeyTag = "com.slipboard.security.secureenclave.payload-key"
        static let unlockPrompt = "Unlock SlipBoard protected payload"
        static let payloadKeySize = 32
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var keyMaterialState: PayloadKeyMaterialState
    private var activeKeyData: Data?

    init() {
        if let wrappedKey = Self.loadWrappedKeyRecord(decoder: decoder) {
            keyMaterialState = .wrappedOnly(wrappedKey)
        } else {
            keyMaterialState = .absent
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

        persistWrappedKey(wrappedKey)
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

        persistWrappedKey(wrappedKey)
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

    private func wrapWithSecureEnclave(_ payloadKeyData: Data, at date: Date) -> WrappedPayloadKey? {
        guard
            let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.privateKeyUsage, .userPresence],
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
            keyVersion: 1,
            wrappingPolicy: .secureEnclaveWrapped,
            wrappedKeyData: encryptedData,
            createdAt: date,
            lastWrappedAt: date
        )
    }

    private func wrapWithFallbackKeychain(_ payloadKeyData: Data, at date: Date) -> WrappedPayloadKey? {
        guard
            let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                nil
            )
        else {
            return nil
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount,
            kSecValueData: payloadKeyData,
            kSecAttrAccessControl: accessControl
        ]

        _ = deleteFallbackKeychainItem()
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            return nil
        }

        return WrappedPayloadKey(
            keyVersion: 1,
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
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount,
            kSecReturnData: true,
            kSecUseAuthenticationContext: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        return item as? Data
    }

    private func persistWrappedKey(_ wrappedKey: WrappedPayloadKey) {
        let record = WrappedPayloadKeyRecord(wrappedKey: wrappedKey)
        guard let data = try? encoder.encode(record) else {
            return
        }

        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.metadataService,
            kSecAttrAccount: Constants.metadataAccount
        ]
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
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
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
        let tagData = Data(Constants.secureEnclaveKeyTag.utf8)
        let context = makeAuthenticationContext()
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
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
        let tagData = Data(Constants.secureEnclaveKeyTag.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: tagData,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    @discardableResult
    private func deleteFallbackKeychainItem() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount
        ]
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

    private static func loadWrappedKeyRecord(decoder: JSONDecoder) -> WrappedPayloadKey? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.metadataService,
            kSecAttrAccount: Constants.metadataAccount,
            kSecReturnData: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return try? decoder.decode(WrappedPayloadKeyRecord.self, from: data).materialize()
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
