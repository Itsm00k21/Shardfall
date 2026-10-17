# Weapons batch 2

G-002. Thirty more weapons, weighted to Epic and above, plus six Heartshard weapons for the Heartwood raid.

The first table is the open-world batch. The second is the raid family. Stats stay on the `ItemBases.luau` ranges for that type. No unique combat perk. Suggested sources are not a live drop table. None of these names are in batch 1 or in `ItemBases.luau`.

| rarity | count |
|---|---|
| Common | 2 |
| Uncommon | 3 |
| Rare | 4 |
| Epic | 8 |
| Legendary | 8 |
| Mythic | 5 |

## Open-world batch

| id | name | type | rarity | flavor | visual note |
|---|---|---|---|---|---|
| yard_sword | Yard Sword | sword | Common | A blunt sword from the Haven practice yard. | Straight blunt sword, scuffed iron and cloth grip, no glow. |
| fence_bow | Fence Bow | bow | Common | A light bow kept by the Haven fence. | Light shortbow, pale wood and a plain string, no glow. |
| sap_needle | Sap Needle | dagger | Uncommon | A thin needle sticky with sweet sap. | Thin straight needle, honey-brown, soft sap glow at the tip. |
| grove_switch | Grove Switch | staff | Uncommon | A flexible switch cut from grove wood. | Flexible crooked staff, living green wood, soft leaf glow. |
| stump_maul | Stump Maul | hammer | Uncommon | A short maul chopped from a hard stump. | Short maul, cut stump head and a root haft, soft amber cracks. |
| river_cleaver | River Cleaver | greatsword | Rare | A wide cleaver stained with river silt. | Wide greatsword, silt-gray blade and a brown wrap, steady muddy-teal glow. |
| saltbrand | Saltbrand | sword | Rare | A saber crusted with dried salt crystals. | Curved saber, steel under white salt crystals, steady pale glow. |
| gull_recurve | Gull Recurve | bow | Rare | A recurve the color of a gull wing. | Recurve, white and gray wing colors, steady sea-gray glow. |
| ink_fang | Ink Fang | dagger | Rare | A dark fang that leaves a purple mark. | Curved fang, black with a purple edge, steady violet glow. |
| amber_edge | Amber Edge | sword | Epic | A sword with a slow amber pulse inside. | Straight sword, gold-brown fuller, bright slow amber pulse. |
| ironroot_slab | Ironroot Slab | greatsword | Epic | A heavy slab of root as hard as iron. | Slab greatsword, iron-gray root grain, bright green seam glow. |
| nightlatch | Nightlatch | dagger | Epic | A latch-blade that clicks open in the dark. | Folding latch dagger, black steel, bright violet latch glow. |
| treant_maul | Treant Maul | hammer | Epic | A maul grown from old treant wood. | Grown hammer, knotted brown wood and moss, bright sap-green glow. |
| featherdraw | Featherdraw | bow | Epic | A bow edged with green owl feathers. | Recurve edged in green feathers, moon-silver limbs, bright feather glow. |
| ambercoil | Ambercoil | staff | Epic | A staff coiled in hardened amber vine. | Straight staff in an amber vine coil, bright honey glow. |
| moonbranch | Moonbranch | bow | Epic | A pale branch bow silvered like moonlight. | Branch bow, pale wood and silver bark, bright moon glow. |
| seedspine | Seedspine | sword | Epic | A sword with a thin green seed line. | Straight sword, dark steel and a green seed line, bright line glow. |
| frostspine | Frostspine | sword | Legendary | A frost sword that draws pale lines in air. | Long sword, ice-blue spine, strong frost trail. |
| veilcleaver | Veilcleaver | greatsword | Legendary | A tall cleaver wrapped in walking frost. | Tall cleaver, steel under a moving frost veil, strong white trail. |
| glass_whisper | Glass Whisper | dagger | Legendary | A thin dagger of quiet singing glass. | Thin glass dagger, clear with a blue note, strong cold glow. |
| boreal_maul | Boreal Maul | hammer | Legendary | A blue-white maul heavy as packed snow. | Heavy maul, packed blue-white snow, strong cold trail. |
| aurora_longbow | Aurora Longbow | bow | Legendary | A longbow banded with slow aurora light. | Tall longbow, green and violet bands, strong slow color trail. |
| clockglass_staff | Clockglass Staff | staff | Legendary | A glass staff holding one stopped snowflake. | Tall glass staff, one stopped flake, strong blue glow. |
| snowthread | Snowthread | bow | Legendary | A bow strung with a thread of bright rime. | Pale bow, white limbs and a rime string, strong string glow. |
| rime_coil | Rime Coil | staff | Legendary | A coiled staff of ice that will not drip. | Coiled ice staff, blue-white spiral, strong cold glow. |
| evenfall | Evenfall | sword | Mythic | A dusk blade that drinks the color nearby. | Long curved sword, dusk-purple to black, a soft dark glow that pulls color in. |
| riftcleaver | Riftcleaver | greatsword | Mythic | A greatsword split by a thin void seam. | Broad greatsword, gray steel and a violet void seam, seam glow across a room. |
| unspoken | Unspoken | dagger | Mythic | A dagger with no reflection and no sound. | Slim dagger, mirrorless gray, a quiet dark outline glow. |
| prismfall | Prismfall | hammer | Mythic | A hammer that breaks light into falling shards. | Massive hammer, clear head of broken rainbow, prism shards glow in the head. |
| voidlace | Voidlace | bow | Mythic | A bow laced from strands of visible night. | Tall bow, black limbs and night-blue laces, lace glow across a room. |

## Heartshard raid weapons

Family name: Heartshard. The id prefix is the string `RaidLuck` already treats as this family. Do not reuse the test ids `heartshard_edge`, `heartshard_drop`, or `heartshard_red`.

Drop rule from `docs/design/shardfall_raids.md`: a Resonant copy has a red border. Three Resonant copies unlock the Forge pattern. Craft spends Raid Marks and materials. The Forge still upgrades the weapon from +0 to +10. A crafted copy can be traded after the crafter's first clear. Not sold for Robux.

Seasonheart is the only Legendary, and only from Shardbreaker. The other five are Epic, matching Normal and Hard reward bands. Suggested sources name a home boss. They are not wired.

| id | name | type | rarity | suggested source | flavor | visual note |
|---|---|---|---|---|---|---|
| heartshard_twinblade | Twinheart Blade | sword | Epic | Thornwarden Twins | Two edges share one quiet amber heart. | Split sword, one bramble-green edge and one violet edge, amber pulse at the join. |
| heartshard_briarneedle | Briarheart Needle | dagger | Epic | Thornwarden Twins | A long briar thorn grown around a shard. | Curved thorn dagger, deep green with a violet crystal vein, faint pulse. |
| heartshard_sapspire | Sapwell Spire | staff | Epic | Mother Sapwell | A living staff that weeps warm golden sap. | Twisted root staff, honey-amber crystal core, slow inner glow. Sap is golden, not red. |
| heartshard_galebow | Galecrown Bow | bow | Epic | Galecrown | Owl feathers lock into a storm-bent bow. | Wing-shaped bow, moon-silver and leaf-green, feather motes when drawn. |
| heartshard_gnarlmaul | Gnarlheart Maul | hammer | Epic | Grandmother Gnarl | Old bark cracked around an amber heart crystal. | Huge bark hammer, cracked face, deep green glow, amber crystal in the head. |
| heartshard_seasonheart | Seasonheart | greatsword | Legendary | Grandmother Gnarl Awakened, Shardbreaker | The awakened heart, cooled into a great blade. | Tall pale heartwood greatsword, amber crystal core, glow cycles spring green, summer gold, autumn amber, winter blue. |

Flags: Resonant and the red border are this game's craft words from `docs/design/shardfall_raids.md`. Galecrown Bow and Sapwell Spire use Heartwood boss names on purpose. No outside weapon names.
