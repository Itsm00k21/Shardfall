# Top action RPGs

G-048. Ten Roblox action RPGs, what their loop and money look like, and what Shardfall should copy or avoid. This file does not change code.

Choice: rank is a same-day player chart, not a play session. Menus of the other games were not opened. Where a loop is only a store blurb or an article, the row says so. Shardfall's own menu is from the code.

Flags: these rows name live experiences so we can avoid them. Do not copy their characters, places, power names, or signature gear into Shardfall. Two of them are built on another studio's IP. Attack on Titan Revolution and Your Bizarre Adventure are on the list for that reason.

## Snapshot

Primary chart: EndgameTools most-played list, 2026-10-17 22:10 UTC. Second chart: Bloxodes RPG genre table, retrieved 2026-10-17. Charts on the same day disagree. Each row names the number it uses.

Slayers 2 had 40,255 players, a 98% rating, and an update the same day (EndgameTools). Its loop, menu, and shop were not opened. It is not one of the ten.

## The ten

| # | game | players | loop (reported) | menu | money (reported) | copy | avoid |
|---|---|---|---|---|---|---|---|
| 1 | Blox Fruits | 177,130 | Quests, seas, bosses. Builds from fruits, swords, guns, or fighting styles. Free to start. | Not opened | Permanent fruits, XP boosts, stat resets, fruit storage (Earnaldo, 2026-04-11) | A next step you can see: the next boss, the next dungeon | Selling combat stats, XP, or the power that is the build |
| 2 | Grand Piece Online | 19.7k | Open sea. A beginner town, then islands, bosses, rare drops, abilities and fighting styles (Bloxodes, 2026-08-31) | Not opened | Not opened | A boss drop that changes a look or a swing you already earned | A rare combat drop with no pity, then a market for that drop |
| 3 | Attack on Titan Revolution | 16k | Licensed mission RPG. High on the RPG chart across 2026 | Not opened | Not opened | A mission row with a role, which Raid already is | The license, the cast, and the signature gear |
| 4 | Your Bizarre Adventure | 15.5k | Ability RPG, 2.3B visits, listed 9+ on a June 2026 trending page | Not opened | Not opened | An ability you can see on the body | Buying the ability, and any of its power names |
| 5 | Dungeon Quest | 11.4k | Run a dungeon, take better gear, run a harder dungeon (BloxRedeem, 2026-09-26) | Not opened | Not opened | Rootvault already is this loop. Keep the dungeon short | A gear treadmill with no raid at the end |
| 6 | World // Zero | 9.6k | Pick a class, run dungeons, fight bosses, collect pets (BloxRedeem, 2026-09-26). The RPG chart showed a large week jump | Not opened | Not opened | Class pedestals, then a dungeon. Shardfall already does this | A pet that outscales the class you picked |
| 7 | King Legacy | 5.2k | Another long sea grind. 4.1B visits on the Bloxodes RPG chart | Not opened | Not opened | Nothing new | A second sea that resets progress without a new verb |
| 8 | Deepwoken | 4.7k | Skill combat, parry and feint, open world. About 1.6B visits on that chart | Not opened | 400 Robux to enter. Permadeath. In-game shop described as smaller than Blox Fruits (Earnaldo, 2026-04-11) | Telegraphs and a build you can read on the character | A paywall to play, permadeath, and always-on PvP |
| 9 | Arcane Odyssey | ~2k in June 2026 | A first island, then a boat, then a wider sea (Bloxodes, 2026-08-31). 151.9M visits, 92% on that June page. Same-day count was not on the Oct 17 RPG top | Not opened | Not opened | Teach travel before the map gets big | Opening the whole world before the first clear |
| 10 | Iron Soul: Dungeon | CCU not on the chart | Store blurb, updated 2026-10-16: gather, forge, and the new weapon changes the fight. 328.7M visits on that listing | Not opened | Not opened | The forge changes the swing. Crafting already does this | A second combat stat from the forge that you can buy |

Arena fighters are action and not RPGs. Jujutsu Shenanigans had 161,440 players and The Strongest Battlegrounds had 50,796 (same EndgameTools list). They have no gear ladder in the sources read here. Do not copy their move lists.

## Shardfall menu

This is the layout to keep. It was read in code, not guessed from the other games.

| surface | what it is | cite |
|---|---|---|
| HUD | One ScreenGui. Portrait, HP, and level at the top left. Gold, Mastery, and Shards at the top right, under the Roblox buttons. A mid-left rail opens the hub. Skills sit on the action bar. Toasts sit top center | `HudShell.luau:6-9` |
| Hub | One modal. Tabs replace each other. Esc and the backdrop pop | `MenuHub.luau:4-5` |
| Tabs | Hero, Bag, Pets, Roll, Raids, Market, Shard Pass, Settings | `ClientChrome.luau:51-59` |
| First fight | A short Verdant teach, then a roll, then a mini dungeon, then Haven. Skip pays the same kit | `docs/design/shardfall_onboarding.md` |

## What to take home

| keep | drop |
|---|---|
| Class on a pedestal. The shard changes the weapon. The roll is not the class | A random power that replaces the class |
| Heartwood is an 8-player raid. A Story wipe retries the pull. One downed player stays in it (`EchoRetry.luau:36-47`). The character is not deleted | Open-world PvP, bounty griefing, permadeath |
| Rootvault, then a raid. The forge changes the weapon | A sea, then another sea |
| Cosmetics and convenience only. Paid luck, paid chests, and the pass are off | XP boosts, stat resets, storage of power, a paid entry fee |
| The first session stays small. The wider map waits until Haven | A full ocean before the first clear |
| Telegraphs in the first fight | A combat system that needs a paid lesson |

## Sources

| source | date | used for |
|---|---|---|
| https://endgametools.com/en/roblox/charts | 2026-10-17 22:10 UTC | Blox Fruits, Slayers 2, the two arena fighters |
| https://bloxodes.com/stats/games?genre=RPG | retrieved 2026-10-17 | RPG chart counts for rows 2–8 |
| https://earnaldo.com/blog/deepwoken-vs-blox-fruits | 2026-04-11 | Entry price, permadeath, Blox Fruits shop kinds |
| https://bloxodes.com/articles/roblox-open-world-rpgs | 2026-08-31 | Grand Piece Online and Arcane Odyssey loops, without their place names |
| https://bloxredeem.com/guides/best-rpg-roblox-games/ | 2026-09-26 | Dungeon Quest and World // Zero |
| https://bloxodes.com/lists/top-trending-roblox-rpg-games | June 2026 | Arcane Odyssey visits and the 9+ note on Your Bizarre Adventure |
| Iron Soul store listing via a public RPG directory | page updated 2026-10-16 | Forge line and visit count |
