# Pet model prompts, batch 1

G-042. One mesh prompt for each pet in `docs/content/pets_batch1.md`. For the 3D pass. These are not the beta eight in `Pets.luau`, not the `ItemBases` catalog pets, and not the evolution forms. Do not add them to `Pets.luau`.

Shared style: dark-fantasy companion, useful before cute. Y-up. Feet or hover point at the origin. It follows a player and must not hide their torso. No gore, no smile-sticker face, no other game's creature. Neon only where the glow column says. Nameplate colors match `UiTheme.RARITY`. Mythic nameplates reuse Legendary gold (`UiTheme.luau:38-39`). Paint the body from the glow column.

Personality is the hatch default only. It does not change the mesh. Suggested passive percents stay in the content file. They are not a reason to add armor or a weapon.

Triangle counts and heights are suggested. A hover pet floats about 1 stud off the ground.

| rarity | suggested tris | height | glow |
|---|---|---|---|
| Common | 800 | 1.6 | none, or one dull glint |
| Uncommon | 1200 | 2.0 | soft |
| Rare | 1800 | 2.4 | steady |
| Epic | 2600 | 3.0 | bright |
| Legendary | 3400 | 3.6 | strong, reads in Haven |
| Mythic | 4200 | 4.2 | prism or void, reads across a room |

| id | name | rarity | role | stance | colors | glow | tris | prompt |
|---|---|---|---|---|---|---|---|---|
| `cinder_cricket` | Cinder Cricket | Common | Striker | Ground, low hop | Bark-brown, dull orange belly | none | 800 | A small oval cricket, bark-brown with a dull orange belly, no glow. Not round, not cute. |
| `pebble_toad` | Pebble Toad | Common | Guardian | Ground, wide | Pebble-gray, moss-green freckles | none | 800 | A round toad of pebble-gray stone with moss-green freckles, no glow. |
| `dewdrop_finch` | Dewdrop Finch | Common | Mender | Low hover | Olive, cream chest, one clear dew bead | faint cool glint on the bead | 800 | A tiny olive finch, cream chest, one clear dew bead with a faint cool glint. |
| `acorn_weevil` | Acorn Weevil | Common | Gatherer | Ground | Nut-brown, acorn-cap shell | none | 800 | A small oval weevil, nut-brown, an acorn-cap shell, no glow. |
| `spore_midge` | Spore Midge | Uncommon | Hexer | Hover | Violet body, soft spore puff | dim purple | 1200 | A tiny long-leg midge, violet, a soft spore puff, dim purple glow. |
| `bramble_hare` | Bramble Hare | Uncommon | Striker | Ground, lean | Twisted twigs, sap-green eyes | small ear-tip | 1200 | A lean hare built of twisted twigs, sap-green eyes, a small glow on the ear tips. |
| `shelf_turtle` | Shelf Turtle | Uncommon | Guardian | Ground, flat | Tan skin, moss and cream mushroom shell | soft rim | 1200 | A flat turtle, tan skin, a mushroom-cap shell in moss and cream, soft glow on the rim. |
| `lily_newt` | Lily Newt | Uncommon | Mender | Ground, low | Pale green, one white lily spot | soft teal along the tail | 1200 | A slim pale-green newt, one white lily spot, soft teal glow along the tail. |
| `truffle_hound` | Truffle Hound | Rare | Gatherer | Ground, stocky | Soil-brown coat, purple truffle nose | nose | 1800 | A stocky soil-brown hound with a purple truffle nose. The nose glows. Not a pup. |
| `dusk_bat` | Dusk Bat | Rare | Hexer | Hover | Charcoal wings, one violet eye | thin wing edge | 1800 | A small bat, charcoal wings, one violet eye, a thin glow on the wing edge. |
| `thorn_lynx` | Thorn Lynx | Rare | Striker | Ground, compact | Dark green stripes, thorn whiskers | bright green eyes | 1800 | A compact lynx, dark green stripes, thorn whiskers, bright green eye glow. |
| `ironbark_ram` | Ironbark Ram | Rare | Guardian | Ground, sturdy | Gray-brown wool, ironbark horns, moss beard | horn tips | 1800 | A sturdy ram, gray-brown wool, ironbark horns, a moss beard, glow on the horn tips. |
| `lumen_moth` | Lumen Moth | Epic | Mender | Hover | Pale gold wings, cream body | warm lumen dust | 2600 | A wide moth, pale gold wings, cream body, a warm lumen-dust trail. |
| `copper_mole` | Copper Mole | Epic | Gatherer | Ground, round | Dirt-brown fur, copper claws | claws | 2600 | A round dirt-brown mole with copper claws. The claws glow. |
| `rune_owl` | Rune Owl | Epic | Hexer | Perch or low hover | Charcoal feathers, faint gold runes | violet eyes | 2600 | A tall charcoal owl, faint gold rune marks, violet eye glow. |
| `leafmane_wolf` | Leafmane Wolf | Legendary | Striker | Ground, lean | Storm-gray fur, leaf-green and gold mane | strong mane | 3400 | A lean storm-gray wolf with a leaf-green and gold mane, strong mane glow. |
| `canopy_bear` | Canopy Bear | Legendary | Guardian | Ground, huge for a pet | Deep brown, living green canopy on the back | amber eyes, leaf glow | 3400 | A deep-brown bear with a living green canopy on its back, amber eyes, leaf glow. Still a follower, not a mount. |
| `dewfont_hart` | Dewfont Hart | Legendary | Mender | Ground, slim | White-green coat, water-shaped antlers | teal | 3400 | A slim white-green hart, antlers like falling water, teal glow. The antlers are water, not bone trophies. |
| `nightcrystal_stag` | Nightcrystal Stag | Mythic | Hexer | Ground, tall | Black crystal, prism cracks | void-purple chest | 4200 | A tall stag of black crystal, prism cracks in the body, void-purple glow in the chest. |
| `geode_sovereign` | Geode Sovereign | Mythic | Gatherer | Ground, heavy | Gray shell open on rainbow crystal plates | bright prism | 4200 | A heavy walking geode, gray shell open on rainbow crystal plates, bright prism glow. |

| rarity | count | roles in this batch |
|---|---|---|
| Common | 4 | Striker, Guardian, Mender, Gatherer |
| Uncommon | 4 | Hexer, Striker, Guardian, Mender |
| Rare | 4 | Gatherer, Hexer, Striker, Guardian |
| Epic | 3 | Mender, Gatherer, Hexer |
| Legendary | 3 | Striker, Guardian, Mender |
| Mythic | 2 | Hexer, Gatherer |

Each role appears four times.

Do not build these under the batch-1 names. They already have a row elsewhere.

| id | name | why it is not in this file |
|---|---|---|
| `moss_hare` | Moss Hare | Catalog Common. Kevin rejected it as cute. |
| `acorn_newt` | Acorn Newt | Catalog Common. Kevin rejected it as cute. |
| `ember_fox` | Ember Fox | Beta hatch Common. |
| `mossback` | Mossback Turtle | Beta hatch. Not Shelf Turtle. |
| `root_mole` | Root Mole | Beta hatch. Not Copper Mole. |
| `void_moth` | Void Moth | Beta hatch. Not Lumen Moth. |
| `fern_stag` | Fern Stag | Beta hatch and catalog. Not Dewfont Hart or Nightcrystal Stag. |
| `bark_owl` | Bark Owl | Beta hatch. Not Rune Owl. |
| `vine_lynx` | Vine Lynx | Catalog Epic. Not Thorn Lynx. |
| `thorn_hydra` | Thorn Hydra | Catalog Mythic. Not Thorn Lynx. |
| `shardjaw` | Shardjaw | Starter shard. Not Truffle Hound. |
| `glass_kestrel` | Glass Kestrel | Starter shard. Not Dewdrop Finch. |

Flags: Spore Midge is not Spore Mote. No outside creature names.
