# Results Card Visual Pass: live `ResultsCard` vs #429 "Results wings", Spec v1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (client UI; `ResultsCard.luau` is Ghost-owned, Prism does not edit it). Echo: FYI (server payload already there). Base: `cursor/live-build-9721` @ `728421a`. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP38P https://app.notion.com/p/403c31ca3883817ebb29c8c5aae16760, task 3 ("results card visual pass vs live ResultsCard"). ACK: https://app.notion.com/p/403c31ca388381ce8fe9f8c71adb38fc. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.

**Sources (link, don't copy):** PR #429 `prism/results-run-again` @ `5b77004` (`SPEC_v1.md` v1.3 = direction A "Results wings", `M12_BUILD_CHECK_v1.4.md`, `TOKEN_FLYIN_v1.2.md`, mockups 01–12). Copy: #459 V1 copy pass v1.1 (CRACK verb, Shard Crater, Hollow Warden). Layout frame and keep-out: #420. Chrome: #392 STYLE.md. Code read (read only) at `728421a`:
- Client card: `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/WaveArena/ResultsCard.luau` (RC), mounted from `WaveArena/init.luau:44`.
- Server card: `src/server/WaveArena/Round.luau:113–135` (`cardOf`), filled by `src/ReplicatedStorage/Shared/RunResults.luau` (RR) when `LaunchGate.m12Results` is on (`LaunchGate.luau:58`, off today).
- Run Again: `WaveArenaHost.luau:590` (`action == "again"` → `RunResults.again`, RR:423). Boss pay: `BossClearReward.card` (`BossClearReward.luau:155–169`). Timings: `WaveArenaConfig.results` (`WaveArenaConfig.luau:232–242`: autoReturn 30, soloCountdown 3, runAgainGap 1, lootNames).

**Headline finding:** the server side of #429 is built. With `m12Results` on, the card already carries `bestWave`, `newBest`, `tier`, `total`, `kills`, `seconds`, `outcome`, `multiplier`, `rollsReady`, `xp`, `levelAfter`, `xpFrac`, `bossClear`, `returnAt` and `loot.items = {id, name, tier, count, hardOnly}` (RR:350–366, RR:370–393), and Run Again has a server action. **The client card reads none of it.** It is still the #382 text box: 280×180 at the screen center, one `TextLabel`, raw ids. This pass is the gap list Ghost needs to build `ResultsWings` to #429 without another design round.

## 1. Goal
When the Shard Crater run ends (clear, wipe or time-out), a phone player knows in about 3 seconds how far they got, what they earned and whether they beat their session best, and is one tap from **RUN AGAIN** or **CRACK**. The center stays clear, so the hero's win pose shows. Every number on screen comes from the server card; the UI grants nothing.

## 2. Where it lives
| Piece | Live today (728421a) | Pass target |
|---|---|---|
| Screen | `ScreenGui "WaveArenaResults"`, DisplayOrder 50 (RC:58–63) | new `ResultsWings` module beside `ResultsCard` in `ShardfallClient/WaveArena/`, same `apply(playerGui, hud)` hook (RC:89–103), called from `WaveArena/init.luau:44` |
| Frame | `Frame "Card"` 280×180, AnchorPoint (0.5, 0.5), Position scale (0.5, 0.55) (RC:64–71) | two wings per #429 §4 (stats wing + loot/actions wing), anchored to the screen edges |
| Data | `hud.card` (Round.luau:113–135) | same `hud.card`, plus the m12 fields (RR:370–393) |
| Flag | card shows whenever `waveArena` is on | `ResultsWings` draws only when `m12Results` is on **and** the card has `outcome`; otherwise the old card stays (RR:6–7 "Off: the arena card stays as it is"). **Delete nothing** (#429 Q4). `ResultsCard.lines()` stays as the text fallback and test helper. |
| Not here | — | no paid revive, "double loot", share card, leaderboards, chests, Robux |

## 3. Flow
| Step | Live today | Pass target (from #429 §3 + v1.4) | Data it reads |
|---|---|---|---|
| 0 Death hold | card is nil until the hold ends, so nothing shows (RC:4–5) | same; wave chip shows CLEARED / WIPED in the gap (`boss.deathHold` 1.5 s) | `hud.card == nil` |
| 1 Card arrives | `gui.Enabled = true` instantly (RC:102) | live HUD fades 0.2 s, wings slide in 0.3 s Quad Out from top/bottom (portrait) or left/right (landscape/desktop) | `hud.card` first non-nil |
| 2 Count-up | none | Roll Tokens and Fragments count up 0.6 s; loot tiles pop in Legendary → Common, 0.05 s apart; NEW BEST badge if `newBest` | `loot.tokens`, `loot.fragments`, `loot.items`, `newBest` |
| 2b Boss pay | none | if `bossClear.granted`: 5-token fly-in to **CRACK** + "BOSS +5" chip (TOKEN_FLYIN_v1.2) | `bossClear.tokens` |
| 3 Tap a tile | — | caption "<name> · <tier>" (+ "· Hard only"); gold 3 px stroke; no popup | `loot.items[i]` |
| 4 RUN AGAIN | no button | solo: "Starting… 3" + Cancel, then server `again` (WaveArenaHost.luau:590); party: back to the Shard Gate pad (#429 Q1) | `WaveArenaConfig.results.soloCountdown` 3 |
| 5 CRACK | no button | teleport to Crater Square and open the roll page; sub-line "N cracks ready" (dim + "need N more" at 0, still tappable) | `rollsReady` |
| 6 Fold | — | chevron folds both wings into one 56 px bar that keeps RUN AGAIN | — |
| 7 Idle | server sends the player home; card shows no timer (RC:6) | 3 px drain bar + "Hub in N" from `returnAt`; any tap resets (#429 Q3) | `returnAt` (RR:365; `autoReturn` 30) |
| Wipe / time-out | titles "Defeated" / "Timed out" (RC:20–23) | same screen, no fly-in; "WIPED ON WAVE N" / "TIME'S UP · WAVE N" + "You keep everything you earned." | `died`, `reason`, `wave` |
| Disconnect | title "Disconnected" (RC:24–25) | never drawn (the player is gone); keep the string only in `lines()` | `reason == "disconnect"` |

## 4. Layout
Frame and keep-out from #420 (full-screen px; build in `CoreUISafeInsets` by subtracting the top inset). Center keep-out: 390×844 x 117–273, y 296–616 · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526.

**Live card vs keep-out (measured from RC:64–68):**
| Viewport | Live card rect (280×180 centered at 50%, 55%) | Overlap with keep-out |
|---|---|---|
| 390×844 | x 55–335, y 374–554 | **covers it** (whole keep-out width and 180 of its 320 px height) |
| 667×375 | x 194–474, y 116–296 | covers it |
| 800×400 | x 260–540, y 130–310 | covers it |
| 1280×720 | x 500–780, y 306–486 | covers it |
So the live card breaks Kevin's "panels stay off screen center" rule at every size. The target layout is #429 §4 unchanged (all wings outside the keep-out):

| Piece | 390×844 | 667×375 | 800×400 | 1280×720 |
|---|---|---|---|---|
| Stats wing | x 16–374, y 107–287 | x 16–196, y 60–361 | x 16–232, y 60–386 | x 16–368, y 66–328 |
| Loot + actions wing | x 16–374, y 620–802 | x 471–651, y 60–361 | x 568–784, y 60–386 | x 912–1264, y 352–704 |
| RUN AGAIN | 190×64 | 156×52 | 192×52 | 328×64 "RUN AGAIN [Space]" |
| CRACK | 136×64 | 156×48 | 192×48 | 328×48 "CRACK · N ready [R]" |
| Chevron | 44×44 | 44×44 | 44×44 | 44×44, key C |
| Loot tiles | 52 px × 6 (6th "+N") | 48 px 3×2 | 56 px 3×2 | 64 px 4×2 (`ResultsGrid.TILE`) |
| Folded bar | x 16–374, y 746–802 | x 174–492, y 301–361 | x 230–570, y 326–386 | x 450–830, y 632–696 |
Every tap target ≥ 44 px (RUN AGAIN 52–64, CRACK 48–64, chevron 44, tiles 48–64).

## 5. States
| Element | Live today | Pass target |
|---|---|---|
| Title: cleared | "Cleared" (RC:27) | **"SHARD CRATER CLEARED"** gold `255,196,64`; landscape short form "CLEARED" |
| Title: wipe | "Defeated" (RC:21) | **"WIPED ON WAVE N"**: white title, only N in danger `230,80,96` (#429 Q11 recommendation), + gold keep line |
| Title: time-out | "Timed out" (RC:23) | **"TIME'S UP · WAVE N"**, wipe layout |
| Title: other | "Run over" (RC:19) | fallback only (card with no outcome) |
| Waves | "Waves cleared %s" (RC:31) | stat tile **WAVES n/5** from `wavesCleared`/`total` |
| Best | none | **SESSION BEST** tile; ok-green value + NEW BEST badge when `newBest`; "—" if missing |
| Kills | none | **KILLS** tile from `kills` |
| Tokens | "Tokens %d" (RC:32) | **"+N Roll Tokens"** (+ BOSS +5 chip when `bossClear.granted`; HARD ×2 tag when `multiplier` = 2) |
| Fragments | "Fragments %d" (RC:33) | **"+N Fragments"** (HARD ×2 tag on Hard) |
| Loot | "%s x%d" with the raw id, e.g. `shard_chip x6` (RC:40, copy pass bug E8) | tiles from `loot.items` with `name` ("Shard Chip", "Boss Core" from `WaveArenaConfig.results.lootNames`) and a 2 px stroke in the item's `tier` color |
| Overflow | listed as extra text rows (RC:35–43) | tiles with "→ Essence" tag + one line "Bag full · N chips became +E Essence" (#429 v1.4) |
| Essence | "Essence %d" (RC:46) | folded into the overflow line; hidden at 0 |
| XP | none | bar from `xpFrac` + "XP +N · Lv N" from `xp`/`levelAfter` |
| RUN AGAIN | none | idle gold / press `UIScale` 0.96 / loading "Starting… 3" / Hard not allowed: sub-line "Normal (Hard needs Lv 5)" |
| CRACK | none | idle violet `108,78,196` "CRACK" + "N cracks ready" / 0 ready: dim `54,46,78` "need N more" (tappable) / receiving tokens: `UIScale` 1.06 pulse |
| Missing m12 fields | n/a | wings still draw from live fields (waves, tokens, fragments, overflow); tiles fall back to overflow rows; never blocks RUN AGAIN (#429 v1.4 §7) |

Tier colors (`Shared/Rarities.luau:38–43`, V1 = 5 tiers): Common `168,168,176` · Uncommon `64,186,98` · Rare `72,142,255` · Epic `186,96,240` · Legendary `255,196,64`. V1 arena drops (`shard_chip`, `boss_core`) are Common today, so most tiles show the Common stroke; gear tiers apply when gear drops arrive.

## 6. Copy
Uses the approved verb **CRACK** and names **Shard Crater**, **Shard Gate**, **Crater Square**, **Hollow Warden** (copy pass Q1–Q4). Caps for titles and buttons; sentence case for lines.
| Key | Line | Replaces (live) |
|---|---|---|
| clear title | SHARD CRATER CLEARED | Cleared (RC:27) |
| wipe title | WIPED ON WAVE N | Defeated (RC:21) |
| time-out title | TIME'S UP · WAVE N | Timed out (RC:23) |
| keep line | You keep everything you earned. | — |
| stat labels | WAVES · SESSION BEST · KILLS | Waves cleared %s (RC:31) |
| tokens | +N Roll Tokens | Tokens %d (RC:32) |
| fragments | +N Fragments | Fragments %d (RC:33) |
| boss chip | BOSS +5 | — |
| overflow | Bag full · N chips became +E Essence | Essence %d (RC:46) |
| loot header | LOOT · N items | — |
| run again | RUN AGAIN · Starting… N · Cancel · Going to the Shard Gate… | — |
| crack | CRACK · N cracks ready · need N more | (#429 said ROLL; Q1 decided CRACK) |
| timer | Hub in N · Back to Crater Square in N (folded) | — |
| empty loot | No drops this run. Your Roll Tokens still count. | — |
| late card | Results are on the way… | — |
This supersedes copy pass rows E1–E9 for the wings (E rows stay valid for the old card while `m12Results` is off). Longest line at 390×844: "Bag full · 6 chips became +18 Essence" ≈ 250 px at 12 px, fits the 334 px wing text width.

## 7. Visual style
| | Live today | Pass target |
|---|---|---|
| Panel fill | `28,26,24` (RC:69), no corner, no stroke | `28,24,40` (STYLE panel), `UICorner` 12, `UIStroke` 2: gold on a Normal clear, danger on Hard, row `40,34,58` on wipe/time-out |
| Text | `236,228,210`, GothamMedium 16 (RC:77–81) | `240,236,248` text / `176,168,198` muted, **BuilderSans** (titles BuilderSansBold 15, stats 17, lines 14, labels 10–11) |
| Rows/tiles | — | row `40,34,58`, tile `UICorner` 8, `UIStroke` 2 in tier color |
| Buttons | — | RUN AGAIN gold `255,196,64` with ink `32,22,10`; CRACK violet `108,78,196` with text `240,236,248`; `UICorner` 10 |
| Good / new | — | ok `110,210,140` for NEW BEST |
| Identity | — | a thin `UIGradient` (gold → transparent) on the clear title row only |
No blur, no drop shadows, no web fonts.

## 8. Motion / VFX
| Moment | Spec | Roblox |
|---|---|---|
| HUD out | 0.2 s fade | `TweenService` on `GroupTransparency` (`CanvasGroup`) or each element's transparency |
| Wings in | 0.3 s, Quad Out, from the edge | tween `Position` |
| Count-up | 0.6 s, tokens + fragments | `NumberValue` tween + `.Changed` → text |
| Tile pop | 0.05 s stagger, max 0.5 s total, `UIScale` 0.8 → 1 | `UIScale` tween |
| Legendary tile | 2 × 0.3 s gold stroke pulse | `UIStroke.Transparency` tween |
| Win burst | gold `ParticleEmitter` `Emit(16)` on the hero (world space, not UI) | `ParticleEmitter` in an `Attachment` on the HumanoidRootPart |
| Boss fly-in | per `TOKEN_FLYIN_v1.2.md` (5 icons, 0.08 s stagger, 0.45 s, Quad In) | `ImageLabel` tweens |
| Fold | 0.25 s | tween `Size`/`Position` |
| Timer | linear drain over `returnAt − now` | tween `Size.X.Scale` |
Any tap skips the count-up and fly-in to their end state. Whole moment ≤ 1.1 s.

## 9. Roblox build notes
| Element | Instances |
|---|---|
| Wings | `Frame` + `UICorner` 12 + `UIStroke` 2 (`ApplyStrokeMode` Border) + `UIPadding` 12 + `UIListLayout`; size/position from a pure layout function per viewport (mirror `ShellLayout.menuRect` style) and re-fit on `ViewportSize` change |
| Stat tiles | `Frame` 104×52 + `UICorner` 8, two `TextLabel`s (label 10 px muted, value 17 px) |
| Loot tiles | `ImageButton` (48–64 px) + `UICorner` 8 + `UIStroke` 2 tier color + `TextLabel` name strip; merge and "+N" via `Shared/ResultsGrid.luau` |
| Buttons | `TextButton` + `UICorner` 10 + `UIScale` (press 0.96); sub-line `TextLabel` 10 px; `AutoButtonColor = false` |
| Chevron | `ImageButton` 44×44 |
| Drain bar | `Frame` 3 px + inner `Frame` sized by scale |
| Title gradient | `UIGradient` on the title row `Frame`, `Offset` tween once |
| Burst | world `ParticleEmitter` (`Rate = 0`, `Emit(16)`), gold `255,196,64`, Lifetime 0.6–0.9 |
| Text | `TextScaled = false`, fixed sizes; `TextTruncate = AtEnd` safety net; caps written in the string |
| Hook | `ResultsWings.apply(playerGui, hud)` mirrors RC:89–103: hidden while `hud.card` is nil; tweens in on the first non-nil card only |
| Gate | draw wings only when `m12Results` is on; else leave `ResultsCard` as is. Delete nothing. |
Prism does not edit `ResultsCard.luau`, `HudLayout`, or any Ghost-owned UI file; this is a build brief.

## 10. Mobile checks
- 390×844: wings at y 107–287 and 620–802, both outside the keep-out (296–616); RUN AGAIN 190×64 and CRACK 136×64 at y 714–778, under the thumb.
- 667×375 and 800×400: wings left/right, outside x 200–467 / 240–560; buttons ≥ 48 px tall.
- 1280×720: wings outside x 384–896; keys Space / R / C.
- The live 280×180 centered card fails all four (§4 table); the target passes all four.
- Toasts wait while the wings are unfolded (the #420 toast lane overlaps the stats wing on portrait).
- Text-fit: longest lines checked in §6; Ghost confirms with `TextService:GetTextSize` as in #459 v1.1 §5.
- Mockup: `mockups/01-live-vs-target-390x844.svg` (live card in the keep-out vs the wings, fake data, PNG inside an SVG wrapper). #429 mockups 01–12 cover landscape, desktop, folded, fly-in and Hard.

## 11. Open questions (answer by number)
1. **@Ghost:** build `ResultsWings` as a new module next to `ResultsCard` and gate it on `m12Results` (old card stays when off, nothing deleted)? Prism recommends **yes**.
2. **@Ghost:** the second action button says **CRACK** (Q1 verb) with "N cracks ready", replacing #429's "ROLL"? Prism recommends **yes**; it opens the same roll page.
3. **@Ghost:** loot tiles read `loot.items[].name` from the server (fixes the raw `shard_chip` id, copy pass E8) and the old card's `lines()` also switches to `name` when present? Prism recommends **yes, both**.
4. **@Kevin (taste):** wipe/time-out title tone: **white title with only the wave number in red** plus the gold "You keep everything you earned." (#429 Q11, Prism recommends), or a fully red title?
5. **@Kevin (taste):** the clear title: **"SHARD CRATER CLEARED"** (caps, place name, Prism recommends) or the copy pass's sentence-case "Shard Crater cleared!"? Prism recommends the caps title on the wings and retiring the sentence-case line.

## Decision log
- 2026-10-24 (Prism, DP38P task 3): visual pass comparing live `ResultsCard` (#382 card at `728421a`) with #429 wings. Finds the server m12 payload and Run Again action already built, client unused; live card sits in the center keep-out at all 4 sizes; raw ids; GothamMedium; no buttons/timer/motion. NOT APPROVED.
