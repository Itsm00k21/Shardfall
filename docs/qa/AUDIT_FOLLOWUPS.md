# Audit follow-ups from AUDIT-A (T-062)

Left over from the 2026-10-16 debug audit after PR #65. The two P0s in that report (practice kill loot, forged perfect dodge) and the salvage hold (P1) are fixed on this branch. Nothing below is an open P0.

#66 (AUDIT-B, T-061) merged at `d6a75b6` and closed the skill, hub-hotkey, rebind, roll-chain, and Haven rows. The leftovers below are what that merge did not take.

## Open

| Pri | Where | What is left | Suggested fix |
| --- | --- | --- | --- |
| P1 | `CombatHud.luau` input, `HudShell.luau` skill keys | Gamepad heavy is ButtonX. Light attack, skills, and ultimate still have no gamepad button. Touch and mouse button 1 still send a light swing. Dodge is ButtonY. | Add the remaining gamepad buttons next to the keyboard cases, and a heavy control on the touch cluster. Keep `processed` so a Gui tap does not also swing. ButtonX stays heavy. |
| P1 | `Ui.luau` legacy panel | MenuHub and the gold banner follow the text-size slider. The bag is Echo's T-167. The legacy panel still does not. | Apply the same `TextFit.px` rule on the legacy panel when settings change. Leave the banner on `BannerFit`. |
| P1 | `DataService.luau` `release` and `BindToClose`, `SessionLock.luau`, `RaidService.luau` `queue` | See the session-lock note below. The part that is worth fixing is the teleport race and the 25 second shutdown cutoff. | Save and clear the lock before `TeleportAsync` returns. In `BindToClose`, wait out the writes up to the engine's shutdown budget. Leave the 60 second autosave and the 20 minute crash lock as they are. |
| P2 | `Schema.luau` version 21 block (around the `if version < 21` step) | That block sets `raw.schemaVersion = 21` and does not assign the local `version`. Every earlier step assigns both. A future version 22 step in the same `migrate` call would also run for a profile that just took the 21 step. Nothing follows 21 today, so no save is wrong yet. | When 22 is added, set `version = 21` in that block the same way 20 does. Do not bump the schema for this alone. |
| P2 | `MenuHub.luau` hero viewport | The hero page builds a `ViewportFrame` and, in a spawned thread, `CreateHumanoidModelFromDescription` for R15 only. If the page is cleared before that returns, the model is never parented and never destroyed. An R6 description fails the call and the frame stays empty. | Parent into the viewport that is still alive, destroy the model on the other path, and accept R6. |
| P2 | `InventoryHud.luau` `RenderStepped` | The bag connects `RenderStepped` for the whole session and rotates every rarity gradient while the bag is closed. Combat floaters, loot beams, and toasts are already bounded. | Connect the gradient spin only while the bag is open. |
| P2 | `init.client.luau` mounts, `RollReel.luau` | The client still mounts RollReel, InventoryHud, ClassHud, RaidHud, LoopHud, MarketHud, and the legacy `Ui` panel beside MenuHub. `retireChrome` disables the old action bar, debug gui, and menu gui. `playChest` still runs on `ShardfallRoll` (DisplayOrder 40) under the hub (DisplayOrder 80). | One roll surface. Route chest reveals through the hub, or hide `ShardfallRoll` while the route is open. |
| P2 | `MarketService.luau`, `MarketBoard.luau` `list`, `Remotes.luau` `SetSettings`, `HudShell.luau` settings send | See the market-hold note below. A crash loses the listing fee, not the item. `SetSettings` replaces the whole `uiSettings` blob, so a slower full snapshot can revert a hotkey. | Persist the listing before the fee counts as spent, or take the fee only after the listing is durable. Merge settings on the server instead of replacing the blob. |

## Already closed

| Pri | Where | What the 2026-10-16 report said | Where it stands |
| --- | --- | --- | --- |
| P1 | `ActionBar.luau` `ShardfallDodge`, `Keybinds.GAMEPAD.dodge` | Dodge had no gamepad button. | T-166 binds ButtonY. ButtonX stays heavy. The Dodge chip shows Y after a gamepad press. Glass Kestrel flashes on ButtonY. |
| P1 | `InventoryHud.luau` I listener, `Keybinds.luau` raids | I opened the old bag and the Raids tab. | T-058 (#62) removed the InventoryHud I listener. Raids stays on I in `Keybinds.MENU`. No second I listener is in the client scripts. No further change. |
| P1 | `HudShell.luau` skill handler | Skill 1 was Left Shift, which sprint sinks. | T-061 (#66) binds skill 1 to 1. Shift stays sprint. |
| P1 | `MenuHub.luau` `ShardfallMenuSink` | Tab letters stopped working while the hub was open. | T-061 handles C, B, P, T, I, and M inside the open menu. Movement, Shift, and the combat keys stay sunk. |
| P1 | `MenuHub.luau` capture path, `Settings.luau` `normalize` | Rebind accepted any letter, including Q, E, and F. | T-061 refuses Q, E, F, R, Shift, 1, 2, ButtonX, and a second tab. A taken menu letter swaps. |
| P1 | `MenuHub.luau` roll close path, `RollLoop.luau`, `RollService.luau` | A hidden roll chain could keep spending tokens and salvaging. | T-061 stops the chain when the hub closes, the roll tab is left, or the player dies. The server ignores a roll that arrives before the reveal would finish. |
| P1 | `init.client.luau` Haven prompts | Haven stalls opened the legacy panel. | T-061 points Forge to Bag, Market to Market, Armory to Roll, and Pet Garden to Pets. |

## Session lock

Priority: **P1** for two concrete paths. The other two behaviors in the same code are the designed tradeoff, and changing them would be the risk.

`DataService.release` writes with `UpdateAsync` and then clears the lock. There is no `SetAsync`. `mutate` updates memory and waits for the 60 second autosave or for leave. Two remotes do not interleave inside one profile.

Worth fixing:

- **Teleport.** `RaidService.queue` calls `TeleportAsync` and does not release first. The old server saves on `PlayerRemoving`, which runs around the teleport, not before `TeleportAsync` returns. The new server retries the load five times, two seconds apart, then kicks with "Your data is still open on another server." A write that finishes inside that window is fine. A throttled write is a kick, and the profile is not overwritten. This is a live reserved-server path. Save and clear the lock before `TeleportAsync` returns.
- **Shutdown cutoff.** `BindToClose` spawns one `release` per player and stops waiting at 25 seconds (`DataService.luau` around the `deadline` loop). The engine's budget is about 30 seconds. On a full server a slow DataStore queue can still be inside `UpdateAsync` when the callback returns, and the process can die there. Those players keep the previous autosave and can still hold the lock. Wait for the writes until the shutdown budget instead of returning at 25 seconds.

Leave alone:

- **The 60 second crash gap.** A hard crash (no leave, no `BindToClose`) drops at most one autosave interval. The module comment already accepts that, and it is tighter than ProfileStore's 300 second default. Writing every `mutate` would spend the DataStore budget. This is not the defect.
- **The 20 minute foreign lock.** `SessionLock.TIMEOUT_SECONDS` is 20 minutes and has to stay well above the autosave interval, or a slow save looks like a dead server and a second server takes the profile. After a hard crash the next join is kicked until that timeout. That is harsh, and it is what stops two servers writing one profile. Do not shorten it to a couple of minutes.

A failed release does not roll the profile backwards and does not write a second copy. The player-facing failure is a kick, or a lost minute of play if the process dies mid-write.

## Market hold crash

Priority: **P2**. The item is safe. The money at risk is the listing fee, which a cancel already sinks on purpose.

`MarketBoard.list` takes a 5% gold fee inside `DataService.mutate`, then stores the listing only on `MarketService`'s in-memory board. The item stays in the bag. `Trading.reserve` is an in-memory hold. Leave cancels that player's open listings (`MarketService.onPlayerRemoving`) and does not refund the fee. The board comment says the fee is not returned on cancel or expiry.

- Crash before the next autosave: the fee existed only in memory. Rejoin has the old gold and the item. Nothing was lost.
- Crash after an autosave that included the fee, and before leave runs cancel: the saved profile has the fee spent and the item still in the bag. The listing was never stored, so it is gone. The seller lost the same 5% a cancel would have taken, without asking to cancel. A buyer who was looking at the board sees the listing vanish. The buyer is not charged, and the item is not duplicated.
- While the server is up, salvage, remove, and feed already refuse a listed uid or a uid sitting in a trade (T-062). The listing stays until buy, cancel, or leave.

So a crash is a forced cancel. It is annoying on an expensive listing, and it is not an item-loss or a duplication bug. Persist the listing (on the profile, or its own store) before the fee counts as spent, or charge the fee only once that record is durable. Until then, do not refund fees on crash or the cancel rule and the crash rule will disagree.

The same audit row's settings half is separate and also P2: `SetSettings` replaces `uiSettings` with `Settings.normalize(patch)`. A layout drag and a settings click each send a full snapshot, so the slower one can revert the other. Merge the patch on the server.

## Choices left in place on purpose

| Pri | Where | What | Suggested fix |
| --- | --- | --- | --- |
| P2 | `PracticeLoot.luau` `wing`, `RaidService.practice` | A level 15 practice run can still open any of the four Heartwood wings. The wing is clamped to that list. Loot, chests, currency, XP, and quest progress stay off, so this is not income. | Leave it. If practice should follow clear order, require a cleared wing in the T-060 rules when those get wired. Do not open loot to do that. |
| P2 | `DebugService.luau` `phase`, `DungeonService.setBossPhase` | The Studio debug "phase" action always calls `setBossPhase(player, 2)`, which sets phase 2 and the phase-2 HP ratio. The remote refuses outside Studio. | Leave it for live servers. If Studio needs another phase, pass that number from the debug action. |
| P2 | `DebugService.luau` `raid`, `RaidService.practice` | The Studio debug "raid" action calls `practice`, which now keeps the level 15 gate. A level 1 Studio profile is refused. | Leave the gate on the live remote. A Studio bypass belongs in `DebugService`, not in `practice`. |
| P2 | `CombatFeel.luau` `DODGE_LATENCY` (0.1) | A dodge that arrives more than 0.1 seconds after the telegraph ends is not perfect, even if the press was inside the window. The early side is not extended. | Leave the early side tight. If playtests miss perfects on slow connections, raise the late allowance a little and keep one ult per telegraph. |
| P2 | `CombatFeel.luau` `scoreAny` | If two telegraphs match one press, only the first window is awarded. A later dodge can still award the other. One press cannot take two ult gains. | Leave it. Paying both windows on one press would undo the one-ult cap. |

## Grok second opinion (2026-10-16 23:09)

New rows from that pass. The hotkey prefix bug was going to be T-075. HELPER already holds T-075 for Contest Weekend on this tip, so the hotkey fix is T-080.

| id | Pri | Where | What is left |
| --- | --- | --- | --- |
| T-080 | P1 | `UiRouter.hotkey` | `string.sub(keyName, 1, 1)` treats `Two` as T, `Tab` as T, `Space` as S, `LeftShift` as L, `Backspace` as B, `Comma` as C, `Period` as P, `Minus` as M, and `Insert` as I. Match only a single-letter key name (KeyCode A-Z). |
| T-076 | P1 | `DungeonService.luau` `onHeartbeat` | One player's error aborts the rest of the heartbeat. Isolate each player in `pcall`. The parallel agent on `cursor/echo-retry-yield-9721` owns the edit. |
| T-077 | P1 | `DataService.luau` load, `ProfileLoad.open` | A load that exceeds `CallBudget`'s timeout keeps running and can still claim the lock and run `Progression.applyReturn` / `lastSeen`. Ignore late transforms with a per-attempt generation token. |
| T-078 | P2 | `HudShell.luau` `prompt`, `ToastQueue.pushPrompt` | Equip and Keep only dequeue. `pushPrompt` has no cap. |
| T-079 | P2 | `init.client.luau` `invoke`, `CombatHud.start` | `WaitForChild` has no timeout. |

The rest of grok-audit.md was already covered. Practice loot and the forged perfect dodge are T-062. The session-lock teleport race and the shutdown cutoff are T-065, and the hop reclaim is T-067. The hub hotkey, rebind, and roll-chain stop are T-061. The NaN wing is the practice-wing choice left on purpose above. `savePair` is already in `docs/qa/DEBUG_AUDIT_2026-10-16.md`. The hero viewport leak is the P2 row above. No second row for those.
