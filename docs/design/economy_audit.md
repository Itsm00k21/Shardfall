# Economy audit

G-027. Sources and sinks per live wallet, with inflation flags and suggested numbers. This file does not change code.

Read `Economy.luau`, `Currencies.luau`, and `docs/design/shardfall_economy.md`, then the modules that actually move the wallets. Line numbers are the current tip.

Choice: keep the live forge curve. It already matches the design draft (500, then about ×1.6). The starvation is the clear gold, not the curve. Suggested clear gold is below. Do not treat it as a live number.

## Wallets

`Economy.CURRENCIES` lists six names (`Economy.luau:13`). The profile also has Shard Tokens and Prism Tokens (`Currencies.luau:14-15`, `Schema.luau:189-191`). Raid Marks are a seventh live wallet and are not in that list.

| wallet | profile field | job today | cap |
|---|---|---|---|
| Gold | `gold` | Clears, quests, forge, eggs, trade tax, listing fee | none (`Schema.luau:351`) |
| Shard Keys | `shardKeys` | Buy Uncommon, Rare, and Epic chests | 99999 (`Schema.luau:492-493`) |
| Shard Dust | `shardDust` | Buy a chosen Epic or Legendary shard | 999999 (`Schema.luau:495-496`) |
| Gems | `gems` | Pass skip, when premium is on | none seen |
| Event Tokens | `eventTokens` | None. Studio grant only | none seen |
| Materials | `materials` | Craft, merge, forge bark | per id, 999 or 99 or 1 (`Materials.luau:50-210`) |
| Shard Tokens | `shardTokens` | One earned roll | none in reconcile; Studio grant stops at 9999 |
| Prism Tokens | `prismTokens` | One Robux roll, purchase still a stub | same |
| Raid Marks | `raidMarks` | Heartwood shop | weekly earn room 600 on the live grant |

Design draft still says six currencies and that trading is post-beta (`shardfall_economy.md:10-19`). `Economy.luau:8` says the same. Market and direct trade are already in `MarketBoard.luau` and `Trading.luau`.

## Gold

Live forge cost from `Economy.upgradeCost` (`Economy.luau:19-26`): `floor(500 * 1.6 ^ level + 0.5)`. Bark is charged when the current level is 7, 8, or 9.

| from | to | gold | bark charged |
|---|---|---|---|
| +0 | +1 | 500 | 0 |
| +1 | +2 | 800 | 0 |
| +2 | +3 | 1280 | 0 |
| +3 | +4 | 2048 | 0 |
| +4 | +5 | 3277 | 0 |
| +5 | +6 | 5243 | 0 |
| +6 | +7 | 8389 | 0 |
| +7 | +8 | 13422 | 1 |
| +8 | +9 | 21475 | 1 |
| +9 | +10 | 34360 | 1 |
| sum | +10 | 90794 | 3 |

| side | where | amount | cite |
|---|---|---|---|
| source | New profile | 0, then starter kit adds 250 | `Schema.luau:188`, `Onboarding.luau:53` |
| source | Each finished daily or weekly | 40 | `LoopService.luau:52`, `Loops.luau:582-600` |
| source | Free pass tier 1 and tier 20 | 150, then 400 | `Loops.luau:618-625`, `LoopService.luau:171` |
| source | Rootvault clear | 45, plus Gold Find, then farm rate | `Dungeons.luau:311`, `DungeonService.luau:1301-1316` |
| source | Heartwood clear | 60, same path | `Dungeons.luau:370` |
| source | Wave clear | `floor(8 + wave * 3)` | `Dungeons.luau:567`, `DungeonService.luau:1753` |
| source | Treasure door | 25 gold, plus a `room` chest grant, and only if the run pays | `DungeonService.luau:2576-2581` |
| sink | Forge upgrade | table above | `Economy.luau:37-44`, `CraftService.luau:132` |
| sink | Pet egg, if no egg item | 50 | `Pets.luau:13`, `PetService.luau:38-44` |
| sink | Direct trade | `floor(gold * 0.10)` | `Trading.luau:27`, `Trading.luau:337-341` |
| sink | Market listing | 5% of the gold price, minimum 1, not returned | `MarketBoard.luau:22`, `MarketBoard.luau:68-80` |
| not a faucet | Studio debug | +1000 | `DebugTools.luau:19` |

Gold Find adds `floor(base * goldFind)` (`CombatMath.luau:414-421`). Auto-farm pays 40% of that clear gold and pays 0 after 2 hours (`Economy.luau:14-15`, `Economy.luau:86-98`). Practice Grove pays nothing (`PracticeLoot.luau:32-33`).

Salvage does not pay gold. It pays materials (`Crafting.luau:105-113`).

## Shard Keys

Shop prices match the design draft: Uncommon 40, Rare 150, Epic 600. Legendary and Mythic are not sold (`ChestConfig.luau:59-64`).

| side | where | amount | cite |
|---|---|---|---|
| source | Starter kit | 40 | `Onboarding.luau:54` |
| source | Each finished daily or weekly | 1 | `LoopService.luau:53` |
| source | Board, on reaching 2 lines | 3, plus 5 Gems | `LoopService.luau:37-39` |
| source | Chest source `room` | 2, with a Common chest | `ChestConfig.luau:119` |
| source | Chest source `login` | 5, with a Common chest | `ChestConfig.luau:120` |
| source | Chest source `clear` | 8, with an Uncommon chest | `ChestConfig.luau:121` |
| source | Chest source `boss` | 10, with a Rare chest | `ChestConfig.luau:122` |
| source | All 3 dailies, once that day | one `room` grant, then one Rare chest | `LoopService.luau:78-83` |
| source | Free pass tier 5 and tier 50 | 4, then 20 | `Loops.luau:621-624` |
| source | Pass overflow, after tier 50 | 4 keys per extra tier | `Loops.luau:33`, `Loops.luau:515`, `LoopService.luau:364` |
| source | Starter goals, not wired to the wallet | 10 each, 50 if all five pay | `StarterGoals.luau:45`, `StarterGoals.luau:601` |
| sink | Key shop | 40 / 150 / 600 | `ChestConfig.luau:447-456` |
| sink | Shop door | 40 keys for one Uncommon chest, no-op if short | `DungeonService.luau:2593-2601` |

`dailyBoss`, `streak`, and `weeklyBoss` add a chest and 0 keys (`ChestConfig.luau:123-125`). No service in `src/` adds the `StarterGoals.grant` payout onto `shardKeys` yet.

## Shard Dust

| side | where | amount | cite |
|---|---|---|---|
| source | Duplicate, or a drop when the bag is full | 5, 15, 50, 200, 1000, 5000 | `ChestConfig.luau:609-611`, `ChestConfig.luau:679-692` |
| source | Free pass tier 10 | 25 | `Loops.luau:622` |
| sink | Buy an Epic shard | 2000 | `ChestConfig.luau:35`, `ChestConfig.luau:86` |
| sink | Buy a Legendary shard | 10000 | `ChestConfig.luau:36`, `ChestConfig.luau:88` |

Dust cannot buy Common through Rare, or Mythic (`ChestConfig.luau:884`). A duplicate also grants one material (`ChestConfig.luau:77-84`).

## Gems and Prism Tokens

These are different wallets. Do not merge them in the shop copy. Gems move on the pass. Prism Tokens are the Robux roll wallet, and the pack is still a pitch.

| side | wallet | where | amount | cite |
|---|---|---|---|---|
| source | Gems | Board, on reaching 2 lines | 5 | `LoopService.luau:38` |
| source | Gems | Premium track, sale off | 40 on ten tiers, 400 total | `Loops.luau:21`, `Loops.luau:30`, `Loops.luau:413-438` |
| sink | Gems | Skip one pass tier, sale off | 80 | `Loops.luau:32`, `Loops.luau:489-493` |
| source | Prism | Live purchase | none | `Currencies.luau:17-19`, `RollService.luau:340-341` |
| sink | Prism | One prism roll | 1 | `Currencies.luau:57-61` |
| pitch | Prism | Placeholder pack | 100 Robux for 10 tokens, not for sale | `Currencies.luau:67-71` |

`Loops.PREMIUM_ENABLED` is false, so the Gem refund and the 80 Gem skip do not run (`Loops.luau:21`). The only live Gem faucet found is the +5 on board line 2. Studio debug adds 50 Gems and is not a faucet (`DebugTools.luau:27`).

## Event Tokens

`Economy.grant` accepts them (`Economy.luau:68-82`). The only writer found is Studio debug, +10 (`DebugTools.luau:35`). There is no sink. Leave the faucet off until an event shop exists. A faucet with no sink is the inflation case in the design draft.

## Materials

Kill drops use the realm primary: normals pay common, elites pay rare, bosses pay boss (`Drops.luau:3-8`, `Drops.luau:36-55`). Only Verdant has a scroll chance (`Drops.luau:60-65`). Verdant forage is extra (`Drops.luau:78-95`).

| side | where | amount | cite |
|---|---|---|---|
| source | Rootvault clear | wood 4, vine 3, spore 2, bark 1, 35% heartwood | `Dungeons.luau:314-317` |
| source | Heartwood clear | same, bark 2, 50% heartwood | `Dungeons.luau:373-375` |
| source | Waves | wood 1, plus vine, spore, bark on a rhythm | `Dungeons.luau:550-558` |
| source | Salvage | common, rare, and boss by rarity | `Crafting.luau:105-113` |
| sink | Chest merge | verdant bark, heartwood, gnarl seed | `ChestConfig.luau:91-97` |
| sink | Forge +8, +9, +10 | 1 `bark` each, the common Ironbark | `Economy.luau:25`, `Economy.luau:41-42`, `Materials.luau:74-81` |

The forge error says "Needs boss bark." The spend is `materials.bark`, which is Ironbark, grade common, and not primary. The boss material is `gnarl_seed` (`Materials.luau:99-106`). The sink does not gate on a boss drop.

Stack caps stop a single id. They do not sink it.

## Shard Tokens

| side | where | amount | cite |
|---|---|---|---|
| source | New profile | 25 | `Schema.luau:31`, `Schema.luau:190` |
| source | Rootvault clear | 3 | `Dungeons.luau:312` |
| source | Heartwood clear | 4 | `Dungeons.luau:371` |
| source | Wave | 1 every 3rd wave, 2 every 5th | `Dungeons.luau:560-564` |
| source | Clear voucher | one armory or pets crack, spends no token | `Dungeons.luau:586-590` |
| sink | One shard roll, if no voucher | 1 | `Currencies.luau:50-55`, `RollService.luau:218-221` |

## Raid Marks

The wallet that pays is `Raids.applyClear`, called from the kill path (`PracticeLoot.luau:99-101`). Normal pays 40. Any other difficulty pays 25. The week room is 600, and `raidMarksEarned` resets when the week changes. There is no bank on this path (`Raids.luau:13`, `Raids.luau:111-121`).

`RaidMarks.payout` is a second table: story 25, normal 40, hard 60, shardbreaker 80, fracture 20, plus a bank of 1800 (`RaidMarks.luau:21-40`). No clear path calls it. Hard and the higher rows do not pay until something grants that payout.

| side | where | amount | cite |
|---|---|---|---|
| source | Heartwood boss, live path | 25, or 40 on normal, up to 600 earned that week | `Raids.luau:114-121` |
| sink | Rare chest | 80 | `Raids.luau:34`, `RaidService.luau:1288` |
| sink | Epic chest | 160 | `Raids.luau:35` |
| sink | Title Heartwood Student | 200 | `Raids.luau:36` |

Spending marks does not lower a lifetime counter. That counter is still a content spec, not a profile field.

## Chests, because they spend the keys

| source | chest | keys with it | cite |
|---|---|---|---|
| `room`, including the all-3 daily | Common | 2 | `ChestConfig.luau:119`, `LoopService.luau:80` |
| all-3 daily, extra | Rare | 0 | `LoopService.luau:81-82` |
| board line 1 | Epic | 0 | `LoopService.luau:34-35` |
| board line 3 | Legendary | 0 | `LoopService.luau:41-42` |
| first Rootvault clear of the day | Rare | 0 | `DungeonService.luau:1321-1325` |
| starter kit | 1 Rare and 1 Uncommon | the 40 keys above | `Onboarding.luau:58-59` |

## Flags

| id | risk | cite | note |
|---|---|---|---|
| F1 | high | `Dungeons.luau:311`, `Economy.luau:24`, `Onboarding.luau:53` | Starter gold is 250. The first forge step is 500. One Rootvault clear is 45. 2,018 of those clears pay 90,810 gold, which covers the 90,794 forge total, before other income. This is starvation, not inflation. |
| F2 | high | `Economy.luau:41-42`, `Materials.luau:74-81` | +8 to +10 spend common Ironbark and call it boss bark. The time gate the design wanted is not there. |
| F3 | medium | `Schema.luau:351` | Gold has no upper cap. Safe while clears pay 45. Not safe if income moves to the draft's 8–12k an hour with no new sink. |
| F4 | medium | `Economy.luau:8`, `MarketBoard.luau:6` | The economy module still says trading is post-beta. The 5% fee and the 10% tax are live sinks. Tune from those, not from the old sentence. |
| F5 | medium | `Raids.luau:114`, `RaidMarks.luau:21-27` | Two mark formulas. Only the flat 25/40 path pays. Wiring both would double-pay story and normal. |
| F6 | low | `DebugTools.luau:35`, `Economy.luau:75` | Event Tokens can be stored and granted, and nothing spends them. |
| F7 | low | `Currencies.luau:14-19`, `Loops.luau:413` | Design calls Gems the Robux currency. Live Robux pitch is Prism Tokens, and it is not for sale. Gems are the pass wallet. |
| F8 | low | `PetService.luau:38-44` | Five eggs cost the whole starter 250 and still leave the player short of +1. |
| F9 | low | `LoopService.luau:34-42` | One finished board pays an Epic chest, 5 Gems, 3 keys, and a Legendary chest. It is weekly, not infinite. Watch it if lines become free. |

The design hour target is 8–12k gold around level 10, with upgrades eating about 70–85% (`shardfall_economy.md:21-24`). Live clear gold cannot reach that target.

## Suggested numbers

Suggestions only. Do not change the live constants from this file.

| knob | live | suggested | why |
|---|---|---|---|
| Rootvault clear gold | 45 | 250 | Starter 250 plus one clear pays the first +1 (500). |
| Heartwood clear gold | 60 | 400 | A raid clear stays ahead of a dungeon clear. |
| Wave gold | `floor(8 + wave * 3)` | `floor(40 + wave * 15)` | Wave 1 pays 55. Wave 10 pays 190. Still under one +1. |
| Treasure door | 25 | 100 | A detour, not a clear. |
| Forge curve | 500 × 1.6 ^ level | keep | Already the draft curve. |
| Forge bark | 1 Ironbark at +8, +9, +10 | 1 `gnarl_seed` instead | Matches the error text and the draft's boss-mat gate. |
| Egg | 50 | keep | Five eggs still fit in the starter kit after the clear-gold change. |
| Key shop | 40 / 150 / 600 | keep | Matches the draft. Do not sell Legendary or Mythic. |
| Event Tokens | no faucet | keep it that way | Add a shop before any grant. |
| Gold cap | none | none yet | Revisit only if the hour target is turned on. |

Auto-farm can stay at 40% and 2 hours. It already cuts the clear faucet (`Economy.luau:14-15`).
