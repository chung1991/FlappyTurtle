import CoreGraphics

/// Deterministic bot used by the screenshot hooks (to reach a mid-game state)
/// and by tests (to prove the physics is still beatable). Not used in play.
struct Autopilot {
    /// How far below the gap centre the turtle may sink before flapping.
    var margin: CGFloat = 30
    /// For moving gaps: flap ~45 below the centre so the ~91 pt hop is centred
    /// on the gap (static pairs keep the original 30, so old runs are unchanged).
    var movingMargin: CGFloat = 45
    /// Extra look-ahead into the hop that a flap now would produce.
    var hopLead: CGFloat = 0.15
    /// Frames each rollout simulates when a moving gap is ahead.
    var rolloutFrames = 45

    func shouldJump(_ model: GameModel) -> Bool {
        let preferred = policy(model)
        guard nextPair(model)?.motion != nil else { return preferred }
        // Moving gap: roll both choices forward on exact copies (each then
        // continuing with the policy) and keep whichever survives longer.
        let flap = rollout(model, flapFirst: true)
        let wait = rollout(model, flapFirst: false)
        return flap == wait ? preferred : flap > wait
    }

    private func nextPair(_ model: GameModel) -> Obstacle? {
        let turtleLeft = model.turtle.position.x - GameConfig.turtleSize.width / 2
        return model.obstacles.first { $0.position.x + $0.width / 2 > turtleLeft }
    }

    /// Cheap rule: flap when below the (predicted) gap centre minus a margin.
    /// Static pairs use exactly the original rule, so older runs are unchanged.
    private func policy(_ model: GameModel) -> Bool {
        let turtle = model.turtle
        guard turtle.worldVelocityY <= 0 else { return false }
        guard let next = nextPair(model) else {
            return turtle.position.y < GameConfig.designSize.height / 2 - margin
        }
        guard let motion = next.motion else {
            return turtle.position.y < next.holeCenter - margin
        }
        let distance = next.position.x - next.width / 2 - (turtle.position.x + GameConfig.turtleSize.width / 2)
        let arrival = max(0, distance / -GameConfig.obstacleVelocity)
        return turtle.position.y < motion.centre(after: arrival + hopLead) - movingMargin
    }

    /// Frames survived (Int.max = whole rollout) on a copy of the model.
    private func rollout(_ model: GameModel, flapFirst: Bool) -> Int {
        let copy = model.clone()
        if flapFirst { copy.jump() }
        for frame in 0..<rolloutFrames {
            copy.update(1.0 / 60.0)
            if copy.state != .play { return frame }
            if policy(copy) { copy.jump() }
        }
        return Int.max
    }

    /// Advances `model` by `seconds` in fixed 1/60 steps, flapping as needed.
    static func run(_ controller: GameController, seconds: Double,
                    autopilot: Autopilot = Autopilot()) {
        let dt: CGFloat = 1.0 / 60.0
        let steps = Int((seconds * 60).rounded())
        for _ in 0..<steps where controller.model.state == .play {
            if autopilot.shouldJump(controller.model) {
                controller.handle(.jump)
            }
            controller.model.update(dt)
        }
    }
}
