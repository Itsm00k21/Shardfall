# Pets panel v1 on PANEL_STYLE: team strip, pet grid, pet detail (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (`MenuHub` pets page and `HubStyle` are Ghost-owned; Prism edits neither). Base: `cursor/live-build-9721` @ **`9c42ce6`**. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP56P https://app.notion.com/p/403c31ca38838112a4abff69093e8583 (next item 2). ACK: https://app.notion.com/p/403c31ca388381ddb081f1fa425ac293. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on: `docs/design/ui-overhaul/PANEL_STYLE.md` (Z12 rect, header, tabs, buttons, item card, badge, status strip) + `HUD_ZONE_MAP.md` on `prism/ui-overhaul` (#479), and the Bag panel `docs/design/bag-inventory-panel/SPEC.md` (#483: card grid, phone bottom sheet, landscape side sheet, decided Q1-Q3 in DP56P). Mockups: `mockups/01`–`03`.

## 1. Goal
Pets feel like a team, not a list. The panel opens in the same Z12 rect as Hero, Bag and Roll. At the top you see your **team** (the 3 equipped sockets and what they add); below, every companion as a rarity card you can compare and equip in one tap; the empty state sends you straight to a Pet Shard crack.

## 2. Where it lives + live audit (`9c42ce6`)
| What players get today | Evidence | Change here |
|---|---|---|
| Pets is a `MenuHub` scroll page with a gold "Equipped n/3" line | MenuHub.luau:1319, :4555 | Header subtitle "Equipped 2 / 3 · 12 companions" |
| Sockets = `HexSlot` / `HexSlotGlow` art 64 + 14 px caption "Slot 1  Name" | MenuHub.luau:4569-4598 | Team strip: 72 sockets (56 phone, 44 landscape header), number badge, name in rarity colour, empty = dashed + "+" |
| Cap = 3 + `petSlotBonus` (max +5), the slot is not for sale | GoldShop.luau:13-15, :41-50 (`GoldShop.petCap`, `apply` refuses `"pet"`) | Copy "More slots come later (not for sale)" |
| Cards: rarity text label + name + star row (`GearHooks.levelLine`) + lock | MenuHub.luau:4697-4745 | PANEL_STYLE item card + badge + stars + Pet DMG line + ON / NEW / lock markers |
| Detail: art 72, "Perk  " + `HubStyle.petPerk` (falls back to role, then **"Companion"**), stat lines Level / Bond / Affinity / Role | MenuHub.luau:4788-4805, HubStyle.luau:312-341 | Viewport + name + badge + stars; compare vs the weakest equipped pet; Bond / Affinity pips only when present; **perk row only when the pet has an ability** |
| Rolled pets carry `pet_damage`, `pet_health`, `attack_speed`, `crit_chance` | ItemBases.luau:98-121 (`PET_STYLES`), :270-285 (Verdant pets) | These four are the compare rows |
| Only 3 roster pets have an ability: Shardjaw "Auto-collect drops", Thorn Lantern "Key ping", Glass Kestrel "Dodge flash" | PetRoster.luau:21-43 | Shown as the gold perk line + in the team bonus |
| Empty: "No companions yet" + a "Crack a Pet Shard" row | MenuHub.luau:4798, :4842 | Empty state card + green **CRACK A PET SHARD** (opens Roll with `rollKind = "pets"`, as today) |
| Mythic / Secret pets exist in the Verdant roster but don't roll while `LaunchGate.extraTiers` is off | Pools.luau:10-12, :131-153 | V1 shows 5 tiers only; no Mythic/Secret styling here |

## 3. Flow
1. Rail **Pets** (or its hotkey, `controls.hotkeys.pets`) → panel opens from the rail button into Z12 (0.26 s). Opening another panel collapses this one into its button (PANEL_STYLE §8).
2. Tap a card → desktop: detail pane on the right; phone: bottom sheet over the grid; landscape: 300 px side sheet (DP56P Q2).
3. **EQUIP · SLOT n** puts it in the first empty socket; if all 3 are full the button reads **SWAP · SLOT n** and targets the weakest equipped pet (the one the compare rows use). Tap a filled socket → its detail opens with **UNEQUIP**.
4. **Equip Best** (header) fills the sockets by Pet DMG; status strip confirms "Team set: +6 pet damage."
5. Lock (44 px) prevents salvage/swap; the lock glyph shows on the card.
6. Empty → **CRACK A PET SHARD** collapses Pets and opens Roll on the pets pool.

## 4. Layout (safe-area px)
| Viewport | Panel (Z12) | Team strip | Grid | Detail |
|---|---|---|---|---|
| 1920×1080 | x 112-1552, y 104-920 (1440×816) | x 20-1040, y 76-216 (in panel); sockets 72, pitch 150; team bonus text right of them | 3 cols, card 332×104, gap 12, from y 284 | pane x 1060-1420, y 76-740 (360×664); viewport 328×150 |
| 390×844 | x 72-382, y 136-836 (310×700) | x 12-298, y 64-160; sockets 56, pitch 92 | 2 cols, card 139×158, gap 8, from y 222 | bottom sheet from y 200 to the panel bottom; viewport 286×120 |
| 667×375 | x 76-651, y 16-359 | 3 × 44 sockets in the header (x 108-246) | 2 cols, card ×72 | — |
| 800×400 | x 76-784, y 16-384 | same as 667 | 2 cols, card ×72 | side sheet 300 wide from the right, below the header |
Tabs: All n · Equipped n · New n (pill style, 44 tall); desktop adds Rarity + Sort dropdowns (44). Status strip 44 at the panel bottom (desktop y 752).

## 5. States
Panel: collapsed (rail button only) · open · open + detail · empty · loading (skeleton cards, no spinner text). Card: idle · selected (3 px gold stroke + outer ring) · ON (green chip desktop / check badge phone) · NEW (red dot with gold ring, clears on first open) · locked (lock glyph) · Legendary (static rays in the detail viewport and the team socket only, not on grid cards). Socket: filled (rarity tile, number badge) · empty (dashed, "+", caption "Slot 3 · empty" / "Empty" on phones) · target (gold pulse 0.6 s when EQUIP is hovered/pressed). Buttons: EQUIP (equip kind) · SWAP (equip kind) · UNEQUIP (secondary) · disabled with reason ("Already on your team").

## 6. Copy
Header "PETS", subtitle "Equipped 2 / 3 · 12 companions" (phone: "Equipped 2 / 3"). Team label "TEAM · follows you and fights". Team bonus "18 pet damage · Auto-collect drops". Compare header "VS SHARDJAW (SLOT 2, WEAKEST)". Empty "No companions yet." / "Crack a Pet Shard to get one. Pets follow you, fight, and pick up loot." Button "CRACK A PET SHARD", note "Opens Roll on the Pets pool." Never "Companion" as a perk name.

## 7. Visual style (Roblox values)
PANEL_STYLE throughout: panel slate + gold 2 px stroke, header `42,48,60`, cards `UICorner` 12 + `UIStroke` 2 rarity + rarity gradient, badge pills 24 (22 phone), text Builder Sans Bold 16 (14 minimum). Stars: gold `255,206,96` filled, `muted` @ 0.55 empty, 14 px. Bond / Affinity pips 14 px circles, fill `255,150,180`. Viewport backdrop = rarity gradient to `20,24,32`, one static ray `ImageLabel` for Legendary, a soft ground ellipse `Frame` (`UICorner` 1,0, black @ 0.65). No blur.

## 8. Motion
Panel open/collapse per PANEL_STYLE §8. Card select 0.12 s stroke tween. Detail pane crossfade 0.1 s; phone sheet slides up 0.22 s Quart Out, down 0.18 s; landscape sheet slides in from the right 0.22 s. Equip: the card's pet tile flies to the socket (`Position` + `Size` tween 0.3 s), socket pops `UIScale` 1 → 1.08 → 1 (0.12 s), team bonus number counts up 0.4 s. Viewport model idles with a slow `CFrame` yaw tween (12 s per turn, paused while dragging). All `TweenService`.

## 9. Roblox build notes
- Panel via the shared `PanelChrome` builder (PANEL_STYLE §9): header / tabs / body / status strip. Rect = `HudLayout.zone("Z12", vx, vy)`.
- Team strip: `Frame` + `UIListLayout` Horizontal, 3 socket `ImageButton`s (reuse `HexSlot`/`HexSlotGlow` art inside a 72/56/44 rounded tile; the tile is the 44+ hit target), number badge `TextLabel` 20×20 `UICorner` (1,0).
- Grid: `ScrollingFrame` + `UIGridLayout` CellSize (332,104) desktop / (139,158) phone / ((w−8)/2, 72) landscape; `AutomaticCanvasSize = Y`.
- Detail viewport: `ViewportFrame` with the pet model clone + `Camera`, `Ambient`/`LightColor` set, behind it the rarity `UIGradient` frame and (Legendary) the ray `ImageLabel`. Rotate by drag (`InputChanged`) on desktop and phones; a rotate glyph 20 shows it can turn.
- Compare rows = `HubStyle.petStats`-style rows extended with the four `PET_STYLES` stats and a delta `TextLabel` (`UiTheme.compareTone`).
- Phone bottom sheet / landscape side sheet: child `Frame` of the panel, dim `Frame` behind it, collapse chevron hit area 44.
- Touch: cards, sockets, tabs, EQUIP, lock, chevrons all ≥ 44. MIN_TEXT 14 everywhere (the live socket caption is 14 already; the live Hatch button at 13 px, PetHud.luau:29, is out of this panel's scope but should move to 14).
- Prism edits no Ghost-owned file (GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud, RollReveal). This is the build brief.

## 10. Mobile checks
| Viewport | Mockup | Checks |
|---|---|---|
| 1920×1080 | `01-pets-desktop-1920x1080.svg` | same Z12 rect as Bag/Hero; 9 cards + detail; status strip |
| 390×844 | `02-pets-phone-390x844-states.svg` (grid · bottom sheet · empty) | panel right of `RAIL_SAFE`; sockets 56; cards 139 wide with 2-line names at 16 px; EQUIP 44 |
| 667×375 / 800×400 | `03-pets-landscape-667x375-800x400.svg` | team in the header (44 sockets); side sheet 300; nothing under 14 px |

## 11. Open questions (answer by number)
1. **@Ghost:** EQUIP when the team is full = **SWAP** the weakest equipped pet (by Pet DMG), shown in the compare header? Prism recommends **yes**.
2. **@Ghost:** add **Equip Best** to Pets (fills sockets by Pet DMG, skips locked choices)? Prism recommends **yes**, same as Bag.
3. **@Kevin:** pet "power" on cards = **Pet DMG** (the stat that matters in a fight)? Prism recommends **Pet DMG**; health/speed/crit live in the detail.
4. **@Ghost:** hide the perk row when a pet has no ability (instead of "Perk Companion")? Prism recommends **hide**.
5. **@Kevin:** pet `ViewportFrame` in the detail (live 3D model you can turn) vs flat art? Prism recommends **viewport** (same taste call as DP41P's Hero pet).
6. **@Ghost:** Bond / Affinity pips only when the record has them (species pets), hidden for rolled pets? Prism recommends **yes**.
