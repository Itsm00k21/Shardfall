# Phase 0.5 — Save system

Status: spec for the save path that already ships on `cursor/live-build-9721`.
Schema stays **26**. This phase does not add a field and does not rewrite a
healthy save. V1's facts (ids, levels, currencies, pity, receipts) already
live in that shape. A new version with nothing to fill would touch every
profile for no data change.

Studio with DataStore API access off already uses the in-memory store and
does not write. Forcing that mock while API access is on is a `StoreAdapter`
change and is not in this phase. See the hook note at the end.

## Document

| | |
|---|---|
| DataStore name | `ShardfallPlayer_v1` (`StoreAdapter`) |
| Key | `Player_<userId>` |
| Envelope | `{ Data = profile, Lock = { jobId, placeId, lockedAt } }` |
| Profile version | `Data.schemaVersion` (number). Current build: `Schema.VERSION` = 26 |

`UpdateAsync` is the only write. A transform that returns nil leaves the key
unchanged. That is how a busy lock, a corrupt profile, and a newer schema
avoid a wipe.

## Current profile (v26)

Plain JSON only. No Color3, Instance, Vector3, CFrame, function, NaN, or
infinity. `Schema.migrate` returns a copy. The table the caller passed in
is not edited.

V1 reads these. Older systems still have their own fields; migrations do
not delete them.

| V1 fact | Field | Notes |
|---|---|---|
| Account level | `level`, `xp`, `ascension` | Level starts at 1 |
| Gold | `gold` | Whole number, minimum 0 |
| Roll tokens | `shardTokens` | V1 Roll Tokens. New profiles start at 10 |
| Pity | `sinceEpic`, `sinceLegendary`, `pity` | `pity` is the old per-pool map and is left in place |
| Item ids | `inventory`, `pets` | `uid`, `templateId`, level-like `upgrade` / `stars` |
| Equipped ids | `equipped` | Weapon, pet, armor, accessories. Uids must exist in the bag |
| Receipts | `receipts` | Map. A missing map becomes `{}`. Existing ids stay |

Other stored groups (not removed): materials, consumables, vouchers, crafting,
waystones, settings, classes, onboarding, chests, dailies, raids, trading,
starter goals, first session, action bars, codex, training grove. Parked
systems stay in the save so turning a flag back on does not look like a
wipe.

Unknown keys are kept when the value is JSON (string, finite number,
boolean, or a table of those). A future field written by a newer build that
has not bumped `schemaVersion` still round-trips. NaN, infinity, functions,
and Roblox values are removed from the migrated copy only.

A missing DataStore key is a new player: `Schema.template()`, not the
version walk. The v14 step would otherwise mark the tutorial finished.

## Version rules

`SaveMigrate.versionOf` reads the field:

| Stored `schemaVersion` | Result |
|---|---|
| missing (`nil`) | version 1, versionless. Walk v2 → v26. Fields that are already present stay (`keepExisting`) |
| `0` or any number `< 1` | run the v1 step, then the rest |
| `1` … `26` | run only the steps above that number |
| `> 26`, including `+inf` | `"newer"`. Do not load, do not write |
| not a number, or NaN | `"corrupt"`. Do not load, do not write |
| `inventory`, `pets`, or `materials` present and not a table | `"corrupt"`. Do not replace the bag with `{}` |

`Schema.MIGRATIONS` is the ordered list. Step `i` has `to == i`. Each
`apply` is the v_(n-1) → v_n fill. `SaveMigrate.run` skips a step when
`version >= step.to`, then sets `schemaVersion` to `to`. `Schema.reconcile`
fills any key the steps left nil and clamps wallets. It does not reset a
wallet that is already there.

## Migration steps

| Step | What an older save gains |
|---|---|
| 1 | First shipped shape. No field rewrite |
| 2 | `equipped.armor` |
| 3 | `materials`, `consumables`, `vouchers` |
| 4 | Star fields on gear. `stats[].baseValue` copied from `value` once |
| 5 | `prismTokens`, `luckBoost` (not copied from shard tokens) |
| 6 | Crafting level, xp, milestones, `forgeBoostUntil` |
| 7 | `inventoryBonus`, accessory slots, lock / favorite / sockets |
| 8 | Waystones, `lastTravel`, `travelPass` |
| 9 | `graphicsQuality` |
| 10 | Shard pity counters, quick roll, VIP, shake |
| 11 | Chests, keys, dust, login and boss clocks |
| 12 | Music and sfx volumes |
| 13 | `classId`, `classXp`, `classTalent` |
| 14 | Onboarding step. A versionless save keeps a real `onboardDone` boolean |
| 15 | Rest and welcome charges, `lastSeen`, titles |
| 16 | `gems`, `eventTokens`, `ledger`, `receipts` |
| 17 | `eggs`, `companions` |
| 18 | Dailies, weekly, pass, board |
| 19 | Raid marks, lock, pity, story, echo, best |
| 20 | Trade day, value, locks, flags |
| 21 | `uiSettings` |
| 22 | `starterGoals` |
| 23 | `firstSession` |
| 24 | `actionBars` |
| 25 | `codex` |
| 26 | `trainingGrove` |

A versionless save that already has one of these fields keeps it. A real
older version (the field is missing because that step had not shipped)
receives the default.

## Session lock

Pure rules: `SessionLock`. DataService applies them inside `UpdateAsync`.

Lock value: `{ jobId, placeId, lockedAt }` plus an optional `userId`.
Old locks omit `userId`. That field is not `schemaVersion` and does not
bump the profile. A missing `userId` still means the player who owns the
`Player_<userId>` key.

| Status | Meaning | This server may |
|---|---|---|
| free | no lock, or `jobId == ""` | claim |
| owned | `jobId` is this server | save, refresh `lockedAt` |
| busy | another server, `now - lockedAt < 20 min` | nothing. Transform returns nil |
| expired | another server, age `>= 20 min`, or the timestamp is NaN / infinity | steal: claim, keep `Data` |
| studio stale | Studio only, same `userId` (or a legacy lock with no `userId`), age `>= 60s`, still inside 20 min | same steal. `status` reports `"expired"` |

`SessionLock.TIMEOUT_SECONDS` is 20 minutes. Autosave is 60 seconds, so a
live server refreshes the lock long before it looks stale. Studio uses
`SessionLock.STUDIO_STEAL_SECONDS` (60) for a lock held by the same user.
A live server does not. A different user id keeps the 20 minute rule even
in Studio. The short steal is a claim. `trySave` still returns nil unless
this server already owns the lock, so a busy profile is not written.

This server's own lock stays `owned` even when `lockedAt` is old. A slow
autosave must not kick the player who is playing here. Another server
treats that same timestamp as expired and may steal. That is the crash
timeout.

No double-load on this process: `SaveGuard.alreadyOpen` is true when a
record is already in the map, or when `PlayerAdded` already started that
player. The second call returns before `UpdateAsync`.

Steal writes the migrated profile, not a blank template. Gold, items, and
receipts from `Data` come back from `Schema.migrate` and are what the new
lock stores.

A cleared lock (`jobId ""`, `placeId 0`, `lockedAt 0`) is free. Release
uses that so the next server can load. `tryRelease` only clears a lock
this server owns, and it copies `Data` through unchanged.

## Retry

Base delay is `LOAD_RETRY_SECONDS` (2) in DataService. `SaveRetry.pauses`
is how many times that delay runs:

| Attempt | Pauses | Wait |
|---|---|---|
| 1 | 1 | 2s |
| 2 | 2 | 4s |
| 3 | 4 | 8s |
| 4 and later | 4 | 8s |

Loads try `LOAD_ATTEMPTS` (5) times. The next wait happens only for
`"busy"` and `"error"`. `"corrupt"` and `"newer"` do not retry.

A live busy lock does not use that backoff. It loads
`SessionLock.LIVE_BUSY_ATTEMPTS` (4) times and waits
`SessionLock.liveBusyPause` between them: 10 seconds, three times, about
30 seconds, then kicks. The 20 minute steal does not change. Studio does
not use this window. A same-user lock at least 60 seconds old is claimed
on the first load. A fresh Studio lock (under 60 seconds) still uses the
table above, then kicks. `"error"` on either server still uses the table.

Writes try `SaveRetry.WRITE_ATTEMPTS` (3) times. Retries are `"error"`
(the call threw) and `"unwritten"` (the transform never reported).
`"lost"` and `"missing"` do not retry. Retrying a lost lock could take
the profile back from the server that stole it.

`StoreAdapter` still has its own short retry around one `UpdateAsync`.
That is unchanged.

## Autosave

Every 60 seconds (`AUTOSAVE_SECONDS`). One pass over the players who are
still in the server. It skips a record that is not loaded, failed,
ephemeral, released, or closing for a teleport.

A successful autosave refreshes `lockedAt` and writes the in-memory
profile. `"lost"` kicks the player: the lock moved, and this server must
not keep granting loot. Any other failure warns and tries again next
interval. Memory is not rolled back on a failed autosave.

The worst crash loses one interval of play.

## Shutdown flush

`PlayerRemoving` and `game:BindToClose` both call `DataService.release`.
Release writes and clears the lock when `ProfileLoad.maySave` says the
profile was loaded and is not ephemeral.

Studio Stop can remove the player before `BindToClose` runs. The callback
also releases any profile still in memory and any release `PlayerRemoving`
already started. A second `release` waits until that write finishes. It
does not return early and let Studio kill the `UpdateAsync` while the
lock is still held.

The wait uses `ProfileLoad.shutdownStillWaiting` for 30 seconds, counting
both the players queued in the callback and a release that is still open.
Autosave does not start a second write after `shuttingDown`. A teleport
that already released the lock is not written again.

## Failure behavior

| Case | Memory | DataStore | Player |
|---|---|---|---|
| Corrupt profile, or bag is not a table | not loaded | key unchanged | kicked. "could not be read. It was not overwritten." |
| Schema newer than this build | not loaded | key unchanged | kicked. Ask them to rejoin after the server updates |
| Lock busy, live, after 4 loads across ~30s | not loaded | key unchanged | kicked. Rejoin in a moment |
| Lock busy, Studio, same user, age >= 60s | loaded | claimed; saved gold kept | stays |
| Lock busy, Studio, fresh (under 60s) or a different user id | not loaded after the short retries | key unchanged | kicked. Rejoin in a moment |
| Live DataStore error after retries | not loaded (`failed`) | key unchanged. Owned lock from a timed-out attempt is cleared with `tryRelease`, which does not replace `Data` | kicked |
| Studio, or the store is not persistent, and the read throws or times out | ephemeral template, or the session profile `open` returned | not written. `save` returns success and does not call `UpdateAsync` | stays. Output says memory, not saved |
| Autosave sees `"lost"` | `loaded` cleared | not written | kicked. Session moved |
| `write` when `failed` | unchanged | `SaveGuard.refusesWrite` returns before `UpdateAsync` | already kicked on the failed load |

`save()`, `replace()`, and autosave all refuse a failed record. Release
does not call `write` unless the load had succeeded and the session is
not ephemeral.

## Test plan

`lune run tests/run` includes `tests/Phase05Save.spec.luau` and
`tests/SaveLockRelease.spec.luau`.

| Case | What it checks |
|---|---|
| Step list | 26 steps, `to == index`, `Schema.VERSION == 26` |
| No version | loads as v1, gold / level / item id / pity stay, unknown string stays, NaN and a function are dropped, caller's table is not edited |
| v1 fixture | gold, level, xp, shard tokens, template id, and an existing receipt survive to v26 |
| One step | `SaveMigrate.run` on a copy sets v1 and leaves the original table |
| Newer and NaN | `"newer"` / `"corrupt"`, no profile |
| Acquire | free key claims; second job is `"busy"` and the first document is unchanged |
| Steal | age `>=` timeout is `"expired"`; claim keeps gold; the previous lock table is not rewritten in place |
| Not stale | fresh foreign lock stays busy; this server's own old lock stays writable |
| Store steal | `ProfileLoad.open` on a fresh lock does not write; after the timeout the same gold is stored under the new job id |
| Backoff | pauses 1, 2, 4, 4; lost and missing are not retried |
| Failed load | corrupt `open` leaves gold and the bad bag; a thrown `updateAsync` leaves gold; `refusesWrite` skips the write |
| Wiring | DataService still autosaves at 60s, flushes on `BindToClose`, checks the failed-load guard before `updateAsync`, and waits `LOAD_RETRY_SECONDS` inside `SaveRetry.pauses` |
| Studio stale lock | same user, age >= 60s, claims and keeps gold; 59s, a different user, and a non-owner save do not write |
| Fresh live lock | a few seconds old, and 90s old, stay busy; the store is unchanged; the live retry window is 30s across 4 loads |
| Release on close | `ProfileLoad.release` clears the lock and keeps gold; `PlayerRemoving` and `BindToClose` both release, and shutdown waits for an in-flight write |

Existing `Schema.spec`, `SessionLock.spec`, `SaveLocks.spec`, and
`ProfileLoad` specs stay the regression net for every older step.

## Hooks not taken

- `StoreAdapter`: Studio with API access on still uses the live DataStore. A mock-by-default switch belongs there. Do not point Studio at live keys until that switch exists.
- `DebugService`: Dev Tools lists "Force autosave" and "Print save version" behind `LaunchGate.saveTools` (default **off**). While it is off the server refuses them before `mutate`. When it is turned on, `DebugService.run` should call `DataService.save` and print `schemaVersion` instead of falling through to `DebugTools.apply`.
- Build stamp files (`Build.luau`, the two init scripts, `DungeonService`) are not edited here.

## Out of scope

New currencies, a schema 27 bump, Robux, receipt product ids, and any
change that replaces a profile that failed to load.
