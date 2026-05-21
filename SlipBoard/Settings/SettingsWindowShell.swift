import Combine
import SwiftUI

final class SettingsShellLocalSession: ObservableObject, MenuBarSessionProviding, SettingsMenuShellRouting {
    @Published private(set) var snapshot: SettingsMenuShellSnapshot

    init(preset: SettingsMenuShellPreset = .settingsDemo) {
        snapshot = SettingsMenuShellFixtures.snapshot(named: preset)
    }

    func initialSettingsMenuShellSnapshot() -> SettingsMenuShellSnapshot {
        snapshot
    }

    func fixtureSettingsMenuShellSnapshot(named preset: SettingsMenuShellPreset) -> SettingsMenuShellSnapshot {
        SettingsMenuShellFixtures.snapshot(named: preset)
    }

    func selectSettingsTab(_ tab: SettingsShellTabID) {
        snapshot = SettingsMenuShellSnapshot(
            selectedTab: tab,
            lastOpenedTab: tab,
            menuBar: snapshot.menuBar,
            tabs: snapshot.tabs,
            general: snapshot.general,
            bridge: snapshot.bridge,
            retention: snapshot.retention,
            exclusions: snapshot.exclusions,
            hotkeys: snapshot.hotkeys,
            snippets: snapshot.snippets,
            security: snapshot.security
        )
    }

    func selectQuickRetention(_ option: QuickRetentionOptionID) {
        let options = snapshot.menuBar.quickRetentionOptions.map { current in
            QuickRetentionOption(id: current.id, title: current.title, isSelected: current.id == option)
        }
        let label = retentionLabel(for: option)

        snapshot = SettingsMenuShellSnapshot(
            selectedTab: snapshot.selectedTab,
            lastOpenedTab: snapshot.lastOpenedTab,
            menuBar: MenuBarSnapshot(
                itemCountLabel: snapshot.menuBar.itemCountLabel,
                retentionLabel: label,
                isCapturePaused: snapshot.menuBar.isCapturePaused,
                pauseSummary: snapshot.menuBar.pauseSummary,
                quickRetentionOptions: options,
                pauseOptions: snapshot.menuBar.pauseOptions
            ),
            tabs: snapshot.tabs,
            general: snapshot.general,
            bridge: snapshot.bridge,
            retention: snapshot.retention,
            exclusions: snapshot.exclusions,
            hotkeys: snapshot.hotkeys,
            snippets: snapshot.snippets,
            security: snapshot.security
        )
    }

    func selectPauseCapture(_ option: PauseCaptureOptionID) {
        let selection = pauseSelection(for: option)
        let options = snapshot.menuBar.pauseOptions.map { current in
            PauseCaptureOption(
                id: current.id,
                title: current.title,
                isSelected: current.id == selection.selectedID,
                resumesAtLabel: current.id == selection.selectedID ? selection.resumesAtLabel : nil
            )
        }

        snapshot = SettingsMenuShellSnapshot(
            selectedTab: snapshot.selectedTab,
            lastOpenedTab: snapshot.lastOpenedTab,
            menuBar: MenuBarSnapshot(
                itemCountLabel: snapshot.menuBar.itemCountLabel,
                retentionLabel: snapshot.menuBar.retentionLabel,
                isCapturePaused: selection.isPaused,
                pauseSummary: selection.pauseSummary,
                quickRetentionOptions: snapshot.menuBar.quickRetentionOptions,
                pauseOptions: options
            ),
            tabs: snapshot.tabs,
            general: snapshot.general,
            bridge: snapshot.bridge,
            retention: snapshot.retention,
            exclusions: snapshot.exclusions,
            hotkeys: snapshot.hotkeys,
            snippets: snapshot.snippets,
            security: snapshot.security
        )
    }

    func openSettings() {
        selectSettingsTab(snapshot.lastOpenedTab)
    }

    private func retentionLabel(for option: QuickRetentionOptionID) -> String {
        switch option {
        case .days7:
            return "7 Days"
        case .days14:
            return "14 Days"
        case .days30:
            return "30 Days"
        case .days90:
            return "90 Days"
        case .forever:
            return "Forever"
        }
    }

    private func pauseSelection(
        for option: PauseCaptureOptionID
    ) -> (selectedID: PauseCaptureOptionID, isPaused: Bool, pauseSummary: String?, resumesAtLabel: String?) {
        switch option {
        case .minutes15:
            return (.minutes15, true, "Paused for 15 minutes", "Resumes in 15 minutes")
        case .hour1:
            return (.hour1, true, "Paused for 1 hour", "Resumes in 1 hour")
        case .untilTomorrow:
            return (.untilTomorrow, true, "Paused until tomorrow", "Resumes tomorrow morning")
        case .resume:
            return (.resume, false, nil, nil)
        }
    }
}

struct SettingsWindowShell: View {
    @StateObject private var session: SettingsShellLocalSession

    init(preset: SettingsMenuShellPreset = .settingsDemo) {
        _session = StateObject(wrappedValue: SettingsShellLocalSession(preset: preset))
    }

    init(session: SettingsShellLocalSession) {
        _session = StateObject(wrappedValue: session)
    }

    var body: some View {
        NavigationSplitView {
            SettingsSidebarList(
                tabs: session.snapshot.tabs,
                selectedTab: session.snapshot.selectedTab,
                onSelect: session.selectSettingsTab(_:)
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            ScrollView {
                tabContent
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 880, minHeight: 580)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch session.snapshot.selectedTab {
        case .general:
            GeneralSettingsTab(summary: session.snapshot.general)
        case .bridge:
            BridgeSettingsTab(summary: session.snapshot.bridge)
        case .retention:
            RetentionSettingsTab(summary: session.snapshot.retention)
        case .exclusions:
            ExclusionsSettingsTab(summary: session.snapshot.exclusions)
        case .hotkeys:
            HotkeysSettingsTab(summary: session.snapshot.hotkeys)
        case .snippets:
            SnippetsSettingsTab(summary: session.snapshot.snippets)
        case .security:
            SecuritySettingsTab(summary: session.snapshot.security)
        }
    }
}

#Preview("Settings Shell") {
    SettingsWindowShell(preset: .settingsDemo)
}
