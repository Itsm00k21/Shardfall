# Phase 3 dungeon gap (3.1–3.8)

Date: 2026-10-24. Base: `cursor/live-build-9721` @ `9269e61`.

Sources read: Notion [Shardfall Roadmap](https://app.notion.com/p/401c31ca388381e4b740e879511b87f1) (locked Oct 21, amended Oct 23) and [Dungeon & Waves](https://app.notion.com/p/403c31ca388381d3b40df42c7e231e6a). The audit uses those amendments. `docs/ROADMAP.md` in the repo still has the old 3.2 ("at least 120 studs") and the old 3.7 ("Leave anytime, keep loot from cleared waves").

Locked rules that this table uses:

- Arena is about **80–100 studs across**, round, 3 enemy gates.
- **No early exit.** Players always keep all loot they earned, even on a wipe.
- Numbers live in `src/ReplicatedStorage/Shared/Config/`.

Nothing here reworks open PR #382 (`echo/3-wave-arena`). That branch is not merged and was not edited.

## Gap table

| Item | Status | Where it stands | PR |
|---|---|---|---|
| 3.1 Shard Gate pad near spawn, teleport into the arena | missing | Haven's Rootvault arch is a crawl entry, not a Shard Gate into a V1 arena. `src/ReplicatedStorage/Shared/Haven.luau:177-186` (`dungeonId = "rootvault"`, pad at z = 108). The Waves button in `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau:566-582` calls `enter` on `rootvault_waves`. | Gate plaza #142, #147. Waves entry is on the live branch via `7ce24f9` (GitHub #6 is still open). #382 adds a pad and is not merged. |
| 3.2 Gray-box round arena, 80–100 studs, 3 enemy gates | partial | Live room is a **square 79-stud** floor (`src/ReplicatedStorage/Shared/Dungeons.luau:116`) with four walls (`src/ServerScriptService/ShardfallServer/DungeonService.luau:455-458`) and forest dressing. No 3 enemy gates. 79 is outside 80–100, and the shape is a square. | Floor size landed in `5f934f0` on the live branch. #382 builds a round arena and is not merged (see breaks below). |
| 3.3 Chaser + wave spawner | partial | A wave spawner exists and is the endless crawl, not the V1 list. `DungeonService.luau:1100` `spawnWave`, `Dungeons.luau:741` `waveKinds`, count starts at 2 (`Dungeons.luau:100`, `waveCount` at 701). Every live enemy uses the same chase (`DungeonService.luau:2096` `moveEnemy`). #415 adds a **chaser** row (`src/ReplicatedStorage/Shared/Config/Enemies.luau:78-96`), copies it onto `Config.Enemies` (`Dungeons.luau:857`), and steps it in `EnemyTypeService.luau:71`. `LaunchGate.luau:41` `enemyTypes` is false, and `waveKinds` does not spawn it. | Spawner: live branch / open #6. Chaser type: #415. #382 also drafts a chaser inside its unmerged arena config. |
| 3.4 Ranged and tank | partial | Live projectile and bulky melee are named creatures (`spore_bat`, `root_brute`), not the V1 ranged and tank. #415 adds both (`Config/Enemies.luau:97-115` ranged, `:116` tank) with kite, slow move, and `damageTaken`. A kite is clamped to `ARENA` (`Enemies.luau:63`). A ranged shot travels at `projectileSpeed` and a server raycast checks line of sight before damage (`EnemyTypeService.luau:46`). Same flag. Live `waveKinds` still does not spawn them. The gated 3.5 mix does, only while the flag is on. | Old creatures: live branch (`f30836b`, open #3) and Far Glade #340. V1 ranged and tank: #415. |
| 3.5 Waves of 6 / 8 / 10 / 12 and a wave counter | partial | The HUD still shows `Wave N` (`Ui.luau:603-611`). Live counts are still 2, then +1 every 2 waves, cap 8 (`Dungeons.luau:100-102`). The run is endless. `Config/Enemies.luau` holds 6/8/10/12 and a chaser/ranged/tank mix. `WaveFlowService` pushes `{ wave, left }` on `Remotes.WaveCounter` only while `enemyTypes` is on. That flag is off, so boot does not start a run and no client file reads the remote. | Live counter text: live branch / open #6. Gated list and remote: this branch, stacked on #415. #382's 6/8/10/12 list is all chasers (`WaveArenaConfig.luau:216-222`) and is not merged. |
| 3.6 Boss + 4 adds on wave 5 | partial | Live wave 5 is still Gnarl **plus 2 adds**, not 4: `Dungeons.luau:749` returns `{ grandmother_gnarl, vine_crawler, spore_bat }` (`isBossWave` at 697, every 5 at `:103`). The gated flow's wave 5 is one boss plus 4 adds from chaser, ranged, and tank (`Config/Enemies.luau` `BOSS`, `BOSS_ADDS`). `enemyTypes` is off, so boot does not spawn it and the HUD is unchanged. | Live crawl: live branch / open #6. Gated boss: this branch, stacked on #417. #382 sets `adds = 4` at `WaveArenaConfig.luau:130` and is not merged. |
| 3.7 No early exit. Keep every earned drop, including on a wipe | partial | Live wipe keeps kill loot because the grant is saved at the kill (`DungeonService.luau:1888-1912`) and `finish(player, false)` (`:3159`) does not take it back. Cleared-wave copy says those rewards stay (`Dungeons.luau:607`). The same server still offers an early exit: `DungeonService.leave` at `:2767`, action `"leave"` at `:2946`, HUD Leave shown at `Ui.luau:634`. That exit breaks the Oct 23 rule. | Leave and kill grants: live branch (`f30836b`, open #3). #382 adds a second early exit and drops ground chips (below). |
| 3.8 Stuck-enemy check, max wave, none stuck after 30s | partial | Live `moveEnemy` still only clamps to the floor (`DungeonService.luau:2124-2128`). The gated flow tracks progress toward the target. `Enemies.STUCK_SECONDS` is 30 and `Enemies.validate` rejects a wait above 30. A stall nudges and re-paths, then respawns on a clear point inside `Enemies.ARENA`. `enemyTypes` is off, so boot does not run it. | Spawn clearance is merged #364. #382's 30s check (`Stuck.luau`) is not merged and was not edited. Gated watchdog: this branch, stacked on #419. |

Status words: **done** would mean Kevin can play the locked rule on the live branch. None of 3.1–3.8 are done. #415 moves 3.3 and 3.4 to partial: the server types exist, the flag is off, and no live wave spawns them. The wave-flow change moves 3.5 forward, still partial: the counts and the server counter exist, the flag is off, and the on-screen HUD is unchanged. The boss change moves 3.6 forward, still partial: the gated wave 5 is a boss plus 4 adds, the flag is off, and the live crawl is still Gnarl plus 2. The stuck-check change moves 3.8 forward, still partial: the gated flow resets a stalled enemy by 30 seconds, the flag is off, and the live crawl still only clamps to the floor.

## Open PR #382 locked-rule breaks

PR: https://github.com/Itsm00k21/Shardfall/pull/382 (`echo/3-wave-arena`). Left as-is.

#382's config is `src/shared/Config/WaveArenaConfig.luau`. The locked folder is `src/ReplicatedStorage/Shared/Config/` (Rojo serves that as `ReplicatedStorage.Shared.Config`). #415 does not move #382's file.

1. **Arena is 140 studs across.** `WaveArenaConfig.luau:23` sets `diameter = 140`. Line 19 sets `minDiameter = 120`, the pre-amendment floor. The locked size is 80–100 studs across.
2. **Leave any time (early exit).** The PR text says "Leave any time." `src/server/WaveArena/Round.luau:7` and `Round.leave` at `:623` end a fight that is still going. `showResults` marks it `leftEarly` and phase `"left"` (`Round.luau:128-138`). `src/ServerScriptService/ShardfallServer/WaveArenaHost.luau:404` accepts remote action `"leave"` during the run. The Oct 23 amendment removed early exit.
3. **Loot left on the ground is lost.** A kill drops a chip (`Round.luau:156`). `autoCollect` (`:180`) is what keeps those chips. On death the step does `run.ground = {}` (`:613`) and does not auto-collect. `Round.leave` does the same at `:636` unless the phase is already `deathHold`. Chips still on the ground are dropped. That breaks keep-all-earned-loot.

#382 also drafts chaser, ranged, and tank, the 6/8/10/12 list, boss + 4 adds, 3 gates, and a 30s stuck check. Those stay on that branch until someone reconciles them with the three breaks and the config path. #415 does not edit that branch.

## What #415 adds

Server-only roster, flag `LaunchGate.SHOW.enemyTypes` (**false** at `LaunchGate.luau:41`).

- Numbers: `src/ReplicatedStorage/Shared/Config/Enemies.luau`. `Config.Enemies` is still `Dungeons.ENEMIES`, and the three ids are copied on at `Dungeons.luau:857`.
- Server: `EnemyTypeService` steps, applies hits, and describes gray **blocks** only while the flag is on. Ranged kiting is clamped to the config arena. A ranged shot travels at `projectileSpeed`, then a Workspace raycast checks line of sight before damage. `init.server` does not require it. No remote, no HUD, no `schemaVersion` change, no profile write.
- Drop rows exist so the config cross-check stays valid (`Drops.luau:84-86`). No room and no `waveKinds` entry uses the ids, so a live run does not pay them.

## What the wave flow adds

Server flow on the same flag, `LaunchGate.SHOW.enemyTypes` (**false**). Stacked on #415. Does not edit #382 or #409.

- Counts and mixes: `Enemies.WAVE_COUNTS` and `Enemies.WAVE_MIXES` in `src/ReplicatedStorage/Shared/Config/Enemies.luau`. `Enemies.validate` rejects a list that is not 6/8/10/12, a mix that drops a type, or a mix that misses the count.
- Math: `src/ReplicatedStorage/Shared/WaveFlow.luau`. Service: `src/ServerScriptService/ShardfallServer/WaveFlowService.luau`. Gray boxes are block specs (size and color from the type). The service does not parent parts.
- Remote: `ReplicatedStorage.Remotes.WaveCounter` (`RemoteEvent`). The server sends one table, `{ wave, left }`, with FireClient. It does not listen for a client fire. Nothing on the client reads it. `init.server` does not require the service.
- No profile write. `schemaVersion` stays 26. Live `Dungeons.waveCount` stays 2 through 8.

## What the boss wave adds

Server boss on the same flag, `LaunchGate.SHOW.enemyTypes` (**false**). Stacked on #417. Does not edit #382, #409, or #389.

- Stats and the adds count: `Enemies.BOSS`, `Enemies.BOSS_ADDS` (4), and `Enemies.BOSS_ADD_MIX` in `src/ReplicatedStorage/Shared/Config/Enemies.luau`. The mix is chaser, ranged, and tank only. `Enemies.validate` rejects a count other than 4, a mix that names something else, or a boss that is not taller and healthier than the tank.
- Wave 5 of `WaveFlow` / `WaveFlowService` spawns that boss plus the four adds as gray blocks. The service does not parent parts. `init.server` requires `WaveFlowService` so `PlayerRemoving` and `BindToClose` connect, and it does not start a run. Live `waveKinds(5)` is still Gnarl plus two adds.
- `bossEnter` fires when wave 5 becomes active. `bossDown` fires when that boss reaches 0 HP. Both go to `Shared.Analytics.event` when that module exists, or to `sink.analytics` when a caller passes one. The analytics module is not in this branch, so a normal boot does not log. No new remote. No client file reads the names. No profile write. `schemaVersion` stays 26.

## What the stuck check adds

Server watchdog on the same flag, `LaunchGate.SHOW.enemyTypes` (**false**). Stacked on #419. Does not edit #382, #409, or #389.

- Clock: `Enemies.STUCK_SECONDS` (30), `Enemies.STUCK_PROGRESS`, `Enemies.STUCK_NUDGE`, and `Enemies.SPAWN_CLEAR` in `src/ReplicatedStorage/Shared/Config/Enemies.luau`. `Enemies.validate` rejects a clock above 30.
- Math: `WaveFlow.step` tracks each living enemy. Closing on the target by `STUCK_PROGRESS`, or dealing or taking damage, clears the clock. At the limit it nudges off the blocked line and aims again. If that step is still blocked, it respawns on a clear point inside `Enemies.ARENA`.
- Service: `WaveFlowService.step` calls that math only while the flag is on. It does not publish `WaveCounter`, parent a part, or write a profile. `init.server` does not require it. No HUD file changes. `schemaVersion` stays 26.
- The live crawl is unchanged. `DungeonService.moveEnemy` still only clamps to the floor.

## What the enemy p2 pass adds

Stacked on #419. Same flag, `LaunchGate.SHOW.enemyTypes` (**false**). `waveArena` stays false. No new flag, remote, profile field, or Robux. `schemaVersion` stays 26.

- A ranged enemy inside `retreat` (12 studs) still backs up, and it fires. Point-blank contact deals the config damage. The arena clamp is unchanged.
- A ranged shot no longer pays damage at the aim point from the firing tick. The server moves the projectile and hits only if that path reaches the target's current position within `SHOT_RADIUS`. The line-of-sight ray uses that current position. Stepping off the path misses.
- `LEASH_RANGE`, `LEASH_SECONDS`, `LEASH_WINDUP`, and `LEASH_RADIUS` live in `Config/Enemies.luau`. `Enemies.validate` rejects a leash inside the boss melee range, a non-positive duration, or a windup too short to dodge. If the player stays beyond the leash for `LEASH_SECONDS`, the boss marks that spot and slams after `LEASH_WINDUP`. Leaving the radius deals 0. The boss HP is not restored.

## What the boss kite pass adds

Stacked on #425. Same flag, `LaunchGate.SHOW.enemyTypes` (**false**). No new flag, remote, profile field, or Robux. `schemaVersion` stays 26.

- `PRESSURE_SECONDS` (4) and `PRESSURE_DECAY` live in `Config/Enemies.luau`. The timer climbs while the boss deals no damage to its target. A damaging tick subtracts the decay. It does not snap to 0. `Enemies.validate` rejects a decay that would clear an armed timer.
- Outside melee, once pressure is armed, the boss uses Shard Volley: `VOLLEY_WINDUP` (0.8s), then `VOLLEY_SHOTS` (3) shots that lead the target, then `VOLLEY_COOLDOWN` (5s). A line-of-sight block still stops a bolt.
- The leash slam dashes to its mark at `LEASH_DASH` and finishes on that spot, clamped to `ARENA`. Chase is clamped the same way. The boss never regens.

## What the boss-clear reward adds

Stacked on #427. Same flag, `LaunchGate.SHOW.enemyTypes` (**false**). No new flag, no new remote, no HUD edit, no Robux. `schemaVersion` stays 26.

- The wave-5 clear pays `Economy.BOSS_CLEAR_TOKENS` (5 Roll Tokens, the boss row, not the 11-token full clear) into `shardTokens`. That 5 is the same on every tier. `tokenMultiplier` still scales the 11-token full clear (Hard 17) and does not turn the boss grant into 8. `Economy.validate` rejects a mismatch, a non-positive amount, and any Robux price key.
- `RunResults` is server to client. `bossClear` is `{ granted, tokens }` copied from the commit result after the save. A failed save, an unsaved table, or a client claim publishes `granted = false` and `0` tokens. The wave counter stays `{ wave, left }`.
- The grant is server-only and keyed by the run id `WaveFlow` mints with `HttpService:GenerateGUID`. A per-boot `run-N` was the same on every server, so a profile that already remembered `run-1` refused the next clear. Saves that already store `run-N` still load. The grant is written by the caller's save callback before `WaveCounter` is fired. A second commit for that id while the save is in flight does not pay again and does not report saved. If the profile changes during the write, it is saved again before the counter is fired. A failed save removes only that grant's tokens, floored at 0, and that run id. A spend or an earn during the write stays. It does not fire the clear.
- Remembered run ids are `profile.bossClearRuns`. A missing list loads as `{}`. The list keeps at most `BOSS_CLEAR_RUNS` (16) ids, newest last. This is the one new save field. It is bounded and it does not bump `schemaVersion`.
- A wipe does not grant and does not remove a grant that was already saved.
- A blocked line from the boss to the slam mark cancels the mark. The dash does not cross that line and the slam pays 0.
- Shard Volley windup is `VOLLEY_WINDUP` **0.9s**. The 5s cooldown is unchanged.

## What the enemy pool adds

Server pool on the same flag, `LaunchGate.SHOW.enemyTypes` (**false**). Stacked on #419. Does not edit #382, #409, or #389.

- Gray blocks are reused by `EnemyPool`. A death parks the block. The next spawn takes it back and clears health, target, projectile, every attribute, and every child. Release does not destroy the block. `WaveFlowService.stop` destroys that run's parts, marks the run stopped, releases its perf slots, and drops its track entry. clear, wipe, `PlayerRemoving`, and `BindToClose` all call stop. `init.server` requires the service and does not require the pool. A party wipe in `DungeonService` calls `WaveFlowService.wipe`.
- One alive cap, `Config.EnemyPerf.ALIVE_CAP` 22. The wave run does not store its own cap or a spawn queue. A wave of 12 spawns 12, because 12 is under 22. `left` on `WaveCounter` is the number still alive. The same remote fields, `{ wave, left }`. No new remote. No client file reads it. The only stuck watchdog is the 30 second clock on the live crawl.
- No profile write. `schemaVersion` stays 26. Live `waveKinds` is unchanged. A normal boot does not start a run, so the pool creates nothing.
