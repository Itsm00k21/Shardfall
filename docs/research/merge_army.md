# Glassmarch

G-050. The v1 brief for the next game: one pad, the Glass Mile, and the first five minutes. PvE only. No paid power. This file does not change Shardfall code.

Choice: the title, the 16 cells, the 15 ranks, the wallets, the shop, the mutation kinds, and the ad times stay the ones in `docs/research/merge_army_loop.md`. This brief does not add a SKU. Six blanks in that file are filled here, all suggested. The pebble price steps when your tallest rank this life goes up, not on every click. A 1.15 rise on every pebble cannot pay for a tier 15. Merges pay Glass, which that file named and did not number. A rebirth closes the arches so the mile can be walked again. The Index stays.

Flags: Cooling Yard is not Saltglass Strand. Glass the wallet is not Slag Glass and not Tideglass. Glassmarch Sovereign is not Geode Sovereign and not Sovereign's Hollow Core. Kiln Marshal is not Kiln Tyrant. Emberwake Titan is not a place from another game. No rank uses a rainbow. Rainbow stays the Shardfall Secret treatment. No aura list, egg roster, or steal verb from another game. No gore. Faces stay readable. No real-world weapons.

## Place

The player is a glasswright's hands. There is no mascot and no spoken guide.

| id | name | what it is | visual note |
|---|---|---|---|
| `cooling_yard` | Cooling Yard | The whole v1 place. One court. No second zone | Flat black glass court, dark teal sky, no sun, no weather. Commons stay easy to see |
| `pad` | the pad | The only board. 4 by 4 pits | Sixteen square pits, thin gray rims `#A8A8B0`, no glow while empty |
| `glass_mile` | Glass Mile | Fifteen arches in one line behind the pad | Hoops recede in a straight row. Closed hoops are dark. Open hoops hold a steady rarity glow. No faces, no teeth |
| `tongs` | glass tongs | The cursor | Two clear glass fingers, gray `#A8A8B0`, no face, no glow |

## Loop

One life is: buy a pebble, merge matches, open the lowest arch you qualify for, reach Glassmarch Sovereign, pour the yard back.

| verb | rule |
|---|---|
| Buy | Spends Glass. Places one Pebble Recruit in the first empty pit. The price is on the button |
| Merge | Drag one rank onto the matching tier. Two become the next tier and free a pit. Tier 15 does not merge |
| March | Opens the lowest closed arch whose rank is standing on the pad. Pays Glass. The pad does not change |
| Stamp | The Index remembers each rank, and each mutation pair, once |
| Rebirth | Asks for a Sovereign on the pad. Clears the pad, Glass, and the arches. Keeps the Index |

A march is a walk past an arch. There is no health, no damage, and no fail that destroys a rank. If the rank is missing, the button names the rank it still needs.

There is no sell and no delete. A rank leaves the pad only by merging or by rebirth. A merge is final.

## Camera and frame

The yard is a locked diorama. The player does not walk.

| knob | suggested |
|---|---|
| Camera | `Scriptable`, pitch 55 degrees down, field of view 35, aimed at the pad |
| Control | No pan, no zoom, no jump |
| Body | No avatar on the court. If the join needs a character, it stays invisible and anchored under the floor |
| Design frame | Portrait, inside device safe insets. Reference size 390 by 844 |
| Scale | Stays 1, same rule as `MobileShell.luau:9-17`. Taps do not shrink |
| Pit | At least 64 px, `UiTheme.TAP` (`UiTheme.luau:22`). Gap 8. Edge 16 (`UiTheme.luau:19`) |
| Pad block | 4 times 64, plus 3 gaps of 8, plus two edges of 16, is 312 px wide |
| Narrower than 312 | The page scrolls. Pits stay 64. Buy and March stay pinned on the bottom, each at least 64 tall |
| Landscape | Same pits, wider margins. No second layout |

Drag lift is 8 px. A rejected drop snaps back in 0.12 s (`UiTheme.MOTION.pop`, `UiTheme.luau:37`).

## Pad

| knob | suggested |
|---|---|
| Cells | 16, in 4 rows of 4 |
| Empty pit | Dark square, 1 px rim `#A8A8B0`, no glow |
| Full pad | The button reads Full. It does not spend |
| Hold Buy | Repeats every 0.2 s while a pit is free and the price is covered. Same price. Not sold |
| Match | Same tier. The mutation does not have to match. A matching pair of marks does not raise the odds |
| Child | The two parents are spent. The new rank can roll a mark if its tier is 8 or higher |
| Tier 15 on tier 15 | They do not combine. The line reads "The Sovereign does not merge." |
| Auto, early | Free while the tallest rank on the pad is tier 6 or below, after the first hand merge |
| Auto, later | Only during the ad session, or with the pass `quiet_hands` |
| Arch hold | Auto will not merge the last unit of the tier the lowest closed arch still needs. A hand drag still can. One settings toggle, default on |

The pass stops merge taps. It does not buy, it does not raise Glass, and it does not change odds.

## Ranks

Names and looks are the G-051 table. Rarity is a look. It does not change the merge. Colors are the `Rarities` ladder (`Rarities.luau:39-44`).

Pebble price while that tier is the tallest this life: `ceil(10 × 1.15^(tier − 1))`, in whole Glass. Rebirth sets the tallest back to none, so the next pebble is 10 again. The two tutorial pebbles do not count as buys.

Merge pay when two of that tier combine: `2 × pebble price of the tier you spent × that tier`. Tier 15 has no pay, because it does not merge. Rebirth then scales the pay by `1 + 0.08 × rebirths`, rebirths capped at 10. Round the scaled result to the nearest whole Glass. A tie rounds up.

| tier | name | rarity | read | pebble price | merge pay | visual note |
|---|---|---|---|---|---|---|
| 1 | Pebble Recruit | Common | front | 10 | 20 | Short gray pebble body, round head. No glow |
| 2 | Flint Ranker | Common | front | 12 | 48 | Dark flint body, one tan strap. No glow |
| 3 | Quartz Spearman | Uncommon | reach | 14 | 84 | Pale quartz spear, soft white edge |
| 4 | Amber Squire | Uncommon | guard | 16 | 128 | One amber shoulder plate. Soft glow |
| 5 | Cinder Pike | Rare | reach | 18 | 180 | Coal pike, steady orange tip. No fire |
| 6 | Brine Warden | Rare | guard | 21 | 252 | Teal glass shield. Steady glow |
| 7 | Ashglass Knight | Epic | front | 24 | 336 | Ash-gray glass armor, bright orange seams |
| 8 | Veinbreaker | Epic | reach | 27 | 432 | Cracked purple glass maul, bright veins |
| 9 | Kiln Marshal | Epic | guard | 31 | 558 | Brick-colored cloak, bright coal collar. Face stays clear |
| 10 | Starwell Captain | Legendary | lead | 36 | 720 | White-gold glass, a small star on the chest. Strong glow |
| 11 | Mireglass Colossus | Legendary | front | 41 | 902 | Wide olive glass body, strong inner glow |
| 12 | Heartsplinter | Legendary | reach | 47 | 1128 | Red glass splinters in a fan. Strong glow. No blood |
| 13 | Emberwake Titan | Mythic | front | 54 | 1404 | Tall red glass. Inner light `#E6404E`. No flame sheet |
| 14 | Eclipse Standard | Mythic | lead | 62 | 1736 | Black glass banner, white rim. Strong glow |
| 15 | Glassmarch Sovereign | Mythic | lead | 71 | — | Clear crown and chest, red core. Strong glow. Face readable |

Making one Sovereign from pebbles takes 16,384 pebbles and 16,383 merges. The two tutorial pebbles count toward that, so a waste-free first life buys 16,382. That length is suggested. Almost all of those buys happen after Brine Warden, when free auto-merge has ended. Auto-merge removes merge taps. It does not remove Buy taps.

## The mile

Gate N needs a unit of tier N standing on the pad. The clear pays `25 × N` Glass before rebirth. Rebirth scales that clear the same way it scales merge pay. It does not scale the mark bonus. The mark bonus is 5% of the unscaled clear, nearest whole Glass, ties up, and only if the tallest unit on the pad is marked. One mark. They do not stack.

| arch | needs | rim | clear | mark bonus | visual note |
|---|---|---|---|---|---|
| 1 | Pebble Recruit | `#A8A8B0` | 25 | 1 | Short hoop, dim gray until open, then a steady common rim. No glow on the glass around it |
| 2 | Flint Ranker | `#A8A8B0` | 50 | 3 | Same hoop, a little taller. Steady gray when open |
| 3 | Quartz Spearman | `#40BA62` | 75 | 4 | Pale green rim when open. Soft glow |
| 4 | Amber Squire | `#40BA62` | 100 | 5 | Same green, taller hoop. Soft glow |
| 5 | Cinder Pike | `#488EFF` | 125 | 6 | Blue rim when open. Steady glow. No fire |
| 6 | Brine Warden | `#488EFF` | 150 | 8 | Blue rim, teal glass in the hoop. Steady glow |
| 7 | Ashglass Knight | `#BA60F0` | 175 | 9 | Purple rim when open. Bright, face of the court stays clear |
| 8 | Veinbreaker | `#BA60F0` | 200 | 10 | Taller purple hoop. Bright veins in the glass, no crack across the sky |
| 9 | Kiln Marshal | `#BA60F0` | 225 | 11 | Purple rim, brick-colored inner edge. Steady glow |
| 10 | Starwell Captain | `#FFC440` | 250 | 13 | Gold rim, one small star on the keystone. Strong glow |
| 11 | Mireglass Colossus | `#FFC440` | 275 | 14 | Wide gold hoop, olive glass center. Strong glow |
| 12 | Heartsplinter | `#FFC440` | 300 | 15 | Gold rim, red glass fans inside. Strong glow. No blood |
| 13 | Emberwake Titan | `#E6404E` | 325 | 16 | Tall red hoop, inner light `#E6404E`. No flame sheet |
| 14 | Eclipse Standard | `#E6404E` | 350 | 18 | Red hoop, black glass center, white rim. Strong glow |
| 15 | Glassmarch Sovereign | `#E6404E` | 375 | 19 | Tallest hoop, clear crown shape, red core. Strong glow. The opening stays readable |

The fifteen clears sum to 3,000 Glass before rebirth and before the mark.

March always offers the lowest closed arch only. The button shows the rank it needs, the clear, and the mark bonus if it will apply. A closed arch you cannot meet yet is visible and not pressable.

## First five minutes

Once per profile. Wallet starts at 30 Glass. Pits 1 and 2 hold a Pebble Recruit each. Those two are not buys. Sparks start at 0. Auto is paused until the first hand merge. March stays disabled until that merge. The Shop tab is visible and quiet. No popup.

| time | player | game shows | wallet after | lesson |
|---|---|---|---|---|
| 0:00 | Lands | Loading line "Two of a kind cool into the next rank." Pad, price 10, March reading "Merge two Pebble Recruits first." | 30 | The pad is the game |
| 0:30 | Drags pebble onto pebble | One Flint Ranker. One cooling tick. Price becomes 12 because the tallest rank grew | 50 | Two of a kind make the next rank, and the price moved |
| 1:30 | Buys | One Pebble Recruit in the first empty pit. That buy spends 12. The next pebble stays 12 until the tallest rank grows | 38 | The price is on the button |
| 2:30 | Marches | Arch 1 takes `#A8A8B0` and a steady rim. Pad unchanged. The arch pays 25, then the Mile toast pays 40 Glass and 2 Sparks | 103 Glass, 2 Sparks | A clear pays. The board stays |
| 3:30 | Opens the Index | Pebble Recruit and Flint Ranker stamp. 5 Sparks each. Page daily pays 2 Sparks | 103 Glass, 14 Sparks | The Index remembers. It has no power column |
| 4:30 | Reads one line, then it leaves | "Two Flint Rankers make a Quartz Spearman. Auto-merge is free while your tallest rank is Brine Warden or below." Auto may run | 103 Glass, 14 Sparks | Free auto is a timer on rank, not a purchase |

The scripted path buys once, then marches. Buying first still works: March unlocks on the first hand merge either way. The Mile daily counts that first clear. Hands stays 1 of 20, so the day still has a merge goal. Page completes when the Index opens.

At 5:00 the player has a Flint Ranker and a Pebble Recruit, Arch 1 open, 103 Glass, 14 Sparks, and no mark. Marks start when a merge makes Veinbreaker or higher.

## After the tutorial

| moment | what changes |
|---|---|
| Tallest is Brine Warden or below | Auto-merge stays free. The ad button is hidden |
| Tallest becomes Ashglass Knight | Free auto ends. The boost button appears, unless `quiet_hands` is owned |
| A merge would make tier 8 or higher | Info shows the mark odds before the drag completes |
| Sovereign stands on the pad | Rebirth enables. The button no longer says it is waiting |
| Shop | The rows in `docs/research/merge_army_loop.md` only. No Glass pack, no Sparks pack, no second board |

### Mark odds

The outcomes are the five kinds plus no mark. Those six sum to 100. The heading percent is their total, not a seventh outcome. The button says Info. A bare (i) is not used (`docs/research/roblox_policy.md`).

| new rank | line |
|---|---|
| Below Veinbreaker | Marked 0%. Crackvein 0%. Pale Core 0%. Twin Spark 0%. Black Salt 0%. Prism Fault 0%. No mark 100% |
| Veinbreaker through Mireglass Colossus | Marked 4%. Each kind 0.8%. No mark 96% |
| Heartsplinter through Eclipse Standard | Marked 8%. Each kind 1.6%. No mark 92% |
| Glassmarch Sovereign | Marked 12%. Each kind 2.4%. No mark 88% |

Kinds and looks stay the five rows in `docs/research/merge_army_loop.md`. None of them is a rainbow. Nothing in the shop changes this table.

### Rebirth

| rule | suggested |
|---|---|
| Ask | A Glassmarch Sovereign standing on the pad |
| Button while locked | "Needs Glassmarch Sovereign." Visible, not hidden |
| Confirm | Second tap. "Pour the yard back. Glass and the pad clear. The arches close. The Index stays." |
| Clears | Pad, Glass, every arch |
| Keeps | Index, stamps, cosmetics, Sparks, the pass, offline hours already bought |
| Glass | +8% per rebirth on merge pay and on arch clears, cap +80% at rebirth 10 |
| Does not change | Tier, mark chance, the mark's 5%, Buy speed |
| Pour | Ranks sink into the pits as white-hot glass, then the pits go dark. One low chime. No scream. The Index stays unmelted on the side |

A rebirth does not complete a daily.

### Dailies, Index, offline, ads

The asks, the pays, the Spark stamp, the shop, and the ad cooldowns are the G-051 tables. This is only when they show up.

| piece | v1 rule |
|---|---|
| Dailies | Hands, Mile, and Page. Fixed. Not rolled from a pool. A missed day is gone. No streak. No paid reroll |
| Index | 15 rank rows and 5 mark rows. A count may read "Ranks 2 of 15." No combat score. No global board |
| Offline | 0 until the first march. Then each hour pays the same whole Glass that last march paid, mark included once. Base 2 hours. The satchel adds hours, not a better rate. The pad does not merge while you are away |
| Ads | Roblox rewarded video only, and only for a player who is 13+ with ads allowed. The button names the 15 minutes and the video before it plays. Reward is auto-merge time, never Robux, Glass, or odds |
| Under 13, ads off, or a failed policy call | Same 15 minutes. No video. The button does not say "watch." Cooldown 45 minutes, as in G-051 |
| Pass owned | The boost button is hidden |

## Kit

Take the save, the policy fail-closed, and the UI shell from `docs/research/starter_kit.md`. Leave Haven, raids, classes, combat, pets, and the roll reel. The mark table is a new file. It is not `RollMath`. Schema is a new pattern. Do not copy Shardfall profile version 26.

| keep the shape of | leave |
|---|---|
| One profile, session lock, receipts that pay once | Raid fields, gold, dust, forge |
| `PaidRollPolicy` fail closed | Prism products |
| Menu shell, safe insets, text size, reduced motion | The eight Shardfall tabs |
| Rate limit, then argument checks | Combat remotes |

## Do not build in v1

Parked on purpose. The longer list is the v2 and v3 tables in `docs/research/merge_army_loop.md`.

| parked | v1 instead |
|---|---|
| A second board | One 4 by 4 pad |
| PvP, steal, a power leaderboard | Arch clears and an Index count |
| Unit trade | Cosmetics stay bound |
| A product that skips rebirth or keeps an arch open | The pour, then Arch 1 again |
| Paid marks or paid odds | The Info lines above |
| Auto-buy | Hold Buy, free, same price |

## Blanks this brief fills

| blank in G-051 | suggested fill |
|---|---|
| When the 1.15 applies | Once per new tallest rank this life, not once per pebble |
| How much a merge pays | `2 × price of the spent tier × that tier`, then the rebirth scale |
| Whether arches survive a rebirth | They close. The Index does not |
| What an offline hour pays | The last march's whole Glass, once per hour |
| Tutorial grant | 30 Glass and two Pebble Recruits, once per profile |
| Shape of the 16 cells | 4 by 4 |

Numbers in this file are suggested. None of them are live in Shardfall.
