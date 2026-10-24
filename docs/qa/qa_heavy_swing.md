# Heavy swing test plan

G-069. Local slash and server swing for the Heavy chip and for keyboard R. This file does not change code.

The backlog line that `onHeavy` calls `CombatHud.swing(true)` only is closed on this tip. The chip and R both call `CombatStage.swing(true)` and then `CombatHud.swing(true)`.

Choice: ButtonX is the same `InputBegan` branch as R (`CombatHud.luau:941-947`). `docs/qa/AUDIT_FOLLOWUPS.md` already records that T-171 plays the slash for R and ButtonX. This plan does not reopen that gamepad note.

What is still missing is the light click. Mouse and touch call `CombatHud.swing(false)` and never call `CombatStage.swing`.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| H1 | Closed for the chip. `onHeavy` plays the slash, then fires the remote with `charged` true | `ActionBar.luau:666-667`, `init.client.luau:1313-1316`, `CombatStage.luau:171-190`, `CombatHud.luau:136-142` | low | Phone, hub closed. One Heavy tap. One heavy slash, one `Attack` with the fifth argument true. A tap that only fires the remote fails |
| H2 | Closed for R when the key is not processed. The same two calls run | `CombatHud.luau:933-947`, `Keybinds.luau:20-22` | low | Hub closed. Press R. One heavy slash and one heavy remote. No character: `CombatStage.swing` returns before the slash (`CombatStage.luau:173-176`) and the remote still fires |
| H3 | Mouse and touch still skip the local slash | `CombatHud.luau:949-954` | high | Hub closed. Click or tap the world. The server can land a light hit. No sword slash and no local combo step. The on-screen Attack button is not this path. That button calls `onLight`, which does both (`init.client.luau:1309-1311`, `ActionBar.luau:669-671`) |
| H4 | One Heavy tap can also take the touch branch | `ActionBar.luau:666-667`, `CombatHud.luau:949-954` | medium | Phone. One Heavy tap sends the heavy pair and, if the touch is not processed, a second light `Attack`. Pass is one heavy remote and no light remote |
| H5 | A processed R plays nothing | `CombatHud.luau:933-935` | medium | Hub open. The menu sink eats R. No slash and no remote. Hub closed, R works as H2. A text box that marks R processed also plays nothing |
| H6 | The chip is easy to miss on a wide window | `HeavyChip.luau:63-65`, `ActionBar.luau:724-731` | low | `show` is true only when the flag is exactly true. Width under 700 forces that flag (`ActionBar.luau:694`). A desktop width hides the chip and keeps R |

H3 is the hole that is still open. H1 and H2 are regression locks.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| HV-1 | Phone, character spawned, hub closed, in a run | Tap Heavy once | One slash marked Heavy (`CombatStage.luau:190`). One `Attack` with `charged` true. The combo step on the client matches the server step |
| HV-2 | Keyboard, hub closed, in a run | Press R once | Same as HV-1. ButtonX is the same branch and is not a separate case here |
| HV-3 | Hub closed, no character | Tap Heavy, then press R | Neither call slashes. The remote may still fire. A slash with no character fails |
| HV-4 | Hub closed | Click the world, then tap empty space | Each one either plays a light slash and sends one light `Attack`, or sends nothing. A light hit with no slash fails H3 |
| HV-5 | Phone, hub closed | Tap the on-screen Attack button | One light slash and one `Attack` with `charged` false. This path already calls both |
| HV-6 | Phone, hub closed | Tap Heavy once and count remotes | One heavy `Attack`. Zero light `Attack`s from that tap |
| HV-7 | Hub open | Press R, then close the hub and press R | Open: no slash and no remote. Closed: HV-2 |
| HV-8 | Width 390 and width 1440 | Look above Dodge | 390 shows Heavy when mobile is true. 1440 hides it. R still heavies on both |
| HV-9 | `CombatHud.start` did not get `Attack` | Tap Heavy | No remote. The local slash is allowed only when the player can tell the swing was not sent. A silent local heavy fails |

## Flags

None. Heavy is the existing 1.75 combat multiplier. It is not a paid upgrade. No gamepad chord from `docs/qa/AUDIT_FOLLOWUPS.md` is reopened.
