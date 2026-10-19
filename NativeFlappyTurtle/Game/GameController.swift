import Foundation

/// The original sound ids (SoundCommand.h) — values are the `ufile_<id>.wav` names.
enum SoundEffect: Int, CaseIterable {
    case die = 2000
    case pass = 2001
    case jump = 2002
    case highScore = 2003

    /// EF_CLICK_BUTTON reuses the jump sound.
    static let click = SoundEffect.jump

    var fileName: String { "ufile_\(rawValue).wav" }
}

protocol SoundPlaying: AnyObject {
    func play(_ effect: SoundEffect)
}

protocol ScoreSharing: AnyObject {
    func share(title: String, caption: String, description: String, link: String, picture: String)
}

/// Requests the view sends to the controller (REQ_* in Resources.h).
enum GameRequest: Equatable {
    case jump
    case pause
    case resume
    case replay
    case newHighScore
    /// Play button on the title board.
    case start
    case shareCurrentScore
    case shareHighScore
}

/// Port of GameController.cpp: routes view requests to the model and owns the
/// sound / share side effects.
final class GameController {
    let model: GameModel
    private let sound: SoundPlaying
    private let sharing: ScoreSharing

    /// Called on replay so the host can present a fresh scene (the original
    /// does `director->replaceScene(GameScene::create())`).
    var onReplay: (() -> Void)?
    /// Model events, forwarded after the controller has played their sounds.
    var onModelEvent: ((GameEvent) -> Void)?

    init(model: GameModel, sound: SoundPlaying, sharing: ScoreSharing) {
        self.model = model
        self.sound = sound
        self.sharing = sharing
        model.onEvent = { [weak self] event in
            switch event {
            case .scored: self?.sound.play(.pass)
            case .gameOver: self?.sound.play(.die)
            }
            self?.onModelEvent?(event)
        }
    }

    func handle(_ request: GameRequest) {
        switch request {
        case .jump:
            guard model.state == .play || model.state == .wait else { return }
            if model.state == .wait {
                model.play()
            }
            model.jump()
            sound.play(.jump)
        case .pause:
            sound.play(.click)
            if model.state == .play { model.pause() }
        case .resume:
            if model.state == .pause { model.resume() }
        case .replay:
            sound.play(.click)
            if model.state == .finish { model.replay() }
            onReplay?()
        case .newHighScore:
            sound.play(.highScore)
        case .start:
            sound.play(.click)
        case .shareCurrentScore:
            sound.play(.click)
            sharing.share(title: ShareText.title, caption: ShareText.currentScoreCaption,
                          description: String(format: ShareText.currentScoreDescription, model.currentScore),
                          link: ShareText.link, picture: ShareText.picture)
        case .shareHighScore:
            sound.play(.click)
            sharing.share(title: ShareText.title, caption: ShareText.highScoreCaption,
                          description: String(format: ShareText.highScoreDescription, model.highScore),
                          link: ShareText.link, picture: ShareText.picture)
        }
    }
}

/// TXT_* sharing strings from Resources.h.
enum ShareText {
    static let title = "Flappy Turtle (iOS/Android) app"
    static let currentScoreCaption = "Wow, it's unbelievable, defeat my score, if you can"
    static let highScoreCaption = "Can you defeat my score"
    static let currentScoreDescription = "I just scored %d in Flappy Turtle"
    static let highScoreDescription = "My best score is %d in Flappy Turtle"
    static let link = "https://apps.facebook.com/flappyturtle"
    static let picture = "http://farm4.staticflickr.com/3788/12492575183_b9db063e57_o.png"
}
