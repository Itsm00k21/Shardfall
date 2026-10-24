# Element Glow Read ("Outline-led"): Ember / Frost / Void on enemies, Spec v1.1

Owner: Prism (design, docs only, no code). Builders: Echo (server glow in `DungeonService` + `Config/Elements`), Ghost (client pip on the enemy bar, if Q2 yes). Base: `cursor/live-build-9721`. Status: **v1.1, Ghost answered Q1, Q2, Q5, Q6, Q7** (board row https://app.notion.com/p/403c31ca3883819d821fe59c27a3d730, Oct 24, 2026, Kevin pre-approved). v1 came from Ghost's GO row https://app.notion.com/p/403c31ca38838155a532f79564499765. Q3 and Q4 (Ember vs orange, Void vs Epic) are Kevin taste calls, now studied in the **Element color separation study** (`prism/element-color-study`, `docs/design/element-color-study/`). Gray-box only (pre-Phase S). Element colors stay **PROVISIONAL** for Kevin. Not an official Vision & Design Rules decision until Kevin approves it.
Asked for in: Ghost's board row: "element glow read spec for #432 (incl. P2-432-1 fallback)". Roadmap **2.3** (elements) and **3.x** (wave readability).

Sources (link, don't copy):
- **PR #432** (`echo/element-glow` @ `eb08366`, read only; flag `LaunchGate.elementGlow = false`):
  - `Shared/Config/Elements.luau`: Ember **255,112,36**, Frost **92,214,255**, Void **196,92,255**; `GLOW` = `fillTransparency 0.28`, `outlineTransparency 0`, `lightBrightness 3`, `lightRange 22`, `depthMode "AlwaysOnTop"`. Tuned for "a phone at crawl zoom (`Dungeons.CAMERA_MAX_ZOOM` 18) on wave 4".
  - `Shared/ElementGlow.luau`: element from **spawn order** (`ORDER` ember → frost → void); flag off returns nil, nothing builds.
  - `DungeonService.applyElementGlow`: one `Highlight` (fill = outline = element color) on the rim host, the warm `Rim` Highlight is **disabled** while the glow draws (so still 1 Highlight per enemy), plus one `PointLight` on the root part. Attribute `ShardfallElement` on the part.
  - `Shared/Dungeons.luau` `RIM`: fill 255,214,160 @ 0.88, outline 255,236,200 @ 0.2 (today's default read).
- **Havoc DP14** (board row https://app.notion.com/p/403c31ca3883816ba337eff1ab1648ef, report https://app.notion.com/p/403c31ca388381339e36c73c90f10e34): SHIP flag-off. **P2-432-1:** Roblox draws at most **31 Highlights** at once; dead enemies keep theirs until wave clear, so at ~22 alive about 10 kills push new glows past the limit. Fix: remove glow + rim on death and cap how many enemies glow on mobile. **P3-432-1:** the light stays lit on the corpse spot. **P3-432-2:** #422 wave-arena enemies get no glow. **P3-432-3:** element follows spawn order, not enemy type. Real alive counts on live today: 3–8 (4 on mobile). **New since Havoc's audit: PR #433** (open, flag `enemyPerf` off) sets `Config.EnemyPerf.ALIVE_CAP` = **22**, so the 22-alive case is no longer only a stress model.
- Specs this must match: **Boss telegraphs v1.1** (`prism/boss-telegraphs`: threat orange 255,120,40, flat floor shapes with white rims). **Hard accent v1.1** (`prism/hard-accent`: Hard is HUD-only, no sky tint). **M15 element buffs v1.2** (#416). **Wave HUD v1.1** (#428 buff pips). **#414 Shard Crater** (arena floor ≈ 64,56,84 → 30,26,42). **#420** keep-out.
- Chrome: PR #392 `docs/ui/reference/STYLE.md`. Rarity colors (`Shared/Rarities.luau`: Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64) are **loot** colors; element glows are **enemy** colors (see §7 for the Void/Epic overlap).

## 0. Directions (pick one) and recommendation
Mockup: `mockups/07-directions.svg` (and the side-by-side in `06-swatch-sheet.svg`).

| | Direction | How it reads | Good | Bad |
|---|---|---|---|---|
| **A** | **Outline-led** | Highlight **fill 0.5** (body keeps its shape and eyes), **outline = element color lerped 45% to white** at 0, a small ground-pool `PointLight` (range 10, brightness 1.5), plus a 12 px **element pip** (shape) on the enemy bar. | Hue + silhouette + shape: reads at ~40 px on 390×844, works for colorblind players, doesn't wash the floor with 8 lights. The pip is also the over-budget fallback (P2-432-1). | One extra small UI element per enemy bar; 3 Config numbers change from #432. |
| B | #432 as-is | Fill 0.28 + same-color outline + big light (range 22, brightness 3). | Loudest; already built. | Enemies turn into flat color blobs (type and eyes vanish); 8 lights of range 22 overlap and tint the whole floor (and the slam ring); no shape cue. |
| C | Outline only | Fill off, tinted outline + pip, no light. | Cheapest (no lights). | The 1-ish px Highlight outline is thin at crawl zoom on a phone; no location cue on the floor. |

**Recommendation: A.** It's the only one where 8 enemies stay readable as *different enemies* and *different elements* at phone size, and it keeps the slam ring and the floor readable. The rest of this spec is A. It's a Config tune of #432 plus the death/budget rules, not a rebuild.

## 1. Goal
On a 390×844 phone at crawl zoom 18, with 3–8 enemies alive, a new player can say which enemy is Ember, Frost or Void at a glance (≤ 1 s), tell two enemies of the same element apart by body shape, and never confuse an Ember enemy with a boss telegraph. Dead enemies stop glowing at once, and no enemy ever silently loses its read.

## 2. Where it lives
- **Server (Echo, #432 follow-up):** `Config/Elements` numbers (§6), `applyElementGlow` (outline color = tinted element color), **remove glow + light on death** (not at wave clear), and the **glow budget** (§4). The warm `Rim` is re-enabled for an enemy that has no glow slot. Nothing saved, no remote added, schema stays 26.
- **Client (Ghost, Q2 decided: pip yes, no bar stroke):** a 12×12 element **pip** at the left end of the existing enemy bar (`enemyBar` BillboardGui), read from the `ShardfallElement` attribute. **No bar stroke** (v1.1). Display-only. Prism doesn't edit Ghost-owned UI files.
- **Not here:** element damage/resists (Roadmap 2.3 stats), boss element glow (Q5 decided: none in v1), Phase S VFX (element particles, shader-like rims), any Robux.

## 3. Flow
| Step | Trigger | What the player sees |
|---|---|---|
| 1 | Flag `elementGlow` off (ships this way) | Today's warm Rim on every enemy. No pips, no lights. Zero element pixels. |
| 2 | Enemy spawns, glow slot free | Highlight pops in over 0.15 s (Fill 1 → 0.5, Outline 1 → 0), ground pool light fades in. Pip shows on the bar. |
| 3 | Enemy spawns, glow budget full | Warm Rim (as today) + pip. No light. |
| 3b | Enemy spawns, enemy Highlight ceiling (18) full (only with #433's cap 22) | No Highlight at all: pip only. |
| 4 | An enemy with a glow dies | Glow fades out in 0.15 s (Fill/Outline → 1, light Brightness → 0), then the Highlight and light are **destroyed**. The slot is free. |
| 5 | Slot freed | The **oldest alive enemy without a glow** gets it (one swap per frame): Rim disabled, glow pops in (step 2). |
| 6 | Wave clear | Nothing left to clean (everything was removed at death). |
| 7 | Boss wave | Boss keeps its own gold-stroked look and Rim (no element glow in v1, Q5 decided); adds glow normally within the budget. |

## 4. Layout
World visuals are 3D and may cross the center keep-out (that rule is for UI panels). The pip is world UI on the enemy bar, so it moves with the enemy.

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Enemy on screen at zoom 18 | ~40–46 px tall | ~36 px | ~38 px | ~60 px |
| Highlight outline | Roblox fixed width (~1–2 px), weight comes from transparency 0 + the light tint | same | same | same |
| Pip (BillboardGui child) | 12×12 at the bar's left end, 4 px gap | 12×12 | 12×12 | 14×14 |
| Glow budget | **6** (touch) | 6 | 6 | **12** (keyboard/mouse) |
| Ground pool lights | max **4** (touch) | 4 | 4 | 12 |

Highlight count rule (fixes P2-432-1): **every alive enemy has at most 1 Highlight** (element glow *or* warm Rim, never both); **every dead enemy has 0**. **Enemy Highlight ceiling = 18** (glow + Rim together), leaving 13 of Roblox's 31 for players, loot, the boss and other systems. At today's 3–8 alive this never binds. With #433's alive cap 22, enemies 19–22 get **no Highlight**: they read by the pip only, and gain a Rim/glow as soon as one frees. Mockup `08-cap-fallback.svg`.
Checks: nothing tappable is added (pip is display-only; no 44 px target needed). No UI panel is added, so the keep-out at all 4 sizes is unchanged.

## 5. States
| Element | Flag off | Glow (slot) | Over glow budget | Dying (0–0.15 s) | Dead |
|---|---|---|---|---|---|
| Highlight | warm Rim | element: Fill 0.5, Outline 0 (tinted) | warm Rim (Fill 0.88, Outline 0.2) | Fill/Outline tween → 1 | destroyed |
| Rim | on | disabled | on | — | destroyed with the glow (P2) |
| PointLight | none | range 10, brightness 1.5 (if under the light cap) | none | Brightness → 0 | destroyed (P3-432-1) |
| Pip | none | shape + color | shape + color | fades with the bar | gone |
Loading: if `ShardfallElement` isn't set yet, show no pip (never a wrong one). Error: unknown id → no glow, warm Rim (matches `ElementGlow.visual` returning nil).

## 6. Numbers
- **Fill colors (PROVISIONAL, Kevin; options in the element color study):** keep #432 until Kevin picks: Ember **255,112,36**, Frost **92,214,255**, Void **196,92,255**.
- **Outline colors (new, rec A):** element color lerped 45% to white: Ember **255,176,134**, Frost **165,232,255**, Void **222,165,255**. The lighter rim reads on the dark crater floor and on the violet sky; the fill carries the hue.
- `GLOW`: `fillTransparency` 0.28 → **0.5**; `outlineTransparency` **0** (keep); `lightBrightness` 3 → **1.5**; `lightRange` 22 → **10** (a pool under the enemy, not a floor wash); `depthMode` **AlwaysOnTop** (keep: enemies behind pillars still read).
- Budget knobs (Echo names them, Config only): glow max **6 touch / 12 desktop**; light max **4 touch / 12 desktop**; enemy Highlight ceiling (glow + Rim) **18** on every device. Over the ceiling: pip only. All three knobs OK'd by Ghost (Q6).
- Tweens: in 0.15 s (Quad Out), out 0.15 s (Quad In). One slot hand-off per frame.
- Pip shapes: Ember = flame triangle, Frost = crystal diamond, Void = ring. 12×12, 1 px ink 20,16,28 stroke.
- Grayscale check (luma): Ember ≈ 145, Frost ≈ 180, Void ≈ 142. Ember and Void are close in gray, so the **shape pip is required** for colorblind reads (Q2 decided: yes).

## 7. Edge cases
- **Ember vs boss telegraph orange (255,120,40):** nearly the same hue. They stay apart by shape (telegraphs are flat floor lanes/rings with white rims and chevrons; Ember is a lit body with a light-tint rim) and by the smaller light (rec A's range 10 keeps Ember pools from looking like slam rings). Q3 (Kevin) is now worked out with swatches and colorblind checks in the element color study.
- **Void vs Epic (186,96,240):** same family. Context separates them (Epic is on loot tiles, drops and UI; Void is on enemies). Q4 (Kevin), see the element color study.
- **Frost vs gate cyan (120,210,255):** gates are static arch parts; OK.
- **Hard:** colors and weights don't change on Hard (Hard accent v1.1 is HUD-only, no sky tint).
- **Element source (P3-432-3, Q1 decided):** the target is **element by enemy type in Config**, so players learn each enemy's element. #432's spawn-order pick **stays for v1**; per-type mapping is a **later Echo task**. Until then the same enemy type can change color between waves, which is fine for the read test.
- **#422 arena path (P3-432-2):** the glow only exists on the Rootvault spawn path. The budget and death rules must cover the #422 arena path too when it gets glows (Echo).
- **Low graphics:** Highlights still draw; lights may be culled. The pip and outline carry the read without lights.
- **Party of 4:** Highlights are per enemy, not per viewer, so the count doesn't scale with players.
- **Accessibility:** shape pips + outline tint; never color alone.
- **Performance:** ≤ 1 Highlight per alive enemy, ≤ 4 lights on touch, no particles, no per-frame scripts except the one-per-frame slot hand-off.

## 8. Mockups
SVG in repo (fake data, original art, gray-box crater). `mockups/01-wave4-phone-390x844.svg` (rec A, 3 enemies, one per element) · `mockups/02-eight-alive-cap-phone-390x844.svg` (8 alive, budget 6, 2 on the warm-Rim + pip fallback) · `mockups/03-boss-wave-landscape-667x375.svg` (Ember next to a slam ring) · `mockups/04-death-drop-landscape-800x400.svg` (glow fades on death) · `mockups/05-desktop-1280x720.svg` · `mockups/06-swatch-sheet.svg` (A/B/C per element, gray values, look-alike colors) · `mockups/07-directions.svg` (A/B/C) · `mockups/08-cap-fallback.svg` (31-Highlight budget, death timeline, fallback, pips). Live HUD dashed; keep-out cyan dashed. PNG renders are on the box only.

## 9. Build split
Before `elementGlow` is ever turned on. Building waits for Ghost's go.
- **Echo (server, #432 follow-up):** Config numbers (§6), tinted outline color, destroy Highlight + light on death with a 0.15 s fade (P2-432-1, P3-432-1), the glow budget + oldest-first hand-off, warm Rim back on for over-budget enemies, the same rules on the #422 arena path (P3-432-2). Tests: alive enemy has ≤ 1 Highlight; dead has 0; glow count ≤ budget; enemy Highlights ≤ 18 with 22 alive (#433); flag off builds nothing.
- **Ghost (client, Q2 decided):** element pip on the enemy bar from `ShardfallElement`. No bar stroke.
- **#428 Wave HUD buff pips (Q7 decided):** read the same `Config/Elements` colors (Prism folds this into #428's spec).
- **Prism:** Phase S pass (element particles, pip art) after the fun test; check Kevin's color call.
- **Havoc:** 8 alive on a phone, kill 20 in a row in one wave (Highlights never stack), 22-enemy stress, Low graphics, flag flip mid-wave.

## 10. Pass criteria (playtest)
1. At 390×844, 4 of 5 testers name the element of 3 enemies in under 1 s each.
2. With 8 alive, testers can still point at "the Frost one" and "the other Frost one" (body shape still reads).
3. No tester calls an Ember enemy's light a "danger circle" when a slam ring is on screen.
4. After 20 kills in one wave, every alive enemy still has its glow or Rim (Studio Highlight count ≤ alive + players + loot).
5. Colorblind check (grayscale capture): elements are still named correctly from the pips.

## 11. Open questions (answer by number)
1. ~~@Ghost: Element by spawn order or by enemy type?~~ **By enemy type in Config (Ghost, Oct 24, 2026):** players learn each enemy's element. #432's spawn-order pick stays for v1; per-type is a later Echo task.
2. ~~@Ghost: Pip + bar stroke on the enemy bar?~~ **Pip yes, no bar stroke (Ghost).**
3. **@Kevin (taste, PROVISIONAL):** Ember 255,112,36 vs orange (telegraph 255,120,40, Legendary 255,196,64, UI warn 255,168,48). Options and a recommendation are in the element color study (`docs/design/element-color-study/`). #432's color stays until Kevin picks.
4. **@Kevin (taste, PROVISIONAL):** Void 196,92,255 vs Epic 186,96,240. Options and a recommendation are in the element color study. #432's color stays until Kevin picks.
5. ~~@Ghost: Boss element glow?~~ **None in v1 (Ghost).**
6. ~~@Ghost: Budgets as Config knobs?~~ **OK (Ghost):** glow 6 touch / 12 desktop, lights 4 / 12, enemy Highlight ceiling 18.
7. ~~@Ghost: #428 buff pips read Config/Elements colors?~~ **Yes (Ghost).** Prism folds it into #428's spec.

Ghost's questions are all answered. Only Kevin's two color calls (Q3, Q4) remain.

## Decision log
- 2026-10-24 (Prism): v1 published from Ghost's GO (board row https://app.notion.com/p/403c31ca38838155a532f79564499765, Kevin pre-approved). Recommends direction A (outline-led: fill 0.5, light-tint outline, range-10 pool, shape pip). Includes the P2-432-1 fix (≤ 1 Highlight per alive enemy, 0 per dead, glow budget 6/12 with warm-Rim + pip fallback, enemy Highlight ceiling 18 for #433's cap 22). Seven open questions (Ghost 1, 2, 5, 6, 7; Kevin 3, 4). Not approved.
- 2026-10-24 (Ghost, Kevin pre-approved; board row https://app.notion.com/p/403c31ca3883819d821fe59c27a3d730): Q1 = element by enemy type in Config is the target, #432's spawn order stays for v1, per-type is a later Echo task. Q2 = pip yes, **no bar stroke**. Q5 = no boss glow in v1. Q6 = budgets 6/12, lights 4/12, ceiling 18 OK. Q7 = #428 buff pips use Config/Elements colors. → **v1.1**: bar stroke removed from §2–§6, §9 and the build notes; over-ceiling fallback is pip only; mockups 02 and 08 re-rendered without the bar stroke. Q3/Q4 moved to the element color study for Kevin.

## Later (not V1)
Element particles on enemies (Ember sparks, Frost motes, Void wisps), element hit flashes, a per-element death pop, element weakness hints on the pip. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox only. No blur, no post-processing, no custom shaders. The mockups are a guide and these notes win.

| Element | Instances |
|---|---|
| Element glow | `Highlight` (Adornee = rim host, `FillColor` element, `OutlineColor` tinted element, `FillTransparency` 0.5, `OutlineTransparency` 0, `DepthMode` AlwaysOnTop); spawn-in = `TweenService` on Fill/Outline transparency 1 → target, 0.15 s |
| Ground pool | `PointLight` on the root part (Range 10, Brightness 1.5, Shadows false, Color element); only while under the light cap |
| Warm Rim | existing `Rim` `Highlight`; `Enabled = false` while a glow draws, `true` when over budget |
| Death | tween Fill/Outline → 1 and light Brightness → 0 (0.15 s Quad In), then `Destroy()` the glow, the Rim and the light **before** the corpse fade (`DungeonService` death path, ~:1987) |
| Budget | server table of enemies with a glow and with a Rim; on spawn: glow if glow count < max, else Rim if enemy Highlights < 18, else none; on death: free, then give it to the oldest alive enemy without one (≤ 1 per `Heartbeat`) |
| Pip (client) | inside the enemy bar `BillboardGui`: `ImageLabel` 12×12 (or `Frame` + `UICorner`/rotated `Frame` for gray-box shapes) + `UIStroke` 1 ink; `Visible` from `ShardfallElement`. No bar `UIStroke` (v1.1) |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| pip_ember_12 / pip_frost_12 / pip_void_12 | 12×12 (+ 24×24 @2x) | enemy bar pips (gray-box can use Frames) |
