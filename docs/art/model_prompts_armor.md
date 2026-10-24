# Armor model prompts, batch 1

G-111. One mesh prompt for each piece in `docs/content/armor_batch1.md`. For the 3D pass. These are looks, not relic sets. Do not add them to `ItemBases.luau`.

Shared style: dark-fantasy Roblox mesh, cloth, leather, metal, and crystal. Y-up. The piece's opening faces +Z and the top points toward +Y, ready to sit on a blocky avatar. One silhouette that reads at 8 studs. No gore, no blood, no logo, no other game's armor. Neon only where the glow column says. Nameplate color is the `Rarities` ladder. Mythic nameplates are red `#E6404E` (`Rarities.luau:44`). Paint the mesh from the glow column, not from that red and not from `UiTheme` gold.

Triangle counts are suggested. They match the weapon prompt budget, one mesh per piece.

| rarity | suggested tris | glow |
|---|---|---|
| Common | 450 | none |
| Uncommon | 700 | soft, one edge |
| Rare | 1100 | steady, one core |
| Epic | 1600 | bright, reads at 20 studs |
| Legendary | 2200 | strong, plus a short trail |
| Mythic | 2800 | prism or void, reads across a room |

| id | name | slot | rarity | silhouette | colors | glow | tris | prompt |
|---|---|---|---|---|---|---|---|---|
| `waycloth_cap` | Waycloth Cap | helm | Common | Soft round cap | Undyed linen, pine-brown stitch | none | 450 | A soft round cap of undyed linen with pine-brown stitch, no glow. |
| `waycloth_tunic` | Waycloth Tunic | chest | Common | Straight tunic | Cream linen, brown hem | none | 450 | A straight cream tunic with a brown hem, no glow. |
| `waycloth_trousers` | Waycloth Trousers | legs | Common | Loose trousers | Dust-gray cloth | none | 450 | Loose dust-gray trousers, no glow. |
| `waycloth_shoes` | Waycloth Shoes | boots | Common | Low soft shoes | Scuffed brown leather | none | 450 | Low soft shoes of scuffed brown leather, no glow. |
| `gladecloth_hood` | Gladecloth Hood | helm | Uncommon | Deep hood | Brown cloth, yellow-green moss | soft moss | 700 | A deep hood, brown cloth under yellow-green moss, soft moss glow. |
| `gladecloth_vest` | Gladecloth Vest | chest | Uncommon | Short vest | Bark-brown panels, green moss seams | soft seam | 700 | A short vest of bark-brown panels with green moss seams, soft seam glow. |
| `gladecloth_leggings` | Gladecloth Leggings | legs | Uncommon | Close leggings | Olive cloth, thin vines | soft green | 700 | Close olive leggings wrapped in thin vines, soft green glow. |
| `gladecloth_boots` | Gladecloth Boots | boots | Uncommon | Ankle boots | Dark leather, damp moss | soft toe | 700 | Ankle boots of dark leather with a damp moss crust, soft toe glow. |
| `coralmail_helm` | Coralmail Helm | helm | Rare | Open helm | Pale pink coral plates | steady teal inner | 1100 | An open helm of pale pink coral plates, steady teal glow inside. |
| `coralmail_hauberk` | Coralmail Hauberk | chest | Rare | Hip-length hauberk | Pink-orange coral scales, kelp-green lining | steady sea | 1100 | A hip-length hauberk of pink-orange coral scales over a kelp-green lining, steady sea glow. |
| `coralmail_leggings` | Coralmail Leggings | legs | Rare | Fitted leggings | Gray-teal scale, white salt | steady pale | 1100 | Fitted gray-teal scale leggings filmed with white salt, steady pale glow. |
| `coralmail_waders` | Coralmail Waders | boots | Rare | Tall waders | Kelp-green, pale salt line | steady tide at the cuff | 1100 | Tall kelp-green waders with a pale salt line, steady tide glow at the cuff. |
| `cinderplate_helm` | Cinderplate Helm | helm | Epic | Closed helm | Soot-black iron, one coal slit | bright orange slit | 1600 | A closed soot-black helm with one coal slit, bright orange slit glow. |
| `cinderplate_cuirass` | Cinderplate Cuirass | chest | Epic | Broad cuirass | Dark iron, orange slag veins | bright vein | 1600 | A broad dark-iron cuirass veined with orange slag, bright vein glow. |
| `cinderplate_leggings` | Cinderplate Leggings | legs | Epic | Plate leggings | Charcoal iron, tiny sparks | bright spark | 1600 | Charcoal plate leggings shedding tiny orange sparks, bright spark glow. |
| `cinderplate_sabatons` | Cinderplate Sabatons | boots | Epic | Heavy sabatons | Black iron, hot orange sole | bright sole | 1600 | Heavy black-iron sabatons with a hot orange sole, bright sole glow. |
| `paleveil_hood` | Paleveil Hood | helm | Legendary | Tall hood | Blue-white cloth, moving frost edge | strong frost trail | 2200 | A tall blue-white hood with a moving frost edge, strong frost trail. |
| `paleveil_surcoat` | Paleveil Surcoat | chest | Legendary | Long surcoat | Packed blue-white frost over pale cloth | strong coat | 2200 | A long surcoat of packed blue-white frost over pale cloth, strong coat glow. |
| `paleveil_leggings` | Paleveil Leggings | legs | Legendary | Close leggings | Clear blue ice glaze | strong cold | 2200 | Close leggings glazed like quiet blue ice, strong cold glow. |
| `paleveil_boots` | Paleveil Boots | boots | Legendary | Tall boots | White leather, ice toes | strong frost trail, no melt | 2200 | Tall boots of white leather and ice toes, strong frost trail, no melt. |
| `prismrift_visor` | Prismrift Visor | helm | Mythic | Narrow visor | Gray metal, violet void seam | seam, room-wide | 2800 | A narrow gray visor split by a violet void seam, seam glow that reads across a room. |
| `prismrift_carapace` | Prismrift Carapace | chest | Mythic | Broad carapace | Cracked rainbow glass on a dark shell | prism, room-wide | 2800 | A broad carapace of cracked rainbow glass on a dark shell, prism glow across a room. |
| `prismrift_leggings` | Prismrift Leggings | legs | Mythic | Plate leggings | Dark metal, falling prism shards | shard, room-wide | 2800 | Dark plate leggings that shed falling prism shards, shard glow across a room. |
| `prismrift_soles` | Prismrift Soles | boots | Mythic | Low boots | Mirrorless black, prism edge | edge, room-wide | 2800 | Low mirrorless-black boots with a prism edge, edge glow across a room. |

| look | rarity | pieces | tris each |
|---|---|---|---|
| Waycloth | Common | 4 | 450 |
| Gladecloth | Uncommon | 4 | 700 |
| Coralmail | Rare | 4 | 1100 |
| Cinderplate | Epic | 4 | 1600 |
| Paleveil | Legendary | 4 | 2200 |
| Prismrift | Mythic | 4 | 2800 |

24 pieces. Each slot appears six times. `set` stays empty. These prompts do not attach a set bonus.

Flags: Gladecloth is not Mossweave, Fernweave, Barkweave, or Woven Bark Vest. Cinderplate Cuirass is not Slagplate Cuirass. Paleveil is not Rimewake. Prismrift is not Riftweave, Voidplate, or Prism Bow. None of these ids are in `ItemBases.luau`.
