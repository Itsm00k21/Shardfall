# Weapon model prompts, batch 1

G-041. One mesh prompt for each weapon in `docs/content/weapons_batch1.md`. For the 3D pass. These are not live items. Do not add them to `ItemBases.luau`.

Shared style: dark-fantasy Roblox mesh, wood, stone, and crystal. Y-up. Handle or grip at the origin, the striking end toward +Y. One silhouette that reads at 8 studs. No gore, no blood, no logo, no other game's weapon. Neon only where the glow column says. The nameplate color is not the mesh glow. `UiTheme.RARITY` is Common `(198, 196, 206)`, Uncommon `(96, 196, 120)`, Rare `(96, 168, 232)`, Epic `(186, 120, 232)`, Legendary `(255, 196, 72)`. Mythic nameplates reuse Legendary gold (`UiTheme.luau:38-39`, `UiTheme.luau:94-98`). Paint the mesh from the glow column, not from that gold.

Triangle counts are suggested.

| rarity | suggested tris | glow |
|---|---|---|
| Common | 450 | none |
| Uncommon | 700 | soft, one edge |
| Rare | 1100 | steady, one core |
| Epic | 1600 | bright, reads at 20 studs |
| Legendary | 2200 | strong, plus a short trail |
| Mythic | 2800 | prism or void, reads across a room |

| id | name | type | rarity | silhouette | colors | glow | tris | prompt |
|---|---|---|---|---|---|---|---|---|
| `trail_cleaver` | Trail Cleaver | sword | Common | Short straight cleaver | Dull iron, pine grip | none | 450 | A short road cleaver, nicked dull iron and a pine grip, no glow. |
| `pocket_thorn` | Pocket Thorn | dagger | Common | Small straight thorn | Dull green, brown wrap | none | 450 | A short thorn dagger in a brown leather wrap, dull green, no glow. |
| `camp_mallet` | Camp Mallet | hammer | Common | Squat round head | Gray stone, pine haft | none | 450 | A squat camp hammer, round gray stone on a pine haft, no glow. |
| `lantern_crook` | Lantern Crook | staff | Common | Crooked walking staff | Brown oak, empty iron hook | none | 450 | A crooked oak staff with one empty iron lantern hook, no glow. |
| `haven_shortbow` | Haven Shortbow | bow | Common | Short plain bow | Pale wood, hemp string | none | 450 | A plain Haven shortbow, pale wood and a hemp string, no glow. |
| `mossedge` | Mossedge | sword | Uncommon | Leaf-shaped blade | Steel under yellow-green moss | soft moss | 700 | A leaf-shaped sword, steel under yellow-green moss, soft moss glow on the edge. |
| `sporekiss` | Sporekiss | dagger | Uncommon | Curved fang | Bone-white, violet dust | soft purple | 700 | A curved bone-white fang dusted with violet spores, soft purple glow. |
| `barkfall` | Barkfall | hammer | Uncommon | Block head | Layered brown bark | soft amber seam | 700 | A block hammer of layered brown bark, a soft amber glow in the seams. |
| `dewspire` | Dewspire | staff | Uncommon | Slim straight staff | Green wood, one clear drop | soft cool | 700 | A slim green staff crowned with one clear dew drop, soft cool glow. |
| `vinewhisper` | Vinewhisper | bow | Uncommon | Bow grown from one vine | Sap-green limbs | soft green string | 700 | A bow grown from one vine, sap-green limbs, soft green glow on the string. |
| `brine_saber` | Brine Saber | sword | Rare | Curved saber | Sea-green steel, white salt | steady teal | 1100 | A curved sea-green saber filmed with white salt, steady teal glow. |
| `pearl_stiletto` | Pearl Stiletto | dagger | Rare | Needle | Cracked cream pearl | steady pale inner | 1100 | A needle dagger grown from cracked cream pearl, steady pale glow inside. |
| `tidebreaker` | Tidebreaker | hammer | Rare | Coral head | Pink-orange coral, teal drip | steady sea | 1100 | A coral-headed hammer, pink-orange coral with a teal drip, steady sea glow. |
| `choir_rod` | Choir Rod | staff | Rare | Straight rod | Pale rose coral, deep teal | steady tip | 1100 | A straight coral rod, pale rose and deep teal, steady glow at the tip. |
| `reef_recurve` | Reef Recurve | bow | Rare | Recurve | Cream reef bone, kelp-green cord | steady tide | 1100 | A recurve of cream reef bone and a kelp-green cord, steady tide glow. |
| `emberbrand` | Emberbrand | sword | Epic | Broad straight sword | Black iron, orange slag veins | bright forge | 1600 | A broad black sword veined with orange slag, bright forge glow in the veins. |
| `spark_fang` | Spark Fang | dagger | Epic | Curved hot dagger | Charcoal blade | bright orange sparks | 1600 | A curved charcoal dagger shedding tiny orange sparks, bright spark glow. |
| `anvilheart` | Anvilheart | hammer | Epic | Square anvil head | Dark iron, coal core | bright orange core | 1600 | A square anvil hammer, dark iron around a coal core, bright orange core glow. |
| `coalspire` | Coalspire | staff | Epic | Tall staff, caged head | Soot-black shaft, caged ember | bright coal | 1600 | A tall soot-black staff with a caged ember, bright coal glow. |
| `heatstring` | Heatstring | bow | Epic | Black recurve | Black limbs, heated-wire string | bright orange string | 1600 | A black recurve whose string glows like heated wire, bright orange string. |
| `pale_oath` | Pale Oath | sword | Legendary | Long straight sword | Ice-white blade | strong frost trail | 2200 | A long ice-white sword that sheds a short frost trail, strong cold glow. |
| `second_frost` | Second Frost | dagger | Legendary | Glass dagger | Clear glass, blue core | strong cold trail | 2200 | A glass dagger, clear with a blue core, strong cold trail. It does not drip. |
| `winter_bell` | Winter Bell | hammer | Legendary | Bell-shaped head | Blue-white ice | strong rim, short frost trail | 2200 | A heavy hammer shaped like a frozen bell, blue-white ice, strong rim glow and a short frost trail. |
| `stillglass_spire` | Stillglass Spire | staff | Legendary | Tall clear staff | Clear ice, one flake inside | strong blue | 2200 | A tall clear staff with one frozen flake inside, strong blue glow. |
| `white_gale` | White Gale | bow | Legendary | Rime longbow | White limbs | strong mist trail when drawn | 2200 | A rime longbow, white limbs, a strong pale mist trail when the string is drawn. |
| `prism_edge` | Prism Edge | sword | Mythic | Long straight sword | Void-black blade, rainbow edge | prism, room-wide | 2800 | A long void-black sword with a rainbow edge, prism glow that reads across a room. |
| `unlit_needle` | Unlit Needle | dagger | Mythic | Needle-thin | Matte black, one white point | point only | 2800 | A needle of matte black with one white point. Only the point glows. |
| `riftcrown` | Riftcrown | hammer | Mythic | Heavy block, crowned | Dark iron, cracked prism crown | prism | 2800 | A heavy dark-iron hammer crowned by a cracked prism, prism glow across a room. |
| `last_verse` | Last Verse | staff | Mythic | Tall staff, caged shard | Night-blue shaft, spinning shard | void plus one spark | 2800 | A night-blue staff caging one spinning shard, void glow plus one spark. |
| `colorless_draw` | Colorless Draw | bow | Mythic | Long asymmetrical bow | Clear limbs, a string of missing color | pale void | 2800 | A long asymmetrical bow, clear limbs and a string of missing color, pale void glow. |

| rarity | swords | daggers | hammers | staffs | bows | total |
|---|---|---|---|---|---|---|
| Common | 1 | 1 | 1 | 1 | 1 | 5 |
| Uncommon | 1 | 1 | 1 | 1 | 1 | 5 |
| Rare | 1 | 1 | 1 | 1 | 1 | 5 |
| Epic | 1 | 1 | 1 | 1 | 1 | 5 |
| Legendary | 1 | 1 | 1 | 1 | 1 | 5 |
| Mythic | 1 | 1 | 1 | 1 | 1 | 5 |

Flags: Choir Rod is this game's Sunken Reach coral, not an outside name. None of these ids are in `ItemBases.luau`.
