# Pity review

G-038. What the roll promise is, where a second counter could lie, and the sentences players should read. This file does not change code.

Choice: the player sheet stays the 1-in-N draw from `RarityConfig.disclose`. Pity stays off those percents. `RollMath.odds` and the pool's `pityLegendaryAt` of 50 are not the promise. Ghost already decided this for the odds sheet. `docs/design/drop_rates.md` still says the Roll tab paints `RollMath.odds`. That sentence is stale. This file does not edit it.

## Two counters

| counter | where it lives | what it does on a crack | player may see it |
|---|---|---|---|
| `sinceEpic` / `sinceLegendary` | profile | `RarityConfig.pick` then `RarityConfig.advance` | Yes. Bars, `pityLine`, reel |
| `pity[pool].rollsSinceLegendary` | `Schema.pityBucket` | Incremented after the grant. The draw does not read it | Only as a cache key in `init.client.luau:279-295` |
| `pityLegendaryAt` 50 | every pool `Pools.luau:83` | `RollMath.roll` would force Legendary or better. `RollService` does not call `RollMath.roll` | No, unless a new panel calls `RollMath.odds` |

The crack path is `RarityConfig.pick` (`RollService.luau:234`), then `RollMath.mint` (`RollService.luau:240`). Mint does not apply pity.

`UiRouter.legendaryPity` reads `sinceLegendary` and `RarityConfig.LEGENDARY_PITY` (1000). It does not read the bucket (`UiRouter.luau:13-16`, `UiRouter.luau:273-288`).

## The live promise

Rarest first. The listed 1-in-N is the check. Common takes what remains. At luck ×1 the sheet in G-028 is the one to quote.

| rarity | 1-in-N | about, at ×1 |
|---|---|---|
| Common | 2 | 76.46% |
| Uncommon | 5 | 19.11% |
| Rare | 25 | 3.98% |
| Epic | 250 | 0.40% |
| Legendary | 2500 | 0.040% |
| Mythic | 25000 | 0.0040% |
| Secret | 100000 | 0.0010% |

| rule | live | cite |
|---|---|---|
| Epic promise | If `sinceEpic + 1` is at least 100, and the Legendary promise is not due, the roll is at least Epic | `RarityConfig.luau:44`, `RarityConfig.luau:247-248` |
| Legendary promise | If `sinceLegendary + 1` is at least 1000, that floor wins | `RarityConfig.luau:45`, `RarityConfig.luau:245-246` |
| Better than the floor | A natural Mythic or Secret is kept. The floor is not a downgrade | `RarityConfig.luau:252` |
| Item inside the rarity | Pool weight splits items after the rarity is chosen | `RarityConfig.luau:279` |
| Epic lands | `sinceEpic` returns to 0. `sinceLegendary` still adds 1 | `RarityConfig.luau:270-272` |
| Legendary, Mythic, or Secret lands | Both counters return to 0 | `RarityConfig.luau:266-269` |
| Floor the pool cannot grant | `present()[1]`, the rarest rarity the pool has, and the floor still clears the counter | `RarityConfig.luau:252-258`, `RarityConfig.luau:265-266` |
| Every 10th roll | ×2 luck on the 1-in-N check. It is not a guarantee | `RarityConfig.luau:43`, `RarityConfig.luau:114` |
| Paid luck | The potion drops out while `PAID_LUCK_ENABLED` is false | `RarityConfig.luau:19`, `RarityConfig.luau:103-113` |
| VIP | Cosmetic. Not a term in the luck formula, even when paid luck is on | `RarityConfig.luau:93`, `RarityConfig.luau:130` |

Verdant armory and Verdant pets include a Secret (weight 2), so the empty-floor fallback does not hit those two pools. A future pool that stops at Epic would clear a Legendary counter without granting a Legendary. Suggested: if the pool has nothing at the floor, do not clear the counter and do not tell the player the promise fired.

Verdant armory weights at 0 luck read about 60 / 25 / 10 / 4 / 0.80 / 0.18 / 0.02. That is the pool weight totals, and `RollMath.entryWeight` leaves them alone at 0 luck. It is not the draw (`Pools.luau:98-123`, `RollMath.luau:128-146`). `Rarities.LUCK_EXPONENT` is not these percents.

## Where the words are

| surface | what a dry account sees for Epic | cite |
|---|---|---|
| Reel odds | `Epic  1 in 250  (0.3998%)` | `RollReel.luau:515-527`, `RarityConfig.luau:446-452` |
| Legacy odds panel | `Epic    1 in 250    0.400%` | `Remotes.luau:157-170`, `Ui.luau:2205-2211`, `RollMath.luau:190-195` |
| Hub Odds list | `Epic  0.4%` | `MenuHub.luau:2811-2823`, `RollBoard.luau:112-120` |
| Hub info toggle | `Epic  0.4%` | `MenuHub.luau:2656-2662`, `RollBoard.luau:112-120` |
| Bars | `Epic n/100 · Legendary n/1000` | `RarityConfig.luau:158-173`, `RollBoard.luau:63-73` |
| Disclose notice | `Luck x1.00. Every 10th roll is x2. Epic+ at 100, Legendary+ at 1000.` | `RarityConfig.luau:434-439` |

`RollBoard.oddsLines` ignores the pity argument (`RollBoard.luau:83`). It rounds each row to 0.1 and lets the last row absorb the dust (`RollBoard.luau:112-118`).

Using the G-028 ×1 percents, that rounding is:

| rarity | sheet % | one decimal, not last | running total |
|---|---|---|---|
| Common | 76.4584 | 76.5 | 76.5 |
| Uncommon | 19.1146 | 19.1 | 95.6 |
| Rare | 3.9822 | 4.0 | 99.6 |
| Epic | 0.3998 | 0.4 | 100.0 |
| Legendary | 0.0400 | 0.0 | 100.0 |
| Mythic | 0.0040 | 0.0 | 100.0 |
| Secret | 0.0010 | last row, remainder 0.0 | 100.0 |

Rare prints as 4.0 because 3.9822% rounds to one decimal. That number matches the old pool-weight Epic figure only by coincidence. Legendary, Mythic, and Secret print as 0.0. The reel and the legacy panel still show them. The hub prints these rounded lines twice: the always-visible Odds block (`MenuHub.luau:2811-2823`) and the info toggle (`MenuHub.luau:2656-2662`).

`RollMath.pityText` returns `Pity n / 50 toward Legendary` in tests (`RollMath.luau:201-215`). Nothing in the client calls it. `RollMath.luau:10-11` still says disclosed odds come from `RollMath.odds`. They do not.

## Player-facing lines

Use these on the hub, the reel, and the legacy panel. Same words. Pity stays out of the percent.

| id | when | say |
|---|---|---|
| P1 | Odds notice | Luck x1.00. Every 10th roll is x2 luck. These percents are the draw. |
| P2 | Under the bars | Epic or better is promised at 100 dry rolls. Legendary or better is promised at 1,000. A better shard counts for both. |
| P3 | Bar | Epic 12/100 · Legendary 40/1000 |
| P4 | Each rarity | Epic  1 in 250  (0.3998%) |
| P5 | ×2 ready | x2 Luck Ready |
| P6 | ×2 waiting | x2 Luck in 4 |
| P7 | Bar at 90% | The bar pulses. The percent does not change. |
| P8 | Close call | Close call |
| P9 | Next Epic | Next Epic is the rolls left until 100. Rare has no countdown. |
| P10 | Promise due | This roll is at least Epic. The list above is the normal draw, not this roll. |
| P11 | Refusal | Keep the server sentence. Do not say Miss. Do not move either pity counter. |
| P12 | Do not say | Pity 12/50 toward Legendary. Epic 4.0% as the draw. |

P4 is `RarityConfig.formatLine`. Suggested: both hub Odds paints use that line, the same as the reel. P5 and P6 are already `RarityConfig.bonusLabel` (`RarityConfig.luau:146-155`). P8 is `UiRouter.CLOSE_BEAT` (`UiRouter.luau:308`). P9 matches `RollLoop.luau:12` and loading tip `tip_26` (`LoadingTips.luau:67`). P11 is the G-072 case. `MenuHub.luau:3205-3206` calls `RollHype.note` with `landed = false` when the result has no item.

Auto-roll stops are a separate promise. The stops are Off, Uncommon, Rare, Epic, and Legendary (`RollBoard.luau:18`). It also stops on a new template and on an upgrade (`RollLoop.luau:406-411`). Suggested line: "Auto stopped. That shard was new, or it was an upgrade." So a stop does not feel like a broken button.

## Anti-frustration

| feel | live protection | gap |
|---|---|---|
| A long dry run | Bars, a pulse from 90%, promises at 100 and 1,000 | Hub Odds lines can show 0.0% and look like those rarities do not exist |
| A "nothing" roll | A paid token that succeeds mints an item | A refusal can still paint a miss and break the session streak |
| Pity bought forward | No sku skips pity. Quick Roll is a reveal shortcut | Copy must not say the Epic wait gets shorter |
| Two promises | The UI goal is 1,000, not 50 | The profile still stores the unused bucket, and `RollMath.odds` would light 50 |
| Every 10th roll | ×2 luck, labeled | Players can mistake it for the Epic promise. P1 keeps them apart |
| Secret | On the ladder, on the reel | Hidden by the hub's one decimal |

## Counts

| | count |
|---|---|
| Live promises | 2 (Epic 100, Legendary 1,000) |
| Unused promise | 1 (pool Legendary at 50) |
| Odds surfaces | 3 (reel, legacy panel, hub). The hub paints the same rounded lines in two places |
| Surface that prints 0.0% for Secret | 1, the hub Odds lines (always-visible list and the info toggle) |
| Suggested sentences | 12 |

## Flags

The word pity here is the dry-roll promise. It is not another game's banner system. Secret stays on the sheet because a hidden outcome is called out in `RarityConfig.luau:9-11`. No paid random item ships on this list.
