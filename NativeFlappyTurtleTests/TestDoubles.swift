import CoreGraphics
@testable import NativeFlappyTurtle

final class FixedRandomSource: RandomSource {
    var value: Int
    init(_ value: Int) { self.value = value }
    func nextInt(_ upperBound: Int) -> Int { value % upperBound }
}

final class SoundSpy: SoundPlaying {
    private(set) var played: [SoundEffect] = []
    func play(_ effect: SoundEffect) { played.append(effect) }
}

final class ShareSpy: ScoreSharing {
    private(set) var descriptions: [String] = []
    private(set) var captions: [String] = []
    func share(title: String, caption: String, description: String, link: String, picture: String) {
        descriptions.append(description)
        captions.append(caption)
    }
}

let frame: CGFloat = 1.0 / 60.0

func makeController(random: RandomSource = SeededRandomSource(seed: 1),
                    highScore: Int = 0) -> (GameController, SoundSpy, ShareSpy, InMemoryHighScoreStore) {
    let store = InMemoryHighScoreStore(highScore)
    let sound = SoundSpy()
    let share = ShareSpy()
    let controller = GameController(model: GameModel(random: random, store: store), sound: sound, sharing: share)
    return (controller, sound, share, store)
}

extension GameModel {
    /// Runs fixed 1/60 frames until `frames` elapse or `until` is satisfied.
    /// `autopilot` flies through the gaps; `hoverY` naively flaps whenever the
    /// turtle sinks below that height (ignoring pipes).
    func run(frames: Int, autopilot: Bool = false, hoverY: CGFloat? = nil,
             controller: GameController? = nil, until: ((GameModel) -> Bool)? = nil) {
        for _ in 0..<frames {
            if autopilot, Autopilot().shouldJump(self) {
                if let controller { controller.handle(.jump) } else { jump() }
            } else if let hoverY, turtle.position.y < hoverY, turtle.worldVelocityY <= 0 {
                if let controller { controller.handle(.jump) } else { jump() }
            }
            update(frame)
            if until?(self) == true { return }
        }
    }
}
