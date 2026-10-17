# Top roll games

G-049. Ten Roblox games where a roll, a hatch, or a rare find is the hook. Roll feel, pity, auto-roll, rarity display, and what brings people back. This file does not change code.

Choice: the ten are roll games that were high on a 2026-10-17 chart, plus two fishing indexes and one older egg game that is still played. Odds are quoted only where a page published numbers. A blank pity cell means this pass did not open that game's pity.

Flags: names are here so we do not lift them. Do not copy aura names, egg pets, banner units, or meme casts. `RollReel.luau:4` already calls our reel a Sol's RNG style reel. Keep the reel. Do not copy that game's aura list.

Shardfall's draw stays the 1-in-N sheet. Q-003 is closed: Common is about 76.46% at x1, and pool weights only split items inside a rarity.

## Snapshot

Primary counts: EndgameTools, 2026-10-17 22:10 UTC. Vanguards and Bubble Gum Simulator INFINITY were not in that top-43 excerpt. Their counts are from a second same-day list (LevelUpPlay, 2026-10-17). Fish It uses RobloxGameFinder, 2026-10-16.

## The ten

| # | game | players | roll feel | pity | auto | rarity on screen | why they return | copy | avoid |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Pet Simulator 99 | 55,907 | Hatch an egg. The rare pet is the point | Not opened as a hard pity | Auto hatch is the verb in press and updates | A May 2026 exclusive egg published 50 / 35 / 13 / 1.50 / 0.390 / 0.100 / 0.010. Those seven sum to 100 | Limited eggs, a season pass, a 10-minute world buff every 2 hours | Percents that sum to 100, shown before you spend. A short free buff | Robux eggs, odds aimed at billions, a pet that exists only inside a window you can miss |
| 2 | Sol's RNG | 31,434 | One Roll button. The result is an aura you wear. Potions change luck. Biomes change what can appear | Not opened | Press (Pocket Gamer, 2026-10-10) says auto roll can run while you fish | Not opened as a full sheet | Aura collection, potions, biomes, codes | One button. The result is a look, not a new class | A luck potion you pay for. Codes as the reason to log in |
| 3 | Vanguards (2nd Anniversary) | ~66k on the second chart | A banner summon. Rates published on a 2026-09-10 guide: Rare 75.496%, Epic 20%, Legendary 4%, Mythic 0.5%, plus rarer rows | Legendary 50. Mythic 400. A still rarer tier at 25,000 on that same guide. This pass did not prove the rows sum to 100 | Not opened | A number on the banner | Limited banners, a pass, login tickets | A pity count the player can plan | A pass that makes the pull cheaper. A top rarity with no pity. A unit that leaves when the banner ends |
| 4 | Fisch | 128,422 | Cast, catch, fill a list. The rare fish is the roll | Not opened | Not opened | Not opened | The index, events, a calm repeat | A codex that fills. Shardfall Codex already exists | Inventing a pity number we did not read |
| 5 | Fish It | 72,488 on 2026-10-16 | A second fishing index. Loop not opened past the chart | Not opened | Not opened | Not opened | Same family as Fisch | Nothing extra | A second fishing minigame inside Shardfall |
| 6 | Steal An Egg | 1,153,921 | Collect rare pets. The title is the loop we could verify | Not opened | Not opened | Not opened | The rare pet, and the scale of the crowd | The rare thing is why you stay | Taking another player's pet. Building the game around that verb |
| 7 | Steal a Brainrot | about 104k–106k (rblxstat, 2026-10-17) | Collect rare units. Details past the title were not opened | Not opened | Not opened | Not opened | Collection and the meme | A rare unit you can show | The cast, and stealing as the verb |
| 8 | Anime Dice | 43,103 | A dice roll on the chart. Odds were not opened | Not opened | Not opened | Not opened | Updates the same day | Nothing until someone reads the odds | Replacing the shard reel with a dice cup |
| 9 | Blox Fruits | 177,130 | The fruit roll is the build, not a cosmetic | Not opened | Not opened | Not opened | The next sea | Keep class and shard apart. We already do | A roll that replaces the class |
| 10 | Bubble Gum Simulator INFINITY | 10.7k on the second chart | An older egg game that is still played. Rates were not opened | Not opened | Not opened | Not opened | Eggs and rebirth, from the genre, not from a rate sheet | Nothing from this pass | Copying its pet names or its egg ladder |

## Pet Simulator event, so we do not blur it

BIG Games, 2026-10-10. A Blood Moon lasts 10 minutes every 2 hours. Event luck is x3. Two top pet tiers have x2 odds. That is a clock, not a guarantee. A later note (The Click, 2026-10-12) says the post does not give a percent per pet.

Copy the shape of a short free buff. Do not copy a rare pet that only exists in that window. Shardfall's login streak pauses instead of resetting (`docs/design/shardfall_loops.md`).

## What Shardfall already does

| piece | live | cite |
|---|---|---|
| Draw | Rarest first. Each listed 1-in-N is that check. Common takes the rest, so the sheet sums to 100 | `RarityConfig.luau:8-11`, `RarityConfig.luau:380-408` |
| At x1 | Common about 76.46%, Epic about 0.40%, Legendary about 0.040%. Full sheet is in `docs/design/pity_review.md` | Q-003 |
| Pity | Epic at 100. Legendary at 1000. The notice states both | `RarityConfig.luau:44-45`, `RarityConfig.luau:434-438` |
| Line | `Epic  1 in 250  (0.3998%)` style. Under 1% prints four decimals. At or above 1% prints two | `RarityConfig.luau:372-377`, `RarityConfig.luau:446-452` |
| Item odds | `disclose` also builds a per-entry chance | `RarityConfig.luau:420-431` |
| Reel | Server picks. The client plays the seed. Quick Roll skips the reel. Mythic still plays | `RollReel.luau:6-8` |
| Auto | Roll-tab auto chains another roll only while the hub is open on Roll, the player is alive, auto is on, tokens remain, the bag has room, the last item is not new and not an upgrade, and the last rarity is below the stop. Stops are Off, Uncommon, Rare, Epic, Legendary. A roll queued by a second press during the reveal skips that stop. This path does not watch window focus | `RollBoard.luau:18`, `RollBoard.luau:115-135`, `RollLoop.luau:50-62`, `RollLoop.luau:343-367`, `RollLoop.luau:395-412`, `MenuHub.luau:3061-3080` |
| Paid luck | Off | `RarityConfig.luau:18-19` |

The stop list ends at Legendary. A player cannot set the stop on Mythic or Secret. That is a product choice already in code, not a new one.

The focus cut is not on the roll tab. `RollReel` turns its own auto off when the window loses focus (`RollReel.luau:947-950`) and will not start a roll while the window is closed (`RollReel.luau:854-857`). That auto button is created hidden, and the client never opens it (`RollReel.luau:1253-1268`, `init.client.luau:775-776`). Losing focus does not stop the live roll-tab auto.

## What to take home

| keep | drop |
|---|---|
| One roll button and a reel | A second verb (dice, case battle, steal) |
| 1-in-N percents, pity in the same notice | A display that hides the top tiers |
| Roll-tab auto-roll that stops at the chosen rarity | Auto-roll locked behind a group, a like, or a pass |
| Quick Roll as a shorter reveal, not better odds | A luck potion, a cheaper pull, or a Robux egg |
| Codex and a paused login streak | Limited pets that never return |
| Class stays the pedestal | A roll that is the class |

If a paid random item ever ships, the buy button needs every entry's percent, not only the rarity line. That gap is in `docs/research/roblox_policy.md`.

## Sources

| source | date | used for |
|---|---|---|
| https://endgametools.com/en/roblox/charts | 2026-10-17 22:10 UTC | Counts for rows 1, 2, 4, 6, 8, 9 |
| https://levelupplay.my/charts/top-playing | 2026-10-17 | Vanguards and Bubble Gum Simulator INFINITY |
| https://robloxgamefinder.com/ | 2026-10-16 | Fish It |
| https://rblxstat.com/lists/most-played-roblox-games | 2026-10-17 | Steal a Brainrot range |
| https://www.pet99prices.com/item/exclusive-origami-egg | page dated 2026-05-09 | Egg percent shape. Pet names are not repeated here |
| https://biggames.io/post/pet-simulator-99-update-97 | 2026-10-10 | Blood Moon length and multipliers |
| https://www.theclick.gg/pet-simulator-99-blood-moon-spawn-times-rewards/ | 2026-10-12 | No per-pet percent in the official post |
| https://www.pocketgamer.com/roblox/sols-rng-codes/ | 2026-10-10 | Roll, potions, auto roll while fishing |
| https://allthings.how/anime-vanguards-on-roblox-how-to-get-and-equip-units/ | 2026-09-10 | Banner rates and pity. Unit names are not repeated here |
