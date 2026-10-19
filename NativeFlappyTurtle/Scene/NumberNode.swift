import SpriteKit

/// Digit-sprite score display, reproducing the layout maths shared by
/// GameScene::updateScore and GameLayer::updateCurrentScore/updateHighScore:
/// digits at `spacing, 2*spacing, ...` and the whole node re-centred on
/// `anchorX - (lastX + digitWidth/2) / 2`.
final class NumberNode: SKNode {
    private let spacing: CGFloat
    private let digitScale: CGFloat
    private let anchorX: CGFloat
    private(set) var value: Int?

    init(anchor: CGPoint, spacing: CGFloat, digitScale: CGFloat) {
        self.spacing = spacing
        self.digitScale = digitScale
        anchorX = anchor.x
        super.init()
        position = anchor
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ number: Int) {
        guard number != value else { return }
        value = number
        removeAllChildren()
        var posX: CGFloat = 0
        var newPosX: CGFloat = 0
        for character in String(number) {
            posX += spacing
            let texture = TextureAtlas.shared.texture("number/\(character).png")
            let digit = SKSpriteNode(texture: texture)
            digit.setScale(digitScale)
            digit.position = CGPoint(x: posX, y: 0)
            // Uses the unscaled content width, like the original.
            newPosX = posX + texture.size().width / 2
            addChild(digit)
        }
        position.x = anchorX - newPosX / 2
    }

    func clear() {
        value = nil
        removeAllChildren()
    }
}
