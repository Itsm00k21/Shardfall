# Echo batch Studio playtest (#381, #382, #383, #384)

One ordered Studio session for Kevin. Do the steps in order. Twenty steps, five per PR. This file does not change code and does not merge anything.

Play one unpublished Studio place that already contains all four branches plus the hookups still landing on them: boot requires, the arena enter remote, and the WaveArena client UI under `StarterPlayer/StarterPlayerScripts/ShardfallClient/WaveArena/`. A step that needs one of those says so. Until that piece is in, that step cannot pass.

## Preamble

Use a test account, not the account that holds the main save. With Studio Access to API Services on, this place writes the live `ShardfallPlayer_v1` key for whoever is in the session. An unpublished place (`CreatorId` 0) still shows the **Dev** button for that test account. A published group place answers `Dev tools are for the game owner only.`

Wait about 11 minutes between Play sessions so the save lock clears. A clean Stop releases the lock on leave. If the next Play says `Your data is still open on another server. Rejoin in a moment.`, the lock is still held (`SessionLock.TIMEOUT_SECONDS` is 20 minutes). Stop. Do not keep playing on that account.

Turn every flag back off when the batch ends (step 20). Do not publish with any of them true.

If Output says `Your Shardfall profile could not be read. It was not overwritten.` or `This server is out of date for your Shardfall profile. Rejoin shortly.`, stop the whole batch. That save was not overwritten.

Leave these Dev buttons alone for the whole batch. They write the test profile: `+1000 Gold`, `+5 Shards`, `+20 Keys`, `+50 Dust`, `+50 Gems`, `+5 Prisms`, `+10 Event Tokens`, and the Progress grants.

### Where the switches live

Edit the file, Rojo-sync, then Play. Each step names the value to set.

| Switch | File | Shipped |
|---|---|---|
| `LaunchGate.SHOW.saveTools` | `src/ReplicatedStorage/Shared/LaunchGate.luau` | `false` |
| `LaunchGate.SHOW.waveArena` | same file | `false` |
| `WaveArenaConfig.enabled` | `src/shared/Config/WaveArenaConfig.luau` | `false` |
| `LaunchGate.SHOW.analytics` | `LaunchGate.luau` | `false` |
| `Analytics.ENABLED` | `src/ReplicatedStorage/Shared/Config/Analytics.luau` | `false` |
| `LaunchGate.SHOW.payouts` | `LaunchGate.luau` | `false` |

The arena runs only when `LaunchGate.SHOW.waveArena` and `WaveArenaConfig.enabled` are both `true`. Analytics sends only when `LaunchGate.SHOW.analytics` and `Analytics.ENABLED` are both `true`. The refusal text calls that second switch `Config.Analytics.ENABLED`.

The **Dev** button (`DevTools.BUTTON_TEXT`) sits under the Gold / Mastery / Shards pills. It opens **Dev Tools (owner only)**. A press toasts one line and prints `[Dev] ok ...` or `[Dev] FAIL ...` in Output. Buttons for a flag that is off are hidden. The footer lists them after `Hidden while their system is off (LaunchGate):`.

Schema stays 26 for this whole batch.

---

## #381 Save system

### 1. Memory session, save buttons hidden

**Flags.** `LaunchGate.SHOW.saveTools = false`. Every other switch in the table stays `false`. Game Settings → Security → Enable Studio Access to API Services **off**.

**Buttons.** Press **Dev**. Do not press **Force autosave** or **Print save version**. They are `Debug` remote args `autosave` and `saveversion`, both gated by `saveTools`.

**Pass.** Output includes `This session keeps profiles in memory and will NOT save.` The load line is `via memory (not saved)`. No error on screen. Testing does not show **Force autosave** or **Print save version**. The footer lists both.

### 2. Live load is schema v26, and a rejoin matches

**Flags.** `LaunchGate.SHOW.saveTools` stays `false`. Turn API Services **on**. Stop, wait the 11 minutes, Play.

**Buttons.** None.

**Pass.** Output includes `[Shardfall] Loaded <name> (<userId>) via DataStore (schema v26)`. Note the Gold pill and the bag. Stop so the leave flush runs. Wait the 11 minutes. Play again. Gold and the bag match. The load line is `schema v26` again.

### 3. Shutdown flush keeps the gold

**Flags.** Unchanged. API Services stays on.

**Buttons.** None.

**Pass.** Note the gold. Stop the server while the character is still in the game, so `BindToClose` flushes. Wait the 11 minutes. Play again. The same gold is there, and the load line is `via DataStore (schema v26)`. Output does not contain `Lost the session lock` or `Your Shardfall session moved to another server.`

### 4. Print save version, then force an autosave

**Flags.** Set `LaunchGate.SHOW.saveTools = true`. Sync. Wait the 11 minutes. Play with API Services on.

**Buttons.** **Dev** → Testing → **Print save version** (`Debug` / `saveversion`). Then **Force autosave** (`Debug` / `autosave`).

**Pass.** The version line names schema 26. Force autosave writes the profile that is already loaded. The Gold pill does not move. The next Play, after the 11 minutes, still says `schema v26` and the same gold.

**Hookup.** `DebugService` has to handle `autosave` with `DataService.save` and `saveversion` by printing `schemaVersion`, and it must not fall through to `DebugTools.apply`. That handler is not in #381, and it is outside the boot / remote / WaveArena UI hookups. If the toast is `Force autosave: Unknown debug action.` or `Print save version: Unknown debug action.`, this step has not passed. The profile was not mutated. Set `LaunchGate.SHOW.saveTools = false` and go on.

### 5. Hide the save buttons again

**Flags.** Set `LaunchGate.SHOW.saveTools = false`. Sync. Wait the 11 minutes. Play.

**Buttons.** Press **Dev**. Leave **Force autosave** and **Print save version** unpressed.

**Pass.** Both labels are gone from Testing and listed in the footer. Gold matches step 2. Output has no profile-could-not-be-read line.

---

## #382 Wave arena

Leave `LaunchGate.SHOW.saveTools` false. API Services stays on for the rest of the batch.

### 6. Both arena switches off

**Flags.** `LaunchGate.SHOW.waveArena = false` and `WaveArenaConfig.enabled = false`.

**Buttons.** Press **Dev**. Leave **Enter arena**, **Skip wave**, and **Spawn boss** unpressed. They are `WaveArena` remote args `enter`, `skip`, and `boss`, all gated by `waveArena`.

**Pass.** No Shard Gate a short walk south of Haven spawn (the pad plan is `(0, 120.5, 46)`, spawn is about `(0, 124, 30)`). No arena out at `z = 12000`. Run / Dungeon does not show those three buttons. The footer lists `Enter arena`, `Skip wave`, and `Spawn boss`.

A missing boot require also leaves the pad absent, so this step does not prove the module loaded. Step 7 does.

### 7. Both switches on, the pad appears

**Flags.** Set `LaunchGate.SHOW.waveArena = true` and `WaveArenaConfig.enabled = true`. Do not publish. Sync. Wait the 11 minutes. Play.

**Buttons.** None. Walk south to the pad.

**Pass.** A Shard Gate pad is there. Its prompt is `Shard Gate` and the action is `Enter`. One switch alone is not enough: with either still false, `WaveArena.present` returns nil and the pad is not created.

**Hookup.** The server boot script calls `WaveArena.present` while both flags are on. No pad means that require is not in yet. Stop the arena steps.

### 8. Enter, wave 1, chips on the ground

**Flags.** Both arena switches stay `true`. `LaunchGate.SHOW.payouts` stays `false`.

**Buttons.** Use the pad's **Enter**, or **Dev** → Run / Dungeon → **Enter arena** (`WaveArena` / `enter`).

**Pass.** The Dev press prints `[Dev] ok Entered the wave arena.` A toast of `Enter arena: The wave arena is off (LaunchGate.waveArena), so this does nothing yet.` means a switch is still false. The buttons appear from `LaunchGate.SHOW.waveArena` alone, and that same sentence is what `WaveArena.dev` returns when `WaveArenaConfig.enabled` is still false. The client shows `Wave 1 / 5`. Six chasers. Chips stay on the ground and pick up inside 12 studs. Gold and shard tokens are unchanged when you check them after leaving (step 10). Nothing on this run writes the profile.

**Hookup.** The pad needs the arena enter remote. The **Enter arena** button needs the `WaveArena` remote. The wave counter is the client UI under `ShardfallClient/WaveArena/`.

### 9. Skip, boss bar, red circle, then the card

**Flags.** Both arena switches stay `true`.

**Buttons.** From inside the run: **Skip wave** (`WaveArena` / `skip`) to move one wave at a time, or fight through. To see the finale without clearing waves 2–4, press **Spawn boss** (`WaveArena` / `boss`) only after you are in a run. Then kill the boss yourself. Do not use **Spawn boss** for the payout count in step 19: it jumps the wave index to 5, so a kill reports a full clear.

**Pass.** Skip prints `[Dev] ok Skipped the wave.` Spawn boss prints `[Dev] ok Spawned the boss.` Waves 2–4 mix ranged and tanks (8, then 10, then 12 bodies). Wave 5 is the boss plus 4 adds. The boss HP bar is on screen while the boss is alive. The slam deals damage only after the red warning, and only inside that circle: stand outside it and the hit does not land. The camera stays outside the boss mesh. After the killing blow the results card waits about 1.5 seconds (`deathHold`). During that hold the card is absent. The card then shows waves cleared plus the run's tokens and fragments. **Skip wave** on the boss wave ends the run immediately and skips that hold, so the hold check is a real kill.

**Hookup.** The three buttons need the `WaveArena` remote. The HP bar, the results card, and the camera room are the client UI under `ShardfallClient/WaveArena/`. The fight itself needs the boot step loop.

### 10. Leave mid-wave, and the save is the same

**Flags.** Both arena switches stay `true` (step 19 still needs the pad). `LaunchGate.SHOW.payouts` stays `false`.

**Buttons.** None. Enter again. Clear wave 1 (fight it, or **Skip wave** once). Walk over one chip in wave 2. Leave before wave 2 ends.

**Pass.** You keep the chip you walked over and wave 1's purse (1 token on the card). Chips still sitting on the ground for wave 2 are dropped. The first 10 seconds of wave 1 read as a fight (six chasers closing). The boss, if you saw it in step 9, reads as the finale: big body, red slam, HP bar, the 1.5 second hold, then the card. Stop, wait the 11 minutes, Play. Gold and shard tokens match the numbers from before step 8.

**Hookup.** Leave and the results card need the boot loop and the client UI under `ShardfallClient/WaveArena/`.

---

## #383 Analytics

Arena switches stay as step 10 left them. `LaunchGate.SHOW.saveTools` stays `false`. `LaunchGate.SHOW.payouts` stays `false`.

### 11. Both analytics switches off

**Flags.** `LaunchGate.SHOW.analytics = false` and `Analytics.ENABLED = false`.

**Buttons.** Press **Dev**. Leave **Print last 20 events** unpressed. It is `Debug` remote arg `analytics`, gated by `analytics`.

**Pass.** The usual build line is in Output. There is no `[Analytics]` line. Testing does not show **Print last 20 events**. The footer lists it. Crack one roll on the Roll tab, or press **Enter Vault** (`Debug` / `dungeon`). Gold and shards match a session without this branch. Nothing asks for Robux. Output does not print the player name from this system.

### 12. Turn both analytics switches on

**Flags.** Set `LaunchGate.SHOW.analytics = true` and `Analytics.ENABLED = true`. Sync. Wait the 11 minutes. Play.

**Buttons.** None yet.

**Pass.** The session joins with no analytics error. One switch alone stays off: the print in the next step would say `Analytics is off (LaunchGate.analytics).` or `Analytics is off (Config.Analytics.ENABLED).`

**Hookup.** Boot calls `AnalyticsService.start()`. That records `session_start`, `session_end` on leave, and the joined funnel steps. Gameplay events come from the call sites, not from `start()`.

### 13. Print the last 20 events

**Flags.** Both analytics switches stay `true`.

**Buttons.** **Dev** → Testing → **Print last 20 events** (`Debug` / `analytics`).

**Pass.** Server Output prints `[Analytics]` followed by lines `ok <userId> <name>`. Expect `session_start`, `tutorial:joined`, and `first_session:joined`. The only id on a line is the user id number. The display name is absent. The toast repeats that text, and the client prints `[Dev] ok` plus the same text.

**Hookup.** Boot `AnalyticsService.start()`, and the `DebugService` branch that returns `AnalyticsService.printRecent()` before the profile mutate. If the toast is `Print last 20 events: Unknown debug action.`, the handler is missing. The profile was not changed. This step has not passed.

### 14. A roll and a vault run show up in the log

**Flags.** Both analytics switches stay `true`.

**Buttons.** Crack one roll on the Roll tab (earned tokens or the free crack). Then **Enter Vault** (`Debug` / `dungeon`, Rootvault, normal). Clear wave 1 or leave the run. Press **Print last 20 events** again.

**Pass.** New `ok <userId>` lines include `roll_x1`, `rarity_pulled`, `dungeon_enter`, and `wave_enter`. A sink line `currency_sink` is present only when the roll actually spent tokens. A clear of wave 1 adds `wave_clear` and `first_session:cleared_wave_1`. Leaving adds `dungeon_leave` and `wave_leave`. The funnel lines look like `first_session:first_roll` and `first_session:entered_gate`. No line contains the player name. Gold changed only by the roll and the run, the same as a build without this branch. Nothing asks for Robux.

**Hookup.** The call sites listed on #383: roll after a successful crack, dungeon enter, wave enter, wave clear, and leave. Those lines are not in #383 itself.

### 15. Leave, rejoin, then turn analytics off

**Flags.** Both analytics switches stay `true` for the leave. After the rejoin check, set `LaunchGate.SHOW.analytics = false` and `Analytics.ENABLED = false`.

**Buttons.** Stop the session (that is the leave). Wait the 11 minutes. Play. Press **Print last 20 events** once. Then set the two switches to `false` and sync. The hidden-button check is the Play in step 16.

**Pass.** The rejoin load is `schema v26` and the gold and bag match the end of step 14. The new print shows a fresh `session_start` for this server. The previous server's `roll_x1` is absent from this print. No analytics line prints the player name.

**Hookup.** `session_end` is recorded by boot `AnalyticsService.start()` on leave. The process exits with the server, so you will not see that row on the next Play. A missing `start()` means step 13 already failed.

---

## #384 Payouts

There is no payout button on the Dev panel. #384 adds the gate name only. `LaunchGate.SHOW.payouts` stays the switch. Arena switches are still `true` from step 7. Analytics switches are `false` from step 15. `LaunchGate.SHOW.saveTools` is `false`.

### 16. Payouts off, a run pays nothing

**Flags.** `LaunchGate.SHOW.payouts = false`. `LaunchGate.SHOW.analytics` and `Analytics.ENABLED` are `false` from step 15. Wait the 11 minutes after step 15's Play, then Play.

**Buttons.** Press **Dev**. Confirm the panel has no payout row. Enter the arena and finish or leave a run (pad **Enter**, or **Enter arena**).

**Pass.** **Print last 20 events** is hidden and the footer lists it. Output has no `[Analytics]` line and does not mention a payout. Note the shard token count before the run. After the run it is the same number. The results card can still show tokens and fragments. Those card numbers stay on the card while the flag is off. `PayoutService.grant` returns `Run payouts (Roll Tokens and Fragments) is off (LaunchGate.payouts), so this does nothing yet.` and does not settle the run.

**Hookup.** The run-end payout hook. A missing hook also leaves the wallet still, so this step does not prove the service is loaded. Step 19 does.

### 17. Command bar: full-clear totals

**Flags.** `LaunchGate.SHOW.payouts` stays `false`. Stay in the current Play session.

**Buttons.** None. In the command bar:

```lua
local Payouts = require(game.ReplicatedStorage.Shared.Config.Payouts)
print(Payouts.tokensThrough("normal", 5), Payouts.tokensThrough("medium", 5), Payouts.tokensThrough("hard", 5))
```

**Pass.** Output prints `11 14 17`. This reads config only. It does not write the profile.

### 18. Command bar: boss death, duplicates, and a second grant

**Flags.** `LaunchGate.SHOW.payouts` stays `false`.

**Buttons.** None. In the command bar:

```lua
local Payouts = require(game.ReplicatedStorage.Shared.Config.Payouts)
local Players = game:GetService("Players")
print(Payouts.tokensThrough("nightmare", 4), Payouts.tokensThrough("insane", 4))
print(Payouts.duplicateFragments("Legendary"), Payouts.duplicateFragments("Mythic"))
local book = Payouts.newBook()
local runId = "qa-batch"
local first = Payouts.grant(book, Players.LocalPlayer.UserId, runId, { difficulty = "normal", wavesCleared = 5 })
local second = Payouts.grant(book, Players.LocalPlayer.UserId, runId, { difficulty = "normal", wavesCleared = 5 })
print(first.paid, first.tokens, second.paid, second.tokens)
print(game.ReplicatedStorage.Shared.LaunchGate.on("payouts"))
```

**Pass.** `12 18`, then `200 200` (Mythic folds into Legendary; the parked 1000 is not used), then `true 11 false 0`, then `false`. The second grant is `paid == false` and `tokens == 0`. The book is memory in the command bar. The profile is unchanged, and `LaunchGate.on("payouts")` is still false, so a real run still pays nothing.

### 19. Flag on, one Normal clear pays 11 once

**Flags.** Set `LaunchGate.SHOW.payouts = true`. Keep `LaunchGate.SHOW.waveArena = true` and `WaveArenaConfig.enabled = true`. Sync. Wait the 11 minutes. Play.

**Buttons.** **Enter arena** (`WaveArena` / `enter`), or the Shard Gate **Enter**. Then **Skip wave** (`WaveArena` / `skip`) once per wave until the results card shows. That is five skips from wave 1: each skip clears the current wave, and the fifth ends the run. Do not press **Spawn boss** for this count.

**Pass.** Note shard tokens before the run. The arena config has no difficulty of its own. The hook's `difficulty` field picks the row. Normal adds 11. A full clear on Medium, Hard, Nightmare, or Insane adds 14, 17, 22, or 33. The results card shows that token total and the fragments from the chips. Fragments have no save field, so a rejoin does not grow a fragment counter. Dying on the boss after waves 1–4 pays the waves 1–4 row: 6 on Normal (Medium 8, Hard 9, Nightmare 12, Insane 18). A second end of this same run adds nothing. Stop, wait the 11 minutes, Play. Shard tokens are the post-clear total, gold is otherwise unchanged, and the load is still `schema v26`.

**Hookup.** The run-end hook calls `PayoutService.grant(player.UserId, runId, { difficulty = difficulty, wavesCleared = wavesCleared })` and adds `payout.tokens` to `shardTokens` only when `payout.paid == true`. A new attempt needs a new `runId`. The enter and skip buttons need the `WaveArena` remote. The card is the client UI under `ShardfallClient/WaveArena/`. If tokens do not move, the hook is missing. Stop. Do not grant tokens by hand.

### 20. Every flag back off

**Flags.** Set all of these to `false`, then sync:

- `LaunchGate.SHOW.saveTools`
- `LaunchGate.SHOW.waveArena`
- `WaveArenaConfig.enabled`
- `LaunchGate.SHOW.analytics`
- `Analytics.ENABLED`
- `LaunchGate.SHOW.payouts`

**Buttons.** Wait the 11 minutes. Play. Press **Dev**. Do not press the hidden rows.

**Pass.** No Shard Gate south of spawn. Output has no payout line and no `[Analytics]` line. The load is `schema v26`. Shard tokens are the step 19 total, not a second grant. The footer lists `Force autosave`, `Print save version`, `Enter arena`, `Skip wave`, `Spawn boss`, and `Print last 20 events`. Leave API Services however you need the place, and do not publish.
