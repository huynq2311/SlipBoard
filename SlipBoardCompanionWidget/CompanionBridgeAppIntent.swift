import AppIntents

struct CompanionBridgeAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open SlipBoard Bridge"
    func perform() async throws -> some IntentResult & OpensIntent { .result(opensIntent: OpenURLIntent(URL(string: "slipboard://companion/import")!)) }
}
