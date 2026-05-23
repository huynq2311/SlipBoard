import SwiftUI

/// The custom interactive dropdown UI for the macOS Menu Bar.
public struct MenuBarDropdownView<Store: SettingsStoreProtocol, Stats: HistoryStatsProvider>: View {
    @ObservedObject public var settings: Store
    @ObservedObject public var stats: Stats
    
    @Environment(\.openWindow) private var openWindow
    @State private var isPaused = false
    @State private var hoverItem: String? = nil
    
    public init(settings: Store, stats: Stats) {
        self.settings = settings
        self.stats = stats
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header stats block
            HStack(spacing: 12) {
                // Clipboard Icon
                Image(systemName: "doc.on.clipboard")
                    .font(.title2)
                    .foregroundColor(Theme.accent)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(stats.totalItemsCount)")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                        Text("items captured")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Text("Auto-clear in \(settings.retentionPeriod.label)")
                        .font(.caption2)
                        .foregroundColor(Theme.textTertiary)
                }
                
                Spacer()
                
                // Status Indicator
                HStack(spacing: 5) {
                    Circle()
                        .fill(isPaused ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(isPaused ? "Paused" : "Active")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isPaused ? Color.orange : Color.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isPaused ? Color.orange.opacity(0.12) : Color.green.opacity(0.12))
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.bgSecondary)
            
            Divider()
                .background(Theme.borderSecondary)
            
            // Quick Retention Pills Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK RETENTION LIMIT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.leading, 4)
                
                SegmentedPillControl(
                    selection: $settings.retentionPeriod,
                    options: RetentionOption.allCases,
                    title: { $0.rawValue }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(Theme.borderSecondary)
            
            // Action Menu Items list
            VStack(spacing: 2) {
                // Command: Open Slipboard
                DropdownItemRow(
                    title: "Open Slipboard Popup",
                    icon: "rectangle.grid.3x2",
                    shortcut: "⌘⇧V",
                    isHovered: hoverItem == "open"
                ) {
                    // Trigger popup action
                }
                .onHover { isHovered in hoverItem = isHovered ? "open" : nil }
                
                // Command: Pause Capture
                DropdownItemRow(
                    title: isPaused ? "Resume Capturing" : "Pause Capturing",
                    icon: isPaused ? "play.fill" : "pause.fill",
                    shortcut: "⌘⌃P",
                    isHovered: hoverItem == "pause"
                ) {
                    withAnimation {
                        isPaused.toggle()
                    }
                }
                .onHover { isHovered in hoverItem = isHovered ? "pause" : nil }
                
                // Command: Settings
                DropdownItemRow(
                    title: "Settings...",
                    icon: "gearshape",
                    shortcut: "⌘,",
                    isHovered: hoverItem == "settings"
                ) {
                    #if os(macOS)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    #endif
                    openWindow(id: "settings-window")
                }
                .onHover { isHovered in hoverItem = isHovered ? "settings" : nil }
                
                Divider()
                    .background(Theme.borderSecondary.opacity(0.6))
                    .padding(.vertical, 4)
                
                // Command: Quit
                DropdownItemRow(
                    title: "Quit Slipboard",
                    icon: "power",
                    shortcut: "⌘Q",
                    isHovered: hoverItem == "quit",
                    role: .destructive
                ) {
                    #if os(macOS)
                    NSApplication.shared.terminate(nil)
                    #endif
                }
                .onHover { isHovered in hoverItem = isHovered ? "quit" : nil }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(Theme.bgPrimary)
    }
}

/// A highly polished clickable row for dropdown options.
struct DropdownItemRow: View {
    let title: String
    let icon: String
    let shortcut: String
    let isHovered: Bool
    var role: ButtonRole? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(role == .destructive ? .red : (isHovered ? Theme.textPrimary : Theme.textSecondary))
                    .frame(width: 18)
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(isHovered ? .semibold : .medium)
                    .foregroundColor(role == .destructive ? .red : (isHovered ? Theme.textPrimary : Theme.textPrimary))
                
                Spacer()
                
                Text(shortcut)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(isHovered ? Theme.textSecondary : Theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isHovered ? Theme.bgSecondary : Theme.bgTertiary)
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Theme.bgTertiary : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
