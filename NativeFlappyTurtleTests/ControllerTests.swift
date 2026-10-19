import XCTest
@testable import NativeFlappyTurtle

/// GameController.cpp routing: which requests act in which state, and which
/// sounds play.
final class ControllerTests: XCTestCase {
    func testButtonsPlayClickSound() {
        let (controller, sound, _, _) = makeController()
        controller.handle(.start)
        controller.handle(.shareHighScore)
        XCTAssertEqual(sound.played, [.jump, .jump])
        XCTAssertEqual(SoundEffect.click, .jump)
    }

    func testPauseOnlyActsWhilePlaying() {
        let (controller, _, _, _) = makeController()
        controller.handle(.pause)
        XCTAssertEqual(controller.model.state, .wait)
        controller.handle(.jump)
        controller.handle(.pause)
        XCTAssertEqual(controller.model.state, .pause)
        controller.handle(.pause)
        XCTAssertEqual(controller.model.state, .pause)
    }

    func testResumeOnlyActsWhilePaused() {
        let (controller, _, _, _) = makeController()
        controller.handle(.resume)
        XCTAssertEqual(controller.model.state, .wait)
    }

    func testReplayAlwaysRebuildsSceneButOnlyResetsAfterFinish() {
        let (controller, _, _, _) = makeController()
        var replays = 0
        controller.onReplay = { replays += 1 }
        controller.handle(.jump)
        controller.model.currentScore = 2
        controller.handle(.replay)
        XCTAssertEqual(replays, 1)
        XCTAssertEqual(controller.model.currentScore, 2, "model untouched unless GS_FINISH")
    }

    func testShareTextsMatchOriginal() {
        let (controller, _, share, _) = makeController(highScore: 9)
        controller.model.currentScore = 4
        controller.handle(.shareCurrentScore)
        controller.handle(.shareHighScore)
        XCTAssertEqual(share.descriptions, ["I just scored 4 in Flappy Turtle", "My best score is 9 in Flappy Turtle"])
        XCTAssertEqual(share.captions, ["Wow, it's unbelievable, defeat my score, if you can", "Can you defeat my score"])
    }

    func testNewHighScoreSound() {
        let (controller, sound, _, _) = makeController()
        controller.handle(.newHighScore)
        XCTAssertEqual(sound.played, [.highScore])
    }

    func testSoundFileNames() {
        XCTAssertEqual(SoundEffect.allCases.map(\.fileName),
                       ["ufile_2000.wav", "ufile_2001.wav", "ufile_2002.wav", "ufile_2003.wav"])
        for effect in SoundEffect.allCases {
            XCTAssertNotNil(Bundle.main.url(forResource: effect.fileName, withExtension: nil), effect.fileName)
        }
    }
}
