struct FixtureSlipBoardSessionProvider: SlipBoardSessionProviding {
    let initialPreset: SlipBoardSessionPreset

    init(initialPreset: SlipBoardSessionPreset = .popupDemo) {
        self.initialPreset = initialPreset
    }

    func initialSession() -> SlipBoardAppSession {
        fixtureSession(named: initialPreset)
    }

    func fixtureSession(named preset: SlipBoardSessionPreset) -> SlipBoardAppSession {
        SlipBoardSessionFixtures.session(named: preset)
    }
}
