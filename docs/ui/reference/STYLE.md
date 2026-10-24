# UI style

Rules for the approved inventory and x10 roll. Match these. Do not add a second inventory, a chip row, or a side strip.

Numbers in [Exact values](#exact-values) are copied from the code at the commits in [README.md](README.md). `ghost/gear-ui-hooks` is `53549b6`. `ghost/roll-x10` is `d3686ba`. Line numbers are from those commits.

## One inventory

One centered Inventory window. Open it with **B** or the **Bag** rail button. Never a second bag, and never a side strip of items.

- `Keybinds.MENU.bag = "B"` in `src/ReplicatedStorage/Shared/Keybinds.luau` (line 108).
- The Bag rail button is the `Bag` entry in `HudShell.luau` (`id = "Bag"`, `call = "onBag"`).
- While `LaunchGate.on("oneInventory")` is true, the Bag key path in `init.client.luau` closes MenuHub and calls `inventory.open()` / `inventory.close()`. The window itself is `InventoryLayout.modal`: centered in the space right of the left rail and under the HP card, capped at `MAX_W` 1180 and `MAX_H` 680 (`InventoryLayout.luau`).

## Top rows

First row: category tabs.

Second row: Search, then the Rarity, Type, and Sort dropdowns.

No chip row that overflows. No sideways scrolling. Tabs share one row and shorten (`Acc.`, `Mats`) when they get narrow. The filter row is one `filterBar` of Search plus three dropdowns (`InventoryHud.luau`, the "ONE filter row" block). Dropdown lists open on the modal root so the row does not clip them. The gear action bar under that is one line and does not scroll sideways (`GearBar.luau`, `GearRow`).

## Item cards

Square cards, a big icon, a border in the rarity color, the name in the rarity color, and a star row.

- An **E** badge when the item is equipped.
- A gold padlock only when the item is locked. Unlocked shows no padlock (a faint lock may appear on hover). Do not show a padlock on every card.

Cells are square: `InventoryLayout.grid` sets `cellH = cellW`. The card corner is `corner(card, 10)`. The border is `strokeFor` at thickness 2 in `Rarities.rgb`. The name uses that same rarity color. The equipped badge is a label whose text is `E` (`EquipBadge`). The padlock is `GearDetail.lockIcon`: `LOCK_GOLD` `Color3.fromRGB(255, 196, 64)` when locked, hidden when not.

## Detail panel

On the right on desktop and on a landscape phone. On a portrait phone it is not a side column: the grid comes first and the detail opens after it (Back returns to the grid). That is `InventoryHud.placePanes`. `stacked()` is true when the phone body is narrower than 600. Landscape keeps `detail` on the right at `InventoryLayout.detailW`.

The panel opens on the equipped item when both panes are on screen (equipped weapon, else anything worn, else the first card). Portrait keeps the grid until a card is chosen.

**EQUIP** and **UPGRADE** sit side by side (`GearDetail`, frame `DetailActions`). UPGRADE is yellow with dark text: fill `Color3.fromRGB(255, 190, 60)`, text `Color3.fromRGB(24, 18, 12)`. When the player is short on gold, or the item is maxed, the button uses the dim fill and muted text instead.

## Auto-salvage

Auto-salvage lives in a popup (`GearBar` frame `AutoPopover`), not in a chip row. The highest cap is Uncommon. The popup dropdown offers only Common and Uncommon. `GearHooks.safeCap` clamps anything above Uncommon to Uncommon (`GearHooks.AUTO_SAFE`).

Turning it on asks for confirm. The popup shows `AutoAsk` (`Turn on` / `Cancel`) before the setting changes. Raising the cap asks the same way. The pill on the bar only opens the popup.

## x10 roll

Each card takes at most **0.3 s**. Skip stays visible for the whole batch. The batch ends on a 10-tile grid with **NEW**, **star-up**, and **Salvaged** badges, plus **Roll again** and **Close**. Milestones are a small toast at the top, not a banner over the reel.

- Pace: `RollSummary.STEP = 0.3`. `RollSummary.fast` scales a longer plan down to that step (`src/ReplicatedStorage/Shared/RollSummary.luau` on `ghost/roll-x10`). This cap is not `RollReveal.FULL`.
- Skip: `RollSummary.SKIP` is `"Skip"`. `MenuHub` `SkipBatch` is parented on the roll page for the whole batch (`paintSkip` sets `Visible` while `batching`). Corner radius 8.
- Summary: `RollSummaryHud` frame `RollSummary`, ten tiles, badges, `RollAgain` (`"Roll again"`), `Close` (`"Close"`). A salvaged tile's badge text is shortened to `Salvaged`.
- Toast: `MenuHub` label `Milestone`, anchored top-center, 220 by 26, attribute `Toast`.

`RollReveal` still owns the single-roll playback clock (full 1.65 s, short 0.7 s). An x10 card does not use that full clock. `RollReveal.skipReady` is true for any elapsed time once duration is above 0, so Skip is not gated on a delay.

## Dev-only buttons

**+ Slots** and the Dev menu are visible only for owner id **10427235156**.

- `DevAccess.OWNER_IDS` is `{ 10427235156 }` (`src/ReplicatedStorage/Shared/DevAccess.luau`, line 28).
- `InventoryHud` builds `+ Slots` only when `DevAccess.player(Players.LocalPlayer)` is true (phone label `+Slots`).
- `DebugHud` returns before building the Dev menu unless `DevAccess.player` is true.

`DevAccess.allowed` also requires Studio, and it allows the place's user-owner or an unpublished place (`CreatorId` 0). The named owner id is `10427235156`. Do not show these controls to anyone else.

## Exact values

Copied from source. Do not match these by eye.

### GearBar

File: `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/GearBar.luau` on `ghost/gear-ui-hooks` @ `53549b6`.

`COLORS` (lines 56–68):

| Token | RGB |
|---|---|
| panel | 28, 24, 40 |
| text | 240, 236, 248 |
| muted | 176, 168, 198 |
| gold | 255, 196, 64 |
| ink | 32, 22, 10 |
| danger | 230, 80, 96 |
| button | 108, 78, 196 |
| buttonDim | 54, 46, 78 |
| on | 70, 140, 96 |
| warn | 255, 168, 48 |

Confirm tray `AutoAsk` background is `Color3.fromRGB(60, 34, 30)` (line 326), separate from `COLORS`.

Sizes (lines 51–53): `ROW_H = 40`, `BAR_H = 48`, `CONTROL_H = 36`.

Corner radius (`UDim.new(0, n)`):

| Piece | Radius |
|---|---|
| `button`, `wideButton`, `AutoAsk`, salvage and clear buttons | 8 |
| Essence chip | 8 |
| Salvage bar | 10 |
| Popup panel (`AutoPopover`, `SalvageConfirm`) | 12 |
| Auto-salvage pill | `CONTROL_H // 2` (18) |

Font:

| Piece | Font |
|---|---|
| `button`, `wideButton`, Essence, salvage, clear, popover title | `Enum.Font.BuilderSansBold` |
| Body labels (`label`) | `Enum.Font.BuilderSans` |
| Auto-salvage pill and its warning mark | `Enum.Font.BuilderSansExtraBold` |

Text size: `UiTheme.MIN_TEXT` (14) on bar buttons and Essence. Wide buttons and the salvage label use 15. Popover title uses 18. Help and the unsafe line use 13. The confirm body uses 15. The ask body uses 14. The warning mark uses 16.

Padding (`UIPadding`, left/right then top/bottom):

| Piece | Padding |
|---|---|
| `button` and Essence | 10, 0 |
| Popup panel | 14, 12 |
| `AutoAsk` | 10, 8 |
| Salvage bar | 6, 6 |

List gaps: popup layout, toggle row, and salvage bar use `UiTheme.PAD` (8). The ask list uses 6.

Popup stroke: gold at transparency 0.5, thickness 1. The pill's warning stroke is `warn` at thickness 2, and it is off while auto-salvage is off.

`GearBar` reads `UiTheme.PAD` and `UiTheme.MIN_TEXT` from `src/ReplicatedStorage/Shared/UiTheme.luau`: `PAD = 8`, `MIN_TEXT = 14`. Those two tokens are the only `UiTheme` numbers this bar applies.

### BagCompare

File: `src/ReplicatedStorage/Shared/BagCompare.luau` on `ghost/gear-ui-hooks` @ `53549b6`.

This module sets no `Color3`, no `UICorner`, no `Font`, and no `UIPadding`. Do not invent chrome for it.

What it does set, and what the detail panel must print:

- Headers: `"Nothing equipped in this slot."`, `"Equipped"`, `"Compared with <name> (equipped)"`.
- Boost row, when a forge level is showing: `"Upgrade +N  stats xM"` (`id = "boost"`, `tone = "gain"`).
- Stat marks: `"="` / `"same"`, `"+"` / `"gain"`, `"-"` / `"loss"`. Equal shown text is `"="` even when the raw numbers differ past the printed precision.
- Power line: `"Power  N"`, with the same marks while comparing.

`GearDetail` paints those tones. It does not live in `BagCompare`. `tone("gain")` is `colors.ok` `Color3.fromRGB(110, 210, 140)`. `tone("loss")` is `colors.loss` `Color3.fromRGB(220, 92, 96)`. Any other tone, including `"same"` and `"text"`, uses `colors.text` `Color3.fromRGB(240, 236, 248)`. `GearDetail.DEFAULT` is the table. The compare header uses `colors.ok` when worn and `colors.muted` `Color3.fromRGB(170, 162, 200)` otherwise, and it is hidden when the item is already worn.

### RollReveal

File: `src/ReplicatedStorage/Shared/RollReveal.luau` on `ghost/roll-x10` @ `d3686ba`.

This module sets no `Color3`, no `UICorner`, no `Font`, and no `UIPadding`. Its clock is for one roll, not for an x10 card.

| Name | Value | Where |
|---|---|---|
| `RollReveal.FULL` | 1.65 | full playback, seconds |
| Short playback | 0.7 | header comment, lines 12–13 |
| Instant, and the skip threshold | 0 | same comment |
| `DIM_END` | 0.15 | local |
| `FAST_END` | 0.6 | local |
| `SLOW_END` | 1.3 | local |
| `HOLD_END` | 1.4 | local |
| `GLOW_AT` | 1.0 | local |
| `FLASH_AT` | 1.15 | local |
| `FLASH_WINDOW` | 0.5 | local |
| `FLASH_GAP` | 1/3 | local |
| `FLASH_HOLD` | 0.08 | local |

`RollReveal.skipReady` (line 191) is `duration > 0 and elapsed >= 0`.

The x10 per-card cap is the next file, not this clock.

### Values the three files do not paint

These are the numbers on the widgets the rules name. They are quoted so the screens are not matched by eye. Paths are on the commit in [README.md](README.md).

**Inventory window and cards** (`InventoryHud.luau` on `ghost/gear-ui-hooks`). `COLORS` matches `GearBar` for panel, text, muted, gold, ink, danger, button, and buttonDim. Extra rows: `background` 16, 14, 24; `row` 40, 34, 58; `ok` 110, 210, 140.

| Piece | Value |
|---|---|
| Card corner | 10 |
| Card fill | rarity mixed 18% into row 40, 34, 58 (`tintedRow`) |
| Card border | thickness 2, `Rarities.rgb` |
| Card name | `Enum.Font.BuilderSansBold`, size 13, rarity color |
| Star / level line | `BuilderSansBold`, size 12, gold 255, 196, 64 |
| E badge | text `E`, fill gold, text ink 32, 22, 10, `BuilderSansBold` size 13, corner 10 |
| Focus ring | corner 9, thickness 2, text color |
| Grid gap | `InventoryLayout.CELL_GAP` 8 |
| Window padding / row gap | `InventoryLayout.PAD` 10, `GAP` 6 |
| Tab row gap | 6 |
| Filter row | horizontal list, gap 6, height from `InventoryLayout` row (`ROW_H` 36, `PHONE_ROW_H` 40) |
| Search | `BuilderSans` size 15, corner 6, padding left 10 and right 8, panel fill |
| Filter fit | `fitFilters` shrinks Search and the three dropdowns to the row width. It does not add a horizontal scroll. |

**Detail actions** (`GearDetail.luau` on `ghost/gear-ui-hooks`):

| Piece | Value |
|---|---|
| Fonts | header `BuilderSansBold`, body `BuilderSans` (or the host fonts) |
| Body text size | `UiTheme.MIN_TEXT` (14) |
| Action text size | `UiTheme.MIN_TEXT + 1` (15) |
| Action corner | 8 |
| Gap between EQUIP and UPGRADE | 8 |
| Action row height | `UiTheme.TOUCH` (44) |
| EQUIP fill | 36, 84, 168, text 240, 236, 248 |
| EQUIPPED fill | 46, 70, 60 |
| UPGRADE fill | 255, 190, 60 |
| UPGRADE text | 24, 18, 12 |
| Short or maxed UPGRADE | fill 58, 52, 88, text 170, 162, 200 |
| Icon well | 84 px (`GearDetail.ICON`), corner 10 |
| Padlock gold / grey | 255, 196, 64 / 150, 146, 170 |
| Hero row gap | 10 |
| Name stack gap | 4 |

**x10 summary** (`RollSummaryHud.luau` and `MenuHub.luau` on `ghost/roll-x10`):

| Piece | Value |
|---|---|
| `RollSummary.STEP` | 0.3 |
| Panel | 30, 26, 44, corner 12, gold stroke thickness 2 (gold 255, 205, 90) |
| Tile corner | 8 |
| Tile fill | rarity mixed 22% into 40, 34, 58 |
| Tile border | rarity color, thickness 2 |
| Tile font | `BuilderSansBold` |
| Badge corner | 4, height 16, text size 10, ink 24, 18, 32 |
| NEW badge | 120, 220, 140 |
| Star-up badge (`★ up`) | 255, 205, 90 |
| Salvaged badge | 230, 120, 110 |
| Roll again | fill 255, 205, 90, text 24, 18, 32, `BuilderSansBold` size 16, corner 8 |
| Close | fill 58, 52, 80, text 240, 236, 250, same font and corner |
| Skip | 72 by 30, corner 8, `BuilderSansBold` size 15, fill `UiTheme` `body` 20, 24, 32, text `UiTheme` `text` 244, 240, 252, anchored bottom-right |
| Milestone toast | 220 by 26, corner 13, fill `UiTheme` gold 255, 206, 96 at transparency 0.05, text ink 24, 18, 12, size 14, top center with a 4 px inset |

`UiTheme.CORNER` is 10. `UiTheme` `upgrade` (96, 196, 120) is not the UPGRADE button. The button is `GearDetail` 255, 190, 60.
