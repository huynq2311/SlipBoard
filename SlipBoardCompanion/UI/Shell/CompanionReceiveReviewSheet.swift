import SwiftUI

struct CompanionReceiveReviewSheet: View {
    let item: CompanionInboundReviewItem

    @State private var hasAcknowledgedManualPaste = false
    @State private var footerState: FooterState = .ready

    enum FooterState {
        case ready
        case submitting
        case success
        case failure
    }

    init(item: CompanionInboundReviewItem = IOSCompanionBridgeMockFixtures.pendingInboundReview) {
        self.item = item
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CompanionBridgeTheme.sectionGap) {
                header

                Label(item.payloadKind.badgeTitle, systemImage: item.payloadKind.symbolName)
                    .font(.companionBadge)
                    .foregroundStyle(item.payloadKind.tint)

                CompanionPayloadPreview(
                    title: "Payload preview",
                    payloadText: item.payloadText
                )

                CompanionPolicyCallout(
                    title: "Confirmation required",
                    message: "SlipBoard can set your iPhone clipboard, but you still paste manually in the destination app."
                )

                confirmationChecklist
                footer
            }
            .padding(CompanionBridgeTheme.screenPadding)
            .background(CompanionBridgeTheme.surfaceBase.ignoresSafeArea())
            .navigationTitle("Review Receive")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.sourceDeviceName)
                .font(.companionSectionTitle)
                .foregroundStyle(CompanionBridgeTheme.textPrimary)

            Text(relativeDateLabel)
                .font(.companionCaption)
                .foregroundStyle(CompanionBridgeTheme.textSecondary)
        }
    }

    private var confirmationChecklist: some View {
        Button {
            hasAcknowledgedManualPaste.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: hasAcknowledgedManualPaste ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(hasAcknowledgedManualPaste ? CompanionBridgeTheme.accentSuccess : CompanionBridgeTheme.textSecondary)
                    .font(.title3)

                Text("I understand this only prepares the iPhone clipboard. Paste into the destination app yourself.")
                    .font(.companionBody)
                    .foregroundStyle(CompanionBridgeTheme.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(CompanionBridgeTheme.rowPadding)
            .background(CompanionBridgeTheme.surfaceRaised)
            .overlay {
                RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius)
                    .stroke(CompanionBridgeTheme.borderSubtle, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                footerState = footerState == .success ? .ready : .success
            } label: {
                HStack {
                    if footerState == .submitting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .font(.companionBody.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .background(hasAcknowledgedManualPaste ? CompanionBridgeTheme.accentInfo : CompanionBridgeTheme.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
            }
            .buttonStyle(.plain)
            .disabled(!hasAcknowledgedManualPaste || footerState == .submitting)

            Button("Dismiss") {}
                .font(.companionBody.weight(.medium))
                .foregroundStyle(CompanionBridgeTheme.textSecondary)

            if footerState == .success {
                Text("Clipboard confirmation stays visible before any paste leaves SlipBoard.")
                    .font(.companionCaption)
                    .foregroundStyle(CompanionBridgeTheme.accentSuccess)
            } else if footerState == .failure {
                Text("SlipBoard could not prepare the clipboard.")
                    .font(.companionCaption)
                    .foregroundStyle(CompanionBridgeTheme.accentDanger)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch footerState {
        case .ready:
            return "Set Clipboard"
        case .submitting:
            return "Setting Clipboard"
        case .success:
            return "Clipboard Ready"
        case .failure:
            return "Try Again"
        }
    }

    private var relativeDateLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Received \(formatter.localizedString(for: item.createdAt, relativeTo: .now))"
    }
}

#Preview {
    CompanionReceiveReviewSheet()
}
