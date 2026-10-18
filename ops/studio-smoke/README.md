# Studio smoke

Nothing in this folder ships. `src/` is never edited. `selene src` and `lune run tests/run` do not load these files. The game place (`default.project.json`) does not include `ops/`.

## Mac Studio launcher

`studio_run.sh [--no-pull] [--timeout SECS] [--ref GITREF]`

Runs on Kevin's Mac. It fast-forwards `origin/cursor/live-build-9721` unless `--no-pull` or `--ref` is set, instruments a copy, opens that place in Roblox Studio, and tails the Studio log. Do not run it in CI. It does not touch the checkout except for that optional fast-forward.

- `instrument.luau` copies `src/` to `~/ShardfallAudit/smoke_build`. It routes client `:Connect` on button and input signals, plus `ContextActionService:BindAction`, through `SmokeShim`, which records each handler and still connects it. It injects the shim after the build print, and copies `SmokeServer` and `SmokeClient` into `ShardfallServer` and `ShardfallClient` so the foreign-script scan leaves them alone.
- `compile_check.luau` compiles every `.luau` under the build with Luau. The launcher runs it on that copy only.
- `plugin/` is inert unless the open place has `ServerStorage.StudioSmokeMarker`. The launcher installs it as `StudioSmoke.rbxm` for the run, starts Play through `StudioTestService:ExecutePlayModeAsync`, then removes the plugin. It kills only the Studio process it started.
- `SmokeServer.server.luau` and `SmokeClient.client.luau` print `SMOKE|<run>|<side>|<STATUS>|<check>|<detail>`.
- Output: `~/ShardfallAudit/studio_smoke_<run>.log`.

`SmokeClient` expects the six-button rail: Hero, Bag, Pets, Roll, Shop, Settings. Market and Pass must be hidden. Key M must leave the hub closed. The RimShop prompt must open Shop and show `Gold shop. A Healing Tonic and a bag slot.` Warden is picked before keys 1-8. Slots 7 and 8 stay empty on a fresh Warden bar.

## Lune lock

`run.sh` runs `lune run ops/studio-smoke/run`, which requires `tests/StudioSmoke.spec.luau`. That spec is also in `tests/run.luau`. It checks the same six-button expectations without Studio.

`play.luau` is the command-bar script. Play the place, switch the command bar to Client, and paste it. It is separate from `SmokeClient`.
