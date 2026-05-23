import SwiftUI

public struct TopFilterBar: View {
    @Binding public var activeFilter: ClipType?
    @Binding public var searchQuery: String
    @State private var isSearching = false
    public let itemsCount: (ClipType?) -> Int
    
    public init(
        activeFilter: Binding<ClipType?>,
        searchQuery: Binding<String>,
        itemsCount: @escaping (ClipType?) -> Int
    ) {
        self._activeFilter = activeFilter
        self._searchQuery = searchQuery
        self.itemsCount = itemsCount
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Search Input Box (expandable toggle)
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            isSearching.toggle()
                        }
                    }
                
                if isSearching || !searchQuery.isEmpty {
                    TextField("Search...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 120)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Theme.bgSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.borderSecondary.opacity(0.5), lineWidth: 0.5)
            )
            
            Spacer()
            
            // Category filter pills list
            HStack(spacing: 4) {
                // "All" Pill
                FilterPillButton(
                    title: "All",
                    count: itemsCount(nil),
                    isActive: activeFilter == nil,
                    action: { activeFilter = nil }
                )
                
                // Specific Type Pills
                ForEach(ClipType.allCases, id: \.self) { type in
                    FilterPillButton(
                        title: type.rawValue,
                        count: itemsCount(type),
                        isActive: activeFilter == type,
                        action: { activeFilter = type }
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct FilterPillButton: View {
    let title: String
    let count: Int
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                
                Text("\(count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(isActive ? .white.opacity(0.8) : Theme.textTertiary)
            }
            .foregroundColor(isActive ? .white : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Theme.accent : (isHovered ? Theme.bgTertiary : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hover
            }
        }
    }
}
