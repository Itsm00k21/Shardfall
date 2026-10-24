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
| 3.3 Chaser + wave spawner | partial | A wave spawner exists and is the endless crawl, not the V1 list. `DungeonService.luau:1100` `spawnWave`, `Dungeons.luau:741` `waveKinds`, count starts at 2 (`Dungeons.luau:100`, `waveCount` at 701). Every live enemy uses the same chase (`DungeonService.luau:2096` `moveEnemy`). #415 adds a **chaser** row (`src/ReplicatedStorage/Shared/Config/Enemies.luau:63-81`), copies it onto `Config.Enemies` (`Dungeons.luau:857`), and steps it in `EnemyTypeService.luau:39`. `LaunchGate.luau:41` `enemyTypes` is false, and `waveKinds` does not spawn it. | Spawner: live branch / open #6. Chaser type: #415. #382 also drafts a chaser inside its unmerged arena config. |
| 3.4 Ranged and tank | partial | Live projectile and bulky melee are named creatures (`spore_bat`, `root_brute`), not the V1 ranged and tank. #415 adds both (`Config/Enemies.luau:82-100` ranged, `:101` tank) with kite, slow move, and `damageTaken`. Same flag. Live `waveKinds` still does not spawn them. The gated 3.5 mix does, only while the flag is on. | Old creatures: live branch (`f30836b`, open #3) and Far Glade #340. V1 ranged and tank: #415. |
| 3.5 Waves of 6 / 8 / 10 / 12 and a wave counter | partial | The HUD still shows `Wave N` (`Ui.luau:603-611`). Live counts are still 2, then +1 every 2 waves, cap 8 (`Dungeons.luau:100-102`). The run is endless. `Config/Enemies.luau` holds 6/8/10/12 and a chaser/ranged/tank mix. `WaveFlowService` pushes `{ wave, left }` on `Remotes.WaveCounter` only while `enemyTypes` is on. That flag is off, so boot does not start a run and no client file reads the remote. | Live counter text: live branch / open #6. Gated list and remote: this branch, stacked on #415. #382's 6/8/10/12 list is all chasers (`WaveArenaConfig.luau:216-222`) and is not merged. |
| 3.6 Boss + 4 adds on wave 5 | partial | Live wave 5 is still Gnarl **plus 2 adds**, not 4: `Dungeons.luau:749` returns `{ grandmother_gnarl, vine_crawler, spore_bat }` (`isBossWave` at 697, every 5 at `:103`). The gated flow's wave 5 is one boss plus 4 adds from chaser, ranged, and tank (`Config/Enemies.luau` `BOSS`, `BOSS_ADDS`). `enemyTypes` is off, so boot does not spawn it and the HUD is unchanged. | Live crawl: live branch / open #6. Gated boss: this branch, stacked on #417. #382 sets `adds = 4` at `WaveArenaConfig.luau:130` and is not merged. |
| 3.7 No early exit. Keep every earned drop, including on a wipe | partial | Live wipe keeps kill loot because the grant is saved at the kill (`DungeonService.luau:1888-1912`) and `finish(player, false)` (`:3159`) does not take it back. Cleared-wave copy says those rewards stay (`Dungeons.luau:607`). The same server still offers an early exit: `DungeonService.leave` at `:2767`, action `"leave"` at `:2946`, HUD Leave shown at `Ui.luau:634`. That exit breaks the Oct 23 rule. | Leave and kill grants: live branch (`f30836b`, open #3). #382 adds a second early exit and drops ground chips (below). |
| 3.8 Stuck-enemy check, max wave, none stuck after 30s | missing | `moveEnemy` clamps to the floor (`DungeonService.luau:2124-2128`). Nothing times a 30s stall. `DungeonConfig.luau:11-19` is spawn clearance (clipping at spawn), which is a different check. | Spawn clearance is merged #364. The 30s stall check exists only on unmerged #382 (`Stuck.luau`, `WaveArenaConfig.luau:193` `seconds = 30`). |

Status words: **done** would mean Kevin can play the locked rule on the live branch. None of 3.1–3.8 are done. #415 moves 3.3 and 3.4 to partial: the server types exist, the flag is off, and no live wave spawns them. The wave-flow change moves 3.5 forward, still partial: the counts and the server counter exist, the flag is off, and the on-screen HUD is unchanged. The boss change moves 3.6 forward, still partial: the gated wave 5 is a boss plus 4 adds, the flag is off, and the live crawl is still Gnarl plus 2.

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
- Server: `EnemyTypeService` steps, applies hits, and describes gray **blocks** only while the flag is on. `init.server` does not require it. No remote, no HUD, no `schemaVersion` change, no profile write.
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
- Wave 5 of `WaveFlow` / `WaveFlowService` spawns that boss plus the four adds as gray blocks. The service does not parent parts. `init.server` does not require it. Live `waveKinds(5)` is still Gnarl plus two adds.
- `bossEnter` fires when wave 5 becomes active. `bossDown` fires when that boss reaches 0 HP. Both go to `Shared.Analytics.event` when that module exists, or to `sink.analytics` when a caller passes one. The analytics module is not in this branch, so a normal boot does not log. No new remote. No client file reads the names. No profile write. `schemaVersion` stays 26.
