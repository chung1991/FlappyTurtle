import SpriteKit
import UIKit

/// SKView that publishes the scene's interactive buttons as accessibility
/// elements — VoiceOver can use them, and UI tests can tap `app.buttons["ft.play"]`.
/// SKView implements the index-based container API itself, so both that and
/// `accessibilityElements` are overridden.
final class GameView: SKView {
    private var elements: [UIAccessibilityElement] = []

    override var isAccessibilityElement: Bool {
        get { false }
        set {}
    }

    override var accessibilityElements: [Any]? {
        get { refreshElements() }
        set {}
    }

    override func accessibilityElementCount() -> Int { refreshElements().count }

    override func accessibilityElement(at index: Int) -> Any? {
        elements.indices.contains(index) ? elements[index] : refreshElements()[safe: index]
    }

    override func index(ofAccessibilityElement element: Any) -> Int {
        elements.firstIndex { $0 === element as AnyObject } ?? NSNotFound
    }

    @discardableResult
    private func refreshElements() -> [UIAccessibilityElement] {
        guard let scene = scene as? GameScene else {
            elements = []
            return elements
        }
        elements = scene.interactiveButtons.map { button, frame in
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityIdentifier = button.identifier
            element.accessibilityLabel = button.accessibilityTitle
            element.accessibilityTraits = .button
            let a = scene.convertPoint(toView: CGPoint(x: frame.minX, y: frame.minY))
            let b = scene.convertPoint(toView: CGPoint(x: frame.maxX, y: frame.maxY))
            element.accessibilityFrameInContainerSpace = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                                                                width: abs(b.x - a.x), height: abs(b.y - a.y))
            return element
        }
        // The playfield itself: VoiceOver users tap through to flap, UI tests
        // tap relative to it (independent of letterboxing).
        let field = UIAccessibilityElement(accessibilityContainer: self)
        field.accessibilityIdentifier = "ft.game"
        field.accessibilityLabel = "Flappy Turtle"
        field.accessibilityHint = "Tap to flap"
        field.accessibilityTraits = .allowsDirectInteraction
        field.accessibilityFrameInContainerSpace = bounds
        elements.append(field)
        return elements
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
