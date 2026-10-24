# Town / Hub Redesign ("Sundered Haven"), Spec v1

Owner: Prism (design, no code). Builders: Ghost (world + UI), Echo (server hooks). Base: `cursor/live-build-9721` @ `9269e61`. Docs only.
Asked for in: Agent Board "Prism: overnight queue: Town redesign + dungeon look specs" (https://app.notion.com/p/403c31ca38838160b0afc69d00631416). Roadmap 3.1 (Shard Gate pad near spawn), Phase 6 (party).
**Building waits for Kevin's OK after his fun test (Phase S).** Nothing here changes code or Config.

Sources (link, don't copy): live hub `HavenBuilder` + `Shared/Haven.luau` (`FLOOR_Y = 120`, `WALK_SPEED = 16`, Lumen Heart at (0,0), Armory stand at (-26,18)); `docs/design/DUNGEON_GATE_PLAZA.md` (Ghost, Oct 17, six-arch plaza parked); first-30-seconds spec (`prism/first-30-seconds`, Wren left / Gate right in the first shot, about 30 studs walk to the Gate). Element colors reuse the live Haven arch colors: Ember 255,150,40 · Frost 186,228,255 · Void 150,70,220.

## 1. Goal
A small, readable hub where a new player sees the Roll altar and the Shard Gate in the very first shot, walks spawn → Roll in ~2 s and Roll → Gate in ~4 s, and instantly gets the world's story: a god-crystal shattered, its shards rain down, and the Hollow is draining color from the edges.

## 2. Where it lives
- World only: replaces the `HavenBuilder` blockout layout at floor y 120 (same model name, Persistent). The six-arch plaza stays parked (Gate Plaza doc); the far realm arches are out of V1.
- Screen UI unchanged: existing ROLL bar (56 px), Bag button, rail. World prompts are `ProximityPrompt` + `BillboardGui`.
- Theme name: **Sundered Haven**. Landmark: **the Sundered Heart** (replaces the Lumen Heart in place, same origin).

## 3. Flow
1. Spawn on a 14×14 pad at (0, 64), facing north. Camera sees: the Sundered Heart center-back, the Crackstone (Roll) front-left with Oracle Wren, the Shard Gate arch front-right.
2. Walk 35 st (2.2 s) to the **Crackstone** at (-26, 40) → ProximityPrompt "Roll" opens the roll flow (existing).
3. Walk 57 st (3.6 s) to the **Shard Gate pad** at (30, 30) → standing on the pad opens the existing Gate dock (first-30 spec) → START → teleport to the arena.
4. Optional: **Kit Rack** at (-34, 4) (Bag / equip prompt, opens the existing Bag). **Muster Ring** at (46, 6), 16 st from the Gate pad (Phase 6 party gather; gray-box ring only in V1, no function).
5. Returning from a run: arrive on a return pad beside spawn at (14, 64) (not on the Gate pad, so no accidental re-entry).

## 4. Layout
Origin = Heart center (0, 0), +z = south (toward spawn). All on floor y 120. Map: `mockups/01-topdown-map.svg`.

| Thing | Center (x, z) | Size (studs) | Notes |
|---|---|---|---|
| Plaza disc | (0, 0) | Ø180 walkable | rim band r 90–100 is the Hollow edge, invisible wall at r 98 |
| Sundered Heart | (0, 0) | pedestal Ø28 × 3; crystal 64 tall | 5–7 floating broken shards at 20–60 high, slow bob |
| Spawn pad | (0, 64) | 14 × 14 | faces north (LookVector -Z) |
| Crackstone (Roll) | (-26, 40) | altar Ø12, crystal 9 tall | Oracle Wren stands at (-32, 40) |
| Shard Gate pad | (30, 30) | pad Ø16; arch 18 tall, 14 wide | arch faces spawn (rotated ~215°) |
| Kit Rack (Bag) | (-34, 4) | 10 × 4 stand, mirror shard 8 tall | |
| Muster Ring | (46, 6) | Ø18 ring, 4 sockets | Phase 6, decor only in V1 |
| Return pad | (14, 64) | 10 × 10 | |
| Shard craters ×4 | (-55,-40) (60,-45) (-60,40) (10,-70) | Ø8 each | landmarks / orientation |
| Paths | spawn↔Roll, Roll↔Gate, spawn↔Gate, Roll↔Rack, Gate↔Muster | 10 wide | lighter slate so the route reads |

**Walk times** (WalkSpeed 16): spawn→Roll 35 st / 2.2 s · Roll→Gate 57 st / 3.6 s · spawn→Gate 45 st / 2.8 s · Roll→Rack 37 st / 2.3 s. All far under the 10 s cap.

**Sight lines:** from spawn, the Heart is dead ahead; Roll at -33° and Gate at +34° from the camera's forward, so both fit the ~70° landscape cone. In the narrow ~40° portrait cone, the Heart and the Gate arch top are visible; the Crackstone sits just outside the cone, so its 9-st crystal + Wren's BillboardGui name must peek in from the left edge (see mockup 02). Nothing tall stands between spawn and Roll/Gate (no part over 2 st high inside the spawn triangle).

**Phone camera checks** (default zoom ~12.5 st, mockups 02–03):
- 390×844 portrait: Heart + Gate arch + Gate billboard visible; Crackstone label at left edge; nothing crosses the center keep-out (x 30–70%, y 28–73%) except the world.
- 667×375 / 800×400 landscape: all three (Heart, Roll, Gate) visible on spawn.
- Desktop 1280×720: same as landscape with more sky.
- BillboardGui labels: `MaxDistance` 80, `AlwaysOnTop` false, text ≥ 18 px at 390 wide.

## 5. States
- **Gate pad:** idle (slow violet swirl) · player on pad (gold rim, dock opens) · countdown (swirl speeds up, 3 s) · party in Muster (Phase 6, later).
- **Crackstone:** idle glow · free rolls left (gold pulse + "FREE" billboard, new players) · rolling (crystal flashes in the revealed rarity color, 0.3 s).
- **Heart:** constant. Shards bob; one shard "falls" into a random crater every 20–30 s (Tween + burst), purely decor.
- **Hollow rim:** static gray band + fog particles; no damage, no gameplay.

## 6. Numbers
- Plaza Ø180 + rim to Ø200. Floor y 120. WalkSpeed 16 (live).
- Heart 64 tall; Gate arch 18; Crackstone 9; Kit Rack mirror 8; nothing else over 12 inside r 60.
- Shard rain: 1 world emitter over the Heart, Rate 6, Lifetime 3–4, Size 0.4–0.8.
- Shard fall event: every 20–30 s.

### Phone performance budget (whole hub, target low-end phone)
| Budget | Cap |
|---|---|
| Parts + MeshParts | ≤ 900 (gray box ≤ 250) |
| Triangles (meshes) | ≤ 60k total; Heart ≤ 8k |
| Lights | ≤ 6 PointLight/SurfaceLight, `Shadows = false` on all; 0 SpotLights |
| ParticleEmitters | ≤ 6, sum of Rate ≤ 40, live particles ≤ 250 |
| Beams | ≤ 3 (onboarding beam reuses one) |
| Textures | ≤ 8 unique; prefer SurfaceAppearance-free plastic/neon/glass |
| Unions | 0 (use MeshParts) |
Glass material only on the Heart and Crackstone crystal (Glass is costly on phones; fallback Neon + 0.3 Transparency on low quality).

## 7. Edge cases
- 20+ players at spawn: spawn pad 14×14 + return pad keep the Gate pad clear; Gate pad triggers only for the local player.
- Player walks off the rim: invisible wall at r 98; if they fall anyway (exploits), `FallenPartsDestroyHeight` respawn on spawn pad.
- Low graphics quality: emitters auto-thin (Roblox), Heart Glass → Neon fallback.
- New player never finds Roll: first-30 spec pointer + Wren line; Crackstone is 35 st away and lit.
- Phone portrait where Crackstone is off-frame: billboard at left edge + world Beam from first-30 spec.
- Streaming: hub model Persistent (live) so landmarks never pop.

## 8. Mockups
SVG (in repo): `mockups/01-topdown-map.svg` (map, studs, walk times, sight cones, landmarks) · `mockups/02-spawn-shot-phone-390x844.svg` · `mockups/03-spawn-shot-landscape-667x375.svg`.
Fake data. Original art: no reference game's art, layout or names.

### Theme: the Sundered Heart (original)
- **Shattered god-crystal:** one tall split crystal (two leaning halves with a bright gap), broken pieces floating around it.
- **Shards raining down:** thin light streaks falling over the plaza, slow and sparse; craters with embedded shards mark where big ones landed.
- **Broken prismatic sky:** a deep violet sky with "crack" lines in pink/cyan/white edges (a skybox decal set, or a few large Neon Beam strips high in the sky).
- **Color draining at the Hollow:** saturation steps down by ring: center parts full color → r 60–90 muted → rim r 90–100 gray (RGB ~110,110,116) with gray fog particles. Strongest in the SW "Hollow creep" wedge.

## 9. Build split
**Gray-box pass (Ghost, after Kevin's OK)** — plain Parts, SmoothPlastic, colors only:
| # | Part | Shape/size | Color (RGB) |
|---|---|---|---|
| 1 | Plaza floor | Block segments forming Ø180 (no cylinders, per HavenBuilder note) | 58,48,86 |
| 2 | Rim band r90–100 | Blocks | 46,46,52 |
| 3 | Invisible wall | 24 thin blocks at r 98, Transparency 1 | — |
| 4 | Heart pedestal | 28×3×28 block (octagon of blocks ok) | 42,36,64 |
| 5 | Heart crystal | 2 wedge stacks, 64 tall | 200,180,255, Neon |
| 6 | Spawn pad + SpawnLocation | 14×1×14 | 255,196,64 trim |
| 7 | Crackstone | 12×2×12 base + 3×9×3 crystal | 120,210,255 |
| 8 | Wren marker | 2×5×2 block | 255,255,255 |
| 9 | Gate pad | 16×1×16 + arch (3 blocks) 14w×18h | 255,196,64 / 180,140,255 |
| 10 | Kit Rack | 10×6×4 + 1×8×4 mirror | 108,226,154 |
| 11 | Muster ring | 4 sockets 3×0.5×3 | 200,180,255 |
| 12 | Return pad | 10×1×10 | 120,210,255 |
| 13 | Paths | 10-wide blocks, 0.1 above floor | 75,63,112 |
| 14 | Craters | 4 × 8×0.5×8 + 1 small wedge | 124,111,176 |
Prompts: Crackstone "Roll", Kit Rack "Bag", Gate pad touch zone (existing EnterPad logic).

**Art pass (later):** 1) Heart MeshPart (split crystal, ≤ 8k tris) + floating shard meshes (≤ 400 tris each) · 2) Crackstone mesh + Wren model · 3) Gate arch mesh with inner Neon swirl (Texture scroll) · 4) prismatic sky (Sky decals or high Beams) · 5) shard rain emitter + fall-event burst · 6) saturation ring re-color of floor tiles + rim fog emitter · 7) crater meshes · 8) Lighting: `Atmosphere` Density 0.32, Color 150,130,200, Decay 90,80,120, Haze 1.5; `Lighting.Ambient` 70,60,100; ClockTime fixed 18.5 (or keep day cycle — open question); `Bloom` Intensity 0.6, Threshold 1.6.

Roblox notes: everything is Parts/MeshParts, Lighting/Atmosphere, Sky, Beams and world ParticleEmitters. "Color draining" is per-part color, not a post effect (ColorCorrection is global and would gray the whole screen).

## 10. Pass criteria
- [ ] From spawn at 390×844 the Heart and Gate are visible; at 667×375 all of Heart, Crackstone, Gate.
- [ ] Spawn→Roll ≤ 10 s (target 2.2 s) and Roll→Gate ≤ 10 s (target 3.6 s), timed on foot.
- [ ] No world part blocks the spawn→Roll or Roll→Gate line.
- [ ] Performance budget table met (Studio MicroProfiler / stats on a phone emulator).
- [ ] No screen UI added; touch targets that exist stay ≥ 44 px.
- [ ] Theme reads in a screenshot: shattered crystal, falling shards, cracked sky, gray edge.

## 11. Open questions (Kevin)
1. Fixed evening time (ClockTime 18.5, best for the cracked sky) or keep the live day cycle?
2. Rename the Lumen Heart to "Sundered Heart" in-world, or keep the Lumen Heart name with the new look?
3. Muster Ring: gray-box it now (decor) so the space is reserved, or leave the spot empty until Phase 6?
