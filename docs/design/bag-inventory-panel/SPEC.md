# Bag / Inventory merged panel v1: one inventory on PANEL_STYLE (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (`InventoryHud`, `MenuHub`, `GearBar` are Ghost-owned; Prism edits none of them). Base: `cursor/live-build-9721` @ **`9c42ce6`** (client/UI files identical to `5501c2f`, where the line refs were read) (no change to InventoryHud, InventoryLayout, GearBar or GearDetail since `a28a5e2`). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP51P https://app.notion.com/p/403c31ca38838108916bf0353aac7dc4 (item 1, overhaul step 4). ACK: https://app.notion.com/p/403c31ca388381db9a78e9f3ba6d7204. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on: `docs/design/ui-overhaul/PANEL_STYLE.md` (§4 Z12 rect, §5 tabs/buttons/item card/badge/status strip) and `HUD_ZONE_MAP.md` (Z12, `RAIL_SAFE`) on `prism/ui-overhaul` (#479). Mockups: `mockups/01`–`03`.

## 1. Goal
One inventory with one look. The Bag rail button, the B key and the I key all open the **same** panel in the **same** Z12 rect as Hero and Roll, so nothing jumps when you switch. You see what you own at a glance, what's better than what you wear (green/red deltas), and you can equip in one tap. Errors land in the panel's status strip, never in a red banner over the tabs.

## 2. Where it lives + live audit (`5501c2f`)
| What players get today | Evidence | Change here |
|---|---|---|
| Two inventories. The small Bag (MenuHub hub page) and the full Inventory (InventoryHud) both exist, because `oneInventory = false` | LaunchGate.luau:50; MenuHub.luau:4311 ("Open full bag"), :7723-7729; init.client.luau:1357, :1410-1415 | One panel. Turn `oneInventory` on together with this style (PANEL_STYLE Q2) |
| Two sizes. Hub 860×640 max vs Inventory up to 1180×680 from y 132 on desktop, and full screen (8 px margin) on phones, which covers the rail | HudLayout.luau:222 `hub`; InventoryLayout.luau:27-35 (`MAX_W 1180`, `MAX_H 680`, `TOP 132`, `PHONE_MARGIN 8`), :59-75; InventoryHud.luau:265 | Z12 rect only: 1440×816 at x 112 y 104 (desktop), 310×700 at x 72 y 136 (390×844) |
| Two tab looks: chips corner 6 at 13 px vs MenuHub pills | InventoryHud.luau:170-180; MenuHub pills | PANEL_STYLE pill tabs, 44 tall, 16 px |
| Sub-14 text in the grid and detail | InventoryHud.luau:173, :343, :958, :997, :1032 (13), :1018 (12), :1078 (11, the "Locked · Fav" marks) | 14 minimum; marks become icons (lock glyph, gold NEW dot, green ON chip) |
| "Your best gear is already equipped." goes through `onStatus` to the full-width banner over the panel | InventoryHud.luau:1891 → Ui.luau:1793-1801 | Panel status strip (44 tall, bottom of the panel) |
Kept as-is (they're good): `InventoryView.TABS` (7 tabs, InventoryView.luau:62) and `SORTS` power/rarity/newest/name (:64); Equip Best in the header; the detail pane that is never empty (InventoryHud.luau:914); `GearDetail` actions EQUIP / UPGRADE <gold cost> / lock (GearDetail.luau:17, :28, :465-484); `GearBar` Auto-salvage pill + Select + salvage bar (GearBar.luau:1-30), **only while `gearSalvage` is on** (LaunchGate.luau:49, off today).

## 3. Flow
1. Tap **Bag** on the rail (or B / I) → the panel grows out of the rail button into Z12 (0.26 s). It opens on the last tab you used (first time: Weapons), sorted by Power, with the **worn weapon** selected in the detail pane, or the newest NEW item if there is one.
2. Tap a card → desktop: the detail pane on the right updates. Phone portrait: a **bottom sheet** rises inside the panel (the grid dims behind it). Landscape: a **side sheet** slides in from the right edge of the panel.
3. **EQUIP** → the card gets the green ON chip, the old item loses it, the status strip says "Equipped Sunfang Greatsword. Power 2,102 → 2,158." **UPGRADE · 1,200** spends gold (never Robux); short on gold = disabled with the gap in the strip ("Need 340 more gold.").
4. **Equip Best** in the header does the whole kit; if nothing changes, the strip says "Your best gear is already on." (info style, not red).
5. Collapse: the header chevron, the Bag rail button again, Esc / B. The sheet (phone) collapses first with its own chevron, then the panel.
6. Tabs with nothing in them show an empty state with the fix (Pets → "Open Roll · Pet Shards", which switches the panel to Roll in the same rect).

## 4. Layout
**Desktop 1920×1080 (mockup 01), Z12 x 112-1552, y 104-920 (1440×816), padding 20:**
| Piece | Rect inside the panel | Notes |
|---|---|---|
| Header | 0-1440 × 0-64 | icon tile 44, "BAG" 26, "34 / 60 slots" 16 muted; right: POWER chip 184×44, **Equip Best** (secondary) 150×44, collapse 44×44 |
| Tabs | x 20, y 80, h 44 | Weapons · Armor · Accessories · Pets · Materials · Items · Chests (all 7 fit at 1440; NEW dot on a tab with unseen items) |
| Filter row | y 136, h 44 | Search 300 · Rarity 190 · Sort 190 · (gearSalvage on) Auto-salvage pill 200 + Select 92, ends at x 1040 |
| Grid | x 20-1040, y 196-740 | **3 columns**, card 332×104, gap 12; 4 rows visible, the rest scroll (`ScrollingFrame`, bar 4 px) |
| Detail pane | x 1060-1420, y 196-740 (360×544) | icon 96 (Legendary: rays behind), slot line, name 22, badge + NEW, Power box with "+56 vs worn", 3 compare rows, traits, sockets, **EQUIP** 48 full width, UPGRADE (gold) + lock 48×48 + Salvage |
| Status strip | x 20-1420, y 752-796 | hidden when empty |
**Item card (horizontal, desktop + landscape):** `UICorner` 12; `UIStroke` 2 `Rarities.COLOR` @ 0.2 (selected: gold 3 + an outer 2 px gold ring @ 0.55); fill = rarity fade; icon tile 64 (48 landscape) left; name 16 bold in `UiTheme.RARITY` (Epic lifted to `206,150,240`); badge 24; "⚡ 242 Power" 16/14. Right-top marker: **ON** chip (green, worn), **NEW** dot (red with gold ring), lock glyph (locked). Text area ≥ 236 px at 3 columns, so names fit on one line at 16 px.
**Phone portrait 390×844 (mockup 02), Z12 x 72-382, y 136-836 (310×700), padding 12:** header 56 ("BAG" 20, "34 / 60 slots" 14, **Best** 72×44, collapse 44); tabs scroll sideways (fade on the right edge, the selected tab scrolls into view); filter row = Search 44 · "Power · All" 118 (one sheet with Sort + Rarity) · Select 108; grid **2 columns of vertical cards 139×150** (icon 52, name 16 on up to 2 lines, badge 22, power 14 top-left, marker top-right). Item **bottom sheet** y 258-700 inside the panel: grab chevron 44×28, icon 60, name 18, badge, Power box, 3 compare rows at 14, traits at 14, EQUIP 44 full width, UPGRADE 150 + lock 44 + Salvage 76.
**Landscape 667×375 / 800×400 (mockup 03):** Z12 x 76-651 / 76-784, y 16-359 / 16-384 (covers Z1/Z3; they hide). Header 52 holds title + scrolling tabs + Best + collapse; filter row 44; grid **2 columns of horizontal cards** (271 / 338 wide × 72); detail = **side sheet** 300 wide from the right edge with its own collapse chevron.
**Not in the panel:** no in-panel icon column (rail is the switcher, PANEL_STYLE Q1); no action slots 1-8 inside the panel (Z10 stays the action bar; desktop keeps it visible under the panel, phone hides it while a panel is open, HUD_ZONE_MAP §3).

## 5. States
| State | What shows |
|---|---|
| Default | last tab, Power sort, worn item selected (or newest NEW) |
| Item selected | gold stroke 3 + ring; detail pane / sheet filled |
| NEW item | red dot with gold ring on the card, gold NEW tag in detail; clears when the card is opened (same rule as the hotbar `newDot`) |
| Worn | green ON chip; EQUIP becomes disabled "Worn" |
| Locked | lock glyph on the card; Salvage disabled with "Unlock to salvage." in the strip |
| Better than worn | Power box delta green "+56 vs worn"; worse = `255,150,150` "−12 vs worn" (never `loss` as text on panel, 4.2:1) |
| Upgrade short on gold | UPGRADE disabled (buttonDim fill, `166,160,186` text); tap puts "Need 340 more gold." in the strip |
| Upgrade maxed | "UPGRADE · Max", disabled |
| Select mode (gearSalvage on) | checkboxes on cards, salvage bar replaces the status strip: "Salvage 6 for +48 Essence" + Clear; every salvage goes through the existing confirm |
| Empty tab | icon + one sentence + the fixing action (mockup 02, Pets) |
| Bag full (60/60) | slots chip turns gold; strip: "Bag full. Free a slot to keep new drops." (no Robux slot prompt) |
| Error | strip in the error style (red stroke + warn glyph, white text, 4 s) |

## 6. Copy
Header "BAG" + "34 / 60 slots". Tabs exactly as `InventoryView.TABS`, title case. Buttons "Equip Best" (phone "Best"), "EQUIP", "UPGRADE · 1,200" (phone "UPGRADE 1,200"), "Salvage", "Select". Detail: slot line caps ("WEAPON · GREATSWORD"), "VS THORNBOUND BLADE (WORN)", "TRAITS · 2", "2 open sockets". Strip lines: "Equipped Sunfang Greatsword. Power 2,102 → 2,158." · "Your best gear is already on." · "Need 340 more gold." · "Unlock to salvage." · "Bag full. Free a slot to keep new drops." Empty: "No pets yet." / "Pet Shards hatch pets. You have 3." / "Open Roll · Pet Shards".

## 7. Visual style
PANEL_STYLE §5/§7 unchanged: panel gradient `36,40,52 → 26,30,40`, gold stroke 2 @ 0.4, corner 16 (14 phone); header gradient; buttons by kind (EQUIP blue, UPGRADE gold with ink text, Select/Best secondary, Salvage secondary until confirm, then danger). Detail Legendary header: rarity fade + one 12-ray `ImageLabel` behind the icon at 0.3 opacity (static here; it only rotates in the Roll x10 call-out). No blur, no drop shadows.

## 8. Motion
Open 0.26 s Quart Out from the rail button, content fade 0.12 s; collapse 0.15 s. Tab switch: pill fill 0.12 s, grid crossfade 0.1 s. Card select: stroke 0.08 s. Phone bottom sheet: `Position` tween 0.22 s Quart Out up, 0.15 s down; grid dim `Frame` 0 → 0.45. Landscape side sheet: 0.2 s from the right. Equip: ON chip pops `UIScale` 0.9 → 1 (0.12 s); Power chip counts up over 0.4 s. All `TweenService` + `UiTheme.MOTION`.

## 9. Roblox build notes
- Panel via the shared `PanelChrome` builder (PANEL_STYLE §9, Ghost-owned new file): header / tabs / body / status strip. InventoryHud chips move onto the pill tabs (`HudLayout.filterBar` reuse).
- Panel rect = `HudLayout.zone("Z12", vx, vy)` (HUD_ZONE_MAP Q1). Drop `InventoryLayout.modal` for Z12; keep `InventoryLayout.chrome` math for the inner rows if handy.
- Grid: `ScrollingFrame` + `UIGridLayout` CellSize (332,104) desktop / (139,150) phone / ((w−8)/2, 72) landscape, CellPadding 12/8; `AutomaticCanvasSize = Y`.
- Card: `Frame` + `UICorner` 12 + `UIStroke` 2 (rarity) + `UIGradient` (rarity @ 0.84 → `26,30,40` @ 0.65, Rotation 90) + icon `ImageLabel` in an icon tile (`UICorner` 10, `UIStroke` 2, `UIGradient` Rotation 160) + name `TextLabel` 16 (`TextTruncate.AtEnd` on desktop/landscape, `TextWrapped` 2 lines on phone) + badge `TextLabel` `AutomaticSize.X` 14 + markers (ON chip `TextLabel`, NEW `Frame` 14×14 `UICorner` (1,0) + gold `UIStroke`, lock `ImageLabel` 18).
- Detail: reuse `GearDetail` content (stats, traits, sockets, `DetailActions`), restyled; the Legendary rays are one `ImageLabel` (original 12-ray asset, Phase S art).
- Phone bottom sheet / landscape side sheet: a child `Frame` of the panel (not a new ScreenGui), `ClipsDescendants` on the panel, dim `Frame` `BackgroundTransparency` tween. The sheet is part of Z12, so UiAudit sees no extra top-level overlap.
- Status strip replaces `onStatus` → banner while the panel is open (HUD_ZONE_MAP Q5).
- Touch: every `Active` thing ≥ 44 (cards, tabs, buttons, sheet chevron 44×28 hit area padded to 44 with an invisible `TextButton`).
- Prism edits no Ghost-owned file (GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud, RollReveal). This is the build brief.

## 10. Mobile checks
| Viewport | Check | Result |
|---|---|---|
| 1920×1080 | panel = Z12 1440×816; 3×4 cards visible; detail 360; all text ≥ 14; buttons 48 | pass (mockup 01) |
| 1280×720 | panel by formula 816×456: grid drops to 2 columns, detail 300; body scrolls | by formula (no mockup) |
| 390×844 | panel 310×700 right of `RAIL_SAFE` (x 72); tabs scroll; 2-column cards with 2-line names at 16; sheet buttons 44; nothing under 14 | pass (mockup 02) |
| 667×375 | panel x 76-651 clears `RAIL_SAFE` x 0-68; 2 columns × 72; header 52; side sheet 300 | pass, tight: 2.5 rows visible (mockup 03) |
| 800×400 | same with 338-wide cards; side sheet shown | pass (mockup 03) |
Panels collapse (no close X) and never sit in the screen center on their own: Z12 is anchored right of the rail.

## 11. Open questions (answer by number)
1. **@Ghost:** keep all 7 `InventoryView.TABS` as pills (they fit at 1440; phones scroll) instead of PANEL_STYLE §4's shorter "All · Weapons · Armor · Pets · Relics"? Prism recommends **keep the 7 live tabs**. They're real data, and the scroll row handles phones.
2. **@Ghost:** phone filter row = Search · one "Power · All" sheet (Sort + Rarity together) · Select, instead of three dropdowns? Prism recommends **yes**. Three dropdowns don't fit in 286 px at 44 tall.
3. **@Ghost:** landscape detail as a 300 px **side sheet** instead of PANEL_STYLE §10's bottom sheet? Prism recommends **side sheet**. A bottom sheet at 343 px tall hides the whole grid.
4. **@Kevin (taste):** show the static Legendary rays behind the icon in the Bag detail pane, or keep rays only for the Roll x10 call-out? Prism recommends **static rays in Bag, rotating only in Roll**.
5. **@Ghost:** open on the newest NEW item when there is one (otherwise the worn weapon)? Prism recommends **yes**. It shows the new drop without a hunt.

## Decision log
- Oct 24, 2026: v1 written for DP51P item 1 (Prism). Nothing decided yet.
