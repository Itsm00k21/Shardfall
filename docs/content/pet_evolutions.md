# Pet evolutions

G-004. Eight evolution lines, three stages each, for a later `PetEvolution.STEPS` pass and the 3D art pass.

Rules match `PetEvolution.luau` and `docs/design/shardfall_pets.md`. A companion evolves at level 25, then at level 50. It cannot skip a stage. The personal name, uid, Bond, Affinity, favorite lock, colors, journal, and personality stay. The journal gains `Evolved to <display name>`. Species id, display name (`speciesName`), ability id, and rarity change. Role is written again as the same role. Counts are suggestions. Pets are not sold for Robux.

The live Verdant chains stay as they are: Ember Fox, Mossback Turtle, and Root Mole. None of those species, or their forms, are in the tables below. Tide Sprite is the one live base included here. It has no step in `PetEvolution.STEPS` today.

Choice: Tide Sprite spends Verdant materials, like the three live chains. The other lines hatch in a later realm and spend that realm's materials. A realm with only three material ids spends two at level 25 (common and rare) and adds the boss material at level 50, count 1. `evolve` stores one count per id, so a recipe never repeats an id. Boss materials stay off the level-25 step. Personality is not on a step, so it stays.

| stays | changes |
|---|---|
| personal name, uid, Bond, Affinity, favorite, colors, journal, personality | species, display name, ability id, rarity |

| stage | level | rarity landing |
|---|---|---|
| 1, hatch | 1 | Common or Uncommon |
| 2 | 25 | Rare |
| 3 | 50 | Epic |

| id | display name | realm |
|---|---|---|
| heartwood | Heartwood | Verdant Wilds |
| verdant_bark | Verdant Bark | Verdant Wilds |
| vine | Living Vine | Verdant Wilds |
| bark | Ironbark | Verdant Wilds |
| spore | Spore Cap | Verdant Wilds |
| gnarl_seed | Gnarl's Seed | Verdant Wilds |
| coral_shard | Coral Shard | Sunken Reach |
| black_pearl | Black Pearl | Sunken Reach |
| leviathan_scale | Leviathan Crown-Scale | Sunken Reach |
| cinder_ore | Cinder Ore | Emberforge |
| molten_core | Molten Core | Emberforge |
| tyrant_heart | Tyrant's Ember Heart | Emberforge |
| frost_pelt | Frost Pelt | Frostveil |
| everfrost_gem | Everfrost Gem | Frostveil |
| matriarch_fang | Matriarch's Frozen Fang | Frostveil |
| void_dust | Void Dust | Void Rift |
| rift_eye | Rift Eye | Void Rift |
| hollow_core | Sovereign's Hollow Core | Void Rift |

## Hatch forms

Personality is the hatch default from `Pets.luau`: Brave, Playful, Lazy, Curious, Grumpy, Loyal. The ability on a live base is a suggestion. `Pets.luau` does not store one today.

| species | name | rarity | role | personality | realm | ability | ability note | visual note |
|---|---|---|---|---|---|---|---|---|
| dew_beetle | Dew Beetle | Common | Striker | Brave | Verdant Wilds | dew_jab | A quick dew bite. | Small oval beetle, dull green shell, one clear dew bead, no glow. |
| lagoon_crab | Lagoon Crab | Uncommon | Guardian | Loyal | Sunken Reach | lagoon_pinch | A pinch that guards you. | Wide low crab, teal shell, pale kelp fringe, soft rim glow. |
| tide_sprite | Tide Sprite | Uncommon | Mender | Playful | Verdant Wilds | tide_mend | Small heal. Design note already says every 8s. | Small water sprite, pale blue, soft tide glow. Already in `Pets.luau`. |
| ash_vole | Ash Vole | Common | Gatherer | Curious | Emberforge | ash_sift | Sifts a bonus material. | Small round vole, soot-gray fur, ash-white belly, no glow. |
| soot_wisp | Soot Wisp | Uncommon | Hexer | Grumpy | Emberforge | soot_dust | Dust that marks a foe. | Small floating wisp, gray soot body, one orange eye, soft dim glow. |
| rime_ram | Rime Ram | Common | Guardian | Loyal | Frostveil | rime_brace | A cold brace when you are hit. | Sturdy ram, white-gray wool, short dull horns, no glow. |
| frost_lark | Frost Lark | Uncommon | Mender | Lazy | Frostveil | frost_note | A soft heal on a note. | Small round bird, pale blue-gray feathers, soft cold glint on the beak. |
| hollow_moth | Hollow Moth | Common | Hexer | Grumpy | Void Rift | hollow_dust | Dim dust on a foe. | Small moth, dull gray wings, a dark empty spot on each wing, no glow. |

## Steps

Same fields as `PetEvolution.Step`: `from`, `level`, `species`, display name, `ability`, `role`, `rarity`, `materials`.

| from | level | species | name | ability | ability note | role | rarity | materials | visual note |
|---|---|---|---|---|---|---|---|---|---|
| dew_beetle | 25 | resin_beetle | Resin Beetle | resin_rush | A sticky charge at the target. | Striker | Rare | heartwood 4, bark 8, vine 6 | Stockier beetle, honey-brown shell plates, steady amber seams. |
| resin_beetle | 50 | amber_borer | Amber Borer | amber_horn | A horn hit that shines. | Striker | Epic | gnarl_seed 1, heartwood 8, verdant_bark 10 | Large horned beetle, dark shell under a clear amber dome, bright amber horn glow. |
| lagoon_crab | 25 | breakwater_crab | Breakwater Crab | reef_brace | A shell brace when you are hit. | Guardian | Rare | black_pearl 3, coral_shard 12 | Heavier crab, coral-pink plates on a gray shell, steady teal claw glow. |
| breakwater_crab | 50 | crownscale_crab | Crownscale Crab | crown_aegis | A bright shell over you. | Guardian | Epic | leviathan_scale 1, black_pearl 6, coral_shard 12 | Tall crab, deep blue shell, one gold-blue crown scale, bright scale glow. |
| tide_sprite | 25 | neap_sprite | Neap Sprite | neap_mend | A wider small heal. | Mender | Rare | heartwood 4, verdant_bark 6, spore 8 | Taller sprite, cream and pale blue, a pearl on the brow, steady pale glow. |
| neap_sprite | 50 | flood_sprite | Flood Sprite | flood_mend | A bright tide heal. | Mender | Epic | gnarl_seed 1, heartwood 6, vine 10 | Tall sprite, rose and deep teal, a ribbon of water, bright tide glow. |
| ash_vole | 25 | slag_vole | Slag Vole | slag_pocket | Pockets an extra material. | Gatherer | Rare | molten_core 3, cinder_ore 12 | Stocky vole, black fur with orange slag cracks, steady crack glow. |
| slag_vole | 50 | hearth_vole | Hearth Vole | hearth_vault | A brighter bonus dig. | Gatherer | Epic | tyrant_heart 1, molten_core 6, cinder_ore 10 | Plump vole, charcoal fur, a coal-bright chest pocket, bright pocket glow. |
| soot_wisp | 25 | slag_wisp | Slag Wisp | slag_mark | A hotter mark on a foe. | Hexer | Rare | molten_core 4, cinder_ore 8 | Taller wisp, cracked black glass, steady orange seams. |
| slag_wisp | 50 | kiln_wisp | Kiln Wisp | kiln_hex | A bright mark that lingers. | Hexer | Epic | tyrant_heart 1, molten_core 8, cinder_ore 8 | Tall wisp, a cage of dark iron around a coal core, bright core glow. |
| rime_ram | 25 | snowpack_ram | Snowpack Ram | snow_guard | A thicker snow guard. | Guardian | Rare | everfrost_gem 3, frost_pelt 12 | Heavy ram, packed snow on the shoulders, ice horns, steady blue horn glow. |
| snowpack_ram | 50 | everfrost_ram | Everfrost Ram | ever_aegis | A bright frost shell. | Guardian | Epic | matriarch_fang 1, everfrost_gem 6, frost_pelt 10 | Huge ram, blue-white crystal horns, bright horn glow and a short frost trail. |
| frost_lark | 25 | glaze_lark | Glaze Lark | glaze_mend | A clearer heal. | Mender | Rare | everfrost_gem 4, frost_pelt 8 | Slim bird, ice-clear wing edges, steady blue wing glow. |
| glaze_lark | 50 | veil_lark | Veil Lark | veil_song | A bright frost heal. | Mender | Epic | matriarch_fang 1, everfrost_gem 8, frost_pelt 6 | Wide-wing bird, a walking frost veil for a tail, bright white trail. |
| hollow_moth | 25 | rift_moth | Rift Moth | rift_mark | A violet mark on a foe. | Hexer | Rare | rift_eye 4, void_dust 8 | Wide moth, charcoal wings with one violet slit, steady slit glow. |
| rift_moth | 50 | voidglass_moth | Voidglass Moth | voidglass_hex | A bright void mark. | Hexer | Epic | hollow_core 1, rift_eye 8, void_dust 10 | Large moth, mirrorless gray-violet glass wings, bright violet body glow. |

| role | lines |
|---|---|
| Striker | 1 |
| Guardian | 2 |
| Mender | 2 |
| Gatherer | 1 |
| Hexer | 2 |

| realm | lines |
|---|---|
| Verdant Wilds | 2 |
| Sunken Reach | 1 |
| Emberforge | 2 |
| Frostveil | 2 |
| Void Rift | 1 |

24 forms. 16 steps. 8 lines.

Flags: Crownscale Crab is not the Leviathan Crown-Scale material. Everfrost Ram is not the Everfrost Gem. Hollow Moth is not Sovereign's Hollow Core. Hearth Vole is not Kilnheart. Veil Lark is not Veilcleaver or Veil of Leaves. Not Ash Phoenix, Void Moth, Pollen Wisp, Thorn Wisp, Prism Moth, Lumen Moth, Shade Mote, Ironbark Ram, or the live fox, turtle, and mole lines. No outside creature names.
