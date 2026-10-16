import ApplicationServices
import Foundation
import Security

/// Accessibility access is what lets SlipBoard post ⌘V into the app the user
/// is working in.
enum AccessibilityPermission {
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    private static let trustedBuildDefaultsKey = "SlipBoard.Accessibility.trustedBuild"

    /// Checks without prompting, and remembers which build was trusted so a
    /// later loss of trust after an update can be explained.
    static var isTrusted: Bool {
        let isTrusted = AXIsProcessTrusted()
        if isTrusted, let currentBuild,
           UserDefaults.standard.string(forKey: trustedBuildDefaultsKey) != currentBuild {
            UserDefaults.standard.set(currentBuild, forKey: trustedBuildDefaultsKey)
        }
        return isTrusted
    }

    /// An earlier build was trusted. An ad-hoc signed update has a new code
    /// identity, so the old entry in the list can stay switched on without
    /// applying to this copy. Team-signed builds keep their identity across
    /// updates, so this never applies to them.
    static var wasGrantedToEarlierBuild: Bool {
        guard isAdHocSigned,
              let trustedBuild = UserDefaults.standard.string(forKey: trustedBuildDefaultsKey) else {
            return false
        }
        return trustedBuild != currentBuild
    }

    /// Adds SlipBoard to the Accessibility list. There is no API that does
    /// this without macOS showing its own prompt, so call it only after the
    /// user asked for the settings.
    static func addToSystemList() {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
    }

    /// The code directory hash TCC matches an ad-hoc signed app by.
    private static let currentBuild: String? = {
        guard let unique = signingInformation?[kSecCodeInfoUnique as String] as? Data else { return nil }
        return unique.base64EncodedString()
    }()

    private static let isAdHocSigned: Bool = {
        guard let flags = signingInformation?[kSecCodeInfoFlags as String] as? UInt32 else { return false }
        return flags & SecCodeSignatureFlags.adhoc.rawValue != 0
    }()

    private static let signingInformation: [String: Any]? = {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess else {
            return nil
        }
        return information as? [String: Any]
    }()
}
