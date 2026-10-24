# Experience Page Kit, Spec v2.1: final compose for icon A v2 + thumbnails T1–T3 (NOT APPROVED, docs only)

Owner: Prism (design, docs only). For: Kevin (uploads in Creator Hub), Ghost (local Studio capture place). Base: `cursor/live-build-9721` @ `728421a`. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP38P https://app.notion.com/p/403c31ca3883817ebb29c8c5aae16760, task 2 ("final compose of icon + T1–T3 on #423"). ACK: https://app.notion.com/p/403c31ca388381ce8fe9f8c71adb38fc. Kevin pre-approved Ghost's tasks.
**Delta on [`SPEC_v2.md`](SPEC_v2.md)** (and v1 for sizes/palette). Prep only: no Robux, passes, prices, offers or ad spend. Nothing is official until Kevin approves it and it is copied into Vision & Design Rules.

## Decided (Ghost, DP38P, under Kevin's pre-approval)
- Icon: **A v2** ("The Cracked Shard"). v2 Q1 closed.
- Headline: **T3 only**. T1 and T2 carry no added words. v2 Q2 closed.
- Genre: **RPG → Action RPG**. v2 Q3 closed.
- Capture may force a Legendary and the boss wave **only in a local Studio capture place, never with a live flag**. v2 Q4 closed. Plan in §3.
- Names in art: Shard Gate, Shard Crater, Crater Square, Hollow Warden; verb CRACK in the descriptions (copy pass Q1).

## 1. Goal
One page that tells whoever composes the final files exactly where every pixel goes, so the uploaded icon and 3 thumbnails match this sheet and pass the phone checks on the first try.

## 2. Where it lives
- Creator Hub → Experience → Configure: icon, thumbnails (order T1, T2, T3), description; Settings → Genre = RPG, Subgenre = Action RPG.
- Files (this PR): this spec, `mockups/final-compose-sheet.svg`, `mockups/icon-A-v2-final-512.svg`, `mockups/T1-roll-reveal-1920x1080.svg`, `mockups/T2-arena-wave-1920x1080.svg`, `mockups/T3-boss-1920x1080.svg`. Each SVG wraps one raster (PNG for the icon, JPEG q88 for thumbs) because the commit tool is text-only; open in a browser to view. Originals on Prism's box: `/workspace/prism/experience-kit/final/png/`.
- These are **direction-level previews** (Prism's sketch renderer, original art). The uploaded files are the Studio captures from §3 composed on these exact layers.

## 3. Flow: capture plan (local Studio capture place only)
1. **Make the capture place:** in Studio open the live place, `File → Save to File As… ShardfallCapture.rbxl` on Ghost's machine. **Never publish it, never sync Rojo into it, never commit anything from it.** Game Settings → Security → **Studio Access to API Services OFF** (no DataStore reads/writes, so no save data is touched).
2. **Arena on, in that file only:** in the capture place's copy of `ReplicatedStorage/Shared/LaunchGate` set `waveArena = true` (and `m12Results = true` if the results card is wanted in a B-roll frame). This is an edit to a local, unpublished file, not a live flag and not a repo change. The repo's `LaunchGate.luau:40` stays `false`.
3. **Force a Legendary for T1 (no code change):** Play (server + 1 client). In the server Command Bar set that test player's pity counter to one short of the guarantee, e.g. `local DS = require(game.ServerScriptService.ShardfallServer.DataService); local d = DS.get(game.Players:GetPlayers()[1]); d.sinceLegendary = require(game.ReplicatedStorage.Shared.RarityConfig).LEGENDARY_PITY - 1`. The next CRACK x1 lands Legendary through the existing pity rule (`RarityConfig.LEGENDARY_PITY`, RarityConfig.luau:60; counter in RollService.luau:270). Ghost may use any other Studio-only way he prefers, as long as it lives in the capture place.
4. **Odds chip text for T1:** read it from Config at capture time ("LEGENDARY · 1 in N"); never type a number by hand.
5. **Boss for T3:** enter the Shard Gate, then trigger the existing dev **boss** action (WaveArenaHost.luau:666 → `WaveArena.dev("boss")`, server/WaveArena/init.luau:200). Studio only.
6. **Camera & settings:** viewport **1920×1080** (Device Emulator custom), Graphics 10, Lighting per #413 (ClockTime 18.5). HUD off for T1/T3 except the listed text (`StarterGui` ScreenGuis Enabled = false in the capture place), HUD on for T2. 3–5 frames per shot.
7. **Compose** on §4 layers, check §10, post the contact sheet to #423. Kevin uploads. Prism never uploads.
8. **Throw away** `ShardfallCapture.rbxl` after upload (or keep it local for re-shoots); it never leaves Ghost's machine.

## 4. Layout: exact compose
**Icon A v2: 512×512 PNG, sRGB, < 3 MB, square corners (Roblox rounds tiles), no text.**

| # | Layer (bottom → top) | Exact spec |
|---|---|---|
| 1 | Sky | vertical gradient `34,16,62` (y 0) → `120,60,140` (y 512) |
| 2 | Crack lines | 9 polylines, colors cycle pink `255,150,220` / cyan `150,235,255` / white `255,255,255`, stroke **6 px**, only in the top 70% |
| 3 | Ground | y 399–512: `70,50,90` → Hollow gray `110,110,116` |
| 4 | Halo | ellipse (113,61)–(399,440), `255,230,250`, soft edge baked in the PNG |
| 5 | Shard | center (256,251), height 338 (66%), width 184; 4 facets: top-left `255,180,230`, top-right `150,235,255`, bottom-left Epic `186,96,240`, bottom-right `255,214,120`; white rim 4 px |
| 6 | Crack mark | `20,10,30` zig-zag top → bottom through the shard, width ≥ 11 px (6% of shard width) |
| 7 | Orbit shards | 4 small shards (61×31) on an arc below-left to below-right: Uncommon `64,186,98`, Rare `72,142,255`, Epic `186,96,240`, Legendary `255,196,64`; no Common |
| Safe | Key art | everything that must read sits inside the center **410×410** box (51,51)–(461,461); orbit tips may touch it |

**Thumbnails: 1920×1080 JPG or PNG, 16:9.** Shared guides (all three): text-safe box **(192,108)–(952,488)**; **no text or key art at y ≥ 918** (bottom 15%, Roblox overlays); **top-right 420×240 (1500,0)–(1920,240)** kept clear (carousel badges).

| # | Layer (bottom → top) | T1 Roll reveal | T2 Arena wave | T3 Boss |
|---|---|---|---|---|
| 1 | Capture | Legendary crack at the Crackstone; player back at x ≈ 576 (30%), crystal at x ≈ 1306 (68%), FOV 50, low angle | Wave 3 in the Shard Crater, default 3/4 camera and zoom, player at ≈ (1056,648) mid-swing | Hollow Warden entering wave 5; boss centered x ≈ 1229 (64%), ≈ 60% of frame height; player small at x ≈ 576 |
| 2 | Color pass | sky to `34,16,62`→`120,60,140`; gold bloom kept | floor stays as captured; rim drains to `110,110,116` in the bottom 15% | sky as T1; floor to Hollow gray `110,110,116` from y ≈ 842 |
| 3 | Vignette | 25% to `12,8,20` | 15% | 30% |
| 4 | Accents | crack lines (≥ 6 px) in the top 60%, dimmed out of the top-right box | rift glows `186,96,240` at the edge | crack lines top 50%; red-violet beam `200,60,120` behind the boss |
| 5 | Kept HUD / plate | **odds chip only**: dark `28,24,40` pill, 2 px Legendary stroke `255,196,64`, text "LEGENDARY · 1 in N" (N from Config), centered under the crystal at y ≈ 670 | **real HUD**: wave chip "Wave 3/5" top-left (inside the safe box), attack button bottom-right (it's real UI; it may sit in the bottom band because it's not added text) | **boss name plate** "Hollow Warden" (white on `28,24,40`) above the boss, y ≈ 216 |
| 6 | Headline | none | none | **"BEAT THE" / "HOLLOW"**, 2 lines, left-aligned at x = 216, first line top y = 128, line pitch 150 px; BuilderSans ExtraBold (Roblox's brand font; the preview uses a stand-in), size so cap height ≈ 100 px (≥ 96), fill `255,255,255`, outside stroke **10 px** `32,22,10`; must stay inside (192,108)–(952,488) |

Rarity colors (Shared/Rarities.luau:38–43): Common `168,168,176`, Uncommon `64,186,98`, Rare `72,142,255`, Epic `186,96,240`, Legendary `255,196,64`. V1 has these 5 tiers only.

## 5. States
| Asset | Ship | Fallback |
|---|---|---|
| Icon | A v2 final | none needed |
| T1 | always (roll is live) | — |
| T2 / T3 | only when `waveArena` is **on in live** at publish (honesty rule, v2 §7) | if off: upload T1 + v1 P1 Crater Square hero; T2/T3 wait |
| Description | v2 §6 text, CRACK verb | drop the party line if `parties` is off |

## 6. Copy
Only one added text in the whole kit: T3 headline "BEAT THE / HOLLOW". In-image UI text is real game text: "LEGENDARY · 1 in N" (T1), "Wave 3/5" (T2, matches copy pass D1), "Hollow Warden" (T3, copy pass D2). Descriptions unchanged from v2 §6. No "free", "%", "best", "#1", "new!", no prices.

## 7. Visual style
Palette as §4. Identity marks: every frame shows ≥ 2 of prismatic shard / cracked sky / Hollow gray (T1: 2, T2: 2, T3: 3). Glow and vignette are painted into the still image (store art), not in-game effects.

## 8. Mockups (preview images)
| File | Shows |
|---|---|
| `mockups/final-compose-sheet.svg` | all 4 assets with guides, icon safe box, icon at 150/100/50 px dark + light theme, thumbs at 160×90 and 320×180 |
| `mockups/icon-A-v2-final-512.svg` | icon at 512×512 |
| `mockups/T1-roll-reveal-1920x1080.svg` | T1 at full size, no guides |
| `mockups/T2-arena-wave-1920x1080.svg` | T2 at full size |
| `mockups/T3-boss-1920x1080.svg` | T3 at full size with the headline |

## 9. Build split
- **Ghost:** capture place + captures (§3). No repo change.
- **Prism:** compose on §4, run §10, post the contact sheet.
- **Kevin:** upload icon + T1–T3, set genre RPG → Action RPG.

## 10. Mobile checks / pass criteria
1. Icon reads as "glowing cracked crystal" at 50 px on dark and light (sheet shows it does in the preview).
2. Each thumb reads at **160×90** (Home tile on a 390×844 phone) and **320×180**; carousel at 667×375 and 800×400 landscape; desktop page at 1280×720.
3. Nothing added in y ≥ 918 or the top-right 420×240; the T3 headline is fully inside the cyan box.
4. T1 odds text matches Config at capture; T2 HUD is the real HUD.
5. Capture place was never published; repo LaunchGate unchanged.

## 11. Open questions
1. **@Kevin (taste):** T3 headline wording: **"BEAT THE / HOLLOW"** (v2, Prism recommends: short, reads at 320×180) or **"BEAT THE / HOLLOW WARDEN"** (full name, smaller type ~80 px cap)? Placement is decided either way.
2. **@Ghost:** OK to set `sinceLegendary` from the server Command Bar in the capture place (§3.3), or do you prefer your own Studio-only trigger?

## Decision log
- 2026-10-24 (Prism, v2): kit on #423. NOT APPROVED.
- 2026-10-24 (Ghost, DP38P): icon A v2, headline T3 only, Action RPG, capture forcing only in a local Studio place.
- 2026-10-24 (Prism, v2.1): final compose layers, coordinates, colors, capture plan, 5 preview images. NOT APPROVED until Kevin approves and it is copied into Vision & Design Rules.

## Roblox build notes
- Store assets are image files, not in-game UI. Captures use only what Roblox renders (Parts/MeshParts, Neon, Beams, ParticleEmitters, Atmosphere, Bloom); the halo and vignette are paint-over on the still.
- If reused in game (loading splash): `ImageLabel` in a `Frame` + `UICorner` 12 + `UIStroke` 2 (`255,196,64`, transparency 0.5), optional `UIGradient` shimmer tweened on `Offset`; no `BlurEffect`. Any in-game button stays ≥ 44 px and off screen center.
