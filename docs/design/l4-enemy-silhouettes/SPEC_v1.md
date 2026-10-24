# L4 Enemy + Boss Silhouette Sheet, Spec v1.2 (NOT APPROVED, docs only)

Owner: Prism (design, docs only, no code, no config edits). Builders: Ghost (meshes / gray-box models, client VFX), Echo (Config sizes, only if a question below says so). Base: `cursor/live-build-9721`. Status: **v1.2, proposal; Ghost closed Q6, Q7, Q10, Q11.** Not an official Vision & Design Rules decision until Kevin approves it and it is copied there.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca3883812fa966d50ee503d110 (11:55Z Oct 24, 2026, Kevin pre-approved): "L4 enemy + boss silhouette sheet v1 (chaser, ranged, tank, boss read by shape alone at phone zoom; extend L1's enemy look sheet, don't duplicate)."
v1.1 asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca388381818692c13be76248b2 (Oct 24, 2026, Kevin pre-approved): "part budgets, element glow from Elements (#432), and how they sit with the existing hit flash/death puff (#382). Build on your L1 look sheet and the L3 kit (#452)." Folded here (ACK https://app.notion.com/p/403c31ca388381bf9d11f641547b5ccf) instead of a new branch / duplicate PR.

**Changelog**
- v1.2 (2026-10-24): Ghost's DP29 rulings folded (board row https://app.notion.com/p/403c31ca3883816cbc9cc827b26d3c96, ACK https://app.notion.com/p/403c31ca388381bda15dc237843e114b, Kevin pre-approved): **Q6 closed, glow `fillTransparency` 0.5** (outline stays 0); **Q7 closed, `ElementGlowLight` capped to the 4 nearest enemies** on touch (12 desktop per #438); **Q10 closed, gray-box enemies use their #422 hitbox sizes** (chaser 2.6×3.4×2.6, ranged 2×2.8×2, tank 4.8×5.4×4.4); **Q11 closed, death puff = hitbox width ×1.15** (chaser 3, ranged 2.3, tank 5.5; 0.45 s, same color; boss keeps the hold). §4b, §5, §6a, §10 and build notes updated. Kevin taste Q1, Q4 and Ghost Q2, Q3, Q5, Q8, Q9, Q12 stay open.
- v1.1 (2026-10-24): §4b element glow rules from the real #432 `Config/Elements` data (read from Config; #432 ships Ember 255,112,36 / Void 196,92,255, and Echo's held follow-up moves them to #435's #E84814 / #C04888 after #432 merges, so both sets are checked); §5 hit flash / death puff / Remains rows from #382 `WaveArena/Feel` + `WaveArenaConfig.feel`; §6 per-enemy part / triangle / instance budgets (chaser, ranged, tank, boss, boss adds, wave peaks); §6b placement and contrast against the L3 kit (#452) back plates, cover and palette; §7 new edge cases; Q6–Q12 added; Roblox build notes for the flash and puff.
- v1 (2026-10-24): silhouette keys, Config-locked sizes, phone ladder, squint/size + crowd tests, pass criteria.

**What this extends (link, don't copy):** L1 = Dungeon Look "Shard Crater" v1.1, PR #414 (`prism/dungeon-look`), `docs/design/dungeon-look/SPEC_v1.md` §8 "Enemy look sheet" + `mockups/03-enemy-look-sheet.svg`. L1 already fixed the role list, the placeholder names (Shardling, Prism Wisp, Bulwark, Hollow Warden; kept by Ghost Oct 23), and the rule "body is dark ink, element only on trim, eyes and particles". **L4 adds what L1 left loose:** exact silhouette features per type, sizes locked to the real Config hitboxes, a phone-zoom pixel ladder, a squint/size test, a crowd test, pass/fail numbers, and Roblox build notes per model.

Sources (read only):
- Repo `cursor/live-build-9721`: the live crawl still runs Rootvault roles (`Shared/Rootvault.luau` `ROLES`: grunt `vine_crawler`, charger `thorn_sprite`, caster `spore_bat`, shielder `root_brute`, mender `moss_crawler`) and the boss `grandmother_gnarl` (`Shared/Dungeons.luau`, size 8×9×7). `Shared/EnemyAbilities.luau` (`SHIELDER` front arc 120°, `MENDER`).
- **V1 wave roster (Echo PR #422, `echo/dungeon-enemy-pool` @ `0549c8d`, not merged):** `Shared/Config/Enemies.luau` `ORDER = chaser, ranged, tank`; hitboxes chaser **2.6×3.4×2.6**, ranged **2×2.8×2**, tank **4.8×5.4×4.4**, `BOSS` **7.5×9×7**; `WAVE_MIXES` (wave 4 = 6 chaser · 4 ranged · 2 tank); `BOSS_ADD_MIX` = 2 chaser · 1 ranged · 1 tank; behind `LaunchGate.SHOW.enemyTypes = false`.
- Notion: Shardfall Home rules, Vision & Design Rules (locked numbers: waves 6/8/10/12, wave 5 = boss + 4 adds), Style Bible v0 rev 2 (PR #424, https://app.notion.com/p/403c31ca388381879bddecc103464360): §4 glow budgets, §6 mobile readability ("a gray screenshot must still show what to hit"), §7 identity ("sharp points = player; flat broken stubs = the Hollow").
- Specs: #438 element glow read v1.1 (outline-led glow, Highlight budgets), #439 boss telegraphs v1.1 (volley 0.9 s / slam 1.2 s), #420 phone layout review (keep-outs), #435 / #428 element colors.
- **v1.1 repo reads (read only, PRs open, not merged):**
  - **#432** (`echo/element-glow` @ `06f078f`): `Shared/Config/Elements.luau` `LIST.ember.color` **255,112,36** · `frost.color` **92,214,255** · `void.color` **196,92,255**; `Elements.GLOW` = `{ name "ElementGlow", lightName "ElementGlowLight", fillTransparency 0.28, outlineTransparency 0, lightBrightness 3, lightRange 22, depthMode "AlwaysOnTop" }`. `Shared/ElementGlow.luau`: `assign(spawnIndex)` cycles `Elements.ORDER` by spawn order; `visual()` / `forEnemy()` return nil when `LaunchGate.SHOW.elementGlow` (false) is off; `detach()` destroys the Highlight + PointLight on death ("so a corpse does not hold a slot in the 31 cap"). `DungeonService.applyElementGlow` parents one `Highlight` (fill + outline = element color) on the rim host, **disables the warm `Rim` Highlight** while it draws, and adds one `PointLight` (Shadows false) per enemy. `ConfigValidation.spec`: fill ≤ 0.55, outline ≤ 0.1, each color peak ≥ 200, colors unique, `lightRange ≥ Dungeons.CAMERA_MAX_ZOOM` (18).
  - **#382** (`echo/3-wave-arena` @ `33be240`): `server/WaveArena/Feel.luau` emits `hitFlash` / `deathPuff` events; `WaveArenaConfig.feel` = `hitFlash 0.08`, `deathPuff 0.45`, `flashColor 255,255,255`, `puffColor 210,206,196`; boss uses `boss.deathHold 1.5` instead of a puff. `WaveArenaHost` today: flash = sets `Enemy_<id>` `BasePart.Color` to white for 0.08 s; puff = an anchored Ball `Part` 3×3×3, 210,206,196, Transparency 0.3, at y + 1.5, destroyed after 0.45 s. Gray-box profiles `WaveArenaConfig.chaser/ranged/tank` (and adds) are all **3.2×2.2×4.2**; boss 8×9×7.
  - **#452** L3 arena kit v1 (`prism/l3-arena-kit` @ `092face`): K6 rift back plate 29×14×1 dark 22,16,31 (wave-start tint to the element), K9 cover 8×2.5×2.5 slab 90,74,138 + 120,210,255 edge, K10 drain fans 110,110,116, live floor 148,148,148 · wall 96,96,96, Atmosphere 110,90,170.

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

### 4b. Element glow (v1.1, from #432 `Config/Elements`; second read, never the role)
| Element (`Elements.LIST`) | `color` (RGB) | Hex | Where it shows on the enemy | Read rule |
|---|---|---|---|---|
| `ember` "Ember" | 255,112,36 | #FF7024 | Highlight fill + outline, `ElementGlowLight` pool; trim Neon (spike tips / eye / ring / slab rim / halo) | warm orange; must stay apart from the boss-entrance red-violet 255,90,110 and from Legendary gold (rarity colors never on enemies) |
| `frost` "Frost" | 92,214,255 | #5CD6FF | same | closest to the L1 vein / cover edge cyan 120,210,255: enemy outline must sit in front of a darker surface (§6b) |
| `void` "Void" | 196,92,255 | #C45CFF | same | closest to the cover / lintel purple 90,74,138: reads by brightness (peak 255 vs 138) |
- **Colors come from Config, never hard-coded.** `Color3.fromRGB(table.unpack(Elements.LIST[id].color))`. **Two color sets are in flight:** #432 ships Ember 255,112,36 / Void 196,92,255 (above); Echo holds a follow-up Config/Elements PR that moves them to #435's **#E84814 (232,72,20)** / **#C04888 (192,72,136)** after #432 merges (Shardfall Home, Echo 5:30 AM PT). Frost is #5CD6FF in both. Every rule here reads Config, so either set works; the §6b plate tints are given for both. Note: #C04888's peak channel is 192, under #432's `ConfigValidation` "peak ≥ 200" phone check (Q12). Mockup 01's trim row shows the #435 set.
- **Assignment:** element follows spawn order (`ElementGlow.assign`, cycling `Elements.ORDER`), not type. So any type can be any element; the silhouette carries the role and the glow only says the element (matches §3 step 3).
- **What #432 actually draws vs. L1/L4's "dark ink body, element on trim":** `fillTransparency 0.28` tints the **whole body** ~72% toward the element color, and `AlwaysOnTop` draws it through walls and cover. The shape still reads (a filled color silhouette is a silhouette), but the "ink body" look is lost while the flag is on. L4 v1.1 rule: **the outline carries the element; the fill is a strength knob.** **v1.2 (Q6 closed): `fillTransparency` = 0.5** (inside the spec test's ≤ 0.55), so the body stays mostly ink and the hit flash shows (§5); builder change is one value in `Elements.GLOW` (Echo).
- **One glow Highlight per enemy, Rim off while it draws** (live `applyElementGlow`). Flag off or over the Highlight budget → the warm `Rim` (Dungeons.RIM) is the fallback; an enemy is **never** shown with neither (see §6b back plate).
- **Lights:** #432 adds one `ElementGlowLight` per enemy (Brightness 3, Range 22, Shadows false). A wave-4 crowd = 12 lights + the L1/L3 arena's 5. **v1.2 (Q7 closed): cap at the 4 nearest enemies to the local camera on touch** (12 desktop, #438); re-pick nearest at most every 0.5 s; enemies past the cap keep their Highlight, no light.
- **Boss:** same rules as any enemy after its entrance (v1 Q3). Its trim Neon and Highlight use its spawn-assigned element; the red-violet entrance Highlight replaces the glow only during the 4.5 s entrance, then `forEnemy` glow takes over.

## 5. States
| State | Silhouette | Trim / VFX |
|---|---|---|
| Idle / walk | as §4 | element trim at 0.2 Transparency |
| Attack windup | chaser crouches 10% lower (Motor6D / CFrame tween), tank raises shield 0.3 st, ranged ring spins 2×, boss per #439 | trim to 0 Transparency (brighter) |
| Hit (v1.1, #382 `hitFlash`) | no shape change | `WaveArenaConfig.feel.hitFlash` **0.08 s** in `flashColor` 255,255,255. With the #432 glow on, the flash is drawn on the **glow Highlight** (FillColor → white, FillTransparency → 0 for 0.08 s, then back) because the glow fill (0.5 in v1.2; 0.28 in #432) hides most of a body `Color` swap; trim Neon also goes white. Glow off: body + trim parts go white (today's `BasePart.Color` swap, applied to every visual part, not only the hitbox) |
| Hit spam (party of 4) | — | one flash per enemy at a time: a new hit while flashing **restarts** the 0.08 s, never stacks; ≥ 0.05 s off between flashes so it blinks, not glows white |
| Shield block (tank front arc, `SHIELDER.frontDot = 0.5`) | slab stays; 6-dot spark burst on the slab face | "Blocked. Flank the brute." toast stays as live |
| Boss entrance (L1 §3.5) | slabs open, Warden walks out | red-violet Highlight during entrance only (L1); see Q3 |
| Death (small enemies + adds) | break into 3–5 flat stub shards, fade **0.4 s**, all inside the #382 `deathPuff` (Ball, 210,206,196, Transparency 0.3, **0.45 s**; v1.2 size = hitbox width ×1.15: chaser 3, ranged 2.3, tank 5.5, Q11 closed) so the puff hides the break and nothing lingers | trim off at once; glow Highlight + `ElementGlowLight` destroyed at once (`ElementGlow.detach`) |
| Death (boss) | no puff (#382): over `boss.deathHold` **1.5 s** the halo arc drops, the wings fold down, the robe sinks 30%; then the results card | Highlight destroyed at the kill; trim fades over the hold |
| Remains (live crawl, `DungeonService`) | the rig stays until the next wave: it must **not** keep a readable silhouette. Rule: Remains go Hollow gray 110,110,116, Transparency 0.5, scaled to 60% height, no trim (Q9) | no Highlight, no light |
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

### 6a. Part / triangle budgets per enemy (v1.1)
Counts include the server hitbox Part. "Gray box" = Parts only (now); "art" = Phase S MeshParts. Instances per enemy: **≤ 1 Highlight** (glow or Rim), **≤ 1 PointLight**, and only the 4 nearest enemies carry one on touch (Q7 closed v1.2), **≤ 1 ParticleEmitter** (motes, `Rate` ≤ 6; hit/death bursts via `:Emit()`).
| Type | Gray-box parts (what) | Art parts | Art tris | Neon trim parts |
|---|---|---|---|---|
| **Chaser** | **8**: hitbox, body Wedge, 3 comb Wedges, 2 legs, eye | **4**: hitbox, body MeshPart, trim MeshPart (comb tips + eye), legs MeshPart | **≤ 1.2k** | 1 (art) / 4 (gray box: 3 tips + eye) |
| **Ranged** | **5**: hitbox, diamond Block (rotated), ring Cylinder, eye, shadow disc Cylinder | **4**: hitbox, diamond MeshPart, ring MeshPart (Neon), shadow disc Part | **≤ 0.8k** | 1 (ring) |
| **Tank** | **9**: hitbox, body Block, slab Block, slab rim Neon, 2 legs, 2 shoulder stubs, eye | **5**: hitbox, body MeshPart, slab MeshPart, slab-rim Neon MeshPart, legs MeshPart | **≤ 1.5k** | 1–2 |
| **Boss** | **18**: hitbox, robe Wedge pair (2), head, eye, 4 wing Wedges (2 per wing), 8 halo arc Parts, 1 base plate | **≤ 12**: hitbox, robe, head, 2 wings, halo MeshPart, eye, 2 hand stubs, trim MeshParts | **≤ 6k** | ≤ 4 |
| **Boss adds** (`BOSS_ADD_MIX` 2 chaser · 1 ranged · 1 tank; #382 "add" uses the chaser profile) | same rows as their type: **8+8+5+9 = 30** | 4+4+4+5 = 17 | 4.7k | — |
**Wave peaks (enemies only):**
| Wave | Bodies | Gray-box parts | Art parts | Art tris | Highlights | Emitters |
|---|---|---|---|---|---|---|
| Wave 4 (6 chaser · 4 ranged · 2 tank) | 12 | 48 + 20 + 18 = **86** | 24 + 16 + 10 = **50** | 7.2k + 3.2k + 3k = **13.4k** | 12 (≤ 18 #438) | 12 enemy + bursts |
| Boss wave (boss + 4 adds) | 5 | 18 + 30 = **48** | 12 + 17 = **29** | 6k + 4.7k = **10.7k** | 5 + 1 entrance | 5 |
- These sit **next to** the L3 kit (gray-box 77–80 parts, Phase S ≈ 26k tris + 9k VFX headroom). Q8 asks whether L1's "≤ 35k tris" arena budget includes enemies; if yes, the art chaser drops to ≤ 0.9k and the wave-4 peak to ≈ 11.6k.
- **Gray-box today (#382):** all three wave types use one 3.2×2.2×4.2 block, so there is **no** shape read in the gray box yet. **v1.2 (Q10 closed):** L4's gray-box models (above) use the per-type #422 hitbox sizes from `Config/Enemies.luau` (chaser 2.6×3.4×2.6 · ranged 2×2.8×2 · tank 4.8×5.4×4.4) when `enemyTypes` goes on at the #422 merge.

### 6b. Placement and contrast vs. the L3 kit (#452)
| Kit surface (L3 color) | Risk | Rule |
|---|---|---|
| **K6 rift back plate** dark 22,16,31 (= the enemy ink body) | spawning enemies stand **in front of** the plate: ink on ink = no silhouette when glow and Rim are both off | an enemy in a gate mouth always has the glow or the warm Rim on (never neither); the plate's wave-start tint uses the element color **at 45% value** (#432 set: Ember 115,50,16 · Frost 41,96,115 · Void 88,41,115; #435 set: Ember 104,32,9 · Void 86,32,61) so a full-strength enemy outline (#432 outline 0) stays the brightest thing in the mouth. L3's K6 colors move to the #432 values in its next fold |
| **K9 cover** 90,74,138 slab + 120,210,255 edge | Frost outline vs. the cyan edge strip; Void vs. the purple slab | heads clear the 2.5-stud cover (chaser 3.4, ranged body top 2.8); the cover edge strip stays at 0.15 st and only flashes on clear, never during a hit flash. AlwaysOnTop glow draws through cover: fine for the read (shape through cover), but the fill is the strength knob (Q6) |
| **Floor** 148,148,148 + **K10 drain fan** 110,110,116 | death puff 210,206,196 on a light floor | puff stays lighter than both floor grays (≥ 60 value apart from the fan, ≥ 60 from the floor) so the "it died" pop reads; Remains (Q9) use the drain-fan gray so they read as "Hollow, gone" |
| **Wall** 96,96,96, lintel 90,74,138, Atmosphere 110,90,170 | far-rift enemies (5 px/stud) hazed toward violet | the far read is the size step + glow outline; Atmosphere Density 0.38 must keep the far-rift chaser outline visible at 390×844 (pass check §10) |
| **Boss spot (0, 8)**, boss doors K8 | boss behind the doors during entrance | the 9-stud boss fits inside the 18 w × 14 h rift frame with the halo below the 14–16 lintel; as the doors open its outline reads against the N back plate (red-violet only during the 4.5 s entrance, then the normal 45%-value tint) |
- **Phone checks (390×844 / 667×375 / 800×400 / desktop):** a hit flash is 0.08 s = 5 frames at 60 FPS, **2–3 frames at 30 FPS** on a low-end phone, still visible; nothing shorter. The 3-stud puff on a chaser at mid range is ~30 px, under the 44-px HUD scale, so it never hides a UI target; the puff is world-only and may sit in the #420 center keep-out (world, not UI).

## 7. Edge cases
- **Ranged at far range is the weakest read** (body 8 px, mockup 02 box C/D). Rule: the ground shadow disc is always on (it carries "floats" when the diamond is tiny); Q2 asks whether to also widen the visual ring to 2.4 st; that pokes 0.2 st out of each side of the 2-st hitbox (mesh only, hit detection unchanged).
- **Crowds overlap** (wave 4 = 12): silhouettes overlap at mid range (mockup 02 crowd box). The size step + the tank's slab still read; chasers become a "spiky carpet", which is fine (they are the trash).
- **Facing:** every type must read from front, side and back. Chaser comb and tank slab are visible from the back too (comb sticks up, slab is taller than the body). Ranged and boss are symmetric.
- **Element-mixed wave:** shape never changes with element; only trim, eye and particles.
- **Hard tier:** no shape or size change (Hard = HUD-only accent, Style Bible §5).
- **Reduced motion / low quality:** idle bob and ring spin off; silhouettes unchanged.
- **Highlight cap:** Roblox renders at most 31 Highlights; the #438 ceiling is 18 enemies. Silhouette read must never depend on a Highlight (it can be off).
- **Live crawl (flag off):** Rootvault kinds keep today's models until `enemyTypes` ships; the mapping in §2 is for the art pass only.
- **v1.1 Flash on Frost:** white over a 92,214,255 fill is the smallest jump of the three; the flash also whitens the trim Neon, which is what carries it on Frost.
- **v1.1 Flash vs. telegraph:** the #439 boss "move now" flash is a ground mark, not a body flash; the boss body flash stays 0.08 s white and never plays red.
- **v1.1 Puff overlap:** in a crowd, 3+ puffs overlap into one light cloud for 0.45 s; that is fine (it reads as "a lot died"). Cap: ≤ 6 live puffs on touch, oldest removed first.
- **v1.1 Puff size vs. type:** #382 uses one 3-stud Ball for every type. It hides a chaser and a ranged, but a tank (4.8 wide) shows its break around it. Q11 proposes puff size from the type's hitbox width.
- **v1.1 Element flag off, Hard, reduced quality:** glow off → warm Rim stays (live default); reduced quality drops the `ElementGlowLight` first, the Highlight last.

## 8. Mockups
SVG in `mockups/` (fake data, original shapes, pure black on gray):
- `01-silhouette-sheet.svg`: the 4 keys at design scale inside their dashed Config hitboxes · the phone-zoom ladder (near / mid / far px) · the element trim row (Ember #E84814 / Frost #5CD6FF / Void #C04888, outlines 45% toward white per #438).
- `02-squint-size-test.svg`: 4 boxes (mid sharp, mid squint, far sharp, far squint), the size ladder, a wave-4 crowd test and the boss wave (boss + 2 chaser · 1 ranged · 1 tank). The blur in the squint boxes is a review tool only, not an in-game effect.
- `03-in-frame-read.svg`: one wave at true scale in 390×844, 667×375, 800×400 and desktop frames with the #420 center keep-out drawn (world enemies may stand in it; UI may not).
PNG renders are on the box only. v1.1 adds no new mockup; the trim row in mockup 01 still shows v1 hexes (Ember #E84814 / Void #C04888) which matches Echo's held follow-up; §4b lists both sets.

## 9. Build split
- **Ghost (gray box, now, flag off):** per type, a block model at the Config hitbox with the unique feature blocked in: chaser = wedge body + 3 WedgeParts for the comb; ranged = rotated block diamond + thin Cylinder ring + floor shadow Part; tank = block body + tall slab Part; boss = WedgePart robe + 2 wing wedges + a 3/4 ring of small Parts for the halo. Trim = Neon Parts in the element color.
- **Ghost (art pass, Phase S):** MeshParts per §4, inside the hitbox, flat-tipped spikes, ≤ budget. Element particles per L1 (ember sparks, snow motes, dark swirl) recolored to the new hexes.
- **Echo:** nothing required. Only if Kevin/Ghost pick Q2 "visual ring 2.4 st" is there anything to check (mesh outside hitbox, hit detection unchanged). v1.1 asks only, no build: Q6 `Elements.GLOW.fillTransparency`, Q7 light cap, Q10 per-type gray-box sizes, Q11 puff size, all Config values.
- **Ghost (v1.1 client):** hit flash on the glow Highlight (§5), death break inside the puff, boss death over `deathHold`, Remains gray (Q9), K6 tint at 45% value.
- **Havoc / M13 testers:** run §10 with the mockup 02 sheet on a phone at full brightness and at 50% brightness.

## 10. Pass criteria
- [ ] Pure-black sheet (mockup 02) on a 390×844 phone: testers name all 4 types in boxes A and C (4/4) and ≥ 3/4 in the squint boxes B and D.
- [ ] Boss never called a tank; ranged never called a chaser (0 confusions in 5 testers).
- [ ] In a live wave-4 crowd at default zoom, testers point to "the tank" and "a ranged one" within 1 s.
- [ ] Grayscale screenshot of a live wave still shows which type is which (Style Bible §6).
- [ ] Every model stays inside its Config hitbox (Studio bounding-box check) and inside the per-enemy part/tri budget.
- [ ] Element read: testers name Ember / Frost / Void on 3/3 types (second read, after shape).
- [ ] (v1.1) With the #432 glow on, a hit flash is visible on all 3 elements at 30 FPS on a phone (testers say "I hit it" 3/3).
- [ ] (v1.1) Killing a chaser in a wave-4 crowd: puff and break end together (≤ 0.45 s), no shape left standing; boss death reads as "falling" across the 1.5 s hold.
- [ ] (v1.1) An enemy in a gate mouth reads against the K6 back plate in a pure gray screenshot with glow on and with glow off (Rim).
- [ ] (v1.2) On a phone in wave 4, at most 4 `ElementGlowLight`s exist at once (Explorer count), always on the nearest enemies; glow fill reads 0.5.
- [ ] (v1.2) Gray-box chaser / ranged / tank match their #422 hitbox sizes; each death puff is hitbox width ×1.15 (3 / 2.3 / 5.5 st).
- [ ] (v1.1) Wave 4 and the boss wave stay inside the §6a budgets (Studio part / tri count).
- **Fail fix order:** grow the unique feature first, then the size step, never color.

## 11. Open questions (answer by number)
1. **@Kevin (taste):** Flat broken tips on every enemy spike (Style Bible §7 "flat broken stubs = the Hollow") instead of L1's pointed spikes. Recommended: yes, flat tips; sharp points stay the player's.
2. **@Ghost:** Ranged far-range read: keep the ring at the 2-st hitbox width + always-on shadow disc (rec), or let the visual ring poke out to 2.4 st (mesh only, hitbox unchanged)? Recommended: hitbox width + shadow first; revisit only if §10 fails.
3. **@Ghost:** Boss outline color. L1 says a red-violet Highlight during the entrance only; Style Bible §4 says "boss keeps its own gold look". Recommended: red-violet Highlight **only** for the 4.5 s entrance, then the boss uses the normal element glow rules like any enemy (gold stays for rewards).
4. **@Kevin (taste):** The boss's shard wings angle **up** (reads as threat, mockup 01). Alternative: wings folded down like a cloak (calmer, less readable). Recommended: up.
5. **@Ghost:** L1 heights (chaser 3 / ranged 4 / tank 7 / boss 14 studs) vs Config (3.4 / 2.8 / 5.4 / 9). This spec follows Config (repo wins). OK to mark L1's numbers superseded in #414's next fold? Recommended: yes.
6. ~~**@Kevin (taste) / @Ghost:** #432's `fillTransparency 0.28` turns the whole enemy body element-colored (bright, very readable, but loses the "dark ink body" look and swallows the hit flash). Keep 0.28, or raise to **0.5** (outline-led, ink body shows, still inside the spec test's ≤ 0.55)? Recommended: **0.5**; the outline stays at 0 so the element still reads at phone zoom.~~ **CLOSED v1.2 (Ghost, DP29, Kevin pre-approved): 0.5 (outline stays 0).**
7. ~~**@Ghost (Echo):** One `ElementGlowLight` per enemy = 12 lights in wave 4 on top of the arena's 5. Cap at the 4 nearest on touch (12 desktop, per #438), or drop lights on touch and keep the Highlight only? Recommended: 4 nearest on touch.~~ **CLOSED v1.2 (Ghost, DP29, Kevin pre-approved): cap `ElementGlowLight` to the 4 nearest (touch; 12 desktop).**
8. **@Ghost:** Does L1's Phase S arena "≤ 35k tris" include enemies? Recommended: no; enemies get their own ≤ 14k peak (§6a), and the phone FPS check covers the sum.
9. **@Ghost:** Live-crawl Remains (rig kept until the next wave) go Hollow gray 110,110,116, 0.5 transparency, 60% height, no trim, so a corpse never reads as a live silhouette? Recommended: yes.
10. ~~**@Ghost (Echo):** #382's gray box uses one 3.2×2.2×4.2 block for chaser / ranged / tank. Give each type its #422 hitbox size (and the §6a gray-box parts) when `enemyTypes` goes on? Recommended: yes, at the #422 merge.~~ **CLOSED v1.2 (Ghost, DP29, Kevin pre-approved): yes, use the #422 gray-box hitbox sizes at the #422 merge.**
11. ~~**@Ghost (Echo):** Death puff size per type = hitbox width × 1.15 (chaser 3, ranged 2.3, tank 5.5), same 0.45 s and color; boss keeps the hold. Recommended: yes (today's single 3-stud Ball is right only for the chaser).~~ **CLOSED v1.2 (Ghost, DP29, Kevin pre-approved): yes, death puff = hitbox width ×1.15, same 0.45 s and color; boss keeps the hold.**
12. **@Ghost (Echo):** Echo's held Ember #E84814 / Void #C04888 follow-up: Void's peak channel 192 fails #432's `ConfigValidation` "peak ≥ 200, too dim to read at phone zoom" check, and #C04888 sits closer to the boss-entrance red-violet 255,90,110. Lift Void to e.g. #C850D0 (200,80,208) or relax the test? Recommended: lift Void (Kevin's #435 pick still decides the hue).

## Decision log
- 2026-10-23 (Ghost, Kevin pre-approved, via L1 #414): roles chaser / ranged / tank / boss; names Shardling, Prism Wisp, Bulwark, Hollow Warden kept; body dark ink, element on trim.
- 2026-10-24 (Ghost GO 11:55Z, Kevin pre-approved for Prism to write it; Prism): **L4 v1** silhouette keys, Config-locked sizes, phone ladder, squint/size + crowd tests, pass criteria. Not approved as a Vision & Design Rules decision.
- 2026-10-24 (Ghost row 403c31ca388381818692c13be76248b2, Kevin pre-approved; Prism): **L4 v1.1** folded on the same branch: part budgets, #432 element glow rules, #382 hit flash / death puff, L3 #452 contrast. Not approved as a Vision & Design Rules decision.
- 2026-10-24 (Ghost DP29 row https://app.notion.com/p/403c31ca3883816cbc9cc827b26d3c96, Kevin pre-approved; Prism): **L4 v1.2** Q6 fill 0.5, Q7 4-nearest light cap, Q10 #422 gray-box sizes, Q11 puff ×1.15 closed. Still a proposal until Kevin copies it into Vision & Design Rules.

## Later (not V1)
Mender silhouette (live `moss_crawler`; proposal: a low flat dome with one tall sprout, the only enemy with a vertical "antenna"), elite variants, per-realm reskins. All go to the Ideas Backlog marked NOT APPROVED.

## Roblox build notes
- **Geometry carries the read.** Parts / WedgeParts / Cylinders for gray box; MeshParts (≤ 1.5k tris, boss ≤ 6k) for art. `CastShadow` false on trim Neon parts; body `Material` SmoothPlastic or Slate, `Color` ink 22,16,31 (L1). Collision: the server hitbox Part stays the Config size; the visual mesh is welded (`WeldConstraint`) with `CanCollide`/`CanQuery`/`CanTouch` false.
- **Highlight limits:** Roblox renders at most 31 `Highlight`s at once; #438 caps enemies at 18 and ≤ 1 per alive enemy (destroy on death). `Highlight.OutlineTransparency` 0 with outline = element color 45% toward white; `FillTransparency` 0.5. The silhouette must read with **no** Highlight (budget overflow drops to warm Rim + pip, or pip only).
- **Element trim:** small `Neon` Parts on spike tips / eye / ring / shield rim / halo, `Color` = `Color3.fromRGB(table.unpack(Elements.LIST[id].color))` (v1.1: #432 ships Ember 255,112,36 · Frost 92,214,255 · Void 196,92,255; Echo's held follow-up moves Ember / Void to #E84814 / #C04888), read from Config, never hard-coded. One `PointLight` ground pool per #438 budget (4 touch / 12 desktop), `Shadows` false. **v1.2 cap (Q7):** a client loop every 0.5 s sorts alive enemies by distance to `workspace.CurrentCamera` and sets `ElementGlowLight.Enabled` true only on the 4 nearest (touch) / 12 (desktop); toggle `Enabled`, don't create/destroy per tick.
- **ParticleEmitters:** one per enemy max (element motes, `Rate` ≤ 6, `LightEmission` 0.5); bursts via `:Emit()` on hit/death (≤ 12 particles); arena live cap ≤ 300 (L1 §6).
- **Ranged shadow disc:** a 0.05-st-thick Cylinder Part (black, Transparency 0.6, `CastShadow` false) raycast-snapped to the floor; do not rely on real shadows (arena lights have `Shadows` false).
- **Motion:** idle bob / ring spin / windup crouch via `TweenService` or `Motor6D`; no skinned-mesh requirement for V1.
- **Hit flash (v1.1):** on the `hitFlash` event, read `event.seconds` / `event.color` (from `WaveArenaConfig.feel`, not literals). Glow on: set the `ElementGlow` Highlight's `FillColor` = flash color and `FillTransparency` = 0, restore both after `seconds` (one restore task per enemy, restarted on a new hit). Glow off: set `Color` on every visual part + trim, restore after `seconds`. No `BlurEffect`, no `ColorCorrection` per hit.
- **Death puff (v1.1):** keep #382's anchored Ball `Part` (CanCollide/CanQuery/CanTouch false, `CastShadow` false, Material SmoothPlastic), size = hitbox width ×1.15 per type (Q11 closed v1.2: chaser 3, ranged 2.3, tank 5.5; read the width from `Config/Enemies`, not literals), plus an optional `:Emit(8)` of flat stub shards from the enemy's one emitter; `TweenService` Transparency 0.3 → 1 over 0.45 s instead of a hard pop; destroy at the end. Call `ElementGlow.detach` first so no Highlight or light outlives the body.
- **Not used:** SurfaceAppearance-only reads, post effects, `BlurEffect`, custom shaders, beams as silhouette parts. Rarity colors (`Rarities.COLOR`) never go on enemies; they stay on loot motes (L1 §5).
