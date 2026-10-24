# Class skills

G-008. Six skills for each of the five classes, for the combat VFX pass and a later kit draft.

`Classes.luau` already has four skills per class. Those twenty rows keep the live id, name, cooldown, resource, and note. Two concept rows per class bring each class to six. A concept is not in the module. It has no damage, heal, or shield coefficient. Ultimates are in `docs/content/class_ultimates.md`. Talents and the core passive are not skills.

Resource is the number on the skill row. Negative spends. Positive adds. `ClassService` caps the bar at 100. Voidcaster starts at 100 and spends down. The other classes start at 0. Palette triples are live from `Classes.palette`.

| class | id | role | resource | palette |
|---|---|---|---|---|
| Warden | `warden` | Tank | Bark | 92, 140, 78 |
| Tidecaller | `tidecaller` | Healer | Tide | 72, 186, 176 |
| Forgeborn | `forgeborn` | Bruiser | Heat | 220, 110, 48 |
| Frostblade | `frostblade` | Melee | Chill | 150, 210, 240 |
| Voidcaster | `voidcaster` | Ranged | Void | 120, 70, 180 |

Design accents, from `docs/design/shardfall_combat.md`, sit on top of that palette: Warden gold sap, Tidecaller pearl white, Forgeborn molten yellow and charcoal, Frostblade silver, Voidcaster magenta edges.

## Warden

Tank. Moss green, bark brown, gold sap. Slow and planted. Left unused: Deep Roots, Thornmail, Overgrowth, Guardian, Ironbark, Eternal Grove, Wildheart, Planted Taunt, Barkskin Share.

| id | name | role | cooldown | resource | note | vfx note |
|---|---|---|---|---|---|---|
| `thorn_bash` | Thorn Bash | taunt strike | 4 live | +8 live | Shield strike. Short stun. | Round shield, moss green and bark brown. A short gold thorn on impact, 6 studs live. A brown root knot on the foe's feet. No trail. |
| `rootgrasp` | Rootgrasp | root | 8 live | 0 live | Roots a circle for 2s. | A root ring, 12 studs live, bark brown, moss tips, soft gold sap. Roots hold, then sink. |
| `barkskin` | Barkskin | self shield | 12 live | -30 live | Spend Bark for 20% max HP. | Bark plates over the chest and shoulders, moss-green seams, gold sap edge, soft glow. Plates crack off and fade. |
| `vine_pull` | Vine Pull | pull | 7 live | 0 live | Yank the target in. | One thick vine from the shield, up to 16 studs live, brown-green, leaf bits, no glow. |
| `sapshield` | Sapshield | ally shield | 14 suggested | -20 suggested | A small bark plate on one ally. | One chest plate on an ally, smaller than Barkskin, moss green, gold sap rim, soft glow, then fades. |
| `rootstep` | Rootstep | step taunt | 9 suggested | 0 suggested | A short step that taunts the foe you reach. | Three root knots under the boots, bark brown, one short step, no trail. A small brown ring on the foe. |

## Tidecaller

Healer. Teal, sea-foam, pearl. Always moving. Left unused: Ebb and Flow, Riptide, Still Waters, Lifeline, Pressure, Tsunami, Deep Current, Pool Cleanse, Ebb Jump.

| id | name | role | cooldown | resource | note | vfx note |
|---|---|---|---|---|---|---|
| `tidal_bolt` | Tidal Bolt | bolt | 3 live | +8 live | Hurts a foe or tops you up. | A teal bolt, sea-foam tip, pearl glint, soft glow, 18 studs live. A heal shows as a green bubble. |
| `healing_pool` | Healing Pool | heal zone | 10 live | +10 live | A tidepool of healing. | A flat pool, 10 studs live, teal water, white foam edge, steady shimmer. |
| `bubble_ward` | Bubble Ward | shield | 9 live | +12 live | Shield and one cleanse. | A clear bubble, teal rim, pearl highlight, soft glow. One dark mote pops on the cleanse. |
| `undertow` | Undertow | wave | 8 live | 0 live | Wave that shoves foes back. | A low wave, 12 studs live, teal face, white crest, a short mist. No whirlpool. |
| `pearl_drop` | Pearl Drop | single heal | 11 suggested | +8 suggested | One pearl heals the lowest ally who steps in. | A fist-sized cracked cream pearl at knee height, steady pale glow, one green bubble on the heal. |
| `foam_step` | Foam Step | self cleanse | 7 suggested | 0 suggested | A sidestep that clears one slow on you. | A sea-foam spiral under the feet, teal and white, one soft splash, no knockback. |

## Forgeborn

Bruiser. Orange, molten yellow, charcoal. Big wind-ups. Left unused: Tempered, Slag, Bellows, Unbreakable, Smelt, Meteor Hammer, Cinder Soul, Cinder Trail, Quenched Slam.

| id | name | role | cooldown | resource | note | vfx note |
|---|---|---|---|---|---|---|
| `hammerfall` | Hammerfall | slam | 5 live | +12 live | Overhead slam. | Charcoal hammer, orange hot edge, a ground-crack ring, 8 studs live, bright sparks, heat haze. |
| `molten_charge` | Molten Charge | dash | 7 live | +8 live | Dash that leaves fire. | A forward dash, 14 studs live, orange and molten-yellow ribbon, charcoal smoke, bright trail that fades. |
| `anvil_guard` | Anvil Guard | block | 8 live | 0 live | Block the next hit. | Braced hammer, charcoal plates, a hot orange edge. A hit throws a short spark fan. |
| `eruption` | Eruption | vent | 11 live | 0 live | Vent all Heat into a ring. | Lava cracks in a ring, 12 studs live, orange on dark ground, bright, heat haze. The Heat bar empties. |
| `cinder_toss` | Cinder Toss | thrown coal | 6 suggested | +6 suggested | A thrown coal with a small splash. | A fist-sized coal, charcoal shell, orange core, bright spark on the splash. No fire ribbon. |
| `kiln_breath` | Kiln Breath | heat cone | 9 suggested | -20 suggested | A low heat cone that spends some Heat. | A low cone, orange to yellow, charcoal edges, heat shimmer. No lava cracks. |

## Frostblade

Melee. Ice blue, white, silver. Short recovery. Left unused: Shatter, Biting Wind, Permafrost, Twin Mirrors, Avalanche, Winter's Edge, Glacier, Rime Path, Shatter Spread.

| id | name | role | cooldown | resource | note | vfx note |
|---|---|---|---|---|---|---|
| `ice_edge` | Ice Edge | combo | 2.5 live | +1 live | Fast cut. Adds Chill. | Three fast arcs, ice blue and silver, short white streaks. A frost film grows on the foe. No ice cage. |
| `glacial_dash` | Glacial Dash | dash | 6 live | +1 live | Dash through and chill. | A dash, 16 studs live, ice-blue afterimage, silver edge. One frost mark on each foe. No ground patch. |
| `frost_mirror` | Frost Mirror | decoy | 10 live | 0 live | A decoy that bursts. | A pale ice copy, ice blue, 8 studs live on the burst. Silver shards, then gone. |
| `cold_snap` | Cold Snap | cone | 8 live | +2 live | Two Chill in a cone. | A forward cone, 10 studs live, white frost breath, ice-blue crystals. No freeze cage. |
| `shard_flick` | Shard Flick | thrown shard | 4 suggested | +1 suggested | A thin ice shard that adds one Chill. | One thin silver shard, ice blue, a short white streak, a tink. One frost film. No cage. |
| `glass_feint` | Glass Feint | feint | 7 suggested | 0 suggested | A pale afterimage that fades in place. | A half-step afterimage, ice blue, silver edge. It cracks once and fades. No burst. |

## Voidcaster

Ranged. Deep purple, black, magenta edges. Hovering hands. Left unused: Entropy, Echo, Hollow, Phase Shift, Contagion, Singularity, Void Pact, Blink Pull, Unstable Hex.

| id | name | role | cooldown | resource | note | vfx note |
|---|---|---|---|---|---|---|
| `void_bolt` | Void Bolt | piercing bolt | 2.5 live | -12 live | A piercing bolt. | A thin bolt, deep purple core, magenta edge, soft glow, 28 studs live. No explosion. |
| `rift` | Rift | pull zone | 9 live | -18 live | A pull that ticks. | A ground portal, 10 studs live, black center, magenta rim, violet ticks. Foes drift in. |
| `blink` | Blink | teleport | 7 live | -8 live | Step through and curse the spot. | A short step, 12 studs live. A purple glitch silhouette stays behind, with one magenta rune. |
| `hex` | Hex of Unmaking | curse | 10 live | -15 live | The target takes more damage. | Three small runes orbit the foe, deep purple, magenta edges, steady glow. |
| `rune_pin` | Rune Pin | mark | 8 suggested | -10 suggested | One rune. The next bolt bends toward it. | One palm-sized magenta rune, deep purple, orbits slowly, soft glow. |
| `veil_crack` | Veil Crack | ground line | 11 suggested | -14 suggested | A short ground crack that ticks on a cross. | A thin violet crack, about 8 studs suggested, magenta edges, a small tick spark. No pull. |

30 skills. 20 live, 10 concepts. Live cooldowns and resource numbers are copied from `Classes.luau`. Concept cooldowns and resource numbers are suggested.

Flags: Sapshield is smaller than Barkskin and is not Barkskin Share. Pearl Drop is not Healing Pool or Bubble Ward. Foam Step is not Undertow or Ebb Jump. Cinder Toss is not Cinder Trail, Cinder Maul, or Cinderplate. Kiln Breath is not Eruption, Kilnheart, or Kiln Bow. Shard Flick is not Ice Edge. Glass Feint is not Frost Mirror. Rune Pin is not Hex of Unmaking. Veil Crack is not Rift, Blink Pull, or Riftweave. No concept sells power.
