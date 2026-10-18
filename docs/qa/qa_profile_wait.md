# Startup wait test plan

G-073. Client waits that can still stall `GetProfile`. This file does not change code.

`ProfileUpdated` and `PolicyUpdated` are bounded on this tip. Each uses `REMOTE_WAIT_SECONDS` (15). A miss skips that connect, and `GetProfile` still runs (`init.client.luau:1434-1454`). Those two are not open stalls.

Do not retest the bounded `invoke` wait (`init.client.luau:229-234`) or the `CombatHud.start` waits for `Attack`, `Dodge`, and `CombatFx` (`CombatHud.luau:157-177`). Those already time out at 15 seconds.

Choice: a wait counts only when this script yields on it before `GetProfile`. Module requires at `init.client.luau:33-56` also yield, because each file waits for `Shared` with no timeout at load. The high rows are the remote waits that still have no second argument.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| W1 | `HavenClient.start` waits forever for `Remotes` and `HavenPrompt` | `init.client.luau:1341`, `HavenClient.luau:214-215` | high | `HavenPrompt` missing. `start` never returns. `RaidHud`, `ClassHud`, `CombatHud`, and `GetProfile` never run. No profile toast. Output never reaches the `GetProfile` error |
| W2 | `RaidHud.start` waits forever for `CombatFx` | `init.client.luau:1390`, `RaidHud.luau:233-234` | high | `Remotes` exists and `CombatFx` does not. The script stops inside `RaidHud.start`. The bounded `CombatHud` wait for the same remote never runs. `GetProfile` never runs. Raids are parked, and this start still runs |
| W3 | `ClassHud.start` waits forever for `SetClass` | `init.client.luau:1411`, `ClassHud.luau:332` | high | `SetClass` missing. The class screen is parented, then `start` yields. `CombatHud.start` and `GetProfile` never run |
| W4 | The first `Shared` waits have no timeout, so a missing folder never reaches the 30 second `Remotes` warning | `init.client.luau:28-32`, `init.client.luau:190-193` | medium | `ReplicatedStorage.Shared` missing, or `ClientChrome`, `LegacyChrome`, `UiRouter`, `ForeignScripts`, `Areas`, `Currencies`, or `Quality` missing. The script yields there. `GetProfile` does not run. The line at `init.client.luau:200-203` is the one that warns and returns |
| W5 | `PlayerGui` has no timeout | `init.client.luau:107` | medium | `PlayerGui` missing. Everything after that line, including `GetProfile`, waits. Later `PlayerGui` waits in `MarketHud.luau:148`, `CombatHud.luau:185`, `ClassHud.luau:120`, `RaidHud.luau:99`, `LoopHud.luau:609`, `DoorHud.luau:43`, `OnboardHud.luau:30`, `PetHud.luau:20`, `CaptureHud.luau:157`, and `DebugHud.luau:37` are the same instance. They return immediately once line 107 has resolved |
| W6 | Required modules wait for `Shared` children with no timeout while `init` is still loading | `init.client.luau:33-56` | low | A renamed module in `MenuHub.luau:25`, `Ui.luau:29`, `CombatHud.luau:23`, `ActionBar.luau:33`, or `HudShell.luau:18` yields at `require`. `GetProfile` does not run. Once `Shared` and the child are present, these return immediately |

W1, W2, and W3 are the stalls that remain after the profile events were bounded. W4 is the stall before any remote timeout.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| PW-1 | `Remotes` present. `ProfileUpdated` and `PolicyUpdated` absent | Play | Within 15 seconds each wait ends. The matching connect is skipped. `GetProfile` still runs. A hang on either name fails |
| PW-2 | `HavenPrompt` absent. Everything else present | Play | `HavenClient.start` returns. `GetProfile` runs. A hang before the profile call fails W1 |
| PW-3 | `CombatFx` absent | Play | `RaidHud.start` returns. `CombatHud.start` then warns and returns on its own 15 second budget. `GetProfile` runs. A hang inside `RaidHud` fails W2 |
| PW-4 | `SetClass` absent | Play | `ClassHud.start` returns. `GetProfile` runs. A hang on `SetClass` fails W3 |
| PW-5 | `Shared` absent | Play | The script warns or returns within 30 seconds. An unbounded wait that never reaches `init.client.luau:200` fails W4 |
| PW-6 | `PlayerGui` absent | Play | The wait at `init.client.luau:107` ends with a timeout and the script stops, or `GetProfile` still runs. An infinite wait fails W5 |
| PW-7 | Place complete, all of the above present | Play | `GetProfile` runs. Output shows the client build line, then a profile apply or the load error. None of W1 through W6 fire |
| PW-8 | `Attack` absent, `CombatFx` present | Play | This is the bounded `CombatHud` path. It warns and returns. `GetProfile` runs. Do not file it again. Confirm only that W2 did not swallow it |

## Already locked

Do not re-file these.

| area | locked by |
|---|---|
| `invoke` stops at 15 seconds and returns an error table | `init.client.luau:229-241` |
| `CombatHud.start` stops at 15 seconds for `Attack`, `Dodge`, and `CombatFx` | `CombatHud.luau:157-177` |
| Humanoid follow stops at 8 seconds | `init.client.luau:78` |
| `Remotes` folder stops at 30 seconds and returns | `init.client.luau:200-203` |
| `ProfileUpdated` and `PolicyUpdated` stop at 15 seconds | `init.client.luau:1434-1450` |

## Flags

None. No paid path runs before `GetProfile`.
