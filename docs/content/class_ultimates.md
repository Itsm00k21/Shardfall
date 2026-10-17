# Class ultimates

G-009. One ultimate per class: fantasy, animation beats, VFX, and SFX, for the combat presentation pass.

These are the five ultimates already in `Classes.luau`. Names, ids, and coefficients below marked live are copied from that module. Cooldown is 0 live. `Classes.ULT_COST` is 100 live. `ClassService` spends that meter on a successful cast, and a successful non-ult skill adds 8 live. `sounds.ult` is an empty string on every class, so the SFX notes are for a later licensed clip.

The suggested window is the length in `docs/design/shardfall_classes.md`. The module has no duration field. Beat times are suggested and fit inside that window. Palette triples are live.

Skills for the same classes are in `docs/content/class_skills.md`.

| class | id | name | damage | heal | shield | radius | window |
|---|---|---|---|---|---|---|---|
| Warden | `heart_grove` | Heart of the Grove | 1.4 live | 0.08 live | 0 live | 14 live | 6s suggested |
| Tidecaller | `monsoon` | Monsoon | 0.4 live | 0.28 live | 0 live | 16 live | 8s suggested |
| Forgeborn | `forgeheart` | Forgeheart | 1.6 live | 0 live | 0 live | 10 live | 8s suggested |
| Frostblade | `absolute_zero` | Absolute Zero | 1.5 live | 0 live | 0.1 live | 14 live | 5s suggested |
| Voidcaster | `event_horizon` | Event Horizon | 1.8 live | 0 live | 0 live | 16 live | 5s suggested |

Live notes: "Taunt, slam, and heal nearby." "Rain heals the party." "Overheat with no health drain." "Freeze the room and crit them." "A black hole, then a boom."

## Warden — Heart of the Grove

You become a broad treant, taunt the circle, slam twice, and drip sap heals on allies. Palette 92, 140, 78. Gold sap is a design accent.

| beat | suggested time | picture | vfx | sfx |
|---|---|---|---|---|
| 1 | 0.0-0.5s | Both feet plant. The shield lowers. | Roots grab the ankles, bark brown, moss tips, soft gold sap. | Wood creak. |
| 2 | 0.5-1.2s | The body swells into a broad treant. | Bark plates, moss-green shoulders, two gold sap eyes. Readable across the raid. | Deep wood groan. |
| 3 | 1.2-1.6s | The arms open. | A moss-green ring, 14 studs live. Allies show no damage flash. | Low horn. |
| 4 | 1.6-5.0s | Two slow slams. | Each slam is a bark-brown root ring. Allies get a small green sap number. | Deep thud, then leaf rustle. |
| 5 | 5.0-6.0s | The treant shrinks back to the Warden. | Bark flakes fall and fade. Sap eyes dim. | One soft creak. |

## Tidecaller — Monsoon

A rain cloud heals the party. One downed ally rises on a bubble. Palette 72, 186, 176. Pearl white is a design accent.

| beat | suggested time | picture | vfx | sfx |
|---|---|---|---|---|
| 1 | 0.0-0.6s | The staff lifts. | A pearl spiral climbs the staff, teal and white, soft glow. | Soft water chime. |
| 2 | 0.6-1.4s | A cloud opens overhead. | Sea-foam cloud, teal light rays, 16 studs live. | A quiet rising pad. |
| 3 | 1.4-7.0s | Rain falls on the party. | Heal numbers ride green bubbles. One downed ally rises inside a clear bubble. | Steady soft rain. |
| 4 | 7.0-8.0s | The rain thins. | The puddle fades to a pale teal sheen. | One chime, then quiet. |

## Forgeborn — Forgeheart

The body runs at full Heat and does not show a health drain. Palette 220, 110, 48. Charcoal and molten yellow are design accents.

| beat | suggested time | picture | vfx | sfx |
|---|---|---|---|---|
| 1 | 0.0-0.5s | The hammer plants. | Orange cracks race up the arms. | Anvil clang. |
| 2 | 0.5-1.2s | Heat haze wraps the body. The body stays the same size. | Cracks brighten to molten yellow. No drain flicker. | Fire roar under the clang. |
| 3 | 1.2-7.2s | Normal swings, hotter. | Every third hit, a short charcoal-and-orange crack ring at the feet, inside 10 studs live. Smaller than Eruption. | Layered impact, bass on the third hit. |
| 4 | 7.2-8.0s | The cracks cool. | Dull coal lines. Haze fades. | Metal hiss. |

The third-hit ring is the design draft. It is not a field on the ult row.

## Frostblade — Absolute Zero

Nearby foes lock in clear ice, and the blade's crits flash on that ice. Palette 150, 210, 240. Silver is a design accent.

| beat | suggested time | picture | vfx | sfx |
|---|---|---|---|---|
| 1 | 0.0-0.4s | A still pose. Breath shows. | One silver flash, no trail yet. | High crystal tone. |
| 2 | 0.4-1.0s | Foes in the circle stop inside clear ice. | Glass cases, ice blue and white, 14 studs live. The ice looks solid, not sharp against the body. | A short crack. |
| 3 | 1.0-4.4s | The blade keeps its fast cuts. | White arcs. A crit on iced foe throws a glass-shard burst, silver and ice blue. | Sharp slice. Glass tink on the crit. |
| 4 | 4.4-5.0s | The ice falls away. | Shards fade before they land. A thin pale shield clings to you, shield 0.1 live. | One soft crack, then quiet. |

## Voidcaster — Event Horizon

A small marble becomes a black sphere, pulls, then pops. Palette 120, 70, 180. Magenta edges are a design accent.

| beat | suggested time | picture | vfx | sfx |
|---|---|---|---|---|
| 1 | 0.0-0.5s | Both hands frame a point. | A violet marble, palm-sized, soft glow. | Reversed whoosh. |
| 2 | 0.5-1.2s | The marble grows. | A black sphere, magenta rim, growing toward 16 studs live. | Low hum. |
| 3 | 1.2-4.4s | Foes slide toward the sphere. | A slight bend at the screen edge. Three magenta runes orbit the rim. | Hum holds. |
| 4 | 4.4-4.6s | The sphere holds still. | Rim glow dips. | Quiet. |
| 5 | 4.6-5.0s | The sphere pops. | A purple-white ring and short shard sparks. The sphere is gone. | Distorted boom. |

The quiet beat is the 0.2s stall from `docs/design/shardfall_combat.md`. It is suggested.

5 ultimates. 22 beats. Live coefficients are unchanged. Sound ids stay empty.

Flags: Heart of the Grove is not Grovewarden and not the Heartwood Bulwark relic. Monsoon is not Undertow or Healing Pool. Forgeheart is not Eruption, Kilnheart, or Cinderplate. Absolute Zero is the live name, a temperature phrase, and not Rimewake or Paleveil. Event Horizon is the live name, a physics phrase, and not Rift, Veil Crack, or Riftweave. No other game's character or signature move is used. No gore.
