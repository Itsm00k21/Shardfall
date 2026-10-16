# Shardfall task board

Integration branch: `cursor/live-build-9721`.

GHOST is this account. HELPER is the second account. Claim a row by editing this file in its own commit before any code. Status values: `owned` (files stay locked; beta already shipped), `claimed` (not started, or still open), `done`.

PR column is `—` until that task has its own pull request into `cursor/live-build-9721`.

Seeded from the playtest cut list ("Not in this build") plus the standing ownership split.

## Claimed by GHOST

GHOST keeps combat, classes, Rootvault, the Heartwood raid (including Raid Hard, AFK/vote-kick, and the raid loot table), onboarding, playtest bug fixes, and core shared modules.

| id | title | owner | branch | files / folders | status | PR |
|---|---|---|---|---|---|---|
| T-001 | Combat feel (beta shipped) | GHOST | `cursor/live-build-9721` | `src/ReplicatedStorage/Shared/CombatFeel.luau`, `src/ReplicatedStorage/Shared/CombatMath.luau`, `src/ServerScriptService/ShardfallServer/CombatService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau`, `tests/CombatFeel.spec.luau` | owned | — |
| T-002 | Five classes (beta shipped) | GHOST | `cursor/live-build-9721` | `src/ReplicatedStorage/Shared/Classes.luau`, `src/ServerScriptService/ShardfallServer/ClassService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ClassHud.luau`, `tests/Classes.spec.luau` | owned | — |
| T-003 | Rootvault doors, roles, Gnarl phases (beta shipped) | GHOST | `cursor/live-build-9721` | `src/ReplicatedStorage/Shared/Rootvault.luau`, `src/ReplicatedStorage/Shared/Dungeons.luau`, `src/ServerScriptService/ShardfallServer/DungeonService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/DoorHud.luau`, `tests/Rootvault.spec.luau`, `tests/Dungeons.spec.luau` | owned | — |
| T-004 | Onboarding (beta shipped) | GHOST | `cursor/live-build-9721` | `src/ReplicatedStorage/Shared/Onboarding.luau`, `src/ServerScriptService/ShardfallServer/OnboardingService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/OnboardHud.luau`, `tests/Onboarding.spec.luau` | owned | — |
| T-005 | Cold open camera pan and world class pedestals | GHOST | `cursor/onboard-pan-9721` | `src/ReplicatedStorage/Shared/Onboarding.luau`, `src/ServerScriptService/ShardfallServer/OnboardingService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/OnboardHud.luau`, `src/ServerScriptService/ShardfallServer/HavenBuilder.luau` (pedestal props only) | claimed | — |
| T-006 | Heartwood Story/Normal (beta shipped) | GHOST | `cursor/live-build-9721` | `src/ReplicatedStorage/Shared/Raids.luau`, `src/ServerScriptService/ShardfallServer/RaidService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RaidHud.luau`, `tests/Raids.spec.luau` | owned | — |
| T-007 | Raid Hard | GHOST | `cursor/raid-hard-9721` | `src/ReplicatedStorage/Shared/Raids.luau`, `src/ServerScriptService/ShardfallServer/RaidService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RaidHud.luau`, `docs/design/shardfall_raids.md` | claimed | — |
| T-008 | Raid AFK detection and vote-kick | GHOST | `cursor/raid-kick-9721` | `src/ServerScriptService/ShardfallServer/RaidService.luau`, `src/ReplicatedStorage/Shared/Raids.luau` | claimed | — |
| T-009 | Raid loot table (replace the chest stand-in) | GHOST | `cursor/raid-loot-9721` | `src/ReplicatedStorage/Shared/Raids.luau`, `src/ServerScriptService/ShardfallServer/RaidService.luau` | claimed | — |
| T-010 | The Vault and Relic Sets | GHOST | `cursor/raid-vault-9721` | `src/ReplicatedStorage/Shared/Raids.luau`, `src/ServerScriptService/ShardfallServer/RaidService.luau`, `docs/design/shardfall_raids.md` | claimed | — |
| T-011 | Playtest bug fixes | GHOST | `cursor/playtest-fixes-9721` | GHOST-owned files above, plus the shared modules in T-012. Do not edit a HELPER-owned path. | claimed | — |
| T-012 | Core shared modules | GHOST | `cursor/live-build-9721` | `src/ReplicatedStorage/Shared/Schema.luau`, `src/ReplicatedStorage/Shared/Build.luau`, `src/ServerScriptService/ShardfallServer/Remotes.luau`, `src/ServerScriptService/ShardfallServer/RateLimiter.luau`, `src/ServerScriptService/ShardfallServer/DataService.luau`, `src/ServerScriptService/ShardfallServer/init.server.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`, `default.project.json` | owned | — |

T-010 is the rest of the cut line "Raid Hard, the Vault, and Relic Sets." Raid Hard itself is T-007.

## Claimed by HELPER

HELPER takes self-contained systems. New modules listed below are the owned paths. Do not edit a GHOST path. If a hook has to land in a shared module or in `CombatHud.luau` / `DungeonService.luau` / `Rootvault.luau`, write that on the row in this file first and wait for GHOST.

| id | title | owner | branch | files / folders | status | PR |
|---|---|---|---|---|---|---|
| T-013 | Trading, Haven Market Board, and trade audit log | HELPER | `helper/market-9721` | `src/ReplicatedStorage/Shared/Trading.luau`, `src/ReplicatedStorage/Shared/MarketBoard.luau`, `src/ServerScriptService/ShardfallServer/TradeService.luau`, `src/ServerScriptService/ShardfallServer/MarketService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MarketHud.luau`, `tests/Trading.spec.luau`, `docs/design/shardfall_economy.md` (v1.1 Market Board and Trade Audit) | claimed | — |
| T-014 | Pet evolution, wild shiny capture, and boss pets | HELPER | `helper/pets-9721` | `src/ReplicatedStorage/Shared/PetEvolution.luau`, `src/ReplicatedStorage/Shared/WildCapture.luau`, `src/ServerScriptService/ShardfallServer/WildCaptureService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CaptureHud.luau`, `tests/PetEvolution.spec.luau`, `docs/design/shardfall_pets.md` | claimed | — |
| T-015 | Shard Pass premium wiring, kept off, and 4x4 board polish | HELPER | `helper/shard-pass-9721` | `src/ReplicatedStorage/Shared/Loops.luau`, `src/ServerScriptService/ShardfallServer/LoopService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/LoopHud.luau`, `tests/Loops.spec.luau`, `docs/design/shardfall_loops.md`. `Loops.PREMIUM_ENABLED` stays `false`. | claimed | — |
| T-016 | Session-recap string on the victory card | HELPER | `helper/session-recap-9721` | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/SessionRecap.luau`, `tests/Progression.spec.luau` (recap string only). Read `Progression.recap` in `src/ReplicatedStorage/Shared/Progression.luau`. The victory card is drawn in `CombatHud.luau` (T-001). Add a call site there only after a note on this row. | claimed | — |
| T-017 | Haste shrines, mender healing, shielder blocking | HELPER | `helper/enemy-abilities-9721` | `src/ReplicatedStorage/Shared/EnemyAbilities.luau`, `tests/EnemyAbilities.spec.luau`, `docs/design/rootvault_design.md`. Haste is stored on the run and does nothing. Menders do not heal. Shielders do not block. Hook points in `DungeonService.luau` and `Rootvault.luau` (T-003) need a note on this row before those files change. | claimed | — |

`src/ReplicatedStorage/Shared/Pets.luau` and `src/ServerScriptService/ShardfallServer/PetService.luau` stay with the shipped hatchery. T-014 adds new modules beside them. Edit those two only after a note on T-014.

### T-013 hooks for GHOST

HELPER did not edit T-012. The modules are ready to call. Wire these, then the Market button and the remotes go live.

`default.project.json` inside `ReplicatedStorage.Remotes`:

```json
"Trade": { "$className": "RemoteFunction" },
"Market": { "$className": "RemoteFunction" }
```

`RateLimiter.luau` `RULES`:

```lua
Trade = { capacity = 6, perSecond = 2 },
Market = { capacity = 8, perSecond = 3 },
```

`Remotes.luau` requires `TradeService` and `MarketService`, then inside `Remotes.bind`:

```lua
functionRemote("Trade").OnServerInvoke = function(player, action, payload)
	return guard(player, "Trade", function()
		if type(action) ~= "string" then
			return { ok = false, error = "Unknown trade action." }
		end
		return TradeService.handle(player, action, payload)
	end)
end

functionRemote("Market").OnServerInvoke = function(player, action, payload)
	return guard(player, "Market", function()
		if type(action) ~= "string" then
			return { ok = false, error = "Unknown market action." }
		end
		return MarketService.handle(player, action, payload)
	end)
end
```

Client calls `InvokeServer(action, payload)`.

| Remote | action | payload |
|---|---|---|
| Trade | `invite` | `{ targetUserId: number }` |
| Trade | `offer` | `{ gold: number?, gems: number?, items: { string }?, materials: { [string]: number }?, chests: { [string]: number }? }` |
| Trade | `confirm` | `nil` |
| Trade | `commit` | `{ acceptWarning: boolean? }` |
| Trade | `cancel` | `nil` |
| Trade | `history` | `nil` |
| Trade | `report` | `{ tradeId: string }` |
| Trade | `state` | `nil` |
| Market | `browse` | `{ search: string?, kind: string?, rarity: string?, currency: string?, sellerUserId: number? }` |
| Market | `list` | `{ price: number, currency: "gold" or "gems", items: { string }?, materials: { [string]: number }?, chests: { [string]: number }? }` |
| Market | `buy` | `{ listingId: string }` |
| Market | `cancel` | `{ listingId: string }` |
| Market | `mine` | `nil` |

`Schema.luau` version 20. Add to `ProfileData`, `template()`, and `if version < 20` in `migrate`:

```lua
tradeDay: number, -- floor(os.time() / 86400). 0 until the first trade.
tradeValueToday: number,
tradeLocked: boolean,
tradeFlagged: boolean,
verifiedTrader: boolean,
tradeCleanSince: number, -- unix time. 0 means clean days follow account age.
tradeHandoff: boolean,
```

Defaults: `tradeDay = 0`, `tradeValueToday = 0`, `tradeLocked = false`, `tradeFlagged = false`, `verifiedTrader = false`, `tradeCleanSince = 0`, `tradeHandoff = false`. The services already read these. They write `tradeDay` and `tradeValueToday` only when the keys exist, so caps survive a restart after this migrate. `vip` stays the Patron flag. Any `receipts[id] == true` counts as a verified spender. Do not put the 180-day log on the profile.

`init.server.luau`, before `DataService.start()`:

```lua
local MarketService = require(script.MarketService)
local TradeService = require(script.TradeService)
TradeService.start()
MarketService.start()
```

`init.client.luau`, after `invoke` exists:

```lua
local MarketHud = require(script.MarketHud)
MarketHud.start(invoke)
```

`tests/run.luau` already requires `./Trading.spec` on this branch.

Server-only, not remotes: `TradeService.rollback(tradeId)`, `TradeService.review(query)`, `TradeService.snapshot()` / `restore(entries)`, `MarketService.exportBoard()` / `importBoard(board)`, `MarketService.audit()`. Optional later: a DataStore for the audit log and the board, and `DataService.mutatePair` so one backup covers both profiles. `Trading.finish` already restores both tables when a commit fails.

Build stamp files are T-012. This branch does not change them. Stamp on merge if you want the printed build to move.

## Open

No unassigned tasks.

## Done

No task has moved here yet. The owner moves a row here in the same commit as the handoff note.
