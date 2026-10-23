import AppIntents

struct CompanionBridgeAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open SlipTray Bridge"
    func perform() async throws -> some IntentResult & OpensIntent { .result(opensIntent: OpenURLIntent(URL(string: "sliptray://companion/import")!)) }
}
