import SpriteKit

/// Port of `MenuItemSprite` inside a `Menu`: shows the selected frame while a
/// finger is on it and fires on touch-up inside. A button that receives the
/// touch swallows it, so the scene never sees it as a jump.
final class SpriteButton: SKSpriteNode {
    /// Stable id used for accessibility / UI tests, e.g. "ft.play".
    let identifier: String
    let accessibilityTitle: String
    var isEnabled = true
    var action: (() -> Void)?

    private let upTexture: SKTexture
    private let downTexture: SKTexture

    var isSelected = false {
        didSet { texture = isSelected ? downTexture : upTexture }
    }

    init(normal: String, selected: String, identifier: String, title: String) {
        upTexture = TextureAtlas.shared.texture(normal)
        downTexture = TextureAtlas.shared.texture(selected)
        self.identifier = identifier
        accessibilityTitle = title
        super.init(texture: upTexture, color: .clear, size: upTexture.size())
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Cocos Menu only hits items that are visible and enabled (and whose
    /// ancestors are visible).
    var isInteractive: Bool {
        guard isEnabled else { return false }
        var node: SKNode? = self
        while let current = node {
            if current.isHidden { return false }
            node = current.parent
        }
        return true
    }

    func contains(scenePoint: CGPoint) -> Bool {
        guard let scene, let parent else { return false }
        return frame.contains(parent.convert(scenePoint, from: scene))
    }
}

/// Tracks the single touch a cocos `Menu` follows at a time.
final class ButtonTracker {
    private(set) var buttons: [SpriteButton] = []
    private var trackedTouch: UITouch?
    private var selected: SpriteButton?

    func register(_ button: SpriteButton) { buttons.append(button) }

    private func hit(_ point: CGPoint) -> SpriteButton? {
        buttons.first { $0.isInteractive && $0.contains(scenePoint: point) }
    }

    /// Returns true when a button claimed (swallowed) the touch.
    func began(_ touch: UITouch, at point: CGPoint) -> Bool {
        guard trackedTouch == nil, let button = hit(point) else { return false }
        trackedTouch = touch
        selected = button
        button.isSelected = true
        return true
    }

    func moved(_ touch: UITouch, at point: CGPoint) -> Bool {
        guard touch == trackedTouch else { return false }
        let current = hit(point)
        if current !== selected {
            selected?.isSelected = false
            selected = current
            selected?.isSelected = true
        }
        return true
    }

    func ended(_ touch: UITouch, at point: CGPoint, cancelled: Bool) -> Bool {
        guard touch == trackedTouch else { return false }
        let button = selected
        button?.isSelected = false
        selected = nil
        trackedTouch = nil
        if !cancelled, let button, button.isInteractive {
            button.action?()
        }
        return true
    }
}
