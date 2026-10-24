# Premade Leave button on a phone

G-080. Where Leave is past the visible slice while Ready is still on screen. This file does not change code.

The raid row is a fixed frame at (120, 132), size 420 by 134 (`RaidHud.luau:154-158`). Seven buttons are 64 by 64 with 6px of horizontal padding (`RaidHud.luau:163-167`, `RaidHud.luau:193-196`). The frame fits six buttons on the first line and wraps the seventh. `64 * 6 + 6 * 5 = 414`, which is inside 420. The seventh starts at local y = 70.

The sixth `button()` call is Leave (`RaidHud.luau:226`). Ready is the seventh (`RaidHud.luau:229`). The list never sets `SortOrder` or `LayoutOrder` (`RaidHud.luau:163-167`, `RaidHud.luau:193-208`). The engine default picks the order. Name order paints Leave second and Ready sixth. Add order paints Leave sixth and wraps Ready. The sixth painted tile is at screen x = 470 either way. On a 390-wide phone that tile is off the right edge, and the wrapped tile at x = 120 stays on.

`RaidHud` does not call `HudLayout.health` or `HudLayout.railFit`. The row does not move on a phone. The HP bar's bottom is y = 72 (`HudLayout.luau:32-53`, margin 16, height 56). The row starts at y = 132, so it does not cover the bar. Coordinates are inside the device safe rect (`MobileShell.luau:9-14`). `ClipsDescendants` is unset, so the screen edge is the clip, not the 420 frame.

Choice: read the pixels. Name order is the pass when Leave is on and Ready is off. Add order is the pass when Leave is off and Ready is on. Do not pick one without looking.

## Painted tiles

Screen origin is (120, 132). Step is 70. The wrapped tile is local (0, 70).

| order | name | screen rect | right | bottom |
|---|---|---|---|---|
| 1 | Board | 120, 132, 64×64 | 184 | 196 |
| 2 | Leave | 190, 132, 64×64 | 254 | 196 |
| 3 | Marks | 260, 132, 64×64 | 324 | 196 |
| 4 | Normal | 330, 132, 64×64 | 394 | 196 |
| 5 | Practice | 400, 132, 64×64 | 464 | 196 |
| 6 | Ready | 470, 132, 64×64 | 534 | 196 |
| 7 | Story | 120, 202, 64×64 | 184 | 266 |

Name order is the reading when an unset list sorts by Name. Leave's right edge is 254. Ready's left edge is 470. Any width that cuts Leave also cuts Ready. No viewport in this order has Leave past the slice and Ready still on screen.

## Call order

This is the order of the `button()` calls, which is what "Leave is the sixth" names. It is not the painted row while `SortOrder` stays unset.

| order | name | screen rect | right | bottom |
|---|---|---|---|---|
| 6 | Leave | 470, 132, 64×64 | 534 | 196 |
| 7 | Ready | 120, 202, 64×64 | 184 | 266 |

Leave is fully past the right edge when the width is 470 or less. Ready is fully on screen when the width is at least 184 and the height is at least 266.

| viewport | Leave | Ready | asked pair |
|---|---|---|---|
| 390×844 | fully past (left 470) | on (120–184, 202–266) | Yes |
| 360×780 | fully past | on | Yes |
| 320×568 | fully past | on (right edge 184) | Yes |
| 480×854 | 10px on screen, the rest past | on | Partial |
| 534×900 | flush, fully on | on | No |
| 667×375 | on | on | No |
| 800×380 | on | on | No |
| 844×390 | on | on | No |
| 1024×768 | on | on | No |
| 1280×720 | on | on | No |
| 1440×900 | on | on | No |
| 390×240 | fully past the right edge | bottom 266 is past the bottom | No. Ready is past too |

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| LV1 | Name order. Ready is past a narrow phone. Leave is not | `RaidHud.luau:163-167`, `RaidHud.luau:211-230` | high | 390×844, 360×780, and 320×568 with the raid row open, if the tiles sort by Name. Leave (190–254) is on screen. Ready (470–534) is off the right edge. Story is on the second line at x = 120. A pass that only checks Leave misses Ready |
| LV2 | Call order. Leave is past the slice and Ready is still on screen | `RaidHud.luau:226-230`, `RaidHud.luau:157-158` | high | Same phones, only if the list keeps add order. Leave is at x = 470 and off the screen. Ready wraps to x = 120, y = 202, and stays on screen. 390×844, 360×780, and 320×568 are the three. 480×854 shows a sliver of Leave |
| LV3 | A short height clips the wrapped tile | `RaidHud.luau:157-158`, `RaidHud.luau:165-166` | medium | Height 240 to 265. The first line (bottom 196) stays. The wrapped tile (bottom 266) is past the bottom. In the painted order that tile is Story. In call order it is Ready. 844×390 and 800×380 are tall enough (390 and 380) and wide enough (right edge 534) |
| LV4 | Wide safe rects show all seven | `MobileShell.luau:9-14` | low | 667×375, 800×380, 844×390, 1024×768, 1280×720, and 1440×900. Every button, including Leave and Ready, is inside the safe rect in both orders |
| LV5 | The row never reads the HP bar or the rail | `HudLayout.luau:32-53`, `HudLayout.luau:333-341`, `RaidHud.luau:154-158` | low | 390×844. The bar ends at y = 72. The row starts at y = 132. Leave does not cover the bar. The row's x does not change when `railFit` moves the rail. A phone width does not slide Leave back on screen |

LV1 and LV2 are the two readings of one unset list. A 390-wide phone hides whichever tile is sixth. The Story Echo chip and the gamepad map are not this plan.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| LV-1 | 390×844, raid row open, safe rect is the gui | Read Leave and Ready | Leave is fully on screen. Ready is fully past the right edge. Scoring Leave as off fails LV1 |
| LV-2 | 360×780 and 320×568 | Same read | Same as LV-1. Ready's left is 470 |
| LV-3 | 480×854 | Same read | Ready is partly past (10px visible). Leave is fully on |
| LV-4 | 534×900, 667×375, 800×380, 844×390 | Same read | Leave and Ready are fully inside the safe rect |
| LV-5 | 1024×768, 1280×720, 1440×900 | Same read | All seven buttons are inside |
| LV-6 | 390×240 | Same read | The wrapped tile is past the bottom. The first line is not |
| LV-7 | Harness only. Set `SortOrder` to LayoutOrder and leave every `LayoutOrder` at 0. 390×844 | Read Leave and Ready | Leave is past the right edge. Ready is on screen at (120, 202). That is LV2. Do not save the harness |
| LV-8 | 390×844, row open | Read the row against the HP bar | The row's top is y = 132. It does not cover the bar. Leave is tappable |

## Flags

None. Leave drops a seat. It does not sell one. No paid control is on this row.
