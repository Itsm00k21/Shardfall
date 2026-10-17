# Launch checklist

G-033. Publish checks for settings, the age questionnaire, images, badges, analytics, DataStore, and a soft launch. This file does not change code.

Choice: beta stays cosmetics and convenience only, and no Robux product ships in v0.1. `ReceiptService` already leaves unknown products unprocessed (`ReceiptService.luau:6-7`).

## Roblox settings

| check | state | note |
|---|---|---|
| Place is published in a universe | confirm | An unpublished place fails the DataStore probe (`StoreAdapter.luau:13-14`) |
| Studio API access on for save tests | confirm | API off becomes an in-memory profile and does not write (`DataService.luau:40-43`) |
| Public slot, voice, and camera match a 10+ action RPG | confirm | Set these on the experience page the week of launch |
| Paid random items use the live policy | in code | `PaidRollPolicy` fails closed when the flag is missing (`PaidRollPolicy.luau:11-12`, `PaidRollPolicy.luau:33-45`) |
| Paid luck kill switch is known | in code | `RarityConfig.PAID_LUCK_ENABLED` (`RarityConfig.luau:19`) |
| Premium track stays off for v0.1 | confirm | `Loops.PREMIUM_ENABLED` is called out as false on the board |
| No Robux product id is processed | in code | `ReceiptService.grant` records the receipt and does not grant a catalog item (`ReceiptService.luau:20-29`) |
| Odds on the Roll tab match the server draw | missing | Draw and `GetOdds` use `RarityConfig`. The Roll tab's Odds lines paint `RollMath.odds` (`MenuHub.luau:2607`, `RollBoard.luau:87`). See `docs/design/drop_rates.md` |
| Server fill and reserved servers tested with two players | confirm | Raid hop saves and clears the lock before teleport (`DataService.luau:22-26`) |

## Age questionnaire

Answer the live Creator Hub questionnaire the week you publish. Label names move. Suggested answers for this build:

| topic | suggested answer |
|---|---|
| Violence | Fantasy combat against plants, beasts, and a raid boss. No gore, no real-world weapons as the fantasy |
| Fear | Dark woods and a cracked sky. No horror chase, no jump-scare mechanic |
| Romance and dating | None |
| Gambling language | Shard rolls and chests disclose odds. No casino table, no betting between players |
| Chat | Premade titles go through `TextService`. A failed filter stores nothing (`RaidService` filter path) |
| Suggested maturity label | Mild, if that label is still on the form |
| Paid random | Disclose the draw table before any Robux random item is offered. Free rolls use the same table |

## Thumbnails, icon, badges

The 3D pass is last. These are the shots to order, not files in the repo.

| asset | spec | shot |
|---|---|---|
| Icon | Hub icon size the page asks for | Haven crystal, cracked, no text |
| Thumbnail A | 16:9 | Five class pedestals under a shard sky |
| Thumbnail B | 16:9 | A roll card at Epic or better, rarity color only |
| Thumbnail C | 16:9 | Heartwood gate, party of four, no loot pile of gore |
| Badge | none in code | Do not promise a badge until `BadgeService` is called. It is not called today |
| Analytics | none in code | `AnalyticsService` is not called. Add a join, a clear, a roll, and a forge event before the soft launch, or write down that v0.1 has no funnels |

Suggested badge set, after the service exists. Each one is a moment the player already has. No stat sale.

| id idea | when it fires |
|---|---|
| First class | They pick a pedestal |
| First clear | Rootvault Normal pays |
| Level 5 | Starter goal |
| First Heartwood | Story clear, any party of 8 or fewer that the raid allows |
| Pity paid | A Legendary guarantee fires |

## DataStore safety

| check | live | launch rule |
|---|---|---|
| Store name | `ShardfallPlayer_v1` (`StoreAdapter.luau:25`) | Do not rename it without a copy plan |
| Probe store | `ShardfallProbe` (`StoreAdapter.luau:26`) | Leave the probe key in place |
| Schema | 23 (`Schema.luau:35`) | Ship the build that matches the live version. A newer file refuses an older reader on the way down |
| Autosave | 60 seconds (`DataService.luau:9`, `DataService.luau:59`) | A crash can lose one interval. Say that in the test notes |
| Session lock | 20 minutes (`SessionLock.luau:25`) | Longer than the autosave, on purpose |
| Load budget | 4 seconds (`CallBudget.luau:13`) | A late transform must not mark the profile loaded |
| Teleport | Save and clear the lock before `TeleportAsync` | A failed hop reclaims or kicks. Test both |
| Trades | Two profiles write together, or both roll back | Test a crash between the two writes |
| Memory fallback | Studio without API | Confirm a playtest did not think a memory profile was saved |
| Bind on close | Header in `DataService` | Leave a server with one player and confirm the last mutate landed |

## Soft launch

| step | who | pass looks like |
|---|---|---|
| 1. Private server, one account | Kevin | Join, class, one Rootvault, one roll, one forge step, leave, rejoin, gold and items still there |
| 2. Two accounts, same party | Kevin | Premade board, ready, one reserved server, a failed hop returns both to the seats |
| 3. Solo Heartwood attempt | Kevin | Refused under 4 players. Practice Grove pays nothing. Tip names the Grove |
| 4. Policy | GHOST | A restricted policy cannot buy paid luck. An earned shard roll still works |
| 5. Odds | GHOST | The number on the Roll tab equals `RarityConfig.disclose` for that pool |
| 6. Friends, one evening | Kevin | Note the minute they drop. Target is the first clear inside 30 minutes |
| 7. Public | Kevin | After steps 1–6. Paid products stay off. Event Tokens stay without a shop |

## Copy before publish

The forge spends one Gnarl's Seed on +8, +9, and +10 (`Economy.luau:34`, `Economy.luau:49`). The short-stack line still says `Needs boss bark.` (`Economy.luau:50`). Suggested player line: `Needs Gnarl's Seed.`

## Flags

None.
