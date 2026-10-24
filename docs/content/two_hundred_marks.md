# Two Hundred Marks lifetime counter

G-077. Suggested lifetime sum for achievement `two_hundred_marks`. `raidMarks` and `raidMarksEarned` are not that sum. This file does not edit `Schema.luau` or `Raids.luau`.

Choice: add the number `Raids.applyClear` already returns as `paid`. Do not add the base when the week room pays less. The suggested field name is `raidMarksLifetime`. That name is not on the profile today.

## Why the live fields are not lifetime

| field | what it does | lifetime |
|---|---|---|
| `raidMarks` | Wallet. `Raids.buy` subtracts the price (`Raids.luau:300-303`) | No. Spending lowers it |
| `raidMarksEarned` | Earned against this week's room. A new week key sets it back to 0, then adds the new grant (`RaidMarks.luau:412-416`, `Raids.luau:245`) | No. The week change wipes it |
| `raidMarkWeek` | Week key stored by `payMarks` (`Raids.luau:246`) | No. It is a stamp, not a sum |
| `raidMarksBank` | Written by `payMarks` (`Raids.luau:247`). Not a field on `ProfileData` (`Schema.luau:317-319`). Template and sanitize never name it | No. It is not on the profile |

`applyClear` does not add marks itself. It calls `payMarks` and returns that `paid` (`Raids.luau:10-13`, `Raids.luau:267-272`, `Raids.luau:292`).

## Suggested sum

Add `paid` once per `applyClear` call. The bases, with no first-timer and room left in the week, are Story 25 and Normal 40 (`RaidMarks.luau:21-24`).

| clear | `paid` added |
|---|---|
| Story, new claim, room at least 25 | 25 |
| Normal, new claim, room at least 40 | 40 |
| Same claim again | 0 |
| Practice, or `practice = true` | 0 (`Raids.luau:220-221`) |
| A paid ask (`productId`, `robux`, `cost`, or `skip`) | 0 (`Raids.luau:109-116`) |
| AFK removal | 0 (`RaidMarks.luau:363-366`) |
| Vote-kick | The same as a clean clear. A kick keeps the grant (`RaidMarks.luau:15`) |
| Week room smaller than the base | The clipped grant, not the base (`RaidMarks.luau:460-464`) |

The weekly cap is 600 (`Raids.luau:20`, `RaidMarks.luau:29`). When the week rolls, `raidMarksEarned` goes back to 0. `raidMarksLifetime` does not. The next clear adds its new `paid` on top of the old sum.

## Spend does not lower it

| action | wallet | lifetime sum |
|---|---|---|
| Earn 200, then stop | 200 | 200. The row unlocks |
| Buy Heartwood Student for 200 (`Raids.luau:46`, `Raids.luau:303-308`) | 0 | Still 200 |
| Buy a Rare chest for 80 | drops by 80 | Unchanged |
| Hit the 600 room, then a new week | wallet keeps the marks | Sum keeps every `paid` from the capped week |

Eight Story clears at 25, or five Normal clears at 40, cross 200. A mix crosses 200 the same way. The row sticks once. A later spend does not unset it.

## Not `already_student`

| id | unlock | suggested reward |
|---|---|---|
| `two_hundred_marks` | Lifetime sum of `paid` reaches 200 | 20 gold |
| `already_student` | `milestoneTitle` is Heartwood Student | 10 gold, and no second title |

Buying the title can happen before the sum reaches 200, or after. Neither row grants the other. Capped Pouch is `raidMarksEarned` reaching 600 for one week. It is not this sum.

## Visual note

| id | name | visual note |
|---|---|---|
| `two_hundred_marks` | Two Hundred Marks | A small brown pouch, dull amber stitch, no glow |

The pouch is an icon. It is not currency and not the Heartwood Student title.

## Flags

Two Hundred Marks is not Capped Pouch and not Heartwood Student. The pouch is not Seat Ribbon. A paid skip does not add to the sum. No other game's currency trophy is used.
