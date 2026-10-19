import XCTest
@testable import NativeFlappyTurtle

/// Rules ported from FlappyModel.cpp / Turtle.cpp. Expected numbers are worked
/// out by hand from the original code paths.
final class GameModelTests: XCTestCase {
    func testInitialStateMatchesFlappyModelWait() {
        let model = GameModel(random: FixedRandomSource(0), store: InMemoryHighScoreStore())
        XCTAssertEqual(model.state, .wait)
        XCTAssertEqual(model.turtle.position, CGPoint(x: 240, y: 320))
        XCTAssertEqual(model.lands.map(\.position), [CGPoint(x: 0, y: 25)])
        XCTAssertEqual(model.stars.map(\.position), [CGPoint(x: 0, y: 547.5)])
        XCTAssertEqual(model.currentScore, 0)
        XCTAssertTrue(model.obstacles.isEmpty)
    }

    func testWaitScrollsEnvironmentButTurtleHovers() {
        let model = GameModel(random: FixedRandomSource(0), store: InMemoryHighScoreStore())
        model.update(0.5)
        XCTAssertEqual(model.turtle.position, CGPoint(x: 240, y: 320), "World is not stepped in GS_WAIT")
        // Land moves at -250/s; once x < 0 the next tile is appended at x + 1150.
        XCTAssertEqual(model.lands.map(\.position.x), [-125, 1025])
        XCTAssertTrue(model.lands[0].passHead)
        // Stars move at -20/s.
        XCTAssertEqual(model.stars.map(\.position.x), [-10, 1140])
    }

    func testLandTileRemovedOncePastItsWidth() {
        let model = GameModel(random: FixedRandomSource(0), store: InMemoryHighScoreStore())
        model.update(0.1)            // first tile -25, second appended at 1125
        model.update(4.6)            // first -1175 (< -1150) -> removed
        XCTAssertEqual(model.lands.count, 1)
        XCTAssertEqual(model.lands[0].position.x, 1125 - 1150, accuracy: 0.001)
        XCTAssertFalse(model.lands[0].passHead)
    }

    func testJumpSetsBox2DVelocityAndRotation() {
        let (controller, sound, _, _) = makeController()
        controller.handle(.jump)
        let model = controller.model
        XCTAssertEqual(model.state, .play)
        XCTAssertEqual(model.turtle.worldVelocityY, 20)
        XCTAssertEqual(model.turtle.rotation, 30)
        XCTAssertEqual(model.turtle.spinVelocity, 0)
        XCTAssertEqual(model.turtle.spinAccel, -1)
        XCTAssertEqual(sound.played, [.jump])
    }

    func testOneBox2DStepIsSemiImplicitEuler() {
        let (controller, _, _, _) = makeController()
        controller.handle(.jump)
        controller.model.update(frame)
        // v = 20 - 70/60 ; y = 320 + 32 * v / 60
        let v: CGFloat = 20 - 70.0 / 60.0
        XCTAssertEqual(controller.model.turtle.worldVelocityY, v, accuracy: 1e-9)
        XCTAssertEqual(controller.model.turtle.position.y, 320 + 32 * v / 60, accuracy: 1e-9)
    }

    func testRotationCurveFollowsTurtleUpdate() {
        let (controller, _, _, _) = makeController()
        controller.handle(.jump)
        let model = controller.model
        model.update(0.1)
        // rotation += 0; accel = 0.3 -> sub = 15 * 0.3
        XCTAssertEqual(model.turtle.rotation, 30, accuracy: 1e-9)
        XCTAssertEqual(model.turtle.rotationVelocity, -4.5, accuracy: 1e-9)
        model.update(0.1)
        // rotation = 30 - 0.45; accel = 1.6 -> sub = 15 * 1.6 = 24
        XCTAssertEqual(model.turtle.rotation, 29.55, accuracy: 1e-9)
        XCTAssertEqual(model.turtle.rotationVelocity, -28.5, accuracy: 1e-9)
    }

    func testSpinIsClampedAndRotationBottomsOutAtMinus90() {
        let (controller, _, _, _) = makeController()
        controller.handle(.jump)
        controller.model.run(frames: 600, until: { $0.state == .finish })
        XCTAssertEqual(controller.model.turtle.rotation, -90)
        XCTAssertGreaterThanOrEqual(controller.model.turtle.spinVelocity, -500)
    }

    func testHittingTheGroundEndsTheGame() {
        let (controller, sound, _, _) = makeController()
        var events: [GameEvent] = []
        controller.onModelEvent = { events.append($0) }
        controller.handle(.jump)
        controller.model.run(frames: 600, until: { $0.state == .finish })
        XCTAssertEqual(controller.model.state, .finish)
        XCTAssertEqual(controller.model.turtle.position.y, GameConfig.groundY, accuracy: 1e-9)
        XCTAssertEqual(events, [.gameOver(isHighScore: false)])
        XCTAssertEqual(sound.played.last, .die)
    }

    func testTurtleKeepsFallingToGroundAfterGameOverAndStripsStop() {
        let (controller, _, _, _) = makeController(random: FixedRandomSource(349))
        controller.handle(.jump)
        let model = controller.model
        // Gap 409...629: hovering at 320 hits the bottom pipe mid-air.
        model.run(frames: 1200, hoverY: 320, until: { $0.state == .finish })
        XCTAssertEqual(model.state, .finish)
        XCTAssertGreaterThan(model.turtle.position.y, GameConfig.groundY, "Died on a pipe, not the ground")
        let lands = model.lands
        let obstacles = model.obstacles
        model.run(frames: 120)
        XCTAssertEqual(model.turtle.position.y, GameConfig.groundY, accuracy: 1e-9)
        XCTAssertEqual(model.lands, lands, "Land stops in GS_FINISH")
        XCTAssertEqual(model.obstacles, obstacles, "Obstacles only move in GS_PLAY")
    }

    func testObstaclesSpawnEveryTwoSecondsWithOriginalGeometry() throws {
        let (controller, _, _, _) = makeController(random: FixedRandomSource(100))
        controller.handle(.jump)
        let model = controller.model
        var spawnFrame: Int?
        for i in 1...130 where spawnFrame == nil {
            model.run(frames: 1, autopilot: true)
            if !model.obstacles.isEmpty { spawnFrame = i }
        }
        let first = try XCTUnwrap(spawnFrame)
        XCTAssertTrue((119...122).contains(first), "spawned at frame \(first)")

        // hole = 100 + 170 = 270 -> up height 640 - 380, down height 270 - 110 - 50.
        let up = model.obstacles[0], down = model.obstacles[1]
        XCTAssertTrue(up.isFlipped)
        XCTAssertFalse(down.isFlipped)
        XCTAssertEqual(up.height, 260)
        XCTAssertEqual(down.height, 110)
        XCTAssertEqual(up.position.y, 640)
        XCTAssertEqual(down.position.y, 160)
        // Spawned at 960 + 75 and moved once in the same frame.
        XCTAssertEqual(up.position.x, 1035 - 250 * frame, accuracy: 1e-6)

        // 2.0s later (+ a few frames: float accumulation decides the exact frame).
        model.run(frames: 115, autopilot: true)
        XCTAssertEqual(model.obstacles.count, 2, "no second pair before 2s")
        model.run(frames: 10, autopilot: true)
        XCTAssertEqual(model.state, .play)
        XCTAssertEqual(model.obstacles.count, 4, "second pair two seconds later")
    }

    func testPassingAPairScoresOnceAndPlaysPassSound() {
        let (controller, sound, _, _) = makeController(random: FixedRandomSource(150)) // gap centre 320
        controller.handle(.jump)
        let model = controller.model
        var scores: [Int] = []
        controller.onModelEvent = { if case let .scored(score) = $0 { scores.append(score) } }
        // Pair spawns at ~2s and reaches x < 240 after (1035 - 240) / 250 = 3.18s.
        model.run(frames: 60 * 6, autopilot: true)
        XCTAssertEqual(model.state, .play)
        XCTAssertEqual(scores, [1])
        XCTAssertEqual(model.currentScore, 1)
        XCTAssertTrue(sound.played.contains(.pass))
    }

    func testObstaclesRemovedOnceOffScreenLeft() {
        let (controller, _, _, _) = makeController(random: FixedRandomSource(150))
        controller.handle(.jump)
        let model = controller.model
        // First pair: spawn ~2s, needs (1035 + 75) / 250 = 4.44s to leave.
        model.run(frames: Int(60 * 6.5), autopilot: true)
        XCTAssertEqual(model.state, .play)
        XCTAssertTrue(model.obstacles.allSatisfy { $0.position.x >= -75 })
        XCTAssertEqual(model.obstacles.count, 4)
    }

    func testPauseFreezesEverythingAndResumeContinues() {
        let (controller, sound, _, _) = makeController()
        controller.handle(.jump)
        let model = controller.model
        model.run(frames: 10)
        controller.handle(.pause)
        XCTAssertEqual(model.state, .pause)
        XCTAssertEqual(sound.played.last, .jump, "click sound reuses the jump effect")
        let turtle = model.turtle, lands = model.lands
        model.run(frames: 120)
        XCTAssertEqual(model.turtle, turtle)
        XCTAssertEqual(model.lands, lands)
        controller.handle(.jump)
        XCTAssertEqual(model.turtle, turtle, "jump is ignored while paused")
        controller.handle(.resume)
        XCTAssertEqual(model.state, .play)
    }

    func testJumpIgnoredOnceAboveTheScreen() {
        let model = GameModel(random: FixedRandomSource(0), store: InMemoryHighScoreStore())
        model.play()
        model.jump()
        var guardFrames = 0
        while model.turtle.position.y < 640 && guardFrames < 600 {
            model.jump()
            model.update(frame)
            guardFrames += 1
        }
        XCTAssertGreaterThanOrEqual(model.turtle.position.y, 640)
        let velocity = model.turtle.worldVelocityY
        model.jump()
        XCTAssertEqual(model.turtle.worldVelocityY, velocity)
    }

    func testReplayResetsRound() {
        let (controller, _, _, _) = makeController()
        var replayed = 0
        controller.onReplay = { replayed += 1 }
        controller.handle(.jump)
        controller.model.currentScore = 3
        controller.model.run(frames: 600, until: { $0.state == .finish })
        controller.handle(.replay)
        let model = controller.model
        XCTAssertEqual(replayed, 1)
        XCTAssertEqual(model.state, .wait)
        XCTAssertEqual(model.currentScore, 0)
        XCTAssertEqual(model.highScore, 3)
        XCTAssertEqual(model.turtle, Turtle())
        XCTAssertEqual(model.lands.count, 1)
        XCTAssertTrue(model.obstacles.isEmpty)
    }

    func testHighScoreOnlySavedWhenBeaten() {
        let (controller, _, _, store) = makeController(highScore: 5)
        var events: [GameEvent] = []
        controller.onModelEvent = { events.append($0) }
        let model = controller.model
        model.play()
        model.currentScore = 5
        model.gameOver()
        XCTAssertEqual(store.value, 5)
        model.replay()
        model.play()
        model.currentScore = 7
        model.gameOver()
        XCTAssertEqual(store.value, 7)
        XCTAssertEqual(model.highScore, 7)
        XCTAssertEqual(events, [.gameOver(isHighScore: false), .gameOver(isHighScore: true)])
    }

    func testLargeStepIsClampedByMaxTranslation() {
        let model = GameModel(random: FixedRandomSource(0), store: InMemoryHighScoreStore())
        model.play()
        model.jump()
        model.update(0.2)
        // v = 20 - 14 = 6 m/s -> 1.2 m (< 2 m, unclamped)
        XCTAssertEqual(model.turtle.worldVelocityY, 6, accuracy: 1e-9)
        let fast = GameModel(random: FixedRandomSource(0), store: InMemoryHighScoreStore())
        fast.play()
        fast.update(0.5)
        // v = -35 m/s -> 17.5 m step > 2 m, so v is scaled to 2 / 0.5 = 4 m/s
        XCTAssertEqual(fast.turtle.worldVelocityY, -4, accuracy: 1e-9)
    }
}
