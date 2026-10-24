# Drop rates

G-028. Live chances per source, plus suggested rates where a second table disagrees. This file does not change code.

Read `Rarities.luau`, `RarityConfig.luau`, and `Drops.luau`, then the modules that actually grant the drop. Decision, Ghost, 2026-10-17: the Roll sheet keeps the 1-in-N draw. `RarityConfig.pick` and `RarityConfig.disclose` are the authoritative odds (Common about 76.46% at luck x1, Epic about 0.3998%). Pool weights only split items inside a chosen rarity. They are not the rarity odds. Numbers in the suggested column are suggestions.

## Rolls

The server draws a rarity with `RarityConfig.pick` (`RollService.luau:233`), then an item of that rarity by pool weight (`RarityConfig.chooseEntry`). `GetOdds` returns `RarityConfig.disclose` (`Remotes.luau:169`). The Roll tab's always-visible Odds list (`MenuHub.luau:2811-2823`) and the info toggle (`MenuHub.luau:2659-2662`) both paint `RollBoard.oddsLines` (`RollBoard.luau:85-112`). That function prints `RarityConfig.formatLine` (`RarityConfig.luau:446-452`), the same line as the reel (`RollReel.luau:527`): two decimals at 1% or more, four decimals under 1%. Those lines are the disclose sheet. They are not pool weights and they are not `RollMath.odds`. The info toggle starts closed (`MenuHub.luau:300`). `RollMath.odds` (`RollMath.luau:282`) is the weight table. The crack does not call it.

`Rarities.ORDER` is Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret (`Rarities.luau:15`). Secret stays on the sheet. A hidden outcome is called out in `RarityConfig.luau:9-11`.

Live 1-in-N at luck x1, full ladder, rarest first. The listed 1-in-N is the check. The percent is what remains after rarer checks. Common absorbs the rest, so its percent is wider than "1 in 2".

| rarity | live 1-in-N | live percent at x1 | pool-weight reading |
|---|---|---|---|
| Common | 2 | 76.4584% | 60% |
| Uncommon | 5 | 19.1146% | 25% |
| Rare | 25 | 3.9822% | 10% |
| Epic | 250 | 0.3998% | 4% |
| Legendary | 2500 | 0.0400% | 0.80% |
| Mythic | 25000 | 0.0040% | 0.18% |
| Secret | 100000 | 0.0010% | 0.02% |

The 1-in-N column is `RarityConfig` (`RarityConfig.luau:47-55`). The percent column is `disclose` at multiplier 1. That column is the sheet. The Roll tab prints it with `formatLine`, so Epic is `Epic  1 in 250  (0.3998%)`, Legendary is `0.0400%`, Mythic is `0.0040%`, and Secret is `0.0010%`. None of those is `0.0%`. The pool-weight column is Verdant armory and Verdant pets, whose rarity weights are the same 10,000: 6000, 2500, 1000, 400, 80, 18, 2 (`Pools.luau:102-154`). At 0 luck those weights are what `RollMath.odds` would print. The Roll tab does not print them. Epic on the draw is 0.3998%, not 4.0%.

| rule | live | suggested |
|---|---|---|
| Draw | `RarityConfig.pick`, rarest first | Keep |
| Sheet the player reads | Roll tab and `GetOdds` use `RarityConfig.disclose`, printed with `formatLine` | Decided. The sheet is the 1-in-N draw. Pool weights only split items inside the rarity. |
| Epic pity | Guarantee Epic+ at 100 (`RarityConfig.luau:44`) | Keep. Pity stays off the percent |
| Legendary pity | Guarantee Legendary+ at 1000 (`RarityConfig.luau:45`) | Keep |
| Pool `pityLegendaryAt` | `RarityConfig.LEGENDARY_PITY` (1000) on every pool (`Pools.luau:87`). The draw does not read the field. There is no Legendary guarantee at 50. The per-pool save bucket stays on schema 24 and the crack does not increment it (`RollService.luau:250-251`) | Leave it off the sheet |
| Every 10th roll | x2 luck (`RarityConfig.luau:43`, `RarityConfig.luau:114`) | Keep |
| Luck math on the draw | `oneIn / multiplier` (`RarityConfig.luau:138-147`) | Keep |
| `Rarities.LUCK_EXPONENT` | Used by `RollMath.entryWeight` (`RollMath.luau:131`). Marked placeholder (`Rarities.luau:27`) | Leave it off the draw |

Paid luck, the VIP x1.2, and the potion add only while `PAID_LUCK_ENABLED` is on (`RarityConfig.luau:19`, `RarityConfig.luau:91-118`). A paid roll uses the same rarity table as a free roll.

Inside a chosen rarity, weight still picks the item. Verdant armory commons are 1000 each, so they split evenly. Verdant pet commons do not.

| pet | rarity | live weight | live share of that rarity | suggested weight |
|---|---|---|---|---|
| Moss Hare | Common | 3500 | 58.33% of Common | 3000 |
| Acorn Newt | Common | 2500 | 41.67% of Common | 3000 |

Suggested weights keep the Common total at 6000. The rarity percents above do not move.

## Mobs

Kill drops are materials. Gear rarity is not on this table. Auto-Farm uses the same rows (`Drops.luau:7-8`). Only Verdant enemies are listed (`Drops.luau:67-74`). Sunken, Emberforge, Frostveil, and Void have a realm bundle and no enemy id, so `Drops.entries` returns nothing for them.

Chance 1 pays every kill. A range rolls an integer from min to max.

| enemy | role | live drop | chance | count |
|---|---|---|---|---|
| Vine Crawler | normal | Verdant Bark | 1 | 1–2 |
| Vine Crawler | normal | Living Vine | 1 | 1–2 |
| Vine Crawler | normal | Verdant Wood | 1 | 1 |
| Spore Bat | normal | Verdant Bark | 1 | 1–2 |
| Spore Bat | normal | Spore Cap | 1 | 1–2 |
| Moss Crawler | normal | Verdant Bark | 1 | 1–2 |
| Moss Crawler | normal | Spore Cap | 1 | 1–2 |
| Root Brute | elite | Heartwood | 1 | 1 |
| Root Brute | elite | Thornbound Scroll | 0.15 | 1 |
| Root Brute | elite | Ironbark | 1 | 1 |
| Thorn Sprite | elite | Heartwood | 1 | 1 |
| Thorn Sprite | elite | Thornbound Scroll | 0.15 | 1 |
| Thorn Sprite | elite | Living Vine | 1 | 1 |
| Grandmother Gnarl | boss | Gnarl's Seed | 1 | 1 |
| Grandmother Gnarl | boss | Thornbound Scroll | 0.35 | 1 |

Realm bundle: normal pays the common primary, elite the rare primary, boss the boss primary (`Drops.luau:36-55`). Verdant primaries are Verdant Bark, Heartwood, and Gnarl's Seed (`Materials.luau:83-105`). The scroll is Verdant only (`Drops.luau:60`). Boss scroll chance is `min(1, 0.15 + 0.2)`.

A non-boss Verdant kill also rolls a Common chest at 0.02 (`ChestConfig.luau:34`, `ChestConfig.luau:393-402`). Bosses skip that roll.

| source | live | suggested |
|---|---|---|
| Material rows above | chance 1, scrolls 0.15 and 0.35 | Keep. Recipes stay farmable |
| Gear on a kill | none | Keep gear on rolls and chests |
| Other realms | no enemy rows | When a realm gets enemies, copy this shape: common 1 (1–2), rare 1 (1), boss 1 (1), scroll only if that realm has a scroll id |
| Common chest on a normal or elite | 0.02 | Keep |

## Chests

Percents below are the live `ODDS` rows. Each row sums to 100. A 0 is outside that chest (`ChestConfig.luau:40-48`). Luck moves weight inside the allowed rarities and cannot turn a 0 into a drop (`ChestConfig.luau:268-294`).

| chest | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Common | 70 | 25 | 4.5 | 0.5 | 0 | 0 |
| Uncommon | 0 | 75 | 20 | 4.5 | 0.5 | 0 |
| Rare | 0 | 0 | 80 | 17 | 2.8 | 0.2 |
| Epic | 0 | 0 | 0 | 85 | 13.5 | 1.5 |
| Legendary | 0 | 0 | 0 | 0 | 92 | 8 |
| Mythic | 0 | 0 | 0 | 0 | 0 | 100 |

Secret is not a chest tier (`ChestConfig.luau:38`).

| pity | live | suggested |
|---|---|---|
| Rare chest | Epic+ on open 20 (`ChestConfig.luau:32`, `ChestConfig.luau:583-584`) | Keep |
| Epic chest | Legendary on open 15 (`ChestConfig.luau:33`, `ChestConfig.luau:586-587`) | Keep |
| Common, Uncommon, Legendary, Mythic | no pity counter | Keep |

| source | live grant | keys with it |
|---|---|---|
| Enemy chest roll | Common chest, chance 0.02 | 0 |
| Room | Common chest | 2 |
| Login | Common chest | 5 |
| Clear | Uncommon chest | 8 |
| Boss kill | Rare chest, every kill | 10 |
| Daily boss | Epic chest, first boss kill that day | 0 |
| Login streak | Epic chest when the streak is a multiple of 7 | 0 |
| Weekly boss | Legendary chest, first boss kill that week | 0 |

Shop prices stay Uncommon 40, Rare 150, Epic 600. Legendary and Mythic are not sold (`ChestConfig.luau:59-64`). Suggested: keep this whole chest table.

## Bosses and raid chests

Grandmother Gnarl's kill row is in the mob table. Every boss kill then calls `ChestConfig.bossKill`: a Rare chest every time, plus the daily Epic and the weekly Legendary on their first stamp (`PracticeLoot.luau:107-110`, `ChestConfig.luau:405-428`).

A Heartwood boss does that and also rolls `Raids.applyClear` (`PracticeLoot.luau:99-106`). One wing can pay both.

| boss | live chests on the kill | suggested |
|---|---|---|
| Rootvault Normal | Rare from `bossKill`. Floor chest is Common, and only Uncommon or Rare floors are added (`PracticeLoot.luau:111-114`, `Rootvault.luau:14`) | Keep |
| Rootvault Hard | Rare from `bossKill`, plus the Uncommon floor | Keep |
| Rootvault Nightmare | Rare from `bossKill`, plus the Rare floor | Keep |
| Heartwood Story | Rare from `bossKill`, and a 0.20–0.80 roll for another Rare | On a hit, skip the `bossKill` Rare. Daily Epic and weekly Legendary stay |
| Heartwood Normal | Rare from `bossKill`, and a 0.20–0.80 roll for an Epic | Same. The weekly roll stays the difficulty chest |

Heartwood rooms use Grandmother Gnarl's material row, so each wing also drops one Gnarl's Seed (`Dungeons.luau:364-367`, `Drops.luau:73`).

`Raids.applyClear` allows one chest roll per boss per difficulty per week (`Raids.luau:97-136`). Later clears in that week still pay Marks and skip that roll. They still run `bossKill`.

| difficulty | live chest on a hit | level gate |
|---|---|---|
| Story | Rare | 15 (`Raids.luau:20`) |
| Normal | Epic | 15 (`Raids.luau:21`) |

| dry streak before this roll | live chance | suggested |
|---|---|---|
| 0 | 0.20 | Keep |
| 1 | 0.30 | Keep |
| 2 | 0.40 | Keep |
| 3 | 0.50 | Keep |
| 4 | 0.60 | Keep |
| 5 | 0.70 | Keep |
| 6 or more | 0.80 | Keep |

Base 0.20, step 0.10, cap 0.80 (`Raids.luau:14-16`). A hit zeros that boss's pity. A miss adds 1. Expected rolls until the first chest, from a fresh pity, is about 2.96. Four wings in one fresh Story week, all at 0.20, hit at least one Rare chest about 59% of the time (`1 - 0.80^4`).

Practice Grove pays nothing (`PracticeLoot.luau:32-33`).

Suggested: when a gear table replaces this chest, the gear uses this same 0.20 / 0.10 / 0.80 schedule and the chest grant stops. The two do not stack.

## Clear bonuses

These sit on the clear, beside the per-kill rows.

| clear | live always | live Heartwood chance | live voucher chance | suggested |
|---|---|---|---|---|
| Rootvault | Verdant Wood 4, Living Vine 3, Spore Cap 2, Ironbark 1 | 0.35 | 0.40 | Keep |
| Heartwood | Verdant Wood 4, Living Vine 3, Spore Cap 2, Ironbark 2 | 0.50 | 0.20 | Keep |

`Dungeons.luau:310-318`, `Dungeons.luau:369-376`, `Dungeons.luau:575-599`. The voucher is an armory crack or a pets crack, even odds, and spends no shard token. Wave materials are fixed by wave number (`Dungeons.luau:548-572`), not a chance.

## Flags

None. No borrowed names.
