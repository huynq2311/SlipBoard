import SwiftUI

/// Renders general startup, layout, and theme preferences.
public struct GeneralSettingsView<Store: SettingsStoreProtocol>: View {
    @ObservedObject public var settings: Store
    
    public init(settings: Store) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            Divider()
                .background(Theme.borderSecondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Launch at login
                Toggle(isOn: $settings.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                        Text("Start SlipBoard automatically when you sign in to your Mac.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                
                Divider()
                    .background(Theme.borderSecondary.opacity(0.4))
                
                // Show Dock Icon
                Toggle(isOn: $settings.showDockIcon) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Dock Icon")
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                        Text("Keep SlipBoard in your Dock in addition to the Menu Bar.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                
                Divider()
                    .background(Theme.borderSecondary.opacity(0.4))
                
                // Menu Bar badge
                Toggle(isOn: $settings.menuBarBadge) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Menu Bar Item Count")
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                        Text("Display the active count of captured items next to the icon.")
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
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Appearance Theme")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                
                Picker("Theme Selection", selection: $settings.theme) {
                    ForEach(ThemeOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 320)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(24)
        .background(Theme.bgPrimary)
    }
}
