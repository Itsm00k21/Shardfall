# Two-agent coordination

GHOST (this account) and HELPER (second account) share `cursor/live-build-9721`. The board is `TASKS.md` at the repo root. Design docs for both accounts are in `docs/design/`. Echo fallback protocol: issue #15, comment 6228878047 (https://github.com/Itsm00k21/Shardfall/issues/15#issuecomment-6228878047).

## Branches

- Integration branch: `cursor/live-build-9721`. Pull requests land here. Do not retarget them at `main`.
- GHOST feature branches match `cursor/<name>-9721`.
- HELPER feature branches match `helper/<name>-9721`.
- Each agent writes code only on its own branch. The integration branch receives that work through a pull request.
- One branch per claimed task. Do not mix two task ids on one branch.

## Claims

1. Pick a row in `TASKS.md` that is `claimed` or move an `Open` row to your section.
2. Commit that edit by itself, before any code: set owner, branch, status `claimed`, and the files you will touch.
3. Then branch and implement.
4. When the work is finished, set status to `done` and put the PR link on the row. Do that in the same commit as the handoff note.

Do not start a task someone else has already claimed.

## File ownership

Work only inside the files and folders on your claimed rows.

Do not edit a file owned by the other agent's claimed or owned task. That includes combat, classes, Rootvault, Heartwood, onboarding, and the shared modules under T-012 while GHOST owns them.

Shared modules change only through GHOST, or after a note on the task row in `TASKS.md` that names the file and the change:

- `src/ReplicatedStorage/Shared/Schema.luau` (player data version, template, migrate, snapshot)
- `src/ServerScriptService/ShardfallServer/Remotes.luau`
- `src/ServerScriptService/ShardfallServer/RateLimiter.luau` (a new remote with no rule is rejected)
- `default.project.json` (new remotes)
- `src/ServerScriptService/ShardfallServer/init.server.luau`
- `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`
- `src/ReplicatedStorage/Shared/Build.luau`

HELPER tasks that need a hook in `CombatHud.luau`, `DungeonService.luau`, or `Rootvault.luau` say so on the row and wait. Those files are GHOST's.

New self-contained modules listed on a HELPER row belong to that task. Do not put the feature inside a GHOST file to avoid the note.

## Build stamp

Every code push that changes gameplay updates the printed stamp. Docs-only commits do not.

After the feature commit, `git rev-parse --short HEAD`, then replace the previous stamp in:

- `src/ReplicatedStorage/Shared/Build.luau` (`Build.STAMP`)
- `src/ServerScriptService/ShardfallServer/init.server.luau` (comment and `print`, before any `require`)
- `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau` (comment and `print`, before any `require`)
- `src/ServerScriptService/ShardfallServer/DungeonService.luau` (the `[Rootvault] build` print)

Second commit message: `Record the build stamp as <sha>+.` Do not amend a pushed commit. The printed line is `<sha>+`. The tip may be the stamp commit.

GHOST owns `Build.luau`. HELPER edits those four lines only as this stamp step, and mentions it on the task row.

## Tests

Before pushing code:

- `selene src` (0 warnings). Do not treat `selene tests` as the gate.
- `lune run tests/run`
- `rojo build -o /tmp/Shardfall.rbxlx` when modules or `default.project.json` changed.

Add tests for new rules. Stylua: tabs, column width 100.

## Handoff

After each work session, add `docs/handoffs/YYYY-MM-DD-<agent>.md`.

Use `ghost` or `helper`. If you already wrote one that day, add a session heading to the same file.

```markdown
# YYYY-MM-DD <agent>

## Done
- T-000: what landed, branch, PR link, printed build stamp if code changed

## Blocked
- what is stuck, and which file needs the other agent

## Next
- the next task id
```

## Design docs

Read `docs/design/` before implementing a system. Build the beta scope (and the v1.1 notes the task names). Leave post-beta items that are not on your row.

| doc | file |
|---|---|
| Combat | `docs/design/shardfall_combat.md` |
| Classes | `docs/design/shardfall_classes.md` |
| Rootvault | `docs/design/rootvault_design.md` |
| Onboarding | `docs/design/shardfall_onboarding.md` |
| Progression | `docs/design/shardfall_progression.md` |
| Economy | `docs/design/shardfall_economy.md` |
| Pets | `docs/design/shardfall_pets.md` |
| Daily / weekly | `docs/design/shardfall_loops.md` |
| Raids | `docs/design/shardfall_raids.md` |
| Audio | `docs/design/shardfall_audio.md` |
