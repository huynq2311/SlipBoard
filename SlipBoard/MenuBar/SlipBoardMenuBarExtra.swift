import SwiftUI

struct SlipBoardMenuBarExtra: Scene {
    private let preset: SettingsMenuShellPreset

    init(preset: SettingsMenuShellPreset = .settingsDemo) {
        self.preset = preset
    }

    var body: some Scene {
        MenuBarExtra("SlipBoard", systemImage: "paperclip.circle.fill") {
            SlipBoardMenuBarMenu(preset: preset)
        }
    }
}

private struct SlipBoardMenuBarMenu: View {
    @StateObject private var session: SettingsShellLocalSession

    init(preset: SettingsMenuShellPreset) {
        _session = StateObject(wrappedValue: SettingsShellLocalSession(preset: preset))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusHeader

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Retention")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(session.snapshot.menuBar.quickRetentionOptions) { option in
                        Button(option.title) {
                            session.selectQuickRetention(option.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(option.isSelected ? .accentColor : Color.secondary.opacity(0.15))
                    }
                }
            }

            Menu {
                ForEach(session.snapshot.menuBar.pauseOptions) { option in
                    Button {
                        session.selectPauseCapture(option.id)
                    } label: {
                        if let resumesAtLabel = option.resumesAtLabel {
                            Text("\(option.title) • \(resumesAtLabel)")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                Label(session.snapshot.menuBar.pauseSummary ?? "Pause Capture", systemImage: "pause.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .menuStyle(.borderlessButton)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button("Open SlipBoard") {}

                Button("Settings...") {
                    session.openSettings()
                }

                Button("Quit SlipBoard") {}
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SlipBoard")
                    .font(.headline)

                Spacer()

                Text(session.snapshot.menuBar.itemCountLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }

            Text("Retention: \(session.snapshot.menuBar.retentionLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if session.snapshot.menuBar.isCapturePaused, let pauseSummary = session.snapshot.menuBar.pauseSummary {
                Label(pauseSummary, systemImage: "pause.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
    }
}

#Preview("Menu Bar Shell") {
    SlipBoardMenuBarMenu(preset: .pausedCapture)
        .padding()
        .frame(width: 360)
}
