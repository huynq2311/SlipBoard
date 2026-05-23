import Foundation
import Combine

public protocol HistoryEngineProtocol: ObservableObject {
    var items: [ClipItem] { get }
    var pinnedItems: [ClipItem] { get }
    var recentItems: [ClipItem] { get }
    var activeFilter: ClipType? { get set }
    var searchQuery: String { get set }
    
    func selectItem(_ item: ClipItem)
    func pinItem(_ item: ClipItem)
    func deleteItem(_ item: ClipItem)
    func saveNote(for item: ClipItem, note: String)
}
