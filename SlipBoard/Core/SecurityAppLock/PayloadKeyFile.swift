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
        /// The file could not be read for a reason that may go away: access
        /// rights, another owner, a symlink, an I/O error, or a format from a
        /// newer build. It is never replaced, as a keychain item that cannot be
        /// read is never replaced.
        case inaccessible
        /// The file is not a key file this build can parse. It may be moved
        /// aside, never deleted, before a new key is written.
        case corrupt(FileIdentity)
    }

    /// Tells the file that was read apart from one another instance put at
    /// the same path afterwards.
    struct FileIdentity: Equatable {
        let device: dev_t
        let inode: ino_t

        init(_ info: stat) {
            device = info.st_dev
            inode = info.st_ino
        }
    }

    enum MoveAsideResult {
        case moved
        /// The file at the path is no longer the one that was read; it was
        /// left in place.
        case changed
        case failed
    }

    /// Runs `body` while holding an exclusive lock that every SlipBoard
    /// instance takes before writing, replacing or moving the key file, so
    /// reading, moving aside and creating the file happen as one step. Nil if
    /// the lock could not be taken. Not reentrant: `body` must not take it again.
    func withExclusiveLock<T>(_ body: () -> T) -> T? {
        guard let directoryURL = makeDirectory() else {
            return nil
        }
        let lockPath = directoryURL.appendingPathComponent(".\(url.lastPathComponent).lock").path
        let descriptor = open(lockPath, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            return nil
        }
        defer { close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else {
                return nil
            }
        }
        defer { flock(descriptor, LOCK_UN) }
        return body()
    }

    private struct FormatHeader: Codable {
        var formatVersion: Int
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
            return errno == ENOENT ? .missing : .inaccessible
        }
        defer { close(descriptor) }

        var info = stat()
        guard
            fstat(descriptor, &info) == 0,
            info.st_mode & S_IFMT == S_IFREG,
            info.st_uid == getuid()
        else {
            return .inaccessible
        }
        guard info.st_size <= Self.maximumFileSize else {
            return .corrupt(FileIdentity(info))
        }
        if info.st_mode & 0o077 != 0, fchmod(descriptor, 0o600) != 0 {
            return .inaccessible
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        guard let data = try? handle.readToEnd() else {
            return .inaccessible
        }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(FormatHeader.self, from: data) else {
            return .corrupt(FileIdentity(info))
        }
        guard header.formatVersion <= Self.formatVersion else {
            return .inaccessible
        }
        guard
            header.formatVersion == Self.formatVersion,
            let contents = try? decoder.decode(Contents.self, from: data),
            contents.keyData.count == keySize
        else {
            return .corrupt(FileIdentity(info))
        }

        return .found(contents.key.materialize(), keyData: contents.keyData)
    }

    enum CreateResult {
        case created
        /// Another SlipBoard instance wrote a key file first; it was left as is.
        case alreadyExists
        case failed
    }

    /// Writes a temporary file created with mode 0600 and renames it over the
    /// key file, so a crash leaves either the old key or the new one. Only for
    /// rewriting the key already in use.
    func write(_ wrappedKey: WrappedPayloadKey, keyData: Data) -> Bool {
        publish(wrappedKey, keyData: keyData, replacingExisting: true) == .created
    }

    /// Writes a new key only if there is no key file yet. Two instances
    /// creating a key at the same time would otherwise each encrypt notes with
    /// their own key while only the last one written survives.
    func create(_ wrappedKey: WrappedPayloadKey, keyData: Data) -> CreateResult {
        publish(wrappedKey, keyData: keyData, replacingExisting: false)
    }

    private func publish(_ wrappedKey: WrappedPayloadKey, keyData: Data, replacingExisting: Bool) -> CreateResult {
        let contents = Contents(
            formatVersion: Self.formatVersion,
            key: WrappedPayloadKeyRecord(wrappedKey: wrappedKey),
            keyData: keyData
        )
        guard let data = try? JSONEncoder().encode(contents) else {
            return .failed
        }

        guard let directoryURL = makeDirectory() else {
            return .failed
        }

        let temporaryPath = directoryURL
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
            .path
        let descriptor = open(temporaryPath, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            return .failed
        }

        let isWritten = fchmod(descriptor, 0o600) == 0
            && Self.writeAll(data, to: descriptor)
            && Self.syncToDisk(descriptor)
        close(descriptor)

        guard isWritten else {
            unlink(temporaryPath)
            return .failed
        }
        let isPublished = replacingExisting
            ? rename(temporaryPath, url.path) == 0
            : renamex_np(temporaryPath, url.path, UInt32(RENAME_EXCL)) == 0
        guard isPublished else {
            let isTaken = replacingExisting == false && errno == EEXIST
            unlink(temporaryPath)
            return isTaken ? .alreadyExists : .failed
        }

        // Makes the rename itself survive a crash or power loss.
        let directoryDescriptor = open(directoryURL.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryDescriptor >= 0 else {
            return .failed
        }
        defer { close(directoryDescriptor) }
        return Self.syncToDisk(directoryDescriptor) ? .created : .failed
    }

    /// Keeps a file that could not be parsed as `PayloadKey.unreadable-<time>.json`
    /// next to it, so writing a new key never destroys the old one.
    ///
    /// Only the file that was read is moved: another instance may have moved
    /// it aside and written its new key there in the meantime. Call it under
    /// `withExclusiveLock`, together with the read that returned `expected`.
    func moveAside(_ expected: FileIdentity) -> MoveAsideResult {
        guard Self.identity(at: url.path) == expected else {
            return .changed
        }

        let directoryURL = url.deletingLastPathComponent()
        let stamp = Int64(Date().timeIntervalSince1970 * 1000)
        let destination = directoryURL
            .appendingPathComponent("\(url.deletingPathExtension().lastPathComponent).unreadable-\(stamp).json")
        guard renamex_np(url.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
            return errno == ENOENT ? .changed : .failed
        }

        let directoryDescriptor = open(directoryURL.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryDescriptor >= 0 else {
            return .failed
        }
        defer { close(directoryDescriptor) }
        return Self.syncToDisk(directoryDescriptor) ? .moved : .failed
    }

    private func makeDirectory() -> URL? {
        let directoryURL = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            return nil
        }
        return chmod(directoryURL.path, 0o700) == 0 ? directoryURL : nil
    }

    private static func identity(at path: String) -> FileIdentity? {
        var info = stat()
        guard lstat(path, &info) == 0 else {
            return nil
        }
        return FileIdentity(info)
    }

    /// On macOS fsync only reaches the drive's cache; F_FULLFSYNC flushes it.
    /// fsync is used only where the file system does not support F_FULLFSYNC.
    private static func syncToDisk(_ descriptor: Int32) -> Bool {
        if fcntl(descriptor, F_FULLFSYNC) == 0 {
            return true
        }
        switch errno {
        case ENOTSUP, EOPNOTSUPP, EINVAL, ENOTTY:
            return fsync(descriptor) == 0
        default:
            return false
        }
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
