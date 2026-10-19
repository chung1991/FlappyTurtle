import CoreGraphics
import XCTest
@testable import NativeFlappyTurtle

// Hidden verifier for Verification/moving-pipes/TASK.md.
// Uses only API that exists at the base commit, so it compiles against the
// unfixed code (FAIL_TO_PASS tests then fail) and against any solution.

private let dt: CGFloat = 1.0 / 60.0
private let gapSize: CGFloat = 220
private let land: CGFloat = 50
private let top: CGFloat = 640

/// One pipe pair as observed in a frame, derived from public geometry only.
private struct PairSample {
    let pairNumber: Int
    let x: CGFloat
    let topPipe: Obstacle
    let bottomPipe: Obstacle
    var gapBottom: CGFloat { bottomPipe.position.y }
    var gapTop: CGFloat { topPipe.position.y - topPipe.height }
    var centre: CGFloat { (gapBottom + gapTop) / 2 }
    var pipeRects: [OrientedBox] {
        [topPipe, bottomPipe].map {
            OrientedBox(center: CGPoint(x: $0.position.x, y: $0.position.y - $0.height / 2),
                        size: CGSize(width: 150, height: $0.height))
        }
    }
}

/// Drives a round frame by frame and numbers pairs in spawn order.
private final class Round {
    let model: GameModel
    private(set) var frame = 0
    private var pairOf: [Int: Int] = [:]      // obstacle id -> pair number
    private var spawned = 0
    private(set) var history: [Int: [(frame: Int, sample: PairSample)]] = [:]

    init(seed: UInt64) {
        model = GameModel(random: SeededRandomSource(seed: seed), store: InMemoryHighScoreStore())
        model.play()
        model.jump()
    }

    /// Pairs currently on screen, oldest first.
    var pairs: [PairSample] {
        var grouped: [Int: [Obstacle]] = [:]
        for obstacle in model.obstacles {
            grouped[pairOf[obstacle.id]!, default: []].append(obstacle)
        }
        return grouped.keys.sorted().compactMap { number in
            let members = grouped[number]!
            guard let t = members.first(where: { $0.isFlipped }),
                  let b = members.first(where: { !$0.isFlipped }) else { return nil }
            return PairSample(pairNumber: number, x: t.position.x, topPipe: t, bottomPipe: b)
        }
    }

    /// Flies through gaps using only the visible geometry.
    func pilotWantsJump(hover: CGFloat? = nil) -> Bool {
        let turtle = model.turtle
        guard turtle.worldVelocityY <= 0 else { return false }
        let target = hover ?? nextPair?.centre ?? 320
        return turtle.position.y < target - 30
    }

    var nextPair: PairSample? {
        let turtleLeft = model.turtle.position.x - 47.5
        return pairs.first { $0.x + 75 > turtleLeft }
    }

    func step(jump: Bool) {
        if jump { model.jump() }
        model.update(dt)
        frame += 1
        for obstacle in model.obstacles where pairOf[obstacle.id] == nil {
            // Pipes spawn in (top, bottom) pairs.
            pairOf[obstacle.id] = spawned / 2 + 1
            spawned += 1
        }
        for pair in pairs {
            history[pair.pairNumber, default: []].append((frame, pair))
        }
    }

    /// Pilots until `condition` holds; fails the test if the turtle dies first.
    func fly(until condition: (Round) -> Bool, limit: Int = 60 * 40,
             file: StaticString = #filePath, line: UInt = #line) -> Bool {
        while !condition(self) {
            guard model.state == .play, frame < limit else {
                XCTFail("pilot died/timed out at frame \(frame), score \(model.currentScore)", file: file, line: line)
                return false
            }
            step(jump: pilotWantsJump())
        }
        return true
    }

    func seen(_ number: Int) -> Bool { history[number] != nil }
}

/// Reference gap-centre trace from TASK.md (50 pt/s, 180 band, bounce).
private func referenceCentres(spawn: CGFloat, frames: Int) -> [CGFloat] {
    let lo = min(max(spawn - 90, 170), 340), hi = lo + 180
    var centre = spawn
    var direction: CGFloat = spawn < 345 ? 1 : -1
    var out: [CGFloat] = []
    for _ in 0..<frames {
        centre += direction * 50 * dt
        if centre > hi { centre = 2 * hi - centre; direction = -1 }
        if centre < lo { centre = 2 * lo - centre; direction = 1 }
        out.append(centre)
    }
    return out
}

/// Spawn centre of pair `n` for a seed: the base game draws once per pair.
private func spawnCentre(seed: UInt64, pair n: Int) -> CGFloat {
    let random = SeededRandomSource(seed: seed)
    var hole = 0
    for _ in 0..<n { hole = random.nextInt(350) + 170 }
    return CGFloat(hole)
}

final class MovingPipesVerifierTests: XCTestCase {
    private let seeds: [UInt64] = [1, 2, 3]

    // MARK: FAIL_TO_PASS

    func testTenthPairGapMoves() {
        for seed in seeds {
            let round = Round(seed: seed)
            guard round.fly(until: { $0.seen(10) }) else { return }
            let start = round.frame
            guard round.fly(until: { $0.frame >= start + 90 }) else { return }
            let centres = round.history[10]!.map(\.sample.centre)
            let travel = centres.max()! - centres.min()!
            XCTAssertGreaterThanOrEqual(travel, 40, "seed \(seed): pair 10 gap moved only \(travel) pt in 1.5 s")
        }
    }

    func testLaterPairsAlsoMove() {
        for seed in seeds {
            let round = Round(seed: seed)
            guard round.fly(until: { $0.seen(11) }) else { return }
            let start = round.frame
            // 40 frames: ends before pair 10 reaches the turtle (~22.7 s), so the
            // result never depends on flying through a moving pair.
            guard round.fly(until: { $0.frame >= start + 40 }) else { return }
            let centres = round.history[11]!.map(\.sample.centre)
            XCTAssertGreaterThanOrEqual(centres.max()! - centres.min()!, 20, "seed \(seed): pair 11 must move too")
        }
    }

    func testMovingGapFollowsSpec() {
        for seed in seeds {
            let round = Round(seed: seed)
            guard round.fly(until: { $0.seen(10) }) else { return }
            let start = round.frame
            guard round.fly(until: { $0.frame >= start + 150 }) else { return }
            let samples = round.history[10]!.map(\.sample)
            let spawn = spawnCentre(seed: seed, pair: 10)
            let reference = referenceCentres(spawn: spawn, frames: samples.count)
            // One frame of phase either way is allowed (2 pt).
            for (i, sample) in samples.enumerated() {
                XCTAssertEqual(sample.centre, reference[i], accuracy: 2.5,
                               "seed \(seed) frame +\(i): centre \(sample.centre), spec \(reference[i])")
                XCTAssertEqual(sample.topPipe.position.y, top, accuracy: 0.01, "top pipe anchored to the top edge")
                XCTAssertEqual(sample.bottomPipe.position.y - sample.bottomPipe.height, land, accuracy: 0.01,
                               "bottom pipe stands on the land")
                XCTAssertEqual(sample.gapTop - sample.gapBottom, gapSize, accuracy: 0.01)
            }
        }
    }

    func testCollisionUsesMovingGeometry() {
        var crashesIntoMovedPipe = 0
        for seed: UInt64 in 1...6 {
            let round = Round(seed: seed)
            guard round.fly(until: { $0.nextPair?.pairNumber == 10 }) else { return }
            // Hover at a fixed height and let the moving gap run into the turtle.
            let hover = round.nextPair!.centre
            while round.model.state == .play, round.frame < 60 * 40 {
                round.step(jump: round.pilotWantsJump(hover: hover))
                let turtle = round.model.turtle
                // Square inscribed in the radius-35.5 circle that always fits in the turtle box.
                let inner = OrientedBox(center: turtle.position, size: CGSize(width: 50, height: 50))
                let rects = round.pairs.flatMap(\.pipeRects)
                if round.model.state == .play {
                    XCTAssertFalse(rects.contains { Collision.overlaps(inner, $0, tolerance: -0.5) },
                                   "seed \(seed) frame \(round.frame): turtle is inside a pipe but the game goes on")
                } else if turtle.position.y > 85.6, let hit = round.pairs.first(where: { pair in
                    // The rotated box never reaches beyond its bounding square (118.6).
                    let outer = OrientedBox(center: turtle.position, size: CGSize(width: 118.6, height: 118.6))
                    return pair.pipeRects.contains { Collision.overlaps(outer, $0) }
                }) {
                    let spawn = spawnCentre(seed: seed, pair: hit.pairNumber)
                    if hit.pairNumber >= 10, abs(hit.centre - spawn) >= 20 { crashesIntoMovedPipe += 1 }
                } else if turtle.position.y > 85.6 {
                    XCTFail("seed \(seed): game over mid-air with no pipe near the turtle's current geometry")
                }
            }
        }
        XCTAssertGreaterThanOrEqual(crashesIntoMovedPipe, 1,
                                    "expected at least one crash into a pair whose gap had moved")
    }

    // MARK: PASS_TO_PASS (guards)

    func testFirstNinePairsStayStill() {
        for seed in seeds {
            let round = Round(seed: seed)
            guard round.fly(until: { $0.seen(10) }) else { return }
            for number in 1...9 {
                let samples = round.history[number]!.map(\.sample)
                for sample in samples {
                    XCTAssertEqual(sample.topPipe.height, samples[0].topPipe.height, "seed \(seed) pair \(number)")
                    XCTAssertEqual(sample.bottomPipe.position.y, samples[0].bottomPipe.position.y,
                                   "seed \(seed) pair \(number)")
                }
            }
        }
    }

    func testMovingInvariantsEveryFrame() {
        for seed in seeds {
            let round = Round(seed: seed)
            guard round.fly(until: { $0.frame >= 60 * 22 + 30 }) else { return }
            for (number, track) in round.history {
                var previous: CGFloat?
                for (_, sample) in track {
                    XCTAssertEqual(sample.gapTop - sample.gapBottom, gapSize, accuracy: 0.01, "pair \(number)")
                    XCTAssertTrue((169.99...520.01).contains(sample.centre), "pair \(number) centre \(sample.centre)")
                    XCTAssertEqual(sample.topPipe.position.y, top, accuracy: 0.01, "pair \(number)")
                    XCTAssertEqual(sample.bottomPipe.position.y - sample.bottomPipe.height, land, accuracy: 0.01)
                    if let previous {
                        XCTAssertLessThanOrEqual(abs(sample.centre - previous), 2.5, "pair \(number) jumped")
                    }
                    previous = sample.centre
                }
            }
        }
    }

    func testPauseFreezesMovement() {
        let round = Round(seed: 1)
        guard round.fly(until: { $0.seen(10) && $0.frame >= 60 * 20 + 20 }) else { return }
        round.model.pause()
        let before = round.pairs.map(\.centre)
        for _ in 0..<60 { round.model.update(dt) }
        XCTAssertEqual(round.pairs.map(\.centre), before)
    }
}
