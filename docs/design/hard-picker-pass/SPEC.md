# Hard Picker Pass vs Live, Spec v1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips, no Ghost-owned files). Builders: Ghost (pad/dock UI), Echo (server tier, arena multipliers, snapshot). Live base read: `cursor/live-build-9721` @ **`9feb018`** (Oct 24, 2026, PT). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP43P https://app.notion.com/p/403c31ca3883817d8f60c884c3fb20e8, item 2 ("Hard picker pass vs live"). ACK: https://app.notion.com/p/403c31ca388381248271dd5368dccc6c. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
**Branch note:** a Hard picker branch already existed (`prism/hard-mode-selector`, PR #437, spec v1.3 in `docs/design/hard-mode-selector/SPEC_v1.md`), so this pass continues on that branch instead of a new `prism/hard-picker-pass`. v1.3 stays the full design; this file is the **live-truth pass** that says what can ship now, what must wait, and what v1.3 has to change to fit the HUD zone map / PANEL_STYLE (`prism/ui-overhaul`, `docs/design/ui-overhaul/`).
Mockups: `mockups/01-hard-picker-phone-390x844.svg` (3 states), `mockups/02-hard-picker-desktop-1920x1080.svg`.

## 0. Live audit (`9feb018`): how the Normal/Hard picker renders today
**Short answer: it doesn't.** There is no client picker, no Gate dock and no HARD chip in live code. Hard exists only as server rules behind a flag that is off, and the arena ignores the tier.
| # | Finding | Evidence (file:line @ 9feb018) |
|---|---|---|
| L1 | **No client UI for difficulty.** No client file mentions `HardMode`, `hardMode`, `difficulty` or a Hard/Normal label; the `difficulty_normal`/`difficulty_hard` strings are unused. The #412 Gate dock ("Normal · 🔒 Hard · START") is not built. | `git grep` over `src/StarterPlayer` = 0 hits; Strings.luau:20, :22 |
| L2 | **The flag is off.** `hardMode = false`; `HardMode.offered("hard")` returns false, so any Hard request gets "That difficulty is closed." | LaunchGate.luau:53; HardMode.luau:83-95, :26 |
| L3 | **There is a server picker with no caller.** `DungeonService.action("difficulty", tier)` → `setDifficulty` → `HardMode.select(level, tier, userId)` stores a per-player session tier. Nothing on the client calls it. | DungeonService.luau:3283-3285, :3255-3266; HardMode.luau:171-184 |
| L4 | **The pad is a plain touch.** Stepping on an `EnterPad` part calls `enterFromPad`, which reads the session tier (default `"normal"`) via `HardMode.touch`; refusals arrive as run text. No screen UI appears on the pad. | DungeonService.luau:3334-3343, :3268-3279; HardMode.luau:97-118, :186-196 |
| L5 | **The Wave arena forces Normal.** `WaveArenaHost` sets `opts.tier = "normal"` for every enter; `Round` stores `run.tier` but no WaveArena file reads `hpMultiplier`/`damageMultiplier` (only Rootvault does). **Hard does not scale the arena** (confirms the DP40P finding). | WaveArenaHost.luau:672-676; Round.luau:640, :679-680; Rootvault.luau:21-22, :72-73 |
| L6 | **Results would pay ×2 without ×2 danger.** `RunResults` multiplies by the tier's `tokenMultiplier`, so if a Wave run were ever tagged `hard` before L5 is fixed, it would pay 2× tokens for a Normal fight. | RunResults.luau:435-440 |
| L7 | **Config already matches the Core Loop.** Hard = 2× tokens, 2× fragments, 2× HP, 1.5× dmg, Lv 5. (v1.3's "mismatch: Lv 10 / 1.5×" note is now stale.) | Economy.luau:72-80; Progression.luau:24 |
| L8 | **Unlock list promises Hard while it's closed.** `Progression.unlocked` hides `nightmare` behind `extraDifficulties` but returns `"hard"` ("Hard mode") at Lv 5 even with `hardMode` off. No caller today, so it's latent. | Progression.luau:41-52 |
| L9 | **Party tier is leader-only in live code**, unlike v1.3's decided per-player rule; no caller of `Gather.setTier`; `parties` is off and the "start" event only prints. | Party.luau:333-354 (leader check :340); PartyGatherHost.luau:254-260; LaunchGate.luau:60 |
| L10 | **Server refusal copy exists and is good:** "Hard unlocks at Lv 5." / "This party is on Hard (Lv 5)." / "That difficulty is closed." | HardMode.luau:24-26 |

## 1. Goal
When Hard is real, a Lv 5+ player picks it in one tap on the pad and reads what it costs and pays in under 2 seconds; a lower-level player sees how far away it is. **Until Hard is real, the picker promises nothing:** no Hard segment, no "2×" text, no HARD chip, no ×2 tags (Ghost's DP43P Q4/Q9 direction).

## 2. Where it lives
- **Screen (Ghost):** the #412 Gate dock, shown only while standing on the pad, in the **Z10 action-bar slot** of the HUD zone map (the action bar hides on the pad, #420 D2). The Hard card sits directly above the dock, below the center keep-out. One `ScreenGui`, `CoreUISafeInsets`, DisplayOrder 60 (Z10's rung). It uses the shared panel shell from PANEL_STYLE (one shell, no new chrome).
- **World (Ghost):** pad rim gold → danger `230,80,96` only while the run will be Hard (v1.3 §2).
- **Arena:** the HARD chip from the zone map v1.1 addendum (under the run chip), drawn only once Hard scales (Echo Q4).
- **Server (Echo, dependency only):** one "Hard is real" truth (see §5 gating), arena multipliers, per-player party tier (L9). Not specced as code here.
- **Not here:** Medium/Nightmare/Insane (parked), Robux, passes. Hard is earned by level only.

## 3. Flow (staged by what's live)
| Stage | When | What the player sees |
|---|---|---|
| **0 (today)** | `hardMode` off **or** the arena ignores tier (L2, L5) | Pad → dock rises with chevron · **"Normal"** (static chip, not a button) · START. Label "Shard Crater · Normal · starts in 12". **No Hard segment, no locked teaser, no numbers** (Q1). |
| 1 (must not ship) | flag on but L5 not fixed | Same as Stage 0. The client keys off the single "Hard is real" truth, not `hardMode` alone (Q3). |
| **2 (Hard real), Lv ≥ 5** | the "Hard is real" truth is on | Dock: chevron · Normal · Hard · START. Tap Hard → `action("difficulty","hard")` (L3); on `ok` the segment turns selected, pad rim → danger, Hard card slides in. Server refusal → segment snaps back + toast with the server text (L10). |
| 2, Lv < 5 | same | Hard segment **locked** (PANEL_STYLE locked kind: lock glyph + "Lv 5"); tapping it opens the locked card (level bar, "Tap Normal to play now"). |
| START | any | Re-check on the server as today (DungeonService.luau:2935-2944). The run chip shows HARD only if the run is Hard. |
**Collapse, not close:** on phones the card auto-collapses after 4 s back into the selected Hard segment (tap Hard to reopen). On landscape/desktop it stays while Hard is selected and collapses with the dock chevron. Walking off the pad collapses the dock to nothing.

## 4. Layout (safe-area px, zone map frame)
| Piece | 390×844 | 667×375 | 800×400 | 1920×1080 |
|---|---|---|---|---|
| Dock (Z10 slot) | x 16–374, y 738–802 (358×64) | x 174–492, y 301–361 | x 230–570, y 326–386 | x 720–1200, y 984–1048 (480×64) |
| Segments (48 tall) | chevron 44 · Normal 92 · Hard 92 · START 94 | chevron 44 · Normal 76 · Hard 76 · START 92 | chevron 44 · Normal 90 · Hard 90 · START 92 | chevron 44 · Normal 120 · Hard 120 · START 156 "START [E]" |
| Stage 0 label | x 40–350, y 700–732 (above the dock) | inside the dock, left of START | same | x 720–1200, y 950–978 |
| Hard card | **x 80–374, y 618–732** (294×114): top 618 > keep-out bottom 616 | x 500–651, y 221–361 (151×140), right of keep-out (467) | x 578–784, y 246–386 (206×140), right of keep-out (560) | **x 720–1200, y 860–972** (480×112), below keep-out (788) |
| Card rows | HARD chip 52×22 + cost line · gold pay line · 5 tiles 44×44 | chip · cost · pay · 3 tiles 44 in a `ScrollingFrame` | same, 4 tiles | left: chip, cost, pay, key hints; right: 5 tiles 48×48 + caption |
Rules: nothing enters the keep-out or `RAIL_SAFE`; the card and dock never show with Z11 (a confirm/Defeated closes them) or Z8; every tap target ≥ 44 (segments 48, tiles 44/48, chevron 44); all text **≥ 14 px** (v1.3 used 11–13 px; this pass lifts it to `MIN_TEXT_PX`, which is why the phone card grows from 104 to 114 tall and drops the tile caption line). The card `Frame` is `Active = false` so a missed tap still reaches the thumbstick; only tiles are buttons.

## 5. States
| Element | Stage 0 | Idle (Stage 2) | Selected | Locked (Lv < 5) | Busy / error |
|---|---|---|---|---|---|
| Normal | static chip, `header` fill, `divider` stroke | Secondary button | Primary fill + gold stroke 2 | — | — |
| Hard | **absent** | `52,40,48` fill, danger stroke 1 @ 0.3, text `255,176,186` | `74,28,40` fill + gold stroke 2 | PANEL_STYLE Locked: `40,40,52`, lock 16 + "Lv 5", text `166,160,186` | waiting for `ok`: `UIScale` 0.96 hold; refusal: snap to Normal + toast |
| Hard card | absent | — | danger stroke 2, 4 s bar along the bottom (phone) | 1 px muted stroke, level bar, muted numbers | — |
| Drop tiles | absent | — | rarity stroke (Epic `186,96,240`, Legendary `255,196,64`) | — | **hidden until Config has a Hard-only list** (Q7); no "coming soon" line |
| START | gold, ink text | same | same | same | "Starting…" dim |
**Gating truth (Q3):** the client shows Stage 2 only when the server says Hard is real (e.g. one replicated attribute Echo sets when `hardMode` is on **and** the arena applies the tier). `hardMode` alone is not enough because of L5/L6.

## 6. Copy
| Where | Copy |
|---|---|
| Stage 0 label | "Shard Crater · Normal · starts in %d" |
| Hard card, cost | "Enemies 2× HP · 1.5× dmg" (from `Economy.DIFFICULTIES.hard`, Economy.luau:72-80; never hard-coded) |
| Hard card, pay | "Pays 2× tokens + fragments" (gold) |
| Locked card | "Unlocks at Lv 5 · you are Lv %d" / "Tap Normal to play now" |
| Refusals | server text as-is (HardMode.luau:24-26) |
| Desktop key hints | "1 Normal · 2 Hard · E Start" |
| Unlock toast (Stage 2 only) | "Hard mode unlocked! Pick it at the Shard Gate." (v1.3; never sent while Stage 0) |

## 7. Visual style
PANEL_STYLE shell: card gradient `36,40,52 → 26,30,40`, `UICorner` 12, `UIStroke` 1 `divider 120,132,156`; Hard accent danger `230,80,96` (red is Hard-only now that the Normal boss bar is orange `230,120,70`, Ghost Q10); gold `255,206,96` for selection and pay line; START gold with ink text. Rarity colors from `Shared/Rarities.luau` for the 5 V1 tiers (Common, Uncommon, Rare, Epic, Legendary); Hard-only tiles are Epic/Legendary only. Plain HARD chip, no skull (Ghost Q11, provisional). No blur, no shadows.

## 8. Motion / feedback
Dock rise 0.26 s (`UiTheme.MOTION.open`); segment press `UIScale` 0.96 in 0.08 s; card in 0.2 s Quad Out (slide 8 px + fade), out 0.2 s; phone auto-collapse at 4 s (bar `Size` tween); pad rim color 0.3 s; refusal: segment shake 2 × 4 px in 0.16 s + toast. `TweenService` only.

## 9. Roblox build notes
- `GateDock` Frame (`UICorner` 14, `UIStroke` 1, `UIGradient` 90°) with a `UIListLayout` (horizontal, padding 8) of `TextButton`s; `UISizeConstraint` keeps segments ≥ 44×44; `UITextSizeConstraint.MinTextSize = 14` on every label.
- `HardCard` Frame sibling of the dock, `Active = false`; tiles are `ImageButton`s with `UIStroke` in the rarity color; landscape tiles in a horizontal `ScrollingFrame`.
- Tap Hard → existing server action `"difficulty"` (L3); no new remote is needed for solo. Party (L9) waits for Echo.
- Gate the whole Hard segment on the server truth (Q3), not on `LaunchGate.hardMode` read client-side.
- Prism doesn't touch GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud or RollReveal; the dock is a new view Ghost owns.

## 10. Acceptance checks
1. Stage 0 at all 4 sizes: no Hard text, no "2×", no HARD chip, no ×2 tag anywhere in the pad → run → results path.
2. Stage 2: dock and card rects as §4; nothing in the keep-out or `RAIL_SAFE`; UiAudit finds no text < 14 px and no tap target < 44 px.
3. Tap Hard at Lv 4 (spoofed or real) → server refusal toast, segment back to Normal.
4. A Wave run started on Hard shows the HARD chip **and** spawns enemies with 2× HP (Echo check, L5); results show 2× tokens only then (L6).
5. Phone card auto-collapses at 4 s and reopens on a Hard tap; landscape/desktop card stays until the chevron.
6. Mockups: `mockups/01` (390×844 Stage 0 / Stage 2 / locked), `mockups/02` (1920×1080 Stage 2).

## 11. Open questions (answer by number)
1. **@Kevin (taste):** while Hard isn't real, show **nothing** about Hard (rec) or a locked "Hard · coming soon" chip with no numbers? Prism recommends **nothing**: a teaser for a mode that doesn't exist is a promise we can't keep.
2. **@Ghost:** build the #412 Gate dock in the Z10 slot (action bar hidden on the pad) as the only picker surface? Prism recommends **yes**. It's not in live code yet (L1), and it keeps the screen center clear.
3. **@Ghost (route to Echo):** one server "Hard is real" truth (hardMode on **and** the arena applies the tier, L5) that the client reads before showing the Hard segment, HARD chip or ×2? Prism recommends **yes**.
4. **@Ghost (route to Echo):** align `Party.setTier` (leader-only, Party.luau:340) with v1.3's decided per-player pick before `parties` turns on? Prism recommends **yes**.
5. **@Ghost:** lift all picker text to 14 px (v1.3 used 11–13 px), growing the phone card to 114 tall and dropping its caption row? Prism recommends **yes** (`MIN_TEXT_PX`).
6. **@Ghost (route to Echo):** filter `"hard"` out of `Progression.unlocked` while Hard isn't real, the same way `nightmare` is filtered (L8)? Prism recommends **yes**.
7. **@Kevin (taste):** show Hard-only drop tiles only once Config has a real Hard-only list, with no "coming soon" line before that? Prism recommends **yes**.
8. **@Kevin (taste, carried):** Hard accent stays danger `230,80,96` everywhere (pad rim, segment, chip) now that the Normal boss bar is orange? Prism recommends **yes**.

## Decided (Ghost, DP51P, Oct 24, 2026 PT; Kevin pre-approved Ghost's tasks and can veto)
Source: Agent Board row DP51P https://app.notion.com/p/403c31ca38838108916bf0353aac7dc4. All 8 answered per Prism's recs. Echo gets Q3/Q4/Q6 (DP51).
| # | Decision | Owner |
|---|---|---|
| Q1 | No Hard teaser while Hard isn't real (nothing about Hard shows) | Ghost (client) |
| Q2 | The picker docks in the Z10 slot on the Gate pad (#412 dock), the only picker surface | Ghost |
| Q3 | One server "Hard is real" truth (hardMode on **and** the arena applies the tier) gates the Hard segment, HARD chip and ×2 | Echo |
| Q4 | Per-player tier: `Party.setTier` aligned with v1.3's per-player pick before `parties` turns on | Echo |
| Q5 | All picker text lifted to 14 px (phone card 114 tall, caption row dropped) | Ghost |
| Q6 | `"hard"` filtered out of `Progression.unlocked` while Hard isn't real (same as `nightmare`) | Echo |
| Q7 | Hard-only drop tiles only once Config has a real Hard-only list; no "coming soon" line | Ghost |
| Q8 | Hard accent stays danger `230,80,96` everywhere (pad rim, segment, chip) | Ghost |
Still NOT APPROVED as design rules until Kevin copies them into Vision & Design Rules.

## Decision log
- Oct 24, 2026: v1 written for DP43P (Prism), live read @ `9feb018`. Nothing decided yet. Supplements `docs/design/hard-mode-selector/SPEC_v1.md` v1.3 (PR #437).
- Oct 24, 2026: Ghost decided Q1-Q8 per Prism's recs (DP51P); "Decided" section added (Prism, docs only).
