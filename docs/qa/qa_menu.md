# Menu bug risks

G-056. Stuck tabs, lost dim, overlap, and input leaks in `UiRouter.luau`, `MenuHub.luau`, and `HudShell.luau`. This file does not change code.

The prefix hotkey bug is closed. `UiRouter.hotkey` accepts only a one-letter name (`UiRouter.luau:153-156`), and `tests/UiRouter.spec.luau` locks it. The hero viewport now asks `HeroView.place` before it parents (`MenuHub.luau:2136-2141`, `HeroView.luau:36-43`). The equip prompt queue stops at `ToastQueue.MAX` (`ToastQueue.luau:109-110`). Those three are not reopened here.

Dim and the screen flag move together. `apply` writes transparency from `state.dim`, sets `Modal` from `state.open`, and sets `screen.Enabled` from `state.open` (`MenuHub.luau:4571-4580`). `publish` sets dim to `0.5` only while open and to `0` on close (`UiRouter.luau:76-85`). A lost dim in this build means `Enabled` true while `state.dim` is `0`, or the movement sink left on after `Enabled` goes false.

Line numbers are the tip after #216 and #217. #216 moved hub lines. #217 changed the pill column and did not change `railFit`.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| M1 | The first open never disables the control module if that module was not ready. A later `setWorldInput(true)` skips the call because the flag already matches | `MenuHub.luau:453-475` | high | Hub is open, dim is up, before `PlayerModule` exists. The sink still binds, so W, A, S, D, Space, and Thumbstick1 are eaten (`Keybinds.luau:342-364`). `Disable` never runs. The on-screen stick can still walk. Close, then open, calls `Disable`. A second open while the flag is already true does not |
| M2 | Closed on the tip. Width 390 no longer lays Gold, Mastery, and Shards across the portrait and the HP bar | `HudLayout.luau:32-53`, `HudLayout.luau:71-85`, `HudShell.luau:546-555`, `UiTheme.luau:19`, `UiTheme.luau:85-86` | low | Safe margin is 16 (`safeMargin`). Width under 500 uses the right column from #217. At width 390 the column is x=266, y=16, w=108, h=112. Portrait is x=16, y=16, 56 by 56. Health is x=80, y=16, w=178, h=56. The column starts 8px past the health bar. At width 844 the strip starts at x=488, w=340, and misses the health bar. That strip crosses the toast, so the fit then sits at y=48, h=32. The old x=34, y=52, w=340 row was the pre-#217 rect |
| M3 | The rail is pushed into the portrait on a short height. #217 did not change this fit | `HudLayout.luau:304-333`, `HudShell.luau:570-575` | high | Height 380, margin 16, 7 buttons, preferred 64, minimum 44. The fit stays at 44 and the final y is 8. Portrait y is 16. The rail's x is 16 and its width is 44, so it covers the portrait's left edge. Height 390 (the phone view `{ 844, 390 }`) stays at 44 and y=17, so it still covers that edge. The phone spec does not pair the rail with the portrait. Height 720 keeps the preferred 64 and y=112, clear of the portrait |
| M4 | Rebind capture eats Escape and every other keyboard key. Button B still closes the hub and leaves capture on | `MenuHub.luau:4725-4748`, `MenuHub.luau:4753-4756` | medium | Start a rebind. Escape does not close and does not cancel. Button B closes the hub. The next letter writes a hotkey, calls `save`, and calls `show("settings")` while the screen is disabled |
| M5 | Bag and Market jump to a second panel, then close the hub. The sink stays if that close never runs | `MenuHub.luau:2412-2413`, `MenuHub.luau:2440-2441`, `MenuHub.luau:4253-4254`, `init.client.luau:1189-1201` | medium | "Open full bag" and the empty-bag button call `onBag`. "Open board" calls `onMarket`. Each opens the legacy panel, then `menuHub.close()`. For one turn both are up: hub DisplayOrder 80 (`MenuHub.luau:100`) over the shell at 30 (`HudShell.luau:62`). If close is skipped, `ShardfallMenuSink` stays bound |
| M6 | The class card is a stack id, not a tab. A hero visit forces it back on while the class is missing | `UiRouter.luau:105-113`, `MenuHub.luau:1413-1421`, `MenuHub.luau:2007-2028`, `MenuHub.luau:4617-4624` | medium | No class. Open Hero. The stack is `{ "hero", "class" }` and `tab` is `"class"`. Close the card. Switch to Bag, then Hero. `follow` calls `showClassPrompt(true)` and the card is back. Hotkey to Bag sets `classDismissed` because the top stopped being `"class"` (`MenuHub.luau:4573-4575`) |
| M7 | Equip dequeues before the remote answers | `HudShell.luau:506-513`, `HudShell.luau:746-751` | medium | Two prompts queued. Tap Equip. The first card is gone even if `EquipItem` throws. The uid still goes out. Keep drops the card and does not equip |
| M8 | Close leaves the sink and the control module matched to `state.open` | `MenuHub.luau:4577-4595`, `UiRouter.luau:128-137` | low | Open, confirm dim transparency `0.5` and `Modal` true. Esc, backdrop, and the close button each leave `Enabled` false, dim transparency `1`, `Modal` false, and `ShardfallMenuSink` unbound. `rollHandoff` does the same and sets `rollAway` (`UiRouter.luau:134-137`) |

M3 is the overlap that is still open. M2's width-390 cover closed in #217. This list is the fail condition.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| MN-1 | `PlayerModule` missing, then the hub opens on Hero | Press W and move the stick | No walk. Dim is 0.5. After `PlayerModule` appears, still no walk until close |
| MN-2 | Hub open, module ready | Close with Esc, with the backdrop, and with the close button | Each one: screen disabled, sink gone, module enabled, rail highlight cleared (`init.client.luau:1203-1206`) |
| MN-3 | Width 390 and width 844, hub closed | Read portrait, health, and pill rects | 390 does not cover the portrait or the health bar. 844 does not |
| MN-4 | Height 380 and height 720, hub closed | Read the rail rect | 380 overlaps the portrait as in M3. 720 does not |
| MN-5 | Settings, a hotkey waiting for a key | Escape, then Button B, then the letter A | Escape changes nothing. Button B closes. A does not rebind while the hub is closed. Capture is nil |
| MN-6 | Bag tab, items present | "Open full bag" | Legacy bag ends open, hub screen disabled, sink unbound |
| MN-7 | Bag empty | The empty state's "Open full bag" | Same as MN-6 |
| MN-8 | Market tab | "Open board" | Legacy board ends open, hub closed, sink unbound |
| MN-9 | No class | Hero, close the card, Bag, Hero | The card returns on the second Hero visit. Bag while the card is up does not leave `tab` equal to `"class"` |
| MN-10 | Class already chosen | Open Hero from the rail | The class card stays hidden. `showClassPrompt` pops if the top is still `"class"` (`MenuHub.luau:2009-2011`) |
| MN-11 | Two equip prompts | Tap Equip, force the remote to throw | The first card is gone, the second shows, and exactly one invoke was sent |
| MN-12 | Hub open on a pushed Sets page | Button R1, then Esc from Sets | R1 leaves Sets and opens the next real tab (`UiRouter.luau:180-193` uses `stack[1]`, then `switch` replaces the stack). Esc from Sets returns to Bag, dim still 0.5 |
| MN-13 | Hub open | Press W, Shift, R, Button X, Button Y | The sink eats them (`Keybinds.luau:342-364`). Button R1 and Button L1 still change tabs. Button B and Esc pop once |
| MN-14 | Text scale above 1, width 390 | Open the shell only | Pill text may clip. The column in M2 still misses the portrait and the health bar. The scale does not move those rects (`HudShell.luau:701-722`) |

## Flags

None. Tab names are the live eight: Hero, Bag, Pets, Roll, Raids, Market, Shard Pass, Settings (`UiRouter.luau:35`). No paid control is on these paths.
