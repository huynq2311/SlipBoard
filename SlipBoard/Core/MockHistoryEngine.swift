import Foundation
import Combine

public class MockHistoryEngine: HistoryEngineProtocol {
    @Published public var items: [ClipItem] = []
    @Published public var activeFilter: ClipType? = nil
    @Published public var searchQuery: String = ""
    
    public var pinnedItems: [ClipItem] {
        filteredItems.filter { $0.isPinned }
    }
    
    public var recentItems: [ClipItem] {
        filteredItems.filter { !$0.isPinned }
    }
    
    private var filteredItems: [ClipItem] {
        var result = items
        
        if let filter = activeFilter {
            result = result.filter { $0.contentType == filter }
        }
        
        if !searchQuery.isEmpty {
            result = result.filter { 
                $0.contentString.localizedCaseInsensitiveContains(searchQuery) ||
                $0.sourceApp.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.note?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }
        
        return result
    }
    
    public init() {
        loadMockData()
    }
    
    private func loadMockData() {
        self.items = [
            ClipItem(
                contentType: .text,
                contentString: "React hooks let you use state and other React features without writing a class.",
                sourceApp: "Safari",
                sourceAppIcon: "safari",
                timestamp: Date().addingTimeInterval(-120),
                isPinned: false
            ),
            ClipItem(
                contentType: .code,
                contentString: "func fetchUserData(id: UUID) async throws -> User {\n    let url = URL(string: \"https://api.domain.com/user/\\(id)\")!\n    let (data, _) = try await URLSession.shared.data(from: url)\n    return try JSONDecoder().decode(User.self, from: data)\n}",
                sourceApp: "Xcode",
                sourceAppIcon: "curlybraces",
                timestamp: Date().addingTimeInterval(-600),
                isPinned: true
            ),
            ClipItem(
                contentType: .image,
                contentString: "figma_vector_asset_2026.png",
                sourceApp: "Figma",
                sourceAppIcon: "paintpalette",
                timestamp: Date().addingTimeInterval(-3600),
                isPinned: false
            ),
            ClipItem(
                contentType: .file,
                contentString: "annual_financial_report.pdf",
                sourceApp: "Finder",
                sourceAppIcon: "folder",
                timestamp: Date().addingTimeInterval(-7200),
                isPinned: false
            ),
            ClipItem(
                contentType: .url,
                contentString: "https://news.ycombinator.com/item?id=45239920",
                sourceApp: "Arc",
                sourceAppIcon: "network",
                timestamp: Date().addingTimeInterval(-10800),
                isPinned: false
            ),
            ClipItem(
                contentType: .text,
                contentString: "Antigravity coding assistant is Google DeepMind's flagship pair programming agent.",
                sourceApp: "Terminal",
                sourceAppIcon: "terminal",
                timestamp: Date().addingTimeInterval(-15000),
                isPinned: true,
                note: "Important tool info"
            )
        ]
    }
    
    public func selectItem(_ item: ClipItem) {
        print("Pasting item: \(item.contentString)")
    }
    
    public func pinItem(_ item: ClipItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isPinned.toggle()
        }
    }
    
    public func deleteItem(_ item: ClipItem) {
        items.removeAll(where: { $0.id == item.id })
    }
    
    public func saveNote(for item: ClipItem, note: String) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].note = note.isEmpty ? nil : note
        }
    }
}
