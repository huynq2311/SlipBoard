import Darwin
import Foundation

/// The payload key and its record for builds without the keychain entitlement
/// (ad-hoc builds), kept in one file that only this user can read.
///
/// The login keychain ties an item to the exact build that created it, so on
/// ad-hoc builds every update asked for the login password again. A file has no
/// such tie, but it sits next to the encrypted payloads: anyone who can read this
/// user's files can read the key too. Note encryption on these builds only keeps
/// notes out of casual view, and App Lock stays a lock on the window.
struct PayloadKeyFile {
    enum ReadResult {
        case found(WrappedPayloadKey, keyData: Data)
        case missing
        /// The file exists but is not a readable key file owned by this user. It
        /// is kept, as a keychain item that cannot be read is kept.
        case unreadable
    }

    private struct Contents: Codable {
        var formatVersion: Int
        var key: WrappedPayloadKeyRecord
        var keyData: Data
    }

    private static let formatVersion = 1
    private static let maximumFileSize = 64 * 1024

    let url: URL
    let keySize: Int

    static func defaultURL(fileManager: FileManager = .default) -> URL {
        let applicationSupportURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return applicationSupportURL
            .appendingPathComponent("SlipBoard", isDirectory: true)
            .appendingPathComponent("PayloadKey.json")
    }

    func read() -> ReadResult {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else {
            return errno == ENOENT ? .missing : .unreadable
        }
        defer { close(descriptor) }

        var info = stat()
        guard
            fstat(descriptor, &info) == 0,
            info.st_mode & S_IFMT == S_IFREG,
            info.st_uid == getuid(),
            info.st_size <= Self.maximumFileSize
        else {
            return .unreadable
        }
        if info.st_mode & 0o077 != 0, fchmod(descriptor, 0o600) != 0 {
            return .unreadable
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        guard
            let data = try? handle.readToEnd(),
            let contents = try? JSONDecoder().decode(Contents.self, from: data),
            contents.formatVersion == Self.formatVersion,
            contents.keyData.count == keySize
        else {
            return .unreadable
        }

        return .found(contents.key.materialize(), keyData: contents.keyData)
    }

    /// Writes a temporary file created with mode 0600 and renames it over the
    /// key file, so a crash leaves either the old key or the new one.
    func write(_ wrappedKey: WrappedPayloadKey, keyData: Data) -> Bool {
        let contents = Contents(
            formatVersion: Self.formatVersion,
            key: WrappedPayloadKeyRecord(wrappedKey: wrappedKey),
            keyData: keyData
        )
        guard let data = try? JSONEncoder().encode(contents) else {
            return false
        }

        let directoryURL = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            return false
        }
        guard chmod(directoryURL.path, 0o700) == 0 else {
            return false
        }

        let temporaryPath = directoryURL
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
            .path
        let descriptor = open(temporaryPath, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            return false
        }

        let isWritten = fchmod(descriptor, 0o600) == 0
            && Self.writeAll(data, to: descriptor)
            && fsync(descriptor) == 0
        close(descriptor)

        guard isWritten, rename(temporaryPath, url.path) == 0 else {
            unlink(temporaryPath)
            return false
        }

        // Makes the rename itself survive a crash or power loss.
        let directoryDescriptor = open(directoryURL.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        if directoryDescriptor >= 0 {
            fsync(directoryDescriptor)
            close(directoryDescriptor)
        }
        return true
    }

    private static func writeAll(_ data: Data, to descriptor: Int32) -> Bool {
        data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(descriptor, buffer.baseAddress! + offset, buffer.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    return false
                }
                offset += written
            }
            return true
        }
    }
}
