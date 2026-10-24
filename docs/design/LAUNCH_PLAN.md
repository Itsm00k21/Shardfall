# Shardfall Launch Plan

Owner: Ghost (direction). Kevin playtests and makes the money and launch calls. Status: **approved Oct 17, 2026.**

## Rule
One milestone at a time. Each one ends with something Kevin can play. New ideas go to the Parking Lot, not into the current build.

## Launch scope: KEEP
- One compact plaza hub (see docs/design/vision/VISION.md).
- Combat: sword, dodge, 2-3 skills on the 1-8 action bar.
- 3 dungeons of rising difficulty, plus a boss at the end of dungeon 3.
- Shard rolls with the crack reveal. Gear shards and pet shards each get their own clear spot.
- Bag (Equip, Equip Best, Lock), Forge (upgrade only), Pets (equip 3).
- Levels and XP, starter goals, quest tracker, daily login reward.
- Currencies: Gold and Shards only.

## PARKED (code stays, kill switches off, nav hidden)
Raids, trading, the Market Board, the season pass, pet evolution, boss pets, relic sets, Forge reroll and salvage, guilds, leaderboards, extra realms, and extra currencies.

## Launch shop (Robux), milestone M4
- Shard chests in 3 tiers (Common, Rare, Mythic), each with better odds than the last. Sold in packs of x1, x10 and x25, using the same crack reveal.
- Pity carries across paid and free rolls toward a guaranteed Legendary.
- Timed boosts: 2x Luck, 2x XP, 2x Gold (30 or 60 minutes, stackable).
- Game passes: Auto-Roll, Fast Crack, +Pet slot, +Bag space, VIP (small permanent luck boost and a chat tag).
- Starter Pack: a one-time, low-price bundle.
- Gold shop NPC (no Robux): a Healing Tonic and a bag slot. Pet slots come later under T-194.
- Everything paid can also be earned by playing, just slower.

### Policy gate before the first sale (docs/research/roblox_policy.md)
- Each item's odds shown next to the buy button, via an Info/Details control, adding to 100%, plus a rounding disclaimer.
- Paid luck and pity are numeric, and the odds on screen update while they're active.
- Players with `ArePaidRandomItemsRestricted` get no paid rolls but can still crack earned shards (already enforced by PaidRollPolicy).
- Re-answer the maturity questionnaire with "yes" to paid random items the week the shop ships.

## Milestones
| # | Milestone | Done when |
|---|---|---|
| M0 | P0 bugs from Kevin's 6:31 clip | Crack, the Market icon, Pets and the Bag behave correctly in Studio |
| M1 | Launch loop only | Freeze PR merged; only KEEP systems are visible; the harness is green |
| M2 | Plaza and restyle | Compact plaza built; Roll, Bag, Forge and Pets match VISION.md |
| M3 | Combat feel | Hitstop, knockback, sound and screen shake; one swing feels great |
| M4 | Shop | Launch shop live behind the policy gate |
| M5 | First 60 seconds and playtest | Spawn to first crack in under 60s; one friend on a phone for 15 minutes; fixes done |
| M6 | Soft launch | Name, icon and thumbnail ready; published; analytics watched |

## After launch
Updates every 1-2 weeks, using analytics to fix the biggest drop-off first. Planned update order: trading, then the free season pass, then cosmetics, then raids.

## Parking Lot
(New ideas go here.)
