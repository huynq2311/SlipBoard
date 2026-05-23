import SwiftUI

/// Renders interactive keyboard shortcut options for global commands.
public struct HotkeysSettingsView<Store: SettingsStoreProtocol>: View {
    @ObservedObject public var settings: Store
    @State private var recordingField: String? = nil
    
    // In-memory mock shortcuts
    @State private var openShortcut = "⌘ ⇧ V"
    @State private var pasteAsShortcut = "⌘ ⌥ V"
    @State private var pauseShortcut = "⌘ ⌃ P"
    
    public init(settings: Store) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keyboard Shortcuts")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            Divider()
                .background(Theme.borderSecondary)
            
            Text("Trigger SlipBoard instantaneously from anywhere on your Mac using global shortcuts.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            VStack(spacing: 16) {
                // Shortcut 1: Open Popover
                HotkeyRecorderRow(
                    label: "Open Slipboard Popup",
                    description: "Bring up the quick-pasting history grid.",
                    shortcut: openShortcut,
                    isRecording: recordingField == "open"
                ) {
                    toggleRecording(field: "open")
                }
                
                Divider()
                    .background(Theme.borderSecondary.opacity(0.4))
                
                // Shortcut 2: Paste As...
                HotkeyRecorderRow(
                    label: "Paste Formatted As...",
                    description: "Paste with format modifier menus open.",
                    shortcut: pasteAsShortcut,
                    isRecording: recordingField == "paste"
                ) {
                    toggleRecording(field: "paste")
                }
                
                Divider()
                    .background(Theme.borderSecondary.opacity(0.4))
                
                // Shortcut 3: Pause
                HotkeyRecorderRow(
                    label: "Pause Clipboard Capture",
                    description: "Temporarily pause/resume global pasteboard listening.",
                    shortcut: pauseShortcut,
                    isRecording: recordingField == "pause"
                ) {
                    toggleRecording(field: "pause")
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
            
            if recordingField != nil {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                        .scaleEffect(0.8)
                    Text("Press any keys on your keyboard to assign the new shortcut. Press **Esc** to cancel.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.leading, 8)
                .transition(.opacity)
            }
            
            Spacer()
        }
        .padding(24)
        .background(Theme.bgPrimary)
    }
    
    private func toggleRecording(field: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            if recordingField == field {
                recordingField = nil
            } else {
                recordingField = field
                
                // Simulate recording ending after 3 seconds for mock interactivity
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    guard recordingField == field else { return }
                    withAnimation {
                        if field == "open" {
                            openShortcut = "⌥ Space"
                        } else if field == "paste" {
                            pasteAsShortcut = "⇧ ⌥ V"
                        } else if field == "pause" {
                            pauseShortcut = "⌥ ⇧ P"
                        }
                        recordingField = nil
                    }
                }
            }
        }
    }
}

/// Helper view representing a single row in the hotkeys configuration.
struct HotkeyRecorderRow: View {
    let label: String
    let description: String
    let shortcut: String
    let isRecording: Bool
    let onRecord: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            Button(action: onRecord) {
                if isRecording {
                    Text("Recording...")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.8))
                        )
                } else {
                    Text(shortcut)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Theme.accentBg)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .buttonStyle(.plain)
        }
    }
}
