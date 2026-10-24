# Results Card Visual Pass, Spec v1.1: ResultsWings landscape + desktop, CRACK button, live field map (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (client UI; `ResultsCard.luau` is Ghost-owned, Prism does not edit it). Echo: FYI (one server note, §3). Base: `cursor/live-build-9721` @ **`bcef573`** (#458 `echo/m12-results-hardening` merged 08:46 AM PT Oct 24; the brief said `728421a`, and #458 changed `RunResults.luau` and `WaveArenaHost.luau`, so every ref below is re-read at `bcef573`). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP39P https://app.notion.com/p/403c31ca38838185b713c8b940061349, task 1. ACK: https://app.notion.com/p/403c31ca388381adaefad6af1360711a. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on `SPEC_v1.md` (same folder, `609b215`). v1 tables that are not repeated here still stand. Refreshes #429 mockups 04–06 (`prism/results-run-again` @ `5b77004`) with the CRACK verb and live data.

## What changed in v1.1
1. **v1 Q1–Q5 folded as decided** (Ghost, DP39P, under Kevin's pre-approval): Q1 `ResultsWings` is a new module gated on `m12Results` (old card stays, nothing deleted). Q2 second button is **CRACK** with "N cracks ready". Q3 tiles and the old `lines()` both read `loot.items[].name` (fixes `shard_chip` at ResultsCard.luau:40). Q4 wipe title is **white with only the wave number in red**. Q5 clear title is **SHARD CRATER CLEARED** in caps; the sentence-case line retires.
2. **Landscape + desktop re-render** (mockups 02–04, replace #429 04–06): wings, CRACK button, real V1 loot (Shard Chip, Boss Core, both Common), real stats.
3. **Live field map** (mockup 05, §3): every element names its card field and `file:line` at `bcef573`, plus the 8 Run Again results from `RunResults.again`.
4. **Three corrections from the live code** (§3 notes): XP row shows no "+N" (the payload's `xp` is always 0), the "Hub in N" timer can't use `returnAt` on the client (server clock), and the timer no longer resets on tap (the server sends the seat home at `returnAt` regardless).

## 1. Goal
Unchanged from v1: in about 3 seconds after a Shard Crater run ends, a player sees how far they got, what they earned and whether it is a session best, and is one tap from **RUN AGAIN** or **CRACK**, with the hero and win burst left in the clear center. v1.1 makes that true on landscape phones and desktop, and proves every number comes from the server card.

## 2. Where it lives
Same as v1 §2: new `ResultsWings` beside `ResultsCard` in `ShardfallClient/WaveArena/`, same `apply(playerGui, hud)` hook, drawn only when `LaunchGate.m12Results` (LaunchGate.luau:58, off) is on **and** `hud.card.outcome` is set. With the flag off, `RunResults.apply` leaves the card alone (RR:463–466) and `again()` is a no-op (RR:517–519), so the old card is the only UI.

## 3. Flow + live field map
Flow steps 0–7 are as in v1 §3. Field map (mockup `05-live-field-map.svg`):
| Wing element | Card field (`hud.card`) | Live source @ `bcef573` | Rule |
|---|---|---|---|
| Title | `outcome`, `reason`, `wave` | RR:432–433; Round.luau:113–121 (`cardOf`) | `outcome` is only `cleared`/`wiped`; a time-out also reads `wiped`, so the TIME'S UP title keys off `reason == "timeout"` |
| WAVES n/5 | `wavesCleared`, `total` | RR:430–431 | `total` defaults to `#WaveArenaConfig.waves` (5) |
| SESSION BEST + NEW BEST | `bestWave`, `newBest` | RR:369–384 (`noteBest`) | in session memory per player and tier, never saved |
| KILLS | `kills` | RR:449 | whole number |
| +N Roll Tokens, ×mult tag | `loot.tokens`, `multiplier` | Round.luau:124; RR:437–440 | tag only when `multiplier > 1` (`normal` = 1, Economy.luau `DIFFICULTIES`) |
| BOSS +5 chip + fly-in | `bossClear.granted`, `.tokens` | RR:457; BossClearReward.luau:155–169 | only when the grant saved |
| +N Fragments | `loot.fragments` | Round.luau:125 | — |
| Loot tiles | `loot.items[] = {id, name, tier, count, hardOnly}` | RR:333–367 (`itemsOf`) | `name` from `WaveArenaConfig.results.lootNames` (WaveArenaConfig.luau:238–241); stroke = `Rarities.COLOR[tier]` |
| Bag full line | `loot.overflow`, `loot.essence` | Round.luau:127–128 | short form on landscape (§6) |
| Lv N + bar | `levelAfter`, `xpFrac` | RR:386–407 (`personal`) | **`xp` is always 0** ("This run does not grant account XP", RR:405): show "Lv N" + bar only, no "XP +N" until a run grants XP |
| CRACK · N cracks ready | `rollsReady` | RR:453; `refresh` RR:489–505, called from WaveArenaHost.luau:643 | the first card uses the account snapshot from run start; `refresh` re-reads the profile after settle, so N can rise while the card is open. Re-read it on every hud update and pulse CRACK (`UIScale` 1.06) when it rises |
| Hub in N bar | none (see note) | RR:458 | **`returnAt` = server `os.clock()` + 30**: the client clock is different, so the client counts down `WaveArenaConfig.results.autoReturn` (30, WaveArenaConfig.luau:233) from the first card. The server sends the seat home at `returnAt` (`releaseSeat` RR:281, `recall` WaveArenaHost.luau:607–634) whatever the player taps, so **v1's "any tap resets" is dropped** |
| RUN AGAIN | action `"again"` | WaveArenaHost.luau:694–733; RR:516–597 | states below |

**RUN AGAIN results** (`RunResults.again` at `bcef573`):
| Result | Button shows |
|---|---|
| `started = true` (WH:729–733) | "Starting… 3" from `countdown` (`soloCountdown` 3), then the new run |
| `duplicate = true` | stays loading; no second request |
| `error = "payout"` (RR:583) | "Saving…" for 1 s, then one auto-retry (the payout settles first) |
| `error = "rate"` (RR:577–580) | ignore (1 s `runAgainGap`) |
| `"teleport"`, `"state"`, `"owner"` | button greys; only the timer / Crater Square path stays |
| `"party"` (RR:567) | "Going to the Shard Gate…" (today `party` is always 1, WH:676) |
| `"eligible"` (RR:570–574) | sub-line "Normal (Hard needs Lv 5)" |
| `noop` (flag off) | never drawn: the old card is up |

**Echo note (no ask):** a `returnIn` seconds field would let a late card show the right timer. Not needed for V1; the client countdown is off by at most the death hold.

## 4. Layout
Unchanged rects (v1 §4 / #429 §4), now drawn at all 3 sizes. Keep-out from #420.
| Piece | 667×375 (mockup 02) | 800×400 (mockup 03) | 1280×720 (mockup 04) |
|---|---|---|---|
| Stats wing | x 16–196, y 60–361 | x 16–232, y 60–386 | x 16–368, y 66–328 |
| Loot + actions wing | x 471–651, y 60–361 | x 568–784, y 60–386 | x 912–1264, y 352–704 |
| Keep-out (clear) | x 200–467, y 105–274 | x 240–560, y 112–292 | x 384–896, y 202–526 |
| Title | CLEARED (short) | CLEARED (short) | SHARD CRATER CLEARED |
| Stats | 3 rows × 30 px | 3 rows × 30 px | 3 tiles 104×52 |
| Tiles | 48 px, 3×2 | 56 px, 3×2 | 64 px, 4×2 (`ResultsGrid.TILE`) |
| RUN AGAIN | 156×52 | 192×52 | 328×64 "RUN AGAIN [Space]" |
| CRACK | 156×48 + "N cracks ready" | 192×48 + "N cracks ready" | 328×48 "CRACK · N ready [R]" |
| Chevron | 44×44 | 44×44 | 44×44, key C |
The mockup script checks that both wings are clear of the keep-out, nothing spills out of its wing, and every button is at least 44 px. All pass. The 390×844 portrait layout is v1 mockup 01 (unchanged; its "XP +40" label is wrong per §3 and should read "Lv 4").

## 5. States
v1 §5 stands, with these v1.1 changes: **wipe title** = "WIPED ON WAVE " in text `240,236,248` + the number in danger `230,80,96` (Q4); **time-out** = "TIME'S UP · WAVE N" with the same split; **clear** = "SHARD CRATER CLEARED" gold, "CLEARED" on landscape phones (the full title is about 183 px at 13 px bold, and a 180 px wing leaves about 104 px beside the 44 px chevron); **XP** = no "+N" while `xp == 0`; **CRACK** gets a "rising" state (pulse once when `rollsReady` goes up); **timer** has no reset state; **tile tap** puts "Shard Chip · Common" in the Bag-full line slot for 2 s (no extra row, so 667×375 still fits).

## 6. Copy
v1 §6 stands with Q4/Q5 decided. New lines: "CLEARED" (landscape title), "Bag full · +E Essence" (landscape short form of "Bag full · N chips became +E Essence", which is about 207 px at 11 px: neither the 156 px nor the 192 px landscape column can hold it), "Saving…" (payout not settled yet), "CRACK · N ready [R]" (desktop one-liner). Old card: `lines()` switches to `name` when present (Q3), so "shard_chip x6" reads "Shard Chip x6" even with the flag off.

## 7. Visual style
Unchanged from v1 §7 (panel `28,24,40`, `UICorner` 12, `UIStroke` 2 gold on clear / row `40,34,58` on wipe, BuilderSans, RUN AGAIN gold `255,196,64` + ink `32,22,10`, CRACK violet `108,78,196`). Tier strokes from `Rarities.COLOR` (Rarities.luau:38–43): Common `168,168,176`, Uncommon `64,186,98`, Rare `72,142,255`, Epic `186,96,240`, Legendary `255,196,64`. V1 arena drops are all Common, so the mockups show grey strokes; that is the honest look today.

## 8. Motion / VFX
v1 §8 stands. Changes: the timer bar is a single linear `Size.X.Scale` tween over 30 s with no restart; the CRACK "rising" pulse is `UIScale` 1 → 1.06 → 1 over 0.25 s once per rise; the win burst is a world-space gold `ParticleEmitter` (`Emit(16)`) on the HumanoidRootPart, shown in the keep-out in the mockups because it is world art, not UI.

## 9. Roblox build notes
v1 §9 stands (Frames + `UICorner` + `UIStroke` + `UIPadding` + `UIListLayout`; `ImageButton` tiles with tier `UIStroke`; `TextButton` + `UIScale` press; `UIGradient` on the clear title row; world `ParticleEmitter`). v1.1 adds:
- **Layout function per breakpoint:** portrait (`< 500` wide) top/bottom wings; landscape phone (`HudLayout.breakpoint == "phone"`, wide) left/right wings at full height minus 60 top / 14 bottom; desktop corners as in §4. Re-fit on `ViewportSize`.
- **Landscape stat rows:** 3 `Frame` rows 30 px tall (label left 10 px muted, value right 15 px) in place of the 104×52 tiles, which don't fit a 180 px wing.
- **Timer:** read `WaveArenaConfig.results.autoReturn` (shared config, ReplicatedStorage) and tween from the first non-nil card. Do not read `card.returnAt` on the client.
- **CRACK count:** bind to `hud.card.rollsReady` on each hud push; compare with the last value to fire the pulse.
- **Run Again:** handle the 8 results in §3; one request in flight at a time (also covered on the server by `duplicate`).
- No blur, no shadows. Prism does not edit `ResultsCard.luau`, `HudLayout`, or any Ghost-owned file.

## 10. Mobile checks
| Viewport | Wings clear of keep-out | Smallest tap | Text fit |
|---|---|---|---|
| 390×844 | yes (v1 mockup 01) | chevron 44×44 | v1 §6 |
| 667×375 | yes (mockup 02) | CRACK 156×48, chevron 44 | short title + short Bag line (§5, §6) |
| 800×400 | yes (mockup 03) | CRACK 192×48 | short title + short Bag line |
| 1280×720 | yes (mockup 04) | CRACK 328×48 | full title + full Bag line |
Ghost confirms text with `TextService:GetTextSize` in Studio, the same as #459 v1.1 §5. Mockups: `mockups/02-wings-landscape-667x375.svg`, `03-wings-landscape-800x400.svg`, `04-wings-desktop-1280x720.svg`, `05-live-field-map.svg` (PNG inside an SVG wrapper; fake data shaped like the live payload).

## 11. Open questions (answer by number)
v1 Q1–Q5 are decided. New, small:
1. **@Ghost:** "Hub in N" counts down `autoReturn` (30) on the client from the first card, and tapping no longer resets it, which matches the server's `releaseSeat`. OK? Prism recommends **yes**. The other option is asking Echo for a tap-to-extend server action, and that's out of V1 scope.
2. **@Ghost:** hide the "XP +N" label while the payload's `xp` is 0 and show only "Lv N" + bar? Prism recommends **yes**.
3. **@Kevin (taste):** landscape phones use the short title **CLEARED** because the full SHARD CRATER CLEARED (about 183 px) doesn't fit beside the chevron in a 180–216 px wing. Alternatively it could wrap to 2 lines and push the stats down 16 px. Prism recommends **CLEARED**.

## Decision log
- 2026-10-24 (Prism, DP38P task 3): v1 visual pass (`609b215`). NOT APPROVED.
- 2026-10-24 (Ghost under Kevin's pre-approval, DP39P): v1 Q1–Q5 yes (ResultsWings gated on `m12Results`; CRACK "N cracks ready"; tiles read `loot.items` name; white title + red wave number; SHARD CRATER CLEARED caps).
- 2026-10-24 (Prism, v1.1): folded Q1–Q5, re-read refs at `bcef573` (#458), landscape + desktop re-render (02–04 replace #429 04–06), live field map (05), 3 corrections from live code (xp 0, server-clock `returnAt`, no tap reset). NOT APPROVED until copied into Vision & Design Rules.
