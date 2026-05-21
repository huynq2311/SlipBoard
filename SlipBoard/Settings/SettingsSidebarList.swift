import SwiftUI

struct SettingsSidebarList: View {
    let tabs: [SettingsTabSummary]
    let selectedTab: SettingsShellTabID
    let onSelect: (SettingsShellTabID) -> Void

    var body: some View {
        List(tabs) { tab in
            Button {
                onSelect(tab.id)
            } label: {
                Label(tab.title, systemImage: tab.symbolName)
                    .font(.body.weight(tab.id == selectedTab ? .semibold : .regular))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tab.id == selectedTab ? Color.accentColor.opacity(0.14) : .clear)
            )
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Static Shell")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("All controls mutate local preview state only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.thinMaterial)
        }
    }
}
