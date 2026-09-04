import AppKit
import SwiftUI

struct SBIconButton: View {
    let symbolName: String
    let theme: SBTheme
    var isActive: Bool = false
    var size: CGFloat = 28
    var accessibilityLabel: String? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? theme.palette.accentPrimary : theme.palette.textSecondary)
                .frame(width: size, height: size)
                .background(isActive ? theme.palette.accentPrimaryMuted : theme.palette.subpanel)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                        .stroke(isActive ? theme.palette.accentPrimary : theme.palette.borderStrong, lineWidth: theme.border.hairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? symbolName)
    }
}

struct SBSearchFieldShell: View {
    @Binding var text: String
    let theme: SBTheme
    var isPresented: Bool
    var placeholder: String = "Search clipboard..."
    var trailingHint: String? = nil
    var focusRequestToken: Int = 0

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: theme.spacing.control6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.palette.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(theme.typography.rowPrimary)
                .foregroundStyle(theme.palette.textPrimary)
                .focused($isFocused)

            if let trailingHint, isPresented {
                SBKeyboardHint(text: trailingHint, theme: theme)
            }
        }
        .onChange(of: focusRequestToken) { _, _ in
            isFocused = true
            DispatchQueue.main.async {
                guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
                editor.selectedRange = NSRange(location: editor.string.count, length: 0)
            }
        }
        .padding(.horizontal, theme.spacing.control8)
        .frame(width: isPresented ? 180 : 0, height: 28, alignment: .leading)
        .background(theme.palette.subpanel.opacity(isPresented ? 1 : 0.001))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                .stroke(theme.palette.border, lineWidth: theme.border.hairline)
                .opacity(isPresented ? 1 : 0)
        )
        .opacity(isPresented ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

struct SBFilterChip: View {
    let title: String
    let systemImage: String?
    let countText: String?
    let theme: SBTheme
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.control4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                }

                Text(title)
                    .font(theme.typography.chip)

                if let countText {
                    SBCountBadge(
                        text: countText,
                        theme: theme,
                        tone: isSelected ? .primary : .neutral,
                        compact: true
                    )
                }
            }
            .foregroundStyle(isSelected ? theme.palette.accentPrimary : theme.palette.textSecondary)
            .padding(.horizontal, theme.spacing.control10)
            .padding(.vertical, theme.spacing.control4)
            .background(isSelected ? theme.palette.accentPrimaryMuted : theme.palette.subpanel)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? theme.palette.accentPrimary : theme.palette.border, lineWidth: theme.border.hairline))
        }
        .buttonStyle(.plain)
    }
}

struct SBSegmentedControl<Option: Identifiable & Hashable>: View {
    let options: [Option]
    let selection: Option.ID
    let theme: SBTheme
    var label: (Option) -> String
    var icon: ((Option) -> String?)? = nil
    var action: (Option.ID) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.id) { option in
                let isSelected = option.id == selection
                Button {
                    action(option.id)
                } label: {
                    HStack(spacing: 3) {
                        if let iconName = icon?(option) {
                            Image(systemName: iconName)
                                .font(.system(size: 10, weight: .medium))
                        }

                        Text(label(option))
                            .font(theme.typography.meta)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.textTertiary)
                    .padding(.horizontal, theme.spacing.control8)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? theme.palette.canvas : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.palette.subpanel)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(theme.palette.borderStrong, lineWidth: theme.border.hairline))
    }
}

struct SBKeyboardHint: View {
    let text: String
    let theme: SBTheme

    var body: some View {
        Text(text)
            .font(theme.typography.keyboard)
            .foregroundStyle(theme.palette.textSecondary)
            .padding(.horizontal, theme.spacing.control4)
            .padding(.vertical, 2)
            .background(theme.palette.subpanel)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.keycap, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.keycap, style: .continuous)
                    .stroke(theme.palette.borderStrong, lineWidth: theme.border.hairline)
            )
    }
}

struct SBKeyboardShortcutPill: View {
    let text: String
    let theme: SBTheme
    var tone: SBAccentTone = .neutral
    var isEmphasized: Bool = false

    var body: some View {
        Text(text)
            .font(theme.typography.keyboard)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, theme.spacing.control8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                    .stroke(borderColor, lineWidth: theme.border.hairline)
            )
    }

    private var foregroundColor: Color {
        tone == .primary && isEmphasized ? Color.white : accentColor
    }

    private var backgroundColor: Color {
        if tone == .primary && isEmphasized {
            return theme.accent(for: .primary)
        }
        return isEmphasized ? theme.accentBackground(for: tone) : theme.palette.raised
    }

    private var borderColor: Color {
        isEmphasized ? accentColor : theme.palette.borderStrong
    }

    private var accentColor: Color {
        tone == .neutral ? theme.palette.textSecondary : theme.accent(for: tone)
    }
}

struct SBControlPillButton: View {
    let title: String
    let theme: SBTheme
    var tone: SBAccentTone = .neutral
    var isEnabled: Bool = true
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.chip)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, theme.spacing.control10)
                .padding(.vertical, 5)
                .background(theme.accentBackground(for: backgroundTone))
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                        .stroke(borderColor, lineWidth: theme.border.hairline)
                )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.52)
    }

    private var foregroundColor: Color {
        tone == .neutral ? theme.palette.textSecondary : theme.accent(for: tone)
    }

    private var backgroundTone: SBAccentTone {
        tone == .neutral ? .neutral : tone
    }

    private var borderColor: Color {
        tone == .neutral ? theme.palette.border : theme.accent(for: tone).opacity(0.55)
    }
}

struct SBCountBadge: View {
    let text: String
    let theme: SBTheme
    var tone: SBAccentTone = .primary
    var compact: Bool = false

    var body: some View {
        Text(text)
            .font(compact ? theme.typography.keyboard : theme.typography.meta)
            .foregroundStyle(tone == .primary ? Color.white : theme.accent(for: tone))
            .padding(.horizontal, compact ? 5 : theme.spacing.control8)
            .padding(.vertical, compact ? 1 : 3)
            .background(tone == .primary ? theme.accent(for: tone) : theme.accentBackground(for: tone))
            .clipShape(Capsule())
    }
}

struct SBIconAvatar: View {
    let symbolName: String?
    let accentToken: String
    let theme: SBTheme
    var size: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(theme.accent(for: accentToken).opacity(0.16))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbolName ?? "circle.fill")
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(theme.accent(for: accentToken))
            }
    }
}

struct SBMonoMetaText: View {
    let text: String
    let theme: SBTheme

    var body: some View {
        Text(text)
            .font(theme.typography.monoMeta)
            .foregroundStyle(theme.palette.textTertiary)
    }
}
