# Shard Pass season 2

G-019. Season 2 theme and a 50-tier outline. Cosmetics and convenience only, for a later pass draft.

Season name: Bell Tide. Id: `bell_tide`. Theme: the Saltglass coast after the verdant beta. Cream salt, teal water, soft bell light. Ages 10+. No gore.

Choice: G-018 still owns the season 1 writeup, so this file does not invent season 1 rows. The live beta track in `Loops.PREMIUM_TRACK` and `Loops.FREE_TRACK` stays as it is. Bell Tide uses the same shape: 50 tiers, 1000 Pass XP each (`Loops.PASS_XP`), premium gems that sum to 400, and a feat skin at tier 50 that pays no gems. Every number below is suggested. Nothing here changes `Loops.luau`. `Loops.PREMIUM_ENABLED` stays false.

| rule | suggested |
|---|---|
| Tiers | 50. Empty tiers still cost 1000 Pass XP and pay nothing, same as `Loops.claimFree`. |
| Free | Gold, Shard Keys, Dust, two pet cosmetics, one title. No stats. |
| Premium | Cosmetics plus a Gem refund. No gold, keys, dust, or stats. |
| Gems | 40 on ten tiers. Sum 400, the live `Loops.PASS_GEMS`. |
| Skip | 80 Gems adds one tier of Pass XP (`Loops.SKIP_GEMS`). The skip does not claim tier 50. |
| Feat | Stand once at Bell Pool. No Robux bypass. |
| After 50 | Each extra 1000 Pass XP is a cache of 4 Shard Keys (`Loops.OVERFLOW_KEYS`). Live claim does not call this yet. |
| Power | None. No luck, no drop odds, no raid advantage. |
| Archive | Not in this outline. A bought pass still never expires once the live rule is on. |

Bell Pool is the Saltglass Strand landmark in `docs/content/zones.md`. That zone is post-beta (suggested levels 20–25, beta cap 20). Until the landmark exists, Glass Tide cannot be claimed.

## Tiers

| tier | free (suggested) | premium (suggested) |
|---|---|---|
| 1 | 150 gold | — |
| 2 | — | Saltcloth |
| 3 | — | — |
| 4 | — | Foamweave |
| 5 | 4 Shard Keys | 40 Gems, Bell Cap |
| 6 | — | — |
| 7 | — | — |
| 8 | — | Brineweave |
| 9 | — | — |
| 10 | 25 Dust | 40 Gems, Foam Trail |
| 11 | — | — |
| 12 | — | Gullcloth |
| 13 | — | — |
| 14 | — | — |
| 15 | Foam Collar | 40 Gems, Pool Lamp |
| 16 | — | — |
| 17 | — | — |
| 18 | — | Pearlsheen |
| 19 | — | — |
| 20 | 400 gold | 40 Gems, Tide Bow |
| 21 | — | — |
| 22 | — | Kelpbound |
| 23 | — | — |
| 24 | — | — |
| 25 | — | 40 Gems, Bell Glow |
| 26 | — | — |
| 27 | — | — |
| 28 | — | Archcloth |
| 29 | — | — |
| 30 | Tidewalker | 40 Gems, Shell Cap |
| 31 | — | — |
| 32 | — | — |
| 33 | — | — |
| 34 | — | — |
| 35 | — | 40 Gems, Bell Trail |
| 36 | — | — |
| 37 | — | — |
| 38 | — | Veil of Salt |
| 39 | — | — |
| 40 | Salt Ribbon | 40 Gems |
| 41 | — | — |
| 42 | — | — |
| 43 | — | — |
| 44 | — | — |
| 45 | — | 40 Gems |
| 46 | — | — |
| 47 | — | — |
| 48 | — | 40 Gems |
| 49 | — | — |
| 50 | 20 Shard Keys | Glass Tide. No Gems. Feat: Bell Pool. |

Gold, key, and Dust counts on tiers 1, 5, 10, 20, and 50 match the live free track. Foam Collar (tier 15) and Salt Ribbon (tier 40) are suggested additions. The live tier 30 title is Boardwalker. This season's title is Tidewalker.

Gem rows: 5, 10, 15, 20, 25, 30, 35, 40, 45, 48. Ten times 40 is 400.

## Cosmetics

Art look is a paint note for the pass, not a drop rarity. Higher tiers are brighter. Commons stay simple.

| id | name | tier | track | kind | art look | visual note |
|---|---|---|---|---|---|---|
| `pass_s2_skin_salt` | Saltcloth | 2 | premium | skin | Common | Cream cloth, pale salt speckles. No glow. |
| `pass_s2_skin_foam` | Foamweave | 4 | premium | skin | Common | White cloth, a teal foam edge. No glow. |
| `pass_s2_hat_bell` | Bell Cap | 5 | premium | pet hat | Uncommon | Small cream bell on a strap. Soft teal glow. |
| `pass_s2_skin_brine` | Brineweave | 8 | premium | skin | Uncommon | Dark teal cloth, salt hem. No glow. |
| `pass_s2_trail_foam` | Foam Trail | 10 | premium | trail | Uncommon | Short white foam puffs. Soft teal. |
| `pass_s2_skin_gull` | Gullcloth | 12 | premium | skin | Rare | Gull-gray cloak, cream hem. No glow. |
| `pass_s2_collar_foam` | Foam Collar | 15 | free | pet collar | Common | Cream band, one teal stitch. No glow. |
| `pass_s2_skin_lamp` | Pool Lamp | 15 | premium | skin | Rare | Blue-white lamp stitches. Soft lamp glow. |
| `pass_s2_skin_pearl` | Pearlsheen | 18 | premium | skin | Rare | Cream cloth, one pale pearl button. Soft glow. |
| `pass_s2_emote_tide` | Tide Bow | 20 | premium | emote | Rare | A short bow. One teal ripple on the ground. No splash. |
| `pass_s2_skin_kelp` | Kelpbound | 22 | premium | skin | Rare | Dark green-teal wrap. No glow. |
| `pass_s2_vfx_bell` | Bell Glow | 25 | premium | weapon glow | Epic | Soft teal bell glint on the weapon. No beam. |
| `pass_s2_skin_arch` | Archcloth | 28 | premium | skin | Epic | White salt-arch pattern. Pale steady glow. |
| `pass_s2_title_tide` | Tidewalker | 30 | free | title | Uncommon | Name text in `#40BA62`. Soft moss glow. No icon. |
| `pass_s2_hat_shell` | Shell Cap | 30 | premium | pet hat | Epic | Cream shell cap, teal rim. Steady glow. |
| `pass_s2_trail_bell` | Bell Trail | 35 | premium | trail | Epic | Tiny cream bells. Soft teal glow. Quiet. |
| `pass_s2_skin_veil` | Veil of Salt | 38 | premium | skin | Epic | Sheer cream veil, salt glitter. Steady glow. |
| `pass_s2_ribbon_salt` | Salt Ribbon | 40 | free | pet ribbon | Rare | Short cream ribbon, one teal stitch. Soft glow. |
| `pass_s2_skin_glass` | Glass Tide | 50 | premium | skin | Mythic | Tall salt-glass coat, teal inner light. Bright, still readable. No face. |

Premium count: 10 skins, 2 pet hats, 2 trails, 1 emote, 1 weapon glow. Same slots as the live premium track, new names.

Flags: Saltcloth is not Gladecloth. Foamweave is not Mossweave, Fernweave, or Barkweave. Bell Cap is not Moss Cap. Foam Trail is not Spore Trail. Pool Lamp is not Lantern Glow and not the Far Glade sap lamps. Tide Bow is not Root Bow and not Tideglass Dagger. Kelpbound is not Kelpstrand Bow. Bell Glow is not Sap Glow. Shell Cap is not Gnarl Crown. Bell Trail is not Lantern Trail. Veil of Salt is not Veil of Leaves. Glass Tide is not Nightmare Bloom and not the Drowned Choir raid. Pearlsheen is not a Pearl Trench prop. Gullcloth is not Gull Shelf. Foam Collar and Salt Ribbon are not Grove Ribbon, Nest Thread, Mudstep Ribbon, or Seat Ribbon. Tidewalker is not Boardwalker and not Heartwood Student. No other game's pass, skin, or signature mechanic is used.
