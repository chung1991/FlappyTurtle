import CoreGraphics

/// Drives a freshly presented scene into the state a `LaunchConfig` asks for.
/// Everything runs synchronously in fixed 1/60 steps before the first frame,
/// so the same config always produces the same picture.
enum TestHooks {
    static func apply(_ config: LaunchConfig, to scene: GameScene) {
        let controller = scene.controller
        let model = controller.model

        switch config.scene {
        case nil, .menu?:
            break
        case .ready?:
            scene.hud.hideBegin()
        case .playing?, .paused?:
            scene.hud.hideBegin()
            controller.handle(.jump)
            Autopilot.run(controller, seconds: config.effectiveAdvance)
            if config.scene == .paused {
                controller.handle(.pause)
            }
        case .gameover?:
            scene.hud.hideBegin()
            if config.effectiveAdvance > 0 {
                controller.handle(.jump)
                Autopilot.run(controller, seconds: config.effectiveAdvance)
            }
            if model.state == .wait { model.play() }
            if let score = config.score { model.currentScore = score }
            if model.state != .finish { model.gameOver() }
            // Let the turtle drop onto the ground.
            for _ in 0..<90 { model.update(1.0 / 60.0) }
            scene.hud.completeFinishImmediately()
        }

        if let score = config.score, config.scene != .gameover {
            model.currentScore = score
        }
        scene.syncNodes()
        scene.applyStateVisibility()
        scene.isAutopilotEnabled = config.autopilot
        scene.isFrozen = config.freeze
    }

    /// One-line machine-readable state, exposed to UI tests through the
    /// accessibility label of an invisible probe view (`ft.state`).
    static func stateDescription(of scene: GameScene) -> String {
        let model = scene.controller.model
        let fields: [(String, Any)] = [
            ("state", model.state.rawValue),
            ("score", model.currentScore),
            ("high", model.highScore),
            ("begin", scene.hud.beginLayer.isHidden ? 0 : 1),
            ("instruction", scene.hud.isInstructionShown ? 1 : 0),
            ("pause", scene.hud.isPauseShown ? 1 : 0),
            ("finish", scene.hud.isFinishShown ? 1 : 0),
            ("obstacles", model.obstacles.count),
            ("frozen", scene.isFrozen ? 1 : 0),
        ]
        return fields.map { "\($0.0)=\($0.1)" }.joined(separator: " ")
    }
}
