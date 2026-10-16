import CryptoKit
import Foundation
import Security

/// Checks that the updater plug-in and Sparkle.framework were signed with the
/// running app's own certificate, before AppUpdater loads them.
///
/// Release builds are signed with a self-signed certificate, which has no Team
/// ID, so they carry com.apple.security.cs.disable-library-validation
/// (SlipBoard-NoTeam.entitlements): otherwise macOS refuses to load Sparkle at
/// all. With library validation off, macOS would load any validly signed code
/// from the bundle, so this check puts the same-signer rule back for the only
/// code SlipBoard loads. Sparkle's nested code (its XPC services, Autoupdate and
/// Updater.app) is covered by kSecCSCheckNestedCode: the framework's seal, made
/// with the same certificate, records each nested item as it was when signed.
///
/// This stops code that was replaced before the check. It cannot stop a
/// process that swaps files between the check and the load, nor check the
/// helpers Sparkle starts later from disk (Autoupdate, Updater.app), which run
/// as separate processes.
///
/// A build without a certificate (ad-hoc or unsigned) has nothing to compare
/// against, so it never loads the plug-in and updates stay off.
nonisolated enum UpdaterSignatureCheck {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static let validityFlags = SecCSFlags(
        rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate
            | kSecCSCheckNestedCode | kSecCSRestrictSymlinks
    )

    /// Each item is a bundle and the code signing identifier it must have.
    static func verify(_ items: [(url: URL, identifier: String)]) throws {
        let leafHash = try runningCertificateHash()
        for item in items {
            var staticCode: SecStaticCode?
            try check(SecStaticCodeCreateWithPath(item.url as CFURL, [], &staticCode), "open \(item.url.path)")
            let requirement = try makeRequirement(
                "identifier \"\(item.identifier)\" and certificate leaf = H\"\(leafHash)\""
            )
            var error: Unmanaged<CFError>?
            let status = SecStaticCodeCheckValidityWithErrors(staticCode!, validityFlags, requirement, &error)
            if status != errSecSuccess {
                let detail = error.map { String(describing: $0.takeRetainedValue()) } ?? "OSStatus \(status)"
                throw Failure(description: "\(item.url.lastPathComponent) failed its signature check: \(detail)")
            }
        }
    }

    /// SHA-1 of the running app's leaf certificate, the form the code
    /// requirement language takes. Read from the executable on disk, then
    /// checked against the running process, in case the file was replaced
    /// after launch.
    private static func runningCertificateHash() throws -> String {
        var selfCode: SecCode?
        try check(SecCodeCopySelf([], &selfCode), "read the app's signature")
        var staticSelf: SecStaticCode?
        try check(SecCodeCopyStaticCode(selfCode!, [], &staticSelf), "read the app's signature")
        var info: CFDictionary?
        try check(
            SecCodeCopySigningInformation(staticSelf!, SecCSFlags(rawValue: kSecCSSigningInformation), &info),
            "read the app's signature"
        )
        let certificates = (info as NSDictionary?)?[kSecCodeInfoCertificates] as? [SecCertificate]
        guard let leaf = certificates?.first else {
            throw Failure(description: "this build is not signed with a certificate")
        }
        let digest = Insecure.SHA1.hash(data: SecCertificateCopyData(leaf) as Data)
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        let requirement = try makeRequirement("certificate leaf = H\"\(hash)\"")
        try check(SecCodeCheckValidity(selfCode!, [], requirement), "match the running app to its certificate")
        return hash
    }

    private static func makeRequirement(_ text: String) throws -> SecRequirement {
        var requirement: SecRequirement?
        try check(SecRequirementCreateWithString(text as CFString, [], &requirement), "build requirement \(text)")
        return requirement!
    }

    private static func check(_ status: OSStatus, _ action: String) throws {
        guard status == errSecSuccess else {
            throw Failure(description: "could not \(action): OSStatus \(status)")
        }
    }
}
