# Glass Kestrel dodge flash

QA checklist for T-158.

G-081. Case list for the Glass Kestrel flash. T-158 replaces G-081. This file does not change code.

`PetFlash.should(keyName, effect)` returns true only for `LeftShift` and `RightShift` when the equipped effect is `"flash"`. `LeftShift` is `Keybinds.COMBAT.dodge` (`Keybinds.luau:19`). `RightShift` is the other dodge name (`Keybinds.luau:92`). Q does not flash. `processed` is not an argument. The caller must not return early because `processed` is true.

`PetRoster` names the ability "Dodge flash" and the effect `"flash"` (`PetRoster.luau:38-42`). The pane is the full-screen `Dodge` frame on `ShardfallPetAura`, color `(186, 230, 255)`, transparency `1` at rest (`PetAura.luau:30-37`). A true result writes `0.45`, then `1` after `0.12` seconds (`PetAura.luau:73-76`). Do not change the color.

The listener calls `PetFlash.should` and does not read `processed` (`PetAura.luau:64-67`). `ShardfallDodge` binds both Shift keys, calls `onDodge`, and returns Sink (`ActionBar.luau:707-722`), so a real dodge arrives processed. That sink does not cancel the flash.

A focused text box does. After `should` returns true, the listener returns when `GetFocusedTextBox()` is set (`PetAura.luau:70-72`). Chat is not a dodge. The action bar does not focus a text box, so a sunk Shift still flashes.

The on-screen Dodge button calls `onDodge` from `ActionBar` (`ActionBar.luau:346`, `ActionBar.luau:522`). That button does not flash in T-158. T-106 owns `ActionBar.luau`. Treat the chip as a follow-up, not a pass.

`ButtonX` stays false. T-166 closed gamepad dodge on ButtonY. `PetFlash.should("ButtonY", "flash")` is true. ButtonX stays heavy and still does not flash.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| R1 | A Shift dodge never flashes | `PetAura.luau:64-67`, `PetFlash.luau:27-32`, `ActionBar.luau:707-722` | high | LeftShift or RightShift dodges. The pane stays at transparency `1`. |
| R2 | The listener bails on `processed` | `PetAura.luau:64`, `ActionBar.luau:717` | high | Sink already marked the dodge processed. An early return skips the flash. |
| R3 | Q flashes | `PetFlash.luau:28-30`, `PetAura.luau:65` | medium | Q, with Glass Kestrel equipped, paints the pane. Q is not a dodge. |
| R4 | The on-screen chip is scored as a pass | `ActionBar.luau:346`, `ActionBar.luau:522` | medium | The Dodge button runs `onDodge` and the pane flashes. T-158 does not include that button. |
| R5 | Another effect flashes | `PetFlash.luau:32`, `PetRoster.luau:22-42` | low | Shardjaw (`collect`) or Thorn Lantern (`ping`) paints the pane. |
| R6 | ButtonX or a paid flag flips the answer | `PetFlash.luau:27-32`, `Keybinds.luau:37`, `docs/qa/AUDIT_FOLLOWUPS.md` | low | `ButtonX` flashes, or `paid` / Robux blocks a Shift flash. |
| R7 | Chat Shift flashes, or a text box blocks a real dodge | `PetAura.luau:68-72` | medium | Typing Shift in chat paints the pane, or a dodge with no text box stays dark. |

## Cases

Equip means `PetRoster.equippedEffect` is the effect below. Pass means the pane hits transparency `0.45` and returns to `1` at about `0.12` seconds, color unchanged. Fail means the pane never leaves `1`.

| case | equip | do this | `PetFlash.should` | flash |
|---|---|---|---|---|
| KF-1 | `glass_kestrel` / `flash` | LeftShift, press begin, including when `processed` is true | true | pass |
| KF-2 | `glass_kestrel` / `flash` | RightShift, press begin, including when `processed` is true | true | pass |
| KF-3 | `glass_kestrel` / `flash` | Q | false | fail (stays `1`) |
| KF-4 | `glass_kestrel` / `flash` | Tap the on-screen Dodge button | not this row | fail (stays `1`). Follow-up for T-106, not a pass |
| KF-5 | `glass_kestrel` / `flash` | LeftShift while the hub is open and no text box is focused. `ActionBar` returns Pass (`ActionBar.luau:713-714`), so `onDodge` does not run | true if the key name still arrives | pass when `InputBegan` delivers `LeftShift`. `processed` does not cancel it |
| KF-6 | `shardjaw` / `collect` | LeftShift | false | fail (stays `1`) |
| KF-7 | `thorn_lantern` / `ping` | RightShift | false | fail (stays `1`) |
| KF-8 | no pet | LeftShift | false | fail (stays `1`) |
| KF-9 | `glass_kestrel` / `flash` | `ButtonX` | false | fail (stays `1`). ButtonX is heavy. ButtonY is the dodge (T-166) |
| KF-10 | `glass_kestrel` / `flash` | LeftShift while a text box is focused | true | fail (stays `1`). `PetAura.luau:70-72` returns after `should` |

KF-6 still sets the character attribute `ShardfallCollect` from the heartbeat (`PetAura.luau:84-86`). KF-7 still shows `KeyPing` when `shardKeys` is above 0 (`PetAura.luau:91`). The flash change must not stop those two.

## Pure check

`PetFlash.should(keyName, effect)`. The first argument is `KeyCode.Name`. It is not an action id.

| keyName | effect | result |
|---|---|---|
| `"LeftShift"` | `"flash"` | true |
| `Keybinds.COMBAT.dodge` | `"flash"` | true |
| `"RightShift"` | `"flash"` | true |
| `"Q"` | `"flash"` | false |
| `"LeftShift"` | `"collect"` | false |
| `"LeftShift"` | `"ping"` | false |
| `"LeftShift"` | nil | false |
| `"ButtonX"` | `"flash"` | false |

A third argument (`paid`, a product id, Robux, `cost`, `skip`) does not flip a Shift flash and does not make Q flash. Nothing in this check costs Robux.

Source watch, locked in `tests/PetFlash.spec.luau`: `PetAura.luau` does not contain `KeyCode.Q`. The listener calls `PetFlash.should` before any return. It does not return on `processed`. The text-box return sits after that call and before the `0.45` write.

Flags: none. Glass Kestrel is the roster pet, not Dewdrop Finch.
