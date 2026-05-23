import Foundation
import LocalAuthentication
import Combine

/// Manages the locked/unlocked state of SlipBoard, biometric auth, and inactivity timers.
public class SecurityManager: ObservableObject {
    public static let shared = SecurityManager()
    
    @Published public var isLocked: Bool = false
    
    private var settings: (any SettingsStoreProtocol)?
    private var autoLockTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Configures the security manager with settings.
    public func configure(with settings: any SettingsStoreProtocol) {
        self.settings = settings
        
        // Listen to settings changes using generic helper
        subscribeToChanges(settings)
    }
    
    private func subscribeToChanges<T: ObservableObject>(_ settings: T) {
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resetInactivityTimer()
            }
            .store(in: &cancellables)
    }
    
    /// Locks the application.
    public func lock() {
        guard settings?.lockSlipboard == true else { return }
        DispatchQueue.main.async {
            self.isLocked = true
            self.autoLockTimer?.invalidate()
            self.autoLockTimer = nil
            NotificationCenter.default.post(name: .slipBoardDidLock, object: nil)
        }
    }
    
    /// Prompts the user to unlock using Touch ID or password.
    public func unlock(completion: @escaping (Bool) -> Void) {
        guard isLocked else {
            completion(true)
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        if settings?.unlockMethod == .touchID && context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock SlipBoard History") { success, evaluationError in
                DispatchQueue.main.async {
                    if success {
                        self.isLocked = false
                        self.resetInactivityTimer()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
        } else {
            // Fallback to system password (device owner authentication)
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock SlipBoard History") { success, evaluationError in
                    DispatchQueue.main.async {
                        if success {
                            self.isLocked = false
                            self.resetInactivityTimer()
                            completion(true)
                        } else {
                            completion(false)
                        }
                    }
                }
            } else {
                // If LA is completely unavailable (e.g. simulator/CI), auto-unlock for safety in development
                DispatchQueue.main.async {
                    self.isLocked = false
                    self.resetInactivityTimer()
                    completion(true)
                }
            }
        }
    }
    
    /// Resets the auto-lock timer based on user preference.
    public func resetInactivityTimer() {
        guard let settings = settings, settings.lockSlipboard, !isLocked else {
            autoLockTimer?.invalidate()
            autoLockTimer = nil
            return
        }
        
        autoLockTimer?.invalidate()
        
        let interval: TimeInterval
        switch settings.autoLockTime {
        case .never:
            return
        case .oneMin:
            interval = 60
        case .fiveMin:
            interval = 300
        case .fifteenMin:
            interval = 900
        case .oneHour:
            interval = 3600
        }
        
        autoLockTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.lock()
        }
    }
}

public extension Notification.Name {
    static let slipBoardDidLock = Notification.Name("com.huynq.SlipBoard.didLock")
}
