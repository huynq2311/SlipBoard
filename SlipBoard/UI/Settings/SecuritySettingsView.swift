import SwiftUI

/// Renders security, app lock authentication, and privacy settings.
public struct SecuritySettingsView<Store: SettingsStoreProtocol>: View {
    @ObservedObject public var settings: Store
    
    public init(settings: Store) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Security")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                Text("Manage application encryption and lock gates.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Divider()
                .background(Theme.borderSecondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Section 1: App Lock Controls
                    VStack(alignment: .leading, spacing: 16) {
                        Text("APP LOCK")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                        
                        Toggle(isOn: $settings.lockSlipboard) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lock Slipboard")
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.textPrimary)
                                Text("Require authentication to open the app and view history.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        
                        if settings.lockSlipboard {
                            Divider()
                                .background(Theme.borderSecondary.opacity(0.4))
                            
                            // Unlock Method selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("UNLOCK METHOD")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textTertiary)
                                
                                Picker("Unlock Method", selection: $settings.unlockMethod) {
                                    ForEach(UnlockMethod.allCases) { method in
                                        Text(method.rawValue).tag(method)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .frame(width: 320)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            
                            Divider()
                                .background(Theme.borderSecondary.opacity(0.4))
                            
                            // Auto Lock Inactivity Timer
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Auto-lock after inactivity")
                                        .fontWeight(.medium)
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Automatically lock history after a period of no interaction.")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                Picker("Auto-lock delay", selection: $settings.autoLockTime) {
                                    ForEach(AutoLockOption.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .frame(width: 140)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.bgSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.borderSecondary.opacity(0.5), lineWidth: 1)
                    )
                    
                    // Section 2: Privacy Mode
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PRIVACY MODE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                        
                        Toggle(isOn: $settings.hidePreviewsInMissionControl) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hide previews in Mission Control / Exposé")
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.textPrimary)
                                Text("Mask windows with a blur overlay when resigned active.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.bgSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.borderSecondary.opacity(0.5), lineWidth: 1)
                    )
                    
                    // Footer Information
                    HStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textTertiary)
                        Text("Key material is protected locally by the macOS Secure Enclave. Cleartext indexing is suspended while history is locked.")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 10)
                }
            }
        }
        .padding(24)
        .background(Theme.bgPrimary)
    }
}
