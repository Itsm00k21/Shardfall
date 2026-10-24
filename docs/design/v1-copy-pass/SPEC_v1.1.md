# V1 Copy Pass, Spec v1.1: decisions folded, line refs re-pinned, Studio text-fit list (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builders: Ghost (UI files), Echo (server/shared strings). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP38P https://app.notion.com/p/403c31ca3883817ebb29c8c5aae16760, task 1 ("#459 v1.1 fold + Studio text-fit list for the 4 tight rows"). ACK: https://app.notion.com/p/403c31ca388381ce8fe9f8c71adb38fc. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.

**This file is a delta on [`SPEC_v1.md`](SPEC_v1.md).** Every v1 row not named here stands as written. Read v1 first.

**Source read (read only, repo wins):** `cursor/live-build-9721` @ `728421a` (merge of #457 echo/t3-guide-hardening, Oct 24, 2026). Between `1445560` and `728421a` only `SessionGuide.luau`, `OnboardingService.luau`, `RollService.luau` changed player text or line numbers. All 122 v1 refs were re-checked by script against `728421a`: 102 still match their line, 20 moved (table in §3). Measures in §4 were run with the real layout modules (`BannerFit.fit`, `ShellLayout.menuRect`) under Lune at each test viewport.

## Changelog v1 → v1.1
1. **Q1–Q4 folded as decided** (Ghost, DP38P, under Kevin's pre-approval): verb **CRACK**; guide heading **Wren**; place names **Crater Square** + **Shard Crater**; boss bar name **Hollow Warden**. Rows that depended on them (B5, B6, B8, B10, B12, B23, B30, F8, F9, F16, F26, A2, B20, C10, D12, E4, D1, D2) are now **final proposals**, not options.
2. **Q5 folded**: starter goals point only at live systems. Prism's 3 picks with file:line in §2. Replaces v1 B31, B32, B34.
3. **20 line refs re-pinned** for `728421a` (§3). SessionGuide validator pins moved: SG:379/391/394/397 → **SG:446/458/461/464**. StarterGoals pins unchanged (ST:157–161).
4. **2 new rows** from #457 (B35, B36): 122 → **124 strings**.
5. **Correction to v1 §4 (toast box):** v1 measured toasts as a 178 px × 2-line lane at 14 px. Live code shows every toast goes through `Ui.setStatus` (Ui.luau:1793) → `showBanner` (Ui.luau:320) → the **gold banner**: one line, `BuilderSansBold` 16 px, `TextWrapped = false`, `TextTruncate = AtEnd`, UIPadding 12 px left/right (Ui.luau:272–297), rect from `BannerFit.fit` (BannerFit.luau:1–25). Re-measured, **5 proposed toast lines were too long on a 390×844 phone** and are shortened in §5 (C5, C6, C7, D7, D11).
6. **Correction to v1 §4 (D3 run label):** the label is `BuilderSans` 12 px, 2 lines (28 px tall), width = menu panel − 24 padding − 56 (Ui.luau:530–540; panel from `ShellLayout.menuRect`, Ui.luau:377–381). Not 14 px / 358 px.

## 1. Goal
Close every open copy question so Ghost and Echo can paste lines without another round, and give Ghost a 15-minute Studio checklist that proves the 4 tightest rows fit at 390×844, 667×375, 800×400 and desktop.

## 2. Starter goals (Q5): 3 picks from live code
Rule from Ghost: goals point only at live systems (roll, arena waves, Bag equip, Tidecrypt boss); nothing parked. The tracker shows 3 at a time (StarterGoals.luau:46), pays the same 10 Shard Keys each (:47), order is the list order (:59–65).

| Slot | v1 / today (ST:60–64) | v1.1 final | Box check (goal, 260 px @ 14 px bold) | Live code it points at | Progress source (Echo) |
|---|---|---|---|---|---|
| 1 | `Roll 10 shards` | **`Crack 10 shards`** (keep id `rolls`) | 106/260 OK | RollService.luau:271 `data.shardRolls += 1` | unchanged: `data.shardRolls` (StarterGoalPay.luau:131) |
| 2 | `Craft your first item at the Forge` (parked `forgeCraft`, LaunchGate.luau:21) | **`Equip gear from your Bag`** (new id `equip`, goal 1) | 167/260 OK | Remotes.luau:324 `EquipItem` → InventoryService.luau:141 → Schema.luau:1406 `equipItem`. Not behind a switch (`LaunchGate.equip` :45 only gates the Phase 2 EquipSlot remotes, server/EquipService/Bind.luau:70). | derived, no new save field: 1 when `data.equipped.weapon`, `.pet`, or any `armor`/`accessories` slot is set (defaults are empty, Schema.luau:373–378) |
| 3 | `Clear Rootvault` | **`Clear wave 3 in the Shard Crater`** (new id `waves`, goal 3) | 221/260 OK | WaveArenaConfig.luau:244–250 (waves 6, 8, 10, 12, boss) | new record counter `bestWave` beside `rootvaultClears` (StarterGoalPay.luau:91). Arena keeps best wave in session only (WaveArenaConfig.luau:231), so Echo writes the max on wave clear. |
| 4 | `Reach Lv 5` | keep | 71/260 OK | Progression (`data.level`) | unchanged |
| 5 | `Join or browse a guild` (parked `guilds`, LaunchGate.luau:22) | **`Beat the Hollow Warden`** (new id `boss`, goal 1) | 158/260 OK | WaveArenaConfig.luau:135 `boss` (wave 5, :250); name Hollow Warden (Q4, D2) | new record counter `bossKills` |

- **Why wave 3, not wave 1:** wave 1 is already the Wren guide's last step (SessionGuide.luau:110–113), so a "clear wave 1" goal would pay the moment it shows. Wave 3 (10 enemies) is the next real step and sits before the boss goal.
- **Tidecrypt boss: not picked.** It is not live code: `TIDECRYPT` is `implemented = false`, `rooms = {}` (Dungeons.luau:534–543) and its gate is `sealed`, Lv 20 (Haven.luau:214–226). There is no boss to beat yet. When Tidecrypt ships, it can replace slot 5 in a later pass.
- **Arena goals while `waveArena` is off:** add `waves = "waveArena"` and `boss = "waveArena"` to `StarterGoals.PARKED` (StarterGoals.luau:69–72). `reachable()` (:74–77) then hides them until Kevin flips the arena on, so no player ever sees a goal they can't do. That is the existing pattern, not a new system.
- **Echo's edit list (one commit):** GOALS :59–65, PARKED :69–72, `Granted` type :91–97, `Counts` :144–150, `EXPECTED_GOAL` :155, `EXPECTED_TEXT` :156–162, `COUNT_KEYS` :180–187, and StarterGoalPay `GOAL_IDS` :51–57 / `blankGranted` :75–83 / `normalize` / `stateOf` / `progressOf` :129–139. Old `forge`/`rootvault`/`guild` granted flags stay readable in saves (no data loss); they just stop being in GOALS. Reward table untouched; no paid skip (:21).

## 3. Line refs re-pinned for `728421a`
Text unchanged; only the line moved (SessionGuide +19, from #457 hardening).

| Row | v1 ref (1445560) | v1.1 ref (728421a) |
|---|---|---|
| B3 / B4 / B5 / B6 / B7 | SG:42 / 44 / 50 / 51 / 52 | **SG:61 / 63 / 69 / 70 / 71** |
| B8 / B9 / B10 / B11 / B12 | SG:54 / 60 / 63 / 69 / 72 | **SG:73 / 79 / 82 / 88 / 91** |
| B13 / B14 / B15 / B16 | SG:79 / 80 / 81 / 82 | **SG:98 / 99 / 100 / 101** |
| B17 / B18 / B19 / B20 | SG:84 / 85 / 91 / 94 | **SG:103 / 104 / 110 / 113** |
| B28 | OnboardingService.luau:90 | **OnboardingService.luau:99** (same text also at :106, :127) |
| B29 | OnboardingService.luau:102 | **OnboardingService.luau:132** (same text also at :157) |
| Pins | SG:379 / 391 / 394 / 397 | **SG:446 / 458 / 461 / 464** |

New rows (from #457):

| # | Ref | Box | Current | Proposed | Check (banner, 270 px @ 16 bold) | Why |
|---|---|---|---|---|---|---|
| B35 | `SessionGuide.luau:48` (pin :502) | toast | `use your free roll` | `Crack your free shard first.` | 133 → 192/270 OK | Shown when the player taps CRACK x10 during a free-roll step (RollService.luau:497–502). Lowercase, no verb, says "roll" (Q1). Echo updates the pin at SG:502 in the same commit. |
| B36 | `RollService.luau:386` (also :396, :489, :496, :602) | toast | `Could not crack that shard.` | keep | 196/270 OK | Already uses CRACK. |

## 4. Real boxes at the 4 test viewports (measured from live layout code)
| Viewport | Banner rect `BannerFit.fit` (x, y, w × h) | Banner text width (w − 24) | Menu panel `ShellLayout.menuRect` w | D3 run label width (w − 24 − 56) |
|---|---|---|---|---|
| 390×844 portrait | 88, 308, 294 × 32 | **270 px** | 294 | **214 px** × 2 lines |
| 667×375 landscape | 308, 8, 351 × 32 | 327 px | 360 | 280 px × 2 lines |
| 800×400 landscape | 308, 8, 484 × 32 | 460 px | 360 | 280 px × 2 lines |
| 1280×720 desktop | 308, 8, 964 × 32 | 940 px | 360 | 280 px × 2 lines |

Viewport here is the safe area Roblox reports (`ScreenInsets = CoreUISafeInsets`, Ui.luau:268), so a real notched phone is a few px narrower: keep ≥ 10% slack on portrait. Text scale setting > 1 grows the banner font (`BannerFit` :8, `uiSettings.access.textScale`), so at 1.25× the portrait budget drops to ~216 px; lines over that truncate with "…" (allowed safety net, not a target).

## 5. Studio text-fit list: the 4 tight rows (Ghost)
Estimates use v1's BuilderSans glyph model; Ghost confirms each with `TextService:GetTextSize(text, size, font, Vector2.new(4000, 200))` and by eye at each viewport (Studio Device Emulator: iPhone 14 390×844, landscape phone 667×375, small landscape 800×400, desktop 1280×720).

| # | Element (file:line) | TextLabel setup today | Current → v1.1 line | Est. width now → new | 390×844 | 667×375 | 800×400 | Desktop |
|---|---|---|---|---|---|---|---|---|
| **C5** | WaveArena dev/enter error (server/WaveArena/init.luau:180) → banner (Ui.luau:272) | `BuilderSansBold` 16, `TextScaled = false`, `TextWrapped = false`, `TextTruncate = AtEnd`, size from BannerFit, 32 px tall | `The wave arena is off (LaunchGate.waveArena), so this does nothing yet.` → **`The Shard Gate is closed.`** (v1 line `…closed right now.` was 275 > 270) | 553 → **198** | OVER → OK (72 px slack) | OVER → OK | OVER → OK | OK → OK |
| **D3** | Run label (Ui.luau:605, label built at Ui.luau:530) | `BuilderSans` 12, `TextScaled = false`, `TextWrapped = true`, 2 lines (28 px), width from menuRect | `%s  ·  Wave %d  ·  %d left%s%s` (worst: `Rootvault Waves  ·  Wave 3  ·  12 left  ·  hit during the gold weak spot  ·  next in 5s`) → **`Wave %d/%d · %d left`**; tips move to the banner (D4, D5); countdown becomes D8 | 446 → **~100** (worst with name kept: 238) | 446 > 428 (2 × 214) OVER → OK | OK (tight) → OK | same as 667 | same as 667 |
| **E11** | Auto Farm status (init.client.luau:791) → banner | same as C5 | `Auto Farm is on. Wins and losses start the same run again.` → **`Auto Farm on. Runs repeat.`** (v1 line was 323 > 270); off line `Auto Farm is off.` → **`Auto Farm off.`** | 446 → **204** | OVER → OK | OVER → OK | OK → OK | OK → OK |
| **F29** | Summary tile badge (RollSummary.luau:29; drawn at RollSummaryHud.luau:181–191) | `BuilderSansBold` 10, `TextWrapped = false`, `TextTruncate = AtEnd`, box `max(28, chars × 7 + 8)` × 16 | `Auto-salvaged` → **`Salvaged`** (the HUD already swaps it at :181; v1.1 makes the source say it so RollSummary.luau:108 `Salvaged +%d Essence` and the badge agree) | 68 in a 99 box → **44 in a 64 box** | badges row `NEW` + `Salvaged` = 28 + 3 + 64 = 95 px: fits a 100 px tile; **check the 84 px tile** (RollSummaryHud nameSize branch `cell >= 84`) | OK | OK | OK |

**Pass rule for each row:** no "…" at 1.0 text scale, ≥ 10% slack at 390×844, the label does not overlap a neighbor. Screenshot each at 4 viewports into the PR thread (16 shots).
**If a row still fails in Studio:** shorten the string (Prism provides an alt within the hour); do **not** turn on `TextScaled`. If Ghost must use `TextScaled` for a one-off, pair it with `UITextSizeConstraint` `MaxTextSize = 16`, `MinTextSize = 14` (UiTheme.MIN_TEXT, UiTheme.luau:20) so text never shrinks under 14.

Other toast lines re-measured against the real 270 px banner (fixed in v1.1):

| # | v1 proposed (width) | v1.1 proposed (width) |
|---|---|---|
| C6 (WH:550, :554, :583) | `The Shard Gate is closed right now.` (275) | **`The Shard Gate is closed.`** (198) |
| C7 (WH:576, :617, WI:186) | `Could not open the Shard Gate. Try again.` (320) | **`The Shard Gate stuck. Try again.`** (252) |
| D7 (DungeonService.luau:1789) | `Wave %d clear! %s` (worst 352) | **`Wave %d clear!`** (109); the reward list moves to the results card rows E5–E9, where it already shows |
| D11 (DungeonService.luau:1858) | `Your clear did not save. Try again.` (270, zero slack) | **`Clear did not save. Try again.`** (231) |

All other toast rows in v1 fit 270 px with slack (largest: F20 `Duplicate %s became %d Shard Dust.` 264 with a short name; long names truncate, the toast still reads).

## 6. States, edge cases, mobile checks
- States unchanged from v1 §5. Starter goals: arena goals hidden while `waveArena` is off (§2); visible order stays 3 at a time.
- Format strings: D3 adds a `%d` for total waves; pass `#WaveArenaConfig.waves` (5), never a literal.
- Touch targets unchanged: every button named in this pass is in an existing ≥ 44 px control (`UiTheme.TOUCH = 44`, UiTheme.luau:23). No new panel; nothing enters the #420 center keep-out.
- No Robux, prices or offers in any line.

## 7. Roblox build notes (adds to v1)
- All strings are plain `.Text`. Keep `TextScaled = false` and fixed TextSize; the banner already handles user text scale through `BannerFit`.
- Caps buttons stay written in caps in the string. "·" (U+00B7) is the one separator.
- Studio check snippet (Ghost, Command Bar, not committed): `print(game:GetService("TextService"):GetTextSize("The Shard Gate is closed.", 16, Enum.Font.BuilderSansBold, Vector2.new(4000, 200)))` → expect X ≤ 243 (270 × 0.9).

## 8. Open questions
None left from v1 (Q1–Q5 decided). New, small:
1. **@Ghost:** D7: OK to drop the reward list from the wave-clear toast (it does not fit a phone) since the results card shows it? Prism recommends yes.
2. **@Ghost:** Slot 3 goal at wave 3 (Prism) or wave 5 (the full clear, overlaps with slot 5 boss)? Prism recommends wave 3.

## Decision log
- 2026-10-24 (Prism, v1): 122 rows from `1445560`. NOT APPROVED.
- 2026-10-24 (Ghost under Kevin's pre-approval, DP38P): Q1 CRACK, Q2 Wren heading, Q3 Crater Square / Shard Crater, Q4 Hollow Warden, Q5 goals from live systems only (Prism picks 3).
- 2026-10-24 (Prism, v1.1): folded Q1–Q5, re-pinned 20 refs and 4 validator pins to `728421a`, +2 rows (124), corrected toast box to the real banner and shortened 5 lines, added Studio text-fit list. NOT APPROVED until copied into Vision & Design Rules.
