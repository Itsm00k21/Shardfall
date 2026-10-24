# Wave HUD ("Stack chip + boss bar"), Spec v1.2

Owner: Prism (design, docs only, no code). Builders: Ghost (client HUD), Echo (server payloads). Base: `cursor/live-build-9721`. Status: **v1.2** (element colors folded in + Hard red final, Ghost row https://app.notion.com/p/403c31ca388381919fdfd588508d2143, Oct 24, 2026, Kevin pre-approved). v1.1: **direction A chosen by Ghost** (Kevin pre-approved, Agent Board row https://app.notion.com/p/403c31ca388381089ec4e42d24ad049f, Oct 24, 2026). Ghost questions 1–4 are decided; Kevin taste call 5 stays **PROVISIONAL**. Gray-box only (pre-Phase S). Not an official Vision & Design Rules decision until Kevin approves it.
Asked for in: Ghost's Agent Board row (Kevin pre-approved) https://app.notion.com/p/403c31ca388381eeb7def55a6b3d4953, from canvas item **M6**: "Wave HUD spec (wave counter, next-wave timer, boss bar, HARD chip)". Roadmap **3.5** ("wave counter on screen"), **3.6** (boss + 4 adds on wave 5), **5.1** (8 s draft break), **5.4** (Hard).

Sources (link, don't copy):
- Locked: Roadmap Phase 3 (5 waves: 6 / 8 / 10 / 12 enemies, then boss + 4 adds on wave 5; no early exit; keep all earned loot even on a wipe). V1 Core Loop §3 (Hard ≈ 2× HP, 1.5× damage).
- Live HUD (read only, `cursor/live-build-9721`): `Shared/HudLayout.luau` (portrait 56, HP 220 or clipped on portrait, 108 px currency column, rail, toast host), `ShardfallClient/Ui.luau` lines ~595–640 (today's run label "Waves · Wave N · N left" plus a 96×44 Leave button, which the Oct 23 no-early-exit rule removes), `ShardfallClient/CombatHud.luau` (HP bar, victory card). `Shared/Rarities.luau` `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64).
- Server data: PR #417 (`echo/dungeon-wave-flow`) adds `Remotes.WaveCounter` that sends `{ wave, left }` (flag `enemyTypes`, off) and `Config/Enemies.luau` `WAVE_COUNTS = {6, 8, 10, 12}`. PR #419 (`echo/dungeon-wave5-boss`) adds the wave-5 boss + 4 adds. Nothing on the client reads the remote yet.
- Specs this must match: **#420 phone layout review rev 1.1** (full-screen px frame; center keep-out, portrait top 35% = y 296 (D1, provisional); D2 hub cluster hides under docks, the arena keeps the combat cluster; D3 one toast lane, max 1, loot/rarity outrank info; §4 "Top-left stack: live portrait + HP → a future #417 wave counter → #412 Oracle pill/goal → #416 buff strip"). **#412** first 30 seconds (wave toasts "Wave 1/5", "First kill!", "Wave 1 cleared!" go through the lane). **#414** Shard Crater (arena, loot chip through the lane). **#416** buffs pick-3 v1.1 (8 s break, buff strip, held pill). **Hard mode selector v1.1** (`prism/hard-mode-selector`, "one HARD chip on the wave counter").
- Element colors (**v1.2**): **PR #435** element color separation study (`docs/design/element-color-study/SPEC_v1.md`), variant **E3 + V3**, picked by Ghost under Kevin's handoff (row https://app.notion.com/p/403c31ca388381919fdfd588508d2143, Q4). Colors live in `Config/Elements` on PR #432 (Echo).
- Chrome: PR #392 `docs/ui/reference/STYLE.md` (panel 28,24,40 · row 40,34,58 · gold 255,196,64 · danger 230,80,96 · corners 8/10/12 · strokes 1/2 · Builder Sans).

## 0. Directions (pick one) and recommendation
Mockup: `mockups/08-directions.svg`.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Stack chip + boss bar** | One small **wave chip** in the #420 top-left stack, right under the live HP block. It changes state: fighting (WAVE 2/5 + enemies-left bar), break (NEXT WAVE + 8 s timer), boss next (BOSS IN), boss (adds left). Hard adds a HARD chip inside it. On wave 5 a **boss bar** joins: top band on landscape/desktop, in the chip's row on portrait. | One glance spot the #420 review already reserved. No new lane, no center use, toasts keep the D3 lane. The timer lives in the same chip, so the eye never moves. | The portrait boss bar is short (190 px) and the buff strip has to fold during the boss (§4). |
| B | Top-center banner | A big "WAVE 2 / 5" banner top-center with the boss bar under it. | Classic and very readable. | Portrait: no room between the HP block and the currency column; landscape: it fights the D3 toast lane in the top band. Pushes into the keep-out on 667×375. |
| C | Rail dial | A round dial on top of the mid-left rail; the boss HP becomes a ring around it. | Very compact. | Text under 13 px on phones, the rail hides in #412 Focus mode (exactly when wave 1 starts), and a ring is a poor boss HP read. |

**Recommendation: A.** It's the slot #420 already set aside, it follows D1–D3 with no new rules, and it keeps the screen center for the fight. The rest of this spec is A.

**Decided (Ghost, Oct 24, 2026, Kevin pre-approved): A.**

## 1. Goal
At any moment in a run, a player can tell in under a second which wave they're on (of 5), how many enemies are left, how long the break lasts before the next wave, whether this is Hard, and, on wave 5, how much HP the boss has left. All of this without covering the fight or a combat button.

## 2. Where it lives
- **Screen (Ghost):** the arena HUD only (never in the hub). New `WaveHud` pieces in the same ScreenGui as the live HP block (`CoreUISafeInsets`): `WaveChip` (Frame) in the #420 top-left stack, `BossBar` (Frame) shown only on wave 5, and the `HardChip` (inside both when the run is Hard). It replaces today's text run label in `Ui.luau`; the Leave button goes away with it (no early exit, Oct 23 rule). Prism doesn't edit `Ui.luau`, `HudLayout`, `CombatHud` or any Ghost-owned file; Ghost decides where the code goes.
- **Toasts:** "Wave N cleared!", "First kill!", "Boss incoming!", "Weak spot open!" use the existing D3 toast lane (info priority). The HUD adds no second toast host.
- **Server (Echo):** extend the #417 `WaveCounter` payload to a **full snapshot** (Q3, decided: yes, rejoin-safe) `{ wave, total, left, phase = "fight" | "break" | "boss", breakEndsAt, tier, bossHp, bossMax, bossPhase }`. Every send is the whole state, never a delta, and the server sends one on join. The client only displays; the server owns every number. Nothing is saved.
- **Not here:** party member list, damage numbers, minimap, timers on the whole run, any Robux or boost prompt.

## 3. Flow
| Step | Trigger | What the player sees | Server |
|---|---|---|---|
| 1 | Run starts (teleport in) | Chip fades in (0.2 s) with "WAVE 1/5" and a full cyan enemies-left bar ("6 left"). Hard runs show the HARD chip inside it. Toast lane: "Wave 1/5" (#412). | sends `{ wave 1, total 5, left 6, phase fight, tier }` |
| 2 | Enemy dies | The bar shrinks (0.15 s tween), the number ticks down. At 3 left or fewer, the number turns gold. | `left` on every kill |
| 3 | Last enemy of waves 1–3 dies | Toast "Wave N cleared!". Chip turns gold: **NEXT WAVE · 8**, the gold bar drains over the 8 s break. The #416 draft (if on) happens during this break; the chip keeps counting under it. | `phase break`, `breakEndsAt` (server time) |
| 4 | Break ends | Chip pulses once (`UIScale` 1 → 1.06 → 1, 0.2 s) and goes back to WAVE N+1/5. | `phase fight` |
| 5 | Wave 4 cleared | Chip turns red: **BOSS IN · 8**. At 3 s: toast "Boss incoming!". | `phase break`, next = boss |
| 6 | Wave 5 starts | The boss bar slides in (0.25 s): name, HP bar, a tick at the phase line (50%). The chip shows "WAVE 5/5 · 4 adds". | `phase boss`, `bossHp`, `bossMax` |
| 7 | Boss hits the phase line | The tick flashes and "phase 2" shows over it; the existing weak-spot hint toast plays in the lane. | `bossPhase 2` |
| 8 | Boss dies | Boss bar empties, flashes gold, folds (0.25 s). Chip shows "CLEARED". Then the results screen (separate spec, `prism/results-run-again`). | run end |
| — | Wipe | The chip shows "WIPED · wave N" for the death hold, then the results screen. No penalty text; all earned loot is kept. | run end |

**First run (Q2, decided):** the #412 first-run row (Oracle pill carrying "Wave 1/5") is **session-only**: it lives in memory for the current server session and needs **no save field**. The chip shows after the pill's wave-1 line ends, so the row never holds both.

Collapse: tapping the chip folds it to a 44×44 badge "2/5" (and back); the pip row under it hides while folded. The boss bar can't be folded (it's the fight's main read) but it's only up on wave 5. Desktop: Tab folds/unfolds.

## 4. Layout
Full-screen px, same frame as the #420 review (0,0 = screen top-left including the Roblox top bar). Build in `CoreUISafeInsets` by subtracting the top inset.

**Center keep-out:** 390×844 x 117–273, y 296–616 (D1, provisional) · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. Nothing in this spec enters it.

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Live HP block (Ghost, unchanged) | x 16–258, y 115–171 | x 16–300, y 68–124 | x 16–300, y 68–124 | x 16–300, y 74–130 |
| **Wave chip** | **x 16–150, y 179–223** (134×44) | **x 61–197, y 132–176** (136×44), right of the rail; right edge 197 < keep-out 200 | **x 66–222, y 132–176** (156×44) | **x 88–268, y 138–182** (180×44), above the rail top 177 is too tight, so it sits right of the rail |
| Collapsed chip | 44×44 at the chip's top-left | same | same | same |
| **Boss bar** (wave 5) | **x 16–206, y 179–223** (190×44), replaces the chip in its row; the chip's "adds left" moves into the bar's sub-line | **top band x 160–403, y 8–48** (243×40), between the Roblox buttons (`TopbarInset.Min.X + 8`) and the toast lane (411) | **top band x 200–516, y 8–48** (316×40); toast lane starts at 524 | **x 440–840, y 110–150** (400×40), under the top-center toast lane (y 66–102); keep-out top 202 |
| #416 buff strip (**v1.1, Q1 decided: under the wave counter, clear of the action bar**) | **pip row x 16–84, y 226–240** (≤ 68×14, up to 4 pips 10 px, spacing 14), 3 px under the chip and 2 px above the rail top (242); left of the toast lane (88). It stays in the same place under the boss bar on wave 5 (no fold to the right any more). Display-only on portrait (see Q6) | x 61, y 184 (8 px under the chip) | x 66, y 184 | x 88, y 190 |
| #412 goal tab / Oracle pill (first run only) | the one row y 179–223 already carries the pill; on a first run the chip is the pill's second line, see Q2 | goal tab moves to y 184, buff strip to y 236 | same as 667 | goal under the strip |
| Toast lane (D3, unchanged) | x 88–266, y 231–267 | x 411–651, y 8–44 | x 524–784, y 8–44 | x 480–800, y 66–102 |

Checks:
- **Portrait:** chip bottom 223 < pip row top 226; pip row bottom 240 < rail top 242; pip row right 84 < toast lane left 88; chip right 150 stays left of the currency column (266). The boss bar (x 16–206) keeps the pip row under it. Nothing reaches y 296, and nothing is near the action bar / skill grid (y ≥ 566) or the thumbstick.
- **667×375:** chip x 61–197 clears the rail (x 16–53) and the keep-out (x ≥ 200). Boss bar 160–403 in the top band (y < 52) doesn't touch the HP block (y 68) or the toast lane (≥ 411).
- **800×400 / desktop:** same logic, all edges outside the keep-out.
- **Combat buttons (Q1):** the buff strip / pip row sits under the wave counter on every size, so nothing in this spec is near the attack/dodge/jump cluster, the action/skill bar or the thumbstick zone. The chip is the only tappable piece (44 tall, a full 44×44 target even when collapsed); the 14 px portrait pip row is display-only, so it never needs a 44 px target.
- **Text:** chip line 1 at 13 px bold, line 2 at 11 px (badge size, R7 minimum). Boss name 13 px bold.

## 5. States
| Element | Idle (fight) | Press | Break | Boss next | Boss | Collapsed | Hard |
|---|---|---|---|---|---|---|---|
| Wave chip | panel 28,24,40 + 1 px row stroke; "WAVE n/5" text 240,236,248; cyan 120,210,255 enemies bar; "N left" muted (gold at ≤ 3) | `UIScale` 0.96, 0.08 s | 2 px gold stroke, "NEXT WAVE" + seconds in gold, gold bar drains 8 s | 2 px danger stroke, "BOSS IN" + seconds in danger | 2 px danger stroke, "WAVE 5/5", "N adds" | 44×44, "n/5" 13 px | 2 px danger stroke, HARD chip inside (all states) |
| Boss bar | — | not tappable | — | — | panel + 2 px gold stroke (Normal) / danger (Hard); HP bar 8 px, fill 230,120,70 (Normal) / danger (Hard); white tick at 50% | — | HARD chip before the name |
| HARD chip | Hard red **230,80,96** fill (final, Ghost Q5), ink 32,22,10 "HARD" 9–11 px bold, pill corners | — | — | — | — | a 4 px danger line at the top of the badge | — |
Loading: until the first payload arrives, the chip shows "WAVE –/5" with an empty bar (no spinner). Error / stale (no payload for 5 s): keep the last values, no warning text. Empty: in the hub the HUD is hidden.

**Element colors (v1.2).** The #416 buff pips and the enemy-bar pip read `Config/Elements` (Ghost Q7 on #435); the HUD never hard-codes them. Source: PR #435, variant **E3 + V3** (fixes the deutan Void-vs-Rare/Epic clash).

| Element | Fill (pip / glow) | Outline (45% to white) | Pip shape | Notes |
|---|---|---|---|---|
| Ember | **#E84814** · 232,72,20 | #F29A7E · 242,154,126 | flame | was #FF7024 on #432; now ≥ 9 ΔE00 from boss telegraph 255,120,40, gold, warn, UPGRADE in all 4 visions |
| Frost | #5CD6FF · 92,214,255 (unchanged) | #A5E8FF · 165,232,255 | crystal | — |
| Void | **#C04888** · 192,72,136 | #DC9ABE · 220,154,190 | ring | was #C45CFF (= Epic); now ≥ 18 from Epic 186,96,240, ≥ 23 from Rare |

Pip build: 10 px (buff pip) / 12 px (enemy bar, 14 px desktop), white pip art tinted with the fill + 1 px ink 32,22,10 stroke so the shape carries the read in grayscale (Ember vs Void gray ΔE 0, the pip shape is the colorblind cue; don't drop it). The pip sits 4 px left of the enemy HP bar so it never merges with the HP / Hard red **230,80,96** (Ember E3 vs that red is 5 for tritan; the gap + shape cover it). Element colors never appear on loot, rarity strokes or the HARD chip; rarity keeps `Rarities.COLOR`.

Rarity colors (`Rarities.COLOR`) aren't used by the HUD itself; loot toasts in the lane keep their rarity strokes (D3 priority 1).

## 6. Numbers
- Waves: **5** (6 / 8 / 10 / 12, then boss + 4 adds). Total and counts come from Config (`Enemies.WAVE_COUNTS`), never hard-coded in the UI.
- Break: **8 s** between waves (#416, Config). The timer reads `breakEndsAt` (server clock via `workspace:GetServerTimeNow()`), so a laggy client can't drift.
- Boss phase line: **50%** (proposal, matches the live Gnarl "phase 2" note; Config). Boss HP shown with party scaling already applied (HP × (1 + 0.3 × (players − 1))).
- Sizes: chip 134–180 × 44, collapsed 44×44, boss bar 190–400 × 40–44, HARD chip 38×16 (phone) / 46×20 (desktop), bars 6 px (chip) and 8 px (boss), corners 10 (chip, bar) and h/2 (chips, bars).
- Timings: chip in 0.2 s, bar tween 0.15 s per kill, state color change 0.2 s, break pulse 0.2 s, boss bar in/out 0.25 s (Quad Out), phase tick flash 2 × 0.15 s.
- Colors: enemies bar cyan 120,210,255; break gold 255,196,64; boss/Hard danger **230,80,96** (Hard accent **final**, Ghost Q5 on row https://app.notion.com/p/403c31ca388381919fdfd588508d2143); Normal boss HP 230,120,70; element pips Ember **#E84814** (232,72,20), Frost #5CD6FF (92,214,255), Void **#C04888** (192,72,136), from `Config/Elements` (PR #435 V3).
- Copy: "WAVE n/5" · "N left" · "NEXT WAVE" · "BOSS IN" · "N adds" · "CLEARED" · "WIPED · wave N" · "HARD" · "phase 2" · boss name from Config (gray box: "GNARL"). Toasts (lane): "Wave n/5" · "First kill!" · "Wave n cleared!" · "Boss incoming!" · "Weak spot open!".

## 7. Edge cases
- **Element colors before #432 lands:** if `Config/Elements` has no `color` (today's live build), pips show white with their shape only; no fallback hex in the UI.
- **Server authority:** the client only displays the payload. A missed event is fixed by the next one (each payload is a full snapshot, not a delta).
- **Rejoin mid-run:** the server sends a snapshot on join; the chip shows the current state at once (no replay of toasts).
- **Party:** everyone sees the same wave and boss HP; "N left" counts the whole wave, not personal kills. The anti-AFK rule (Roadmap 6.3) has no HUD in V1.
- **Draft during the break (#416):** the draft row is in the center during the pick moment; the chip stays visible and keeps counting. If the pick runs out with the break, the server's auto-pick rule applies (#416 Q3).
- **Wipe on the boss:** boss bar stays for the death hold, then folds. All earned loot is kept (Oct 23 rule); no "failed" wording.
- **Hard on a first run:** impossible (Lv 5 gate), so the chip and the #412 Focus mode never both carry Hard.
- **Notched landscape:** the chip and boss bar follow `CoreUISafeInsets`, so they move right with the side inset.
- **Performance:** 2 Frames + a few labels; updates only on payloads (no Heartbeat), one tween per change.

## 8. Mockups
SVG in repo (fake data, original art, gray-box arena). v1.1 re-rendered 01–03 with the pip row under the chip / boss bar. `mockups/01-fight-phone-390x844.svg` (Hard, wave 2/5) · `mockups/02-break-phone-390x844.svg` (8 s break, toast lane) · `mockups/03-boss-phone-390x844.svg` (Hard boss, phase 2, pips under the bar) · `mockups/04-fight-landscape-667x375.svg` (chip right of the rail, toast in the top band) · `mockups/05-boss-landscape-800x400.svg` (boss bar in the top band) · `mockups/06-desktop-1280x720.svg` (BOSS IN 5) · `mockups/07-states.svg` (every state) · `mockups/08-directions.svg` (A/B/C). The live HUD is dashed; the keep-out is the cyan dashed box. PNG renders are on the box only.

## 9. Build split
Roadmap 3.5 / 3.6. Building waits for Ghost's go and the #417 / #419 flags.
- **Echo (server):** full-snapshot `WaveCounter` payload (Q3, decided): `wave, total, left, phase, breakEndsAt, tier, bossHp, bossMax, bossPhase`; send on join, on every kill, on phase change and on boss damage (throttled to 10 Hz). Tests: snapshot after rejoin, `left` never negative, break end uses server time, Hard tier flag present.
- **Ghost (client):** `WaveChip`, `BossBar`, `HardChip`, collapse, Tab key, buff strip re-dock under the wave counter (Q1) and goal tab per §4, session-only first-run row (Q2, no save field), remove the Leave button and old run label when the flag flips, toasts through the D3 lane.
- **Prism:** copy check and a Phase S pass (boss name plate art, phase tick VFX).
- **Havoc:** kill spam (bar never goes below 0), rejoin during break, lag spike during the timer, wipe on the boss.

## 10. Pass criteria (playtest)
1. At 390×844 a tester can say the wave number and roughly how many enemies are left after a 1-second look.
2. During a break, a tester knows when the next wave starts without reading a toast.
3. On wave 5 a tester can say whether the boss is above or below half HP.
4. A Hard run is identifiable from the HUD alone.
5. Nothing enters the center keep-out at any of the 4 sizes; no combat button, thumbstick or toast lane is covered; the chip is a 44 px target.
6. No Leave / early-exit button appears anywhere in the run.

## 11. Open questions (answer by number)
1. ~~**@Ghost:** Buff strip placement?~~ **Decided (Ghost, Oct 24, 2026, Kevin pre-approved): re-dock the #416 buff strip under the wave counter, clear of the action bar.** Portrait: a 14 px pip row at x 16–84, y 226–240 (also under the boss bar on wave 5); landscape/desktop: 8 px under the chip (unchanged). See §4.
2. ~~**@Ghost:** First run row?~~ **Decided: the first-run row is session-only, no save field.** The chip shows after the Oracle pill's wave-1 line ends. See §3.
3. ~~**@Ghost:** Full-snapshot payload?~~ **Decided: yes, a full-snapshot `WaveCounter` payload (rejoin-safe).** See §2 and §9.
4. ~~**@Ghost:** Boss bar in the top band?~~ **Decided: yes, top-band boss bar** on landscape/desktop (portrait keeps it in the chip row). See §4.
5. **@Kevin (taste, PROVISIONAL):** Normal boss HP color: warm orange 230,120,70 (recommended, keeps red for Hard) or the same danger red on both tiers? The spec ships orange until Kevin says otherwise.
6. **@Ghost (new in v1.1):** On portrait the pip row is 14 px tall, so it's display-only. Recommended: the full buff list opens from a long-press (0.4 s) on the wave chip and also shows on the results screen; a normal tap keeps folding the chip. OK, or would you rather have a separate 44 px buff button?

## Decision log
- 2026-10-24 (Prism, Ghost GO row https://app.notion.com/p/403c31ca388381919fdfd588508d2143, Kevin pre-approved): **v1.2** folds element colors from the PR #435 study, variant E3 + V3: Ember #E84814, Void #C04888 (Frost unchanged), read from `Config/Elements` for the buff pips and enemy-bar pip; Hard red 230,80,96 is final (Ghost Q5). Q5 (Normal boss HP color) still Kevin's. No layout change; mockups unchanged (pips in 01–03 are gray-box). Not approved as a design rule.
- 2026-10-24 (Ghost, Kevin pre-approved, board row https://app.notion.com/p/403c31ca388381089ec4e42d24ad049f): direction **A**. Q1 = buff strip re-docks under the wave counter, clear of the action bar (portrait pip row x 16–84, y 226–240; mockups 01–03 re-rendered). Q2 = first-run row session-only, no save field. Q3 = yes, full-snapshot `WaveCounter` payload (rejoin-safe). Q4 = yes, top-band boss bar. Q5 (Kevin taste) stays PROVISIONAL. New Q6 for Ghost (portrait buff list). → v1.1.
- 2026-10-24 (Prism): v1 published. Recommends direction A (stack chip + boss bar). Five open questions (Ghost 1–4; Kevin 5). Not approved. The HARD chip uses the Hard accent that is still a PROVISIONAL Kevin taste call (Hard spec Q4).

## Later (not V1)
Per-wave timer splits, a party HP strip, boss name plates with art, wave-clear star ratings, a "best wave" marker on the chip. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox UI only. No blur or glassmorphism, no soft shadows, no web fonts (Builder Sans / GothamSSm). `ParticleEmitter` only in world space; UI motion = TweenService. The mockups are a guide and these notes win.

| Element | Instances |
|---|---|
| Wave chip | `TextButton` WaveChip (AutoButtonColor false, panel 28,24,40) + `UICorner` 10 + `UIStroke` 1–2 (row / gold / danger by state) + `UIListLayout` horizontal for [HardChip, title] + `TextLabel` title (13 px BuilderSansBold) + `TextLabel` count/seconds (right aligned) + bar `Frame` 6 px (`UICorner` h/2, dim 54,46,78) with fill `Frame` (Size X tween) + `UIScale` (press 0.96, break pulse 1.06) |
| Collapsed | same button, Size tween to 44×44, title swaps to "n/5"; Tab via `ContextActionService` |
| Boss bar | `Frame` BossBar + `UICorner` 10 + `UIStroke` 2 + `TextLabel` name + `TextLabel` sub ("WAVE 5/5" or "N adds") + HP back `Frame` 8 px + fill `Frame` with `UIGradient` (fill color → 85% brightness, Rotation 0) + tick `Frame` 2×12 at X scale 0.5; damage = Size tween 0.15 s; a trailing "ghost" fill `Frame` (white, 0.6 transparency) lags 0.3 s behind for hit feel |
| Element pips (v1.2) | `ImageLabel` (white pip art: flame / crystal / ring) with `ImageColor3` = `Config/Elements[id].color` + `UIStroke` 1 ink 32,22,10; enemy-bar pip 12×12 (14 desktop) 4 px left of the HP bar; no `UIGradient`, no glow image |
| HARD chip | `Frame` + `UICorner` h/2 + `TextLabel` "HARD" (danger fill, ink text), optional hard_chip_skull_32 `ImageLabel` |
| Motion | TweenService only, Quad Out; no RenderStepped loops; the break timer updates its label once per second from `breakEndsAt` and tweens the bar once over the remaining time |
| World VFX (Phase S) | wave start: a short `ParticleEmitter` burst at each enemy gate (gray box: none); boss phase 2: a ring `ParticleEmitter` on the boss (`LightEmission` 0.5) |
| Toasts | the existing D3 lane; no new host |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| hard_chip_skull_32 (optional, shared with the Hard spec) | 32×32 | HARD chip glyph; V1 can ship text only |
| boss_icon_gnarl_64 (Phase S) | 64×64 | optional icon before the boss name |
