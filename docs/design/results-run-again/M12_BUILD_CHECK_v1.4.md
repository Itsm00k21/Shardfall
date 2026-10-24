# M12 Results Screen + Run Again: Build Check v1.4 (extends PR #429)

Owner: Prism (design, docs only, no code, no Config, no save edits). Builders: Ghost (client `ResultsWings`), Echo (results card fields). Base: `cursor/live-build-9721`. Status: **v1.4 proposal on top of `SPEC_v1.md` v1.3** (Ghost Q1–Q4, Q6–Q7 decided; Kevin Q5 PROVISIONAL). Not an official Vision & Design Rules decision until Kevin copies it there.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca388381e89200df4fe6fe8d29 (Oct 24, 2026 12:50Z, Kevin pre-approved), Next GO (1): "M12 results screen + Run Again spec (waves cleared, loot grid #365, best wave, Run Again + Roll, wipe variant, phone first)."

**Why this is a file on #429, not a new branch:** M12 is already specced on PR #429 (`prism/results-run-again`, `SPEC_v1.md` v1.3 + `TOKEN_FLYIN_v1.2.md`, direction A "Results wings", all Ghost questions closed). A second M12 branch would be a duplicate. This file (1) maps every item in Ghost's GO to the section that already covers it, and (2) checks the spec against the **real results card that now ships in the merge train** (PR #451 `echo/merge-train`, which carries #382 `WaveArena/ResultsCard.luau`, #431 boss-clear pay and `WaveArenaConfig`), and folds the differences in. `SPEC_v1.md` stays the spec of record; where they differ, this file wins.

Code read (read only): `echo/merge-train` @ #451 head: `ShardfallClient/WaveArena/ResultsCard.luau`, `Shared/Config/WaveArenaConfig.luau`, `Shared/ResultsGrid.luau` (#365), `Shared/Rarities.luau`. Specs: #429 v1.3, #449 T3 v1.1 (decided 12:50Z), #416 buffs v2.2, #445 M13 observer sheet, #414 dungeon look, #420 phone review.

---

## 1. Goal
Unchanged from `SPEC_v1.md` §1: in about 3 seconds after any run end (clear, wipe or time-out) a phone player knows how far they got, what they earned and whether they beat their best, and is one tap from RUN AGAIN or ROLL. **v1.4 adds:** the screen reads the live #382 results card (one payload), covers the **time-out** end and the **full-Bag overflow → Essence** line the live code already produces, and drops the live card's center position and "Defeated" wording.

### Ghost's GO mapped to the spec
| Ghost asked for | Where it is | v1.4 change |
|---|---|---|
| Waves cleared | §3 step 1, §4 stat tile "WAVES n/5", §6 | reads `card.wavesCleared` (live field) |
| Loot grid #365 | §4 loot tiles (52/48/56/64 px), Roblox notes "reuse `ResultsGrid.merge`/`layout`/+N" | real V1 drops are few kinds (`shard_chip`, `boss_core`), so the grid is usually 1–3 tiles; overflow rows get an Essence tag (§5) |
| Best wave | §2 session-only `bestWave`/`newBest` (Q2 decided), NEW BEST badge | live card has no best-wave field yet: Echo adds it to the same card (Q8) |
| Run Again + Roll | §3 steps 4–5b, §4 buttons, Q1/Q5 | none (Kevin Q5 still PROVISIONAL) |
| Wipe variant | §3 "Wipe", mockup 02 | title copy + color tone (Q11 @Kevin); live "Defeated" retired |
| Phone first | §4 390×844 column first, mockups 01–03 | new mockup 12: cleared / wipe / time-out + overflow on 390×844 |

## 2. Where it lives
- **Payload (Echo, request):** the client already gets the run end as `hud.card` (#382): `{ cleared, died, reason = "wipe" | "timeout" | "disconnect" | nil, wavesCleared, loot = { tokens, fragments, overflow = { {id, count} }, essence } }`, shown only after the death hold (`WaveArenaConfig.boss.deathHold` = 1.5 s). **v1.4 recommends no second `RunResults` remote:** Echo adds the §2 fields that are still missing to this same card: `tier`, `total` (5), `kills`, `bestWave`, `newBest` (session-only), `rollsReady`, `xp`/`levelAfter`/`xpFrac`, `loot.items = { {id, name, tier, count, hardOnly} }` for the grid, and `bossClear = { granted, tokens }` (Q6). Q8.
- **Screen (Ghost):** `ResultsWings` replaces the #382 `WaveArenaResults` card (a 280×180 `Frame` at scale (0.5, 0.55), GothamMedium 16, a text list) **behind the V1 arena flag; nothing is deleted** (same rule as Q4 for the old `CombatHud` card). `ResultsCard.lines()` can stay as the text fallback / test helper.
- **Not here:** paid revive, "double loot", share card, leaderboards, chests, any Robux.

## 3. Flow (changes only; `SPEC_v1.md` §3 still applies)
| Step | v1.3 | v1.4 |
|---|---|---|
| 1 clear | wings slide in 1.0 s after the boss dies | **1.5 s**: wait for the live card (`boss.deathHold` 1.5 s); the Wave HUD CLEARED chip fills the gap. The wings never start before `hud.card` exists. |
| 1 wipe | after the death hold | same; respawn standing; gray vein fade (#414 §3.6) plays under the wings |
| **1t time-out (new)** | — | the run hits `WaveArenaConfig.timeout` (480 s). Same screen as a wipe with the title **"TIME'S UP · WAVE N"** and the same keep line. No boss fly-in. |
| disconnect | no results on rejoin | unchanged; `reason = "disconnect"` never draws the wings (player is gone); rejoin lands in the hub |
| **2o overflow (new)** | — | if `loot.overflow` has rows, the loot wing shows those tiles with an **"→ Essence"** corner tag and one line under the grid: **"Bag full · 6 chips became +18 Essence"** (count from overflow rows, amount from `loot.essence`). Shown once, no extra animation. |
| first run | ROLL highlighted once | the #449 T3 guide ends on wave 1 clear (`wave1` → `starter()`), so the first results screen comes after `onboardDone`. Use a client session flag "first results this session and `onboardDone` just flipped", not `onboardStep`. ROLL highlight rule stays Kevin Q5 (PROVISIONAL). |

## 4. Layout
No change to `SPEC_v1.md` §4 (all wings outside the keep-out at 390×844, 667×375, 800×400, 1280×720; buttons ≥ 44 px; chevron 44×44; collapsed bar 56 px keeps RUN AGAIN). v1.4 additions:
| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Overflow line | one 12 px line under the tile row, x 28–362, y 703–717; the RUN AGAIN / ROLL row stays at y 718–778 (buttons shrink 64 → 60 tall only when the line shows) | under the 3×2 grid, 11 px, wraps to 2 lines max | same | under the 4×2 grid, 13 px |
| "→ Essence" tag | 14 px tall gold-outline tag on the tile's bottom-left, inside the tile | same | same | 16 px |
| Time-out title | stats wing title row, same slot as "WIPED ON WAVE N" | same | same | same |
| Live #382 card | **retired** (its (0.5, 0.55) center sits inside every keep-out) | — | — | — |

## 5. States (adds to `SPEC_v1.md` §5)
| Element | Normal | Pressed | Hidden | Notes |
|---|---|---|---|---|
| Title: cleared | "SHARD CRATER CLEARED" gold (Q5) | — | — | `card.cleared` |
| Title: wipe | "WIPED ON WAVE N" (color = Q11) + "You keep everything you earned." | — | — | `card.died` or `reason == "wipe"`; replaces live "Defeated" |
| Title: time-out (new) | "TIME'S UP · WAVE N" same tone as wipe + same keep line | — | — | `reason == "timeout"`; replaces live "Timed out" |
| Overflow tile (new) | tile stroke `Rarities.COLOR` + "→ Essence" tag | tap = caption "Held in a full Bag, turned into Essence at run end." | no overflow rows | count merged by `ResultsGrid` |
| Overflow line (new) | "Bag full · N chips became +E Essence" muted text, gold E | — | `loot.essence == 0` | never says "lost" |
| NEW BEST | as v1.3 | — | `newBest` missing or false | needs Echo field (Q8) |

## 6. Numbers
- Waves: `#WaveArenaConfig.waves` = 5 (6/8/10/12, boss + 4 adds). Wave tokens per wave come from `WaveArenaConfig.loot.waveTokens` (Config; the screen shows what the card says, never computes).
- Death hold before the wings: `boss.deathHold` = 1.5 s (live). Time-out: `timeout` = 480 s. Overflow cap: `loot.overflowCap` = 40; `bagSlots` = 100.
- Drop kinds in V1: `shard_chip` (chaser / ranged / tank / add) and `boss_core` (boss), both Common in Config today → tile stroke Common 168,168,176. Rarity colors stay `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64) for gear drops when they arrive.
- Fonts: Builder Sans (the live card's GothamMedium is retired with it). Chrome per STYLE.md (#392): panel 28,24,40 · row 40,34,58 · gold 255,196,64 · danger 230,80,96 · ok 110,210,140.
- Copy added: "TIME'S UP · WAVE N" · "Bag full · N chips became +E Essence" · "→ Essence" · "Held in a full Bag, turned into Essence at run end."

## 7. Edge cases
- **Card arrives without the new fields (Echo not done yet):** wings still draw from the live fields: WAVES, Roll Tokens, Fragments, overflow line. Best wave tile shows "—", no NEW BEST, no XP bar, no fly-in, grid falls back to overflow rows only. Never blocks RUN AGAIN.
- **Overflow past the cap:** live code banks the salvage value on the run; the line shows the total Essence actually paid (`loot.essence`), never a "lost" count.
- **Time-out on wave 5 with the boss at 1 HP:** time-out, no boss pay, no fly-in (same as wipe).
- **Wipe and time-out in the same tick:** whatever `reason` the server settled wins; the screen never shows two titles.
- **Disconnect, then rejoin:** settlement already paid once (#382 one settlement per run id); hub, no results.
- **Hard:** unchanged from v1.3 (HARD badge, ×2 tags on clear tokens/fragments, boss 5 flat).

## 8. Mockups
- **New:** `mockups/12-m12-end-variants-phone-390x844.svg`: three 390×844 phones side by side: cleared (NEW BEST, BOSS +5 chip), wipe on wave 3 (keep line, Q11 tone shown as recommended), time-out on wave 4 with 6 overflow chips → +18 Essence. Keep-out dashed cyan. Fake data.
- Existing 01–11 still apply (landscape, desktop, collapsed, fly-in, Hard).

## 9. Build split
- **Echo:** add the missing fields to the #382 card (Q8): `tier`, `total`, `kills`, `bestWave`/`newBest` (session memory only, schema stays 26), `rollsReady`, XP trio, `loot.items`, `bossClear`. No save writes. Tests: card fields present on clear / wipe / time-out; overflow + essence unchanged.
- **Ghost:** `ResultsWings` reads `hud.card`; time-out title; overflow tiles + line; retire the #382 card and the `CombatHud` card behind the V1 arena flag (delete nothing); wait for `hud.card` before the slide.
- **Prism:** copy check after build; Phase S title art.
- **Havoc:** time-out at 480 s, full Bag with 41+ overflow chips, wipe + disconnect same second, card with only live fields.
- Build waits for M13 (Ghost 12:50Z).

## 10. Pass criteria (adds to `SPEC_v1.md` §10)
1. At 390×844, a tester who timed out says "I ran out of time on wave N and kept my loot" within 3 s.
2. With a full Bag, a tester can say where the extra chips went (Essence) from the screen alone.
3. No results panel enters the center keep-out at any of the 4 sizes (the live #382 card is gone).
4. The screen shows correct numbers when Echo's new fields are missing (fallback rule §7).

## 11. Open questions (answer by number; 1–7 are on `SPEC_v1.md`)
8. **@Ghost (and Echo):** One payload: extend the live #382 `hud.card` with the missing §2 fields instead of a new `RunResults` remote? **Recommended: yes** (one source, already gated by the death hold, matches how T6 extended `RollAnnounce`).
9. **@Ghost:** Time-out gets its own title "TIME'S UP · WAVE N" with the wipe layout (no fly-in, keep line)? **Recommended: yes.**
10. **@Ghost:** Overflow shown as tagged tiles + one "Bag full · N chips became +E Essence" line (no popup, no extra step)? **Recommended: yes.**
11. **@Kevin (taste):** Wipe/time-out title tone: v1.3 has it in danger red; #414 says a wipe gets "no red loss flash, gray fade only". **Recommended: white title with only the wave number in danger red**, plus the gold keep line, so it reads "keep your loot", not "you lost".

## Decision log
- 2026-10-24 (Prism, Ghost GO row https://app.notion.com/p/403c31ca388381e89200df4fe6fe8d29 item 1, Kevin pre-approved): **v1.4 build check** on #429 instead of a duplicate M12 branch. Maps Ghost's 6 asks to v1.3, folds the live #382 card (in #451 merge train): 1.5 s death hold, time-out variant, overflow → Essence line/tags, retire the centered card + "Defeated" copy behind the flag (delete nothing). New Q8–Q10 (@Ghost), Q11 (@Kevin). Not approved.

## Roblox build notes (adds to `SPEC_v1.md`)
Stock Roblox UI only; no blur, no shadows, no web fonts; `ParticleEmitter` only in world space; UI motion with TweenService.
| Element | Instances |
|---|---|
| Overflow line | `TextLabel` 12 px BuilderSans, RichText for the gold Essence number, `TextTruncate` AtEnd (portrait) / `TextWrapped` 2 lines (landscape) |
| "→ Essence" tag | `Frame` 14 px tall + `UICorner` h/2 + `UIStroke` gold 1 + `TextLabel` 10 px, parented inside the tile `ImageButton`, AnchorPoint (0, 1) |
| Time-out title | same `TextLabel` as the wipe title; text swap only |
| Wipe tone (Q11 rec) | title `TextLabel` RichText `WIPED ON WAVE <font color="#E65060">3</font>` |
| Card hook | `ResultsWings.apply(playerGui, hud)` mirrors `ResultsCard.apply` (hidden while `hud.card` is nil); wings tween in on the first non-nil card only |
