# Raid toggle phone test plan

G-109. Where `RaidToggle` covers the HP bar or the left rail. This file does not change code.

`RaidHud.start` places `RaidToggle` at offset (120, 60), size 96 by 64 (`RaidHud.luau:103-106`). `placeChip` writes the Echo chip only (`RaidHud.luau:139-152`). The toggle stays on that offset at every viewport. It is created hidden (`RaidHud.luau:114`). `hideStrayButtons` sets it hidden again (`init.client.luau:887-899`, `init.client.luau:904-912`). Nothing in `src/` sets it visible. The rects below are the cover if a later change shows it.

The toggle's gui uses device safe insets (`RaidHud.luau:100`, `MobileShell.luau:13-14`). The HP bar and the rail use core safe insets (`HudShell.luau:63-64`, `HudShell.luau:271-272`). The table compares them in one space, margin 16 (`UiTheme.safeMargin`, `UiTheme.luau:85-87`). `HudLayout.health` is `HudLayout.luau:32-54`. `HudLayout.railFit` is `HudLayout.luau:434-523`. Overlap is `HudLayout.overlaps` (`HudLayout.luau:756-758`).

Choice: the launch sizes are the phone, tablet, laptop, and console sizes from the layout matrix. The toggle is 120,60 96×64 on every row. Its right edge is 216. Its bottom is 124.

## Locked rects

HP overlap is the top 12px of the toggle (y 60 through 72) where the bar's right edge is past x 120. The rail's right edge on these sizes is 80 (button 64) or 60 (button 44). The toggle starts at x 120.

| viewport | HP | rail | covers |
|---|---|---|---|
| 390×844 | 80,16 178×56 | 16,210 64×424, button 64 | HP 96×12. Rail clear by 40px |
| 375×667 | 80,16 163×56 | 16,121 64×424, button 64 | HP 96×12. Rail clear |
| 320×568 | 80,16 108×56 | 16,72 64×424, button 64 | HP 68×12. Rail clear |
| 844×390 | 80,16 220×56 | 16,80 44×294, button 44, gap 6 | HP 96×12. Rail right edge 60 |
| 800×380 | 80,16 220×56 | 16,80 44×284, button 44, gap 4 | HP 96×12. Rail clear |
| 667×375 | 80,16 220×56 | 16,80 44×279, button 44, gap 3 | HP 96×12. Rail clear |
| 1024×768 | 80,16 220×56 | 16,172 64×424, button 64 | HP 96×12. Rail clear |
| 1280×720 | 80,16 220×56 | 16,148 64×424, button 64 | HP 96×12. Rail clear |
| 1440×900 | 80,16 220×56 | 16,238 64×424, button 64 | HP 96×12. Rail clear |
| 1920×1080 | 80,16 220×56 | 16,328 64×424, button 64 | HP 96×12. Rail clear |
| 252×600 | 80,16 40×56, right edge 120 | 16,88 64×424 | Neither. The edges meet and `overlaps` is false |
| 200×350 | 80,16 0×56 | 80,23 44×304, button 44 | Rail covers x 120–124 of the toggle, full 64px tall. HP does not |

Width 253 and up, the portrait formula's bar reaches past x 120, so the 12px HP cover is back (253×600 is 1×12). Width 212 or less and height 399 or less is the rail case: the column cannot sit under the portrait, it slides to x 80, and a zero-width HP bar does not pull it back (`HudLayout.luau:466-473`, `HudLayout.luau:484-520`).

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| RT1 | Shown toggle covers the bottom 12px of the HP bar on every launch size | `RaidHud.luau:104-106`, `HudLayout.luau:32-54`, `HudShell.luau:595-597`, `HudShell.luau:62` | high | Set `RaidToggle.Visible` true. 390×844, 844×390, 800×380, 1024×768, 1280×720, 1440×900. The brown 96×64 button's top 12px sits on the HP bar. HP DisplayOrder is 30 and the toggle's gui is 13, so the bar paints over the word Raid. The health frame does not set Active (`HudShell.luau:136-141`), so the fail is the covered label |
| RT2 | The left rail stays clear of the toggle on those same sizes | `HudLayout.luau:434-523`, `HudShell.luau:615-618`, `HudShell.luau:270` | low | The sizes in RT1. Rail right edge is 80 or 60. Toggle left is 120. A rail button on the toggle fails this lock. Rail DisplayOrder 85 is above the toggle, so a real overlap would hide the button under a rail icon |
| RT3 | A gui 212 wide or narrower, and 399 tall or shorter, puts the rail on the toggle | `HudLayout.luau:466-473`, `HudLayout.luau:37-51` | medium | 200×350, toggle shown. Rail is 80,23 44×304. It covers the toggle's left 4px. 200×400 does not: the rail fits under the portrait at x 16. 213×380 does not: the HP move pulls the rail back to x 16 |
| RT4 | The two safe rects are not the same origin | `MobileShell.luau:13-14`, `HudShell.luau:63-64`, `HudShell.luau:271-272` | medium | Toggle shown on 390×844. Same-space cover is 12px. A core top inset larger than the device top inset moves the HP bar down. The cover grows while that extra is under 108px. At 108px the bar's top meets the toggle's bottom and `overlaps` is false. A photograph that only checks one gui's offsets can miss this |
| RT5 | Join leaves the button hidden, so the cover is not on screen yet | `RaidHud.luau:114`, `init.client.luau:892-894`, `init.client.luau:1567` | low | Fresh join, any size in RT1. `RaidToggle` is not visible. The position is still (120, 60). Hiding it is not a pass of RT1 |

RT1 is the hole once the button is shown. RT2 is the regression lock for the rail on a real phone. RT5 is why a join screenshot looks clean.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| RT-1 | 390×844. Set `RaidToggle.Visible` true | Photograph the toggle against the HP bar | The button is not on the bar. Today the top 12px is. The whole "Raid" label is readable |
| RT-2 | 844×390, 800×380, and 667×375. Toggle shown | Same photograph, then read the rail frame | Same HP fail as RT-1 until it is moved. The rail's right edge stays left of x 120 |
| RT-3 | 1280×720, 1440×900, and 1024×768. Toggle shown | Same photograph | The top 12px is still on the 220px bar. A desktop width does not clear it |
| RT-4 | 200×350. Toggle shown | Read rail position and the toggle | They do not meet. Today the rail covers x 120–124 |
| RT-5 | 252×600, then 253×600. Toggle shown | Read HP right edge and the toggle | 252 meets at x 120 and does not overlap. 253 overlaps by 1px. Both rails stay at x 16 |
| RT-6 | Fresh join, toggle left as authored | Look beside the HP bar | The button is hidden. Position is still (120, 60), size 96×64 |

## Flags

None. The toggle does not sell a queue, a skip, or a raid reward. Showing it does not change `LaunchGate.SHOW.raids`.
