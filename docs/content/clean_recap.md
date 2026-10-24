# Clean Recap unlock

G-076. Unlock check for achievement `clean_recap`. Read the removal token, not only `member.afk`. This file does not edit `docs/content/achievements.md`.

`readRemoval` is the local function at `RaidRecap.luau:268-293`. It is not a module field. `RaidRecap.panel` copies only the boolean `afk` (`RaidRecap.luau:410`, `RaidRecap.luau:523-526`). A kick leaves that boolean false and still fails this row.

Choice: score the player's own raw `removal` on that wing's recap. Another player's kick does not fail yours. Practice Grove is not a wing recap and does not count.

## Token

`token` trims and lowercases a string (`RaidRecap.luau:191-200`). An empty string becomes nil.

| raw `removal` | token | clean |
|---|---|---|
| nil, or the field missing | `""` | Yes |
| `"ok"`, `"warning"`, `"paused"` | `""` | Yes |
| table `state` `"ok"`, `"warning"`, or `"paused"` | `""` | Yes |
| `"afk"` or `"AFK"` | `"afk"` | No |
| `"kick"` or `"Kick"` | `"kick"` | No |
| `"remove"` | `"afk"` | No |
| table `state` `"remove"` | `"afk"` | No |
| table `ok = false` | error | Does not count |
| `""`, a number, `"boot"`, or `state` `"kick"` | error | Does not count |

Present states are `ok`, `warning`, and `paused` (`RaidRecap.luau:65-69`). They return an empty token (`RaidRecap.luau:280-281`). The string `"remove"` is `AFK_STATE` (`RaidRecap.luau:63`, `RaidRecap.luau:286-287`). Known removal names are `afk` and `kick` (`RaidRecap.luau:57-60`). Anything else returns `nil` and `"That removal is not a known cause."` (`RaidRecap.luau:84`, `RaidRecap.luau:292`).

## Why `afk` is not enough

| token | `member.afk` | panel `afk` | `clean_recap` |
|---|---|---|---|
| `""` | false | false | Counts as clean |
| `"afk"` | true | true | Fails |
| `"kick"` | false | false | Fails. A kick does not set `afk` (`RaidRecap.luau:410`) |
| error | no member row | false (`RaidRecap.luau:540`) | Does not count. It is not a clean finish |

`docs/content/achievements.md` still says no `afk` and no `kick`. That sentence matches this check. A reader that stops at `panel.afk` would grant the row on a kick. This file does not change the achievement sentence.

## Pay

| id | name | suggested reward | visual note |
|---|---|---|---|
| `clean_recap` | Clean Recap | 15 gold, once | A small closed card, cream paper, no glow |

One clean wing is enough. A later kick on a different wing does not take it back. An error token does not grant it and does not spend it. No stats, no luck, no Raid Marks.

## Flags

Clean Recap is not Capped Pouch and not Heartwood Student. The card is not Seat Ribbon. No other game's recap grade is used.
