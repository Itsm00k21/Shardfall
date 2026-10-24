# HUD Zone Map v1.1: one zone per element, one toast lane, a left-rail safe area (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (client HUD, `HudLayout`, UiAudit DP42). Base: `cursor/live-build-9721` @ **`8cb42ff`** (audit file:line refs are from `a28a5e2`; no client or shared UI file changed between the two). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP41P https://app.notion.com/p/403c31ca388381999e16eb0137b3af5a (deliverable 2). ACK: https://app.notion.com/p/403c31ca388381ec9523ef97de82e8c3. Context: Havoc's QA lane DP41 (seed list) https://app.notion.com/p/403c31ca388381438c83e2d2641c44ea, UiAudit DP42 https://app.notion.com/p/403c31ca388381dc8592f7b330a6a7a6. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Siblings in this folder: `PANEL_STYLE.md` (deliverable 3) and `HERO_SCREEN.md` (deliverable 1). Mockups: `mockups/04`–`09`.

## 1. Goal
Every HUD element gets exactly one screen zone at every viewport, so nothing boxes the player in or stacks on anything else. Goals and the tutorial share one slot. Loot, errors and room banners share one toast lane with a cap. The left rail has a safe area nothing may cover. The rects are in scale + offset so Ghost can code them as constants and UiAudit (DP42) can check them.

## 2. Where it lives + live audit (`a28a5e2`)
**Coordinates:** safe-area px inside a `ScreenGui` with `IgnoreGuiInset = false` (the frame `HudLayout` already uses, HudLayout.luau:4-5). Margin 16 = `UiTheme.safeMargin()` (UiTheme.luau:85-87). Live rects below were measured by running the live `HudLayout`, `ShellLayout`, `InventoryLayout`, `BannerFit` and `DevTools.layout` functions in lune at each size (mockups 08, 09).

**Root causes (the reason the seed bugs keep coming back):**
| # | Finding | Evidence (file:line @ a28a5e2) |
|---|---|---|
| R1 | **Two layout modules place HUD.** `HudLayout` (new shell) and the legacy `ShellLayout` both hand out rects, and neither knows about the other's pieces. | `ShellLayout.comboRect`/`cueRect`/`actionBar` in CombatHud.luau:346-354; `menuSheet` MenuHud.luau:70; `skillsRect` ClassHud.luau:138; `menuRect` Ui.luau:379; `doorRect` DoorHud.luau:55; `travelRect` TravelHud.luau:142; `captureRect` CaptureHud.luau:173; `petRect` InventoryHud.luau:264 |
| R2 | **Two inset modes.** HudShell, the rail and the banner use `CoreUISafeInsets`; every screen mounted with `MobileShell.mount` uses `DeviceSafeInsets`. The same `HudLayout` rect can land on different pixels on notched or landscape phones. | HudShell.luau:63 and :270, Ui.luau:268 vs MobileShell.luau:13 (used by OnboardHud.luau:139, InventoryHud.luau:197, CombatHud.luau:202) |
| R3 | **Three message channels for one line.** `ui.setStatus` shows a gold full-width banner, a 13 px status label, and loot lines also go to the HudShell toast. | Ui.luau:1793-1801 (`showBanner`, gold fill Ui.luau:276-284, ink text), status label TextSize 13 Ui.luau:855-859, loot copy to toast init.client.luau:1628-1633 |
| R4 | **DisplayOrder ladder puts the tutorial above everything.** Onboard (95) sits above the hub (80), rail (85) and prompt (90). Only the banner (100) and loading (110) are higher. | OnboardHud.luau:137, MenuHub.luau:122, HudShell.luau:268/481, Ui.luau:269, LoadingHud.luau:105 |
| R5 | **Two panel sizers.** MenuHub Bag/Hero use `HudLayout.hub` (860×640 max), while InventoryHud uses `InventoryLayout.modal` (up to 1180×680, full screen on phones). That's the Bag/Inventory size jump. | HudLayout.luau:222-249 vs InventoryLayout.luau:59-75; InventoryHud.luau:265 |

**Seed list vs live (`a28a5e2`), with the zone fix:**
| Seed | Still on a28a5e2? | Evidence | Fix in this map |
|---|---|---|---|
| 2 Clutter boxes the player in | yes | 1920×1080 has 20 rect pairs that intersect when both are up (mockup 08), e.g. CombatHud combo x 244-404, y 16-40 on the HP block x 80-300 (ShellLayout.luau:123 vs HudLayout.luau:32-54); LoopHud x 1624-1904, y 72-292 on the pills y 52-88 (ShellLayout.luau:135) | one zone each (§4) |
| 4 Tutorial / Defeated over the rail | Defeated: yes on phones. Tutorial: not reproducible from the math | Defeated card is `AnchorPoint 0.5`, scale (0.38, 0.45), 340 wide (CombatHud.luau:474-476), so at 390 wide it spans x −22 to 318 over the rail x 16-80. The onboard card math stays clear of the rail (checked every 10 px of height at 6 widths in lune: 0 hits), so Kevin's overlap is likely the first-frame default rect (16, 96, 460×144, OnboardHud.luau:143-144) before `apply()` runs, or R2. **@Havoc repro.** | Dialog zone Z11 + `RAIL_SAFE` |
| 5 Loot toasts look like debug text | yes | "Loot: …" (CombatFeel.luau:461) goes through `onHint` → `ui.setStatus` (gold banner) + `hudShell.toast` (plain `TextLabel`, no icon) (init.client.luau:1628-1633, HudShell.luau:457-472); CombatHint label at x 16 over the action-bar line (CombatHud.luau:312-320, :353) | Toast lane Z6, toast style in PANEL_STYLE §5 |
| 7 Yellow room banners; raw red "best gear" over the tabs | yes | Banner = gold fill + ink, 16 px, `DisplayOrder 100` (Ui.luau:264-292, :333-338, red on `error`); "Your best gear is already equipped." from InventoryHud.luau:1891 via `onStatus` | Room banners become a toast kind; panel errors go to the panel status strip (PANEL_STYLE §1) |
| 9 Dev Tools over Goals | yes | Dev Tools button x 1848-1904, y 96-128 (DevTools.luau:231-236) sits on the onboard goals tracker x 1664-1904, y 96-168 (HudLayout.luau:707); panel x 1604-1904, y 136-843 (DevTools.luau:237-245) | Z5 under the objective slot |
| 8 Small text (HUD part) | yes | rail key hint 11 px (HudShell.luau:368), build stamp 12 px (HudShell.luau:569), status line 13 px (Ui.luau:858) | `MIN_TEXT_PX = 14` everywhere (§9) |
Seeds 1, 3, 6 are panel issues; see `HERO_SCREEN.md` §2 and `PANEL_STYLE.md` §2.

## 3. Flow (who owns the screen when)
| Moment | Visible zones | Rule |
|---|---|---|
| Explore | Z1 stats, Z2 rail, Z3 currency, Z4 objective (goals **or** tutorial), Z10 action bar | Center keep-out stays empty |
| Loot / error / room entered | + Z6 toast lane (+ Z8 Equip/Keep prompt) | Phones: Z4 auto-folds to its tab while Z6/Z8 are up (#465 Q4, decided) |
| Fight | + Z9 callout (combo, telegraph) | Z9 is just above the action bar, never at the top-left |
| Shard Crater run | Z7 run band (wave chip / boss bar, #428) | Pills hide in a run (#428 Q1); Z4 shows its tab only (#465) |
| Panel open (Hero, Bag, Roll, Pets, Shop, Settings) | Z1, Z2, Z3, Z12 | Z4 folds (desktop) / hides (phone); Z6 lines go to the panel's status strip; Z8 waits; phone hides Z10. One panel at a time: opening one collapses the other |
| Defeated / confirm | Z11 dialog | Closes any panel; hides Z9 and (phone) Z10. Never over `RAIL_SAFE` |
| Owner Dev Tools | Z5 | Desktop: right column under Z4. Phone: opens as the Z12 sheet. Never over Z4 |
**Collapse, not close:** Z4 folds to its 44 px tab; panels collapse back into their rail button (PANEL_STYLE §8). The tutorial uses Z4: while a tutorial step is up the goals list is folded into the same slot's tab, and the slot shows the step card. When the step ends, the goals come back. They are never both on screen.

## 4. Layout (target rects, safe-area px)
**1920×1080 (pc)** (mockup 04):
| Zone | Element(s) | Rect | Scale + offset (Position / Size) |
|---|---|---|---|
| Z1 Stats | portrait + HP/XP block (HudShell) | x 16-300, y 16-72 | (0,16, 0,16) / (0,284, 0,56) |
| Z2 Rail | 6 × 64 buttons, gap 8 | x 16-80, y 328-752 | (0,16, 0.5,-212) / (0,64, 0,424) |
| `RAIL_SAFE` | nothing else may intersect | **x 0-96, y 320-760** | **(0,0, 0.5,-220) / (0,96, 0,440)** |
| Z3 Currency | Gold, Mastery, Shards pills | x 1564-1904, y 16-52 (moves up from y 52, Q2) | (1,-356, 0,16) / (0,340, 0,36) |
| Z4 Objective | goals tracker **or** tutorial card | x 1584-1904, y 64-304 (max) | (1,-336, 0,64) / (0,320, 0,240) |
| Z4 tab | folded goals / tutorial pill | x 1760-1904, y 64-108 | (1,-160, 0,64) / (0,144, 0,44) |
| Z5 Dev Tools | toggle 104×44 + panel (owner, Studio) | x 1584-1904, y 316-948 | (1,-336, 0,316) / (0,320, 1,-448) |
| Z6 Toast lane | max 3 cards × 40, gap 8 | x 720-1200, y 76-212 | (0.5,-240, 0,76) / (0,480, 0,136) |
| Z7 Run band | boss bar (#428) | x 760-1160, y 16-60 | (0.5,-200, 0,16) / (0,400, 0,44) |
| Z8 Prompt | Equip / Keep | x 720-1200, y 220-300 | (0.5,-240, 0,220) / (0,480, 0,80) |
| Z9 Callout | combo count, telegraph cue, combat hint | x 760-1160, y 908-956 | (0.5,-200, 1,-172) / (0,400, 0,48) |
| Z10 Action bar | 8 slots (ActionSlots) | x 676-1244, y 964-1064 (live, unchanged) | from `ActionSlots.placement` |
| Z11 Dialog | Defeated, confirms | x 750-1170, y 796-956 | (0.5,-210, 1,-284) / (0,420, 0,160) |
| Z12 Panel | Hero, Bag/Inventory, Roll, Pets, Shop, Settings | x 112-1552, y 104-920 | (0,112, 0,104) / (0, min(1440, vx−464), 0, min(816, vy−264)) |
| Keep-out | #420 center rule, scaled | x 576-1344, y 302-788 | (0.3,0, 0.28,0) / (0.4,0, 0.45,0) |
| World | damage numbers (BillboardGui, CombatHud.luau:83-113), room/area labels in 3D | world space only | never a ScreenGui |

**390×844 (phone portrait)** (mockup 05, four states):
| Zone | Rect | Scale + offset |
|---|---|---|
| Z1 Stats | x 16-258, y 16-72 (live `HudLayout.health` phone width) | (0,16, 0,16) / (0,242, 0,56) |
| Z3 Currency | x 266-374, y 16-128 (live column) | (1,-124, 0,16) / (0,108, 0,112) |
| Z6 Toast lane | **max 2** × 40: x 16-258, y 80-168 | (0,16, 0,80) / (0,242, 0,88) |
| Z8 Prompt | x 16-258, y 172-248 | (0,16, 0,172) / (0,242, 0,76) |
| Z4 Objective | x 80-374, y 136-292 (#465 rect, left edge moved to 80 to clear `RAIL_SAFE`) | (0,80, 0,136) / (1,-96, 0,156) |
| Z4 tab | x 266-374, y 136-180 (#465) | (1,-124, 0,136) / (0,108, 0,44) |
| Z2 Rail | 6 × **48** buttons, gap 8: x 16-64, y 258-586 (Q3) | (0,16, 0.5,-164) / (0,48, 0,328) |
| `RAIL_SAFE` | **x 0-72, y 250-594** | **(0,0, 0.5,-172) / (0,72, 0,344)** |
| Z10 Action | x 158-374, y 600-740 (live) | `ActionSlots.placement` |
| Z11 Dialog | x 80-374, y 620-780 (hides Z10) | (0,80, 1,-224) / (1,-96, 0,160) |
| Z12 Panel | x 72-382, y 136-836 (310×700) | (0,72, 0,136) / (1,-80, 1,-144) |
| Z5 Dev Tools | Studio/owner only: toggle bottom-left under the rail, x 16-120, y 790-834; the panel opens as the Z12 sheet | (0,16, 1,-54) / (0,104, 0,44) |
| Z7 / Z9 | Wave chip takes the Z3 slot, boss bar x 16-258 y 80-116 and Z6 starts at y 124 while it's up (#428 Q1/Q2). Callouts use Z6 card 1 with the danger style | — |
| Keep-out | x 117-273, y 296-616 (#420) | — |

**Landscape phones (cheap pass, lower confidence; Ghost confirms with UiAudit)** (mockups 06, 07):
| Zone | 667×375 | 800×400 |
|---|---|---|
| Z1 Stats | x 16-300, y 16-72 | x 16-300, y 16-72 |
| Z3 Currency | x 311-651, y 16-48 | x 444-784, y 16-48 |
| Z2 Rail / `RAIL_SAFE` | 6 × 44, x 16-60, y 80-359 / **x 0-68, y 72-367** = (0,0, 0,72) / (0,68, 1,-80) | x 16-60, y 80-384 / **x 0-68, y 72-392** (same formula) |
| Z6 Toasts (max 2) | x 76-300, y 80-168 | x 76-300, y 80-168 |
| Z8 Prompt | x 76-300, y 172-248 | x 76-300, y 172-248 |
| Z4 Objective / tab | x 471-651, y 56-216 / tab x 543-651, y 56-100 | x 604-784, y 56-156 / tab x 676-784, y 56-100 |
| Z10 Action | x 451-651, y 227-359 (live) | x 584-784, y 164-296 (live) |
| Z11 Dialog | x 76-436, y 200-360 | x 76-436, y 220-380 |
| Z12 Panel | x 76-651, y 16-359 (covers Z1/Z3; they hide) | x 76-784, y 16-384 |
Known compromise: on landscape the toast lane and prompt cross the top-left corner of the keep-out (667: x 200-300, y 105-248). There's no other free band at 375 px tall. See Q6.

## 5. States
| Zone | States |
|---|---|
| Z4 | goals open · goals folded (tab "Goals 2/5") · tutorial step (card) · tutorial folded (tab "Tutorial 3/6") · hidden (panel open on phone, Wave run shows tab only) |
| Z6 | empty · 1-3 cards (2 on phones) · merged (×N) · routed to the panel status strip while a panel is open |
| Z12 | collapsed (rail button only) · open · switching (collapse old 0.15 s, open new 0.26 s, same rect, so no size jump) |
| Z11 | hidden · Defeated · confirm (with a 0.5 backdrop, the only element allowed over `RAIL_SAFE`) |
| Z5 | hidden (non-owner / live server) · toggle · open |

## 6. Copy
| Where | Copy |
|---|---|
| Z4 tab | "Goals %d/%d" · "Tutorial %d/%d" |
| Z6 loot | item name in its rarity color, "×N" right; no "Loot:" prefix (keep `CombatFeel.LOOT_PREFIX` for parsing only) |
| Z6 room banner | "ROOT HALL · ROOM 2/5" (room name caps, then the counter) |
| Z6 error | short sentence, white text, red accent: "Your best gear is already on." |
| Z11 Defeated | title "Defeated", body from the payload (CombatHud.luau:947), one button "Back to Haven" / "Revive" as today |

## 7. Visual style
Zone chrome follows `PANEL_STYLE.md`: dark slate `20,24,32` at 0.08 transparency for HUD cards, `UICorner` 10-12, `UIStroke` 1 `divider 120,132,156` (gold `255,206,96` for the active rail button and the Z4 tab). No blur and no drop shadows.

## 8. Motion
Z4 fold/unfold 0.2 s `Size` tween; Z6 cards slide in 8 px + fade 0.15 s, out 0.2 s; Z12 open 0.26 s / collapse 0.15 s toward the rail button (`UiTheme.MOTION.open`/`panel`); Z11 pop `UIScale` 0.94 → 1 in 0.12 s. All `TweenService`, no `RenderStepped`.

## 9. Roblox build notes + UiAudit constants (DP42)
- **One zone module.** Ghost adds the rects above to `HudLayout` (e.g. `HudLayout.zone(name, vx, vy)` returning `Rect`), and the `ShellLayout` callers in R1 move onto it. Prism doesn't edit `HudLayout` or any Ghost-owned file; this is the brief.
- **One inset mode:** every HUD `ScreenGui` uses `ScreenInsets = CoreUISafeInsets`, `IgnoreGuiInset = false` (R2).
- **DisplayOrder ladder (proposed):** world-attached 8-20 · HudShell 30 · Z4 objective 32 (it moves down from 95) · run band 40 · results 50 · action bar 60 · panel 80 · rail 85 (above panels, so it stays tappable) · prompt 90 · dialog 92 · toast 100 · confirm 105 · loading 110.

**Constants for UiAudit (one shared table):**
| Constant | Value |
|---|---|
| `RAIL_SAFE` pc/console/tablet | Position `UDim2.new(0,0, 0.5,-220)`, Size `UDim2.new(0,96, 0,440)` (rail 6 × 64 + 5 × 8 = 424, plus 8 px around it, plus a 16 px gutter on the right) |
| `RAIL_SAFE` phone portrait | `UDim2.new(0,0, 0.5,-172)` / `UDim2.new(0,72, 0,344)` (6 × 48 + 40 = 328) |
| `RAIL_SAFE` phone landscape (`vy < 500`) | `UDim2.new(0,0, 0,72)` / `UDim2.new(0,68, 1,-80)` |
| General formula | x 0, w = 16 + button + gutter (16 pc / 8 phone); h = railH + 16, centered on the rail (landscape: from y 72 to vy − 8) |
| `MIN_TEXT_PX` | **14** at 1920×1080 **and** on phones (Roblox offsets are device-independent points, so the phone equivalent is also 14). Check `TextSize` after any `UIScale` (HudShell has `ShellScale`, HudShell.luau:66-68); `TextScaled` must resolve ≥ 14 (use `UITextSizeConstraint.MinTextSize = 14`) |
| `MIN_TOUCH_PX` | 44 (`UiTheme.TOUCH`) for anything with `Active = true` |
| `TOAST_MAX` | 3 (pc), 2 (phone) |
| `CONTRAST_MIN` | 4.5:1 body text, 3:1 for text ≥ 24 px bold (WCAG AA) |
| Breakpoints | `HudLayout.breakpoint` (HudLayout.luau:446-457) |
**Allowed overlap pairs (a visible pair outside this list fails):**
| A | B | Why |
|---|---|---|
| Rail `Tip` tooltips (HudShell.luau:346-356) | anything | hover-only, < 2 s |
| Confirm dialog + its backdrop | everything, including `RAIL_SAFE` | modal, the player must answer |
| LoadingHud (DisplayOrder 110) | everything | load screen |
| Dropdowns / popovers (`Dropdown.luau`, GearBar `AutoPopover`) | their own parent panel | children, not top-level |
| Z12 panel (landscape phones only) | Z1, Z3 | they hide; UiAudit should see them hidden |
| Dev Tools panel (phone, Studio) | Z12 sheet slot | it *is* the sheet; owner only |
Everything else, including Z6 vs Z12, Z8 vs Z12, Z11 vs Z9/Z10 and Z4 vs Z6/Z8 on phones, must **not** be visible together. The state rules in §3 hide one of them. UiAudit should fail if both are visible.

## 10. Mobile checks
| Viewport | Mockup | Result |
|---|---|---|
| 1920×1080 | `04-zone-map-1920x1080.svg` | no visible overlaps outside the allowed list; nothing in the keep-out except panels/dialogs |
| 390×844 | `05-zone-map-390x844-states.svg` (explore · loot + prompt · panel · defeated) | `RAIL_SAFE` clear in all 4; Z4 folds while Z6/Z8 are up |
| 667×375 | `06-zone-map-667x375-states.svg` | rail 44 px; toast lane crosses the keep-out corner (Q6) |
| 800×400 | `07-zone-map-800x400-states.svg` | same |
| Live today | `08-live-audit-1920x1080.svg`, `09-live-audit-390x844.svg` | red = intersects another live rect (20 pairs at 1920, 32 at 390 when everything that can show is shown) |
Touch: every tappable element is ≥ 44 px (rail 64/48/44, Z4 tab 44, toggles 44, prompt buttons 44).

## 11. Open questions (answer by number)
1. **@Ghost:** move every `ShellLayout` HUD caller (R1) onto one `HudLayout.zone()` table and switch every HUD `ScreenGui` to `CoreUISafeInsets` (R2)? Prism recommends **yes**. Patching rects one at a time is how the seed bugs came back.
2. **@Ghost:** move the desktop pills up to y 16 (Z3), now that the gold banner (which they were dodging, HudLayout.luau:89-102) becomes a toast? Prism recommends **yes**. It frees the right column for Z4.
3. **@Ghost / @Kevin:** phone portrait rail buttons at **48** px (from 64) so panels get 310 px of width? Prism recommends **yes**. 48 is still above the 44 touch floor, and captions become icon-only on phones.
4. **@Ghost:** objective slot on the **right** at desktop (under currency, like #465) instead of the tutorial's current top-left? Prism recommends **right**. It keeps the left for stats + rail only.
5. **@Ghost:** route toasts into the panel status strip while a panel is open (instead of drawing them over the panel header)? Prism recommends **yes**. It's how the "best gear" line stops landing on the tabs.
6. **@Kevin:** on landscape phones, accept the toast lane crossing the keep-out's top-left corner (no other free band at 375 px)? Prism recommends **yes, max 2 cards**.
7. **@Havoc:** repro seed 4 (tutorial over rail) at Kevin's Studio window size with Output, since the layout math doesn't produce it (§2).

## Addendum v1.1 (Oct 24, 2026, PT): Wave HUD calls folded in (DP43P)
Source: Ghost's Agent Board row DP43P https://app.notion.com/p/403c31ca3883817d8f60c884c3fb20e8 (Ghost decided per Prism's recs, Kevin pre-approved Ghost's tasks, Kevin can veto). Specs: Wave HUD v2 (`prism/wave-hud`, #428), results v1.2 (#464), goals tracker v1.1 (#465). Ghost's DP43P numbering is used below. This addendum only adds the run state; §1–§11 stay as written. Mockup: `mockups/11-zone-map-run-state.svg`.

**Decided (Ghost):**
| # | Call | Zone effect |
|---|---|---|
| Q1 | Hide the currency pills during a run (`phase` `fight`/`deathHold`); a **run chip** takes their slot | Z3 becomes the run chip in a run |
| Q2 | Portrait: boss bar sits under HP; the toast host moves **1 card lower** on wave 5 | 390×844 Z7 under Z1, Z6 from y 124, Z8 moves +44 |
| Q5 | Starter goals tracker (#465) is its **folded tab** during runs | Z4 = tab only in a run |
| Q7 | Park the break timer; show a **1.0 s "CLEAR n/5"** gold flash | inside the run chip, no new rect |
| Q8 | Time-out keep line shows **"8:00"** | results card copy (#464), no HUD rect |
| Q10 | Normal boss HP bar **orange `230,120,70`**; red stays Hard-only | Z7 fill |
| Q11 | **Plain HARD chip** (no skull). Provisional, Kevin can veto | Z3 sub-slot, see below |

**Run-state rects (safe-area px), additive to §4:**
| Piece | 1920×1080 | 390×844 | 667×375 | 800×400 |
|---|---|---|---|---|
| Run chip (Z3 slot, Q1) | x 1744–1904, y 16–60 (160×44) | x 266–374, y 16–60 (108×44) | x 531–651, y 16–60 | x 664–784, y 16–60 |
| HARD chip (Q11, under the run chip, right-aligned, display-only) | x 1852–1904, y 64–86 (52×22) | x 322–374, y 64–86 | x 599–651, y 64–86 | x 732–784, y 64–86 |
| Z7 boss bar (wave 5, Q2/Q10) | x 760–1160, y 16–60 (unchanged) | **x 16–258, y 80–116** (under Z1) | x 311–523, y 20–56 (pills slot, left of the chip) | x 308–656, y 20–56 |
| Z6 toast lane while the boss bar is up | unchanged (y 76–212) | **x 16–258, y 124–212** (2 × 40, Q2) | unchanged (y 80–168) | unchanged |
| Z8 prompt while the boss bar is up | unchanged | **x 16–258, y 216–292** (+44) | unchanged | unchanged |
| Z4 in a run (Q5) | tab only, x 1760–1904, y 64–108; **y 92–136 while the HARD chip shows** | tab only, x 266–374, y 136–180 (clear of the HARD chip) | tab x 543–651, y 64–108; y 92–136 with HARD | tab x 676–784, y 64–108; y 92–136 with HARD |
Checks (same script as §10): none of these enter the keep-out or `RAIL_SAFE`; the run chip and Z4 tab stay ≥ 44 tall (tap targets); the HARD chip and boss bar are `Active = false` (display only). Text in the chip, bar and HARD chip is **14 px** (`MIN_TEXT_PX`); Wave HUD v2's 13 px chip line and 11 px boss name move up to 14 (the landscape boss name truncates with "…" before it goes under 14).

**Copy:** run chip "WAVE n/5" → "CLEAR n/5" (gold, 1.0 s) on wave 1–4 clear, then "WAVE n+1/5"; boss bar name from `WaveArenaConfig.boss.name` once in the snapshot (Echo Q3), until then "BOSS"; HARD chip "HARD" (ink `32,22,10` on danger `230,80,96`).

**DisplayOrder:** run chip, HARD chip and boss bar are the run band (40, §9). No change to the ladder.

**Echo dependencies (not specced as code here; Ghost routes them, DP43):**
- **Q3** `Hud.snapshot` gets `left`, `adds`, `boss.name` and the "Wave %d/%d" text. Until then the chip shows "WAVE n/5" only.
- **Q4** `tier` in the snapshot; the **HARD chip draws only once Hard really scales the arena** (today `WaveArenaHost.luau:675` hard-sets `opts.tier = "normal"` @ `9feb018`, and no WaveArena file reads `hpMultiplier`). Until then the HARD chip rect stays empty and Z4's tab stays at y 64.
- **Q6** red countdown in the chip for the last 60 s of 480 s, needs `secondsLeft`. Same chip rect, no new zone.
- **Q9** hide the ×2 tags now; Hard multipliers go into the arena before `hardMode` flips.

## Decision log
- Oct 24, 2026: v1 written for DP41P (Prism). Nothing decided yet.
- Oct 24, 2026: v1.1 (Prism, DP43P): Ghost's Wave HUD calls Q1/Q2/Q5/Q7/Q8/Q10/Q11 folded as a run-state addendum + mockup 11; Echo items Q3/Q4/Q6/Q9 noted as dependencies. Still NOT APPROVED until copied into Vision & Design Rules.
