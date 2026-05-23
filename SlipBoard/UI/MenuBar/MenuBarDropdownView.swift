import SwiftUI

/// The custom interactive dropdown UI for the macOS Menu Bar.
public struct MenuBarDropdownView<Store: SettingsStoreProtocol, Stats: HistoryStatsProvider>: View {
    @ObservedObject public var settings: Store
    @ObservedObject public var stats: Stats
    @ObservedObject private var securityManager = SecurityManager.shared
    
    @Environment(\.openWindow) private var openWindow
    @State private var hoverItem: String? = nil
    @State private var showPauseSubmenu: Bool = false
    
    public init(settings: Store, stats: Stats) {
        self.settings = settings
        self.stats = stats
    }
    
    private var isPaused: Bool {
        settings.pauseCapture || (settings.pauseUntil != nil && settings.pauseUntil! > Date())
    }
    
    private var activePauseOption: String? {
        guard let pauseUntil = settings.pauseUntil else { return nil }
        let remaining = pauseUntil.timeIntervalSinceNow
        guard remaining > 0 else { return nil }
        
        if remaining <= 900 {
            return "15m"
        } else if remaining <= 3600 {
            return "1h"
        } else {
            return "tomorrow"
        }
    }
    
    private func togglePause(minutes: Double) {
        if activePauseOption == (minutes == 15 ? "15m" : "1h") {
            settings.pauseCapture = false
            settings.pauseUntil = nil
        } else {
            settings.pauseCapture = false
            settings.pauseUntil = Date().addingTimeInterval(minutes * 60)
        }
    }
    
    private func togglePauseUntilTomorrow() {
        if activePauseOption == "tomorrow" {
            settings.pauseCapture = false
            settings.pauseUntil = nil
        } else {
            settings.pauseCapture = false
            let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            settings.pauseUntil = tomorrow
        }
    }
    
    private func togglePauseIndefinitely() {
        if settings.pauseCapture && settings.pauseUntil == nil {
            settings.pauseCapture = false
            settings.pauseUntil = nil
        } else {
            settings.pauseCapture = true
            settings.pauseUntil = nil
        }
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
                    if securityManager.isLocked {
                        Text("Locked")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textTertiary)
                    } else {
                        HStack(spacing: 4) {
                            Text("\(stats.totalItemsCount)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)
                            Text("items captured")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
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
            .background(securityManager.isLocked ? Theme.bgTertiary : Theme.bgSecondary)
            
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
                    PopupPanelManager.shared.toggle()
                }
                .onHover { isHovered in hoverItem = isHovered ? "open" : nil }
                
                // Command: Pause Capturing (Accordion)
                VStack(spacing: 2) {
                    Button(action: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                            showPauseSubmenu.toggle()
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(hoverItem == "pause" ? Theme.textPrimary : Theme.textSecondary)
                                .frame(width: 18)
                            
                            Text("Pause Capturing")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(hoverItem == "pause" ? .semibold : .medium)
                                .foregroundColor(hoverItem == "pause" ? Theme.textPrimary : Theme.textPrimary)
                            
                            Spacer()
                            
                            Image(systemName: showPauseSubmenu ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(hoverItem == "pause" ? Theme.bgTertiary : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in hoverItem = isHovered ? "pause" : nil }
                    
                    if showPauseSubmenu {
                        VStack(alignment: .leading, spacing: 2) {
                            DropdownSubmenuItemRow(
                                title: "Pause for 15 minutes",
                                isActive: activePauseOption == "15m",
                                isHovered: hoverItem == "pause_15m"
                            ) {
                                togglePause(minutes: 15)
                            }
                            .onHover { isHovered in hoverItem = isHovered ? "pause_15m" : nil }
                            
                            DropdownSubmenuItemRow(
                                title: "Pause for 1 hour",
                                isActive: activePauseOption == "1h",
                                isHovered: hoverItem == "pause_1h"
                            ) {
                                togglePause(minutes: 60)
                            }
                            .onHover { isHovered in hoverItem = isHovered ? "pause_1h" : nil }
                            
                            DropdownSubmenuItemRow(
                                title: "Pause until tomorrow",
                                isActive: activePauseOption == "tomorrow",
                                isHovered: hoverItem == "pause_tomorrow"
                            ) {
                                togglePauseUntilTomorrow()
                            }
                            .onHover { isHovered in hoverItem = isHovered ? "pause_tomorrow" : nil }
                            
                            DropdownSubmenuItemRow(
                                title: "Pause indefinitely",
                                isActive: settings.pauseCapture && settings.pauseUntil == nil,
                                isHovered: hoverItem == "pause_indefinitely"
                            ) {
                                togglePauseIndefinitely()
                            }
                            .onHover { isHovered in hoverItem = isHovered ? "pause_indefinitely" : nil }
                        }
                        .padding(.leading, 18)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
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
                
                if settings.lockSlipboard {
                    DropdownItemRow(
                        title: securityManager.isLocked ? "Unlock Slipboard" : "Lock Slipboard",
                        icon: securityManager.isLocked ? "lock.open" : "lock",
                        shortcut: "",
                        isHovered: hoverItem == "lock_toggle"
                    ) {
                        if securityManager.isLocked {
                            PopupPanelManager.shared.toggle()
                        } else {
                            SecurityManager.shared.lock()
                        }
                    }
                    .onHover { isHovered in hoverItem = isHovered ? "lock_toggle" : nil }
                }
                
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
                
                if !shortcut.isEmpty {
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

/// A custom sub-item row for accordion dropdown options.
struct DropdownSubmenuItemRow: View {
    let title: String
    let isActive: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.orange)
                        .frame(width: 14)
                } else {
                    Spacer()
                        .frame(width: 14)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isHovered ? Theme.textPrimary : Theme.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered ? Theme.bgTertiary : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
