# Results Screen + Run Again ("Results wings"), Spec v1.3

Owner: Prism (design, docs only, no code). Builders: Ghost (client results UI, teleports), Echo (results payload, payouts). Base: `cursor/live-build-9721`. Status: **v1.1, direction A chosen by Ghost** (Kevin pre-approved, Agent Board row https://app.notion.com/p/403c31ca388381089ec4e42d24ad049f, Oct 24, 2026). Ghost questions 1–4 are decided; Kevin taste call 5 stays **PROVISIONAL**. **v1.2 (Oct 24, 2026):** folds in the boss-clear reward moment (5 Roll Tokens fly to ROLL) from Ghost's GO row https://app.notion.com/p/403c31ca388381758d47e930e50ccb27 item 2 (#431); new questions 6–7 for Ghost. **v1.3 (Oct 24, 2026):** Ghost answered Q6/Q7 (board row https://app.notion.com/p/403c31ca38838155a532f79564499765, Kevin pre-approved): `bossClear` comes from the saved grant only (Echo adds it) and the boss pays 5 Roll Tokens on every tier. Adds the **Hard-clear variant** (5 tokens, same as Normal; Hard badge only), mockup 09. Gray-box only (pre-Phase S). Not an official Vision & Design Rules decision until Kevin approves it.

**M12 build check v1.4 (Oct 24, 2026, Ghost GO row https://app.notion.com/p/403c31ca388381e89200df4fe6fe8d29 item 1):** see `M12_BUILD_CHECK_v1.4.md` (this folder). It maps Ghost's M12 asks to this spec, folds the live #382 results card now in the #451 merge train (1.5 s death hold, time-out variant "TIME'S UP · WAVE N", full-Bag overflow → Essence line and tile tags, retire the centered card and "Defeated" copy behind the flag, delete nothing) and adds Q8–Q10 (@Ghost) and Q11 (@Kevin, wipe title tone). Mockup 12. Where they differ, v1.4 wins.

**Fly-in v1.2 (Oct 24, 2026, Ghost GO row https://app.notion.com/p/403c31ca388381919fdfd588508d2143):** now `TOKEN_FLYIN_v1.2.md` (Roll Tokens row is a 44 px minimum tap target, `RunResults.tokens` wave-only with the boss 5 only in `bossClear.tokens` as a separate BOSS +5 chip, chip fills gold on landing). **Fly-in v1.1 (Oct 24, 2026, Ghost GO row https://app.notion.com/p/403c31ca388381ecbd1de2f133fd3cb4):** the boss-clear token fly-in is now its own spec, `TOKEN_FLYIN_v1.1.md` (this folder). Live wave-5 `waveReward` 2 is correct and #431's boss clear 5 is a one-time grant on top, so the Roll Tokens line shows the **wave** tokens and a separate **BOSS +5** chip (never one merged "+17"), and the fly-in reads only `bossClear.tokens`. It replaces §3 step 2b and the §6 fly-in row below; mockups 10 and 11.

Asked for in: Ghost's Agent Board row (Kevin pre-approved) https://app.notion.com/p/403c31ca388381eeb7def55a6b3d4953, from canvas item **M12**: "Results screen + Run Again spec". Roadmap **4.2** ("Results screen: waves cleared, loot grid, best wave") and **4.3** ("Run Again button + back-to-roll shortcut"). Phase 4 done-when: "Full loop works with no dead ends: roll → equip → run → reward → roll."

Sources (link, don't copy):
- Locked: Roadmap Phase 3/4 (5 waves; no early exit; keep all earned loot, even on a wipe; 4.1 Roll Tokens + Fragments from Config; Kevin's checks "After a run, do you want to roll right away?" and "Do you want to run again?"; metric: Run Again rate). V1 Core Loop §3/§4 (personal loot; Hard pays 2× tokens/fragments + Hard-only Epic+ items).
- Live code (read only, `cursor/live-build-9721`): `ShardfallClient/CombatHud.luau` victory card (`Result` Frame, 340 wide, centered at (0.38, 0.45), title "<dungeon> cleared", body lines Gold / Shard tokens / XP / voucher, a 44 px Continue button, loot tiles via `Shared/ResultsGrid.luau`: 64 px tiles, 36 px name strip, merged by name, max 2 rows, extra kinds fold into one "+N" tile, from #365). `ShardfallClient/SessionRecap.luau` (one "This session:" line). `Shared/Rarities.luau` `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64). No best-wave field exists in the save today (schema 26).
- Open PRs read: #384 `echo/4-payouts` (Roll Tokens + Fragments grant, one per run, flag off, no Fragments save field yet); #382 `echo/3-wave-arena` (unmerged `WaveArena/ResultsCard.luau`, results after a death hold).
- Specs this must match: **#420 phone layout review rev 1.1** (full-screen px frame; center keep-out with portrait top 35% = y 296, D1 provisional; D3 one toast lane, max 1). **#397** roll reveal (Roll page this shortcut opens; collapse bar). **#414** Shard Crater (arena). **#416** buffs (draft ends with the run). **Hard mode selector v1.1** ("Hard ×2" line, HARD tags on Hard-only drops). **Party gather spot v1.1** (Gate pad, join order, 15 s countdown + 5 s late-join bump, no ProximityPrompt; "Run it back" is a Later idea, NOT APPROVED). **Wave HUD v1** (`prism/wave-hud`, chip shows CLEARED / WIPED right before this screen).
- **v1.2 source: PR #431** (`e7abb8e`, read only): `Shared/BossClearReward.luau` pays `Config/Economy.BOSS_CLEAR_TOKENS` = **5** Roll Tokens (the wave-5 boss row; `shardTokens`) **once per run id** (`profile.bossClearRuns`, bounded 16). The server **saves before it tells the client**; a failed save pays nothing; a wipe doesn't grant. `WaveFlowService.publish` still sends only `{ wave, left }`, so the client has no boss-clear signal yet (Q6). #430: Hard multiplies dungeon-clear tokens via `HardMode.tokens`; the #431 boss grant is a flat 5 (Q7).
- Chrome: PR #392 `docs/ui/reference/STYLE.md` (panel 28,24,40 · row 40,34,58 · button 108,78,196 · gold 255,196,64 · danger 230,80,96 · ok 110,210,140 · corners 8/10/12 · strokes 1/2 · Builder Sans).

## 0. Directions (pick one) and recommendation
Mockup: `mockups/07-directions.svg`.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Results wings** | The run ends in the arena. Two panels slide in from the edges: a **stats wing** (title, waves, best wave, tokens, fragments, XP) and a **loot + actions wing** (loot grid, RUN AGAIN, ROLL). Portrait: top and bottom; landscape/desktop: left and right. The center stays clear, so the player sees their hero's victory pose. A chevron folds both wings into one 56 px bar that keeps RUN AGAIN. | Keeps the win moment, follows the keep-out, RUN AGAIN is 1 tap and always the biggest thing on screen. Reuses `ResultsGrid` tiles. | Two panels to build instead of one card; the portrait loot row shows 6 tiles (the rest scroll). |
| B | Center card | Upgrade today's 340 px victory card (`CombatHud`): add best wave, Run Again, Roll. | Fastest to build, the card already exists. | Sits right in the center keep-out (Kevin's rule), covers the hero, and the "Continue" habit stays. |
| C | Hub return + recap | Teleport straight to the hub; a small recap card shows by the Gate pad; to run again, step on the pad. | Fewest screens; the hub is where rolling happens. | Loses the win moment; Run Again becomes walk + up to 15 s countdown, which works against the "do you want to run again?" test. |

**Recommendation: A.** It's the only one that keeps the center clear and makes Run Again a single tap, and it shows the reward where the player earned it. The rest of this spec is A.

**Decided (Ghost, Oct 24, 2026, Kevin pre-approved): A.**

## 1. Goal
After a run (clear or wipe), a player understands in about 3 seconds how far they got, what they earned and whether they beat their best, and can either run again or go roll their new tokens in one tap. No dead ends: every exit leads back into the loop.

## 2. Where it lives
- **Screen (Ghost):** a new `ResultsWings` UI in the arena, shown at run end. It replaces the `CombatHud` victory card for the V1 arena. **Q4 decided:** the old card is retired **behind a flag** when the V1 arena flag flips, and **nothing is deleted** (the card and its code stay in the repo). Prism doesn't edit `CombatHud`, `HudLayout` or any Ghost-owned file. While it's up, the live HP block, currency pills, rail and combat cluster hide (the run is over). The Roblox thumbstick stays, so a player who folds the wings can walk.
- **Loot tiles:** reuse `Shared/ResultsGrid.luau` merge + "+N" rules; tile size per viewport in §4.
- **Server (Echo):** one `RunResults` snapshot per player (personal loot) at run end: `{ outcome = "cleared" | "wiped", tier, wavesCleared, total, seconds, kills, tokens, fragments, multiplier, xp, levelAfter, xpFrac, loot = { {id, name, tier, count, hardOnly} }, bestWave, newBest, rollsReady, bossClear = { granted, tokens } }` (**v1.2**: `bossClear` comes from the #431 `BossClearReward.commit` result; `granted = true` only when that commit saved this run, `tokens` = the amount actually paid. **v1.3, Q6 decided:** yes, `RunResults` carries `bossClear = { granted, tokens }` from the saved grant only; Echo adds it). `bestWave` / `newBest` are **session-only** for V1 (Q2 decided): kept in server memory per player per tier, never written to the save (schema stays 26; a saved best-wave field is parked). Payouts are already granted by the server (#384) before the snapshot; the UI shows, never grants.
- **Teleports (Ghost):** RUN AGAIN and ROLL (§3). Run state lives in memory only.
- **Not here:** sharing/screenshots, leaderboards, Robux offers, "double your loot" prompts, chests. None of these appear on the results screen.

## 3. Flow
| Step | Trigger | What the player sees / does | Server |
|---|---|---|---|
| 1 | Boss dies (or the party wipes) | Wave chip shows CLEARED / WIPED (Wave HUD spec). After 1.0 s (clear) or the death hold (wipe), the live HUD fades (0.2 s) and the wings slide in from the edges (0.3 s, Quad Out). The hero plays a victory pose (clear) or respawns standing (wipe). | grants payouts, sends `RunResults` |
| 2 | Wings in | Tokens and fragments count up (0.6 s). Loot tiles pop in Legendary → Common, 0.05 s apart. A Legendary tile gets a 2-pulse gold stroke and a world `ParticleEmitter` burst on the hero. **NEW BEST** badge pops on Best wave if `newBest`. | — |
| 2b (v1.2) | Wings landed and `bossClear.granted` | **Boss-clear token fly-in.** A gold burst (world `ParticleEmitter`) pops at the boss-defeat point; **5 Roll Token icons** (24 px) fly on a curve from that point's screen position (clamped inside the screen; fallback: the Roll Tokens line) to the **ROLL** button: 0.08 s apart, 0.45 s each, Quad In, shrinking 24 → 16 px. Each arrival: ROLL `UIScale` 1 → 1.06 → 1 (0.12 s) and its gold 2 px stroke flashes; on the last one a "+5" pop sits on ROLL's top-right for 0.6 s and "N rolls ready" ticks to the new value. The Roll Tokens line shows a gold-outline **BOSS +5** chip. Total ≈ 0.77 s, running alongside the 0.6 s count-up. Any tap snaps the tokens to ROLL at once. | — (already saved by #431) |
| 2c (v1.3) | Hard clear with `bossClear.granted` | **Hard-clear variant.** Same fly-in, same 5 icons, same "+5" pop and the same gold **BOSS +5** chip as Normal (the boss pays 5 on every tier, Q7). The only Hard mark is the **HARD badge** on the stats wing title (plus the existing red 2 px wing stroke from the Hard accent pass). The **HARD ×2** tags stay on the dungeon-clear tokens and fragments only (#430). Tapping the Roll Tokens line puts the split in the caption line: "Roll Tokens: 6 clear ×2 (Hard) + 5 boss". Mockup 09. | — |
| 3 | Tap a loot tile | The caption line shows "<name> · <tier>" (+ "· Hard only"); the tile gets a gold 3 px stroke. No popup. | — |
| 4 | Tap the "+N" tile | The loot row becomes a horizontal scroll with every tile; no new panel. | — |
| 5a | Tap **RUN AGAIN** (solo) | Button reads "Starting… 3" with a small "Cancel" link under it; after 3 s a fresh run starts in a new arena copy with the **same tier** (Hard only if still allowed). No hub trip. | new run, re-checks the tier rule |
| 5b | Tap **RUN AGAIN** (party) | **Decided (Q1):** party Run Again goes back through the hub **Gate pad countdown**. You go to the pad and take a slot by tap order; the party re-forms there (party spec rules: leader by join order, 15 s countdown, 5 s late-join bump). Button reads "Going to the Gate…". No direct arena restart for parties in V1. | teleport to pad, join |
| 6 | Tap **ROLL** | Teleport to the hub and open the Roll page (#397) directly. Badge "N rolls ready" (= tokens ÷ roll cost). With 0 rolls the button is dim and reads "need N more", and still works (it opens the Roll page so the player sees the cost). | teleport |
| 7 | Tap the chevron | Both wings fold (0.25 s) to one 56 px bar: "CLEARED · 5/5 · +17 tokens · 12 items" + RUN AGAIN. Tap the bar's chevron to unfold. | — |
| 8 | No tap for 30 s | **Decided (Q3): 30 s auto-return with a visible timer.** From the moment the wings land, a 3 px drain bar + "Hub in N" sits in the loot wing header (and over the folded bar as "Back to the hub in N"), counting the whole 30 s. Any tap on the results UI resets it to 30. At 0: teleport to the hub. | teleport, server-timed (`returnAt`) |

**Wipe:** no boss clear, so no fly-in and no BOSS +5 chip. Same screen otherwise. Title "WIPED ON WAVE 3" (danger color), sub-line "You keep everything you earned." No penalty, no "failed" wording, no retry upsell. **First run (#412 Focus mode):** same screen, ROLL is the highlighted button once ("Roll your tokens!" toast in the lane), because the first loop's goal is roll → run → roll.

## 4. Layout
Full-screen px, same frame as the #420 review (0,0 = screen top-left including the Roblox top bar). Build in `CoreUISafeInsets` by subtracting the top inset. The live HUD is hidden during results, so the wings can use its spots.

**Center keep-out:** 390×844 x 117–273, y 296–616 (D1, provisional) · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. Nothing in this spec enters it.

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Stats wing | **x 16–374, y 107–287** (358×180); bottom 287 < 296 | **x 16–196, y 60–361** (180×301); right 196 < 200 | **x 16–232, y 60–386** (216×326); 232 < 240 | **x 16–368, y 66–328** (352×262); 368 < 384 |
| Stats wing contents | title row (HARD chip + title 15 px, chevron 44×44 top-right), 3 stat tiles 104×52 (Waves / Best wave / Kills), Roll Tokens + Fragments lines (HARD ×2 tags), XP bar | title, 2 stat tiles (Waves / Best), token + fragment lines, XP bar, one "HARD ×2 tokens + fragments" strip, kills line | same as 667 | same as portrait, tags per line |
| Loot + actions wing | **x 16–374, y 620–802** (358×182); top 620 > 616 | **x 471–651, y 60–361**; left 471 > 467 | **x 568–784, y 60–386**; 568 > 560 | **x 912–1264, y 352–704** (bottom-anchored); 912 > 896 |
| Loot tiles | 52 px, 6 per row, gap 5, one row y 648–700 (6th = "+N") | 48 px, 3 × 2, gap 6 (6th = "+N") | 56 px, 3 × 2 | 64 px, 4 × 2 (`ResultsGrid.TILE`) |
| RUN AGAIN | **190×64**, x 28–218, y 714–778 | 156×52, y 241–293 | 192×52 | 328×64 "RUN AGAIN [Space]" |
| ROLL | 136×64, x 226–362, y 714–778 | 156×48, y 301–349 | 192×48 | 328×48 "ROLL · N rolls ready [R]" |
| Collapse chevron | 44×44 in the stats wing title row | 44×44 in the loot wing header | same | same, key C |
| Collapsed bar | x 16–374, y 746–802 (358×56): chevron 44, summary, RUN AGAIN 144×44 | x 174–492, y 301–361 (#420 bottom-center slot) | x 230–570, y 326–386 | x 450–830, y 632–696 |
| Token fly-in path (v1.2) | boss-defeat screen point (clamped to x 16–374, y 296–616) → ROLL center (294, 746); curve bends right (control point +70 px x); icons pass over the keep-out for < 0.8 s (motion, not a panel) | → ROLL center (561, 325) | → ROLL center (676, 354) | → ROLL center (1088, 680) |
| BOSS +5 chip (v1.2) | 52×14 gold 1.2 px outline, after the "Roll Tokens" label (x 102–154, y 225–239) | same, after the label | same | same |
| Auto-return timer (v1.1, always visible) | 3 px drain bar x 28–362, y 626 + "Hub in N" 10 px right-aligned at y 642 in the loot wing header (the tile caption moves to the left of that row) | drain bar under the loot header (x 483–583, y 100) + "Hub in N" left of the chevron | same pattern | same pattern; folded bar: "Back to the hub in N" + drain bar above it |

Checks:
- Every button ≥ 44 px tall (RUN AGAIN 52–64, ROLL 48–64, chevron 44, tiles 48–64). Text ≥ 13 px except badges/captions at 10–11 (R7).
- Portrait: the bottom wing covers the thumbstick zone (y 640–794) while unfolded; that's intended (no combat), and folding frees it except the 56 px bar, which the #412 collapse bar already uses.
- Toast lane (D3) stays where #420 put it; on portrait (x 88–266, y 231–267) it would overlap the stats wing, so **toasts wait while the wings are unfolded** (queue, same as during the #416 tray).

## 5. States
| Element | Idle | Press | Selected | Disabled | Loading | Special |
|---|---|---|---|---|---|---|
| RUN AGAIN | gold 255,196,64, ink 32,22,10 text 16 px heavy, sub-line "Hard · same party" / "Normal · solo" | `UIScale` 0.96, 0.08 s | — | Hard no longer allowed: sub-line "Normal (Hard needs Lv 5)" | "Starting… 3" / "Going to the Gate…" | first run: not highlighted (ROLL is) |
| ROLL | button 108,78,196, "ROLL" + "N rolls ready" | `UIScale` 0.96 | — | 0 rolls: buttonDim 54,46,78, "need N more" (still tappable) | "Going to roll…" | first run: gold 2 px stroke pulse ×2. **v1.2 receiving:** per token `UIScale` 1.06 + gold stroke flash, "+5" pop 0.6 s; if 0 rolls before and ≥ 1 after, it switches from dim to violet on the last token |
| BOSS +5 chip (v1.2) | gold outline chip on the Roll Tokens line, shown only when `bossClear.granted` | — | — | hidden (wipe, already paid, failed save) | — | text = "BOSS +" .. `bossClear.tokens` |
| Loot tile | row fill + 2 px `Rarities.COLOR` stroke, count "xN" | `UIScale` 0.96 | gold 3 px stroke, caption shows name | — | `spinner_64` (#397) until the snapshot arrives | Hard-only: small HARD tag; new item: ok-green dot |
| Best wave | value 17 px | — | — | no data: "—" | — | `newBest`: ok-green value + "NEW BEST" badge |
| Wings | panel 28,24,40; stats wing 2 px stroke (danger on Hard, gold on a Normal clear, row on a wipe) | — | — | — | — | folded = 56 px bar |
Error: if `RunResults` doesn't arrive in 3 s, show the wings with "Results are on the way…" and keep RUN AGAIN / ROLL working (rewards are already granted server-side). Empty loot: "No drops this run. Your tokens still count." 

## 6. Numbers
- Waves: 5 (Config). Shown as cleared / total, e.g. 5/5, 2/5 on a wipe.
- Rewards: Roll Tokens + Fragments from Config (#384); Hard = ×2 (Core Loop), shown as a HARD ×2 tag, never as a separate bonus line. XP and level from the existing XP flow.
- Rolls ready = floor(tokens ÷ roll cost) from Config.
- Best wave: per tier (Normal / Hard), **session-only** (Q2 decided; label "SESSION BEST"). The first run of a session shows the value with no NEW BEST badge; later runs show NEW BEST when they beat it. No save field (schema stays 26).
- **Boss-clear fly-in (v1.2):** icons = min(`bossClear.tokens`, 5) (5 today); 0.08 s stagger, 0.45 s flight, Quad In, 24 → 16 px; starts as the wings land (t = 0.3 s), last lands at ≈ 1.07 s; ROLL pulse 0.12 s per token; "+5" pop 0.6 s; world burst `Emit(16)` gold.
- Run Again countdown: 3 s solo (cancelable). Party: Gate pad rules (15 s from the first player, 5 s late-join bump).
- Auto-return: 30 s idle, timer visible for the full 30 s, any tap resets (Q3 decided).
- Timings: wings in 0.3 s, out 0.25 s, counters 0.6 s, tile pop 0.05 s stagger (max 0.5 s total), Legendary pulse 2 × 0.3 s.
- Colors: Hard accent danger 230,80,96 (**PROVISIONAL**, Kevin taste call, Hard spec Q4); wipe title danger; clear title gold; NEW BEST ok 110,210,140; tile strokes `Rarities.COLOR`.
- Copy: "SHARD CRATER CLEARED" / "CLEARED" (landscape) · "WIPED ON WAVE N" · "You keep everything you earned." · "WAVES" · "SESSION BEST" · "KILLS" · "NEW BEST" · "Roll Tokens" · "Fragments" · "HARD ×2" · "XP +N · Lv N" · "LOOT · N items" · "RUN AGAIN" · "Starting… N" · "Cancel" · "Going to the Gate…" · "ROLL" · "N rolls ready" · "need N more" · "Back to the hub in N" · "No drops this run. Your tokens still count." · "Results are on the way…".

## 7. Edge cases
- **Server authority:** rewards are granted before the snapshot; the UI can't grant, double or re-roll anything. RUN AGAIN re-checks the tier rule (Hard needs Lv 5 for every member) on the server.
- **Wipe:** keep every earned drop (Oct 23 rule). The screen never says "failed" or offers a paid revive.
- **Disconnect during results:** rewards are already saved by the payout grant; on rejoin the player is in the hub with no results screen (no replay).
- **Party, mixed choices:** each player chooses on their own screen (personal loot). With the recommended Q1, RUN AGAIN players meet on the Gate pad; ROLL players go to the Crackstone; idle players return at 30 s.
- **Level-up during the run:** the XP bar fills to the end and shows "Lv N!" once; the Hard unlock toast (Hard spec) queues in the lane until the wings fold or close.
- **Boss-clear moment (v1.2):** plays only when `bossClear.granted` is true. Already paid (rejoin / repeat event, `already = true`), failed save, or wipe → no fly-in, no chip, and the Roll Tokens total shows only what was really paid. If the player folds the wings mid-flight, the remaining tokens retarget to the folded bar's "+N tokens" text. Party: each player sees their own fly-in (personal pay). Reduced motion is not a V1 setting; the whole moment is < 1.1 s and any tap skips it.
- **Lots of loot:** `ResultsGrid` merges by name and folds extras into "+N"; the scroll shows all.
- **Tokens below one roll:** ROLL is dim with "need N more" but still opens the Roll page (no dead end).
- **Anti-AFK (Roadmap 6.3):** an AFK member gets no end rewards; their screen says "No rewards: deal damage in 3 of 5 waves." (server text) instead of the reward lines.
- **Performance:** two Frames, ≤ 13 tiles, one world emitter burst; tweens only.

## 8. Mockups
SVG in repo (fake data, original art, gray-box arena). v1.1 re-rendered all six screens with "SESSION BEST" and the always-visible hub timer. `mockups/01-cleared-phone-390x844.svg` (Hard clear, NEW BEST, ×2 tags) · `mockups/02-wipe-phone-390x844.svg` (wipe on wave 3, ROLL dim) · `mockups/03-collapsed-phone-390x844.svg` (folded bar + auto-return line) · `mockups/04-cleared-landscape-667x375.svg` (wings left/right, keep-out clear) · `mockups/05-cleared-landscape-800x400.svg` (Normal solo) · `mockups/06-desktop-1280x720.svg` (keys Space / R / C) · `mockups/07-directions.svg` (A/B/C) · **v1.2:** `mockups/08-token-flyin.svg` (3 frames + timeline). **v1.3:** `mockups/09-hard-clear-variant.svg` (Normal vs Hard boss-clear moment + rules); 01, 03, 04, 06 re-rendered without the Hard sky tint (Hard accent v1.1 Q3), 01 note updated. v1.2 also re-rendered 01 (Hard clear, tokens in flight, BOSS +5 chip, ROLL +5), 03 (folded bar total), 04 and 06 (fly-in in landscape/desktop) and 05 (Normal, landed state). The keep-out is the cyan dashed box. PNG renders are on the box only.

## 9. Build split
Roadmap 4.2 / 4.3. Building waits for Ghost's go and the #384 payouts flag.
- **Echo (server):** `RunResults` snapshot (personal), payouts granted first, `rollsReady`, session-only best-wave compare in memory (Q2, no save write), RUN AGAIN entry: solo restart in a fresh arena copy with a tier re-check; party → Gate pad countdown (Q1); 30 s idle return with a server `returnAt` (Q3); analytics `run_again` and `results_roll` events; **v1.2/v1.3 (Q6 decided):** fill `bossClear = { granted, tokens }` from the #431 `BossClearReward.commit` result (granted only when saved; 5 on every tier, Q7) (Roadmap metric "Run Again rate"). Tests: rewards never granted twice, wipe keeps loot, Hard re-check on RUN AGAIN, no save write when Q2 says session only.
- **Ghost (client):** `ResultsWings` (2 wings + folded bar), reuse `ResultsGrid`, hide the live HUD during results, teleports, keys Space / R / C, retire the old victory card behind a flag for the V1 arena, deleting nothing (Q4), toast-lane wait while unfolded; **v1.2:** token fly-in (5 `ImageLabel`s on a NumberValue-driven curve), ROLL receive pulse, BOSS +5 chip, world burst at the boss-defeat point; **v1.3:** Hard-clear variant = HARD badge on the wing title only, tokens-line tap caption with the clear/boss split.
- **Prism:** final copy check; Phase S pass (victory pose, Legendary burst, title art).
- **Havoc:** spam RUN AGAIN, RUN AGAIN + disconnect, party where one member picks ROLL, Hard re-check after a member levels down/leaves, 30 s idle.

## 10. Pass criteria (playtest)
1. At 390×844 a tester can say how many waves they cleared and how many tokens they got within 3 s of the screen appearing.
2. A tester starts a new run in 1 tap (solo) and reaches wave 1 in under 5 s.
3. A tester with ≥ 1 roll ready goes from results to a roll in ≤ 2 taps.
4. A tester can tell from the screen alone whether they beat their best wave.
5. Nothing enters the center keep-out at any of the 4 sizes; every button ≥ 44 px; the collapsed bar keeps RUN AGAIN.
6. A wipe shows the loot kept and no "failed" or paid wording.
7. **(v1.3)** On a Hard clear, a tester says the boss gave 5 tokens (not 10) and that the ×2 was the clear reward.
8. **(v1.2)** After a boss clear, a tester can say they got 5 Roll Tokens for the boss and taps ROLL within 5 s more often than without the fly-in (compare `results_roll` rate).
9. Kevin's Phase 4 checks: "After a run, do you want to roll right away?" and "Do you want to run again?" both get a yes from most testers.

## 11. Open questions (answer by number)
1. ~~**@Ghost:** Party RUN AGAIN?~~ **Decided (Ghost, Oct 24, 2026, Kevin pre-approved): party Run Again goes back through the Gate pad countdown.** "Run it back" from the arena stays a Later idea (NOT APPROVED). See §3 step 5b.
2. ~~**@Ghost:** Best wave save field?~~ **Decided: best wave is session-only for V1.** Schema stays 26; the saved field is parked (a future save change needs Kevin's OK). See §2, §6.
3. ~~**@Ghost:** Auto-return?~~ **Decided: yes, 30 s auto-return with a visible timer.** See §3 step 8 and §4.
4. ~~**@Ghost:** Retire the CombatHud victory card?~~ **Decided: retire it behind a flag, delete nothing.** See §2.
5. **@Kevin (taste, PROVISIONAL):** Which button wins? Recommended: RUN AGAIN is the big gold button and ROLL is violet with the "N rolls ready" count, except on the very first run when ROLL is highlighted once. Also title wording: "SHARD CRATER CLEARED" (recommended) or "VICTORY!". The spec ships the recommendation until Kevin says otherwise.

6. ~~**@Ghost:** Boss-clear signal?~~ **Decided (Ghost, Oct 24, 2026, board row https://app.notion.com/p/403c31ca38838155a532f79564499765, Kevin pre-approved): yes.** `RunResults` carries `bossClear = { granted, tokens }`, from the saved grant only; Echo adds it. See §2.
7. ~~**@Ghost:** Hard and the boss grant?~~ **Decided: the boss pays 5 Roll Tokens on every tier in v1, no Hard bonus.** Hard-clear variant (§3 step 2c, mockup 09): 5 tokens, Hard badge only.

All Ghost questions (1–4, 6–7) are closed. Only Kevin's taste call 5 is open (PROVISIONAL). **v1.4 adds Q8–Q11 in `M12_BUILD_CHECK_v1.4.md`** (Q8–Q10 @Ghost, Q11 @Kevin).

## Decision log
- 2026-10-24 (Prism, Ghost GO row https://app.notion.com/p/403c31ca388381e89200df4fe6fe8d29 item 1, Kevin pre-approved): **v1.4 build check** in `M12_BUILD_CHECK_v1.4.md` instead of a duplicate M12 branch (live #382 card fold, time-out + overflow variants, mockup 12, Q8–Q11). Not approved.
- 2026-10-24 (Prism, Ghost GO row https://app.notion.com/p/403c31ca388381919fdfd588508d2143, Kevin pre-approved): **fly-in v1.2** in `TOKEN_FLYIN_v1.2.md` (44 px Roll Tokens row, wave-only tokens + separate BOSS +5 chip, chip fills gold on landing). Not approved as a design rule.
- 2026-10-24 (Prism, Ghost GO row https://app.notion.com/p/403c31ca388381ecbd1de2f133fd3cb4, Kevin pre-approved): **fly-in v1.1** split out to `TOKEN_FLYIN_v1.1.md` (waves value + BOSS +N chip, fly-in reads `bossClear.tokens`, no merged total; mockups 10, 11). Not approved as a design rule.
- 2026-10-24 (Ghost, board row https://app.notion.com/p/403c31ca38838155a532f79564499765, Kevin pre-approved): **v1.3.** Q6 = `RunResults.bossClear = { granted, tokens }` from the saved grant only (Echo adds it). Q7 = boss pays 5 on every tier, no Hard bonus. Added the Hard-clear variant (same 5-token fly-in and BOSS +5 chip; HARD badge on the wing title only; ×2 tags only on clear tokens/fragments; tap caption splits the sum). Mockup 09 added; 01, 03, 04, 06 re-rendered with no Hard sky tint. Kevin Q5 stays PROVISIONAL.
- 2026-10-24 (Prism, Ghost GO row https://app.notion.com/p/403c31ca388381758d47e930e50ccb27 item 2, Kevin pre-approved): **v1.2** folds in the boss-clear reward moment from #431: 5 Roll Tokens fly from the boss-defeat point to ROLL (0.08 s stagger, 0.45 s each), ROLL pulses, "+5" pop, BOSS +5 chip on the Roll Tokens line; plays only on a saved grant. New Q6 (boss-clear signal in `RunResults`) and Q7 (Hard × boss grant). Mockups 01, 03–06 re-rendered, 08 added.
- 2026-10-24 (Ghost, Kevin pre-approved, board row https://app.notion.com/p/403c31ca388381089ec4e42d24ad049f): direction **A**. Q1 = party Run Again goes back through the Gate pad countdown. Q2 = best wave session-only for V1 (schema stays 26, saved field parked). Q3 = yes, 30 s auto-return with a visible timer. Q4 = retire the CombatHud victory card behind a flag, delete nothing. Q5 (Kevin taste) stays PROVISIONAL. Mockups re-rendered. → v1.1.
- 2026-10-24 (Prism): v1 published. Recommends direction A (Results wings). Five open questions (Ghost 1–4; Kevin 5). Not approved. The Hard colors use the Hard accent that is still a PROVISIONAL Kevin taste call (Hard spec Q4).

## Later (not V1)
"Run it back" with the same party from the arena (party spec Later), per-run grade stars, share card, wave-by-wave breakdown, best-time tracking. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox UI only. No blur or glassmorphism, no soft shadows, no web fonts (Builder Sans / GothamSSm). `ParticleEmitter` only in world space; UI motion = TweenService. The mockups are a guide and these notes win.

| Element | Instances |
|---|---|
| Wings | 2 × `Frame` (panel 28,24,40) + `UICorner` 12 + `UIStroke` 1–2 + `UIPadding` 12 + `UIListLayout` vertical (Padding 8); portrait anchors (0.5, 0) top / (0.5, 1) bottom, landscape (0, 0.5) left / (1, 0.5) right; enter = Position tween from off-screen, 0.3 s Quad Out |
| Title row | `TextLabel` (15 px BuilderSansBold, `TextTruncate` AtEnd) + HARD chip `Frame` (`UICorner` h/2) + chevron `ImageButton` 44×44 (`UICorner` 8) |
| Stat tiles | `Frame` (row 40,34,58) + `UICorner` 8 + 2 `TextLabel`s; NEW BEST badge `Frame` (ok fill, `UICorner` h/2) with `UIScale` pop 0 → 1.1 → 1 |
| Reward lines | `TextLabel` label + `TextLabel` value (count-up via a NumberValue tween, label updated on `.Changed`) + HARD ×2 tag `Frame` |
| XP bar | back `Frame` 6 px (`UICorner` h/2) + fill `Frame` gold with `UIGradient` (gold → 85% brightness) |
| Loot grid | `ScrollingFrame` (portrait: horizontal, `AutomaticCanvasSize` X, ScrollBarThickness 0; landscape/desktop: `UIGridLayout` CellSize per §4) + tile `ImageButton` + `UICorner` 8 + `UIStroke` 2 (`Rarities.COLOR`) + `UIGradient` top sheen + icon `ImageLabel` + count `TextLabel`; reuse `ResultsGrid.merge` / `layout` / "+N" |
| RUN AGAIN / ROLL | `TextButton` (AutoButtonColor false) + `UICorner` 10 + 2 `TextLabel`s (main + sub) + `UIScale` press 0.96; first-run ROLL: `UIStroke` gold Transparency tween ×2 |
| Folded bar | one `Frame` 56 px + `UICorner` 12 + chevron + summary `TextLabel` + RUN AGAIN 144×44 |
| World VFX | victory pose `Animation` on the hero; Legendary drop: one `ParticleEmitter` burst (`Emit(24)`, LightEmission 0.5, Lifetime 0.6) at the hero's root; no UI particles |
| Token fly-in (v1.2) | 5 × `ImageLabel` token_24 in a top-level `Frame` (ZIndex above the wings, `Active = false`); each driven by a `NumberValue` 0 → 1 tween (0.45 s, Quad In) and a quadratic Bézier set on `.Changed` (start = `Camera:WorldToViewportPoint` of the boss-defeat point, clamped; end = ROLL `AbsolutePosition` center); Size tween 24 → 16; `Destroy` on arrival. ROLL: `UIScale` 1 → 1.06 → 1 per arrival, `UIStroke` gold Transparency flash; "+5" pop `Frame` (gold, `UICorner` h/2) `UIScale` 0 → 1.1 → 1. World: one `ParticleEmitter:Emit(16)` gold at the boss-defeat point. Any `InputBegan` on the results UI snaps every token to the end |
| Input | `ContextActionService`: Space / Enter = RUN AGAIN, R = ROLL, C = fold; gamepad A = RUN AGAIN, X = ROLL, Y = fold |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| spinner_64, item icons | as in #397 / item art | reused |
| token_24 (v1.2) | 24×24 | Roll Token fly-in icon (same glyph as the currency pill; gray-box can use a gold `Frame` + `UICorner` h/2) |
| chevron_44 | 44×44 | fold / unfold (shared with #397 collapse bar) |
| hard_chip_skull_32 (optional, shared) | 32×32 | HARD chip glyph; V1 can ship text only |
