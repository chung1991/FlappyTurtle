import XCTest
@testable import NativeFlappyTurtle

/// From the 10th pair on, gaps move up and down (GameConfig.movingGap*).
final class MovingGapTests: XCTestCase {
    func testBandIsKeptInsideSpawnRange() {
        XCTAssertEqual(GapMotion(spawnCentre: 300).low, 210)
        XCTAssertEqual(GapMotion(spawnCentre: 170).low, 170)
        XCTAssertEqual(GapMotion(spawnCentre: 519).low, 340)
        XCTAssertEqual(GapMotion(spawnCentre: 519).high, 520)
    }

    func testStartsTowardsTheMiddleAndBounces() {
        var low = GapMotion(spawnCentre: 200)    // band 170...350, moving up at 50 pt/s
        low.advance(0.5)
        XCTAssertEqual(low.centre, 225, accuracy: 1e-9)
        low.advance(3.0)                          // 375 -> reflects off 350
        XCTAssertEqual(low.centre, 325, accuracy: 1e-9)
        XCTAssertEqual(low.direction, -1)

        var high = GapMotion(spawnCentre: 500)   // band 340...520, moving down
        high.advance(0.5)
        XCTAssertEqual(high.centre, 475, accuracy: 1e-9)
    }

    func testClosedFormPredictionMatchesStepping() {
        for spawn: CGFloat in [170, 260, 345, 519] {
            var stepped = GapMotion(spawnCentre: spawn)
            let start = stepped
            for frame in 1...600 {
                stepped.advance(1.0 / 60.0)
                XCTAssertEqual(start.centre(after: CGFloat(frame) / 60), stepped.centre, accuracy: 1e-6)
            }
        }
    }

    func testMovingPipesStayAnchoredWithConstantGap() {
        let motion = GapMotion(spawnCentre: 300)
        var up = Obstacle(id: 1, position: CGPoint(x: 0, y: 640), height: 230, isFlipped: true,
                          holeCenter: 300, pairNumber: 10, motion: motion)
        var down = Obstacle(id: 2, position: CGPoint(x: 0, y: 190), height: 140, isFlipped: false,
                            holeCenter: 300, pairNumber: 10, motion: motion)
        for _ in 0..<200 {
            up.advanceMotion(frame)
            down.advanceMotion(frame)
            XCTAssertEqual(up.position.y, 640)
            XCTAssertEqual(down.position.y - down.height, 50, accuracy: 1e-9)
            XCTAssertEqual((up.position.y - up.height) - down.position.y, 220, accuracy: 1e-9)
            XCTAssertEqual(up.holeCenter, down.holeCenter)
        }
    }

    func testOnlyPairsFromTheTenthMoveAndNumberingRestartsOnReplay() {
        let (controller, _, _, _) = makeController(random: SeededRandomSource(seed: 1))
        controller.handle(.jump)
        let model = controller.model
        var seen: [Int: Bool] = [:]
        while model.pairsSpawned < 11, model.state == .play {
            Autopilot.run(controller, seconds: 1.0 / 60.0)
            for obstacle in model.obstacles { seen[obstacle.pairNumber] = obstacle.motion != nil }
        }
        XCTAssertEqual(model.state, .play)
        XCTAssertEqual((1...9).map { seen[$0] }, Array(repeating: false, count: 9))
        XCTAssertEqual(seen[10], true)
        XCTAssertEqual(seen[11], true)

        model.gameOver()
        controller.handle(.replay)
        XCTAssertEqual(model.pairsSpawned, 0)
    }

    func testBotStillClearsMovingPairs() {
        for seed in UInt64(1)...5 {
            let (controller, _, _, _) = makeController(random: SeededRandomSource(seed: seed))
            controller.handle(.jump)
            Autopilot.run(controller, seconds: 40)
            XCTAssertEqual(controller.model.state, .play, "seed \(seed) died at score \(controller.model.currentScore)")
            XCTAssertGreaterThan(controller.model.pairsSpawned, 15)
        }
    }
}
