# Economy v1 — gear upgrade numbers

Run pay (Roll Tokens per wave) lives in `Shared/Config/Economy.luau` and is not repeated here. The live forge is `Shared/Economy.luau`. This note is the tuning sheet for gear upgrades, duplicate overflow, and the Shard Core.

Nothing here is a Robux price.

## The upgrade that already exists

The Bag **UPGRADE** button writes `item.upgrade`. Schema saves it as a whole number from **+0** to **+10** (`Economy.UPGRADE_MAX`). A missing field loads as **+0**. There is no second `item.level`.

The button label is the **gold** cost from `Economy.upgradeCost`. The hub also shows a wallet named Shards (shard tokens). Those are different. A duplicate does not spend either one.

Gold for the step that leaves the current upgrade (`level` in the function is the upgrade you have now):

| From | Gold | Gnarl's Seed |
|---|---:|---:|
| +0 | 150 | 0 |
| +1 | 300 | 0 |
| +2 | 1,280 | 0 |
| +3 | 2,048 | 0 |
| +4 | 3,277 | 0 |
| +5 | 5,243 | 0 |
| +6 | 8,389 | 0 |
| +7 | 13,422 | 1 |
| +8 | 21,475 | 1 |
| +9 | 34,360 | 1 |

`+0` and `+1` are flat. From `+2`, gold is `floor(500 * (1.6 ^ upgrade) + 0.5)`. A seed is required when the current upgrade is 7 or more (the steps that land on +8, +9, and +10).

## Why the cap is +10 for every rarity

Stage A asked for Common 5, Uncommon 6, Rare 7, Epic 8, Legendary 10. That fights the button: a Common piece can still be forged to +10, and the gold curve above is priced through that step. Duplicates use the same cap, `Economy.UPGRADE_MAX`, for every rarity including Mythic and Secret. Changing the cap means changing the forge, not adding a second ladder.

## Read-time scale (flag `upgradeScale`, off)

`1 + upgrade * 0.08` on the saved stat. Stars are already inside that saved number (`Stars.STAT_PER_STAR` is 0.08). The upgrade multiply is a second step, at read time, so the two do not bake into each other.

- +0 → ×1
- +1 → ×1.08
- +10 → ×1.80

Readers: Equip totals, combat weapon damage, combat armor HP, Item Power (`+10` per upgrade, the same step as one star), and `UpgradeScale.preview` for the Bag. The product is not written back onto `stat.value`.

The flag is separate from `gearLevels`. Gold already spends. The dupe rule is still Kevin's call. One flag would force those two decisions to move together.

Duplicates do not add upgrade levels. While `gearLevels` is on they feed stars. At ★5 they add Essence (below). A +10 piece with room for stars still takes a star. A ★5 piece does not move `item.upgrade`.

## Essence record (overflow only)

A duplicate of a piece that is already ★5 does not raise stars or `item.upgrade`. It adds this much to `profile.gearEssence` (default 0). Same numbers as the old duplicate fragments. Stage B salvages into this wallet. Stage C spends it on a Shard Core. This table is only the overflow record. The automatic feed stays behind `gearLevels` (off).

| Rarity | Essence |
|---|---:|
| Common | 1 |
| Uncommon | 3 |
| Rare | 10 |
| Epic | 40 |
| Legendary, Mythic, Secret | 200 |

## Stage C — Shard Core (flag `shardCore`, off)

One core per weapon. The level is `profile.shardCores[weaponUid]` (missing means **0**, cap **5**). Feeding spends `profile.gearEssence`. The item is not written: no `item.coreLevel`, and the core does not read `item.upgrade` or stars.

Essence to buy the next level:

| From | Essence | Unlocks (kept at higher levels) |
|---|---:|---|
| 0 → 1 | 5 | +1% crit chance (`crit_chance` +0.01) |
| 1 → 2 | 15 | +2% shard find (`shard_find` +0.02) |
| 2 → 3 | 40 | +2% move speed (`move_speed` +0.02) |
| 3 → 4 | 100 | +5% crit damage (`crit_damage` +0.05) |
| 4 → 5 | 250 | +1 luck (`luck` +1) |

A full core costs **410** Essence. That number is `Config.ShardCore.FULL_COST`. The crit-damage perk adds **0.05** to the finished multiplier (1.50 becomes 1.55). It does not multiply the finished stat.

While `shardCore` is on, a rarity sweep and auto-salvage skip a weapon whose core is level 1 or higher and report `That weapon has a Shard Core.` An explicit salvage still previews that warning (or `N weapons have a Shard Core.`) and confirm deletes the weapon. While the flag is off, the skip and the warning are absent. Equipped, locked, and favorite gear stay either way. The first `counts`, `state`, or `GetShardCore` reply in a session can include `Essence feeds a weapon's Shard Core.` That line is session memory only. `schemaVersion` stays 26.

Perks are applied once, after Equip has finished its totals (base, gear, elements, and whatever upgrade or star scale is on). While `shardCore` is off, that add does not run. They are small. None of them is required to clear. Pets have no core.

Dev Tools grants **100** Essence. That button is not a product.

## Stage B salvage (flag `gearSalvage`, off)

This section is the Stage B note that landed on `cursor/live-build-9721`. Salvage amounts are the overflow table above (`Config.Essence`). The wallet is the same `profile.gearEssence`.

`profile.gearEssence` defaults to 0. A missing, non-number, NaN, negative, or infinite value becomes 0. A fraction floors. The stored number stops at 1_000_000_000. There is no second wallet. Nothing here is sold for Robux.

Salvage, lock, auto-salvage, and the bag-full confirm read `LaunchGate.gearSalvage` (off by default).

Equipped gear stays, including `equipLoadout` when that table exists. `item.locked` is the lock. `item.favorite` stays out of salvage the same way: an explicit list returns "That item is a favorite." and a rarity sweep skips that piece. There is no second lock field.

An explicit uid list is all-or-nothing. Auto-salvage is off by default and only converts a new drop. Turning it on leaves the bag as it is.

A capped duplicate calls `GearSalvage.grant(profile, amount)` or `GearSalvage.grantCappedDupe(profile, rarity, key, ownerId)`. That write does not look at the owned item. Stage A decides when a duplicate is capped. `Accept.record` on #387 can pass `grant` as its hook so both paths share one write. Calling `grant` and `Accept.record`'s default write on the same duplicate pays twice.

### Replacing #384 Fragments

PR #384 (`echo/4-payouts`) converts duplicates to Fragments (Dust/5: 1/3/10/40/200, Mythic and Secret 200) through `PayoutService.grant`. There is no fragments save field. `LaunchGate.payouts` is off. That branch is not edited here.

When that path is wired, call `GearSalvage.grant(profile, amount)` or `GearSalvage.grantCappedDupe(profile, rarity, rollId, userId)` into `profile.gearEssence`. Do not add a fragments field. Do not also call `Accept.record`'s default write on the same duplicate.

### Save plug-in

`#381` (`echo/0.5-save-system`) is not on this base. `schemaVersion` stays 26. `GearSalvage.migrate` copies first and fills `gearEssence`, `autoSalvage`, and `autoSalvageRarity`. `Schema.template` and `Schema.reconcile` default the same fields on load. When #381's migration list lands, register that copy as one step. Do not bump the version before then.
