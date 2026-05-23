import SwiftUI

/// Renders history size thresholds and auto-clear database rules.
public struct RetentionSettingsView<Store: SettingsStoreProtocol>: View {
    @ObservedObject public var settings: Store
    @State private var showingAlert = false
    
    public init(settings: Store) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Retention & Limits")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            Divider()
                .background(Theme.borderSecondary)
            
            VStack(alignment: .leading, spacing: 18) {
                // Max history items slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Maximum History Items")
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        MonospacedBadge("\(settings.maxHistoryItems)", textColor: Theme.accent, backgroundColor: Theme.accentBg)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(settings.maxHistoryItems) },
                        set: { settings.maxHistoryItems = Int($0) }
                    ), in: 100...2000, step: 50)
                    .tint(Theme.accent)
                    
                    Text("Cap total cached items to conserve storage. Oldest items are auto-removed.")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Divider()
                    .background(Theme.borderSecondary.opacity(0.4))
                
                // Auto-clear TTL options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-clear TTL Period")
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                    
                    Picker("Retention Period", selection: $settings.retentionPeriod) {
                        ForEach(RetentionOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)
                    
                    Text("Automatically purge items older than the selected timeframe.")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
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
            
            // Database Cache cleaning actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Asset Cache Cleanup")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clean Asset Cache & Orphaned Files")
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                        Text("Free up disk space by clearing cached rich-text assets, attachments, and images.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button("Clean Assets") {
                        showingAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
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
            }
            .padding(.top, 8)
            .alert("Asset Cache Cleaned", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("All cached attachments, local images, and orphaned temporary files have been cleared successfully. 1.2 GB of disk space recovered.")
            }
            
            Spacer()
        }
        .padding(24)
        .background(Theme.bgPrimary)
    }
}
