# Native Flappy Turtle

A native iOS port of the Cocos2d-x game *Flappy Turtle*, written in Swift with
SpriteKit. Physics, tuning constants, layout maths and art match the original.
The port also adds one gameplay feature the original never had: from the 10th
pipe pair on, the gaps move up and down.

- iOS 15+, iPhone and iPad, landscape only
- No third-party dependencies
- Bundle id: `com.droidtapgames.nativeflappyturtle`

## Quick start

```bash
Scripts/build.sh                 # build for the simulator, prints the .app path
Scripts/test.sh                  # run unit + UI tests
Scripts/shot.sh menu --live      # install, launch and screenshot the title screen
```

Or open `NativeFlappyTurtle.xcodeproj` in Xcode and run the `NativeFlappyTurtle`
scheme.

The scripts use the simulator in `$SIM_UDID`. If that isn't set, they use the
first booted simulator, or boot an "iPhone 17". Build products go to
`~/Library/Developer/Xcode/DerivedData/NativeFlappyTurtle-sim`. You can
override that with `$DERIVED`.

## Project layout

```
NativeFlappyTurtle/
  App/        UIKit host: app/scene delegates, GameViewController, GameView (accessibility)
  Game/       Pure-Swift game logic, no SpriteKit (model, entities, collision, config, autopilot)
  Scene/      SpriteKit rendering: GameScene, HUD, digit sprites, buttons
  Platform/   Texture atlas, sound, share sheet
  Support/    Launch hooks for tests and screenshots
  Resources/  Original atlas, sounds and fonts
NativeFlappyTurtleTests/     Unit tests (model, physics, collision, layout, atlas, autopilot)
NativeFlappyTurtleUITests/   Screenshot tests and end-to-end gameplay flows
Snapshots/Baselines/         Reference screenshots, grouped by screen size
Verification/                SWE-bench-style tasks with hidden tests
Scripts/                     Build, test, screenshot and verify scripts
SourceArt/                   Original loose art (not part of the build)
Config/Info.plist
```

### Architecture

- **`GameModel`** ports `FlappyModel.cpp`. It holds all game state and rules
  and advances in fixed steps. It doesn't import SpriteKit, so every rule can
  be unit-tested.
- **`GameController`** routes view requests (play, pause, replay, share, …) to
  the model and handles sound and sharing.
- **`GameScene`** copies model state onto sprites every frame and turns touches
  into controller requests. **`HUDNode`** draws the title board, "get ready",
  pause overlay, score and game-over board.
- **`GameConfig`** holds every tuning constant, ported 1:1 from the original
  `Resources.h`, `AppMacros.h` and the Box2D defaults. The design resolution is
  960×640. Wider screens get black side bars (`maxDisplayAspect`).

## Testing

```bash
Scripts/test.sh                       # everything
Scripts/test.sh unit                  # model/physics/layout tests (fast)
Scripts/test.sh ui                    # all UI tests
Scripts/test.sh snapshots             # screenshot tests only
Scripts/test.sh flows                 # gameplay flow tests only
Scripts/test.sh snapshots --record    # re-record baselines after an intended visual change
```

Baselines are stored per screen size (for example
`Snapshots/Baselines/1260x2736/`), so run screenshot tests on the same
simulator model that recorded them. When a screenshot test fails, the actual
image and a red diff are written to `Snapshots/Failures/` (git-ignored).

## Launch hooks

You can launch the app straight into any state using launch arguments or a
deep link. The tests, the screenshot script and the autopilot all use these
hooks. A launch with no `-ft-` options behaves like a normal launch.

```bash
# launch arguments
-ft-scene gameover -ft-score 12 -ft-highscore 30 -ft-seed 7 -ft-freeze -ft-mute

# deep link (restarts the game in place, no relaunch)
xcrun simctl openurl booted "nativeflappyturtle://launch?scene=gameover&freeze=1"
```

| Option | Effect |
|---|---|
| `scene` | `menu`, `ready`, `playing`, `paused`, `gameover` |
| `seed` | Seeds the obstacle gaps so layouts are reproducible |
| `score` / `highscore` | Override the current / starting high score (`highscore` implies `isolated`) |
| `advance` | Seconds of fixed-step autopilot before showing the scene (default 3 for `playing`/`paused`) |
| `freeze` | Stop simulation and animations for pixel-stable screenshots |
| `autopilot` | Let the bot fly during live play |
| `mute` | No sound |
| `isolated` | Keep the high score in memory and never touch the saved one |

### Screenshots

```bash
Scripts/shot.sh gameover -ft-score 12 -ft-highscore 30
Scripts/shot.sh playing -ft-advance 8
Scripts/shot.sh paused --compare      # also diff against the recorded baseline
Scripts/shot.sh menu --live --build   # rebuild first, don't freeze
```

Every screenshot is muted, uses seed 7 and an in-memory high score. Output goes
to `/tmp/nativeflappyturtle/<scene>.png`.

## Verification tasks

`Verification/<task>/` holds SWE-bench-style tasks. Each task has a problem
statement (`TASK.md`), a `FAIL_TO_PASS` / `PASS_TO_PASS` list (`tests.json`),
hidden unit and UI tests, and reference screenshots.

```bash
Scripts/verify_task.sh moving-pipes                    # grade this tree
Scripts/verify_task.sh moving-pipes --tree /tmp/base   # grade another checkout
Scripts/verify_task.sh moving-pipes --fast             # unit tests only
Scripts/verify_task.sh moving-pipes --record           # gold solution only: record reference screenshots
```

The script copies the hidden tests into the tree, runs the full suite, and
prints a JSON report. It exits 0 when the task is `RESOLVED`.

### `moving-pipes`

Starting with the 10th pair of each round, the pipe gap (still 220 pt) moves
at 50 pt/s. It bounces inside a 180 pt band around the pair's spawn centre.
The constants are in the "Moving gaps" section of `GameConfig`.
`Verification/moving-pipes/TASK.md` has the full spec. It also explains why
the speed is 50 pt/s rather than 120: at 120 pt/s a descending gap can't be
passed.
