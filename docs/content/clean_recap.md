# Clean Recap

G-076. Unlock check for achievement `clean_recap`. Read the removal token the way `readRemoval` does. `member.afk` is not enough. This file does not edit `docs/content/achievements.md`.

`docs/content/achievements.md` still says the row has no `afk` and no `kick`. This file is that rule.

Choice: one clean finish sticks. A later kick does not take it away. An error wing does not grant it and does not revoke it. Practice Grove does not count (`docs/content/achievements.md:21`).

## Why `afk` is not the check

`readRemoval` is local (`RaidRecap.luau:268-293`). `readMember` keeps only `afk = removal == "afk"` (`RaidRecap.luau:399-410`). `RaidRecap.panel` returns that boolean and no token (`RaidRecap.luau:511-526`, `RaidRecap.luau:682-694`).

A kick takes the string branch, returns `"kick"`, and leaves `afk` false. A panel with `afk == false` can still be a kick. An error panel also sets `afk` false (`RaidRecap.luau:536-548`). Reading `afk` alone would grant both.

The check reads the raw `removal` value with the same branches. It grants only when the token is empty and the panel is `ok == true`.

## Tokens

`token` trims and lowercases (`RaidRecap.luau:191-199`). `"Kick"` and `"AFK"` match. Present states are `ok`, `warning`, and `paused` (`RaidRecap.luau:65-69`). `AFK_STATE` is `"remove"` (`RaidRecap.luau:63`). Known string removals are `afk` and `kick` (`RaidRecap.luau:57-60`).

| raw `removal` | token | clean | counts |
|---|---|---|---|
| `nil` | `""` | Yes | Grants, once `panel.ok` |
| table state `ok`, `warning`, or `paused` | `""` | Yes | Grants |
| `"afk"` | `"afk"` | No | This wing does not grant |
| `"kick"` | `"kick"` | No | Does not grant. `afk` stays false |
| `"remove"` | `"afk"` | No | The string remove is an AFK removal |
| table state `"remove"` | `"afk"` | No | An AFK result whose state is remove |
| table `ok == false` | error | No | Does not count |
| `"ok"`, `"warning"`, `"paused"` as strings | error | No | Present states are table states only |
| `""`, a number, a boolean, or any other name | error | No | Does not count |

The error string is "That removal is not a known cause." (`RaidRecap.luau:84`). `readMember` fails the row (`RaidRecap.luau:399-401`). There is no clean token to store. Do not grant. Do not treat the error as a dirty wing that blocks a later clean one.

A kick does not set `afk` (`RaidRecap.luau:410`). It still fails this wing. Kudos and MVP skip only `member.afk == true` (`RaidRecap.luau:557`, `RaidRecap.luau:592-596`). A kicked player can still look present there. `clean_recap` does not use that boolean.

## Rule

| check | grants |
|---|---|
| Your row finished a wing, `panel.ok`, token `""` | Yes |
| Token `"kick"` on an otherwise fine row | No |
| Token `"afk"` from `"afk"`, `"remove"`, or state `"remove"` | No |
| `panel.ok == false`, including an unknown token | No. Does not count |
| Practice Grove, any token | No |
| A later clean wing after a kick or an error | Yes. The first clean finish sticks |

## Reward

| id | name | suggested reward | visual note |
|---|---|---|---|
| `clean_recap` | Clean Recap | 15 gold | Icon: a small closed card, cream paper, no glow. |

No stats, no luck, no drop chance. The card is not Seat Ribbon.

## Flags

Clean Recap is not the kudos gate and not Eight Seats. A kick is not an AFK removal, and it still fails the wing. No other game's recap medal is used.
