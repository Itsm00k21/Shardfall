# Wave-5 Token Fly-in ("two payouts, one read"), Spec v1.1

> **Superseded by `TOKEN_FLYIN_v1.2.md`** (2026-10-24: 44 px Roll Tokens row, wave-only tokens confirmed, BOSS chip fills gold). Kept as history.

Owner: Prism (design, docs only, no code). Builders: Ghost (client Results UI, fly-in), Echo (`RunResults` payload). Base: `cursor/live-build-9721`. Lives on PR #429 (`prism/results-run-again`) next to `SPEC_v1.md` (Results + Run Again v1.3), whose §3 step 2b / §6 fly-in rows this file **replaces**. Status: **v1.1, Ghost GO** (Agent Board row https://app.notion.com/p/403c31ca388381ecbd1de2f133fd3cb4, 10:50Z Oct 24, 2026, Kevin pre-approved). Not an official Vision & Design Rules decision until Kevin copies it there.

Why v1.1: Ghost answered the M13 token question (same row, answer 3; earlier row https://app.notion.com/p/403c31ca3883819582cac954aba7f160): live wave-5 `Dungeons.waveReward(5)` = **2** is correct, and the **5** is #431's **one-time boss-clear grant on top**. So a first boss clear pays **2 + 5 = 7** Roll Tokens, as two separate payouts. v1.2/v1.3 of the Results spec showed one "+17" with a BOSS +5 chip beside it, which reads either as "17 including 5" or "17 plus 5". v1.1 makes the split impossible to misread and makes the fly-in read only `bossClear.tokens`.

Sources (link, don't copy): PR #431 `Shared/BossClearReward.luau` (`Config/Economy.BOSS_CLEAR_TOKENS` = 5, once per run id, saved before the client hears, wipe = no grant) · PR #434 M13 smoke (live wave-5 = 2) · M13 visual QA checklist v1.1 (PR #436, rows H1/H2) · Results + Run Again v1.3 (`SPEC_v1.md`, §2 `RunResults`, §4 layout, mockups 01, 04, 08, 09) · Wave HUD v1.1 (#428, wave-clear hint) · #420 phone layout review (keep-out, D3 toast lane) · STYLE.md (PR #392) · `Shared/Rarities.luau`.

## 0. Directions (pick one) and recommendation
| | Direction | How it reads | Good | Bad |
|---|---|---|---|---|
| **A** | **Split line + BOSS chip** | Roll Tokens line counts up only the **wave** tokens (`+12`). A separate gold **BOSS +5** chip sits after it, outlined while 5 icons fly to ROLL, filled when the last lands. A 10 px caption under it says "12 from waves (wave 5 +2) · 5 boss clear, once". | Both payouts visible, no merged total to misread, fly-in has exactly one source (`bossClear.tokens`). Fits the existing wing. | One extra 10 px line in the stats wing. |
| B | Merged total + tap caption (v1.3 behaviour) | One "+17" with the chip beside it; split only on tap. | Shortest. | The exact double-count read Ghost flagged; the split is hidden. |
| C | Two separate lines ("Wave tokens", "Boss clear") | Two full reward rows. | Very clear. | Costs ~20 px the portrait wing doesn't have (wing is 180 tall); repeats "tokens". |

**Recommendation: A.** The rest of this spec is A.

## 1. Goal
After a boss clear, a player can say in one read **"I got 12 tokens from waves and 5 for the boss"**, sees the 5 boss tokens fly into ROLL, and never sees a number bigger than what reached their wallet. Repeat clears, wipes and failed saves show no boss part at all.

## 2. Where it lives
- **Results stats wing (Ghost):** the Roll Tokens line of `ResultsWings` (portrait top wing, landscape/desktop left wing), per `SPEC_v1.md` §4.
- **Fly-in layer (Ghost):** a top-level `Frame` above the wings, `Active = false`; path from the boss-defeat point to **ROLL**.
- **Payload (Echo):** `RunResults.tokens` = **wave tokens only** (sum of `waveReward(n)` for cleared waves, Hard ×2 applied, wave 5 = 2 Normal / 4 Hard); `RunResults.bossClear = { granted, tokens }` from #431's saved grant (Ghost Q6 decided). The client total is `tokens + (bossClear.granted and bossClear.tokens or 0)`; it is never sent pre-merged (Q1 below confirms).
- **In-run (Ghost, #428):** the wave-5 clear hint stays "Wave 5 cleared. +G gold, +X XP, **+2 tokens**." It does **not** mention the 5 (that's the Results moment), so the hint and Results never count the same tokens twice.
- **Not here:** no Robux, no boost, no "double your boss reward" upsell. Hard never multiplies the boss 5 (Ghost Q7, v1.3).

## 3. Flow
| Step | Trigger | What the player sees | Data |
|---|---|---|---|
| 1 | Wave 5 boss dies | In-run hint (toast lane): "+2 tokens" (wave 5 `waveReward`). Wallet +2 already. | `waveReward(5)` |
| 2 | Wings land (t = 0.30 s) | Roll Tokens line counts up the **wave** total 0 → `+12` (0.6 s). If `bossClear.granted`: the **BOSS +5** chip appears **outlined** after the value; caption "12 from waves (wave 5 +2) · 5 boss clear, once". World: gold `ParticleEmitter:Emit(16)` at the boss-defeat point. | `tokens`, `bossClear` |
| 3 | t = 0.30–1.07 s | `min(bossClear.tokens, 5)` token icons fly on a curve to ROLL (0.08 s apart, 0.45 s each, Quad In, 24 → 16 px). Each arrival: ROLL `UIScale` 1 → 1.06 → 1 and a gold stroke flash. **The waves value never changes during the flight.** | — |
| 4 | Last icon lands (≈ 1.07 s) | The BOSS chip **fills** gold (ink text). "+5" pop on ROLL's top-right (0.6 s). "N rolls ready" ticks from the waves-only value to the wallet value (e.g. 2 → 3). | wallet = waves + boss |
| 5 | Tap the Roll Tokens line | Caption swaps for 3 s to the sum, written as a sum: "12 waves + 5 boss = 17". This is the **only** place a total appears, and it always shows its parts. | — |
| 6 | Fold the wings | Folded bar: "CLEARED · 5/5 · +12 tokens · BOSS +5 · 12 items" (two parts, never "+17"). | — |
| — | Any tap during the flight | Icons snap to ROLL, chip fills, pop plays once. | — |

**No boss part:** wipe, already paid (`bossClear.granted = false`, e.g. a repeat event or rejoin), or failed save → no chip, no caption boss part ("12 from waves (wave 5 +2)" only if wave 5 was cleared, else "8 from waves"), no fly-in, ROLL shows the wallet value at once. **Hard clear:** waves value shows the red **×2** tag (e.g. `+24`, caption "24 from waves (wave 5 +4)"); the BOSS chip stays **+5 gold** (no ×2, no red).

## 4. Layout
Full-screen px, #420 frame. Keep-out: 390×844 x 117–273, y 296–616 · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. **No panel, chip or caption enters it**; only the flying icons cross it, for < 0.8 s (motion, not a panel).

| Piece | 390×844 (mockup 10) | 667×375 (mockup 11) | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Stats wing | x 16–374, y 107–287 (unchanged) | x 16–196, y 60–361 (unchanged) | x 16–232, y 60–386 | x 16–368, y 66–328 |
| Roll Tokens line | label x 28, baseline y 232; waves value right-aligned at x 296; **BOSS chip 58×16** at x 304–362, y 220–236 | label x 28, y 196; value right-aligned x 184; chip on its own row under it: x 28–86, y 204–220 + "once · wave 5 +2" 10 px | as 667 (wing 216: chip inline fits, use portrait pattern) | as portrait (wing 352) |
| Split caption | 10 px, x 28, y 246, one line, ≤ 334 px | merged into the chip row ("once · wave 5 +2"); full split on tap | one line under the value | one line under the value |
| Fragments / XP | Fragments y 264, XP y 282 (bar y 276); bottom 287 stays above 296 | Fragments y 240, XP y 260, Kills y 296, tap hint y 316 | +22 px each | +22 px each |
| Fly-in path | boss-defeat point (clamped to x 16–374, y 296–616) → ROLL center (294, 746), control point +70 px x | → ROLL center (561, 325), bend −20 px | → ROLL center (676, 354) | → ROLL center (1088, 680), bend −40 |
| "+5" pop | 40×18 at ROLL top-right (x 322–362, y 702–720) | x 611–651, y 289–307 | same pattern | same pattern |

Touch targets: nothing new is tappable except the Roll Tokens line, whose hit box is the full wing-wide row **334×44** (portrait, y 214–258; `TextButton` behind the labels) and **156×44** on 667 (y 182–226). Chevron 44×44, RUN AGAIN 52–64 tall, ROLL 48–64 tall (unchanged). Text ≥ 13 px except the chip (9 px heavy, badge) and the caption (10 px, caption rule R7). Panels fold with the existing 44 px chevron to the 56 px bar.

## 5. States
| Element | Idle | Flying | Landed | Hidden | Hard | Tap |
|---|---|---|---|---|---|---|
| Waves value | count-up 0 → `tokens`, gold 14 px | unchanged | unchanged | — (always shown when > 0) | + red ×2 tag before the value | — |
| BOSS chip | — | outline 1.2 px gold, gold text "BOSS +N" | gold fill, ink text, `UIScale` 1 → 1.1 → 1 | no grant (wipe, repeat, failed save) | same gold (never red, never ×2) | — |
| Split caption | "W from waves (wave 5 +2) · N boss clear, once" | same | same | boss part dropped when no grant | "(wave 5 +4)" | 3 s: "W waves + N boss = T" |
| Token icons | — | 24 → 16 px, `min(N,5)` icons | destroyed | none | same | snap to ROLL |
| ROLL | "R rolls ready" from wallet − N | pulse per arrival | "+N" pop, rolls ready = wallet value | — | same | — |
| Folded bar | "+W tokens · BOSS +N" | — | — | "+W tokens" | "+W tokens ×2 · BOSS +N" | — |
Loading: if `RunResults` is late (> 3 s), show "Results are on the way…" (v1.3) and no chip; when it arrives with a grant, play steps 2–4 then. Error: if `bossClear.tokens` is nil or 0, treat as no grant (no chip, no fly-in).

## 6. Numbers
- Wave 5 `waveReward` = **2** Normal (4 on Hard ×2). Boss clear = `bossClear.tokens` = **5** (`BOSS_CLEAR_TOKENS`), **once per run id**, every tier, never ×2.
- Example Normal first clear: waves 1–5 = 12 (fake data) → wallet +12, then +5 → **17**, shown as `+12` + `BOSS +5`. Repeat clear: `+12` only.
- Icons = `min(bossClear.tokens, 5)`; chip and pop text always use the real `bossClear.tokens` (if Config ever says 8, 5 icons fly and the chip says +8).
- Timings: wings 0.3 s; count-up 0.6 s; flight 0.30–1.07 s (0.08 s stagger, 0.45 s each, Quad In); chip fill 0.15 s; pop 0.6 s; tap caption 3 s. Whole moment < 1.1 s, any tap skips.
- Colors: gold 255,196,64; ink 32,22,10; Hard tag danger 230,80,96 (**PROVISIONAL**, Kevin Hard accent call); panel 28,24,40.
- Copy: "Roll Tokens" · "BOSS +5" · "12 from waves (wave 5 +2) · 5 boss clear, once" · "once · wave 5 +2" (landscape) · "12 waves + 5 boss = 17" · "+5" · "N rolls ready".

## 7. Edge cases
- **Double count guard:** the waves value is `RunResults.tokens` only; the boss part is `bossClear.tokens` only; the UI never adds the boss into the waves number and never shows a bare merged total. If Echo ever sends `tokens` including the boss (Q1), the client must subtract nothing: Echo fixes the payload instead (no client math on rewards beyond display).
- **Already paid / rejoin:** `granted = false` → no chip, no fly-in, no replay (M13 J2).
- **Failed save:** #431 pays nothing, so `granted = false` → nothing shown for the boss.
- **Wipe on wave 5:** no grant; waves value shows waves 1–4 only.
- **Folded mid-flight:** remaining icons retarget to the folded bar's "BOSS +N" text; the chip fills there.
- **ROLL off-screen (folded):** icons fly to the folded bar (v1.2 rule kept).
- **Party:** personal payout; each player sees their own split and fly-in. A member with `granted = false` (e.g. joined late, already paid) sees no boss part while others do.
- **Live build without #431 (M13 #434 pass):** no `bossClear` → wave line only (+2 on wave 5), exactly what M13 H1 checks.
- **Performance:** ≤ 5 `ImageLabel`s for < 1.1 s, one world burst; no Heartbeat loops.

## 8. Mockups
SVG in repo (gray-box, fake data, original art): `mockups/10-flyin-v1.1-phone-390x844.svg` (t = 0.70 s: waves +12 counted, BOSS +5 outlined, 5 icons mid-flight to ROLL, caption with the split) · `mockups/11-flyin-v1.1-landscape-667x375.svg` (t = 1.07 s: chip filled under the value, ROLL "+5" pop, rolls ready 2 → 3). The keep-out is the cyan dashed box. Generator: `gen_flyin_v1_1.py` (box only). Older 08/09 stay as v1.2/v1.3 history.

## 9. Build split
- **Echo:** keep `RunResults.tokens` wave-only and `bossClear = { granted, tokens }` from the saved grant (#431); test: first clear = tokens 12 + boss 5, repeat = boss `granted = false`, wipe = no boss, Hard = waves ×2 and boss 5.
- **Ghost:** Roll Tokens line (value + chip + caption + 44 px row hit box), fly-in reading `bossClear.tokens`, ROLL pulse/pop, folded-bar text, tap caption. Wave-5 hint keeps "+2 tokens" only.
- **Prism:** copy check after the first build; update M13 H2 if anything moves.
- **Havoc:** rejoin during the flight, fold during the flight, repeat event, failed-save stub.

## 10. Pass criteria (playtest)
1. After a first boss clear, 4 of 5 testers can say "12 from waves, 5 for the boss" (or the real numbers) without help.
2. No tester reports a total higher than their wallet change (eyeball wallet before/after).
3. On a repeat clear, nobody sees a BOSS chip or fly-in.
4. At 390×844 and 667×375 nothing but the flying icons enters the keep-out; every tap target ≥ 44 px.
5. M13 H1 (+2 on live) and H2 (fly-in = `bossClear.tokens`) both pass on a #429 + #431 build.

## 11. Open questions (answer by number)
1. **@Ghost / Echo:** Confirm `RunResults.tokens` is **wave tokens only** and the boss 5 is only in `bossClear.tokens` (never pre-merged)? Recommended: yes, it's what makes the no-double-count rule hold without client math.
2. **@Ghost:** OK to make the whole Roll Tokens row a 44 px tap target for the 3 s sum caption, or keep it display-only? Recommended: tappable (it's the only place the total shows).
3. **@Kevin (taste):** BOSS chip fills gold when the tokens land (recommended) or stays outlined the whole time?

## Decision log
- 2026-10-24 (Prism, Ghost GO, board row https://app.notion.com/p/403c31ca388381ecbd1de2f133fd3cb4, Kevin pre-approved): **v1.1** aligns the fly-in with Ghost's M13 answer: live wave-5 `waveReward` 2 is correct, #431's boss clear 5 is a one-time grant on top. Direction A (split line + BOSS chip + caption); fly-in reads `bossClear.tokens` only; no merged total; Hard ×2 only on waves. Replaces Results v1.3 §3 step 2b and the §6 fly-in row. Mockups 10, 11. Not approved as a design rule.

## Roblox build notes
Stock Roblox UI only: no blur, no glass, no soft shadows, no web fonts (Builder Sans / GothamSSm). `ParticleEmitter` only in world space; UI motion = TweenService. The mockups are a guide and these notes win.

| Element | Instances |
|---|---|
| Roll Tokens row | `TextButton` row (AutoButtonColor false, BackgroundTransparency 1, Size full-width × 44) holding: label `TextLabel` 12 px muted; value `TextLabel` 14 px gold (count-up via `NumberValue` tween 0.6 s, text on `.Changed`); optional Hard ×2 tag `Frame` (danger fill, `UICorner` h/2) |
| BOSS chip | `Frame` 58×16 + `UICorner` 8 + `UIStroke` 1.2 gold (flying) → BackgroundColor3 gold + BackgroundTransparency 1 → 0 tween 0.15 s (landed) + `TextLabel` 9 px heavy (gold → ink) + `UIScale` 1 → 1.1 → 1 |
| Split caption | `TextLabel` 10 px, `TextTruncate` AtEnd, `TextScaled` false; text swapped for 3 s on row tap (`task.delay`) |
| Fly-in icons | `min(N,5)` × `ImageLabel` token_24 (or gray-box `Frame` gold + `UICorner` h/2 + inner `ImageLabel` shard) in a top-level `Frame` (`Active = false`, ZIndex above the wings); each: `NumberValue` 0 → 1 `TweenService` (0.45 s, Quad In) driving a quadratic Bézier on `.Changed`; start = `Camera:WorldToViewportPoint(bossPoint)` clamped; end = ROLL `AbsolutePosition + AbsoluteSize/2`; Size 24 → 16; `Destroy` on arrival |
| ROLL receive | `UIScale` 1 → 1.06 → 1 (0.12 s) per arrival + `UIStroke` gold Transparency 0 → 1 flash; "+N" pop `Frame` gold + `UICorner` h/2 + `UIScale` 0 → 1.1 → 1, fades after 0.6 s |
| Optional sheen | `UIGradient` on the filled chip (gold → 85% brightness, Rotation 90); no glow images |
| World burst | one `ParticleEmitter` at the boss-defeat point: `Emit(16)`, gold Color, LightEmission 0.5, Lifetime 0.4–0.6 |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| token_24 | 24×24 | fly-in icon (shared with v1.2) |
| chevron_44, spinner_64 | as in #397 | reused |
