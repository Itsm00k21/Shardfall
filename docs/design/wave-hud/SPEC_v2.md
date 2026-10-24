# Wave HUD + Boss Bar, Spec v2: phone pass against the live arena HUD (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builders: Ghost (client HUD), Echo (`server/WaveArena/Hud.luau` payload). Base: `cursor/live-build-9721` @ **`a28a5e2`**. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP40P https://app.notion.com/p/403c31ca388381019967e14f73d4b5e4, task 1 ("Wave HUD + boss bar phone pass vs live a28a5e2 with copy-pass names, #428 refresh"). ACK: https://app.notion.com/p/403c31ca3883819ea93ced18efc48254. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on `SPEC_v1.md` (v1.2, same folder, direction **A: stack chip + boss bar**, decided). v1 was written before the arena HUD existed. v2 re-bases it on the code that shipped: what still holds, what moves, and what the payload is missing. Names come from the V1 copy pass (#459 `prism/v1-copy-pass` v1.1): **Shard Crater**, **Hollow Warden**, **CRACK**, "Wave %d/%d", "Wave %d clear!".

## What changed in v2 (short)
1. **Live audit** (§2, mockup 09): the arena HUD today is one `TextLabel` + one bar, top-center, and at every size it sits on the HP block, the currency pills or the toast host.
2. **Data reality:** the arena sends a **full snapshot every 0.1 s** already (the `step` poll, WaveArena/init.luau:32–50), so v1's "full-snapshot `WaveCounter` remote" ask is done in shape. What's missing is **fields**: `left`, `tier`, boss `name`, `secondsLeft` (§2, Q3–Q4, Q7).
3. **No break phase in live code**: the next wave spawns in the same step the last enemy dies (Round.luau:369–386). v1's "NEXT WAVE · 8" state is **parked** until #416 adds a break. It's replaced by a 1.0 s "CLEAR n/5" flash (Q8).
4. **No boss phase 2 in live code** (Boss.luau is a single slam), so v1's 50% phase tick is parked too.
5. **Placement moves** to fit the live `HudLayout` (§4): in a run, the chip takes the **currency pills slot** (top right), and the boss bar goes **under the HP block** on portrait, **in the pills strip** on landscape, **top-center** on desktop. All of them clear the toast host, the keep-out, the rail and the action cluster (mockups 10–12).

## 1. Goal
At any moment in a Shard Crater run, a phone player can tell in under a second which wave they're on (of 5), how many enemies are left, and, on wave 5, roughly how much HP the Hollow Warden has left. All of it without covering the fight, a combat button, the thumbstick or a toast, and with nothing in the screen center.

## 2. Where it lives + live audit (`a28a5e2`)
**Live code (read only):**
| Piece | File:line | What it does today |
|---|---|---|
| Client gate | `ShardfallClient/WaveArena/init.luau:24–27` | nothing mounts unless `LaunchGate.waveArena` (LaunchGate.luau:40, off) |
| Poll | `WaveArena/init.luau:32–50` | `InvokeServer("step", …)` every 0.1 s (`task.wait(0.1)` :49); `BossBar.apply(playerGui, state.hud)` :43 |
| Screen | `WaveArena/BossBar.luau:39–43` | `ScreenGui "WaveArenaBossBar"`, `DisplayOrder` 40, `ResetOnSpawn` false, default insets (CoreUISafeInsets) |
| Wave label | `BossBar.luau:44–54` | `TextLabel` 280×22, AnchorPoint (0.5, 0), Position **scale (0.5, 0.08)**, GothamMedium 16, `236,228,210`, no backing |
| Boss track | `BossBar.luau:55–69` | `Frame` 280×14 at **scale (0.5, 0.12)**, `40,32,28`; fill `176,64,48`; no `UICorner`, no `UIStroke`, no name |
| Update | `BossBar.luau:87–92` | label = `hud.text`; track visible only while a boss is alive (:90); fill `Size` set directly, no tween (:92) |
| Payload | `server/WaveArena/Hud.luau:31–43` | `{ wave, total, text = "Wave %d / %d" (:38), boss = { shown, hp, maxHp, ratio }, phase, card }` |
| Boss read | `Hud.luau:10–29` | first living `kind == "boss"`; hides as soon as the boss dies, even if adds are still up |
| Phases | `Round.luau:364` `fight`, `:372` `deathHold`, `:142` `results` | no `break` phase |
| Wave flow | `Round.luau:369–386` (`finishWave`) | wave clear → `spawnInto` next wave at once; boss wave → `deathHold` 1.5 s (WaveArenaConfig.luau:148) → results |
| Waves | `WaveArenaConfig.luau:245–251` | 6, 8, 10, 12, then boss + 4 adds (`boss.adds` :140, `boss.hp` 480 :141) |
| Time limit | `WaveArenaConfig.luau:25` `timeout = 480`; `Round.luau:263–269` | no on-screen timer today |
| Tier | `Round.luau:640` default `normal`, `:679–681`; `WaveArenaHost.luau:675` enter is always `normal` | tier is **not** in the HUD payload |
| Living count | `Round.luau:94–102` (`livingCount`) | exists on the server, **not** in the payload |
| Boss name | `WaveArenaConfig.luau:135–150` (`boss`) has no `name`; #459 D2 picks **Hollow Warden** | not in the payload |
| Old run label | `Ui.luau:605` (#459 D3) | Rootvault waves only; not drawn in the arena |

**Live rects** (safe-area px, measured from the scale positions above; mockup 09):
| Viewport | Label | Track | Sits on |
|---|---|---|---|
| 390×844 | x 55–335, y 68–90 | x 55–335, y 101–115 | portrait, HP block, pills column, toast host |
| 667×375 | x 194–474, y 30–52 | x 194–474, y 45–59 | HP block, pills strip |
| 800×400 | x 260–540, y 32–54 | x 260–540, y 48–62 | HP block, pills strip |
| 1280×720 | x 500–780, y 58–80 | x 500–780, y 86–100 | toast host |
It never enters the center keep-out, but it has no 44 px target, can't fold, and stacks on 2–4 live HUD pieces at every size.

**Target (Ghost):** a `WaveHud` module beside `BossBar`/`ResultsCard` in `ShardfallClient/WaveArena/`, same `apply(playerGui, hud)` hook from init.luau:43, drawing `WaveChip` and `BossBar` (v2 look). It replaces the old label + track; nothing else in the run HUD changes. **Echo:** extend `Hud.snapshot` (Q3, Q4, Q7). Prism edits none of these files.

## 3. Flow
| Step | Trigger (live) | Player sees | Payload |
|---|---|---|---|
| 1 Run starts | `enter` → `phase = "fight"`, wave 1 | chip fades in 0.2 s: "WAVE 1/5", "6 left", full cyan bar. Toast lane: "Into the Shard Crater!" (#459 C10) | `wave`, `total`, **`left`** (Q3) |
| 2 Kill | `livingCount` drops | bar tweens 0.15 s, count ticks; at ≤ 3 left the count + bar + stroke turn gold | `left` |
| 3 Wave 1–3 clear | `finishWave` → next wave spawns at once (Round.luau:379) | chip flashes **"CLEAR n/5"** gold for 1.0 s, then "WAVE n+1/5" with a full bar. Toast "Wave n clear!" (#459 D7) | `wave` jumps |
| 4 Wave 4 clear | same, wave 5 spawns | chip "WAVE 5/5", stroke turns boss orange (red on Hard), sub-line "4 adds". **Boss bar slides in** 0.25 s: "HOLLOW WARDEN", HP bar, % | `boss.shown`, `boss.ratio`, **`boss.name`** (Q3) |
| 5 Boss hit | `boss.ratio` drops | fill tweens 0.15 s, a white "ghost" fill trails 0.3 s behind | `boss.ratio` |
| 6 Boss dies | `phase = "deathHold"` 1.5 s | boss bar flashes gold and folds 0.25 s; chip "CLEARED" gold; adds left alive still count in the chip | `boss.shown = false` |
| 7 Last 60 s of 480 | `secondsLeft ≤ 60` (Q7) | count swaps to a red "0:59" countdown; stroke red | **`secondsLeft`** |
| 8 Run ends | `phase = "results"` | chip and boss bar fade 0.2 s; results wings take over (`prism/results-card-pass`, PR #464) | `card` |
| — Wipe | `endRun(run, "wipe")` | no HUD state: results show at once ("WIPED ON WAVE N", #464) | `card` |
| — Rejoin / missed poll | next `step` | chip repaints from the snapshot (every poll is a full snapshot) | all |
**Collapse:** tap the chip (or Tab on desktop) to fold it to a 44×44 "n/5" badge; tap again to unfold. The boss bar can't fold (it's the fight's main read), but it's only up while the boss is alive.

## 4. Layout
Frame: safe-area px (`HudLayout` coords, CoreUISafeInsets applied), the same frame as #464/#465. Neighbours from `HudLayout` @ `a28a5e2` (unchanged since `bcef573`). Center keep-out (#420): 390×844 x 117–273, y 296–616 · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. Toast host = `HudLayout.toastHost` (3 cards × 36 + 8 gaps, from y 80).

**In-run rule (Q1):** the currency pills (`HudLayout.pills`) hide while `phase` is `fight` or `deathHold` (#420 D2: the arena keeps the combat cluster), and the wave chip takes their slot.
| Piece | 390×844 | 667×375 | 800×400 | 1280×720 |
|---|---|---|---|---|
| Wave chip | **x 266–374, y 16–60** (108×44) | **x 531–651, y 36–80** (120×44) | **x 664–784, y 36–80** (120×44) | **x 1124–1264, y 44–88** (140×44) |
| Folded badge | x 330–374, y 16–60 | x 607–651, y 36–80 | x 740–784, y 36–80 | x 1220–1264, y 44–88 |
| Boss bar (wave 5) | **x 16–258, y 80–116** (242×36), under the HP block | **x 311–523, y 40–76** (212×36), left of the chip | **x 308–656, y 40–76** (348×36) | **x 440–840, y 28–72** (400×44), top-center |
| Toast host while the boss bar is up | **starts at y 124** (2 cards, Q2) | unchanged (y 80) | unchanged | unchanged |
| Goals tracker (#465) during a run | folded tab x 266–374, y 136–180 (Q6) | folded tab | folded tab | folded tab |
| Buff pips (#416, later) | 14 px row under the chip, x 266–374, y 64–78 | in the chip's row, left of the boss bar | same | same |
Checks (script, all pass): no piece enters the keep-out; none touches the portrait, HP block, rail, action cluster or Equip prompt; none overlaps the toast host (with the portrait boss shift); every tap target is ≥ 44 px (chip 44 tall, badge 44×44). The boss bar is display-only (`Active = false`), so its 36 px height isn't a tap target.

## 5. States
| # | State | Chip | Boss bar |
|---|---|---|---|
| 1 | Today's payload (no `left`, no `tier`) | "WAVE n/5" only, row stroke | as below if `boss.shown` |
| 2 | Fight | "WAVE n/5" + "N left" + cyan `120,210,255` bar | — |
| 3 | ≤ 3 left | count, bar and stroke gold `255,196,64` | — |
| 4 | Wave clear | "CLEAR n/5" (phone) / "WAVE n CLEAR" (desktop) gold, "next wave now", 1.0 s | — |
| 5 | Wave 5 | "WAVE 5/5" + "N adds", stroke boss color | "HOLLOW WARDEN", %, 8 px fill boss color + white ghost fill |
| 6 | Last 60 s | count → red "0:42", red stroke | unchanged |
| 7 | Boss down (death hold) | "CLEARED" gold | gold flash, fold |
| 8 | Hard | HARD chip on line 2 (phone) / before the title (desktop); bar becomes a 3 px strip on phones; boss color danger `230,80,96` | HARD chip before the name |
| 9 | Folded | 44×44 "n/5", gold stroke | not foldable |
| — | Hidden | `hud == nil` (arena off / not in a run) or `phase == "results"` | hidden |
Boss color: Normal **orange `230,120,70`** (v1 Q5, still Kevin's provisional call), Hard **danger `230,80,96`** (final). Mockup 13 draws every chip state at 108×44 and 140×44.

## 6. Copy (from #459 v1.1)
| String | Where | Source |
|---|---|---|
| "WAVE %d/%d" | chip title (caps like the other HUD chips; #459 D1 sets "Wave %d/%d" for `Hud.luau:38` `text`) | `wave`, `total` (never a literal 5) |
| "%d left" / "%d adds" | chip sub-line | `left` (Q3) |
| "CLEAR %d/%d" (phone) / "WAVE %d CLEAR" (desktop) + "next wave now" | 1.0 s flash | client, on `wave` change |
| "CLEARED" | death hold | `phase == "deathHold"` |
| "HOLLOW WARDEN" | boss bar name, caps | `boss.name` (Q3), #459 D2 |
| "%d%%" | boss bar right | `boss.ratio` |
| "0:%02d" | last 60 s | `secondsLeft` (Q7) |
| "HARD" | chip | `tier == "hard"` (Q4) |
| Toasts (lane, not the chip) | "Into the Shard Crater!" (C10), "Wave %d clear!" (D7) | existing toast lane |
Fit (DejaVu Bold stand-in, Ghost confirms with `TextService:GetTextSize`): "WAVE 5/5" 13 px ≈ 69 px in the 88 px line of a 108 px chip; "HOLLOW WARDEN" 11 px ≈ 112 px in the 192 px text room of the 212 px landscape bar; "CLEAR 2/5" ≈ 74 px fits; the desktop "WAVE 2 CLEAR" (≈ 107 px) doesn't fit the 88 px line, which is why phones use "CLEAR n/5".

## 7. Visual style
Panel `28,24,40`, `UICorner` 10, `UIStroke` 2 (row `70,60,96` / gold / boss color / danger by state); text `240,236,248`, muted `176,168,198`; bar back `54,46,78`; Builder Sans Bold 13 (title), 11 (sub, name), 10 (%). Replaces the live GothamMedium 16 label with no backing and the square `40,32,28`/`176,64,48` track. No blur, no shadows, no glow images.

## 8. Motion / VFX
| Moment | Spec | Roblox |
|---|---|---|
| Chip in / out | 0.2 s fade + 8 px slide from the top | `TweenService` on `Position` + per-element transparency |
| Kill | bar 0.15 s Quad Out; count pops `UIScale` 1 → 1.08 → 1 at ≤ 3 | `Size.X.Scale` tween; skip the tween if the value didn't change (the poll runs at 10 Hz) |
| Wave clear | gold stroke + "CLEAR n/5" 1.0 s, then a 0.2 s pulse `UIScale` 1.06 | `UIStroke.Color` tween |
| Boss bar in | 0.25 s slide + fade | `Position` tween |
| Boss hit | fill 0.15 s; white ghost fill (transparency 0.6) follows after 0.3 s | two fill `Frame`s |
| Boss down | 2 × 0.15 s gold flash, fold 0.25 s; world gold burst on the boss (`ParticleEmitter:Emit(24)`, Phase S art) | `UIStroke` tween; world `ParticleEmitter` |
| Last 60 s | red count; the stroke pulses once a second for the last 10 s | `UIStroke.Transparency` tween |
| Fold | 0.2 s `Size` tween to 44×44 | `Size` tween |

## 9. Roblox build notes
| Element | Instances |
|---|---|
| Screen | one `ScreenGui "WaveHud"` (or reuse "WaveArenaBossBar"), `DisplayOrder` 40, `ResetOnSpawn = false`, `ScreenInsets = CoreUISafeInsets`, under the results `ScreenGui` (50) |
| Rects | from `HudLayout`: chip = right end of `HudLayout.pills(vx, margin)` (portrait: the pills column top), boss bar per §4; re-fit on `ViewportSize` |
| Wave chip | `TextButton` (`AutoButtonColor = false`, panel `28,24,40`) + `UICorner` 10 + `UIStroke` 2 (`ApplyStrokeMode.Border`) + `UIPadding` 10 L/R + title `TextLabel` (BuilderSansBold 13) + count `TextLabel` (11, right) + bar back `Frame` 5 px (`UICorner` 2, `54,46,78`) with fill `Frame` + `UIScale` (press 0.96 / pulse 1.06). Tap and `ContextActionService` Tab toggle fold. |
| HARD chip | `Frame` 38×16 (phone) / 46×20 (desktop) + `UICorner` h/2 + `TextLabel` "HARD" (ink `32,22,10`) on danger fill |
| Boss bar | `Frame` (`Active = false`) + `UICorner` 10 + `UIStroke` 2 + name `TextLabel` + % `TextLabel` + back `Frame` 8 px + ghost fill `Frame` (white, transparency 0.6) + fill `Frame` with `UIGradient` (boss color → 85% brightness, Rotation 0) |
| Data | read only `hud.wave`, `hud.total`, `hud.left`, `hud.phase`, `hud.tier`, `hud.secondsLeft`, `hud.boss.{shown, ratio, name}`; fall back to state 1 when a field is nil. Never count enemies on the client. |
| Echo payload (`Hud.snapshot`, Hud.luau:35–42) | add `left = livingCount(run)` (Round.luau:94), `adds` (living `kind == "add"` on the boss wave), `tier = run.tier`, `secondsLeft = max(0, timeout − run.seconds)`, and `boss.name` from a new `WaveArenaConfig.boss.name = "Hollow Warden"`; change `text` to "Wave %d/%d" (#459 D1) |
| Pills | `HudShell` hides the pills while `hud.phase` is `fight`/`deathHold` (Q1) |
| Toast host | while `hud.boss.shown` on portrait, offset the host by one card (36 + 8) and cap it at 2 cards (Q2) |
| VFX | `ParticleEmitter` only in world space (boss burst); UI motion is `TweenService` only, no `RenderStepped` loops |
Prism doesn't edit `BossBar.luau`, `WaveArena/init.luau`, `HudShell`, `HudLayout`, `Hud.luau` or any Ghost-owned file. This is a build brief.

## 10. Mobile checks
| Viewport | Mockup | Chip | Boss bar | Keep-out | Other |
|---|---|---|---|---|---|
| 390×844 | `10-phone-390x844.svg` (A fight, B Hard boss, C folded + goals tab) | 108×44 top right | 242×36 under the HP block | clear | toast host starts at y 124 on wave 5 |
| 667×375 | `11-landscape-667x375-800x400.svg` (Normal boss) | 120×44 | 212×36 in the pills strip | clear | above the toast host; thumbstick and action cluster free |
| 800×400 | same sheet (wave 4, 3 left) | 120×44 | 348×36 | clear | — |
| 1280×720 | `12-desktop-1280x720.svg` (Hard boss) | 140×44, Tab folds | 400×44 top-center | clear | toasts stay at y 80+ |
| Live | `09-live-audit-4-sizes.svg` | — | — | clear | overlaps 2–4 HUD pieces per size |
| States | `13-states.svg` | all 9 states at 108×44 + 140×44 | — | — | — |
PNG inside an SVG wrapper, fake data shaped like the live `Hud.snapshot` plus the proposed fields. Gray-box arena.

## 11. Open questions (answer by number)
1. **@Ghost:** hide the currency pills during a run (`phase` `fight`/`deathHold`) and put the wave chip (and the landscape boss bar) in their slot? Prism recommends **yes**. It's the only top-band space that clears the HP block, the toast host and the keep-out at all 4 sizes.
2. **@Ghost:** on portrait, put the boss bar under the HP block (x 16–258, y 80–116) and start the toast host one card lower (y 124, 2 cards) while the boss is up? Prism recommends **yes**. The other option is a 108 px bar under the chip, which is a poor HP read.
3. **@Ghost (route to Echo):** add `left`, `adds`, `boss.name` ("Hollow Warden" via `WaveArenaConfig.boss.name`) and the #459 D1 "Wave %d/%d" text to `Hud.snapshot`? Prism recommends **yes**. Without `left`, the chip can only say "WAVE n/5".
4. **@Ghost (route to Echo):** add `tier` to the snapshot, but only draw the HARD chip once Hard actually scales the arena (results v1.2 Q2: today `tier` changes nothing in a run)? Prism recommends **yes**.
5. **@Kevin (taste, carried from v1 Q5, still provisional):** Normal boss HP in warm orange `230,120,70` (keeps red for Hard), or the same red on both tiers? Prism recommends **orange**.
6. **@Ghost:** show the starter goals tracker (#465) as its folded tab only during a run? Prism recommends **yes**.
7. **@Ghost (route to Echo):** show a red countdown in the chip for the last 60 s of the 480 s limit (needs `secondsLeft`)? Prism recommends **yes**, and nothing before that, so the run doesn't feel like a timer game.
8. **@Ghost:** park v1's "NEXT WAVE · 8" break state and v1's 50% phase tick (neither exists in live code), and use the 1.0 s "CLEAR n/5" flash instead? Prism recommends **yes**. Both come back with #416's break and a real boss phase.
v1.1 Q6 (portrait buff list on long-press) stays open and parked with #416.

## Decision log
- 2026-10-24 (Prism, v1–v1.2): direction A, Ghost Q1–Q4 decided, element colors folded, Hard red final; Kevin Q5 provisional. See `SPEC_v1.md`.
- 2026-10-24 (Prism, DP40P, v2): re-based on live `a28a5e2`: live audit (file:line), payload gaps (`left`, `tier`, `boss.name`, `secondsLeft`), no break and no boss phase in live code (parked), new placement in the pills slot / under the HP block / top-center that clears every live neighbour at 4 sizes, #459 names. Mockups 09–13. NOT APPROVED until copied into Vision & Design Rules.
