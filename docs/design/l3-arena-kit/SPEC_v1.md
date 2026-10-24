# L3 Arena Art Kit ("Shard Crater" gray-box kit), Spec v1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only, no code, no Config, no save edits). Builders: Ghost (world parts, client VFX), Echo (`WaveArena/Graybox` pieces + solids, only if a question below says so). Base: `cursor/live-build-9721`. Status: **v1, proposal.** Not an official Vision & Design Rules decision until Kevin approves it and it is copied there. **Art stays gray-box until Phase S**; Phase S notes are identity guidance only.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca388381e89200df4fe6fe8d29 (Oct 24, 2026 12:50Z, Kevin pre-approved), Next GO (2): "L3 arena art kit spec (90-stud arena, 3 gates, 2–3 low cover, no ceiling, part budget)."

**What this extends (link, don't copy):** L1 = Dungeon Look "Shard Crater" v1.1, PR #414 (`prism/dungeon-look`): theme, flow (wave start / clear / boss entrance), lighting, the Phase S phone budget (≤ 400 parts, ≤ 35k tris, ≤ 5 lights, ≤ 8 emitters, ≤ 4 beams). L4 = silhouette sheet, PR #446 (enemy sizes, "sharp points = player, flat broken stubs = the Hollow"). **L3 adds what L1 left loose:** a numbered piece list built on the **real** arena geometry, 2–3 low cover pieces (L1 had none), the gate back plate the live gray-box is missing, a gray-box part count vs. budget, and per-piece Roblox build notes. No duplicate branch exists (`prism/l3-*` checked; #414 is theme, not kit).

**Repo read (read only; repo wins over older spec numbers, Home rule 6):** `echo/merge-train` (PR #451, carries #382 + #422): `Shared/Config/WaveArenaConfig.luau`: `arena.diameter` **90** (`minDiameter` 90, Kevin-approved via Ghost Oct 24), `wallHeight` 14, `wallThickness` 4, `floorThickness` 2, `wallSegments` 48, origin (0, 240, 12000), gray-box colors floor 148,148,148 · wall 96,96,96 · gate 176,112,72 · post 72,72,72 · stand 120,132,120; `gates` count 3, width **18**, `facing` 90° (first gate faces +Z), posts 2×14×3 poking 1.5 into the disk; `spawn.boss` (0, 8); `player.start` (0, −18); `loot.pickupRadius` 12. `server/WaveArena/Graybox.luau`: floor cylinder Ø90 + **33** wall blocks (48 minus 5 per gate gap) + 3 gate pads (9.9×0.2×3 at r 39) + 6 posts + 1 center stand 4×4 = **44 parts**; inner (walkable) radius = 90/2 − 4 = **41** (Ø82); `Graybox.solids` feeds `Spawns.blocked` and `Round.spotBlocked`. **#422** `Config/Enemies.luau` hitboxes: chaser 2.6×3.4×2.6, ranged 2×2.8×2, tank 4.8×5.4×4.4, boss 7.5×9×7.

---

## 1. Goal
A modular arena kit that Ghost can drop onto the live 90-stud gray-box in one pass: the ring wall, 3 rift gates, 2–3 low cover pieces and an open sky, readable on a phone, inside the part budget, with the Shard Crater identity (prismatic shards, broken sky, color draining where the Hollow comes in) planned for Phase S but **built gray-box first**. Cover gives players something to kite around without hiding the hero, blocking a rift, or breaking spawn clearance.

## 2. Where it lives
- **World only:** the wave arena at `WaveArenaConfig.arena.origin` (0, 240, 12000), behind `LaunchGate.SHOW.waveArena` + `WaveArenaConfig.enabled` (both false). Hub (Crater Square, #413) untouched.
- **Pieces:** live `Graybox.pieces` stays the source of truth for floor / wall / posts / gate pads / stand. New kit pieces (cover, lintels, back plates, boss doors, drain fans, veins, sockets) are **requests**: Echo adds solids to `Graybox.pieces` (cover, back plates) because the server's spawn and pathing checks read `Graybox.solids`; purely visual pieces (lintels above 14, fans, veins, sockets) can live in a client/Studio folder with CanCollide/CanQuery/CanTouch false.
- **No UI.** The kit adds no screen UI; existing HUD, Wave HUD, results wings and toast lane are unchanged.
- **Not here:** enemy models (L4), wave VFX timing (L1 §3), boss telegraphs (#439), any Config number change, ceilings, roofs, props that need streaming.

## 3. Flow (what the kit does during a run)
1. **Arrive:** players appear at the start row around (0, −18) facing +Z (N rift). Sky open; all 3 rifts visible from the start at default zoom on 800×400 / 667×375; the N rift at least on 390×844.
2. **Wave start:** active rift back plates light (Phase S Neon inner plane; gray-box: color swap to the wave element via a client tween). Enemies spawn in the gate slots (`Spawns.place`) and walk the 3 lanes to the center; **cover never sits in a lane**.
3. **Fight:** players kite around the 2 cover slabs (NE, NW) and, if Q1 says so, the 3rd behind the start. Cover blocks bodies (players and enemies path around it) but **not shots** in V1 (no line-of-sight check, Q2).
4. **Hollow spread (identity):** each rift mouth has a gray "drain fan" on the floor. If Q5 = grow, the fans widen each wave (wave 1 → boss), so the arena visibly loses color as the Hollow pushes in; a clear washes them back.
5. **Boss (wave 5):** the N rift's 2 slab doors slide apart (L1 §3.5); the boss walks to `spawn.boss` (0, 8), which is clear of both cover pieces by > 15 studs.
6. **Run end:** no exit is added (no Leave rule). Rejoin lands on the hub pad (#382).

## 4. Layout
Mockup `mockups/01-arena-plan-topdown.svg`. Arena-local studs, origin = center, +Z = N rift. Angles are measured like the code (`x = cos a · r`, `z = sin a · r`).
| ID | Piece | Size (studs) | Position | Count | Solid? | Source |
|---|---|---|---|---|---|---|
| K1 | Floor disc | cylinder Ø90 × 2 | top at y 0 | 1 | floor | live |
| K2 | Wall ring segment | ≈ 5.9 × 14 × 4 | r 43, every 7.5°, minus 5 per gate | 33 | yes | live |
| K3 | Rift post | 2 × 14 × 3 | each side of a gate gap | 6 | yes | live |
| K4 | Gate pad (spawn mouth) | 9.9 × 0.2 × 3 | r 39 at 90° / 210° / 330° | 3 | no | live |
| K5 | Center stand (Impact Core marker) | 4 × 0.2 × 4 | (0, 0) | 1 | no | live |
| K6 | **Rift back plate** | 29 × 14 × 1 | r 44, closes each whole wall gap behind the posts (the wall gap is ≈ ±19°, wider than the 18-stud gate, so there are ≈ 3-stud slivers beside each post today) | 3 | **yes** (Q3) | new |
| K7 | Rift lintel | 22 × 2 × 3 | on the posts, y 14–16 → rift frame 18 w × 14 h | 3 | no (above reach) | new |
| K8 | Boss rift doors | 2 × (9 × 14 × 1) | N gate, between the posts at r 42, in front of K6; slide ±9 sideways on boss entrance | 2 | yes while closed | new (L1 §3.5) |
| K9 | **Low cover "fallen shard slab"** A / B | 8 × 2.5 × 2.5 slab + 2 end wedges 2 × 2.5 × 2.5 (total 12 long) | A at 30°, r 24 → (20.8, 12.0); B at 150°, r 24 → (−20.8, 12.0); long axis tangent | 2 × 3 parts | **yes** (Q2) | new |
| K9c | Low cover C (optional, Q1) | same | 270°, r 30 → (0, −30), behind the start row | 1 × 3 parts | yes | new |
| K10 | Drain fan (Hollow spread) | flat wedge plate, 0.05 thick, 10° → 24° wide, 6 → 14 deep | floor at each gate mouth, r 27–41 | 3 | no | new |
| K11 | Vein strips | 0.4 × 0.05 × 26 | 12 radial, r 6 → 32, skipping the 3 lanes ±4° | 12 (optional gray-box) | no | L1 |
| K12 | Start sockets | 2 × 0.1 × 2 | (−6/−2/2/6, −18) | 4 | no | new (replaces L1's z +30 sockets) |
| Sky | none (no ceiling) | — | `Sky` + `Atmosphere` in `Lighting` | — | — | — |

**Clearances (why these spots):**
- **Lanes:** each gate's lane runs from the pad to the center. Cover A/B sit midway between lanes at 30° / 150°, so each is **20.8 studs** from the two nearest lane lines (r · sin 60°). The 12-enemy spawn steps toward the center along the lane (`spawn.step` 2, `tries` 14 → up to 28 studs in), never near a slab.
- **Boss spot (0, 8)** (boss footprint radius 3.75–4): 21 studs to A or B. **Start (0, −18):** 31 studs to A/B, 12 to C.
- **Wall walkway:** A/B outer face at r ≈ 25.3 → **15.7 studs** to the inner wall (r 41); C at r 30 → 9.7 studs walkway behind it (Q1).
- **Height 2.5:** below the chaser (3.4) and every player rig (~5), so heads always show over cover at phone zoom (L4 ladder: a chaser head is ≥ 6 px above the slab at the far rift).

## 5. States
| Piece | Idle | Wave active | Boss | Clear | Wipe |
|---|---|---|---|---|---|
| K6 back plate | dark 22,16,31 | gray-box: element color (Ember #E84814 · Frost #5CD6FF · Void #C04888) via `Color` tween 0.4 s; Phase S: Neon inner plane 0 → 0.2 transparency | N: red-violet 255,90,110 | fades to dark | gray |
| K8 doors | closed | closed | slide open 1.0 s (Quad Out) | stay open until reset | — |
| K9 cover | gray-box 90,74,138 slab, 120,210,255 edge strip | unchanged | unchanged | edge strip flashes white 0.25 s with the veins | edge strip gray |
| K10 drain fans | hidden (transparency 1) | wave n: size step n (Q5) at Hollow gray 110,110,116, transparency 0.35 | max size | shrink to 0 over 1.5 s | stay at max, gray |
| K11 veins | 120,210,255 @0.7 | sweep (L1) | — | white flash | gray |

## 6. Numbers
**Gray-box part count (target ≤ 90):**
| Group | Parts |
|---|---|
| Live (K1–K5) | 44 |
| K6 back plates + K7 lintels + K8 doors | 3 + 3 + 2 = 8 |
| K9 cover A/B (+ C) | 6 (+3) |
| K10 drain fans | 3 |
| K11 veins (optional) | 12 |
| K12 sockets | 4 |
| **Total** | **77 without C / 80 with C** (65–68 without veins) |

**Phase S budget (from L1 #414, shared with enemies and players):** arena ≤ 400 parts/MeshParts, ≤ 35k triangles, ≤ 5 lights (center + 3 rifts + boss), Shadows off on lights, ≤ 8 ParticleEmitters (bursts by `:Emit()`, ≤ 300 live), ≤ 4 Beams. Kit split for Phase S: lip rock MeshParts (one per 2 wall segments, ~17) ≤ 12k tris · 18 leaning lip shards outside r 45 ≤ 6k · 3 rift frames ≤ 4.5k · 3 cover slabs ≤ 1.5k · floor 1 MeshPart + crack `Texture` ≤ 2k · veins/fans/sockets flat parts · headroom ≈ 9k for VFX parts. Physics: all decor `Anchored`, `CanQuery`/`CanTouch` false; only K1–K3, K6, K8, K9 collide. Collision fidelity `Box` on cover and lip MeshParts.
**Colors (gray-box):** keep the live Config gray-box colors for K1–K5; new pieces use L1's palette: back plate 22,16,31 · lintel/cover 90,74,138 · cover edge 120,210,255 · drain fan 110,110,116 (Hollow gray). Element colors from #435 V3 (Ember #E84814 · Frost #5CD6FF · Void #C04888). Rarity colors (`Rarities.COLOR`) are not used by the kit.
**Lighting (no ceiling):** `Lighting.Technology` as the live place; `Atmosphere` Density 0.38, Color 110,90,170, Haze 2 (L1); `Sky`: gray-box = default sky; Phase S = custom 6-face broken prismatic skybox (cracks with pink/cyan/white seams, darker than Crater Square). No ceiling part, no `Clouds` needed.

## 7. Edge cases
- **Walking out of a gate:** the live gray-box leaves the 3 gaps open (floor ends at r 45, then a 240-stud drop). K6 back plates close them. If the server sim already clamps the real character inside r 41, K6 is still needed so a Roblox character can't step past the clamp (Q3).
- **Spawn clearance:** cover must be in `Graybox.solids`, or `Spawns.place` / `Round.spotBlocked` could put an enemy inside a slab. A/B are > 20 studs from every lane, so today's slots don't move (Echo re-runs the 12-body clearance and 30 s pathing tests).
- **Stuck enemies:** a chaser pinned on a slab corner triggers the live 30 s stuck check (`stuck.seconds` 30, `teleportStuds` 16); end wedges round the slab ends to reduce this.
- **Camera:** low cover never needs camera occlusion handling (2.5 < camera height). The wall (14) and lintels (16) can block a zoomed-in camera at the rim; the live `Camera` room logic only handles the boss body, so Ghost checks rim zoom in Studio.
- **Boss doors in a party:** doors are server-owned solids; clients only see the tween. A player standing in the N mouth when doors open is not pushed (doors slide sideways along K6).
- **Reduced quality / low-end phone:** veins (K11) and fans (K10) are the first things to drop; part count falls to 65.
- **Hard (Lv 5):** same kit. No Hard-only geometry. Sky tint for Hard is off (Hard accent v1.1 Q3).

## 8. Mockups
SVG in `mockups/` (original art, fake data; PNG renders stay on the box):
- `01-arena-plan-topdown.svg`: real arena plan in studs (Ø90 wall ring, Ø82 walkable, 3 gates at 90° / 210° / 330°, lanes, cover A/B/C, boss spot, start row, drain fans, clearances).
- `02-kit-sheet.svg`: piece sheet (front elevations to scale with the 5-stud player and #422 hitboxes), gray-box part counts vs. the ≤ 90 target and the Phase S budget.
- `03-phone-read-check.svg`: camera-view sketches at 390×844 and 667×375 showing the hero and a chaser over 2.5-stud cover, rifts in view, no screen UI added; notes for 800×400 and desktop.

## 9. Build split
- **Echo (server, request):** add K6 back plates, K8 doors (while closed) and K9 cover to `Graybox.pieces` as solids with Config entries (sizes/angles in `WaveArenaConfig`, not hard-coded); re-run `WaveArena.spec` clearance (12-body wave, boss + 4 adds) and 30 s pathing; boss door open on boss entrance (server event).
- **Ghost (client/world):** visual pieces K7, K10–K12 in a client folder; color tweens for K6/K9/K10 on wave events; skybox + Atmosphere; Studio camera check at the 4 sizes.
- **Prism:** Phase S mesh briefs (lip rock, rift frame, cover slab, skybox) after M13; color check in Studio screenshots.
- **Havoc:** walk into every gate mouth; kite a 12-chaser wave around each slab for 60 s (stuck count); boss doors with a player in the mouth; low-end phone FPS with K10/K11 on and off.
- Build waits for M13 and for Ghost's go; art stays gray-box until Phase S.

## 10. Pass criteria (playtest)
1. Fresh tester at 390×844 can point at all 3 rifts and both cover pieces within 5 s of arriving.
2. Nobody can leave the floor through a gate (0 falls in 20 attempts).
3. 12-chaser wave kited around a slab for 60 s: 0 enemies spawn inside cover, ≤ 1 stuck-teleport per wave.
4. The hero's head and every chaser are visible over cover at default zoom at 390×844, 667×375, 800×400 and desktop.
5. Gray-box total ≤ 90 parts; low-end phone holds ≥ 30 FPS with 12 enemies + 4 players (L1 budget).
6. Testers describe the arena as "open sky / no roof" and, with Q5 = grow, notice "it gets grayer each wave."

## 11. Open questions (answer by number)
1. **@Ghost:** 2 cover slabs (NE, NW) for V1, with the 3rd (C, behind the start) only if M13 testers say there's nowhere to kite? **Recommended: 2 now, C after M13.**
2. **@Ghost (Echo):** Cover goes into `Graybox.pieces` as solids (spawns and pathing see it), and blocks bodies but not shots in V1 (no line-of-sight check)? **Recommended: yes.**
3. **@Ghost (Echo):** Add the K6 rift back plate (29 × 14 × 1, solid, r 44) behind each gate? The live gray-box leaves the 3 wall gaps open (the 18-stud gate plus ≈ 3-stud slivers beside each post) over a 240-stud drop. **Recommended: yes.**
4. **@Ghost:** Repo numbers win over L1 (#414): walkable Ø82 inside the Ø90 wall ring (L1 said lip Ø100), gates 18 w × 14 h (L1 said 16 × 20), start row at (0, −18) (L1 said sockets at z +30)? Prism then updates #414 to match. **Recommended: yes.**
5. **@Kevin (taste):** Hollow color drain: the gray fans at the rift mouths **grow each wave** (6 → 14 studs deep, washed back on clear), or stay a fixed size? **Recommended: grow.** It tells "the Hollow spreads" with one tween and no new parts.
6. **@Kevin (taste):** Cover look: **fallen prismatic shard slabs** (player-side: sharp tips, cyan edge) or Hollow-gray broken rock (flat stubs)? **Recommended: prismatic shard slabs**, so cover reads as "ours" against the gray drain.

## Decision log
- 2026-10-24 (Prism): v1 on `prism/l3-arena-kit`, built on the live #382 gray-box (via #451), L1 #414 and L4 #446. 2 + 1 optional low cover, rift back plates, boss doors, drain fans, no ceiling; gray-box 77–80 parts. Open: Ghost 1–4, Kevin 5–6. Not approved.

## Later (not V1)
Destructible cover, cover that blocks shots, jump pads, height levels, rotating arena variants per element, a second arena shape. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox only: `Part` (Block, Wedge, Cylinder), `MeshPart` (Phase S), `Texture`/`Decal`, `Beam`, `ParticleEmitter`, `PointLight` (≤ 5, Shadows false), `Sky`, `Atmosphere`, TweenService. **No screen UI is added**; if a later pass adds any, it follows Frames/ImageLabels + `UICorner` / `UIStroke` / `UIGradient`, ≥ 44 px targets, collapse, off the center. No blur, no post effects beyond Bloom/Exposure (L1), no SurfaceAppearance on phone-critical pieces, no transparency-heavy Glass on cover.
| Piece | Instances |
|---|---|
| K6 back plate | `Part` Block 29×14×1, Anchored, CanCollide true, Material SmoothPlastic, Color 22,16,31; Phase S: child Neon `Part` 16×12×0.2 (Transparency 1 → 0.2 on wave start, `TweenInfo` 0.4 Quad Out) |
| K7 lintel | `Part` Block 22×2×3, Anchored, CanCollide false, CanQuery false |
| K8 doors | 2 `Part` 9×14×1, Anchored; open = `TweenService` CFrame ±9 studs sideways, 1.0 s Quad Out; server toggles CanCollide false at the end |
| K9 cover | `Model` (PrimaryPart = slab): slab `Part` 8×2.5×2.5 + 2 `WedgePart` 2×2.5×2.5 (rotated so the slope faces out) + cyan edge `Part` 12×0.15×0.15 Neon (Phase S) on the top outer edge; all Anchored |
| K10 drain fan | `Part` 0.05 thick (Wedge pair or a flat `MeshPart` fan in Phase S), CanCollide/CanQuery/CanTouch false, Color 110,110,116, Transparency 0.35; size tween per wave (Q5), 0.6 s |
| K11 veins | `Part` 0.4×0.05×26, Material Neon (Phase S) / SmoothPlastic (gray-box), Transparency 0.7 |
| Sky | `Lighting.Sky` (SkyboxBk/Dn/Ft/Lf/Rt/Up = 6 × 1024² PNG, Phase S) + `Atmosphere`; no ceiling part |
| Wave FX | reuse L1 emitters; arena total ≤ 8 `ParticleEmitter`, `Rate` 0 + `:Emit()` only |

Image assets (Phase S, PNG): skybox_broken_prism ×6 (1024×1024), floor_cracks_512 (tileable `Texture`, StudsPerTile 16), drain_fan_256 (optional Decal with a soft edge). Gray-box needs none.
