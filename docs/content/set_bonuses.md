# Armor set bonuses

G-007. Eight world armor sets, each with a 2-piece and a 4-piece bonus, for a later catalog draft.

Bonuses are flat `health` or `defense` from `Stats.DEFS`. Every number below is suggested. Piece ranges in `ItemBases.luau` and `Stats.RARITY_SCALE` stay as they are. A bonus is under one chest of that rarity on those live ranges. It is not multiplied by `RARITY_SCALE` again.

Count rule, same shape as `RelicSets`: 0 or 1 piece gives nothing. 2 or 3 gives the 2-piece. 4 gives both, 2-piece first. A duplicate piece counts once. Pieces from two sets do not add. The four slots are `helm`, `chest`, `legs`, `boots`, so one of these sets and a Verdant Relic Set cannot be worn at the same time.

These sets are open to every class. They are earned loot. No Robux product, no drop-odds change, no raid advantage.

Choice: the six looks in `docs/content/armor_batch1.md`, the live `grovewarden` set, and one new Rootvault set. Plate looks open on defense. Cloth and bark looks open on health. The two Rare sets share one pair of numbers, swapped. The two Epic sets do the same.

Left unused: Heartwood Bulwark, Springwell, Kilnheart, Rimewake, Riftweave, and the bonus ids in `RelicSets.luau` (`planted_taunt`, `barkskin_share`, `pool_cleanse`, `ebb_jump`, `charge_slow`, `guard_cone`, `dash_patch`, `shatter_spread`, `blink_pull`, `unstable_jump`). Also unused: Woven Bark Vest, Living Bark Cuirass, Brineplate Cuirass, Slagplate Cuirass, Chronoplate, Voidplate.

| set | id | rarity | realm | 2-piece | suggested | 4-piece | suggested |
|---|---|---|---|---|---|---|---|
| Waycloth | `waycloth` | Common | Haven | Road Stitch | health +8 | Dust Hem | defense +2 |
| Gladecloth | `gladecloth` | Uncommon | Verdant Wilds | Moss Seam | health +14 | Vine Step | defense +3 |
| Coralmail | `coralmail` | Rare | Sunken Reach | Salt Film | defense +5 | Tide Cuff | health +22 |
| Rootlatch | `rootlatch` | Rare | Rootvault | Amber Knot | health +22 | Root Brace | defense +5 |
| Grovewarden | `grovewarden` | Epic | Verdant Wilds | Sap Line | health +32 | Grove Weight | defense +7 |
| Cinderplate | `cinderplate` | Epic | Emberforge | Coal Band | defense +7 | Spark Vein | health +32 |
| Paleveil | `paleveil` | Legendary | Frostveil | Frost Hem | health +48 | Quiet Ice | defense +10 |
| Prismrift | `prismrift` | Mythic | Void Rift | Void Seam | defense +14 | Prism Rim | health +64 |

## Waycloth

Common. Haven road clothes. Pieces `waycloth_cap`, `waycloth_tunic`, `waycloth_trousers`, `waycloth_shoes` in `docs/content/armor_batch1.md`. No glow on the cloth.

| id | pieces | name | suggested | visual note |
|---|---|---|---|---|
| `road_stitch` | 2 | Road Stitch | health +8 | A dull pine-brown stitch along the hem. No glow. |
| `dust_hem` | 4 | Dust Hem | defense +2 | A faint dust line on the shoes. Still no glow. |

## Gladecloth

Uncommon. Verdant Wilds. Pieces `gladecloth_hood`, `gladecloth_vest`, `gladecloth_leggings`, `gladecloth_boots`. Soft moss glow already on the pieces.

| id | pieces | name | suggested | visual note |
|---|---|---|---|---|
| `moss_seam` | 2 | Moss Seam | health +14 | Yellow-green moss thickens on one seam. Soft seam glow. |
| `vine_step` | 4 | Vine Step | defense +3 | A thin vine ring at the ankles. Soft green glow, no trail. |

## Coralmail

Rare. Sunken Reach. Pieces `coralmail_helm`, `coralmail_hauberk`, `coralmail_leggings`, `coralmail_waders`. Steady sea glow already on the pieces.

| id | pieces | name | suggested | visual note |
|---|---|---|---|---|
| `salt_film` | 2 | Salt Film | defense +5 | A white salt film on the coral plates. Steady pale glow. |
| `tide_cuff` | 4 | Tide Cuff | health +22 | A teal water line at the wader cuffs. Steady tide glow. |

## Rootlatch

Rare. Rootvault. New pieces, not in `ItemBases.luau`. Suggested source: a Rootvault Hard clear. Steady amber glow.

| id | name | slot | visual note |
|---|---|---|---|
| `rootlatch_brow` | Rootlatch Brow | helm | Low bark band, dark wood, one amber knot, steady amber glow. |
| `rootlatch_coat` | Rootlatch Coat | chest | Short bark coat, dark plates, amber seam, steady seam glow. |
| `rootlatch_chaps` | Rootlatch Chaps | legs | Bark chaps over olive cloth, amber stitch, steady stitch glow. |
| `rootlatch_boots` | Rootlatch Boots | boots | Heavy bark boots, an amber sole line, steady sole glow. |

| id | pieces | name | suggested | visual note |
|---|---|---|---|---|
| `amber_knot` | 2 | Amber Knot | health +22 | The brow knot brightens. Steady amber glow, no rays. |
| `root_brace` | 4 | Root Brace | defense +5 | A root band locks the coat hem. Steady brown-amber glow. |

## Grovewarden

Epic. Verdant Wilds. Live set id `grovewarden` in `ItemBases.luau`. The four pieces sit in the Verdant armory pool at weight 100. The hood also has recipe `grove_hood`. No bonus is in code today. Bright gold-sap glow.

| id | name | slot | visual note |
|---|---|---|---|
| `grovewarden_hood` | Grovewarden Hood | helm | Deep hood, brown cloth, living green leaves, bright gold-sap edge. |
| `grovewarden_vestments` | Grovewarden Vestments | chest | Long vestments, layered leaves, bright sap seams. |
| `grovewarden_greaves` | Grovewarden Greaves | legs | Bark greaves, vine laces, bright green edge. |
| `grovewarden_wraps` | Grovewarden Wraps | boots | Cloth wraps to the knee, leaf print, bright sap at the ankle. |

| id | pieces | name | suggested | visual note |
|---|---|---|---|---|
| `sap_line` | 2 | Sap Line | health +32 | A thin gold sap line links the worn pieces. Bright, short. |
| `grove_weight` | 4 | Grove Weight | defense +7 | A soft leaf ring rests at the feet. Bright green, no pull. |

## Cinderplate

Epic. Emberforge. Pieces `cinderplate_helm`, `cinderplate_cuirass`, `cinderplate_leggings`, `cinderplate_sabatons`. Bright coal glow already on the pieces.

| id | pieces | name | suggested | visual note |
|---|---|---|---|---|
| `coal_band` | 2 | Coal Band | defense +7 | A coal band closes on the helm slit. Bright orange glow. |
| `spark_vein` | 4 | Spark Vein | health +32 | Orange sparks run the slag veins. Bright vein glow, no fire trail. |

## Paleveil

Legendary. Frostveil. Pieces `paleveil_hood`, `paleveil_surcoat`, `paleveil_leggings`, `paleveil_boots`. Strong frost trail already on the pieces.

| id | pieces | name | suggested | visual note |
|---|---|---|---|---|
| `frost_hem` | 2 | Frost Hem | health +48 | A blue-white frost hem walks with the coat. Strong frost glow. |
| `quiet_ice` | 4 | Quiet Ice | defense +10 | A clear ice film on the boots. Strong cold glow. The film leaves no melt. |

## Prismrift

Mythic. Void Rift. Pieces `prismrift_visor`, `prismrift_carapace`, `prismrift_leggings`, `prismrift_soles`. Prism glow that reads across a room.

| id | pieces | name | suggested | visual note |
|---|---|---|---|---|
| `void_seam` | 2 | Void Seam | defense +14 | The visor seam widens a finger. Violet glow reads across a room. |
| `prism_rim` | 4 | Prism Rim | health +64 | A cracked rainbow rim circles the carapace. Prism glow reads across a room. |

8 sets. 16 bonuses. 4 new Rootlatch pieces. Grovewarden visuals are notes for the live items.

Flags: Grovewarden is the live `ItemBases` set. Gladecloth is not the Mossweave skin. Cinderplate is not Slagplate Cuirass. Paleveil is not Rimewake. Prism Rim is not the Prism Edge sword, and Prismrift is not Riftweave or Voidplate. Rootlatch is not the Choked Thicket room, Living Bark Cuirass, or Grovewarden. Amber Knot is not Gnarl's Seed. No bonus here taunts, cleanses, slows, pulls, spreads Chill, or vents Heat.
