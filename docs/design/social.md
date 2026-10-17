# Social plan

G-037. Parties, a friends bonus, a guild concept, and trading etiquette. This file does not change code.

Choice: a friend in your party is a look and a Second Chance point. It is not damage, luck, gold, Raid Marks, or a higher trade cap. The guild name for this concept is Rootcircle. No live profile field uses that word.

`Trading.luau` is the rule source for trades. Raid Finder and the premade board are the party source. Guild modules exist as pure tables. Tests require them. No game service does.

## Parties

| rule | live | cite |
|---|---|---|
| Finder size | 4 to 8. Story and Normal only | `RaidFinder.luau:14`, `RaidFinder.luau:36-37`, `RaidFinder.luau:64-67` |
| Premade size | 4 to 8. Story, Normal, Hard, Shardbreaker. One listing per host. Expires at 1800 seconds | `RaidPremade.luau:15-20`, `RaidPremade.luau:29-31` |
| Full wing | 1 tank, 1 healer, 6 DPS at size 8. Flex fills tank, then healer, then DPS | `RaidFinder.luau:32`, `RaidFinder.luau:13` |
| Role check | Warden tanks. Tidecaller heals. Any class can take DPS. Flex is always allowed | `Raids.luau:51-64` |
| Under 4 | Finder and premade refuse. Rootvault Normal is a solo crawl and pays loot. Practice Grove is the solo door that pays nothing | `RaidFinder.luau:36`, `PracticeLoot.luau:4-5`, `DungeonService.luau:1300-1302` |
| Heartwood queue | Story and Normal at account level 15 | `Raids.luau:20-21` |
| Boss HP | Scales with party size. Size 8 is full HP. Size 4 is half | `RaidFinder.luau:47-53` |
| No healer | After 180 seconds the group may start. Boss damage flag 0.85 and a Healing Spring | `RaidFinder.luau:15-16`, `RaidFinder.luau:38-41` |
| Ready hop | A ready Story or Normal party shares one reserved server. Hard and Shardbreaker do not hop | `RaidPremadeHop.luau:4-8` |

A shorter party is not a weaker player. The HP scale is the only party-size number, and it is on the boss.

## Friends

Settings stores three switches. `SetSettings` saves the whole blob (`Remotes.luau:396-398`). No trade, raid, or chat path reads them. The client writers are the default at `Settings.luau:111`, the normalize at `Settings.luau:245-248`, and the Settings cycles in `MenuHub.luau:3780-3801`.

| switch | saved values | server gate found |
|---|---|---|
| Trades | everyone, friends, off. Default everyone | none in `TradeService.luau` |
| Raid invites | on or off. Default on | none |
| Chat filter | default, strict, off | none |

Suggested, before friends get a bonus: TradeService refuses an invite when the target's saved value is `off`, and when it is `friends` and the two accounts are not Roblox friends. Raid invites use the same check. Chat filter stays a client display until a chat row exists.

### Friends bonus

| moment | suggested | never |
|---|---|---|
| A Roblox friend is in your Heartwood party | Both nameplates get a small amber spark. Soft glow. No beam | Damage, healing, luck, marks, or loot |
| That friend is under level 10, or new to the wing | The existing Second Chance point, once `noteMentor` is called | A second point because they are a friend |
| You and a friend trade | The 95% confirm still shows | A higher daily cap, a waived tax, or a skipped lock |

Second Chance is already the mentor rule (`Loops.luau:266-274`). A friend who is level 10 or higher and not new grants the spark only.

No Robux version of the spark. No sku sets `vip`. Patron does not raise `Trading.dailyCap` (`Trading.luau:346-361`).

## Rootcircle

The Haven plate is already placed. The station is `soon`, and the line is "The Guild Hall is coming soon." (`Haven.luau:134-141`). The starter goal says "Join or browse a guild" and pays 10 Shard Keys. The browse fact counts only at account level 10 or higher (`StarterGoals.luau:62`, `StarterGoalPay.luau:23`, `StarterGoalPay.luau:191`).

Suggested shape, still unwired:

| piece | rule | already in the repo |
|---|---|---|
| Badge | A round pine-brown disc, one amber shard in the middle. Soft glow. No crown | new look only |
| Hall | The soon plate becomes a list of Rootcircles. Browsing it can set the starter flag at level 10 | `Haven.luau:134-141` |
| Roster | A named circle of players. No stat aura | no guild schema yet |
| Raid night | RSVP into tank, healer, dps, or flex. A full role refuses. No paid slot | `RaidCalendar.luau:3-19`. Tests only |
| Strategy | The lead places stack, soak1, and soak2. Presets key off a guild id. No paid marker | `RaidStrategy.luau:3-18`. Tests only |
| Guided score | A counted guided clear adds `guideScore` 1 and scales guild raid XP by 2. Raid Marks are not multiplied | `RaidGuided.luau:32-34`. Tests only |

Rootcircle grants no gold, no luck, no queue priority, and no extra chest. Guided raid XP is a score on the guild record, not a damage buff, and it stays unwired until a guild record exists.

## Trading etiquette

Player lines, from the live rules. Say these in the trade window. Do not soften the cap.

| moment | say | cite |
|---|---|---|
| Offer changes | "The trade changed. Wait 3 seconds, then confirm." | `Trading.luau:28`, `Trading.luau:52` |
| Gold leaves the offer | "You pay the gold you offered. They receive it minus a 10% tax, rounded down." | `Trading.luau:27`, `Trading.luau:1517-1522` |
| Your side is 95% or more of the value | "You're giving ~N% of the value. Continue?" | `Trading.luau:36`, `Trading.luau:572-576`, `Trading.luau:1181-1188` |
| Value is at least 10× the other side, and you are not connected | The audit flags `lopsided`. The warning above still shows either way | `Trading.luau:35`, `Trading.luau:1253-1258` |
| New account, under 14 days | Daily cap 2,000. Trade cap 2,000. Above Rare stays bound. Cosmetics can move | `Trading.luau:31`, `Trading.luau:55-56`, `Trading.luau:66`, `Trading.luau:391-397` |
| Standard | Level 15 and 14 days. Cap starts at 50,000 and grows by 5,000 a level, up to 150,000 | `Trading.luau:32`, `Trading.luau:57-59`, `Trading.luau:355-359` |
| Trusted | Level 40, or 60 clean days. Cap 2,000,000. A receipt must not be enough on its own | `Trading.luau:33-34`, `Trading.luau:63`, `Trading.luau:351-352` |
| Mythic | "Mythic shards bind for 7 days." | `Trading.luau:30`, `Trading.luau:494-497` |
| Robux look | "Robux items stay bound." | `Trading.luau:14-15`, `Trading.luau:477-478` |
| Starter or locked | "Starter gear is bound." or "That item is locked." | `Trading.luau:480-485` |
| Gems | New accounts cannot trade them. Restricted regions cannot. The switch defaults on | `Trading.luau:49`, `Trading.luau:378-387` |
| Market | Listing fee is 5% of the gold price, minimum 1, not returned. A listing lasts 48 hours | `MarketBoard.luau:6-7`, `MarketBoard.luau:21-23`, `MarketBoard.luau:68-80` |

Etiquette beyond the code:

| do | do not |
|---|---|
| Read the percent line before you confirm | Ask for Robux, gift cards, or an off-site payment |
| Leave a Mythic in the bag for 7 days | List a bound starter piece and blame the tax |
| Use friends or off if you want fewer invites, once the server reads the switch | Treat a friend spark as a price discount |

A connected pair skips the `lopsided` audit flag only (`Trading.luau:1256`). They do not skip the confirm sentence, the tax, the lock, or the cap.

## Counts

| | count |
|---|---|
| Party rules cited | 9 |
| Settings switches with no server reader | 3 |
| Friends bonuses suggested | 2 |
| Guild pieces already written as pure modules | 3 |
| Paid social perks | 0 |

## Flags

Rootcircle is not Practice Grove, Grovewarden, or The Unnamed Grove. The amber spark is not Sap Wisp and not the Patron aura. No other game's party finder or guild name is used.
