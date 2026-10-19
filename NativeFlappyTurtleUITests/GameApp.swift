import XCTest

/// Thin page-object over the app: launches with test hooks and reads the
/// `ft.state` probe the app exposes in test mode.
struct GameApp {
    let app = XCUIApplication()

    /// Launches straight into a scene. Every launch is muted and uses an
    /// in-memory high score so tests never touch real data.
    @discardableResult
    func launch(scene: String? = nil, _ extra: [String] = []) -> GameApp {
        app.launchArguments = ["-ft-mute", "-ft-isolated"] + (scene.map { ["-ft-scene", $0] } ?? []) + extra
        app.launch()
        XCTAssertTrue(probe.waitForExistence(timeout: 10), "state probe missing")
        return self
    }

    var probe: XCUIElement { app.staticTexts["ft.state"] }

    /// Parsed probe, e.g. ["state": "play", "score": "3", ...].
    var state: [String: String] {
        Dictionary(uniqueKeysWithValues: probe.label.split(separator: " ").compactMap { pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        })
    }

    func button(_ id: String) -> XCUIElement { app.buttons[id] }

    var playfield: XCUIElement { app.descendants(matching: .any)["ft.game"] }

    /// Taps empty sky (a jump / resume tap): upper middle of the playfield,
    /// design point (W/2, 448) — above every button in every state.
    func tapGame() {
        playfield.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
    }

    /// Polls the probe (every 0.1s — XCTNSPredicateExpectation only checks
    /// about once a second, too slow for a game) until it reports `key=value`.
    @discardableResult
    func wait(_ key: String, _ value: String, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if state[key] == value { return true }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return false
    }
}
