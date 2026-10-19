import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        var config = LaunchConfig(arguments: ProcessInfo.processInfo.arguments)
        if let url = connectionOptions.urlContexts.first?.url, let fromURL = LaunchConfig(url: url) {
            config = fromURL
        }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController(config: config)
        window.makeKeyAndVisible()
        self.window = window
    }

    /// `xcrun simctl openurl booted "nativeflappyturtle://launch?scene=gameover&freeze=1"`
    /// restarts the game in the requested state without relaunching.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url, let config = LaunchConfig(url: url),
              let controller = window?.rootViewController as? GameViewController else { return }
        controller.restart(with: config)
    }
}
