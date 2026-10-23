import SwiftUI

struct CompanionShareImportView: View {
    let payloadText: String
    let isSupported: Bool
    @State private var state: ImportState

    enum ImportState {
        case idle
        case importing
        case imported
        case unsupported
    }

    init(
        payloadText: String = IOSCompanionBridgeMockFixtures.shareImport.payloadText,
        isSupported: Bool = true
    ) {
        self.payloadText = payloadText
        self.isSupported = isSupported
        _state = State(initialValue: isSupported ? .idle : .unsupported)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import to SlipTray")
                .font(.companionSectionTitle)
                .foregroundStyle(CompanionBridgeTheme.textPrimary)

            CompanionPayloadPreview(
                title: "Shared payload",
                payloadText: payloadText
            )

            if state == .unsupported {
                CompanionPolicyCallout(
                    title: "Not supported",
                    message: "Only text, URL, and code can enter the companion bridge.",
                    tint: CompanionBridgeTheme.accentDanger
                )
            } else {
                CompanionPolicyCallout(
                    title: "One-shot import",
                    message: "This sends the shared payload into the same reviewed bridge queue used by the companion app."
                )
            }

            Button {
                guard isSupported else { return }
                state = state == .imported ? .idle : .imported
            } label: {
                HStack {
                    if state == .importing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .font(.companionBody.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .background(isSupported ? CompanionBridgeTheme.accentInfo : CompanionBridgeTheme.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
            }
            .buttonStyle(.plain)
            .disabled(!isSupported || state == .importing)

            Text(terminalMessage)
                .font(.companionCaption)
                .foregroundStyle(terminalTint)
        }
        .padding(CompanionBridgeTheme.screenPadding)
        .background(CompanionBridgeTheme.surfaceBase)
    }

    private var primaryButtonTitle: String {
        switch state {
        case .idle:
            return "Import"
        case .importing:
            return "Importing"
        case .imported:
            return "Imported"
        case .unsupported:
            return "Not Supported"
        }
    }

    private var terminalMessage: String {
        switch state {
        case .idle:
            return "Review stays local until the companion app handles the payload."
        case .importing:
            return "Preparing bridge record."
        case .imported:
            return "Imported into SlipTray."
        case .unsupported:
            return "Not supported."
        }
    }

    private var terminalTint: Color {
        switch state {
        case .imported:
            return CompanionBridgeTheme.accentSuccess
        case .unsupported:
            return CompanionBridgeTheme.accentDanger
        default:
            return CompanionBridgeTheme.textSecondary
        }
    }
}

#Preview {
    CompanionShareImportView()
}
