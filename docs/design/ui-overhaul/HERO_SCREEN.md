# Hero Screen v1: big 3D hero, Attack/Defense stats, "Classes unlock soon" (NOT APPROVED, docs only)

Owner: Prism (design, docs only). Builder: Ghost (MenuHub Hero page). Base: `cursor/live-build-9721` @ **`8cb42ff`** (audit file:line refs are from `a28a5e2`; no client or shared UI file changed between the two). Date: Oct 24, 2026 (PT).
Asked for in: DP41P https://app.notion.com/p/403c31ca388381999e16eb0137b3af5a (deliverable 1; Kevin wants to see this before Ghost builds it). ACK: https://app.notion.com/p/403c31ca388381ec9523ef97de82e8c3. Related: Ghost's bug row (class step stuck with classes off; MenuHub picker ungated; Power 2102 = rarity floor) https://app.notion.com/p/403c31ca3883815ea631d39064bd4286. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Uses `HUD_ZONE_MAP.md` (Z12 panel rect) and `PANEL_STYLE.md` (chrome, cards, type). **Preview images:** `mockups/01-hero-desktop-1920x1080-locked.svg` (recommended state), `02-hero-desktop-1920x1080-class.svg`, `03-hero-phone-390x844.svg` (3 frames: top, scrolled, class picked).

## 1. Goal
Opening Hero should feel like looking at *your* hero: a big 3D character wearing exactly what's equipped, the numbers that matter grouped as Attack and Defense, and a class area that is never empty or confusing. While the server gate is closed, it clearly says **Classes unlock soon** and shows the Starter Kit you're actually using. No dead space at 1920×1080 or 390×844.

## 2. Where it lives + live audit (`a28a5e2`)
| Seed 1 symptom | Live cause (file:line) |
|---|---|
| Tiny, low-res character | The avatar is a `ViewportFrame` tucked in the header corner, 150×124 on desktop and 72×84 on phones (MenuHub.luau:3787-3796; sizes from `HeroBoard.sheet`, HeroBoard.luau:186-188). The panel itself is the 860×640 hub (MenuHub.luau:3641, HudLayout.luau:223-224) |
| Stat grid floating in empty space | 8 equal 64 px tiles in 4 columns (2 on phones), no grouping: Damage, HP, Defense, Attack speed, Crit, Crit damage, Gold find, Level (HeroBoard.luau:113-160, :182; MenuHub.luau:3833-3848) |
| Bottom half "No skills…" | `hubFn.line(..., "No skills until a class is chosen.")` (MenuHub.luau:4010) |
| "No class" next to full HP | header name falls back to "No class" / role "Choose a class" (MenuHub.luau:3699, :3711) |
| Picker shown while classes are off | `Choose` / `Choose class` / `Change class` are drawn with no `LaunchGate` check (MenuHub.luau:3575-3583, :3910-3917, :4012) while `LaunchGate.classes = false` (LaunchGate.luau:29); the server answers "That is closed". Same gate also stalls onboarding at the class step (OnboardHud.luau:62 copy; Echo's fix) |
| Power 2,102 at level 1 | not a bug: Power counts the gear rarity floor (`HeroBoard.power`, HeroBoard.luau:74; Ghost's row, InventoryView:202). It needs one explaining line, not a new number |
Reusable as is: `HeroView.rig`/`HeroView.place` (HeroView.luau:29-36) already clone the character into a `WorldModel`. The Bag "Worn" viewport (MenuHub.luau:2854) uses the same path. Equipped slots come from `EquipSlots.ORDER` = weapon, armor, pet, skill1, skill2 (EquipSlots.luau:25). Stats come from `CombatMath.loadout` via `HeroBoard.tiles`.

## 3. Flow
| Step | Player does | Sees |
|---|---|---|
| 1 | Taps the Hero rail button (or key) | panel grows from the button into Z12 (0.26 s); the hero turns 25° into view |
| 2 | Drags on the viewport (mouse, touch, right stick) | hero turns on Y, eases to a stop. 6°/s idle turn until the first drag |
| 3 | Taps a gear card | opens Bag on that slot's tab (Weapons / Armor / Pets) in the same panel rect |
| 4a | Classes **locked**: taps a class tile | tile shakes 4 px; status strip: "Classes unlock in a later update. You're using the Starter Kit." |
| 4b | Classes **open**, none picked: taps a class | tile selects (gold stroke), the skill kit area previews that class, primary button "Choose Frostblade" (server `SetClass`) |
| 4c | Class picked | identity row + resource + passive, skill kit (4 + ultimate), talent pick; "Change class" (secondary) reopens the picker |
| 5 | Equips something elsewhere | viewport re-clones; the rarity floor ring pulses once in the new top rarity |
| 6 | Collapses (chevron, Hero button, Esc/B) | panel shrinks back into the rail button (0.15 s) |

## 4. Layout
**1920×1080** (panel x 112-1552, y 104-920, 1440×816; panel-local px):
| Block | Rect | Contents |
|---|---|---|
| Header | 0-1440 × 0-64 | icon tile 44 · "HERO" 26 · "Itsm00k21 · Level 12" 16 · XP bar 240×8 + "3,450 / 5,000 XP" 14 · **Power chip** 184×44 (gold stroke, "POWER" 14 + "2,102" 26) · collapse 44×44 |
| Showcase | x 20-620, y 84-644 (600×560) | `ViewportFrame` with the equipped character + pet; floor ring in the top rarity; "Drag to turn" chip, "Equipped look" chip |
| Gear row | x 20-620, y 656-796 | 3 cards 190×140 (Weapon, Armor, Pet): icon tile 56, slot caps 14, name 16 bold in rarity color, badge, one stat line 14 |
| Stats card | x 640-1420, y 84-376 | "STATS" + two columns of 360: **ATTACK** (Damage, Attack speed, Crit chance, Crit damage) and **DEFENSE** (Max HP, Defense, Gold find) + the Power note, 48 px rows, label 16, value 22 |
| Class card | x 640-1420, y 388-796 | locked or picked (§5) |
**390×844** (panel x 72-382, y 136-836, 310×700; content scrolls under a sticky 56 px header):
| Block | Content y | Contents |
|---|---|---|
| Header | 0-56 (sticky) | "HERO" 20 + "Level 12" 14 · Power chip 110×40 · collapse 44 |
| Showcase | 64-276 | `ViewportFrame` 286×212 |
| Gear row | 284-356 | 3 cards 90×72: icon 36 + slot label 14 in rarity color (the name shows on tap) |
| Attack | 364-500 | 2×2 tiles 128×44 (label 14, value 18) |
| Defense | 508-644 | 2×2: Max HP, Defense, Gold find, Power (gear) |
| Class | 652-… | header row visible at first paint (scroll hint), full card after scrolling (mockup 03, frames 2-3) |
No dead space: every column is filled to the panel's padding at both sizes. The stats card and class card share the right column's height exactly (292 + 12 + 408 = 712).

## 5. States
| # | State | Class card | Notes |
|---|---|---|---|
| 1 | **Classes locked** (`LaunchGate.classes` off, today) **(recommended now)** | "CLASS" + gold "UNLOCKS SOON" chip · "Classes unlock soon" 26 · one sentence · 5 class tiles (Warden Tank, Tidecaller Healer, Forgeborn Bruiser, Frostblade Melee, Voidcaster Ranged; class palette from Classes.luau, dimmed, lock glyph) · **STARTER KIT · ACTIVE**: Light attack, Heavy attack, Dodge with their binds | no "No class" anywhere, no Choose button, no empty skills half |
| 2 | Classes open, none picked | same tiles, active (no locks), tap selects; kit area previews the selected class; primary "Choose ‹Class›" | the one place `SetClass` is offered |
| 3 | **Class picked** | class icon 72 + name 26 + role chip · resource + passive line · **SKILL KIT** 4 skills + ultimate (name, note, cooldown chip; ultimate gold) · **TALENT · PICK ONE** two cards · "Change class" secondary | data from `Classes` (Frostblade shown: Ice Edge 2.5 s, Glacial Dash 6 s, Frost Mirror 10 s, Cold Snap 8 s, Absolute Zero) |
| 4 | Loading viewport | hero silhouette in `muted` @ 0.7 + spinner ring | until `HeroView.place` returns |
| 5 | Empty gear slot | dashed card, slot icon @ 0.5, "Equip a weapon" + small `Open Bag` button | never a blank square |
| 6 | No pet | pet card says "No pet yet" + `Pets`; the viewport shows the hero only | — |
| 7 | Phone, short height (667×375) | showcase left 40%, stats + class card scroll on the right | panel per HUD_ZONE_MAP Z12 |

## 6. Copy
| Key | String |
|---|---|
| Title / sub | "HERO" · "%s · Level %d" |
| Power chip | "POWER" + "%s" (thousands separator) |
| Power note | "Power %s = your gear's rarity floor plus upgrades" |
| Stat labels | Attack: "Damage", "Attack speed" ("%.2f/s"), "Crit chance" ("%d%%"), "Crit damage" ("%d%%"). Defense: "Max HP", "Defense", "Gold find" ("+%d%%") |
| Locked chip / title | "UNLOCKS SOON" · "Classes unlock soon" |
| Locked body | "Each class adds its own skill kit and resource. Until classes open, every hero fights with the Starter Kit below." (phone: "Each class adds a skill kit and a resource. Until then you fight with the Starter Kit.") |
| Locked tap | "Classes unlock in a later update. You're using the Starter Kit." |
| Kit header | "STARTER KIT · ACTIVE" / "SKILL KIT" / "TALENT · PICK ONE" |
| Starter kit | "Light attack" "Click or tap · 3-hit combo" · "Heavy attack" "Hold to charge a big hit" · "Dodge" "Quick roll · 2 charges" (Ghost: match ActionBar's real binds and charges) |
| Buttons | "Choose %s" · "Change class" · "Open Bag" |
| Drag hint | "Drag to turn" (phone "Drag") |
No Robux, no "buy", no premium currency on this screen.

## 7. Visual style
Chrome per `PANEL_STYLE.md`. Showcase backdrop `UIGradient` Rotation 90: `58,50,88` → `34,32,52` (0.55) → `20,24,32`. Floor ring: an `ImageLabel` ellipse (original asset) tinted with `Rarities.COLOR` of the best equipped tier, outer stroke 3 @ 0.15, inner ring 2 @ 0.6. Attack accent `230,120,70`, Defense accent `96,168,232`, gold `255,206,96` for Power and Gold find. Class tiles use each class `palette` (Classes.luau:82, :147, :223, :277, :331) at 0.84 fill / 0.5 stroke, glyphs lifted 35% toward white. Locked = lock glyph + `muted`. Starter kit cards use the `ok` green stroke to read "active".

## 8. Motion / VFX
| Moment | Spec |
|---|---|
| Open | panel 0.26 s; hero rotates from −25° to 0° over 0.4 s, Quad Out |
| Idle | 6°/s Y turn until the first drag; stops for good after one |
| Drag | yaw = drag × 0.4°/px, inertia 0.3 s; pitch clamped ±8° |
| Equip change | ring `ImageColor3` tween 0.2 s + `UIScale` pulse 1 → 1.06 → 1 |
| Locked tile tap | 4 px X shake, 3 × 0.04 s; status strip line |
| Class picked | selected tile gold stroke 0.15 s; kit cards stagger in at 0.05 s |
| Legendary gear equipped | ring rays `ImageLabel` rotate (same asset as the x10 Legendary beat) |
No ParticleEmitters (they don't render inside a ScreenGui/ViewportFrame); no blur.

## 9. Roblox build notes
| Element | Instances |
|---|---|
| Panel | Z12 rect + `PanelChrome` (PANEL_STYLE §9) |
| Showcase | `Frame` (UIGradient, `UICorner` 14, `UIStroke` 1) → ring `ImageLabel`s → `ViewportFrame` (`BackgroundTransparency` 1, `Ambient` `140,140,160`, `LightColor` `255,244,230`, `LightDirection` (−0.6, −1, −0.4)) → `WorldModel` with the `HeroView` clone of the character **plus the equipped pet model**; own `Camera` (FieldOfView 30), framed from the model's `GetBoundingBox()` so the whole body fills ~88% of the height |
| Rotate | `InputBegan/Changed` on the showcase `Frame` (`Active = true`), rotate the model's pivot (`PivotTo`), never the camera; gamepad right stick |
| Gear row | 3 `TextButton` cards (PANEL_STYLE item card) from `EquipSlots` weapon / armor / pet |
| Stats | 2 column `Frame`s, `UIListLayout`; rows = icon `ImageLabel` + label + value `TextLabel`s; values from `HeroBoard.tiles` (only regrouped; no new math) |
| Class gate | client reads `LaunchGate.on("classes")`; **off → state 1 and no `SetClass` call at all** (removes the ungated buttons at MenuHub.luau:3575, :3910, :4012) |
| Kit | `Classes` for state 2/3; Starter Kit rows from ActionBar's light / heavy / dodge names and binds (`Keybinds`) |
| Phone | the body is one `ScrollingFrame` with `AutomaticCanvasSize = Y`; header outside it (sticky) |
| Perf | re-clone only on equip change; clear the `WorldModel` on collapse; viewport at panel size, no extra `ViewportFrame`s |
Prism edits no Ghost-owned file. This is the build brief.

## 10. Mobile checks
| Viewport | Mockup | Check |
|---|---|---|
| 1920×1080 | 01 (locked), 02 (Frostblade) | panel right of `RAIL_SAFE`; currency + Goals tab visible; action bar clear; all text ≥ 14; buttons ≥ 44 |
| 390×844 | 03 frame 1 (top), 2 (locked scrolled), 3 (class scrolled) | 310 px panel right of the 48 px rail; viewport 286×212; tiles 128×44 readable at 14/18; collapse 44×44 |
| 667×375 / 800×400 | not drawn (state 7) | showcase left, details scroll right |
The character in the mockups is a stand-in built from 3D blocks to show framing and scale. In game it's the player's own avatar from `HeroView`. Gear names and numbers are sample data.

## 11. Open questions (answer by number)
1. **@Kevin:** while `classes` is off, show the **locked "Classes unlock soon" state with the Starter Kit** (mockup 01) instead of a class picker that the server refuses? Prism recommends **locked state**.
2. **@Kevin:** show the equipped **pet** next to the hero in the viewport? Prism recommends **yes**. It fills the frame, and pets are a big part of the loadout (taste call).
3. **@Ghost:** gate every Choose / Change class button on `LaunchGate.on("classes")` (MenuHub.luau:3575, :3910, :4012) as part of the Hero rebuild? Prism recommends **yes**. Echo's onboarding class-step skip is the matching server/onboarding half.
4. **@Ghost:** regroup the existing `HeroBoard.tiles` into Attack / Defense with no new stats, and add the one-line Power note? Prism recommends **yes**. "Level" moves to the header, and nothing new is computed.
5. **@Ghost:** tap a gear card → open Bag on that slot's tab in the same panel rect? Prism recommends **yes**.
6. **@Kevin:** Starter Kit labels (Light attack / Heavy attack / Dodge) are OK as the "active" skills while classes are locked? Prism recommends **yes** (they're the real actions).

## Decision log
- Oct 24, 2026: v1 written for DP41P (Prism). Nothing decided yet.
