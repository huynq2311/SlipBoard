import SwiftUI

/// A clean, monospaced badge designed for numeric counts and statuses.
public struct MonospacedBadge: View {
    public let text: String
    public var textColor: Color
    public var backgroundColor: Color
    
    public init(_ text: String, textColor: Color = Theme.textSecondary, backgroundColor: Color = Theme.bgTertiary) {
        self.text = text
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Theme.borderSecondary.opacity(0.5), lineWidth: 0.5)
            )
    }
}

/// A premium, animated segmented control styled as modern visual pills.
public struct SegmentedPillControl<Option: Hashable & Identifiable>: View {
    @Binding public var selection: Option
    public let options: [Option]
    public let title: (Option) -> String
    
    public init(selection: Binding<Option>, options: [Option], title: @escaping (Option) -> String) {
        self._selection = selection
        self.options = options
        self.title = title
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.id) { option in
                Text(title(option))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(selection == option ? .white : Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selection == option ? Theme.accent : Color.clear)
                            .shadow(color: selection == option ? Theme.accent.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                    )
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            selection = option
                        }
                    }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Theme.bgTertiary)
        )
        .overlay(
            Capsule()
                .stroke(Theme.borderSecondary.opacity(0.6), lineWidth: 1)
        )
    }
}

/// A glassmorphic container with micro-borders and subtle drop shadows.
public struct GlassCard<Content: View>: View {
    public let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.bgSecondary.opacity(0.7))
                    .background(
                        SlipVisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                            .opacity(0.2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.borderPrimary.opacity(0.4), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

/// Native macOS NSVisualEffectView wrapper for glassmorphism
#if os(macOS)
import AppKit

public struct SlipVisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    
    public init(material: NSVisualEffectView.Material = .hudWindow, blendingMode: NSVisualEffectView.BlendingMode = .withinWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#else
public struct SlipVisualEffectBlur: View {
    public init(material: Int = 0, blendingMode: Int = 0) {}
    
    public var body: some View {
        Spacer()
    }
}
#endif
