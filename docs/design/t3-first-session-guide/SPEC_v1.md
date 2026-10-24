# T3 First-Session Guide ("Crack your first shard → the Gate"), Spec v1

Owner: Prism (design, docs only: no code, no Config, no save edits). Builders: Ghost (OnboardHud, HUD, world markers), Echo (Onboarding / OnboardingService server steps). Base: `cursor/live-build-9721`. Status: **v1.1, all 7 questions decided** by Ghost's Agent Board row https://app.notion.com/p/403c31ca388381e89200df4fe6fe8d29 (Oct 24, 2026 12:50Z, Kevin's design calls pre-approved to Ghost). Build still waits for M13. Not an official Vision & Design Rules decision until Kevin copies it there.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca3883813bb309d78b13d87259 (Oct 24, 2026 12:32Z, Kevin pre-approved). ACK: https://app.notion.com/p/403c31ca38838177ab48faab126dd578.
**Pass target:** a brand-new player reaches the Shard Gate pad in **under 2 minutes with no help**.

**How this relates to what already exists (link, don't copy):**
- **PR #412** (`prism/first-30-seconds`, `docs/design/first-30-seconds/SPEC_v1.md`, all questions closed) owns beats 0–30 s: Oracle Wren card/pill, 3 free rolls (3rd ≥ Rare), Gate Beam, Gate dock, first fight. **This spec does not restate those beats.** It adds what #412 left open: the *code mapping* onto the live `Onboarding` + `OnboardHud`, the exact copy table, skip/replay rules, the idle ladder that guarantees < 2:00, and the phone layout of the guide pieces.
- **#412 also carries `FIRST_SESSION_GUIDE_T3_v1.md`** (an earlier "Wren's Trail" 5-step draft that runs to wave 2). This file is the **T3 spec of record** Ghost asked for on its own branch. Where they differ, this wins; see Q1 for what happens to the #412 file.
- **PR #413** (`prism/town-hub`, v1.1, Crater Square): spawn (0, 30) → Crackstone (-12, 52) **25 st / 1.6 s**; Crackstone → Gate pad (0, 98) **48 st / 3.0 s**; spawn → Gate pad 68 st / 4.2 s; Gate billboard "Shard Gate · 4 s". Wren stands at (-18, 52).
- **PR #397** Roll/Reveal (tier timings 0.55 / 0.70 / 0.90 / 1.30 / 2.20 s, Skip ≥ 88×44).
- The T3 canvas (cursor.com/canvas/…/efb9d78e…) was **not readable** from this session (403); this spec follows the board row text.

**Live code read (read only, `cursor/live-build-9721`):**
- `Shared/Onboarding.luau`: `STEPS` = open, class, swing, dodge, door, haven (old cold open, replaced for V1 by #412 Q3). `goals()` skips the literal id `"open"` and builds one goal row per other step. `SHORT` feeds the pill: `"Shardfall: " .. SHORT[id]`. `starter()` pays 250 gold, 40 shard keys, 3 healing tonics (+ chests behind `LaunchGate "chests"`), sets `onboardDone = true`, `onboardStep = "haven"`.
- `OnboardingService.luau`: `note(player, eventId)` advances only when `eventId == onboardStep`; `advance()` only works on `"open"`/`"haven"` (else "Try it in the world first."); `skip()` pays the same kit and `FirstSessionKit.grant`.
- `OnboardHud.luau` (Ghost-owned, **not edited**): card `Frame` at (16, 96) **460×144**, Continue/Skip intro 140×52, chevron **28×28**, `IntroPill` "Shardfall: <step>", Goals panel (16, 248) 280×72 that folds to a **"Goals N/5"** tab on the right edge, `TEXT_BEATS = { open, haven }`, `HINTS` per world step, `coverWhen` hides it under any menu, collapse state is session-only, Skip closes on the press.
- `RollService.rollFree` + `FirstSession.CONFIG.rollFloor = "Rare"`; `Settings` (`rolls.animation`, `hud.otherVfx`, `access.textScale`).

---

## 1. Goal
In the first session, Oracle Wren gets a brand-new player from spawn to the Shard Gate pad with one instruction at a time: **"Crack your first shard."** → 3 free rolls (fast win, 3rd ≥ Rare) → **follow the arrow** → **step on the Gate**. Typical time to the pad **~15 s**; a slow, hint-following player **≤ 60 s**; the guide guarantees the pad **before 2:00** without anyone helping. Character stays visible the whole time; no new screens; no Robux.

## 2. Where it lives
- **Shared/Onboarding.luau (Echo, request):** new V1 `STEPS` list (ids below). Keep the literal first id **`"open"`** so `goals()` and `TEXT_BEATS` work unchanged; that gives exactly **5 goal rows**, so the live **"Goals N/5"** tab needs no change. (#412 called the first beat `spawn`; same beat, live id kept.)
- **OnboardingService (Echo, request):** `note(player, "roll1"|"roll2"|"roll3")` from `RollService.rollFree` on a resolved free roll; `note(player, "gate")` when the server sees the player on the Gate pad; `note(player, "wave1")` on wave 1 clear (→ `next()` = nil → `starter()` → `onboardDone`). No new save field; `onboardStep` already exists.
- **OnboardHud (Ghost, requests only; Prism doesn't edit it):** new `HINTS`/`SHORT` copy, portrait card width, 44 px chevron hit area, edge arrow + "Take me there" button. Ghost owns the file.
- **World (Ghost):** the #412 Gate Beam (character → Gate pad), ground chevrons, #413 Gate billboard. Wren NPC at (-18, 52) from #413.
- **Settings (Ghost):** a "Replay guide" button row in the existing Settings panel (client-only, §3.3). No new saved setting.
- **Not here:** paid skips, starter packs, purchase prompts, or Robux anywhere in the guide. Arena coaching after START stays in #412 (beats ~19–30 s).

## 3. Flow

### 3.1 Step list (V1 `onboardStep` ids)
| # | id | Starts when | Player does | Advances on (server) | Goal row (Goals tab) |
|---|---|---|---|---|---|
| 0 | `open` | first join, `onboardDone ~= true` | nothing (camera 0.6 s, card slides in) | auto after 0.7 s, or Continue (live text beat) | — (not a row) |
| 1 | `roll1` | card shown | tap **ROLL** (FREE ×3) | `note("roll1")` after the free roll resolves | Crack shard 1 |
| 2 | `roll2` | roll 1 revealed | tap ROLL (FREE ×2) | `note("roll2")` | Crack shard 2 |
| 3 | `roll3` | roll 2 revealed | tap ROLL (FREE ×1), **≥ Rare** | `note("roll3")` | Crack shard 3 |
| 4 | `gate` | roll 3 revealed | walk the Beam to the Gate pad (68 st / 4.2 s from spawn; 48 st / 3.0 s from the Crackstone) | `note("gate")` on the pad (server touch check) | Step on the Gate |
| 5 | `wave1` | on the pad → Gate dock → START | clear wave 1 (#412) | `note("wave1")` → `starter()` → `onboardDone = true` | Clear wave 1 |

The **pass target is met at step 4 → 5** (on the pad). Step 5 is #412's first fight; it's listed only so the Goals tab reads 5/5 at the end.

### 3.2 Timeline and idle ladder (guarantees < 2:00)
| t (s) | Beat | If the player does nothing |
|---|---|---|
| 0.0–0.7 | Fade 0.4 s, camera to the #413 spawn shot (Wren + Crackstone front-left, Gate dead ahead) | — |
| 0.7 | Wren card: **"Crack your first shard."** ROLL bar rises, badge FREE ×3, gold ring pulse | +4 s: pointer hand on ROLL · +9 s: Wren repeats "Tap ROLL below." (once) · +20 s: ROLL ring + pointer pulse again, no extra text |
| ~2–8 | Rolls 1–3 at #397 tier timings (Common 0.55 … Rare 0.90). Lines per roll (§6). 3rd roll ≥ Rare = **fast win at ~8 s** | same ladder per roll |
| ~9 | Hand-off: stage fades, Beam + chevrons + "Shard Gate · 4 s" appear. Wren: **"A Rare! Now test it at the Shard Gate."** Goal: "Step on the Gate" | +6 s no progress toward the pad: **edge arrow** if the pad is off-screen · +9 s: Wren "Follow the arrow to the Gate." (once) · **+30 s on this step: "Take me there" button** (§4) |
| ~13–15 | On the pad → #412 Gate dock (solo, 3 s countdown). Goal row 4 ✓. **Pass point.** | dock auto-starts after 3 s (#412) |

Worst case with every fallback and a player who only acts on the last hint: 0.7 + 3 × (9 + ~3) + 30 + 4.2 ≈ **71 s**, inside 2:00 with ~50 s spare. A player who walks away entirely is not failing the guide (no timer, no nag, nothing blocks).

### 3.3 Skip, collapse, replay
**Skip intro** (live behavior kept):
1. Shown on the card at steps `open`–`gate`. Hidden after START (arena).
2. One tap, closes on the press (live Ghost Clip 7). No confirm dialog. It's the secondary (dim) button, right of Continue, never where ROLL is.
3. Pays exactly what finishing pays: `Onboarding.starter()` + `FirstSessionKit.grant` + **unused free rolls as Roll Tokens** (#412). Nothing is lost by skipping.
4. After a skip: no Wren lines; the Gate Beam + billboard stay for the session as a hint (#412); the Goals tab hides.

**Collapse** (live, ≠ skip): chevron folds the card to the pill; tap the pill to open it; session memory; the guide keeps running collapsed. Any open menu hides card + pill (`coverWhen`).

**Replay** (new, client-only):
1. Settings → "Replay guide" (TextButton 44 tall). Shown only when `onboardDone == true` and the player is in Crater Square.
2. Replays the **pointing**, not the rewards: Wren card with step copy, Beam to the Crackstone ("Roll at the Crackstone"), then Beam to the Gate. **No free rolls, no kit, no `onboardStep` write, no save write.** Rolls during replay cost normal tokens and use the normal roll flow.
3. Ends on the Gate pad, on "Stop replay" (pill menu, 44 px), on leaving the hub, or on rejoin. Can be started again any time.
4. Never auto-starts.

**Rejoin mid-guide:** resume at the saved `onboardStep` with the right FREE count (#412). Never re-grant a resolved roll.

## 4. Layout
Full-screen px. Keep-out (no screen UI): 390×844 x 117–273, y 296–616 (portrait top 35%, provisional) · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. World-space Beam/billboard/chevrons may pass through.

| Piece | 390×844 portrait | 667×375 landscape | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Wren card | (16, 103) **358×112** (live is 460 wide and overflows a 390 screen: request `UDim2.new(1,-32,0,112)` on portrait) | (100, 6) 360×88 (FocusTop, right of the Roblox chat button) | (100, 6) 380×88 | (24, 24) 460×144 (live size OK) |
| Card buttons | Continue 140×44, Skip intro 100×44 (visual 84×40 ok inside a 44 hit) | 120×40 visual / 44 hit | same | live 140×52 |
| Chevron (collapse) | **44×44 hit** (live is 28×28; keep the 28 glyph inside a 44 transparent button) | 44×44 | 44×44 | 44×44 |
| Pill (collapsed card) | (16, 103) auto 200–260 × 44 | (100, 6) × 44 | same | (24, 24) 300×44 |
| Goal chip / Goals tab | chip (16, 223) 216×44 when card open; (16, 155) when collapsed; live "Goals N/5" tab on the right edge (≥ 44 tall) | live tab, right edge, y 60 | same | (24, 180) 240×44 |
| ROLL bar (steps 1–3) | bottom center (95, 700) 200×56 + FREE ×n badge | (233, 315) 200×48, between thumbstick and combat cluster | (300, 336) 200×48 | (540, 640) 200×56 |
| Edge arrow (step 4, pad off-screen) | 44×44 on the nearest safe edge, 16 px inset, y clamped 120–560 on left/right, never in the keep-out or over ROLL / thumbstick | right/left edge, y 120–260 | y 120–280 | y 150–600 |
| "Take me there" (step 4, +30 s) | pill button 160×44 directly under the goal chip: (16, 275) when collapsed → (16, 207) | under the Goals tab, right edge, 150×44 | same | under the chip |
| Toast lane ("Bag unlocked!") | D3 lane x 88–266, y 231–267 | x 411–651, y 8–44 | x 524–784, y 8–44 | x 480–800, y 66–102 |

Checks: every tap target ≥ 44 px; the card, pill and chip/tab all collapse; nothing guide-related sits in the keep-out; one instruction visible at a time (card text **or** pill, plus one goal).

## 5. States
| Element | Idle | Press | New | Done | Hidden |
|---|---|---|---|---|---|
| Wren card | bg 16,14,24, stroke gold 1 @0.5, left accent 4 px button 108,78,196, wren_64 portrait | Continue: button color → 88,62,170, `UIScale` 0.96 | slides in 0.26 s; text swap fades 0.15 s | — | menu open, during a reveal (auto-collapses to pill), after Skip |
| Pill | "Wren: <SHORT>" (Q6 decided) gold 255,214,120, stroke 108,78,196 @0.3 | 0.96 → opens card | `newDot` 230,64,78 on a new Wren line | fades at `onboardDone` | menu open |
| Goal chip | ◆ + text 13 px | folds to tab | — | ✓ ok 110,210,140 + gold stroke 1.2 s | in the arena on portrait (pill carries it, #412) |
| ROLL bar | FREE ×n badge, gold ring pulse 1.0 s loop | disabled while a roll resolves | rises 0.26 s Back Out | slides down after roll 3 | menus, steps 4–5 |
| Edge arrow | cyan 120,210,255 stroke 2, arrow rotated to the pad | tap = camera turns toward the pad (0.4 s) | fades in 0.2 s | hides when the pad is on screen | pad on screen / on the pad |
| Take me there | button 108,78,196, text "Take me there" | `Humanoid:MoveTo(pad)` (client; any stick input cancels) | fades in at +30 s | hides on the pad | not on step 4 |

## 6. Numbers and exact copy
**Timings:** fade 0.4 · camera 0.6 · card/bar slide 0.26 (`UiTheme.MOTION.open`) · collapse 0.15 · pointer at +4 s · Wren repeat at +9 s (once per step) · edge arrow at +6 s · Take me there at +30 s · goal done flash 1.2 · Gate countdown 3 (first run). Reveal timings per #397. Arrow rotation update ≤ 10/s.
**Proposed Config (Echo; Prism doesn't write Config):** `GUIDE_POINTER_IDLE = 4`, `GUIDE_REPEAT_IDLE = 9`, `GUIDE_EDGE_IDLE = 6`, `GUIDE_TAKE_ME_IDLE = 30`, `FREE_ROLLS = 3` (already in #412).

**Proposed `Onboarding.STEPS` (text = Wren line on the card, hint = goal row):**
| id | text (Wren, card) | hint (goal row) | SHORT (pill) | Continue hint (live `HINTS`) |
|---|---|---|---|---|
| open | "Crack your first shard." | "" | "Welcome" | (text beat, Continue advances) |
| roll1 | "Crack your first shard. Tap ROLL below." (desktop: "Click ROLL or press R.") | "Crack shard 1" | "Crack a shard" | "Tap ROLL at the bottom. Or press Skip intro." |
| roll2 | "Nice! Two more free shards." | "Crack shard 2" | "2 free shards left" | same |
| roll3 | "Last free shard. Make it count!" | "Crack shard 3" | "Last free shard" | same |
| gate | "A Rare! Now test it at the Shard Gate." (Epic / Legendary 3rd roll: "An Epic! …" / "A Legendary! …") | "Step on the Gate" | "Follow the arrow" | "Follow the arrow to the Gate. Or press Skip intro." |
| wave1 | "Step in. Smash the shardlings!" | "Clear wave 1" | "Clear wave 1" | "Clear wave 1 in the arena." |

Other lines: idle repeat on `gate`: "Follow the arrow to the Gate." · edge arrow label: "Shard Gate · N s" (N = walk seconds, #413 billboard style) · Take me there: "Take me there" · toast at hand-off: "Bag unlocked!" · replay: "Replay guide", "Roll at the Crackstone", "Stop replay" · errors (live): "That did not go through. Press Skip intro to start." · Rarity colors from `Shared/Rarities.luau` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64). Element colors (Ember #E84814, Frost #5CD6FF, Void #C04888) appear only on item cards in the reveal, never in guide chrome.

## 7. Edge cases
- **Roll remote fails:** ROLL re-enables; stage line "Could not roll. Try again." (#412); the step does not advance; no free roll is spent.
- **Bag full / token rules:** free tutorial rolls ignore the token check and always have room (new profile; Echo confirms with `RollConfig.batchBlock`).
- **Roll 1 better than roll 3:** roll 3 still meets the Rare floor, shows "Saved to Bag"; `gate` line uses the best tier of the 3.
- **Player walks to the Crackstone instead of tapping ROLL:** the Crackstone prompt opens the same free-roll flow (FREE count shown); no double roll.
- **Player on the pad early (before roll 3):** dock does not open; billboard says "Crack your shards first" (one line, BillboardGui) and the Beam is not shown yet. No soft-lock: Skip intro still works.
- **Arena gated off (#382 not live):** pad shows "Coming soon" (#412 §7); `note("gate")` still fires, so the pass point is still reached.
- **Menu opened mid-guide:** card/pill hide (live `coverWhen`); the step and timers pause while covered.
- **Take me there blocked by geometry:** `MoveTo` times out after 8 s → fall back to the edge arrow only. Any stick/keyboard input cancels the walk.
- **Reduced motion / `rolls.animation` = short:** no pointer bounce or ring pulse; reveal uses the short timing; idle timers unchanged.
- **Text scale (`access.textScale` > 1):** card grows in height, never in width; text wraps (TextWrapped), max 3 lines on portrait.
- **Returning players:** never see the guide (`onboardDone`). **Alt accounts:** new profile, full guide (FirstSessionKit rule).
- **Party invite during the guide:** first run stays solo (#412 Q4).

## 8. Mockups
SVG in `mockups/` (fake data, original art; PNG renders stay on the box):
- `01-roll-step-phone-390x844.svg` — step `roll1` at 0:01: Wren card (358 wide), FREE ×3 ROLL bar, pointer, Goals tab, keep-out, chevron 44.
- `02-gate-step-landscape-667x375.svg` — step `gate`, pad off-screen: edge arrow + "Shard Gate · 4 s", pill in FocusTop, "Take me there" at +30 s, Goals tab.
- `03-skip-replay-rules.svg` — step ladder with times vs. the 2:00 target, Skip / collapse / replay rules, and the 800×400 + desktop placement notes.

## 9. Build split
- **Echo (server):** V1 `Onboarding.STEPS` ids/copy (§6) behind the existing flag; `note()` calls from `rollFree` and the Gate pad check; free-roll path per #412 Q5; analytics: seconds to roll1, roll3, pad (`gate`), skip step, take-me-there used (yes/no). No new save field.
- **Ghost (UI, requests):** portrait card width and 44 px chevron hit in `OnboardHud`; `HINTS`/SHORT copy; edge arrow + Take me there; "Replay guide" row in Settings (client-only); hide ROLL bar after roll 3. Ghost owns `OnboardHud`, `HudLayout`, `RollReveal`.
- **Prism:** wren_64 portrait, arrow_64, chevron_ground_128 in the Phase S art pass (shared with #412); copy check after build.
- **Havoc:** fresh account timing at 390×844, 667×375, 800×400, desktop; Skip at every step; rejoin at every step; arena off; menu open at each step; Take me there into a wall.

## 10. Pass criteria (playtest)
1. **Fresh account, no help, 390×844 phone: on the Gate pad in under 2:00** (target ≤ 30 s median of 3 testers; hard fail ≥ 120 s).
2. 3 free rolls happen with the 3rd ≥ Rare, and the first roll starts within 5 s of spawn.
3. A tester who ignores the ROLL bar and wanders still reaches the pad before 2:00 using only the on-screen hints (pointer, edge arrow, Take me there).
4. Only one Wren instruction is on screen at a time; nothing guide-related enters the center keep-out at any of the 4 sizes.
5. Every guide tap target is ≥ 44 px (including the chevron); card, pill and goals collapse.
6. Skip intro at any step pays the same kit + unused rolls as tokens; Replay guide grants nothing and writes nothing to the save (save diff check).
7. No Robux or purchase prompt appears before the pad.

## 11. Open questions (answer by number)
All 7 are **Decided (Ghost 12:50Z)**, Ghost's Agent Board row https://app.notion.com/p/403c31ca388381e89200df4fe6fe8d29 (Oct 24, 2026 12:50Z, Kevin's design calls pre-approved to Ghost). Build still waits for M13.
1. ~~Supersede #412's T3 draft?~~ **Decided (Ghost 12:50Z): yes.** This file is the T3 spec of record; `FIRST_SESSION_GUIDE_T3_v1.md` on #412 gets a "Superseded by #449" note at the top. Nothing is deleted; its steps 4–5 (buff pick, wave 2) move to Later.
2. ~~Keep the live id `"open"`?~~ **Decided (Ghost 12:50Z): keep `open`.** `goals()` and the "Goals N/5" tab stay unchanged.
3. ~~ROLL bar at spawn?~~ **Decided (Ghost 12:50Z): yes.** The 3 free rolls run from the ROLL bar at spawn; the Crackstone prompt stays a second way in (same free-roll flow, no double roll).
4. ~~"Take me there" at +30 s?~~ **Decided (Ghost 12:50Z): yes.** Client `MoveTo`, any input cancels, 8 s timeout falls back to the edge arrow (§7).
5. ~~Server `note("gate")`?~~ **Decided (Ghost 12:50Z): yes.** The server checks the pad (touch check); the client arrow and Beam are cosmetic only and can't advance the step.
6. ~~Pill prefix?~~ **Decided (Ghost 12:50Z, Kevin's call pre-approved to Ghost): "Wren:" pill.** SHORT copy reads "Wren: Crack a shard", "Wren: Follow the arrow", etc. (§6 SHORT column gets the "Wren: " prefix instead of "Shardfall: ").
7. ~~Replay guide in V1?~~ **Decided (Ghost 12:50Z, Kevin's call pre-approved to Ghost): ships in V1, grants nothing.** Points only (§3.3): no free rolls, no kit, no `onboardStep` or save write.

No open questions remain on this spec.

## Decision log
- 2026-10-24 (Ghost 12:50Z, board row https://app.notion.com/p/403c31ca388381e89200df4fe6fe8d29, Kevin's calls pre-approved to Ghost): **v1.1.** Q1 yes (#449 supersedes #412's T3 file; note added on #412, nothing deleted). Q2 keep `open`. Q3 ROLL bar at spawn. Q4 Take me there at +30 s. Q5 server checks the pad, client arrow cosmetic. Q6 "Wren:" pill. Q7 Replay guide ships in V1, grants nothing. Build waits for M13.
- 2026-10-24 (Prism): v1 on `prism/t3-first-session-guide`, built on #412 (beats 0–30 s) and #413 (walk times). Ends at the Gate pad (pass point). Open: Ghost 1–5, Kevin 6–7. Not approved.

## Later (not V1)
Wren walking with the player (#412 T3 direction B), voice lines, a second-session "welcome back" line, set-bonus tip once 2 items share an element. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox only: Frames, ImageLabels, TextLabels/TextButtons/ImageButtons, `UICorner`, `UIStroke`, `UIGradient`, `UIListLayout`, `UIPadding`, `UIScale`, TweenService, world `Beam` / `BillboardGui` / `ParticleEmitter` / `Decal`. No blur, no drop shadows, no web fonts. Mockups are a guide; these notes win.

| Element | Instances |
|---|---|
| Wren card | live card `Frame` + `UICorner` 10 + `UIStroke` gold 1 (Transparency 0.5) + 4 px accent `Frame` + wren_64 `ImageLabel` in a circle `Frame` (`UICorner` 0.5 scale, `UIStroke` cyan 1.5) + title/body `TextLabel` (BuilderSansBold 15 / BuilderSans 14, TextWrapped) + Continue / Skip intro `TextButton` (`UICorner` 8) + chevron `TextButton` 44×44 transparent with a 28 glyph child |
| Pill | live `IntroPill` `TextButton` (`UICorner` 0.5 scale, `UIStroke` 1 @0.3, `UIPadding` 12) + `newDot` `Frame` 12×12 |
| ROLL bar | `TextButton` 200×56 (BuilderSansExtraBold 20) + `UICorner` 12 + `UIStroke` gold 2 + `UIGradient` (255,214,120 → 255,170,40, Rotation 90) + FREE badge `Frame` (`UICorner` h/2) + ring `ImageLabel` ring_96 with a looping Size/ImageTransparency tween 1.0 s |
| Pointer | `ImageLabel` hand_48, Position tween ±6 px, 0.5 s, Reverses, RepeatCount -1 |
| Gate path | #412 `Beam` (Attachment0 HumanoidRootPart → Attachment1 Gate pad, arrow_strip, TextureSpeed 1, Width 1.2, FaceCamera) + chevron `Decal`s on flat parts every ~6 studs |
| Gate billboard | `BillboardGui` (MaxDistance 96, AlwaysOnTop false) + `TextLabel` 18 px "Shard Gate · 4 s" |
| Edge arrow | `ImageButton` 44×44 (`UICorner` 0.5 scale, `UIStroke` cyan 2) + arrow_64 `ImageLabel` Rotation from `Camera:WorldToViewportPoint(pad)`; clamp per §4; 0.1 s update loop (not RenderStepped) |
| Take me there | `TextButton` 160×44, `UICorner` 0.5 scale, `UIStroke` gold 1; client `Humanoid:MoveTo(pad.Position)` with `MoveToFinished` 8 s timeout |
| Rare burst (roll 3) | #412 world `ParticleEmitter` `:Emit(24)` in the tier color, Lifetime 0.6–0.9 |

Image assets (PNG, transparent, shared with #412): wren_64 64×64 · arrow_64 64×64 · arrow_strip 256×64 · chevron_ground_128 128×128 · ring_96 96×96 · hand_48 48×48.
