# Shardfall debug audit, 2026-10-16

Static audit of `cursor/live-build-9721` at `8f7877c` (Add the GROK offload lane). No game code was changed. The R-key overlap (heavy attack in `CombatHud.luau` and the Roll hotkey) is T-058 and is not repeated below. Every other bind was checked.

## Gates

| Gate | Result |
| --- | --- |
| `selene src` (0.32.0) | 0 errors, 0 warnings, 0 parse errors |
| `lune run tests/run` (lune 0.11.0) | 582 passed, 0 failed. One run, no flake |
| `rojo build` (7.7.1) | Built `shardfall.rbxlx` |

`selene.toml` allows `incorrect_standard_library_use`, so Selene will not flag a bare DataStore call. Those were read by hand. The only test warning is expected: test 568 forces an audit failure and the service prints `[Shardfall] trade commit failed:` plus the spec traceback. The assertion still passes.

## Keybind audit

Default letters live in `Settings.luau` 104–111 and `ClientChrome.luau` 47–56. Combat labels live in `HudShell.luau` 62–68. Listeners are `UserInputService.InputBegan` unless noted. `processed` means the engine already used the key (a Gui button, a focused TextBox, or a ContextAction that returned Sink).

| Key | Who listens | Conflict |
| --- | --- | --- |
| C, B, P, M | MenuHub tab hotkeys only, while the hub is closed | Clear of combat. While the hub is open they are on the sink list, so they do not switch tabs. See P1-3 |
| I | InventoryHud toggles the old bag (`InventoryHud.luau` 1270–1276). Raids hotkey is also I | Same class of double bind as R. See P1-1 |
| R | CombatHud heavy and Roll hotkey | Known. T-058. Not filed again |
| Q | CombatHud dodge only (`CombatHud.luau` 729–731) | Clear at the defaults. A rebind can stack a tab on Q. See P1-4 |
| E | HudShell attack (`HudShell.luau` 558–559), which calls `CombatHud.swing` | Clear at the defaults. A rebind can stack a tab on E |
| F | HudShell ultimate (`HudShell.luau` 566–567) | Clear at the defaults. A rebind can stack a tab on F |
| Left Shift, Right Shift | HudShell skill 1 (`HudShell.luau` 560–563). Left Shift is also the default sprint | Skill 1 on the labeled Shift key does not fire. See P1-2 |
| 2 (`KeyCode.Two`) | HudShell skill 2 | Clear. Numpad 2 is `KeypadTwo` and does nothing. See P2-4 |
| Mouse button 1 | CombatHud light swing when `processed` is false (`CombatHud.luau` 737–741) | A click on a Gui button is swallowed. A click on the world still swings |
| Touch | Same listener as mouse button 1, always a light swing | No touch heavy. See P1-6 |
| Gamepad | MenuHub: ButtonB closes, ButtonL1 / ButtonR1 change tabs while open, ButtonA is a pointer-down on the roll button (`MenuHub.luau` 2467–2470, 3045–3057) | No gamepad dodge, heavy, attack, skill, or ultimate. See P1-6 |
| Escape | MenuHub pop (`MenuHub.luau` 3045–3049) | Clear |
| W A S D, Space, Thumbstick1 | Sunk only while the hub is open (`MenuHub.luau` 363–385) | Movement stops while the hub is open. Shoulders are left free on purpose |

`Settings.normalize` (`Settings.luau` 154–162) accepts any single letter and does not check that two tabs, or a tab and a combat key, share it. The capture path (`MenuHub.luau` 3031–3037) writes that letter straight through.

## Findings

| Pri | Where | Issue | Why it matters | Suggested fix | Lane |
| --- | --- | --- | --- | --- | --- |
| P0 | `DungeonService.luau:1287-1312`, `DungeonService.luau:921-924`, `RaidService.luau:187-201`, `DungeonService.luau:1803-1812`, `DungeonService.luau:1894-1900` | Practice Grove still pays kill loot. `grant()` returns before rewards when `run.practice` is true, and raid marks are skipped, but the death path always calls `Drops.apply` and `ChestConfig.bossKill`. Heartwood rooms spawn `grandmother_gnarl` (a verdant boss drop: guaranteed boss material, plus a scroll chance). `bossKill` grants a Rare chest every kill, an Epic daily chest the first time that day, and a Legendary weekly chest the first time that week (`ChestConfig.luau` 122–125, 405–423). `RaidPractice` is a normal remote. `enter` skips the level 15 gate when `practice` is true, and `tuneRaid` honors the client wing and phase, including phase 3 at 25% HP | A client can farm boss materials and the daily and weekly boss chests without clearing Story or Normal. The practice note says "No loot" | On the death path, return before `Drops.apply`, `ChestConfig.bossKill`, and the floor chest when `run.practice` is true. Keep the level gate, or cap practice to a wing the player has already cleared | GHOST code |
| P0 | `CombatService.luau:743-759`, `CombatService.luau:402-407`, `DungeonService.luau:1572-1578`, `CombatHud.luau:140-145`, `CombatHud.luau:546-549`, `CombatFeel.luau:107-108` | Perfect dodge trusts a client number. The server sends `endsAt = enemy.telegraphUntil`, which is `os.clock()` plus the cue length. The client stores it and sends it back on every dodge. `CombatFeel.perfect` is true when server `now` is inside the last 0.15s before that number. Nothing checks that a telegraph is live. After one cue, the client knows the server clock and can send `endsAt` slightly ahead of it on every dodge | Each forged perfect adds `PERFECT_ULT` (12) and plays the perfect FX. Ult fills without the timing | Score perfect only against the server's own live `telegraphUntil` for that player. Ignore the remote argument, or treat it as a hint that must match the server value within the window | GHOST code |
| P1 | `InventoryHud.luau:1270-1276`, `Settings.luau:109`, `ClientChrome.luau:52`, `MenuHub.luau:3066-3073`, `init.client.luau:740` and `init.client.luau:1097` | I is bound twice. InventoryHud toggles the old bag. The Raids hotkey is also I. InventoryHud connects first, so I opens the old bag (and that path closes the hub), then MenuHub opens Raids on top. Both listeners run whenever `processed` is false | One key opens two panels. Same shape as the R bug | Give Raids a free letter, or delete the InventoryHud key listener and open the bag from the hub. Do this with T-058 so the letters are chosen once | UI |
| P1 | `HudShell.luau:554-567`, `HudShell.luau:62-68` | Skill 1 is Left Shift and Right Shift, and the handler returns when `processed` is true. The default control script sinks Left Shift for sprint, so the key printed on the button does not cast. Right Shift still casts. E, 2, and F are the other skill keys and do not have a second listener at the defaults | The labeled Shift skill looks dead in a playtest | Bind skill 1 to a key sprint does not sink, or cast it from the sprint action before returning Sink. Keep the on-screen button | UI |
| P1 | `MenuHub.luau:322-325`, `MenuHub.luau:363-385`, `MenuHub.luau:3027-3064` | While the hub is open, `ShardfallMenuSink` sinks C, B, P, R, I, M (and the combat keys) at high priority and returns Sink. The hotkey handler returns immediately when `processed` is true, so those letters never reach `UiRouter.key`. ButtonL1 and ButtonR1 are not in the sink, so shoulders still change tabs | Tab letters open the hub and then stop working until it is closed | Handle the tab letter inside the sink callback, or take the tab letters off the sink list. Leave W A S D, Space, Shift, and the combat keys sunk | UI |
| P1 | `MenuHub.luau:3031-3037`, `Settings.luau:154-182` | Rebind accepts any A–Z letter and saves it. Two tabs may share a letter (`UiRouter.hotkey` returns the first tab in list order). Q, E, and F are legal rebinds and then fire the combat listener and the tab listener together, because both `InputBegan` connections run | The next playtest that rebinds a key will invent another R-style overlap | Reject a letter already used by a tab or by E, Q, R, F, Shift, or 2. Show the current owner on the row | UI |
| P1 | `MenuHub.luau:2887-2910`, `MenuHub.luau:2325-2338`, `MenuHub.luau:2356-2365` | Closing the hub sets `screen.Enabled` false and does not clear `shownId`, `holdingRoll`, `autoOn`, or `activeReveal`. `chainAllowed` still returns true while `shownId` is `"roll"` and auto-roll or the held button is on. `finishReveal` then calls `beginRoll`, which invokes `RollShard` | Tokens keep spending on a screen the player cannot see. Auto-junk can also fire `Salvage` from `paintResult` (`MenuHub.luau` 2318–2321) during that hidden chain | On close, bump `revealToken`, clear `holdingRoll`, and set the roll phase to idle. Chain only while `route.open` and the roll page is showing | UI |
| P1 | `init.client.luau:1241-1257`, `Ui.luau:1624-1647`, `MarketHud.luau` open path from the same Haven callback | Haven prompts open the legacy `Shardfall` panel (`userOpen = true` on the DisplayOrder 18 screen) for the forge and the armory, and `MarketHud` for the market. The hub is a different screen. `retireChrome` disables the old action bar, debug gui, and menu gui, not this panel | A playtest at a Haven stall draws the old column of buttons on top of the new shell | Point Haven prompts at `MenuHub` tabs. Leave `Ui.mount` in place only for the banner until those buttons are gone | UI |
| P1 | `Crafting.luau:349-369`, `InventoryView.luau:222-239`, `Trading.luau:383` and `Trading.luau:1668-1694` | Salvage and bulk salvage block locked and equipped gear only. A market listing records an in-memory hold and does not take the item out of the bag. Salvage deletes the uid and pays materials. The listing stays open until a buy fails in `moveOffer` and reopens it | The seller is paid salvage for an item that is still advertised. The buyer gets "That listing is gone." after the attempt | `salvageBlock` should return when `Trading.itemHold(uid)` is set. Cancel the listing if the item disappears | GHOST code |
| P1 | `HudShell.luau:850-867`, `MenuHub.luau` text rows (for example `2149-2159` and `1110-1117`) | `access.textScale` is stored and applied only while painting HudShell, and only to labels under that chrome. MenuHub, InventoryHud, and the legacy panel keep a fixed `TextSize`. `UiTheme.safeMargin` (`UiTheme.luau` 76–78) is always 16. The hub and the shell do use `ScreenInsets.CoreUISafeInsets`. The gold banner in `Ui.luau` 205–209 sets `IgnoreGuiInset = true` at DisplayOrder 100 | The text-size slider does not change the menu the player is looking at. The banner can sit under a notch | Apply `textScale` in MenuHub when settings change. Give the banner the same insets as the hub | UI |
| P1 | `CombatHud.luau:725-742`, `HudShell.luau:554-568`, `MenuHub.luau:3045-3057` | Gamepad has tab shoulders and ButtonB. It has no dodge, heavy, attack, skill, or ultimate. Touch and mouse button 1 always send a light swing (`charged` false). Heavy is R only. The on-screen skill buttons do cover attack, dodge, skills, and ultimate for touch | A controller cannot fight. A phone cannot heavy-attack | Add gamepad buttons next to the existing keyboard cases, and a heavy control on the touch cluster. Keep `processed` so a Gui tap does not also swing | UI |
| P1 | `DataService.luau:422-437`, `DataService.luau:517-529`, `SessionLock.luau:23-25` and `SessionLock.luau:67-70`, `DataService.luau:410-414` | Leave and `BindToClose` both call `release`, which writes with `UpdateAsync` and then clears the lock. There is no `SetAsync`. If the new server loads before that write finishes, load retries five times, two seconds apart, then kicks. A foreign lock younger than 20 minutes cannot be taken. `BindToClose` stops waiting after 25 seconds even if a write is still running. Autosave is 60 seconds (`DataService.luau` 46), so a hard crash can drop the last minute. `mutate` itself does not yield, so two remotes do not interleave inside one profile | A fast rejoin or a teleport into a reserved raid can kick with the lock message, or a shutdown can drop the last save | On teleport, save and clear the lock before `TeleportAsync` returns. In `BindToClose`, wait out the writes up to the engine's shutdown budget. The 60-second crash window is the accepted one if shutdown and teleport are tight | GHOST code |
| P2 | `Schema.luau:30`, `Schema.luau:965-968` | Live schema is 21. There is no version 22 step. The version 21 block sets `raw.schemaVersion` and does not assign the local `version`, unlike every earlier step. `migrate` still refuses `version > 21` as `"newer"` and will not roll a profile backwards | A later step written against the local `version` will also run for a profile that just took the 21 step in the same call. Today nothing follows it, so this does not eat saves | When 22 is added, set `version = 21` in that block the same way 20 does | GHOST code |
| P2 | `MenuHub.luau:1528-1564` | The hero page builds a `ViewportFrame` and, in a spawned thread, `CreateHumanoidModelFromDescription` for R15 only. If the page is cleared before that returns, `viewport.Parent` is nil and the model is never parented and never destroyed. An R6 description fails the call and the frame stays empty | Opening Hero and switching tabs leaks a character model. Some bodies never appear | Parent into the viewport that is still alive, destroy the model on the other path, and accept R6 | UI |
| P2 | `InventoryHud.luau:1279-1288`, `CombatHud.luau:103-115` and `CombatHud.luau:685-706` | InventoryHud connects `RenderStepped` for the life of the session and rotates every rarity gradient even while the bag is closed. Combat floaters disconnect and destroy the part at 0.85s. Loot orbs in `DungeonService.luau` 584–622 disconnect the beam follow at pickup or at 6 seconds. Toast rows in HudShell are a fixed pool (`ToastQueue.MAX`). The roll strip is capped at `RollBoard.HISTORY` (`MenuHub.luau` 2421–2424). The pity tween is cancelled in `paintRoll` | The bag spin is the one per-frame cost that stays on in town. The beams, floaters, and toasts are bounded | Connect the gradient spin only while the bag is open | UI |
| P2 | `init.client.luau:32-51`, `init.client.luau:1288-1296`, `RollReel.luau:1253-1268` | The client still mounts RollReel, InventoryHud, ClassHud, RaidHud, LoopHud, MarketHud, and the legacy `Ui` panel beside MenuHub. `retireChrome` disables ShardfallActions, ShardfallDebug, and ShardfallMenu. RollReel's roll button starts hidden, but `playChest` still runs on `ShardfallRoll` (DisplayOrder 40), under the hub (DisplayOrder 80) if the hub is open | A chest resume or a second roll surface can play under the hub, and the dim for that reel is its own flash, not `UiRouter` | One roll surface. Route chest reveals through the hub, or hide `ShardfallRoll` while `route.open` | UI |
| P2 | `MarketService.luau:146-158`, `MarketBoard.luau:329-376`, `Remotes.luau:384-401`, `HudShell.luau:1174-1181` | Listings and trade holds live in server memory. Leaving cancels that player's open listings. A crash after the listing fee is saved, and before leave runs, keeps the fee and drops the hold. `SetSettings` replaces `uiSettings` with `Settings.normalize(patch)`. A layout drag and a settings click each send a full snapshot, so the slower one can revert the other | A market crash loses the fee, not the item. A settings click can revert a hotkey that was saved a moment earlier | Persist listings with the profile, or take the fee only after the listing is durable. Merge settings on the server instead of replacing the blob | GHOST code |

Checked and not filed:

- Dev grants and `Debug` return "Dev tools only work in Studio." Paid rolls, prism packs, luck boosts, forge boosts, and inventory expansion are stubs and do not grant. `PremiumPass` returns a product id and does not set the track.
- Every remote in `Remotes.bind` goes through `RateLimiter.take`. An action missing from `RULES` is denied. Attack, Dodge, and Steer are limited on the events.
- Salvage, equip, feed, and bulk salvage validate the uid on the server and pay inside one `mutate`. No second copy of the item was found. The hold hole above is the salvage gap.
- `DataService` writes with `UpdateAsync` only. A profile newer than schema 21 is refused and not overwritten.
- Toasts, damage numbers, and loot beams are destroyed. The hero viewport is the leak.

## Studio checks

Boot should print these two lines before anything else. If either is missing, Studio is not running this repo:

- `[Shardfall] build f0af554+ server`
- `[Shardfall] build f0af554+ client`

Watch for these. The wording is what the scripts emit.

| Output | What it means |
| --- | --- |
| `[Shardfall] DataStores are unavailable (` … `).` then `This session keeps profiles in memory and will NOT save.` | Studio API access is off, or the store probe hung. The session is ephemeral. Leave and rejoin will not keep gold or items |
| `[Shardfall] To save: publish the place, then Game Settings → Security → Enable Studio Access to API Services, then press Play again.` | Same cause. Turn API access on before a save playtest |
| `[Shardfall] Loaded <name> (<id>) via memory (not saved)` | That join did not read the DataStore |
| `[Shardfall] Loaded <name> (<id>) via DataStore` | The profile is the saved one |
| `[Shardfall] DataStore load failed for` | The load threw or timed out. In Studio this falls through to the memory profile |
| `[Shardfall] Profile save failed:` or `[Shardfall] Autosave failed for` or `[Shardfall] Final save failed for` | The leave or the 60-second save did not commit. The next line is the reason (`busy`, `lost`, `missing`, or `error:`) |
| `[Shardfall] Lost the session lock for` | Another server took the profile. This server kicks: `Your Shardfall session moved to another server. Rejoin to keep playing.` |
| Kick text `Your data is still open on another server. Rejoin in a moment.` | The lock was still fresh. Wait, or the other server never finished `release` |
| Kick text `This server is out of date for your Shardfall profile. Rejoin shortly.` | The save is newer than schema 21. This server will not overwrite it |
| Kick text `Your Shardfall profile could not be read. It was not overwritten.` | `schemaVersion` was not a number. The key was left alone |
| `[Shardfall] Profile mutate failed:` | A remote handler threw inside `mutate`. The in-memory profile was restored from the backup |
| `[Shardfall] <Action>: ` | A remote failed its guard. The client also warns `[Shardfall] ` plus the same text |
| `[Shardfall] Attack:` or `[Shardfall] Dodge:` | The combat event threw. The swing or dodge did not apply |
| `[Shardfall] Rootvault reward failed:` | The clear did not save. The client is told no rewards were granted |
| `[Shardfall] Could not write the restored profiles back.` | A trade or market `savePair` failed and the undo write failed too |
| `[Shardfall] trade commit failed:` | A trade rolled back. In tests this line is the expected warning from the audit-failure case |
| `[Shardfall] market could not watch leaving players:` | Listings will not cancel on leave |
| `[Shardfall] RaidService failed:` | Join teleport data could not start a raid |
| `[Shardfall] <Service> failed:` | That service's `start` threw. The rest of boot continues. `DataService failed` means nobody loaded |
| `[Shardfall] Haven hub failed to build:` | The hub folder did not build. Prompts and the walk surface may be missing |
| `[Shardfall] removed legacy ScreenGui ` or `[Shardfall] removed legacy panel ` | A place-file gui was destroyed. If it comes back every few seconds, a script inside StarterGui is cloning it. Names already called out: Gold x0.00, Tools 2, Stat points, Stardust's Grace, Luck Aura, Auto Parry |
| `[Shardfall] removed stale UI script ` | A second LocalScript was drawing a panel and was destroyed |
| `[Shardfall] ReplicatedStorage.Remotes did not appear. Connect Rojo, then press Play.` | The client gave up after 30 seconds. Buttons will do nothing |
| `[Toast] shown ` | The legacy banner, not the HudShell toast pool |
| `[Roll] landed` or `[Roll] reel ready` | RollReel, not the hub roll page |
| `[ForgeUI] opened` | A Haven prompt opened the legacy forge panel |
| `[Shardfall] <name> fell out of the room` or `fell off Haven` | The server moved them back. Not a save error |

## Top 5 to do first

1. Stop Practice Grove from paying `Drops.apply` and `ChestConfig.bossKill`. That is live item and chest income from `RaidPractice`.
2. Score a perfect dodge from the server's telegraph only. The client already receives the server clock in `endsAt`.
3. Split I from the old bag, and reject hotkey letters that match another tab or E, Q, F, Shift, or 2. Leave the R overlap to T-058.
4. Make Shift cast skill 1, and let C, B, P, I, and M switch tabs while the hub is open. The sink should keep movement and combat, not the tab letters.
5. Stop the roll chain when the hub closes, and point Haven prompts at the hub so the legacy panel stays hidden.
