import SwiftUI

@main
struct SlipBoardCompanionApp: App {
    @StateObject private var model = CompanionRootCoordinator.makeScreenModel()
    var body: some Scene { WindowGroup { CompanionBridgeScreen(model: model) } }
}
