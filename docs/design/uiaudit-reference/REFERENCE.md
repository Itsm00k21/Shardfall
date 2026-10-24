# UiAudit pass-reference sheet v1 (for Havoc + Ghost's DP42 test) (NOT APPROVED, docs only)

Owner: Prism (design, docs only). Test owner: Ghost (DP42 UiAudit, Studio/dev only). Runner: Havoc (DP41 UI/HUD QA lane). Base: `cursor/live-build-9721` @ **`9c42ce6`** (client/UI files identical to `5501c2f`, where the line refs were read) (no UiAudit code in live yet: no `UiAudit` file, branch or test). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP51P https://app.notion.com/p/403c31ca38838108916bf0353aac7dc4 (item 3). ACK: https://app.notion.com/p/403c31ca388381db9a78e9f3ba6d7204. DP42 spec: https://app.notion.com/p/403c31ca388381dc8592f7b330a6a7a6. Numbers come from `docs/design/ui-overhaul/HUD_ZONE_MAP.md` §4/§9 + v1.1 addendum (`prism/ui-overhaul`, #479). Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Mockups: `mockups/01-reference-1920x1080.svg` (actual-size plate), `02-reference-phones.svg` (390×844, 844×390, 667×375, 800×400), `03-pass-fail-cases.svg` (one PASS and one FAIL per rule, with log lines).

## 1. Goal
Havoc can look at one sheet and know, for every DP42 rule, what PASS and FAIL look like, which numbers the test should use, and which FAIL lines the **current** live build should print (so we know the test catches Kevin's seed bugs). Ghost gets one constants table to paste, so UiAudit and the HUD use the same numbers.

## 2. Where it lives
- DP42 checks (from Ghost's row): (R1) two visible top-level panels/popups whose rects intersect, outside an allowed-pairs list; (R2) anything covering the left-rail safe area; (R3) `TextSize` < 14 or `TextScaled` text that resolves < 14; (R4) `TextFits == false`. Runs at 1920×1080 and a phone size (390×844; 844×390 if cheap). Output `[UiAudit] PASS` or `[UiAudit] FAIL <size> <panel> <rule> <GuiObject path> <detail>`.
- This sheet adds two **optional** rules Prism suggests (Q2, Q3): (R5) `MIN_TOUCH` 44 for `Active` buttons, (R6) every main panel's rect equals Z12 (±2 px).
- Panels in DP42's loop: Hero, Bag, Inventory, Roll (x1 and x10 results), Pets, Shop, Settings, Defeated, results card.

## 3. Flow (how Havoc uses it)
1. In Studio, set the device emulator to each size in §4 (Fit to window off, scale 100%).
2. Run UiAudit from the command bar. It opens each panel, waits for tweens to settle (≥ 0.4 s after open: `UiTheme.MOTION.open` 0.26 + fade 0.12), checks, collapses, and confirms the panel really closed.
3. Compare the printed lines with §5 (rules) and §6 (expected on `5501c2f`). A FAIL that matches §6 is a known seed bug (good: the test works). A FAIL not in §6 is new. File it with the size, panel, path and a screenshot next to plate 01/02.
4. After the overhaul lands (Z12 panels, `RAIL_SAFE`, 14 px floor), the target is `[UiAudit] PASS` at every size.

## 4. Layout: constants (safe-area px, `IgnoreGuiInset = false` frame)
| Constant | 1920×1080 | 390×844 (portrait) | 844×390 (landscape) | 667×375 | 800×400 |
|---|---|---|---|---|---|
| `RAIL_SAFE` rect | **x 0-96, y 320-760** | **x 0-72, y 250-594** | **x 0-68, y 72-382** | x 0-68, y 72-367 | x 0-68, y 72-392 |
| `RAIL_SAFE` UDim2 | (0,0, 0.5,-220) / (0,96, 0,440) | (0,0, 0.5,-172) / (0,72, 0,344) | (0,0, 0,72) / (0,68, 1,-80) (landscape rule: `vy < 500`) | same | same |
| Rail buttons | 6 × 64, gap 8, x 16-80, y 328-752 | 6 × 48, gap 8, x 16-64, y 258-586 | 6 × 44, x 16-60, from y 80 | 6 × 44, gap 3 | 6 × 44, gap 8 |
| Z12 panel rect | x 112-1552, y 104-920 (1440×816) | x 72-382, y 136-836 (310×700) | x 76-828, y 16-374 | x 76-651, y 16-359 | x 76-784, y 16-384 |
| Z12 formula | (0,112, 0,104) / (0, min(1440, vx−464), 0, min(816, vy−264)) | (0,72, 0,136) / (1,-80, 1,-144) | (0,76, 0,16) / (1,-92, 1,-32) when `vy < 500` | ← | ← |
| Keep-out (HUD only) | x 576-1344, y 302-788 | x 117-273, y 296-616 | — (landscape compromise, HUD_ZONE_MAP Q6) | — | — |
| `MIN_TEXT_PX` | 14 | 14 | 14 | 14 | 14 |
| `MIN_TOUCH_PX` | 44 | 44 | 44 | 44 | 44 |
| `TOAST_MAX` | 3 | 2 | 2 | 2 | 2 |
| Rect tolerance | 2 px | 2 px | 2 px | 2 px | 2 px |
1280×720 desktop uses the same formulas (Z12 = x 112-928, y 104-560; `RAIL_SAFE` = x 0-96, y 140-580).
**Paste-ready table (Ghost):**
```
UiAuditConstants = {
  MIN_TEXT_PX = 14, MIN_TOUCH_PX = 44, RECT_TOLERANCE = 2, SETTLE_SECONDS = 0.4,
  RAIL_SAFE = { pc = {0,0, 0.5,-220, 0,96, 0,440}, phonePortrait = {0,0, 0.5,-172, 0,72, 0,344}, phoneLandscape = {0,0, 0,72, 0,68, 1,-80} },
  Z12 = { pc = "x112 y104 w=min(1440,vx-464) h=min(816,vy-264)", phonePortrait = {0,72, 0,136, 1,-80, 1,-144}, phoneLandscape = {0,76, 0,16, 1,-92, 1,-32} },
  TOAST_MAX = { pc = 3, phone = 2 },
}
```
(Docs only; Ghost owns where it lives, e.g. next to `HudLayout.zone`.)

## 5. States: the rules, PASS vs FAIL (sheet 03)
| Rule | PASS | FAIL | Measure |
|---|---|---|---|
| R1 Overlap | one top-level panel visible; its errors go to its status strip | any two visible top-level `GuiObject`s (direct children of a `ScreenGui`, plus `Dropdown`/popover roots) intersect by > 2 px and the pair isn't in the allowed list | `AbsolutePosition`/`AbsoluteSize`, after normalizing every ScreenGui to one frame (see §9) |
| R2 Rail safe area | nothing but the rail, its tips, confirm dialog + backdrop, LoadingHud intersects `RAIL_SAFE` | any other visible element intersects `RAIL_SAFE` by > 2 px | same rects vs the table in §4 |
| R3 Text size | every visible `TextLabel`/`TextButton`/`TextBox` ≥ 14 after `UIScale` (HudShell `ShellScale`) | `TextSize × scale < 14`, or `TextScaled` with no `UITextSizeConstraint.MinTextSize ≥ 14` | walk descendants; multiply by every ancestor `UIScale.Scale` |
| R4 TextFits | `TextFits == true`, or the text is `TextTruncate.AtEnd` **and** the full text shows elsewhere (detail pane, tooltip) | `TextFits == false` on a label whose full text appears nowhere else | `TextFits` property after one frame |
| R5 Touch (proposed) | every `Active` `GuiButton` ≥ 44×44 (hit area may be padded by an invisible parent button) | smaller than 44 on either side | `AbsoluteSize` |
| R6 Panel rect (proposed) | main panel rect = Z12 for the size ±2 px | anything else (e.g. 860×640 hub vs 1180×680 inventory) | compare to §4 |
**Allowed overlap pairs** (copy of HUD_ZONE_MAP §9): rail `Tip` tooltips × anything; confirm dialog + backdrop × everything incl. `RAIL_SAFE`; LoadingHud × everything; dropdowns/popovers × their own parent panel; Z12 × Z1/Z3 on landscape phones only (they must report hidden); Dev Tools sheet × Z12 slot (owner, Studio). Everything else fails, including Z6 × Z12, Z8 × Z12, Z11 × Z9/Z10, Z4 × Z6/Z8 on phones.
**Hidden means hidden:** `Visible = false` on the element or an ancestor, or the `ScreenGui.Enabled = false`. A frame at `BackgroundTransparency = 1` with visible text still counts as visible (Q4).

## 6. Copy: expected FAIL lines on live `5501c2f` (verify in Studio)
These are what the math and code say today. They match Kevin's seed list (DP41), so the test should print them.
| Size | Panel | Rule | Expected line (path shortened) | Evidence | Seed |
|---|---|---|---|---|---|
| 1920×1080 | Bag/Inventory | R1 | `FAIL 1920x1080 Inventory overlap ShardfallBanner ∩ Inventory/Modal` after Equip Best with nothing better | InventoryHud.luau:1891 → Ui.luau:1793-1801 (banner, DisplayOrder 100) | 7 |
| 1920×1080 | Bag vs Inventory | R6 | Bag 860×640 (`HudLayout.hub`), Inventory up to 1180×680 from y 132: neither = Z12 | HudLayout.luau:222; InventoryLayout.luau:27-35 | 3 |
| 1920×1080 | Inventory | R3 | `TextSize 13` ×5 (InventoryHud.luau:173, :343, :958, :997, :1032), `12` (:1018), `11` (:1078) | | 8 |
| 1920×1080 | HUD (any panel) | R3 | rail key hint `TextSize 11` (HudShell.luau:370), build stamp `12` (:571) | | 8 |
| 1920×1080 | Roll x10 | R1 / R6 | `RollSummary/Root` x 672-1248, y 372-708: not Z12; intersects the hub panel if the test treats it as top-level | RollSummary.luau:266-296; MenuHub.luau:2004 | 6 |
| 390×844 | Roll x10 | R2 | `RollSummary/Root` x 9-380, y 259-585 ∩ `RAIL_SAFE` | same math at 390 (5 cols × 63 px) | 6 |
| 390×844 | Roll x10 | R3 | tile name `TextSize 11`, line `11`, badge `10` | RollSummaryHud.luau:168, :175, :183 | 6, 8 |
| 390×844 | Roll x10 | R5 | `SkipBatch 72x30 < 44` | MenuHub.luau:1991-1992 | — |
| 390×844 | Inventory | R2 | `Inventory/Modal` x 8-382 (full screen, 8 px margin) ∩ `RAIL_SAFE` | InventoryLayout.luau:35, :59-62 | 3 |
| 390×844 | Defeated | R2 | `CombatHud/Result` x −22-318 (anchor 0.5 at scale 0.38, 340 wide) ∩ `RAIL_SAFE` | CombatHud.luau:474-476 | 4 |
| any | loot toasts | R3 | combat loot label `MinTextSize 9` (`UITextSizeConstraint`) | CombatHud.luau:622, :632-633 | 5, 8 |
Not expected from the math: the tutorial over the rail (seed 4, tutorial half). If it shows, it's the first-frame default rect or the two inset modes (HUD_ZONE_MAP §2 R2). Ghost's `f63da3f` (live) moved the onboarding and goals cards off the rail, so a PASS there now is expected.

## 7. Visual style (how to read the plates)
Red hatch = `RAIL_SAFE`. Green outline = Z12 panel rect. Orange dashed = keep-out (a HUD rule, not a DP42 rule). Blue solid = zones that stay visible with a panel open (Z1, Z3, Z4 tab, Z10 on desktop). Grey dashed = zones that must be hidden while a panel is open (Z4 body, Z6, Z8, Z9, Z11). Grid lines every 100 px on plate 01 (actual size, so a Studio screenshot at 1920×1080 can be overlaid at 50% opacity).

## 8. Motion
Measure only after tweens settle (`SETTLE_SECONDS` 0.4). The panel open tween starts at the rail button's rect, so a check during the tween reports false R2 hits. During the x10 batch, check once mid-batch (Skip visible) and once on the results.

## 9. Roblox build notes (for Ghost's test, no code here)
- **One frame for every rect:** HudShell/rail/banner use `CoreUISafeInsets`, `MobileShell.mount` screens use `DeviceSafeInsets` (HUD_ZONE_MAP §2 R2). Before comparing, convert each `AbsolutePosition` to one frame, e.g. add the `ScreenGui`'s inset offset (`GuiService:GetGuiInset()` when `IgnoreGuiInset = false`, and the device-vs-core inset difference). Until R2 is fixed, log which inset mode each FAIL's ScreenGui uses, so Havoc can tell a real overlap from an inset mismatch.
- **Top-level =** direct children of an enabled `ScreenGui` that are visible, plus `Dropdown` / `AutoPopover` roots. Children of the same panel never fail R1 against their own panel.
- **R3 scale:** multiply `TextSize` by every ancestor `UIScale.Scale` (HudShell `ShellScale`, HudShell.luau:66-68) and by the text-size setting floor (`uiSettings.access.textScale`, floor 14).
- **R4:** read `TextFits` one frame after layout (`task.wait()`), with `TextWrapped` labels at their real size.
- Studio/dev only (`RunService:IsStudio()` + owner check), flags off, no save writes (DP42 rules).

## 10. Mobile checks (sizes to run)
| Size | Why | Plate |
|---|---|---|
| 1920×1080 | desktop target (DP42) | 01 |
| 390×844 | phone portrait target (DP42), rail 48 | 02 |
| 844×390 | phone landscape (DP42 "if cheap"); landscape rule `vy < 500` | 02 |
| 667×375 | smallest landscape (iPhone SE), rail gap 3 | 02 |
| 800×400 | small Android landscape | 02 |
| 1280×720 | small desktop window; formulas only | — |

## 11. Open questions (answer by number)
1. **@Ghost:** rect tolerance 2 px for R1/R2/R6? Prism recommends **2 px**. 1 px gives false hits from `UIStroke` and rounding.
2. **@Ghost:** add R5 (touch ≥ 44 for `Active` buttons)? Prism recommends **yes**. The live x10 Skip (72×30) would be caught.
3. **@Ghost:** add R6 (main panel rect = Z12 ±2 px)? Prism recommends **yes, once the zone module lands**. Until then, warn instead of fail.
4. **@Ghost / @Havoc:** treat a transparent frame (`BackgroundTransparency = 1`) with visible text or images as visible for R1/R2? Prism recommends **yes**. Players see the text.
5. **@Havoc:** run 844×390 as the landscape size and add 667×375 when it's cheap? Prism recommends **yes**. 667×375 is where the rail gap drops to 3.

## Decision log
- Oct 24, 2026: v1 written for DP51P item 3 (Prism). Nothing decided yet.
