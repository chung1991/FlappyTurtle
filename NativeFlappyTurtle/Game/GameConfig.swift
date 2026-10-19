import CoreGraphics

/// Every tuning constant of the original game, ported 1:1 from
/// `Classes/util/Resources.h`, `Classes/AppMacros.h` and the Box2D defaults the
/// original relied on. Units are design points (== pixels of the xhdpi art).
enum GameConfig {
    // MARK: Design resolution (AppMacros.h, ResolutionPolicy::FIXED_HEIGHT)
    static let designSize = CGSize(width: 960, height: 640)

    /// Widest display aspect ratio the game renders; wider screens get black
    /// side bars. The original has no launch storyboard, so on every modern
    /// iPhone iOS runs it in a 3:2 legacy box (display == design, vectorMove 0).
    /// 1.5 reproduces exactly that. Raise up to 1150/640 (art width) to use more
    /// of the screen; beyond that the background/land art shows gaps.
    static let maxDisplayAspect: CGFloat = 1.5

    // MARK: Obstacles (NUM_*)
    static let holeHeight = 220
    static let holeMin = 170
    static let holeMax = 520
    static let obstacleSpawnInterval: CGFloat = 2.0
    static let obstacleVelocity: CGFloat = -250
    static let starVelocity: CGFloat = -20
    static let landHeight: CGFloat = 50
    static let scoreCountVelocity: CGFloat = 10

    // MARK: Moving gaps (new: not in the original game)
    /// From this pair on (1-based, per round) the gap moves up and down.
    static let movingGapFromPair = 10
    static let movingGapSpeed: CGFloat = 50
    /// Height of the band the gap centre bounces in.
    static let movingGapBand: CGFloat = 180

    // MARK: Box2D world (FlappyModel::createWorld / Turtle::jump / b2Settings.h)
    static let ptmRatio: CGFloat = 32
    static let gravity: CGFloat = -70            // m/s^2
    static let jumpVelocity: CGFloat = 20        // m/s
    static let maxTranslationPerStep: CGFloat = 2 // b2_maxTranslation, metres
    /// b2CollidePolygons tolerance: 2 * b2_polygonRadius. The original passes
    /// pixel coordinates straight into Box2D, so this is in points.
    static let collisionTolerance: CGFloat = 0.02

    // MARK: Turtle rotation (Turtle.cpp)
    static let jumpRotation: CGFloat = 30
    static let minRotation: CGFloat = -90
    static let spinAccelRate: CGFloat = 13
    static let spinBaseRate: CGFloat = 150
    static let maxSpinVelocity: CGFloat = -500

    // MARK: Sprite sizes (content sizes from game.plist / obstacle.png).
    // AtlasTests asserts these still match the bundled art.
    static let turtleSize = CGSize(width: 95, height: 71)
    static let obstacleSize = CGSize(width: 150, height: 500)
    static let landSize = CGSize(width: 1150, height: 50)
    static let starSize = CGSize(width: 1150, height: 185)

    /// Lowest y the turtle centre may reach; touching it ends the game.
    static var groundY: CGFloat { turtleSize.height / 2 + landHeight }
}

/// Display geometry derived exactly like AppDelegate::applicationDidFinishLaunching.
struct Viewport: Equatable {
    /// Visible area in design points (height is always 640).
    let displaySize: CGSize
    /// Offset applied to the gameplay layers so the 960-wide design is centred.
    let vectorMove: CGPoint

    init(aspect: CGFloat) {
        let height = GameConfig.designSize.height
        let width = height * aspect
        displaySize = CGSize(width: width, height: height)
        vectorMove = CGPoint(x: (width - GameConfig.designSize.width) * 0.5,
                             y: 0)
    }

    static let design = Viewport(aspect: GameConfig.designSize.width / GameConfig.designSize.height)
}
