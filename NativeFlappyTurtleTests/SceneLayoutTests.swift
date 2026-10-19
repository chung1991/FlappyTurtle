import SpriteKit
import XCTest
@testable import NativeFlappyTurtle

/// Layout parity with GameLayer.cpp / GameScene.cpp, using positions computed
/// by hand from the original formulas, plus the test hooks themselves.
final class SceneLayoutTests: XCTestCase {
    private func makeScene(aspect: CGFloat = 1.5, showBegin: Bool = true,
                           highScore: Int = 0) -> (GameScene, GameController) {
        let (controller, _, _, _) = makeController(highScore: highScore)
        let scene = GameScene(viewport: Viewport(aspect: aspect), controller: controller, showBegin: showBegin)
        return (scene, controller)
    }

    func testViewportMatchesAppDelegateMaths() {
        XCTAssertEqual(Viewport(aspect: 1.5).displaySize, CGSize(width: 960, height: 640))
        XCTAssertEqual(Viewport(aspect: 1.5).vectorMove, .zero)
        let wide = Viewport(aspect: 16.0 / 9.0)
        XCTAssertEqual(wide.displaySize.width, 1137.78, accuracy: 0.01)
        XCTAssertEqual(wide.vectorMove.x, 88.89, accuracy: 0.01)
    }

    func testTitleBoardPositions() {
        let (scene, _) = makeScene()
        let hud = scene.hud
        XCTAssertEqual(hud.playButton.position, CGPoint(x: 480, y: 371.5))
        XCTAssertEqual(hud.shareHighScoreButton.position, CGPoint(x: 480, y: 262.5))
        XCTAssertEqual(hud.pauseButton.position, CGPoint(x: 42, y: 597))
        XCTAssertEqual(hud.replayButton.position, CGPoint(x: 380, y: 223))
        XCTAssertEqual(hud.shareScoreButton.position, CGPoint(x: 580, y: 223))
        XCTAssertEqual(scene.interactiveButtons.map(\.button.identifier), ["ft.play", "ft.shareHighScore"])
    }

    func testScoreDigitsAreCentredLikeUpdateScore() {
        let (scene, controller) = makeScene()
        controller.model.currentScore = 7
        scene.syncNodes()
        // One digit: posX 35, newPosX 35 + 18 -> node x = 480 - 26.5.
        XCTAssertEqual(scene.hud.scoreNode.position, CGPoint(x: 453.5, y: 590))
        controller.model.currentScore = 42
        scene.syncNodes()
        XCTAssertEqual(scene.hud.scoreNode.position.x, 480 - (70 + 18) / 2)
        XCTAssertEqual(scene.hud.scoreNode.children.count, 2)
    }

    func testPlayButtonHidesBoardAndShowsInstructions() {
        let (scene, _) = makeScene()
        scene.hud.playButton.action?()
        scene.applyStateVisibility()
        XCTAssertTrue(scene.hud.beginLayer.isHidden)
        XCTAssertTrue(scene.hud.isInstructionShown)
    }

    func testGameOverHookShowsFinishedBoard() {
        let (scene, controller) = makeScene(highScore: 30)
        TestHooks.apply(LaunchConfig(arguments: ["-ft-scene", "gameover", "-ft-score", "42", "-ft-freeze"]), to: scene)
        XCTAssertEqual(controller.model.state, .finish)
        XCTAssertEqual(controller.model.highScore, 42)
        XCTAssertTrue(scene.hud.isFinishShown)
        XCTAssertEqual(controller.model.turtle.position.y, GameConfig.groundY, accuracy: 1e-6)
        XCTAssertEqual(Set(scene.interactiveButtons.map(\.button.identifier)), ["ft.replay", "ft.shareScore"])
        XCTAssertEqual(TestHooks.stateDescription(of: scene),
                       "state=finish score=42 high=42 begin=0 instruction=0 pause=0 finish=1 obstacles=0 frozen=1")
    }

    func testPlayingHookIsDeterministic() {
        func run() -> [Obstacle] {
            let (controller, _, _, _) = makeController(random: SeededRandomSource(seed: 7))
            let scene = GameScene(viewport: Viewport(aspect: 1.5), controller: controller, showBegin: true)
            TestHooks.apply(LaunchConfig(arguments: ["-ft-scene", "playing", "-ft-seed", "7", "-ft-advance", "6"]), to: scene)
            XCTAssertEqual(controller.model.state, .play)
            return controller.model.obstacles
        }
        let first = run()
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, run())
    }
}
