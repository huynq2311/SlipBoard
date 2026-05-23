import Foundation
import Security

/// A helper class managing the storage of the AES-256 master key in the macOS Keychain.
public class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private let service = "com.huynq.SlipBoard.masterkey"
    private let account = "masterkey"
    
    private init() {}
    
    /// Retrieves the master key from the Keychain.
    /// - Returns: The 256-bit key data if found, nil otherwise.
    public func getMasterKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    /// Generates a new cryptographically secure 256-bit master key and saves it in the Keychain.
    /// - Returns: The generated key data if successful, nil otherwise.
    public func generateAndStoreMasterKey() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { return nil }
        let keyData = Data(bytes)
        
        // Ensure any old item is removed
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Save the new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return keyData
        }
        return nil
    }
}
