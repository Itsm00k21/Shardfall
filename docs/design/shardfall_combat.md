# Shardfall Combat Feel v1 (draft, Oct 16 2026)

## Pillars
1. Every hit is felt (feedback on screen, sound, camera).
2. Every danger is readable (telegraphs before damage).
3. Every class looks and moves differently (own colors, shapes, sound, rhythm).
4. Runs on phones (effects scale with Graphics Quality).

## Universal hit feedback ("juice")
| Layer | Light hit | Heavy hit / crit | Kill |
|---|---|---|---|
| Hitstop (freeze frame) | 0.03s | 0.07s | 0.1s |
| Enemy flash | white 0.08s | class color 0.12s | dissolve into class-colored shards |
| Knockback | tiny | medium + stagger | ragdoll pop |
| Damage numbers | white, small | big, class color, "CRIT" bounce | - |
| Camera | none | 0.15s shake (toggle) | small punch-zoom on elites |
| Sound | swish + thud | layered impact + bass | shatter chime |
| Particles | 4-6 sparks | burst + ring | shard burst + loot pop |
Also: input buffer 0.2s, animation cancel into dodge, hits stagger normal enemies (bosses use a stagger bar).

## Movement & defense
- **Dodge roll** (all classes): 0.35s, i-frames 0.2s, 2 charges, 3s recharge. A perfect dodge (dodging inside an attack's last 0.15s) gives slow-mo 0.3s plus +ult charge.
- Sprint out of combat. Optional lock-on (PC: middle mouse / Tab; mobile: tap enemy).
- Mobile: auto-face nearest enemy, larger skill buttons, dodge = swipe or button.

## Combo system
- Basic attack = 3-hit chain (3rd hit heavy). Hold for a charged attack.
- Skills cancel the end of a basic chain = "weave" for skilled players.
- Combo counter on screen; 10/25/50 hits give small damage buffs (resets after 3s idle).

## Class identity
### Warden - "the immovable wall"
- Palette: moss green, bark brown, gold sap. Shapes: roots, leaves, thorn spikes.
- Animation style: slow, grounded, heavy weight shifts; shield up between swings.
- Sound: wood creaks, deep thuds, rustling leaves.
- Signature effects: Rootgrasp roots erupt from the ground in a ring; Barkskin = bark plates grow over the body; ult treant form with glowing sap eyes.
- Feel moment: enemies bounce off the shield (heavy hitstop on blocks).

### Tidecaller - "the flowing current"
- Palette: teal, sea-foam white, pearl. Shapes: waves, bubbles, spirals.
- Animation: fluid, dance-like, floating staff twirls; never stops moving.
- Sound: splashes, chimes, soft whale-song on ult.
- Signature effects: heal numbers in green bubbles; Healing Pool = shimmering tidepool on the ground; Monsoon = rain + light rays.
- Feel moment: the ally health bar visibly surges with a wave effect.

### Forgeborn - "the walking furnace"
- Palette: orange, molten yellow, charcoal. Shapes: sparks, cracks, embers.
- Animation: big wind-ups, huge follow-through, ground cracks on slams.
- Sound: anvil clangs, roaring fire, metal hiss.
- Signature effects: Heat bar glows on the body (cracks glow brighter); Overheat = body emits embers and heat haze; Eruption = ring of lava cracks.
- Feel moment: Hammerfall has the longest hitstop in the game + screen shake.

### Frostblade - "the blur"
- Palette: ice blue, white, silver. Shapes: crystals, shards, sharp arcs.
- Animation: fast, snappy, short recovery; afterimages on dashes.
- Sound: sharp slices, crystal tinks, cracking ice.
- Signature effects: Chill stacks shown as frost creeping over the enemy; Frozen = enemy encased in ice; Shatter = glass-like burst.
- Feel moment: shattering a frozen enemy (big crit number + shard spray).

### Voidcaster - "the reality breaker"
- Palette: deep purple, black, magenta edges. Shapes: rifts, cracks in space, orbiting runes.
- Animation: controlled, hovering, hand gestures; Blink leaves a glitch silhouette.
- Sound: low hums, reversed whooshes, distorted echoes.
- Signature effects: curses = dark runes orbiting the target; Rift = swirling portal; Event Horizon = screen-edge warp + light bending.
- Feel moment: black hole detonation (silence 0.2s, then boom).

## Enemy readability
- Wind-ups: red ground decals for AoE, a red glint on the weapon for melee, a charging line for dashes.
- Rule: no damage without at least 0.5s telegraph (0.8s on Normal).
- Enemy types each have a distinct silhouette: Charger (low, horned), Caster (tall, glowing hands), Shielder (wide), Mender (floating, green aura).

## Boss design rules
- Stagger bar: filling it gives a 4s stun + bonus damage window.
- 3 phases, each with a new mechanic and a visual change (cracks, color shift, arena change).
- Telegraph language shared across the game: red = dodge, yellow = stack together, purple = spread out, blue = interrupt this.
- Phase-transition moment: 2s invulnerable roar + camera pull-back (skippable on repeat runs).
- Boss health bar at top with phase markers.

### Grandmother Gnarl (Rootvault) example
- P1: Root Slam (red circle, 1s), Bramble Spit (3 lines, 0.8s).
- P2 (60%): summons Saplings (kill them before they become trees), Vine Sweep (jump/dodge ring).
- P3 (25%): Thorn Wall closes in; Heartwood Roar (blue: interrupt or the party takes big damage).
- Look: bark cracks open, revealing glowing amber inside as phases progress.

## Performance budget
- Low: half particles, no shake, no afterimages, decals only.
- Med/High: full effects. Max ~200 active particles per player on Low.
- Pool effects and damage numbers (no Instance spam).

## Beta scope
Universal juice layer, dodge + perfect dodge, 3-hit combos, class palettes/sounds/signature effects for 4 skills, telegraph system, Gnarl 3 phases with stagger bar.
