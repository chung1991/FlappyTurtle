import SpriteKit

/// Port of GameScene.cpp. Mirrors `GameModel` state with sprites every frame
/// and turns touches into controller requests.
final class GameScene: SKScene {
    let controller: GameController
    let viewport: Viewport
    let hud: HUDNode

    /// Called at the end of every frame (state probe for tests).
    var onFrame: ((GameScene) -> Void)?

    /// Test hook: the bot flaps during live play.
    var isAutopilotEnabled = false

    /// Stops simulation and animations so screenshots are pixel-stable.
    var isFrozen = false {
        didSet { if isFrozen { freezeAnimations() } }
    }

    private var model: GameModel { controller.model }

    // Same stack and z-order as GameScene::createLayers. `root` exists because
    // the original shakes the scene node itself, which SKScene cannot do.
    private let root = SKNode()
    private let environmentLayer = SKNode()
    private let mainLayer = SKNode()
    private let specialLayer = SKNode()
    private let menuLayer = SKNode()

    private let turtleNode = TextureAtlas.sprite("turtle-1.png")
    private var obstacleNodes: [Int: SKSpriteNode] = [:]
    /// Height each obstacle sprite was last cropped to (moving gaps resize pipes).
    private var obstacleHeights: [Int: CGFloat] = [:]
    private var landNodes: [Int: SKSpriteNode] = [:]
    private var starNodes: [Int: SKSpriteNode] = [:]

    private let tracker = ButtonTracker()
    private var isTouching = false
    private var lastUpdateTime: TimeInterval?

    private static let flapKey = "flap"
    private static let obstacleDepth: CGFloat = 1
    private static let turtleDepth: CGFloat = 2

    init(viewport: Viewport, controller: GameController, showBegin: Bool) {
        self.viewport = viewport
        self.controller = controller
        hud = HUDNode(displaySize: viewport.displaySize)
        super.init(size: viewport.displaySize)
        anchorPoint = .zero
        scaleMode = .fill
        backgroundColor = .black

        addChild(root)
        let background = SKSpriteNode(texture: StandaloneTexture.background)
        background.anchorPoint = CGPoint(x: 0, y: 0.5)
        background.position = CGPoint(x: 0, y: viewport.displaySize.height / 2)
        background.zPosition = 0
        root.addChild(background)

        for (depth, layer) in [environmentLayer, mainLayer, specialLayer, menuLayer, hud].enumerated() {
            layer.zPosition = CGFloat(depth + 1)
            root.addChild(layer)
        }
        for layer in [mainLayer, specialLayer, menuLayer] {
            layer.position = viewport.vectorMove
        }

        let flapFrames = (1...4).map { TextureAtlas.shared.texture("turtle-\($0).png") }
        turtleNode.run(.repeatForever(.animate(with: flapFrames, timePerFrame: 0.8 / 4,
                                               resize: true, restore: false)),
                       withKey: Self.flapKey)
        turtleNode.zPosition = Self.turtleDepth
        mainLayer.addChild(turtleNode)

        wireButtons()
        controller.onModelEvent = { [weak self] event in
            if case let .gameOver(isHighScore) = event { self?.onGameOver(isHighScore: isHighScore) }
        }
        if showBegin { hud.showBegin() }
        syncNodes()
        applyStateVisibility()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Frame loop (GameScene::update)

    override func update(_ currentTime: TimeInterval) {
        var dt = CGFloat(lastUpdateTime.map { currentTime - $0 } ?? 0)
        lastUpdateTime = currentTime
        // Director (debug) clamps hitches the same way.
        if dt > 0.2 { dt = 1.0 / 60.0 }

        if !isFrozen {
            if isAutopilotEnabled, model.state == .play, Autopilot().shouldJump(model) {
                controller.handle(.jump)
            }
            model.update(dt)
            hud.tick(dt)
        }
        syncNodes()
        applyStateVisibility()
        onFrame?(self)
    }

    func syncNodes() {
        hud.updateScore(model.currentScore)

        let turtle = model.turtle
        turtleNode.position = turtle.position
        turtleNode.zRotation = turtle.rotation * .pi / 180

        sync(model.obstacles, into: &obstacleNodes, parent: mainLayer, make: makeObstacleNode)
        obstacleHeights = obstacleHeights.filter { obstacleNodes[$0.key] != nil }
        for obstacle in model.obstacles where obstacleHeights[obstacle.id] != obstacle.height {
            guard let node = obstacleNodes[obstacle.id] else { continue }
            let texture = Self.obstacleTexture(height: obstacle.height)
            node.texture = texture
            node.size = texture.size()
            obstacleHeights[obstacle.id] = obstacle.height
        }
        sync(model.lands, into: &landNodes, parent: environmentLayer) { _ in
            Self.stripNode("land.png")
        }
        sync(model.stars, into: &starNodes, parent: environmentLayer) { _ in
            Self.stripNode("star.png")
        }
    }

    func applyStateVisibility() {
        switch model.state {
        case .play:
            hud.hidePause()
            hud.hideInstruction()
            hud.showMain()
        case .pause:
            hud.showPause()
            hud.hideInstruction()
            hud.showMain()
        case .wait:
            hud.hidePause()
            if hud.beginLayer.isHidden { hud.showInstruction() }
            hud.hideMain()
        case .finish:
            hud.hidePause()
            hud.hideInstruction()
            hud.hideMain()
        }
    }

    // MARK: - Touches (GameScene::onTouches* + Menu swallowing)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let unclaimed = touches.filter { !tracker.began($0, at: $0.location(in: self)) }
        guard !unclaimed.isEmpty, hud.beginLayer.isHidden else { return }
        if !isTouching {
            isTouching = true
            controller.handle(.jump)
        }
        // The original checks pauseLayer->isVisible(), which is always true.
        controller.handle(.resume)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { _ = tracker.moved(touch, at: touch.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches, cancelled: true)
    }

    private func endTouches(_ touches: Set<UITouch>, cancelled: Bool) {
        let unclaimed = touches.filter { !tracker.ended($0, at: $0.location(in: self), cancelled: cancelled) }
        if !unclaimed.isEmpty { isTouching = false }
    }

    // MARK: - Buttons

    private func wireButtons() {
        hud.buttons.forEach(tracker.register)
        hud.playButton.action = { [weak self] in
            self?.controller.handle(.start)
            self?.hud.hideBegin()
        }
        hud.shareHighScoreButton.action = { [weak self] in self?.controller.handle(.shareHighScore) }
        hud.shareScoreButton.action = { [weak self] in self?.controller.handle(.shareCurrentScore) }
        hud.pauseButton.action = { [weak self] in self?.controller.handle(.pause) }
        hud.replayButton.action = { [weak self] in self?.controller.handle(.replay) }
        hud.onNewHighScore = { [weak self] in self?.controller.handle(.newHighScore) }
    }

    /// Interactive buttons and their frames in scene coordinates (accessibility).
    var interactiveButtons: [(button: SpriteButton, frame: CGRect)] {
        hud.buttons.filter(\.isInteractive).compactMap { button in
            guard let parent = button.parent else { return nil }
            let frame = button.frame
            let origin = parent.convert(frame.origin, to: self)
            return (button, CGRect(origin: origin, size: frame.size))
        }
    }

    // MARK: - Game over (GameScene::onGameOver)

    private func onGameOver(isHighScore: Bool) {
        hud.showFinish(isNewHighScore: isHighScore, score: model.currentScore, highScore: model.highScore)

        let binh = TextureAtlas.sprite("binh.png")
        binh.anchorPoint = CGPoint(x: 1, y: 0.5)
        binh.position = model.turtle.position
        // Cocos rotation is clockwise and the original passes the body angle as-is.
        binh.zRotation = -model.turtle.rotation * .pi / 180
        specialLayer.addChild(binh)
        binh.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))

        root.run(Self.shake(duration: 0.2, strength: 5))

        let flash = SKSpriteNode(color: .white, size: viewport.displaySize)
        flash.anchorPoint = .zero
        flash.alpha = 0
        menuLayer.addChild(flash)
        flash.run(.sequence([.fadeIn(withDuration: 0.05), .fadeOut(withDuration: 0.05), .removeFromParent()]))
    }

    /// Port of UGShake: random offset every frame, then restore. `root` always
    /// rests at the origin, so that is the restore point.
    private static func shake(duration: TimeInterval, strength: CGFloat) -> SKAction {
        .sequence([
            .customAction(withDuration: duration) { node, _ in
                node.position = CGPoint(x: .random(in: -strength...strength),
                                        y: .random(in: -strength...strength))
            },
            .move(to: .zero, duration: 0),
        ])
    }

    // MARK: - Node helpers

    private func sync<T: Identifiable>(_ items: [T], into nodes: inout [Int: SKSpriteNode],
                                       parent: SKNode, make: (T) -> SKSpriteNode) where T.ID == Int {
        var alive = Set<Int>()
        for item in items {
            alive.insert(item.id)
            let node = nodes[item.id] ?? {
                let created = make(item)
                parent.addChild(created)
                nodes[item.id] = created
                return created
            }()
            node.position = Self.position(of: item)
        }
        for (id, node) in nodes where !alive.contains(id) {
            node.removeFromParent()
            nodes[id] = nil
        }
    }

    private static func position<T>(of item: T) -> CGPoint {
        switch item {
        case let obstacle as Obstacle: return obstacle.position
        case let strip as ScrollStrip: return strip.position
        default: return .zero
        }
    }

    /// setTextureRect(0, 0, w, h): the top `height` rows of obstacle.png.
    private static func obstacleTexture(height: CGFloat) -> SKTexture {
        let full = StandaloneTexture.obstacle
        let fraction = height / full.size().height
        return SKTexture(rect: CGRect(x: 0, y: 1 - fraction, width: 1, height: fraction), in: full)
    }

    private func makeObstacleNode(_ obstacle: Obstacle) -> SKSpriteNode {
        let node = SKSpriteNode(texture: Self.obstacleTexture(height: obstacle.height))
        obstacleHeights[obstacle.id] = obstacle.height
        if obstacle.isFlipped {
            // Cocos flips the texture, not the geometry: still hangs down from the anchor.
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.yScale = -1
        } else {
            node.anchorPoint = CGPoint(x: 0.5, y: 1)
        }
        node.zPosition = Self.obstacleDepth
        return node
    }

    private static func stripNode(_ frame: String) -> SKSpriteNode {
        let node = TextureAtlas.sprite(frame)
        node.anchorPoint = CGPoint(x: 0, y: 0.5)
        return node
    }

    private func freezeAnimations() {
        turtleNode.removeAction(forKey: Self.flapKey)
        let first = TextureAtlas.shared.texture("turtle-1.png")
        turtleNode.texture = first
        turtleNode.size = first.size()
        hud.completeFinishImmediately()
        // Drop the transient game-over effects (shake, binh, flash).
        root.removeAllActions()
        root.position = .zero
        specialLayer.removeAllChildren()
        menuLayer.removeAllChildren()
    }
}
