# Save wipe plan

Status: **plan only**. Nothing in this file deletes a key, ships a wipe, or adds wipe code. `schemaVersion` stays 26. Launch flags stay off. No Robux product is involved. A client cannot ask for a wipe. Do not run a wipe from this document.

A wipe is a possible later decision if a pre-launch economy reset is actually approved. It is not approved here, and it is not a migration. A server that still reads version 26 must keep reading these profiles.

## Scope

In scope, if a wipe is ever approved:

- DataStore name `ShardfallPlayer_v1` (`StoreAdapter.luau`).
- Keys `Player_<userId>`, the same key `DataService` loads.
- The whole document for each in-scope key: `Data` and `Lock`.

Out of scope:

- `ShardfallProbe`. Leave the probe key in place.
- Ordered stores, messaging topics, and memory-only Studio sessions. A Studio session with API access off is not a live profile and must not be written back over a real key.
- Any profile whose `schemaVersion` is not 26. Stop and report it. Do not rewrite it to force 26.
- Paid products, receipts, and refunds. Nothing in the live game charges Robux. A later paid wipe would be a separate decision.
- LaunchGate switches. A wipe does not turn a parked system on.

The server is the only writer. There is no remote, dev button, or chat command for this.

## Backup

Take the backup before any delete, and do not treat a copy that failed partway as a backup.

1. Read every `Player_*` key in `ShardfallPlayer_v1`. Count the keys.
2. Write two copies of that export. One stays offline, off the game servers.
3. Check a sample round-trip: `schemaVersion` is 26, and gold, bag size, and tokens match the live document.
4. Abort if the export count does not match the live key count, or if any sample mismatches. Do not delete anything after a failed export.
5. Do not "back up" by writing an empty template over the live key.

## Comms

Kevin approves the wipe before anyone is told a time, and again before it runs. Players hear the window before it starts. Say what is erased (that profile's progress), what is not (the Roblox account), and that the client cannot undo it. No silent wipe, and no wipe during a normal play session. Support gets the same note, including the line to use when someone says the save is gone.

## Rollback

Rollback restores the backup. It does not invent a new profile.

1. Stop the wipe if it is still running. Do not keep deleting while a restore is in progress.
2. Write each backed-up document back to the same key. A key that fails to restore stays untouched until it can be retried. Do not fill it with `Schema.template()`.
3. Restore all of the backup or stop and say which keys are left. A partial restore is not done.
4. Locks in the restored documents should be clear, or old enough that a join can claim them. A lock still owned by a dead server makes the player look busy for the 20 minute timeout.
5. Join with one restored account and compare gold, tokens, and bag size to the backup. Then stop. Do not keep playing on a restore that has not been checked.
6. If the restore itself fails, stop. Keep both backup copies. Do not publish a build that changes `schemaVersion` to paper over a bad restore.

## This change

This file is the plan. No code reads it. Shutdown saves and duplicate roll, salvage, and equip invokes are covered by tests, not by deleting data.
