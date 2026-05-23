import SwiftUI

/// Renders blacklist rules preventing clipboard tracking in specific applications.
public struct ExclusionsSettingsView<Store: SettingsStoreProtocol>: View {
    @ObservedObject public var settings: Store
    @State private var newAppName = ""
    @State private var newAppBundle = ""
    
    public init(settings: Store) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("App Exclusions")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            Divider()
                .background(Theme.borderSecondary)
            
            Text("SlipBoard will ignore clipboard changes originating from the following applications. Excellent for security vaults and banking tools.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            // List of active exclusions
            VStack(spacing: 0) {
                if settings.excludedApps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "nosign")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.textTertiary)
                            .padding(.top, 24)
                        Text("No apps excluded")
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(settings.excludedApps) { app in
                                ExclusionRow(app: app) {
                                    settings.removeExcludedApp(app)
                                }
                                if app.id != settings.excludedApps.last?.id {
                                    Divider()
                                        .background(Theme.borderSecondary.opacity(0.4))
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
            .background(Theme.bgSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.borderSecondary.opacity(0.5), lineWidth: 1)
            )
            
            // Add new app section
            VStack(alignment: .leading, spacing: 12) {
                Text("Add Custom App Exclusion")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                
                HStack(spacing: 12) {
                    TextField("App Name (e.g. Dashlane)", text: $newAppName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                    
                    TextField("Bundle Identifier", text: $newAppBundle)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                    
                    Button(action: addExclusion) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(newAppName.isEmpty || newAppBundle.isEmpty)
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
            
            Spacer()
        }
        .padding(24)
        .background(Theme.bgPrimary)
    }
    
    private func addExclusion() {
        let trimmedName = newAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBundle = newAppBundle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty && !trimmedBundle.isEmpty else { return }
        
        let newApp = ExcludedApp(name: trimmedName, bundleIdentifier: trimmedBundle, category: "Utility")
        settings.addExcludedApp(newApp)
        
        newAppName = ""
        newAppBundle = ""
    }
}

/// Helper view representing a row inside the exclusion list.
struct ExclusionRow: View {
    let app: ExcludedApp
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "nosign")
                .foregroundColor(Theme.textTertiary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                Text(app.bundleIdentifier)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            MonospacedBadge(app.category, textColor: Theme.textSecondary, backgroundColor: Theme.bgTertiary)
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
