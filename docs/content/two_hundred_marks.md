# Two Hundred Marks

G-077. Suggested lifetime sum for achievement `two_hundred_marks`. `raidMarks` and `raidMarksEarned` are not that sum. This file does not edit `Schema.luau` or `Raids.luau`.

`docs/content/achievements.md` says earn 200 Raid Marks across clears, and spent marks still count. This file is that rule. `raidMarksBank` is not on the profile.

Choice: add a suggested field `raidMarksLifetime`. Each clear adds the `paid` number `Raids.applyClear` returns. The weekly cap can shrink one grant. It does not subtract from the sum. A buy does not subtract.

## Why the live fields fall short

| field | what it is | where |
|---|---|---|
| `raidMarks` | Wallet. `Raids.buy` subtracts the price | `Raids.luau:300-303` |
| `raidMarksEarned` | This week's room. A later Tuesday stores 0, then the new grant | `RaidMarks.luau:403-416`, copied at `Raids.luau:245-246` from `applyClear` `Raids.luau:267-272` |
| `raidMarksBank` | Not a profile column | Absent from `ProfileData` (`Schema.luau:304-306`), `template` (`Schema.luau:417-419`), `sanitize` (`Schema.luau:626-627`), and `snapshot` (`Schema.luau:1445-1448`) |

While `raidMarksBank` is nil, `marksState` passes week key -1 (`Raids.luau:199-201`). `roll` then stamps this Tuesday and keeps `earnedThisWeek` (`RaidMarks.luau:389-393`). The comment says a key below 0 keeps earned marks (`Raids.luau:193-196`). That keep is one call. It is not lifetime earned. `payMarks` then writes `data.raidMarksBank` on the table in memory (`Raids.luau:247`). A later clear in that same table passes the real week key, and a new Tuesday takes the zero path. Do not read either saved field as the achievement.

The chip label is the wallet (`RaidHud.luau:77-79`). The achievement does not read that label. `snapshot` does not send `raidMarksEarned`.

## Suggested sum

Bases with no first-timers, and `doubleMarks` false: Story 25, Normal 40 (`RaidMarks.luau:21-27`, `RaidMarks.luau:39`). One first-timer on Story pays 28 (`RaidMarks.luau:286-302`). Add `paid`, not a flat 25, when the grant is different. Hard 60, Shardbreaker 80, and Fracture 20 sit on the payout table and are not live difficulties. If `paid` is one of those, add that number. Do not require them for the 200.

| clear | added to the sum |
|---|---|
| Story, new claim, room enough, no first-timers | 25 |
| Normal, same | 40 |
| Story, one first-timer | 28 |
| Vote-kick | The grant. A kick keeps marks (`RaidMarks.luau:15-16`, `RaidMarks.luau:379`) |
| AFK removal | 0 (`RaidMarks.luau:363-367`) |
| Practice, a paid ask (`productId`, `robux`, `cost`, `skip`), or a repeated claim | 0 (`Raids.luau:109-116`, `Raids.luau:220-225`) |
| Room shorter than the grant | The granted amount only (`RaidMarks.luau:460-464`) |
| Room 0 because the week already paid 600 | 0. The sum stays where it is |
| The Tuesday roll itself | 0. The new clear's `paid` is added after. The roll does not subtract |

Unlock at a sum of at least 200.

| path | sum |
|---|---|
| 8 Story clears, no first-timers | 200 |
| 5 Normal clears | 200 |
| 4 Story and 3 Normal | 220 |

`Raids.MARK_CAP` and `RaidMarks.CONFIG.weeklyCap` are 600 (`Raids.luau:20`, `RaidMarks.luau:30`). A week that pays 600 leaves the sum at 600 or higher. The next Tuesday does not set the sum to 0.

## Spend

| id | price | wallet | sum | title |
|---|---|---|---|---|
| `rare_chest` | 80 | Drops by 80 | Unchanged | No |
| `epic_chest` | 160 | Drops by 160 | Unchanged | No |
| `title` | 200 | Drops by 200 | Unchanged | Sets `milestoneTitle` to Heartwood Student (`Raids.luau:43-47`, `Raids.luau:307-309`) |

`already_student` is owning that shop title. Buying it does not grant `two_hundred_marks`. A sum of 200 does not grant `already_student`.

`capped_pouch` reads `raidMarksEarned` at 600 and sticks after the week field drops (`docs/content/titles.md`). It is not this sum.

## Reward

| id | name | suggested reward | visual note |
|---|---|---|---|
| `two_hundred_marks` | Two Hundred Marks | 20 gold | Icon: a small brown pouch, dull amber stitch, no glow. |

No stats, no luck, no drop chance. The pouch is not the Capped Pouch title glow.

## Flags

Two Hundred Marks is not Capped Pouch and not Already a Student. Heartwood Student stays the live 200-mark shop title. `raidMarksLifetime` is a suggested name only. `raidMarksBank` stays off the profile. No other game's currency is used.
