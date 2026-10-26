# Mario OTP

A SwiftUI one-time-code screen where verification is a tiny platformer level. Type the 4-digit
code and Mario runs in, punching each box from below with his signature fist-up jump:

- **Right digit**: the box bumps, turns **green** and pops a coin.
- **Wrong digit**: the box rattles and turns **red**, and a confused "?" appears over Mario.
- **All correct**: the boxes slide together into a gold **?-block**. Mario punches it and it turns into a check
  mark with a ripple and confetti. *Verified successfully.*
- **Some wrong**: greens stay locked in, reds clear, and you retype only those. Mario then
  sweeps back across and punches just the boxes you changed.

![Motion preview](docs/choreography-preview.gif)

*The preview is drawn from the real choreography engine's frame data (positions, timing, states).
Glows and type look nicer in the app itself.*

## Run it

You'll need **Xcode 16 or newer**. The app targets iOS 17+.

```sh
# first time
cd ~ && git clone https://github.com/nodedesignagency/mario-otp.git
cd ~/mario-otp && git checkout claude/wonderful-rubin-h46qhn && ./scripts/run.sh

# after that, to get the latest changes
cd ~/mario-otp && git fetch origin && git checkout claude/wonderful-rubin-h46qhn && git pull && ./scripts/run.sh
```

`scripts/run.sh` builds the app, boots a simulator and launches it. It uses the simulator that's already
open, or the newest iPhone Pro. Pass a name to choose: `./scripts/run.sh "iPhone 16"`.
You can also open `MarioOTP.xcodeproj` in Xcode and press **Run**.

The demo code is shown at the top of the screen (starts as `1985`). Type it, or type something wrong
first to see the red path.

To run on a device, choose your team under *Signing & Capabilities*.
Sounds follow the silent switch. Use the speaker button in the HUD to mute them.

## Extras beyond the reference

| | |
|---|---|
| 8-bit sound effects | Jump, coin, bonk, merge, fanfare and error sounds, synthesised at launch from square, triangle and noise waves (`ChipSounds.swift`). There are no audio files to ship. |
| Haptics | Light tap per digit, a rigid knock per block hit, success/error notifications. |
| Retro HUD | Score (+200 per coin, +1000 on verify), coin counter, and "world" that advances on every attempt. |
| Smart retry | Correct digits lock green; the cursor skips them. |
| SMS autofill | A hidden `.oneTimeCode` field drives everything, so autofill and paste work. |
| Resend countdown | "Resend in 0:30". Resending issues a new demo code. |
| Reduce Motion | No running or jumping. Boxes light up one after another and crossfade to the check. |
| VoiceOver | The code field is labelled, and results are announced. |

## How the animation works

```
type 4th digit ─▶ OTPFlowModel.startVerification()
                    │  grades each digit, then builds a Choreography: every Mario move,
                    │  every hit time, and the ending, all worked out before anything moves
                    ▼
           TimelineView (every frame)                     Task (on cue times)
           StageScene = f(choreography, t)                sounds · haptics · score · headline
           blocks, coins, Mario, rings, confetti          commit → lock greens / clear reds
```

- `Stage/Choreography.swift` holds the physics. A bonk takes off as if aiming 35% above the box, stops
  dead when the fist touches it, and falls back under the same gravity. The hop is timed so the fist touches
  the underside of each box, under its centre, right on the hit cue.
- `Stage/StageScene.swift` turns the choreography plus the time into a frame as plain values: bump curves,
  coin arcs, shake, the merge into the ?-block, rings and confetti.
- `Stage/StageView.swift` and `OTPBlockView.swift` render the frame. The neon boxes, the gold ?-block face,
  and the pixel sprites (`Sprites/Sprites.swift`, drawn as text grids) all live here.

Tuning knobs: `StageLayout` (sizes, jump headroom), `Choreography` (run speed, merge timing),
`BonkJump` (jump feel), `Motion` (bump, shake, coin and confetti curves).

## Hooking up a real backend

`CodeVerifier` in `Flow/OTPFlowModel.swift` is the stand-in. In production, keep two things in mind:

- **Per-digit feedback is for the demo only.** Telling users which digits are right reduces a 4-digit
  code from 10,000 guesses to at most 40. For a real OTP, have the server return pass/fail. Then light all
  boxes green, or all red, with the same choreography (`targets` with one shared `correct` value).
- The check is synchronous here. With a network call, start Mario's run when the request fires and
  build the hits once the response arrives, or add a short wait before the first bonk.

## A note on Mario

The plumber sprites are hand-made fan art, so this works as a concept or portfolio piece. Mario is Nintendo's IP: before
shipping to the App Store, swap the sprites in `Sprites.swift` for your own mascot. The animation
system doesn't care who's jumping.
