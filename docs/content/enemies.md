# Field enemies

G-012. Thirty field enemies across the six zones in `docs/content/zones.md`, for a later spawn draft and the 3D art pass.

Five enemies in each zone. Roles are only melee, ranged, caster, and swarm. One move each. No live stats. Rootvault's five enemies stay in `Dungeons.ENEMIES` and are not reused.

Choice: regular enemies do not use the blue interrupt. That color stays on the world bosses in `docs/content/bosses.md`. Red means dodge. Purple means step out of the landing. A swarm is a pack with one telegraph, not a stack circle.

| role | count |
|---|---|
| melee | 8 |
| ranged | 8 |
| caster | 7 |
| swarm | 7 |

| id | name | zone | role | move | visual note |
|---|---|---|---|---|---|
| `mud_tusk` | Mud Tusk | Far Glade | melee | Tusk Rush. Red line, then a straight charge. | Low boar, mud-brown hide, dull root tusks, no glow. |
| `hedge_lurker` | Hedge Lurker | Far Glade | melee | Hedge Pounce. Red circle, then a short hop. | Crouched twig cat, dark green, a soft eye glint, no body glow. |
| `seed_flinger` | Seed Flinger | Far Glade | ranged | Pod Toss. Purple circle where the pod lands. | Round plant back, olive body, a sack of brown pods, no glow. |
| `sap_mouth` | Sap Mouth | Far Glade | caster | Sap Glob. Purple puddle. Step out. | Short stump, a honey sap lamp in a wood knot, soft amber glow. The lamp is sap, not a wound. |
| `mite_cloud` | Mite Cloud | Far Glade | swarm | Cloud Nip. The cloud drifts into melee. | A ball of tiny leaf mites, yellow-green, no single body, faint glint. |
| `salt_pincher` | Salt Pincher | Saltglass Strand | melee | Pincher Snap. Short red arc in front. | Wide crab, pale salt crust, teal shell edge, soft rim glow. |
| `gull_ray` | Gull Ray | Saltglass Strand | ranged | Salt Spit. Purple splash at range. | Flat ray, white and gull-gray wings, soft pale belly, no beam. |
| `brine_tosser` | Brine Tosser | Saltglass Strand | ranged | Crystal Toss. Purple circle, one salt crystal. | Hermit crab, white salt shell, a gray throwing arm, no glow. |
| `tide_bell` | Tide Bell | Saltglass Strand | caster | Bell Pulse. A purple ring grows. Step outside it. | Floating bell jelly, cream bell, teal ribbons, steady soft glow. |
| `foam_swarm` | Foam Swarm | Saltglass Strand | swarm | Foam Rush. A low white wave on a red line. | A pile of tiny foam crabs, white and pale teal, no glow. |
| `trench_jaw` | Trench Jaw | Pearl Trench | melee | Lamp Lunge. Red line from the chin lamp. | Long fish, deep blue, a round lamp on the chin, steady lamp glow. |
| `dart_fin` | Dart Fin | Pearl Trench | ranged | Spine Shot. A thin water dart on a purple line. | Thin fish, silver-blue, one long fin, no glow. The dart is water. |
| `pressure_wisp` | Pressure Wisp | Pearl Trench | caster | Pressure Orb. A slow purple orb, then a circle. | Small wisp, deep teal, one cream pearl core, steady core glow. |
| `lamp_fry` | Lamp Fry | Pearl Trench | swarm | Fry Flash. The school drifts in, then flashes. | A school of tiny lamp fish, blue-white dots, soft flash, no teeth shown. |
| `pearl_clutch` | Pearl Clutch | Pearl Trench | swarm | Clutch Nip. The pack runs on a red line. | A clutch of tiny pearl crabs, cream shells, no glow. |
| `coal_runt` | Coal Runt | Slag Marches | melee | Coal Charge. Red line, short charge. | Small slag beast, charcoal body, orange cracks, steady crack glow. |
| `slag_fist` | Slag Fist | Slag Marches | melee | Fist Slam. Red circle, slow. Step out. | Bulky golem, dark iron, one oversized fist, bright fist glow, no face. |
| `ore_slinger` | Ore Slinger | Slag Marches | ranged | Ore Toss. Purple circle, one hot ore chunk. | Stooped rock thrower, soot-brown, a sling of cinder ore, soft orange glow. |
| `ember_vent` | Ember Vent | Slag Marches | caster | Vent Cone. Red heat cone. Step aside. | Cracked rock, one orange vent, bright vent glow. Not a dragon mouth. |
| `spark_swarm` | Spark Swarm | Slag Marches | swarm | Spark Nip. The sparks drift into melee. | A cloud of tiny sparks, orange on black, bright and small. |
| `hoar_prowler` | Hoar Prowler | Hoarfrost Expanse | melee | Ice Pounce. Red circle, then a pounce. | Lean ice beast, blue-white shards in the fur, short frost trail. |
| `frost_spitter` | Frost Spitter | Hoarfrost Expanse | ranged | Frost Spit. Purple splash at range. | Low lizard, pale gray, a blue throat sac, soft sac glow. |
| `pane_tosser` | Pane Tosser | Hoarfrost Expanse | ranged | Pane Toss. A slow ice pane on a purple line. | Crouched ice figure, one clear pane in its hands, soft blue edge glow. |
| `glaze_caster` | Glaze Caster | Hoarfrost Expanse | caster | Glaze Bolt. Blue-white bolt, purple circle on the hit. | Floating six-sided ice crystal, blue-white, strong cold glow. |
| `chip_swarm` | Chip Swarm | Hoarfrost Expanse | swarm | Chip Rush. The chips fly on a red line. | A whirl of tiny ice chips, white, faint glint, no body. |
| `void_husk` | Void Husk | Rift Margin | melee | Husk Swing. Slow red arc. | An empty coat shape, mirrorless gray, violet rim, rim glow, no face. |
| `dust_flinger` | Dust Flinger | Rift Margin | ranged | Dust Dart. Purple line, one violet dart. | A floating mitt of void dust, purple-gray, soft dust glow. |
| `core_caster` | Core Caster | Rift Margin | caster | Core Bolt. Violet bolt, purple circle on the hit. | A floating core shard, dark purple, a bright hole of light. The hole is light, not a wound. |
| `seam_caster` | Seam Caster | Rift Margin | caster | Seam Bolt. A violet crack on the ground, then the bolt. | A floating crack, violet edges, dark center, soft seam glow. |
| `glass_mites` | Glass Mites | Rift Margin | swarm | Mite Flicker. The specks blink, then take a short red line. | Tiny gray-violet glass specks, faint glints, no single body. |

## Live (2026-10-19)

The Far Glade five are in code. `Dungeons.FAR_GLADE`, rigs in `ModelFactory.FIELD_MONSTERS`, verdant `Drops` rows (all `normal`).

| id | where | how the move plays |
|---|---|---|
| `mud_tusk` | Waves from wave 3, the Elite Fight stray, a Mireoak add | Tusk Rush: red mark from 16 studs, then a 0.2 s lunge onto it (`Dungeons.LUNGES`). |
| `hedge_lurker` | Waves from wave 3, the Elite Fight stray | Hedge Pounce: same lunge, 11 studs. |
| `seed_flinger` | Waves from wave 3, the Elite Fight stray, a Mireoak add | Pod Toss: purple mark, and the pod lands there (`Dungeons.LOBS`). No bolt. |
| `sap_mouth` | Waves from wave 3, the Elite Fight stray | Sap Glob: the same purple landing. No lingering puddle yet. |
| `mite_cloud` | Waves from wave 3 | Cloud Nip: a fast, low-HP melee. No pack split yet. |

They're still not open-world spawns: Far Glade as a zone isn't built. The Waves banner on wave 3 says "Far Glade beasts join. Purple: step out." The daily `glade` (defeat 4 in Waves) counts paying kills only.

Left unused: Vine Crawler, Spore Bat, Root Brute, Moss Crawler, Thorn Sprite, and the raid trash names Leafling, Sapling, and Treant. Charger, caster, shielder, and mender stay role words in Rootvault, not names here.

Flags: Gull Ray is not Gull Recurve. Tide Bell is not Winter Bell or Lantern Jelly. Pressure Wisp is not Pollen Wisp or Soot Wisp. Coal Runt is not Coal Newt. Hoar Prowler is not Aeon Wolf, Dawnbloom Wolf, or Leafmane Wolf. Glaze Caster is not Glaze Lark. Pane Tosser is not Pane Strider. No other game's creature is named. No gore.
