# Element Color Separation Study (Ember vs orange, Void vs Epic), v1

Owner: Prism (design, docs only, no code). Builders (only after Kevin picks): Echo (`Config/Elements` colors on #432), Ghost (#428 buff pips read the same colors). Base: `cursor/live-build-9721`. Status: **v1, recommendations awaiting Kevin.** Final colors are **Kevin's taste call**; nothing here is approved or copied into Vision & Design Rules until he picks. Gray-box only (pre-Phase S).
Asked for in: Ghost's Agent Board row (Kevin pre-approved) https://app.notion.com/p/403c31ca3883819d821fe59c27a3d730, pick 2 ("element color separation study (phone swatches)"), from Prism's queue suggestion https://app.notion.com/p/403c31ca388381e1975be0b435f03cd4. Answers the Kevin questions Q3 (Ember vs orange) and Q4 (Void vs Epic) of the element glow read spec (`prism/element-glow-read`, v1.1).

Sources (link, don't copy):
- **Element colors today:** `Config/Elements.luau` on `cursor/live-build-9721` has **no colors** (ids, names, stats only). The colors live on **PR #432** (`echo/element-glow`, flag `elementGlow` off): Ember **255,112,36**, Frost **92,214,255**, Void **196,92,255**.
- **Rarity colors:** `Shared/Rarities.luau` `Rarities.COLOR` on `cursor/live-build-9721`: Common 168,168,176 · Uncommon 64,186,98 · Rare **72,142,255** · Epic **186,96,240** · Legendary **255,196,64** (Mythic/Secret fold to Legendary in V1, `Config/Rarities.FOLD`).
- **UI oranges:** STYLE.md (PR #392, `docs/ui/reference/STYLE.md`): gold 255,196,64, **warn 255,168,48** (`GearBar` line 78), **UPGRADE 255,190,60**, danger/HP 230,80,96, button 108,78,196. **Boss telegraph** threat orange **255,120,40** (boss telegraphs v1.1, `prism/boss-telegraphs`).
- Glow read v1.1 rec A: fill transparency 0.5, outline = element color lerped 45% to white, pool light range 10, 12 px shape pip (flame / crystal / ring), no bar stroke.

## 0. Directions (pick one per element) and recommendation
Mockups: `mockups/01-ember-vs-orange-phone-390x844.svg`, `mockups/02-void-vs-epic-phone-390x844.svg`, `mockups/03-in-context-landscape-667x375.svg`, `mockups/04-colorblind-sims.svg`, `mockups/05-swatch-table.svg`.

**Ember (vs Legendary gold, UI warn/UPGRADE, telegraph orange):**

| | Option | Hex / RGB | What changes | Good | Bad |
|---|---|---|---|---|---|
| E1 | Keep #432 | **#FF7024** · 255,112,36 | nothing | No change; clear of Legendary gold in normal vision (ΔE 28). | Same color as the boss telegraph (ΔE 2 in every vision); vs UI warn only 7 for deutan players. |
| E2 | Redder | **#FF5420** · 255,84,32 | hue 21° → 14° | Further from gold and warn (min 10). | Still close to the telegraph for deutan (4); same brightness as the HP red in gray (1). |
| **E3** | **Deep ember (rec)** | **#E84814** · 232,72,20 | hue + **darker** (luma 146 → 114) | Separates from every UI orange by **value**, not only hue, so it survives all 4 sims (min 9 vs telegraph, ≥ 16 vs gold/warn/UPGRADE). Light-tint outline #F29A7E keeps 5.1:1 on the floor. | Fill alone is darker on the floor (2.8:1); the outline carries the edge (rec A already does). Close to the HP-bar red for tritan (5) → the flame pip shape covers it. |

**Void (vs Epic purple, UI button, Rare blue):**

| | Option | Hex / RGB | What changes | Good | Bad |
|---|---|---|---|---|---|
| V1 | Keep #432 | **#C45CFF** · 196,92,255 | nothing | No change. | **Same color as Epic** (ΔE 2 in every vision). Also looks like **Rare blue** for deutan players (ΔE 2) — a new finding. |
| V2 | Deep indigo | **#8048FF** · 128,72,255 | darker, bluer | Stays "void purple"; clear of Epic in normal vision (12); keeps Ember vs Void apart in every sim. | Protan players: 6 vs Epic; close to the UI button purple (8). |
| **V3** | **Deep plum (rec)** | **#C04888** · 192,72,136 | hue toward magenta-berry + darker | Clear of Epic in **every** vision (min 18), of Rare (min 23) and of the button (min 12). Reads as "not loot" at a glance. | Less "classic purple" (a taste call); Ember vs Void for tritan drops to 12 (still clear) and both are the same gray (pips cover it, as today). |

**Recommendation (awaiting Kevin): E3 Deep ember #E84814 + V3 Deep plum #C04888.** They are the only picks where every element-vs-loot/UI pair in this study (Legendary, warn, UPGRADE, telegraph, Epic, button, Rare) stays ≥ 9 ΔE00 in normal, protan, deutan and tritan vision. The HP-bar red is the one close neighbor (Ember E3 5 for tritan), and the pip shape covers it (§7). If Kevin wants Void to stay blue-purple, **E3 + V2 (#8048FF)** is the runner-up. Rarity colors and UI chrome never move in this study; only the two element colors do.

## 1. Goal
A phone player at crawl zoom can tell, in under 1 s, an **Ember enemy** from a Legendary drop, a UI warning or a boss telegraph, and a **Void enemy** from an Epic drop or Epic card, including players with the three common color-vision types. Element colors should mean "enemy element", never "loot rarity".

## 2. Where it lives
- **Config only (Echo, after Kevin's pick):** the `color` field of each element in `Config/Elements` (#432). Outline colors are derived (45% to white), so they follow automatically.
- **Client (Ghost):** #428 Wave HUD buff pips read the same `Config/Elements` colors (Ghost Q7 decided); the enemy-bar pip reads them too. No new UI.
- **Not here:** rarity colors (`Shared/Rarities.luau`), UI chrome (STYLE.md), the boss telegraph color (boss telegraphs v1.1), Phase S VFX.

## 3. Flow
Not a screen flow. Decision flow: (1) Kevin looks at the 5 sheets on a phone (PNG renders on the box) → (2) picks one Ember and one Void (or keeps #432) → (3) Prism records it in this spec, the glow read spec and #428 → (4) Echo changes the 2 Config colors on #432 (flag stays off) → (5) Havoc checks the colorblind captures in Studio (pass criteria §10).

## 4. Layout
No new layout. Where the colors appear (all sizes):

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Enemy Highlight + pool light | ~40–46 px enemy at zoom 18 | ~36 px | ~38 px | ~60 px |
| Enemy-bar pip | 12×12 | 12×12 | 12×12 | 14×14 |
| #428 buff pips | 10 px, row x 16–84, y 226–240 | x 61, y 184 | x 66, y 184 | x 88, y 190 |
| Loot (unchanged) | tiles 52–64 px with rarity stroke 2; drop beams | same | same | same |
Checks: nothing tappable added; no panel added; keep-out unchanged.

## 5. States
| Element color use | Normal | Over glow budget | Dead | Flag off |
|---|---|---|---|---|
| Highlight fill / outline | element / tinted element | warm Rim (no element color) | gone | warm Rim |
| Pool light | element | none | gone | none |
| Pip (bar) | element + shape | element + shape | gone | none |
| #428 buff pip | element + shape | — | — | — |

## 6. Numbers
All ΔE00 values (CIEDE2000); sims = Machado et al. 2009 at full severity in linear RGB; gray = Rec.601 luma. Read: **≥ 10 clear at a glance · 5–10 needs the shape · < 5 looks the same.**

### Ember vs orange (ΔE00)
| Option | vs | Normal | Protan | Deutan | Tritan | Gray |
|---|---|---|---|---|---|---|
| E1 keep #FF7024 | Legendary 255,196,64 | 28 | 19 | 11 | 20 | 15 |
| E1 keep #FF7024 | UI warn 255,168,48 | 18 | 13 | 7 | 13 | 10 |
| E1 keep #FF7024 | UPGRADE 255,190,60 | 26 | 17 | 11 | 19 | 14 |
| E1 keep #FF7024 | Telegraph 255,120,40 | 2 | 2 | 1 | 2 | 2 |
| E1 keep #FF7024 | HP / danger 230,80,96 | 22 | 21 | 14 | 4 | 7 |
| E2 redder #FF5420 | Legendary 255,196,64 | 35 | 25 | 14 | 26 | 21 |
| E2 redder #FF5420 | UI warn 255,168,48 | 25 | 19 | 10 | 19 | 16 |
| E2 redder #FF5420 | UPGRADE 255,190,60 | 33 | 24 | 14 | 24 | 20 |
| E2 redder #FF5420 | Telegraph 255,120,40 | 9 | 8 | 4 | 8 | 8 |
| E2 redder #FF5420 | HP / danger 230,80,96 | 17 | 17 | 12 | 2 | 1 |
| E3 deep ember #E84814 | Legendary 255,196,64 | 37 | 30 | 19 | 26 | 27 |
| E3 deep ember #E84814 | UI warn 255,168,48 | 28 | 24 | 16 | 20 | 22 |
| E3 deep ember #E84814 | UPGRADE 255,190,60 | 35 | 29 | 19 | 25 | 26 |
| E3 deep ember #E84814 | Telegraph 255,120,40 | 12 | 14 | 9 | 9 | 14 |
| E3 deep ember #E84814 | HP / danger 230,80,96 | 17 | 17 | 11 | 5 | 5 |

### Void vs purple (ΔE00)
| Option | vs | Normal | Protan | Deutan | Tritan | Gray |
|---|---|---|---|---|---|---|
| V1 keep #C45CFF | Epic 186,96,240 | 2 | 2 | 2 | 2 | 1 |
| V1 keep #C45CFF | Button 108,78,196 | 19 | 14 | 18 | 31 | 17 |
| V1 keep #C45CFF | Rare 72,142,255 | 27 | 6 | 2 | 50 | 3 |
| V1 keep #C45CFF | HP / danger 230,80,96 | 32 | 39 | 49 | 22 | 5 |
| V2 deep indigo #8048FF | Epic 186,96,240 | 12 | 6 | 10 | 29 | 11 |
| V2 deep indigo #8048FF | Button 108,78,196 | 8 | 8 | 8 | 7 | 4 |
| V2 deep indigo #8048FF | Rare 72,142,255 | 23 | 12 | 9 | 21 | 9 |
| V2 deep indigo #8048FF | HP / danger 230,80,96 | 37 | 40 | 55 | 44 | 7 |
| V3 deep plum #C04888 | Epic 186,96,240 | 19 | 18 | 22 | 18 | 9 |
| V3 deep plum #C04888 | Button 108,78,196 | 23 | 12 | 24 | 37 | 6 |
| V3 deep plum #C04888 | Rare 72,142,255 | 38 | 23 | 24 | 68 | 7 |
| V3 deep plum #C04888 | HP / danger 230,80,96 | 17 | 25 | 25 | 9 | 5 |

### Element vs element (ΔE00)
| Pair | Normal | Protan | Deutan | Tritan | Gray |
|---|---|---|---|---|---|
| Today E1/V1 Ember–Void | 49 | 59 | 61 | 21 | 1 |
| Today E1/V1 Ember–Frost | 59 | 50 | 52 | 68 | 11 |
| Today E1/V1 Void–Frost | 42 | 24 | 16 | 57 | 12 |
| Alt E2/V2 Ember–Void | 50 | 61 | 68 | 45 | 8 |
| Alt E2/V2 Ember–Frost | 63 | 51 | 52 | 71 | 17 |
| Alt E2/V2 Void–Frost | 41 | 29 | 26 | 35 | 24 |
| Rec E3/V3 Ember–Void | 33 | 41 | 33 | 12 | 0 |
| Rec E3/V3 Ember–Frost | 63 | 54 | 53 | 71 | 23 |
| Rec E3/V3 Void–Frost | 63 | 34 | 26 | 81 | 22 |

### Fill and outline values
| Color | Hex | RGB | Luma (Rec.601) | Contrast on crater floor 64,56,84 | Rec A outline (45% to white) | Outline contrast on floor |
|---|---|---|---|---|---|---|
| E1 keep | #FF7024 | 255,112,36 | 146 | 4.0:1 | #FFB087 (255,176,135) | 6.2:1 |
| E2 redder | #FF5420 | 255,84,32 | 129 | 3.4:1 | #FFA184 (255,161,132) | 5.6:1 |
| E3 deep ember | #E84814 | 232,72,20 | 114 | 2.8:1 | #F29A7E (242,154,126) | 5.1:1 |
| V1 keep | #C45CFF | 196,92,255 | 142 | 3.3:1 | #DFA5FF (223,165,255) | 5.7:1 |
| V2 deep indigo | #8048FF | 128,72,255 | 110 | 2.2:1 | #B99AFF (185,154,255) | 4.8:1 |
| V3 deep plum | #C04888 | 192,72,136 | 115 | 2.4:1 | #DC9ABE (220,154,190) | 4.9:1 |
| Frost keep | #5CD6FF | 92,214,255 | 182 | 6.5:1 | #A5E8FF (165,232,255) | 8.2:1 |


## 7. Edge cases
- **Grayscale Ember vs Void** is close in every option (today 1, rec 0). The shape pip (flame vs ring) is the colorblind read, as already decided (glow Q2). Don't drop the pip.
- **HP-bar red (230,80,96)** sits next to the pip on the enemy bar: Ember E3 and Void V3 are both ~5 from it for tritan/gray. The pip sits **left** of the bar with a 4 px gap and has a 1 px ink stroke, so it reads as a separate shape.
- **Hard accent** (danger 230,80,96, HUD-only, Hard accent v1.1): not on enemies, no conflict.
- **Boss telegraph:** E3 vs telegraph is 9–14 in every vision. The telegraph keeps its white rims and floor shape; no telegraph change needed.
- **Low graphics:** lights can be culled; the Highlight + pip carry the color.
- **Mythic 230,64,78** is folded to Legendary in V1 (`Config/Rarities.FOLD`), so it never shows; V3 plum would be close to it if Mythic ever returns (Later).
- **Phase S:** element particles should use the same base color + the tinted outline color.

## 8. Mockups
SVG in repo (fake data, original art, gray-box crater). `mockups/01-ember-vs-orange-phone-390x844.svg` (E1/E2/E3 next to a Legendary drop, UI warn, UPGRADE and a telegraph ring, with ΔE chips) · `mockups/02-void-vs-epic-phone-390x844.svg` (V1/V2/V3 next to an Epic drop, Epic card, UI button and a Frost enemy) · `mockups/03-in-context-landscape-667x375.svg` (wave 5 at 667×375: today vs recommended, with buff pips, loot and a telegraph) · `mockups/04-colorblind-sims.svg` (today / alt / rec under normal, protan, deutan, tritan, grayscale) · `mockups/05-swatch-table.svg` (hex, RGB, luma, floor contrast, outlines). PNG renders are on the box only.

## 9. Build split
Nothing to build until Kevin picks.
- **Echo:** change Ember and/or Void `color` in `Config/Elements` on #432 (flag stays off). Test: colors match this spec; outline = 45% to white.
- **Ghost:** #428 buff pips + enemy-bar pip read `Config/Elements` (already decided, Q7).
- **Prism:** record Kevin's pick here, in the glow read spec and #428; Phase S particle colors later.
- **Havoc:** Studio captures at 390×844 with a colorblind filter (any sim tool) on wave 4 + a Legendary/Epic drop on screen.

## 10. Pass criteria (playtest)
1. At 390×844, 4 of 5 testers never call an Ember enemy "a Legendary" or "a warning", and never call a Void enemy "an Epic".
2. On a deutan / protan / tritan capture, testers still name each enemy's element using color + pip.
3. Every element-vs-loot/UI pair in §6 for the picked colors (except the HP red, covered by the pip) is ≥ 9 in all four visions, or Kevin accepts the gap knowingly.

## 11. Open questions (answer by number)
1. **@Kevin (taste):** Ember: keep #FF7024 (E1), redder #FF5420 (E2) or **deep ember #E84814 (E3, recommended)**?
2. **@Kevin (taste):** Void: keep #C45CFF (V1), deep indigo #8048FF (V2) or **deep plum #C04888 (V3, recommended)**? (V2 if you want Void to stay blue-purple.)
3. **@Ghost (FYI):** V1 (today's Void) is ΔE 2 from **Rare blue** for deutan players, not only from Epic. If Kevin keeps V1, the pip shape is the only read for those players.

## Decision log
- 2026-10-24 (Prism): v1 published from Ghost's GO (board row https://app.notion.com/p/403c31ca3883819d821fe59c27a3d730, Kevin pre-approved). Recommends E3 #E84814 + V3 #C04888 (runner-up E3 + V2 #8048FF). **Recommendations only; final colors are Kevin's call. Not approved.**

## Later (not V1)
Per-element particle palettes (Phase S), a colorblind-mode toggle that thickens pips, Mythic color review if Mythic returns. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox only. All colors are flat `Color3` values; nothing here needs blur, post-processing or shaders.

| Use | Instance / property |
|---|---|
| Enemy glow | `Highlight.FillColor` = element color, `Highlight.OutlineColor` = element lerped 45% to white (`color:Lerp(Color3.new(1,1,1), 0.45)`), `FillTransparency` 0.5 |
| Pool light | `PointLight.Color` = element color |
| Pips | `ImageLabel.ImageColor3` (white pip art) or `Frame.BackgroundColor3` = element color + `UIStroke` 1 ink |
| #428 buff pips | same `Config/Elements` color, 10 px |
| Particles (Phase S) | `ParticleEmitter.Color` = `ColorSequence` (element → outline color) |

### Image assets to upload
None new (pip art from the glow read spec is white and tinted in code).
