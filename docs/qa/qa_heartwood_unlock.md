# Heartwood unlock line test plan

G-108. A level 15 player can queue Story while the unlock list still lacks `heartwood`, and a level 20 player's list includes it. This file does not change code.

`Progression.UNLOCKS` puts `heartwood` at level 20 (`Progression.luau:28`). `Progression.unlocked` adds an id only when the account level is at least that row (`Progression.luau:42-54`). `Raids.DIFFICULTIES` story and normal are both level 15 (`Raids.luau:29-32`). `RaidService.queue` calls `startQueue`, which rejects when `(profile.level or 1) < row.level` on the asked row (`RaidService.luau:663-674`, `RaidService.luau:219-221`). That check does not call `Progression.unlocked`. Nothing in `src/` calls `unlocked` except the function itself.

Live flags: `LaunchGate.SHOW.raids` is false (`LaunchGate.luau:12`), `hardMode` is false (`LaunchGate.luau:53`), and `extraDifficulties` is false (`LaunchGate.luau:52`). `HardMode.isHardReal` is false while `hardMode` is off (`HardMode.luau:105-107`). With those flags, `unlocked(15)` is `class`, `talent`, `craft`. It skips `hard` and `nightmare`, and it does not include `heartwood`. `unlocked(20)` adds `heartwood` and still skips `hard` and `nightmare`. The list is the same at 14, 15, and 19.

Choice: turn `raids` on only inside the harness for the queue cases, then turn it off. While it stays false, `queue` returns "That is closed." before the level line (`RaidService.luau:664-666`). Role `flex` passes `Raids.roleOk` with no class (`Raids.luau:61-63`). Both difficulty rows stay 15. This plan does not split them.

## Lists

| level | `unlocked` with live hard and nightmare flags | Story queue level line, raids on |
|---|---|---|
| 14 | `class`, `talent`, `craft`. No `heartwood` | Refuses "Level 15 opens The Heartwood." |
| 15 | Same three. No `heartwood` | Passes. The list did not change |
| 19 | Same three. No `heartwood` | Passes |
| 20 | Those three plus `heartwood` | Passes. Account cap is 20 (`Progression.luau:15`) |

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| HU1 | Level 15 queues Story. The unlock list still lacks `heartwood` | `RaidService.luau:219-221`, `Progression.luau:28`, `Progression.luau:44-54`, `Raids.luau:29-32` | high | Raids on. Level 15. `queue` `"story"` `"flex"` passes the level line. `unlocked(15)` is `class`, `talent`, `craft`. A gate that waits for `heartwood` in that list refuses a player the queue accepts |
| HU2 | Level 20 is the first list that includes `heartwood`. The queue has already been open for five levels | `Progression.luau:28`, `Progression.luau:42-54`, `Progression.luau:15` | high | Raids on. Level 20. `unlocked(20)` contains `heartwood`. Story queue still passes on 15, not on 20. Levels 15, 16, 17, 18, and 19 are the whole window |
| HU3 | The list does not change at 15. Only the queue does | `Progression.luau:27-28`, `RaidService.luau:219-221` | medium | Level 14 and level 15 return the same three ids. Level 14 queue refuses with Level 15. Level 15 queue passes. Scoring them as the same door fails HU1 |
| HU4 | Raids off hides the level line | `RaidService.luau:664-666`, `LaunchGate.luau:12` | low | Any level, raids off. Queue returns "That is closed." and does not read `UNLOCKS`. That refusal is not HU1. Turn raids back off after the harness |
| HU5 | Normal's story-clear line is not the unlock list | `RaidService.luau:222-224` | low | Level 15, `raidStory` false, raids on. Story queue passes the level line. Normal refuses "Clear Story once before Normal." The unlock list is the same either way |

HU1 is the hole. HU2 is the same hole measured at the cap. The unlock list is not the queue.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| HU-1 | Raids on. Level 15. No story clear | `RaidService.queue` `"story"` `"flex"`, then `Progression.unlocked(15)` | The level line passes. The list is `class`, `talent`, `craft` and does not contain `heartwood` |
| HU-2 | Raids on. Level 20 | Queue Story, then `unlocked(20)` | The level line passes. The list contains `heartwood` |
| HU-3 | Raids on. Level 14, then level 19 | Queue Story at each level. Read `unlocked` at 14, 15, and 19 | 14 refuses "Level 15 opens The Heartwood." 19 passes the level line. All three lists match HU-1 and lack `heartwood` |
| HU-4 | Raids off. Level 15 and level 20 | Queue Story | Both return "That is closed." The level-20 list still contains `heartwood`. Do not leave raids on |
| HU-5 | Raids on. Level 15. `raidStory` false | Queue Story, then queue Normal | Story passes the level line. Normal refuses "Clear Story once before Normal." Neither call reads `UNLOCKS` |

## Flags

None. The unlock row does not sell a skip. A paid field is not a level. No live number in `Raids.DIFFICULTIES` or `Progression.UNLOCKS` changes.
