# Shared Panel Style v1: Bag / Inventory / Roll (x1, x10) / Hero (NOT APPROVED, docs only)

Owner: Prism (design, docs only). Builder: Ghost. Base: `cursor/live-build-9721` @ **`8cb42ff`** (audit file:line refs are from `a28a5e2`; no client or shared UI file changed between the two). Date: Oct 24, 2026 (PT).
Asked for in: DP41P https://app.notion.com/p/403c31ca388381999e16eb0137b3af5a (deliverable 3). ACK: https://app.notion.com/p/403c31ca388381ec9523ef97de82e8c3. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Inputs: `UiTheme.luau` (tokens), `Rarities.luau` (Q-004 ladder), `docs/design/UI_STYLE.md` + `mockups/mock_bag.jpg`, `mock_roll.jpg`, `mock_pets.jpg` and `refs/` (structure, not pixels). Zones come from `HUD_ZONE_MAP.md` (Z12 panel, Z6 toasts). Sheet: `mockups/10-panel-style-sheet.svg`.

## 1. Goal
Every panel looks like the same game: one size per viewport (so switching Bag ↔ Inventory ↔ Roll ↔ Hero never jumps), one tab style, one button set with the same five states, readable text (≥ 14 px, ≥ 4.5:1), rarity badges that never squish, an x10 result that celebrates, and toasts that look designed rather than like debug lines.

## 2. Where it lives + live audit (`a28a5e2`)
| Seed | Live evidence | Rule here |
|---|---|---|
| 3 Bag vs Inventory size jump | MenuHub hub `HudLayout.hub` 860×640 max (HudLayout.luau:222-249, MenuHub.luau:1050) vs InventoryHud `InventoryLayout.modal` up to 1180×680 at 1920×1080 and full screen x 8-382 on phones (InventoryLayout.luau:59-75, InventoryHud.luau:265). Two tab looks: InventoryHud chips corner 6, 13 px (InventoryHud.luau:170-180) vs MenuHub pills `CornerRadius (1,0)` (MenuHub.luau:1370). Two inventories exist only because `oneInventory` is off (init.client.luau:1347, :1405) | §4 one panel rect; §5 one tab |
| 6 Cramped x10 | `UIGridLayout` cells 128×44 (RollReel.luau:446), each a bare `TextLabel` at 13 px in the rarity color, no icon, no badge, no beat (RollReel.luau:1021-1035) | §5 x10 grid |
| 7 Raw red error over tabs | `InventoryHud.luau:1891` → `onStatus` → full-width banner (Ui.luau:1793-1801, red fill on `error` Ui.luau:333-336) drawn at DisplayOrder 100 over the panel | §5 status strip |
| 8 Small / low-contrast text | sub-14 px in panels: InventoryHud.luau:173, :343, :958, :997, :1018 (12), :1032, :1078 (11); RollReel.luau:1028; loot names 13 → 9 px with `UITextSizeConstraint` (CombatHud.luau:622, :632-633). Epic `186,120,232` on a card fill `44,50,64` is only 4.2:1 | §6 type + contrast |
| 5 Debug-looking loot | plain `TextLabel` toast, no icon, "Loot: Verdant Wood x1" (HudShell.luau:457-472, CombatFeel.luau:461) | §5 toasts |

## 3. Flow
Open: tap a rail button (or its key) → the panel grows out of that button into Z12 (0.26 s). Switch: tap another rail button → the open panel collapses 0.15 s and the new one opens **in the same rect**. Collapse: the header chevron, the same rail button, Esc / B. There's no separate close (Kevin: collapse, not close). Errors and results inside a panel go to its status strip, never to a banner over it.

## 4. Layout
**Panel rect = HUD zone Z12** (same for Hero, Bag/Inventory, Roll, Pets, Shop, Settings):
| Viewport | Rect | Padding | Header | Corner |
|---|---|---|---|---|
| 1920×1080 | x 112-1552, y 104-920 (1440×816) | 20 | 64 | 16 |
| 1280×720 | x 112-928, y 104-560 (816×456 by the formula; body scrolls) | 16 | 56 | 16 |
| 390×844 | x 72-382, y 136-836 (310×700) | 12 | 56 | 14 |
| 667×375 / 800×400 | x 76-651, y 16-359 / x 76-784, y 16-384 | 12 | 52 | 14 |
Formula: Position `(0,112, 0,104)`, Size `(0, min(1440, vx−464), 0, min(816, vy−264))` on pc; phone `(0,72, 0,136)` / `(1,-80, 1,-144)`. `UISizeConstraint` MinSize 300×320.
**Anatomy** (top to bottom): header (icon tile 44, title, sub-line, right-hand stat chip, collapse 44×44) · tab row 44 (only if the panel has sub-tabs) · body (`ScrollingFrame`, `UIPadding` 16 / 12) · status strip 44 (hidden when empty). **No in-panel icon column:** the rail already is the panel switcher (the active rail button gets the gold stroke + accent bar), so `HudLayout.tabColumn` (HudLayout.luau:255-264, 96-132 px) goes away and the body gets that width back (Q1).
**Bag/Inventory (merged)**: tabs All · Weapons · Armor · Pets · Relics; grid of item cards (§5) on the left; detail pane on the right on desktop (360 wide: worn viewport, item lines, EQUIP, UPGRADE gold), a bottom sheet on phones; slots 1-8 under the grid (UI_STYLE.md "Bag"). **Roll**: tabs Gear Shards · Pet Shards; pedestal left, odds/pity right, crack row bottom (UI_STYLE.md "Roll"); x1/x10 results replace the pedestal area inside the same panel. **Hero**: `HERO_SCREEN.md`.

## 5. States + components
**Buttons** (sheet §2). Height 48 desktop / 44 phone, min width 88, white text clears 4.5:1 on every gradient stop, `UICorner` 10, text 16 Builder Sans Bold (18 for the single primary action per panel), padding 16.
| Kind | Fill (UIGradient top → bottom, Rotation 90) | Stroke | Text | Use |
|---|---|---|---|---|
| Primary | `116,86,204` → `96,68,180` (base `button 108,78,196`) | 1.5 gold @ 0.45 | `244,240,252` (≥ 4.7:1) | main action |
| Secondary | `52,58,72` → `40,46,58` (`header`) | 1 `divider` | text | Change class, Info, Auto |
| Equip | `52,104,192` → `32,76,156` (`equip`) | 1.5 `150,200,255` @ 0.4 | text (≥ 4.8:1) | EQUIP |
| Crack / claim | `34,122,78` → `24,98,62` (`claim`) | 1.5 `ok` @ 0.3 | text (≥ 4.7:1) | CRACK x10 |
| Gold | `255,220,130` → `240,186,70` (`gold`) | 1.5 ink @ 0.4 | `ink 24,18,12` (12.6:1) | UPGRADE (costs gold, never Robux) |
| Danger | `188,58,68` → `160,40,50` (`close`) | 1.5 `255,160,160` @ 0.5 | text (≥ 4.9:1) | Salvage confirm |
| State | Look | Behaviour |
|---|---|---|
| Idle | as above | — |
| Hover (desktop) | +8% brightness (`hover 64,56,92` for secondary) | 0.08 s |
| Press | `UIScale` 0.96, fill −15% (`press 36,30,54` for secondary) | 0.08 s down, 0.12 s up |
| Disabled | fill `buttonDim 54,46,78`, stroke `divider` @ 0.65, text **`166,160,186`** (5.0:1 on buttonDim; today's `muted` on `button` is 3.4:1) | no tween; tap puts the reason in the status strip |
| New | gold `UIStroke` 2 + `newDot 230,64,78` 14 px dot top-right | dot clears on first open (same rule as the hotbar `newDot`) |
| Locked | fill `40,40,52`, dashed-look stroke (`UIStroke` 1 `muted` @ 0.4), lock glyph 16 + the condition ("Lv 10", "Unlocks soon") | never a blank or silent button |
**Tabs** (one style for every panel): pill, height 44, `UICorner` (1,0), padding 16, Builder Sans Bold 16, `AutomaticSize X`, gap 8, in a horizontal `ScrollingFrame` when they overflow (390 px). Idle `header` fill + `divider` stroke + `muted` text; selected `button` fill + gold stroke 2 + white text; new = white text + 12 px `newDot`; locked = `32,32,42` + lock glyph + `166,160,186`.
**Item card** (Bag, Roll results, Hero gear): `UICorner` 12, `UIStroke` 2 `Rarities.COLOR[r]` @ 0.2, fill `UIGradient` `Rarities.COLOR[r]` @ 0.84 transparency → `26,30,40` at 0.65. Icon tile 56-64 with the rarity gradient. Name 16 bold in `UiTheme.RARITY[r]` (Epic lifted to `206,150,240` on cards, 5.6:1). Then the badge, then the action.
**Rarity badge**: pill, height 24 (22 phone), padding 10, Builder Sans Bold 14 caps, letter spacing +4%, `AutomaticSize X` and never `TextScaled`. Fill `Rarities.COLOR` @ 0.8 transparency, stroke 1.5 `Rarities.COLOR`, text `UiTheme.RARITY` (Epic lifted). Widths at 14 px: COMMON ≈ 78, UNCOMMON ≈ 104, RARE ≈ 58, EPIC ≈ 52, LEGENDARY ≈ 112. The badge row must fit 112 + 20, so card text areas are ≥ 132 px.
**Roll x10 grid**: desktop 5 × 2, cell 160×166, gap 10; phone 2 columns × 5 rows, cell 135×150, gap 8, `ScrollingFrame` with the best pull pinned first. Cell = icon 64 (phone 52), badge, name 16 bold up to 2 lines (`TextWrapped`, no `TextScaled`). Reveal: cells pop in at a 0.06 s stagger, best pull last. **Epic**: 3 px stroke + a `UIGradient` sweep (Transparency band, `Offset` tween −1 → 1, 0.6 s, once). **Legendary**: Epic + a rotating ray `ImageLabel` behind the icon (Rotation tween 0 → 360, 6 s, loop while visible), `UIScale` 1 → 1.08 → 1.04, one gold flash `Frame` over the grid (transparency 0.6 → 1 in 0.3 s) and the existing big-roll sound. x1 uses the same cell at 2× inside the pedestal area. No Robux, no "buy more" prompt.
**Toasts (Z6)**: card 480×40 desktop / 242×40 phone, `UICorner` 10, fill `20,24,32` @ 0.06, `UIStroke` 1.5 (kind color or `divider` for loot), a 5 px left accent bar, icon 24 (`UiIcons` / item icon), text Builder Sans Bold 16 (14 phone), counter right. Kinds: **loot** (name in rarity color, "×N"; same item within 1.5 s merges), **loot rare+** (Rare and up: rarity stroke + "NEW" in gold if first time), **success** (`ok`), **error** (`loss` accent + warn glyph, white text, 4 s), **room banner** (gold accent, door glyph, "ROOT HALL · ROOM 2/5"). Max 3 (2 on phones), newest on top, oldest drops (`ToastQueue.MAX` = 3, ToastQueue.luau:14). Life 3.5 s (`ShellLayout.BANNER_SECONDS`, ShellLayout.luau:31).
**Status strip** (inside every panel): 44 tall, `UICorner` 10, fill `20,24,32`, `UIStroke` 1 in the kind color, glyph 20 + one line 16 (14 phone). It replaces the banner for anything said while a panel is open.
**Empty states**: icon + one sentence + the action that fixes it, e.g. Bag empty: "Your bag is empty." + `CRACK a shard` (opens Roll). Never a lone muted line.

## 6. Copy + type
| Role | Desktop | Phone | Font |
|---|---|---|---|
| Panel title | 26 | 20 | Builder Sans Bold, caps |
| Section header | 18 | 14-16 | Bold, caps, +6% tracking |
| Body / labels | 16 | 14 | Builder Sans (600) |
| Minimum | **14** | **14** | — |
| Numbers | 22-26 | 18-20 | Bold |
**Contrast (WCAG, computed with `UiTheme.contrast` math):** `text` on body/panel/header/card 15.8 / 13.8 / 11.8 / 11.4; `muted` 10.1 / 8.8 / 7.5 / 7.3; `gold` 12.1 / 10.5 / 9.0 / 8.7; rarity text on `panel`: Common 9.0, Uncommon 7.1, Rare 6.1, **Epic 5.1** (4.2 on cards, so lift it to `206,150,240`: 5.6), Legendary 9.8. Don't use `muted` on `button` (3.4) or `loss` as text on `panel` (4.2). Use them as stroke/accent only.

## 7. Visual style (Roblox values)
| Piece | UICorner | UIStroke | UIGradient |
|---|---|---|---|
| Panel | 16 (14 phone) | 2, `accent 255,206,96`, Transparency 0.4 | Rotation 90: `36,40,52` → `26,30,40` |
| Header bar | 14 top (clip with a child Frame) | bottom divider `Frame` 1 px `divider` @ 0.55 | Rotation 90: `50,56,70` → `40,46,58` |
| Card | 12 | 1 `divider` @ 0.55 (rarity cards 2 rarity) | flat `26,30,40` or the rarity fade |
| Button | 10 | per kind | per kind (above) |
| Pill / chip / badge | (1,0) | 1-1.5 | flat |
| Icon tile | 10 | 2 rarity / class color | Rotation 160: color @ 0.45 → color @ 0.88 |
Shadows: none (no blur). Depth comes from the stroke and the gradient only.

## 8. Motion
Panel open: from the rail button rect to Z12, `Size` + `Position` 0.26 s Quart Out, content fades 0.12 s after. Collapse: 0.15 s back into the button. Tab switch: underline/fill tween 0.12 s, body crossfade 0.1 s. Button press 0.08 s. Toast in 0.15 s (8 px slide + fade), out 0.2 s. x10 timings in §5. All `TweenService` + `UiTheme.MOTION` (UiTheme.luau:33-38). Respect the existing text-size setting (`uiSettings.access.textScale`), with a floor of 14.

## 9. Roblox build notes
- One `PanelChrome` builder (Ghost-owned, new file) makes header / tabs / body / status strip for every panel. MenuHub tabs and InventoryHud chips both move onto it.
- Panel `Frame` + `UICorner` + `UIStroke` (`ApplyStrokeMode.Border`) + `UIGradient`; body `ScrollingFrame` (`AutomaticCanvasSize = Y`, `ScrollBarThickness` 4, `ScrollBarImageColor3` `muted`).
- Tabs: `TextButton` + `UICorner (1,0)` + `UIStroke` + `UIPadding` 16 + `AutomaticSize.X`, in a `ScrollingFrame` with a horizontal `UIListLayout` (Padding 8). This reuses `HudLayout.filterBar` (HudLayout.luau:502-510) as is.
- Badges: `TextLabel` `AutomaticSize.X`, `TextSize 14`, `TextScaled = false`, + `UICorner (1,0)` + `UIStroke` + `UIPadding` 10.
- x10: `UIGridLayout` CellSize from §5 (replace 128×44 at RollReel.luau:446); the sweep is a child `Frame` with a `UIGradient` Transparency `NumberSequence` (1, 0.6 at 0.5, 1) tweened on `Offset`; rays = one `ImageLabel` (original 8-ray star asset, Phase S art).
- Toast = `Frame` (not a bare `TextLabel`) + accent `Frame` + `ImageLabel` icon + `TextLabel`; the queue stays `ToastQueue`.
- Never `TextScaled` without `UITextSizeConstraint.MinTextSize = 14`.
- Prism edits no Ghost-owned file (GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud, RollReveal). This is the build brief.

## 10. Mobile checks
| Viewport | Check |
|---|---|
| 390×844 | panel 310×700 right of `RAIL_SAFE`; tabs scroll; buttons 44; x10 2 columns with names on 2 lines at 16 px; toasts 242 wide at 14 px |
| 667×375 / 800×400 | panel covers Z1/Z3 (they hide); header 52; detail pane becomes a bottom sheet |
| 1920×1080 | panel 1440×816, Bag detail pane 360, x10 5×2 |
| Desktop 1280×720 | panel by formula; body scrolls |
Sheet: `10-panel-style-sheet.svg` (anatomy, 6 button kinds × 5 states, tabs, 5 rarity cards, 5 toast kinds, x10 with Epic + Legendary beats, type).

## 11. Open questions (answer by number)
1. **@Ghost:** drop the in-panel icon tab column (`HudLayout.tabColumn`) and let the rail be the panel switcher? Prism recommends **yes**. It's 96-132 px of width back and one fewer tab style.
2. **@Ghost:** turn `oneInventory` on with this style, so Bag and Inventory become one panel? Prism recommends **yes, with this PR's style**. Two inventories is seed 3.
3. **@Kevin:** primary buttons purple (`button 108,78,196`) with blue EQUIP, green CRACK and gold UPGRADE, as in UI_STYLE.md? Prism recommends **yes** (taste call).
4. **@Kevin:** Legendary x10 beat = rays + gold flash + scale pop (no screen shake)? Prism recommends **yes** (taste call).
5. **@Ghost:** lift Epic text to `206,150,240` on cards/headers (keep `UiTheme.RARITY.Epic` for strokes)? Prism recommends **yes**. 4.2 → 5.6:1.

## Decision log
- Oct 24, 2026: v1 written for DP41P (Prism). Nothing decided yet.
