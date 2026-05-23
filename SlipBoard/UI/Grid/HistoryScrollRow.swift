import SwiftUI

public struct HistoryScrollRow: View {
    public let title: String
    public let items: [ClipItem]
    public let selectedItem: ClipItem?
    public let onSelect: (ClipItem) -> Void
    
    public init(
        title: String,
        items: [ClipItem],
        selectedItem: ClipItem?,
        onSelect: @escaping (ClipItem) -> Void
    ) {
        self.title = title
        self.items = items
        self.selectedItem = selectedItem
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Pinned or Recent title
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 14)
            
            if items.isEmpty {
                // Empty state card inside horizontal scroll Row
                HStack {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.textSecondary)
                        Text("Section is empty")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                    }
                    .frame(width: 188, height: 140)
                    .background(Theme.bgSecondary.opacity(0.4))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.borderSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    )
                    .padding(.horizontal, 14)
                }
            } else {
                // Scroll container with horizontal cards
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(items, id: \.id) { item in
                            ClipCardView(item: item, isSelected: selectedItem?.id == item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(item)
                                }
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 146)
                }
                .mask(
                    HStack(spacing: 0) {
                        // Left edge fade
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.08)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 25)
                        
                        // Main viewport container
                        Color.white
                        
                        // Right edge fade
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white, location: 0.92),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 25)
                    }
                )
            }
        }
    }
}
