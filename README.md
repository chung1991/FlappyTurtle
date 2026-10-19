# Native Flappy Turtle

A native iOS port of the Cocos2d-x game *Flappy Turtle*, written in Swift with
SpriteKit. It keeps the original's physics, tuning, layout and art.

- iOS 15+, iPhone and iPad, landscape only
- No third-party dependencies

## Usage

### Run

Open `NativeFlappyTurtle.xcodeproj` in Xcode and run the `NativeFlappyTurtle`
scheme. Or, from the command line:

```bash
Scripts/build.sh              # build for the simulator, prints the .app path
Scripts/shot.sh menu --live   # install and launch on the simulator, save a screenshot
```

The scripts use the simulator in `$SIM_UDID`. If that isn't set, they use the
first booted simulator, or boot an "iPhone 17".

### Test

```bash
Scripts/test.sh                       # unit + UI tests
Scripts/test.sh unit                  # unit tests only
Scripts/test.sh ui                    # UI tests only
Scripts/test.sh snapshots --record    # re-record screenshot baselines
```

### Launch options

To open the app in a given state, pass launch arguments or open a deep link:

```bash
-ft-scene gameover -ft-score 12 -ft-highscore 30 -ft-seed 7 -ft-freeze -ft-mute
xcrun simctl openurl booted "nativeflappyturtle://launch?scene=gameover&freeze=1"
```

Scenes: `menu`, `ready`, `playing`, `paused`, `gameover`. Without any `-ft-`
option the app launches normally.
