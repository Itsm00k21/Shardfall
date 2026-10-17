# Roblox policy notes

G-053. Paid random items, age labels, and ads, set next to what Shardfall already does. This file does not change code. It is not legal advice. The Creator Hub page wins if a line here goes stale.

Choice: v0.1 still sells nothing. Earned shard cracks stay outside the paid-random rules. No ad is added. The gap to close before any Prism sale is item-level odds on the buy button, plus a rounding disclaimer.

Sources were read 2026-10-17.

## Paid random items

A paid random item is a random outcome bought with Robux, or with a currency the player bought with Robux. A key the player found does not count. Luck boosts, pity, and rate-up items count when they are paid, and the odds on screen have to change while they are on.

| rule | source | Shardfall |
|---|---|---|
| Show every outcome as a percent. The percents sum to 100. Long decimals may round to four or more places past the first non-zero digit, with a disclaimer that the shown numbers may not sum to 100 | Creator Hub, paid random items | Earned cracks are not required to do this. We disclose anyway |
| A details control needs the word Details or Info. A bare (i) is not enough | same | Not audited on the Roll tab this pass |
| Many items in one rarity still need each item's odds, in that details view | same | `disclose` builds per-entry chances (`RarityConfig.luau:420-431`). The roll lines print rarity rows (`RollBoard.luau:101-111`) |
| Paid luck or pity must be numeric, and the shown odds update | same | Pity is in the notice (`RarityConfig.luau:434-438`). Paid luck is off (`RarityConfig.luau:18-19`) |
| An outcome cannot be a total loss of the payment | Community Standards note, May 2026 clarification | No paid roll is on sale |
| `ArePaidRandomItemsRestricted` true: the player cannot use the paid generator. Offer an earn path, a fixed list, a direct buy, or hide it | Creator Hub | `PaidRollPolicy` fails closed. Restricted players do not get paid rolls (`PaidRollPolicy.luau:57-66`, `PolicyCache.luau:136-147`) |
| A missing or failed policy also stays closed | our rule, stricter than a retry | `PaidRollPolicy.luau:33-45`. Cache message is "Checking purchase policy..." until ready (`PolicyCache.luau:41`) |
| `IsPaidItemTradingAllowed` false: that player cannot trade the paid outcome | Creator Hub | `canTrade` exists (`PaidRollPolicy.luau:73-76`). `ROBUX_ITEM_TRADING_ENABLED` is false (`Trading.luau:50`) |
| Say yes to paid random items on the maturity questionnaire if any Robux currency can buy a roll | Content maturity, paid random questions | Nothing is on sale, so the honest answer today is no. The day Prism ships, the answer becomes yes |

### What is parked

| switch | live | cite |
|---|---|---|
| Paid luck, Prism rolls, Quick Roll kill switch | false | `RarityConfig.luau:18-19` |
| Paid chests | false | `ChestConfig.luau:27` |
| Shard Pass premium | false | `Loops.luau:21` |
| Pass product id | 0 | `Loops.luau:27` |
| Prism pack | 100 Robux for 10 tokens, labeled not for sale | `Currencies.luau:17-19`, `Currencies.luau:67-71` |
| Receipts | Unknown product stays unprocessed. One id does not pay twice | `ReceiptService.luau:4-7` |
| Schema | 26 | `Schema.luau:4` |
| Ads | No `AdService` call in `src/` | search of `src/` |

Earned Shard Token cracks do not go through `PaidRollPolicy` (`PaidRollPolicy.luau:11-12`). That matches the earned-key exception. Keep it that way.

`formatPercent` prints two decimals at or above 1% and four decimals below 1% (`RarityConfig.luau:372-377`). That is enough for an earned roll. Before a paid roll, add the rounding disclaimer and show `disclose.entries`, not only the rarity line.

## Age and maturity

| rule | what it means for us |
|---|---|
| No questionnaire, and the game is treated like it is not cleared for young players | Fill the form before publish. `docs/design/launch_checklist.md` already has suggested answers |
| A game with no age-restricted content can answer one question and publish to 16+ as "Content May Vary" (DevForum, 2026-10-12) | That path misses ages 10+. Shardfall wants the full form and a Mild or Minimal label |
| Kids is about ages 5–8 and wants Minimal or Mild. Select is about ages 9–15 and can include Moderate. Both need the full form (Creator Hub, Kids and Select) | Aim at Mild: fantasy combat, no gore, no real-world weapons as the fantasy. The checklist already says this |
| 17+ is unavailable in some countries and is the wrong label for this game | Do not answer the form toward Restricted |
| Paid random items are a questionnaire question, separate from violence | Answer no until a Robux roll exists |
| Inaccurate answers can take the game down | Re-answer the form the week a paid random item or a voice feature ships |
| Premade titles | The launch checklist says they go through `TextService`. This pass did not re-open that call |

Suggested maturity for the current build is Mild, same as the launch checklist. That is a suggestion for the form, not a rating Roblox has assigned.

## Ads

| rule | source | Shardfall |
|---|---|---|
| Rewarded video for under-13 is not allowed. Do not attach a reward to an ad for those players | Advertising Standards, updated 2026-10-09. DevForum, 2026-03-20 | No rewarded video |
| Use Roblox rewarded video. Independent rewarded video was to be gone after 2026-05-04 | DevForum, 2026-03-20 | Nothing to migrate |
| Disclose the reward and the required action before the video. The reward cannot be Robux | Advertising Standards | Not applicable until an ad exists |
| `AreAdsAllowed` is the PolicyService flag for immersive ads | PolicyService docs | We do not read it. We have no immersive ads |
| A continuous autoplay feed that pays the player to keep watching is not allowed in Kids and Select. Roblox rewarded video is treated differently when the player starts it and Roblox rate-limits it | DevForum, 2026-08-25 | Do not build a feed |

Glassmarch, if it ever uses the ad row in `docs/research/merge_army_loop.md`, has to follow this table. Under-13 players get the boost on a timer with no video.

## Before any Robux roll

| step | done when |
|---|---|
| 1 | Product id is real and `ReceiptService` grants that sku only |
| 2 | `PolicyCache.allowPaid` still fails closed |
| 3 | The buy button shows every entry's percent, summing to 100, with a rounding disclaimer |
| 4 | Paid luck, if it is ever turned on, changes those percents on screen |
| 5 | Restricted players still crack earned shards |
| 6 | Paid outcomes stay bound while `IsPaidItemTradingAllowed` is false |
| 7 | The maturity form is answered yes for paid random items |
| 8 | No ad is required to roll |

## Sources

| page | retrieved |
|---|---|
| https://create.roblox.com/docs/production/monetization/paid-random-items | 2026-10-17 |
| https://create.roblox.com/docs/reference/engine/classes/PolicyService | 2026-10-17 |
| https://create.roblox.com/docs/production/promotion/content-maturity | 2026-10-17 |
| https://create.roblox.com/docs/production/publishing/kids-and-select | 2026-10-17 |
| https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards | page says updated 2026-10-09 |
| DevForum, paid-random clarification | 2026-05-26 |
| DevForum, advertising standards and rewarded video | 2026-03-20 |
| DevForum, Kids and Select media-feed rule | 2026-08-25 |
| DevForum, simpler publish path | 2026-10-12 |
