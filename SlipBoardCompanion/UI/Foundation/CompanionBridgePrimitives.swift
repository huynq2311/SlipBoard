import SwiftUI

struct CompanionStatusBadge: View {
    let status: CompanionBridgeAccountStatus

    var body: some View {
        Text(status.badgeTitle)
            .font(.companionBadge)
            .foregroundStyle(status.badgeTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.badgeTint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct CompanionActionRow: View {
    let symbolName: String
    let title: String
    let detail: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var completionLabel: String?
    var validationMessage: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isEnabled ? CompanionBridgeTheme.accentInfo : CompanionBridgeTheme.accentMuted)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.companionBody.weight(.semibold))
                        .foregroundStyle(CompanionBridgeTheme.textPrimary)

                    if let completionLabel {
                        Text(completionLabel)
                            .font(.companionCaption.weight(.semibold))
                            .foregroundStyle(CompanionBridgeTheme.accentSuccess)
                    }
                }

                Text(detail)
                    .font(.companionCaption)
                    .foregroundStyle(CompanionBridgeTheme.textSecondary)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.companionCaption.weight(.medium))
                        .foregroundStyle(CompanionBridgeTheme.accentDanger)
                }
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CompanionBridgeTheme.textSecondary)
            }
        }
        .padding(CompanionBridgeTheme.rowPadding)
        .background(CompanionBridgeTheme.surfaceRaised)
        .overlay {
            RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius)
                .stroke(CompanionBridgeTheme.borderSubtle, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
        .opacity(isEnabled ? 1 : 0.6)
    }
}

struct CompanionPendingReceiveRow: View {
    let item: CompanionInboundReviewItem
    var state: State = .fresh

    enum State {
        case fresh
        case expiringSoon
        case confirmed
        case dismissed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.sourceDeviceName)
                        .font(.companionBody.weight(.semibold))
                        .foregroundStyle(CompanionBridgeTheme.textPrimary)

                    payloadBadge
                }

                Text(item.payloadText)
                    .font(.companionBody)
                    .foregroundStyle(CompanionBridgeTheme.textPrimary)
                    .lineLimit(2)

                Text(relativeLabel)
                    .font(.companionCaption)
                    .foregroundStyle(CompanionBridgeTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Image(systemName: trailingSymbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(trailingTint)
                .padding(8)
                .background(trailingTint.opacity(0.12))
                .clipShape(Circle())
        }
        .padding(CompanionBridgeTheme.rowPadding)
        .background(CompanionBridgeTheme.surfaceRaised)
        .overlay {
            RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius)
                .stroke(CompanionBridgeTheme.borderSubtle, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
    }

    private var payloadBadge: some View {
        Label(item.payloadKind.badgeTitle, systemImage: item.payloadKind.symbolName)
            .font(.companionBadge)
            .foregroundStyle(item.payloadKind.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(item.payloadKind.tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var relativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let base = state == .expiringSoon ? item.expiresAt : item.createdAt
        let value = formatter.localizedString(for: base, relativeTo: .now)
        switch state {
        case .fresh:
            return "Received \(value)"
        case .expiringSoon:
            return "Expires \(value)"
        case .confirmed:
            return "Clipboard confirmed"
        case .dismissed:
            return "Dismissed locally"
        }
    }

    private var trailingSymbolName: String {
        switch state {
        case .fresh: return "arrow.down.circle"
        case .expiringSoon: return "clock.badge.exclamationmark"
        case .confirmed: return "checkmark.circle.fill"
        case .dismissed: return "xmark.circle"
        }
    }

    private var trailingTint: Color {
        switch state {
        case .fresh: return CompanionBridgeTheme.accentInfo
        case .expiringSoon: return CompanionBridgeTheme.accentWarning
        case .confirmed: return CompanionBridgeTheme.accentSuccess
        case .dismissed: return CompanionBridgeTheme.accentMuted
        }
    }
}

struct CompanionPayloadPreview: View {
    let title: String
    let payloadText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.companionCaption.weight(.semibold))
                .foregroundStyle(CompanionBridgeTheme.textSecondary)
                .textCase(.uppercase)

            ScrollView {
                Text(payloadText)
                    .font(.companionBody.monospaced())
                    .foregroundStyle(CompanionBridgeTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 120, maxHeight: 160)
        }
        .padding(CompanionBridgeTheme.previewInset)
        .background(CompanionBridgeTheme.surfaceRaised)
        .overlay {
            RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius)
                .stroke(CompanionBridgeTheme.borderSubtle, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
    }
}

struct CompanionPolicyCallout: View {
    let title: String
    let message: String
    var tint: Color = CompanionBridgeTheme.accentInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(tint)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.companionBody.weight(.semibold))
                    .foregroundStyle(CompanionBridgeTheme.textPrimary)

                Text(message)
                    .font(.companionCaption)
                    .foregroundStyle(CompanionBridgeTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(CompanionBridgeTheme.rowPadding)
        .background(tint.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
    }
}

struct CompanionEmptyStateBlock: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.companionBody.weight(.semibold))
                .foregroundStyle(CompanionBridgeTheme.textPrimary)

            Text(message)
                .font(.companionCaption)
                .foregroundStyle(CompanionBridgeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CompanionBridgeTheme.rowPadding)
        .background(CompanionBridgeTheme.surfaceRaised)
        .overlay {
            RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius)
                .stroke(CompanionBridgeTheme.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .clipShape(RoundedRectangle(cornerRadius: CompanionBridgeTheme.groupRadius))
    }
}
