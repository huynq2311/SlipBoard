import SwiftUI

@main
struct SlipTrayCompanionApp: App {
    @StateObject private var model = CompanionRootCoordinator.makeScreenModel()
    var body: some Scene { WindowGroup { CompanionBridgeScreen(model: model) } }
}
