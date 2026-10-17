# Retention review

G-036. Daily login, streaks, comeback, and weekly goals. What is live, and what is still a gap. This file does not change code.

Choice: a missed day already pauses the streak, so this pass does not add a streak shield. A shield that protects the day-7 Epic chest would be a paid random-item saver. Comeback pay, if added later, is one free board seal. It is not luck, gear odds, or a raid skip.

Day and week stamps use unix time. A day is `floor(now / 86400)` UTC (`Loops.luau:71-72`). A week is `floor(now / 604800)`, which turns over on Thursday 00:00 UTC, not Monday (`Loops.luau:75-76`). Keep that stamp. Moving it would reset live boards.

## What is live

| hook | live rule | cite |
|---|---|---|
| Login chest | Once per UTC day. Common chest and 5 Shard Keys. Same day returns "Daily login is already claimed." | `ChestConfig.luau:120`, `ChestConfig.luau:431-444`, `ChestService.luau:173` |
| Streak | Next calendar day adds 1. The same day pays nothing again. A gap keeps the number and still pays the chest | `Loops.luau:79-90` |
| Day 7 chest | When the stored streak is a multiple of 7, add an Epic chest and 0 keys | `ChestConfig.luau:124`, `ChestConfig.luau:441-442` |
| Streak display | Bag detail reads `loginStreak` | `InventoryHud.luau:498` |
| Dailies on the list | 3 at a time, from a pool of 5. An unfinished row lasts 3 days | `Loops.luau:22`, `Loops.luau:39-45`, `Loops.luau:115-122` |
| Daily reroll | One free reroll per UTC day | `LoopService.luau:146-153` |
| All 3 done today | One `room` grant, then one Rare chest. Once per day | `LoopService.luau:78-83` |
| Quest pay | Each finish pays 150 gold, 1 Shard Key, and 100 Pass XP | `Economy.luau:19`, `LoopService.luau:51-54` |
| Weeklies | All 5 rows, every week. Higher goals on the same five ids. A new week replaces the list, the board, and `boardLines` | `Loops.luau:49-55`, `Loops.luau:526-545`, `Loops.luau:570-575` |
| Same action, both lists | One forge, dodge, hatch, pet, or room count can finish a daily and a weekly together | `Loops.luau:582-600` |
| Shard Board | 4×4. Up to 9 seals a week. 1 line: Epic chest. 2 lines: 5 Gems and 3 keys. 3 lines: Legendary chest. `boardLines` does not pay the same line twice | `Loops.luau:34`, `LoopService.luau:30-43` |
| Second Chance | Help a player under level 10, or a new player. Not yourself. Cap 9. Retry costs 1. Shuffle costs 2. Points survive the weekly reset | `Loops.luau:266-274`, `Loops.luau:286-336`, `Loops.luau:575` |
| First Rootvault clear | Once per UTC day, account XP ×3 and one Rare chest. Gold is not multiplied | `Loops.luau:518-523`, `DungeonService.luau:1323-1329` |
| Daily Gnarl | First boss kill of the UTC day grants an Epic chest and stamps the day. The button jumps to Gnarl's Heart if the stamp is open | `ChestConfig.luau:405-418`, `DungeonService.luau:2493-2518` |
| Weekly boss chest | First boss kill of the unix week also grants a Legendary chest | `ChestConfig.luau:125`, `ChestConfig.luau:420-427` |
| Pass XP | 1,000 XP per tier, 50 tiers. A clear adds 40. Premium grant, claim, and skip refuse while the switch is off | `Loops.luau:19-21`, `DungeonService.luau:1338`, `Loops.luau:348-350` |
| Free track | Gold, keys, dust, and the Boardwalker title. Claim is live | `Loops.luau:618-625`, `LoopService.luau:162-183` |
| Nightmare times | Top 10 fastest in this server's memory. Not a saved weekly board | `LoopService.luau:24`, `LoopService.luau:89-111` |

`LoopService.noteMentor` has no caller outside its own definition. Second Chance stays at 0 until a clear calls it (`LoopService.luau:231`).

## The daily list refills

`Loops.expire` drops a row when `done` is true, even on the day it was born (`Loops.luau:118`). `Loops.refresh` then fills the list back to 3 (`Loops.luau:556-568`). `LoopService.progress` refreshes before it applies the new count (`LoopService.luau:49-50`).

The next counted action after a finish can replace that daily. The five ids can pay again later the same day. The all-3 Rare chest stays once per day. The 150 gold, the key, the 100 Pass XP, and a seal do not. Seals still stop at 9. Gold, keys, and Pass XP do not.

Suggested: a finished id stays on the list until the UTC day changes, and it pays once. Unfinished rows keep the 3-day life.

## Gaps

| hook | wanted in the loop draft | live | suggested |
|---|---|---|---|
| Streak shield | 1 free shield a week | No shield. A gap pauses the number | Add none. The pause is the grace |
| 28-day calendar | Day 28 is a Legendary chest and a cosmetic | Only every 7th streak adds an Epic chest | Keep the Epic. A day-28 Legendary chest is a later content row, still free |
| Comeback gift | A return after time away feels like a reward | The paused chest is the only pay | If `today > lastLoginDay + 3`, add one free board seal, once per return. No rarity boost |
| Daily bar | Any mix of play fills one chest | Three named quests, and they refill when finished | Cap the named list first. A bar can wait |
| Weekly catch-up | Missed weeklies return 3 at a time | A new week deletes unfinished weeklies | Suggested: keep up to 3 unfinished weekly ids into the next week. Do not pay them twice |
| Weekly variety | Bigger goals than the daily five | The same five ids, larger goals, every week | Leave the ids. New sentences need a content row |
| Mentor points | Play with a new player | The function exists. Nothing calls it | Call `noteMentor` from a real clear. One point. No luck |
| Weekday | Monday reset in the draft | Thursday 00:00 UTC | Keep the unix week |
| Saved nightmare board | A weekly top 10 | Memory only, this server | Leave it until a board row exists |
| Pass slack | About 6 weeks of a season, with room to miss days | Premium is off. Free XP is 40 a clear and 100 a finish | Do not tune `PASS_XP` while the daily list can refill |
| Notifications | One opt-in note a day | None | None until the login chest is the thing they point at |

## Weekly goals, as the player sees them

| id | weekly sentence | goal | also counts for the daily |
|---|---|---|---|
| `rooms` | Clear 6 Rootvault rooms | 6 | Clear 2 Rootvault rooms |
| `dodge` | Dodge 15 attacks | 15 | Dodge 5 attacks |
| `hatch` | Hatch 3 eggs | 3 | Hatch an egg |
| `forge` | Upgrade 3 pieces of gear | 3 | Upgrade a piece of gear |
| `pet` | Pet or feed a companion 3 times | 3 | Pet or feed a companion |

A room that is not the last one counts once, and only when the run pays (`DungeonService.luau:1503-1504`). The last room counts once from the clear grant (`DungeonService.luau:1384-1385`). Practice returns before that grant (`DungeonService.luau:1300-1302`). `PracticeLoot.noteQuest` is not called from a service.

## Comeback, suggested

| away | they already get | suggested extra | they do not get |
|---|---|---|---|
| 0 days | Nothing. Already claimed | None | A second chest |
| 1 missed day | The same Common chest. Streak number unchanged | None | A reset to 0 |
| 3 or more missed days | That chest, and dailies older than 3 days are replaced | 1 board seal, once | Luck, a Rare chest, or Pass premium |

Numbers in that last column of extras are suggested.

## Counts

| | count |
|---|---|
| Live hooks in the first table | 18 |
| Gaps with a suggested change | 6 |
| Gaps left as they are | 5 |
| Paid retention items | 0 |

## Flags

Boardwalker is the free-track title at tier 30. It is not a store name. No other game's login calendar or battle-pass name is used.
