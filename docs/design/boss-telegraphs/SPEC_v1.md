# Boss Telegraphs ("Ground lanes + ring"): Shard Volley + Leash Slam read spec, v1

Owner: Prism (design, docs only, no code). Builders: Ghost (client visuals, boss bar cue), Echo (server telegraph state on the boss). Base: `cursor/live-build-9721`. Status: **v1, waiting on Ghost** (Ghost GO on the Agent Board, Kevin pre-approved: https://app.notion.com/p/403c31ca388381758d47e930e50ccb27, Oct 24, 2026). Gray-box safe (pre-Phase S): stock Parts, Beams, Trails and default ParticleEmitters only, no new art. Not an official Vision & Design Rules decision until Kevin approves it.
Asked for in: Ghost's board row item 1: "Boss Shard Volley + slam-dash telegraph read spec (0.9s windup per #431): phone-readable shapes/colors, ParticleEmitter notes, gray-box safe." Roadmap **3.6** (wave-5 boss).

Sources (link, don't copy):
- **PR #431** (`e7abb8e`, "Pay the wave-5 boss clear once and stop a blocked slam", stacked on #427/#425/#419) – read only:
  - `Shared/Config/Enemies.luau`: `VOLLEY_WINDUP = 0.9`, `VOLLEY_SHOTS = 3`, `VOLLEY_SPREAD = 0.12` rad, `VOLLEY_SPEED = 64` studs/s, `VOLLEY_COOLDOWN = 5`, `VOLLEY_LEAD_MAX = 24`; `PRESSURE_SECONDS = 4`, `PRESSURE_DECAY = 1.5`; `LEASH_RANGE = 24`, `LEASH_SECONDS = 3`, `LEASH_WINDUP = 1.2`, `LEASH_RADIUS = 4`, `LEASH_DASH = 40`; `SHOT_RADIUS = 2`. `BOSS` row: melee, range 9, moveSpeed 5, gray box 7.5×9×7 studs, color 58,58,62.
  - `Shared/EnemyRoster.luau`: `actor.volley = { left }` (windup), `actor.mark = { x, z, left }` (slam). The lead is computed **at fire time** (`fireVolley`), not at windup start. A live slam mark **pauses** the volley windup (it doesn't cancel it). A blocked boss→mark line cancels the mark before the dash moves.
  - `ShardfallServer/EnemyTypeService.luau`: "There is no remote" – telegraph state is server memory only today. Flag `enemyTypes` ships **off**.
- Note on the brief: **0.9 s is the volley windup**. The slam's windup is its own number, `LEASH_WINDUP` **1.2 s**. This spec uses both as they are in Config.
- Specs this must match: **Wave HUD v1.1** (`prism/wave-hud`, PR #428: boss bar portrait x 16–206, y 179–223; landscape top band; Normal HP orange 230,120,70 PROVISIONAL, Hard red). **#420 phone layout review rev 1.1** (keep-out, D1, D3 one toast lane). **#414 Shard Crater** (arena, gray-box). **Hard accent pass v1** (`prism/hard-accent`, this batch). **Hard mode selector v1.1**.
- Chrome: PR #392 `docs/ui/reference/STYLE.md` (panel 28,24,40 · row 40,34,58 · gold 255,196,64 · danger 230,80,96 · corners 8/10/12 · Builder Sans). Rarity colors (`Shared/Rarities.luau`) are **not** used for telegraphs, so a telegraph is never mistaken for loot.

## 0. Directions (pick one) and recommendation
Mockup: `mockups/08-directions.svg`.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Ground lanes + ring** | World shapes on the arena floor. **Volley:** 3 orange lanes (one per shot) grow from the boss toward you and track you for 0.75 s, then flash white for the last 0.15 s and fire. The boss's chest gem charges (ParticleEmitter). **Slam:** an orange ring with 4 rim ticks drops at your feet; an inner disc fills from the center to the rim over 1.2 s; impact when it meets the rim. A dashed beam + trail shows the boss dashing in. The boss bar shows the attack name as a small orange tag for the windup. | Tells **where** and **when** at phone size. Shape carries the meaning (lines = dodge sideways / take cover, circle = step out), so it works without color. Gray-box: Parts, Beam, Trail, default emitters. | More parts to spawn per attack (≤ 6 per telegraph). |
| B | Body tells only | The boss glows orange and leans back before the volley, crouches before the slam. No floor shapes, no HUD cue. | Cheapest; no extra parts. | No direction for the volley, and a 4-stud ring is invisible without a floor mark. On a phone the boss is ~90 px tall, so a lean is easy to miss. |
| C | Screen alerts | Red edge flash + a big "SHARD VOLLEY!" banner on every windup. | Impossible to miss. | Sits in the center keep-out, doesn't say where to move, red clashes with the Hard tint and the HP bar, and it gets tiring by the 10th volley. |

**Recommendation: A.** It's the only one that tells the player where to move as well as when, and it stays out of the screen center. The rest of this spec is A.

## 1. Goal
On a 390×844 phone, a player who has never seen the boss can tell within one windup that (1) a Shard Volley is coming, from which direction, and when it fires, and (2) a slam is coming, where it lands, and that stepping out of the ring avoids it. Every boss hit should feel fair: "I saw that and could have moved."

## 2. Where it lives
- **World (Ghost, client):** telegraph visuals are built **locally** on each client from state the server puts on the boss model (recommended, Q1). One `Folder` `BossTelegraphs` under the arena; nothing is saved.
- **Server (Echo):** while a windup is live, the boss model carries attributes: `VolleyEnd` (server time when the shots fire, `workspace:GetServerTimeNow()` + `left`), `VolleyTarget` (UserId being tracked), `MarkX`, `MarkZ`, `MarkEnd`, and `MarkCancel` (set true for one tick when a blocked path cancels it). Cleared when the windup ends. No remote, no profile, no save (schema stays 26). Prism doesn't touch `EnemyRoster`/`EnemyTypeService`.
- **HUD (Ghost):** the **Wave HUD boss bar** (#428) gets a small attack-name tag + a 2 px windup drain under the HP bar. No new panel. Optional off-screen edge pointer (Q5).
- **Not here:** damage numbers, screen shake on every attack (one small shake on slam impact only, Q4), audio (Phase S; Echo/audio spec), any Robux.

## 3. Flow
| Step | Trigger (server, #431) | What the player sees | Time |
|---|---|---|---|
| V1 | Pressure armed (4 s without damage) **and** target outside melee (range 9) **and** cooldown 0 → `actor.volley` set | Boss bar tag **SHARD VOLLEY** pops (UIScale 0 → 1.1 → 1, 0.12 s). Boss gem goes orange, emitter starts drawing dots in. 3 lanes start at the boss and grow toward the tracked player. | 0.00 s |
| V2 | windup ticking | Lanes reach full length at 0.75 s and **track** the player's current position each frame (the lead isn't known until fire). Chevrons on each lane point at the player. Drain under the boss HP bar runs out. | 0.00–0.75 s |
| V3 | `left` ≤ 0.15 | **Flash:** lanes + gem tween to white (255,244,230), lane width +20%. This is the "move now" beat. | 0.75–0.90 s |
| V4 | `fireVolley` | Lanes vanish (0.05 s). 3 bolts fly (64 studs/s; ~0.4 s at 24 studs). Each bolt = small Neon part + Trail. A bolt that hits cover pops (8-dot burst). | 0.90 s → |
| V5 | cooldown 5 s | Tag fades. Nothing on screen. | — |
| S1 | Target beyond 24 studs for 3 s → `actor.mark` set at the target's feet | Boss bar tag **SLAM**. Orange ring (radius 4 studs) + 4 white rim ticks appear at your feet (0.1 s pop). A dashed beam from the boss to the mark. | 0.00 s |
| S2 | windup, boss dashes at 40 studs/s | Inner disc fills from the center (0 → rim) over 1.2 s, linear, so the fill meeting the rim = impact. Boss gets a Trail (orange → transparent); the mockup draws it as faded copies. | 0.00–1.20 s |
| S3 | `left` ≤ 0 and target inside 4 studs | Impact: ring flashes white, 24-particle burst, one small camera shake (Q4), then the ring is gone in 0.25 s. Outside the ring: same visuals, no hit. | 1.20–1.45 s |
| S4 | Blocked path (`MarkCancel`) | **Fizzle:** ring turns gray (150,150,160), dashed, fades in 0.15 s; tag disappears. Teaches "cover cancels the slam". | ≤ 0.15 s |
| — | A live mark while a volley windup is running | The volley lanes **freeze** (no growth, dimmed to 50%) while the mark is live, then resume. Matches the code (mark pauses the windup). | — |

Wipe/clear during a windup: every telegraph part is destroyed with the arena (no orphan rings).

## 4. Layout
Full-screen px, same frame as the #420 review. World telegraphs are 3D and can cross the center keep-out (that rule is for UI panels); every **UI** piece in this spec stays out of it.

**Center keep-out (UI only):** 390×844 x 117–273, y 296–616 (D1, provisional) · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526.

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Boss bar (Wave HUD v1.1, unchanged) | x 16–206, y 179–223 | top band x 160–403, y 8–48 | top band x 200–516, y 8–48 | x 440–840, y 110–150 |
| Attack tag (new, inside the bar) | right-aligned in the bar's title row, 16 px tall, text 9 px heavy, ink on orange | same | same | same, text 10 px |
| Windup drain (new) | 2 px under the HP bar, full bar width, orange, drains to 0 | same | same | same |
| Edge pointer (Q5, display-only) | 24×28 triangle + "VOLLEY"/"SLAM" 9 px label, on the screen edge at the boss's bearing, clamped to y 242–566 (beside the rail/skill bar, never in the keep-out) | clamped to x 0–24 / 643–667 edges, y 60–300 | same | same |
| World: lane | 4 studs wide (2 × `SHOT_RADIUS`) at the far end, 1 stud at the boss; length = boss→player + 12% | — | — | — |
| World: ring | radius 4 studs (`LEASH_RADIUS`), 0.2 stud thick rim, 4 rim ticks 1 stud long | — | — | — |

Size check (default camera, gray-box arena): the boss box is ~90 px tall on 390×844, the 8-stud ring is ~150 px wide, a lane is ≥ 30 px wide at the player. Telegraph lines are ≥ 2 px, rim 3–4 px, chevrons 2.4 px stroke.
Checks: nothing tappable is added (the tag, drain and pointer are display-only; no 44 px target needed). No UI enters the keep-out at any of the 4 sizes. The tag never covers the boss name or HP bar.

## 5. States
| Element | Idle | Windup | Flash (last 0.15 s) | Fired / landed | Cancelled | Paused |
|---|---|---|---|---|---|---|
| Volley lanes | none | orange 255,120,40 at Transparency 0.5, white edges + chevrons, length grows 0 → 1 over 0.75 s, track target | white 255,244,230, Transparency 0.4, width +20% | destroyed (0.05 s) | — (volleys don't cancel) | frozen, Transparency 0.75 |
| Boss gem | gold Neon 0.6 | orange, emitter Rate 0 → 60 | white, PointLight Brightness 2 | back to gold | — | orange, emitter Rate 10 |
| Slam ring | none | orange rim + white ticks, inner fill grows 0 → 1 over 1.2 s | at ≥ 0.9 fill, rim pulses white once | white flash + burst, gone in 0.25 s | gray dashed, fades 0.15 s | — |
| Dash beam | none | dashed white over orange, boss → mark | — | gone | gone | — |
| Boss bar tag | hidden | "SHARD VOLLEY" / "SLAM" (orange fill, ink text) | tag pulses `UIScale` 1.08 once | hides 0.3 s after | hides at once | stays |
| Edge pointer | hidden | shown when the boss's screen point is off-screen or behind the camera | pulse | hidden | hidden | — |

Error/loading: if the attributes arrive late (lag), the client starts the visual with the **remaining** time from `VolleyEnd`/`MarkEnd` (never restarts at 0.9/1.2), so the flash still lines up with the real fire. If less than 0.15 s is left on arrival, show the flash frame only.

## 6. Numbers
- Volley: windup **0.9 s** (`VOLLEY_WINDUP`), lanes grow 0–0.75 s, flash 0.75–0.9 s; 3 shots, spread ±0.12 rad, 64 studs/s, cooldown 5 s; arms after 4 s with no damage dealt, only outside range 9.
- Slam: after **3 s** beyond **24 studs**; windup **1.2 s** (`LEASH_WINDUP`); ring radius **4 studs**; dash 40 studs/s; impact burst 0.25 s; fizzle 0.15 s.
- Lane width: 1 → 4 studs (hit band = 2 × `SHOT_RADIUS`). Lane length: boss→player × 1.12.
- Colors (telegraph palette, same on every tier): threat orange **255,120,40** (PROVISIONAL, Kevin taste Q6), flash white **255,244,230**, fizzle gray **150,150,160**. Not Hard red (230,80,96), not Legendary gold (255,196,64), not any rarity color.
- Hard (#430): enemies 2× HP, 1.5× damage. **Timings and colors do not change on Hard.** On the red-tinted Hard arena the white rim/edges carry the contrast.
- Copy: "SHARD VOLLEY" (from `Enemies.VOLLEY_NAME`) · "SLAM" · edge pointer "VOLLEY" / "SLAM".

## 7. Edge cases
- **Lead at fire time:** the lanes show the boss→player line during the windup, not the lead (the lead doesn't exist yet). Shots that lead a running player can land slightly ahead of the lanes; the flash beat + "change direction or stop" is the counterplay. Q2 asks whether Ghost/Echo want an aim lock at 0.15 s so the lanes become exact.
- **Party:** only the tracked player (`VolleyTarget`) sees the full-strength lanes; other players see them at Transparency 0.75 so they still read the boss but don't dodge someone else's volley. Slam rings are full strength for everyone (a ring is a place, not a person).
- **Mark pauses the volley:** lanes freeze dimmed (see §3).
- **Blocked dash:** fizzle (gray) so the cancel is visible.
- **Boss off-screen (portrait camera is narrow):** edge pointer (Q5). The ring is at the player's feet, so it is always on screen.
- **Boss dies mid-windup:** all telegraphs destroyed at once; no late shots (server already stops).
- **Low-end phones:** max live telegraph parts = 3 lanes + 1 ring + 1 beam + 3 bolts = 8 parts, 2 emitters (gem, impact). Emitters capped (`Rate` ≤ 60, `Lifetime` ≤ 0.6).
- **Flag off (`enemyTypes`):** nothing spawns, nothing to show.
- **Accessibility:** shape over color (lines vs. circle, chevrons, rim ticks); the flash is a brightness change, not a hue change only.

## 8. Mockups
SVG in repo (fake data, original art, gray-box arena). `mockups/01-volley-windup-phone-390x844.svg` (0.6 s of 0.9, lanes tracking, boss bar tag + drain) · `mockups/02-slam-dash-phone-390x844.svg` (0.7 s of 1.2, ring filling, dash beam, "step out") · `mockups/03-volley-flash-landscape-667x375.svg` (flash frame 0.75–0.9 s) · `mockups/04-slam-hard-landscape-667x375.svg` (Hard: same colors; blocked-path fizzle) · `mockups/05-offscreen-landscape-800x400.svg` (edge pointer) · `mockups/06-desktop-1280x720.svg` (scale check) · `mockups/07-timeline.svg` (both timelines from Config) · `mockups/08-directions.svg` (A/B/C). The live HUD is dashed. PNG renders are on the box only.

## 9. Build split
Roadmap 3.6. Building waits for Ghost's go and the `enemyTypes` flag.
- **Echo (server):** set/clear the boss attributes in §2 from `actor.volley` / `actor.mark` (server time stamps, `MarkCancel` one tick). Optional per Q2/Q3: aim lock, leash pre-warning attribute. Tests: attributes clear on fire/land/cancel/boss death; no remote, no save.
- **Ghost (client):** `BossTelegraphs` builder (lanes, ring, beam, bolts, emitters) driven by the attributes and `GetServerTimeNow`; boss bar tag + drain on the #428 bar; edge pointer (if Q5 yes).
- **Prism:** Phase S pass (shard-shaped lane texture, ring decal, sound timing with the audio owner) after the fun test.
- **Havoc:** 200 ms ping (flash still lines up), party of 4 (volley targets one player), blocked dash next to cover, boss dies mid-windup, mark during a volley windup.

## 10. Pass criteria (playtest)
1. At 390×844, 4 of 5 new testers dodge or take cover from the 2nd volley they see.
2. 4 of 5 testers step out of the ring on their 1st or 2nd slam and can say "the fill reaching the edge is when it hits".
3. With 200 ms ping, the flash still starts before the shots fire.
4. Testers can tell Hard from Normal by the HUD, but describe the telegraphs as the same.
5. No UI enters the center keep-out at any of the 4 sizes; frame rate stays stable on a low-end phone with 4 players and the boss + 4 adds.

## 11. Open questions (answer by number)
1. **@Ghost:** Data path for the telegraph: boss-model attributes with server-time end stamps (client builds the visuals, recommended) or server-built telegraph Parts in Workspace (simplest in gray-box, but tweens stutter and lag eats the windup)?
2. **@Ghost:** Volley aim. Today the lead is computed at fire, so the lanes can only show boss→player. Keep it (recommended for V1: the flash + 3-lane spread is enough), or ask Echo to lock the aim at 0.15 s before fire so the lanes are exact? (That's a gameplay code change, not Prism's call.)
3. **@Ghost:** Leash pre-warning. Should the boss's gem turn orange at 2 of the 3 leash seconds (needs an attribute from `actor.leash`) so players learn "too far = slam" before the ring drops? Recommended: yes.
4. **@Ghost:** One small camera shake on slam impact (only when you're inside the ring), or no shake at all? Recommended: small shake, inside only.
5. **@Ghost:** Off-screen edge pointer (display-only, outside the keep-out) when the boss is off-screen during a windup? Recommended: yes, portrait mostly needs it.
6. **@Kevin (taste, PROVISIONAL):** Telegraph color. Recommended: threat orange 255,120,40 with white edges on both tiers (keeps red for Hard and HP). Alternative: shard violet-white. The spec ships orange until Kevin says otherwise.

## Decision log
- 2026-10-24 (Prism): v1 published from Ghost's GO (board row https://app.notion.com/p/403c31ca388381758d47e930e50ccb27). Recommends direction A (ground lanes + ring). Timings from #431 Config (`VOLLEY_WINDUP` 0.9 s, `LEASH_WINDUP` 1.2 s). Six open questions (Ghost 1–5; Kevin 6). Not approved.

## Later (not V1)
Shard-shaped lane decals and a cracked-floor ring texture (Phase S), boss voice line per attack, a "Dodged!" micro-toast for the first dodge (Ideas Backlog, NOT APPROVED), colorblind palette toggle in Settings.

## Roblox build notes
Stock Roblox only. No blur, no glow post-effects, no custom shaders. World visuals are Parts/Beams/Trails/ParticleEmitters with default textures; UI motion = TweenService. The mockups are a guide and these notes win.

| Element | Instances |
|---|---|
| Lane (×3) | `Part` (Anchored, CanCollide/CanQuery/CanTouch false, `Material` Neon, Color 255,120,40, Transparency 0.5, Size (width, 0.05, length)), CFrame from boss toward the tracked player each `RenderStepped`, rotated ±0.12 rad; white edges = 2 thin `Part`s (0.15 stud) or a `Beam` pair (Width 0.15, FaceCamera false); chevrons = 3 `Beam`s with a default arrow `Texture` or 2 thin Parts each (gray-box: Parts). Size tween 0 → full over 0.75 s (`TweenService`, Linear) |
| Flash | Color tween to 255,244,230 + Transparency 0.4 + width ×1.2, 0.15 s (Quad Out) |
| Boss gem | existing gold `Part` (Neon) + `Attachment` + `ParticleEmitter` (default texture, Rate 0 → 60, Speed −6 (inward), Lifetime 0.4, Size 0.4 → 0, LightEmission 1, Color orange→white) + `PointLight` (Range 8, Shadows false) |
| Slam ring | rim = `Part` Cylinder (0.2 thick, diameter 8 studs, rotated flat) Neon orange + second Cylinder slightly smaller as the white edge; inner fill = flat Cylinder, Size tween 0 → 7.6 studs over 1.2 s (Linear), Transparency 0.5; 4 tick `Part`s 1 × 0.1 × 0.2 Neon white |
| Dash beam | 2 `Attachment`s (boss root, mark) + `Beam` (Width 0.3, `Texture` default dashed or none, TextureMode Wrap, Color white, Transparency 0.2) + boss `Trail` (Lifetime 0.25, orange → transparent) |
| Bolts (×3) | `Part` Ball 0.6 Neon white + `Trail` (Lifetime 0.15); cover hit: `ParticleEmitter:Emit(8)` |
| Impact | `ParticleEmitter:Emit(24)` (Speed 10–16, Lifetime 0.5, SpreadAngle 180,0 flat ring) + ring flash tween; camera shake (Q4) = `Camera.CFrame` offset spring 0.15 s, amplitude 0.3 studs, only inside the ring |
| Fizzle | Color tween to 150,150,160, Transparency → 1 over 0.15 s, then `Destroy` |
| Boss bar tag | `Frame` (orange fill, `UICorner` h/2) + `TextLabel` 9 px BuilderSansHeavy ink + `UIScale` pop; drain = `Frame` 2 px, Size X tween 1 → 0 over the remaining windup |
| Edge pointer | `ImageLabel` triangle (or `Frame` + `UIStroke` rotated) 24×28 + `TextLabel`; position from `Camera:WorldToViewportPoint`, clamped to the edge band in §4; `Active = false` |
| Sync | `workspace:GetServerTimeNow()` vs `VolleyEnd` / `MarkEnd`; tween length = remaining time |

### Image assets to upload (PNG, transparent)
None needed for V1 (gray-box). Optional later: `lane_chevron_64` (64×64), `ring_crack_256` (256×256 decal), `edge_pointer_28` (24×28).
