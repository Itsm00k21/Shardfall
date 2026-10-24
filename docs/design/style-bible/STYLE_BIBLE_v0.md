# Shardfall Style Bible v0 (rev 2, Oct 24, 2026)

**Status: v0, NOT APPROVED (rev 2 adds tonight's decisions, Ghost GO row https://app.notion.com/p/403c31ca388381ecbd1de2f133fd3cb4, 10:50Z, Kevin pre-approved for Prism to write it; the content itself still needs Kevin).** These are Prism's proposals, collected from the open spec PRs and the repo. Nothing here is official until Kevin approves it and it's copied into the Notion Vision & Design Rules page. Where a line repeats something already decided elsewhere, the source is named.

Owner: Prism (design, docs only). For: Kevin (approval), Ghost (UI/world build), Echo (FYI). Base: `cursor/live-build-9721` @ `581c995`. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca38838103a80ad21380d7f451 (item 3, "Style Bible v0").
Rev 2 sources: element color study #435, element glow read v1.1 #438, Hard accent v1.1 #440, Hard selector v1.3 #437, boss telegraphs v1.1 #439, M13 visual QA v1.1 #436, token fly-in v1.1 on #429. Notion mirror: https://app.notion.com/p/403c31ca388381879bddecc103464360 (Shardfall Home → Content & Data, Art & Style).
Sources (link, don't copy): `Shared/Rarities.luau` `Rarities.COLOR`; `Shared/Config/Elements.luau` (Ember / Frost / Void); PR #392 `docs/ui/reference/STYLE.md` (chrome); `docs/design/vision/VISION.md` (Kevin's look target); #397 roll/reveal, #398 salvage/core, #412 first 30 s, #413 Crater Square, #414 Shard Crater, #416 Shard Draft, #420 phone layout review, #423 store briefs.

## 0. Tonight's decisions at a glance (rev 2, Oct 24, 2026)
| Topic | What it says | Status |
|---|---|---|
| Palette | Roles in §6.1 (panel 28,24,40 · button 108,78,196 · gold 255,196,64 single accent · ink 32,22,10 · danger 230,80,96 · gate cyan 120,210,255 world only) | Proposal (v0), Kevin to approve |
| Rarity colors | 5 V1 tiers from `Shared/Rarities.luau` `Rarities.COLOR` (§6.3) | Live in code; V1 = 5 tiers is a Kevin rule |
| Element colors | Current (#432) Ember 255,112,36 · Frost 92,214,255 · Void 196,92,255 → candidates Ember **#E84814** · Frost keep · Void **#C04888** (§6.7) | **Pending Kevin on #435.** Don't build the candidates; they fold into #428 only after Kevin picks (Ghost, answer 7) |
| Glow | Outline-led; budgets 6 touch / 12 desktop, lights 4 / 12, enemy Highlight ceiling 18 (§6.8) | Ghost decided (#438 Q6, Kevin pre-approved); not yet in Vision & Design Rules |
| Hard accent | danger 230,80,96, HUD-only chip + stroke, no red sky (§6.9) | **Pending Kevin** (Hard selector Q4); used PROVISIONALLY in mockups |
| Mobile readability | §4 + §6.10 | Kevin's rules (mobile first, ≥ 44 px, 4 sizes, panels collapse, off center) + Prism proposals |
| Signature identity | Prismatic shards, broken sky, color draining where the Hollow spreads (§1, §6.11) | Kevin's look target (VISION.md); wording here is a proposal |

## 1. Goal
Anyone building a screen, a mesh or an effect can answer "what color, what shape, how bright, how big on a phone" from one page, so Shardfall looks like one game: prismatic shards under a broken sky, with color draining where the Hollow spreads.

## 2. Where it lives
- This file (`docs/design/style-bible/STYLE_BIBLE_v0.md`) plus the reference sheet `mockups/01-style-sheet.svg`.
- Once Kevin approves it, the approved lines get copied into Notion **Vision & Design Rules**, which then wins over this file.
- It applies to every spec in `docs/design/`, the HUD, the world (Crater Square, Shard Crater) and the store art (#423).

## 3. Flow (how to use it)
1. Pick the **palette role** first (§6.1), never a raw color.
2. Check **value** (§6.2): desaturate the screenshot, and the thing to notice must still pop.
3. Shape: use the **shard language** for the element or realm (§6.4).
4. Effects: use the **tier VFX ladder** (§6.5) and the phone budgets.
5. Check at **390×844, 667×375, 800×400 and desktop** (Kevin's rule) with the keep-out and the touch rules (§4).

## 4. Layout rules (screen)
- **Mobile first.** Touch targets ≥ 44 px tall (a visual can be smaller if the hit box is 44). Text ≥ 13 px on phones; badges/caps 11 (#420 R7).
- **Center keep-out:** no UI in x 30–70% / y 28–73%; **portrait top 35%** (#420 D1, provisional until Kevin's phone playtest). Opened menus (Roll page, Bag) and the #416 pick moment are the only exceptions.
- **Panels collapse, not just close,** and dock to edges (Kevin's rule). A collapsed panel is a 44 px pill or a 56 px bar.
- **One toast lane:** max 1 toast on screen, the rest queue, loot/rarity before info (#420 D3).
- **Hub bottom slot:** the ROLL/collapse bar or the Gate dock owns the bottom-center; the combat cluster hides under them in the hub (#420 D2).
- Corners: card/chip 10, buttons 8, stage 12, pill/toast = h/2 (#412 chrome). Strokes 1 (panels), 2 (primary buttons, stage, tier tiles).

## 5. States (visual vocabulary for every control)
| State | Look |
|---|---|
| Idle | panel 28,24,40, stroke 1 gold at transparency 0.5, text 240,236,248 |
| Press | darker fill + `UIScale` 0.96 for 0.06–0.08 s |
| Disabled | buttonDim 54,46,78, muted text 176,168,198, no glow |
| New | `newDot` 230,64,78, 10 px dot top-right |
| Locked | padlock + muted label; a tap gives an "Unlocks at …" toast |
| Selected | 2 px gold stroke 255,196,64 |
| Danger | 230,80,96 (salvage confirm, errors) |

## 6. Numbers

### 6.1 Palette (roles)
| Role | RGB | Use |
|---|---|---|
| bg | 16,14,24 | screen backgrounds, scrims (transparency 0.55) |
| panel / row | 28,24,40 / 40,34,58 | cards, lists |
| text / muted | 240,236,248 / 176,168,198 | body / secondary |
| button | 108,78,196 | primary action fill |
| gold | 255,196,64 | the ONE accent: primary stroke, selected, Legendary |
| ink | 32,22,10 | text stroke on art and thumbnails |
| sky deep → low | 34,16,62 → 120,60,140 | broken prismatic sky gradient |
| crack lines | pink 255,150,220 · cyan 150,235,255 · white | sky cracks, shard facets |
| gate cyan | 120,210,255 | world markers and Beams only (never UI fill) |
| Hollow lip / deep | 110,110,116 / 92,92,98 | color-drained ground, Hollow enemies; never carries text |
| ok / danger | 110,210,140 / 230,80,96 | confirm / destructive |

**Color draining (the Hollow):** saturation steps down by distance, as in #413: full color at the center → muted (about 50% saturation) at r 60–88 → Hollow gray at the lip. It's done per part color, never a global ColorCorrection (that would gray the whole screen and the UI).

### 6.2 Value and contrast
- Value ladder, darkest to brightest: bg 6% → sky 12% → floor 24% → Hollow 36–43% → Common 66% → Rare/Epic glow 78% → text 94% (reference sheet row 4).
- The thing to tap or notice is at least **3 ladder steps** brighter than what's behind it.
- Text on art always has an ink stroke (`UIStroke` 1.5–2 on `TextLabel`s, 10 px on thumbnails).
- Gray check: every mockup is also checked desaturated, and silhouettes must still read.
- No mid-gray UI over the Hollow gray: put UI on a panel (28,24,40) there.

### 6.3 Rarity colors (V1 = 5 tiers)
| Tier | RGB (`Rarities.COLOR`) | Tile stroke | Glow | Reveal time (#397) |
|---|---|---|---|---|
| Common | 168,168,176 | 1 px | none | 0.55 s |
| Uncommon | 64,186,98 | 2 px | soft (ImageLabel glow at transparency 0.8) | 0.70 s |
| Rare | 72,142,255 | 2 px | glint sweep (`UIGradient` offset tween) | 0.90 s |
| Epic | 186,96,240 | 2 px + rotating gradient stroke | glow + 12 sparks | 1.30 s |
| Legendary | 255,196,64 | 3 px rotating gold gradient stroke | burst + pull beam (#413) | 2.20 s |
- Rarity color is **only** for rarity: tile strokes, tier chips, reveal light, beams. Never as a button fill or a decorative color.
- Mythic and Secret exist in code but are not shown in V1 art or UI.
- Color-blind safety: tier always also shows as a **word** (tier chip) and as **stroke weight**, not hue alone.

### 6.4 Shard shape language (per realm / element)
| Family | Silhouette | Surface | Where |
|---|---|---|---|
| **Lumen / prismatic** (the god-crystal) | tall 6-sided bipyramid, symmetric, 1 : 1.8 | inner light, white facet lines, prismatic gradient | Lumen Heart, Crackstone, roll crystal, icon (#423 A) |
| **Ember** | jagged, forward-leaning blades with sharp tips; asymmetric | warm Neon edges 255,150,40, sparks | Ember arch, Ember enemies, Ember buff cards |
| **Frost** | clustered upright prisms with clean 90° faces and flat tops | pale glass 186,228,255, snow motes | Frost arch, Frost enemies, Frost buff cards |
| **Void** | crescent/diamond with a hollow dark core and an inward-curved rim | dark center, violet rim 150,70,220, slow swirl | Void arch, Void enemies, Void buff cards |
| **Hollow** (decay/enemy) | broken, flat-topped stubs; never a clean point | matte gray 110,110,116, no glow, gray fog | crater lip, Hollow Warden, shardling bodies |
- Rule: a silhouette must read at **32 px in gray** (UI icons) and at **default camera zoom on 390×844** (world).
- Sharp points = player power (prismatic, Ember). Flat breaks = the Hollow. That's how a player tells friend from decay at a glance.
- Meshes ≤ 400 tris per floating shard (#413), chunky low-poly (VISION.md).

### 6.5 VFX language
- **Tier ladder** (§6.3): more tier = more light, never more screen coverage. Even Legendary stays inside its stage or tile; the beam is a world effect.
- **Element identity:** Ember = sparks rising (orange), Frost = slow snow motes falling (pale blue), Void = an inward swirl (violet, dark center). One particle style per element, used everywhere (#414, #416).
- **Story beats:** shard rain (world, constant, sparse), a vein sweep on wave start (#414), the boss rift opening (#414), color draining to gray at the Hollow edge (#413).
- **Phone budgets (proposal):** ≤ 60 live particles per effect on phones, ≤ 150 on desktop; bursts ≤ 0.6 s; nothing flashes faster than 3 times per second; camera shake ≤ 0.3 studs and off with reduced motion (#414).
- **Durations:** UI open 0.26 s, collapse 0.15 s, press 0.06–0.08 s, toasts 1.2–2.5 s (#412, #420 D3).

### 6.6 Typography
BuilderSansExtraBold (ROLL, START, big numbers), BuilderSansBold (names, buttons), BuilderSans (body). Phones: body 14, labels 13, badges 11 (min). Desktop scales with `UIScale` clamp 1–1.5.

### 6.7 Element colors (rev 2) · PENDING KEVIN on #435
`Config/Elements.luau` on `cursor/live-build-9721` has no colors yet; the current colors live on PR #432 (flag `elementGlow` off).
| Element | Current (#432) | Candidate (#435 rec) | Candidate outline tint | Why change |
|---|---|---|---|---|
| Ember | **#FF7024** 255,112,36 | **#E84814** 232,72,20 (E3 deep ember) | #F29A7E 242,154,126 | Today it's the same as boss telegraph orange 255,120,40 (ΔE 2 in every vision); E3 separates by value, min ΔE 9 vs telegraph, ≥ 16 vs gold/warn/UPGRADE |
| Frost | **#5CD6FF** 92,214,255 | keep | #A5E8FF 165,232,255 | already clear |
| Void | **#C45CFF** 196,92,255 | **#C04888** 192,72,136 (V3 deep plum) | #DC9ABE 220,154,190 | Today it's the same as Epic 186,96,240 (ΔE 2), and looks like Rare blue for deutan players (ΔE 2) |
- Until Kevin picks, build with the **current** colors and the #438 outline tints (§6.8). The candidates fold into #428 buff pips and #432 glow **only after** Kevin's pick on #435.
- Element is never shown by hue alone: pip **shape** (Ember flame, Frost hex, Void crescent) + color.
- Deutan note for Kevin: current Void reads as Rare blue for deutan players; V3 fixes it (it goes in Kevin's summary with the V3 rec).

### 6.8 Glow rules (rev 2, from #438 v1.1, Ghost Q6 decided)
- **Outline-led:** Highlight fill transparency **0.5** (the enemy keeps its shape and eyes), outline transparency **0**, outline = element color lerped **45% to white** (Ember 255,176,134 · Frost 165,232,255 · Void 222,165,255 on current colors), one ground-pool `PointLight` (range **10**, brightness **1.5**), plus a 12 px element pip on the enemy bar.
- **Budgets:** element glows **6 touch / 12 desktop**; pool lights **4 touch / 12 desktop**; enemy Highlight ceiling (glow + warm Rim) **18** on every device (Roblox draws at most 31; 13 stay free for players, loot, the boss).
- **Count rule:** every alive enemy has **≤ 1 Highlight** (element glow or warm Rim, never both); every dead enemy has **0** (destroy on death, not at wave clear). Over the glow budget = warm Rim + pip; over the ceiling = pip only.
- Boss keeps its own gold-stroked look (no element glow in v1). Telegraph orange 255,120,40 is the same on every tier and must never read as Ember.
- Flag `elementGlow` off = zero element pixels (warm Rim only).

### 6.9 Hard accent (rev 2) · PENDING KEVIN (Hard selector Q4)
- PROVISIONAL rec: accent **230,80,96** (= danger), selected fill 74,28,40, red-family text 255,170,180, text on red = ink 32,22,10 (≈ 4.8:1). Alternative for Kevin: a deep violet closer to the shard palette.
- **HUD-only:** HARD chip + stroke on the dock, wave chip, boss bar and results wing; your pad rim/swirl turns red only when the whole party is Hard. **No red sky, no world tint**, and flag `hardMode` off = zero Hard pixels (#440 v1.1).
- The boss-clear reward is gold on every tier (never red, never ×2) (#429 fly-in v1.1).

### 6.10 Mobile readability (rev 2 summary)
- Check every screen at **390×844, 667×375, 800×400 and desktop**. Touch targets **≥ 44 px** hit box. Body text ≥ 13 px, badges 10–11 px.
- **Panels collapse** (to a 44 px pill or 56 px bar), never just close, and stay **off the screen center** (keep-out in §4; only flying reward icons may cross it, for < 0.8 s).
- One toast lane, one number per payout (no merged totals that hide their parts, #429 fly-in v1.1).
- Readability on the floor comes from **outline and value**, not glow size: a gray capture must still show what to hit and what to tap.
- Color is never the only cue: tier = word + stroke weight; element = pip shape; Hard = the word HARD.

### 6.11 Signature identity (rev 2)
- **Prismatic shards:** sharp, faceted, inner light = the player's power (Lumen bipyramid, roll crystal, icon).
- **Broken sky:** deep violet gradient 34,16,62 → 120,60,140 with pink / cyan / white crack lines; visible in every hub and arena shot.
- **Color draining where the Hollow spreads:** saturation steps down toward Hollow gray 110,110,116 at the crater lip and on Hollow enemies, done per part (never a global ColorCorrection, so UI keeps its color).

## 7. Edge cases
- **Copy risk** (Roadmap 7.6): our own names and our own shard/sky/Hollow look. Don't copy another game's aura text, layouts or fonts.
- **Bright scenes** (Legendary burst on the gold accent): the gold UI stroke drops to transparency 0.7 while a Legendary burst plays, so the burst wins.
- **Hollow areas:** UI over gray ground always sits on a panel, never directly on the world.
- **Low-end phones:** particles fall back to half the budget and the rotating gradient strokes stop rotating (a static gradient).
- **Accessibility:** tier = word + stroke weight + color. Element = icon shape + color.
- **Conflicts:** if a spec PR disagrees with this v0, the spec PR's Decision log wins until Kevin approves this file.

## 8. Mockups
| File | Shows |
|---|---|
| `mockups/01-style-sheet.svg` | rarity, element, chrome and world swatches; the 5 shard silhouettes; the tier light ladder; the value ladder in gray |
| `mockups/02-tonight-colors-glow.svg` (rev 2) | rarity row; element current vs candidate (pending Kevin); glow/light/Highlight budgets; outline tints; Hard accent (pending Kevin); signature identity lines |
Local PNG: `/workspace/prism/style-bible/png/01-style-sheet.png` (Prism's box).

## 9. Build split
- **Prism:** this doc, the reference sheet, and keeping specs consistent with it.
- **Ghost:** applies it in UI/world builds (no code in this PR). Flags anything Roblox can't render.
- **Kevin:** approves the lines that become official (§11).
- **Echo:** none.

## 10. Pass criteria
1. A gray screenshot of any screen still shows what to tap.
2. Every tier is distinguishable by word and stroke weight without color.
3. Ember, Frost and Void shards are tellable apart by silhouette alone at 32 px.
4. No UI color uses a rarity color except to show rarity.
5. All 4 sizes pass the keep-out and 44 px rules.

## 11. Open questions (answer by number)
1. **@Kevin (taste):** approve the **shard shape language** (§6.4: Ember jagged, Frost clustered prisms, Void hollow core, Hollow broken stubs)?
2. **@Kevin (taste):** gold 255,196,64 as the **single UI accent** (it's also the Legendary color)? The alternative is a separate UI accent, which Prism doesn't recommend because it adds a 9th strong color.
3. **@Kevin:** approve the **phone VFX budgets** in §6.5 (≤ 60 particles per effect on phones)? These are a proposal; Ghost may tune them after a device check.
4. **@Ghost:** anything in §6.5 Roblox can't render, or that's too costly on your test phone?
5. **@Kevin (rev 2):** element colors: pick on #435 (rec Ember #E84814, Void #C04888, Frost keep). Note: current Void reads as Rare blue for deutan players.
6. **@Kevin (rev 2):** Hard accent: danger red 230,80,96 (rec, HUD-only) or a deep violet?
7. **@Kevin (rev 2):** approve the glow rules in §6.8 and the readability rules in §6.10 for copying into Vision & Design Rules?

## Decision log
- 2026-10-24 (Prism): v0 written from the repo and open spec PRs. Not approved, so nothing here is official until Kevin approves it and it's copied into Vision & Design Rules.
- 2026-10-24 (Prism, rev 2, Ghost GO row https://app.notion.com/p/403c31ca388381ecbd1de2f133fd3cb4, Kevin pre-approved): added §0 at-a-glance, §6.7 element colors (current + candidates, pending Kevin on #435), §6.8 glow rules + budgets (#438), §6.9 Hard accent (pending Kevin), §6.10 mobile readability, §6.11 signature identity; mockup 02. Notion mirror page created. Still v0, not approved.

## Roblox build notes
- UI: `Frame` / `ImageLabel` / `TextLabel` with `UICorner` (radii in §4), `UIStroke` (1 / 2 / 3 px by role and tier), `UIGradient` (prismatic edge, rotating tier strokes via a `Rotation` tween, a glint via an `Offset` tween), `UIScale` for press and desktop scale. Glow = a soft `ImageLabel` behind the tile at transparency 0.6–0.8. **No blur, no `BlurEffect`, no shaders.**
- World: Parts/MeshParts, Neon for crystal edges, `Beam` (pull beam, gate marker), `ParticleEmitter` (element particles, shard rain), `Atmosphere` + `Bloom` only (values in #413). Color draining = per-part color, not `ColorCorrectionEffect`.
- Motion: TweenService only. Durations from §6.5.
