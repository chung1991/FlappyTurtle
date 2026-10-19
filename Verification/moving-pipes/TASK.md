# Task: pipes start moving up and down from the 10th pair

## Problem statement (what the solver sees)

Flappy Turtle stays at the same difficulty forever. Starting with the
**10th pipe pair** of a round, the gap between the top and bottom pipe should
**move up and down** while the pair scrolls across the screen.

Requirements:

1. Pipe pairs are numbered from 1 in spawn order, per round (replay restarts
   at 1). A pair is one top pipe plus one bottom pipe, spawned together.
2. Pairs 1–9 behave exactly as before.
3. Every pair from the 10th on moves vertically for its whole life on screen:
   - Only the **gap** moves. The top pipe stays attached to the top edge
     (`position.y == 640`) and the bottom pipe stays standing on the land (its
     bottom at y = 50). Pipe heights change to follow the gap.
   - The gap size stays **220**.
   - The gap centre starts at the pair's spawn centre and moves at
     **50 pt/s**. It bounces between the edges of a **180 pt band**
     `[lo, lo + 180]`, where `lo = clamp(spawnCentre - 90, 170, 340)`. So the
     centre always stays within the normal spawn range 170…520.
   - It starts moving **up** if `spawnCentre < 345`, otherwise **down**.
   - Movement advances only while playing (not while paused or after game over).
4. Collisions use the pipes' current (moved) geometry.
5. The movement must show on screen. The sprites follow the model every frame.
6. All existing tests keep passing. That includes `AutopilotTests`: the
   built-in bot (used by the test hooks) must still be able to play.

Out of scope: art changes, sound, and score rules.

## How a verifier checks it

The hidden tests are in `hidden/` and run with `Scripts/verify_task.sh moving-pipes`.
They only use API that already existed at the base commit (`GameModel`,
`Obstacle.position/height/isFlipped/id`, `Collision`, launch hooks), so they
compile against any solution and against the unfixed base.

| Kind | Test | What it proves |
|---|---|---|
| FAIL_TO_PASS | `testTenthPairGapMoves` | pair 10's gap centre travels ≥ 40 pt within 1.5 s |
| FAIL_TO_PASS | `testLaterPairsAlsoMove` | pair 11 moves as well, ≥ 20 pt within 0.67 s ("from the 10th on") |
| FAIL_TO_PASS | `testMovingGapFollowsSpec` | exact trace: 50 pt/s, 180 band, start direction, anchoring, gap 220 |
| FAIL_TO_PASS | `testCollisionUsesMovingGeometry` | crashing into a moving pair ends the game on the exact frame the *current* geometry first overlaps |
| FAIL_TO_PASS | `testMovingPairOnScreen` (UI) | frozen screenshots at two moments of pair 10 match the reference render (the state is drawn correctly) |
| FAIL_TO_PASS | `testMovingPairAnimatesLive` (UI) | during live play, pair 10's gap measured **from the pixels** moves ≥ 20 pt and stays ≈ 220 (existing sprites really update) |
| PASS_TO_PASS | `testFirstNinePairsStayStill` | pairs 1–9 never change y or height |
| PASS_TO_PASS | `testMovingInvariantsEveryFrame` | every frame: gap 220, centre in 170…520, ≤ 2.5 pt/frame, pipes stay anchored |
| PASS_TO_PASS | `testPauseFreezesMovement` | no vertical motion while paused |
| PASS_TO_PASS | the existing suite | `NativeFlappyTurtleTests` + `NativeFlappyTurtleUITests` (54 tests) |

The invariant, pause and still-pair tests pass on the base too: the base never
moves anything, so the invariants hold trivially. They guard against a solution
that makes pipes move but breaks the rules.

The tests can't rely on the game's own bot surviving (a solution might break
it). So they fly the turtle with their own pilot, which works only from the
public pipe geometry.

Resolved = every FAIL_TO_PASS and every PASS_TO_PASS test passes.

## Verifier hole found by a mutant (and fixed)

A mutant whose sprites never move after spawning passed the frozen screenshot
test. The `-ft-advance … -ft-freeze` hook simulates first and then builds every
sprite fresh, so frozen frames only prove that the *state* can be drawn.
`testMovingPairAnimatesLive` closes the hole. It lets the game run, takes several
screenshots, and measures pair 10's gap from the pixels. That needs no hook
changes from the solver.

Mutants used to check that the verifier is strict:

| Mutant | Caught by |
|---|---|
| moves from pair 9 (off by one) | `testFirstNinePairsStayStill`, bot tests |
| pipes translate instead of staying anchored | `testMovingGapFollowsSpec`, invariants |
| 120 pt/s (unbeatable) | `testMovingGapFollowsSpec`, `AutopilotTests` |
| model moves but sprites don't | `testMovingPairAnimatesLive` |

## Why 50 pt/s (spec revision)

The first draft said 120 pt/s. The existing PASS_TO_PASS test
`AutopilotTests` ("the game stays beatable") failed against it, and the physics
explains why. A flap sets the turtle's upward speed to 640 pt/s, so inside a
gap descending at speed v the hop is (640 + v)² / (2·2240) tall *relative to
the gap*. The turtle's rotated box (43–54 pt half-height) leaves about 114 pt of
room in a 220 gap. That gives v ≲ 75 pt/s, and at 120 pt/s a descending gap is
impossible to pass for anyone. A rollout planner confirms it: it survives every
seed at 50, and dies at 75 and at 120.
