# Town / Hub: "Crater Square" (V1 hub cut down from the live Haven), Spec v1.1

Owner: Prism (design, no code). Builders: Ghost (world + UI), Echo (server hooks, flags). Base: `cursor/live-build-9721` @ `9269e61`. Docs only.
Asked for in: Agent Board "Prism: overnight queue: Town redesign + dungeon look specs" (https://app.notion.com/p/403c31ca38838160b0afc69d00631416). Aligned to Ghost's Kevin-approved decisions row (https://app.notion.com/p/403c31ca38838189b1c5ed1249a17e57), decisions 2, 3, 8, 10. Roadmap 3.1 (Shard Gate pad near spawn), Phase 6 (party).
Nothing here changes code or Config. LaunchGate flag names below are suggestions for Ghost/Echo.

**v1.1 changelog (Oct 23, 2026):** renamed "Sundered Haven" → **Crater Square**. The hub is now the live Haven **cut down**, not a new layout: live spawn (0, 30), live Lumen Heart (0, 0), live Armory, live Rootvault arch slot (0, 108) reused as the Shard Gate. Parked districts and the 5 sealed/raid arches are hidden behind LaunchGate flags (nothing deleted). Walk numbers redone (all under 5 s). Gate prompt = Normal + Hard (Lv 5) only. Pull beams added (per-server, not saved, Phase S). Havoc's QA risks folded into §7. Taste call 2 settled (see §11).

Sources (link, don't copy): `Shared/Haven.luau` (`FLOOR_Y = 120`, `WALK_SPEED = 16`, `PLAZA_RADIUS = 52`, `CRYSTAL` height 36 at (0, 0), `SPAWN` (0, 30) looking south, `GATE_RADIUS = 78` crescent of 6 arches around spawn, `COURT_RIM = 96`, `ARMORY` (-38, -35.8), `DISTRICTS` Forge/Market/Guild Hall/Pet Garden/Observatory at 100–200 st); `Shared/LaunchGate.luau` (`SHOW`, `promptOpen`, `dungeonOpen`); `docs/design/DUNGEON_GATE_PLAZA.md` (Ghost, six-arch crescent; its Hard Lv 10 / Nightmare Lv 15 lines are superseded by decision 10; that doc was updated in PR #418, https://github.com/Itsm00k21/Shardfall/pull/418); first-30-seconds spec (#412). Element colors reuse the live arch colors: Ember 255,150,40 · Frost 186,228,255 · Void 150,70,220.

## 1. Goal
A small, readable V1 hub where a new player sees the Roll altar and the Shard Gate in the very first shot, walks spawn → Roll in ~1.6 s and Roll → Gate in ~3 s, and gets the world's story at a glance: a god-crystal shard fell here and left a crater, shards still rain down, and the Hollow is draining color from the crater lip. Everything not in V1 is hidden, not removed.

## 2. Where it lives
- World only: the live `HavenBuilder` hub at floor y 120 (same model, Persistent), **cut down** to the plaza (r 52 around the Lumen Heart) plus the live gate court (rim r 96 around spawn). That footprint is **Crater Square**.
- Hidden behind LaunchGate flags (built only when the flag is on; nothing deleted): the 5 district islands and their bridges (Forge, Market, Guild Hall, Pet Garden, Observatory), the 5 non-V1 arches (Heartwood raid, Tidecrypt, Emberforge, Frostveil, Void Rift), Shop, Shrine, Training Grove (`grove`, already off), the 5 class stones (`classes`, already off). Suggested new flags: `hubDistricts`, `sealedGates`.
- The live Rootvault arch slot (0, 108) is reskinned as the **Shard Gate** into the new wave arena (old Rootvault Waves + room crawl parked per decision 4).
- Screen UI unchanged: existing ROLL bar (56 px), Bag button, rail. World prompts are `ProximityPrompt` + `BillboardGui`.
- Theme name: **Crater Square**. Landmark: the live **Lumen Heart** (name kept, see §11 Q2), now the crater's centerpiece.

## 3. Flow
1. Spawn on the live pad at (0, 30), facing south (live `SPAWN.lookZ`). First shot: Crackstone + Oracle Wren front-left, Shard Gate arch dead ahead (68 st). The Lumen Heart is behind the camera; its 36-st crystal shows when the player turns.
2. Walk 25 st (1.6 s) to the **Crackstone** at (-12, 52) → ProximityPrompt "Roll" opens the roll flow (existing). Epic/Legendary results fire a **pull beam** (§5).
3. Walk 48 st (3.0 s) to the **Shard Gate pad** at (0, 98) in front of the arch → standing on the pad opens the existing Gate dock (first-30 spec): **Normal** and **Hard (Lv 5)** only, Hard shows a lock + "Lv 5" below level 5. No Nightmare. START → teleport to the arena.
4. Optional: **Armory** (live, (-38, -35.8), equip stand; opens the existing Bag/equip). **Muster spot** at (24, 90), 26 st from the Gate pad, reserved for Phase 6 party gather (see §11 Q3).
5. Returning from a run (win, wipe, or rejoin): arrive on the **return pad** at (14, 30) beside spawn, never on the Gate pad, so no accidental re-entry.

## 4. Layout
Origin = Lumen Heart (0, 0), +z = south. All on floor y 120. Map: `mockups/01-topdown-map.svg`.

| Thing | Center (x, z) | Size (studs) | Source | Notes |
|---|---|---|---|---|
| Plaza | (0, 0) | r 52 | live | inner crater floor |
| Gate court | around spawn (0, 30) | rim r 96 | live `COURT_RIM` | crater lip band r 88–96 is the Hollow-gray edge; invisible wall at r 96 |
| Lumen Heart | (0, 0) | pedestal 22×22, crystal 36 tall | live | art pass adds a crack + 5–6 orbiting broken shards at r 18–20 |
| Spawn pad | (0, 30) | live | live | looks south (+Z) at the Gate |
| Return pad | (14, 30) | 10 × 10 | new | |
| Crackstone (Roll) | (-12, 52) | altar Ø12, crystal 9 tall | new | Oracle Wren at (-18, 52) |
| Shard Gate arch | (0, 108) | arch 18 tall, 14 wide | live Rootvault slot | reskinned; subline `Lv 1 · Normal / Hard` |
| Shard Gate pad | (0, 98) | Ø16 | new | dock trigger (existing EnterPad logic) |
| Armory | (-38, -35.8) | live | live | equip stand |
| Muster spot | (24, 90) | Ø18 | reserved | Phase 6, gray-box now (§11 Q3, decided) |
| Hidden arch slots ×5 | crescent bearings 12°–60°, r 78 from spawn | | live, hidden | flag `sealedGates` off; slot left as plain floor (art pass may add rubble decor) |
| Shard craters ×4 | (-60, 60) (52, -28) (-44, 104) (60, 40) | Ø8 | new | decor / orientation |
| Paths | spawn↔Roll, Roll↔Gate pad, spawn↔Gate pad, spawn↔Armory, Gate pad↔Muster | 10 wide | new | lighter slate so the route reads |

**Walk times** (WalkSpeed 16): spawn→Roll 25 st / 1.6 s · Roll→Gate pad 48 st / 3.0 s · spawn→Gate pad 68 st / 4.2 s · spawn→Armory 76 st / 4.7 s. All under the ~10 s cap (decision 2). The Armory path passes the Heart pedestal with 6 st clearance.

**Sight lines:** from spawn the Gate is dead ahead (0°) and the Crackstone is ~29° left, so both fit the ~70° landscape cone. In the ~40° portrait cone the Gate arch and its billboard are centered; the Crackstone sits just outside, so its 9-st crystal + Wren's BillboardGui name peek in from the left edge (mockup 02). No part over 2 st tall inside the spawn → Roll → Gate triangle.

**Phone camera checks** (default zoom ~12.5 st, mockups 02–03):
- 390×844 portrait: Gate arch + "Shard Gate · 4 s" billboard visible; Crackstone + Wren label at left edge; no screen UI inside the center keep-out (x 30–70%, y 28–73%; on portrait the top is 35%, review D1, provisional).
- 667×375 / 800×400 landscape: Crackstone and Gate both visible on spawn.
- Desktop 1280×720: same as landscape with more sky.
- BillboardGui labels: `MaxDistance` 80 (Gate 96, live `NAMEPLATE_DISTANCE`), `AlwaysOnTop` false, text ≥ 18 px at 390 wide.

## 5. States
- **Gate pad:** idle (slow violet swirl) · player on pad (gold rim, dock opens: Normal / Hard Lv 5) · countdown (swirl speeds up, 3 s) · party gathering (Phase 6, later).
- **Crackstone:** idle glow · free rolls left (gold pulse + "FREE" billboard, new players) · rolling (crystal flashes in the revealed rarity color, 0.3 s).
- **Pull beam (Phase S):** on an Epic or Legendary roll, a vertical `Beam` in the rarity color (Epic 186,96,240 · Legendary 255,196,64) rises 60 st from the Crackstone for 2.5 s, plus a one-line server toast "<name> pulled a Legendary!" (through the one toast lane as a loot/rarity toast, which goes before queued info toasts; max 1 on screen, phone layout review D3). **Per-server only, not saved, no list, no ranking** (decision 8). Max 1 beam at a time; extra pulls queue at 1 s spacing (cap 3 queued, rest dropped).
- **Lumen Heart:** constant. Shards bob; one shard "falls" into a random crater every 20–30 s (tween + burst), decor only.
- **Hollow lip:** static gray band + fog particles; no damage, no gameplay.

## 6. Numbers
- Crater Square = plaza r 52 + court rim r 96. Floor y 120. WalkSpeed 16 (live).
- Heart 36 (live); Gate arch 18 (live); Crackstone 9; nothing else over 12 inside the spawn triangle.
- Shard rain: 1 world emitter over the Heart, Rate 6, Lifetime 3–4, Size 0.4–0.8.
- Shard fall event: every 20–30 s. Pull beam: 2.5 s, 1 at a time.

### Phone performance budget (whole visible hub, low-end phone)
| Budget | Cap |
|---|---|
| Parts + MeshParts (flags off) | ≤ 900 (gray box ≤ 250) |
| Triangles (meshes) | ≤ 60k total; Heart ≤ 8k |
| Lights | ≤ 6 PointLight/SurfaceLight, `Shadows = false` on all; 0 SpotLights |
| ParticleEmitters | ≤ 6, sum of Rate ≤ 40, live particles ≤ 250 |
| Beams | ≤ 4 (onboarding path beam + 1 pull beam + 2 spare) |
| Textures | ≤ 8 unique |
| Unions | 0 (use MeshParts) |
Hiding districts/arches by not building them (flag off) is what makes this budget reachable; hidden ≠ Transparency 1.

## 7. Edge cases
- 20+ players at spawn: return pad beside spawn keeps the Gate pad clear; Gate pad triggers only for the local player.
- Player walks off the lip: invisible wall at r 96; if they fall anyway, live `FALL_Y` respawn on the spawn pad.
- **Hidden content must be closed on the server too (Havoc risk 3):** with a flag off, the district/arch is not built *and* its remote/teleport refuses (`LaunchGate.promptOpen` / `dungeonOpen`), not just hidden parts. A save whose last location points at a hidden district or a parked dungeon loads on the spawn pad.
- **Gate difficulty (Havoc risk 4):** the dock greys Hard below Lv 5, but the server re-checks level on START.
- Pull beams: per-server, nothing written to the save (decision 8); a player who leaves mid-beam just ends it.
- Low graphics quality: emitters auto-thin, Heart Glass → Neon fallback.
- New player never finds Roll: first-30 spec pointer + Wren line; Crackstone is 25 st away and lit.
- Streaming: hub model Persistent (live) so landmarks never pop.

## 8. Mockups
SVG (in repo): `mockups/01-topdown-map.svg` (map, studs, walk times, sight cones, hidden content dashed) · `mockups/02-spawn-shot-phone-390x844.svg` · `mockups/03-spawn-shot-landscape-667x375.svg`. PNG renders are on the box only.
Fake data. Original art: no reference game's art, layout or names.

### Theme: Crater Square (original)
- **The crater:** the plaza is the bowl where a god-crystal shard struck; the court rim is the crater lip, slightly raised, cracked outward.
- **Lumen Heart:** the live crystal, art pass adds a bright crack and floating broken pieces, so it reads as "what's left of the shard".
- **Shards raining down:** thin light streaks over the square; 4 small craters with embedded shards.
- **Broken prismatic sky:** deep violet with pink/cyan/white "crack" lines (Sky decals or a few high Neon Beam strips).
- **Color draining at the Hollow:** saturation steps down by ring: center full color → r 60–88 muted → lip r 88–96 gray (RGB ~110,110,116) + gray fog.

## 9. Build split
**Flags pass (Ghost/Echo, first):** add `hubDistricts` + `sealedGates` (off) and gate the matching builders, prompts and remotes; nothing deleted. Park Rootvault Waves/room crawl per decision 4.
**Gray-box pass (Ghost)** — plain Parts, SmoothPlastic, colors only:
| # | Part | Shape/size | Color (RGB) |
|---|---|---|---|
| 1 | Crater lip band r 88–96 | Blocks | 46,46,52 |
| 2 | Invisible wall | thin blocks at r 96, Transparency 1 | — |
| 3 | Return pad | 10×1×10 at (14, 30) | 120,210,255 |
| 4 | Crackstone | 12×2×12 base + 3×9×3 crystal at (-12, 52) | 120,210,255 |
| 5 | Wren marker | 2×5×2 at (-18, 52) | 255,255,255 |
| 6 | Gate pad | 16×1×16 at (0, 98) | 255,196,64 |
| 7 | Shard Gate arch | live Rootvault arch, recolor | 180,140,255 body / 255,196,64 edge |
| 8 | Paths | 10-wide blocks, 0.05 above floor (`Haven.LAYER`) | 75,63,112 |
| 9 | Craters | 4 × 8×0.5×8 + 1 small wedge | 124,111,176 |
| 10 | Muster spot (Q3 = gray-box) | 4 sockets 3×0.5×3 | 200,180,255 |
Prompts: Crackstone "Roll", Armory (live), Gate pad touch zone (existing EnterPad logic).

**Art pass (Phase S):** 1) Heart crack + floating shard meshes (≤ 400 tris each) · 2) Crackstone mesh + Wren model · 3) Shard Gate arch reskin with inner Neon swirl (Texture scroll) · 4) prismatic sky · 5) shard rain emitter + fall-event burst · 6) pull beam (`Beam` + 2 Attachments, Width 3, LightEmission 1) · 7) saturation ring re-color + lip fog · 8) crater meshes · 9) Lighting: `Atmosphere` Density 0.32, Color 150,130,200, Decay 90,80,120, Haze 1.5; `Lighting.Ambient` 70,60,100; ClockTime fixed 18.5 (§11 Q1, decided); `Bloom` Intensity 0.6, Threshold 1.6.

Roblox notes: everything is Parts/MeshParts, Lighting/Atmosphere, Sky, Beams and world ParticleEmitters. "Color draining" is per-part color, not a post effect (ColorCorrection is global and would gray the whole screen).

## 10. Pass criteria
- [ ] From spawn at 390×844 the Gate arch + billboard are visible and Wren's label peeks in left; at 667×375 both Crackstone and Gate.
- [ ] Spawn→Roll ≤ 10 s (target 1.6 s) and Roll→Gate ≤ 10 s (target 3.0 s), timed on foot.
- [ ] With flags off: no district, sealed arch, Shop, Shrine, Grove or class stone is built, and their remotes refuse; old saves load on spawn.
- [ ] Gate dock shows Normal + Hard (Lv 5) only; no Nightmare anywhere.
- [ ] Pull beam shows for everyone on the server and nothing is saved.
- [ ] Performance budget met; no screen UI added; touch targets stay ≥ 44 px.
- [ ] Theme reads in a screenshot: crater, falling shards, cracked sky, gray lip.

## 11. Open questions (Kevin)
1. ~~Fixed evening time or live day cycle?~~ **Fixed evening, ClockTime 18.5 (Ghost, Kevin pre-approved, Oct 23, 2026).** Board row: https://app.notion.com/p/403c31ca388381c0bb72d75abab9bd4d
2. ~~Rename the Lumen Heart to "Sundered Heart"?~~ **Settled by Ghost's decisions (Oct 23, 2026):** the hub identity is **Crater Square** (decision 2/3) and the hub is the live Haven cut down, so the landmark keeps its live name **Lumen Heart** with the new cracked look. Kevin can still rename it later.
3. ~~Muster spot gray-box now or empty?~~ **Gray-box the 4 sockets now (Ghost, Kevin pre-approved).** Decor only, no party logic until Phase 6.

Done: `DUNGEON_GATE_PLAZA.md` now says Hard Lv 5 and no Nightmare (decision 10). It was updated in PR #418 (https://github.com/Itsm00k21/Shardfall/pull/418).

## Decision log
- 2026-10-23 (Ghost, Kevin pre-approved): hub = Crater Square, small V1 hub cut down from the live Haven; parked districts + 5 sealed gates hidden behind LaunchGate flags (delete nothing); Spawn, Roll and Gate within ~10 s walk. Gate prompt = Normal + Hard (Lv 5), no Nightmare. Pull beams per-server only, not saved, Phase S. → v1.1.
- 2026-10-23 (Ghost, Kevin pre-approved): taste call 1 = fixed evening sky (ClockTime 18.5); taste call 3 = gray-box the Muster spot now. All §11 questions are now closed.
- 2026-10-23 (Prism, phone layout review, docs/design/phone-layout-review/REVIEW_v1.md): phone check pass, no screen UI in this spec. The Gate dock it opens is #412's (see the review's bottom-slot note R2). The `DUNGEON_GATE_PLAZA.md` follow-up was done in PR #418.
- 2026-10-24 (Ghost, Kevin pre-approved, board row https://app.notion.com/p/403c31ca38838103a80ad21380d7f451; folded by Prism from the phone layout review rev 1.1, docs/design/phone-layout-review/REVIEW_v1.md §8/§10): D1: the portrait keep-out top is 35% (§4 phone check). D2: on the Gate pad the live combat cluster hides while the #412 Gate dock is up (no change to this world-only spec). D3: the pull toast goes through the one toast lane as loot/rarity (§5).
