# Heartwood level gate test plan

G-071. The case where Story's level and Normal's level diverge. This file does not change code.

`PracticeLoot.levelGate` reads `Raids.DIFFICULTIES.story.level` and ignores the difficulty the player asked for (`PracticeLoot.luau:37-46`). `DungeonService.enter` calls that gate for every Heartwood difficulty (`DungeonService.luau:2433-2444`). The `Dungeon` remote `enter` action forwards `extra` as that difficulty (`Remotes.luau:342-347`, `DungeonService.luau:2738-2740`).

`RaidService.queue` calls `startQueue`, which rejects when `(profile.level or 1) < row.level` on that difficulty's own row (`RaidService.luau:663-674`, `RaidService.luau:201-221`).

Today both rows are 15 (`Raids.luau:29-32`). A live level 14 fails every door. A live level 15 passes every level door. The split below is not live. It is the case those two checks disagree.

Choice: illustrate the split as Story 15 and Normal 20, and the reverse as Story 20 and Normal 15. Do not write those numbers into `Raids.luau`. The pass, once the rows differ, is that queue and enter both use the asked difficulty's level.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| HW1 | Normal's level is above Story's. The Dungeon remote still lets that player into Normal | `PracticeLoot.luau:37-38`, `DungeonService.luau:2440-2444`, `RaidService.luau:219-221`, `Remotes.luau:342-347` | high | Story level 15, Normal level 20. Profile level 15, 16, 17, 18, or 19, with Story already cleared. `RaidService.queue` for `"normal"` refuses "Level 20 opens The Heartwood." `Dungeon` `enter` with dungeon id `heartwood` and extra `"normal"` accepts the level check. The same level on `"story"` is accepted by both |
| HW2 | Story's level is above Normal's. Queue's level line says yes, then enter says no | `RaidService.luau:219-221`, `RaidService.luau:264`, `RaidService.luau:140`, `DungeonService.luau:2440-2444` | high | Story level 20, Normal level 15. Profile level 15 through 19. Queue for `"normal"` passes its level line, then `launch` calls `DungeonService.enter`, and `levelGate` refuses "Level 20 opens The Heartwood." Queue for `"story"` refuses at the queue line with Level 20. Enter of either difficulty refuses with Level 20 |
| HW3 | Today the two rows match, so no live player hits HW1 or HW2 | `Raids.luau:29-32` | low | Level 14, both difficulties, queue and enter and Practice: all refuse "Level 15 opens The Heartwood." Level 15: the level line passes on both doors. Changing one row without the other fails HW1 or HW2 |
| HW4 | The Story-clear line is not a level split | `RaidService.luau:222-224`, `DungeonService.luau:2445-2447` | low | Level 15, `raidStory` false, Normal. Both doors refuse "Clear Story once before Normal." Story at the same level is not refused for that reason. Scoring this as HW1 fails the case |
| HW5 | The premade board uses Story's level for every difficulty | `RaidService.luau:334-339` | medium | Same invented split as HW1, level 16, Normal listing. `premadeGate` does not mention Level 20. It uses Story's 15, then the Story-clear line. A level 14 still fails the board. The board and the Dungeon remote stay on Story. Only queue uses the row |
| HW6 | Practice is Story's number on purpose | `RaidService.luau:1331-1338` | low | Practice calls `levelGate`, then launches `"story"`. It has no Normal level to disagree with. A level 14 practice refuses. A level 15 practice passes the level line |

HW1 is the hole. The remote admits a player the finder refused, the moment Normal's level is higher than Story's. HW3 is the lock while both stay 15.

An `EnterPad` touch calls `enter` with the dungeon attribute and no difficulty (`DungeonService.luau:2795`). Heartwood then refuses "Pick Story or Normal." (`DungeonService.luau:2436-2438`). That pad is not HW1.

`Schema` stores level as a whole number of at least 1 (`Schema.luau:508`). A saved NaN is not a profile the gate sees. Do not build the case on NaN.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| HG-1 | Live tables. Level 14. Story not cleared | Queue Story, queue Normal, `Dungeon` enter `heartwood` `story`, enter `heartwood` `normal`, then Practice | All five refuse "Level 15 opens The Heartwood." |
| HG-2 | Live tables. Level 15. Story not cleared | The same five calls | Story queue, Story enter, and Practice pass the level line. Both Normal calls refuse "Clear Story once before Normal." Neither Normal call says a level other than 15 |
| HG-3 | Live tables. Level 15. `raidStory` true | Queue Normal, and enter `heartwood` `normal` | Both pass the level line. Neither invents a second number |
| HG-4 | Harness only. Story level 15, Normal level 20. Level 16. `raidStory` true | Queue Normal, then `Dungeon` enter `heartwood` `normal` | Both refuse "Level 20 opens The Heartwood." An enter that accepts fails HW1. Do not save the harness numbers |
| HG-5 | Same harness. Level 16. `raidStory` true | Queue Story, enter `heartwood` `story`, Practice | All three pass the level line. The text uses 15 |
| HG-6 | Harness only. Story level 20, Normal level 15. Level 16. `raidStory` true | Queue Normal | The level line and the enter it calls use the same number. A queue level pass followed by "Level 20 opens The Heartwood." fails HW2 |
| HG-7 | Same harness as HG-4. Level 16. `raidStory` true | Post or join a Normal premade | The level line uses Normal's 20. A board that only checks Story's 15 fails HW5 |
| HG-8 | Live tables. Level 14, then level 15 | Practice only | 14 refuses with Level 15. 15 passes the level line. Practice does not read Normal's row |

## Flags

None. The level gate does not sell a skip. A paid field is not a level. No live number in `Raids.DIFFICULTIES` changes.
