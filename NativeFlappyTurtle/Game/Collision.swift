import CoreGraphics

/// Rectangle with centre, size and rotation — the native stand-in for the
/// original `RectBody` as fed into `Utils::b2Interact`.
struct OrientedBox: Equatable {
    var center: CGPoint
    var size: CGSize
    /// Radians, counter-clockwise.
    var angle: CGFloat = 0

    var vertices: [CGPoint] {
        let hx: CGFloat = size.width / 2, hy: CGFloat = size.height / 2
        let c: CGFloat = cos(angle), s: CGFloat = sin(angle)
        let corners: [(CGFloat, CGFloat)] = [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)]
        return corners.map { corner -> CGPoint in
            let (x, y) = corner
            let px: CGFloat = center.x + c * x - s * y
            let py: CGFloat = center.y + s * x + c * y
            return CGPoint(x: px, y: py)
        }
    }
}

enum Collision {
    /// Port of `b2CollidePolygons(...)` + `manifold.pointCount > 0` for two
    /// boxes: separating-axis test over both boxes' edge normals with Box2D's
    /// polygon skin tolerance.
    static func overlaps(_ a: OrientedBox, _ b: OrientedBox,
                         tolerance: CGFloat = GameConfig.collisionTolerance) -> Bool {
        let va = a.vertices, vb = b.vertices
        return maxSeparation(va, vb) <= tolerance && maxSeparation(vb, va) <= tolerance
    }

    private static func maxSeparation(_ poly: [CGPoint], _ other: [CGPoint]) -> CGFloat {
        var best = -CGFloat.greatestFiniteMagnitude
        for i in 0..<poly.count {
            let v1 = poly[i], v2 = poly[(i + 1) % poly.count]
            let edge = CGPoint(x: v2.x - v1.x, y: v2.y - v1.y)
            let length = (edge.x * edge.x + edge.y * edge.y).squareRoot()
            // Outward normal for counter-clockwise winding.
            let n = CGPoint(x: edge.y / length, y: -edge.x / length)
            let s = other.map { n.x * ($0.x - v1.x) + n.y * ($0.y - v1.y) }.min()!
            best = max(best, s)
        }
        return best
    }
}
