import SwiftUI

public struct BottomStatusBar: View {
    public let totalItems: Int
    public let activeFilter: ClipType?
    
    public init(totalItems: Int, activeFilter: ClipType? = nil) {
        self.totalItems = totalItems
        self.activeFilter = activeFilter
    }
    
    public var body: some View {
        HStack {
            // Count indicator with active filter details
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                
                Text("\(totalItems) items")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                
                if let filter = activeFilter {
                    Text("• Filter: \(filter.rawValue)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            
            Spacer()
            
            // Monospaced keyboard shortcut indicators cheat-sheet
            Text("⌘⇧V Toggle  •  ⌘P Pin  •  Tab Cycle  •  ⌘N Note  •  Esc Hide")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Theme.bgSecondary.opacity(0.75)
                .background(SlipVisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow))
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Theme.borderSecondary.opacity(0.4)),
            alignment: .top
        )
    }
}
