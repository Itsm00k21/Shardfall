# L4 Enemy + Boss Silhouette Sheet, Spec v1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only, no code, no config edits). Builders: Ghost (meshes / gray-box models, client VFX), Echo (Config sizes, only if a question below says so). Base: `cursor/live-build-9721`. Status: **v1, proposal.** Not an official Vision & Design Rules decision until Kevin approves it and it is copied there.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca3883812fa966d50ee503d110 (11:55Z Oct 24, 2026, Kevin pre-approved): "L4 enemy + boss silhouette sheet v1 (chaser, ranged, tank, boss read by shape alone at phone zoom; extend L1's enemy look sheet, don't duplicate)."

**What this extends (link, don't copy):** L1 = Dungeon Look "Shard Crater" v1.1, PR #414 (`prism/dungeon-look`), `docs/design/dungeon-look/SPEC_v1.md` §8 "Enemy look sheet" + `mockups/03-enemy-look-sheet.svg`. L1 already fixed the role list, the placeholder names (Shardling, Prism Wisp, Bulwark, Hollow Warden; kept by Ghost Oct 23), and the rule "body is dark ink, element only on trim, eyes and particles". **L4 adds what L1 left loose:** exact silhouette features per type, sizes locked to the real Config hitboxes, a phone-zoom pixel ladder, a squint/size test, a crowd test, pass/fail numbers, and Roblox build notes per model.

Sources (read only):
- Repo `cursor/live-build-9721`: the live crawl still runs Rootvault roles (`Shared/Rootvault.luau` `ROLES`: grunt `vine_crawler`, charger `thorn_sprite`, caster `spore_bat`, shielder `root_brute`, mender `moss_crawler`) and the boss `grandmother_gnarl` (`Shared/Dungeons.luau`, size 8×9×7). `Shared/EnemyAbilities.luau` (`SHIELDER` front arc 120°, `MENDER`).
- **V1 wave roster (Echo PR #422, `echo/dungeon-enemy-pool` @ `0549c8d`, not merged):** `Shared/Config/Enemies.luau` `ORDER = chaser, ranged, tank`; hitboxes chaser **2.6×3.4×2.6**, ranged **2×2.8×2**, tank **4.8×5.4×4.4**, `BOSS` **7.5×9×7**; `WAVE_MIXES` (wave 4 = 6 chaser · 4 ranged · 2 tank); `BOSS_ADD_MIX` = 2 chaser · 1 ranged · 1 tank; behind `LaunchGate.SHOW.enemyTypes = false`.
- Notion: Shardfall Home rules, Vision & Design Rules (locked numbers: waves 6/8/10/12, wave 5 = boss + 4 adds), Style Bible v0 rev 2 (PR #424, https://app.notion.com/p/403c31ca388381879bddecc103464360): §4 glow budgets, §6 mobile readability ("a gray screenshot must still show what to hit"), §7 identity ("sharp points = player; flat broken stubs = the Hollow").
- Specs: #438 element glow read v1.1 (outline-led glow, Highlight budgets), #439 boss telegraphs v1.1 (volley 0.9 s / slam 1.2 s), #420 phone layout review (keep-outs), #435 / #428 element colors.

## 1. Goal
At phone zoom, a new player names **chaser, ranged, tank, boss** from **shape alone** (pure black, no color, no name plate) in under a second, including in a mixed wave of 12 and at the far rift. Color then adds the element (second read), never the role.

## 2. Where it lives
- World models only: the 3 V1 wave enemy types and the wave-5 boss + 4 adds in the Shard Crater arena (L1 / #414). Gray-box first (Parts sized to Config), art pass later (MeshParts per this sheet, Phase S).
- Not here: enemy HP bars / pips (Ghost UI, #438), telegraph shapes (#439), names (L1), new enemy types, any Config number change.
- Live crawl mapping (until `enemyTypes` is on): `vine_crawler` / `thorn_sprite` → chaser silhouette · `spore_bat` → ranged · `root_brute` (shielder) → tank (its front shield already matches the slab) · `grandmother_gnarl` → boss · `moss_crawler` (mender) → no V1 silhouette (not in `Enemies.ORDER`); see Later.

## 3. Flow (how a player reads a wave)
1. **Spawn (0–0.8 s, L1 wave start):** enemies step out of a rift. First read = **size step** (tiny / small / big / huge).
2. **Approach (mid range, ~10 px/stud):** second read = **the one unique feature** per type (spike comb, ring + gap, slab, halo + wings). This must work in pure black.
3. **Engage:** third read = element trim color + the HP-bar pip (#438). Role never depends on it.
4. **Boss wave:** the boss reads first by height (2.6× a chaser) and the only symmetric, haloed outline; the 4 adds read as the same 3 types they always were.
5. **Death:** model breaks into flat shard stubs (Hollow language) and fades 0.4 s; no silhouette lingers to confuse the count.

## 4. Layout (silhouette keys; side view facing right; all inside the Config hitbox)
Mockup `mockups/01-silhouette-sheet.svg` (dashed = hitbox).
| Type (L1 name) | Hitbox w × h (studs) | Unique feature (must survive pure black) | Supporting features | Never |
|---|---|---|---|---|
| **Chaser** (Shardling) | 2.6 × 3.4 | **Forward lean:** head/nose low and forward, back high; **3-spike back comb** leaning backward | Leg gap (negative space under the body), eye on the nose | Upright pose, vertical spikes, a round blob |
| **Ranged** (Prism Wisp) | 2 × 2.8 | **Floats:** body is a diamond in the top 1.55 studs; **empty gap** under it to the floor + a ground shadow disc | **Flat ring** through the diamond's middle, full hitbox width (2 st) | Touching the floor, legs, a ring that tilts more than 15° |
| **Tank** (Bulwark) | 4.8 × 5.4 | **Widest + flat top** body and a **tall slab shield** on its front side that is the tallest part | Short thick legs with a gap, broken-stub shoulders | Points on top, a round shield, a shield narrower than 1.3 st |
| **Boss** (Hollow Warden) | 7.5 × 9 | **Tallest, only symmetric outline:** robed spire + **broken halo** (arc with a gap) above + 2 **shard wings** angled up and out | Wings reach the hitbox edge (±3.75 st); eye at the head | A halo that closes into a ring (reads as a ranged ring), wings that droop |

**Shape language (Style Bible §7):** every enemy spike and wing ends in a **flat broken tip** (clipped, never a sharp point). Sharp points stay the player's (weapons, shards, VFX). This is the one rule that makes "Hollow" read on every enemy.
**Silhouette distinctness check:** no two types share both size step and outline family: chaser (small, diagonal), ranged (small, floating diamond + horizontal line), tank (big, rectangles), boss (huge, triangle + arc).

## 5. States
| State | Silhouette | Trim / VFX |
|---|---|---|
| Idle / walk | as §4 | element trim at 0.2 Transparency |
| Attack windup | chaser crouches 10% lower (Motor6D / CFrame tween), tank raises shield 0.3 st, ranged ring spins 2×, boss per #439 | trim to 0 Transparency (brighter) |
| Hit | no shape change (a 0.08 s white trim flash only) | — |
| Shield block (tank front arc, `SHIELDER.frontDot = 0.5`) | slab stays; 6-dot spark burst on the slab face | "Blocked. Flank the brute." toast stays as live |
| Boss entrance (L1 §3.5) | slabs open, Warden walks out | red-violet Highlight during entrance only (L1); see Q3 |
| Death | break into 3–5 flat stub shards, fade 0.4 s | trim off at once; Highlight destroyed (#438) |
| Element glow over budget (#438) | unchanged | warm Rim + pip, or pip only |

## 6. Numbers
- **Hitboxes = Config** (`Config/Enemies.luau`, PR #422): meshes stay inside them; the server never reads mesh size. Repo wins if L1's older 3/4/7/14-stud art heights disagree (Home rule 6); this spec **replaces L1's heights for the art pass**, no Config change.
- **Phone-zoom pixel ladder** (390×844 portrait, default camera; desktop reads larger at ~12–16 px/stud):
| Type | Height (st) | near ~14 px/st | mid ~10 px/st | far rift ~5 px/st |
|---|---|---|---|---|
| Chaser | 3.4 | 48 px | 34 px | 17 px |
| Ranged | 2.8 | 39 px (body 22) | 28 px (body 16) | 14 px (body 8) |
| Tank | 5.4 | 76 px | 54 px | 27 px |
| Boss | 9.0 | 126 px | 90 px | 45 px |
- Minimum feature sizes at **mid** range: spike comb ≥ 6 px tall each, ring ≥ 20 px wide × 2 px, ranged gap ≥ 10 px, shield slab ≥ 13 px wide and ≥ 4 px taller than the body, halo gap ≥ 30° of arc.
- Per-enemy budget (L1 §6): ≤ 12 parts / ≤ 1.5k tris; boss ≤ 40 parts / 6k tris. Max wave 12 + boss wave 5 bodies.

## 7. Edge cases
- **Ranged at far range is the weakest read** (body 8 px, mockup 02 box C/D). Rule: the ground shadow disc is always on (it carries "floats" when the diamond is tiny); Q2 asks whether to also widen the visual ring to 2.4 st; that pokes 0.2 st out of each side of the 2-st hitbox (mesh only, hit detection unchanged).
- **Crowds overlap** (wave 4 = 12): silhouettes overlap at mid range (mockup 02 crowd box). The size step + the tank's slab still read; chasers become a "spiky carpet", which is fine (they are the trash).
- **Facing:** every type must read from front, side and back. Chaser comb and tank slab are visible from the back too (comb sticks up, slab is taller than the body). Ranged and boss are symmetric.
- **Element-mixed wave:** shape never changes with element; only trim, eye and particles.
- **Hard tier:** no shape or size change (Hard = HUD-only accent, Style Bible §5).
- **Reduced motion / low quality:** idle bob and ring spin off; silhouettes unchanged.
- **Highlight cap:** Roblox renders at most 31 Highlights; the #438 ceiling is 18 enemies. Silhouette read must never depend on a Highlight (it can be off).
- **Live crawl (flag off):** Rootvault kinds keep today's models until `enemyTypes` ships; the mapping in §2 is for the art pass only.

## 8. Mockups
SVG in `mockups/` (fake data, original shapes, pure black on gray):
- `01-silhouette-sheet.svg`: the 4 keys at design scale inside their dashed Config hitboxes · the phone-zoom ladder (near / mid / far px) · the element trim row (Ember #E84814 / Frost #5CD6FF / Void #C04888, outlines 45% toward white per #438).
- `02-squint-size-test.svg`: 4 boxes (mid sharp, mid squint, far sharp, far squint), the size ladder, a wave-4 crowd test and the boss wave (boss + 2 chaser · 1 ranged · 1 tank). The blur in the squint boxes is a review tool only, not an in-game effect.
- `03-in-frame-read.svg`: one wave at true scale in 390×844, 667×375, 800×400 and desktop frames with the #420 center keep-out drawn (world enemies may stand in it; UI may not).
PNG renders are on the box only.

## 9. Build split
- **Ghost (gray box, now, flag off):** per type, a block model at the Config hitbox with the unique feature blocked in: chaser = wedge body + 3 WedgeParts for the comb; ranged = rotated block diamond + thin Cylinder ring + floor shadow Part; tank = block body + tall slab Part; boss = WedgePart robe + 2 wing wedges + a 3/4 ring of small Parts for the halo. Trim = Neon Parts in the element color.
- **Ghost (art pass, Phase S):** MeshParts per §4, inside the hitbox, flat-tipped spikes, ≤ budget. Element particles per L1 (ember sparks, snow motes, dark swirl) recolored to the new hexes.
- **Echo:** nothing required. Only if Kevin/Ghost pick Q2 "visual ring 2.4 st" is there anything to check (mesh outside hitbox, hit detection unchanged).
- **Havoc / M13 testers:** run §10 with the mockup 02 sheet on a phone at full brightness and at 50% brightness.

## 10. Pass criteria
- [ ] Pure-black sheet (mockup 02) on a 390×844 phone: testers name all 4 types in boxes A and C (4/4) and ≥ 3/4 in the squint boxes B and D.
- [ ] Boss never called a tank; ranged never called a chaser (0 confusions in 5 testers).
- [ ] In a live wave-4 crowd at default zoom, testers point to "the tank" and "a ranged one" within 1 s.
- [ ] Grayscale screenshot of a live wave still shows which type is which (Style Bible §6).
- [ ] Every model stays inside its Config hitbox (Studio bounding-box check) and inside the per-enemy part/tri budget.
- [ ] Element read: testers name Ember / Frost / Void on 3/3 types (second read, after shape).
- **Fail fix order:** grow the unique feature first, then the size step, never color.

## 11. Open questions (answer by number)
1. **@Kevin (taste):** Flat broken tips on every enemy spike (Style Bible §7 "flat broken stubs = the Hollow") instead of L1's pointed spikes. Recommended: yes, flat tips; sharp points stay the player's.
2. **@Ghost:** Ranged far-range read: keep the ring at the 2-st hitbox width + always-on shadow disc (rec), or let the visual ring poke out to 2.4 st (mesh only, hitbox unchanged)? Recommended: hitbox width + shadow first; revisit only if §10 fails.
3. **@Ghost:** Boss outline color. L1 says a red-violet Highlight during the entrance only; Style Bible §4 says "boss keeps its own gold look". Recommended: red-violet Highlight **only** for the 4.5 s entrance, then the boss uses the normal element glow rules like any enemy (gold stays for rewards).
4. **@Kevin (taste):** The boss's shard wings angle **up** (reads as threat, mockup 01). Alternative: wings folded down like a cloak (calmer, less readable). Recommended: up.
5. **@Ghost:** L1 heights (chaser 3 / ranged 4 / tank 7 / boss 14 studs) vs Config (3.4 / 2.8 / 5.4 / 9). This spec follows Config (repo wins). OK to mark L1's numbers superseded in #414's next fold? Recommended: yes.

## Decision log
- 2026-10-23 (Ghost, Kevin pre-approved, via L1 #414): roles chaser / ranged / tank / boss; names Shardling, Prism Wisp, Bulwark, Hollow Warden kept; body dark ink, element on trim.
- 2026-10-24 (Ghost GO 11:55Z, Kevin pre-approved for Prism to write it; Prism): **L4 v1** silhouette keys, Config-locked sizes, phone ladder, squint/size + crowd tests, pass criteria. Not approved as a Vision & Design Rules decision.

## Later (not V1)
Mender silhouette (live `moss_crawler`; proposal: a low flat dome with one tall sprout, the only enemy with a vertical "antenna"), elite variants, per-realm reskins. All go to the Ideas Backlog marked NOT APPROVED.

## Roblox build notes
- **Geometry carries the read.** Parts / WedgeParts / Cylinders for gray box; MeshParts (≤ 1.5k tris, boss ≤ 6k) for art. `CastShadow` false on trim Neon parts; body `Material` SmoothPlastic or Slate, `Color` ink 22,16,31 (L1). Collision: the server hitbox Part stays the Config size; the visual mesh is welded (`WeldConstraint`) with `CanCollide`/`CanQuery`/`CanTouch` false.
- **Highlight limits:** Roblox renders at most 31 `Highlight`s at once; #438 caps enemies at 18 and ≤ 1 per alive enemy (destroy on death). `Highlight.OutlineTransparency` 0 with outline = element color 45% toward white; `FillTransparency` 0.5. The silhouette must read with **no** Highlight (budget overflow drops to warm Rim + pip, or pip only).
- **Element trim:** small `Neon` Parts on spike tips / eye / ring / shield rim / halo, `Color` = `Color3.fromHex("#E84814")` Ember · `("#5CD6FF")` Frost · `("#C04888")` Void, read from Config, never hard-coded. One `PointLight` ground pool per #438 budget (4 touch / 12 desktop), `Shadows` false.
- **ParticleEmitters:** one per enemy max (element motes, `Rate` ≤ 6, `LightEmission` 0.5); bursts via `:Emit()` on hit/death (≤ 12 particles); arena live cap ≤ 300 (L1 §6).
- **Ranged shadow disc:** a 0.05-st-thick Cylinder Part (black, Transparency 0.6, `CastShadow` false) raycast-snapped to the floor; do not rely on real shadows (arena lights have `Shadows` false).
- **Motion:** idle bob / ring spin / windup crouch via `TweenService` or `Motor6D`; no skinned-mesh requirement for V1.
- **Not used:** SurfaceAppearance-only reads, post effects, `BlurEffect`, custom shaders, beams as silhouette parts. Rarity colors (`Rarities.COLOR`) never go on enemies; they stay on loot motes (L1 §5).
