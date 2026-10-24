# Ad Thumbnail Set v1 (Roadmap 7.6 soft-launch ad test, 8 creatives), Spec v1

Owner: Prism (design, docs only, no code, no uploads). For: Kevin (taste picks; he alone uploads, publishes and approves any spend), Ghost (Studio capture setup), Echo (FYI: element colors on #432). Base: `cursor/live-build-9721` @ `581c995`. Date: Oct 24, 2026 (PT). Status: **v1, compositions for Kevin's reaction. Nothing here is approved, uploaded, bought or priced.** Not an official Vision & Design Rules decision until Kevin approves it and it's copied there.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca388381919fdfd588508d2143 (item 3, "Ad thumbnail set v1, docs only, no generation spend"; Kevin pre-approved), from Prism's queue pick https://app.notion.com/p/403c31ca388381209975c3872a5f711f.

**No generation spend.** The mockups are hand-built vector wireframes (SVG, original art). No fal/Krea/paid image generation, and **don't use Ads Manager's "AI generate" option** for these creatives (unique-art rule, see §7). Final art = Studio captures + Prism paint-over, as in #423 §9.

Sources (link, don't copy):
- **Roadmap 7.6** (`docs/ROADMAP.md`): "Soft launch: public, small ad test (Kevin approves spend). Approved Oct 21 at the Roblox minimum: 10 ad credits (5/day, 2 days). Kevin still gives the final OK before any spend. Run about a week. **7–8 thumbnails.** Target new players. Don't touch the campaign in the first hours." Risk line: "Looking like a copy → unique names and art".
- **PR #423** store briefs v1 (`docs/design/store-briefs/SPEC_v1.md`): sizes, text-safe box, bottom-15% rule, identity rule (2 of 3: prismatic shard, cracked sky, color draining to gray), AD1–AD8 hooks. **This spec is the detailed version of #423's AD list and replaces its ad table** (page thumbnails P1–P5 and the icon stay in #423).
- **PR #442** store art roughs v1 (thumb 2 "split world" = AD7 here; thumb 1 Crater hero ≈ AD8 crop).
- **PR #424** Style Bible v0 rev 2 (`docs/design/style-bible/STYLE_BIBLE_v0.md`): §6.1 palette roles, §6.2 value ladder, §6.3 rarity, §6.4 shard shape language, §6.11 identity.
- **PR #435** element color study, variant **E3 + V3** (Ember **#E84814**, Void **#C04888**, Frost keep), picked by Ghost under Kevin's handoff (row above, Q4); folded into Wave HUD v1.2 on #428.
- Hard red **230,80,96** (Ghost Q5): **not used in ads** (Hard is a Lv 5 mode; ads target new players).
- Roblox Creator Hub, checked Oct 24, 2026: *Ads Manager → Creatives* (sponsored tiles show on Home and in search at **16:9**; up to **10** thumbnails per campaign, served evenly at first; other ratios get resized; non-unique games "can result in no ad spend and no conversions") and *Thumbnails* (16:9, ideally **1920×1080**, < 3 MB, JPG/PNG; "avoid essential text or elements at the bottom", metadata like the player count can cover it).

## 0. Directions (pick one) and recommendation
| | Set structure | What it tests | Good | Bad |
|---|---|---|---|---|
| **A** | **4 hooks × 2 (text vs. no text / two framings)**, 8 creatives | Which hook (loot, boss, waves, world story) and whether a headline helps | Clean read in Ads Manager reporting: each pair differs by one thing. Matches #423. Fits the 10-slot limit with 2 spare for a re-test | Only 4 hooks |
| B | 8 different hooks, all with text | Widest hook spread | More ideas tried | 10 credits over ~a week won't give enough plays per creative to call a winner; nothing isolates "text helps?" |
| C | 2 hooks × 4 variants | Depth on loot + boss | Strong winner inside a hook | If both hooks miss, nothing learned |

**Recommendation: A**, with one change from #423: the **rarity-ladder pair (old AD5/AD6) is replaced by a waves pair** that shows the three element enemies in the new colors. A row of 5 rarity shards is the look closest to existing RNG/aura games (copy risk, #423 itself flagged it for icon C), and "staged shards cracking at once" isn't a real game moment (honesty rule). Kevin can swap it back (Q2).

## 1. Goal
A new player scrolling Roblox Home on a phone sees one of our 8 tiles at 160×90 px and, in under a second, reads one clear idea ("crack a glowing shard", "fight a giant Hollow boss", "fight elemental waves", "save the color") and knows it isn't a copy of another game. The test tells Kevin which hook and which framing pulls the best play-through rate, so the winner becomes page thumbnail #1.

## 2. Where it lives
- **Ads Manager → Sponsored campaign (7.6) → Creatives:** 8 uploaded 16:9 thumbnails (slots 9–10 left empty for a re-test). Shown on Home and in search, phone first. **Kevin uploads and publishes**; Roblox moderation takes about a day.
- **Experience page (7.5):** after the test, the top 1–2 become page thumbnails (#423 P-list); nothing else changes on the page.
- **Repo:** `docs/design/ad-thumbnails/` (this spec + 3 SVG wireframe sheets). Final PNGs are made from captures and are **not** committed until Kevin picks.
- **Not here:** the icon, the description, page thumbnails P1–P5 (all #423/#442), any Robux, price, offer or in-game store item.

## 3. Flow (production, not player flow)
| Step | Who | What | Gate |
|---|---|---|---|
| 1 | Kevin | Reacts to the 8 compositions on mockup 01/02 (Q1–Q4) | taste |
| 2 | Echo | Ember/Void colors land in `Config/Elements` on #432 (E3/V3), so AD5/AD6 captures show the real in-game colors | before AD5/AD6 captures |
| 3 | Ghost | Studio capture copy of the place (no live-data writes), 1920×1080 viewport, high graphics, #413 Lighting (ClockTime 18.5). HUD off for every ad except AD5 (real HUD optional, see §7). Camera list in §6 | per #423 §9 |
| 4 | Prism | Composes each on the §4 template: crop, value pass, headline. Checks at 320×180 and 160×90 and in gray (mockup 02 method). Contact sheet for Kevin | §10 |
| 5 | Kevin | Picks, uploads all 8, gives the final OK on the 10-credit spend. Doesn't touch the campaign in the first hours (Roadmap) | spend OK |
| 6 | Kevin + Prism | After ~a week: keep the top 2–3 by play-through rate; the best becomes page thumbnail #1 (#423 §3 step 5). Losers are disabled, not deleted | data |
Back/cancel: any step can stop; nothing is public until Kevin uploads.

## 4. Layout (sizes, text-safe zones, composition)
**Size:** every creative is **1920×1080 (16:9)**, PNG (or JPG if > 3 MB as PNG), **< 3 MB**, sRGB, no transparency, no baked rounded corners. One master per creative; no other sizes are needed (Roblox scales the 16:9 tile for phone, tablet, PC and console).

**Zones** (mockup 03, px on 1920×1080):
| Zone | Rect | Rule |
|---|---|---|
| Action-safe 90% | (96,54)–(1824,1026) | all key art inside |
| **Text-safe box** | **(192,108)–(952,488)** top-left | the only place for a headline: ≤ 3 words (#423 allows 4; ads use 3 for phone), 2 lines max, **cap height ≥ 140 px** (≈ 12 px at 160×90), BuilderSans ExtraBold, white **#FFFFFF** with a **20 px ink stroke #20160A** (≈ 10 px at 50%) |
| **Bottom band** | y ≥ 918 (bottom 15%) | no text, no faces, no shard tips; ground/floor only (Roblox metadata and player count can cover it) |
| **Top-right corner** | (1440,54)–(1824,270) | clean: no text, no icon-like shapes, no sky crack ending there (Roblox flags ambiguous top-right graphics) |
| Subject zone | right two-thirds, roughly (1000,300)–(1760,860) | the brightest value in the frame, subject ≥ 40% of frame height (#423) |

**Phone read (mobile-first):** a Home tile on a 390-pt phone is ~160–330 px wide. Every creative must pass at **160×90** (the small tile): one subject, one silhouette, ≥ 3 value steps between subject and background (Style Bible §6.2), and at most 3 big shapes. The 4 in-game frames (390×844, 667×375, 800×400, desktop) don't apply to store art; see the build notes for reuse in game.

**The 8 compositions** (mockup 01 with guides, mockup 02 at phone sizes):
| # | Hook · pair test | Composition (1920×1080) | Headline (text box) | Identity marks (need 2 of 3) | Brightest value |
|---|---|---|---|---|---|
| **AD1** | Loot · vs AD2 (text vs no text) | Legendary crack at the Crackstone: prismatic shard 640 px tall centered at (1220,520), gold burst r 430 behind, 3 small orbit shards; tier chip "LEGENDARY" (real chip, gold) at y 790–854, above the bottom band; cracked sky top | **CRACK A SHARD** (2 lines) | shard + sky | shard core / gold burst |
| **AD2** | Loot · no text | 10% tighter: shard 820 px at (1120,560), the player's face lit gold at the left third (x 640), burst r 560; text box left empty on purpose | — | shard + sky | shard + lit face |
| **AD3** | Boss · vs AD4 (framing) | Hollow Warden (Hollow gray **#5C5C62**, Void rim **#C04888**, red eyes) fills ~70% of height at x 1300; small player with a gold blade at x 820 for scale; Void burst behind the boss | **BEAT THE HOLLOW** | Hollow gray + sky | Void rim + gold blade |
| **AD4** | Boss · no text | Over the boss's shoulder: the Warden's gray mass enters from the right edge (x ≥ 1250), the player at (760,860) lit gold, swinging up at it | — | Hollow gray + sky | player's gold light |
| **AD5** | Waves · vs AD6 (wide vs close) | Player (x 820) slashes a gold arc toward 3 element enemies on the Crater floor: **Ember #E84814** (flame pip) at x 1180, **Frost #5CD6FF** (crystal pip) at x 1470, **Void #C04888** (ring pip) at x 1730; each with its pool light; enemies ≥ 25% of height | **FIGHT THE WAVES** | sky + Hollow-gray bodies | gold arc |
| **AD6** | Waves · no text | Close clash: player 1.9× at x 700, Ember and Void enemies large (x 1180, 1560), gold hit sparks between them | — | sky + Hollow-gray bodies | gold sparks |
| **AD7** | World story · vs AD8 | Split frame (#442 thumb 2): left full prismatic color, right drained Hollow gray along a ragged edge x 1040–1140; the hero shard sits on the edge, half color, half gray; player on the color side (x 820) | **SAVE THE COLOR** | all 3 | prismatic half of the shard |
| **AD8** | World · no text | Wide Crater Square (P1 alt crop): Lumen shard 520 px at center, sparse shard rain (≤ 25 shards), Hollow-gray lips at both bottom corners, Shard Gate ring (gate cyan **#78D2FF**) at x 1640–1800, small player x 700 | — | all 3 | center shard |

## 5. States (variants we prepare)
| Creative | Now (v1) | Final | Reserve |
|---|---|---|---|
| AD1–AD8 | vector wireframes (mockups 01–02) | paint-over of Studio captures, one PNG each | — |
| Pair twins | AD2/4/6/8 are the twins of AD1/3/5/7 | same | if moderation rejects one, run its twin alone and note it |
| Slots 9–10 | empty | empty | after the first readout: the winning hook with the other framing |
| Loading / error / empty | n/a (static images) | — | — |
| Hard / Robux / event variants | **none** (Hard isn't for new players; no Robux or offers ever in ads) | — | — |

## 6. Numbers
**Palette (codes, from Style Bible #424 §6.1/§6.3 and #435 V3):**
| Role | Hex | RGB | Where in ads |
|---|---|---|---|
| sky deep → low | #22103E → #783C8C | 34,16,62 → 120,60,140 | every backdrop (top → horizon) |
| crack pink / cyan / white | #FF96DC / #96EBFF / #FFFFFF | 255,150,220 / 150,235,255 | sky cracks, shard facets |
| bg (chrome) | #100E18 | 16,14,24 | contact sheet only |
| gold (single accent, = Legendary) | #FFC440 | 255,196,64 | blade, burst, tier chip, hit sparks |
| ink (text stroke) | #20160A | 32,22,10 | headline stroke 20 px, shard crack |
| Hollow lip / deep | #6E6E74 / #5C5C62 | 110,110,116 / 92,92,98 | Warden, enemy bodies, drained half; never behind text |
| gate cyan (world only) | #78D2FF | 120,210,255 | Shard Gate ring (AD8) |
| **Ember (new, E3)** | **#E84814** (outline #F29A7E) | 232,72,20 | AD5/AD6 Ember enemy + pool light |
| Frost (unchanged) | #5CD6FF (outline #A5E8FF) | 92,214,255 | AD5 Frost enemy |
| **Void (new, V3)** | **#C04888** (outline #DC9ABE) | 192,72,136 | AD3/AD4 boss rim, AD5/AD6 Void enemy |
| Rarity (5 V1 tiers) | Common #A8A8B0 · Uncommon #40BA62 · Rare #488EFF · Epic #BA60F0 · Legendary #FFC440 | `Rarities.COLOR` | only on real loot (AD1 chip, orbit shards); never decoration |
Not used: Hard red #E65060 (230,80,96), Mythic/Secret, button purple as a fill.

- **Capture cameras (Ghost):** AD1/AD2 over-the-shoulder at the Crackstone, FOV 50, crystal at the right third · AD3 low angle, FOV 60, boss 14 studs tall fills ~70% · AD4 behind the boss's shoulder, FOV 45 · AD5 3/4 top-down at default zoom, wave 2–3 with one of each element · AD6 same scene, zoom 0.6× · AD7 any Crater edge, split grade done in paint-over (no game change) · AD8 wide low angle from spawn, FOV 60, ClockTime 18.5 (#413).
- **Text:** max 3 words, 2 lines, cap ≥ 140 px, line gap 1.05, left-aligned at x 200. Gameplay words only.
- **File:** 1920×1080, < 3 MB, sRGB. Avoid fine noise/grain (JPEG mush at small size).
- **Test (Roadmap):** ~1 week, 10 credits (5/day, 2 days) at the Roblox minimum, audience **New Players**, all 8 on from the start, no edits in the first hours. Readout = play-through rate per creative; with this little spend, treat differences under ~20% as a tie.

## 7. Edge cases
- **Copy risk:** our names and art only (Shardfall, Crater Square, Lumen Heart, Crackstone, Shard Gate, Hollow Warden). No "RNG"/"Simulator" words, no aura-text look, no other game's fonts, UI or layouts, no rarity "ladder" of 5 shards (old AD5/AD6). **No Ads Manager "AI generate"** thumbnails: they're generic by design and fail the unique-art rule.
- **Honesty:** only real V1 content. Element colors in AD5/AD6 must match the game at capture time, so captures wait for E3/V3 on #432 (if Kevin overrides the colors, recapture). The LEGENDARY chip is the real reveal chip; no odds or percent invented on the art. No parties, pets, raids, Mythic/Secret or Hard unless live.
- **No Robux, prices, "free", "%", "best", "#1", "new!"** or giveaway wording anywhere.
- **Text vs. bottom band:** headlines never drop below y 488; if a 3-word headline needs 3 lines, cut a word instead.
- **Element read for colorblind players:** Ember vs Void is the same gray (ΔE 0, #435); the flame and ring **pip shapes** carry it, so keep pips ≥ 24 px tall in the final at 1920 (≈ 2 px at 160×90 is fine, the color read is a bonus there).
- **Moderation rejection:** run the twin; don't edit a live campaign in its first hours.
- **Feature not live at publish:** if the Warden isn't in the build, drop AD3/AD4 and run 6; if the Gate isn't live, crop it out of AD8.
- **Light theme:** tiles have a full-bleed dark sky, so they read on both themes; no transparent edges.

## 8. Mockups
SVG in repo (original vector art, wireframes, not final art; fake scenes). Generator `gen.py` and PNG renders are on Prism's box only (`/workspace/prism/ad-thumbnails/`).
| File | Shows |
|---|---|
| `mockups/01-contact-sheet-guides.svg` | all 8 compositions with the zones drawn (action-safe white, text-safe cyan, top-right red, bottom band red) |
| `mockups/02-phone-readability.svg` | each creative at 320×180 and 160×90, plus a 160×90 gray check |
| `mockups/03-template-zones-1920x1080.svg` | the blank template with every zone labeled |
Finding from mockup 02: at 160×90 the headline (cap 140) still reads; AD5's enemies only read once they're ≥ 25% of frame height (already applied), and AD8 is the weakest at 160×90 (a lot of small shapes), so it's the twin, not a lead.

## 9. Build split
- **Prism:** this spec, the paint-over finals from captures, small-size and gray checks, the contact sheet for Kevin. Docs only; no uploads, no spend.
- **Ghost:** Studio capture copy and the 8 cameras in §6 (no live-data writes; if a capture helper needs code, that's Ghost's call outside this PR).
- **Echo:** Ember **#E84814** / Void **#C04888** in `Config/Elements` on #432 before AD5/AD6 captures (flag can stay off in live).
- **Kevin:** picks (§11), uploads, final OK on the 10-credit spend, reads the results after a week.
- **Havoc:** none.

## 10. Pass criteria (Kevin can check on a phone)
1. Each of the 8 reads at **160×90**: a tester says the one idea ("crack a shard", "big boss", "fight monsters", "save the color") in 1 s.
2. Each passes the gray check: the subject is still the brightest shape.
3. Every image has 2 of 3 identity marks; 3 testers who haven't seen the game can't name a Roblox game it "looks like".
4. No text outside the text-safe box, nothing important in the bottom 15% or the top-right corner, ≤ 3 words.
5. All 8 are 1920×1080, < 3 MB; element and rarity colors match the codes in §6 and the live game.
6. No Robux, prices, offers, Hard, Mythic/Secret or unreleased features.

## 11. Open questions (answer by number)
1. **@Kevin (taste):** set structure A (4 hooks × 2, recommended), B (8 hooks) or C (2 hooks × 4)?
2. **@Kevin (taste):** OK to replace #423's rarity-ladder pair with the elemental waves pair (AD5/AD6, recommended for copy risk and honesty), or keep the ladder?
3. **@Kevin (taste):** headlines as listed ("CRACK A SHARD", "BEAT THE HOLLOW", "FIGHT THE WAVES", "SAVE THE COLOR"), or different words? (≤ 3 words each.)
4. **@Kevin (taste):** lead creative order for your own review: AD1 first (recommended: loot is the core hook), or AD7 (most unique)?
5. **@Ghost:** can the capture copy show a Legendary reveal at the Crackstone, the Warden entrance and a wave with all 3 elements without code? If not, which helper (your call)?

## Decision log
- 2026-10-24 (Prism, Ghost GO row https://app.notion.com/p/403c31ca388381919fdfd588508d2143, Kevin pre-approved for Prism to write it): v1 written for Roadmap 7.6. Recommends set A (4 hooks × 2) with the waves pair replacing #423's rarity ladder; palette from Style Bible #424 + #435 V3 element colors (Ember #E84814, Void #C04888); vector wireframes only, no generation spend. Replaces #423's ad table. Not approved.

## Later (not V1)
Animated/GIF creatives, per-country headline tests, seasonal or update banners, a second test round with slots 9–10. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
- These are **store images**, not in-game UI. Captures still use only what Roblox renders in-engine: Parts/MeshParts, Neon, `Beam`, `ParticleEmitter`, `Highlight`, `PointLight`, `Atmosphere`, `Bloom` (#413 values). **No blur, no `BlurEffect`, no depth-of-field, no faked shaders** in captures or paint-over (honesty: the tile must look like the game). Paint-over is limited to crop, color/value grade, the headline, and cleaning HUD remnants.
- Element looks in AD5/AD6 come from the game: `Highlight.FillColor` = element color, `OutlineColor` = element lerped 45% to white, `PointLight.Color` = element color (#435 build notes).
- **Reuse in game** (e.g. a loading splash or the results backdrop): upload the PNG as an image asset, show it in an `ImageLabel` (`ScaleType` Crop) inside a `Frame` with `UICorner` 12 and `UIStroke` 2 (gold 255,196,64 at transparency 0.5); optional prismatic edge = `UIGradient` with an `Offset` tween (TweenService). On 390×844 portrait the Crop keeps the center 9:16 slice, so the subject zone must be centered for any image picked for reuse (AD1, AD8 qualify; AD7's split doesn't). Any tappable element on a reused image (e.g. "Skip") is a ≥ 44×44 `TextButton` in a corner, outside the center keep-out. Sparkles = a few `ImageLabel`s tweened, or a world `ParticleEmitter` behind the UI.
- Don't bake headlines into an in-game reuse; use a `TextLabel` (BuilderSans ExtraBold) + `UIStroke` 2 ink instead so it scales.
