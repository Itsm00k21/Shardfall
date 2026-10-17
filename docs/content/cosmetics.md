# Cosmetics batch 1

G-023. Thirty cosmetics: auras, foot trails, weapon dyes, and name plates, for a later catalog and the 3D art pass.

Each row is a look. No stat, no luck, no drop odds, no Raid Marks, and no raid power. Not a Robux price list. G-031 owns any later shop. `RaidLuck` already excludes `aura`, `dye`, and `cosmetic` from gear pity, and these rows stay in that group. A dye does not change the weapon's size. A plate does not change the title string. Letters keep the title's own tint from `docs/content/titles.md`.

Choice: name plates stop at Legendary. The Mythic red `#E6404E` stays the title tint, so a plate does not wear it. The three Mythic looks are an aura, a trail, and a dye.

The UI chip is the live `Rarities.COLOR` hex. It tints a name-plate frame only. An aura, a trail, or a dye keeps its visual note. Mythic objects stay prism or void, not a red paint. Commons stay plain.

| rarity | count | UI chip | glow key |
|---|---|---|---|
| Common | 6 | `#A8A8B0` | none |
| Uncommon | 6 | `#40BA62` | soft |
| Rare | 6 | `#488EFF` | steady |
| Epic | 5 | `#BA60F0` | bright |
| Legendary | 4 | `#FFC440` | strong, short |
| Mythic | 3 | `#E6404E` | prism or void, readable across a room |
| Total | 30 | | |

| kind | count |
|---|---|
| aura | 8 |
| trail | 8 |
| dye | 8 |
| plate | 6 |

## Auras

A soft body effect. The face stays readable. Not the Patron aura.

| id | name | rarity | visual note |
|---|---|---|---|
| `pebble_dust` | Pebble Dust | Common | A few gray pebble specks at the ankles. No glow. |
| `linen_haze` | Linen Haze | Common | A faint undyed haze on the hem. No glow. |
| `sap_wisp` | Sap Wisp | Uncommon | One small amber wisp at the shoulder. Soft glow. No beam. |
| `brine_ring` | Brine Ring | Rare | A teal ring on the ground under the feet. Steady glow. No splash. |
| `cinder_crownlet` | Cinder Crownlet | Epic | A small coal ring above the head. Bright orange. Does not cover the face. No fire. |
| `kiln_shoulders` | Kiln Shoulders | Epic | Two orange motes on the shoulders. Bright. No beam. |
| `frost_sigh` | Frost Sigh | Legendary | A short pale breath cloud. Strong cold glow. No ice left on the ground. |
| `prism_shade` | Prism Shade | Mythic | A thin cracked-rainbow shade around the body. Face readable. Prism glow across a room. |

## Trails

Behind the feet. Short. They fade. Not a skill trail.

| id | name | rarity | visual note |
|---|---|---|---|
| `gravel_step` | Gravel Step | Common | Three gray gravel specks. No glow. |
| `hem_puff` | Hem Puff | Common | Two dull linen puffs at the heels. No glow. |
| `moss_wake` | Moss Wake | Uncommon | Short yellow-green moss puffs. Soft glow. |
| `foam_wake` | Foam Wake | Uncommon | Short cream foam puffs. Soft teal tint. |
| `salt_wake` | Salt Wake | Rare | A short line of white salt specks. Steady pale glow. |
| `slag_wake` | Slag Wake | Epic | Three orange slag sparks behind the feet. Bright. They fade. No fire trail. |
| `hoar_wake` | Hoar Wake | Legendary | A short blue-white frost line. Strong cold glow. |
| `void_wake` | Void Wake | Mythic | A thin violet seam on the ground that fades. Seam glow across a room. |

## Weapon dyes

A thin edge tint. The weapon mesh stays the same. No beam.

| id | name | rarity | visual note |
|---|---|---|---|
| `pine_wash` | Pine Wash | Common | A dull pine-brown edge. No glow. |
| `moss_wash` | Moss Wash | Uncommon | A yellow-green edge. Soft moss glow. |
| `kelp_wash` | Kelp Wash | Uncommon | A kelp-green edge. Soft sea glow. |
| `pearl_wash` | Pearl Wash | Rare | A cream pearl edge. Steady pale glow. |
| `tide_wash` | Tide Wash | Rare | A teal edge. Steady sea glow. |
| `coal_wash` | Coal Wash | Epic | An orange coal edge. Bright. No beam. |
| `gale_wash` | Gale Wash | Legendary | A moon-silver edge with a short mist. Strong glow. No beam. |
| `prism_wash` | Prism Wash | Mythic | A rainbow edge on the weapon only. Prism glow across a room. The weapon stays the same size. |

## Name plates

The frame behind the name. Letters stay the title color. Readable on a phone nameplate.

| id | name | rarity | visual note |
|---|---|---|---|
| `plain_board` | Plain Board | Common | A flat gray rectangle. `#A8A8B0` edge. No glow. |
| `stitch_board` | Stitch Board | Uncommon | A cream board with a pine-brown stitch. Soft `#40BA62` corner glow. |
| `salt_board` | Salt Board | Rare | White salt-crystal corners. Steady `#488EFF` pale edge. |
| `lamp_board` | Lamp Board | Rare | Two small amber lamp marks in the corners. Thin `#488EFF` edge. Soft warm glow. No beam. |
| `frost_board` | Frost Board | Epic | Blue-white ice corners. Thin `#BA60F0` inner edge. Bright cold glow. Letters stay readable. |
| `margin_board` | Margin Board | Legendary | A gray board with a thin violet inner line. Strong gold `#FFC440` outer edge. Letters stay readable. No face. |

Flags: Pebble Dust is not Pebble Toad. Sap Wisp is not Sap Glow or Sapshine. Brine Ring is not Brine Loop, Brine Clasp, or Brine Saber. Cinder Crownlet is not the Cinderseat crown. Kiln Shoulders is not Kilnheart, Kiln Breath, or Kiln Bow. Prism Shade is not Prismrift or Prism Edge. Gravel Step is not Soft Step. Moss Wake is not Mossweave, Spore Trail, or Moss Band. Foam Wake is not Foam Trail. Salt Wake is not Saltcloth or Salt Ribbon. Slag Wake is not Slagwalker or Spark Vein. Hoar Wake is not Hoar Prowler or the unused set name Rimewake. Void Wake is not Void Seam, Voidlace, Void Locket, or Voidplate. Gale Wash is not Galecrown Bow or White Gale. Prism Wash is not Prism Edge, Prism Loop, Prism Rim, Prismfall, or Prism Name. Plain Board is not Boardwalker and not the Shard Board. Lamp Board is not Lantern Glow, Lantern Trail, or Pool Lamp. Margin Board is not Hollow Regent. None of these is the Patron aura. No other game's cosmetic is used.
