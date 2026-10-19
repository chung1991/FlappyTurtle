import CoreGraphics

/// Turtle.cpp + its Box2D body. `rotation` is the original `Body` rotation:
/// degrees, counter-clockwise positive (jump = +30, dead = -90).
struct Turtle: Equatable {
    /// Screen position (design points) of the body centre.
    var position = CGPoint(x: GameConfig.designSize.width / 4,
                           y: GameConfig.designSize.height / 2)
    var rotation: CGFloat = 0
    var rotationVelocity: CGFloat = 0
    /// Turtle::currentVelocity — angular velocity being built up.
    var spinVelocity: CGFloat = -100
    /// Turtle::currentAccel.
    var spinAccel: CGFloat = 0
    /// Box2D linear velocity, metres per second (x is always 0).
    var worldVelocityY: CGFloat = 0

    var box: OrientedBox {
        // Utils::b2Interact converts with 3.14, not pi; keep it for parity.
        OrientedBox(center: position, size: GameConfig.turtleSize,
                    angle: rotation * 3.14 / 180)
    }
}

/// Obstacle.cpp. Anchored at its top-centre like the original (anchor 0.5, 1).
struct Obstacle: Equatable, Identifiable {
    let id: Int
    var position: CGPoint
    private(set) var height: CGFloat
    /// Top pipe: texture flipped vertically.
    let isFlipped: Bool
    /// Current y of the gap centre this pipe belongs to.
    private(set) var holeCenter: CGFloat
    /// 1-based spawn order of the pair within the round.
    let pairNumber: Int
    /// Set from `GameConfig.movingGapFromPair` on: the gap moves up and down.
    private(set) var motion: GapMotion?
    var velocityX: CGFloat = GameConfig.obstacleVelocity
    var reached = false

    var width: CGFloat { GameConfig.obstacleSize.width }

    init(id: Int, position: CGPoint, height: CGFloat, isFlipped: Bool, holeCenter: CGFloat,
         pairNumber: Int = 1, motion: GapMotion? = nil) {
        self.id = id
        self.position = position
        self.height = height
        self.isFlipped = isFlipped
        self.holeCenter = holeCenter
        self.pairNumber = pairNumber
        self.motion = motion
    }

    /// Advances the gap motion and re-derives this pipe's geometry. The top pipe
    /// stays attached to the top edge, the bottom pipe stays on the land.
    mutating func advanceMotion(_ dt: CGFloat) {
        guard var motion else { return }
        motion.advance(dt)
        self.motion = motion
        holeCenter = motion.centre
        let halfGap = CGFloat(GameConfig.holeHeight) / 2
        if isFlipped {
            height = GameConfig.designSize.height - (motion.centre + halfGap)
        } else {
            height = motion.centre - halfGap - GameConfig.landHeight
            position.y = GameConfig.landHeight + height
        }
    }

    var collisionBox: OrientedBox {
        OrientedBox(center: CGPoint(x: position.x, y: position.y - height / 2),
                    size: CGSize(width: width, height: height))
    }
}

/// Vertical movement of a gap centre: constant speed, bouncing inside a band
/// of `GameConfig.movingGapBand` that is kept within the normal spawn range.
struct GapMotion: Equatable {
    private(set) var centre: CGFloat
    /// +1 up, -1 down.
    private(set) var direction: CGFloat
    let low: CGFloat
    var high: CGFloat { low + GameConfig.movingGapBand }

    init(spawnCentre: CGFloat) {
        let band = GameConfig.movingGapBand
        let minCentre = CGFloat(GameConfig.holeMin)
        let maxCentre = CGFloat(GameConfig.holeMax)
        centre = spawnCentre
        low = min(max(spawnCentre - band / 2, minCentre), maxCentre - band)
        direction = spawnCentre < (minCentre + maxCentre) / 2 ? 1 : -1
    }

    /// Closed form of repeated `advance` (a triangle wave inside the band).
    func centre(after seconds: CGFloat) -> CGFloat {
        let band = GameConfig.movingGapBand
        let offset = centre - low
        let unfolded = (direction > 0 ? offset : 2 * band - offset) + GameConfig.movingGapSpeed * seconds
        let phase = unfolded.truncatingRemainder(dividingBy: 2 * band)
        return low + (phase <= band ? phase : 2 * band - phase)
    }

    mutating func advance(_ dt: CGFloat) {
        centre += direction * GameConfig.movingGapSpeed * dt
        if centre > high {
            centre = 2 * high - centre
            direction = -1
        } else if centre < low {
            centre = 2 * low - centre
            direction = 1
        }
    }
}

/// Land.cpp / Star.cpp: endlessly tiled strips, anchored left-centre.
struct ScrollStrip: Equatable, Identifiable {
    let id: Int
    var position: CGPoint
    var passHead = false
}
