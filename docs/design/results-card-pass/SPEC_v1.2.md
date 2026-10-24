# Results Card Visual Pass, Spec v1.2: decisions folded + 390×844 refresh, Hard and time-out variants (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (client UI; `ResultsCard.luau` is Ghost-owned, Prism does not edit it). Echo: one server gap (§3, Q2). Base: `cursor/live-build-9721` @ **`a28a5e2`** (#462 merged on top of `bcef573`; the only change near this card is one new LaunchGate line, so every v1.1 `file:line` still holds). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP40P https://app.notion.com/p/403c31ca388381019967e14f73d4b5e4 (Q1, Q2, Q6 decided; task 2 = 390×844 refresh + Hard/time-out variants). ACK: https://app.notion.com/p/403c31ca3883819ea93ced18efc48254. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on `SPEC_v1.md` and `SPEC_v1.1.md` (same folder). Their tables still stand unless a row below replaces them.

## What changed in v1.2
1. **v1.1 open questions decided** (Ghost, DP40P, Kevin can veto Q6):
   - v1.1 Q1 → **yes**: "Hub in N" counts down `WaveArenaConfig.results.autoReturn` (30, WaveArenaConfig.luau:233) on the client from the first card. **No tap reset.** The server sends the seat home at `returnAt` anyway (RunResults.luau:281 `releaseSeat`).
   - v1.1 Q2 → **yes**: no "XP +N" label while the payload's `xp` is 0 (RunResults.luau:405 "This run does not grant account XP"). The row shows "Lv N" + bar only.
   - v1.1 Q3 (board Q6) → **yes**: landscape phones use the short title **CLEARED**. Kevin can still veto.
2. **Mockup 01 re-rendered** at 390×844 with live numbers: no XP label, CRACK + "N cracks ready", and a wipe pane with a white title + red wave number.
3. **New mockups 06 (Hard clear) and 07 (time-out)** at 390×844, both from live code and config.
4. **New live finding (Q2 below):** Hard doesn't change anything in the arena yet. The card carries `tier = "hard"` and `multiplier = 2`, but no arena code scales pay or enemy HP.

## 1. Goal
Same as v1: in about 3 seconds after a Shard Crater run ends, a phone player sees how far they got, what they earned and whether it's a session best, and is one tap from **RUN AGAIN** or **CRACK**, with the hero left in the clear center. v1.2 covers the portrait phone for all 3 endings (clear, wipe, time-out) and for Hard.

## 2. Where it lives
Unchanged (v1.1 §2): new `ResultsWings` beside `ResultsCard` in `ShardfallClient/WaveArena/`, drawn only when `LaunchGate.m12Results` (LaunchGate.luau:58, off) is on **and** `hud.card.outcome` is set.

## 3. Flow + live numbers used in the mockups
Flow steps 0–7 are as in v1 §3, with v1.1's timer and XP rules now final. Numbers in mockups 01, 06 and 07 come from config @ `a28a5e2` (fake player: Lv 4, 0 Roll Tokens before the run, every chip picked up):
| Ending | Waves | Kills | Roll Tokens | Fragments | Loot | Cracks ready | Source |
|---|---|---|---|---|---|---|---|
| Clear, Normal (01 B) | 5/5 | 41 = 6+8+10+12 + boss + 4 adds | +11 (1, 1, 2, 2, 5) + BOSS +5 | +44 | Shard Chip ×40, Boss Core ×1 (Common) | 16 | WaveArenaConfig.luau:245–251 (waves), :194 (`waveTokens`), :187–193 (drops), :238–241 (names); BossClearReward.luau:27 (boss row 5) |
| Wipe on wave 4 (01 C) | 3/5 | 29 (24 + 5) | +4 | +29 | Shard Chip ×29 | 4 | the unfinished wave pays no purse: `purseDue` Round.luau:259–261 |
| Hard clear, target (06 left) | 5/5 | 41 | +22 ×2 + BOSS +5 | +88 ×2 | as Normal | 27 | Economy.luau:72–80 (`hard`: tokenMultiplier 2, fragmentMultiplier 2, levelGate 5) |
| Hard clear, live today (06 right) | 5/5 | 41 | **+11 with a ×2 tag** | **+44 with a ×2 tag** | as Normal | 16 | `multiplier` on the card (RunResults.luau:435–452), but `Loot.purse` reads `waveTokens` only (Loot.luau:88–96) |
| Time-out on wave 4 (07 left) | 3/5 | 31 | +4 | +31 | Shard Chip ×31 | 4 | `timeout` 480 s (WaveArenaConfig.luau:25), `timedOut` Round.luau:263–269, reason `timeout` at :738/:759 |
| Idle time-out on wave 1 (07 right) | 0/5 | 4 | +0 | +4 | Shard Chip ×4 | 0 → dim CRACK "need 1 more" | `RollConfig.SINGLE_COST = 1` (RollConfig.luau:32), so cracks ready = Roll Tokens (RunResults.luau:400–404) |
Notes:
- **Cracks ready** uses the run-start profile on the first card, and `refresh` re-reads it after settle (v1.1 §3), so the number can rise while the card is open. The mockups show it after the refresh. CRACK pulses once when it rises.
- **Hard is only reachable through RUN AGAIN** today: `enter` always sets `opts.tier = "normal"` (WaveArenaHost.luau:675), and `again` keeps `result.tier` (WaveArenaHost.luau:714) after `HardMode.accept` (RunResults.luau:572). The Shard Gate pad has no Hard picker yet (Hard mode selector spec, `prism/hard-mode-selector`).
- **Session best is per tier** (key `owner:tier`, RunResults.luau:378), so the Hard tile says **HARD BEST** and a first Hard clear shows NEW BEST even when the Normal best is 5.
- **Time-out:** `outcome` reads `wiped` (RunResults.luau:432–433), so the title keys off `reason == "timeout"`. `card.seconds` (RunResults.luau:450) gives the "8:00" in the keep line.

## 4. Layout (390×844, unchanged rects)
| Piece | Rect | Check |
|---|---|---|
| Stats wing | x 16–374, y 107–287 | clear of the keep-out (y 296) |
| Loot + actions wing | x 16–374, y 620–802 | clear of the keep-out (y 616) |
| Title row | 15 px bold; HARD chip 40×18 before the title on Hard | HARD chip + gap + "SHARD CRATER CLEARED" ≈ 257 px (DejaVu stand-in), fits the 284 px left of the 44 px chevron |
| Keep line (wipe / time-out) | 11 px gold under the title: "You keep everything you earned." / "8:00 · You keep everything you earned." | fits (≈ 216 px) |
| Stat tiles | 3 × 106×48 | "HARD BEST" replaces "SESSION BEST" on Hard (the longer label didn't fit 106 px) |
| ×2 tags | 30×17 danger chips after "+N Roll Tokens" and "+N Fragments" on Hard | BOSS +5 stays outlined gold and never gets ×2 |
| Lv row | "Lv 4" right-aligned 11 px over a 7 px bar | no "XP +N" (decided) |
| RUN AGAIN | 190×64, sub-line "Normal · solo" / "Hard · solo" | ≥ 44 |
| CRACK | 136×64, sub-line "N cracks ready" / "1 crack ready" / dim + "need 1 more" | ≥ 44 |
| Chevron | 44×44 | ≥ 44 |
The mockup script checks that both wings stay out of the keep-out, nothing overflows its wing, and every target is ≥ 44 px. All pass.

## 5. States (adds to v1.1 §5)
| State | Look |
|---|---|
| Clear, Normal | gold title "SHARD CRATER CLEARED", gold 2 px wing stroke, win burst (world `ParticleEmitter`) |
| Clear, Hard | the same, plus a HARD chip (danger `230,80,96`, ink text) before the title, ×2 tags, **HARD BEST** tile, RUN AGAIN sub-line "Hard · solo" |
| Wipe | "WIPED ON WAVE " in text `240,236,248` + the number in danger; row-color stroke; gold keep line; no burst |
| Time-out | "TIME'S UP · WAVE " + the red number; keep line starts with the run time ("8:00 · …"); same layout as wipe |
| CRACK count 1 | "1 crack ready" (singular) |
| CRACK count 0 | fill `54,46,78`, "need 1 more", still tappable (goes to the roll page) |
| XP | "Lv N" + bar only while `xp == 0` (decided) |
| Timer | client countdown from `autoReturn`, no reset (decided) |

## 6. Copy
New or changed: "HARD BEST", "×2", "1 crack ready", "need 1 more", "8:00 · You keep everything you earned.". Everything else is from v1.1 §6 and #459 (CRACK, Shard Crater, Hollow Warden). "TIME'S UP · WAVE N" stays the results title; #459 E3 "Out of time" is the old card's `lines()` fallback only.

## 7. Visual style
Unchanged (v1.1 §7). Hard uses only the existing danger red for the chip and tags: no new color, no glow.

## 8. Motion / VFX
Unchanged (v1.1 §8). The ×2 tags pop in with the count-up (`UIScale` 0.8 → 1, 0.15 s) only on Hard. Time-out and wipe have no burst.

## 9. Roblox build notes
v1.1 §9 stands. Adds:
- **HARD chip:** `Frame` 40×18 + `UICorner` (h/2) + `TextLabel` "HARD" (BuilderSansBold 11, ink `32,22,10`), first child in the title row's horizontal `UIListLayout`; `Visible = card.tier == "hard"`.
- **×2 tag:** same chip style, text `"×" .. card.multiplier`, `Visible = card.multiplier > 1`. **Gate it on Q2:** don't show it until the server's numbers really include the multiplier.
- **Keep line:** `TextLabel` 11 px gold; when `reason == "timeout"`, prefix `string.format("%d:%02d · ", m, s)` from `card.seconds`.
- **Best tile label:** `card.tier == "hard"` → "HARD BEST", else "SESSION BEST".
- **CRACK sub-line:** `n == 1` → "1 crack ready"; `n == 0` → "need 1 more" (`RollConfig.SINGLE_COST - tokens`), fill `54,46,78`.
- No blur, no shadows. Prism doesn't edit `ResultsCard.luau`, `HudLayout` or any Ghost-owned file.

## 10. Mobile checks
| Mockup | Viewport | Result |
|---|---|---|
| `mockups/01-live-vs-target-390x844.svg` (refreshed) | 390×844 | live card covers the keep-out; target wings clear; Lv-only XP row; CRACK "16 cracks ready"; wipe title white + red 4 |
| `mockups/06-hard-clear-390x844.svg` (new) | 390×844 | HARD title row fits; ×2 tags fit; target vs what live code shows today |
| `mockups/07-timeout-390x844.svg` (new) | 390×844 | time-out title + "8:00" keep line fit; 0-ready dim CRACK |
Landscape and desktop stay as v1.1 mockups 02–04 (the Hard chip fits the 180–352 px wings at 13 px: the short "CLEARED" + chip is about 113 px). PNG inside an SVG wrapper, fake player data, live config numbers.

## 11. Open questions (answer by number)
v1.1 Q1–Q3 are decided (see "What changed"). New:
1. **@Ghost:** time-out keep line shows the run time ("8:00 · You keep everything you earned.") from `card.seconds`? Prism recommends **yes**: it tells the player why the run ended without a second line.
2. **@Ghost (route to Echo):** Hard pays and plays like Normal in the arena today (`Loot.purse` ignores tier, Loot.luau:88–96, and nothing in `server/WaveArena` reads `hpMultiplier`/`damageMultiplier`), but the card says `multiplier = 2`. Options: (a) Echo applies `Economy.DIFFICULTIES[tier]` multipliers in the arena before Hard ships, and the card shows ×2; (b) hide the ×2 tags until (a) lands. Prism recommends **(b) now, (a) before `hardMode` flips**, so the card never shows a ×2 the player didn't get.
3. **@Kevin (taste, small):** on Hard, keep the HARD chip as plain red text-on-chip (as drawn), or add the optional skull glyph from the Hard spec (`hard_chip_skull_32`)? Prism recommends **plain chip for V1**.

## Decision log
- 2026-10-24 (Prism, DP38P): v1 visual pass (`609b215`). NOT APPROVED.
- 2026-10-24 (Ghost under Kevin's pre-approval, DP39P): v1 Q1–Q5 yes. v1.1 folded them (`af6f0dd`, `2cb8877`).
- 2026-10-24 (Ghost under Kevin's pre-approval, DP40P https://app.notion.com/p/403c31ca388381019967e14f73d4b5e4): v1.1 Q1 yes (client timer from `autoReturn`, no tap reset), Q2 yes (hide "XP +N" while `xp == 0`), Q3 yes (landscape title CLEARED; Kevin can veto).
- 2026-10-24 (Prism, v1.2): folded those, refreshed mockup 01 at 390×844 with live numbers, added 06 (Hard) and 07 (time-out), found the Hard pay/HP gap (Q2). NOT APPROVED until copied into Vision & Design Rules.
