# Dungeon Look: "Shard Crater", Spec v1.1 — Phase S theme

Owner: Prism (design, no code). Builders: Ghost (world/VFX), Echo (wave/boss/loot hooks). Base: `cursor/live-build-9721` @ `9269e61`. Docs only.
Asked for in: Agent Board "Prism: overnight queue" (https://app.notion.com/p/403c31ca38838160b0afc69d00631416). Aligned to Ghost's Kevin-approved decisions row (https://app.notion.com/p/403c31ca38838189b1c5ed1249a17e57), decisions 1, 3, 4, 7, 9. **Phase S art; the gray box can follow the #382 fix.**
Locked numbers (Vision & Design Rules + decision 1): arena **90 studs across**, 3 edge gates, waves 6/8/10/12, wave 5 = boss + 4 adds, no run timer, party 1–4, elements Ember/Frost/Void, **no Leave button, keep all earned loot**. Element colors reuse the live arch colors: Ember 255,150,40 · Frost 186,228,255 · Void 150,70,220.

**v1.1 changelog (Oct 23, 2026):** renamed "The Shattered Nave" → **Shard Crater** (decision 3, theme B: new and original, matches the Crater Square hub; Gnarl/Verdant stays parked). The arena is now the impact crater of a fallen shard: crater floor, shard veins, crater lip with leaning crystal shards, 3 rifts as the edge gates. Removed the south "player entry" arch (no Leave, no exit). Added auto-collect loot at wave end and on wipe (decision 9) with full-Bag feedback (Havoc risk 1). Element-leaning waves are Config-only tuning (decision 7, Echo). Ø90 taste call settled.

## 1. Goal
One arena theme that makes every wave feel like the fallen shard is fighting back: dark readable floor, enemies that pop by silhouette at phone zoom, clear "wave start / wave clear / boss / loot" moments made only of world parts, lights, particles and the existing toasts. It must read as the same world as Crater Square.

## 2. Where it lives
- The round wave arena (Roadmap 3.2, PR #382 arena, fixed in place by Echo per decision 1) — this is its skin. Same footprint (90 across), same 3 edge gates, same spawn logic. It is the **only** V1 dungeon (old Rootvault Waves + room crawl parked behind a flag, decision 4).
- Screen UI: existing wave toast, attack button, Bag button. One new element: the wave-end loot chip (reuses the #397 toast style). No Leave button.

## 3. Flow
1. **Arrive (drop-in):** fade in on the 4 party sockets at z +30 with a small shard-landing burst (12 particles) at each socket; veins dim, rifts dark, ambient hum.
2. **Wave start (each wave):** 0.0 s shard veins sweep from the Impact Core outward (0.6 s) → 0.4 s the active rifts flare in the wave's element color (inner Neon plane 0 → 0.2 transparency, burst of 30 particles) → 0.8 s enemies step out of the rift mouths. Existing "Wave n/5" toast plays. If Echo's Config leans a wave toward one element (decision 7), the rifts simply take that color; no extra art.
3. **Fight:** rifts keep a slow pulse while they still spawn; a rift goes dim when it has spawned its last enemy. Drops land on the floor as small rarity-colored shard motes.
4. **Wave clear:** last kill → veins flash white (0.25 s) → **loot auto-collect:** every drop on the floor tweens to its owner (0.5 s arc, rarity-colored trail) and the loot chip shows "+N loot · wave n" for 2 s → shard shower from above (40 particles, 1.5 s) → `Lighting` ExposureCompensation +0.3 for 0.8 s.
5. **Boss entrance (wave 5):** side rifts dim → 1.5 s rumble (dust burst at the N rift base, camera shake ≤ 0.3 studs (decided yes), off on reduced motion) → the N rift's two shard slabs slide apart (Tween 1.0 s) → red-violet Beam + light from the mouth → Hollow Warden walks out (2 s) with a BillboardGui name → 4 adds from E/W rifts. Boss HP bar is existing UI.
6. **Run end:** win = loot auto-collect + shard shower ×2 + rifts go gold → results → return to the Crater Square return pad. Wipe = **loot auto-collect first**, then veins fade to gray, chip "All loot kept" → results → return pad. There is no Leave; disconnect, wipe, timeout or the win are the only ways out.

## 4. Layout
Map: `mockups/01-arena-topdown.svg`. Origin = arena center.
| Thing | Size (studs) | Notes |
|---|---|---|
| Crater floor | Ø90 | dark fractured stone (34,28,58), 3 dashed vein rings (r 12, 26, 38) + 12 radial shard veins (Neon strips 0.4 wide) |
| Impact Core | Ø12 center | raised 0.2, a stub of the fallen shard flush with the floor (no cover, no block); lights on wave start |
| Crater lip | Ø100, 14 tall | cracked rock wall with 18 leaning crystal shards (same shard shape as the Crater Square craters); not climbable (invisible wall to 30 tall) |
| Rifts ×3 (edge gates) | frame 16 w × 20 h | N (boss rift, red-violet trim 255,90,110), ESE and WSW (tint to wave element) |
| South side | solid lip | no entry arch, no exit (no Leave) |
| Party sockets | 4, 6 apart at z +30 | drop-in points; rejoin also lands here |
| Ceiling | none (open sky) | same broken prismatic sky as Crater Square, darker, with sparse falling shard streaks |

Camera check: at default zoom the rift tops (20 tall) are visible from the center on 800×400 and 667×375; on 390×844 portrait at least the nearest rift. See `mockups/02-wave-start-800x400.svg` (also shows the loot chips top-right, outside the keep-out; §6 has the exact sizes per viewport).

## 5. States
- **Rift:** sealed (dark, 0.9 transparency inner) · spawning (element color, pulse 1 Hz) · spent (dim) · boss (slabs open, red-violet).
- **Shard veins:** idle (cyan 120,210,255 at 0.7 transparency) · wave start sweep · clear flash (white) · wipe (gray).
- **Loot motes:** on floor (rarity color, 1 Hz bob, Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64) · collecting (tween to owner) · gone.
- **Loot chip:** "+N loot · wave n" (green stroke) · "Bag full · N held for you" (amber stroke 255,168,48, plus a "!" badge on the Bag button) · "All loot kept" (on wipe).
- **Lighting:** fight (default) · boss (Atmosphere Color tints to 120,60,110 over 2 s) · clear (exposure pulse).

## 6. Numbers
- Floor Ø90 (decision 1), lip Ø100, 14 tall; rifts 16×20; lip shards 18.
- Wave start 0.8 s from veins to first enemy; wave clear effects 1.5 s (auto-collect 0.5 s inside that); boss entrance 4.5 s total (no gameplay waits longer than the existing wave break).
- Loot chip: 2 s, text ≥ 13. It goes through the **one toast lane** (phone layout review D3, §4a): max 1 toast on screen and the rest queue (it no longer stacks 2). As a loot toast it goes before queued info toasts (wave, Resonance). Lane slot: **portrait 390×844** x 88–266, y 231–267 (178×36); **667×375** top band x 411–651, y 8–44 (240×36); **800×400** top band x 524–784, y 8–44 (260×36); **desktop** top-center x 480–800, y 66–102 (320×36). (F14's notice-column places are replaced.) The wave toast stays top-center; the chip is never "under" it.
- Enemy heights: chaser 3, ranged 4 (floats 3 up), tank 7, boss 14 studs.

### Phone performance budget (arena + max wave 12 enemies + party of 4)
| Budget | Cap |
|---|---|
| Arena parts/MeshParts | ≤ 400 |
| Arena triangles | ≤ 35k |
| Per enemy | ≤ 12 parts / ≤ 1.5k tris (boss ≤ 40 parts / 6k tris) |
| Loot motes on floor | ≤ 40 (pooled; extra drops merge into one mote per owner) |
| Lights | ≤ 5 (center + 3 rifts + boss), Shadows false |
| ParticleEmitters | ≤ 8 in arena, bursts via `:Emit()`, live ≤ 300 |
| Beams | ≤ 4 |

## 7. Edge cases
- Wave with enemies only from one rift: only that rift flares.
- Element-mixed wave: each rift takes the color of what it spawns; if mixed, violet neutral (200,180,255).
- Reduced motion / low quality: no camera shake; bursts at half count; loot motes snap instead of arcing.
- Player stands in a rift mouth: invisible blocker past the frame; enemies spawn 4 st inside the mouth and push out.
- Boss dies during its entrance: not possible (invulnerable until slabs open; Echo hook).
- Wipe: no red "loss" flash; gray fade only (keeps the "always keep loot" tone).
- **Auto-collect is server-side, once per drop (Havoc risk 1):** wave end and wipe in the same frame, or a player leaving mid-collect, must not dupe. The VFX only plays what the server already granted.
- **Full Bag never silently drops loot (Havoc risk 1):** the chip says "Bag full · N held for you" and the Bag gets a badge. Held items go to a per-player overflow list (server-owned, Config cap) shown on the results screen (§11 Q4, Echo).
- **No Leave (Havoc risk 2):** disconnect/wipe/timeout is the only exit; rejoin keeps earned loot exactly once and lands on the return pad, never inside a dead arena.
- **Hard (Lv 5) entry is checked on the server (Havoc risk 4).**
- Long runs: enemy and loot-mote pooling needs a leak test (Havoc risk 5); the mote cap above helps.

## 8. Mockups
`mockups/01-arena-topdown.svg` (layout + studs, Shard Crater labels) · `mockups/02-wave-start-800x400.svg` (wave start, phone landscape, keep-out box, 44+ px UI, loot + full-Bag chips) · `mockups/03-enemy-look-sheet.svg` (4 roles × 3 elements + pure-black phone-zoom silhouettes). Original designs, fake data. PNG renders are on the box only.

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
**Gray box (Ghost, after Echo's #382 fix):** floor as block segments (34,28,58) + Neon vein strips · Impact Core block · 18 lip-shard wedges (90,74,138) · 3 rift frames (3 blocks each) + inner Neon plane · N rift 2 slab doors · invisible walls · 4 party sockets. Enemies: block stand-ins at the right heights with Neon trim in element color.
**Art pass (Phase S):** lip rock + shard + rift MeshParts · floor crack Texture · vein Neon strips · enemy meshes per sheet · emitters (rift flare, vein sweep via a Neon ring part tweened in Size, shard shower, drop-in burst, boss dust, element motes) · loot mote (`Part` Neon 0.6 + `Trail`) · Lighting: Atmosphere Density 0.38, Color 110,90,170, Haze 2; Ambient 50,40,80; Bloom 0.7.
**Echo hooks (read-only ask):** wave-start, rift-spent, wave-clear, loot-granted (per player, with held/overflow count), boss-enter, run-end events the client VFX can listen to. Element lean per wave lives in Config only (decision 7).
Roblox notes: vein "sweep" = a thin Neon ring (MeshPart or ring of parts) whose Size tweens out; loot chip = `Frame` + `UICorner` 15 + `UIStroke` 2 + `TextLabel` (the #397 toast); no shaders, no blur, no post effects beyond Bloom/Exposure.

## 10. Pass criteria
- [ ] Crater floor Ø90, 3 rifts, no Leave button, readable at 390×844 / 667×375 / 800×400 / desktop.
- [ ] At phone zoom, testers name chaser/ranged/tank/boss from silhouette alone (4/4) and the element from color (3/3).
- [ ] Wave start ≤ 0.8 s to first enemy; boss entrance ≤ 4.5 s.
- [ ] Every floor drop is collected at wave end and on wipe, exactly once; a full Bag shows the amber chip, never a silent drop.
- [ ] Testers say it "looks like the same world as the hub" (shard + crater read).
- [ ] Budget met with 12 enemies + 4 players on a low-end phone (≥ 30 FPS); existing touch targets ≥ 44 px.

## 11. Open questions
1. ~~Arena size Ø90?~~ **Settled by Ghost's decision 1 (Oct 23, 2026): 90 studs across.**
2. ~~@Kevin: Boss entrance camera shake?~~ **Yes (Ghost, Kevin pre-approved, Oct 23, 2026).** At most 0.3 studs, off on reduced motion. Board row: https://app.notion.com/p/403c31ca388381c0bb72d75abab9bd4d
3. ~~@Kevin: Keep or rename enemy names?~~ **Keep Shardling, Prism Wisp, Bulwark, Hollow Warden (Ghost, Kevin pre-approved).**
4. ~~@Echo: Where do held items go when the Bag is full?~~ **A per-player overflow list (Echo, Oct 23, 2026).** Server-owned, capped in Config, shown on the results screen as the chip count. Never past-cap Bag slots. Keeping it across sessions needs a schema note to Ghost first. Board row: https://app.notion.com/p/403c31ca388381dba1c1f358d0618f00

## Decision log
- 2026-10-23 (Ghost, Kevin pre-approved): Phase S theme = B, a new original Shard Crater matching Crater Square; Gnarl/Verdant parked. Arena 90 across, 3 edge gates, no Leave, keep all earned loot; floor loot auto-collects at wave end and on wipe. Element-leaning waves are Config-only (Echo). → v1.1.
- 2026-10-23 (Ghost, Kevin pre-approved): boss-entrance shake = **yes** (off on reduced motion); enemy names kept. (Echo): held full-Bag items go to a per-player overflow list, Config-capped, shown on results. All §11 questions are now closed.
- 2026-10-23 (Prism, phone layout review, docs/design/phone-layout-review/REVIEW_v1.md): loot chip sizes and places set per viewport (F14). It used to say "top-right under the wave toast", but the wave toast is top-center, and a 220 px chip at the top-right crossed the landscape keep-out. No design change.
- 2026-10-24 (Ghost, Kevin pre-approved, board row https://app.notion.com/p/403c31ca38838103a80ad21380d7f451; folded by Prism from the phone layout review rev 1.1, docs/design/phone-layout-review/REVIEW_v1.md §8/§10): D3: the loot chip goes through the one toast lane (max 1 on screen, the rest queue, loot before info), so it no longer stacks 2, and the lane slots replace F14's places (§6). D1 (portrait keep-out top 35%) and D2 (hub cluster hides under ROLL/Gate dock) don't change this arena spec.
