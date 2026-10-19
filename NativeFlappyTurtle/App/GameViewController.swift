import SpriteKit
import UIKit

/// Replaces AppController/RootViewController + AppDelegate.cpp: builds the
/// model/controller, sizes the game view (fixed 640 height, aspect capped by
/// `GameConfig.maxDisplayAspect`, centred with black bars) and presents scenes.
final class GameViewController: UIViewController {
    private(set) var config: LaunchConfig
    private let gameView = GameView()
    private var probe: UILabel?
    private var controller: GameController?
    private var presentedAspect: CGFloat?
    private let sharing = ShareSheet()
    private lazy var sound = SoundPlayer(muted: config.mute)

    init(config: LaunchConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        gameView.preferredFramesPerSecond = 60
        gameView.ignoresSiblingOrder = false
        view.addSubview(gameView)
        sharing.presenter = self
        if config.isTestMode { installProbe() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let longSide = max(bounds.width, bounds.height)
        let shortSide = min(bounds.width, bounds.height)
        let aspect = min(longSide / shortSide, GameConfig.maxDisplayAspect)
        let size = CGSize(width: (shortSide * aspect).rounded(), height: shortSide)
        gameView.frame = CGRect(x: ((longSide - size.width) / 2).rounded(), y: 0,
                                width: size.width, height: size.height)
        if presentedAspect != aspect {
            presentedAspect = aspect
            startGame()
        }
    }

    /// Re-runs the whole launch path with new hooks (deep links).
    func restart(with config: LaunchConfig) {
        self.config = config
        sound.isMuted = config.mute
        if config.isTestMode && probe == nil { installProbe() }
        startGame()
    }

    private func startGame() {
        guard let aspect = presentedAspect else { return }
        let random: RandomSource = config.seed.map { SeededRandomSource(seed: $0) } ?? SystemRandomSource()
        let store: HighScoreStore = config.isolated
            ? InMemoryHighScoreStore(config.highScore ?? 0)
            : UserDefaultsHighScoreStore()
        let sharing: ScoreSharing = config.isTestMode ? RecordingShareSheet() : self.sharing
        let controller = GameController(model: GameModel(random: random, store: store),
                                        sound: sound, sharing: sharing)
        controller.onReplay = { [weak self] in self?.presentScene(showBegin: false) }
        self.controller = controller

        let scene = presentScene(showBegin: true, aspect: aspect)
        TestHooks.apply(config, to: scene)
        updateProbe(scene)
    }

    @discardableResult
    private func presentScene(showBegin: Bool, aspect: CGFloat? = nil) -> GameScene {
        let viewport = Viewport(aspect: aspect ?? presentedAspect ?? 1.5)
        let scene = GameScene(viewport: viewport, controller: controller!, showBegin: showBegin)
        scene.onFrame = { [weak self] scene in self?.updateProbe(scene) }
        scene.isAutopilotEnabled = config.autopilot
        gameView.presentScene(scene)
        return scene
    }

    // MARK: - State probe (tests only)

    private func installProbe() {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        label.textColor = .clear
        label.accessibilityIdentifier = "ft.state"
        view.addSubview(label)
        probe = label
    }

    private func updateProbe(_ scene: GameScene) {
        guard let probe else { return }
        let description = TestHooks.stateDescription(of: scene)
        if probe.accessibilityLabel != description {
            probe.accessibilityLabel = description
        }
    }
}
