# World bosses

G-010. Eight open-world bosses, for a later spawn draft and the 3D art pass.

These are field bosses, not raid wings and not Rootvault rooms. Zones are the six in `docs/content/zones.md`. Every number below is suggested. Nothing here changes `Raids.luau`, `Dungeons.luau`, or the daily Gnarl.

Spawn follows `docs/design/shardfall_progression.md`: about every 2–3 hours, one boss awake in a realm, and everyone nearby is paid. No last hit. A realm with two bosses in this list alternates. Sunken Reach alternates Glasshorn and Brinecrown. Emberforge alternates Slagwalker and Cinderseat. Frostveil alternates Pane Strider and Stillfang. The daily board in `docs/design/shardfall_loops.md` can rotate these later. Beta still uses Daily Gnarl.

| rule | suggested |
|---|---|
| Nearby | 90 studs. A bit wider than one dungeon floor (`Dungeons.FLOOR_SIZE` is 79). |
| Phases | 3. Cuts at 70% and 35%, matching the Heartwood draft, not the live Gnarl cut at half. |
| Roar | 2 seconds between phases. The boss does not hit during the roar. |
| Leash | At 5 minutes the boss resets and walks home. It does not kill the field. |
| Solo | A yellow circle needs 1 player when fewer than 4 are in range, and 3 when 4 or more are in range. |
| Colors | Red dodge, yellow share, purple spread, blue interrupt. Same words as the raid kit. |
| Day's material | Once per player per day, on the first kill that day. The material is the column below. |
| Repeat that day | The realm's common material only. |
| First kill ever | The cosmetic below. No stats. Not a Robux item. |
| Chest | None. These bosses do not add an Epic chest and do not replace Daily Gnarl. |

Choice: four live boss materials get a field source. Gnarl's Seed stays Grandmother Gnarl's. The other four bosses pay the realm rare instead. Cosmetics have no power.

| id | name | zone | signature | first daily material | visual note |
|---|---|---|---|---|---|
| `mireoak` | Mireoak | Far Glade | The amber knot takes the last hits, and the yellow circle shares them. | Heartwood | Wide walking oak, mud-brown bark, short root legs, one amber knot, calm amber eye-lights, soft amber glow. |
| `glasshorn` | Glasshorn | Saltglass Strand | The glass horn is a big blue interrupt. Three huge plates are the safe floor. | Black Pearl | Giant low tortoise, white salt crust, one clear horn, teal rim, steady rim glow. |
| `brinecrown` | Brinecrown | Pearl Trench | The gold-blue brow scale is the only bright target. | Leviathan Crown-Scale | Long whale-eel, deep blue, one gold-blue brow scale, soft lamp spots down the side. No blood. |
| `slagwalker` | Slagwalker | Slag Marches | It walks a purple slag path. Blue vents on its back stop the heat wave. | Molten Core | Bulky walking heap, charcoal rock, orange cracks, bright crack glow, no face. |
| `cinderseat` | Cinderseat | Slag Marches | It stays seated. The chest crystal opens. The yellow circle at the chair shares the last hits. | Tyrant's Ember Heart | Huge seated slag figure, dark iron, a cinder crown, one orange crystal in the chest, bright crystal glow. |
| `pane_strider` | Pane Strider | Hoarfrost Expanse | You track its blue glow when the field goes white. | Everfrost Gem | Tall ice strider, clear pane antlers, blue-white body, strong blue eye glow, short frost trail. |
| `stillfang` | Stillfang | Hoarfrost Expanse | One crystal fang plants in the ice and is the blue interrupt. | Matriarch's Frozen Fang | Long low ice serpent, blue-white plates, one oversized pale crystal fang, strong cold glow. |
| `hollow_regent` | Hollow Regent | Rift Margin | A hole of light opens in the chest. The yellow circle shares the last hits. | Sovereign's Hollow Core | Tall mirrorless gray figure, no face, violet rim, a bright hole of light in the chest, rim glow across the field. |

Repeat drops, suggested: Mireoak and the Verdant field pay Verdant Bark. Glasshorn and Brinecrown pay Coral Shard. Slagwalker and Cinderseat pay Cinder Ore. Pane Strider and Stillfang pay Frost Pelt. Hollow Regent pays Void Dust.

## Mireoak

Live (2026-10-19) as a Waves mini-boss only: boss waves 10, 20, 30… (Gnarl keeps 5, 15, 25). It's Gnarl's boss kit with the amber knot as the WeakSpot: 240 HP, 11 dmg, plus Waves boss scaling. `Drops` role is `elite`, so it pays the realm rare, not a boss material. Boss chests follow the normal `ChestConfig.bossKill`. There's no Heartwood, no first-kill cosmetic and no field spawn; the field version below is still the plan.

Far Glade. Arena: Mireoak's Bowl. Verdant realm boss for this field.

| phase | suggested HP | name | what you do | telegraph |
|---|---|---|---|---|
| 1 | 100–70% | Mud Ring | Step out of the rings. | Purple rings under players. |
| 2 | 70–35% | Root Charge | Dodge to the side. | Red line, then a straight rush. |
| 3 | 35–0% | Amber Knot | Stand in the circle. Hits on the knot count for everyone in it. | Yellow circle in front of the trunk. |

Cosmetic: Mire Lamp. A small amber knot in an iron cage. Soft amber glow. No stats.

## Glasshorn

Saltglass Strand. Arena: The Saltglass Arch.

| phase | suggested HP | name | what you do | telegraph |
|---|---|---|---|---|
| 1 | 100–70% | Salt Cone | Dodge sideways. | Red cone of salt spray. |
| 2 | 70–35% | Horn Bell | Hit the glowing horn. | Blue charge on the horn, then a wide pulse. |
| 3 | 35–0% | Glass Plates | Stand on a plate. The plates are huge. No jump. | Three pale plates. The shelf outside them dims. |

Cosmetic: Glasshorn Crest. A small clear horn on a salt-white plate. Steady pale glow. No stats.

## Brinecrown

Pearl Trench. Arena: Brinecrown Trench. Source of the live Sunken boss material.

| phase | suggested HP | name | what you do | telegraph |
|---|---|---|---|---|
| 1 | 100–70% | Tail Sweep | Dodge the slow arc. | Wide red arc. |
| 2 | 70–35% | Scale Flash | Step off the rings around the brow scale. | Purple rings at the gold-blue scale. |
| 3 | 35–0% | Jaw Breach | Stand under the jaw. Hits on the scale count for everyone in the circle. | Yellow circle under the jaw. |

Cosmetic: Brine Clasp. A gold-blue scale on a teal pin. Steady scale glow. No stats.

## Slagwalker

Slag Marches. Arena: The Cool Vent. The walker, not the seated boss.

| phase | suggested HP | name | what you do | telegraph |
|---|---|---|---|---|
| 1 | 100–70% | Slow Slam | Step out of the circle. | Red circle, slow. |
| 2 | 70–35% | Slag Path | Do not stand in the path it walks. | Purple pools behind it. |
| 3 | 35–0% | Cool Vent | Hit a glowing vent on its back. | Blue vents, large, then a heat wave. |

Cosmetic: Slag Cloak. A short charcoal cloak with one orange seam. Steady seam glow. No stats.

## Cinderseat

Slag Marches. Arena: The Cinder Chair. It never stands up, so the camera stays put. Source of the live Emberforge boss material. Not a heat-meter fight. That idea stays on the Crucible raid sketch.

| phase | suggested HP | name | what you do | telegraph |
|---|---|---|---|---|
| 1 | 100–70% | Mace Arc | Dodge back. | Wide red arc from the seated swing. |
| 2 | 70–35% | Blue Vents | Stand in a floor vent while the crystal holds. | Three blue floor vents, large. |
| 3 | 35–0% | Open Crystal | Stand at the chair's foot. Hits on the crystal count for everyone in the circle. | Yellow circle. The orange crystal opens. It is a crystal, not a wound. |

Cosmetic: Cinderseat Charm. A tiny orange crystal in a dark iron cage. Bright crystal glow. No stats.

## Pane Strider

Hoarfrost Expanse. Arena: Pane Strider's Run. No copies of itself. The mirror boss stays on the Glacier Throne raid sketch. Frost Mirror stays a class skill.

| phase | suggested HP | name | what you do | telegraph |
|---|---|---|---|---|
| 1 | 100–70% | Antler Sweep | Dodge the slow arc. | Red arc from the pane antlers. |
| 2 | 70–35% | White Gust | Step out of the circles. Follow the blue eye glow. The body stays visible. | The field whitens. Purple circles mark the gusts. |
| 3 | 35–0% | Warm Breath | Stand at the muzzle. The circle shares the last hits and clears the slow. | Yellow circle at the muzzle. |

Cosmetic: Pane Halo. A thin clear ring that sits over the shoulders. Soft blue edge glow. No stats.

## Stillfang

Hoarfrost Expanse. Arena: The Still Fang. The serpent sleeps around the crystal spike. Source of the live Frostveil boss material.

| phase | suggested HP | name | what you do | telegraph |
|---|---|---|---|---|
| 1 | 100–70% | Low Bite | Dodge the wide slow bite. | Very wide red line. |
| 2 | 70–35% | Coil Rings | Step out of the rings along the body. | Four large purple rings. |
| 3 | 35–0% | Planted Fang | Hit the planted fang. | The crystal fang glows blue, then a freeze pulse. |

Cosmetic: Stillfang Pin. A tiny pale crystal fang on a white pin. Strong cold glow. No stats.

## Hollow Regent

Rift Margin. Arena: Regent's Step. Source of the live Void Rift boss material. One field, not a split reality. That idea stays on the Hollow Crown raid sketch.

| phase | suggested HP | name | what you do | telegraph |
|---|---|---|---|---|
| 1 | 100–70% | Dust Bolts | Step out of the landing circles. | Purple circles. |
| 2 | 70–35% | Lit Rings | Stand in a lit ring when the field dims. The rings are huge. | Three violet glass rings stay bright. |
| 3 | 35–0% | Open Core | Stand in the circle. Hits on the light count for everyone in it. | Yellow circle. A hole of light opens in the chest. |

Cosmetic: Regent Circlet. A thin gray ring with one violet gap. Soft violet glow. No stats.

Left unused: Thornwarden Twins, Mother Sapwell, Galecrown, Grandmother Gnarl, Grandmother Gnarl Awakened, Gnarl's Sprout, Daily Gnarl, the Crucible anvil-giant, the Glacier Throne mirror boss, the Drowned Choir, the Hollow Crown. Also unused as names: The Green Tyrant, Kiln Tyrant, Leviathan Mallet, Glacier Elk, Geode Sovereign, Gnarlling, Rootstrider.

Flags: Leviathan Crown-Scale is a live material, not Leviathan Mallet. Tyrant's Ember Heart is a live material, not Kiln Tyrant and not The Green Tyrant. Matriarch's Frozen Fang is a live material. Galecrown is the Heartwood owl, and Stillfang is not that owl. Sovereign's Hollow Core is a live material, not the pet Geode Sovereign. No raid boss is renamed here. No Robux item. No drop-odds change.
