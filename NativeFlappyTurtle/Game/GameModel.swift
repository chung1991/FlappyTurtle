import CoreGraphics

enum GameState: String {
    case wait, play, pause, finish
}

enum GameEvent: Equatable {
    case scored(Int)
    case gameOver(isHighScore: Bool)
}

/// Port of FlappyModel.cpp (+ Turtle/Obstacle/Land/Star update logic).
/// Pure Swift — no SpriteKit — so every rule is unit-testable. The scene reads
/// this state each frame and mirrors it with sprites.
final class GameModel {
    private(set) var state: GameState = .wait
    private(set) var turtle = Turtle()
    private(set) var obstacles: [Obstacle] = []
    private(set) var lands: [ScrollStrip] = []
    private(set) var stars: [ScrollStrip] = []
    var currentScore = 0
    private(set) var highScore: Int

    var onEvent: ((GameEvent) -> Void)?

    private let random: RandomSource
    private let store: HighScoreStore
    private var spawnTimer: CGFloat = -1
    private var nextId = 0
    /// Pairs spawned this round (numbering restarts on replay).
    private(set) var pairsSpawned = 0

    init(random: RandomSource = SystemRandomSource(),
         store: HighScoreStore = UserDefaultsHighScoreStore()) {
        self.random = random
        self.store = store
        highScore = store.load()
        wait()
    }

    /// Independent copy for look-ahead (the autopilot). Has its own random
    /// source and store and emits no events, so simulating never affects the game.
    func clone() -> GameModel {
        let copy = GameModel(random: SeededRandomSource(seed: 0), store: InMemoryHighScoreStore(highScore))
        copy.state = state
        copy.turtle = turtle
        copy.obstacles = obstacles
        copy.lands = lands
        copy.stars = stars
        copy.currentScore = currentScore
        copy.spawnTimer = spawnTimer
        copy.nextId = nextId
        copy.pairsSpawned = pairsSpawned
        return copy
    }

    // MARK: - State transitions (FlappyModel::wait/play/replay/pause/resume)

    func wait() {
        state = .wait
        pairsSpawned = 0
        turtle = Turtle()
        createEnvironment()
    }

    func play() {
        state = .play
        spawnTimer = GameConfig.obstacleSpawnInterval
    }

    func replay() {
        obstacles.removeAll()
        lands.removeAll()
        stars.removeAll()
        currentScore = 0
        wait()
    }

    func pause() { state = .pause }
    func resume() { state = .play }

    /// Turtle::jump.
    func jump() {
        guard turtle.position.y < GameConfig.designSize.height else { return }
        turtle.worldVelocityY = GameConfig.jumpVelocity
        turtle.rotation = GameConfig.jumpRotation
        turtle.spinVelocity = 0
        turtle.spinAccel = -1
    }

    func gameOver() {
        turtle.rotationVelocity = 0
        turtle.rotation = GameConfig.minRotation
        state = .finish
        onEvent?(.gameOver(isHighScore: saveHighScore()))
    }

    // MARK: - Frame update (FlappyModel::update)

    func update(_ dt: CGFloat) {
        if state == .pause { return }

        if state != .finish {
            scroll(&lands, velocity: GameConfig.obstacleVelocity,
                   width: GameConfig.landSize.width,
                   y: GameConfig.landSize.height / 2, dt: dt)
            scroll(&stars, velocity: GameConfig.starVelocity,
                   width: GameConfig.starSize.width,
                   y: GameConfig.designSize.height - GameConfig.starSize.height / 2, dt: dt)
        }

        if state != .wait {
            stepTurtle(dt)
        }

        guard state == .play else { return }

        spawnTimer -= dt
        if spawnTimer < 0 {
            spawnTimer = GameConfig.obstacleSpawnInterval
            createObstacles()
        }

        var reachedCount = 0
        for i in obstacles.indices {
            obstacles[i].advanceMotion(dt)
            // Obstacle::update
            obstacles[i].position.x += obstacles[i].velocityX * dt
            if obstacles[i].position.x < -(obstacles[i].width / 2) {
                obstacles[i].velocityX = 0
            }
            if obstacles[i].position.x < turtle.position.x && !obstacles[i].reached {
                obstacles[i].reached = true
                reachedCount += 1
            }
        }
        if reachedCount == 2 {
            currentScore += 1
            onEvent?(.scored(currentScore))
        }
        obstacles.removeAll { $0.velocityX == 0 }

        if turtle.position.y <= GameConfig.groundY {
            gameOver()
            return
        }
        let turtleBox = turtle.box
        if obstacles.contains(where: { Collision.overlaps(turtleBox, $0.collisionBox) }) {
            gameOver()
        }
    }

    // MARK: - Private

    /// One Box2D step (semi-implicit Euler, b2_maxTranslation clamp) followed by
    /// Turtle::update and the ground clamp done in FlappyModel::update.
    private func stepTurtle(_ dt: CGFloat) {
        let ptm = GameConfig.ptmRatio
        var worldY = turtle.position.y / ptm
        var v = turtle.worldVelocityY + dt * GameConfig.gravity
        let translation = dt * v
        if translation * translation > GameConfig.maxTranslationPerStep * GameConfig.maxTranslationPerStep {
            v *= GameConfig.maxTranslationPerStep / abs(translation)
        }
        worldY += dt * v
        turtle.worldVelocityY = v

        // Turtle::update (Obj::update integrates the body rotation first).
        turtle.rotation += turtle.rotationVelocity * dt
        turtle.spinAccel += dt * GameConfig.spinAccelRate
        var rotationToSub = dt * GameConfig.spinBaseRate
        if turtle.spinAccel > 0 {
            rotationToSub *= turtle.spinAccel
        }
        turtle.spinVelocity = max(turtle.spinVelocity - rotationToSub, GameConfig.maxSpinVelocity)
        turtle.rotationVelocity = turtle.spinVelocity
        if turtle.rotation < GameConfig.minRotation {
            turtle.rotation = GameConfig.minRotation
        }

        turtle.position.y = max(worldY * ptm, GameConfig.groundY)
    }

    private func scroll(_ strips: inout [ScrollStrip], velocity: CGFloat,
                        width: CGFloat, y: CGFloat, dt: CGFloat) {
        for i in strips.indices {
            strips[i].position.x += velocity * dt
        }
        guard let first = strips.first else { return }
        if !first.passHead {
            if first.position.x < 0 {
                strips.append(ScrollStrip(id: makeId(),
                                          position: CGPoint(x: first.position.x + width, y: y)))
                strips[0].passHead = true
            }
        } else if first.position.x < -width {
            strips.removeFirst()
        }
    }

    private func createObstacles() {
        let hole = random.nextInt(GameConfig.holeMax - GameConfig.holeMin) + GameConfig.holeMin
        let halfHole = GameConfig.holeHeight / 2
        let upHeight = CGFloat(Int(GameConfig.designSize.height) - (hole + halfHole))
        let downHeight = CGFloat(hole - halfHole - Int(GameConfig.landHeight))
        let x = GameConfig.designSize.width + GameConfig.obstacleSize.width / 2
        pairsSpawned += 1
        let motion = pairsSpawned >= GameConfig.movingGapFromPair ? GapMotion(spawnCentre: CGFloat(hole)) : nil

        obstacles.append(Obstacle(id: makeId(),
                                  position: CGPoint(x: x, y: GameConfig.designSize.height),
                                  height: upHeight, isFlipped: true, holeCenter: CGFloat(hole),
                                  pairNumber: pairsSpawned, motion: motion))
        obstacles.append(Obstacle(id: makeId(),
                                  position: CGPoint(x: x, y: GameConfig.landHeight + downHeight),
                                  height: downHeight, isFlipped: false, holeCenter: CGFloat(hole),
                                  pairNumber: pairsSpawned, motion: motion))
    }

    private func createEnvironment() {
        lands.append(ScrollStrip(id: makeId(),
                                 position: CGPoint(x: 0, y: GameConfig.landSize.height / 2)))
        stars.append(ScrollStrip(id: makeId(),
                                 position: CGPoint(x: 0, y: GameConfig.designSize.height - GameConfig.starSize.height / 2)))
    }

    private func saveHighScore() -> Bool {
        guard currentScore > highScore else { return false }
        highScore = currentScore
        store.save(highScore)
        return true
    }

    private func makeId() -> Int {
        nextId += 1
        return nextId
    }
}
