# E-010 phone recheck

Tip `0a6253b` (`cursor/live-build-9721`, includes #285 and #288). Sizes are the safe GUI after `CoreUISafeInsets`, not raw device pixels. Margin is 16. Touch floor is 44. Overlap is strict: edges that only touch still pass.

`tests/PhoneRecheck.spec.luau` locks the checks that pass. It does not assert the pending overlaps below, so the suite stays green. Nothing in `src/` was changed.

Gates on this branch: `selene src` clean (0 errors, 0 warnings, 0 parse errors). `lune run tests/run` 1469 passed / 0 failed, including the click harness and the 180-local gate. `rojo build -o /tmp/Shardfall.rbxlx` built.

GuiFake does not lay out `UIListLayout`, and it ignores `AnchorPoint`. Card and tip Y in the fake are the list origin. Tip X for a full-width card is layout math (`BagBoard.tipPlace`), and that clamp does not depend on Y.

## Steps

| Step | 390×844 | 844×390 | Failure |
| --- | --- | --- | --- |
| 1 Spawn | pass | pass | Plaza and the cold-open sentence are manual. |
| 2 Plaza and one nav | fail | fail | Portrait: `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau:902`, `src/ReplicatedStorage/Shared/HudLayout.luau:214`, `src/ReplicatedStorage/Shared/HudLayout.luau:358`. Landscape: `src/ReplicatedStorage/Shared/HudLayout.luau:352`. |
| 3 First fight | manual | manual | Studio. Code support is not a pass. |
| 4 First loot | manual | manual | Studio. Code support is not a pass. |
| 5 Bag tip and Equip | fail | fail | `src/ReplicatedStorage/Shared/BagBoard.luau:266`, `src/ReplicatedStorage/Shared/BagBoard.luau:272`, called from `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau:2312`. |
| 6 First crack | pass | pass | Portrait page shares the step 2 rail cover. The pass line still holds. |
| 7 Settings and pets | pass | pass | Portrait page shares the step 2 rail cover. The absent rows are the pass line. |
| 8 Forge sheet | pass | fail | Landscape: `src/ReplicatedStorage/Shared/ShellLayout.luau:252`, applied in `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau:380`. |
| 9 Gold shop | pass | pass | |
| 10 Still hidden | pass | pass | A plaza walk for a stray daily-boss control is manual. |
| 11 Controller rail | pass | pass | Ring motion at these sizes was not re-driven. Physical gamepad draw is manual. |

390×844: pass 7, fail 2, manual 2. 844×390: pass 6, fail 3, manual 2. Step 8 fails only in landscape.

## What passed

Always-on shell, both sizes. Portrait `(16,16 56×56)`, HP `(80,16 178×56)`, pills `(266,16 108×112)`. Landscape portrait `(16,16 56×56)`, HP `(80,16 220×56)`, pills `(488,48 340×32)`. Rail is clear of the portrait and the HP bar at both sizes. The E-001 rail-on-portrait overlap is gone. Counters read `Gold 40` and `Shards 10` and sit off the portrait. Mastery stays hidden (`extraCurrencies` off). No Robux string on Bag, Roll, or Shop.

Rail buttons, both sizes: Hero, Bag, Pets, Roll, Shop, Settings, each visible and at least 44. Portrait rail `(16,210 64×424)`, button 64. Landscape rail `(16,80 44×304)`, button 44. Hub tabs stay `Visible = false`. Close is at least 44 tall.

Action cluster, both sizes, each button at least 44, on screen, clear of the 2×4 bar and of each other. Portrait attack `(310,764 64×64)`, dodge `(258,784 44×44)`, jump `(206,784 44×44)`, heavy `(154,784 44×44)`. Landscape attack `(548,302 72×72)`, dodge `(492,326 48×48)`, jump `(572,246 48×48)`, heavy `(492,270 48×48)`. Labels Atk, Heavy, Jump. The drawn Heavy is `CombatCluster`, not `HeavyChip.place`.

Skip intro is a 140×44 control inside the onboard card. Portrait card `(16,136 358×144)`, skip relative `(183,88)`. Landscape card `(192,88 460×144)`, skip relative `(234,88)`.

Bag: no Salvage, no Robux. Tip name `Practice Blade` in Rare `(96,168,232)`, one line `Nothing equipped in this slot.` Equip reads `Equip`, then `Equipped` on the same press. Tip box stays inside an 8px inset. That inset check is not the rail check.

Roll: title Roll, `Shards  10` matches the counter's 10, `Pity 0/100`, `Pity 0/1000`, `CRACK x1`. Crack button 72 on portrait and 44 on landscape. Pity geometry: tier ends at or before the lock, count starts at lock plus lock width. Portrait span 248 (lock 130–146, count 152–240). Landscape span 575 (lock 457–473, count 479–567).

Settings title Settings. No Trades, no Raid invites, no Hotkey raids, no Hotkey market. Text size is present. Pets title Pets. No Evolution, no Boss. `Crack a Pet Shard` is present. Shop title Shop. `Healing Tonic  40 Gold` and `Bag slot  250 Gold`. No pet slot, no Dust, no Robux.

Schema 26, starter shards 10, `PASS_PRODUCT_ID` 0, `ARCHIVE_PRODUCT_ID` 0. Parked switches checked off: raids, trading, market, pass, petEvolution, bossPets, forgeSalvage, forgeCraft, chests, paid.

## Pending, do not fix

1. Portrait hub page sits under the rail. Hub is `(55,102 280×640)` (`HudLayout.luau:214`). Body is `(63,158 264×576)` (`MenuHub.luau:902`, pad 8). Rail is `(16,210 64×424)` and its right edge is 80 (`HudLayout.luau:358`). The title at y=110 misses the rail. The body does not. Rail `DisplayOrder` 85 (`HudShell.luau:248`) is above the hub's 80 (`MenuHub.luau:114`). This is the step 2 portrait fail, and the same cover sits on Bag, Roll, Settings, Pets, and Shop.

2. Bag tip clamps to x=8, under the rail at both sizes. A full-width card takes the wide branch (`BagBoard.luau:266`) and the floor (`BagBoard.luau:272`). `MenuHub.luau:2312` calls that. Portrait tip `(8,394 220×46)` from a card at the body origin. Landscape tip `(8,99 220×46)`. The name starts 8px into the tip, at screen x=16, so the left of the name is on the rail. This is the step 5 fail at both sizes. A finger-hold without `MouseEnter` is still manual. The fake shows the tip on `MouseEnter`.

3. Landscape rail leaves the 16px inset. `HudLayout.luau:352` accepts `endY <= viewportY` after parking the rail under the HP bar. Bottom is 384. The safe limit is 374. The button stays 44 and on screen, and it stays clear of the portrait and the HP bar. This is the step 2 landscape fail.

4. Landscape Forge sheet is under the rail for its whole height. Sheet `(16,140 360×162)` (`ShellLayout.luau:252`, `Ui.luau:380`). Rail `(16,80 44×304)`. Scroll is Y only, so no scroll position clears it. Sheet `DisplayOrder` 18 (`Ui.luau:242`) is under the rail. This is the step 8 landscape fail. Salvage is still absent.

## Step 8 portrait, and the words on the Forge

Portrait sheet `(16,140 358×616)`, inner height 592. It misses the HP bar. A 44px upgrade row (`Ui.luau:226`) at the top of the sheet ends before the rail (y=210) and before the 2×4 bar (y=600). The bar does cover the bottom of the sheet, so the row has to be scrolled up. Counted as pass. See the question below.

World prompt: ActionText `Forge`, ObjectText `Upgrade gear` (`HavenBuilder.luau:907`). Opening the sheet toasts `Forge. Upgrade gear.` (`init.client.luau:1353`). Sheet title `FORGE` (`Ui.luau:1269`). Hint `Crafting Level 1` (`Ui.luau:1279`). Upgrade tab is shown. Craft (`Ui.luau:1329`), Materials (`Ui.luau:1337`), and Salvage (`Ui.luau:1333`) are not shown. Forge Boost is `paid` off (`Ui.luau:1309`). Chests is created only when `chests` is on (`Ui.luau:1150`). Empty upgrade copy is `Upgrade gear from your bag.` (`Ui.luau:209`).

## Manual

- Step 1. Standing in the plaza, and the cold-open sentence. Skip, the two counters, and Shards 10 are checked.
- Step 2. Rootvault readable from the spawn. `Haven.gatePlate` for Rootvault is `Lv 1 · Solo` (`Haven.luau:193`). The Heartwood arch is still built and open (`Haven.luau:197`). That is not a fail of the rail-and-panel pass line.
- Step 3. Swing shows, and the enemy reacts. A Heavy tap fires `begin`, then waits `CHARGE_HOLD` 0.35s (`CombatHud.luau:145`, `CombatFeel.luau:26`). Swing length is 0.28s (`CombatFeel.luau:45`). Unarmed `hitsMelee` is true in front and false behind. Dodge and Jump are at least 44 and clear of the attack button and the bar. GuiFake's last input is keyboard, so the dodge label reads `Shift` here. A touch last-input shows Dodge.
- Step 4. Reading the drop during a fight. Loot is a world orb plus a `+ name` toast, not a screen card. A single 36px toast ends above the action bar in the layout math. Rarity color is the orb. The toast text is not the rarity color.
- Step 6. The crack motion, a same-press backdrop tap, and the longer Rare hold. Panel text, pity rows, the crack button, and the matching shard number are checked.
- Step 10. A walk of the plaza. Salvage, dust, and the daily board are off in code. `setHubChrome` forces `LoopHud.setOpen(false)` (`init.client.luau:832`).
- Step 11. A physical gamepad at these two sizes. Rail buttons and page titles are checked here. The ring walk is the existing HubInput harness at 1280×800.

Not re-filed: the E-007 same-frame ButtonA plus mouse click, and the E-009 negative `SetAudio` write (`Remotes.luau:444`, `Audio.luau:41`).

## Questions for Ghost

1. Portrait step 8. A 44px upgrade row scrolled to the top of the sheet counts as fully readable, even though the action bar covers the bottom of the sheet. Default: yes, that is a pass.
2. Landscape step 8. The rail covers the left of the upgrade button at every scroll position. Centered text of a short name may still clear x=60. Default: fail, because the row is not fully visible.
3. Landscape step 2. The rail button stays 44 and on screen, and it ends at y=384, 10px into the 16px inset. Default: fail, and leave `railFit`. Do not shrink a button under 44.
4. Steps 3 and 4, the plaza, and the daily-boss walk stay manual. Default: do not treat the code support as a Studio pass.
5. The Heartwood arch is still open in the plaza while raids are hidden from the rail. Default: not a fail of step 2. Do not change Haven.
6. The dodge label `Shift` in GuiFake is the keyboard last-input path. Default: not a bug.
