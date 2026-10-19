import Foundation

/// Test / debug hooks, readable from launch arguments or a deep link:
///
///     -ft-scene gameover -ft-score 12 -ft-highscore 30 -ft-seed 7 -ft-freeze -ft-mute -ft-autopilot
///     nativeflappyturtle://launch?scene=gameover&score=12&highscore=30&seed=7&freeze=1&mute=1
///
/// Without any `ft` option the app behaves exactly like a normal launch.
struct LaunchConfig: Equatable {
    enum Scene: String, CaseIterable {
        /// Title board (normal launch).
        case menu
        /// "Get ready" instructions (as if Play was tapped).
        case ready
        /// Mid-game: first flap, then `advance` seconds of autopilot.
        case playing
        /// `playing` + pause overlay.
        case paused
        /// Game-over board fully shown (slide-in and count-up skipped).
        case gameover
    }

    var scene: Scene?
    /// Seeds obstacle gaps so layouts are reproducible.
    var seed: UInt64?
    /// Overrides the current score after the scene is set up.
    var score: Int?
    /// Starting high score; implies `isolated`.
    var highScore: Int?
    /// Seconds of fixed-step autopilot for `playing`/`paused`/`gameover`.
    var advance: Double?
    /// Freeze simulation + animations after setup (pixel-stable screenshots).
    var freeze = false
    /// Let the bot fly during live play (soak tests, demos, flow tests).
    var autopilot = false
    var mute = false
    /// Keep the high score in memory so runs never touch the saved one.
    var isolated = false

    static let urlScheme = "nativeflappyturtle"
    private static let prefix = "-ft-"

    var isTestMode: Bool { self != LaunchConfig() }

    /// Seconds of autopilot actually used for `scene`.
    var effectiveAdvance: Double {
        advance ?? (scene == .playing || scene == .paused ? 3.0 : 0)
    }

    init() {}

    init(arguments: [String]) {
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            index += 1
            guard argument.hasPrefix(Self.prefix) else { continue }
            let key = String(argument.dropFirst(Self.prefix.count))
            if index < arguments.count, !arguments[index].hasPrefix("-") {
                values[key] = arguments[index]
                index += 1
            } else {
                values[key] = "1"
            }
        }
        self.init(values: values)
    }

    init?(url: URL) {
        guard url.scheme == Self.urlScheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            values[item.name] = item.value ?? "1"
        }
        self.init(values: values)
    }

    private init(values: [String: String]) {
        scene = values["scene"].flatMap(Scene.init(rawValue:))
        seed = values["seed"].flatMap(UInt64.init)
        score = values["score"].flatMap(Int.init)
        highScore = values["highscore"].flatMap(Int.init)
        advance = values["advance"].flatMap(Double.init)
        freeze = Self.flag(values["freeze"])
        autopilot = Self.flag(values["autopilot"])
        mute = Self.flag(values["mute"])
        isolated = Self.flag(values["isolated"]) || highScore != nil
    }

    private static func flag(_ value: String?) -> Bool {
        guard let value else { return false }
        return !["0", "false", "no"].contains(value.lowercased())
    }
}
