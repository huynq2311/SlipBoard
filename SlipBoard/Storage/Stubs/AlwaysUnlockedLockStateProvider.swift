import Foundation

final class AlwaysUnlockedLockStateProvider: LockStateProviding, @unchecked Sendable {
    var isLocked: Bool {
        return false
    }
    
    var onLockStateChanged: (@Sendable (Bool) -> Void)?
    
    init() {}
}

