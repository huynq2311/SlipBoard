import WidgetKit
import SwiftUI

struct CompanionBridgeWidget: Widget {
    let kind = "CompanionBridgeWidget"
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: CompanionBridgeWidgetProvider()) { _ in CompanionBridgeWidgetEntryView() }.configurationDisplayName("SlipTray Bridge") }
}

struct CompanionBridgeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> Date { .now }
    func getSnapshot(in context: Context, completion: @escaping (Date) -> Void) { completion(.now) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Date>) -> Void) { completion(Timeline(entries: [.now], policy: .never)) }
}
