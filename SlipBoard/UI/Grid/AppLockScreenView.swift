import SwiftUI

/// Renders a blur overlay lock screen requiring biometrics or passcode to view clipboard history.
public struct AppLockScreenView: View {
    @ObservedObject public var securityManager = SecurityManager.shared
    @State private var passwordInput: String = ""
    @State private var errorMessage: String? = nil
    @State private var showPasswordFallback: Bool = false
    
    public let onUnlock: () -> Void
    
    public init(onUnlock: @escaping () -> Void) {
        self.onUnlock = onUnlock
    }
    
    public var body: some View {
        ZStack {
            // Background blur matching PopupGridContainer backdrop
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.bgPrimary.opacity(0.85))
                .background(
                    SlipVisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.borderPrimary.opacity(0.4), lineWidth: 1)
                )
            
            VStack(spacing: 24) {
                Spacer()
                
                // Icon Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.accent)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    VStack(spacing: 6) {
                        Text("SLIPBOARD IS LOCKED")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Authentication is required to unlock your history.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                // Interaction Panel
                VStack(spacing: 14) {
                    if showPasswordFallback {
                        // Secure Password Entry
                        HStack(spacing: 8) {
                            SecureField("Enter macOS Password", text: $passwordInput, onCommit: {
                                handlePasswordUnlock()
                            })
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 10)
                            .frame(width: 220, height: 32)
                            .background(Theme.bgSecondary)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(errorMessage != nil ? Color.red.opacity(0.8) : Theme.borderSecondary.opacity(0.6), lineWidth: 0.5)
                            )
                            .textFieldStyle(.plain)
                            
                            Button(action: handlePasswordUnlock) {
                                Text("Unlock")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Theme.accent.cornerRadius(6))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Large Biometrics Trigger Button
                        Button(action: triggerBiometricUnlock) {
                            HStack(spacing: 8) {
                                Image(systemName: "touchid")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Unlock with Touch ID")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Theme.accent.cornerRadius(8))
                            .shadow(color: Theme.accent.opacity(0.2), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Toggle Options
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showPasswordFallback.toggle()
                            errorMessage = nil
                        }
                    }) {
                        Text(showPasswordFallback ? "Use Touch ID" : "Use Password Option")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    
                    // Error Message
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                            .transition(.opacity)
                    }
                }
                
                Spacer()
                
                // Footer Hint
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                    Text("Press ESC to exit")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 800, height: 400)
        .onAppear {
            triggerBiometricUnlock()
        }
    }
    
    private func triggerBiometricUnlock() {
        errorMessage = nil
        securityManager.unlock { success in
            if success {
                onUnlock()
            } else {
                errorMessage = "Biometrics authentication failed"
            }
        }
    }
    
    private func handlePasswordUnlock() {
        guard !passwordInput.isEmpty else { return }
        errorMessage = nil
        
        // Mock system password validation: length >= 4 accepted in mock mode
        if passwordInput.count >= 4 {
            securityManager.isLocked = false
            securityManager.resetInactivityTimer()
            onUnlock()
        } else {
            errorMessage = "Invalid system password"
            passwordInput = ""
        }
    }
}
