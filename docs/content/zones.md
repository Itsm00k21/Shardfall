# Zones

G-011. Six field zones after Haven and the Heartwood, for a later world draft and the 3D art pass.

Haven stays the hub. The Heartwood stays the raid. Rootvault stays the dungeon. These six are the open fields after that raid. Level bands are suggested. They follow the realm rows in `docs/design/shardfall_progression.md`. Live raid levels stay 15 for Story and Normal in `Raids.DIFFICULTIES`. The beta cap stays 20. No new music ids. Moods narrow the realm rows in `docs/design/shardfall_audio.md`.

Choice: the five realm names stay. Sunken Reach is the realm that is split, so the count is six. Far Glade is only the Verdant field past the raid gate. Levels 1–15 stay the live trail and Rootvault. A shared boundary level is the story gate, same as the realm table where 20, 30, 40, and 50 meet. Inside Sunken, Saltglass Strand is 20–25 and Pearl Trench is 26–30.

| id | name | realm | suggested levels | mood | enemy theme | music mood |
|---|---|---|---|---|---|---|
| `far_glade` | Far Glade | Verdant Wilds | 16–20 | Quiet wood past the raid gate. Birds remain. The mud is dark, not grim. | Mud beasts and seed throwers that left the outer wood. | Verdant flutes and hand drums, slower, plus a soft wood creak. |
| `saltglass_strand` | Saltglass Strand | Sunken Reach | 20–25 | Bright drowned coast. Salt wind. Teal water. Hopeful. | Salt crabs, salt throwers, and one bell jelly. | Harp, tide bells, distant gulls, a light choir pad. |
| `pearl_trench` | Pearl Trench | Sunken Reach | 26–30 | Deep blue and quiet. Lamp light. Pressure, not panic. | Trench fish, a pearl wisp, and small pearl crabs. | Low harp, choir pads, a slow pressure drone. No gulls. |
| `slag_marches` | Slag Marches | Emberforge | 30–40 | Hot wind over black rock. Orange cracks. A road, not a battlefield. | Slag beasts and ore throwers between the forges. | Distant anvils, low brass, a slow heat shimmer. |
| `hoarfrost_expanse` | Hoarfrost Expanse | Frostveil | 40–50 | Wide pale ice. Long sight. Quiet sun. | Ice prowlers, pane throwers, and chip whirls. | Celesta and sparse piano, far apart, plus wind. |
| `rift_margin` | Rift Margin | Void Rift | 50–60 | The color thins toward violet. No faces. The theme almost starts. | Faceless husks, dust, and glass specks. | Reversed pads, a detuned choir, one bell that never finishes. |

Only Far Glade sits inside the beta cap. The other five are post-beta. Suggested.

## Far Glade

Verdant Wilds. The field on the far side of the Heartwood gate. Not a raid wing.

| landmark | visual note |
|---|---|
| The Bent Waystone | A tilted gray stone, one dull amber crack. No glow until you stand close, then a soft pulse. |
| Mireoak's Bowl | A round mud bowl with root walls. Amber seeps in the cracks. Soft amber glow. |
| Thorn Arch | Two bent trunks and a dark green thorn lintel. No glow. A gate, not a boss. |

## Saltglass Strand

Sunken Reach, shallow half. Not the Drowned Choir raid.

| landmark | visual note |
|---|---|
| The Saltglass Arch | A natural arch of white salt crystal. Teal water light through it. Steady pale glow. |
| Gull Shelf | A flat white rock over teal water. Gull-gray stains. No glow. |
| Bell Pool | A round tide pool with cream foam. One soft bell glow under the water. |

## Pearl Trench

Sunken Reach, deep half. The field under where the Drowned Choir raid can sit later. This zone is not that raid.

| landmark | visual note |
|---|---|
| The Pearl Stair | Wide cream-pearl steps into dark blue. Steady pale edge glow. |
| Brinecrown Trench | A deep blue cut. Gold-blue glints in the walls. Steady glints, no beam. |
| Lamp Orchard | Tall stalks with blue-white lamp bulbs. Soft lamp glow. No fire. |

## Slag Marches

Emberforge. The open road. Not the Crucible raid.

| landmark | visual note |
|---|---|
| The Cool Vent | A blue-white steam crack in black rock. Bright cool glow. The safe color. |
| The Cinder Chair | A throne-shaped slag outcrop. One orange crystal in the back. Bright crystal glow. |
| Slag Bridge | Cooled black slag over a crack. Orange seams. Steady seam glow. |

## Hoarfrost Expanse

Frostveil. Open ice. Not the Glacier Throne raid.

| landmark | visual note |
|---|---|
| The Still Fang | A crystal spike the shape of a fang, taller than a player, stuck in the ice. Strong cold glow. It is crystal, not bone. |
| Pane Strider's Run | A long ice road of cracked clear panes. Blue edge glow. |
| The Pale Flame | An ice bowl with a pale blue flame that does not melt the bowl. Strong flame glow. |

## Rift Margin

Void Rift. The near edge of the rift. Not the Hollow Crown raid.

| landmark | visual note |
|---|---|
| The Hollow Ring | A gray stone ring with a violet inner edge. Steady rim glow. |
| Regent's Step | Gray stairs that fade into violet mist at the top. Soft violet glow. No faces carved in. |
| The Unfinished Bell | A gray glass bell with one gap. A faint bell shape, violet crack, no glow strong enough to light the stair. |

Flags: realm names, Heartwood, Haven, and Rootvault match the live docs and `Materials.REALMS`. The Drowned Choir, the Crucible, Glacier Throne, and the Hollow Crown stay raid sketches in `docs/design/shardfall_raids.md`. Tideglass is a weapon (`Tideglass Dagger`), so the coast zone is Saltglass. No other game's zone name is used.
