# Economy v1 — gear upgrade numbers

Run pay (Roll Tokens per wave) lives in `Shared/Config/Economy.luau` and is not repeated here. The live forge is `Shared/Economy.luau`. This note is the tuning sheet for gear upgrades, duplicate overflow, and the later Shard Core.

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

## Read-time scale (Stage A, flag `gearLevels`, off)

`1 + upgrade * 0.08` on the rolled stat when Equip totals are computed.

- +0 → ×1 (an old item does not gain power)
- +1 → ×1.08
- +10 → ×1.80

The product is not written back onto `stat.value`. Stars already did their multiply into that saved value (`Stars.STAT_PER_STAR` is also 0.08, from ★0). The element multiplier runs after this scale. While `gearLevels` is off, totals skip the scale, so flipping Equip on does not buff a piece someone already forged.

Paid forge upgrades and free duplicate upgrades share this scale. Neither is sold for Robux.

## Essence record (overflow only)

A duplicate of a piece that is already +10 does not raise the upgrade. It adds this much to `profile.gearEssence` (default 0). Same numbers as the old duplicate fragments. Stage B is the wallet, the salvage, and the spend. This table is only the record.

| Rarity | Essence |
|---|---:|
| Common | 1 |
| Uncommon | 3 |
| Rare | 10 |
| Epic | 40 |
| Legendary, Mythic, Secret | 200 |

## Stage C — Shard Core (not built)

Nothing in the game reads this block. It is a starting sheet so the numbers can be balanced before that PR.

One core per weapon. Feed Essence to raise it. Proposed costs to reach each level: **5, 15, 40, 100, 250** Essence (levels 1 through 5). Cap 5.

Proposed perks, one each, modest, not required to clear:

1. +1% crit chance
2. +2% shard find
3. +2% move speed
4. +5% crit damage
5. +1 luck

Pets stay parked. No pet feeder.
