# Dungeon Look ("The Shattered Nave"), Spec v1 — Phase S theme

Owner: Prism (design, no code). Builders: Ghost (world/VFX), Echo (wave/boss hooks). Base: `cursor/live-build-9721` @ `9269e61`. Docs only.
Asked for in: Agent Board "Prism: overnight queue" (https://app.notion.com/p/403c31ca38838160b0afc69d00631416). **Phase S: building waits for Kevin's OK after his fun test.**
Locked numbers (Vision & Design Rules): arena ~80–100 studs, 3 edge gates, waves 6/8/10/12, wave 5 = boss + 4 adds, no run timer, party 1–4, elements Ember/Frost/Void. Element colors reuse the live Haven arch colors: Ember 255,150,40 · Frost 186,228,255 · Void 150,70,220.

## 1. Goal
One arena theme that makes every wave feel like the god-crystal's broken heart is fighting back: dark readable floor, enemies that pop by silhouette at phone zoom, clear "wave start / wave clear / boss" moments made only of world parts, lights and particles.

## 2. Where it lives
- The round wave arena (Roadmap 3.2, PR #382 arena) — this is its skin. Same footprint, same 3 edge gates, same spawn logic.
- Screen UI unchanged (existing wave toast, attack button). All effects here are world-space.

## 3. Flow
1. **Arrive:** fade in at the south entry; seams dim, gates dark, ambient hum.
2. **Wave start (each wave):** 0.0 s floor seams ring sweep from the Core Sigil outward (0.6 s) → 0.4 s the active gates flare in the wave's element color (inner Neon plane 0 → 0.2 transparency, burst of 30 particles) → 0.8 s enemies step out of the gate mouths. Existing "Wave n/5" toast plays.
3. **Fight:** gates keep a slow pulse while they still spawn; a gate goes dim when it has spawned its last enemy.
4. **Wave clear:** last kill → seams flash white (0.25 s) then settle → one shard shower burst from the ceiling ring (40 particles, 1.5 s) → `Lighting` ExposureCompensation +0.3 for 0.8 s, back to 0. Existing toast.
5. **Boss entrance (wave 5):** side gates dim → 1.5 s rumble (dust burst at the N gate base, optional small camera shake ≤ 0.3 studs, off on reduced motion) → N gate's two slab doors slide apart (Tween 1.0 s) → red-violet Beam + light from the mouth → Hollow Warden walks out (2 s) with a BillboardGui name "Hollow Warden" → 4 adds from E/W gates. Boss HP bar is existing UI.
6. **Run end:** win = shard shower ×2 + gates go gold; wipe = seams fade to gray (loot kept, per rules).

## 4. Layout
Map: `mockups/01-arena-topdown.svg`. Origin = arena center.
| Thing | Size (studs) | Notes |
|---|---|---|
| Play floor | Ø90 | dark crystal slab, 3 dashed seam rings (r 12, 26, 38) + 12 radial seams (Neon strips 0.4 wide) |
| Core Sigil | Ø12 center | raised 0.2, lights on wave start |
| Rim wall | Ø100, 14 tall | 18 leaning crystal pillars + low wall between; not climbable (invisible wall to 30 tall) |
| Gates ×3 | frame 16 w × 20 h | N (boss gate, red-violet trim 255,90,110), E and W (tint to wave element). Player entry is S (no gate, a closed sealed arch) |
| Party spawn | 4 sockets 6 apart at z +30 | |
| Ceiling | none (open sky) | broken prismatic sky like the hub, darker |

Camera check: at default zoom the gate arch tops (20 tall) are visible from the center on 800×400 and 667×375; on 390×844 portrait at least the nearest gate. See `mockups/02-wave-start-800x400.svg`.

## 5. States
- **Gate:** sealed (dark, 0.9 transparency inner) · spawning (element color, pulse 1 Hz) · spent (dim) · boss (doors open, red-violet).
- **Floor seams:** idle (cyan 120,210,255 at 0.7 transparency) · wave start sweep · clear flash (white) · wipe (gray).
- **Lighting:** fight (default) · boss (Atmosphere Color tints to 120,60,110 over 2 s) · clear (exposure pulse).

## 6. Numbers
- Floor Ø90 (inside 80–100 lock), wall Ø100, 14 tall; gates 16×20; pillars 18.
- Wave start 0.8 s from seams to first enemy; wave clear effects 1.5 s; boss entrance 4.5 s total (no gameplay waits longer than the existing wave break).
- Enemy heights: chaser 3, ranged 4 (floats 3 up), tank 7, boss 14 studs.

### Phone performance budget (arena + max wave 12 enemies + party of 4)
| Budget | Cap |
|---|---|
| Arena parts/MeshParts | ≤ 400 |
| Arena triangles | ≤ 35k |
| Per enemy | ≤ 12 parts / ≤ 1.5k tris (boss ≤ 40 parts / 6k tris) |
| Lights | ≤ 5 (center + 3 gates + boss), Shadows false |
| ParticleEmitters | ≤ 8 in arena, bursts via `:Emit()`, live ≤ 300 |
| Beams | ≤ 4 |

## 7. Edge cases
- Wave with enemies only from one gate: only that gate flares.
- Element-mixed wave: each gate takes the color of what it spawns; if mixed, gate uses violet neutral (200,180,255).
- Reduced motion / low quality: no camera shake; bursts at half count.
- Player stands in a gate mouth: gates are walls past the frame (invisible blocker), enemies spawn 4 st inside the mouth and push out.
- Boss dies during its entrance (not possible: invulnerable until doors open; Echo hook) — flag for Echo.
- Wipe: no "loss" flash in red; gray fade only (keeps the "always keep loot" tone).

## 8. Mockups
`mockups/01-arena-topdown.svg` (layout + studs) · `mockups/02-wave-start-800x400.svg` (wave start, phone landscape, keep-out box, 44+ px UI) · `mockups/03-enemy-look-sheet.svg` (4 roles × 3 elements + pure-black phone-zoom silhouettes). Original designs, fake data.

### Enemy look sheet
Rule: body is dark ink (22,16,31); element shows only on glow trim, eyes and particles, so shape reads first and color second.
| Role | Name (placeholder) | Silhouette key | Size |
|---|---|---|---|
| Chaser | Shardling | low hunched wedge with back spikes, leans forward | 3 st |
| Ranged | Prism Wisp | floating diamond with an orbiting ring, shadow under it | 4 st, hovers 3 |
| Tank | Bulwark | wide block body + tall slab shield on one side | 7 st |
| Boss | Hollow Warden | tall robed spire, broken halo above, shard "wings" | 14 st |
Elements: Ember 255,150,40 (ember sparks), Frost 186,228,255 (snow motes), Void 150,70,220 (dark swirl). Boss adds a red-violet `Highlight` (OutlineTransparency 0.2) only during the entrance.

## 9. Build split
**Gray box (Ghost):** floor as block segments (dark 34,28,58) + Neon seam strips · Core Sigil block · 18 pillar wedges (90,74,138) · 3 gate frames (3 blocks each) + inner Neon plane · N gate 2 slab doors · invisible walls · 4 spawn sockets. Enemies: block stand-ins at the right heights with Neon trim in element color.
**Art pass:** pillar + gate MeshParts · floor crack Texture · seam Neon strips · enemy meshes per sheet · emitters (gate flare, seam sweep via a Neon ring part Tween in Size, shard shower, boss dust, element motes) · Lighting: Atmosphere Density 0.38, Color 110,90,170, Haze 2; Ambient 50,40,80; Bloom 0.7.
**Echo hooks (later, read-only ask):** wave-start, gate-spent, wave-clear, boss-enter events the client VFX can listen to (likely exist in #382; confirm).
Roblox notes: seam "sweep" = a thin Neon ring (MeshPart or ring of parts) whose Size tweens out; no shaders, no post effects beyond Bloom/Exposure.

## 10. Pass criteria
- [ ] Arena Ø90 floor, 3 gates, readable at 390×844 / 667×375 / 800×400 / desktop.
- [ ] At phone zoom, testers name chaser/ranged/tank/boss from silhouette alone (4/4) and the element from color (3/3).
- [ ] Wave start ≤ 0.8 s to first enemy; boss entrance ≤ 4.5 s.
- [ ] Budget met with 12 enemies + 4 players on a low-end phone (≥ 30 FPS).
- [ ] No screen UI added; existing touch targets ≥ 44 px.

## 11. Open questions (Kevin)
1. Arena size: Ø90 floor (my pick, middle of the 80–100 lock) OK?
2. Boss entrance camera shake (tiny, off on reduced motion): yes or no?
3. Enemy names (Shardling, Prism Wisp, Bulwark, Hollow Warden) are placeholders — keep or rename?
