protocol SlipBoardSessionProviding {
    func initialSession() -> SlipBoardAppSession
    func fixtureSession(named preset: SlipBoardSessionPreset) -> SlipBoardAppSession
}
