# Shardfall Economy v1 (Phase 4 sheet)

Status: **draft for review**. Docs only. Nothing in `src/` changes from this file.
Author: Echo (support lane), Oct 21, 2026 (PT). Spec: issue #15 comment 6333741405, item 3.
Base: `cursor/live-build-9721`. Roadmap: `docs/ROADMAP.md` Phase 4.

## How to read this sheet

- **Current** = the value is in the repo today. The source file is cited next to it.
- **Proposed** = a new number from this sheet. It is not in the repo. Ghost decides whether it goes into config.
- **Missing** = the repo has no value for this. A proposal is given.

Paths: `S/` = `src/ReplicatedStorage/Shared/`. The roadmap says all numbers will live in `src/shared/Config/` (ROADMAP ground rule 6, milestone 0.3). That folder does not exist on the base branch yet. The only file there is `WaveArenaConfig.luau` on draft PR #368. Proposed config paths below use `src/shared/Config/` to match the roadmap.

Free-to-play rule for every row: nothing here costs Robux and nothing is pay-to-win. Roll Tokens and Fragments are earn-only. Pity is free and never sold (`S/RollConfig.luau` header). The paid kill switch stays off (`S/RarityConfig.luau` `PAID_LUCK_ENABLED = false`).

---

## 1. Currencies

The roadmap reshapes the six live currencies into **Roll Tokens + Fragments** (+ Gold only if needed) (ROADMAP salvage map, "Currencies → 4.1").

| Currency | Job | Live name today | Status |
|---|---|---|---|
| Roll Tokens | Pay for rolls. 1 token = 1 roll. | Shard Tokens, `shardTokens` (`S/Currencies.luau` `SHARD`, `S/Schema.luau`) | Current wallet, renamed in Phase 4 (**Proposed** rename only, field id stays `shardTokens` so saves don't migrate) |
| Fragments | Bad-luck protection. Duplicates turn into Fragments, and Fragments buy progress. | Closest is Shard Dust, `shardDust` (`S/ChestConfig.luau` `DUST`) | **Missing** as a V1 wallet. Shard Dust / dup merging is in the Parking Lot and "needs Kevin's OK" (ROADMAP Parking Lot). Proposed below; needs Kevin's OK before build. |
| Gold | Everyday money | `gold` (`S/Economy.luau`) | Current. Only kept if Phase 2+ needs it. Not part of this loop. |
| Prism Tokens | Robux roll wallet | `prismTokens` (`S/Currencies.luau`) | Current but **off** (`PAID_LUCK_ENABLED = false`). Not part of V1. Stays off. |

**Roll Tokens**
- Sources (current): new profile `Schema.STARTER_TOKENS = 10` (`S/Schema.luau:170`); Rootvault clear 3 (`S/Dungeons.luau` ROOTVAULT `rewards.shardTokens`); Heartwood clear 4 (same file); old Waves mode 1 token every 3rd wave, 2 every 5th (`Dungeons.waveReward`); a clear voucher at 40% Rootvault / 20% Heartwood (`voucherChance`).
- Sources (**Proposed** for V1): wave arena waves (section 2), dailies and weekly (section 7), 3 free first rolls (section 3).
- Sinks (current): 1 per single roll, 9 per x10 (`RollConfig.SINGLE_COST = 1`, `RollConfig.cost(10)`).
- Cap: **Missing** in profile reconcile (economy_audit.md says "none in reconcile; Studio grant stops at 9999"). **Proposed** cap 9,999.

**Fragments**
- Sources (**Proposed**): duplicates from rolls (section 5). Nothing else in V1.
- Sinks (**Proposed**): buy a chosen Epic or Legendary from the current tab's pool, and later gear upgrades (section 6).
- Cap: **Proposed** 99,999. (Live Shard Dust cap is 999,999 in `S/ChestConfig.luau` / `S/Schema.luau`.)

---

## 2. Income per run (wave arena)

Wave layout is current on draft PR #368: waves of 6, 8, 10, 12, then 1 boss with 4 adds (`src/shared/Config/WaveArenaConfig.luau` `waves`). The arena has **no reward fields**. All token numbers below are **Proposed**.

The closest live numbers are the old Waves mode (`Dungeons.waveReward`: 0, 0, 1, 0, 2 tokens for waves 1–5 = 3) and a Rootvault clear (3 tokens + 40% voucher). At 3 tokens a run, one run buys 3 singles and an x10 takes 3 runs. The roadmap target is "about 1 run = a few rolls" (ROADMAP 4.4), and the loop needs a run to feel like it paid. So the proposal pays more.

| Wave | Enemies (current, #368) | Roll Tokens, Normal (**Proposed**) |
|---|---|---|
| 1 | 6 | 1 |
| 2 | 8 | 1 |
| 3 | 10 | 2 |
| 4 | 12 | 2 |
| 5 boss | 1 boss + 4 adds | 3 |
| **Full clear** | | **9** (= one x10 roll) |

- **Difficulty multiplier (Proposed):** Normal x1.0, Hard x1.5, Nightmare x2.0, applied to the run total and rounded half up. The live Rootvault difficulties already use 1 / 1.5 / 2 for enemy HP and damage (`S/Rootvault.luau` `DIFFICULTIES`), so pay tracks danger. Live rows have **no** reward multiplier, only chest tier (Common / Uncommon / Rare). Hard and Nightmare are Phase 5 (ROADMAP 5.4, 5.5); level gates live at 10 and 15 (`S/Rootvault.luau`).
- **First clear of the day (Proposed):** +5 tokens once a day. Live first clear of the day pays x3 XP + a Rare chest (`S/Loops.luau` `firstClear`); chests are parked, so tokens replace the chest.
- **First-ever clear (Proposed):** +10 tokens once per difficulty. Gives a new player a second x10 right after their first win.
- **Failed or left run:** keep tokens from every cleared wave, no clear bonuses (ROADMAP 3.7 "Leave anytime, keep loot from cleared waves"; live text in `S/Dungeons.luau` "Rewards from cleared waves are still yours"). Dying on the boss pays 6 of 9 on Normal.
- **Fragments from runs (Proposed):** none. Fragments come only from duplicates, so runs feed rolls and rolls feed Fragments (ROADMAP scope rule 6).

| Difficulty | Full clear | Failed on boss (waves 1–4) | First of day | First ever |
|---|---|---|---|---|
| Normal | 9 | 6 | +5 | +10 |
| Hard | 14 (13.5 rounded) | 9 | +5 | +10 |
| Nightmare | 18 | 12 | +5 | +10 |

---

## 3. Roll costs

| Item | Value | Status / source |
|---|---|---|
| Single roll | 1 token | Current, `RollConfig.SINGLE_COST` |
| x10 roll | 9 tokens (10% off) | Current, `RollConfig.MULTI_COUNT = 10`, `MULTI_DISCOUNT = 0.10`, `RollConfig.cost` |
| Batch rule | x10 needs 10 free bag slots and 9 tokens before anything is spent | Current, `RollConfig.batchBlock` |
| Epic+ pity | 50 rolls | Current, `RollConfig.EPIC_PITY = 50` |
| Legendary+ pity | 1000 rolls | Current, `RollConfig.LEGENDARY_PITY = 1000` |
| x2 luck roll | every 10th roll | Current, `RollConfig.BONUS_EVERY = 10`, `RarityConfig.luckMultiplier` |
| 3 free first rolls | 3 rolls, no token | **Missing** as a count. Roadmap 1.5 asks for it. Live gives 10 starter tokens (`Schema.STARTER_TOKENS`) and one floored first roll (`FirstSession.CONFIG.rollFloor = "Rare"`). **Proposed:** `freeRolls = 3`, first one keeps the Rare floor. Keep the 10 starter tokens so the first x10 is one run away. |

**When pity resets (current):** any Epic or better, natural or forced, resets the Epic counter. Legendary+ resets both (`RarityConfig.advance`). Saved as `sinceEpic` / `sinceLegendary`.

**Does x10 count as 10?** Yes, current. A batch is 10 server rolls in a row, each advancing pity (`S/RollBatch.luau`, `RollService`). Pity can fire on any roll inside the batch. 50 = exactly five x10s (`RollConfig` header).

**Odds (current, 7 tiers):** Common 1/2, Uncommon 1/5, Rare 1/25, Epic 1/250, Legendary 1/2500, Mythic 1/25000, Secret 1/100000 (`S/RarityConfig.luau` `ONE_IN`). Roadmap 1.3 moves to 5 tiers; that collapse is not done yet, so this sheet keeps 7.

---

## 4. Pacing targets

Run length target is about 5 minutes (ROADMAP Phase 3 "done when"). Rolls per run = tokens x 10 / 9 when spent on x10s.

| Difficulty | Tokens / run (**Proposed**) | Rolls / 5-min run | Runs to 50 pity | Minutes to pity | 15-min session | 1-hour session |
|---|---|---|---|---|---|---|
| Normal | 9 | 10 | 5 | 25 | 3 runs, 27 tokens, 30 rolls | 12 runs, 108 tokens, 120 rolls (+16 daily, +5 first clear) |
| Hard | 14 | ~15.5 | 3.2 | ~16 | 42 tokens, ~46 rolls | 168 tokens, ~186 rolls |
| Nightmare | 18 | 20 | 2.5 | ~13 | 54 tokens, 60 rolls | 216 tokens, 240 rolls |

**Time to first item at each rarity (Normal, from the sim in section 9, median):**
Uncommon ~4 min, Rare ~5 min, Epic ~10 min (pity carries this; natural Epic+ is ~0.44%/roll per `RollConfig` header), Legendary ~7.6 h (mostly the 1000 pity), Mythic and Secret are rare chase items (under 6% and 2% of players in 10 h).

What a session feels like (Proposed target):
- **15 minutes:** 3 runs, three x10s, at least one Epic (pity fires around roll 50 if luck doesn't). Matches the Checkpoint fun test (ROADMAP: "Kevin wants to keep playing after 15 min").
- **1 hour:** 12 runs, ~130 rolls with dailies, 2–3 Epics, a full pity bar every 25 min.

---

## 5. Duplicates

V1 Fragments are **Proposed** (Parking Lot item, needs Kevin's OK). Live Shard Dust per duplicate is current in `S/ChestConfig.luau` `DUST`. Proposed Fragments are live Dust / 5, so the numbers stay readable at roll volume.

| Rarity | Live Shard Dust per dup (current) | Fragments per dup (**Proposed**) |
|---|---|---|
| Common | 5 | 1 |
| Uncommon | 15 | 3 |
| Rare | 50 | 10 |
| Epic | 200 | 40 |
| Legendary | 1000 | 200 |
| Mythic | 5000 | 1000 |
| Secret | none listed | 1000 |

What Fragments buy (**Proposed**):
- Chosen Epic from the tab's pool: 400 (live Dust price 2000, `ChestConfig.DUST_EPIC`, / 5).
- Chosen Legendary: 2000 (live 10000, `ChestConfig.DUST_LEGENDARY`, / 5).
- Mythic and Secret are never sold for Fragments (matches live rule that Dust can't buy Mythic, `ChestConfig.buyDustShard`).
- Gear upgrades, section 6.

Alternative live path: `S/Stars.luau` feeds a duplicate into the kept item (+8% stats per star, max 5). It is parked under the `stars` flag. If Kevin prefers stars over Fragments, the dup table above becomes "star progress" and section 6 shrinks.

---

## 6. Gear sinks

Gear upgrading is **out of scope for Phase 2** (ROADMAP Phase 2: "Upgrading gear, fusing, salvaging, Shard Dust"). So V1 launches with no gear sink. This section reserves the budget so it doesn't fight rolling later.

Live Forge (parked, `forgeCraft` flags): +0→+10, paid in Gold. +1 = 150, +2 = 300, then `floor(500 * 1.6^level + 0.5)`; 1 boss material from level 7 (`S/Economy.luau` `upgradeCost`, `UPGRADE_MAX = 10`).

**Proposed** Fragment upgrade path (+1 to +5 only, post-Checkpoint):

| Step | Fragments (**Proposed**) | Cumulative |
|---|---|---|
| +0→+1 | 20 | 20 |
| +1→+2 | 40 | 60 |
| +2→+3 | 80 | 140 |
| +3→+4 | 160 | 300 |
| +4→+5 | 320 | 620 |

Budget check (sim, Normal): a player earns ~300 Fragments/hour. One item to +5 = ~2 h of dups. A full 5-slot loadout to +5 = 3,100 = ~10 h. A chosen Epic (400) competes with ~1.3 upgrades, which is the intended choice. Upgrades never destroy items (`S/Economy.luau` header).

---

## 7. Daily and weekly rewards

Live dailies: 3 a day from a pool, each lasts 3 days, one reroll (`S/Loops.luau` `POOL`, `DAILY_LIFE_DAYS = 3`). Live payout is 40 gold + 1 Shard Key per daily (economy_audit.md, `LoopService.luau`). Login streak pauses, never resets (`Loops.login`). Weekly = 5 quests (`Loops.WEEKLY`). Most live daily texts point at parked systems (eggs, forge, pets), so ROADMAP 6.7 rewrites them for rolling and dungeons.

**Proposed V1 token payout:**

| Source | Tokens | Notes |
|---|---|---|
| Login (once a day) | 2 | streak never resets |
| Each daily (x3) | 3 | e.g. "Clear 3 waves", "Roll 20 times", "Clear a run" |
| All 3 dailies bonus | 5 | |
| First clear of the day | 5 | section 2 |
| Each weekly (x5) | 10 | 50 a week ≈ 7/day |

**Typical day (Normal, 45 minutes = 9 runs):** runs 81 + login 2 + dailies 9 + all-3 bonus 5 + first clear 5 + weekly share ~7 = **~109 tokens ≈ 121 rolls**. Dailies are ~25% of a light day and ~10% of a 2-hour day, so they reward coming back without replacing play.

---

## 8. Balance risks

| Risk | Why | Mitigation (**Proposed**) |
|---|---|---|
| Farming the easiest difficulty | If Normal tokens/min beats Hard, players sit on Normal | Hard pays x1.5 for x1.5 enemy HP. Watch clear time: if Hard takes >1.5x Normal's time, raise Hard to x1.75. Log clear times (section 10). Harder runs also get better shard odds in Phase 5 (ROADMAP 5.6). |
| Hoarding | Players bank tokens for a "luck" moment | Pity is per player and doesn't care when you roll. Token cap 9,999 ≈ 92 h of Normal. |
| Inflation | Tokens only enter, rolls only remove; Fragments can pile up | Every token has one sink (rolls). Fragments get two sinks (chosen shard, upgrades). Event tokens stay off until a shop exists (economy_audit F6). |
| New vs veteran gap | Veterans have 1000s of rolls; new players feel behind | Power comes from rarity, not count. Fragments cap progress with rising costs. Comeback boost (section 11). No trading in V1 (parked), so veterans can't funnel. |
| Element pick | One element best → everyone rolls one tab | ROADMAP balance rule: Ember / Frost / Void stay close. Log element mix. |
| Bots / AFK | Free token farm | Anti-AFK in Phase 6 (6.3). Live auto-farm pays 40% for 2 h max (`S/Economy.luau` `FARM_RATE`, `FARM_SECONDS`). |

---

## 9. Simulation

**Design.** 1,000 simulated players x 10 hours each. Each player starts with 10 tokens (current `STARTER_TOKENS`) and 3 free rolls (proposed). Runs take 5 minutes; 10% of runs fail at a random wave and keep cleared-wave tokens. Tokens are spent on x10 as soon as 9 are held. Each roll uses the current 7-tier `ONE_IN` odds, x2 luck every 10th roll, Epic pity 50 and Legendary pity 1000 with the live reset rules. Daily income is added every 2 hours of play (one "day"). Duplicates assume proposed pool sizes per tab: Common 12, Uncommon 10, Rare 8, Epic 6, Legendary 4, Mythic 2, Secret 1.

Two profiles: **Normal only**, and **Ladder** (Normal until 2.5 h, Hard until ~7.8 h, then Nightmare, matching level-10 / level-15 gate times in `docs/design/pacing.md`).

Script: Python, run on Echo's box with seed 42. Not committed (docs only). Can be added as `tools/econ_sim.py` if wanted.

**Sim output from those inputs** (current odds and pity, proposed income):

```
== profile normal: 1000 players x 10 h
rolls in 10h: median 1303.0, p10 1293, p90 1313
fragments in 10h: median 3071.5
  Common: 100.0% reached; median first at 0 min
  Uncommon: 100.0% reached; median first at 4 min
  Rare: 100.0% reached; median first at 5 min
  Epic: 100.0% reached; median first at 10 min
  Legendary: 97.8% reached; median first at 458 min
  Mythic: 5.6% reached; median first at 250 min
  Secret: 1.4% reached; median first at 462 min
== profile ladder: 1000 players x 10 h
rolls in 10h: median 1903.0, p10 1883, p90 1923
fragments in 10h: median 4688.0
  Common: 100.0% reached; median first at 0 min
  Uncommon: 100.0% reached; median first at 2 min
  Rare: 100.0% reached; median first at 5 min
  Epic: 100.0% reached; median first at 10 min
  Legendary: 99.6% reached; median first at 356 min
  Mythic: 7.5% reached; median first at 402 min
  Secret: 2.0% reached; median first at 325 min
```

Read: Normal gives ~130 rolls/hour. Every player hits Epic by ~10 min. Legendary arrives by ~6–7.5 h for almost everyone, mostly via the 1000 pity. Mythic and Secret stay true chase items. Fragments ~300/h Normal, ~470/h Ladder.

---

## 10. Analytics hooks

Server-side only (ROADMAP "Analytics to add early", milestone 0.8).

- **Economy source events:** `tokens_earned {source: wave|clear_bonus|first_clear|login|daily|weekly|free_roll, amount, difficulty, balance}`; `fragments_earned {rarity, amount, balance}`.
- **Economy sink events:** `tokens_spent {kind: single|x10, amount, balance}`; `fragments_spent {kind: chosen_shard|upgrade, amount}`.
- **Roll events:** rolls per session, x10 vs x1 share, auto-roll use (ROADMAP Phase 1 metrics), `pity_fired {tier, roll_index}`, natural vs forced Epic share.
- **Run events:** run start, wave reached, run end (cleared / left / died), death wave, run length, difficulty (ROADMAP Phase 3 metrics), Run Again rate (Phase 4).
- **Balance:** tokens per minute by difficulty, median token balance (hoarding), top 1% balance, time to first Epic and first Legendary.
- **Funnel step 7:** "Second roll with earned tokens" (ROADMAP funnel).

---

## 11. Notes for later phases

- **Phase 5 (twists):** Hard / Nightmare pay x1.5 / x2 here; ROADMAP 5.6 adds better shard odds on harder runs. Chests may come back for Hard / Nightmare (`chests` flag). Keep chest value out of token math.
- **Pets (Phase 2 basic, evolution parked):** pets roll on their own tab with the same tokens. No pet currency.
- **Events (Phase 8):** event tokens only with an event shop, expire or convert at the end (`docs/design/shardfall_economy.md`). Event rewards are cosmetic or extra rolls, never exclusive power.
- **Season pass:** stays **off** (`Loops.PREMIUM_ENABLED = false`, `pass` flag off). If it ever turns on, the paid track is cosmetic only, matching the live premium track rule ("Cosmetics and the Gem refund only. No gold, keys, dust, or stats", `S/Loops.luau`). Free track may pay tokens.
- **Comeback boost (Proposed):** a player away 7+ days gets x2 run tokens for their next 5 runs (about 45 extra tokens = 5 x10s). Streak already pauses instead of resetting (`Loops.login`).

---

## 12. Tuning table

| Key | Value | Status | Config path |
|---|---|---|---|
| Single roll cost | 1 | Current | `S/RollConfig.luau` `SINGLE_COST` |
| x10 count | 10 | Current | `S/RollConfig.luau` `MULTI_COUNT` |
| x10 discount | 0.10 (9 tokens) | Current | `S/RollConfig.luau` `MULTI_DISCOUNT` |
| Max batch | 10 | Current | `S/RollConfig.luau` `MAX_BATCH` |
| Epic pity | 50 | Current | `S/RollConfig.luau` `EPIC_PITY` |
| Legendary pity | 1000 | Current | `S/RollConfig.luau` `LEGENDARY_PITY` |
| x2 luck every | 10 | Current | `S/RollConfig.luau` `BONUS_EVERY` |
| Odds 1-in (C/U/R/E/L/M/S) | 2/5/25/250/2500/25000/100000 | Current | `S/RarityConfig.luau` `ONE_IN` |
| Starter tokens | 10 | Current | `S/Schema.luau` `STARTER_TOKENS` |
| Free first rolls | 3 | Proposed | `src/shared/Config/Economy.luau` `freeRolls` |
| First roll floor | Rare | Current | `S/FirstSession.luau` `CONFIG.rollFloor` |
| Wave tokens (1–4, boss) | 1, 1, 2, 2, 3 | Proposed | `src/shared/Config/Rewards.luau` `waveTokens` |
| Difficulty multiplier N/H/NM | 1.0 / 1.5 / 2.0 | Proposed | `src/shared/Config/Rewards.luau` `difficultyMult` |
| Enemy HP/dmg N/H/NM | 1 / 1.5 / 2 | Current | `S/Rootvault.luau` `DIFFICULTIES` |
| Hard / Nightmare level gate | 10 / 15 | Current | `S/Rootvault.luau` `DIFFICULTIES` |
| First clear of day | +5 tokens | Proposed | `src/shared/Config/Rewards.luau` `firstClearDaily` |
| First-ever clear | +10 tokens | Proposed | `src/shared/Config/Rewards.luau` `firstClearEver` |
| Failed run keeps | cleared waves | Current rule | ROADMAP 3.7; `S/Dungeons.luau` |
| Old Waves token rule | 1 per 3rd wave, 2 per 5th | Current (to retire) | `S/Dungeons.luau` `waveReward` |
| Rootvault clear tokens | 3 (+40% voucher) | Current (to retire) | `S/Dungeons.luau` ROOTVAULT `rewards` |
| Arena waves | 6/8/10/12 + boss w/ 4 adds | Current (draft #368) | `src/shared/Config/WaveArenaConfig.luau` `waves` |
| Token cap | 9,999 | Proposed | `src/shared/Config/Economy.luau` `tokenCap` |
| Fragment cap | 99,999 | Proposed | `src/shared/Config/Economy.luau` `fragmentCap` |
| Fragments per dup C/U/R/E/L/M/S | 1/3/10/40/200/1000/1000 | Proposed | `src/shared/Config/Economy.luau` `dupFragments` |
| Live Dust per dup | 5/15/50/200/1000/5000 | Current (parked) | `S/ChestConfig.luau` `DUST` |
| Chosen Epic / Legendary | 400 / 2000 Fragments | Proposed | `src/shared/Config/Economy.luau` `fragmentShop` |
| Live Dust Epic / Legendary | 2000 / 10000 | Current (parked) | `S/ChestConfig.luau` `DUST_EPIC`, `DUST_LEGENDARY` |
| Gear +1..+5 Fragments | 20/40/80/160/320 | Proposed | `src/shared/Config/Economy.luau` `upgradeFragments` |
| Live Forge gold | 150, 300, then 500×1.6^lvl | Current (parked) | `S/Economy.luau` `upgradeCost` |
| Login tokens | 2 | Proposed | `src/shared/Config/Rewards.luau` `loginTokens` |
| Daily tokens / all-3 bonus | 3 each / 5 | Proposed | `src/shared/Config/Rewards.luau` `dailyTokens` |
| Weekly tokens | 10 each (x5) | Proposed | `src/shared/Config/Rewards.luau` `weeklyTokens` |
| Dailies per day / life | 3 / 3 days | Current | `S/Loops.luau` `DAILY_LIFE_DAYS` |
| Comeback boost | x2 tokens, 5 runs, after 7 days away | Proposed | `src/shared/Config/Rewards.luau` `comeback` |
| Auto-farm rate / cap | 40% / 2 h | Current | `S/Economy.luau` `FARM_RATE`, `FARM_SECONDS` |
| Paid luck / season pass | off / off | Current | `S/RarityConfig.luau` `PAID_LUCK_ENABLED`, `S/Loops.luau` `PREMIUM_ENABLED` |
