# Armor batch 1

G-005. Twenty-four armor pieces in six themed looks, for a later catalog draft and the 3D art pass.

Each look is helm, chest, legs, and boots, the slots in `Schema.ARMOR_SLOTS`. One look per rarity. These are looks, not set bonuses. `setId` stays empty. G-007 owns bonuses. They are not class-locked and they are not raid relics.

Stats stay on the slot ranges in `ItemBases.luau`. Rarity multiplies both ends by the live scale in `Stats.RARITY_SCALE`. Those numbers are already in code. Nothing below changes them. Flavor is 12 words or fewer.

Not used: Woven Bark Vest, Living Bark Cuirass, Grovewarden (Hood, Vestments, Greaves, Wraps), Brineplate Cuirass, Slagplate Cuirass, Chronoplate, Voidplate, Heartwood Bulwark, Springwell, Kilnheart, Rimewake, Riftweave.

| rarity | glow key | live scale |
|---|---|---|
| Common | none | 1 |
| Uncommon | soft | 1.15 |
| Rare | steady | 1.35 |
| Epic | bright | 1.6 |
| Legendary | strong, short trail | 1.95 |
| Mythic | prism or void, readable across a room | 2.4 |

| slot | health min | health max | defense min | defense max |
|---|---|---|---|---|
| helm | 20 | 36 | 4 | 8 |
| chest | 40 | 70 | 8 | 14 |
| legs | 28 | 48 | 6 | 11 |
| boots | 14 | 26 | 3 | 7 |

Common scale, weight 1, from `ItemBases` `ARMOR_STATS`. A drop still rolls inside the scaled range.

## Waycloth

Common. Haven road clothes. No glow. Choice: the hub look, not a realm ascension set.

| id | name | slot | flavor | visual note |
|---|---|---|---|---|
| waycloth_cap | Waycloth Cap | helm | A plain cap for the road out of Haven. | Soft round cap, undyed linen, pine-brown stitch, no glow. |
| waycloth_tunic | Waycloth Tunic | chest | A linen tunic with pine-brown stitching. | Straight tunic, cream linen, brown hem, no glow. |
| waycloth_trousers | Waycloth Trousers | legs | Loose trousers dusty from the Haven trail. | Loose trousers, dust-gray cloth, no glow. |
| waycloth_shoes | Waycloth Shoes | boots | Soft shoes with one worn heel. | Low soft shoes, scuffed brown leather, no glow. |

## Gladecloth

Uncommon. Verdant Wilds. Soft moss glow. Not Grovewarden, not the bark chest pieces, and not the Mossweave Shard Pass skin.

| id | name | slot | flavor | visual note |
|---|---|---|---|---|
| gladecloth_hood | Gladecloth Hood | helm | A hood grown over with yellow-green moss. | Deep hood, brown cloth under yellow-green moss, soft moss glow. |
| gladecloth_vest | Gladecloth Vest | chest | A soft vest seamed with living moss. | Short vest, bark-brown panels, green moss seams, soft seam glow. |
| gladecloth_leggings | Gladecloth Leggings | legs | Thin leggings wrapped in green vine. | Close leggings, olive cloth, thin vine wraps, soft green glow. |
| gladecloth_boots | Gladecloth Boots | boots | Ankle boots crusted with damp moss. | Ankle boots, dark leather, damp moss crust, soft toe glow. |

## Coralmail

Rare. Sunken Reach. Steady sea glow. Not Brineplate Cuirass.

| id | name | slot | flavor | visual note |
|---|---|---|---|---|
| coralmail_helm | Coralmail Helm | helm | A helm of pale pink coral plates. | Open helm, pale pink coral plates, steady teal inner glow. |
| coralmail_hauberk | Coralmail Hauberk | chest | Linked coral scales over a kelp lining. | Hip-length hauberk, pink-orange coral scales, kelp-green lining, steady sea glow. |
| coralmail_leggings | Coralmail Leggings | legs | Leggings filmed with dried sea salt. | Fitted leggings, gray-teal scale, white salt film, steady pale glow. |
| coralmail_waders | Coralmail Waders | boots | Tall waders the color of kelp. | Tall waders, kelp-green, a pale salt line, steady tide glow at the cuff. |

## Cinderplate

Epic. Emberforge. Bright coal glow. Not Slagplate Cuirass and not Kilnheart.

| id | name | slot | flavor | visual note |
|---|---|---|---|---|
| cinderplate_helm | Cinderplate Helm | helm | A closed helm with one coal slit. | Closed helm, soot-black iron, one coal slit, bright orange slit glow. |
| cinderplate_cuirass | Cinderplate Cuirass | chest | A dark cuirass veined with cooling slag. | Broad cuirass, dark iron, orange slag veins, bright vein glow. |
| cinderplate_leggings | Cinderplate Leggings | legs | Leggings that shed tiny orange sparks. | Plate leggings, charcoal iron, tiny orange sparks, bright spark glow. |
| cinderplate_sabatons | Cinderplate Sabatons | boots | Heavy sabatons with a hot orange sole. | Heavy sabatons, black iron, a hot orange sole, bright sole glow. |

## Paleveil

Legendary. Frostveil. Strong frost trail. Not Rimewake and not Chronoplate.

| id | name | slot | flavor | visual note |
|---|---|---|---|---|
| paleveil_hood | Paleveil Hood | helm | A hood that sheds slow walking frost. | Tall hood, blue-white cloth, a moving frost edge, strong frost trail. |
| paleveil_surcoat | Paleveil Surcoat | chest | A long coat of packed blue-white frost. | Long surcoat, packed blue-white frost over pale cloth, strong coat glow. |
| paleveil_leggings | Paleveil Leggings | legs | Leggings glazed like quiet blue ice. | Close leggings, clear blue ice glaze, strong cold glow. |
| paleveil_boots | Paleveil Boots | boots | Tall boots that leave no melt behind. | Tall boots, white leather and ice toes, strong frost trail, no melt. |

## Prismrift

Mythic. Void Rift. Prism or void glow that reads across a room. Not Voidplate and not Riftweave.

| id | name | slot | flavor | visual note |
|---|---|---|---|---|
| prismrift_visor | Prismrift Visor | helm | A visor split by a thin void seam. | Narrow visor, gray metal, a violet void seam, seam glow across a room. |
| prismrift_carapace | Prismrift Carapace | chest | A carapace of cracked rainbow glass. | Broad carapace, cracked rainbow glass on a dark shell, prism glow across a room. |
| prismrift_leggings | Prismrift Leggings | legs | Leggings that break light into shards. | Plate leggings, dark metal, falling prism shards, shard glow across a room. |
| prismrift_soles | Prismrift Soles | boots | Dark soles with a prism edge glow. | Low boots, mirrorless black, a prism edge, edge glow across a room. |

| look | rarity | realm | pieces |
|---|---|---|---|
| Waycloth | Common | Haven | 4 |
| Gladecloth | Uncommon | Verdant Wilds | 4 |
| Coralmail | Rare | Sunken Reach | 4 |
| Cinderplate | Epic | Emberforge | 4 |
| Paleveil | Legendary | Frostveil | 4 |
| Prismrift | Mythic | Void Rift | 4 |

24 pieces. Each slot appears six times.

Flags: Gladecloth is not the Mossweave, Fernweave, or Barkweave Shard Pass skins, and Gladecloth Vest is not Woven Bark Vest. Cinderplate Cuirass is not Slagplate Cuirass or Bulwark Cuirass. Paleveil is not Rimewake or Veil of Leaves. Prismrift is not Riftweave, Voidplate, Prism Bow, or Prismfall. No set bonus is attached.
