# Glass Kestrel dodge flash

QA checklist for T-158.

G-081. Case list for the Glass Kestrel flash. T-158 replaces G-081. This file does not change code.

`PetFlash.should(keyName, effect)` returns true only for `LeftShift` and `RightShift` when the equipped effect is `"flash"`. `LeftShift` is `Keybinds.COMBAT.dodge` (`Keybinds.luau:19`). `RightShift` is the other dodge name (`Keybinds.luau:92`). Q does not flash. `processed` is not an argument. The caller must not return early because `processed` is true.

`PetRoster` names the ability "Dodge flash" and the effect `"flash"` (`PetRoster.luau:38-42`). The pane is the full-screen `Dodge` frame on `ShardfallPetAura`, color `(186, 230, 255)`, transparency `1` at rest (`PetAura.luau:29-36`). A true result keeps the flash that is already there: `0.45`, then `1` after `0.12` seconds. Do not change the color.

Today the listener still bails. It returns when `processed` is true, and it returns unless the key is `KeyCode.Q` (`PetAura.luau:63-65`). `ShardfallDodge` binds both Shift keys, calls `onDodge`, and returns Sink (`ActionBar.luau:707-722`), so a real dodge arrives processed. T-158 removes that bail.

The on-screen Dodge button calls `onDodge` from `ActionBar` (`ActionBar.luau:346`, `ActionBar.luau:522`). That button does not flash in T-158. T-106 owns `ActionBar.luau`. Treat the chip as a follow-up, not a pass.

`ButtonX` stays false. Gamepad dodge stays the open note in `docs/qa/AUDIT_FOLLOWUPS.md`. Do not close it here.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| R1 | A Shift dodge never flashes | `PetAura.luau:63-65`, `ActionBar.luau:707-722` | high | LeftShift or RightShift dodges. The pane stays at transparency `1`. |
| R2 | The listener still bails on `processed` | `PetAura.luau:64`, `ActionBar.luau:717` | high | Sink already marked the dodge processed. An early return skips the flash. |
| R3 | Q still flashes | `PetAura.luau:64-73` | medium | Q, with Glass Kestrel equipped, paints the pane. Q is not a dodge. |
| R4 | The on-screen chip is scored as a pass | `ActionBar.luau:346`, `ActionBar.luau:522` | medium | The Dodge button runs `onDodge` and the pane flashes. T-158 does not include that button. |
| R5 | Another effect flashes | `PetAura.luau:67-68`, `PetRoster.luau:22-36` | low | Shardjaw (`collect`) or Thorn Lantern (`ping`) paints the pane. |
| R6 | ButtonX or a paid flag flips the answer | `Keybinds.luau:37`, `docs/qa/AUDIT_FOLLOWUPS.md` | low | `ButtonX` flashes, or `paid` / Robux blocks a Shift flash. |

## Cases

Equip means `PetRoster.equippedEffect` is the effect below. Pass means the pane hits transparency `0.45` and returns to `1` at about `0.12` seconds, color unchanged. Fail means the pane never leaves `1`.

| case | equip | do this | `PetFlash.should` | flash |
|---|---|---|---|---|
| KF-1 | `glass_kestrel` / `flash` | LeftShift, press begin, including when `processed` is true | true | pass |
| KF-2 | `glass_kestrel` / `flash` | RightShift, press begin, including when `processed` is true | true | pass |
| KF-3 | `glass_kestrel` / `flash` | Q | false | fail (stays `1`) |
| KF-4 | `glass_kestrel` / `flash` | Tap the on-screen Dodge button | not this row | fail (stays `1`). Follow-up for T-106, not a pass |
| KF-5 | `glass_kestrel` / `flash` | LeftShift while the hub is open. `ActionBar` returns Pass (`ActionBar.luau:713-714`), so `onDodge` does not run | true if the key name still arrives | pass when `InputBegan` delivers `LeftShift`. `processed` does not cancel it |
| KF-6 | `shardjaw` / `collect` | LeftShift | false | fail (stays `1`) |
| KF-7 | `thorn_lantern` / `ping` | RightShift | false | fail (stays `1`) |
| KF-8 | no pet | LeftShift | false | fail (stays `1`) |
| KF-9 | `glass_kestrel` / `flash` | `ButtonX` | false | fail (stays `1`). Gamepad dodge stays open in `docs/qa/AUDIT_FOLLOWUPS.md` |

KF-6 still sets the character attribute `ShardfallCollect` from the heartbeat (`PetAura.luau:76-83`). KF-7 still shows `KeyPing` when `shardKeys` is above 0 (`PetAura.luau:84-88`). The flash change must not stop those two.

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

Source watch, after T-158 lands: `PetAura.luau` does not contain `KeyCode.Q`. The listener calls `PetFlash.should`. It does not return on `processed` before that call.

Flags: none. Glass Kestrel is the roster pet, not Dewdrop Finch.
