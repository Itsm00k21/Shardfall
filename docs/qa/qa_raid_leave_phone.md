# Premade Leave button on a phone

G-080. Where Leave sits past the visible slice while Ready is still on screen. This file does not change code.

The raid row is a fixed frame at offset (120, 132), size 420 by 134 (`RaidHud.luau:154-161`). It does not read `HudLayout`. `placeChip` moves only `EchoChip` (`RaidHud.luau:139-152`). The row's gui is `DeviceSafeInsets` (`MobileShell.luau:8-14`). Measure `ShardfallRaids.AbsoluteSize`. A device inset is already inside that size.

Seven buttons, 64 by 64, in this order: Story, Normal, Board, Practice, Marks, Leave, Ready (`RaidHud.luau:211-230`). The list is horizontal, padding 6, and it wraps (`RaidHud.luau:163-167`). Six fit on the first line because `6 * 64 + 5 * 6 = 414`, which is inside 420. The seventh starts a line at local (0, 70) because `64 + 6 + 64 = 134` fills the frame height.

Screen position is the row origin plus the local cell. Leave is the sixth cell, local x = 350, screen x = 470, right edge 534. Ready is the wrapped cell, screen x = 120, right edge 184, top 202, bottom 266.

| button | screen rect | right | bottom |
|---|---|---|---|
| Story | 120, 132, 64×64 | 184 | 196 |
| Normal | 190, 132, 64×64 | 254 | 196 |
| Board | 260, 132, 64×64 | 324 | 196 |
| Practice | 330, 132, 64×64 | 394 | 196 |
| Marks | 400, 132, 64×64 | 464 | 196 |
| Leave | 470, 132, 64×64 | 534 | 196 |
| Ready | 120, 202, 64×64 | 184 | 266 |

The row frame ends at screen x = 540. Leave's local right edge is 414, so Leave is inside the frame and past a narrow gui. The frame does not set `ClipsDescendants`. The screen edge is the clip.

`RaidToggle` is created `Visible = false` (`RaidHud.luau:114`). `hideStrayButtons` keeps it false (`init.client.luau:813-815`). `LaunchGate.SHOW.raids` is false (`LaunchGate.luau:12`). Open the toggle and the row in Studio before reading rects. A hidden row did not run this plan. This file does not restate the Echo chip (G-070), the Raid toggle rect (G-109), or the gamepad follow-up.

Choice: a button is on screen only when its full 64×64 sits inside `AbsoluteSize`. A clipped Leave is still past the slice.

## Widths

Leave is fully past when the width is 470 or less. Leave is clipped from 471 through 533. Leave is fully inside at 534 and wider. Ready is fully inside horizontally at width 184 or more, and fully inside vertically at height 266 or more.

| viewport | Leave | Ready | this bug |
|---|---|---|---|
| 390×844 | Starts at 470, 80px past the right edge | 120, 202, fully inside | Yes |
| 430×932 | Fully past | Fully inside | Yes |
| 500×900 | Starts at 470, 34px past 500 | Fully inside | Yes |
| 844×390 | Right edge 534 is inside 844 | Bottom 266 is inside 390 | No |
| 800×380 | Inside | Inside | No |
| 1024×768 | Inside | Inside | No |
| 1280×720 | Inside | Inside | No |
| 1440×900 | Inside | Inside | No |

On 390×844, Practice ends at 394, so 4px of it is past, and Marks is fully past. Those two are the same slice. The hole is Leave gone and Ready still tappable.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| LV1 | Portrait phone. Leave is past the right edge and Ready is on the second line, on screen | `RaidHud.luau:154-167`, `RaidHud.luau:211-230`, `MobileShell.luau:13-14` | high | 390×844, hub closed, row open. Story, Normal, and Board are fully inside. Leave's `AbsolutePosition.X` is 470. Ready is at x = 120, y = 202, and the word Ready is readable. A player can ready and cannot leave |
| LV2 | Any safe width from 184 through 533 with height at least 266. Same split | `RaidHud.luau:157-158`, `RaidHud.luau:226-230` | medium | 430×932 and 500×900. Leave is not a full 64px target. Ready is. A width of 534 or more is not this row |
| LV3 | Landscape phone, tablet, laptop, and console fit both | `RaidHud.luau:157-158` | low | 844×390, 800×380, 1024×768, 1280×720, and 1440×900. Leave's right edge is 534 and Ready's bottom is 266. Both are inside. Failing one of these is a different overlap |
| LV4 | A short height clips Ready while Leave can still be on screen | `RaidHud.luau:157-158`, `RaidHud.luau:226-230` | low | Height 200 through 265, width 844. Leave occupies y = 132 to 196. Ready starts at y = 202. Scoring that as LV1 fails the case. LV1 needs Ready's full rect inside and Leave's rect outside |
| LV5 | The parked gate hides the row, so a closed toggle is not a layout pass | `RaidHud.luau:114`, `init.client.luau:813-815`, `LaunchGate.luau:12` | low | Join the plaza and look for Leave. The toggle is hidden, so neither button is on screen. Show the row, then judge LV1. An open hub covers this gui. DisplayOrder of the raid gui is 13 (`RaidHud.luau:98`). Read the rects with the hub closed |

LV1 is the hole on the portrait phone. LV3 is the lock once the width is at least 534 and the height is at least 266.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| LV-1 | 390×844, `ShardfallRaids` at that AbsoluteSize, row `Visible` | Read Leave and Ready `AbsolutePosition` and `AbsoluteSize` | Leave is fully inside the gui and Ready is fully inside. Today Leave starts at x = 470 and Ready is at 120, 202. That fails LV1 |
| LV-2 | 430×932 and 500×900, row open | Same read | Same pass as LV-1. A Leave that crosses the right edge fails LV2 |
| LV-3 | 844×390 and 800×380, row open | Same read | Both buttons are fully inside. Leave's right edge is 534. Ready's bottom is 266 |
| LV-4 | 1024×768, 1280×720, and 1440×900 | Same read | Both buttons are fully inside |
| LV-5 | 390×844, row open | Tap Ready, then look for Leave | Ready invokes `RaidReady`. Leave is on screen and invokes `RaidLeave`. A Ready tap with no Leave button on screen fails LV1 |
| LV-6 | Height 220, width 844, row open | Read both rects | Leave is inside. Ready is past the bottom. Do not file that as LV1 |
| LV-7 | 390×844, fresh join, raids switch off | Look for the Raid toggle | It is hidden. Then show the row and run LV-1. A hidden toggle does not pass the phone |

## Flags

None. Leave and Ready are not paid skips. No live offset in `RaidHud` changes.
