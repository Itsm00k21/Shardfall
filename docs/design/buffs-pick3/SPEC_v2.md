# Pick-1-of-3 Element Buffs ("Shard Draft"), SPEC v2 (M15)

Owner: Prism (design, docs only, no code, no config edits). Builders: Echo (server, Config, LaunchGate line, telemetry), Ghost (DraftHud client). Base: `cursor/live-build-9721`. Status: **v2.2, proposal for building after the fun test.** Not an official Vision & Design Rules decision until Kevin approves it and it is copied there.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca3883818abc23e33d062c9c26 (11:40Z Oct 24, 2026, Kevin pre-approved): "M15 pick-1-of-3 element buffs, design only: offer cadence between waves, buff list in a Config table, server-authoritative pick, LaunchGate flag default off, per-player picks in parties, a pick-rate target of no element over ~50% plus the telemetry to check it, cards in Ember #E84814 / Frost #5CD6FF / Void #C04888. If a buff spec already exists, revise it instead of a new PR."
**v2.1 note (Oct 24, 2026, 5:10 AM PT):** Ghost answered Q4 and Q5 (board row https://app.notion.com/p/403c31ca3883812fa966d50ee503d110). (a) Landscape held-buff list = break only; combat keeps just the small held pill. (b) Auto-takes are out of the 50% share and counted separately in `buff_run_summary`. §5, §6 telemetry and §11 are updated below; nothing else changed.
**v2.2 note (Oct 24, 2026, 5:35 AM PT):** Echo answered Q3 (board row https://app.notion.com/p/403c31ca3883818383eaedad9f4adf44): yes to `buffDraft` and to parking `BuffPick` via `PARKED_ACTION`. Spec fix: `guard()` checks the rate limit **before** the park (`Remotes.luau:166-172`), so the pick contract in §7 now lists rate limit first, then `buffDraft`. §7, §9 and §11 updated; nothing else changed.
**What v2 is:** one consolidated spec that replaces reading `SPEC_v1.md` (v1.1, pick moment) and `M15_ELEMENT_BUFFS_v1.2.md` (Config contract + guard) side by side. Both files stay on this branch as history. Every earlier decision is carried forward unchanged (see the Decision log). New in v2: the LaunchGate flag, the full Config table, the server pick contract, party rules in one place, the telemetry events and fields, and the new element colors.

Sources (link, don't copy):
- Locked: Roadmap 5.1 "Pick 1 of 3 element buffs between waves" (done-when "No element picked more than ~50% of the time"; metric "Buff pick rates"); Roadmap Analytics ("Server-side only"; custom event "Buff picked (Phase 5)"); Roadmap PARK rule ("Switch off with a LaunchGate flag. Don't delete."). V1 Core Loop §2 (elements, set bonuses 2/3/4) and §3 (5–8 s loot break, personal loot, no run timer). Vision & Design Rules ("game data stays in Config tables", "never sell exclusive power").
- Repo (read only, `cursor/live-build-9721`): `Shared/LaunchGate.luau` (`LaunchGate.SHOW`, every flag `false` by default, e.g. `waveArena`, `equip`). `Shared/Config/Elements.luau` (`ORDER = ember, frost, void`). `Shared/Rarities.luau` `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64). `Remotes.luau` `guard()` (type check → `RateLimiter.take` → LaunchGate park → `xpcall`; parked remotes answer "That is closed."). No `Buffs.luau` yet.
- Specs: #416 v1.1 + v1.2 (this branch). #428 Wave HUD (buff strip under the wave counter, Q1; element colors). #435 element color study (Ember #E84814, Void #C04888 V3). #420 phone layout review rev 1.1 (keep-out, one toast lane, portrait keep-out top y 296). #429 Results ("Buffs this run" row).

## 1. Goal
Between waves, each player makes one fast, readable choice (≤ 2 s, 1 tap) that changes how the next wave plays and nudges an element build, without slowing the run or the party. Every number lives in one Config table, the server decides everything, the whole feature ships **off** behind a LaunchGate flag, and the three elements stay close enough that **no element is picked more than ~50% of the time**, which telemetry proves.

## 2. Where it lives
| Piece | Owner | What |
|---|---|---|
| `Shared/LaunchGate.luau` | Echo (one line) | **New flag `LaunchGate.SHOW.buffDraft = false`** (comment: "M15 Shard Draft between waves. Off until Kevin flips it after the fun test."). Default **off**. |
| `Shared/Config/Buffs.luau` | Echo (data only) | The Config table in §6. Prism doesn't write it; §6 is the contract. |
| Server (proposed `BuffService`, inside the wave run) | Echo | Offer roll, pick validation, held offer + auto-take, Resonance recompute, telemetry. Run-only state. **Nothing is saved.** |
| Remote `BuffPick` (RemoteFunction) | Echo | Goes through `Remotes.guard()`; parked on `buffDraft` like the other parked actions. |
| Client `ScreenGui` DraftHud | Ghost | Draft row, Later, held pill + tray, buff strip (under the #428 wave chip), Resonance toast. Reads every string, number and color from the offer payload. Not built at all while the flag is off. |
| World | Ghost | 3 shard bursts from the Impact Core at the pick moment (world `ParticleEmitter`s). |
| Results (#429) | Ghost | "Buffs this run" row (mini tiles). Hidden while the flag is off. |
| Not here | — | Robux, Developer Products, passes, paid rerolls, extra cards, rarity boosts, ads. Card rarity never reads the luck stat or the 2× luck pass. |

## 3. Flow
**Offer cadence:** a run has **4 drafts**, one after each of waves 1, 2, 3 and 4. **No draft after wave 5 (boss).** Each draft opens in the existing loot break (Core Loop 5–8 s); the break length is Config (`OFFER.breakSeconds = 8`) and the next wave **never waits** for a pick.

| t (from wave clear) | Beat | Player | Server |
|---|---|---|---|
| 0.0 | Wave clear | Veins flash, loot auto-collects (#414). | Grant loot. If `buffDraft` is off: stop here (today's game). |
| 0.6 | Draft in | 3 shard bursts jump from the Impact Core; scrim fades in (0.2 s); header "SHARD DRAFT · pick 1" + break bar; 3 cards fly up (0.25 s, 0.06 s stagger). Party line "2/4 picked" under the header. | Roll **this player's** offer: 1 card per element, shuffled; tier per card from `TIER_ODDS[mode]`; draft 4 guarantees ≥ 1 Rare+. Send payload `{offerId, wave, cards[3]}`. Log `buff_offer`. |
| 0.9 → ~3 | Pick | Tap a card (keys 1/2/3, gamepad ←/→ + A). Card pops 1.08×, others fade, card flies to the strip, a pip lands. | Validate (§7), apply buff, recompute set bonus with pips, log `buff_pick` (`method = tap/key/pad`). Reply `{ok, cardId}`. |
| +0.3 | Resonance | If 2 pips of one element: toast in the one toast lane (info priority) "Ember Resonance · +1 Ember item for set bonus" (2 s). | — |
| any | Later | "Later ›" folds the row to the held pill (right edge, under the currency pills). | Offer stays held (max 1). |
| break end | Timeout | Unpicked row folds to the pill. Next wave starts on time for everyone. | Offer held. |
| next wave | Held | Pill "Pick a buff ›" → tray of 3 mini cards (top band) → tap = pick (`method = tray`). | Same validation. |
| next clear / boss start | Auto-take | A still-held offer auto-takes the highest-rarity card (ties → first card; server-decided, Echo Q3). Toast "Auto-picked: Chill Touch". From wave 4 it auto-takes at **boss start**, so the boss wave has all 4 buffs. | Apply, log `buff_pick` with `method = auto`. |
| run end | Results | "Buffs this run" row. "Buffs end with the run. Loot is yours." | Log `buff_run_summary`; clear buff state. |

First-ever draft (one time per account, existing tips flag): "Pick one. It lasts this run." for 3 s. Cancel/back = Later or the tray chevron. A pick can't be undone (the fly-to-strip is the confirmation).

## 4. Layout
Unchanged from v1.1 §4 + v1.2 §4 (full-screen px, the #420 frame; build in `CoreUISafeInsets` by subtracting the top inset). Summary for the 4 check sizes:

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Center keep-out (empty except the draft row during the pick moment, ≤ 8 s) | x 117–273, y 296–616 | x 200–467, y 105–274 | x 240–560, y 112–292 | x 384–896, y 202–526 |
| Draft row | 3 × 116×196, gap 8, y 296–492 | 3 × 136×132, gap 12, y 86–218 (above the skill bar top 227) | 3 × 150×160, gap 14, y 86–246 (above the jump button 256) | 3 × 200×280, gap 20, y 254 (UIScale clamp) |
| Later | 120×44 centered, y ~500 | 120×44 right end of header band | 120×44 right end of header band | 140×44 "Later (Esc)" |
| Held pill | 100×44, right edge, y 235 | 158×44, right edge, y 136 | 158×44, right edge, y 136 | 158×44, right edge, y 150 |
| Tray | 1 row of 3 × 116×48, y 235–283 (in place of the pill; may cover the rail top ≤ 4 s, Q6) | 3 × 157×48 at y 52–104 | 600×52 at y 52–104 | 640×64 top band |
| Buff strip | pip row x 16–84, y 226–240 under the wave chip (display-only) | 44 px pill at x 61, y 184 | 44 px pill at x 66, y 184 | 44 px pill at x 88, y 190 |
| Toasts | one toast lane (D3): x 88–266, y 231–283 | x 411–651, y 8–60 | x 524–784, y 8–60 | x 480–800, y 66–118 |

Rules: every tap target ≥ 44 px (whole card = target); panels **collapse** (row → pill, tray → pill, list → pill), never just close; nothing but the draft row enters the keep-out, and only during the pick moment; nothing covers the attack cluster, skill bar, jump or thumbstick on landscape. Mobile first: design at 390×844, then 667×375, 800×400, desktop.

**Element colors (v2, Ghost GO):** Ember **#E84814** (232,72,20) · Frost **#5CD6FF** (92,214,255) · Void **#C04888** (192,72,136). They replace the v1.1 arch colors on the card's element icon circle, the corner shard, the "+1 <Element> pip" footer, strip pips and the Resonance toast stroke. **Rarity stays on the 2 px card stroke + tier chip (`Rarities.COLOR`)**, so element and rarity never share a channel (mockup v2-01). Closest pair is Frost #5CD6FF vs Rare 72,142,255: the tier word on the chip always carries rarity. Void follows the #428/#435 value (V3); if Kevin picks the V2 override there, cards follow the same Config value with no card change.

## 5. States
- **Feature:** `buffDraft` off (shipped default): no offers, no DraftHud, no strip, no Results row, `BuffPick` answers "That is closed.", no telemetry. On: everything below.
- **Card:** incoming · idle (tier stroke 2 px, tier chip, element icon) · Epic/Legendary idle (+ rotating gold `UIGradient` stroke, soft glow ImageLabel) · pressed 0.96× · picked 1.08× + ring → fly · faded 0.35 · busy (spinner on the picked card, others locked; 1.5 s timeout → retry once → "Try again" toast, row stays). Missing Config string → stat name + value (never blank or "nil").
- **Row:** open (scrim) · folded (held pill) · tray open · auto-taken.
- **Landscape held-buff list (v2.1, Ghost Q4):** expanded only during the break; in combat it collapses to the small held pill (no list over the play space).
- **Strip:** hidden (0 buffs) · 1–4 pips · expanded list (landscape phones: break-only) · Resonance pulse.
- **Party:** own draft per player; "n/N picked" counter only, no waiting, no voting.
- **Error:** offer payload fails validation → no draft this wave, toast "Shard Draft skipped" (info), run continues, logged.
- **Reduced motion:** cross-fades instead of fly paths, no gradient rotation, bursts at half count.

## 6. Numbers: proposed Config table for Echo (`Shared/Config/Buffs.luau`)
Proposal only, not code. Echo builds the table in Luau with these keys; values are starting estimates tuned after the fun test.

**6.1 Top-level keys**
| Key | Proposed value | Notes |
|---|---|---|
| `OFFER.perElement` | 1 | 3 cards = one Ember, one Frost, one Void; order shuffled |
| `OFFER.draftAfterWaves` | {1, 2, 3, 4} | none after wave 5 (boss) |
| `OFFER.breakSeconds` | 8 | top of Core Loop's 5–8 s; never extends the break |
| `OFFER.openDelay` | 0.6 | s after wave clear |
| `OFFER.rarePlusOnDraft` | 4 | draft 4 guarantees ≥ 1 Rare+ card |
| `OFFER.maxHeld` | 1 | held offer auto-takes at next clear / boss start |
| `OFFER.capPerCard` | 2 | a card at cap is excluded from offers |
| `TIER_ODDS.normal` | Common 0.50 · Uncommon 0.30 · Rare 0.15 · Epic 0.045 · Legendary 0.005 | sums to 1 |
| `TIER_ODDS.hard` | Common 0.35 · Uncommon 0.32 · Rare 0.22 · Epic 0.09 · Legendary 0.02 | sums to 1 (Roadmap 5.6) |
| `TIER_SCALE` | Common 1 · Uncommon 1.5 · Rare 2 · Epic 3 · Legendary 4 | value = `base × scale`; Epic/Legendary add the twist |
| `RESONANCE.pipsPerItem` / `.maxItems` | 2 / 2 | 2 pips = +1 matching item for set bonuses, max +2 per element |
| `SHARD_SENSE_LUCK_CAP` | Echo sets (Q4) | run drops only, never RollService |
| `COLORS.ember / .frost / .void` | #E84814 / #5CD6FF / #C04888 | card element channel (§4); Ghost reads from payload |
| `GUARD.minRuns` / `.warnShare` / `.actShare` / `.budgetTolerance` | 20 / 0.45 / 0.50 / 0.10 | §6.3 |
| `TEXT_LIMITS.name` / `.effect` / `.twist` | 14 / 18 / 26 chars | 3 lines on a 116 px phone card |

**6.2 `POOL` (12 rows, 4 per element; names kept per Q2)**
| id | element | name | stat | base (Common) | text (`{v}` = base × scale) | twist (Epic/Legendary) | cap |
|---|---|---|---|---|---|---|---|
| ember_kindle | ember | Kindle | damage | 8 | +{v}% damage | crits ignite | 2 |
| ember_flashburn | ember | Flashburn | crit_chance | 5 | +{v}% crit | crits splash 2 st | 2 |
| ember_ignite | ember | Ignite | burn_dps | 3 | burn 2 s, {v}%/s | burn spreads on kill | 2 |
| ember_cinder | ember | Cinder Heart | ember_damage | 6 | +{v}% Ember dmg | kills leave fire | 2 |
| frost_rime | frost | Rime Hide | health | 10 | +{v}% max HP | +1 shield per wave | 2 |
| frost_guard | frost | Frostguard | defense | 6 | −{v}% dmg taken | block a hit every 8 s | 2 |
| frost_chill | frost | Chill Touch | slow | 15 | slow {v}% 1.5 s | 3rd hit freezes | 2 |
| frost_glacier | frost | Glacier Heart | clear_heal | 4 | heal {v}% at clear | freeze nova at 30% HP | 2 |
| void_quickcut | void | Quickcut | attack_speed | 6 | +{v}% atk speed | every 5th hit doubles | 2 |
| void_sense | void | Shard Sense | run_luck | 8 | +{v} drop luck | +1 fragment per wave | 2 |
| void_mark | void | Hollow Mark | mark_damage | 6 | marked +{v}% dmg | marks jump on kill | 2 |
| void_echo | void | Rift Echo | repeat_chance | 5 | {v}% hits repeat | echoes can crit | 2 |

Every `element` must be in `Elements.ORDER`. Stats follow Element Freedom & Stat Affinity (Ember damage/crit, Frost health/defense, Void attack speed/luck).

**6.3 Pick-rate target and check**
- **Target (Roadmap 5.1 done-when):** over ≥ 20 runs per mode, **no element's pick share ≥ 50%**. Share = an element's **manual** picks ÷ all manual picks in that mode. Auto-takes are tracked separately (they follow rarity, not choice).
- **Bands:** < 45% OK · 45–50% **warn** (watch) · ≥ 50% **act**: lower that element's `base` values (or raise the others) in Config, re-run the budget test, playtest again. No code change, no hidden live auto-balance.
- **Budget test (Config test in CI):** per element, Σ (base × expected scale) with expected scale Normal ≈ 1.41 / Hard ≈ 1.62 (twist = +1 Common value) must sit within ±10% of the mean of the three elements.
- **Secondary reads:** per-card pick rate when offered (a card picked < 15% when shown is a dead card → buff or rename), median pick time (target ≤ 2 s), held/auto-take rate (target < 25%, else the cards are too hard to read).

**6.4 Telemetry: events and fields (server-side only, Roadmap Analytics)**
| Event | When | Fields |
|---|---|---|
| `buff_offer` | each offer sent | `runId`, `userId`, `mode` (normal/hard), `wave` (1–4), `offerId`, `partySize`, `cards` = 3 × {`cardId`, `element`, `tier`}, `buildVersion` |
| `buff_pick` | each applied pick | `runId`, `userId`, `mode`, `wave`, `offerId`, `cardId`, `element`, `tier`, `slotIndex` (1–3, checks position bias), `method` (tap / key / pad / tray / auto), `pickMs` (offer shown → pick), `wasHeld` (bool), `pipsAfter` {ember, frost, void}, `setBonusTierUp` (bool) |
| `buff_reject` | a pick the server refuses | `runId`, `userId`, `offerId`, `reason` (not_owner / spent / wrong_wave / bad_index / closed / rate_limited) |
| `buff_run_summary` | run end | `runId`, `userId`, `mode`, `result` (cleared / died / left), `picks` (list of manual cardIds), `autoTakes` (count, **kept out of the 50% share**, v2.1), `autoTakeCards` (list of auto-taken cardIds, v2.1), `pipsFinal`, `resonanceItems`, `runSeconds` |

Roblox `AnalyticsService:LogCustomEvent` carries a name, a value and a few custom fields, so map: event `BuffPicked`, value 1, custom fields **Element / Tier / Mode** (what the share chart needs). The full rows above go to the server's own playtest log (same place as the other M13 run events) so the guard can be computed per mode, per card and per slot. No personal data beyond the Roblox `userId` already used by saves.

## 7. Edge cases
- **Server authority (pick contract):** the client sends only `{offerId, index}`. Server checks, in order: rate limit (`guard`, `RateLimiter.take`), then `buffDraft` on (else "That is closed."; same order as `Remotes.guard()` at `Remotes.luau:166-172`, v2.2), the offer belongs to this player and this run, it is unspent, its wave matches the current/held wave, `index` ∈ 1–3. First valid pick wins; double taps or a second device are ignored (logged `buff_reject`). The client never sends a cardId, tier or value.
- **Party (per-player picks):** each player rolls their own offer with their own RNG draw; picks are simultaneous; nobody waits; a slow picker never delays the next wave. Buffs apply to the picker only (no shared or aura buffs in V1). Each player's picks count once in telemetry. A late joiner gets drafts from the next wave clear on.
- **Disconnect / rejoin mid-run:** taken buffs and a held offer restore from run state (not the save). After the run → nothing to restore.
- **Wipe / leave:** buffs end with the run, loot is kept (Kevin's rule). Results just lists them.
- **Boss:** no draft after wave 5; a held wave-4 offer auto-takes at boss start.
- **Dead player:** can pick; buff applies on respawn.
- **Every card of an element capped:** that slot shows the next element's card (rare, logged); the pick counts toward the real element in the guard.
- **Bad Config row:** CI Config test fails; at runtime an invalid card is skipped and the next card of that element fills the slot (logged).
- **Flag flipped mid-run:** reads at run start only; a run that started with it off stays off.
- **Small samples:** under `GUARD.minRuns` the share chart says "not enough runs"; no tuning.
- **Phone performance:** 3 Frames + ~10 ImageLabels; bursts ≤ 3 × 20 particles; no per-frame Heartbeat.
- **No P2W:** no reroll, extra card, odds boost or luck-pass hook, ever, unless Kevin asks. A Config test asserts `Buffs.luau` has no `robux`, `productId`, `passId` or `paid` keys.

## 8. Mockups
SVG in `mockups/` (fake data, original art, gray box): **new in v2:** `v2-01-element-colors.svg` (3 element cards at the same tier with the new hexes + each element across the 5 V1 tiers + read checks) · `v2-02-pick-phone-390x844.svg` (pick moment, new colors, "2/4 picked" party line, wave chip + pip row) · `v2-03-held-landscape-800x400.svg` (next wave: held pill under the currency pills, strip under the wave chip, flag-off note). Still valid from v1.1/v1.2: `01`–`04` (layout at all 4 sizes) and `m15-01`–`m15-04` (directions, card anatomy, portrait pick, landscape strip). The older ones use the v1.1 arch colors; the v2 colors win. PNG renders on the box only.

## 9. Build split
**Waits for the fun test** (Ghost's decision 5). Then:
- **Echo:** `LaunchGate.SHOW.buffDraft = false` line + park `BuffPick` on it via `PARKED_ACTION = { BuffPick = "buffDraft" }` (`ShardfallServer/Remotes.luau:123`, same as Trade/Market) + a `RateLimiter` entry for `BuffPick` + a `ParkedRemotes.spec` case (v2.2); `Buffs.luau` per §6; Config tests (odds sum to 1, 4 cards per element, elements in `Elements.ORDER`, budget ±10%, text limits, no paid keys); `BuffService` (offer roll, validation, held/auto-take, Resonance, Shard Sense luck hook); the 4 telemetry events.
- **Ghost:** DraftHud (row, Later, pill, tray, strip, toast), Results row, world bursts, input (touch/keys/pad); all strings and colors from the payload; nothing built while the flag is off.
- **Prism:** element icons + 12 card glyphs (128×128 PNG) when building starts; guard review after each playtest batch (tuning note on the Agent Board).
- **Havoc:** flag-off refusal, double picks / two devices, rejoin restore, auto-take at boss start, party of 4 picking at once, telemetry rows match picks 1:1.

## 10. Pass criteria (playtest)
1. Flag off (shipped): no draft UI, `BuffPick` returns "That is closed.", no buff telemetry. The M13 loop is unchanged.
2. Flag on, 390×844: a tester reads 3 cards and picks in ≤ 2 s median, 1 tap.
3. Nothing but the draft row enters the keep-out, and only in the pick moment; every target ≥ 44 px; attack cluster, skill bar and thumbstick never covered at 667×375 and 800×400; desktop keys 1/2/3/Esc work.
4. Next wave starts on time when nobody picks; a held offer auto-takes at the next clear (or at boss start).
5. Party of 2–4: everyone gets their own draft, nobody waits, each pick logs once.
6. Over ≥ 20 runs per mode, no element's manual pick share ≥ 50%; telemetry rows = picks 1:1.
7. Changing a card's value, name or color needs only a Config edit.
8. Runs stay near 5 min. Testers say the picks change how they play (Roadmap Phase 5 Kevin check).

## 11. Open questions (answer by number)
1. **@Kevin (confirm or change):** Resonance (2 pips = +1 matching item, max +2) and the 12 card names were decided by Ghost under your pre-approval on Oct 23 ("Kevin can change later"). Keep both? Recommended: keep.
2. **@Kevin (taste):** Void on cards follows the #428/#435 pick (V3 #C04888). If you choose the V2 override there, cards follow automatically. Any separate call for cards? Recommended: no, one Void color everywhere.
3. ~~**@Echo:** Flag name `buffDraft` (in `LaunchGate.SHOW`) OK, and is `BuffPick` parked through `PARKED_ACTION`?~~ **Answered yes to both (Echo, 12:22Z, v2.2).** `PARKED_ACTION = { BuffPick = "buffDraft" }`; rate limit runs before the park, so the §7 contract order was swapped.
4. ~~**@Ghost (carried from v1.2 Q2):** On landscape phones the expanded strip list opens only during the break. OK?~~ **Answered yes (Ghost, 11:55Z, v2.1).** The landscape held-buff list shows in the break only; during combat only the small held pill shows.
5. ~~**@Ghost (carried from v1.2 Q3):** Auto-takes excluded from the 50% share (tracked separately). OK?~~ **Answered yes (Ghost, 11:55Z, v2.1).** Auto-takes are excluded from the 50% pick-rate share and counted separately in `buff_run_summary`.

v1.2 Q1 (direction A: Config knobs + human-tuned guard, no live auto-balance) is treated as **answered by Ghost's 11:40Z GO**, which asks for exactly that (Config table + telemetry check). v1.2 Q4 (element colors) is **answered** by the same GO (new hexes).

## Decision log
- 2026-10-23 (Ghost, Kevin pre-approved): spec pick-1-of-3 buffs (5.1) now, design only; building waits for the fun test. Direction A (Shard Draft).
- 2026-10-23 (Echo): Q3 yes (8 s Config break; held offer auto-takes highest rarity, ties to first card, server-decided). Q4 yes (Shard Sense = run drops only, never RollService; Config cap + validation test).
- 2026-10-23 (Ghost, Kevin pre-approved; Kevin can change later): Q1 Resonance yes (max +2). Q2 keep all 12 card names. Q5 strip dock rule.
- 2026-10-23/24 (Prism phone layout review, Ghost D1/D3): F15–F19 layout fixes; portrait tray at y 235–283; one toast lane.
- 2026-10-24 (Ghost, Q6): portrait tray may cover the rail top ≤ 4 s, tap-to-dismiss, provisional until Kevin's phone playtest.
- 2026-10-24 (Ghost via #428 Q1): buff strip under the wave counter. v1.2 (M15 Config contract + guard) added.
- **2026-10-24 (Ghost GO 11:40Z, Kevin pre-approved; Prism): SPEC v2** consolidates v1.1 + v1.2; adds `LaunchGate.SHOW.buffDraft` (default off), the full Config table, the pick contract, party rules, telemetry events/fields, and the card colors Ember #E84814 / Frost #5CD6FF / Void #C04888. v1.2 Q1 and Q4 closed by the GO. Not approved as a Vision & Design Rules decision.
- **2026-10-24 (Ghost, board row https://app.notion.com/p/403c31ca3883812fa966d50ee503d110, 11:55Z, Kevin pre-approved; Prism): v2.1.** Q4 yes: on landscape phones (667×375, 800×400) the expanded held-buff list opens **during the break only**; in combat only the small held pill / 44 px strip pill shows. Q5 yes: **auto-takes are excluded** from the 50% pick-rate share (share = manual picks only) and are **counted separately** in `buff_run_summary` (`autoTakes` count + new `autoTakeCards` list). Docs only; no other change.
- **2026-10-24 (Echo, board row https://app.notion.com/p/403c31ca3883818383eaedad9f4adf44, 12:22Z; Prism): v2.2.** Q3 yes to both (`buffDraft`, `PARKED_ACTION`). Pick contract order fixed to match `guard()`: rate limit first, then the `buffDraft` park. Build adds a `RateLimiter` entry and a `ParkedRemotes.spec` case. Docs only.

## Later (not V1)
5.2 Fusion cards, element-leaning offers on element waves, underdog tier tag (v1.2 direction C), draft-history Codex page, a balance dashboard page in Notion, cosmetic card backs (never power). All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox UI only: `Frame`, `ImageLabel`, `TextLabel`/`TextButton`, `UICorner`, `UIStroke`, `UIGradient`, `UIListLayout`, `UIScale`, `UIPadding`, TweenService, world-space `ParticleEmitter`. **No blur or glassmorphism** (BlurEffect blurs the 3D world, not GUI), no soft shadows, no web fonts (Builder Sans / GothamSSm). The mockups are a guide; these notes win.

| Element | Instances |
|---|---|
| Root | `ScreenGui` DraftHud (ResetOnSpawn false, ZIndexBehavior Sibling, `ScreenInsets = CoreUISafeInsets`, DisplayOrder above CombatHud). **Not created while `LaunchGate.SHOW.buffDraft` is false.** `Frame` root + `UIScale` (desktop clamp, cards ≤ 200×280) |
| Scrim | full-screen `Frame` 10,8,16, BackgroundTransparency 1 → 0.55 (0.2 s tween), `Active = false` |
| Header | `TextLabel` "SHARD DRAFT · pick 1" + break bar `Frame` (UICorner h/2), inner `Frame` Size tween 1 → 0 over `breakSeconds`; party `TextLabel` "n/N picked" |
| Card | `TextButton` (AutoButtonColor false, Text "") + `UICorner` 12 + `UIStroke` 2 = `Rarities.COLOR[tier]` + `UIGradient` top sheen (tier color → panel 28,24,40) + tier chip `Frame` (UICorner h/2) + `TextLabel` + element icon `ImageLabel` in a circle `Frame` (UICorner 0.5 scale, `UIStroke` 2 = element color from payload) + name/effect/twist `TextLabel`s (TextWrapped, TextTruncate AtEnd) + pip footer `Frame` (UICorner h/2, `UIStroke` 1 element color, fill = element color at 25% over the panel) |
| Element colors | Color3.fromHex("#E84814") Ember · ("#5CD6FF") Frost · ("#C04888") Void, read from the payload/Config, never hard-coded in DraftHud |
| Epic/Legendary | outer `Frame` + `UIStroke` 3 + `UIGradient` gold stops, Rotation tween 0 → 360 over 3 s, repeat (off on reduced motion) + `ImageLabel` glow_soft_256 at transparency 0.8 |
| Pick feedback | card `UIScale` 1 → 1.08 (0.08 s); others via `CanvasGroup` GroupTransparency 0.65 (no blur); clone icon `ImageLabel` flies to the strip AbsolutePosition (0.35 s, Quad Out) |
| Later / pill / tray | `TextButton` 44 tall + `UICorner` h/2 + `UIStroke` gold 2 + `UIPadding` 12; tray `Frame` + `UIListLayout` horizontal, mini cards `TextButton` 44–48 tall |
| Buff strip | portrait pip row `Frame` 14 tall + up to 4 pip `Frame`s 10×10 (UICorner 0.5 scale), parented with the wave chip; landscape/desktop 44 px pill `TextButton` 8 px under the chip; list `Frame` + `UIListLayout` rows 44 tall, fold = Size tween 0.15 s |
| Toast | #397 toast (`Frame` + `UICorner` 12 + `UIStroke` 2 element color + icon + 2 `TextLabel`s) in the one toast lane |
| World bursts | 3 `Attachment`s on the Impact Core, each `ParticleEmitter` Rate 0, `:Emit(20)`, Color = element color, LightEmission 0.6, Speed 18–26, Lifetime 0.6 |
| Input | `ContextActionService` 1/2/3 + Esc + gamepad; touch = the buttons |
| Animation | TweenService only, no per-frame Heartbeat |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| el_ember_128, el_frost_128, el_void_128 | 128×128 | element icons (white glyph; tinted by `ImageColor3` = element color) |
| card_glyph_* ×12 (optional) | 128×128 | per-card glyphs; V1 can ship element icons only |
| glow_soft_256, shard_frag_a/b/c, spinner_64 | as in #397 | reused |
