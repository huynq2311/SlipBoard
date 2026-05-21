import SwiftUI

struct SessionPreviewHost: View {
    let session: SlipBoardAppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            switch session.activeSurface {
            case .popup:
                popupPlaceholder
            case let .settings(tab):
                settingsPlaceholder(selectedTab: tab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(backgroundColor)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(surfaceTitle)
                .font(.title2.weight(.semibold))

            Text(surfaceSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                hostChip(title: "Theme", value: session.theme.rawValue.capitalized)
                hostChip(title: "Clipboard", value: "\(session.clipboard.filteredCount)/\(session.clipboard.totalCount)")
                hostChip(title: "Settings", value: session.settings.selectedTab.rawValue.capitalized)
            }
        }
    }

    private var popupPlaceholder: some View {
        VStack(alignment: .leading, spacing: 16) {
            placeholderCard(
                title: "Popup Host Placeholder",
                detail: "Root injection is ready for the popup shell. This host renders typed clipboard counts, filters, and selection state without depending on menu bar plumbing."
            )

            HStack(alignment: .top, spacing: 16) {
                hostMetric(title: "Pinned", value: "\(session.clipboard.pinnedItems.count)")
                hostMetric(title: "Recent", value: "\(session.clipboard.recentItems.count)")
                hostMetric(title: "Filter", value: session.popupChrome.activeFilter.rawValue.capitalized)
                hostMetric(title: "Search", value: session.popupChrome.searchQuery.isEmpty ? "Empty" : session.popupChrome.searchQuery)
            }

            if let selectedItemID = session.popupChrome.selectedItemID {
                Text("Selected item: \(selectedItemID.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Selected item: none")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settingsPlaceholder(selectedTab: SettingsTabID) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            placeholderCard(
                title: "Settings Host Placeholder",
                detail: "Root injection is ready for the settings shell. This host keeps the active tab and summary values typed while the real window layout is still pending."
            )

            HStack(alignment: .top, spacing: 16) {
                hostMetric(title: "Selected Tab", value: selectedTab.rawValue.capitalized)
                hostMetric(title: "Bridge", value: session.settings.bridge.isEnabled ? "Enabled" : "Disabled")
                hostMetric(title: "Devices", value: "\(session.settings.bridge.devices.count)")
                hostMetric(title: "Snippets", value: "\(session.settings.snippets.totalCount)")
            }

            Text(settingsSummaryLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func placeholderCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func hostMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func hostChip(title: String, value: String) -> some View {
        Text("\(title): \(value)")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }

    private var surfaceTitle: String {
        switch session.activeSurface {
        case .popup:
            return "Popup Session Host"
        case .settings:
            return "Settings Session Host"
        }
    }

    private var surfaceSummary: String {
        switch session.activeSurface {
        case .popup:
            return "Typed clipboard session data is injected and ready for the future popup shell."
        case let .settings(tab):
            return "Typed settings session data is injected and ready for the future \(tab.rawValue) settings shell."
        }
    }

    private var settingsSummaryLine: String {
        let bridgeLabel = session.settings.bridge.lastPublishedLabel ?? "No bridge publish activity yet."
        return "\(session.settings.general.interfaceTheme.value) theme. \(bridgeLabel)"
    }

    private var backgroundColor: some ShapeStyle {
        switch session.theme {
        case .system:
            return AnyShapeStyle(.background)
        case .light:
            return AnyShapeStyle(Color(red: 0.96, green: 0.94, blue: 0.90))
        case .dark:
            return AnyShapeStyle(Color(red: 0.12, green: 0.14, blue: 0.17))
        }
    }
}

private struct FixtureSessionProvider: SlipBoardSessionProviding {
    let initialPreset: SlipBoardSessionPreset

    func initialSession() -> SlipBoardAppSession {
        fixtureSession(named: initialPreset)
    }

    func fixtureSession(named preset: SlipBoardSessionPreset) -> SlipBoardAppSession {
        SlipBoardSessionFixtures.session(named: preset)
    }
}

struct SessionPreviewHost_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AppRootContainer(provider: FixtureSessionProvider(initialPreset: .popupDemo))
                .previewDisplayName("Popup Demo")

            AppRootContainer(provider: FixtureSessionProvider(initialPreset: .settingsDemo))
                .previewDisplayName("Settings Demo")

            SessionPreviewHost(session: SlipBoardSessionFixtures.session(named: .fullDemo))
                .previewDisplayName("Direct Session Injection")
        }
        .frame(width: 420, height: 320)
    }
}
