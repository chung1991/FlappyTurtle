import XCTest
@testable import NativeFlappyTurtle

/// End-to-end regression for the physics: a simple bot must still be able to
/// clear pipes. If a tuning change makes the game unbeatable, this fails.
final class AutopilotTests: XCTestCase {
    func testBotSurvivesAMinuteOnSeveralSeeds() {
        for seed in UInt64(1)...5 {
            let (controller, _, _, _) = makeController(random: SeededRandomSource(seed: seed))
            controller.handle(.jump)
            Autopilot.run(controller, seconds: 60)
            XCTAssertEqual(controller.model.state, .play, "seed \(seed) died at score \(controller.model.currentScore)")
            XCTAssertGreaterThanOrEqual(controller.model.currentScore, 25, "seed \(seed)")
        }
    }
}
