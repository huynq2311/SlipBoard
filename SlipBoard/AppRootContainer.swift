import SwiftUI

struct AppRootContainer<Provider: SlipBoardSessionProviding>: View {
    private let session: SlipBoardAppSession

    init(provider: Provider) {
        session = provider.initialSession()
    }

    init(session: SlipBoardAppSession) {
        self.session = session
    }

    var body: some View {
        SessionPreviewHost(session: session)
    }
}
