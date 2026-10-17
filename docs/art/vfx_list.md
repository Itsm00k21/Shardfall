# VFX list

G-046. Combat, roll, and loot effects for the art pass. Live times and counts come from `CombatFeel.luau` and `RollReveal.luau`. The hub crack uses `CrackReveal.luau` as well. Do not change those numbers. Colors below are live unless the row says suggested.

Two roll clocks are both in the game. The Roll tab samples `CrackReveal`. `RollReel.luau` still plays the 1.65s `RollReveal` clock. A new effect has to fit the clock that surface already uses.

Graphics budgets: `CombatFeel.vfxBudget` multiplies the juice count by the intensity slider. The low tier halves that count and keeps at least 2 (`CombatFeel.luau:260-274`). Roll shards use `RarityConfig.particleCap` instead. Other players' VFX can be switched off in Settings.

## Combat

| id | when | live timing | color | count | drawn today |
|---|---|---|---|---|---|
| `slash_sparks` | a local swing | trail dies at 0.18s. Emitter life 0.08–0.16s, speed 2–6, light emission 0.6 | neon `#FFF4DC` (255, 244, 220) | rate equals the juice budget: light 5, heavy 8, kill 12 | yes. A neon bar on the held blade (`CombatStage.luau:106-143`) |
| `screen_hit_flash` | a damage payload with `flash` | light 0.08s, heavy 0.12s, kill 0.12s (`CombatFeel.luau:14`) | white, or `#FFC440` when `crit` | full screen at transparency 0.72 | yes (`CombatHud.luau:318-325`, `CombatHud.luau:714-719`, `CombatHud.luau:894`) |
| `model_hit_flash` | `ModelFactory.flash` | 0.12s | fill `#FFF4DC`, outline `#FFDC8C` | one Highlight | yes (`ModelFactory.luau:977-990`) |
| `hitstop` | heavy or kill juice | light 0.03s, heavy 0.07s, kill 0.10s (`CombatFeel.luau:13`) | none | none | yes, but the client applies it only when the hit is heavy or the weight is kill (`CombatHud.luau:710-712`) |
| `camera_shake` | heavy or kill | 0.15s. Light is 0 (`CombatFeel.luau:229-257`) | none | none | yes, unless the tier is low or shake is off (`CombatFeel.luau:306-310`) |
| `damage_floater` | damage | pops and fades | `#F5F0E6` at text size 22. Crit is `#FFC440` at 30 and adds `!` | one label | yes (`CombatHud.luau:690-724`) |
| `heal_floater` | heal | same pop | `#6ED28C` (110, 210, 140), text `+n` | one label | yes |
| `combo_label` | combo greater than 1 | stays until the next plain damage | HUD text | `N hit` | yes (`CombatHud.luau:700-705`) |
| `kill_shards` | kill juice with `shards` | 0.45s, drift 6 studs out and 4 up | neon `#FFD678` (255, 214, 120), cubes 0.4 | 4 cubes. The juice row says 12 particles. The client spawns 4 | yes (`CombatHud.luau:760-789`) |
| `dodge_dash` | a dodge clip | dodge 0.35s, iframe 0.20s, 2 charges, recharge 3s (`CombatFeel.luau:15-18`) | none | no trail | the clip plays. No afterimage. A Codex cue pulses the Dodge button (`ActionBar.luau:363`) and can show Dodge! (`ActionBar.luau:590`). That hint is not a trail |
| `perfect_floater` | a perfect dodge | window 0.15s, plus 0.10s of late latency (`CombatFeel.luau:19`, `CombatFeel.luau:127`) | `#FFEC8C` (255, 236, 140), word PERFECT | one label | yes (`CombatHud.luau:749-753`) |
| `perfect_slowmo` | `notePerfect` | 0.30s (`CombatFeel.luau:20`, `CombatFeel.luau:182-184`) | none | none | not drawn. Suggested: a short desat, only if the photosensitivity flash is not reduced |
| `telegraph_floor` | enemy windup | boss 1.80s. Normal, story, or an unset difficulty is 0.80s. Any other difficulty is 0.50s, and a boss overrides that. Square half-extent 4, so the part is 8×0.2×8 (`CombatFeel.luau:31-37`, `CombatFeel.luau:325-337`, `CombatFeel.luau:54-59`) | red `#DC4038` dodge, yellow `#F0C440` stack, purple `#A860DC` spread, blue `#5096E6` interrupt | one neon part, transparency 0.35 when it has no emitter (`DungeonService.luau:1638`) | yes (`DungeonService.luau:2175-2182`) |
| `telegraph_lesson` | the first 3 cues only | same seconds as the floor mark (`CombatFeel.CUE_LESSONS` is 3) | the cue's rgb on a stroke | no word. The label is cleared | yes, then the edge hides (`CombatHud.luau:726-741`) |
| `flinch` | a hit sets `ShardfallFlinchUntil` | 0.12s (`CombatFeel.luau:42`) | none | pitch plus 18 degrees | yes (`ModelFactory.luau:958-960`) |
| `death_dissolve` | death | 0.45s (`CombatFeel.luau:43`) | puff has no color of its own | rate 12, life 0.20–0.45s, speed 2–6, five transparency steps | yes (`ModelFactory.luau:1011-1043`) |
| `spore_cloud` | Gnarl phase-2 fog | at least 1.2s | `#8CE6B0` (140, 230, 176), size 18×7×18 | emitter rate 14, life 0.8–1.6s (`DungeonService.luau:1642-1646`) | yes. This is not a telegraph color (`VerdantLook.luau:53-58`, `DungeonService.luau:2089-2096`) |
| `stagger_bar` | stagger reaches 100, then a 4s stun | light hit 8, heavy 18, boss hits pay 60% (`CombatFeel.luau:26-29`, `CombatFeel.luau:313-316`) | none | none | not drawn. No art until a HUD row exists |

The first three cue lessons hide the telegraph words. Color is the lesson. Red means move. A Codex snapshot can still paint a color icon on the boss and pulse the Dodge button with the word Dodge!. That hint is not a fifth floor color.

## Rolls

`RollReveal.FULL` is 1.65s (`RollReveal.luau:41`). Dim ends at 0.15s. The fast spin ends at 0.60s. The slow spin ends at 1.30s. Hold ends at 1.40s. Glow starts at 1.00s. Flash starts at 1.15s and lasts 0.50s, in two pulses of 0.08s a third of a second apart (`RollReveal.luau:42-50`, `RollReveal.luau:238-248`).

| id | when | live rule | art note |
|---|---|---|---|
| `reel_dim` | the spin starts | backdrop 0.5 times the dim, black flash | a dark wash, not a whiteout |
| `reel_glow` | Epic or better, 1.00–1.40s | stroke becomes the lifted rarity color, thickness 2 | one steady rim |
| `reel_flash` | Legendary or better, two short pulses | flash transparency 0.55, rarity color | two blinks, not a strobe |
| `reel_particles` | Legendary or better, 1.15–1.65s | one glass cube, 2.2 studs, emitter rate is the particle cap, life 0.35–0.80s, speed 1–5 | color is the lifted rarity. Low tier emits 0 for Mythic and Secret |
| `card_morph` | after 1.40s | scale 0.85 to 1.0 with a back-out | the shard becomes the card. No second item |
| `reel_land_sound` | spin progress hits 1 | `Audio.cue(rarity)`. If that is empty, Rare, Epic, and Legendary play `electronicpingshort.wav`. Common, Uncommon, Mythic, and Secret stay quiet | see `docs/art/audio_cues.md` |

`RarityConfig.reveal` is the other cut (`RarityConfig.luau:516-546`). A normal reel is 1.45s plus 0.40s land plus 0.60s card. Epic adds 0.50s. Legendary plays a 1.50s scene when it is not a quick roll. Mythic and Secret skip the reel, hold a 3.00s scene, stall, and can be skipped after 1.00s. Shake is 0.30s for Epic or better. A quick roll on Common or Uncommon is a toast only.

The hub crack is what the Roll button plays (`CrackReveal.luau:43-51`).

| rarity | full seconds | shake | crack | tension | flash |
|---|---|---|---|---|---|
| Common | 0.55 | first 32% | until 58% | none | no |
| Uncommon | 0.72 | first 32% | until 58% | none | no |
| Rare | 1.15 | first 40% | until 62% | none | yes, unless reduced |
| Epic | 1.60 | first 40% | until 62% | until 80%, the label is `...` | yes |
| Legendary | 1.95 | first 40% | until 62% | until 80% | yes |
| Mythic | 2.35 | first 40% | until 62% | until 80% | yes |
| Secret | 2.60 | first 40% | until 62% | until 80% | yes |

Quick multiplies those seconds by 0.45 and keeps at least 0.28s. Skip uses 0.32 and keeps at least 0.22s. Reduced motion is 0.20s, no flash. The stone rests at `#C6CED6` (198, 206, 214) and takes the rarity color on the burst (`MenuHub.luau:1022`, `MenuHub.luau:3474`). The burst stroke is 2 plus glow times 5 (`MenuHub.luau:3477-3489`). The flash cover sits at transparency 0.42 while `sample.flash` is on (`MenuHub.luau:3496-3498`).

The strip does not tease a higher rarity than the landed card (`RollReveal.luau:12-14`). Do not add a near-miss flash.

## Loot

| id | live | art note |
|---|---|---|
| `loot_orb` | neon ball, 0.7 studs, `Rarities` color, pops with velocity `(cos(index * 1.7) * 8, 16, sin(index * 1.7) * 8)` (`CombatFeel.luau:277-279`, `DungeonService.luau:669-685`) | one orb per material stack, not per item |
| `rarity_beam` | neon bar 0.12×5×0.12, same color, follows the orb 2.4 studs up (`DungeonService.luau:687-710`) | a thin beam. It is not a weapon |
| `loot_magnet` | after 0.35s, within 14 studs (`CombatFeel.MAGNET_RANGE`), velocity 36 toward the player, pickup inside 3.5, gone at 6s | a pull, not a trail. Suggested: a short streak only on Epic and above |

## Counts

| group | rows | drawn | not drawn |
|---|---|---|---|
| Combat | 18 | 16 | `perfect_slowmo`, `stagger_bar` |
| Rolls | 6 clocks plus the crack table | both clocks | a near-miss, which must stay absent |
| Loot | 3 | 3 | the Epic streak is suggested only |

Flags: telegraph colors stay the four in `CombatFeel.TELEGRAPHS`. Do not add a fifth. No gore on the death puff. No other game's hit spark or loot beam.
