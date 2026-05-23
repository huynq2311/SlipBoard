import SwiftUI

/// Renders iCloud Sync and connected mobile devices bridge preferences.
public struct BridgeSettingsView<Store: SettingsStoreProtocol>: View {
    @ObservedObject public var settings: Store
    
    public init(settings: Store) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("iCloud Bridge")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            Divider()
                .background(Theme.borderSecondary)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $settings.enableBridge) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable iCloud Sync Bridge")
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                        Text("Securely synchronize your snippets and clipboard metadata across your iOS devices using private CloudKit containers.")
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
            
            if settings.enableBridge {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Linked Devices")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    VStack(spacing: 0) {
                        DeviceRow(name: "iPhone 16 Pro", type: "Mobile Companion", lastSynced: "Just Now", isOnline: true)
                        Divider()
                            .background(Theme.borderSecondary.opacity(0.4))
                        DeviceRow(name: "iPad Air M2", type: "Tablet Companion", lastSynced: "5 minutes ago", isOnline: true)
                        Divider()
                            .background(Theme.borderSecondary.opacity(0.4))
                        DeviceRow(name: "MacBook Air (Office)", type: "Secondary Desktop", lastSynced: "Yesterday", isOnline: false)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.bgSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.borderSecondary.opacity(0.5), lineWidth: 1)
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.top, 40)
                    Text("Sync Disabled")
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textSecondary)
                    Text("Turn on iCloud Sync to backup your snippets and access history across all your active Apple devices.")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
            }
            
            Spacer()
        }
        .padding(24)
        .background(Theme.bgPrimary)
    }
}

/// Helper view for rendering mobile device status rows.
struct DeviceRow: View {
    let name: String
    let type: String
    let lastSynced: String
    let isOnline: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isOnline ? "apple.logo" : "desktopcomputer")
                .font(.title2)
                .foregroundColor(isOnline ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                Text(type)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(isOnline ? Color.green : Theme.textTertiary)
                    .frame(width: 8, height: 8)
                
                Text(lastSynced)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
