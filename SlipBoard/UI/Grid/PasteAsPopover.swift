import SwiftUI

public enum PasteTransformation: String, CaseIterable, Identifiable {
    case plain = "Plain Text"
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case titleCase = "Title Case"
    case trim = "Trim Whitespace"
    
    public var id: String { self.rawValue }
    
    public func transform(_ input: String) -> String {
        switch self {
        case .plain:
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        case .uppercase:
            return input.uppercased()
        case .lowercase:
            return input.lowercased()
        case .titleCase:
            return input.capitalized
        case .trim:
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

public struct PasteAsPopover: View {
    public let item: ClipItem
    public let onTransform: (String) -> Void
    @State private var hoveredIndex: Int? = nil
    
    public init(item: ClipItem, onTransform: @escaping (String) -> Void) {
        self.item = item
        self.onTransform = onTransform
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PASTE AS...")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            
            Divider()
                .foregroundColor(Theme.borderSecondary.opacity(0.3))
                .padding(.horizontal, 4)
            
            ForEach(Array(PasteTransformation.allCases.enumerated()), id: \.offset) { offset, trans in
                let isHovered = hoveredIndex == offset
                let previewText = trans.transform(item.contentString)
                
                Button(action: {
                    onTransform(previewText)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(isHovered ? Theme.accent : Color.clear)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trans.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            
                            // Monospaced Preview text
                            Text(previewText)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .frame(maxWidth: 180, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isHovered ? Theme.bgTertiary : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .onHover { hover in
                    if hover {
                        hoveredIndex = offset
                    } else if hoveredIndex == offset {
                        hoveredIndex = nil
                    }
                }
            }
        }
        .padding(4)
        .frame(width: 220)
        .background(
            Theme.bgSecondary.opacity(0.85)
                .background(SlipVisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow))
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.borderSecondary.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
