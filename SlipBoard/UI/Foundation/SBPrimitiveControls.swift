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
        .frame(width: isPresented ? 240 : 0, height: 34, alignment: .leading)
        .background(theme.palette.subpanel.opacity(isPresented ? 1 : 0.001))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
    /// Semantic type color (Text/Image/Code/…). Leave nil for "All", which
    /// always uses the app accent color instead of a per-type color.
    var tintColor: Color? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.control4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tintColor ?? (isSelected ? theme.palette.accentPrimary : theme.palette.textSecondary))
                }

                Text(title)
                    .font(theme.typography.chip)

                if let countText {
                    SBCountBadge(
                        text: countText,
                        theme: theme,
                        tone: isSelected ? .primary : .neutral,
                        compact: true,
                        tintColorOverride: tintColor
                    )
                }
            }
            .foregroundStyle(tintColor ?? (isSelected ? resolvedAccent : theme.palette.textSecondary))
            .padding(.horizontal, theme.spacing.control10)
            .padding(.vertical, theme.spacing.control6)
            .frame(height: 32)
            .background {
                ZStack {
                    // Type tints are only 10–16% opaque; on clear glass they
                    // need a surface under them or the wallpaper shows through.
                    if theme.treatment == .liquidGlass {
                        theme.palette.raised
                    }
                    chipBackground
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(chipBorder, lineWidth: theme.border.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    private var resolvedAccent: Color {
        tintColor ?? theme.palette.accentPrimary
    }

    private var chipBackground: Color {
        guard tintColor != nil else {
            return isSelected ? resolvedAccent.opacity(0.16) : theme.palette.subpanel
        }
        return resolvedAccent.opacity(isSelected ? 0.16 : 0.10)
    }

    private var chipBorder: Color {
        guard tintColor != nil else {
            return isSelected ? resolvedAccent : theme.palette.border
        }
        return resolvedAccent.opacity(isSelected ? 0.72 : 0.22)
    }
}

struct SBUtilityDropdownOption: Identifiable, Hashable {
    let id: String
    let label: String
}

// A native SwiftUI `Menu` doesn't reliably pop open inside the app's
// borderless `.nonactivatingPanel` window, so this renders its own dropdown
// list as a plain overlay (same approach as SBContextMenuShell) instead.
struct SBUtilityDropdown<Option: Identifiable & Hashable>: View {
    let label: String
    let selectionText: String
    let options: [Option]
    let theme: SBTheme
    var isEnabled: Bool = true
    var isOpen: Bool = false
    var optionLabel: (Option) -> String
    var onToggle: () -> Void = {}
    var action: (Option) -> Void = { _ in }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: theme.spacing.control4) {
                Text("\(label):")
                    .foregroundStyle(theme.palette.textTertiary)

                Text(selectionText)
                    .foregroundStyle(theme.palette.textSecondary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.palette.textTertiary)
            }
            .font(theme.typography.chip)
            .padding(.horizontal, theme.spacing.control10)
            .frame(height: 32)
            .background(theme.palette.subpanel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isOpen ? theme.palette.accentPrimary : theme.palette.border, lineWidth: theme.border.hairline)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(isEnabled == false || options.isEmpty)
        .opacity(isEnabled == false || options.isEmpty ? 0.5 : 1)
        .overlay(alignment: .topTrailing) {
            if isOpen {
                dropdownList
                    .offset(y: 34)
            }
        }
    }

    private var dropdownList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.id) { option in
                Button {
                    action(option)
                } label: {
                    Text(optionLabel(option))
                        .font(theme.typography.rowPrimary)
                        .foregroundStyle(theme.palette.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, theme.spacing.control12)
                        .padding(.vertical, theme.spacing.control8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(minWidth: 160, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .sbSurface(.overlay, theme: theme)
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
                            .fontWeight(isSelected ? .semibold : .regular)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? theme.accent(for: .primary) : theme.palette.textTertiary)
                    .padding(.horizontal, theme.spacing.control8)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? theme.accentBackground(for: .primary) : Color.clear)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(isSelected ? theme.accent(for: .primary).opacity(0.4) : Color.clear, lineWidth: theme.border.hairline)
                    )
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
    /// Semantic type color (Text/Image/Code/…) to tint the badge with instead
    /// of the generic tone color, so a chip's count matches its own accent.
    var tintColorOverride: Color? = nil

    var body: some View {
        Text(text)
            .font(compact ? theme.typography.keyboard : theme.typography.meta)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? 5 : theme.spacing.control8)
            .padding(.vertical, compact ? 1 : 3)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        guard tone == .primary else {
            return tintColorOverride ?? theme.accent(for: tone)
        }
        return tintColorOverride == nil ? Color.white : tintColorOverride!
    }

    private var backgroundColor: Color {
        guard let tintColorOverride else {
            return tone == .primary ? theme.accent(for: tone) : theme.accentBackground(for: tone)
        }
        return tone == .primary ? tintColorOverride.opacity(0.22) : tintColorOverride.opacity(0.14)
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
