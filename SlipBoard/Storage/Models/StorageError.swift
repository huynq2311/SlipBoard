import Foundation

enum StorageError: Error, Equatable, Sendable {
    case databaseError(code: Int32, message: String)
    case locked
    case payloadNotFound(hash: String)
    case assetNotFound(itemID: String)
    case writeFailed(reason: String)
    case readFailed(reason: String)
    case migrationFailed(version: Int, reason: String)
}

