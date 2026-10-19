import XCTest
@testable import NativeFlappyTurtle

/// Guards the copied resources: every frame the game asks for exists, and the
/// sizes hard-coded in GameConfig still match the art.
final class AtlasTests: XCTestCase {
    private let atlas = TextureAtlas.shared

    func testEveryFrameUsedByTheGameExists() {
        var names = ["binh.png", "land.png", "star.png"]
        names += (1...4).map { "turtle-\($0).png" }
        names += (0...9).map { "number/\($0).png" }
        names += ["pause-1", "pause-2", "fb-1", "fb-2", "game-logo", "text-ready", "instruction",
                  "play-1", "play-2", "text-pause", "text-game-over", "score", "new"].map { "board/\($0).png" }
        for name in names {
            XCTAssertNotNil(atlas.frames[name], name)
        }
    }

    func testFrameRectsMatchTexturePackerPlist() {
        XCTAssertEqual(atlas.frames["turtle-1.png"]?.rect, CGRect(x: 1154, y: 473, width: 95, height: 71))
        XCTAssertEqual(atlas.frames["board/score.png"]?.rect, CGRect(x: 175, y: 245, width: 419, height: 170))
    }

    func testConfigSizesMatchArt() {
        XCTAssertEqual(atlas.texture("turtle-1.png").size(), GameConfig.turtleSize)
        XCTAssertEqual(atlas.texture("land.png").size(), GameConfig.landSize)
        XCTAssertEqual(atlas.texture("star.png").size(), GameConfig.starSize)
        XCTAssertEqual(StandaloneTexture.obstacle.size(), GameConfig.obstacleSize)
        XCTAssertEqual(StandaloneTexture.background.size(), CGSize(width: 1150, height: 640))
    }

    func testFontsAreBundledAndRegistered() {
        let fonts = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String] ?? []
        XCTAssertEqual(fonts.count, 4)
        for font in fonts {
            XCTAssertNotNil(Bundle.main.url(forResource: font, withExtension: nil), font)
        }
    }
}
