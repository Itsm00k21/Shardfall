# World model prompts

G-043. One mesh prompt for each field boss in `docs/content/bosses.md` and each landmark in `docs/content/zones.md`. For the 3D pass. These are not Haven props, not Rootvault dressing, and not the Heartwood raid bosses. Do not add them to `src/`.

Shared style: dark-fantasy Roblox mesh, wood, stone, salt, slag, ice, or glass. Y-up. Feet, base, or waterline at the origin. One silhouette that reads at 40 studs for a boss and 30 studs for a landmark. No gore, no blood, no logo, no other game's creature. Neon only where the glow column says. A hole of light is light, not a wound. A crystal fang is crystal, not bone.

Triangle counts are suggested. Priority matches `docs/art/shot_list.md`: Far Glade and Mireoak are P1. The other five zones are past the beta cap and are P2.

| kind | suggested tris | glow |
|---|---|---|
| Field boss | 6500–8000 | signature part only |
| Landmark | 1400–2800 | the zone note, or none |
| First-kill charm | 450 | one small core |

## Bosses

Arenas are the landmarks below. Do not build a second copy of the arena into the boss mesh. Grandmother Gnarl, the Thornwarden Twins, Mother Sapwell, and Galecrown stay on the shot list.

| id | name | zone | priority | silhouette | colors | glow | tris | prompt |
|---|---|---|---|---|---|---|---|---|
| `mireoak` | Mireoak | Far Glade | P1 | Wide oak on short root legs | Mud-brown bark, one amber knot | soft amber eyes and knot | 6500 | A wide walking oak, mud-brown bark, short root legs, one amber knot, calm amber eye-lights, soft amber glow. |
| `glasshorn` | Glasshorn | Saltglass Strand | P2 | Giant low tortoise | White salt crust, one clear horn, teal rim | steady rim and horn | 7000 | A giant low tortoise, white salt crust, one clear horn, a teal rim, steady rim glow. The safe plates are the floor, not the shell. |
| `brinecrown` | Brinecrown | Pearl Trench | P2 | Long whale-eel | Deep blue, one gold-blue brow scale | soft lamp spots | 8000 | A long deep-blue whale-eel, one gold-blue brow scale, soft lamp spots down the side. No blood. |
| `slagwalker` | Slagwalker | Slag Marches | P2 | Bulky walking heap | Charcoal rock, orange cracks | bright cracks, blue back vents | 7000 | A bulky walking heap of charcoal rock, orange cracks, no face, bright crack glow, and blue vents on the back. |
| `cinderseat` | Cinderseat | Slag Marches | P2 | Huge seated figure | Dark iron, a cinder crown | bright orange chest crystal | 8000 | A huge seated slag figure, dark iron, a cinder crown, one orange crystal in the chest. It never stands. The crystal is a crystal, not a wound. |
| `pane_strider` | Pane Strider | Hoarfrost Expanse | P2 | Tall ice strider | Blue-white body, clear pane antlers | strong blue eyes, short frost trail | 6500 | A tall ice strider, clear pane antlers, a blue-white body, strong blue eye glow, and a short frost trail. |
| `stillfang` | Stillfang | Hoarfrost Expanse | P2 | Long low serpent | Blue-white plates, one oversized pale fang | strong cold fang | 7500 | A long low ice serpent, blue-white plates, one oversized pale crystal fang, strong cold glow. The fang is crystal, not a tooth. |
| `hollow_regent` | Hollow Regent | Rift Margin | P2 | Tall mirrorless figure | Gray, no face, violet rim | bright hole of light in the chest | 6500 | A tall mirrorless gray figure, no face, a violet rim, and a bright hole of light in the chest. The hole is light. Rim glow reads across the field. |

| zone | bosses |
|---|---|
| Far Glade | 1 |
| Saltglass Strand | 1 |
| Pearl Trench | 1 |
| Slag Marches | 2 |
| Hoarfrost Expanse | 2 |
| Rift Margin | 1 |

## Landmarks

Three props per zone. Ids match the shot list. The Saltglass Arch is not the hub realm arch.

| id | name | zone | priority | silhouette | colors | glow | tris | prompt |
|---|---|---|---|---|---|---|---|---|
| `bent_waystone` | The Bent Waystone | Far Glade | P1 | Tilted standing stone | Gray stone, one dull amber crack | soft pulse up close only | 1600 | A tilted gray waystone with one dull amber crack. No glow until the camera is close, then a soft pulse. |
| `mireoak_bowl` | Mireoak's Bowl | Far Glade | P1 | Round mud bowl | Mud, root walls, amber seams | soft amber in the cracks | 2400 | A round mud bowl with root walls and amber seeping in the cracks, soft amber glow. |
| `thorn_arch` | Thorn Arch | Far Glade | P1 | Two trunks and a lintel | Bent wood, dark green thorns | none | 1800 | Two bent trunks and a dark green thorn lintel. No glow. A gate, not a boss. |
| `saltglass_arch` | The Saltglass Arch | Saltglass Strand | P2 | Natural crystal arch | White salt crystal | steady pale, teal light through it | 2200 | A natural arch of white salt crystal, teal water light through it, steady pale glow. |
| `gull_shelf` | Gull Shelf | Saltglass Strand | P2 | Flat rock shelf | White rock, gull-gray stains | none | 1400 | A flat white rock over teal water, gull-gray stains, no glow. |
| `bell_pool` | Bell Pool | Saltglass Strand | P2 | Round tide pool | Cream foam, teal water | one soft bell under the water | 1800 | A round tide pool with cream foam and one soft bell glow under the water. |
| `pearl_stair` | The Pearl Stair | Pearl Trench | P2 | Wide steps | Cream pearl, dark blue | steady pale edge | 2600 | Wide cream-pearl steps into dark blue, a steady pale glow on the edges. |
| `brinecrown_trench` | Brinecrown Trench | Pearl Trench | P2 | Deep cut | Deep blue walls, gold-blue glints | steady glints, no beam | 2200 | A deep blue cut with gold-blue glints in the walls. Steady glints, no beam. |
| `lamp_orchard` | Lamp Orchard | Pearl Trench | P2 | Tall stalks | Blue-white lamp bulbs | soft lamp, no fire | 2400 | Tall stalks with blue-white lamp bulbs, soft lamp glow, no fire. |
| `cool_vent` | The Cool Vent | Slag Marches | P2 | Steam crack | Black rock, blue-white steam | bright cool | 1600 | A blue-white steam crack in black rock, bright cool glow. This is the safe color. |
| `cinder_chair` | The Cinder Chair | Slag Marches | P2 | Throne-shaped outcrop | Slag, one orange crystal in the back | bright crystal | 2600 | A throne-shaped slag outcrop with one orange crystal in the back, bright crystal glow. |
| `slag_bridge` | Slag Bridge | Slag Marches | P2 | Cooled bridge | Black slag, orange seams | steady seams | 2200 | Cooled black slag over a crack, orange seams, steady seam glow. |
| `still_fang` | The Still Fang | Hoarfrost Expanse | P2 | Crystal spike | Pale ice crystal, taller than a player | strong cold | 1800 | A crystal spike the shape of a fang, taller than a player, stuck in the ice, strong cold glow. Crystal, not bone. |
| `pane_run` | Pane Strider's Run | Hoarfrost Expanse | P2 | Long ice road | Cracked clear panes | blue edge | 2800 | A long ice road of cracked clear panes, blue edge glow. |
| `pale_flame` | The Pale Flame | Hoarfrost Expanse | P2 | Ice bowl | Pale blue flame in ice | strong flame, the bowl does not melt | 1800 | An ice bowl with a pale blue flame that does not melt the bowl, strong flame glow. |
| `hollow_ring` | The Hollow Ring | Rift Margin | P2 | Stone ring | Gray stone, violet inner edge | steady rim | 1600 | A gray stone ring with a violet inner edge, steady rim glow. |
| `regent_step` | Regent's Step | Rift Margin | P2 | Stairs into mist | Gray stairs, violet mist | soft violet | 2600 | Gray stairs that fade into violet mist at the top, soft violet glow, no faces carved in. |
| `unfinished_bell` | The Unfinished Bell | Rift Margin | P2 | Glass bell with one gap | Gray glass, a violet crack | faint, does not light the stair | 1800 | A gray glass bell with one gap and a faint violet crack. The glow is too weak to light the stair. |

| zone | landmarks | priority |
|---|---|---|
| Far Glade | 3 | P1 |
| Saltglass Strand | 3 | P2 |
| Pearl Trench | 3 | P2 |
| Slag Marches | 3 | P2 |
| Hoarfrost Expanse | 3 | P2 |
| Rift Margin | 3 | P2 |

## First-kill charms

These are the G-010 cosmetics. No stats. Not Robux. Bag scale, about 1 stud. Draft ids only. `grove_ribbon` is the Training Grove cosmetic and stays out of this table. `TrainingGrove.clear` refuses a caller-supplied `cosmeticId`, and the spec uses the string `mire_lamp` as that sample, so these charms use a `field_` prefix.

| id | name | boss | colors | glow | tris | prompt |
|---|---|---|---|---|---|---|
| `field_mire_lamp` | Mire Lamp | Mireoak | Amber knot, iron cage | soft amber | 450 | A small amber knot in an iron cage, soft amber glow. |
| `field_glasshorn_crest` | Glasshorn Crest | Glasshorn | Clear horn, salt-white plate | steady pale | 450 | A small clear horn on a salt-white plate, steady pale glow. |
| `field_brine_clasp` | Brine Clasp | Brinecrown | Gold-blue scale, teal pin | steady scale | 450 | A gold-blue scale on a teal pin, steady scale glow. |
| `field_slag_cloak` | Slag Cloak | Slagwalker | Short charcoal cloak, one orange seam | steady seam | 450 | A short charcoal cloak with one orange seam, steady seam glow. |
| `field_cinderseat_charm` | Cinderseat Charm | Cinderseat | Tiny orange crystal, dark iron cage | bright crystal | 450 | A tiny orange crystal in a dark iron cage, bright crystal glow. |
| `field_pane_halo` | Pane Halo | Pane Strider | Thin clear ring | soft blue edge | 450 | A thin clear ring that sits over the shoulders, soft blue edge glow. |
| `field_stillfang_pin` | Stillfang Pin | Stillfang | Tiny pale crystal fang, white pin | strong cold | 450 | A tiny pale crystal fang on a white pin, strong cold glow. Crystal, not bone. |
| `field_regent_circlet` | Regent Circlet | Hollow Regent | Thin gray ring, one violet gap | soft violet | 450 | A thin gray ring with one violet gap, soft violet glow. |

| group | rows |
|---|---|
| Bosses | 8 |
| Landmarks | 18 |
| Charms | 8 |
| Total | 34 |

Flags: Saltglass is the coast. Tideglass stays the dagger. Leviathan Crown-Scale, Tyrant's Ember Heart, Matriarch's Frozen Fang, and Sovereign's Hollow Core stay materials, not these meshes. The Drowned Choir, the Crucible, Glacier Throne, and the Hollow Crown stay raid sketches. No other game's creature or landmark name is used.
