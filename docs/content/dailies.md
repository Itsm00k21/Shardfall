# Daily and weekly templates

G-022. Forty sentence templates for the daily and weekly boards. The live rows stay in `Loops.luau`.

Read against `docs/design/shardfall_loops.md` and `Loops.luau`. A template is a swap, or a parked sentence. It is not a new payout. `Loops.PREMIUM_ENABLED` stays false.

| rule | live |
|---|---|
| Dailies | `Loops.POOL` has 5 rows. `rollDailies` keeps 3. They last `Loops.DAILY_LIFE_DAYS` (3). One free reroll a day. |
| Weeklies | `Loops.WEEKLY` has 5 rows. `rollWeekly` keeps 5, so the table is the whole week. |
| Track | `Loops.apply` finishes a row only when `quest.id` equals the id passed to `LoopService.progress`. |
| Calls | `rooms` from a paying dungeon advance. `dodge` from `CombatService`. `hatch` and `pet` from `PetService`. `forge` from `CraftService.upgrade` only. |
| Pay | One finish pays 40 gold, 1 Shard Key, and 100 Pass XP (`LoopService.luau` 51–54). All 3 dailies done that day also grant a Common chest and 2 Shard Keys (`ChestConfig` source `room`) plus one Rare chest (`LoopService.luau` 78–83). A weekly uses the same finish pay, because `apply` bumps both lists. |
| Board | Line chests stay in `payLines`: 1 line an Epic chest, 2 lines 5 Gems and 3 Shard Keys, 3 lines a Legendary chest. This file does not add a quest chest. |
| Paste | Replace the text and goal on the one live row with that track id. Do not add a second row with the same id. A repeated id is skipped. A new id never finishes. The pool still needs 3 unique daily ids or `rollDailies` cannot fill. |
| Rooms counter | Not Rootvault-only. A paying non-endless clear adds 1 in `grant` (`DungeonService.luau` 1372). A paying advance adds 1 in `beginAdvance` (line 1487), and endless waves take that path (line 1754). Practice adds 0. |
| First clear | `Loops.firstClear` still pays 3x XP and a Rare chest on the first Rootvault clear of the day. A rooms sentence does not replace it. |
| Parked | Track is not one of the five calls. Leave these out of `POOL` and `WEEKLY`. |
| Power | No stats, no luck, no drop odds, no Robux. No 1-in-20 lucky triple. |

Choice: the 28 wired rows are alternate sentences for the five live ids. The 12 parked rows wait for a new `progress` call. Player-facing rooms text says "dungeon rooms" because the counter is wider than the live "Rootvault" sentence. This file does not edit that live sentence.

Pace is against the live goal for that track. Short is under it. Same is within 1. Long is over it. Swap a long daily in only when the other two stay short, so the day stays near the design's 15 minutes.

## Live rows

Do not copy these into the menu. They are already the board.

| cadence | id | text | goal |
|---|---|---|---|
| daily | `rooms` | Clear 2 Rootvault rooms | 2 |
| daily | `dodge` | Dodge 5 attacks | 5 |
| daily | `hatch` | Hatch an egg | 1 |
| daily | `forge` | Upgrade a piece of gear | 1 |
| daily | `pet` | Pet or feed a companion | 1 |
| weekly | `rooms` | Clear 6 Rootvault rooms | 6 |
| weekly | `dodge` | Dodge 15 attacks | 15 |
| weekly | `hatch` | Hatch 3 eggs | 3 |
| weekly | `forge` | Upgrade 3 pieces of gear | 3 |
| weekly | `pet` | Pet or feed a companion 3 times | 3 |

`dodge` counts a dodge that `grantsProgress` allows, not only a perfect dodge (`CombatService.luau` 826–827). `pet` counts both pet and feed (`PetService.luau` 81). `hatch` spends one egg, or `Pets.EGG_COST` gold (50) when the egg pile is empty (`PetService.luau` 41–45, 58).

## Daily swaps

13 rows. `id` here is the menu id. The quest id you keep is `track`.

| id | track | text | goal | pace |
|---|---|---|---|---|
| `d_rooms_1` | `rooms` | Clear 1 dungeon room | 1 | short |
| `d_rooms_3` | `rooms` | Clear 3 dungeon rooms | 3 | long |
| `d_rooms_4` | `rooms` | Clear 4 dungeon rooms | 4 | long |
| `d_rooms_5` | `rooms` | Clear 5 dungeon rooms | 5 | long |
| `d_dodge_3` | `dodge` | Dodge 3 attacks | 3 | short |
| `d_dodge_4` | `dodge` | Dodge 4 attacks | 4 | same |
| `d_dodge_6` | `dodge` | Dodge 6 attacks | 6 | same |
| `d_dodge_8` | `dodge` | Dodge 8 attacks | 8 | long |
| `d_dodge_10` | `dodge` | Dodge 10 attacks | 10 | long |
| `d_dodge_12` | `dodge` | Dodge 12 attacks | 12 | long |
| `d_hatch_2` | `hatch` | Hatch 2 eggs | 2 | long |
| `d_forge_2` | `forge` | Upgrade 2 pieces of gear | 2 | long |
| `d_pet_2` | `pet` | Pet or feed a companion 2 times | 2 | long |

## Weekly swaps

15 rows. Same rule. Do not run a weekly goal that matches a daily you just swapped in for that track.

| id | track | text | goal | pace |
|---|---|---|---|---|
| `w_rooms_8` | `rooms` | Clear 8 dungeon rooms | 8 | long |
| `w_rooms_10` | `rooms` | Clear 10 dungeon rooms | 10 | long |
| `w_rooms_12` | `rooms` | Clear 12 dungeon rooms | 12 | long |
| `w_dodge_20` | `dodge` | Dodge 20 attacks | 20 | long |
| `w_dodge_25` | `dodge` | Dodge 25 attacks | 25 | long |
| `w_dodge_30` | `dodge` | Dodge 30 attacks | 30 | long |
| `w_hatch_4` | `hatch` | Hatch 4 eggs | 4 | long |
| `w_hatch_5` | `hatch` | Hatch 5 eggs | 5 | long |
| `w_hatch_6` | `hatch` | Hatch 6 eggs | 6 | long |
| `w_forge_4` | `forge` | Upgrade 4 pieces of gear | 4 | long |
| `w_forge_5` | `forge` | Upgrade 5 pieces of gear | 5 | long |
| `w_forge_6` | `forge` | Upgrade 6 pieces of gear | 6 | long |
| `w_pet_5` | `pet` | Pet or feed a companion 5 times | 5 | long |
| `w_pet_6` | `pet` | Pet or feed a companion 6 times | 6 | long |
| `w_pet_8` | `pet` | Pet or feed a companion 8 times | 8 | long |

## Parked

12 rows. Each needs a new progress id. If it is wired later, the finish pay stays 40 gold, 1 Shard Key, and 100 Pass XP. No extra chest on the row.

| id | cadence | text | goal | needs |
|---|---|---|---|---|
| `p_boss_1` | daily | Clear Daily Gnarl 1 time | 1 | A boss call. The Epic chest stays `ChestConfig` source `dailyBoss`. Do not grant a second one. |
| `p_roll_3` | daily | Finish 3 Armory cracks | 3 | A roll call. A free crack and a paid crack count the same. No odds change. |
| `p_trade_1` | daily | Finish 1 direct trade | 1 | A trade-complete call. Any finished direct trade. No rarity rule. |
| `p_grove_1` | daily | Clear the Training Grove 1 time | 1 | A grove call. Not side quest `grove_course`. Does not grant a second `grove_ribbon`. |
| `p_tonic_1` | daily | Craft 1 Healing Tonic | 1 | `CraftService.craft` does not call `progress`. Not the `forge` upgrade. |
| `p_mentor_1` | daily | Help 1 newer player | 1 | `noteMentor` grants a Second Chance point and does not call `progress`. Newer means under level 10, or new to that fight, and not yourself (`Loops.mentorCredit`). Cap stays 9. |
| `p_boss_3` | weekly | Clear Daily Gnarl 3 times | 3 | Same boss call as `p_boss_1`. Still one Epic boss chest per day, from the boss, not from this row. |
| `p_roll_10` | weekly | Finish 10 Armory cracks | 10 | Same roll call as `p_roll_3`. |
| `p_raid_story` | weekly | Clear 1 Heartwood wing on Story | 1 | A wing-clear call. Not the `rooms` counter. Practice does not count. Level is 15. Party mix is not checked. |
| `p_raid_normal` | weekly | Clear 1 Heartwood wing on Normal | 1 | Same wing call, Normal only. Story and Normal stay separate. Level is 15. |
| `p_mentor_3` | weekly | Help 3 newer players | 3 | Same mentor rule as `p_mentor_1`. Points still cap at 9. This row does not mint points of its own. |
| `p_tonic_3` | weekly | Craft 3 Healing Tonics | 3 | Same craft call as `p_tonic_1`. Not three upgrades. |

| band | count |
|---|---|
| Daily swaps | 13 |
| Weekly swaps | 15 |
| Parked | 12 |
| Total | 40 |

Flags: Soot and Apron (`apron_errand`) is not the `forge` line. Healing Tonic is not an upgrade. Training Grove is not `grove_course` and not Practice Grove. Daily Gnarl is not Mireoak. Heartwood Story and Normal are not the `eight_seats` check. No other game's quest name is used.
