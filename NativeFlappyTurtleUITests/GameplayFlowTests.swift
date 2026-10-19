import XCTest

/// Real taps through the game, asserting on the state probe — catches broken
/// wiring that a frozen screenshot cannot (buttons, touch routing, replay).
final class GameplayFlowTests: XCTestCase {
    private let game = GameApp()

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testFullRound() {
        game.launch()
        XCTAssertTrue(game.wait("state", "wait"))
        XCTAssertTrue(game.wait("begin", "1"))

        // Tapping the sky on the title board does nothing.
        game.tapGame()
        XCTAssertEqual(game.state["state"], "wait")

        game.button("ft.play").tap()
        XCTAssertTrue(game.wait("instruction", "1"))
        XCTAssertEqual(game.state["begin"], "0")

        // First tap starts the round; without more flaps the turtle drops.
        game.tapGame()
        XCTAssertTrue(game.wait("state", "finish"))
        XCTAssertTrue(game.button("ft.replay").waitForExistence(timeout: 5))
        XCTAssertTrue(game.button("ft.shareScore").exists)
        XCTAssertFalse(game.button("ft.pause").exists)

        game.button("ft.replay").tap()
        XCTAssertTrue(game.wait("state", "wait"))
        XCTAssertTrue(game.wait("begin", "0"), "replay skips the title board")
        XCTAssertTrue(game.wait("instruction", "1"))
    }

    func testPauseAndResume() {
        // Autopilot keeps the round alive while we poke at it.
        game.launch(scene: "playing", ["-ft-seed", "7", "-ft-autopilot"])
        XCTAssertTrue(game.wait("state", "play"))

        game.button("ft.pause").tap()
        XCTAssertTrue(game.wait("state", "pause"))
        XCTAssertTrue(game.wait("pause", "1"))
        let frozenScore = game.state["score"]

        // Pause button again is swallowed by the menu: still paused.
        game.button("ft.pause").tap()
        XCTAssertEqual(game.state["state"], "pause")
        XCTAssertEqual(game.state["score"], frozenScore)

        game.tapGame()
        XCTAssertTrue(game.wait("state", "play"))
        XCTAssertTrue(game.wait("pause", "0"))
    }

    func testAutopilotScores() {
        game.launch(scene: "playing", ["-ft-seed", "3", "-ft-advance", "0.1", "-ft-autopilot"])
        XCTAssertTrue(game.wait("score", "2", timeout: 15), "probe: \(game.probe.label)")
        XCTAssertEqual(game.state["state"], "play")
    }

    func testDeepLinkRestartsIntoScene() throws {
        guard #available(iOS 16.4, *) else { throw XCTSkip("XCUIApplication.open needs iOS 16.4") }
        game.launch()
        XCTAssertTrue(game.wait("state", "wait"))
        let url = URL(string: "nativeflappyturtle://launch?scene=gameover&score=9&highscore=3&freeze=1&mute=1")!
        game.app.open(url)
        XCTAssertTrue(game.wait("state", "finish"))
        XCTAssertEqual(game.state["high"], "9")
    }
}
