# Pick-1-of-3 Buffs ("Shard Draft"), Spec v1.1

Owner: Prism (design). Builders: Ghost (UI + VFX), Echo (server + Config). Base: `cursor/live-build-9721` @ `581c995`. Docs only, no code.
Asked for in: Ghost's Kevin-approved decisions row, decision 5 (https://app.notion.com/p/403c31ca38838189b1c5ed1249a17e57): "Prism specs the pick-1-of-3 buffs (5.1) now, as design only. **Building waits for the fun test.**"
Scope: Roadmap **5.1 "Pick 1 of 3 element buffs between waves."** 5.2 Fusion cards are out (see Later).

Sources (link, don't copy):
- Locked: Roadmap Phase 5 (5.1; done-when "No element picked more than ~50% of the time"; metric "Buff pick rates"; risk "Twists slow the run → keep the run near 5 min"); V1 Core Loop §2 Elements / Set bonuses (2 / 3 / 4 matching) / Element Freedom & Stat Affinity, §3 Party & Run Setup (5–8 s loot break, personal loot, no run timer, no early exit, keep all loot); Vision & Design Rules ("never sell exclusive power").
- Repo: `Shared/Config/Elements.luau` (Ember = damage + crit_chance, Frost = health + defense, Void = attack_speed + luck), `Shared/Config/Rarities.luau` (V1 ORDER Common → Legendary), `Shared/Rarities.luau` `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64). Element colors = live arch colors: Ember 255,150,40 · Frost 186,228,255 · Void 150,70,220.
- Chrome: PR #392 `docs/ui/reference/STYLE.md`; toasts and collapse bar from #397; arena look from #414 (Shard Crater v1.1).

## 0. Directions (pick one) and recommendation
| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Shard Draft (element cards + Resonance)** | After waves 1–4, 3 cards (one Ember, one Frost, one Void), each with a rarity. Pick 1. Each pick adds a run-only buff **and** a pip of its element; every 2 pips of one element count as +1 matching item for set bonuses (max +2). | Ties buffs to the locked element + set-bonus build; pick rates per element are easy to measure (5.1 done-when); teaches set bonuses by doing. | Needs a small card pool (12) and Config tuning. |
| B | Stat cards | 3 generic stat cards (damage, HP, speed…) with rarity. | Fastest to build. | No element identity; doesn't serve "element buffs" or the build loop; picks feel samey. |
| C | Shard altars in the world | 3 crystals rise in the arena; walk into one to take it. | Very diegetic, no UI. | Slow on phones, party members fight over altars, hard to read rarity at phone zoom, eats the 5–8 s break. |

**Recommendation: A, "Shard Draft".** It's the only one that answers 5.1 as written (element buffs), it feeds the build (set bonuses) and the economy loop (Void "Shard Sense" raises drop luck, so a run pays more rolls), and it stays a 1-tap moment. C's best idea (shards bursting from the Impact Core) is kept as the world VFX that introduces the cards. The rest of this spec is A.

## 1. Goal
Between waves, a player makes one quick, readable choice (≤ 2 s, 1 tap) that visibly changes how the next wave plays, pushes them toward an element build, and never slows the run or the party.

## 2. Where it lives
- **Server (Echo):** a run-only buff state per player inside the wave run (proposed `BuffService` + `Shared/Config/Buffs.luau`). Offers are rolled and validated on the server. **Nothing is saved**; buffs end when the run ends (win or wipe). No new currency, no Robux, no paid reroll.
- **HUD (Ghost):** new `ScreenGui` **DraftHud** with three parts:
  1. **Draft row** (the 3 cards) — the one brief UI allowed in the center, only during the pick moment.
  2. **Held-draft pill + tray** — if the player taps **Later** or the break ends unpicked, the row folds into a 44 px "Pick a buff ›" pill on the right edge; tapping it opens a compact tray **above** the keep-out.
  3. **Buff strip** — a 44 px "✦ n ●●" pill top-left under the Roblox menu; tap expands a left-docked list of taken buffs.
- **World:** at the pick moment 3 shard bursts (Ember/Frost/Void colors) jump from the Impact Core (#414) — world `ParticleEmitter`s, no screen effect.
- **Results screen (Phase 4.2):** one row "Buffs this run" with the taken cards as mini tiles.
- Not shown in the first 30 seconds flow (#412): the first-ever run gets its first draft after wave 1 with one-time help text (§3).

## 3. Flow
Runs have 4 drafts: after waves 1, 2, 3 and 4 (none after the boss).

| t (s, from wave clear) | Beat | What the player sees / does | Server |
|---|---|---|---|
| 0.0 | Wave clear | Veins flash, loot auto-collects (#414). | grant loot (once per drop) |
| 0.6 | Draft in | 3 shard bursts jump from the Impact Core; a dark scrim (Frame, transparency 0.55) fades in 0.2 s; header "SHARD DRAFT · pick 1" + break bar; 3 cards fly up 0.25 s, staggered 0.06 s. Epic/Legendary cards get a rotating gold `UIGradient` stroke. | roll offer: 1 card per element, rarity per §6 |
| 0.9–~3 | Pick | Tap a card (or keys 1/2/3, gamepad ←/→ + A). The card pops 1.08×, the other two fade to 0.35, the card shrinks and flies to the buff strip (0.35 s). A pip lands on the strip. | validate offerId + index, apply buff |
| +0.3 | Resonance (if hit) | Toast in the one toast lane (review D3; info priority, waits behind a loot chip): "Ember Resonance · 2 pips = +1 Ember item for set bonus" (2 s). If a set bonus tier turns on, the existing Set Bonus box flashes. | recompute set bonus with pips |
| any | Later | "Later ›" (120×44) folds the row into the right-edge pill with a gold dot. The scrim fades. | offer stays held |
| break end (8 s, Config) | Timeout | Unpicked row folds to the pill (same as Later). Next wave starts on time for everyone. | offer held |
| during next wave | Held | Pill "Pick a buff ›" stays at the right edge. Tap → tray of 3 mini cards (157×48) opens in the top band. Tap one = pick. Tray chevron/outside tap folds it. | |
| next wave clear | Auto-take | If an offer is still held, it auto-takes the **highest-rarity card** (tie → the element the player has the most pips of, then left-most), toast "Auto-picked: Chill Touch" (toast lane, info). Then the new draft opens. Max 1 held offer. | |
| run end | Results | Results row "Buffs this run" (4 mini tiles). Text: "Buffs end with the run. Loot is yours." | clear buff state |

First-ever draft (one time per account, saved flag via existing onboarding/tips): under the header, "Pick one. It lasts this run." for 3 s. No other help.

Cancel / back: Later and the tray chevron are the only "back". A pick can't be undone (1 tap = final, the fly-to-strip is the confirmation). Dead players can still pick (they respawn next wave).

## 4. Layout
Full-screen px (see **Frame** below); build in `ScreenInsets = CoreUISafeInsets`. **Center keep-out** (x 30–70%, y 28–73%) stays empty at all times **except the draft row during the pick moment** (scrim on, max 8 s). The tray, pills, toasts and strip never enter it.

**Frame (phone layout review F19):** the numbers below are **full-screen px**, the same frame as the keep-out box. (0,0) is the screen's top-left, including the Roblox top bar (52 px on phones, 58 on desktop; about 99 on a notched portrait phone). Build in `CoreUISafeInsets` by subtracting the top inset. The live HUD (portrait + HP top-left, currency pills top-right, mid-left rail, 2×4 skill bar + attack cluster bottom-right) is the computed `HudLayout` / `CombatCluster` layout at `581c995` (see the review).

| Element | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Header + break bar | center, y 250, bar 300×6 | center, y 56, bar 300×6 | center, y 56, bar 360×6 | center, y 208, bar 480×6 |
| Draft row | 3 × **116×196**, gap 8, y 284 (bottom 480) | 3 × **136×132**, gap 12, y 86 (bottom 218, above the skill bar's top at 227) | 3 × **150×160**, gap 14, y 86 (bottom 246, above the jump button at 256) | 3 × **200×280**, gap 20, y 254 (UIScale clamp) |
| Later | 120×44, centered, y 490 (above the skill bar's top at 566) | 120×44 at the right end of the header band, x 531, y 56 | 120×44 at the right end of the header band, x 664, y 56 | 140×44 "Later (Esc)", centered, y 552 |
| Held pill | 100×44 "Buff ›", right edge, y 235, under the currency pills (x 274–374, clear of keep-out x ≤ 273) | 158×44, right edge, y 136 (4 px under the currency pills) | 158×44, right edge, y 136 | 158×44, right edge, y 150 |
| Tray (from pill) | one row of 3 × 116×48 (gap 8), x 16–374, y 235–283: it opens **in place of** the pill (review D1: keep-out top 296, so the bottom 283 clears it). While open it covers the top of the mid-left rail and the toast lane waits; it folds after a pick, an outside tap or 4 s | one row of 3 × 157×48, 547×52, at y 52–104 (between the top bar and the keep-out). While open it covers the HP bar and currency pills; it folds after a pick, an outside tap or 4 s | 600×52 at y 52–104, same rule | top band 640×64, y 110 |
| Buff strip pill | 8 px under the live HP block: (16, 179), compact ≤ 74 wide (✦ + count; pips show from 667 up). On a first run with the #412 Oracle pill there, x 184 | x 61 (8 px right of the live rail), y 132 (y 184 on a first run, under the #412 goal tab) | x 66, y 132 (184 on a first run) | x 88 (right of the rail), y 138 |
| Strip list (expanded) | width = min(236, keep-out left − x − 8) = 93: icon + stack count rows, 44 tall | 131 wide | 166 wide | 236 wide |
| Resonance toast | toast lane (D3): x 88–266, y 231–283 (178×52) | toast lane, top band: x 411–651, y 8–60 (240×52) | toast lane: x 524–784, y 8–60 (260×52) | toast lane: top-center x 480–800, y 66–118 (320×52) |

Dock rule (Q5, Ghost): (12, 52) is the default. If a live arena HUD item (wave counter, HP bar) occupies the top-left, the strip anchors 8 px under that item's bottom edge at the same x, and never moves into the center keep-out.
- **Resolved with live numbers (F16):** the live portrait + HP block always sits at CoreUISafe (16,16) and is 56 tall, so (12, 52) overlapped it on every size. The strip therefore always docks 8 px under it. Where the mid-left rail crosses that band (landscape phones and desktop), it moves 8 px right of the rail.
- A future wave counter (#417's `WaveCounter`, no client UI yet) joins that top-left stack above the strip.
- The expanded list is never wider than `keep-out left − x − 8`. It folds on an outside tap or after 4 s.

Rules: whole card is the tap target (≥ 116×196 on the smallest phone). Card text ≤ 3 short lines: name (15–18 px bold), main effect (12–14 px, tier-tinted), sub line (11–13 px muted). Footer chip "+1 <Element> pip". On landscape the draft row ends above the live 2×4 skill bar and jump button (bottom-right), and Later moves into the header band, so nothing covers the attack cluster or the thumbstick (bottom-left) (F19). The tray sits in the top band for the same reason. The portrait tray is one row of 3 mini cards (F15). The old stacked 3 × 52 version ended at y 256, inside the keep-out.

**Notice column (landscape phones, F17):** from 8 px right of the keep-out to 16 px inside the safe right edge, under the currency pills. Since review D3 it holds only the held pill. Notices (the #414 loot chip, the Resonance and Auto-picked toasts) go through the one toast lane: max 1 on screen, the rest queue, loot/rarity before info.

## 5. States
- **Card:** incoming (fly-in) · idle (tier stroke 2 px, tier chip, element icon) · Epic/Legendary idle (+ rotating gradient stroke, soft glow ImageLabel) · pressed (0.96×, 0.06 s) · picked (1.08× + 3 px ring, then fly) · faded (other two at 0.35) · disabled (server busy: spinner on the picked card, others locked; 1.5 s timeout → retry once, then "Try again" toast and the row stays).
- **Row:** open (scrim) · folded (pill) · tray open · auto-take.
- **Buff strip:** empty (hidden) · 1–4 pips · expanded list · resonance flash (pip ring pulse 2×).
- **Party:** each player has their own draft; no waiting, no voting. A small "2/4 picked" text sits under the header for the curious (no pressure, no timer change).
- **Reduced motion:** no fly paths (cross-fade), no gradient rotation, bursts at half count.

## 6. Numbers
All placeholders for Echo's `Shared/Config/Buffs.luau` (Config-only tuning). Starting estimates.

**Offer rules:** 3 cards per draft, exactly one per element, order shuffled. No duplicate card inside one offer. A card already taken can appear again (stacks, cap 2 per card per run).

**Card rarity odds per card** (independent, not affected by player luck stat, luck pass or anything paid):
| Tier | Normal | Hard (Lv 5) |
|---|---|---|
| Common | 50% | 35% |
| Uncommon | 30% | 32% |
| Rare | 15% | 22% |
| Epic | 4.5% | 9% |
| Legendary | 0.5% | 2% |
Draft 4 (before the boss) guarantees at least one Rare+ card. Hard shifts odds up (Roadmap 5.6 "better shard odds on harder runs").

**Rarity scale:** Common ×1 · Uncommon ×1.5 · Rare ×2 · Epic ×3 + twist line · Legendary ×4 + twist line.

**Card pool V1 (12 cards, 4 per element, follows Element Freedom & Stat Affinity):**
| Element | Card | Common value | Epic/Legendary twist |
|---|---|---|---|
| Ember | Kindle | +8% damage | crits ignite |
| Ember | Flashburn | +5% crit chance | crit hits splash 2 st |
| Ember | Ignite | hits burn 2 s, 3% dmg/s | burn spreads on kill |
| Ember | Cinder Heart | +6% Ember damage | kills drop a short fire patch |
| Frost | Rime Hide | +10% max HP | +1 shield charge per wave |
| Frost | Frostguard | −6% damage taken | block a hit every 8 s |
| Frost | Chill Touch | hits slow 15% for 1.5 s | 3rd hit freezes 0.6 s |
| Frost | Glacier Heart | heal 4% HP at wave clear | one freeze nova at 30% HP |
| Void | Quickcut | +6% attack speed | every 5th hit is double |
| Void | Shard Sense | +8 drop luck (this run's drops) | +1 fragment per wave cleared |
| Void | Hollow Mark | marked enemies take +6% | marks jump on kill |
| Void | Rift Echo | 5% of hits repeat | echoes can crit |

**Resonance:** each card = 1 pip of its element. Every 2 pips of one element = +1 matching item for set bonuses, **max +2 per element** (so 4 Ember pips + 2 Ember gear = 4-matching). Pips never replace gear: with 0 gear of that element, max is the 2-matching tier.

**Timing:** draft in 0.6 s after clear; break 8 s (Config, top of Core Loop's 5–8 s; the run stays ~5 min since the break already exists); fly-in 0.25 s; pick fly 0.35 s; toasts 2 s.

**Rolling tie-in:** Shard Sense raises this run's drop luck (tokens/fragments/gear drops, server-side, capped in Config) and its twist pays +1 fragment per wave; both feed the next roll. Card rarity itself never uses luck, so the paid 2× luck pass doesn't buy better buffs.

## 7. Edge cases
- **Party:** personal drafts, simultaneous. Nobody waits for a slow picker; the next wave starts on the normal break.
- **Server authority:** client sends `{offerId, index}` only; server checks the offer belongs to the player and the run, is unspent, and the wave matches. Double taps / two devices → first valid pick wins, the rest are ignored.
- **Disconnect / rejoin mid-run:** taken buffs and a held offer are restored from the run state (not the save). Rejoin after the run ended → nothing to restore; loot already granted (Havoc risk 2).
- **Wipe:** buffs end with the run; loot kept (Kevin's rule). No "lost buffs" messaging, results just lists them.
- **Boss wave:** no draft after wave 5. A held draft from wave 4 auto-takes at boss start (not at the clear), so wave 5 always has all 4 buffs.
- **Dead player:** can pick; buff applies on respawn.
- **Max stacks:** a card at cap 2 is excluded from offers; if an element has no eligible card, that slot shows the next-best element's card (rare; logged).
- **Phone performance:** the draft row is 3 Frames + ~10 ImageLabels; bursts ≤ 3 × 20 particles. No per-frame Heartbeat.
- **Analytics (Roadmap "Buff picked")**: log offered cards + tiers, picked card, pick time, auto-taken yes/no, element pips at run end. Used for the "no element > ~50%" check.
- **No P2W:** no reroll, no extra card, no rarity boost for Robux or passes, ever, without Kevin explicitly asking.

## 8. Mockups
SVG (in repo, fake data, original art): `mockups/01-pick-phone-390x844.svg` (pick moment, portrait, 3 cards Rare/Common/Epic, Later, strip) · `mockups/02-held-landscape-667x375.svg` (held draft tray in the top band during a wave, attack button and thumbstick clear) · `mockups/03-picked-landscape-800x400.svg` (Legendary picked, others faded, fly-to-strip) · `mockups/04-desktop-1280x720.svg` (pick with 1/2/3 key hints, strip list expanded, Ember Resonance toast). PNG renders on the box only.

## 9. Build split
**Waits for the fun test** (decision 5). Then:
- **Echo (server + Config):** `Shared/Config/Buffs.luau` (pool, odds, scales, caps, break length, Resonance cap), run-only buff state, offer RNG, pick remote with validation, auto-take, set-bonus recompute with pips, drop-luck hook for Shard Sense, analytics event. Tests: odds sum, one-per-element offers, cap 2, auto-take rule, no save writes.
- **Ghost (client):** DraftHud (row, Later, pill, tray), buff strip, resonance toast, results row, world bursts, keyboard/gamepad input.
- **Prism:** card icon set (3 element icons + 12 card glyphs, 128×128 PNG), tuning review after the first playtest.
- **Havoc:** dupes/double picks, rejoin restore, auto-take at boss start, long-run leak test of DraftHud.

## 10. Pass criteria (playtest)
1. At 390×844, a tester reads all 3 cards and picks in ≤ 2 s (median), 1 tap.
2. No draft UI is in the center keep-out outside the pick moment; the tray, pill, strip and toasts never enter it; every tap target ≥ 44 px; attack button and thumbstick never covered (667×375, 800×400).
3. The next wave starts on time even if nobody picks; a held draft auto-takes at the next clear (or at boss start).
4. Over ≥ 20 test runs, no element is picked more than ~50% (Roadmap 5.1 done-when).
5. Runs stay near 5 min (no added wait).
6. Testers say the picks change how they play (Roadmap Phase 5 Kevin check).
7. A Resonance pip visibly turns on a set-bonus tier at least once in a typical run.

## 11. Open questions (answer by number)
1. ~~@Kevin: Resonance yes, or keep buffs separate?~~ **Yes (Ghost under Kevin's pre-approval, Oct 23, 2026; Kevin can change later).** 2 pips of one element = +1 matching item for set bonuses, max +2 per element. Board row: https://app.notion.com/p/403c31ca3883815687a3f85a05f4323e
2. ~~@Kevin: Card names keep or rename?~~ **Keep all 12 (Ghost under Kevin's pre-approval).** Kindle, Flashburn, Ignite, Cinder Heart, Rime Hide, Frostguard, Chill Touch, Glacier Heart, Quickcut, Shard Sense, Hollow Mark, Rift Echo.
3. ~~@Echo: 8 s break and held-offer auto-take?~~ **Yes (Echo, Oct 23, 2026).** 8 s break is a Config value; a held offer auto-takes the highest rarity, ties go to the first card, decided on the server. Board row: https://app.notion.com/p/403c31ca388381dba1c1f358d0618f00
4. ~~@Echo: Shard Sense run-drops only, luck cap in Config?~~ **Yes (Echo).** Shard Sense touches run drops only, never RollService; the cap lives in Config with a validation test and is tuned after the fun test.
5. ~~@Ghost: Buff strip at (12, 52), any clash?~~ **OK provisionally (Ghost).** Rule: if any live arena HUD item (wave counter, HP) sits top-left, the strip docks directly under it and never enters the center keep-out. See §4.

All questions answered. This spec is closed (direction A, Shard Draft). Building still waits for the fun test.

## Decision log
- 2026-10-23 (Ghost, Kevin pre-approved): Prism specs pick-1-of-3 buffs (5.1) now, design only; building waits for the fun test. Prism recommends direction A (Shard Draft); not approved yet.
- 2026-10-23 (Echo): Q3 = **yes** (8 s Config break; held offer auto-takes highest rarity, ties to first card, server-decided). Q4 = **yes** (run drops only, never RollService; Config cap + validation test). Q1, Q2 (Kevin) and Q5 (Ghost) are still open.
- 2026-10-23 (Ghost, Kevin pre-approved; Kevin can change later): Q1 Resonance = **yes** (max +2). Q2 = **keep all 12 card names**. Q5 = (12, 52) OK provisionally; strip docks under any top-left arena HUD item (wave counter, HP), never in the keep-out. Spec closed → v1.1.

- 2026-10-23 (Prism, phone layout review, docs/design/phone-layout-review/REVIEW_v1.md): F15: the portrait tray is a single row. F16: the strip docks under the live HP block (it overlapped at (12, 52)) and to the right of the rail on landscape and desktop, with the list width capped. F17: the Resonance toast and notices use the landscape notice column. F18: the held pill docks under the currency pills (it overlapped them on every size). F19: the §4 frame is now full-screen px, and the landscape draft row and Later are clear of the live skill bar and jump button. Layout numbers only; direction A is unchanged.
- 2026-10-24 (Ghost, Kevin pre-approved, board row https://app.notion.com/p/403c31ca38838103a80ad21380d7f451; folded by Prism from the phone layout review rev 1.1, docs/design/phone-layout-review/REVIEW_v1.md §8/§10): D1: the portrait keep-out top is 35% (y 296), so the portrait tray opens in place of the pill at y 235–283 (§4). D3: the Resonance and Auto-picked toasts go through the one toast lane (max 1 on screen, the rest queue, loot/rarity first), and the notice column keeps only the held pill (§3, §4). D2 (hub cluster) doesn't touch this arena spec.

## Later (not V1)
5.2 Fusion cards (two buffs combine, e.g. Ember + Frost = "Steam"), element-leaning offers matching the wave's element (would pair with decision 7's Config-only element waves), a draft-history Codex page, cosmetic card backs (never power).

## Roblox build notes
Stock Roblox UI only. No blur or glassmorphism (BlurEffect blurs the 3D world, not the GUI), no soft shadows, no web fonts (Builder Sans / GothamSSm). `ParticleEmitter` only in world space; UI sparkle = tweened ImageLabels. The mockups are a guide, and these notes win.

| Element | Instances |
|---|---|
| Root | `ScreenGui` DraftHud (ResetOnSpawn false, ZIndexBehavior Sibling, `ScreenInsets = CoreUISafeInsets`, DisplayOrder above CombatHud) → `Frame` root + `UIScale` (desktop clamp so cards max 200×280) |
| Scrim | full-screen `Frame` 10,8,16, BackgroundTransparency 1 → 0.55 (0.2 s), `Active = false` so world input still works if a card isn't hit |
| Header | `TextLabel` "SHARD DRAFT · pick 1" + break bar `Frame` (UICorner h/2) with inner `Frame` Size tween 1 → 0 over the break |
| Draft row | `Frame` + `UIListLayout` Horizontal, Padding 8–20, HorizontalAlignment Center |
| Card | `TextButton` (AutoButtonColor false, Text "") + `UICorner` 12 + `UIStroke` 2 (tier color) + `UIGradient` top sheen (tier color → panel) + tier chip `Frame` (UICorner h/2) + `TextLabel` + element icon `ImageLabel` in a circle `Frame` (UICorner 0.5 scale, UIStroke element color) + name/effect/sub `TextLabel`s (TextScaled false, TextWrapped true) + pip chip `Frame` |
| Epic/Legendary stroke | second `UIStroke` 3 on an outer `Frame` with `UIGradient` (gold stops), Rotation tween 0 → 360, 3 s, repeat −1 (off on reduced motion) + `ImageLabel` glow_soft_256, transparency 0.8 |
| Pick feedback | TweenService: card `UIScale` 1 → 1.08 (0.08 s), others GroupTransparency 0.65 via `CanvasGroup` (allowed, no blur), clone `ImageLabel` icon flies to the strip pill AbsolutePosition (0.35 s, Quad Out) |
| Later / pill / tray | `TextButton` 44 tall + `UICorner` h/2 + `UIStroke` gold 2 + `UIPadding` 12; tray `Frame` + `UIListLayout` (Horizontal landscape, Vertical portrait), mini cards `TextButton` 157×48 |
| Buff strip | `TextButton` pill + 4 pip `Frame`s 12×12 (UICorner 0.5); list `Frame` 236 wide + `UIListLayout` rows 220×46 |
| Resonance toast | #397 toast style (`Frame` + `UICorner` 12 + `UIStroke` element color 2 + icon + 2 `TextLabel`s) |
| World bursts | 3 `Attachment`s on the Impact Core, each `ParticleEmitter` Rate 0, `:Emit(20)`, Color = element color, LightEmission 0.6, Speed 18–26, Lifetime 0.6 |
| Input | `ContextActionService` binds 1/2/3 and Esc (desktop) and gamepad; touch = the buttons |
| Animation | TweenService only. No per-frame Heartbeat |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| el_ember_128, el_frost_128, el_void_128 | 128×128 | element icons on cards, tray, strip |
| card_glyph_* ×12 | 128×128 | optional per-card glyph (V1 can ship with the element icon only) |
| glow_soft_256, shard_frag_a/b/c, spinner_64 | as in #397 | reused |
