import XCTest

/// Jumps straight to each scene with the launch hooks, freezes it, and compares
/// the screen with a recorded baseline. Adding a scene/feature? Add a case here
/// (and a hook in LaunchConfig/TestHooks if it needs a new state).
final class SceneSnapshotTests: XCTestCase {
    private let game = GameApp()

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    private func snapshot(_ name: String, scene: String, _ extra: [String] = []) {
        game.launch(scene: scene, ["-ft-seed", "7", "-ft-freeze"] + extra)
        XCTAssertTrue(game.wait("frozen", "1"))
        // Let the first frames land on screen.
        Thread.sleep(forTimeInterval: 1.0)
        SnapshotAssert.assertScreen(named: name)
    }

    func testMenu() { snapshot("menu", scene: "menu") }

    func testReady() { snapshot("ready", scene: "ready") }

    func testPlaying() { snapshot("playing", scene: "playing", ["-ft-advance", "6"]) }

    /// Pair 10 (~20 s in) is the first with a moving gap.
    func testPlayingMovingGap() { snapshot("playing-moving-gap", scene: "playing", ["-ft-advance", "21.2"]) }

    func testPaused() { snapshot("paused", scene: "paused", ["-ft-score", "5"]) }

    func testGameOver() { snapshot("gameover", scene: "gameover", ["-ft-score", "12", "-ft-highscore", "30"]) }

    func testGameOverNewHighScore() {
        snapshot("gameover-new-high", scene: "gameover", ["-ft-score", "42", "-ft-highscore", "30"])
    }
}
