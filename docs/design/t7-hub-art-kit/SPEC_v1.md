# T7 Hub Art Kit ("Crater Square" gray-box kit), Spec v1.1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only, no code, no Config, no save edits). Builders: Ghost (hub world parts, client dressing), Echo (LaunchGate flags + server refusals, only where a question below says so). Base: `cursor/live-build-9721` @ `581c995`. Status: **v1.1, proposal (Ghost answered Q1–Q5 on board row DP31P, Kevin pre-approved; Q6 open for Kevin).** Not an official Vision & Design Rules decision until Kevin approves it and it is copied there. **Art stays gray-box until Phase S**; Phase S rows are identity and budget guidance only.
Asked for in: Ghost's Agent Board row DP29 https://app.notion.com/p/403c31ca3883816cbc9cc827b26d3c96 (Oct 24, 2026, Kevin pre-approved), Next (1): "T7 hub art kit spec on Crater Square #413 (art list, reuse, StreamingEnabled, part/tri + phone budget, like L3 #452)." ACK: https://app.notion.com/p/403c31ca388381bda15dc237843e114b. v1.1 answers: Ghost row DP31P https://app.notion.com/p/403c31ca388381feb52fdb6685c444a5 (ACK https://app.notion.com/p/403c31ca3883813bb703cccb4dc0e0fa).

**v1.1 changes (Ghost DP31P):** Q1 yes, lip band H16, walls H17 and craters C1–C4 snap to the real square floor blocks (locked). Q2 yes, the live `EnterPad` sits on the Gate pad H12 at (0, 98); its position comes from Haven config (`Haven.KIT`), an **Echo build note**, not a Prism edit. Q3 yes, guide ring H3 trimmed to the open gate's 2 segments. Q4 yes, budget trims accepted (NoviceStone behind `classes`, waystones behind `travel`, 3 waterfall lights dropped, 2 foliage motes retired); **hard cap stays 250 parts**. Q5 yes, the plaza sign is renamed **"Shard Gate"** (matches the pad and the arch billboard). Q6 (Phase S lip look) stays open for Kevin.

**What this extends (link, don't copy):** #413 = Town/Hub "Crater Square" v1.1 (`prism/town-hub`, `docs/design/town-hub/SPEC_v1.md`): layout, walk times, sight lines, gray-box list, art pass list, phone budget, all decisions (ClockTime 18.5, Muster gray-box, Lumen Heart name). L3 = arena kit #452 (`prism/l3-arena-kit`): same piece-list format. T6 = big-roll beam #450 (pull beam rules). **T7 adds what #413 left loose:** a numbered piece list snapped to the **real** live floor (not the r 52 / r 96 circles), a measured count of what's reused vs hidden vs new, a gray-box part count vs the ≤ 250 cap, a Phase S triangle split, StreamingEnabled notes, and per-piece Roblox build notes. No duplicate branch exists (`prism/t7-*` checked).

**Repo read (read only; repo wins, Home rule 6).** `Shared/Haven.luau`: `FLOOR_Y` 120, `WALK_SPEED` 16, `PLAZA_RADIUS` 52, `CRYSTAL` (0, 0) h 36, `SPAWN` (0, 30) looking at (0, 108), `GATE_RADIUS` 78 crescent of 6 arches (bearings 0°–60° toward +X), `COURT_RIM` 96 (only used by `Haven.courtRim` for bridge ends; **there is no wall or ring at r 96**), `FALL_Y` 60. `HavenBuilder.luau`: `island()` floors are **square** blocks (`disc()` = a square slab): plaza `BossPlaza` Ground 104×8×104 at (0, 0) + Rock 120×12×120; `GateCourt` Ground A 144×98 at (50, 101) → x −22…122, z 52…150, Ground B 96×36 at (100, 34) → x 52…148, z 16…52; `RimShop` floor 38×40 at (−71, 0); a "Boss Plaza" `sign` at (0, 14, −40); the Rootvault arch at (0, 108) carries the live `EnterPad`; one shadowless `PointLight` per arch mouth; hub model `ModelStreamingMode = Persistent`. `default.project.json` Workspace: `StreamingEnabled` true, `StreamingMinRadius` 128, `StreamingTargetRadius` 512. `HavenLife`: day cycle `START_CLOCK` 15.4, `DAY_SECONDS` 480, `lanternsOn` ≥ 18.2, `exposure()` glare band ±1.8 h around 18.2. `Quality.luau`: Low = touch default (`particleScale` 0.2, `particleBudget` 16, `decorKeep` 0.34, `fogEnd` 480, no decor shadows), `MIN_TAP` 44. `Shared/Rarities.luau` `COLOR`: Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64. `LaunchGate.SHOW`: no `hubDistricts` / `sealedGates` yet (#413 suggests them); `classes`, `travel`, `grove` false.
**Measured (Prism ran the live `HavenBuilder.build` through the repo's own `tests/HavenBuild.spec` mock, lune, read only, nothing committed):** whole hub today = **319 BaseParts** (272 Part, 46 Wedge, 1 SpawnLocation), 35 PointLights, 30 ParticleEmitters, 16 BillboardGuis, 11 ProximityPrompts. **On the Crater Square floor** (plaza + court blocks): **147 parts, 13 lights, 8 emitters** (Rootvault arch ≈ 12 parts; the 5 other arches ≈ 39 parts, 5 lights, 5 emitters; 5 `NoviceStone` + 2 waystones + 2 crystals + `Shrine` + 2 bridge ends are built today even with `classes` / `travel` off).

---

## 1. Goal
A drop-in piece list that turns the live Haven into Crater Square in one gray-box pass: reuse every live landmark that #413 keeps, hide (don't build) everything parked, add only the ~60 gray-box parts #413 asks for, and land **≤ 250 gray-box parts, ≤ 6 lights, ≤ 6 emitters** on the floor a phone actually renders, with the crater / falling shards / Hollow-gray lip identity planned for Phase S. A new player at 390×844 still sees the Shard Gate dead ahead and the Crackstone peeking in at the left on the very first frame (#413 §4), and the first win (Roll in 1.6 s) is never blocked by a kit piece.

## 2. Where it lives
- **World only:** the live `Haven` model (direct child of Workspace, Persistent) at floor y 120. Crater Square = the plaza block (x/z ±52) + the court L (A: x −22…122, z 52…150; B: x 52…148, z 16…52). Mockup `01-hub-plan-topdown.svg`.
- **Reused live pieces** stay in their builders (`buildPlaza`, `buildCrystal`, `buildCourt`, `buildPortals` for Rootvault only). **Hidden pieces** are not built when their flag is off (#413 `hubDistricts`, `sealedGates`; plus `classes`, `travel` per Q4). **New pieces** go in a `CraterKit` Model inside `Haven` (so they inherit Persistent).
- **No screen UI.** World prompts are the live `ProximityPrompt` + `BillboardGui`; the Gate dock and ROLL bar are #412 / live. Wave arena (L3) untouched.
- **Not here:** Gate dock UI (#412), first-session guide (#449), big-roll beam logic (#450), pets / districts / raids (parked), any Config number change.

## 3. Flow (what the kit does for one player)
1. **Join:** Haven is Persistent, so the whole square is on the client before the character spawns (no pop-in). Spawn pad (0, 30) faces the Shard Gate (0, 108).
2. **First frame:** Gate arch + "Shard Gate" billboard centered (the plaza sign behind spawn now also reads "Shard Gate", Q5); Crackstone crystal + Wren name at the left edge (portrait) or in view (landscape). Paths (H14) lead the eye: spawn → Crackstone → Gate pad.
3. **Roll (1.6 s walk):** Crackstone prompt "Roll" → live roll flow. Crackstone crystal flashes the revealed tier color (`Rarities.COLOR`, 0.3 s). Epic+ fires the #450 pull beam from the Crackstone top attachment.
4. **Gate (3.0 s walk):** step on the Gate pad H12 (the live `EnterPad`, moved, Q2) → #412 dock → START → teleport to the arena (StreamingEnabled requests the arena stream, live `DungeonService`).
5. **Return:** land on the return pad H11 (14, 30). Lip H16 and walls H17 stop walk-offs; `FALL_Y` 60 respawn stays as the backstop.
6. **Ambient:** shard fall decor every 20–30 s into one of 4 craters H15 (#413 §5); Lumen Heart shards keep orbiting (live heartbeat).

## 4. Layout (piece list)
Hub-local studs, origin = Lumen Heart (0, 0), +Z = south (toward the Gate), floor top y 120. "Live" = built today and kept; "Hide" = not built while its flag is off; "New" = this kit.
| ID | Piece | Size (studs) | Position (x, z) | Count (parts) | Solid? | Source |
|---|---|---|---|---|---|---|
| H1 | Plaza floor + rock skirt | 104×8×104 + 120×12×120 | (0, 0) | 2 | yes | live `BossPlaza` |
| H2 | Gate court floors A + B + 6 inlays | 144×98, 96×36, inlays 1.1 | A (50, 101), B (100, 34) | 8 | yes (inlays no) | live `GateCourt` |
| H3 | Court guide ring | 5.2×0.08×1.4 (+1.2×16 lit) | r 36 / 26 from spawn | 8 → **2** (Q3, decided v1.1) | no | live `CourtRing`, trimmed |
| H4 | Lumen Heart (pedestal, crystal, core, crack, 6 crystal shards, 6 orbit shards, 4 light beams) | pedestal 22×22, crystal h 36 | (0, 0) | 20 | pedestal + crystal | live |
| H5 | Spawn pad | 12×1×12 | (0, 30) | 1 | yes | live `HubSpawn` |
| H6 | Armory stand + blade + station disc | 8×6×2, disc 12 | (−38, −35.8) | 3 | stand | live |
| H7 | Shard Gate arch (Rootvault arch reskinned, recolor only) | arch h 18, w 14 | (0, 108) | ≈ 12 | pillars | live, recolor |
| H8 | Signs ("Shard Gate", "Armory") | BillboardGui hosts 0.4³ | (0, −40), (−38, −35.8) | 2 | no | live; "Boss Plaza" text → **"Shard Gate"** (Q5, decided v1.1) |
| H9 | Plaza dressing kept (3 lanterns, banner, tree, flowers, grass) + 3 Townsfolk | small | plaza | 16 + 15 | no | live `Foliage` / `Townsfolk` |
| H10 | Edge dressing kept (3 waterfalls + lips at (±37, −69), (28, 155); under-island cloud; sky shards) | live | edges | ≈ 10 | no | live `Waterfall` / `FallLip` / `Alive` |
| H11 | **Return pad** | 10×1×10 | (14, 30) | 1 | yes | new (#413) |
| H12 | **Shard Gate pad** (the live `EnterPad` moved here, Q2) | 16×1×16 | (0, 98) | 1 | yes, touch zone | new / moved (#413; Q2 decided v1.1, position from `Haven.KIT`, Echo) |
| H13 | **Crackstone** (base + crystal) + **Wren marker** | 12×2×12 + 3×9×3; Wren 2×5×2 | (−12, 52); Wren (−18, 52) | 3 | base + crystal | new (#413) |
| H14 | **Paths** (spawn↔Roll, Roll↔Gate pad, spawn↔Gate pad, Gate pad↔Muster, spawn↔Armory as 2 legs via (−24, 14)) | 10 wide, 0.05 above floor | see plan | 6 | no | new (#413; Armory leg re-routed, §7) |
| H15 | **Shard craters** (disc + embedded wedge) | 8×0.5×8 + 2×3×1 wedge | C1 (−40, 30) · C2 (36, −36) · C3 (−10, 136) · C4 (60, 40) | 8 | no | new; 3 of #413's 4 spots moved onto the floor (Q1, decided v1.1) |
| H16 | **Hollow lip band** along the real floor edge | 4 wide × 0.3, segments ≤ 32 long | 10 outline edges, 804 studs total | 26 | no (walk-on) | new; replaces #413's r 88–96 ring (Q1, decided v1.1) |
| H17 | **Edge walls** (invisible) | one Block per edge, 12 tall × 1 | outline edges, 0.5 outside | 10 | yes, Transparency 1 | new (#413 "invisible wall") |
| H18 | **Muster sockets** | 3×0.5×3 | 2×2 at (24, 90) ±3 | 4 | no | new (#413 Q3 decided) |
| — | Pull beam (Phase S, #450) | `Beam` + 2 `Attachment`s on H13 | Crackstone top → +60 | 0 parts | — | #450 |
| Hide | 5 districts + bridges, RimShop, 5 non-V1 arches, Shrine, 5 NoviceStones, waystones, Grove | — | — | −(39 arches + 12) on the floor | — | flags (`hubDistricts`, `sealedGates`, `classes`, `travel`, `grove`) |

**Floor outline (H16/H17 follow it, clockwise from the NW plaza corner):** (−52, −52) → (52, −52) → (52, 16) → (148, 16) → (148, 52) → (122, 52) → (122, 150) → (−22, 150) → (−22, 52) → (−52, 52) → back. #413's "lip r 88–96 around spawn" hangs over air west of x −22 and south of z 52 and cuts through the plaza north half, so the band follows the blocks (Q1).
**Clearances checked (on the measured part list):** Crackstone, Wren, return pad, Muster and all 4 craters overlap no live part. Gate pad edge (z 106) sits 2 studs in front of the arch pillars (z 108). Paths: the straight spawn→Armory line from #413 runs **0 studs** from the Heart pedestal corner (its 10-wide path would cut 5 studs into the pedestal); the dog-leg via (−24, 14) clears it by 4.7 studs and the Townsfolk spot at (−30, 8) by 3.5 (81 studs, 5.0 s, still under 10 s). Nothing over 2 studs tall inside the spawn → Crackstone → Gate pad triangle (live Townsfolk stand at (24, 10), (−30, 8), (8, −24), outside it).

## 5. States
| Piece | Idle | Active | Notes |
|---|---|---|---|
| H12 Gate pad | gray-box 255,196,64 rim, slow violet swirl (Phase S `Texture` scroll) | player on pad: rim brightens (Transparency 0.4 → 0, 0.2 s) + #412 dock | countdown swirl speed ×2 for 3 s (#413) |
| H13 Crackstone | crystal 120,210,255 @ Transparency 0.2 | free rolls left: gold pulse 255,196,64 every 1.2 s + "FREE" billboard; rolling: crystal `Color` = `Rarities.COLOR[tier]` for 0.3 s | Neon in Phase S; no `PointLight` (budget) |
| H7 Shard Gate | recolor body 180,140,255, edge 255,196,64; live mouth light kept | dock open: mouth light `Brightness` 0.45 → 0.8 | live `bindGateMotion` pulse stays |
| H15 craters | static | shard fall: a 2×3×1 Neon wedge tweens from y +60 into a random crater over 1.2 s + `:Emit(10)` burst | decor only; skipped on Low (`decorKeep`) |
| H16 lip | Hollow gray 110,110,116 band, Phase S fog | none | no damage, no gameplay |
| H3 guide ring | live (lit segment points at the open gate) | — | 5 hidden-gate segments not built (Q3) |
| Pull beam | — | #450 rules (Epic 186,96,240 · Legendary 255,196,64 from `Rarities.COLOR`, 1 live + 3 queued) | per-server only, nothing saved |

## 6. Numbers
**Gray-box part count on the Crater Square floor (cap ≤ 250, #413):**
| Group | Parts |
|---|---|
| Live kept (H1–H10) | 2 + 8 + 2 + 20 + 1 + 3 + 12 + 2 + 31 + 10 = **91** |
| New (H11–H18) | 1 + 1 + 3 + 6 + 8 + 26 + 10 + 4 = **59** |
| **Total** | **≈ 150 (hard cap 250, Q4 decided v1.1)** (live today on the same floor: 147 + 172 off-floor) |
| Hidden by flags | −39 sealed/raid arches, −5 NoviceStones, −4 waystone parts, −1 Shrine, −2 bridge ends, −6 guide segments, all districts (−172 off-floor) |

**Lights (cap ≤ 6, all `Shadows` false):** kept = Heart 2 (LumenHeart, LumenCore) + Shard Gate mouth 1 + 3 plaza lanterns = **6**. Today's other on-floor lights go with their flags (5 arches, 2 waystones). The 3 kept waterfalls carry under-floor lights (`Brightness` 0.28, y 116) that would make 9 → drop them (Q4). **No kit piece adds a light** (Crackstone, craters, pad use Neon only).
**ParticleEmitters (cap ≤ 6):** Shard Gate 1 (live mist) + 3 waterfall mists + Phase S shard rain 1 + Phase S lip fog 1 = **6**; the 2 live plaza foliage motes are retired for the two Phase S emitters (Q4). Shard fall burst uses `:Emit()` on the shard rain emitter (no 7th emitter). Low tier scales all rates × 0.2 (live `Quality`).
**Beams (≤ 4):** pull beam 1 (#450) + onboarding path beam 1 (#449) + 2 spare. Live `LightBeam` ×4 on the Heart are **Parts**, counted above.
**Phase S triangle split (cap ≤ 60k, #413):** Heart crack + floating shards ≤ 8k · Crackstone ≤ 3k · Oracle Wren ≤ 4k · Shard Gate reskin ≤ 5k · lip rock teeth (26 MeshParts, ≤ 350 each) ≤ 9k · 4 crater meshes ≤ 2k · Armory ≤ 3k · kept dressing + Townsfolk ≤ 10k · waterfalls ≤ 2k · headroom (players, pets, VFX) ≈ 14k. Floor stays a Part + tiling `Texture` (0 tris). ≤ 8 unique textures. 0 Unions.
**Colors (gray-box):** live floors / Heart / Armory unchanged; new pieces per #413 §9: return pad 120,210,255 · Crackstone 120,210,255 · Wren 255,255,255 · Gate pad 255,196,64 · paths 75,63,112 · craters 124,111,176 · Muster 200,180,255 · lip band **110,110,116** (Hollow gray, matches L3 drain fans and L4 remains; #413's 46,46,52 becomes the Phase S rock-teeth base). Rarity colors only on the Crackstone flash and the pull beam (`Rarities.COLOR`, never hard-coded).
**Lighting:** #413 decided fixed ClockTime 18.5. That sits inside `HavenLife.exposure`'s 18.2 glare band, which already damps it (brightness ≈ 0.75, bloom ≈ 0.02) and turns lanterns on, so it reads as dusk without a yellow screen; pin it with one fixed clock value instead of the 480 s cycle (builder note, no new Lighting rule). `Atmosphere` / `Bloom` per #413 §9 item 9.

## 7. Edge cases
- **StreamingEnabled:** `Haven` is Persistent, so the whole hub replicates at join no matter `StreamingMinRadius` 128 / `StreamingTargetRadius` 512; the far court corner (122, 150) is 171 studs from spawn and would stream late if it weren't Persistent. Keep `CraterKit` inside `Haven` (Persistent). Persistent means **every hub part costs phone memory all session**, so the budget lever is "don't build" (flags), never Transparency 1 or far placement. The wave arena at (0, 240, 12000) stays outside `Haven` and streams on teleport (live `RequestStreamAroundAsync` path); the hub needs no stream request on return.
- **Walk-offs:** H17 walls on all 10 edges, including the 5 old bridge mouths (bridges hidden). The plaza north edge waterfalls stay visible past the wall. `FALL_Y` 60 respawn stays.
- **Old saves / hidden content:** a save pointing at a hidden district loads on the spawn pad; hidden prompts' remotes refuse on the server (#413 §7, Havoc risk 3). Kit pieces add no remote.
- **Two Gate triggers:** today the live `EnterPad` is inside the arch at (0, 108). Adding #413's pad at (0, 98) without moving it would give two triggers 10 studs apart; move it (Q2).
- **20+ players on spawn:** return pad H11 keeps arrivals off the Gate pad; paths are 0.05 thin (no tripping); Townsfolk stay out of the spawn triangle.
- **Low tier / low-end phone:** `decorKeep` 0.34 hides 2/3 of trim decor locally; first to go are shard-fall wedges, H15 wedges, kept foliage, lip rock teeth (Phase S); never the Gate, Crackstone, pads, paths, walls.
- **Camera:** nothing over 2 studs in the spawn triangle; the 36-stud Heart is behind the spawn camera. Edge walls are invisible and `CanQuery` false so the camera never pops on them.
- **Hard (Lv 5):** no hub change; Hard lives in the #412 dock.

## 8. Mockups
SVG in `mockups/` (original art, fake data; PNG renders stay on the box):
- `01-hub-plan-topdown.svg`: real floor blocks in studs, kept / hidden (dashed) / new pieces, Hollow lip band on the outline, paths with the Armory dog-leg, craters moved onto the floor, walk times, spawn sight cones (40° portrait, 70° landscape).
- `02-kit-sheet.svg`: new-piece elevations to scale with a 5-stud player, gray-box counts vs ≤ 250, lights / emitters / beams vs caps, Phase S tri split.
- `03-phone-read-check.svg`: spawn camera at 390×844 and 667×375 with live HUD zones dashed: Gate + billboard centered, Crackstone + Wren at the left edge (portrait), paths reading, no new screen UI; notes for 800×400 and desktop.

## 9. Build split
- **Echo / Ghost (flags pass, first, request):** `hubDistricts` + `sealedGates` off gate the district, bridge, RimShop and 5-arch builders and their prompts / remotes (#413). Also gate `NoviceStone` behind `classes` and waystones behind `travel` (Q4).
- **Echo (build note, v1.1 Q2):** the `EnterPad` position/size for H12 comes from Haven config (`Haven.KIT.gatePad` = (0, 98), 16×1×16), not a literal in the builder; Prism does not edit config.
- **Ghost (gray-box pass):** H11–H18 in `CraterKit` (sizes in a `Haven.KIT` table, not literals), place `EnterPad` on H12 (Echo config), recolor H7, trim H3 to the open gate, rename H8 to "Shard Gate", drop waterfall lights, pin ClockTime 18.5. Studio checks at 390×844, 667×375, 800×400, 1280×720.
- **Prism:** Phase S mesh briefs (Heart crack, Crackstone, Wren, lip teeth, craters, Gate reskin, skybox) after M13; screenshot color check.
- **Havoc:** walk every edge (0 falls in 20 tries), 20-player spawn crowd, phone FPS on Low with 4 players + 1 pull beam, old-save load on a hidden district.
- Build waits for Ghost's go; art stays gray-box until Phase S.

## 10. Pass criteria (playtest)
1. Fresh tester at 390×844 sees the Gate + billboard on the first frame and finds the Crackstone within 5 s; at 667×375 / 800×400 / desktop both are in the first frame.
2. Spawn → Roll ≤ 10 s (target 1.6 s), Roll → Gate pad ≤ 10 s (3.0 s), spawn → Armory ≤ 10 s (5.0 s), timed on foot.
3. 0 walk-offs in 20 attempts along all 10 edges; no stuck spots on paths or crater lips.
4. Studio count on the Crater Square floor: ≤ 250 parts gray-box, ≤ 6 PointLights, ≤ 6 ParticleEmitters, ≤ 4 Beams; with flags off, no district, sealed arch, Shrine, NoviceStone or waystone exists in Explorer.
5. Low-end phone on Low: ≥ 30 FPS with 4 players on spawn and one pull beam; ≥ 25 FPS with 20 players.
6. Every prompt tap target ≥ 44 px on touch (live `ProximityPrompt` button); billboard text ≥ 18 px at 390 wide.
7. Testers describe the hub as "a crater with a crystal" and notice the gray edge, in a screenshot, without being told.

## 11. Open questions (answer by number; Q1–Q5 answered in v1.1)
1. ~~**@Ghost:**~~ **DECIDED v1.1 (Ghost DP31P): yes.** Snap to the real floor: lip band H16 and walls H17 follow the 10-edge block outline (804 studs) instead of #413's r 88–96 ring around spawn, and 3 of #413's crater spots move onto the floor ((−60, 60) and (−44, 104) are over air; (52, −28) hangs half off the plaza) to C1 (−40, 30), C2 (36, −36), C3 (−10, 136); C4 (60, 40) stays. **Recommended: yes**; Prism folds the numbers into #413 next.
2. ~~**@Ghost:**~~ **DECIDED v1.1: yes**, `EnterPad` sits on the pad, positioned via Haven config (Echo build note). Move the live Rootvault `EnterPad` from (0, 108) to the #413 Gate pad H12 at (0, 98) (one trigger, in front of the arch) instead of adding a second pad? **Recommended: yes, move it.**
3. ~~**@Ghost:**~~ **DECIDED v1.1: yes, trim.** Court guide ring H3: build only the open gate's 2 segments (the 6 inlays stay as floor dots), so no lit guide points at a hidden arch? **Recommended: yes** (−6 parts).
4. ~~**@Ghost (Echo):**~~ **DECIDED v1.1: yes, trims accepted; hard cap stays 250 parts.** Budget trims to hit #413's caps: gate `NoviceStone` ×5 behind `classes` and waystones behind `travel` (both built today with the flags off), drop the 3 under-floor waterfall `PointLight`s (lights 9 → 6), retire the 2 plaza foliage motes for the Phase S shard rain + lip fog (emitters 8 → 6)? **Recommended: yes to all four.**
5. ~~**@Ghost:**~~ **DECIDED v1.1: rename to "Shard Gate"** (matches the pad; Ghost's call over Prism's "Crater Square"). The live plaza sign still says "Boss Plaza" (there is no boss in the hub).
6. **@Kevin (taste, still open):** Phase S lip look: **Hollow-gray broken rock teeth** (flat stubs, the L4 "flat broken = Hollow" rule, color draining at the edge) or leaning prismatic shards like the arena lip (L1)? **Recommended: gray broken teeth on the hub lip**, prismatic shards only around the Lumen Heart, so the story reads "the shard's light, the Hollow eating the edge".

## Decision log
- 2026-10-24 (Ghost DP29, Kevin pre-approved for Prism to write it; Prism): **T7 v1** on `prism/t7-hub-art-kit`, built on the live `HavenBuilder` (measured), #413, L3 #452 and #450. 18 piece rows (10 live, 8 new), hidden-by-flag list, ≈ 150 gray-box parts vs ≤ 250, lights 6 / emitters 6 at cap, Phase S tri split ≤ 60k, StreamingEnabled notes. Open: Ghost 1–5, Kevin 6. Not approved.
- 2026-10-24 (Ghost DP31P, Kevin pre-approved; Prism): **T7 v1.1**: Q1 snap to real floors yes; Q2 `EnterPad` on the pad via Haven config (Echo note); Q3 guide ring trimmed; Q4 budget trims accepted, hard cap 250; Q5 sign renamed "Shard Gate". Mockups 01/02 relabeled. Still open: Kevin Q6 (lip look). Not approved.

## Later (not V1)
District islands back (`hubDistricts` on), seasonal hub dressing, a second hub ring for raids, animated Townsfolk routes, a real skybox swap per event. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox only: `Part` (Block, Wedge, Cylinder), `MeshPart` (Phase S), `Texture`/`Decal`, `Beam`, `ParticleEmitter`, `PointLight` (≤ 6, `Shadows` false), `Sky`, `Atmosphere`, `Bloom`, `BillboardGui`, `ProximityPrompt`, TweenService. **No screen UI is added**; any later screen UI follows Frames/ImageLabels + `UICorner` / `UIStroke` / `UIGradient`, ≥ 44 px targets, panels that collapse and stay off the center. No blur, no `ColorCorrection` (global; "color draining" is per-part color), no SurfaceAppearance on phone-critical pieces, no Unions.
| Piece | Instances |
|---|---|
| `CraterKit` | `Model` under `Haven` (inherits Persistent); every child Anchored; decor `CanCollide` / `CanQuery` / `CanTouch` false, `CastShadow` false |
| H11 return pad | `Part` 10×1×10, SmoothPlastic, Color 120,210,255, CanCollide true; rejoin / run-end teleport targets its top + 3 |
| H12 Gate pad | the live `EnterPad` (attribute `EnterDungeon`), resized 16×1×16, moved to (0, 98); rim = child Neon `Part` ring of 4 thin Blocks 16×0.1×0.4, Color 255,196,64; Phase S swirl = `Texture` with `OffsetStudsU` tween |
| H13 Crackstone | base `Part` 12×2×12 + crystal `Part` 3×9×3 (Neon in Phase S, Color 120,210,255); `ProximityPrompt` "Roll" on the base (`HavenAction` roll, `RequiresLineOfSight` false, `MaxActivationDistance` 10); `Attachment` at the crystal top for the #450 beam; flash = `TweenService` on `Color` to `Rarities.COLOR[tier]`, 0.3 s; Wren = 2×5×2 `Part` + `BillboardGui` name (`MaxDistance` 80, text ≥ 18 px) |
| H14 paths | `Part` Blocks 10 wide × 0.05, top at `FLOOR_Y + Haven.LAYER` (no z-fighting), Color 75,63,112, CanCollide false |
| H15 craters | disc `Part` 8×0.5×8 Color 124,111,176 + `WedgePart` 2×3×1 (Neon in Phase S); shard-fall = one pooled Neon wedge tweened 1.2 s Quad In + `:Emit(10)` on the shard rain emitter |
| H16 lip band | `Part` Blocks 4 wide × 0.3, ≤ 32 long, on the outline, Color 110,110,116, SmoothPlastic; Phase S: 26 rock-teeth `MeshPart`s (≤ 350 tris, `CollisionFidelity` Box, CanCollide false) + 1 fog `ParticleEmitter` (Rate ≤ 6) |
| H17 edge walls | `Part` Block per edge, 12 tall × 1 thick, Transparency 1, CanCollide true, CanQuery false, CanTouch false |
| H18 Muster | 4 `Part` 3×0.5×3, Color 200,180,255; no logic until Phase 6 |
| Lighting | one fixed `ClockTime` 18.5; `Atmosphere` Density 0.32, Color 150,130,200, Decay 90,80,120, Haze 1.5; `Bloom` Intensity 0.6 / Threshold 1.6 (#413 §9) |
| Pull beam | #450: `Beam` Width 3, `LightEmission` 1, Color = `Rarities.COLOR` Epic / Legendary, between the H13 top `Attachment` and one +60 above; 1 live, 3 queued |

Image assets (Phase S, PNG): skybox_broken_prism ×6 (1024², shared with L3, brighter), crater_floor_512 (tileable plaza `Texture`, StudsPerTile 16), gate_swirl_256, lip_fog_64 (particle). Gray-box needs none.
