# Layout test matrix

G-061. Phone, tablet, laptop, and console sizes for every panel the launch build can show. This file does not change code.

Rects below are what `HudLayout`, `ShellLayout`, and `ActionSlots.placement` return at margin 16 (`UiTheme.safeMargin`, `UiTheme.luau:85-87`). Coordinates are inside the safe GUI. A device inset can move the whole GUI. It does not change these numbers.

Choice: the code has no "laptop" name. Laptop in this matrix is the `pc` breakpoint. Phone is tested in both orientations, because `HudLayout.breakpoint` returns `"phone"` when the width is under 900 or the height is under 500 (`HudLayout.luau:369-380`).

Launch rail is six buttons: Hero, Bag, Pets, Roll, Shop, Settings (`HudShell.luau:42-48`). Mastery is hidden (`HudShell.luau:242`). Raids, Market, and Shard Pass stay off (`LaunchGate.luau:11-26`). The hub draws at DisplayOrder 80 (`MenuHub.luau:104`) over the shell at 30 (`HudShell.luau:61`).

`docs/qa/qa_menu.md` M3 said a 390-tall view covers the portrait at y=17. `railFit` now slides the rail to the right of the portrait when they overlap (`HudLayout.luau:334-342`). On 844×390 that slide lands on the HP bar. M2's width-390 pill row is not reopened.

## Sizes

| name | pixels | `breakpoint` | action bar the HUD uses |
|---|---|---|---|
| Phone portrait | 390 × 844 | phone | 2×4, because the breakpoint is phone (`HudLayout.luau:383-387`) |
| Phone landscape | 844 × 390 | phone | 2×4 from the breakpoint. `ActionBar` also treats width under 700 as mobile (`ActionBar.luau:694`). 844 is not under 700, so a keyboard at this size keeps the desktop row unless `mobile()` is true |
| Tablet | 1024 × 768 | tablet | one row of 8 |
| Laptop | 1440 × 900 | pc | one row of 8 |
| Console | 1280 × 720 | console | one row of 8 |

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| L1 | On a short phone the rail moves off the portrait and onto the HP bar | `HudLayout.luau:334-342`, `HudLayout.luau:32-53` | high | 844×390. Portrait is 16,16 56×56. Rail is 80,43 44×304. HP is 80,16 220×56. The rail covers the left 44px of the HP bar from y=43 to y=72. The six buttons still fit. They are not on the portrait |
| L2 | The hub covers the equip prompt on every size in this matrix | `HudLayout.luau:170-174`, `HudLayout.luau:211-219`, `MenuHub.luau:104`, `HudShell.luau:61` | high | Prompt is up and the hub is open. Equip and Keep sit under the hub. Phone portrait: prompt 98,212 160×88, hub 55,102 280×640. Laptop: prompt 510,212 420×88, hub 290,130 860×640 |
| L3 | The open hub covers the top of the action cluster on phone, tablet, and console | `HudLayout.luau:211-219`, `HudLayout.luau:383-387`, `ActionSlots.luau:602-654` | medium | Hub open. Phone portrait cluster is 158,600 216×140 and the hub runs to y=742. Console cluster is 356,604 568×100 and the hub runs to y=640. Laptop does not: hub ends at y=770 and the cluster starts at y=784 |
| L4 | The Forge sheet is 140px wide on a portrait phone and 86px tall on a landscape phone | `Ui.luau:377-381`, `ShellLayout.luau:239-255` | high | Haven Forge opens the legacy panel. 390×844: 16,140 140×540. 844×390: 16,140 303×86. Upgrade rows clip. The live action cluster is not this panel |
| L5 | The legacy 7-slot bar is off the right edge of a portrait phone | `ShellLayout.luau:146-154` | medium | 390×844. `actionBar` is 88,768 552×64 and ends at x=640. Door and Forge use that y. If a legacy thumb row is still visible, it clips. The live cluster stays on screen at 158,600 216×140 |
| L6 | Gold and Shards use a 3-pill rect while Mastery is hidden | `HudShell.luau:240-243`, `HudLayout.luau:71-103` | medium | Portrait phone: pills 266,16 108×112, three stacked slots, Mastery invisible. The empty slot is still in the column. It must not cover the HP bar (HP ends at x=258) |
| L7 | The daily board's first rect crosses the pill column | `LoopHud.luau:615-616`, `LoopHud.luau:300-314` | medium | Board opens before `LoopHud.layout` shrinks it. Anchor right, top 72, 280×220. On 390×844 that is x=102, which crosses the pill column at x=266. Pass only if the fitted board misses Gold and Shards |
| L8 | Bag cells are 228px tall, so a short hub body scrolls | `HudLayout.luau:257-296`, `HudLayout.luau:238-246` | low | Phone portrait hub body is 156×576 inside the panel. Eight cards are one column, 1908px of content. Lock and Equip stay in the cell. The page scrolls. It does not squash the cell |

L1 is the overlap that is still open on the short phone. L2 is the prompt under the hub. L4 is the Forge sheet.

## Matrix

Pass means the rect is inside the viewport, misses the portrait and the HP bar, and a 44px target stays 44px. Hub pages share one frame: Hero, Bag, Pets, Roll, Shop, Settings.

| panel | 390×844 | 844×390 | 1024×768 | 1440×900 | 1280×720 |
|---|---|---|---|---|---|
| Portrait | 16,16 56×56 | 16,16 56×56 | 16,16 56×56 | 16,16 56×56 | 16,16 56×56 |
| HP | 80,16 178×56 | 80,16 220×56 | 80,16 220×56 | 80,16 220×56 | 80,16 220×56 |
| Pills | 266,16 108×112 | 488,48 340×32 | 668,48 340×32 | 1084,52 340×36 | 924,52 340×36 |
| Rail | 16,210 64×424, button 64 | 80,43 44×304, button 44. Fails L1 | 16,172 64×424, button 64 | 16,238 64×424, button 64 | 16,148 64×424, button 64 |
| Toast host | 98,80 160×124 | 212,80 420×124 | 302,80 420×124 | 510,80 420×124 | 430,80 420×124 |
| Equip prompt | 98,212 160×88. Under the hub | 212,212 420×88. Under the hub | 302,212 420×88. Under the hub | 510,212 420×88. Under the hub | 430,212 420×88. Under the hub |
| Hub | 55,102 280×640 | 118,43 607×304 | 143,84 737×599 | 290,130 860×640 | 210,79 860×561 |
| Bag grid | 1 column, cell 156×228, scrolls | 3 columns, cell 141×228, scrolls | 4 columns, cell 135×228, fits 8 | 5 columns, cell 130×228, fits 8 | 5 columns, cell 130×228, fits 8 |
| Action cluster | 158,600 216×140, slot 48, 2×4 | Breakpoint says 628,242 200×132, slot 44, 2×4. A keyboard with width 844 uses the 8-wide row unless `mobile()` is true | 228,652 568×100, slot 64 | 436,784 568×100, slot 64. Clear of the hub | 356,604 568×100, slot 64. Top 36px under the hub |
| Heavy chip | Shown only when mobile is true. Same size as Dodge, one 8px gap above it (`HeavyChip.luau:50-65`) | Same rule. Hidden when `HeavyChip.show` is false | Hidden | Hidden | Hidden |
| Forge sheet | 16,140 140×540. Fails L4 on width | 16,140 303×86. Fails L4 on height | 16,140 360×464 | 16,140 360×596 | 16,140 360×416 |
| Class sheet | Same band as `menuSheet`: 16,72 358×420 (`ShellLayout.luau:350-368`) | 222,72 400×230 | 312,72 400×420 | 520,72 400×420 | 440,72 400×420 |
| Door strip | 16,688 200×72 | 68,234 420×72 | 158,612 420×72 | 366,744 420×72 | 286,564 420×72 |
| Stamp | Hidden on touch (`HudLayout.luau:354-356`) | Hidden on touch | Shown if not touch: x=80, y=736, 140×16 | x=80, y=868, 140×16 | x=80, y=688, 140×16 |
| Daily board | Open it. Fitted rect misses the pills. The 280×220 starter rect does not | Same | Same | Same | Same |
| Market, Raids, Pass | No rail button. Screen stays hidden or disabled | Same | Same | Same | Same |

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| LY-1 | 844×390, hub closed, touch on | Read portrait, HP, and rail | Rail does not cover the portrait or the HP bar. Today it covers the HP bar, as in L1 |
| LY-2 | 390×844, hub closed | Read portrait, HP, pills, rail | 8px between HP (ends x=258) and pills (x=266). Rail at x=16 does not touch the portrait. Mastery is not drawn |
| LY-3 | Each size, hub closed, then open | Toggle an equip prompt while the hub is open | Equip and Keep are readable and tappable. A prompt fully under the hub fails L2 |
| LY-4 | Each size, hub open, then closed | Press a cluster slot and the rail | With the hub open, a covered slot does not fire. With the hub closed, every slot is on screen and at least 44px |
| LY-5 | 390×844 and 844×390 | Open Forge from Haven | The upgrade list scrolls inside the sheet. A 140px width or an 86px height that clips Upgrade fails L4 |
| LY-6 | 844×390 with a keyboard, touch off | Read the action cluster | One row of 8, unless `mobile()` is true. It must not also show the 2×4 cluster |
| LY-7 | Phone, touch on | Look above Dodge | Heavy is visible, the same size as Dodge, and one gap above it. Desktop sizes hide it |
| LY-8 | Each size | Open Bag with 8 items | Cells stay at least 228px tall. A short page scrolls. Lock and Equip stay in the cell |
| LY-9 | Each size | Open the daily board | The board misses Gold, Shards, the HP bar, and the action cluster |
| LY-10 | Each size, LaunchGate flags off | Look for Market, Raids, and Pass | No rail button and no visible panel. The six KEEP buttons still open |
| LY-11 | 390×844 | Look for a 7-slot bar along the bottom | It is not drawn. If it is drawn, it fails L5. The 2×4 cluster is the live bar |
| LY-12 | Laptop and console, touch off | Read the stamp | It sits at x=80 and does not cover the cluster. A phone hides it |

## Flags

None. No paid control is on these panels. Text scale is not in these rects. A scale above 1 can clip pill text without moving the frames (`HudShell.luau:544-569` places from the viewport, not from the text).
