# Shardfall Economy v1 (Phase 4 sheet)

Status: **draft for review, revision 3** (Kevin-approved revisions, Oct 21, 2026 PT). Docs only. Nothing in `src/` changes from this file.
Author: Echo (support lane). Spec: issue #15 comment 6333741405, item 3. PR #369.
Base: `cursor/live-build-9721`. Roadmap: `docs/ROADMAP.md` Phase 4.

## How to read this sheet

- **Current** = the value is in the repo today. The source file is cited next to it.
- **Proposed** = a new number from this sheet. It is not in the repo. Ghost decides whether it goes into config.
- **Missing** = the repo has no value for this. A proposal is given.

Paths: `S/` = `src/ReplicatedStorage/Shared/`. The roadmap says all numbers will live in `src/shared/Config/` (ROADMAP ground rule 6, milestone 0.3). That folder doesn't exist on the base branch yet. The only file there is `WaveArenaConfig.luau` on draft PR #368. Proposed config paths below use `src/shared/Config/` to match the roadmap.

Free-to-play rule for every row: nothing here costs Robux and nothing is pay-to-win. Roll Tokens and Fragments are earn-only. Pity is free and never sold (`S/RollConfig.luau` header). The paid kill switch stays off (`S/RarityConfig.luau` `PAID_LUCK_ENABLED = false`).

### What changed in revision 3

Kevin wants rolling to be Shardfall's main gacha, with more depth. All of these are **Proposed**:
1. **8-tier base ladder** (Common through Divine) replaces the rev 2 five-tier plan. **This reverses ROADMAP 1.3 ("7 tiers → 5") and needs Ghost's agreement before any config work** (section 3a).
2. **Variants** (Shiny, Golden, Rainbow) as an independent extra roll inside any tier (section 3b).
3. **Mutations and traits** as a second independent roll (section 3c).
4. **1-in-a-million chase pulls** with a server-wide announcement (section 3d).
5. **Per-tier pity** from Epic up, with soft pity near each cap (section 3e).
6. New sections: Fragments for variants and mutations (5b), bag and collection slots (7a, rewritten). Analytics, tuning table and sim updated.

### What changed in revision 2

1. Five difficulties (Normal, **Medium**, Hard, Nightmare, **Insane**) with multipliers, level gates and enemy scaling.
2. Pay is judged **per minute**, with Proposed run lengths. Each tier strictly beats the one below it.
3. Boss wave pays 5. A Normal clear is now **11** tokens. Everything downstream was recomputed.
4. The sim modelled the roadmap's 5-tier target (superseded in rev 3), and kept the current 7-tier ladder as a comparison.
5. Legendary pace: Proposed **hard pity 150 with soft pity from roll 100**. First Legendary drops from ~6 h to ~30 min.
6. Token split across the 4 tabs. 7. Bag space. 8. Gold keep-or-cut call. 9. Fragment shop check against pity. 10. Run-length caveat. 11. Sim committed as `tools/econ_sim.py` (seed 42).

---

## 1. Currencies

The roadmap reshapes the six live currencies into **Roll Tokens + Fragments** (+ Gold only if needed) (ROADMAP salvage map, "Currencies → 4.1").

| Currency | Job | Live name today | Status |
|---|---|---|---|
| Roll Tokens | Pay for rolls. 1 token = 1 roll. One wallet for all 4 tabs. | Shard Tokens, `shardTokens` (`S/Currencies.luau` `SHARD`, `S/Schema.luau`) | Current wallet. **Proposed** rename in UI only. Field id stays `shardTokens` so saves don't migrate. |
| Fragments | Bad-luck protection. Duplicates turn into Fragments, and Fragments buy progress. | Closest is Shard Dust, `shardDust` (`S/ChestConfig.luau` `DUST`) | **Missing** as a V1 wallet. Shard Dust / dup merging is in the Parking Lot and "needs Kevin's OK" (ROADMAP Parking Lot). Proposed below. Needs Kevin's OK before build. |
| Gold | Everyday money | `gold` (`S/Economy.luau`) | Current. **Recommendation: cut from the V1 loop** (see section 1a). |
| Prism Tokens | Robux roll wallet | `prismTokens` (`S/Currencies.luau`) | Current but **off** (`PAID_LUCK_ENABLED = false`). Not part of V1. Stays off. |

**Roll Tokens**
- Sources (current): new profile `Schema.STARTER_TOKENS = 10` (`S/Schema.luau`). Rootvault clear 3 and Heartwood clear 4 (`S/Dungeons.luau` `rewards.shardTokens`). Old Waves mode pays 1 token every 3rd wave and 2 every 5th (`Dungeons.waveReward`). A clear voucher drops at 40% (Rootvault) or 20% (Heartwood) (`voucherChance`).
- Sources (**Proposed** for V1): wave arena waves (section 2), dailies and weekly (section 7), 3 free first rolls (section 3).
- Sinks (current): 1 per single roll, 9 per x10 (`RollConfig.SINGLE_COST = 1`, `RollConfig.cost(10)`).
- Cap: **Missing** in profile reconcile (economy_audit.md: "none in reconcile; Studio grant stops at 9999"). **Proposed** cap 9,999.

**Fragments**
- Sources (**Proposed**): duplicates from rolls only (section 5).
- Sinks (**Proposed**): a chosen Epic or Legendary from a tab's pool, and later gear upgrades (section 6).
- Cap: **Proposed** 99,999. (The live Shard Dust cap is 999,999 in `S/ChestConfig.luau` / `S/Schema.luau`.)

### 1a. Gold: keep or cut?

**Recommendation: cut Gold from the V1 loop.** Keep the `gold` save field untouched, but don't show it, pay it, or spend it until a phase needs it.
- The V1 loop is roll → equip → run → tokens → roll (ROADMAP one-line plan). Gold has no job in it.
- Every live gold sink is parked: Forge (`forgeCraft` flags), the market and trading (`market`, `trading`), eggs, and the gold shop (`goldShop`) (ROADMAP salvage map, PARK).
- A faucet with no sink is the inflation case in `docs/design/shardfall_economy.md`, and economy_audit.md flags F1/F3 already show gold is out of balance.
- Fewer currencies passes the "explain each in one sentence" rule (`shardfall_economy.md` principle 2).
- Revisit at the Checkpoint gate if upgrades come back. Section 6 proposes Fragments for upgrades instead, so Gold may never be needed.

---

## 2. Income per run (wave arena)

Wave layout is current on draft PR #368: waves of 6, 8, 10 and 12, then 1 boss with 4 adds (`src/shared/Config/WaveArenaConfig.luau` `waves`). The arena has **no reward fields**. All token numbers below are **Proposed**.

The closest live numbers are the old Waves mode (`Dungeons.waveReward`: 0, 0, 1, 0, 2 tokens for waves 1–5, total 3) and a Rootvault clear (3 tokens plus a 40% voucher). That's 3 rolls a run, which misses the roadmap target "about 1 run = a few rolls" (ROADMAP 4.4).

| Wave | Enemies (current, #368) | Roll Tokens, Normal (**Proposed**) |
|---|---|---|
| 1 | 6 | 1 |
| 2 | 8 | 1 |
| 3 | 10 | 2 |
| 4 | 12 | 2 |
| 5 boss | 1 boss + 4 adds | 5 |
| **Full clear** | | **11** (one x10 plus 2 singles) |

The boss pays almost half the run, so finishing matters more than farming the early waves.

### Five difficulties (all multipliers and run lengths Proposed)

| Tier | Level gate | Enemy HP / damage | Token multiplier | Run length (min) | Full clear | Failed on boss (waves 1–4) |
|---|---|---|---|---|---|---|
| Normal | 1 (current, `S/Rootvault.luau`) | x1 (current) | x1.00 | 5.0 | 11 | 6 |
| **Medium** (new) | 5 (**Proposed**) | x1.25 (**Proposed**) | x1.25 | 5.5 | 14 | 8 |
| Hard | 10 (current) | x1.5 (current) | x1.50 | 6.0 | 17 | 9 |
| Nightmare | 15 (current) | x2 (current) | x2.00 | 7.0 | 22 | 12 |
| **Insane** (new) | 20 (**Proposed**) | x3 (**Proposed**) | x3.00 | 9.0 | 33 | 18 |

- Current rows: Normal, Hard and Nightmare HP, damage and level gates come from `S/Rootvault.luau` `DIFFICULTIES`. Live rows have **no** reward multiplier, only a chest tier. Hard and Nightmare as modes are Phase 5 (ROADMAP 5.4, 5.5). Medium and Insane are new.
- Medium gate L5 sits where pacing.md puts the player at ~0.37 h. Insane gate L20 sits at ~16.8 h (`docs/design/pacing.md` level hours).
- Rounding: totals are rounded half up (13.75 → 14, 16.5 → 17).

### Pay per minute (Proposed run lengths)

| Tier | Tokens / min | Rolls / min (spent on x10) | Beats tier below by |
|---|---|---|---|
| Normal | 2.20 | 2.44 | — |
| Medium | 2.55 | 2.83 | +16% |
| Hard | 2.83 | 3.15 | +11% |
| Nightmare | 3.14 | 3.49 | +11% |
| Insane | 3.67 | 4.07 | +17% |

Each tier strictly beats the one below on tokens per minute (the sim asserts this). The edge is small on purpose (11–17%), because harder runs also take longer and fail more. If playtests show Hard clears taking more than ~7 min, Hard drops below Medium per minute. Raise its multiplier, don't shorten the run.

### Other run rules

- **First clear of the day (Proposed):** +5 tokens once a day. Live first clear of the day pays x3 XP and a Rare chest (`S/Loops.luau` `firstClear`). Chests are parked, so tokens replace the chest.
- **First-ever clear (Proposed):** +10 tokens once per difficulty.
- **Failed or left run:** keep tokens from every cleared wave, but no clear bonuses (ROADMAP 3.7: "Leave anytime, keep loot from cleared waves". Live text in `S/Dungeons.luau`: "Rewards from cleared waves are still yours"). Dying on the boss pays 6 of 11 on Normal.
- **Fragments from runs (Proposed):** none. Fragments come only from duplicates.

### Run length is an assumption

The 5-minute Normal run comes from ROADMAP Phase 3 ("Kevin can clear solo in about 5 minutes"). It hasn't been measured. Ghost's #15 comment 6334230802 (Kevin's Rootvault playtest, 11:19 PM PT) lists loot, boss and camera fixes, but **gives no run timing**. **Verify all five run lengths against Kevin's timed arena playtests**, then re-run `tools/econ_sim.py`. Pay per minute is the number to protect, not pay per run.

---

## 3. Roll costs

| Item | Value | Status / source |
|---|---|---|
| Single roll | 1 token | Current, `RollConfig.SINGLE_COST` |
| x10 roll | 9 tokens (10% off) | Current, `RollConfig.MULTI_COUNT = 10`, `MULTI_DISCOUNT = 0.10`, `RollConfig.cost` |
| Batch rule | x10 needs 10 free bag slots and 9 tokens before anything is spent | Current, `RollConfig.batchBlock` |
| Epic+ pity | 50 rolls | Current, `RollConfig.EPIC_PITY = 50` |
| Legendary+ pity | 1000 rolls | Current, `RollConfig.LEGENDARY_PITY = 1000`. **Proposed: per-tier pity, see 3e** |
| x2 luck roll | every 10th roll | Current, `RollConfig.BONUS_EVERY = 10`, `RarityConfig.luckMultiplier` |
| 3 free first rolls | 3 rolls, no token | **Missing** as a count. Roadmap 1.5 asks for it. Live gives 10 starter tokens (`Schema.STARTER_TOKENS`) and one floored first roll (`FirstSession.CONFIG.rollFloor = "Rare"`). **Proposed:** `freeRolls = 3`, with the first keeping the Rare floor. Keep the 10 starter tokens. |

**When pity resets (current):** any Epic or better, natural or forced, resets the Epic counter. A Legendary or better resets both counters (`RarityConfig.advance`). They're saved as `sinceEpic` / `sinceLegendary`.

**Does x10 count as 10?** Yes, current. A batch is 10 server rolls in a row, each advancing pity (`S/RollBatch.luau`, `RollService`). 50 is exactly five x10s.

### 3a. Base rarity ladder: 8 tiers (Proposed)

**Current, 7 tiers** (`S/RarityConfig.luau` `ONE_IN`): Common 1/2, Uncommon 1/5, Rare 1/25, Epic 1/250, Legendary 1/2500, Mythic 1/25000, Secret 1/100000.

**Roadmap:** ROADMAP 1.3 says "5 rarity tiers + pity meter", and the salvage map says "7 tiers → 5 in config". **This rev 3 proposal reverses that plan. It keeps all 7 live tiers and adds an 8th, Divine.** Because it changes a locked roadmap milestone, **Ghost has to agree** before any roll config changes. If Ghost declines, the rev 2 five-tier numbers are still in git history (commit `e5cea92`).

Upside of 8 tiers: no save migration (the live 7 IDs stay as they are; ROADMAP: "Keep IDs stable"), and a longer chase that fits "rolling is the main gacha".

| Tier | Proposed 1-in-N (checked rarest first; Common absorbs the rest) | Current 1-in-N | Role |
|---|---|---|---|
| Common | 1/2 (remainder) | 1/2 | filler |
| Uncommon | 1/4 | 1/5 | early variety |
| Rare | 1/15 | 1/25 | about one per x10 |
| Epic | 1/100 | 1/250 | natural Epics sometimes beat pity |
| Legendary | 1/1000 | 1/2500 | first big hit, ~30 min with soft pity |
| Mythic | 1/20000 | 1/25000 | chase (~7–9% of players in 10 h) |
| Secret | 1/100000 | 1/100000 | deep chase (~2%) |
| **Divine** (new) | 1/500000 | none | ultra chase (<1%), counts as a chase pull |

The x2 luck roll every 10th roll (current `BONUS_EVERY = 10`) applies to base-tier odds only. It doesn't touch variants, mutations or the Shardheart.

### 3b. Variants (Proposed)

An independent extra roll on every pull, on top of the base tier. At most one variant per pull, checked rarest first. Any tier can carry a variant (for example, a Golden Epic).

| Variant | Proposed odds | Look (cosmetic) | Stat bonus (capped) |
|---|---|---|---|
| Shiny | 1/50 | sparkle particles, brighter tint | +5% to the item's base stats |
| Golden | 1/500 | gold material, gold name text | +10% |
| Rainbow | 1/5000 | cycling hue shader, rainbow trail | +15% (hard cap; no stacking) |

- The bonus multiplies the item's own rolled stats, like `Stars.applyStats` does (`S/Stars.luau`). It never multiplies another item's stats or set bonuses.
- A Rainbow Common is still weaker than a plain Rare. Tier always matters more than variant.
- Variants are **never sold**, and there is no paid variant boost. They have no Robux path.

### 3c. Mutations and traits (Proposed)

A second independent roll on every pull. At most one mutation per item.

| Mutation | Proposed odds | Effect (small) | Look |
|---|---|---|---|
| Trait (checked first) | 1/100 | one minor trait: Swift (+3% move speed), Sturdy (+3% HP), Keen (+2% crit chance), Quick (+3% attack speed) | small icon on the card |
| Elemental: Ember / Frost / Void | 1/20 (equal split) | +3% to that element's stat (Ember → Damage/Crit, Frost → Health/Defense, Void → Attack Speed/Luck; ROADMAP 2.3) | coloured edge glow |

- Mutation effects are capped at +3% each and never stack on one item.
- Elemental mutations follow the roadmap's balance rule (Ember, Frost and Void stay close in value). Log their pick rates.
- The live `S/Traits.luau` (weapon traits) is parked under the `traits` flag (ROADMAP PARK: "Extra roll layer"). This proposal unparks a smaller version, which needs Kevin's OK at a gate, matching the Parking Lot rule.

### 3d. Chase pulls: 1-in-a-million (Proposed)

A pull counts as a **chase pull** if any of these happen:
- A **Divine** base tier (1/500,000).
- A **Rainbow on a Mythic or better** (about 1/5000 × 1/18,000 ≈ 1 in 90 million on its own; mostly a bragging combo).
- The **Shardheart**, a flat 1/1,000,000 special item on any tab, any tier roll. It's a cosmetic-first trophy item: a unique model and aura, stats equal to a Legendary of its tab, and +0 variant bonus.

Every chase pull gets a **server-wide announcement**, using the live cross-server Mythic broadcast path (`RarityConfig.reveal` sets `crossServer` for Mythic and Secret, `RarityConfig.TOPIC = "ShardfallMythic"`). Plus a title and a codex entry. Design note: the announcement is the reward. Shardheart power stays at Legendary level, so a lucky player isn't permanently stronger.

Sim: **0.3% of Normal-only players and 0.8% of Ladder players** get a chase pull in 10 h (section 9).

### 3e. Per-tier pity (Proposed)

One counter per tier from Epic up. Each counts rolls since the player last got **that tier or higher**.

| Tier | Hard cap | Soft pity starts | Soft step (absolute chance added per roll past start) | Current |
|---|---|---|---|---|
| Epic | 50 | 40 | +3% | `EPIC_PITY = 50`, no soft pity |
| Legendary | 150 | 100 | +2% | `LEGENDARY_PITY = 1000`, no soft pity |
| Mythic | 3,000 | 2,500 | +0.2% | none |
| Secret | 15,000 | 12,000 | +0.04% | none |
| Divine | 60,000 | 50,000 | +0.01% | none |

How the counters interact:
- **Reset:** a pull of tier T resets every counter at or below T and adds 1 to the higher ones. That's the live `RarityConfig.advance` rule, extended to 5 counters. Example: a Legendary resets Epic and Legendary. Mythic, Secret and Divine keep counting.
- **Two floors due on the same roll:** the highest one wins, and the lower counters reset with it. Nothing is lost, since the higher tier is better.
- **Soft pity** adds to that tier's natural chance only. It doesn't change lower tiers.
- **x10:** each of the 10 rolls advances every counter (current batch rule).
- **Variants and mutations** have no pity. They're pure luck, so they can't be farmed down.
- **Global, not per tab:** one set of counters for all 4 tabs (current `sinceEpic` is one field). It's saved as new fields `sinceMythic`, `sinceSecret` and `sinceDivine` (new save fields, schema bump).
- **Never sold.** The pity meter shows Epic and Legendary bars, plus a smaller "Mythic+ in N" line.
- In 10 h a player makes ~1,600–2,000 rolls, so only the Epic and Legendary caps fire in practice. The Mythic cap is about 19 h of Normal, which is a long-term promise, not a 15-minute one.

**Odds disclosure** must list the base tiers, variant odds, mutation odds, the Shardheart, and all soft pity rules (`RarityConfig.disclose` and the paid-random rule in its header, even though nothing here is paid).

## 4. Pacing targets

Rolls per run = tokens × 10 / 9 when spent on x10s. Run lengths are Proposed (section 2).

| Tier | Tokens / run | Rolls / run | Run (min) | Runs to 50 Epic pity | Minutes to Epic pity (worst case) | Minutes to Legendary hard pity 150 (worst case) | 15-min session | 1-hour session |
|---|---|---|---|---|---|---|---|---|
| Normal | 11 | 12.2 | 5.0 | 4.1 | 20 | 61 | 3 runs, 33 tokens, ~37 rolls | 12 runs, 132 tokens, ~147 rolls |
| Medium | 14 | 15.6 | 5.5 | 3.2 | 18 | 53 | ~2.7 runs, 38 tokens, ~42 rolls | ~11 runs, 153 tokens, ~170 rolls |
| Hard | 17 | 18.9 | 6.0 | 2.6 | 16 | 48 | 2.5 runs, 43 tokens, ~47 rolls | 10 runs, 170 tokens, ~189 rolls |
| Nightmare | 22 | 24.4 | 7.0 | 2.0 | 14 | 43 | ~2.1 runs, 47 tokens, ~52 rolls | ~8.6 runs, 189 tokens, ~210 rolls |
| Insane | 33 | 36.7 | 9.0 | 1.4 | 12 | 37 | ~1.7 runs, 55 tokens, ~61 rolls | ~6.7 runs, 220 tokens, ~244 rolls |

Session numbers exclude dailies. Add ~28 tokens a day (section 7).

**Time to first item (sim, Normal only, median; times rounded up to the run end):**

| Pull | Proposed 8-tier + extras (rev 3) | Current 7-tier |
|---|---|---|
| Uncommon | < 1 min (free rolls) | ~2 min |
| Rare / Epic | ~5 min | ~5 min |
| Legendary | **~30 min** (100% of players) | ~6.1 h |
| Mythic | ~7% of players in 10 h (median ~5 h for those who hit it) | ~7% |
| Secret | ~2% | ~1% |
| Divine | 0.2% | n/a |
| Shiny | ~5 min | n/a |
| Golden | **~2.1 h** (97% of players) | n/a |
| Rainbow | 25% of players in 10 h (median ~4.5 h for those who hit it) | n/a |
| Any chase pull | 0.3% (Ladder 0.8%) | n/a |

What a session feels like (Proposed target, rev 3):
- **15 minutes:** 3 Normal runs, three x10s, an Epic, a Shiny or two, an elemental mutation, and a Legendary meter about a quarter full. That fits the Checkpoint ("Kevin wants to keep playing after 15 min").
- **1 hour:** 12 runs, ~150 rolls, several Epics, and usually one Legendary.

---

## 5. Duplicates

V1 Fragments are **Proposed** (Parking Lot item, needs Kevin's OK). Live Shard Dust per duplicate is current in `S/ChestConfig.luau` `DUST`. Proposed Fragments are live Dust ÷ 5.

| Rarity | Live Shard Dust per dup (current) | Fragments per dup (**Proposed**) |
|---|---|---|
| Common | 5 | 1 |
| Uncommon | 15 | 3 |
| Rare | 50 | 10 |
| Epic | 200 | 40 |
| Legendary | 1000 | 200 |
| Mythic | 5000 | 1000 |
| Secret | none listed | 3000 |
| Divine (new) | none | 10000 |

**Proposed:** duplicates convert to Fragments automatically and never take a bag slot (see section 7a).

What Fragments buy (**Proposed**):
- A chosen Epic from a tab's pool: **400**
- A chosen Legendary: **2000**
- Gear upgrades (section 6)

### 5b. Fragments from variants and mutations (Proposed)

A copy is a **duplicate** when the player already holds the same item with the same variant. A new variant of an owned item is not a duplicate. It goes into the collection (section 7a).

| Duplicate | Fragments |
|---|---|
| Plain | the tier value above |
| Shiny | x2 |
| Golden | x5 |
| Rainbow | x10 |
| Any mutation on the copy | x1.5 on top (example: Golden Epic with Ember = 40 × 5 × 1.5 = 300) |

- A duplicate of a better variant upgrades the kept copy instead. The old copy becomes Fragments at its own rate, so nothing is lost.
- A mutation never makes a copy count as new. The player keeps whichever mutation they prefer, with a one-tap swap, and the other copy turns into Fragments.
- Fragments still can't buy variants, mutations, Mythic, Secret, Divine or the Shardheart. Those stay pure luck.
- With these multipliers, the sim's Fragment rate rises only ~2% (5,887 / 10 h vs 5,792 in rev 2). The 5a shop check still holds.

### 5a. Fragment shop check against pity

Rule: a chosen Legendary must not come faster than pity, or pity stops mattering.

| Tier | Fragments / hour (sim, rev 3) | Hours to 2000 (chosen Legendary) | Worst-case Legendary pity (hard 150) | OK? |
|---|---|---|---|---|
| Normal | ~590 | ~3.5 h | ~1.0 h | Yes, 3.4x slower |
| Ladder (Normal → Nightmare) | ~780 | ~2.6 h | ~0.7–1.0 h | Yes |
| Insane (estimated ~1.7x Normal rolls/min) | ~980 (est.) | ~2.0 h | ~0.6 h | Yes |

| Epic check | Fragments 400 at ~580/h ≈ 41 min | Epic pity 50 ≈ 20 min worst case on Normal | Yes |

**Prices are kept at 400 / 2000.** The shop is a "pick the exact one you want" tool, not a faster route. If the Legendary pity is cut further, re-check this table. The Legendary price must stay above ~2x the Fragments earned in one worst-case pity window.

---

## 6. Gear sinks

Gear upgrading is **out of scope for Phase 2** (ROADMAP Phase 2: "Upgrading gear, fusing, salvaging, Shard Dust"). V1 launches with no gear sink. This reserves the budget.

Live Forge (parked, `forgeCraft` flags): +0→+10, paid in Gold. +1 = 150, +2 = 300, then `floor(500 * 1.6^level + 0.5)`, and 1 material from level 7 (`S/Economy.luau` `upgradeCost`, `UPGRADE_MAX = 10`). Under the Gold-cut recommendation (1a), that forge would move to Fragments if it ever comes back.

**Proposed** Fragment upgrade path (+1 to +5 only, post-Checkpoint):

| Step | Fragments (**Proposed**) | Cumulative |
|---|---|---|
| +0→+1 | 20 | 20 |
| +1→+2 | 40 | 60 |
| +2→+3 | 80 | 140 |
| +3→+4 | 160 | 300 |
| +4→+5 | 320 | 620 |

Budget check (sim, rev 3 Normal, ~590 Fragments/h): one item to +5 takes ~1.1 h. A full 5-slot loadout (3,100) takes ~5.4 h. A chosen Legendary (2000) costs about 3 items' worth of upgrades, which is the intended trade-off. Upgrades never destroy items (`S/Economy.luau` header).

---

## 7. Daily and weekly rewards

Live dailies: 3 a day from a pool, each lasting 3 days, with one reroll (`S/Loops.luau` `POOL`, `DAILY_LIFE_DAYS = 3`). Live payout is 40 gold + 1 Shard Key per daily (economy_audit.md, `LoopService.luau`). The login streak pauses and never resets (`Loops.login`). Weekly is 5 quests (`Loops.WEEKLY`). Most live daily texts point at parked systems, so ROADMAP 6.7 rewrites them.

**Proposed V1 token payout** (unchanged from revision 1):

| Source | Tokens | Notes |
|---|---|---|
| Login (once a day) | 2 | streak never resets |
| Each daily (x3) | 3 | e.g. "Clear 3 waves", "Roll 20 times", "Clear a Medium run" |
| All 3 dailies bonus | 5 | |
| First clear of the day | 5 | section 2 |
| Each weekly (x5) | 10 | 50 a week ≈ 7 a day |

**Typical day (45 minutes = 9 Normal runs):** runs 99 + login 2 + dailies 9 + all-3 5 + first clear 5 + weekly share ~7 = **~127 tokens ≈ 141 rolls**. On Hard (7.5 runs): ~128 + 28 = ~156 tokens. Dailies are ~22% of a light Normal day and ~10% of a 2-hour day.

### 7a. Bag and collection slots

- **Current bag size:** `Schema.INVENTORY_CAP = 100` (`S/Schema.luau`). The planned paid +10 expansion is off (`S/Currencies.luau` `INVENTORY_EXPAND_SLOTS = 10`, `INVENTORY_EXPAND_ROBUX = 80`, "Not for sale yet"). **Keep it off.** Selling bag space would gate rolling behind Robux.
- **Current rule:** an x10 needs 10 free slots before tokens are spent (`RollConfig.batchBlock`).

**Proposed slot rule (rev 3):**

| Thing | Bag slots | Collection screen |
|---|---|---|
| Base item (tab + tier + item) | **1 slot**, holding the player's chosen copy | 1 tile |
| Variant of an owned item | **0 extra slots.** The kept copy shows its best variant. Others are stored as collection entries. | a pip on the tile (Shiny / Golden / Rainbow) |
| Mutation | 0 slots. One mutation per kept copy, swappable. | an icon on the tile |
| Duplicate | 0 slots, auto-converts to Fragments (5b) | count only |
| Shardheart | 1 slot (it's its own item) | its own trophy tile |

- Collection size with the assumed pools (24 base items per tab × 4 tabs = **96 base tiles**) × 4 variant states = **384 collection entries**. Mutations add a "seen" badge, not entries.
- Sim with this rule: bag slots used median **78 of 100**, collection entries ~104, and **0% of players** blocked from an x10.
- If variants took their own bag slots instead, median use would be ~104, and **100% of players** would hit the wall in 10 h. That's why variants live in the collection, not the bag.
- The current 7-tier comparison sim (pool C12/U10/R8/E6/L4/M2/S1 per tab, no variants) uses ~134 slots and blocks everyone. Pool sizes are what drive this, so they need to be fixed when the item catalog is set.

### 7b. Token split across tabs

One wallet pays for all 4 tabs (Weapons, Armor, Pets, Skills; ROADMAP 1.6). **Proposed typical spread**, used in the sim:

| Tab | Share of rolls | Rolls per Normal hour (~147) | Why |
|---|---|---|---|
| Weapons | 40% | ~59 | biggest power jump, Ember damage scaling |
| Armor | 25% | ~37 | survival for Hard and up |
| Pets | 20% | ~29 | one slot, visible flex |
| Skills | 15% | ~22 | two slots, fewer items |

Implications: a Skills Legendary takes longer to get from luck alone. Pity is per player, not per tab (current `sinceEpic` is one field), so a forced Legendary lands in whichever tab is being rolled. **Proposed:** keep pity global. Log the tab split (section 10). If Skills drops under 10%, add a Skills-only daily.

---

## 8. Balance risks

| Risk | Why | Mitigation (**Proposed**) |
|---|---|---|
| Farming the easiest tier | If Normal tokens/min beats harder tiers, players sit on Normal | Tokens/min rises strictly by tier (2.20 → 2.55 → 2.83 → 3.14 → 3.67). Log clear times. If a tier's real run length makes it lose to the one below, raise its multiplier. Phase 5 adds better odds on harder runs (ROADMAP 5.6). |
| Medium becoming the comfort tier | Medium is only +16% over Normal at low risk | Fine for L5–L10. Hard is +11% over Medium, which should pull L10+ players up. Watch the mode mix. |
| Insane too generous | x3 pay on a 9-minute run could flood veterans | Only +17% per minute over Nightmare, gated at L20 (~17 h). If clear rates top 80%, lower it to x2.75. |
| Hoarding | Players bank tokens for a "luck" moment | Pity is per player and time-blind. Token cap 9,999 ≈ 75 h of Normal. |
| Inflation | Tokens only enter, and rolls only remove; Fragments can pile up | Each currency has a sink. Gold is cut (1a). Event tokens stay off until a shop exists. |
| New vs veteran gap | Veterans earn 3.67/min on Insane vs 2.20 on Normal | That's a 1.67x gap, not 3x, because runs are longer. Power comes from tier, and variants and mutations are capped at +15% and +3%. Comeback boost (section 11). No trading in V1. |
| Legendary too common | Hard pity 150 means about 1 an hour | With 8 tiers, Legendary is the midpoint, not the top. Mythic, Secret and Divine carry the chase. Watch the "Legendary feels special" playtest answer. |
| Variant power creep | A Rainbow Legendary is +15% | Capped at +15%, no stacking with other variants, and it only multiplies the item's own stats. Tier always matters more. |
| Mutation balance | One elemental mutation is clearly best | Each is +3%, matching the element rule. Log `mutation_rolled` keep rates. |
| Chase envy | 0.3–0.8% of players get a chase pull | Shardheart power equals a Legendary, so the pull is a trophy plus an announcement, not a power gap. |
| Too many layers to read | Tier + variant + mutation on one card | Card shows tier colour first, the variant as a frame, the mutation as a small icon. Test on phone (ROADMAP 1.6). |
| Roadmap conflict | Rev 3 keeps 8 tiers, and ROADMAP 1.3 says 5 | Needs Ghost's agreement. Rev 2 numbers are in git (`e5cea92`). |
| Bag wall | x10 blocked by 10-slot rule | Auto-convert dups (7a). |
| Element / tab skew | One element or tab dominates | ROADMAP balance rule. Log element and tab mix. |
| Bots / AFK | Free token farm | Anti-AFK in Phase 6 (6.3). The live auto-farm pays 40% for 2 h max (`S/Economy.luau`). |

---

## 9. Simulation

**Script:** `tools/econ_sim.py`. Python 3, standard library only, deterministic with seed 42. Run it with `python3 tools/econ_sim.py`.

**Design.** 1,000 simulated players × 10 hours each, per scenario.
- Start: 10 tokens (current `STARTER_TOKENS`) plus 3 free rolls (proposed).
- Runs use the section 2 table. 10% of runs fail at a random wave and keep cleared-wave tokens. Dailies (28 tokens) are added every 2 hours of play.
- Tokens are spent on x10s as soon as 9 are held. Each x10 goes to a tab picked by the 7b spread.
- Each roll: base tier (x2 luck every 10th roll), then the per-tier soft and hard pity from 3e, then an independent variant roll (3b), an independent mutation roll (3c), and the chase check (3d).
- Bag: the 7a slot rule (1 slot per base item). Duplicates become Fragments with the 5b multipliers.
- Profiles: **Normal only**, and **Ladder** (Medium at 0.37 h, Hard at 2.58 h, Nightmare at 7.77 h, per pacing.md level hours. Insane isn't reached in 10 h).
- Scenarios: **proposed8** (rev 3: 8 tiers, per-tier pity, variants, mutations, chase; pools per tab C6/U5/R4/E3/L2/M2/S1/D1) and **current7** (current `ONE_IN`, Epic pity 50, Legendary pity 1000, no soft pity or extras; pools per tab C12/U10/R8/E6/L4/M2/S1).

**Sim output from those inputs:**

```
== tokens per minute (PROPOSED income / PROPOSED run length)
normal     gate L1  x1.0   5.0 min  clear 11  fail-on-boss  6  2.20 tok/min  12.2 rolls/run
medium     gate L5  x1.25  5.5 min  clear 14  fail-on-boss  8  2.55 tok/min  15.6 rolls/run
hard       gate L10 x1.5   6.0 min  clear 17  fail-on-boss  9  2.83 tok/min  18.9 rolls/run
nightmare  gate L15 x2.0   7.0 min  clear 22  fail-on-boss 12  3.14 tok/min  24.4 rolls/run
insane     gate L20 x3.0   9.0 min  clear 33  fail-on-boss 18  3.67 tok/min  36.7 rolls/run
== proposed8 / normal: 1000 players x 10 h, seed 42
rolls/10h median 1593; fragments/10h median 5887
bag slots used (1 per base item) median 78 of 100; collection entries (item+variant) median 104; players whose bag blocks x10: 0.0%
players with a chase pull in 10 h: 0.3%
  Common: 100.0% reached, median first at 0 min
  Uncommon: 100.0% reached, median first at 0 min
  Rare: 100.0% reached, median first at 5 min
  Epic: 100.0% reached, median first at 5 min
  Legendary: 100.0% reached, median first at 30 min
  Mythic: 7.4% reached, median first at 298 min
  Secret: 2.1% reached, median first at 353 min
  Divine: 0.2% reached, median first at 442 min
  Shiny: 100.0% reached, median first at 5 min
  Golden: 96.9% reached, median first at 124 min
  Rainbow: 25.1% reached, median first at 270 min
  Mutation: 100.0% reached, median first at 5 min
  Chase: 0.3% reached, median first at 452 min
== proposed8 / ladder: 1000 players x 10 h, seed 42
rolls/10h median 2003; fragments/10h median 7836
bag slots used (1 per base item) median 79 of 100; collection entries (item+variant) median 109; players whose bag blocks x10: 0.0%
players with a chase pull in 10 h: 0.8%
  Common: 100.0% reached, median first at 0 min
  Uncommon: 100.0% reached, median first at 0 min
  Rare: 100.0% reached, median first at 5 min
  Epic: 100.0% reached, median first at 5 min
  Legendary: 100.0% reached, median first at 30 min
  Mythic: 9.0% reached, median first at 271 min
  Secret: 2.4% reached, median first at 296 min
  Divine: 0.6% reached, median first at 256 min
  Shiny: 100.0% reached, median first at 5 min
  Golden: 98.0% reached, median first at 109 min
  Rainbow: 31.9% reached, median first at 298 min
  Mutation: 100.0% reached, median first at 5 min
  Chase: 0.8% reached, median first at 256 min
== current7 / normal: 1000 players x 10 h, seed 42
rolls/10h median 1593; fragments/10h median 3062
bag slots used (1 per base item) median 134 of 100; collection entries (item+variant) median 134; players whose bag blocks x10: 100.0%
  Common: 100.0% reached, median first at 0 min
  Uncommon: 100.0% reached, median first at 2 min
  Rare: 100.0% reached, median first at 5 min
  Epic: 100.0% reached, median first at 5 min
  Legendary: 99.3% reached, median first at 366 min
  Mythic: 6.8% reached, median first at 266 min
  Secret: 1.3% reached, median first at 401 min
== current7 / ladder: 1000 players x 10 h, seed 42
rolls/10h median 2003; fragments/10h median 4054
bag slots used (1 per base item) median 138 of 100; collection entries (item+variant) median 138; players whose bag blocks x10: 100.0%
  Common: 100.0% reached, median first at 0 min
  Uncommon: 100.0% reached, median first at 0 min
  Rare: 100.0% reached, median first at 5 min
  Epic: 100.0% reached, median first at 5 min
  Legendary: 99.9% reached, median first at 311 min
  Mythic: 8.6% reached, median first at 347 min
  Secret: 2.4% reached, median first at 249 min
```

Read:
- **Legendary:** every player gets one by ~30 min (rev 2 pace kept), versus ~6 h on the current ladder.
- **Mythic, Secret, Divine:** still chase items, at ~7–9%, ~2% and 0.2–0.6% of players in 10 h. Only the Epic and Legendary pity caps fire inside 10 h.
- **Variants:** Shiny by ~5 min, Golden by a median of ~2 h (97–98% of players), Rainbow for 25–32% of players.
- **Chase pull:** 0.3% (Normal) to 0.8% (Ladder) in 10 h. That's about 3–8 players per 1,000, enough for regular server announcements once there are a few hundred DAU.
- **Bag:** 78 of 100 slots with the proposed rule, and no x10 blocks.

## 10. Analytics hooks

Server-side only (ROADMAP "Analytics to add early", milestone 0.8).

- **Economy sources:** `tokens_earned {source: wave|clear_bonus|first_clear|login|daily|weekly|free_roll|comeback, amount, difficulty, balance}`, `fragments_earned {rarity, tab, amount, balance}`.
- **Economy sinks:** `tokens_spent {kind: single|x10, tab, amount, balance}`, `fragments_spent {kind: chosen_shard|upgrade, amount}`.
- **Rolls:** rolls per session, x10 vs x1 share, auto-roll use (ROADMAP Phase 1 metrics), `pity_fired {tier, roll_index, soft|hard}`, natural vs forced Epic and Legendary share, **tab split**.
- **`variant_rolled`** `{variant, tier, tab, kept|fragmented}`: checks the 1/50, 1/500 and 1/5000 rates.
- **`mutation_rolled`** `{mutation: trait id|Ember|Frost|Void, tier, tab, kept|swapped|fragmented}`: element balance.
- **`chase_pull`** `{kind: divine|rainbow_mythic_plus|shardheart, tier, variant, roll_index, server_id}`: also triggers the announcement. Alert if the rate drifts from the disclosed odds.
- **Pity:** `pity_fired {tier: epic..divine, roll_index, soft|hard}` for each of the 5 counters.
- **Bag:** `roll_blocked_bag {free_slots}` count, and bag fill at session end.
- **Runs:** run start, wave reached, run end (cleared / left / died), death wave, **run length per difficulty**, difficulty chosen (ROADMAP Phase 3 and Phase 5 metrics), Run Again rate.
- **Balance:** tokens per minute by difficulty (checks the strict ladder), median and top-1% token balance, time to first Epic and first Legendary.
- **Funnel step 7:** "Second roll with earned tokens".

---

## 11. Notes for later phases

- **Phase 5:** Medium, Hard, Nightmare and Insane become playable modes. Better odds on harder runs (ROADMAP 5.6) stack on the multipliers, so re-check per-minute pay. Chests may come back (`chests` flag). Keep chest value out of token math.
- **Pets:** pets roll on their own tab with the same tokens. No pet currency.
- **Events (Phase 8):** event tokens only with an event shop, and they expire or convert at the end (`docs/design/shardfall_economy.md`). Event rewards are cosmetics or extra rolls, never exclusive power. Event-only variants (for example, a seasonal Frost tint) are cosmetic only and never stronger than Rainbow.
- **Season pass:** stays **off** (`Loops.PREMIUM_ENABLED = false`, `pass` flag off). If it ever turns on, the paid track is cosmetic only, matching the live rule ("Cosmetics and the Gem refund only. No gold, keys, dust, or stats", `S/Loops.luau`).
- **Comeback boost (Proposed):** a player away 7+ days gets x2 run tokens for their next 5 runs (~55 extra tokens on Normal, about six x10s). The streak already pauses instead of resetting (`Loops.login`).

---

## 12. Tuning table

| Key | Value | Status | Config path |
|---|---|---|---|
| Single roll cost | 1 | Current | `S/RollConfig.luau` `SINGLE_COST` |
| x10 count / discount | 10 / 0.10 (9 tokens) | Current | `S/RollConfig.luau` `MULTI_COUNT`, `MULTI_DISCOUNT` |
| Max batch | 10 | Current | `S/RollConfig.luau` `MAX_BATCH` |
| Epic pity | 50 | Current | `S/RollConfig.luau` `EPIC_PITY` |
| Legendary pity | 1000 | Current | `S/RollConfig.luau` `LEGENDARY_PITY` |
| Pity hard caps E/L/M/S/D | 50 / 150 / 3000 / 15000 / 60000 | Proposed (Epic 50 is current) | `src/shared/Config/Rarities.luau` `pity` |
| Soft pity start E/L/M/S/D | 40 / 100 / 2500 / 12000 / 50000 | Proposed | `src/shared/Config/Rarities.luau` `pity` |
| Soft pity step E/L/M/S/D | +3% / +2% / +0.2% / +0.04% / +0.01% per roll | Proposed | `src/shared/Config/Rarities.luau` `pity` |
| New pity save fields | `sinceMythic`, `sinceSecret`, `sinceDivine` | Proposed (schema bump) | `S/Schema.luau` |
| x2 luck every | 10 | Current | `S/RollConfig.luau` `BONUS_EVERY` |
| Odds 1-in, 7 tiers (C/U/R/E/L/M/S) | 2/5/25/250/2500/25000/100000 | Current | `S/RarityConfig.luau` `ONE_IN` |
| Odds 1-in, 8 tiers (C/U/R/E/L/M/S/D) | 2/4/15/100/1000/20000/100000/500000 | Proposed (reverses ROADMAP 1.3, needs Ghost's OK) | `src/shared/Config/Rarities.luau` |
| Variant odds Shiny/Golden/Rainbow | 1/50, 1/500, 1/5000 | Proposed | `src/shared/Config/Rarities.luau` `variants` |
| Variant stat bonus | +5% / +10% / +15% (cap, no stacking) | Proposed | `src/shared/Config/Rarities.luau` `variants` |
| Mutation odds trait / elemental | 1/100 / 1/20 | Proposed | `src/shared/Config/Rarities.luau` `mutations` |
| Mutation effect | +2–3% trait, +3% element stat | Proposed | `src/shared/Config/Rarities.luau` `mutations` |
| Shardheart | 1/1,000,000 flat, Legendary-level stats | Proposed | `src/shared/Config/Rarities.luau` `shardheart` |
| Chase pull rule | Divine, Rainbow on Mythic+, or Shardheart, with a server announcement | Proposed | `src/shared/Config/Rarities.luau` `chase` |
| Cross-server announce topic | `ShardfallMythic` | Current | `S/RarityConfig.luau` `TOPIC` |
| Weapon traits (live) | parked, `traits` flag | Current (parked) | `S/Traits.luau` |
| Starter tokens | 10 | Current | `S/Schema.luau` `STARTER_TOKENS` |
| Free first rolls | 3 | Proposed | `src/shared/Config/Economy.luau` `freeRolls` |
| First roll floor | Rare | Current | `S/FirstSession.luau` `CONFIG.rollFloor` |
| Wave tokens (1–4, boss) | 1, 1, 2, 2, 5 (Normal clear 11) | Proposed | `src/shared/Config/Rewards.luau` `waveTokens` |
| Token multiplier N/M/H/NM/I | 1 / 1.25 / 1.5 / 2 / 3 | Proposed | `src/shared/Config/Rewards.luau` `difficultyMult` |
| Run length N/M/H/NM/I (min) | 5 / 5.5 / 6 / 7 / 9 | Proposed (assumption, verify in playtest) | sim input only, `tools/econ_sim.py` `DIFFS` |
| Enemy HP/dmg N/H/NM | 1 / 1.5 / 2 | Current | `S/Rootvault.luau` `DIFFICULTIES` |
| Enemy HP/dmg Medium / Insane | 1.25 / 3 | Proposed | `src/shared/Config/Dungeons.luau` `difficulties` |
| Level gate N/H/NM | 1 / 10 / 15 | Current | `S/Rootvault.luau` `DIFFICULTIES` |
| Level gate Medium / Insane | 5 / 20 | Proposed | `src/shared/Config/Dungeons.luau` `difficulties` |
| First clear of day | +5 tokens | Proposed | `src/shared/Config/Rewards.luau` `firstClearDaily` |
| First-ever clear | +10 tokens per difficulty | Proposed | `src/shared/Config/Rewards.luau` `firstClearEver` |
| Failed run keeps | cleared waves | Current rule | ROADMAP 3.7; `S/Dungeons.luau` |
| Old Waves token rule | 1 per 3rd wave, 2 per 5th | Current (to retire) | `S/Dungeons.luau` `waveReward` |
| Rootvault clear tokens | 3 (+40% voucher) | Current (to retire) | `S/Dungeons.luau` ROOTVAULT `rewards` |
| Arena waves | 6/8/10/12 + boss with 4 adds | Current (draft #368) | `src/shared/Config/WaveArenaConfig.luau` `waves` |
| Bag size | 100 | Current | `S/Schema.luau` `INVENTORY_CAP` |
| Paid bag expansion | +10 for 80 Robux, not for sale | Current (keep off) | `S/Currencies.luau` `INVENTORY_EXPAND_*` |
| Dups auto-convert, no slot | on | Proposed | `src/shared/Config/Economy.luau` `dupAutoConvert` |
| Variant dup Fragment mult Shiny/Golden/Rainbow | x2 / x5 / x10 | Proposed | `src/shared/Config/Economy.luau` `variantFragmentMult` |
| Mutation dup Fragment mult | x1.5 | Proposed | `src/shared/Config/Economy.luau` `mutationFragmentMult` |
| Bag slot rule | 1 slot per base item; variants and mutations in the collection | Proposed | `src/shared/Config/Economy.luau` `slotRule` |
| Tab spread W/A/P/S | 40 / 25 / 20 / 15% | Proposed (sim assumption) | sim input only, `tools/econ_sim.py` `TABS` |
| Token cap | 9,999 | Proposed | `src/shared/Config/Economy.luau` `tokenCap` |
| Fragment cap | 99,999 | Proposed | `src/shared/Config/Economy.luau` `fragmentCap` |
| Fragments per dup C/U/R/E/L/M/S/D | 1/3/10/40/200/1000/3000/10000 | Proposed | `src/shared/Config/Economy.luau` `dupFragments` |
| Live Dust per dup | 5/15/50/200/1000/5000 | Current (parked) | `S/ChestConfig.luau` `DUST` |
| Chosen Epic / Legendary | 400 / 2000 Fragments (checked vs pity, 5a) | Proposed | `src/shared/Config/Economy.luau` `fragmentShop` |
| Live Dust Epic / Legendary | 2000 / 10000 | Current (parked) | `S/ChestConfig.luau` `DUST_EPIC`, `DUST_LEGENDARY` |
| Gear +1..+5 Fragments | 20/40/80/160/320 | Proposed | `src/shared/Config/Economy.luau` `upgradeFragments` |
| Live Forge gold | 150, 300, then 500×1.6^lvl | Current (parked) | `S/Economy.luau` `upgradeCost` |
| Gold in V1 loop | cut (field kept, not shown or paid) | Proposed | n/a |
| Login tokens | 2 | Proposed | `src/shared/Config/Rewards.luau` `loginTokens` |
| Daily tokens / all-3 bonus | 3 each / 5 | Proposed | `src/shared/Config/Rewards.luau` `dailyTokens` |
| Weekly tokens | 10 each (x5) | Proposed | `src/shared/Config/Rewards.luau` `weeklyTokens` |
| Dailies per day / life | 3 / 3 days | Current | `S/Loops.luau` `DAILY_LIFE_DAYS` |
| Comeback boost | x2 tokens, 5 runs, after 7 days away | Proposed | `src/shared/Config/Rewards.luau` `comeback` |
| Auto-farm rate / cap | 40% / 2 h | Current | `S/Economy.luau` `FARM_RATE`, `FARM_SECONDS` |
| Paid luck / season pass | off / off | Current | `S/RarityConfig.luau` `PAID_LUCK_ENABLED`, `S/Loops.luau` `PREMIUM_ENABLED` |
