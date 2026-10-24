# M15 Element Buffs: Config-driven Shard Draft + pick-rate guard, Spec v1.2

Owner: Prism (design, docs only, no code, no config edits). Builders: Echo (server + `Shared/Config/Buffs.luau`), Ghost (DraftHud). Base: `cursor/live-build-9721`. Status: **proposal, not approved.** Building still waits for the fun test (Ghost's decision 5).
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca388381089ec4e42d24ad049f (Oct 24, 2026, Kevin pre-approved): "M15 pick-1-of-3 element buffs spec (Config-driven, no element over ~50% pick rate, no Robux)."
**Why this lives on `prism/buffs-pick3`:** the pick-1-of-3 element buff draft is already specced here as "Shard Draft" v1.1 (PR #416, `SPEC_v1.md`, direction A, all six questions closed). M15 extends that spec instead of starting a duplicate. `SPEC_v1.md` stays the source for the pick moment, cards, tray and timings. This file adds three things: the full Config contract, the pick-rate guard, and the strip re-dock from the Wave HUD decision.

Sources (link, don't copy):
- Locked: Roadmap 5.1 "Pick 1 of 3 element buffs between waves" (done-when "No element picked more than ~50% of the time"; metric "Buff pick rates"); Vision & Design Rules ("game data stays in Config tables separate from logic", "Never sell exclusive power", elements Ember / Frost / Void, set bonuses 2 / 3 / 4).
- Repo (read only): `Shared/Config/Elements.luau` (`ORDER = ember, frost, void`; Ember = damage + crit_chance, Frost = health + defense, Void = attack_speed + luck; the comment says "Ember, Frost and Void must stay close in value (ROADMAP balance rule)"). `Shared/Config/Rarities.luau` (V1 ORDER Common → Legendary). `Shared/Rarities.luau` `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64). There's no `Buffs.luau` yet.
- Specs: #416 Shard Draft v1.1 (this branch). #428 Wave HUD v1.1 (Q1 decided: buff strip under the wave counter, clear of the action bar). #420 phone layout review rev 1.1 (portrait keep-out top 35% = y 296, provisional; one toast lane). #429 Results v1.1 ("Buffs this run" row).

## 0. Directions (pick one) and recommendation
Mockup: `mockups/m15-01-directions.svg`. All three keep the #416 pick moment. They differ in **how the game stays under ~50% per element**.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Config knobs + pick-rate guard** | Offers stay exactly 1 card per element, so every element is seen equally. Every number (pool, values, odds, scales, caps) is in `Buffs.luau`. A Config test checks that each element's total "power budget" is within ±10% of the others. Analytics log every offer and pick; after ≥ 20 runs, an element at 45% is a **warn** and at 50% is an **act**: tune that element's Config values. | Fair and predictable for players; balance is fixed by editing data, never code; matches the Elements.luau "stay close in value" rule. | Needs a human tuning pass after playtests (no auto-fix). |
| B | Live auto-balance | The server lowers the rarity odds of an over-picked element's card using live pick rates across servers. | Fixes itself. | Hidden rubber-banding ("Ember always rolls Common"); needs cross-server stats (MemoryStore) and more code; harder to test. |
| C | Underdog tier bump | The element you have the fewest pips of gets +1 rarity step, with an "UNDERDOG +1 TIER" tag. | Spreads picks in the open. | Works against element builds and Resonance (set bonuses), which is the point of #416. |

**Recommendation: A.** It answers the done-when with data, keeps the game honest, and keeps all tuning in Config, as Kevin's rule asks. C's tag idea goes to the Ideas Backlog (NOT APPROVED).

## 1. Goal
Every buff a player sees in the Shard Draft comes from one Config table, the three elements stay close enough that **no element is picked more than ~50% of the time**, and nothing in the system can be bought, boosted or rerolled with Robux.

## 2. Where it lives
- **Config (Echo):** new `src/ReplicatedStorage/Shared/Config/Buffs.luau`, data only (Prism doesn't write it; this section is the contract):
  - `POOL`: 12 cards (`id`, `element` ∈ `Elements.ORDER`, `name`, `stat`, `base`, `text` with `{v}`, `twist` for Epic/Legendary, `cap = 2`).
  - `TIER_ODDS.normal` / `TIER_ODDS.hard`: per-card rarity odds (the #416 §6 table), summing to 1.
  - `TIER_SCALE`: Common 1, Uncommon 1.5, Rare 2, Epic 3, Legendary 4.
  - `OFFER`: `perElement = 1`, `draftAfterWaves = {1, 2, 3, 4}`, `rarePlusOnDraft = 4`, `breakSeconds = 8`.
  - `RESONANCE`: `pipsPerItem = 2`, `maxItems = 2`.
  - `GUARD`: `minRuns = 20`, `warnShare = 0.45`, `actShare = 0.50`, `budgetTolerance = 0.10`.
  - `SHARD_SENSE_LUCK_CAP` (Echo's #416 Q4 answer).
- **Server (Echo):** offer roll, pick validation, auto-take and Resonance as in #416. New: the analytics event `buff_offer` / `buff_pick` (offered ids + tiers, picked id, element, auto-taken yes/no, mode) on the existing #383 hooks.
- **Client (Ghost):** the DraftHud reads every string and number from the offer payload (built from Config). It hard-codes nothing but layout.
- **Not here:** Robux, Developer Products, passes, paid rerolls, extra cards, rarity boosts, ads. Card rarity never reads the player's luck stat or the 2× luck pass.

## 3. Flow
| Step | When | What happens | Who |
|---|---|---|---|
| 1 | Server start | `Buffs.luau` loads; the Config test has already checked it in CI (odds sum to 1, 4 cards per element, every `element` in `Elements.ORDER`, budget within ±10%, copy limits, no paid keys). | Echo |
| 2 | Waves 1–4 clear | Offer = 1 card per element (order shuffled), tiers from `TIER_ODDS[mode]`, values `base × TIER_SCALE`. Payload carries name, effect text (with `{v}` filled), twist, tier, element. | Echo |
| 3 | Pick / Later / auto-take | Exactly as #416 §3. The picked card's pip lands on the buff strip, which now docks **under the wave counter** (#428 Q1). | Ghost |
| 4 | Every offer and pick | `buff_offer` + `buff_pick` events logged. | Echo |
| 5 | After each playtest batch (≥ 20 runs) | Pick share per element: < 45% OK · 45–50% **warn** (watch it) · ≥ 50% **act**: lower that element's `base` values (or raise the others) in Config, re-run the budget test, playtest again. No code change, no hidden live adjustment. | Prism reviews, Echo edits Config, Ghost approves |
| 6 | Kevin check | Roadmap Phase 5: "Do the picks change how you play?" plus the share chart in the playtest notes. | Kevin |

## 4. Layout
The pick moment, tray and pill keep the #416 v1.1 numbers. v1.2 changes **only the buff strip dock** (Ghost's #428 Q1, Oct 24, 2026: "re-dock buff strip under the wave counter, clear of the action bar"). Full-screen px; keep-out 390×844 x 117–273, y 296–616 · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526.

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Wave chip (#428) | x 16–150, y 179–223 | x 61–197, y 132–176 | x 66–222, y 132–176 | x 88–268, y 138–182 |
| **Buff strip (v1.2)** | **pip row x 16–84, y 226–240** (14 tall, up to 4 pips); display-only; under the boss bar on wave 5 | **44 px pill at x 61, y 184** (8 px under the chip) | 44 px pill at x 66, y 184 | 44 px pill at x 88, y 190 |
| Strip list (expanded) | long-press the wave chip (#428 Q6, pending) → list x 16–109, from y 244, folds after 4 s | **break-only** (Q2): x 61–192 from y 236 | break-only, x 66–232 | any time, 236 wide from y 242 |
| Draft row, Later, tray, held pill | #416 §4 (unchanged) | same | same | same |

Checks: pip row right 84 < toast lane left 88; bottom 240 < rail top 242; nothing near the action bar / skill grid or the attack cluster on any size; the 44 px pill is the strip's tap target on landscape and desktop; nothing enters the keep-out outside the pick moment. On landscape phones the expanded list would reach the thumbstick zone, so it opens only during the break (Q2).

## 5. States
- **Card:** #416 states, plus **text from Config**: name, effect, twist and the "+1 <Element> pip" footer are payload strings. Missing string → card shows the stat name and value only (never blank, never "nil").
- **Tier chip:** 5 tiers, `Rarities.COLOR` fill; Common/Uncommon/Legendary ink text, Rare/Epic white text.
- **Strip:** hidden (0 buffs) · 1–4 pips · expanded list · Resonance pulse.
- **Guard (designer-facing only, not shown to players):** OK < 45% · Warn 45–50% · Act ≥ 50%.
- **Error:** offer payload fails validation → no draft this wave, toast "Shard Draft skipped" (info lane), the run continues; logged for Echo.

## 6. Numbers
All proposals for Echo's `Buffs.luau`, tuned after the fun test.
- Pool: 12 cards, 4 per element (names locked by Ghost in #416 Q2). Values = #416 §6 "Common value" × `TIER_SCALE`.
- **Power budget test:** for each element, `Σ (card base value in % power × expected tier scale)` where expected tier scale = Σ odds × scale (Normal ≈ 1.41, Hard ≈ 1.62). Each element's total must be within ±10% of the mean. Twists count as +1 Common value each.
- Guard: `minRuns 20`, warn 45%, act 50% (Roadmap "~50%"). Shares are computed from **picks** (auto-takes counted separately, because they pick by rarity, not by choice).
- Copy limits: name ≤ 14 characters, effect ≤ 18, twist ≤ 26 (3 lines on a 116 px phone card). The UI rounds to whole % ; Config keeps decimals.
- Money: 0 Robux paths. No paid reroll, extra card, odds boost, or luck-pass hook. Not even as a parked idea unless Kevin asks.

## 7. Edge cases
- **Config typo / bad element id:** the Config test fails in CI; at runtime an invalid card is skipped and the slot uses the next card of the same element (logged).
- **Element with every card capped (2 each):** #416 rule: the slot shows the next-best element's card. That pick counts toward the real element in the guard.
- **Small samples:** under `minRuns` the guard shows "not enough runs" and no tuning happens.
- **Hard vs Normal:** shares tracked per mode; the act rule applies to each mode.
- **Party:** personal drafts; every player's picks count once.
- **Shard Sense** (Void) feeds run drop luck (capped). If Void passes 50% because of it, tune `SHARD_SENSE_LUCK_CAP` or its base first.
- **No P2W:** a test asserts `Buffs.luau` has no keys like `robux`, `productId`, `passId`, `paid`.

## 8. Mockups
SVG in `mockups/` (fake data, original art): `m15-01-directions.svg` (A/B/C) · `m15-02-card-anatomy.svg` (Config field → card part, one card at all 5 tiers, guard chart) · `m15-03-pick-phone-390x844.svg` (pick moment with the #428 chip in its break state and the pip row under it) · `m15-04-strip-landscape-667x375.svg` (during a wave: chip + 44 px strip 8 px under it, thumbstick zone shown). PNG renders on the box only.

## 9. Build split
Waits for the fun test (decision 5).
- **Echo:** `Buffs.luau` per §2; Config tests (odds sum, 4 per element, budget ±10%, copy limits, no paid keys); offer payload with Config strings; `buff_offer` / `buff_pick` events.
- **Ghost:** DraftHud reads strings from the payload; strip re-dock under the wave chip (#428 Q1); landscape list break-only (Q2).
- **Prism:** card icon set; guard review after each playtest batch with a tuning note on the Agent Board.
- **Havoc:** bad Config rows, capped pool, party picks, mode split in analytics.

## 10. Pass criteria (playtest)
1. Over ≥ 20 runs per mode, no element's pick share is ≥ 50% (Roadmap 5.1 done-when).
2. Changing a card's value or name needs only a Config edit (no code diff).
3. The Config test fails on a bad element id, odds that don't sum to 1, an over-long name, or any paid key.
4. The buff strip sits under the wave counter on all 4 sizes and never covers the action bar, attack cluster or thumbstick during a wave.
5. No screen, button or prompt in the draft mentions Robux.

## 11. Open questions (answer by number)
1. **@Ghost:** Direction A (Config knobs + human-tuned guard) instead of live auto-balance? Recommended: A.
2. **@Ghost:** On landscape phones the expanded buff list would reach the thumbstick zone. Recommended: the list opens only during the 8 s break there; during a wave a tap on the pill just pulses the pips. OK?
3. **@Ghost:** Should auto-taken picks count toward the 50% share? Recommended: no (track them separately), since they follow rarity, not choice.
4. **@Kevin (taste, PROVISIONAL):** Element colors on cards (Ember 255,150,40 · Frost 186,228,255 · Void 150,70,220, from the live arch colors). Keep, or move to a Style Bible palette (#424)?

## Decision log
- 2026-10-24 (Prism): v1.2 (M15) published on `prism/buffs-pick3` as an extension of #416, not a new branch. Recommends A. Applies Ghost's #428 Q1 (strip under the wave counter). Open: Ghost 1–3, Kevin 4 (provisional). Not approved.

## Later (not V1)
Underdog tier tag (direction C), element-leaning offers on element waves, a live balance dashboard page in Notion. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox UI only: Frames, ImageLabels, TextLabels/TextButtons, `UICorner`, `UIStroke`, `UIGradient`, `UIListLayout`, `UIScale`, TweenService, world-space `ParticleEmitter`. No blur, no soft shadows, no web fonts. The mockups are a guide, and these notes win.

| Element | Instances |
|---|---|
| Card (from payload) | #416 card: `TextButton` + `UICorner` 12 + `UIStroke` 2 (`Rarities.COLOR[tier]`) + `UIGradient` sheen + tier chip `Frame` (`UICorner` h/2) + element icon `ImageLabel` + name/effect/twist `TextLabel`s (`TextWrapped`, `TextTruncate` AtEnd as a safety net for long Config strings) + pip footer `Frame` |
| Portrait pip row | `Frame` 14 px (`UICorner` h/2, `UIStroke` 1 row color) + `UIListLayout` horizontal (Padding 4) + up to 4 pip `Frame`s 10×10 (`UICorner` 0.5 scale); parented in the same stack Frame as the wave chip so it moves with it |
| Landscape/desktop strip | #416 44 px pill `TextButton` (`UICorner` h/2, `UIStroke`), anchored 8 px under the wave chip's `AbsolutePosition` + `AbsoluteSize` |
| Strip list | `Frame` + `UIListLayout` rows 44 tall; fold = Size tween 0.15 s; landscape phones: only enabled while the wave HUD phase is `break` |
| Pick feedback | TweenService only (card `UIScale` 1.08, fly-to-strip clone `ImageLabel` 0.35 s) |
| World | 3 shard bursts: `ParticleEmitter` `:Emit(20)` on Impact Core attachments, element colors |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| el_ember_128, el_frost_128, el_void_128 | 128×128 | element icons (shared with #416) |
| card_glyph_* ×12 (optional) | 128×128 | per-card glyphs; V1 can ship element icons only |
