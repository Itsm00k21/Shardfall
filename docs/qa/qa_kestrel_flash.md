# Glass Kestrel dodge flash

G-081. Test plan for the dodge flash. The flash follows the dodge action. This file does not change code.

`PetRoster` names Glass Kestrel's ability "Dodge flash" and its effect `"flash"` (`PetRoster.luau:38-42`). The pane is the full-screen `Dodge` frame on `ShardfallPetAura`, color `(186, 230, 255)`, transparency `1` at rest (`PetAura.luau:29-36`). A flash writes `0.45`, then `1` after `0.12` seconds (`PetAura.luau:70-73`).

The listener never sees a dodge. `ShardfallDodge` binds `LeftShift` and `RightShift` at high priority, calls `onDodge`, and returns Sink (`ActionBar.luau:707-722`). `onDodge` plays the dodge and fires `CombatHud.dodge` (`init.client.luau:1252-1255`, `CombatHud.luau:142-147`). `PetAura` returns when `processed` is true, and it returns unless the key is `KeyCode.Q` (`PetAura.luau:63-65`). Dodge is `Keybinds.COMBAT.dodge` (`"LeftShift"`, `Keybinds.luau:18-19`). `RightShift` is the other dodge name (`Keybinds.luau:91-92`).

Choice: hook the flash to that dodge action, or to an event the action already raises. Do not compare a raw key. A key check that still returns on `processed` misses the sunk Shift. Q is not a dodge.

This plan does not cover the missing gamepad dodge in `docs/qa/AUDIT_FOLLOWUPS.md`, and it does not cover the LB chord.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| R1 | A real dodge never flashes | `PetAura.luau:63-65`, `ActionBar.luau:707-722` | high | LeftShift or RightShift dodges. The `Dodge` frame stays at transparency `1`. |
| R2 | A raw-key patch still misses | `PetAura.luau:64`, `ActionBar.luau:717` | high | Swapping Q for LeftShift, then returning on `processed`, still skips the flash. Sink already ate the key. |
| R3 | Q flashes with no dodge | `PetAura.luau:64-73` | medium | Q, with Glass Kestrel equipped, paints the pane. No dodge clip. No `Dodge` remote. |
| R4 | The on-screen button dodges in silence | `ActionBar.luau:522`, `init.client.luau:1252-1255` | medium | The Dodge chip calls `onDodge` and never passes `InputBegan`. A key-only flash skips it. |
| R5 | The other two pets flash | `PetAura.luau:67-68`, `PetRoster.luau:22-36` | low | Shardjaw (`collect`) or Thorn Lantern (`ping`) paints the pane on a dodge or on Q. |

## Cases

Equip means `PetRoster.equippedEffect` is the effect below. Menu closed unless the case says otherwise. Pass means the `Dodge` frame hits transparency `0.45` and returns to `1` at about `0.12` seconds, color unchanged. Fail means the frame never leaves `1`.

| case | equip | do this | dodge action | flash |
|---|---|---|---|---|
| KF-1 | `glass_kestrel` / `flash` | LeftShift, press begin | `onDodge` runs | pass |
| KF-2 | `glass_kestrel` / `flash` | RightShift, press begin | `onDodge` runs | pass |
| KF-3 | `glass_kestrel` / `flash` | Q, and Q is not a dodge | no `onDodge` | fail (stays `1`) |
| KF-4 | `glass_kestrel` / `flash` | Tap the on-screen Dodge chip | `onDodge` runs | pass |
| KF-5 | `glass_kestrel` / `flash` | LeftShift while the hub is open | no `onDodge` (`ActionBar.luau:713-714` returns Pass) | fail (stays `1`) |
| KF-6 | `shardjaw` / `collect` | LeftShift | `onDodge` runs | fail (stays `1`) |
| KF-7 | `thorn_lantern` / `ping` | RightShift | `onDodge` runs | fail (stays `1`) |
| KF-8 | no pet | LeftShift | `onDodge` runs | fail (stays `1`) |
| KF-9 | `glass_kestrel` / `flash` | Q while a Gui has already processed the key | no `onDodge` | fail (stays `1`) |

KF-6 still sets the character attribute `ShardfallCollect` from the heartbeat (`PetAura.luau:76-83`). KF-7 still shows `KeyPing` when `shardKeys` is above 0 (`PetAura.luau:84-88`). The flash change must not stop those two.

## Suggested check

One pure question, called from the dodge action, not from a key compare. Suggested name only: `shouldFlash(action, effect)`.

| action | effect | result |
|---|---|---|
| `"dodge"` | `"flash"` | true |
| `"dodge"` | `"collect"` | false |
| `"dodge"` | `"ping"` | false |
| `"dodge"` | nil | false |
| `"q"` | `"flash"` | false |
| `"slot"` | `"flash"` | false |

`action` is the dodge action. It is not `KeyCode.Name`. A third argument (`paid`, a product id, Robux, `cost`, `skip`) does not flip the answer. Nothing in this check costs Robux.

Source watch, after the code row lands: `PetAura.luau` does not contain `KeyCode.Q`. The flash write sits on the dodge action path. It does not sit behind `if processed`.

Flags: none. Glass Kestrel is the roster pet, not Dewdrop Finch.
