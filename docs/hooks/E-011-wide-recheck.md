# E-011 wide recheck

Cut from tip `a5a8ec6`, rebased onto `540ed07` (`cursor/live-build-9721`, #291). Sizes are the safe GUI after `CoreUISafeInsets`, not raw device pixels. Margin is 16. Touch floor is 44. Overlap is strict: edges that only touch still pass.

This pass scores the breakpoint bar. 1024×768 is `tablet`. 1280×720 is `console`. Neither is `phone`, so `HudLayout.actionCluster` is one row of 8 and Heavy stays hidden. A touch device at the same pixels uses the 2×4 bar. That variant does not change the 1024×768 table. It would clear the 1280×720 forge row, because that bar misses the sheet. The table below is the breakpoint score.

`tests/WideRecheck.spec.luau` locks the checks that pass. It does not assert the 1280×720 forge row, so the suite stays green. Nothing in `src/` was changed.

Gates on this branch, after the rebase onto `540ed07`: `selene src` clean (0 errors, 0 warnings, 0 parse errors). `lune run tests/run` 1474 passed / 0 failed, including the click harness and the 180-local gate. `rojo build -o /tmp/Shardfall.rbxlx` built.

GuiFake does not lay out `UIListLayout` or `UIGridLayout`, and it ignores `AnchorPoint`. Rail captions are real. Card and tip positions in the fake are the host origin. Tip X for a grid cell is layout math (`BagBoard.tipPlace` on the cell size). The crack button and Close use an anchor, so their fake Y is not the Studio Y. The size offset is.

## Steps

| Step | 1024×768 | 1280×720 | Failure |
| --- | --- | --- | --- |
| 1 Spawn | pass | pass | Plaza and the cold-open sentence are manual. |
| 2 Plaza and one nav | pass | pass | |
| 3 First fight | manual | manual | Studio. Code support is not a pass. |
| 4 First loot | manual | manual | Studio. Code support is not a pass. |
| 5 Bag tip and Equip | pass | pass | |
| 6 First crack | pass | pass | |
| 7 Settings and pets | pass | pass | |
| 8 Forge sheet | pass | fail | `src/ReplicatedStorage/Shared/ShellLayout.luau:252`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau:380`, `src/ReplicatedStorage/Shared/HudLayout.luau:428`, `src/ReplicatedStorage/Shared/ActionSlots.luau:639`. |
| 9 Gold shop | pass | pass | |
| 10 Still hidden | pass | pass | A plaza walk for a stray daily-boss control is manual. |
| 11 Controller rail | pass | pass | Ring motion at these sizes was not re-driven. Physical gamepad draw is manual. |

1024×768: pass 9, fail 0, manual 2. 1280×720: pass 8, fail 1, manual 2. Step 8 fails only at 1280×720.

## What passed

Always-on shell, both sizes. Portrait `(16,16 56×56)`, HP `(80,16 220×56)`. Pills 1024 `(668,48 340×32)`, 1280 `(924,52 340×36)`. Rail is inside the 16px inset and clear of the portrait, the HP bar, and the goal tracker. 1024 rail `(16,172 64×424)`, bottom 596, safe limit 752. 1280 rail `(16,148 64×424)`, bottom 572, safe limit 704. Button stays 64. Counters read `Gold 40` and `Shards 10` and sit off the portrait. Mastery stays hidden. No Robux string on Bag, Roll, or Shop.

Goal tracker, text size 14. 1024 `(88,212 320×62)`. 1280 `(88,80 320×62)`. It misses the portrait, the HP bar, the pills, the rail, and the action bar.

Hub misses the rail at both sizes. 1024 hub `(143,84 737×599)`, body `(151,140 721×535)`, title `(151,92 713×32)`. 1280 hub `(210,79 860×561)`, body `(218,135 844×497)`, title `(218,87 836×32)`. Tabs stay `Visible = false`. Close is 96×44. With its anchor, 1024 Close is `(776,92 96×44)` and 1280 Close is `(966,87 96×44)`.

Rail buttons, both sizes: Hero, Bag, Pets, Roll, Shop, Settings. Each caption is the button name. Each button is 64.

Action cluster, breakpoint path, each shown button at least 44, on screen, clear of the bar, the rail, the portrait, the HP bar, the tracker, and each other. Heavy is hidden. 1024 attack `(936,680 72×72)`, dodge `(880,704 48×48)`, jump `(960,624 48×48)`. Bar `(228,652 568×100)`, slot 64, one row of 8. 1280 attack `(1192,632 72×72)`, dodge `(1136,656 48×48)`, jump `(1216,576 48×48)`. Bar `(356,604 568×100)`, slot 64, one row of 8.

Skip intro is a 140×44 control inside the onboard card. 1024 card `(282,88 460×144)`, skip relative `(234,88)`. 1280 card `(410,96 460×144)`, skip relative `(234,88)`.

Bag: no Salvage, no Robux. Grid is 5×131×228 at 1024 and 6×128×228 at 1280. A first-column cell tip is `(298,148 220×46)` at 1024 and `(362,143 220×46)` at 1280. The last column tips at x=503 and x=698. All four stay inside an 8px inset and miss the rail. Tip name `Practice Blade` in Rare `(96,168,232)`, one line `Nothing equipped in this slot.` Equip reads `Equip`, then `Equipped` on the same press.

Roll: title Roll, `Shards  10` matches the counter's 10, `Pity 0/100`, `Pity 0/1000`, `CRACK x1`. Crack button height 72. Pity geometry: tier ends at or before the lock, count starts at lock plus lock width. 1024 span 705 (lock 587–603, count 609–697). 1280 span 828 (lock 710–726, count 732–820).

Settings title Settings. No Trades, no Raid invites, no Hotkey raids, no Hotkey market. Text size is present. Pets title Pets. No Evolution, no Boss. `Crack a Pet Shard` is present. Shop title Shop. `Healing Tonic  40 Gold` and `Bag slot  250 Gold`. No pet slot, no Dust, no Robux.

1024 Forge sheet `(16,140 360×540)` misses the HP bar. A 44px row at y=596 ends at 640. The rail ends at 596 and the action bar starts at 652, so that row is clear. The round attack, dodge, and jump buttons miss the sheet.

Schema 26, starter shards 10, `PASS_PRODUCT_ID` 0, `ARCHIVE_PRODUCT_ID` 0. Parked switches checked off: raids, trading, market, pass, petEvolution, bossPets, forgeSalvage, forgeCraft, chests, paid.

## Pending, do not fix

1. 1280×720 Forge upgrade row is never fully readable. Sheet `(16,140 360×492)` (`ShellLayout.luau:252`, applied in `Ui.luau:380`). Rail `(16,148 64×424)` covers the left of the sheet from y=148 to y=572. The desktop action bar `(356,604 568×100)` (`HudLayout.luau:428` picks the non-phone row, `ActionSlots.luau:639` sets its top) covers the sheet from y=604 to y=632. The open band between them is 32px. A 44px row (`Ui.luau:226`) does not fit. Scroll is Y only. Sheet `DisplayOrder` 18 (`Ui.luau:242`) is under the rail. Salvage stays absent.

The rail half is the known E-010 landscape sheet, showing at this size too. At 1024×768 that same sheet still has a 56px band (rail ends 596, bar starts 652), so step 8 passes there. The 32px band is the new part. Do not fix it here. Leave `railFit`. Do not shrink a button under 44.

## Known, not re-filed

These E-010 overlaps were measured again. They are not new rows.

- Portrait hub body under the rail. Does not show. The hub starts at x=143 and x=210. The rail ends at x=80.
- Bag tip clamped to x=8. Does not show for a grid cell. GuiFake still reports that x=8 tip, because the card measures as the host. The cell does not.
- Landscape rail past the 16px inset. Does not show. Bottoms are 596 and 572. Limits are 752 and 704.
- Landscape Forge sheet under the rail. Shows at both sizes (`ShellLayout.luau:252`, `Ui.luau:380`). It fails step 8 only at 1280×720, together with the desktop bar above.

The E-009 negative `SetAudio` write stays on that row (`Remotes.luau:444`, `Audio.luau:41`). Not re-filed.

## Step 8 words on the Forge

World prompt: ActionText `Forge`, ObjectText `Upgrade gear` (`HavenBuilder.luau:907`). Opening the sheet toasts `Forge. Upgrade gear.` (`init.client.luau:1356`). Sheet title `FORGE` (`Ui.luau:1269`). Hint `Crafting Level 1` (`Ui.luau:1279`). Upgrade tab is shown. Craft (`Ui.luau:1329`), Materials (`Ui.luau:1337`), and Salvage (`Ui.luau:1333`) are not shown. Forge Boost is `paid` off (`Ui.luau:1309`). Chests is created only when `chests` is on (`Ui.luau:1150`). Empty upgrade copy is `Upgrade gear from your bag.` (`Ui.luau:209`).

## Manual

- Step 1. Standing in the plaza, and the cold-open sentence. Skip, the two counters, and Shards 10 are checked.
- Step 2. Rootvault readable from the spawn. `Haven.gatePlate` for Rootvault is `Lv 1 · Solo` (`Haven.luau:193`). The Heartwood arch is still built and open (`Haven.luau:197`). That is not a fail of the rail-and-panel pass line.
- Step 3. Swing shows, and the enemy reacts. A Heavy tap fires `begin`, then waits `CHARGE_HOLD` 0.35s (`CombatHud.luau:145`, `CombatFeel.luau:26`). Swing length is 0.28s (`CombatFeel.luau:45`). Unarmed `hitsMelee` is true in front and false behind. On this score Heavy is hidden (`HeavyChip.show` is false when the device is not touch). Dodge and Jump are at least 44 and clear of the attack button and the bar. With touch off, GuiFake's last input is keyboard, so the dodge label reads `Shift`. A touch last-input shows Dodge.
- Step 4. Reading the drop during a fight. Loot is a world orb plus a `+ name` toast, not a screen card.
- Step 6. The crack motion, a same-press backdrop tap, and the longer Rare hold. Panel text, pity rows, the crack button, and the matching shard number are checked.
- Step 10. A walk of the plaza. Salvage, dust, and the daily board are off in code. `setHubChrome` forces `LoopHud.setOpen(false)` (`init.client.luau:833`).
- Step 11. A physical gamepad at these two sizes. Rail buttons and page titles are checked here. The ring walk is the existing HubInput harness.

## Questions for Ghost

1. 1280×720 step 8. The rail and the desktop action bar leave a 32px band, short of a 44px row. Default: fail. Leave `railFit`. Do not shrink a button under 44. Do not fix it in this PR.
2. 1024×768 step 8. The top of the sheet meets the rail. A 44px row at y=596 is clear of the rail and the action bar. Default: pass, because the rail does not cover the row at every scroll position.
3. Touch on these widths uses the 2×4 bar, and Heavy shows. That bar misses the 1280 sheet, so step 8 would pass on touch. Default: keep the breakpoint score, one row of 8, Heavy hidden. The 1024 table does not change either way.
4. The open hub covers the top of the action bar, and the equip prompt sits under the hub, at both sizes. Default: not a step fail.
5. GuiFake puts the bag tip at x=8 because the card measures as the host. The grid cell does not. Default: step 5 passes. This is not the E-010 full-width clamp.
6. Steps 3 and 4, the plaza, and the daily-boss walk stay manual. Default: do not treat the code support as a Studio pass.
7. The Heartwood arch is still open in the plaza while raids are hidden from the rail. Default: not a fail of step 2. Do not change Haven.
8. With touch off, the dodge label reads `Shift`. Default: that is the keyboard path, not a bug.
