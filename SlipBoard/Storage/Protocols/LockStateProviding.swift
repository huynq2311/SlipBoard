import Foundation

protocol LockStateProviding: Sendable {
    var isLocked: Bool { get }
    var onLockStateChanged: (@Sendable (Bool) -> Void)? { get set }
}

