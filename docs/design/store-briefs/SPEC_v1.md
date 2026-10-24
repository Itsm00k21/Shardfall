# Store Page + Ad Thumbnail Briefs: Spec v1 (Roadmap 7.5 / 7.6)

Owner: Prism (design, docs only). For: Kevin (picks and uploads), Ghost (capture setup), Echo (FYI). Base: `cursor/live-build-9721` @ `581c995`. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca38838103a80ad21380d7f451 ("store briefs 7.5/7.6, prep only, no Robux or pricing").
**Prep only.** Nothing here buys ads, changes a price, sells anything or touches Robux. Roadmap 7.6 spend is approved at the Roblox minimum (10 ad credits, 5/day, 2 days), and Kevin still gives the final OK before any spend. This doc doesn't change either.

Sources (link, don't copy): Roadmap 7.5 ("Game page: icon, thumbnails, description"), 7.6 ("Soft launch … small ad test … 7–8 thumbnails. Target new players") and the risk "Looking like a copy → unique names and art (Roblox gives copies less ad reach)". Rarity colors: `Shared/Rarities.luau` `Rarities.COLOR`. Element colors: the live arch colors (as in #414/#416). World look: #413 Crater Square v1.1 and #414 Shard Crater v1.1. Chrome: PR #392 `docs/ui/reference/STYLE.md`. Roblox rules: Creator Hub "Thumbnails" and "Ads Manager" docs (checked Oct 24, 2026).

## 1. Goal
A new player scrolling Roblox Home on a phone sees one image, reads "shard game, cracked sky, rare loot", and knows it isn't a copy of another game, all in under a second and at thumbnail size. The page then backs that up with 5 honest gameplay thumbnails and a short description, and the ad test gets 8 thumbnails to compare.

## 2. Where it lives
- **Experience page (7.5):** Creator Hub → the experience → **Places/Experience Detail Page**: icon (512×512), thumbnails (16:9, up to 10, we use 5), title, description. The same icon and thumbnails show on Home tiles, search results and the game page, on phone, tablet, PC and console.
- **Ad test (7.6):** Ads Manager → Sponsored campaign → **Creatives**: up to 10 custom 16:9 thumbnails per campaign, served evenly at first. We prep **8**. Kevin uploads and publishes, and Roblox moderation takes about 24 h.
- Files in this folder: this spec, the icon direction mockups and the thumbnail template (§8). Final art is made in Studio captures plus paint-over (§9). It isn't committed here until Kevin picks a direction.

## 3. Flow (production, not player flow)
1. **Kevin picks the icon direction** (§11 Q1). Prism recommends **A, The Cracked Shard**.
2. **Ghost stages captures** in a Studio copy of the place (no live-data writes): a Crater Square hero shot, a roll reveal, wave combat in the Shard Crater, the Hollow Warden entrance and the Shard Draft pick. Camera list in §6.
3. **Prism composes** each thumbnail on the §4 template: crop, color pass, text (if any) in the text-safe box. Then Prism checks it at **320×180** and **160×90** (phone Home tile sizes) and at 50 px for the icon (the readability sheet in §8).
4. **Kevin reviews** a contact sheet of all 5 page and 8 ad thumbnails at phone size, picks, and uploads. Prism never uploads or publishes anything.
5. **Ad test (7.6), after Kevin's OK:** run about a week with all 8 thumbnails on. Don't touch the campaign in the first hours (Roadmap). Afterwards, keep the top 2–3 by play-through rate, and the best one becomes thumbnail #1 on the page.
- Cancel/back: any step can stop. Nothing is public until Kevin uploads.

## 4. Layout (sizes and safe areas)

| Asset | Size | Format | Safe areas |
|---|---|---|---|
| **Icon** | 512×512 | PNG, < 3 MB | Key art inside the **center 410×410** (80%), since tiles round the corners and some surfaces crop. **No text on the icon**: a word is unreadable at 50 px, and the title already sits next to the icon everywhere. 8 px rarity-gold or cyan edge is optional (direction-specific). |
| **Page thumbnails (7.5)** | 1920×1080 (16:9) | PNG or JPG, < 3 MB | Action-safe 90%: (96,54)–(1824,1026). **Text-safe box (192,108)–(952,488)** (top-left), at most 4 words, cap height ≥ 96 px. **Bottom 15% (y ≥ 918): no text or key art**, because Roblox metadata such as the player count can cover it. Keep the **top-right corner clean** (Roblox flags "ambiguous graphics in the top-right" as bad practice). |
| **Ad thumbnails (7.6)** | 1920×1080 (16:9) | same | Same template. Ads show on Home and in search at small sizes, so the subject is at least 40% of the frame height. |

Template mockup: `mockups/thumb-template-1920x1080.svg`.

**Mobile-first readability rules (all assets)**
- Test every asset at **phone size first**: the icon at 150, 100 and 50 px, and thumbnails at 320×180 and 160×90. If it doesn't read at 160×90, it doesn't ship.
- One subject, one light source, one idea per image. The subject's silhouette must read in gray (desaturate and check).
- Value contrast: the subject is at least **3 value steps** apart from the background (dark violet sky vs. a bright prismatic shard). No mid-gray subject on a mid-gray background, except on purpose for the Hollow, where the gray *is* the story and a color accent sits next to it.
- Text: BuilderSans ExtraBold (or Arial Black in mockups), white or Legendary gold with a 10 px dark ink stroke (32,22,10). Max 4 words. It describes gameplay only (Roblox rule: no "free", "%", "best", "#1" or other promo claims).
- Light theme check: the icon must also read on Roblox's light background (readability sheet).

## 5. States (variants we prepare)
| Asset | Variants | Why |
|---|---|---|
| Icon | 4 directions (A–D) now → 1 final + 1 alt of the pick (for example A with a Legendary gold rim vs. a prismatic white rim) | Kevin picks; the alt is kept for a later icon test |
| Page thumbnails | 5 (P1–P5) in a fixed order, P1 = the strongest hook | Page carousel; P1 also shows on Home without an ad |
| Ad thumbnails | 8 (AD1–AD8) as 4 hooks × 2 (text vs. no text, or two framings) | Tells us which hook and whether text helps |
| Description | 1 draft (§6) + a 2-line short version | Title area and the short preview |
| Seasonal / update | none in V1 | No "UPDATE" banners until there's an update to show |

## 6. Numbers (palette, shot lists, description)

**Palette (from the repo)**
- Rarity, `Rarities.COLOR` (V1 = 5 tiers): Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64. Mythic and Secret are **not shown** in V1 art.
- Elements (live arch colors): Ember 255,150,40 · Frost 186,228,255 · Void 150,70,220.
- World: broken prismatic sky = deep violet 34,16,62 → 120,60,140 with pink 255,150,220 / cyan 150,235,255 / white crack lines; Hollow gray 110,110,116 (lip) → 92,92,98 (deep); gate cyan 120,210,255; chrome bg 16,14,24; ink 32,22,10.
- Identity rule: **every image has at least 2 of these 3:** a prismatic shard, a cracked sky, color draining to gray where the Hollow spreads. That's our "not a copy" signature.

**Icon directions (mockups in `mockups/`)**
| Dir | Name | Image | Pros | Cons |
|---|---|---|---|---|
| **A (recommended)** | The Cracked Shard | One big prismatic shard with a dark crack down the middle, over a cracked violet sky; Hollow-gray ground at the bottom; 4 small rarity shards orbiting | Reads at 50 px as "a glowing crystal". It's the game's name in one image, it owns a color combo (violet + prismatic), and it needs no character art | A lone crystal is common in Roblox gem icons; the crack and the cracked sky are what make it ours, so they must stay bold |
| B | Hero on the Crater lip | A blocky avatar silhouette raising a crystal blade under a falling shard, with the gray lip behind | Shows "you play a character and fight" | At 50 px the avatar becomes a dark blob; generic "hero + sword" look; needs final character art |
| C | Rarity fan | 5 shards fanned in tier colors (Common → Legendary) from a cracked core | Says "collect rarities" instantly, and the 5 colors are bright at small size | Closest to existing RNG/aura games (copy risk); hides the world story |
| D | Split world | A prismatic shard cut by a diagonal: the left half full color, the right half drained gray by the Hollow | The most unique story image (color vs. Hollow) | The gray half lowers contrast at 50 px, and the split needs a second look to understand |

**Page thumbnails, 7.5 (shot list; captures by Ghost, compose by Prism)**
| # | Shot | Camera / framing | Text (text-safe box) | Must show |
|---|---|---|---|---|
| P1 | **Crater Square hero**: Lumen Heart in the crater, shard rain, cracked sky, the Shard Gate glowing at the right, the gray Hollow lip at the edge | wide, low angle from the spawn, FOV 60, ClockTime 18.5 (decided in #413) | "CRACK A SHARD" | the 3 identity marks |
| P2 | **Roll reveal**: a Legendary crack at the Crackstone, gold burst + the pull beam, tier chip "LEGENDARY · 1 in N" (N from Config at capture time, never invented) | over-the-shoulder, the crystal at the right third | none (the chip is the text) | real odds text, the gold rarity color |
| P3 | **Wave combat** in the Shard Crater: player + 3 shardlings, Ember sparks / Frost motes, damage numbers | 3/4 top-down, default zoom | "FIGHT THE WAVES" | real HUD, attack button visible (honest) |
| P4 | **Hollow Warden entrance**: the N rift slabs open, red-violet beam, boss silhouette 14 studs tall | low angle, boss fills 60% of the height | "BEAT THE HOLLOW" | boss name billboard |
| P5 | **Shard Draft pick**: 3 cards (Rare / Common / Epic) over the scrim, with element shard bursts | screen capture at 1920×1080, real UI | "PICK 1 OF 3" | only if #416 ships in V1; otherwise swap in a Bag/Shard Core shot |

**Ad thumbnails, 7.6 (8 = 4 hooks × 2)**
| # | Hook | Scene | Text | Pair test |
|---|---|---|---|---|
| AD1 | Rare loot | Legendary reveal close-up (gold burst, prismatic shard splitting) | "CRACK A SHARD" | vs. AD2 |
| AD2 | Rare loot | same scene, the character's face lit gold, 10% tighter | none | text vs. no text |
| AD3 | Boss | Hollow Warden looming over the player, red-violet light | "BEAT THE HOLLOW" | vs. AD4 |
| AD4 | Boss | over the boss's shoulder at a small player swinging a glowing blade | none | framing |
| AD5 | Rarity ladder | 5 shards standing in a row, Common → Legendary, the Legendary one tallest and glowing | "HOW RARE?" | vs. AD6 |
| AD6 | Rarity ladder | the same 5 shards cracking at once (staged, it must match real VFX) | none | static vs. action |
| AD7 | World story | split frame: the left side full prismatic color, the right side drained gray with the Hollow fog, the player at the border | "SAVE THE COLOR" | vs. AD8 |
| AD8 | World story | wide Crater Square with shard rain and the cracked sky (P1 alt crop) | none | wide vs. split |

**Description (draft, 585 characters, Roblox limit 1000; title: "Shardfall")**
> The god-crystal shattered and the sky cracked open. Its shards fell into Crater Square, and the Hollow is draining the color from everything they touched.
>
> - Crack shards for weapons and armor in 5 rarities: Common, Uncommon, Rare, Epic and Legendary. Every pull shows how rare it is.
> - Step through the Shard Gate and fight 5 waves in the Shard Crater, ending with the Hollow Warden.
> - Pick 1 of 3 Shard Draft buffs between waves: Ember, Frost or Void.
> - Salvage spare gear into Essence and feed your favorite weapon's Shard Core.
>
> Built for phones first. Plays on tablet and PC too.

Short version (2 lines, for previews): "The sky cracked and the shards fell. Crack them for 5 rarities of loot and fight the Hollow."

## 7. Edge cases
- **Copy risk (Roadmap 7.6 risk):** Ads Manager says campaigns for games that aren't unique "can result in no ad spend and no conversions", and look-alike games rank lower. So: our own names only (Shardfall, Crater Square, Lumen Heart, Crackstone, Shard Gate, Shard Crater, Hollow Warden, Shard Draft, Wren). No "RNG", "Simulator" or "Sol's"-style title words, no spinning aura-text look, and no other game's art, fonts or layouts. Every image passes the 2-of-3 identity rule (§6).
- **Honesty:** thumbnails show real V1 content and real UI (Roblox rejects misleading thumbnails, and it hurts D1 retention). Nothing that isn't in the build: no Mythic/Secret tiers, no pets/raids/parties unless they're live at publish. Odds text comes from Config at capture time.
- **No Robux, prices or offers** in any image or the description. No "free", "%", "best", "#1", "new!" claims. Store items (`docs/design/store_copy.md`) stay out of all store art.
- **Moderation:** no blood, no real-world logos, and no text that implies a giveaway. If an ad is rejected, swap in the pair image (each hook has 2).
- **Feature not live at publish** (for example #416 Shard Draft): drop P5 / AD7's draft mention and remove that description line. The description lists only what ships.
- **Light/dark theme:** the icon and thumbnails are checked on both (readability sheet).
- **Localization:** V1 English only. Text-safe boxes leave about 30% slack for later languages.
- **Reduced data / old phones:** keep files < 3 MB (Roblox limit) and avoid fine noise that turns into JPEG mush.

## 8. Mockups
SVG in `mockups/` (original art, fake data; these are direction sketches, not final art). Local PNG renders are in Prism's `/workspace/prism/store-briefs/png/`.
| File | Shows |
|---|---|
| `mockups/icon-A-cracked-shard.svg` | Direction A (recommended), 512×512 |
| `mockups/icon-B-crater-hero.svg` | Direction B, 512×512 |
| `mockups/icon-C-rarity-fan.svg` | Direction C, 512×512 |
| `mockups/icon-D-split-world.svg` | Direction D, 512×512 |
| `mockups/icon-readability-sheet.svg` | All 4 at 150 / 100 / 50 px, plus a 100 px light-theme tile |
| `mockups/thumb-template-1920x1080.svg` | Thumbnail template: action-safe 90%, top-left text-safe box, the bottom-15% no-text band, sample headline |

## 9. Build split
- **Prism:** the briefs (this doc), the final compose/paint-over of the icon and thumbnails from captures, small-size checks and the contact sheet for Kevin. Docs only and no uploads.
- **Ghost (Studio, no code changes required):** a capture copy of the place with the #413 Lighting (ClockTime 18.5, Atmosphere and Bloom from #413), the shard rain, the pull beam and the Warden entrance triggerable in Studio. Hide the HUD for P1/P2/P4/AD shots, and keep it for P3/P5. Use a fixed 1920×1080 viewport and a high graphics level. If a capture helper needs code, that's Ghost's call and outside this PR.
- **Kevin:** picks (§11), uploads the icon, thumbnails and description in Creator Hub, and gives the final OK on any ad spend in Ads Manager.
- **Echo:** none (no server work).

## 10. Pass criteria (Kevin can check these)
1. The icon reads as "a glowing cracked crystal" at 50 px on a phone, on both the dark and light themes.
2. Every thumbnail reads at 160×90 (hold the phone at arm's length: you can say what's happening).
3. Each image has 2 of the 3 identity marks (prismatic shard, cracked sky, Hollow gray).
4. No text in the bottom 15% or the top-right corner. Max 4 words per image, gameplay-only words.
5. No Robux, prices, offers, Mythic/Secret or unreleased features anywhere. The description lists only shipped features.
6. 5 page thumbnails + 8 ad thumbnails, all 1920×1080 and < 3 MB, plus 1 icon at 512×512.
7. A tester who hasn't seen the game can't name another Roblox game it "looks like" (ask 3 of the 7.4 playtesters).

## 11. Open questions (answer by number)
1. **@Kevin (taste):** icon direction: **A** The Cracked Shard (Prism recommends), B Hero on the Crater lip, C Rarity fan, or D Split world?
2. **@Kevin (taste):** title: plain **"Shardfall"** (Prism recommends; unique and short) or with a tagline like "Shardfall: Crack the Sky"?
3. **@Kevin (taste):** headline text on thumbnails: on P1/P3/P4/P5 and half the ads as listed (Prism recommends; the ad test checks it), or no text at all?
4. **@Kevin (taste):** description voice: the story-first draft in §6 (Prism recommends), or a shorter feature-list-only version?
5. **@Ghost:** can the capture copy of the place trigger the pull beam, the shard rain and the Warden entrance in Studio without code changes? If not, which capture helper do you want (your call)?

## Decision log
- 2026-10-24 (Prism): v1 brief written for Roadmap 7.5/7.6 as prep only (no Robux, pricing or spend). Recommends icon A. Nothing is official until Kevin approves it and it's copied into Vision & Design Rules.

## Roblox build notes
- These are store assets (image files), not in-game UI, so they aren't rendered by Roblox UI. Captures still use only what Roblox renders in-engine: Parts/MeshParts, Neon, Beams, ParticleEmitters, Atmosphere, Bloom. No faked shaders or blur that the game can't show (honesty rule).
- If any of this art is reused **in game** (a loading screen or splash): build it as an `ImageLabel` (the uploaded PNG) inside a `Frame` with `UICorner` 12 and `UIStroke` 2 (gold 255,196,64 at transparency 0.5), and an optional `UIGradient` for the prismatic edge. Shimmer is a TweenService tween of `UIGradient.Offset`. Sparkles are a few small `ImageLabel`s tweened, or a world `ParticleEmitter` behind the UI. No blur, no `BlurEffect`, no post effects beyond Bloom.
- The icon at 512×512 is uploaded as-is. Don't bake rounded corners (Roblox rounds tiles itself).
