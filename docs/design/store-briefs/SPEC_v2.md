# Experience Page Kit (icon, 3 thumbnails, short description, genre): Spec v2 (NOT APPROVED, docs only)

Owner: Prism (design, docs only). For: Kevin (picks and uploads in Creator Hub), Ghost (Studio capture copy), Echo (FYI). Base: `cursor/live-build-9721` @ `1445560`. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP35P https://app.notion.com/p/403c31ca3883816faf2bc49bb360274c, task 2 ("Roblox experience page kit: icon spec, 3 thumbnail shot lists (roll reveal, arena wave, boss), short description and genre/tags. No Robux, passes or monetization copy."). ACK: https://app.notion.com/p/403c31ca388381ed80a3d6e3208b6952. Kevin pre-approved Ghost's tasks.
**This is v2 of the same brief** (`SPEC_v1.md` in this folder, PR #423, Roadmap 7.5/7.6). v1 stays the source for sizes, safe areas, palette, the 4 icon directions and the 8 ad thumbnails; v2 turns 7.5 into a ready-to-upload kit. Related: #442 store art roughs, #443 ad thumbnail set. **Prep only:** no Robux, no passes, no prices, no offers, no ad spend. Nothing is official until Kevin approves it and it is copied into Vision & Design Rules.

What changed from v1: final icon spec (direction A refined, still pending Kevin's #423 Q1), 3 capture-ready thumbnail shot lists (T1 roll reveal, T2 arena wave, T3 boss) that replace P2–P4, a 2-line short description + updated long description in V1 names (from the V1 copy pass, `prism/v1-copy-pass`), genre/subgenre pick, two new mockups.

## 1. Goal
Kevin can open Creator Hub and fill the experience page in one sitting: 1 icon, 3 thumbnails that show the real V1 loop (crack a shard → fight waves → beat the boss), a description that says only what ships, and the right genre so Roblox puts us next to action RPGs, not RNG/aura games.

## 2. Where it lives
- **Creator Hub → Experience → Places/Configure:** icon (512×512), thumbnails (16:9, we upload 3 now, up to 5 later from v1 P1/P5), name, description; **Settings → Genre** (1 genre + optional subgenre, per Creator Hub "Genres" doc, checked Oct 24, 2026).
- Same art shows on Home tiles, search, the game page, on phone first.
- Files: this spec + `mockups/icon-A-v2-512.svg`, `mockups/icon-A-v2-readability.svg`, `mockups/thumbs-v2-shot-directions.svg` (each wraps a PNG render; originals in Prism's `/workspace/prism/experience-kit/png/`).

## 3. Flow (production)
1. Kevin answers Q1 (icon) and Q2 (headline on T3). Ghost may close Q3/Q4 under pre-approval.
2. Ghost opens a **capture copy** of the place (no live-data writes), turns on `waveArena` there only, sets Lighting from #413 (ClockTime 18.5), hides HUD for T1/T3, keeps HUD for T2, viewport 1920×1080, graphics level 10.
3. Ghost captures each shot from the §6 lists (3–5 frames each). Prism picks, crops on the v1 template, color-passes, adds T3's headline.
4. Prism checks at 160×90 and 320×180 (thumbs) and 150/100/50 px (icon), dark + light theme, then posts a contact sheet.
5. Kevin uploads. Prism never uploads or publishes.

## 4. Layout
Sizes and safe areas are unchanged from v1 §4: icon 512×512 PNG < 3 MB, key art in the center 410×410, **no text on the icon**; thumbnails 1920×1080, text-safe box (192,108)–(952,488), **no text or key art in the bottom 15% (y ≥ 918)**, top-right 420×240 kept clear.

**Icon v2 (direction A, "The Cracked Shard"), mockup `icon-A-v2-512.svg`:**
| Layer | Spec |
|---|---|
| Sky | vertical gradient 34,16,62 → 120,60,140, 6–9 crack lines (pink 255,150,220 / cyan 150,235,255 / white), stroke ≥ 6 px at 512 so they survive at 100 px |
| Shard | one prismatic crystal, 66% of icon height, centered, 4 facets (pink, cyan, Epic 186,96,240, warm gold 255,214,120), white rim 4 px |
| Crack | dark (20,10,30) zig-zag down the shard, ≥ 6% of shard width: the "not a gem icon" mark |
| Glow | soft white-pink halo behind the shard (in the PNG, not a Roblox effect) |
| Ground | bottom 22%: color drains to Hollow gray 110,110,116 |
| Orbit | 4 small rarity shards (Uncommon, Rare, Epic, Legendary), no Common (it reads as dust at 50 px) |
| Corners | square PNG; Roblox rounds tiles itself |
Readability sheet `icon-A-v2-readability.svg`: 150 / 100 / 50 px + light theme. At 50 px it still reads as "glowing cracked crystal".

## 5. States
| Asset | Ship now | Later |
|---|---|---|
| Icon | A v2 (or Kevin's pick from #423 Q1) | alt rim (gold vs white) for an icon test |
| Thumbnails | T1, T2, T3 in that order | + v1 P1 Crater Square hero, + v1 P5 Shard Draft (only if #416 ships) |
| Description | long + short (§6) | add a line per shipped feature, never before it ships |
| Genre | RPG → Action RPG | revisit after the 7.6 ad test |

## 6. Numbers (shot lists, description, genre)

**T1. Roll reveal** (replaces v1 P2; mockup frame 1)
| | |
|---|---|
| Moment | A Legendary crack at the Crackstone: gold burst, pull beam up into the cracked sky, shard rain |
| Staging | capture copy; Ghost forces one Legendary result for the capture only (dev tool, never in live) and the **odds chip text comes from Config at capture time** ("LEGENDARY · 1 in N", N never invented) |
| Camera | over the shoulder, player back at the left third (x ≈ 30%), crystal at the right third (x ≈ 68%), FOV 50, slight low angle |
| HUD | off, except the odds chip (it's the only text) |
| Text | none (the chip is the text) |
| Identity | prismatic/gold shard + cracked sky (2 of 3) |
| Check | at 160×90 you see "gold crystal bursting"; the chip may blur, that's fine |
| Avoid | crack lines crossing the top-right keep-clear box (dim them in the color pass) |

**T2. Arena wave** (replaces v1 P3; mockup frame 2)
| | |
|---|---|
| Moment | Wave 3 in the Shard Crater: player mid-swing (Ember sparks), 3 shardlings hit, damage numbers up, 1–2 rifts glowing at the arena edge |
| Staging | capture copy, `waveArena` on there only; real enemies and real numbers |
| Camera | default 3/4 top-down game camera, default zoom (honest) |
| HUD | **on**: the real wave chip "Wave 3/5" (top-left) and the attack button stay. They are the text |
| Text | no headline (the chip sits where the headline would go; real HUD beats added words) |
| Identity | prismatic shard sparks + Hollow-gray rim at the arena edge (2 of 3) |
| Check | at 160×90: "a fight, lots of hits"; the attack button reads as a game, not a trailer |

**T3. Boss** (replaces v1 P4; mockup frame 3)
| | |
|---|---|
| Moment | The Hollow Warden enters wave 5: rift slabs open, red-violet beam, wings up (#446 Q4, Prism recommendation), boss core glowing |
| Staging | capture copy; trigger the boss wave with the dev "boss" action (exists: `src/server/WaveArena/init.luau:200`, dev only) |
| Camera | low angle, boss fills ≈ 60% of the frame height, player small at the left third with a glowing blade |
| HUD | off except the boss name plate "Hollow Warden" (from the copy pass Q4) |
| Text | headline **"BEAT THE / HOLLOW"** in the text-safe box, 2 lines, cap height ≥ 96 px, white with 10 px ink stroke 32,22,10 (pending #423 Q3 / Q2 below) |
| Identity | cracked sky + Hollow gray + boss core (3 of 3) |
| Check | wings stay out of the top-right box; name plate stays above y 918 |

**Short description (2 lines, for previews; 98 characters):**
> The sky cracked and the shards fell. Crack them for loot, then fight the Hollow at the Shard Gate.

**Long description (V1 names, only what ships; about 500 characters, limit 1000):**
> The god-crystal shattered and the sky cracked open. Its shards fell into Crater Square, and the Hollow is draining the color from everything they touched.
>
> - Crack shards for weapons and armor in 5 rarities: Common, Uncommon, Rare, Epic and Legendary. Every crack shows how rare it is.
> - Step on the Shard Gate and fight 5 waves in the Shard Crater, ending with the Hollow Warden.
> - Play solo or with up to 3 friends. Everyone gets their own loot.
>
> Built for phones first. Plays on tablet and PC too.

Conditional lines (add only when live at publish): parties line (only if `parties` is on; else drop it), Shard Draft line from v1 (#416), Salvage/Shard Core line from v1 (`gearSalvage`/`shardCore` are off in LaunchGate today, so v2 drops that line).

**Genre:** **RPG → Action RPG** (Prism recommends: real-time combat + gear rarities + levels; puts us next to action RPGs). Alternative: Action → Battlegrounds & Fighting (fits the combat but implies PvP, which we don't have). Not "Simulation" or anything that reads as an RNG game.

**Tags / search words:** Roblox's page takes a genre + subgenre, not free tags. Our search words live in the name and description instead, and are already in the copy above: shards, crack, loot, rarities, Legendary, waves, boss, Hollow, friends. Never use other games' names or "RNG", "Simulator", "aura" (v1 §7 copy risk).

## 7. Edge cases
- **Honesty:** every frame is real V1 content; the forced Legendary in T1 is a capture setup, and the odds text is real. If `waveArena` isn't on in live at publish, T2/T3 wait (upload T1 + v1 P1 instead).
- **No Robux, passes, prices or offers** in any image or line; no "free", "%", "best", "#1", "new!".
- **Parties off at publish:** drop the "up to 3 friends" line.
- **Name changes:** if Kevin picks ROLL over CRACK (copy pass Q1), swap "Crack" → "Roll" in both descriptions (thumbnails have no verb).
- **Moderation:** no blood; Warden has no gore; if a thumbnail is rejected, use v1 P1 as the stand-in.
- **Light theme:** icon checked on light (readability sheet).

## 8. Mockups
| File | Shows |
|---|---|
| `mockups/icon-A-v2-512.svg` | Icon A v2 at 512×512 (PNG render inside an SVG wrapper; original art) |
| `mockups/icon-A-v2-readability.svg` | 150 / 100 / 50 px on dark, 100 / 50 px on light |
| `mockups/thumbs-v2-shot-directions.svg` | T1/T2/T3 compositions with guides (cyan text-safe, red bottom-15% + top-right), 160×90 and 280×158 phone checks |
Direction sketches only. Final art = Studio captures + paint-over.

## 9. Build split
- **Ghost:** capture copy + the 3 captures (§3, §6). Dev-only triggers (forced Legendary, boss action) stay in the capture copy. No code change is needed from this doc; if one is, it's Ghost's call outside this PR.
- **Prism:** final compose of icon + 3 thumbs, phone checks, contact sheet.
- **Kevin:** Q1/Q2, upload, genre setting.
- **Echo:** none.

## 10. Pass criteria
1. Icon reads at 50 px on dark and light themes; no text on it.
2. T1, T2, T3 each read at 160×90 (say what's happening at arm's length).
3. Each frame has 2 of 3 identity marks; nothing in the bottom 15% or top-right box.
4. Odds text in T1 matches Config at capture; T2 shows the real HUD.
5. Descriptions list only shipped features; no Robux/price/offer words.
6. Genre set to RPG → Action RPG (or Kevin's pick).

## 11. Open questions (answer by number)
1. **@Kevin (taste):** icon direction: **A v2** (Prism recommends; same as #423 Q1), or B/C/D from v1?
2. **@Kevin (taste):** headline on T3 only ("BEAT THE / HOLLOW"), T1/T2 text-free (Prism recommends), or no headline anywhere?
3. **@Kevin (taste):** genre **RPG → Action RPG** (Prism recommends) or Action → Battlegrounds & Fighting?
4. **@Ghost:** can the capture copy force one Legendary result and trigger the boss wave without touching live code? (`src/server/WaveArena/init.luau:200` already has a dev "boss" action.)

## Decision log
- 2026-10-24 (Prism): v2 kit added on top of v1 (#423). NOT APPROVED.

## Roblox build notes
- Store assets are image files, not in-game UI. Captures use only what Roblox renders: Parts/MeshParts, Neon, Beams, ParticleEmitters, Atmosphere, Bloom. The icon glow is painted in the PNG (it's a still image), not a fake in-game effect.
- If reused in game (loading splash): `ImageLabel` with the PNG in a `Frame` + `UICorner` 12 + `UIStroke` 2 (gold 255,196,64, transparency 0.5), optional `UIGradient` shimmer tweened on `Offset`; no `BlurEffect`.
- Upload the icon as a square PNG; don't bake rounded corners.
- Mobile-first checks: thumbnails at 160×90 / 320×180 (Home tiles on a 390×844 phone), page at 667×375 and 800×400 landscape (carousel), desktop 1280×720. Touch targets: none added (store page is Roblox's own UI).
