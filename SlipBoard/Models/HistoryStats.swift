import Foundation

public protocol HistoryStatsProvider: ObservableObject {
    var totalItemsCount: Int { get }
    var currentRetentionLabel: String { get }
}
