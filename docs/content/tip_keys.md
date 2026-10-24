# Loading tip key sentences

G-110. Replacement sentences for `tip_01` and `tip_02`. The live keys disagree with those two lines. This file does not change `LoadingTips.luau`, `docs/content/loading_tips.md`, or `docs/data/loading_tips.luau`.

`tip_01` says attack is E, dodge is Q, heavy is R, and sprint is Shift (`LoadingTips.luau:38`). `tip_02` says class skills are 1 and 2 and the ultimate is F (`LoadingTips.luau:39`).

Live binds: there is no attack key in `Keybinds.COMBAT` (`Keybinds.luau:20-32`). A mouse click or a touch is the light attack (`CombatHud.luau:1067-1073`). Gamepad light attack is `ButtonR1` while the menu is closed (`PadLight.luau:18`, `ActionBar.luau:1336-1350`). Dodge is `LeftShift`, and the bar also sinks `RightShift` (`Keybinds.luau:21`, `ActionBar.luau:1321-1335`). Both display as Shift (`Keybinds.luau:117-119`). Heavy stays R (`Keybinds.luau:22`). F is interact, and only while a prompt is showing (`Keybinds.luau:23`, `ActionBar.luau:1385-1393`). A proximity prompt that arrives on E is rewritten to F (`ActionBar.luau:1387-1388`).

The default bar puts the four class skills on keys 1 through 4 and the ultimate on 5 (`ActionSlots.luau:164-179`). F is not a slot (`ActionSlots.luau:9-10`).

Choice: drop sprint from `tip_01`. `Keybinds.SPRINT` still names LeftShift and RightShift (`Keybinds.luau:35`), and `Keybinds.owner` can return `"sprint"` for them (`Keybinds.luau:166-169`), but the bar sinks both as dodge. A tip that says sprint is Shift teaches the dodge key. `tip_09` already says WASD moves you. `tip_07` already says controller heavy is ButtonX and keyboard heavy stays R, so these sentences do not repeat ButtonX.

Each replacement is under 90 characters. Counts include spaces. Visual note for both: loading-card text only, no key-cap icon, so the art pass does not draw an E or a Q.

## Sentences

| id | chars | old | chars | replacement | wrong keys dropped |
|---|---|---|---|---|---|
| `tip_01` | 53 | Attack is E. Dodge is Q. Heavy is R. Sprint is Shift. | 62 | Attack is click, tap, or ButtonR1. Dodge is Shift. Heavy is R. | E, Q, and sprint on Shift |
| `tip_02` | 44 | Class skills are 1 and 2. The ultimate is F. | 58 | Class skills are 1 to 4. The ultimate is 5. F is interact. | F as the ultimate. Skills are not only 1 and 2 |

## What a player should read

| key | does | does not |
|---|---|---|
| Click or tap | Light attack | — |
| ButtonR1 | Light attack while the hub is closed | Heavy. ButtonX stays heavy |
| Shift | Dodge | Sprint. Q is not dodge |
| R | Heavy | The Roll tab. Roll stays T |
| 1 to 4 | The four class skills | — |
| 5 | The ultimate | F |
| F | Interact, while a prompt is up | The ultimate |

## Flags

None. The sentences name keys. They do not sell a bind, a skip, or a power.
