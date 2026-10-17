# Pacing

G-030. Minute 0 through minute 30, then day 1, day 3, and day 7. Suggested XP is the G-029 pace. This file does not change code.

Choice: the first 30 minutes follow `Onboarding.STEPS` and the live gates in `Rootvault.DIFFICULTIES` and `Raids.DIFFICULTIES`. The unused `Progression.UNLOCKS` row that names Heartwood at 20 is not the queue. The queue opens at 15.

Live account XP is one dungeon grant (`DungeonService.luau:1319-1337`). The suggested column is the target grant for that minute. It is not what the build pays today.

## Gates the clock uses

| unlock | live gate | where |
|---|---|---|
| Rootvault Normal | account level 1 | `Rootvault.luau:14` |
| Rootvault Hard | account level 10 | `Rootvault.luau:15` |
| Rootvault Nightmare | account level 15 | `Rootvault.luau:16` |
| Heartwood Story and Normal | account level 15 | `Raids.luau:20-21`, `RaidService.luau:218` |
| Class, rolls, pet, chest text | level 1 | `Progression.luau:20` |
| Talent text and dailies text | level 5 | `Progression.luau:21` |
| Crafting text | level 8 | `Progression.luau:22` |
| Heartwood text | level 20 | `Progression.luau:25` |

`Progression.unlocked` has no caller outside that module. Class talent is class level 5 (`Classes.luau:14`). Class XP is a second bar (`Classes.xpForLevel`, 40 times the class level). Do not add it to account XP.

Starter kit, skip or finish: 250 gold, 40 Shard Keys, one Rare chest, one Uncommon chest, three Healing Tonics (`Onboarding.luau:52-64`). The first pet stays unminted until the Shardjaw hold lifts. `FirstSession` can require a Rare-or-better first roll, a Rare weapon, an Uncommon armor piece, and a free Uncommon ring. Treat those four as the target for this clock. Confirm the kit calls them before a playtest marks them done.

Starter goals after Haven, three at a time, 10 Shard Keys each: Forge, Rootvault, 10 rolls, level 5, guild (`StarterGoals.luau:57-63`).

## First 30 minutes

Suggested XP sums to 1,902 at minute 20, which is account level 5 with an empty bar, then to 2,592 at minute 30, still level 5 at 690 / 1,313. Reward rule from the progression draft: something small every 2–3 minutes. Empty minutes are travel, a door look, or a menu.

| min | beat | live today | suggested XP | cum | level |
|---|---|---|---|---|---|
| 0 | Cold open line. Skip lands in Haven with the same kit | step `open` | 0 | 0 | 1 |
| 1 | Five pedestals. Pick Warden, Tidecaller, Forgeborn, Frostblade, or Voidcaster | step `class` | 0 | 0 | 1 |
| 2 | Saplings. Third hit launches | step `swing` | 80 | 80 | 1 |
| 3 | Fight ends. One level-up flash | same step | 80 | 160 | 2 |
| 4 | Red telegraph on a charger | step `dodge` | 0 | 160 | 2 |
| 5 | Dodge lands. Short praise, no second lecture | same step | 40 | 200 | 2 |
| 6 | Two doors. Both safe. Player looks, then picks | step `door` | 40 | 240 | 2 |
| 7 | Mini-boss, two telegraphs | design beat | 180 | 420 | 3 |
| 8 | Loot burst. Uncommon armor if `FirstSession` miniboss is on | design beat | 0 | 420 | 3 |
| 9 | First shard roll. Target is Rare or better, then it stays fair | design beat | 80 | 500 | 3 |
| 10 | Socket the shard. Attacks change | design beat | 0 | 500 | 3 |
| 11 | Open the starter Rare chest | kit chest is live | 0 | 500 | 3 |
| 12 | Arrive in Haven. Forge, Roll, Rootvault gate | step `haven` | 120 | 620 | 3 |
| 13 | Tracker shows Forge, Rootvault, Roll 10 | starter goals live | 80 | 700 | 3 |
| 14 | First Forge craft. Goal pays 10 keys once | forge exists | 120 | 820 | 3 |
| 15 | Pet slot stays empty while the Shardjaw hold is on | no mint | 0 | 820 | 3 |
| 16 | Login chest. Streak does not reset on a missed day | login chest live | 40 | 860 | 3 |
| 17 | Read the Rootvault gate. Normal is level 1 | gate live | 60 | 920 | 3 |
| 18 | One short wilds pull on the way | kill XP is 0 live | 200 | 1120 | 4 |
| 19 | Second pull | kill XP is 0 live | 400 | 1520 | 4 |
| 20 | Third pull. Account level 5. Goal can pay 10 keys | level goal live | 382 | 1902 | 5 |
| 21 | Enter Rootvault Normal | level 1 gate | 0 | 1902 | 5 |
| 22 | Choked Thicket. Two Vine Crawlers. 50 each | materials live, XP on clear only | 100 | 2002 | 5 |
| 23 | Door. Treasure or elite, both fine | doors live | 0 | 2002 | 5 |
| 24 | Spore Canopy. Three normals. 50 each | same | 150 | 2152 | 5 |
| 25 | Door | doors live | 0 | 2152 | 5 |
| 26 | Brute Den. Two elites. 100 each | same | 200 | 2352 | 5 |
| 27 | Door | doors live | 0 | 2352 | 5 |
| 28 | Gnarl's Heart. Boss 200 | seed and scroll live | 200 | 2552 | 5 |
| 29 | Clear pays the live 40, plus the day's first clear at x3 when it is the first | 40 live, 120 if first today | 40 | 2592 | 5 |
| 30 | Haven recap. Rootvault goal pays 10 keys once. Next text: Hard is level 10 | recap line exists | 0 | 2592 | 5 |

Minute 29's suggested 40 is the repeatable clear. The day's first clear is 120 in the live code (`Loops.luau:518-523`). A playtest that starts on a fresh day should expect 120 there, and the cum moves to 2,672, still level 5.

Watch at minute 30: did they clear, did they hit level 5, did the tracker pay Forge and Rootvault once each, did a refused roll show the server reason.

## After the first half hour

Suggested pace from G-029: 5,175 account XP per engaged hour, no rest bonus. Rest doubles the next grants until its charges run out (`Progression.luau:13-16`). Time targets below are the no-rest line.

| mark | suggested account level | what they can do | what to watch |
|---|---|---|---|
| Day 1, 90 minutes total | 7 | One Rootvault, Forge goal, level-5 goal, pity bars visible, bag filters | Drop-off before the clear |
| Day 3, about 3 engaged hours | 11 | Crafting text at 8, Hard Rootvault at 10, three login days, one item on the forge curve | They still know the next bar |
| Day 7, 1 hour a day | 14 | Nightmare and Heartwood still closed. Dailies are a habit. Rolls past the first 10 | They are not stuck on gold |
| Day 7, 90 minutes a day | 16 | Heartwood Story queue is open (level 15). A clear is a stretch goal, not the requirement | Party of 4 finds the board. Solo is sent to Practice Grove |

Level hours at 5,175 XP per hour with no rest: level 5 at 0.37 h, level 8 at 1.40 h, level 10 at 2.58 h, level 15 at 7.77 h, level 20 at 16.79 h. The older 45-minute / 1.5-hour / 4-hour lines in `shardfall_progression.md` are faster than this even rate. This plan uses the even rate so level 20 stays inside 15–20 hours.

| day-7 stretch | rule |
|---|---|
| Heartwood Story | Level 15, party 4 to 8, one reserved server |
| Solo | Practice Grove, no loot |
| Party under 4 | Finder and premade refuse. Loading tip says so |
| Gear from the raid | Still a chest roll, one per boss per difficulty per week |

A Rare chest still drops when the account level hits a multiple of 5 (`Progression.luau:87-92`). That is levels 5, 10, 15, and 20 on the way to the cap.

## Flags

None.
