import XCTest
@testable import NativeFlappyTurtle

final class LaunchConfigTests: XCTestCase {
    func testNormalLaunchIsNotTestMode() {
        let config = LaunchConfig(arguments: ["/path/App", "-NSDocumentRevisionsDebugMode", "YES"])
        XCTAssertFalse(config.isTestMode)
        XCTAssertNil(config.scene)
    }

    func testParsesArguments() {
        let config = LaunchConfig(arguments: ["App", "-ft-scene", "gameover", "-ft-score", "12",
                                              "-ft-highscore", "30", "-ft-seed", "7", "-ft-freeze",
                                              "-ft-mute", "-ft-advance", "2.5"])
        XCTAssertEqual(config.scene, .gameover)
        XCTAssertEqual(config.score, 12)
        XCTAssertEqual(config.highScore, 30)
        XCTAssertEqual(config.seed, 7)
        XCTAssertEqual(config.advance, 2.5)
        XCTAssertTrue(config.freeze)
        XCTAssertTrue(config.mute)
        XCTAssertTrue(config.isolated, "a high score override never touches the saved one")
    }

    func testParsesDeepLink() throws {
        let url = try XCTUnwrap(URL(string: "nativeflappyturtle://launch?scene=paused&seed=3&freeze=1&mute=0"))
        let config = try XCTUnwrap(LaunchConfig(url: url))
        XCTAssertEqual(config.scene, .paused)
        XCTAssertEqual(config.seed, 3)
        XCTAssertTrue(config.freeze)
        XCTAssertFalse(config.mute)
        XCTAssertNil(LaunchConfig(url: URL(string: "https://example.com")!))
    }

    func testDefaultAdvance() {
        XCTAssertEqual(LaunchConfig(arguments: ["-ft-scene", "playing"]).effectiveAdvance, 3)
        XCTAssertEqual(LaunchConfig(arguments: ["-ft-scene", "gameover"]).effectiveAdvance, 0)
    }
}
