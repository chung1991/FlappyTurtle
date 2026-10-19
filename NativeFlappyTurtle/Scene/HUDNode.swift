import SpriteKit

/// Port of GameLayer.cpp: title board, "get ready" instructions, pause overlay,
/// score, and the game-over board. Positions are computed with the original
/// formulas against the display size (not the 960 design width).
final class HUDNode: SKNode {
    let pauseButton: SpriteButton
    let playButton: SpriteButton
    let shareHighScoreButton: SpriteButton
    let replayButton: SpriteButton
    let shareScoreButton: SpriteButton

    /// The original GameLayer sub-layers. `beginLayer.isHidden` gates touches.
    let mainLayer = SKNode()
    let beginLayer = SKNode()
    let instructionLayer = SKNode()
    let pauseLayer = SKNode()
    let finishLayer = SKNode()

    let scoreNode: NumberNode
    private let gameLogo = TextureAtlas.sprite("board/game-logo.png")
    private let ready = TextureAtlas.sprite("board/text-ready.png")
    private let instruction = TextureAtlas.sprite("board/instruction.png")
    private let shadow: SKSpriteNode
    private let pauseText = TextureAtlas.sprite("board/text-pause.png")
    private let gameOverText = TextureAtlas.sprite("board/text-game-over.png")
    private let gameOverBoard = TextureAtlas.sprite("board/score.png")
    private let newHighScoreBadge = TextureAtlas.sprite("board/new.png")
    private let currentScoreNode: NumberNode
    private let highScoreNode: NumberNode

    /// Ask the controller to play the "new high score" sound (REQ_NEW_HIGH_SCORE).
    var onNewHighScore: (() -> Void)?

    private var countedScore: CGFloat = 0
    private var isCounting = false
    private var isNewHighScore = false
    private var finalScore = 0
    private var finalHighScore = 0

    static let finishSlideKey = "finishSlide"

    init(displaySize size: CGSize) {
        pauseButton = SpriteButton(normal: "board/pause-1.png", selected: "board/pause-2.png",
                                   identifier: "ft.pause", title: "Pause")
        playButton = SpriteButton(normal: "board/play-1.png", selected: "board/play-2.png",
                                  identifier: "ft.play", title: "Play")
        shareHighScoreButton = SpriteButton(normal: "board/fb-1.png", selected: "board/fb-2.png",
                                            identifier: "ft.shareHighScore", title: "Share high score")
        replayButton = SpriteButton(normal: "board/play-1.png", selected: "board/play-2.png",
                                    identifier: "ft.replay", title: "Replay")
        shareScoreButton = SpriteButton(normal: "board/fb-1.png", selected: "board/fb-2.png",
                                        identifier: "ft.shareScore", title: "Share score")
        scoreNode = NumberNode(anchor: CGPoint(x: size.width / 2, y: size.height - 50),
                               spacing: 35, digitScale: 1)
        shadow = SKSpriteNode(color: UIColor(white: 0, alpha: 180.0 / 255.0), size: size)

        let boardSize = gameOverBoard.size
        // Children of a cocos sprite are placed from its bottom-left corner;
        // SpriteKit places them from the anchor (centre), hence the shift.
        func boardPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x - boardSize.width / 2, y: y - boardSize.height / 2)
        }
        currentScoreNode = NumberNode(anchor: boardPoint(boardSize.width - 90, 105), spacing: 26, digitScale: 0.5)
        highScoreNode = NumberNode(anchor: boardPoint(boardSize.width - 90, 42), spacing: 26, digitScale: 0.5)
        super.init()

        for layer in [mainLayer, beginLayer, instructionLayer, pauseLayer, finishLayer] {
            addChild(layer)
        }

        // Main layer: pause button + live score.
        let pausePadding: CGFloat = 10
        let pauseSize = pauseButton.size
        pauseButton.position = CGPoint(x: pausePadding + pauseSize.width / 2,
                                       y: size.height - pausePadding - pauseSize.height / 2)
        mainLayer.addChild(pauseButton)
        mainLayer.addChild(scoreNode)

        // Begin layer: logo, play, share (the original adds the menu to mainLayer).
        let padding: CGFloat = 20
        var mainY: CGFloat = 500
        gameLogo.position = CGPoint(x: size.width / 2, y: mainY)
        beginLayer.addChild(gameLogo)
        mainY -= gameLogo.size.height / 2 + padding
        mainY -= playButton.size.height / 2
        playButton.position = CGPoint(x: size.width / 2, y: mainY)
        mainY -= playButton.size.height / 2 + padding
        mainLayer.addChild(playButton)
        mainY -= shareHighScoreButton.size.height / 2
        shareHighScoreButton.position = CGPoint(x: size.width / 2, y: mainY)
        mainLayer.addChild(shareHighScoreButton)

        // Instruction layer.
        var instructionY: CGFloat = 500
        ready.position = CGPoint(x: size.width / 2, y: instructionY)
        instructionLayer.addChild(ready)
        instructionY -= ready.size.height / 2 + padding
        instructionY -= instruction.size.height / 2
        instruction.position = CGPoint(x: size.width / 2, y: instructionY)
        instructionLayer.addChild(instruction)

        // Pause layer.
        shadow.anchorPoint = .zero
        pauseLayer.addChild(shadow)
        pauseText.position = CGPoint(x: size.width / 2, y: size.height / 2)
        pauseLayer.addChild(pauseText)

        // Finish layer.
        var finishY: CGFloat = 500
        gameOverText.position = CGPoint(x: size.width / 2, y: finishY)
        finishLayer.addChild(gameOverText)
        finishY -= gameOverText.size.height / 2 + padding
        finishY -= boardSize.height / 2
        gameOverBoard.position = CGPoint(x: size.width / 2, y: finishY)
        finishLayer.addChild(gameOverBoard)
        finishY -= boardSize.height / 2 + padding
        gameOverBoard.addChild(currentScoreNode)
        gameOverBoard.addChild(highScoreNode)
        newHighScoreBadge.position = boardPoint(boardSize.width - 160, 72)
        gameOverBoard.addChild(newHighScoreBadge)
        finishY -= replayButton.size.height / 2
        replayButton.position = CGPoint(x: size.width / 2 - 100, y: finishY)
        finishLayer.addChild(replayButton)
        shareScoreButton.position = CGPoint(x: size.width / 2 + 100, y: finishY)
        finishLayer.addChild(shareScoreButton)

        hideMain()
        hideBegin()
        hideInstruction()
        hidePause()
        hideFinish()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var buttons: [SpriteButton] {
        [pauseButton, playButton, shareHighScoreButton, replayButton, shareScoreButton]
    }

    // MARK: - Show / hide (GameLayer::show*/hide*)

    func showMain() { set(pauseButton, visible: true); scoreNode.isHidden = false }
    func hideMain() { set(pauseButton, visible: false); scoreNode.isHidden = true }

    func showBegin() {
        beginLayer.isHidden = false
        gameLogo.isHidden = false
        set(playButton, visible: true)
        set(shareHighScoreButton, visible: true)
    }

    func hideBegin() {
        beginLayer.isHidden = true
        gameLogo.isHidden = true
        set(playButton, visible: false)
        set(shareHighScoreButton, visible: false)
    }

    func showInstruction() { ready.isHidden = false; instruction.isHidden = false }
    func hideInstruction() { ready.isHidden = true; instruction.isHidden = true }
    func showPause() { shadow.isHidden = false; pauseText.isHidden = false }
    func hidePause() { shadow.isHidden = true; pauseText.isHidden = true }

    var isPauseShown: Bool { !shadow.isHidden }
    var isInstructionShown: Bool { !ready.isHidden }
    var isFinishShown: Bool { !gameOverBoard.isHidden }

    /// Slides the game-over board up from y = -600 over 1s, then counts the
    /// score up at 10 per second (GameLayer::showFinish/showResult/update).
    func showFinish(isNewHighScore: Bool, score: Int, highScore: Int, animated: Bool = true) {
        self.isNewHighScore = isNewHighScore
        finalScore = score
        finalHighScore = highScore
        for node in [gameOverText, gameOverBoard] as [SKNode] { node.isHidden = false }
        currentScoreNode.isHidden = false
        highScoreNode.isHidden = false
        set(replayButton, visible: true)
        set(shareScoreButton, visible: true)

        guard animated else {
            finishLayer.position = .zero
            countedScore = CGFloat(score)
            currentScoreNode.show(score)
            showHighScore()
            return
        }
        let target = finishLayer.position
        finishLayer.position = CGPoint(x: 0, y: -600)
        finishLayer.run(.sequence([.move(to: target, duration: 1.0),
                                   .run { [weak self] in self?.isCounting = true }]),
                        withKey: Self.finishSlideKey)
    }

    func hideFinish() {
        for node in [gameOverText, gameOverBoard, newHighScoreBadge] as [SKNode] { node.isHidden = true }
        currentScoreNode.isHidden = true
        highScoreNode.isHidden = true
        set(replayButton, visible: false)
        set(shareScoreButton, visible: false)
    }

    /// Jumps the finish animation to its end state (used by test hooks).
    func completeFinishImmediately() {
        guard isFinishShown else { return }
        finishLayer.removeAction(forKey: Self.finishSlideKey)
        finishLayer.position = .zero
        isCounting = false
        countedScore = CGFloat(finalScore)
        currentScoreNode.show(finalScore)
        showHighScore()
    }

    func updateScore(_ score: Int) { scoreNode.show(score) }

    /// Per-frame count-up once the board has arrived.
    func tick(_ dt: CGFloat) {
        guard isCounting else { return }
        countedScore += GameConfig.scoreCountVelocity * dt
        var isEnd = false
        if countedScore > CGFloat(finalScore) {
            countedScore = CGFloat(finalScore)
            isEnd = true
            showHighScore()
        }
        currentScoreNode.show(Int(countedScore))
        if isEnd { isCounting = false }
    }

    private func showHighScore() {
        if isNewHighScore {
            onNewHighScore?()
            newHighScoreBadge.isHidden = false
        }
        highScoreNode.clear()
        highScoreNode.show(finalHighScore)
    }

    private func set(_ button: SpriteButton, visible: Bool) {
        button.isHidden = !visible
        button.isEnabled = visible
    }
}

extension TextureAtlas {
    static func sprite(_ name: String) -> SKSpriteNode {
        SKSpriteNode(texture: shared.texture(name))
    }
}
