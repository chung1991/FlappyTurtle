import UIKit
import XCTest

// Hidden UI verifier for Verification/moving-pipes/TASK.md: the movement must be
// visible, not just in the model. Two frozen frames of pair 10 (seed 7) are
// compared with reference renders recorded from the gold solution.
// Baselines: $FT_HIDDEN_BASELINES/<WxH>/<name>.png (set by verify_task.sh).
final class MovingPipesScreenVerifierTests: XCTestCase {
    override func setUp() {
        // Keep going so both frames are always compared (or recorded) in one run.
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    private func frozenFrame(advance: String) -> Bitmap? {
        let app = XCUIApplication()
        app.launchArguments = ["-ft-mute", "-ft-isolated", "-ft-scene", "playing", "-ft-seed", "7",
                               "-ft-advance", advance, "-ft-freeze"]
        app.launch()
        let probe = app.staticTexts["ft.state"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        let deadline = Date().addingTimeInterval(10)
        while !probe.label.contains("frozen=1") && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertTrue(probe.label.contains("state=play"), "hook run died: \(probe.label)")
        Thread.sleep(forTimeInterval: 1.0)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "pair10-t\(advance)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return Bitmap(image: shot.image)
    }

    private func assertMatchesReference(_ actual: Bitmap, name: String) {
        guard let root = ProcessInfo.processInfo.environment["FT_HIDDEN_BASELINES"] else {
            return XCTFail("FT_HIDDEN_BASELINES not set (run via Scripts/verify_task.sh)")
        }
        let folder = URL(fileURLWithPath: root).appendingPathComponent("\(actual.width)x\(actual.height)")
        let url = folder.appendingPathComponent("\(name).png")
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data),
              let expected = Bitmap(image: image),
              ProcessInfo.processInfo.environment["FT_RECORD_HIDDEN"] != "1" else {
            guard ProcessInfo.processInfo.environment["FT_RECORD_HIDDEN"] == "1" else {
                return XCTFail("Missing reference \(url.path)")
            }
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? actual.pngData().write(to: url)
            return XCTFail("Recorded reference \(url.path) (gold solution only). Re-run without --record.")
        }
        let (ratio, diff) = actual.compare(to: expected, threshold: 24)
        if ratio > 0.00005 {
            let attachment = XCTAttachment(data: diff.pngData(), uniformTypeIdentifier: "public.png")
            attachment.name = "\(name)-diff"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail(String(format: "%@ differs from the reference by %.3f%%", name, ratio * 100))
        }
    }

    /// Live check (no freeze): pair 10 is spawned and drawn by the running game,
    /// and its *drawn* gap must move. Frozen hook frames alone can't prove this,
    /// because the hook builds every sprite fresh after simulating.
    func testMovingPairAnimatesLive() throws {
        let app = XCUIApplication()
        // 19.5 s: pairs 8-9 on screen, pair 10 spawns live at ~20 s.
        app.launchArguments = ["-ft-mute", "-ft-isolated", "-ft-scene", "playing", "-ft-seed", "7",
                               "-ft-advance", "19.5", "-ft-autopilot"]
        app.launch()
        let probe = app.staticTexts["ft.state"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        let deadline = Date().addingTimeInterval(10)
        while !probe.label.contains("obstacles=6") && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        XCTAssertTrue(probe.label.contains("obstacles=6"), "pair 10 never spawned: \(probe.label)")
        // Until ~22 s pair 10 is the rightmost pair fully on screen.
        Thread.sleep(forTimeInterval: 0.7)
        let field = app.descendants(matching: .any)["ft.game"].frame
        var centres: [CGFloat] = []
        for _ in 0..<4 {
            let shot = XCUIScreen.main.screenshot()
            if let gap = GapReader.rightmostGap(in: shot.image, field: field) {
                XCTAssertEqual(gap.size, 220, accuracy: 12, "drawn gap size")
                centres.append(gap.centre)
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(probe.label.contains("state=play"), "round ended early: \(probe.label)")
        XCTAssertGreaterThanOrEqual(centres.count, 3, "could not find pair 10's gap on screen")
        let travel = (centres.max() ?? 0) - (centres.min() ?? 0)
        XCTAssertGreaterThanOrEqual(travel, 20, "drawn gap of pair 10 did not move: \(centres)")
    }

    func testMovingPairOnScreen() throws {
        // Pair 10 spawns at ~20 s; both moments keep it on screen.
        let early = try XCTUnwrap(frozenFrame(advance: "20.8"))
        let late = try XCTUnwrap(frozenFrame(advance: "21.6"))
        assertMatchesReference(early, name: "pair10-early")
        assertMatchesReference(late, name: "pair10-late")
    }
}

/// Reads the rightmost fully visible pipe pair's gap from a screenshot, in
/// design points (640 tall). Relies only on the spec: the top pipe hangs from
/// the top edge and the bottom pipe stands on the land (y = 50).
enum GapReader {
    struct Gap { let centre: CGFloat; let size: CGFloat }

    static func rightmostGap(in image: UIImage, field: CGRect) -> Gap? {
        // Draw upright (the screenshot carries its orientation), crop to the playfield.
        let scale = image.scale
        let size = CGSize(width: field.width * scale, height: field.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(x: -field.minX * scale, y: -field.minY * scale,
                                  width: image.size.width * scale, height: image.size.height * scale))
        }
        guard let bitmap = Bitmap(image: upright) else { return nil }
        let w = bitmap.width, h = bitmap.height
        let pt = CGFloat(h) / 640
        func luma(_ x: Int, _ y: Int) -> Int {
            let i = (y * w + x) * 4
            return (Int(bitmap.pixels[i]) * 3 + Int(bitmap.pixels[i + 1]) * 6 + Int(bitmap.pixels[i + 2])) / 10
        }
        func isPipe(_ x: Int, _ y: Int) -> Bool { luma(x, y) > 120 }

        // Runs of pipe colour along a row just below the top edge.
        let row = 3
        var runs: [(Int, Int)] = []
        var start: Int?
        for x in 0..<w {
            if isPipe(x, row) { start = start ?? x } else if let s = start { runs.append((s, x - 1)); start = nil }
        }
        let minWidth = Int(120 * pt)
        guard let pipe = runs.last(where: { $0.1 - $0.0 >= minWidth && $0.1 < w - 2 && $0.0 > 1 }) else { return nil }
        let column = (pipe.0 + pipe.1) / 2

        func firstGap(from y0: Int, step: Int) -> Int? {
            var y = y0
            var dark = 0
            while y >= 0 && y < h {
                dark = isPipe(column, y) ? 0 : dark + 1
                if dark >= 6 { return y - step * 5 }
                y += step
            }
            return nil
        }
        let landTop = Int((640 - 50) * pt) - 4
        guard let topEdge = firstGap(from: 0, step: 1),
              let bottomEdge = firstGap(from: landTop, step: -1), bottomEdge > topEdge else { return nil }
        let gapTop = 640 - CGFloat(topEdge) / pt
        let gapBottom = 640 - CGFloat(bottomEdge) / pt
        return Gap(centre: (gapTop + gapBottom) / 2, size: gapTop - gapBottom)
    }
}
