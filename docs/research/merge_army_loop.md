# Glassmarch economy

G-051. A monetization and economy model for the next game, merge-army v1. PvE only. No paid power. This file does not change Shardfall code, and it does not close G-050.

Choice: G-050, the full brief, is still `todo`. This model uses only the constraints already on that row: one pad, about 15 tiers, free early auto-merge, PvE only, rebirth, a mutated-merge twist, dailies, a unit Index, ad boosts, and no PvP power. Working title is Glassmarch. One board has 16 cells. Free auto-merge lasts until the highest unit is tier 6. Under-13 players get the same boost on a timer, with no ad. Mutation odds are never for sale. Rainbow stays a Shardfall Secret treatment, so no mutation uses a rainbow.

Numbers are suggested. None of them are live.

Flags: no unit here uses a name from Shardfall content or from another game. Hollow Crown is a Shardfall raid sketch, so tier 9 is Kiln Marshal. Redwake is a place in another Roblox RPG, so the mythic front line is Emberwake Titan.

## Rules

| sell | do not sell |
|---|---|
| Board cloth, unit dye, merge flash | A tier, a mutation, or a mutation odd |
| Permanent auto-merge | Glass, Sparks, or a Glass multiplier |
| Extra offline hours, capped | Lane damage, rebirth count, or the Index |
| | A second board, a PvP queue, or a unit trade |

A player who merges by hand reaches the same tier 15 as a player with the pass. The pass only stops the tapping.

## Wallets

| id | name | earn | spend | never |
|---|---|---|---|---|
| `glass` | Glass | Merges, lane clears, dailies, offline | The next tier-1 unit on the board | Robux. It is not a premium wallet |
| `spark` | Sparks | First Index stamp, the daily board | The cosmetic shop | Power, odds, tiers |
| `robux` | Robux | The store, if Kevin turns it on | The rows in the shop table | Glass, Sparks, mutations |

There is no Gem pack and no Robux rebate.

## The board

One board. 16 cells. Two of the same tier merge into one of the next tier and free a cell. Tier 15 does not merge up.

| knob | suggested |
|---|---|
| Tiers | 15 |
| Cells | 16 |
| Tier-1 price | 10 Glass, times 1.15 for each buy since rebirth. Show the price on the button |
| Merge | Two identical tiers. No skip, no cross-tier merge |
| Early auto-merge | Free while the highest unit on the board is tier 6 or below |
| After tier 6 | Hand merge, the ad session, or the pass |

## Tiers

Rarity is a look label. It does not change the merge. Commons stay plain. Mythic is the striking end. Perk means how the unit reads on the board, not a sold stat.

| tier | name | rarity | read | visual note |
|---|---|---|---|---|
| 1 | Pebble Recruit | Common | front | Short gray pebble body, round head. No glow |
| 2 | Flint Ranker | Common | front | Dark flint body, one tan strap. No glow |
| 3 | Quartz Spearman | Uncommon | reach | Pale quartz spear, soft white edge |
| 4 | Amber Squire | Uncommon | guard | One amber shoulder plate. Soft glow |
| 5 | Cinder Pike | Rare | reach | Coal pike, steady orange tip. No fire |
| 6 | Brine Warden | Rare | guard | Teal glass shield. Steady glow |
| 7 | Ashglass Knight | Epic | front | Ash-gray glass armor, bright orange seams |
| 8 | Veinbreaker | Epic | reach | Cracked purple glass maul, bright veins |
| 9 | Kiln Marshal | Epic | guard | Brick-colored cloak, bright coal collar. Face stays clear |
| 10 | Starwell Captain | Legendary | lead | White-gold glass, a small star on the chest. Strong glow |
| 11 | Mireglass Colossus | Legendary | front | Wide olive glass body, strong inner glow |
| 12 | Heartsplinter | Legendary | reach | Red glass splinters in a fan. Strong glow. No blood |
| 13 | Emberwake Titan | Mythic | front | Tall red glass. Inner light `#E6404E`. No flame sheet |
| 14 | Eclipse Standard | Mythic | lead | Black glass banner, white rim. Strong glow |
| 15 | Glassmarch Sovereign | Mythic | lead | Clear crown and chest, red core. Strong glow. Face readable |

## Lane

One PvE lane, the Glass Mile. Gate N asks for a unit of tier N on the board. A clear pays Glass. It does not pay a unit.

| knob | suggested |
|---|---|
| Gates | 15, one per tier |
| Pay | 25 Glass times the gate |
| Fail | The gate stays. The board does not wipe |
| PvP | None. No steal. No power leaderboard |

The highest unit's mutation, if it has one, adds 5% of that clear's Glass. Mutations do not stack. Rebirth does not multiply that 5%.

## Mutation

Earned. A merge that produces tier 8 or higher can mark the new unit. A unit holds one mutation. A new roll replaces nothing if the unit is already marked. No item changes this table.

| result tier | suggested chance the unit mutates |
|---|---|
| 1–7 | 0 |
| 8–11 | 4% |
| 12–14 | 8% |
| 15 | 12% |

Five kinds split that chance evenly. At 4%, each kind is 0.8%. At 8%, each is 1.6%. At 12%, each is 2.4%. The pad line is the mutation chance, then each kind, then the chance of no mutation. Those lines sum to 100.

| id | name | look | extra |
|---|---|---|---|
| `crackvein` | Crackvein | White fracture lines. No extra glow | The 5% clear bonus above |
| `pale_core` | Pale Core | A pale center. Soft glow | Same bonus. Easier to see on a dark board |
| `twin_spark` | Twin Spark | Two small amber sparks at the shoulders | Same bonus. Merge flash is brighter. Still no rainbow |
| `black_salt` | Black Salt | Dark salt specks on the glass. No glow | Same bonus |
| `prism_fault` | Prism Fault | A split edge, teal on one side and amber on the other. Not a rainbow | Same bonus. Index stamp uses that split border |

Show the odds before the merge, even though this spend is Glass, not Robux. If a later version lets Robux touch the roll, stop and follow `docs/research/roblox_policy.md`.

## Rebirth

| rule | suggested |
|---|---|
| Ask | A tier 15 on the board |
| Clears | The board and Glass |
| Keeps | Index, mutation stamps, cosmetics, Sparks, the pass, offline time already bought |
| Glass gain | +8% per rebirth, cap +80% at rebirth 10 |
| Skip | None. No product shortens it |

The cap is on Glass from merges and clears. It does not raise tier, mutation chance, or lane power.

## Index and dailies

The Index has 15 unit rows and 5 mutation rows. A mutated unit stamps the pair once. The first stamp of a pair pays 5 Sparks once. There is no 75-row pet list.

| daily | ask | pay |
|---|---|---|
| Hands | Merge 20 times | 40 Glass, 2 Sparks |
| Mile | Clear any open gate once | 40 Glass, 2 Sparks |
| Page | Open one Index row | 2 Sparks |

Three dailies. Missing a day does not reset a streak, because there is no streak in v1. A missed day is gone. The Index is not.

## Shop

Bound cosmetics. One grant each, except the offline hours, which can be bought until the cap.

| sku | kind | price | grant | does not grant |
|---|---|---|---|---|
| `quiet_hands` | pass | suggested 199 | Auto-merge with no timer | Glass, odds, tiers, a second multiplier |
| `pad_cloth` | pass | suggested 80 | One board cloth | Extra cells |
| `dye_common` | product | suggested 40 | One Common or Uncommon dye | Stats |
| `dye_rare` | product | suggested 80 | One Rare or Epic dye | Stats |
| `dye_mythic` | product | suggested 120 | One Legendary or Mythic dye. Look only | A tier 15, or a mutation |
| `merge_flash` | product | suggested 50 | A merge flash | Faster merges |
| `offline_satchel` | product | suggested 60 | +4 hours of offline cap, up to +12 | A better offline rate |

Offline base is 2 hours at the Glass of the last clear. The satchel adds time, not a multiplier. Do not sell Sparks. Do not sell a Glass pack.

### Ad boost

Roblox native rewarded video only. No third-party video. Disclose the reward and the wait before the button. The reward is never Robux.

| who | reward | cooldown |
|---|---|---|
| 13+ and ads allowed | 15 minutes of auto-merge | 30 minutes |
| Under 13, ads off, or the policy call failed | The same 15 minutes. No video | 45 minutes |

The boost does not change Glass gain, mutation odds, or tier. It does not stack with itself. `quiet_hands` makes the button unneeded. Players who own the pass do not see the ad.

## v2 parking lot

Not in v1. Do not build these while the one board is still the game.

| idea | rule when it comes back |
|---|---|
| Second board | Still PvE. The pass does not grant it |
| Co-op lane | Two players. No power gap from a purchase |
| Seasonal mutation | Earned. It returns later. It is not gone for good |
| Index frame | A cosmetic around a finished page |

## v3 parking lot

| idea | rule |
|---|---|
| Guild board | Shows Index counts, not power |
| Trade | Cosmetics only. Robux looks stay bound |
| Unit trade | Do not add it |
| PvP | Do not add it |

## Open brief

G-050 still has to name the fantasy, the camera, and the first five minutes. This file should not be treated as that brief. If G-050 picks a different title or a different tier count, change this model to match. Do not keep two economies.
