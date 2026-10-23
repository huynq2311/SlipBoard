import Foundation

@MainActor
enum CompanionRootCoordinator {
    static func makeScreenModel() -> CompanionBridgeScreenModel {
        let transport = CompanionBridgeCloudKitAdapter()
        let receiver = CompanionBridgeReceiveController(transport: transport, ledger: CompanionBridgeLocalLedger())
        let runtime = CompanionBridgeRuntimeController(
            importer: CompanionBridgeImportCoordinator(), receiver: receiver,
            clipboard: CompanionBridgeClipboardAdapter(), publish: { draft in await transport.publish(draft) }
        )
        return CompanionBridgeScreenModel(runtime: runtime)
    }
}
