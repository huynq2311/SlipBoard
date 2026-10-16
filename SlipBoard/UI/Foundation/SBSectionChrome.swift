import SwiftUI

enum SBSectionHeaderStyle: Hashable {
    case compact
    case popup
}

struct SBSectionHeader: View {
    let title: String
    let theme: SBTheme
    var symbolName: String? = nil
    var countText: String? = nil
    var isEmphasized: Bool = false
    var style: SBSectionHeaderStyle = .compact
    var disclosureSymbolName: String? = nil
    var disclosureAccessibilityLabel: String? = nil
    var onDisclosure: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: theme.spacing.control8) {
            // With a disclosure, the whole title cluster toggles, not just the
            // small chevron.
            if let onDisclosure {
                Button(action: onDisclosure) {
                    titleCluster
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(disclosureAccessibilityLabel ?? title)
            } else {
                titleCluster
            }

            if style == .compact {
                Rectangle()
                    .fill(theme.palette.border)
                    .frame(height: theme.border.hairline)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var titleCluster: some View {
        HStack(spacing: theme.spacing.control8) {
            HStack(spacing: 4) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 9, weight: .semibold))
                }

                Text(style == .popup ? title : title.uppercased())
                    .font(style == .popup ? .system(size: 13, weight: .semibold) : theme.typography.uppercaseLabel)
                    .tracking(style == .popup ? 0 : 0.8)
            }
            .foregroundStyle(isEmphasized ? theme.palette.accentPrimary : theme.palette.textTertiary)

            if let countText {
                if style == .popup {
                    Text("· \(countText)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.palette.textSecondary)
                } else {
                    SBCountBadge(text: countText, theme: theme, tone: isEmphasized ? .primary : .neutral, compact: true)
                }
            }

            if let disclosureSymbolName, onDisclosure != nil {
                Image(systemName: disclosureSymbolName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.palette.textTertiary)
                    .frame(width: 22, height: 22)
            }
        }
    }
}

struct SBStatusPill: View {
    let title: String
    let theme: SBTheme
    var tone: SBAccentTone = .success

    var body: some View {
        HStack(spacing: theme.spacing.control4) {
            Circle()
                .fill(theme.accent(for: tone))
                .frame(width: 5, height: 5)

            Text(title)
                .font(theme.typography.meta)
                .foregroundStyle(theme.palette.textTertiary)
        }
    }
}

struct SBSettingsStatusBadge: View {
    let title: String
    let theme: SBTheme
    var tone: SBAccentTone = .neutral
    var symbolName: String? = nil

    var body: some View {
        HStack(spacing: theme.spacing.control4) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 9, weight: .semibold))
            }

            Text(title)
                .font(theme.typography.chip)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, theme.spacing.control8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: theme.border.hairline)
        )
    }

    private var foregroundColor: Color {
        tone == .primary ? Color.white : accentColor
    }

    private var backgroundColor: Color {
        tone == .primary ? accentColor : theme.accentBackground(for: tone)
    }

    private var borderColor: Color {
        tone == .primary ? accentColor : accentColor.opacity(0.5)
    }

    private var accentColor: Color {
        tone == .neutral ? theme.palette.textSecondary : theme.accent(for: tone)
    }
}

enum SBInlineCalloutTone: Hashable {
    case info
    case warning

    var accentTone: SBAccentTone {
        switch self {
        case .info:
            return .info
        case .warning:
            return .warning
        }
    }

    var symbolName: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        }
    }
}

struct SBPaneSection<Content: View>: View {
    let title: String
    let descriptionText: String?
    let theme: SBTheme
    @ViewBuilder var content: Content

    init(
        title: String,
        descriptionText: String? = nil,
        theme: SBTheme,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.descriptionText = descriptionText
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.section12) {
            SBSectionHeader(title: title, theme: theme)

            if let descriptionText, descriptionText.isEmpty == false {
                Text(descriptionText)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
            }

            VStack(alignment: .leading, spacing: theme.spacing.control8) {
                content
            }
        }
    }
}

struct SBEmptyStateCard: View {
    let title: String
    let detailText: String
    let theme: SBTheme
    var badgeText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control8) {
            HStack {
                Text(title)
                    .font(theme.typography.rowPrimary)
                    .foregroundStyle(theme.palette.textPrimary)

                Spacer()

                if let badgeText {
                    SBCountBadge(text: badgeText, theme: theme, tone: .neutral, compact: true)
                }
            }

            Text(detailText)
                .font(theme.typography.rowSecondary)
                .foregroundStyle(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.spacing.control12)
        .sbSurface(.card, theme: theme)
    }
}

struct SBSettingsConflictCallout: View {
    let title: String
    let detailText: String
    let theme: SBTheme
    var tone: SBInlineCalloutTone = .info
    var badgeText: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.control10) {
            Image(systemName: tone.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent(for: tone.accentTone))
                .frame(width: 14, height: 14)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: theme.spacing.control6) {
                    Text(title)
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)
                        .lineLimit(1)

                    if let badgeText {
                        SBCountBadge(
                            text: badgeText,
                            theme: theme,
                            tone: tone.accentTone,
                            compact: true
                        )
                    }
                }

                Text(detailText)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.control8)
        }
        .padding(theme.spacing.control12)
        .background(theme.accentBackground(for: tone.accentTone))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous)
                .stroke(theme.accent(for: tone.accentTone).opacity(0.45), lineWidth: theme.border.hairline)
        )
    }
}

struct SBPolicyNoteRow: View {
    let title: String?
    let detailText: String
    let theme: SBTheme
    var symbolName: String = "shield"

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.control10) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent(for: .info))
                .frame(width: 14, height: 14)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                if let title, title.isEmpty == false {
                    Text(title)
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)
                }

                Text(detailText)
                    .font(theme.typography.rowSecondary)
                    .foregroundStyle(theme.palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.control8)
        }
        .padding(theme.spacing.control12)
        .background(theme.palette.subpanel)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous)
                .stroke(theme.palette.border, lineWidth: theme.border.hairline)
        )
    }
}
