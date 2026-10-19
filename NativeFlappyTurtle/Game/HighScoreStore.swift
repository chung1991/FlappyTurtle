import Foundation

/// Replaces the original `highscore.dat` file.
protocol HighScoreStore: AnyObject {
    func load() -> Int
    func save(_ score: Int)
}

final class UserDefaultsHighScoreStore: HighScoreStore {
    private let defaults: UserDefaults
    private let key = "highScore"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> Int { defaults.integer(forKey: key) }
    func save(_ score: Int) { defaults.set(score, forKey: key) }
}

/// Used by tests and screenshot hooks so runs never touch the real high score.
final class InMemoryHighScoreStore: HighScoreStore {
    var value: Int

    init(_ value: Int = 0) { self.value = value }

    func load() -> Int { value }
    func save(_ score: Int) { value = score }
}
