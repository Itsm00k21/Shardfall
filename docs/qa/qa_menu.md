# Menu bug risks

G-056. Stuck tabs, lost dim, overlap, and input leaks in `UiRouter.luau`, `MenuHub.luau`, and `HudShell.luau`. This file does not change code.

The prefix hotkey bug is closed. `UiRouter.hotkey` accepts only a one-letter name (`UiRouter.luau:151-155`), and `tests/UiRouter.spec.luau` locks it. The hero viewport now asks `HeroView.place` before it parents (`MenuHub.luau:2101-2106`, `HeroView.luau:36-43`). The equip prompt queue stops at `ToastQueue.MAX` (`ToastQueue.luau:109-110`). Those three are not reopened here.

Dim and the screen flag move together. `apply` writes transparency from `state.dim`, sets `Modal` from `state.open`, and sets `screen.Enabled` from `state.open` (`MenuHub.luau:4139-4163`). `publish` sets dim to `0.5` only while open and to `0` on close (`UiRouter.luau:76-85`). A lost dim in this build means `Enabled` true while `state.dim` is `0`, or the movement sink left on after `Enabled` goes false.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| M1 | The first open never disables the control module if that module was not ready. Later opens skip the call because the flag already matches | `MenuHub.luau:451-473` | high | Hub is open, dim is up, WASD or the stick still walks. Closing and opening once recovers. The test opens the hub on the first frame, before `PlayerModule` exists |
| M2 | Gold, Mastery, and Shards cover the portrait and the HP bar on a narrow width | `HudLayout.luau:28-44`, `HudShell.luau:544-555`, `UiTheme.luau:19`, `UiTheme.luau:79-80` | high | Safe margin is 16. At width 390 the pill row is x=34, y=52, w=340, h=36. Portrait is x=16, y=16, 56 by 56. Health is x=80, y=16, 220 by 56. The pills cross both. At width 844 the pills start at x=488 and miss the health bar |
| M3 | The rail is pushed into the portrait on a short height | `HudLayout.luau:223-252`, `HudShell.luau:556-561` | high | Height 380, margin 16, 7 buttons, preferred 64, minimum 44. The fit stays at 44 and the final y is 8. Portrait y is 16. The rail's x is 16 and its width is 44, so it covers the portrait's left edge. Height 720 keeps the preferred 64 and y=112, clear of the portrait |
| M4 | Rebind capture eats Escape and every other keyboard key. Button B still closes the hub and leaves capture on | `MenuHub.luau:4293-4316`, `MenuHub.luau:4321-4324` | medium | Start a rebind. Escape does not close and does not cancel. Button B closes the hub. The next letter writes a hotkey, calls `save`, and calls `show("settings")` while the screen is disabled |
| M5 | Bag and Market jump to a second panel, then close the hub. The sink stays if that close never runs | `MenuHub.luau:2322-2323`, `MenuHub.luau:2350-2351`, `MenuHub.luau:3821-3822`, `init.client.luau:1189-1201` | medium | "Open full bag" and the empty-bag button call `onBag`. "Open board" calls `onMarket`. Each opens the legacy panel, then `menuHub.close()`. For one turn both are up: hub DisplayOrder 80 (`MenuHub.luau:99`) over the shell at 30 (`HudShell.luau:62`). If close is skipped, `ShardfallMenuSink` stays bound |
| M6 | The class card is a stack id, not a tab. A hero visit forces it back on while the class is missing | `UiRouter.luau:105-113`, `MenuHub.luau:1411-1419`, `MenuHub.luau:1972-1993`, `MenuHub.luau:4185-4192` | medium | No class. Open Hero. The stack is `{ "hero", "class" }` and `tab` is `"class"`. Close the card. Switch to Bag, then Hero. `follow` calls `showClassPrompt(true)` and the card is back. Hotkey to Bag sets `classDismissed` because the top stopped being `"class"` (`MenuHub.luau:4141-4143`) |
| M7 | Equip dequeues before the remote answers | `HudShell.luau:506-513`, `HudShell.luau:732-737` | medium | Two prompts queued. Tap Equip. The first card is gone even if `EquipItem` throws. The uid still goes out. Keep drops the card and does not equip |
| M8 | Close leaves the sink and the control module matched to `state.open` | `MenuHub.luau:4145-4163`, `UiRouter.luau:128-137` | low | Open, confirm dim transparency `0.5` and `Modal` true. Esc, backdrop, and the close button each leave `Enabled` false, dim transparency `1`, `Modal` false, and `ShardfallMenuSink` unbound. `rollHandoff` does the same and sets `rollAway` (`UiRouter.luau:134-137`) |

M2 and M3 are the overlap cases. Echo's phone pass owns the layout change. This list is the fail condition, not that change.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| MN-1 | `PlayerModule` missing, then the hub opens on Hero | Press W and move the stick | No walk. Dim is 0.5. After `PlayerModule` appears, still no walk until close |
| MN-2 | Hub open, module ready | Close with Esc, with the backdrop, and with the close button | Each one: screen disabled, sink gone, module enabled, rail highlight cleared (`init.client.luau:1203-1206`) |
| MN-3 | Width 390 and width 844, hub closed | Read portrait, health, and pill rects | 390 overlaps as in M2. 844 does not |
| MN-4 | Height 380 and height 720, hub closed | Read the rail rect | 380 overlaps the portrait as in M3. 720 does not |
| MN-5 | Settings, a hotkey waiting for a key | Escape, then Button B, then the letter A | Escape changes nothing. Button B closes. A does not rebind while the hub is closed. Capture is nil |
| MN-6 | Bag tab, items present | "Open full bag" | Legacy bag ends open, hub screen disabled, sink unbound |
| MN-7 | Bag empty | The empty state's "Open full bag" | Same as MN-6 |
| MN-8 | Market tab | "Open board" | Legacy board ends open, hub closed, sink unbound |
| MN-9 | No class | Hero, close the card, Bag, Hero | The card returns on the second Hero visit. Bag while the card is up does not leave `tab` equal to `"class"` |
| MN-10 | Class already chosen | Open Hero from the rail | The class card stays hidden. `showClassPrompt` pops if the top is still `"class"` (`MenuHub.luau:1974-1976`) |
| MN-11 | Two equip prompts | Tap Equip, force the remote to throw | The first card is gone, the second shows, and exactly one invoke was sent |
| MN-12 | Hub open on a pushed Sets page | Button R1, then Esc from Sets | R1 leaves Sets and opens the next real tab (`UiRouter.luau:180-193` uses `stack[1]`, then `switch` replaces the stack). Esc from Sets returns to Bag, dim still 0.5 |
| MN-13 | Hub open | Press W, Shift, R, Button X, Button Y | The sink eats them (`Keybinds.luau:342-364`). Button R1 and Button L1 still change tabs. Button B and Esc pop once |
| MN-14 | Text scale above 1, width 390 | Open the shell only | Pill text may clip. The rects in M2 still overlap. The scale does not move those rects (`HudShell.luau:686-708`) |

## Flags

None. Tab names are the live eight: Hero, Bag, Pets, Roll, Raids, Market, Shard Pass, Settings (`UiRouter.luau:35`). No paid control is on these paths.
