# XP curve

G-029. Levels 1–100, with time targets. Live account XP stops at 20. Suggested hours use 5,175 XP per engaged hour and no rest bonus. This file does not change code.

Read `Progression.luau`. The live formula is `floor(100 * level^1.6 + 0.5)` and the beta cap is 20 (`Progression.luau:6-7`, `Progression.luau:12`, `Progression.luau:28-37`). Reaching level 20 takes 86,877 XP. The only account grant today is a dungeon clear: Rootvault 40, Heartwood 80, waves `floor(6 + wave * 2)` (`Dungeons.luau:313`, `Dungeons.luau:372`, `Dungeons.luau:569`, `DungeonService.luau:1337`). At 40 XP a clear, level 20 is 2,172 Rootvault clears.

Choice: keep the live formula for levels 1–19. Suggested income below is what makes those levels take the hours in the table. Levels 20–99 use a slower step so level 60 stays near 150 hours. Level 100 is a suggested soft cap.

## Suggested hour

An engaged hour is 7.5 Rootvaults, about 8 minutes each. Kill credit is suggested. It is not in the build. The day's first-clear x3 stays on the 40, and does not multiply kill credit.

| source | live XP | suggested XP | in one engaged hour | XP that hour |
|---|---|---|---|---|
| Rootvault clear | 40, or 120 on the day's first | keep | 7.5 clears | 300 |
| Normal kill credit | 0 | 50 | 5 per clear | 1,875 |
| Elite kill credit | 0 | 100 | 2 per clear | 1,500 |
| Boss kill credit | 0 | 200 | 1 per clear | 1,500 |
| Hour | | | | 5,175 |

Heartwood stays 80 on the clear. Suggested boss credit there is 200 each, on top of the 80, and only when Practice Grove is off.

Class XP is a different bar. A kill grants 24 class XP and a swing grants 4 (`init.server.luau:113`). Class levels cost `40 * level`, cap 30 (`Classes.luau:13`, `Classes.luau:398-403`). Do not add class XP to this table.

Rest after 8 hours offline doubles the next 1,800 `addXp` calls. Welcome back after 14 days doubles the next 10,800 and adds a Rare chest. The two do not stack past +100% (`Progression.luau:13-16`, `Progression.luau:49-59`). Hours below ignore rest.

A multiple of 5 also grants one Rare chest (`Progression.luau:87-92`).

## Formula

| band | xp to next | note |
|---|---|---|
| 1–19 | `floor(100 * level^1.6 + 0.5)` | Same as live |
| 20–99 | `floor(12068 * sqrt(level / 20) + 0.5)` | 12,068 is the live formula with the cap lifted at level 20 |
| 20 live | 0 | Cap. The suggested column is the lift |
| 100 | 0 | Suggested soft cap |

## Milestones

Hours are suggested, at 5,175 XP per hour, no rest. "Clears" is how many live 40-XP Rootvaults reach that level today.

| arrive at | suggested XP so far | suggested hours | live Rootvault clears at 40 XP |
|---|---|---|---|
| 1 | 0 | 0 | 0 |
| 5 | 1,902 | 0.37 | 48 |
| 8 | 7,223 | 1.40 | 181 |
| 10 | 13,372 | 2.58 | 335 |
| 15 | 40,198 | 7.77 | 1,005 |
| 20 | 86,877 | 16.79 | 2,172 |
| 60 | 757,639 | 146.40 | cap already hit |
| 100 | 1,717,491 | 331.88 | cap already hit |

Level 20 at 16.79 hours sits inside the 15–20 hour note. Level 60 at 146 hours sits next to the 150 hour note. Level 100 is a post-launch tail, about 332 hours. The older 45-minute, 1.5-hour, and 4-hour marks in `shardfall_progression.md` are faster than this even rate. This table keeps the even rate.

## Levels 1–100

Live xp is blank after 20 because the cap returns 0 from level 20 on, and there is no level 21 in code. Suggested cum is the XP required to arrive at that level. Suggested hours use the 5,175 pace.

| level | live xp to next | suggested xp to next | suggested cum to arrive | suggested hours |
|---|---|---|---|---|
| 1 | 100 | 100 | 0 | 0.00 |
| 2 | 303 | 303 | 100 | 0.02 |
| 3 | 580 | 580 | 403 | 0.08 |
| 4 | 919 | 919 | 983 | 0.19 |
| 5 | 1313 | 1313 | 1902 | 0.37 |
| 6 | 1758 | 1758 | 3215 | 0.62 |
| 7 | 2250 | 2250 | 4973 | 0.96 |
| 8 | 2786 | 2786 | 7223 | 1.40 |
| 9 | 3363 | 3363 | 10009 | 1.93 |
| 10 | 3981 | 3981 | 13372 | 2.58 |
| 11 | 4637 | 4637 | 17353 | 3.35 |
| 12 | 5330 | 5330 | 21990 | 4.25 |
| 13 | 6058 | 6058 | 27320 | 5.28 |
| 14 | 6820 | 6820 | 33378 | 6.45 |
| 15 | 7616 | 7616 | 40198 | 7.77 |
| 16 | 8445 | 8445 | 47814 | 9.24 |
| 17 | 9305 | 9305 | 56259 | 10.87 |
| 18 | 10196 | 10196 | 65564 | 12.67 |
| 19 | 11117 | 11117 | 75760 | 14.64 |
| 20 | 0 | 12068 | 86877 | 16.79 |
| 21 | — | 12366 | 98945 | 19.12 |
| 22 | — | 12657 | 111311 | 21.51 |
| 23 | — | 12941 | 123968 | 23.96 |
| 24 | — | 13220 | 136909 | 26.46 |
| 25 | — | 13492 | 150129 | 29.01 |
| 26 | — | 13760 | 163621 | 31.62 |
| 27 | — | 14022 | 177381 | 34.28 |
| 28 | — | 14279 | 191403 | 36.99 |
| 29 | — | 14532 | 205682 | 39.75 |
| 30 | — | 14780 | 220214 | 42.55 |
| 31 | — | 15025 | 234994 | 45.41 |
| 32 | — | 15265 | 250019 | 48.31 |
| 33 | — | 15502 | 265284 | 51.26 |
| 34 | — | 15735 | 280786 | 54.26 |
| 35 | — | 15964 | 296521 | 57.30 |
| 36 | — | 16191 | 312485 | 60.38 |
| 37 | — | 16414 | 328676 | 63.51 |
| 38 | — | 16635 | 345090 | 66.68 |
| 39 | — | 16852 | 361725 | 69.90 |
| 40 | — | 17067 | 378577 | 73.15 |
| 41 | — | 17279 | 395644 | 76.45 |
| 42 | — | 17488 | 412923 | 79.79 |
| 43 | — | 17695 | 430411 | 83.17 |
| 44 | — | 17900 | 448106 | 86.59 |
| 45 | — | 18102 | 466006 | 90.05 |
| 46 | — | 18302 | 484108 | 93.55 |
| 47 | — | 18500 | 502410 | 97.08 |
| 48 | — | 18696 | 520910 | 100.66 |
| 49 | — | 18889 | 539606 | 104.27 |
| 50 | — | 19081 | 558495 | 107.92 |
| 51 | — | 19271 | 577576 | 111.61 |
| 52 | — | 19459 | 596847 | 115.33 |
| 53 | — | 19645 | 616306 | 119.09 |
| 54 | — | 19830 | 635951 | 122.89 |
| 55 | — | 20013 | 655781 | 126.72 |
| 56 | — | 20194 | 675794 | 130.59 |
| 57 | — | 20373 | 695988 | 134.49 |
| 58 | — | 20551 | 716361 | 138.43 |
| 59 | — | 20727 | 736912 | 142.40 |
| 60 | — | 20902 | 757639 | 146.40 |
| 61 | — | 21076 | 778541 | 150.44 |
| 62 | — | 21248 | 799617 | 154.52 |
| 63 | — | 21419 | 820865 | 158.62 |
| 64 | — | 21588 | 842284 | 162.76 |
| 65 | — | 21756 | 863872 | 166.93 |
| 66 | — | 21923 | 885628 | 171.14 |
| 67 | — | 22088 | 907551 | 175.37 |
| 68 | — | 22252 | 929639 | 179.64 |
| 69 | — | 22415 | 951891 | 183.94 |
| 70 | — | 22577 | 974306 | 188.27 |
| 71 | — | 22738 | 996883 | 192.63 |
| 72 | — | 22897 | 1019621 | 197.03 |
| 73 | — | 23056 | 1042518 | 201.45 |
| 74 | — | 23213 | 1065574 | 205.91 |
| 75 | — | 23370 | 1088787 | 210.39 |
| 76 | — | 23525 | 1112157 | 214.91 |
| 77 | — | 23679 | 1135682 | 219.46 |
| 78 | — | 23832 | 1159361 | 224.03 |
| 79 | — | 23985 | 1183193 | 228.64 |
| 80 | — | 24136 | 1207178 | 233.27 |
| 81 | — | 24286 | 1231314 | 237.94 |
| 82 | — | 24436 | 1255600 | 242.63 |
| 83 | — | 24584 | 1280036 | 247.35 |
| 84 | — | 24732 | 1304620 | 252.10 |
| 85 | — | 24879 | 1329352 | 256.88 |
| 86 | — | 25025 | 1354231 | 261.69 |
| 87 | — | 25170 | 1379256 | 266.52 |
| 88 | — | 25314 | 1404426 | 271.39 |
| 89 | — | 25457 | 1429740 | 276.28 |
| 90 | — | 25600 | 1455197 | 281.20 |
| 91 | — | 25742 | 1480797 | 286.14 |
| 92 | — | 25883 | 1506539 | 291.12 |
| 93 | — | 26023 | 1532422 | 296.12 |
| 94 | — | 26163 | 1558445 | 301.15 |
| 95 | — | 26302 | 1584608 | 306.20 |
| 96 | — | 26440 | 1610910 | 311.29 |
| 97 | — | 26577 | 1637350 | 316.40 |
| 98 | — | 26714 | 1663927 | 321.53 |
| 99 | — | 26850 | 1690641 | 326.69 |
| 100 | — | 0 | 1717491 | 331.88 |

## Flags

None.
