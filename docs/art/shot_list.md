# 3D shot list

G-040. Every model the 3D pass needs, by group, with a build priority. This file does not change code. Blockouts stay until a mesh replaces them.

| priority | build when |
|---|---|
| P0 | Beta. A player can already stand next to the block or the data row. |
| P1 | First pass after that. Heartwood prizes, Far Glade, batch 1, the live Verdant gaps. |
| P2 | Later realms, Secret rows, and drafts past the beta cap. |

Inside one priority, low rarity first. Commons stay simple. Mythic reads across a room.

Choice: the player body is the Roblox avatar. No custom body mesh. A class reads through its weapon, its VFX, and a pedestal. Mounts, auras, trails, dyes, and name plates stay in `docs/content/mounts.md` and `docs/content/cosmetics.md`. They are not in the groups below.

`DUNGEON_GATE_PLAZA.md` is a proposal. The live hub is still `HavenBuilder`. Do not model a second arch row.

Secret sits above Mythic in `Rarities.ORDER`. Suggested look: one impossible detail up close, no extra room light. The mesh is stranger than Mythic at arm's length. It does not out-glow it across Haven.

Mythic nameplates reuse Legendary gold (`UiTheme.luau:38-39`). Mesh glow follows the row, not that gold.

## Haven

Live parts in `HavenBuilder`. One mesh each, unless the note says a tint.

| id | name | priority | visual note |
|---|---|---|---|
| `lumen_heart` | Lumen Heart | P0 | Pale glass column `(186, 168, 204)`, warm neon core `(255, 214, 164)`, a cool crack, six lilac glass spikes on a 22-stud slate pedestal. Orbit shards stay a separate ring. |
| `hub_spawn` | Hub spawn pad | P0 | Flat 12×12 pad at the plaza. No glow. Not a statue. |
| `forge` | Forge | P0 | Stone workshop, chimneys, a small fire, orange sparks. The fire is a forge, not a wound. |
| `market` | Market | P0 | Stall roofs on the rim. Cloth and wood. No glow. |
| `guild` | Guild hall | P0 | A hall mass on the rim. Dark wood, one dull lantern. No banners with words. |
| `garden` | Pet garden | P0 | Low beds, moss, one still pool. Soft green. No cute statues. |
| `observatory` | Observatory | P0 | A round dark building on the east island. One pale window. |
| `gate_court` | Gate court | P0 | The paved court the live hub already stamps. Keep it empty enough to walk. |
| `rim_shop` | Rim shop | P0 | One stall, wood counter, no floating sign text. |
| `realm_arch` | Realm arch | P0 | One arch mesh, five tints. Verdant `(64, 196, 96)` is open. Sunken `(50, 150, 255)`, Ember `(255, 150, 40)`, Frost `(186, 228, 255)`, and Void `(150, 70, 220)` read closed. |
| `bridge` | Bridge | P0 | Stone deck off the plaza. No rails that block the camera. |
| `waystone` | Waystone | P0 | Gray-lilac pillar and a small glass crystal. Six placements. They do not collide. Soft crystal glow. |
| `townsfolk` | Townsfolk | P0 | A simple walker, cloth and a plain flag. No face detail. Not a class. |
| `bird` | Haven bird | P0 | A small dark bird, circle path. Not a pet. |
| `armory_stand` | Armory stand | P0 | Wood board 8×6×2. This is the live roll stand. The onboarding doc calls it the Roll Shrine. One mesh, either name. |
| `waterfall` | Waterfall | P0 | A sheet of water and a lip. Clear, not red. |
| `foliage_kit` | Foliage kit | P0 | Repeatable trees and bushes for the Alive folder. Dark green. No unique hero tree. |
| `rock_kit` | Rock kit | P0 | Repeatable plaza rocks, including the south floater. Slate. Most do not collide. |
| `court_ring` | Court ring | P0 | A flat ring in the court floor. Stone. No glow. |

## Props

| id | name | priority | visual note |
|---|---|---|---|
| `chest` | Chest | P0 | One mesh, recolored per tier. Not built yet (`ChestConfig.luau:136`). Common through Mythic. Secret is not a chest tier. No gore latch. |
| `next_pad` | NEXT pad | P0 | Neon pad in a crawl room, sign NEXT. A floor piece, not a character. |
| `room_thicket` | Choked Thicket dressing | P1 | Tight vines, dark green. Rootvault room `thicket`. |
| `room_canopy` | Spore Canopy dressing | P1 | Hanging pale caps, violet dust. Room `canopy`. Spores, not blood. |
| `room_den` | Brute Den dressing | P1 | Root walls, packed earth. Room `den`. |
| `room_heart` | Gnarl's Heart dressing | P1 | A dark green chamber and an amber knot. Room `heart`. |
| `pedestal_warden` | Warden pedestal | P1 | Not built. A stone stand and a thorn shield shape. Green. Onboarding asks for five pedestals (`Onboarding.luau:17`). |
| `pedestal_tidecaller` | Tidecaller pedestal | P1 | Not built. A stone stand and a still teal basin. |
| `pedestal_forgeborn` | Forgeborn pedestal | P1 | Not built. A stone stand and a caged coal. Orange, small. |
| `pedestal_frostblade` | Frostblade pedestal | P1 | Not built. A stone stand and a pale ice blade shape. No drip. |
| `pedestal_voidcaster` | Voidcaster pedestal | P1 | Not built. A stone stand and a violet crack. No face in the stone. |
| `bent_waystone` | The Bent Waystone | P1 | Far Glade. Tilted gray stone, one dull amber crack, soft pulse up close. |
| `mireoak_bowl` | Mireoak's Bowl | P1 | Far Glade. Round mud bowl, root walls, soft amber in the cracks. |
| `thorn_arch` | Thorn Arch | P1 | Far Glade. Two bent trunks, a dark green thorn lintel. No glow. |
| `saltglass_arch` | The Saltglass Arch | P2 | Saltglass Strand. White salt crystal arch, teal light through it, steady pale glow. Not the hub's realm arch. |
| `gull_shelf` | Gull Shelf | P2 | A flat white rock over teal water. Gull-gray stains. No glow. |
| `bell_pool` | Bell Pool | P2 | A round tide pool, cream foam, one soft bell glow under the water. |
| `pearl_stair` | The Pearl Stair | P2 | Wide cream-pearl steps into dark blue. Steady pale edge glow. |
| `brinecrown_trench` | Brinecrown Trench | P2 | A deep blue cut. Gold-blue glints in the walls. No beam. |
| `lamp_orchard` | Lamp Orchard | P2 | Tall stalks, blue-white lamp bulbs. Soft lamp glow. No fire. |
| `cool_vent` | The Cool Vent | P2 | A blue-white steam crack in black rock. Bright cool glow. The safe color. |
| `cinder_chair` | The Cinder Chair | P2 | A throne-shaped slag outcrop. One orange crystal in the back. |
| `slag_bridge` | Slag Bridge | P2 | Cooled black slag over a crack. Orange seams. Steady seam glow. |
| `still_fang` | The Still Fang | P2 | A crystal fang in the ice, taller than a player. Strong cold glow. Crystal, not bone. |
| `pane_run` | Pane Strider's Run | P2 | A long ice road of cracked clear panes. Blue edge glow. |
| `pale_flame` | The Pale Flame | P2 | An ice bowl and a pale blue flame that does not melt the bowl. |
| `hollow_ring` | The Hollow Ring | P2 | A gray stone ring, violet inner edge. Steady rim glow. |
| `regent_step` | Regent's Step | P2 | Gray stairs that fade into violet mist. Soft violet glow. No carved faces. |
| `unfinished_bell` | The Unfinished Bell | P2 | A gray glass bell with one gap. A faint violet crack. The glow does not light the stair. |

Door choices, the odds list, and the action bar are UI. They are not props.

## Weapons

Live rows are `ItemBases.luau`. The look is suggested from the name and the realm, because those rows have no visual note. Batch 1 prompts are in `docs/art/model_prompts_weapons.md`. Batch 2 looks are the visual notes in `docs/content/weapons_batch2.md`.

### Live catalog

| id | name | type | rarity | priority | suggested look |
|---|---|---|---|---|---|
| `iron_sword` | Iron Sword | sword | Common | P0 | Straight dull iron, pine grip, no glow. |
| `iron_greatsword` | Iron Greatsword | greatsword | Common | P0 | Wide dull iron slab, pine grip, no glow. |
| `iron_bow` | Iron Bow | bow | Common | P0 | Plain shortbow, iron tips, hemp string, no glow. |
| `iron_staff` | Iron Staff | staff | Common | P0 | Straight staff, pine shaft, iron cap, no glow. |
| `iron_dagger` | Iron Dagger | dagger | Common | P0 | Short dull iron, pine grip, no glow. |
| `iron_hammer` | Iron Hammer | hammer | Common | P0 | Block iron head, pine haft, no glow. |
| `vinewood_sword` | Vinewood Sword | sword | Common | P0 | Straight sword, pale vine wood, no glow. |
| `briar_bow` | Briar Bow | bow | Common | P0 | Short bow of briar wood, no glow. |
| `sapling_staff` | Sapling Staff | staff | Common | P0 | Thin living sapling, no glow. |
| `thorn_dagger` | Thorn Dagger | dagger | Common | P0 | A straight thorn, brown wrap, no glow. |
| `root_mallet` | Root Mallet | hammer | Common | P0 | Root-knot head, short haft, no glow. |
| `thornbound_blade` | Thornbound Blade | sword | Rare | P1 | Straight blade bound in green thorn, steady green seam. |
| `fernblade` | Fernblade | sword | Uncommon | P1 | Leaf-thin sword, fern green, soft edge glow. |
| `canopy_bow` | Canopy Bow | bow | Uncommon | P1 | Bow of canopy limbs, soft green string. |
| `wildgrowth_staff` | Wildgrowth Staff | staff | Uncommon | P1 | Staff with a living crook, soft green tip. |
| `bramble_fang` | Bramble Fang | dagger | Uncommon | P1 | Curved bramble fang, soft green. |
| `beastbone_hammer` | Beastbone Hammer | hammer | Uncommon | P1 | Pale bone head, root haft, soft amber seam. Bone as stone, not gore. |
| `hartseeker` | Hartseeker | sword | Rare | P1 | Straight hunter's sword, dark wood and steel, steady green fuller. |
| `galevine_bow` | Galevine Bow | bow | Rare | P1 | Vine recurve, steady green glow on the limbs. |
| `mycelium_staff` | Mycelium Staff | staff | Rare | P1 | Pale staff, soft violet caps, steady cap glow. |
| `nightbriar` | Nightbriar | dagger | Rare | P1 | Dark curved briar, steady violet edge. |
| `antlerbrand` | Antlerbrand | sword | Legendary | P1 | A sword like a pale antler, strong green-gold trail. |
| `worldroot_staff` | Worldroot Staff | staff | Legendary | P1 | Thick world-root staff, strong amber core. |
| `green_tyrant` | The Green Tyrant | hammer | Mythic | P1 | Huge green hammer, prism sap in the head, room-wide glow. |
| `bloomheart_bow` | Bloomheart Bow | bow | Mythic | P1 | Bow around one bloom heart, prism green, room-wide glow. |
| `unnamed_grove` | The Unnamed Grove | staff | Secret | P2 | A plain staff until you are close. One bud that is not a flower. No room light. |
| `driftwood_saber` | Driftwood Saber | sword | Common | P2 | Curved driftwood, salt film, no glow. |
| `tideglass_dagger` | Tideglass Dagger | dagger | Uncommon | P2 | Small tide-glass blade, soft teal. |
| `kelpstrand_bow` | Kelpstrand Bow | bow | Rare | P2 | Kelp-strand bow, steady teal. |
| `abyssal_staff` | Abyssal Staff | staff | Legendary | P2 | Deep blue staff, strong tide glow. |
| `leviathan_mallet` | Leviathan Mallet | hammer | Mythic | P2 | Heavy tide hammer, prism teal, room-wide glow. |
| `drowned_name` | The Drowned Name | sword | Secret | P2 | A salt-white saber with one letter missing from the fuller. No room light. |
| `cinder_maul` | Cinder Maul | hammer | Common | P2 | Squat charcoal maul, no glow. |
| `soot_dagger` | Soot Dagger | dagger | Uncommon | P2 | Soot-black dagger, soft orange nick. |
| `kiln_bow` | Kiln Bow | bow | Rare | P2 | Black bow, steady orange string. |
| `sunhammer` | Sunhammer | hammer | Legendary | P2 | Heavy hammer, strong sun-orange core. |
| `dragonkiln_staff` | Dragonkiln Staff | staff | Mythic | P2 | Tall kiln staff, caged prism coal. Not a dragon body. |
| `unquenched` | The Unquenched | sword | Secret | P2 | A dark blade with one coal that will not go out. The coal is small. No room light. |
| `rimewood_sword` | Rimewood Sword | sword | Common | P2 | Pale wood sword, frost film, no glow. |
| `hourglass_dagger` | Hourglass Dagger | dagger | Uncommon | P2 | Glass dagger, one stuck grain, soft blue. |
| `snowblind_bow` | Snowblind Bow | bow | Rare | P2 | White bow, steady pale glow. |
| `glacial_staff` | Glacial Staff | staff | Legendary | P2 | Tall ice staff, strong blue core. |
| `minute_mallet` | The Minute Mallet | hammer | Mythic | P2 | Ice mallet, prism blue cracks, room-wide cold glow. |
| `unthawed` | The Unthawed | sword | Secret | P2 | A frost sword with one drop that never falls. No room light. |
| `null_shard` | Null Shard | dagger | Common | P2 | A gray shard dagger, no glow. |
| `prism_bow` | Prism Bow | bow | Uncommon | P2 | Small clear bow, soft prism nick. |
| `rift_staff` | Rift Staff | staff | Rare | P2 | Gray staff, steady violet seam. |
| `spectrum_hammer` | Spectrum Hammer | hammer | Legendary | P2 | Heavy hammer, strong prism band. |
| `last_color` | The Last Color | sword | Mythic | P2 | A sword that keeps one last color on the edge. Room-wide prism. |
| `unmaking` | Unmaking | staff | Secret | P2 | A staff with a gap where the head should be. The gap is the detail. No room light. |

### Batch 1

All P1. Prompts, colors, and triangle budgets are in `docs/art/model_prompts_weapons.md`. Model the five Commons before the Mythics.

| id | name | type | rarity |
|---|---|---|---|
| `trail_cleaver` | Trail Cleaver | sword | Common |
| `pocket_thorn` | Pocket Thorn | dagger | Common |
| `camp_mallet` | Camp Mallet | hammer | Common |
| `lantern_crook` | Lantern Crook | staff | Common |
| `haven_shortbow` | Haven Shortbow | bow | Common |
| `mossedge` | Mossedge | sword | Uncommon |
| `sporekiss` | Sporekiss | dagger | Uncommon |
| `barkfall` | Barkfall | hammer | Uncommon |
| `dewspire` | Dewspire | staff | Uncommon |
| `vinewhisper` | Vinewhisper | bow | Uncommon |
| `brine_saber` | Brine Saber | sword | Rare |
| `pearl_stiletto` | Pearl Stiletto | dagger | Rare |
| `tidebreaker` | Tidebreaker | hammer | Rare |
| `choir_rod` | Choir Rod | staff | Rare |
| `reef_recurve` | Reef Recurve | bow | Rare |
| `emberbrand` | Emberbrand | sword | Epic |
| `spark_fang` | Spark Fang | dagger | Epic |
| `anvilheart` | Anvilheart | hammer | Epic |
| `coalspire` | Coalspire | staff | Epic |
| `heatstring` | Heatstring | bow | Epic |
| `pale_oath` | Pale Oath | sword | Legendary |
| `second_frost` | Second Frost | dagger | Legendary |
| `winter_bell` | Winter Bell | hammer | Legendary |
| `stillglass_spire` | Stillglass Spire | staff | Legendary |
| `white_gale` | White Gale | bow | Legendary |
| `prism_edge` | Prism Edge | sword | Mythic |
| `unlit_needle` | Unlit Needle | dagger | Mythic |
| `riftcrown` | Riftcrown | hammer | Mythic |
| `last_verse` | Last Verse | staff | Mythic |
| `colorless_draw` | Colorless Draw | bow | Mythic |

### Batch 2 and Heartshard

Open-world batch is P2. The six Heartshard weapons are P1. They are the Heartwood prizes. Looks stay the visual notes in `docs/content/weapons_batch2.md`.

| id | name | type | rarity | priority |
|---|---|---|---|---|
| `yard_sword` | Yard Sword | sword | Common | P2 |
| `fence_bow` | Fence Bow | bow | Common | P2 |
| `sap_needle` | Sap Needle | dagger | Uncommon | P2 |
| `grove_switch` | Grove Switch | staff | Uncommon | P2 |
| `stump_maul` | Stump Maul | hammer | Uncommon | P2 |
| `river_cleaver` | River Cleaver | greatsword | Rare | P2 |
| `saltbrand` | Saltbrand | sword | Rare | P2 |
| `gull_recurve` | Gull Recurve | bow | Rare | P2 |
| `ink_fang` | Ink Fang | dagger | Rare | P2 |
| `amber_edge` | Amber Edge | sword | Epic | P2 |
| `ironroot_slab` | Ironroot Slab | greatsword | Epic | P2 |
| `nightlatch` | Nightlatch | dagger | Epic | P2 |
| `treant_maul` | Treant Maul | hammer | Epic | P2 |
| `featherdraw` | Featherdraw | bow | Epic | P2 |
| `ambercoil` | Ambercoil | staff | Epic | P2 |
| `moonbranch` | Moonbranch | bow | Epic | P2 |
| `seedspine` | Seedspine | sword | Epic | P2 |
| `frostspine` | Frostspine | sword | Legendary | P2 |
| `veilcleaver` | Veilcleaver | greatsword | Legendary | P2 |
| `glass_whisper` | Glass Whisper | dagger | Legendary | P2 |
| `boreal_maul` | Boreal Maul | hammer | Legendary | P2 |
| `aurora_longbow` | Aurora Longbow | bow | Legendary | P2 |
| `clockglass_staff` | Clockglass Staff | staff | Legendary | P2 |
| `snowthread` | Snowthread | bow | Legendary | P2 |
| `rime_coil` | Rime Coil | staff | Legendary | P2 |
| `evenfall` | Evenfall | sword | Mythic | P2 |
| `riftcleaver` | Riftcleaver | greatsword | Mythic | P2 |
| `unspoken` | Unspoken | dagger | Mythic | P2 |
| `prismfall` | Prismfall | hammer | Mythic | P2 |
| `voidlace` | Voidlace | bow | Mythic | P2 |
| `heartshard_twinblade` | Twinheart Blade | sword | Epic | P1 |
| `heartshard_briarneedle` | Briarheart Needle | dagger | Epic | P1 |
| `heartshard_sapspire` | Sapwell Spire | staff | Epic | P1 |
| `heartshard_galebow` | Galecrown Bow | bow | Epic | P1 |
| `heartshard_gnarlmaul` | Gnarlheart Maul | hammer | Epic | P1 |
| `heartshard_seasonheart` | Seasonheart | greatsword | Legendary | P1 |

## Pets

Live hatch rows are `Pets.SPECIES`. Catalog rows are `ItemBases` pets. `fern_stag` is in both. One mesh. Batch 1 prompts are in `docs/art/model_prompts_pets.md`.

`shardjaw`, `thorn_lantern`, and `glass_kestrel` are the starter shards. Kevin's hold is Shardjaw. Do not mint one in this list. The starter pitch lists all three as Common. Live rows are Shardjaw Common, Thorn Lantern Uncommon, and Glass Kestrel Rare (`PetRoster.luau:22-42`, `ItemBases.luau:282-284`). Build those live rarities. Glass Kestrel's edge glow is steady, not a dull Common glint.

`moss_hare` and `acorn_newt` stay in the catalog. Kevin rejected them as the starter. Priority P2. Do not use them on a thumbnail.

### Hatch roster

Suggested looks. These rows have no visual note in `Pets.luau`.

| id | name | rarity | priority | suggested look |
|---|---|---|---|---|
| `ember_fox` | Ember Fox | Common | P0 | Small fox, charcoal fur, dull orange ears, no smile, no glow. |
| `root_mole` | Root Mole | Common | P0 | Stocky soil mole. Not Copper Mole. No glow. |
| `mossback` | Mossback Turtle | Uncommon | P0 | Low turtle, moss shell. Not Shelf Turtle. Soft rim. |
| `tide_sprite` | Tide Sprite | Uncommon | P0 | Small teal wisp, no face, soft ribbon glow. |
| `void_moth` | Void Moth | Rare | P0 | Dark moth, one violet eye. Not Lumen Moth. |
| `fern_stag` | Fern Stag | Rare | P0 | Lean stag, fern antlers, soft green. Not Dewfont Hart. |
| `pollen_wisp` | Pollen Wisp | Epic | P0 | Pale gold dust, no face, bright dust. |
| `bark_owl` | Bark Owl | Epic | P0 | Owl of bark plates, amber eyes. Not Rune Owl. |

### Catalog pets

| id | name | rarity | priority | suggested look |
|---|---|---|---|---|
| `shardjaw` | Shardjaw | Common | P0 | Low angular beast, gray shard plates, a jaw of broken crystal, dull green cracks. No glow. Not a pup. |
| `thorn_lantern` | Thorn Lantern | Uncommon | P0 | A walking lantern of black thorns and iron, one dull amber pane. No flame jet. |
| `glass_kestrel` | Glass Kestrel | Rare | P0 | Sharp glass bird, slate body, one red-amber glass edge, steady edge glow. Not a finch. |
| `briar_pup` | Briar Pup | Uncommon | P1 | A briar hound, not a round pup. Twig legs, soft green eyes. |
| `pollen_moth` | Pollen Moth | Uncommon | P1 | Small cream moth, soft pollen dust. Not Lumen Moth. |
| `brook_otter` | Brook Otter | Rare | P1 | Low otter, wet brown, a steady teal whisker glow. |
| `vine_lynx` | Vine Lynx | Epic | P1 | Lean lynx of vines. Not Thorn Lynx. Bright leaf eyes. |
| `myco_fox` | Myco Fox | Epic | P1 | Fox shape in pale caps, bright violet gills. Not Ember Fox. |
| `antler_hart` | Antler Hart | Legendary | P1 | Tall hart, wood antlers, strong amber glow. |
| `dawnbloom_wolf` | Dawnbloom Wolf | Legendary | P1 | Wolf, pale gold bloom along the back, strong warm glow. |
| `thorn_hydra` | Thorn Hydra | Mythic | P1 | Three thorn heads, one body, prism green. Not Thorn Lynx. No gore. |
| `grove_phoenix` | Grove Phoenix | Mythic | P1 | A bird of leaves and ember, prism green and gold. Not a real-world phoenix costume. |
| `sleeping_dryad` | The Sleeping Dryad | Secret | P2 | A small wooden figure, eyes closed, one bud. No room light. |
| `moss_hare` | Moss Hare | Common | P2 | Mossy hare. Catalog only. Not the starter. Not Bramble Hare. |
| `acorn_newt` | Acorn Newt | Common | P2 | Small newt with an acorn plate. Catalog only. Not the starter. Not Lily Newt. |
| `tide_skipper` | Tide Skipper | Common | P2 | Small tide crab, pale shell, no glow. |
| `reef_pup` | Reef Pup | Uncommon | P2 | Reef-stone hound, soft teal. Not a pup face. |
| `lantern_jelly` | Lantern Jelly | Rare | P2 | Cream bell, teal ribbons, steady lamp glow. |
| `abyss_eel` | Abyss Eel | Epic | P2 | Long deep-blue eel, bright lamp on the chin. |
| `moonwhale_calf` | Moonwhale Calf | Legendary | P2 | Small whale shape, strong pale moon glow. A follower, not a mount. |
| `storm_kraken` | Storm Kraken | Mythic | P2 | Compact kraken, prism teal arms. No ship. No gore. |
| `quiet_tide` | The Quiet Tide | Secret | P2 | A still ribbon of water with one pearl that does not roll. No room light. |
| `coal_newt` | Coal Newt | Common | P2 | Charcoal newt, no glow. |
| `cinder_whelp` | Cinder Whelp | Uncommon | P2 | Small cinder beast, soft orange cracks. Not a dragon costume. |
| `forge_hound` | Forge Hound | Rare | P2 | Stocky soot hound, steady orange nose. Not Shardjaw. |
| `magma_salamander` | Magma Salamander | Epic | P2 | Low salamander, bright orange seams. |
| `ash_phoenix` | Ash Phoenix | Legendary | P2 | Ash-gray bird, strong orange crest. |
| `kiln_tyrant` | Kiln Tyrant | Mythic | P2 | Heavy kiln beast, prism coal core. |
| `last_ember` | The Last Ember | Secret | P2 | A dark coal with one awake spark. No room light. |
| `snow_hare` | Snow Hare | Common | P2 | White hare, frost film, no glow. Not Moss Hare. |
| `frost_pup` | Frost Pup | Uncommon | P2 | Frost hound, soft blue. Not a pup face. |
| `clockwork_owl` | Clockwork Owl | Rare | P2 | Owl of pale gears and ice, steady blue eye. Gears are wood and crystal. |
| `glacier_elk` | Glacier Elk | Epic | P2 | Elk, clear ice antlers, bright cold glow. |
| `aeon_wolf` | Aeon Wolf | Legendary | P2 | Tall wolf, strong blue-white mane. |
| `white_hour` | The White Hour | Mythic | P2 | A white beast with a frozen clock-face mark. Prism ice. The face is a mark, not a person's face. |
| `paused_hart` | The Paused Hart | Secret | P2 | A hart mid-step, one hoof that never lands. No room light. |
| `shade_mote` | Shade Mote | Common | P2 | A gray speck with a body, no glow. |
| `prism_moth` | Prism Moth | Uncommon | P2 | Small clear moth, soft prism dust. |
| `rift_hound` | Rift Hound | Rare | P2 | Gray hound, steady violet seam. Not Shardjaw. |
| `void_lynx` | Void Lynx | Epic | P2 | Lean gray lynx, bright violet eyes. |
| `spectrum_wyrm` | Spectrum Wyrm | Legendary | P2 | Short wyrm, strong prism scales. A follower, not a mount. |
| `uncolor` | The Uncolor | Mythic | P2 | A creature whose coat is the missing color, prism edge, room-wide. |
| `nameless_rift` | Nameless | Secret | P2 | A rift pet with no face and one unfinished edge. No room light. |

### Batch 1

All P1. Full prompts are in `docs/art/model_prompts_pets.md`.

| id | name | rarity | role |
|---|---|---|---|
| `cinder_cricket` | Cinder Cricket | Common | Striker |
| `pebble_toad` | Pebble Toad | Common | Guardian |
| `dewdrop_finch` | Dewdrop Finch | Common | Mender |
| `acorn_weevil` | Acorn Weevil | Common | Gatherer |
| `spore_midge` | Spore Midge | Uncommon | Hexer |
| `bramble_hare` | Bramble Hare | Uncommon | Striker |
| `shelf_turtle` | Shelf Turtle | Uncommon | Guardian |
| `lily_newt` | Lily Newt | Uncommon | Mender |
| `truffle_hound` | Truffle Hound | Rare | Gatherer |
| `dusk_bat` | Dusk Bat | Rare | Hexer |
| `thorn_lynx` | Thorn Lynx | Rare | Striker |
| `ironbark_ram` | Ironbark Ram | Rare | Guardian |
| `lumen_moth` | Lumen Moth | Epic | Mender |
| `copper_mole` | Copper Mole | Epic | Gatherer |
| `rune_owl` | Rune Owl | Epic | Hexer |
| `leafmane_wolf` | Leafmane Wolf | Legendary | Striker |
| `canopy_bear` | Canopy Bear | Legendary | Guardian |
| `dewfont_hart` | Dewfont Hart | Legendary | Mender |
| `nightcrystal_stag` | Nightcrystal Stag | Mythic | Hexer |
| `geode_sovereign` | Geode Sovereign | Mythic | Gatherer |

## Armor

Live pieces are the `armor` rows in `ItemBases.luau`. Batch 1 looks are `docs/content/armor_batch1.md`. Slot order is helm, chest, legs, boots. These are looks. They are not relic sets.

| id | name | slot | rarity | priority | suggested look |
|---|---|---|---|---|---|
| `woven_bark_vest` | Woven Bark Vest | chest | Common | P0 | Woven bark, olive, no glow. The live common chest. |
| `living_bark_cuirass` | Living Bark Cuirass | chest | Rare | P1 | Living bark plates, steady green seams. |
| `grovewarden_hood` | Grovewarden Hood | helm | Epic | P1 | Deep hood, bright grove-green edge. |
| `grovewarden_vestments` | Grovewarden Vestments | chest | Epic | P1 | Long vestments, bright moss seams. |
| `grovewarden_greaves` | Grovewarden Greaves | legs | Epic | P1 | Bark greaves, bright green line. |
| `grovewarden_wraps` | Grovewarden Wraps | boots | Epic | P1 | Cloth wraps, bright toe glow. |
| `brineplate_cuirass` | Brineplate Cuirass | chest | Epic | P2 | Coral and salt chest, bright teal. |
| `slagplate_cuirass` | Slagplate Cuirass | chest | Epic | P2 | Dark iron chest, bright orange cracks. |
| `chronoplate` | Chronoplate | chest | Epic | P2 | Pale plate, bright blue seam, one stuck gear of crystal. |
| `voidplate` | Voidplate | chest | Epic | P2 | Gray chest, bright violet seam. |

Batch 1. Waycloth and Gladecloth are P1. The other four looks are P2.

| id | name | slot | rarity | priority |
|---|---|---|---|---|
| `waycloth_cap` | Waycloth Cap | helm | Common | P1 |
| `waycloth_tunic` | Waycloth Tunic | chest | Common | P1 |
| `waycloth_trousers` | Waycloth Trousers | legs | Common | P1 |
| `waycloth_shoes` | Waycloth Shoes | boots | Common | P1 |
| `gladecloth_hood` | Gladecloth Hood | helm | Uncommon | P1 |
| `gladecloth_vest` | Gladecloth Vest | chest | Uncommon | P1 |
| `gladecloth_leggings` | Gladecloth Leggings | legs | Uncommon | P1 |
| `gladecloth_boots` | Gladecloth Boots | boots | Uncommon | P1 |
| `coralmail_helm` | Coralmail Helm | helm | Rare | P2 |
| `coralmail_hauberk` | Coralmail Hauberk | chest | Rare | P2 |
| `coralmail_leggings` | Coralmail Leggings | legs | Rare | P2 |
| `coralmail_waders` | Coralmail Waders | boots | Rare | P2 |
| `cinderplate_helm` | Cinderplate Helm | helm | Epic | P2 |
| `cinderplate_cuirass` | Cinderplate Cuirass | chest | Epic | P2 |
| `cinderplate_leggings` | Cinderplate Leggings | legs | Epic | P2 |
| `cinderplate_sabatons` | Cinderplate Sabatons | boots | Epic | P2 |
| `paleveil_hood` | Paleveil Hood | helm | Legendary | P2 |
| `paleveil_surcoat` | Paleveil Surcoat | chest | Legendary | P2 |
| `paleveil_leggings` | Paleveil Leggings | legs | Legendary | P2 |
| `paleveil_boots` | Paleveil Boots | boots | Legendary | P2 |
| `prismrift_visor` | Prismrift Visor | helm | Mythic | P2 |
| `prismrift_carapace` | Prismrift Carapace | chest | Mythic | P2 |
| `prismrift_leggings` | Prismrift Leggings | legs | Mythic | P2 |
| `prismrift_soles` | Prismrift Soles | boots | Mythic | P2 |

## Enemies

Rootvault uses the live block colors in `Dungeons.ENEMIES`. Field rows use the visual notes in `docs/content/enemies.md`. Far Glade is P1. The other zones are P2.

| id | name | priority | visual note |
|---|---|---|---|
| `vine_crawler` | Vine Crawler | P0 | Low crawler, green `(72, 140, 74)`, about 3×2×4 studs. |
| `spore_bat` | Spore Bat | P0 | Small bat, violet `(156, 96, 210)`, hovers. |
| `root_brute` | Root Brute | P0 | Heavy root body, brown `(122, 84, 52)`, about 5×6×4 studs. |
| `moss_crawler` | Moss Crawler | P0 | Wide crawler, moss green `(86, 150, 78)`. |
| `thorn_sprite` | Thorn Sprite | P0 | Small hovering thorn, pale green `(170, 255, 176)`. Not a pet. |
| `mud_tusk` | Mud Tusk | P1 | Low boar, mud-brown, dull root tusks, no glow. |
| `hedge_lurker` | Hedge Lurker | P1 | Crouched twig cat, dark green, a soft eye glint. |
| `seed_flinger` | Seed Flinger | P1 | Round plant back, olive, a sack of brown pods. |
| `sap_mouth` | Sap Mouth | P1 | Short stump, a honey sap lamp in a wood knot. The lamp is sap, not a wound. |
| `mite_cloud` | Mite Cloud | P1 | A ball of tiny leaf mites, yellow-green, no single body. |
| `salt_pincher` | Salt Pincher | P2 | Wide crab, pale salt, teal shell edge, soft rim. |
| `gull_ray` | Gull Ray | P2 | Flat ray, white and gull-gray wings. |
| `brine_tosser` | Brine Tosser | P2 | Hermit crab, white salt shell, a gray throwing arm. |
| `tide_bell` | Tide Bell | P2 | Floating bell jelly, cream bell, teal ribbons. |
| `foam_swarm` | Foam Swarm | P2 | A pile of tiny foam crabs, white and pale teal. |
| `trench_jaw` | Trench Jaw | P2 | Long deep-blue fish, a round chin lamp. |
| `dart_fin` | Dart Fin | P2 | Thin silver-blue fish, one long fin. |
| `pressure_wisp` | Pressure Wisp | P2 | Small deep-teal wisp, one cream pearl core. |
| `lamp_fry` | Lamp Fry | P2 | A school of tiny blue-white lamp fish. |
| `pearl_clutch` | Pearl Clutch | P2 | Tiny pearl crabs, cream shells. |
| `coal_runt` | Coal Runt | P2 | Small slag beast, charcoal, orange cracks. |
| `slag_fist` | Slag Fist | P2 | Bulky golem, one oversized fist, no face. |
| `ore_slinger` | Ore Slinger | P2 | Stooped rock thrower, a sling of cinder ore. |
| `ember_vent` | Ember Vent | P2 | Cracked rock, one orange vent. Not a dragon mouth. |
| `spark_swarm` | Spark Swarm | P2 | A cloud of tiny orange sparks. |
| `hoar_prowler` | Hoar Prowler | P2 | Lean ice beast, blue-white shards, short frost trail. |
| `frost_spitter` | Frost Spitter | P2 | Low pale lizard, a blue throat sac. |
| `pane_tosser` | Pane Tosser | P2 | Crouched ice figure, one clear pane in its hands. |
| `glaze_caster` | Glaze Caster | P2 | Floating six-sided ice crystal, strong cold glow. |
| `chip_swarm` | Chip Swarm | P2 | A whirl of tiny ice chips, no body. |
| `void_husk` | Void Husk | P2 | An empty coat shape, mirrorless gray, violet rim, no face. |
| `dust_flinger` | Dust Flinger | P2 | A floating mitt of void dust. |
| `core_caster` | Core Caster | P2 | A floating core shard, a bright hole of light. The hole is light, not a wound. |
| `seam_caster` | Seam Caster | P2 | A floating violet crack. |
| `glass_mites` | Glass Mites | P2 | Tiny gray-violet glass specks, no single body. |

## Bosses

Heartwood's four wings currently reuse `grandmother_gnarl` (`Dungeons.luau:372-375`). They still need their own meshes. World bosses use `docs/content/bosses.md`. Daily Gnarl stays Grandmother Gnarl.

| id | name | priority | visual note |
|---|---|---|---|
| `grandmother_gnarl` | Grandmother Gnarl | P0 | Walking tree, dark green `(36, 92, 58)`, about 8×9×7 studs. Amber knot. No gore. |
| `twins` | Thornwarden Twins | P1 | Two bramble figures, one green and one violet, amber where they meet. |
| `sapwell` | Mother Sapwell | P1 | Twisted roots, a honey-amber core. Sap is golden, not red. |
| `galecrown` | Galecrown | P1 | A tree with an owl crown, moon-silver and leaf-green, feather motes. |
| `awakened` | Grandmother Gnarl Awakened | P1 | The same tree, taller, an amber heart. Glow cycles spring green, summer gold, autumn amber, winter blue. |
| `mireoak` | Mireoak | P1 | Wide walking oak, mud-brown bark, short root legs, one amber knot, calm amber eye-lights. |
| `glasshorn` | Glasshorn | P2 | Giant low tortoise, white salt crust, one clear horn, teal rim. |
| `brinecrown` | Brinecrown | P2 | Long whale-eel, deep blue, one gold-blue brow scale, soft lamp spots. No blood. |
| `slagwalker` | Slagwalker | P2 | Bulky walking heap, charcoal, orange cracks, no face. |
| `cinderseat` | Cinderseat | P2 | Huge seated slag figure, a cinder crown, one orange crystal in the chest. |
| `pane_strider` | Pane Strider | P2 | Tall ice strider, clear pane antlers, strong blue eye glow, short frost trail. |
| `stillfang` | Stillfang | P2 | Long low ice serpent, one oversized pale crystal fang. Crystal, not a bloody tooth. |
| `hollow_regent` | Hollow Regent | P2 | Tall mirrorless gray figure, no face, violet rim, a bright hole of light in the chest. |

## Counts

| group | rows | P0 | P1 | P2 |
|---|---|---|---|---|
| Haven | 19 | 19 | 0 | 0 |
| Props | 29 | 2 | 12 | 15 |
| Weapons, live | 50 | 11 | 14 | 25 |
| Weapons, batch 1 | 30 | 0 | 30 | 0 |
| Weapons, batch 2 and Heartshard | 36 | 0 | 6 | 30 |
| Pets, hatch | 8 | 8 | 0 | 0 |
| Pets, catalog | 43 | 3 | 9 | 31 |
| Pets, batch 1 | 20 | 0 | 20 | 0 |
| Armor, live | 10 | 1 | 5 | 4 |
| Armor, batch 1 | 24 | 0 | 8 | 16 |
| Enemies | 35 | 5 | 5 | 25 |
| Bosses | 13 | 1 | 5 | 7 |
| Total | 317 | 50 | 114 | 153 |

`fern_stag` is counted once, in the hatch roster. The realm arch is one mesh. The chest is one mesh.

Flags: Choir Rod, Saltglass, and the Heartshard names stay this game's. No outside creature or weapon names.
