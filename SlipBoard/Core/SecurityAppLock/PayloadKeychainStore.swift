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
        static let fileWrappedKeyMarker = "file:this-device-only"
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
    /// keep the key in a 0600 file instead (see `PayloadKeyFile`). The login
    /// keychain is not used: it ties an item to the exact build, so every update
    /// asked for the login password again. Tradeoff: the key sits next to the
    /// encrypted payloads, so on these builds note encryption only keeps notes
    /// out of casual view, and App Lock hides the window without encrypting the
    /// disk. The release before this one kept the key in the login keychain;
    /// that key is moved to the file on first unlock.
    ///
    /// A build whose signature claims the keychain entitlement but still gets
    /// errSecMissingEntitlement (a missing or expired profile) is
    /// misconfigured; it gets no key at all rather than a plain file.
    private enum KeychainBackend {
        case dataProtection
        case file
        case unavailable
    }

    private static let logger = Logger(subsystem: "huynq.SlipBoard", category: "AppLock")

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let keyFile: PayloadKeyFile

    /// Resolved on first use: without App Lock, launch touches neither the
    /// keychain nor the key file.
    private lazy var backend: KeychainBackend = {
        let backend = Self.resolveBackend()
        switch backend {
        case .dataProtection:
            Self.logger.info("App Lock key storage: data protection keychain")
        case .file:
            Self.logger.info("App Lock key storage: key file")
        case .unavailable:
            Self.logger.error("App Lock key storage unavailable: keychain entitlement claimed but not granted")
        }
        return backend
    }()
    private var hasLoadedKeyRecord = false

    private(set) var keyMaterialState: PayloadKeyMaterialState
    /// True only when the storage reported that no key record exists. A record
    /// that could not be read (for example, keychain access was denied) is not
    /// missing, so it is never replaced. False until the record is loaded.
    private(set) var isKeyRecordMissing: Bool
    private var activeKeyData: Data?

    init(keyFileURL: URL? = nil) {
        keyFile = PayloadKeyFile(url: keyFileURL ?? PayloadKeyFile.defaultURL(), keySize: Constants.payloadKeySize)
        keyMaterialState = .absent
        isKeyRecordMissing = false
    }

    /// Only a found record or a definite "not found" is final. Any other result
    /// (an unreadable file, a locked keychain, a lookup that would have asked
    /// the user) is tried again on the next unlock.
    func loadStoredKeyIfNeeded(allowsUserInteraction: Bool) {
        guard hasLoadedKeyRecord == false else {
            return
        }

        switch backend {
        case .unavailable:
            hasLoadedKeyRecord = true
        case .dataProtection:
            let lookup = Self.loadWrappedKeyRecord(decoder: decoder)
            if let wrappedKey = lookup.wrappedKey {
                keyMaterialState = .wrappedOnly(wrappedKey)
                hasLoadedKeyRecord = true
            } else if lookup.status == errSecItemNotFound {
                isKeyRecordMissing = true
                hasLoadedKeyRecord = true
            } else {
                Self.logger.error("App Lock key record unreadable: \(lookup.status, privacy: .public)")
            }
        case .file:
            switch keyFile.read() {
            case let .found(wrappedKey, _):
                keyMaterialState = .wrappedOnly(wrappedKey)
                hasLoadedKeyRecord = true
            case .missing:
                let legacyLookup = Self.legacyLoginKeychainKey(allowsUserInteraction: allowsUserInteraction)
                if let legacyKey = legacyLookup.wrappedKey {
                    keyMaterialState = .wrappedOnly(legacyKey)
                    hasLoadedKeyRecord = true
                } else if legacyLookup.status == errSecItemNotFound {
                    isKeyRecordMissing = true
                    hasLoadedKeyRecord = true
                } else {
                    Self.logger.error("App Lock login keychain key unreadable: \(legacyLookup.status, privacy: .public)")
                }
            case .inaccessible, .corrupt:
                Self.logger.error("App Lock key file unreadable")
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
        switch backend {
        case .unavailable:
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        case .file:
            return provisionInKeyFile(at: date)
        case .dataProtection:
            break
        }

        hasLoadedKeyRecord = true
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
        case .keychainThisDeviceOnly, .localFile:
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
        loadStoredKeyIfNeeded(allowsUserInteraction: true)
        guard let wrappedKey = activeWrappedKey else {
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }

        if backend == .file {
            return unwrapFromKeyFile(wrappedKey, at: date)
        }

        let keyData: Data?
        switch wrappedKey.wrappingPolicy {
        case .secureEnclaveWrapped:
            keyData = unwrapSecureEnclaveWrappedKey(wrappedKey)
        case .keychainThisDeviceOnly:
            keyData = loadFallbackKeychainKeyData()
        case .localFile:
            keyData = nil
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

        if backend == .file {
            return storeInKeyFile(keyData, createdAt: activeWrappedKey?.createdAt ?? date, at: date)
        }

        _ = deleteSecureEnclaveKey()
        _ = deleteFallbackKeychainItem()

        let wrappedKey: WrappedPayloadKey?
        switch policy {
        case .secureEnclaveWrapped:
            wrappedKey = wrapWithSecureEnclave(keyData, at: date)
                ?? wrapWithFallbackKeychain(keyData, at: date)
        case .keychainThisDeviceOnly, .localFile:
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

    /// Turning App Lock off and on keeps an existing key, so notes saved under
    /// it stay readable. A new key is written only when there is none, or when
    /// the file cannot be parsed; that file is moved aside first. A key that
    /// could not be read (a file with other access rights or owner, a newer
    /// format, a login keychain key that was denied or could not be checked) is
    /// never replaced: enabling fails and can be retried. A new key is written
    /// only where no key file exists; if another instance writes one first, its
    /// key is used instead. The same holds when it replaced an unparsable file
    /// this instance was about to move aside: instances take a lock on the key
    /// file from reading it to writing the new key.
    private func provisionInKeyFile(at date: Date) -> PayloadKeyMaterialState {
        loadStoredKeyIfNeeded(allowsUserInteraction: true)
        if let existingKey = activeWrappedKey {
            let state = unwrapFromKeyFile(existingKey, at: date)
            if state.hasUnwrappedKeyInMemory || existingKey.wrappingPolicy == .keychainThisDeviceOnly {
                return state
            }
        }
        guard let state = keyFile.withExclusiveLock({ createKeyInKeyFile(at: date) }) else {
            Self.logger.error("App Lock key file could not be locked")
            activeKeyData = nil
            return keyMaterialState
        }
        return state
    }

    private func createKeyInKeyFile(at date: Date) -> PayloadKeyMaterialState {
        if isKeyRecordMissing == false {
            let identity: PayloadKeyFile.FileIdentity
            switch keyFile.read() {
            case .found:
                return adoptKeyFromAnotherInstance(at: date)
            case let .corrupt(readIdentity):
                identity = readIdentity
            case .missing, .inaccessible:
                Self.logger.error("App Lock key not replaced: the existing key could not be read")
                activeKeyData = nil
                return keyMaterialState
            }
            switch keyFile.moveAside(identity) {
            case .moved:
                Self.logger.info("App Lock moved an unparsable key file aside")
            case .changed:
                return adoptKeyFromAnotherInstance(at: date)
            case .failed:
                Self.logger.error("App Lock key not replaced: the unparsable key file could not be moved aside")
                activeKeyData = nil
                return keyMaterialState
            }
        }

        guard let payloadKeyData = Self.randomPayloadKeyData() else {
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }
        hasLoadedKeyRecord = true
        let wrappedKey = fileWrappedKey(createdAt: date, at: date)
        switch keyFile.create(wrappedKey, keyData: payloadKeyData) {
        case .created:
            return useStoredKey(wrappedKey, keyData: payloadKeyData, at: date)
        case .alreadyExists:
            return adoptKeyFromAnotherInstance(at: date)
        case .failed:
            Self.logger.error("App Lock key file could not be saved")
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }
    }

    /// Another instance wrote its key first and may already use it.
    private func adoptKeyFromAnotherInstance(at date: Date) -> PayloadKeyMaterialState {
        guard case let .found(storedKey, keyData) = keyFile.read() else {
            Self.logger.error("App Lock key not replaced: another instance wrote a key that could not be read")
            hasLoadedKeyRecord = false
            isKeyRecordMissing = false
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }
        Self.logger.info("App Lock adopted the key another instance wrote")
        return useStoredKey(storedKey, keyData: keyData, at: date)
    }

    private func fileWrappedKey(createdAt: Date, at date: Date) -> WrappedPayloadKey {
        WrappedPayloadKey(
            keyVersion: Self.sessionOnlyKeyVersion,
            wrappingPolicy: .localFile,
            wrappedKeyData: Data(Constants.fileWrappedKeyMarker.utf8),
            createdAt: createdAt,
            lastWrappedAt: date
        )
    }

    /// The file holds the key and its record together, so one atomic write
    /// replaces both and there is no record without a key. Only for the key
    /// already in use (migration, rewrap); a new key goes through
    /// `PayloadKeyFile.create`.
    private func storeInKeyFile(_ keyData: Data, createdAt: Date, at date: Date) -> PayloadKeyMaterialState {
        let wrappedKey = fileWrappedKey(createdAt: createdAt, at: date)
        // Decided under the lock: the file is created only if there is none,
        // and rewritten only if it already holds this key. A different key
        // (another instance may have just created one) or a file that cannot
        // be read is never replaced.
        let isStored = keyFile.withExclusiveLock { () -> Bool in
            switch keyFile.read() {
            case .missing:
                switch keyFile.create(wrappedKey, keyData: keyData) {
                case .created:
                    return true
                case .alreadyExists:
                    if case let .found(_, existingKeyData) = keyFile.read() {
                        return existingKeyData == keyData
                    }
                    return false
                case .failed:
                    return false
                }
            case let .found(_, existingKeyData) where existingKeyData == keyData:
                return keyFile.write(wrappedKey, keyData: keyData)
            default:
                return false
            }
        }
        guard isStored == true else {
            Self.logger.error("App Lock key file could not be saved")
            keyMaterialState = .absent
            activeKeyData = nil
            return keyMaterialState
        }
        return useStoredKey(wrappedKey, keyData: keyData, at: date)
    }

    private func useStoredKey(_ wrappedKey: WrappedPayloadKey, keyData: Data, at date: Date) -> PayloadKeyMaterialState {
        isKeyRecordMissing = false
        activeKeyData = keyData
        keyMaterialState = .unwrappedInMemory(wrappedKey, unwrappedAt: date)
        return keyMaterialState
    }

    /// The key is read from the file on every unlock instead of being kept in
    /// memory while locked.
    private func unwrapFromKeyFile(_ wrappedKey: WrappedPayloadKey, at date: Date) -> PayloadKeyMaterialState {
        if wrappedKey.wrappingPolicy == .keychainThisDeviceOnly {
            return moveLegacyLoginKeychainKey(wrappedKey, at: date)
        }

        guard case let .found(storedKey, keyData) = keyFile.read() else {
            activeKeyData = nil
            keyMaterialState = .wrappedOnly(wrappedKey)
            return keyMaterialState
        }

        activeKeyData = keyData
        keyMaterialState = .unwrappedInMemory(storedKey, unwrappedAt: date)
        return keyMaterialState
    }

    /// Moves the key that the previous ad-hoc release kept in the login keychain
    /// into the key file. That item belongs to the build that wrote it, so
    /// reading it asks for the login password once. Losing the key would make
    /// existing notes unreadable, which is worse than one prompt. The keychain
    /// items are deleted only after the file is written, and only if macOS
    /// allows it without asking again; leftovers are never read once the file
    /// exists.
    private func moveLegacyLoginKeychainKey(_ legacyKey: WrappedPayloadKey, at date: Date) -> PayloadKeyMaterialState {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount,
            kSecReturnData: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let keyData = item as? Data, keyData.count == Constants.payloadKeySize else {
            Self.logger.error("App Lock login keychain key unreadable: \(status, privacy: .public)")
            activeKeyData = nil
            keyMaterialState = .wrappedOnly(legacyKey)
            return keyMaterialState
        }

        let nextState = storeInKeyFile(keyData, createdAt: legacyKey.createdAt, at: date)
        guard
            nextState.hasUnwrappedKeyInMemory,
            case let .found(_, storedKeyData) = keyFile.read(),
            storedKeyData == keyData
        else {
            // Keep the keychain copy and use the key for this session anyway.
            activeKeyData = keyData
            keyMaterialState = .unwrappedInMemory(legacyKey, unwrappedAt: date)
            return keyMaterialState
        }

        Self.deleteLegacyLoginKeychainItems()
        return nextState
    }

    /// Reads only the attributes of the previous release's key item, which
    /// macOS allows without a prompt unless the keychain is locked; the key
    /// itself is read on unlock.
    private static func legacyLoginKeychainKey(
        allowsUserInteraction: Bool
    ) -> (wrappedKey: WrappedPayloadKey?, status: OSStatus) {
        // A locked keychain might answer "not found" without asking, which
        // would let a new key shadow the old one. Ask again on Unlock instead.
        if allowsUserInteraction == false, isLoginKeychainUnlocked() == false {
            return (nil, errSecInteractionNotAllowed)
        }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = withUserInteraction(allowed: allowsUserInteraction) {
            SecItemCopyMatching(query as CFDictionary, &item)
        }
        guard status == errSecSuccess, let attributes = item as? [CFString: Any] else {
            return (nil, status)
        }

        // That release always wrote session-only keys. Its metadata item is not
        // read, because reading it would be a second prompt.
        let createdAt = attributes[kSecAttrCreationDate] as? Date ?? .now
        let wrappedKey = WrappedPayloadKey(
            keyVersion: sessionOnlyKeyVersion,
            wrappingPolicy: .keychainThisDeviceOnly,
            wrappedKeyData: Data("keychain:this-device-only".utf8),
            createdAt: createdAt,
            lastWrappedAt: createdAt
        )
        return (wrappedKey, status)
    }

    private static func isLoginKeychainUnlocked() -> Bool {
        var keychain: SecKeychain?
        var status = SecKeychainStatus()
        guard
            SecKeychainCopyDefault(&keychain) == errSecSuccess,
            let keychain,
            SecKeychainGetStatus(keychain, &status) == errSecSuccess
        else {
            return false
        }
        return status & SecKeychainStatus(kSecUnlockStateStatus) != 0
    }

    /// Only affects the login keychain; Data Protection items never prompt.
    private static func withUserInteraction<T>(allowed: Bool, _ body: () -> T) -> T {
        guard allowed == false else {
            return body()
        }
        var wasInteractionAllowed: DarwinBoolean = true
        SecKeychainGetUserInteractionAllowed(&wasInteractionAllowed)
        SecKeychainSetUserInteractionAllowed(false)
        defer { SecKeychainSetUserInteractionAllowed(wasInteractionAllowed.boolValue) }
        return body()
    }

    private static func deleteLegacyLoginKeychainItems() {
        for account in [Constants.fallbackKeyAccount, Constants.metadataAccount] {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: Constants.fallbackKeyService,
                kSecAttrAccount: account
            ]
            let status = withUserInteraction(allowed: false) {
                SecItemDelete(query as CFDictionary)
            }
            if status != errSecSuccess, status != errSecItemNotFound {
                logger.info("App Lock left login keychain item \(account, privacy: .public): \(status, privacy: .public)")
            }
        }
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
        let query = Self.dataProtectionQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount,
            kSecValueData: payloadKeyData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ])

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
        let query = Self.dataProtectionQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount,
            kSecReturnData: true,
            kSecUseAuthenticationContext: context
        ])

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

        let baseQuery = Self.dataProtectionQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.metadataService,
            kSecAttrAccount: Constants.metadataAccount
        ])
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
        let query = Self.dataProtectionQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.fallbackKeyService,
            kSecAttrAccount: Constants.fallbackKeyAccount
        ])
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
        decoder: JSONDecoder
    ) -> (wrappedKey: WrappedPayloadKey?, status: OSStatus) {
        let query = dataProtectionQuery([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Constants.metadataService,
            kSecAttrAccount: Constants.metadataAccount,
            kSecReturnData: true
        ])

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return (nil, status)
        }

        return (try? decoder.decode(WrappedPayloadKeyRecord.self, from: data).materialize(), status)
    }

    /// Falls back to the key file only on errSecMissingEntitlement, and only
    /// when the signature claims no keychain entitlement (ad-hoc builds, and
    /// Developer ID builds re-signed without entitlements). A build that claims
    /// it and still gets errSecMissingEntitlement is misconfigured and gets no
    /// key. Any other status keeps the Data Protection keychain, so such a
    /// build never reads or writes key material outside it. Deleting an item
    /// that is never written has no effect; only the status matters.
    private static func resolveBackend() -> KeychainBackend {
        let probe: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain: true,
            kSecAttrService: Constants.backendProbeService,
            kSecAttrAccount: Constants.backendProbeAccount
        ]
        guard SecItemDelete(probe as CFDictionary) == errSecMissingEntitlement else {
            return .dataProtection
        }
        return signatureClaimsKeychainAccess() == false ? .file : .unavailable
    }

    /// Nil when the signature cannot be read, which counts as claiming it, so
    /// the key file is never used by mistake.
    private static func signatureClaimsKeychainAccess() -> Bool? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard
            SecCodeCopySelf([], &code) == errSecSuccess,
            let code,
            SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
            let staticCode,
            SecCodeCopySigningInformation(
                staticCode,
                SecCSFlags(rawValue: kSecCSSigningInformation),
                &information
            ) == errSecSuccess,
            let information = information as? [String: Any]
        else {
            return nil
        }
        let entitlements = information[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]
        return entitlements["keychain-access-groups"] != nil
            || entitlements["com.apple.application-identifier"] != nil
    }

    /// Without `kSecUseDataProtectionKeychain`, macOS uses the login keychain.
    private static func dataProtectionQuery(_ query: [CFString: Any]) -> [CFString: Any] {
        query.merging([kSecUseDataProtectionKeychain: true]) { _, flag in flag }
    }

    private func makeAuthenticationContext() -> LAContext {
        let context = LAContext()
        context.localizedReason = Constants.unlockPrompt
        return context
    }
}

struct WrappedPayloadKeyRecord: Codable {
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
