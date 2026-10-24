# Starter Goals Tracker, Visual Spec v1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builders: Ghost (client: `StarterGoalHud.luau`, `init.client.luau`; Prism does not edit them), Echo (rules: `StarterGoals.luau`, `StarterGoalPay.luau`, the edit list in #459 v1.1 §2). Base: `cursor/live-build-9721`. Refs read at **`bcef573`**, and the branch is cut from **`a28a5e2`** (#462 + #448 merged after `bcef573`; neither touched any file cited here). The brief said `728421a`. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP39P https://app.notion.com/p/403c31ca38838185b713c8b940061349, task 2. ACK: https://app.notion.com/p/403c31ca388381adaefad6af1360711a. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.

**Sources (link, don't copy):** goal picks and copy are #459 `prism/v1-copy-pass` SPEC_v1.1 §2 (`f564ef3`), with Ghost's DP39P decisions: Q2 the slot-3 goal is **wave 3** (yes), and Havoc confirmed the v1.1 picks with no change. Layout frame and keep-out come from #420. Chrome is #392 STYLE.md. The Wren guide's "Goals N/5" tab is #449. Code read (read only) at `bcef573`:
- Rules: `src/ReplicatedStorage/Shared/StarterGoals.luau` (ST): `CONFIG.visible = 3`, `shardKeys = 10` (ST:45–49), `GOALS` (ST:59–65), `PARKED` (ST:69–72), `reachable()` (ST:74–77), window (`windowIds`, ST:457–470: first 3 not granted **and** reachable; none for `returning`).
- Client: `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau` (SGH): 3 `TextLabel` rows, 18 px, BuilderSans 14, frame `16,14,24` with `UICorner` 8, no header, `Active = false` (SGH:486–520). Rect from `place()` (SGH:361–396), with the fallback under the HP bar (SGH:242–358). Painted by `presentStarterGoals` (init.client.luau:434–445).
- Layout neighbours: `HudLayout.health`, `pills`, `toastHost`, `equipPrompt`, `railFit`, `actionCluster`, `onboard` (HudLayout.luau). The live rects below came from running those functions and `StarterGoalHud.place` in a lune scratch script (the same loader as `tests/StarterGoalHud.spec.luau`). Nothing was committed from that run.

**Headline finding:** the live tracker is a plain 3-line text box with no counter and no fold. At **390×844 it sits inside the center keep-out** (x 88–374, y 354–416 vs keep-out x 117–273, y 296–616). At **667×375 it squeezes to 47 px wide** (x 68–115, y 212–274), which cuts every row to one glyph. 800×400 (x 88–408, y 308–370) and 1280×720 (x 88–408, y 80–142) are clear. This spec gives Ghost a tracker that reads at all 4 sizes, folds, and carries the "Goals N/5" counter.

## 1. Goal
After the Wren guide, a new player always knows their next 3 things to do and how close each one is, in one glance and without opening a menu. Every goal they see can be done in the live game (no parked systems), each pays 10 Shard Keys, and the tracker never covers the hero or the center of the fight.

## 2. Where it lives
| Piece | Live today (`bcef573`) | Target |
|---|---|---|
| Module | `StarterGoalHud` on `ShardfallHud` / `Chrome` (SGH:463–520) | same module and same `present(result)` / `applyChrome(settings)` API. Ghost restyles it, with no new ScreenGui |
| Goal list | rolls, forge, rootvault, level, guild (ST:59–65); forge + guild parked (ST:69–72) | #459 v1.1: **rolls, equip, waves, level, boss** (Echo's one-commit edit list, #459 v1.1 §2) |
| Shown | first 3 not granted and reachable | unchanged (rule stays in ST, the client never counts) |
| Counter | none on this tracker (OnboardHud's "Goals %d/%d" is the Wren guide list, OnboardHud.luau:492/496) | **GOALS N/T** header on this tracker (§5 for N and T) |
| Data | `profile.starterGoalTracker` (init.client.luau:438) | same, plus `done` and `total` on the show result (Echo, §9) |
| Not here | — | no paid skip (ST:21, `SKIP_KEYS` ST:173–178), no Robux, no timers, no daily goals |

## 3. Flow
| Step | What the player sees | Data |
|---|---|---|
| 0 Wren guide running | tracker hidden (the onboarding card and its own Goals tab own that space) | onboarding active |
| 1 Guide ends | tracker slides in, unfolded, 0.25 s from the screen edge it is anchored to | first show result |
| 2 Play | each row: icon, goal line, a 5 px progress bar, "p/g" on the right | `goals[i].progress`, `.goal` |
| 3 Goal met | row icon → check, bar turns ok-green, row stroke flashes gold | `goals[i].met` |
| 4 Granted | "+10 Shard Keys" chip on the bar line for 1.2 s, 6 key sparkles, then the row slides out left (0.25 s) and the next goal slides in from below; the counter pops (`UIScale` 1 → 1.12 → 1) | grant result `payout`, next show result |
| 5 Fold | tap the header (44 px) → folds into a 108×44 **GOALS N/T ›** tab; tap again to unfold. The choice is kept for the session | client only |
| 6 Toast / equip prompt | while a toast or the Equip/Keep prompt is showing, an unfolded tracker auto-folds to its tab and comes back 1 s after the lane is clear (both sit in the toast-host lane, §4) | `ToastQueue`, equip prompt visible |
| 7 Arena off → on | while `waveArena` is off, the wave + boss goals are **PARKED** and never shown; when Kevin flips the arena on, the next show result just includes them (no animation beyond step 4's slide-in) | `StarterGoals.PARKED` (§5) |
| 8 All done | "GOALS 5/5 · All starter goals done!" for 4 s, then the tracker hides for good | all granted |
| Returning player | never shown (`state.returning`, ST:459–461) | — |

## 4. Layout
Keep-out from #420: 390×844 x 117–273, y 296–616 · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. Margin 16 (`UiTheme.safeMargin`).
| Viewport | Live rect (measured) | Target unfolded | Folded tab | Clear of |
|---|---|---|---|---|
| 390×844 | x 88–374, y 354–416, **in keep-out** | **x 88–374, y 136–292** (286×156, 3 rows × 34) | x 266–374, y 136–180 | pills (y ≤ 128), rail (x ≤ 80), keep-out (y ≥ 296) |
| 667×375 | x 68–115, y 212–274, **47 px wide** | **x 471–651, y 82–226** (180×144, 3 rows × 30, short labels) | x 543–651, y 82–126 | pills (y ≤ 80), keep-out (x ≤ 467), action cluster (y ≥ 227) |
| 800×400 | x 88–408, y 308–370 | **x 68–236, y 82–226** (168×144, short labels) | x 68–176, y 82–126 | rail (x ≤ 60), keep-out (x ≥ 240); the right side is the action cluster from y 164 |
| 1280×720 | x 88–408, y 80–142 | **x 964–1264, y 96–252** (300×156) | x 1156–1264, y 96–140 | pills (y ≤ 88), toast host (x ≤ 850), keep-out (x ≤ 896) |
- The panel shrinks with the row count: header 44 + rows + 6 px padding at the bottom (1 row = 84 px portrait).
- The toast host and Equip prompt share the top-center lane on phones (390×844 toast x 98–258, y 80–204 and prompt y 212–300; 667×375 toast x 123–543; 800×400 toast x 190–610), so the unfolded panel overlaps that lane on phones. That's why step 6 auto-folds. The folded 108×44 tab is clear of the lane at all 4 sizes (390×844 it lines up with the pills column, x 266–374).
- Desktop matches `HudLayout.onboard().tracker`'s right-hand slot (x 1024, y 96, 240 wide), widened to 300 so full lines fit.
- Touch: the header row / tab is the only tap target, **≥ 44 px** tall (portrait header 286×44, tab 108×44). Rows are display only (`Active = false`, as today).

## 5. States
| State | Look |
|---|---|
| Row: in progress | gold `255,196,64` ◆ icon, line in text `240,236,248`, bar fill gold on row `40,34,58`, "p/g" gold 11 px bold |
| Row: met (waiting for grant) | ✓ icon, bar + "g/g" in ok `110,210,140` |
| Row: granting | 2 px gold `UIStroke` on the row, warm fill `60,50,30`, "+10 Shard Keys" gold chip replaces "p/g" for 1.2 s |
| Header | "GOALS N/T" gold BuilderSansBold 14 + muted "10 Shard Keys each" (portrait/desktop only) + 44 px fold chevron ‹ |
| Folded | 108×44 tab, gold 2 px stroke, "GOALS N/T ›" |
| Parked goals | **not drawn at all** while their switch is off: proposed `PARKED` = `{ forge = "forgeCraft", guild = "guilds", waves = "waveArena", boss = "waveArena" }` (#459 v1.1 §2). With the arena off, a fresh save shows rolls, equip, level (mockup 04 A). With it on, it shows rolls, equip, waves (04 B) |
| Counter N/T | **N** = granted goals among the reachable ones. **T** = reachable goals: **0/3 while `waveArena` is off, 0/5 when on** (Prism recommendation, Q1). A fixed /5 would leave a player stuck at "3/5" with nothing left to do |
| 1–2 rows left | panel shrinks (04 C) |
| All done | 60 px card "GOALS 5/5 · All starter goals done!" with gold stroke for 4 s, then hidden for good (04 D) |
| HUD hidden setting | hidden (`uiSettings.hud.hidden`, SGH:154–180, unchanged) |
| Bigger text (`access.textScale`) | rows grow (`lineHeight`, SGH:145–151); the panel grows down. At 390×844, 1.25× text (rows +4 px each, as `lineHeight` does today) pushes the bottom to about y 304, past the keep-out top (296), so **at textScale > 1 on portrait the tracker starts folded** |

## 6. Copy
Goal lines are #459 v1.1 §2 (Echo owns the strings and pins). Landscape phones use a client-side short label per goal id because the 168–180 px panels leave 126–136 px for text:
| id | Full line (portrait, desktop) | Short line (667×375, 800×400) | Width at 14 px (#459 estimator) |
|---|---|---|---|
| rolls | Crack 10 shards | Crack 10 shards | 106 |
| equip | Equip gear from your Bag | Equip from Bag | 167 → 100 |
| waves | Clear wave 3 in the Shard Crater | Clear wave 3 | 221 → 84 |
| level | Reach Lv 5 | Reach Lv 5 | 71 |
| boss | Beat the Hollow Warden | Beat the Warden | 158 → 108 |
Text room: portrait 242 px, desktop 256 px (full lines fit, longest 221). Landscape 126–136 px (short lines fit, longest 108). Other strings: header "GOALS N/T", sub-line "10 Shard Keys each", chip "+10 Shard Keys", done line "All starter goals done!". The `TextTruncate = AtEnd` safety net stays (SGH:513).

## 7. Visual style
Panel `28,24,40` with `UICorner` 12 and `UIStroke` 2 `70,60,96`; header strip `36,30,52`; rows on the panel with bars on row `40,34,58`; gold `255,196,64` for progress and the counter; ok `110,210,140` for met; key sparkle `255,214,110`. BuilderSans 14 for rows (as live), BuilderSansBold 14 for the header, 11 for "p/g". Replaces the live `16,14,24` box (SGH:488). No blur, no shadows.

## 8. Motion / VFX
| Moment | Spec | Roblox |
|---|---|---|
| Slide in | 0.25 s Quad Out from the anchored edge | tween `Position` |
| Bar fill | 0.3 s to the new value | tween inner `Frame` `Size.X.Scale` |
| Met | stroke flash 2 × 0.2 s | `UIStroke.Transparency` tween |
| Grant chip | in 0.15 s, hold 1.2 s, out 0.15 s | `TextLabel` + `UIScale` |
| Key sparkles | 6 small key-shape `ImageLabel`s burst out 14 px and fade in 0.5 s (UI). A world `ParticleEmitter` `Emit(8)` on the character is optional, off on low graphics | `ImageLabel` tweens. `ParticleEmitter` in an `Attachment` |
| Row swap | out left 0.25 s, next in from below 0.25 s | tween `Position` + `GroupTransparency` (`CanvasGroup` per row, or per-element transparency) |
| Counter pop | `UIScale` 1 → 1.12 → 1, 0.2 s | `UIScale` tween |
| Fold / unfold | 0.2 s `Size` tween to the tab | tween `Size` |
The whole grant moment is ≤ 1.9 s, and a second grant queues behind it.

## 9. Roblox build notes
| Element | Instances |
|---|---|
| Panel | `Frame` + `UICorner` 12 + `UIStroke` 2 (`ApplyStrokeMode.Border`) + `UIPadding` 12 L/R; rect from `StarterGoalHud.place` (a new branch per breakpoint, §4) |
| Header | `TextButton` (full width × 44, `AutoButtonColor = false`) with a `TextLabel` "GOALS N/T", a muted sub-label and a 44×44 chevron `ImageLabel`; the tap toggles fold |
| Rows | `Frame` per row (34 px portrait/desktop, 30 px landscape): icon `TextLabel` or `ImageLabel` 12 px, line `TextLabel` 14 px, bar `Frame` 5 px + `UICorner` 2 + inner fill `Frame`, "p/g" `TextLabel` 11 px right-aligned |
| Tab | the same header `TextButton` at 108×44 with the panel body `Visible = false` |
| Short labels | client table `SHORT = { rolls = …, equip = …, waves = …, level = …, boss = … }` in `StarterGoalHud`, used when `HudLayout.breakpoint` is `phone` and the width is ≥ 500; unknown ids fall back to `text` |
| Counter data | **Echo:** add `done` (granted among reachable) and `total` (reachable count) to the show result in `StarterGoalPay`, so the client never counts (SGH header says "This module does not count") |
| Repaint key | **Ghost/Echo:** `starterGoalKey` hashes only `forge, rootvault, rolls, level, guild` granted flags (init.client.luau:426–430). Add `equip, waves, boss` in the same commit as the GOALS edit, or a new grant won't repaint |
| Parked | **Echo:** `PARKED` gets `waves = "waveArena"`, `boss = "waveArena"` (ST:69–72); `reachable()` and `windowIds` already do the rest |
| Fold state | session-only client boolean; no save field, no `uiSettings` change |
Prism does not edit `StarterGoalHud.luau`, `init.client.luau`, `HudLayout` or any Ghost-owned UI file; this is a build brief.

## 10. Mobile checks
- 390×844: unfolded y 136–292, clear of the keep-out (296) and pills; header 286×44, tab 108×44. Auto-folds for toasts and the equip prompt (mockup 01).
- 667×375: unfolded 180×144 in the right column, clear of pills (80) and the action cluster (227); short labels (mockup 02).
- 800×400: unfolded 168×144 in the left column, between the rail (60) and the keep-out (240); short labels (mockup 02).
- 1280×720: unfolded 300×156 top right, full lines (mockup 03, grant moment).
- Live failures fixed: 390×844 keep-out overlap, 667×375 47 px squeeze.
- Text-fit: §6 table. Ghost confirms with `TextService:GetTextSize` in Studio, the same as #459 v1.1 §5.
- Mockups (PNG inside SVG, fake data): `mockups/01-portrait-390x844.svg` (live vs target, folded with a toast), `02-landscape-667x375-800x400.svg`, `03-desktop-1280x720-grant.svg`, `04-states-sheet.svg` (parked off/on, 4/5, 5/5).

## 11. Open questions (answer by number)
1. **@Ghost:** counter T = reachable goals (**GOALS 0/3** while the arena is off, **0/5** when on), or a fixed **/5** as the brief says? Prism recommends **reachable**, so nobody sits at "3/5" with nothing they can do.
2. **@Ghost:** auto-fold the unfolded tracker while a toast or the Equip/Keep prompt is up (phones), so it can sit in the top lane without a bigger move? Prism recommends **yes**.
3. **@Ghost:** client short labels on landscape phones (§6), with "Beat the Warden" for the boss goal? Prism recommends **yes**; the full "Hollow Warden" name stays on portrait, desktop and the boss bar.
4. **@Kevin (taste):** should the tracker show **"10 Shard Keys each"** under the counter (a visible reason to play the goals), or stay quiet and only show the "+10 Shard Keys" chip when one pays? Prism recommends showing it on portrait and desktop.

## Decision log
- 2026-10-24 (Ghost under Kevin's pre-approval, DP38P/DP39P): goals from live systems only (#459 Q5), slot 3 at wave 3 (#459 v1.1 Q2 yes); Havoc confirmed the picks.
- 2026-10-24 (Prism, DP39P task 2): v1 tracker visual: live rects measured at `bcef573` (keep-out overlap at 390×844, 47 px squeeze at 667×375), target rects at 4 sizes, fold tab, counter rule, parked-hide rule, grant moment, 4 mockups. NOT APPROVED until copied into Vision & Design Rules.
