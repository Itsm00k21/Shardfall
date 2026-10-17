# Shard Pass season 1

G-018. Season name, theme, and the 50 live tiers. Cosmetics and convenience only, for the beta pass that is already in `Loops.luau`.

Season name: Greenwake. Id: `greenwake`. Theme: the first grove, moss to sap to a dark crystal bloom. Ages 10+. No gore. The hub still says "The Shard Pass is quiet." This file does not change that line.

Choice: rows match `Loops.FREE_TRACK` and `Loops.PREMIUM_TRACK`. No new payout, no renamed reward, no second set of ids. Art notes are paint only. Nothing here changes `Loops.luau`. `Loops.PREMIUM_ENABLED` stays false. The older design wish of two free pet cosmetics and a 25% Gem refund is not on the live free track, so it is not added. Bell Tide already suggests Foam Collar and Salt Ribbon for season 2.

| rule | live |
|---|---|
| Tiers | 50. `Loops.PASS_TIERS`. |
| Tier cost | 1000 Pass XP. `Loops.PASS_XP`. The 10,000 note in `docs/design/shardfall_loops.md` is not live. |
| Empty tier | Still costs 1000 Pass XP. `Loops.claimFree` advances and pays nothing when the row is missing. Premium does the same. |
| Free | 150 gold, 4 Shard Keys, 25 Dust, 400 gold, the title Boardwalker, 20 Shard Keys. No stats. |
| Premium | Cosmetics plus a Gem refund. No gold, keys, dust, or stats. |
| Gems | 40 on ten tiers. Sum 400. `Loops.PASS_GEMS`. |
| Price | 400 Robux. `Loops.PASS_ROBUX`. Product id is 0, so it cannot match. |
| Archive | `Loops.archiveRobux()` is 480 (400 plus 20%). Same entitlement, not a limited return. Id is 0. |
| Keep | `Loops.keepsPremium` stays true after the season ends. Earned tiers are not re-locked. |
| Skip | 80 Gems adds one tier of Pass XP (`Loops.SKIP_GEMS`). It does not claim tier 50. |
| Feat | `nightmareBest` at least 1. Refusal text: "Clear Nightmare to claim this." |
| After 50 | Each extra 1000 Pass XP is a cache of 4 Shard Keys (`Loops.OVERFLOW_KEYS`). Live free claim does not call this. |
| Sale | Off. Grant, claim, and skip refuse and write nothing while the switch is false. |
| Power | None. No luck, no drop odds, no raid advantage. |

Suggested length is about 8 weeks. There is no season clock in `Loops`.

## Pass XP

These grants are already live. They are not a new pace.

| grant | amount | where |
|---|---|---|
| One finished daily or weekly | 100 | `LoopService.progress` |
| One paying clear | 40 | `DungeonService` clear mutate, after practice returns |
| One tier skip | 1000 | `Loops.skipTier`, premium owned, switch on |

A practice clear returns before the 40. An endless Rootvault run can still take the 40. It does not set `nightmareBest`.

## Feat

`nightmareBest` is a best time in seconds. A paying, non-endless Rootvault clear on difficulty `nightmare` stores at least 1. Heartwood writes `raidBest`, not this field. Zero means no clear. The skip only adds Pass XP. The claim still checks the feat, so the skin cannot be bought outright.

## Tiers

| tier | free | premium |
|---|---|---|
| 1 | 150 gold | — |
| 2 | — | Mossweave |
| 3 | — | — |
| 4 | — | Fernweave |
| 5 | 4 Shard Keys | 40 Gems, Moss Cap |
| 6 | — | — |
| 7 | — | — |
| 8 | — | Barkweave |
| 9 | — | — |
| 10 | 25 Dust | 40 Gems, Spore Trail |
| 11 | — | — |
| 12 | — | Heartwood |
| 13 | — | — |
| 14 | — | — |
| 15 | — | 40 Gems, Lantern Glow |
| 16 | — | — |
| 17 | — | — |
| 18 | — | Sapshine |
| 19 | — | — |
| 20 | 400 gold | 40 Gems, Root Bow |
| 21 | — | — |
| 22 | — | Rootbound |
| 23 | — | — |
| 24 | — | — |
| 25 | — | 40 Gems, Sap Glow |
| 26 | — | — |
| 27 | — | — |
| 28 | — | Shardfall |
| 29 | — | — |
| 30 | Boardwalker | 40 Gems, Gnarl Crown |
| 31 | — | — |
| 32 | — | — |
| 33 | — | — |
| 34 | — | — |
| 35 | — | 40 Gems, Lantern Trail |
| 36 | — | — |
| 37 | — | — |
| 38 | — | Veil of Leaves |
| 39 | — | — |
| 40 | — | 40 Gems |
| 41 | — | — |
| 42 | — | — |
| 43 | — | — |
| 44 | — | — |
| 45 | — | 40 Gems |
| 46 | — | — |
| 47 | — | — |
| 48 | — | 40 Gems |
| 49 | — | — |
| 50 | 20 Shard Keys | Nightmare Bloom. No Gems. Feat: Rootvault Nightmare. |

Gold, keys, Dust, and Boardwalker are the live free rows. Tiers 15 and 40 pay nothing on the free track. Gem rows: 5, 10, 15, 20, 25, 30, 35, 40, 45, 48. Ten times 40 is 400. Tiers 40, 45, and 48 are Gems only.

A free claim writes gold, `shardKeys`, `shardDust`, or `milestoneTitle`. Boardwalker replaces the previous `milestoneTitle` string. It is not a second title slot. A premium claim writes Gems through `Economy.grant` and sets `passCosmetics[id] = true`. These are profile flags, not bag items.

## Cosmetics

Art look is a paint note, not a drop rarity. Higher tiers are brighter. Commons stay simple. Kind is the live `cosmetic` field. Boardwalker is the free `title` field. Hex values are `Rarities.COLOR`.

| id | name | tier | track | kind | art look | visual note |
|---|---|---|---|---|---|---|
| `pass_skin_moss` | Mossweave | 2 | premium | skin | Common | Short coat, yellow-green moss speckles on brown cloth. No glow. |
| `pass_skin_fern` | Fernweave | 4 | premium | skin | Common | Knee-length fern-green cloth, one pale frond stitch on the hem. No glow. |
| `pass_hat_moss` | Moss Cap | 5 | premium | pet_hat | Uncommon | Small rounded moss cap on a thin strap. Soft green glow. |
| `pass_skin_bark` | Barkweave | 8 | premium | skin | Uncommon | Short vest of flat brown bark panels. Dark seams. No glow. |
| `pass_trail_spores` | Spore Trail | 10 | premium | trail | Uncommon | Short trail of pale green spore puffs. Soft glow. Quiet. |
| `pass_skin_heartwood` | Heartwood | 12 | premium | skin | Rare | Pale wood-grain coat, one amber crystal vein. Soft amber glow. |
| `pass_skin_lantern` | Lantern Glow | 15 | premium | skin | Rare | Dark green coat, two small amber lantern stitches. Soft warm glow. No beam. |
| `pass_skin_sap` | Sapshine | 18 | premium | skin | Rare | Green cloth, three glossy amber buttons. Soft glow. |
| `pass_emote_bow` | Root Bow | 20 | premium | emote | Rare | A short bow. One thin root ring on the ground, then it fades. No splash. |
| `pass_skin_root` | Rootbound | 22 | premium | skin | Rare | Dark root wraps over green cloth. No glow. |
| `pass_vfx_sap` | Sap Glow | 25 | premium | weapon_vfx | Epic | Thin amber glint along the weapon edge. No beam. The weapon stays the same size. |
| `pass_skin_shard` | Shardfall | 28 | premium | skin | Epic | Deep green coat. Small pale crystal chips rest on the cloth. Steady soft glow. |
| `boardwalker` | Boardwalker | 30 | free | title | Uncommon | Name text in `#40BA62`. Soft moss glow. No icon. |
| `pass_hat_crown` | Gnarl Crown | 30 | premium | pet_hat | Epic | Small twig circlet, one dull amber knot. Steady glow. No face. |
| `pass_trail_lantern` | Lantern Trail | 35 | premium | trail | Epic | Three tiny amber lantern motes behind the feet. Soft warm glow. Quiet. |
| `pass_skin_veil` | Veil of Leaves | 38 | premium | skin | Epic | Sheer green leaf veil, pale veins. Steady glow. The face stays readable. |
| `pass_skin_nightmare` | Nightmare Bloom | 50 | premium | skin | Mythic | Tall dark coat, closed crystal buds, thin `#E6404E` edge. Bright enough to read. No face. |

Premium count: 10 skins, 2 pet hats, 2 trails, 1 emote, 1 weapon glow. Boardwalker is the only free cosmetic.

`UiTheme.RARITY.Uncommon` is a different green (`96, 196, 120`). Boardwalker uses `Rarities.COLOR` Uncommon `#40BA62`, the same hex as `docs/content/titles.md`. This file does not pick a new hex.

Flags: Greenwake is not the side-quest line about waking the oak. Mossweave is not Gladecloth. Fernweave and Barkweave are not Woven Bark Vest, Living Bark Cuirass, or Grovewarden. Moss Cap is not Moss Band, Moss Locket, Moss Hare, or Gladecloth Hood. Spore Trail is not Spore Cap, Spore Canopy, Spore Mote, or Spore Midge. The Heartwood skin is not the Heartwood raid, Heartwood Student, or Heartwood Bulwark. Lantern Glow is not Lantern Crook, Lantern Trail, or the Far Glade sap lamps. Sapshine is not Sap Glow. Root Bow is not Canopy Bow, Tide Bow, Tideglass Dagger, or a weapon grant. Rootbound is not Rootlatch or Kelpbound. Sap Glow is not Bell Glow and not a damage aura. The Shardfall skin uses the game name as a coat, not a logo. Gnarl Crown is not Gnarl's Seed, Grandmother Gnarl, or Amber Knot. Lantern Trail is not Bell Trail. Veil of Leaves is not Paleveil, Veil Lark, or Veil of Salt. Boardwalker is not Tidewalker, Vault Walker, or Heartwood Student. Nightmare Bloom is not Nightglass, Night Root, or Glass Tide. No other game's pass, skin, or signature mechanic is used.
