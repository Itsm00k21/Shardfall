# Story Echo chip test plan

G-070. Where the Story Echo chip clips or covers the HP bar. This file does not change code.

The backlog line that `RaidHud` pins `EchoChip` at (248, 16), size 128 by 28, with no safe inset, is closed on this tip. `placeChip` calls `EchoChip.place` and writes that rect (`RaidHud.luau:139-149`). `tests/EchoChip.spec.luau` locks the string `248, 16` as absent (`EchoChip.spec.luau:140-141`). The margin is `UiTheme.safeMargin()`, which is 16 (`UiTheme.luau:19`, `UiTheme.luau:85-87`).

Choice: compare the chip and the HP bar in screen space. They do not share a ScreenGui origin. A pass inside one `AbsoluteSize` is not a pass on the phone.

## Locked rects

Same-space gap is the chip's top minus the HP bar's bottom. The live bar is `HudLayout.health(margin, vx)` (`HudShell.luau:564`). Its bottom is y = 72. The chip rects are locked at `EchoChip.spec.luau:22-29`.

| viewport | chip | live HP | same-space gap | right edge |
|---|---|---|---|---|
| 390×844 | 266, 136, 108×28 | 80, 16, 178×56 | 64px | 374, flush with 390 − 16 |
| 844×390 | 700, 80, 128×28 | 80, 16, 220×56 | 8px | 828, flush with 844 − 16 |
| 800×380 | 656, 80, 128×28 | 80, 16, 220×56 | 8px | 784, flush with 800 − 16 |
| 1280×720 | 1136, 96, 128×28 | 80, 16, 220×56 | 24px | 1264, flush with 1280 − 16 |

In one coordinate space none of these four cover the bar, and none cross the 16px margin. `EchoChip` avoids `HudLayout.health(margin)` with no viewport (`EchoChip.luau:93`, `EchoChip.luau:114`). On a width under 500 that obstacle is the wide 220px bar, and the drawn bar is shorter (`HudLayout.luau:32-53`). Missing the wide bar does not put the chip on the short one.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| EC1 | Landscape phone. The chip and the HP bar use different safe rects, and the same-space gap is only 8px | `MobileShell.luau:13-14`, `RaidHud.luau:98-100`, `HudShell.luau:61-63`, `HudShell.luau:564`, `EchoChip.luau:111-136` | high | 844×390 and 800×380 during a Heartwood pull with Echo above 0. The chip gui is `DeviceSafeInsets`. The HP gui is `CoreUISafeInsets`. Chip DisplayOrder is 13. The HP gui is 30, so the bar paints on top. If the core top inset exceeds the device top inset by more than 8px, the green chip sits under the HP bar and `Echo +N%` is not readable. The right edge is inside that device rect, 16px in. A clip past the screen fails |
| EC2 | Desktop and laptop. The same mismatch, with a 24px gap | `EchoChip.spec.luau:28`, `HudShell.luau:61-63`, `RaidHud.luau:98` | medium | 1280×720, Echo showing. A core top inset more than 24px larger than the device top inset hides the chip under the bar. A smaller difference leaves the chip readable under the bar |
| EC3 | Portrait phone is the regression lock | `EchoChip.spec.luau:22`, `EchoChip.spec.luau:25`, `RaidHud.luau:147-149` | low | 390×844, Echo showing. The chip is 64px under the bar in its own space. It stays readable unless the core top inset exceeds the device top inset by more than 64px. Width is 108, not 128. Pass is the whole `Echo +25%` string visible at TextSize 14 |
| EC4 | A side under 200 still places the 390×844 rect | `RaidHud.luau:143-149`, `EchoChip.luau:54-60`, `EchoChip.spec.luau:68` | high | Width or height under 200, including 199×844, 390×199, and 180×320. `placeChip` pretends the gui is 390×844 and does not call `MobileShell.view`. The chip is drawn at x = 266, width 108, right edge 374, inside a gui that is narrower than that. The chip is cut off. `MobileShell.view` would have used the camera size (`MobileShell.luau:21-38`). This path does not |
| EC5 | The old offset comes back | `EchoChip.spec.luau:140-141`, `HudLayout.luau:32-53` | high | Position (248, 16), size 128×28. On 390×844 the live bar ends at x = 258, so the chip covers 10px of it and its right edge (376) crosses the 16px margin. On 844×390, 800×380, and 1280×720 the bar ends at x = 300, so x = 248 covers the bar's right end. That placement is absent today. A return of it fails |
| EC6 | The fallback rect skips the fit checks | `EchoChip.luau:127-140` | low | A viewport where every slot is blocked. The function still returns the under-pills rect and does not check `inside` or `blocked`. Pass is a rect inside the 16px margin that does not meet the live HP bar. The four locked viewports return before this line |

EC1 is the hole that is still open. EC3 and the same-space table are the regression lock. The label caps at `Echo +25%` (`RaidEcho.luau:28`, `RaidEchoFight.luau:210-219`). The chip has no `TextWrapped` (`RaidHud.luau:121-129`).

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| EC-1 | 844×390, Heartwood, Echo above 0 | Photograph the chip against the HP bar | The whole `Echo +N%` string is readable. It does not sit under the bar. The right edge is on screen |
| EC-2 | 800×380, same pull | Same photograph | Same as EC-1 |
| EC-3 | 1280×720, same pull | Same photograph | The chip is fully readable. A gap under 24px of screen space fails EC2 |
| EC-4 | 390×844, same pull | Same photograph | The chip is under the counters, fully on screen, and not on the HP bar. The label is complete inside the 108px chip |
| EC-5 | Width 199, or height 199 | Open a Heartwood pull that would show Echo | The chip is inside the real gui. A rect whose right edge is 374 on a gui narrower than 374 fails EC4 |
| EC-6 | 390×844, 844×390, 800×380, 1280×720 | Read `chip.Position` | It is not (248, 16), and the size is not a fixed 128×28 on 390×844. The 390×844 size is 108×28 |
| EC-7 | Plaza, Echo at 0 | Look at the top of the screen | The chip is hidden (`RaidEchoFight.chip` returns nil at 0). An empty green pill fails |

## Flags

None. Echo percent is the wipe bonus already in `RaidEcho`. It is not a paid boost. A third argument, including `paid = true`, does not move the rect (`EchoChip.luau:22-23`).
