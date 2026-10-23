import SwiftUI

struct CompanionBridgeWidgetEntryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.title2)
                    .foregroundStyle(CompanionBridgeTheme.accentInfo)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SlipTray Bridge")
                        .font(.companionBody.weight(.semibold))
                        .foregroundStyle(CompanionBridgeTheme.textPrimary)

                    Text("Launch import flow")
                        .font(.companionCaption)
                        .foregroundStyle(CompanionBridgeTheme.textSecondary)
                }
            }

            Button {
            } label: {
                Text("Open Companion")
                    .font(.companionBody.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(CompanionBridgeTheme.accentInfo)
                    .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
            }
            .buttonStyle(.plain)

            Text("Widget and Shortcuts launch the same reviewed import path. They do not promise background capture.")
                .font(.companionCaption)
                .foregroundStyle(CompanionBridgeTheme.textSecondary)
        }
        .padding(16)
        .background(CompanionBridgeTheme.surfaceRaised)
        .overlay {
            RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius)
                .stroke(CompanionBridgeTheme.borderSubtle, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
    }
}

#Preview {
    CompanionBridgeWidgetEntryView()
        .padding()
        .background(CompanionBridgeTheme.surfaceBase)
}
