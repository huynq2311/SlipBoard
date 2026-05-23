import SwiftUI

/// Supported settings navigation tabs
public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case bridge = "iCloud Bridge"
    case security = "Security"
    case retention = "Retention"
    case exclusions = "Exclusions"
    case hotkeys = "Hotkeys"
    case snippets = "Snippets"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .bridge: return "icloud.and.arrow.up"
        case .security: return "shield.lock"
        case .retention: return "clock"
        case .exclusions: return "nosign"
        case .hotkeys: return "keyboard"
        case .snippets: return "curlybraces"
        }
    }
}

/// The unified settings window shell, composing all preference pane subviews.
public struct SettingsWindowView<Store: SettingsStoreProtocol>: View {
    @ObservedObject public var settings: Store
    @State private var activeTab: SettingsTab = .general
    
    public init(settings: Store) {
        self.settings = settings
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Sidebar Navigation
            VStack(alignment: .leading, spacing: 6) {
                // Branding Header
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                        .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text("SlipBoard Settings")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Tabs List
                ForEach(SettingsTab.allCases) { tab in
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(activeTab == tab ? .white : Theme.textSecondary)
                            .frame(width: 18)
                        
                        Text(tab.rawValue)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(activeTab == tab ? .semibold : .medium)
                            .foregroundColor(activeTab == tab ? .white : Theme.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(activeTab == tab ? Theme.accent : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.12)) {
                            activeTab = tab
                        }
                    }
                }
                
                Spacer()
                
                // Footer
                VStack(alignment: .leading, spacing: 4) {
                    Text("SlipBoard v0.8")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Theme.textTertiary)
                    Text("Local-first Clipboard")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            .frame(width: 172)
            .padding(.horizontal, 8)
            .background(Theme.bgSecondary)
            .overlay(
                HStack {
                    Spacer()
                    Divider()
                        .background(Theme.borderSecondary.opacity(0.6))
                }
            )
            
            // Detail Content Panel
            ZStack {
                switch activeTab {
                case .general:
                    GeneralSettingsView(settings: settings)
                case .bridge:
                    BridgeSettingsView(settings: settings)
                case .security:
                    SecuritySettingsView(settings: settings)
                case .retention:
                    RetentionSettingsView(settings: settings)
                case .exclusions:
                    ExclusionsSettingsView(settings: settings)
                case .hotkeys:
                    HotkeysSettingsView(settings: settings)
                case .snippets:
                    SnippetsSettingsView(settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bgPrimary)
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(Theme.bgPrimary)
    }
}
