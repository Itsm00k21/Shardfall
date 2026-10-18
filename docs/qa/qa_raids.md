# Raid rule cases

G-060. Cross-module test list for RaidFinder, RaidPremade, RaidMarks, RaidLeaver, RaidLuck, RaidRecap, and RaidLeaderboard.

The single-module specs already lock most error strings. The rows below are the contracts those modules must keep together, plus the live closed-remote case. This file does not change code. Raids stay parked.

## Parked gate

| check | where | expect |
|---|---|---|
| Switch | `LaunchGate.luau:12` | `raids` is false |
| Seven actions | `Remotes.luau:128-134` | RaidQueue, RaidPost, RaidJoin, RaidPractice, RaidBuy, RaidLeave, RaidReady park on `raids` |
| Closed invoke | `Remotes.luau:151-153`, `Remotes.luau:665-668` | `"That is closed."` before `RaidService.queue` |
| Hub | `MenuHub.luau:5315`, `MenuHub.luau:5364` | No raids hotkey row. No raid-invites row |

## Difficulty

| id | finder | premade | marks base | luck | board |
|---|---|---|---|---|---|
| story | queues | lists | 25 | bonus | known, off |
| normal | queues | lists | 40 | bonus | live |
| hard | refused | lists | 60 | bonus | known, off |
| shardbreaker | refused | lists | 80 | bonus | known, off |
| fracture | error | error | 20 | error | error |
| guided | error | refused | no payout | error | error |

Finder refusal for hard and shardbreaker uses the guided sentence (`RaidFinder.luau:269-270`). Fracture and guided use the Story-or-Normal sentence (`RaidFinder.luau:272`). Premade refuses guided only (`RaidPremade.luau:49-51`).

## Removal

One cause is four rules. Do not collapse them.

| cause | marks | luck on a dry clear | recap | board credit |
|---|---|---|---|---|
| afk | amount 0 | no add, reason afk | private panel, no kudos, no MVP | omitted |
| kick | grant kept | still adds | `afk` false, can take MVP and kudos | omitted |
| string `remove`, or afk result state `remove` | not a Marks token | not a Luck token | counts as afk | counts as afk |
| present ok, warning, paused | n/a | n/a | empty token, not afk | not excluded |

| rule | where |
|---|---|
| Marks forfeits only `afk` | `RaidMarks.luau:363-366` |
| Luck skips only the afk reason | `RaidLuck.luau:543-544` |
| Recap `afk` is that token only | `RaidRecap.luau:410` |
| Board skips afk and kick | `RaidLeaderboard.luau:416-418` |

## Risks

| id | risk | where | rating | test to add |
|---|---|---|---|---|
| R1 | A direct raid invoke still reaches the service while the switch is off | `LaunchGate.luau:12`, `Remotes.luau:128-134`, `Remotes.luau:151-153` | high | Each of the seven actions returns `ok` false and `"That is closed."`. `RaidService.queue` does not run. The raids hotkey and raid-invites rows stay hidden |
| R2 | Leaver and Finder do not call each other. A third leave blocks Finder only when the ticket copies `cooldownUntil` | `RaidLeaver.luau:212-222`, `RaidLeaver.luau:345-356`, `RaidFinder.luau:690-706` | high | Three voluntary leaves. `finder` is cooling and `cooldownUntil` is now plus 900. `canQueue` with that deadline is `queued` false, `finderBlocked` true, error cooling. The same ticket with `cooldownUntil` nil is `queued` true |
| R3 | A cooling player can still join a premade. The board has no cooldown field | `RaidPremade.luau:22-23`, `RaidPremade.luau:688-690` | medium | A player who is `finderBlocked` `canJoin` an open Story listing that has a free slot. `allowed` is true |
| R4 | Difficulty sets disagree. Fracture pays Marks and is refused everywhere else | `RaidFinder.luau:64-72`, `RaidPremade.luau:35-40`, `RaidMarks.luau:21-27`, `RaidLuck.luau:35-40`, `RaidLeaderboard.luau:30-41`, `RaidLeaderboard.luau:625-632` | medium | Fracture payout is 20. Finder and premade reject it. Luck `chance` and `settle` error. Board submit of fracture errors difficulty. Story and hard error disabled. A legal Normal clear is accepted |
| R5 | A vote-kick and an AFK removal are easy to treat as the same penalty | `RaidMarks.luau:363-366`, `RaidLuck.luau:543-565`, `RaidRecap.luau:268-292`, `RaidRecap.luau:410`, `RaidLeaderboard.luau:416-418` | medium | Dry clear, removal kick: Marks stay at the gross, luck `added` true, recap `afk` false, board omits them. Removal afk: Marks amount 0, luck `added` false and reason afk, recap `afk` true, board omits them. Kick can still win MVP |
| R6 | Finder will start a healerless party too early, or give Normal a Story golem | `RaidFinder.luau:35-53`, `RaidFinder.luau:833-856` | medium | Four players, no healer, waited 179: `mayStart` false, damage scale 1, Healing Spring false. Waited 180: `mayStart` true, damage scale 0.85, Healing Spring true. Story missing one tank: `wardenCount` 1. Normal missing one tank: `wardenCount` 0 and `mayStart` false. `hpScale(4)` is 0.5. `hpScale(8)` is 1. `hpScale(3)` is nil. Flex fills tank, then healer, then dps |
| R7 | The Marks wallet and the weekly room get reset together | `RaidMarks.luau:29-40`, `RaidMarks.luau:363-381`, `RaidMarks.luau:387-419`, `RaidMarks.luau:501-520` | medium | Story with one first-timer pays 28. Normal with none pays 40. Normal with one pays 44. A locked reclear pays the same base. `event` true while `doubleMarks` is false pays 1x. `earn` of 600 then 25 grants 0 and `capped` true. The next week banks unused room. `bankedCap` never passes 1800. Spending 200 lowers `balance` and leaves `earnedThisWeek`. A stored week ahead of now errors clock |
| R8 | Luck bleeds across difficulties, or a side drop resets the bonus | `RaidLuck.luau:28-33`, `RaidLuck.luau:59-66`, `RaidLuck.luau:204-210`, `RaidLuck.luau:274-284`, `RaidLuck.luau:303-324`, `RaidLuck.luau:474-495`, `RaidLuck.luau:537-565` | medium | Six dry Story clears reach bonus 0.6 and `capped` true. A seventh stays 0.6 and `added` false. A gear drop resets Story only. Normal stays. Pet, mount, title, dye, cosmetic, and aura do not reset. A dye id that merely contains `heartshard` stays non-gear. A dye with `heartshard` true errors. A weapon with no raid source errors. A weapon sourced `heartwood` resets. `chance(0.5, story bonus 0.6)` is 1. The same bonus on Normal with base 0.2 is 0.2. A locked clear does not add |
| R9 | The public recap leaks numbers, or a third tip shows, or an AFK player takes MVP | `RaidRecap.luau:11-22`, `RaidRecap.luau:50-52`, `RaidRecap.luau:493-508`, `RaidRecap.luau:551-577`, `RaidRecap.luau:580-596` | medium | Three failures sort by boss id, then mechanic, and the panel keeps two tips. The public view has kudos and awards only. An AFK player still gets a private panel and cannot give or receive kudos. An MVP tie goes to the lower user id. A second kudos from the same player errors already |
| R10 | A short clear, a practice clear, or a Story clear lands on the Normal board | `RaidLeaderboard.luau:23-33`, `RaidLeaderboard.luau:625-632` | medium | Duration 299 errors floor. Duration 300 on Normal with 4 to 8 credited players is accepted. Practice errors. The same `runId` is a no-op. Sort is duration, then earlier clear, then lower runId, trimmed to 10. A roster that is entirely afk or kick errors empty. Party size must match the credited roster |
| R11 | A Story listing requires gear, or a host keeps two boards, or the expiry instant stays open | `RaidPremade.luau:16-23`, `RaidPremade.luau:28-47` | low | Story and Normal with a gear score error. Hard may store a gear score and `canJoin` does not compare it. A second listing from the same host errors taken. Host depart closes the listing. `now` equal to `expiresAt` is expired. Tags are Learning, Farm, Speedrun, Achievement, at least one, no duplicates. Party size 4 to 8, slots match |
| R12 | Mentor, gear filters, or idle priority drift off the Finder config | `RaidFinder.luau:42-44`, `RaidFinder.luau:75-78`, `RaidFinder.luau:447-452`, `RaidFinder.luau:532-548`, `RaidFinder.luau:655-671` | low | 10 clears and opt-in is a mentor. 9 clears, or opt-in false, is not. `filters` on Story and Normal report gear and clears false. An idle or afk kick sets priority to -1 until the next UTC day, then 0. The string `kick` is not an idle reason |

## Cases already locked

Do not re-file these. The spec file is the lock.

| module | locked by |
|---|---|
| Finder queue, form, mentor, priority | `tests/RaidFinder.spec.luau` |
| Premade validate, open, join, depart | `tests/RaidPremade.spec.luau`, `tests/RaidPremadeWire.spec.luau` |
| Marks payout, week roll, spend | `tests/RaidMarks.spec.luau` |
| Leaver count, rejoin window, kick | `tests/RaidLeaver.spec.luau` |
| Luck classify, chance, settle | `tests/RaidLuck.spec.luau` |
| Recap panel, kudos, awards | `tests/RaidRecap.spec.luau` |
| Board submit, personal best, rank | `tests/RaidLeaderboard.spec.luau` |

## Left on other rows

| row | owns |
|---|---|
| G-070 | Echo chip rect on a phone |
| G-071 | Heartwood level gate when Story and that difficulty diverge |
| G-079 | Premade seat kept after a failed hop |
| G-080 | Leave button past the phone slice |

## Suggested order

Write R1 and R2 first. R1 is the live launch gate. R2 is the cooldown the two modules do not share. R5 should stay a four-column case so a later pass does not make kick and afk the same penalty.

Flags: the live Galecrown gust tip says Blink (`RaidRecap.luau:39`). That word is already in the tip table. This list does not add a spell. No other game's raid name is used.
