import SwiftUI

public enum PasteTransformation: String, CaseIterable, Identifiable {
    case plain = "Plain Text"
    case markdown = "Convert to Markdown"
    case stripUnicode = "Strip Unicode / Accent"
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    
    public var id: String { self.rawValue }
    
    public func transform(_ input: String) -> String {
        switch self {
        case .plain:
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        case .markdown:
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                return "[Link](\(trimmed))"
            }
            return "*\(trimmed)*"
        case .stripUnicode:
            let mutableString = NSMutableString(string: input)
            CFStringTransform(mutableString as CFMutableString, nil, kCFStringTransformToLatin, false)
            CFStringTransform(mutableString as CFMutableString, nil, kCFStringTransformStripCombiningMarks, false)
            var result = mutableString as String
            result = result.replacingOccurrences(of: "đ", with: "d")
            result = result.replacingOccurrences(of: "Đ", with: "D")
            return result
        case .uppercase:
            return input.uppercased()
        case .lowercase:
            return input.lowercased()
        }
    }
}

public struct PasteAsPopover: View {
    public let item: ClipItem
    public let onTransform: (String) -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @State private var eventMonitor: Any? = nil
    
    public init(item: ClipItem, onTransform: @escaping (String) -> Void) {
        self.item = item
        self.onTransform = onTransform
    }
    
    private var transformations: [PasteTransformation] {
        PasteTransformation.allCases
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Title
            Text("PASTE AS...")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.top, 8)
            
            // Dynamic Preview Box
            VStack(alignment: .leading, spacing: 4) {
                ScrollView {
                    Text(transformations[selectedIndex].transform(item.contentString))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .frame(height: 64)
                .padding(8)
                .background(Theme.bgTertiary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.borderSecondary.opacity(0.4), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 10)
            
            Divider()
                .foregroundColor(Theme.borderSecondary.opacity(0.3))
                .padding(.horizontal, 4)
            
            // Section 1: Standard / Formatting transformations
            VStack(spacing: 2) {
                ForEach(0..<3) { idx in
                    rowView(for: idx)
                }
            }
            .padding(.horizontal, 4)
            
            Divider()
                .foregroundColor(Theme.borderSecondary.opacity(0.3))
                .padding(.horizontal, 4)
            
            // Section 2: Case transformations
            VStack(spacing: 2) {
                ForEach(3..<5) { idx in
                    rowView(for: idx)
                }
            }
            .padding(.horizontal, 4)
            
            Divider()
                .foregroundColor(Theme.borderSecondary.opacity(0.3))
                .padding(.horizontal, 4)
            
            // Footer
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                    Text("ESC cancel")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                Button(action: {
                    executePaste(at: selectedIndex)
                }) {
                    Text("Paste")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.accent.cornerRadius(6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .padding(4)
        .frame(width: 260)
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
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }
    
    private func rowView(for idx: Int) -> some View {
        let trans = transformations[idx]
        let isSelected = selectedIndex == idx
        let isHovered = hoveredIndex == idx
        
        let iconName: String
        let descText: String
        let badgeText: String
        
        switch trans {
        case .plain:
            iconName = "doc.text"
            descText = "Strip formatting"
            badgeText = "↵"
        case .markdown:
            iconName = "chevron.left.forwardslash.chevron.right"
            descText = "Convert links or wrap text"
            badgeText = "⌘1"
        case .stripUnicode:
            iconName = "eraser.line.dashed"
            descText = "Remove accents & diacritics"
            badgeText = "⌘2"
        case .uppercase:
            iconName = "textformat.size.larger"
            descText = "Convert to UPPERCASE"
            badgeText = "⌘3"
        case .lowercase:
            iconName = "textformat.size.smaller"
            descText = "convert to lowercase"
            badgeText = "⌘4"
        }
        
        return Button(action: {
            executePaste(at: idx)
        }) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(trans.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? Theme.accent : Theme.textPrimary)
                    
                    Text(descText)
                        .font(.system(size: 8.5))
                        .foregroundColor(isSelected ? Theme.accent.opacity(0.8) : Theme.textTertiary)
                }
                
                Spacer()
                
                Text(badgeText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Theme.bgTertiary)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Theme.borderSecondary.opacity(0.6), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.accent.opacity(0.12) : (isHovered ? Theme.bgTertiary : Color.clear))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            if hover {
                hoveredIndex = idx
                selectedIndex = idx
            } else if hoveredIndex == idx {
                hoveredIndex = nil
            }
        }
    }
    
    private func executePaste(at idx: Int) {
        let text = transformations[idx].transform(item.contentString)
        onTransform(text)
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.handleKeyEvent(event) {
                return nil // handled, consume
            }
            return event
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 125: // Arrow Down
            selectedIndex = (selectedIndex + 1) % transformations.count
            return true
            
        case 126: // Arrow Up
            selectedIndex = (selectedIndex == 0) ? transformations.count - 1 : selectedIndex - 1
            return true
            
        case 36: // Enter
            executePaste(at: selectedIndex)
            return true
            
        case 18, 19, 20, 21: // Keys 1, 2, 3, 4
            if event.modifierFlags.contains(.command) {
                let idx: Int
                switch event.keyCode {
                case 18: idx = 1 // Markdown
                case 19: idx = 2 // Strip Unicode
                case 20: idx = 3 // Uppercase
                case 21: idx = 4 // Lowercase
                default: return false
                }
                if idx >= 0 && idx < transformations.count {
                    executePaste(at: idx)
                    return true
                }
            }
            
        default:
            break
        }
        return false
    }
}
