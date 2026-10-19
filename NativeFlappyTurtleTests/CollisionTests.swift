import XCTest
@testable import NativeFlappyTurtle

final class CollisionTests: XCTestCase {
    private let pipe = OrientedBox(center: CGPoint(x: 0, y: 0), size: CGSize(width: 150, height: 200))

    func testOverlappingBoxesCollide() {
        let turtle = OrientedBox(center: CGPoint(x: 100, y: 0), size: GameConfig.turtleSize)
        XCTAssertTrue(Collision.overlaps(turtle, pipe))
        XCTAssertTrue(Collision.overlaps(pipe, turtle))
    }

    func testSeparatedBoxesDoNotCollide() {
        let turtle = OrientedBox(center: CGPoint(x: 75 + 47.5 + 1, y: 0), size: GameConfig.turtleSize)
        XCTAssertFalse(Collision.overlaps(turtle, pipe))
    }

    func testBox2DSkinToleranceCountsNearTouchAsHit() {
        let touching = OrientedBox(center: CGPoint(x: 75 + 47.5 + 0.015, y: 0), size: GameConfig.turtleSize)
        XCTAssertTrue(Collision.overlaps(touching, pipe), "within 2 * b2_polygonRadius")
        let apart = OrientedBox(center: CGPoint(x: 75 + 47.5 + 0.03, y: 0), size: GameConfig.turtleSize)
        XCTAssertFalse(Collision.overlaps(apart, pipe))
    }

    func testRotationMatters() {
        // Axis-aligned there is a 5pt gap; rotated 45 degrees the half-width
        // grows to (47.5 + 35.5) * cos 45 = 58.7 and it reaches into the pipe.
        let near = CGPoint(x: 75 + 47.5 + 5, y: 0)
        XCTAssertFalse(Collision.overlaps(OrientedBox(center: near, size: GameConfig.turtleSize), pipe))
        XCTAssertTrue(Collision.overlaps(OrientedBox(center: near, size: GameConfig.turtleSize, angle: .pi / 4), pipe))
    }

    func testTurtleBoxUsesOriginalDegreeConversion() {
        var turtle = Turtle()
        turtle.rotation = 90
        XCTAssertEqual(turtle.box.angle, 90 * 3.14 / 180)
    }
}
