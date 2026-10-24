# Store Art Roughs: Game Icon + 2 Thumbnail Options (Roadmap 7.5 prep), v1

Owner: Prism (design, docs only). For: Kevin (picks; he alone uploads/publishes), Ghost (capture setup later). Base: `cursor/live-build-9721`. Status: **v1 roughs, waiting on Kevin's taste calls** (Ghost GO on the Agent Board, Kevin pre-approved: https://app.notion.com/p/403c31ca38838155a532f79564499765, Oct 24, 2026). **Prep only: nothing is uploaded, published, bought or priced.** Gray-box safe. Colors **PROVISIONAL** for Kevin. Not an official Vision & Design Rules decision until Kevin approves it.
Asked for in: Ghost's board row: "icon + 2 thumbnail roughs" from the #423 store briefs (launch item 7.5 prep).

Sources (link, don't copy): **PR #423** store briefs v1 (`prism/store-briefs`: `docs/design/store-briefs/SPEC_v1.md`: icon 512×512 with the center 410×410 safe, no text on the icon; thumbnails 1920×1080, text-safe box (192,108)–(952,488), ≤ 4 words, bottom 15% clear, top-right clean; identity rule "2 of 3: prismatic shard, cracked sky, color draining to gray where the Hollow spreads"; icon directions A–D, Prism recommends **A, The Cracked Shard**; shot list P1–P5, AD1–AD8). Rarity colors `Shared/Rarities.luau` (5 V1 tiers). World look #413 Crater Square, #414 Shard Crater.

## 0. Directions (pick one) and recommendation
| | Option | Image | Good | Bad |
|---|---|---|---|---|
| Icon | **A rough** (the #423 recommendation) | One big prismatic shard with a dark crack, over a violet broken sky, Hollow-gray ground, 4 small rarity shards orbiting (Rare, Legendary, Epic, Uncommon) | Reads as "a glowing cracked crystal" at 50 px (sheet); owns violet + prismatic; no character art needed | A lone crystal is common; the crack + cracked sky must stay bold to keep it ours |
| **Thumb 1** | **P1 Crater Square hero**, "CRACK A SHARD" | Lumen Heart shard in the crater, shard rain, the sky cracking open, the Hollow lip graying the left edge, the Shard Gate at the right, the player raising a gold shard blade | All 3 identity marks; shows the hub + the roll fantasy; strongest page thumbnail #1 | Busy at 160×90 if the rain is too dense (thin it in paint-over) |
| Thumb 2 | **AD7 split world**, "SAVE THE COLOR" | The frame splits down a ragged edge: left full prismatic color, right drained Hollow gray; the hero shard is half color, half gray; the player stands on the color side | The most unique story image (nobody else's "color vs. gray"); very readable at 160×90 | Says less about gameplay (loot, waves); best as an ad test hook |

**Recommendation: icon A + thumbnail 1 as page thumbnail #1, thumbnail 2 as an ad-test creative (AD7).** Final art is a paint-over of Studio captures (per #423 §9), so these roughs pin composition, value and identity, not rendering.

## 1. Goal
Give Kevin something concrete to react to: one icon and two thumbnail compositions that read in under a second at phone size, pass the #423 identity rule, and can't be mistaken for another Roblox game.

## 2. Where it lives
Files only: `docs/design/store-art-roughs/` (this spec + 4 SVG mockups). In the future: Creator Hub experience page (icon, thumbnails) and Ads Manager creatives, **uploaded by Kevin only**. Nothing in the game changes.

## 3. Flow (production)
1. Kevin reacts to the roughs (Q1–Q3).
2. Ghost stages the #423 captures (P1 camera: wide, low angle, FOV 60, ClockTime 18.5; AD7 needs a split-grade pass, no game change).
3. Prism paints over the captures on these compositions, checks them at 320×180 / 160×90 and the icon at 150/100/50 px on dark + light.
4. Kevin picks and uploads. Prism never uploads or publishes.

## 4. Layout
| Asset | Size | Composition |
|---|---|---|
| Icon A | 512×512 | Shard centered, 300 px tall, inside the 410×410 safe (cyan dashed in the mockup); ground band y ≥ 420; orbit shards at r ≈ 170×120. No text. Don't bake rounded corners. |
| Thumb 1 | 1920×1080 | Headline in the text-safe box (192,108)–(952,488), 2 lines at 150 px cap. Hero shard at x ≈ 1180 (right-of-center third), player at the left third, gate at the right edge. Bottom 15% (y ≥ 918) has no text or key art; top-right kept clear. |
| Thumb 2 | 1920×1080 | Split edge at x ≈ 1060–1160, headline top-left, shard on the border, player feet at y 900 (above the bottom band). |
Mobile-first checks (readability sheet): icon at 150 / 100 / 50 px + light theme 100 px; thumbs at 320×180 and 160×90.

## 5. States (variants)
| Asset | Now | Next (after Kevin's pick) |
|---|---|---|
| Icon | A rough | A final + 1 alt rim (Legendary gold vs. prismatic white) |
| Thumbnails | option 1 (text), option 2 (text) | each with a no-text twin for the #423 ad pair test |

## 6. Numbers
- Palette (from #423 §6): sky 34,16,62 → 120,60,140; cracks pink 255,150,220 / ice 150,235,255 / white; Hollow gray 110,110,116 → 92,92,98; ink 32,22,10; rarity shards from `Rarities.COLOR` (V1 5 tiers only; no Mythic/Secret).
- Headline: Arial Black in roughs (BuilderSans ExtraBold in finals), white with a ~10% ink stroke, ≤ 4 words, gameplay words only.
- File limits for finals: PNG/JPG < 3 MB.

## 7. Edge cases
- **Copy risk:** own names and art only; no "RNG"/"Simulator" title words; no aura-text look. Both thumbs pass 3 of 3 identity marks.
- **Honesty:** final thumbnails must be built from real captures; the roughs show the shard rain, sky cracks and the gate as they exist in #413/#414 gray-box. No Robux, prices, "free", "%", "#1".
- **Feature not live at publish:** if the Shard Gate/arena isn't live, drop the gate from thumb 1.
- **Moderation:** no blood, no logos, no giveaway text.
- **Rough vs. generated art:** the roughs are vector compositions, not paintings (see Q4).

## 8. Mockups
SVG in repo (original art; roughs, not final). `mockups/icon-A-rough-512.svg` · `mockups/thumb-1-crater-hero-1920x1080.svg` · `mockups/thumb-2-split-world-1920x1080.svg` · `mockups/readability-sheet.svg` (icon 150/100/50 + light theme; thumbs at 320×180 and 160×90). Thumbnails include the #423 guides (action-safe, text-safe, bottom 15%); finals drop them. PNG renders are on the box only.

## 9. Build split
- **Prism:** paint-over finals from captures, small-size checks, contact sheet for Kevin. Docs only, no uploads.
- **Ghost:** Studio capture copy per #423 §9 (no live-data writes).
- **Kevin:** picks (§11), uploads and publishes.
- **Echo:** none.

## 10. Pass criteria
1. Icon reads as "a glowing cracked crystal" at 50 px on dark and light.
2. Each thumbnail reads at 160×90 (you can say what's happening).
3. 2 of 3 identity marks per image (both roughs have 3 of 3).
4. Nothing in the bottom 15% or top-right; ≤ 4 gameplay words.
5. 3 testers can't name another Roblox game it "looks like".

## 11. Open questions (answer by number)
1. **@Kevin (taste, PROVISIONAL):** Icon direction A (this rough) still your pick, or B/C/D from #423?
2. **@Kevin (taste):** Page thumbnail #1: option 1 (Crater hero, recommended) or option 2 (split world)?
3. **@Kevin (taste):** Headline on thumbnails ("CRACK A SHARD" / "SAVE THE COLOR"), or no text?
4. **@Ghost (FYI):** These are vector roughs. Built-in image generation wasn't available in this session, so painterly concept frames weren't made; finals come from Studio captures + paint-over anyway. Want generated concept frames too once a generator is available?

## Decision log
- 2026-10-24 (Prism): v1 roughs from Ghost's GO (board row https://app.notion.com/p/403c31ca38838155a532f79564499765, Kevin pre-approved). Icon A + 2 thumbnail options (P1 Crater hero, AD7 split world). Nothing published. Not approved.

## Roblox build notes
- Store assets are image files, not in-game UI. Captures use only what Roblox renders: Parts/MeshParts, Neon, Beams, ParticleEmitters, Atmosphere, Bloom. No faked blur or shaders the game can't show.
- If reused in game (loading splash): `ImageLabel` (uploaded PNG) in a `Frame` with `UICorner` 12 + `UIStroke` 2 (gold 255,196,64 @ 0.5), optional `UIGradient` prismatic edge with a `TweenService` tween of `UIGradient.Offset` for shimmer; sparkles = small tweened `ImageLabel`s or a world `ParticleEmitter` behind the UI. No `BlurEffect`.
- Upload the 512×512 icon as-is (Roblox rounds tiles itself).
