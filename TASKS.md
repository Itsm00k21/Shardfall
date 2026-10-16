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
| T-020 | Wire T-014 hooks (Capture/EvolvePet remotes, DungeonService noteShiny/markDefeated/grantBoss/clear, capture_charm ItemBases row) | GHOST | `cursor/capture-hooks-9721` | `default.project.json`, `src/ServerScriptService/ShardfallServer/RateLimiter.luau`, `src/ServerScriptService/ShardfallServer/Remotes.luau`, `src/ServerScriptService/ShardfallServer/init.server.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`, `src/ServerScriptService/ShardfallServer/DungeonService.luau`, `src/ReplicatedStorage/Shared/ItemBases.luau`. Snippets are in the T-014 hooks section. Marks are per player per kind, so two same-kind shinies in one run share one mark (acceptable for beta at a 2% spawn rate). Do not edit `Pets.luau` or `PetService.luau`. | claimed | — |

T-010 is the rest of the cut line "Raid Hard, the Vault, and Relic Sets." Raid Hard itself is T-007.

## Claimed by HELPER

HELPER takes self-contained systems. New modules listed below are the owned paths. Do not edit a GHOST path. If a hook has to land in a shared module or in `CombatHud.luau` / `DungeonService.luau` / `Rootvault.luau`, write that on the row in this file first and wait for GHOST.

| id | title | owner | branch | files / folders | status | PR |
|---|---|---|---|---|---|---|
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

Server-only, not remotes: `TradeService.rollback(tradeId)`, `TradeService.review(query)`, `TradeService.snapshot()` / `restore(entries)`, `MarketService.exportBoard()` / `importBoard(board)`, `MarketService.audit()`. T-018 stores the audit log in `ShardfallTradeAudit` and writes both profiles in `DataService.savePair`. The market board itself is still in memory. `Trading.finish` restores both tables when a commit fails.

Build stamp files are T-012. T-018 stamped `3558616+`.

### T-014 hooks for GHOST

HELPER did not edit T-012, `Pets.luau`, or `PetService.luau`. Evolution, shiny tames, and boss pets are ready to call. Wire these against the post-#18 files (the same shape as Trade and Market). Schema stays at version 20. This branch does not add a profile field.

`default.project.json`, inside `ReplicatedStorage.Remotes`, next to the Trade and Market lines:

```json
        "Capture": { "$className": "RemoteFunction" },
        "EvolvePet": { "$className": "RemoteFunction" },
```

`$path` already includes `PetEvolution`, `WildCapture`, `WildCaptureService`, and `CaptureHud`. Do not add a new tree for them.

`RateLimiter.luau` `RULES`, next to Trade and Market. A remote with no rule is rejected:

```lua
	Capture = { capacity = 4, perSecond = 1 },
	EvolvePet = { capacity = 3, perSecond = 1 },
```

`Remotes.luau`, with the other service requires:

```lua
local WildCaptureService = require(script.Parent.WildCaptureService)
```

Inside `Remotes.bind`, next to the Trade and Market handlers:

```lua
	functionRemote("Capture").OnServerInvoke = function(player, action, payload)
		return guard(player, "Capture", function()
			if type(action) ~= "string" then
				return { ok = false, error = "Unknown capture action." }
			end
			return WildCaptureService.handle(player, action, payload)
		end)
	end
	functionRemote("EvolvePet").OnServerInvoke = function(player, uid)
		return guard(player, "EvolvePet", function()
			if type(uid) ~= "string" then
				return { ok = false, error = "Pick a companion." }
			end
			return WildCaptureService.evolve(player, uid)
		end)
	end
```

`Capture` from the client is only `tame`. `handle` ignores a client shiny flag, a client roll, and a client `defeated` bit. `EvolvePet` takes the companion uid.

| Remote | action | payload |
|---|---|---|
| Capture | `tame` | `{ enemyId: string }` |
| EvolvePet | — | companion `uid: string` |

`init.server.luau`, with the TradeService require, and `start()` next to `TradeService.start()` / `MarketService.start()` before `DataService.start()`:

```lua
local WildCaptureService = require(script.WildCaptureService)
```

```lua
WildCaptureService.start()
```

`start` drops that player's marks on `PlayerRemoving`. Run end still needs `clear` below.

`init.client.luau`, require next to `MarketHud`, and start next to `MarketHud.start`. Pass the existing `invoke` local. CaptureHud calls `invoke("Capture", "tame", { enemyId })`, so do not wrap it the way MarketHud does:

```lua
local CaptureHud = require(script.CaptureHud)
```

```lua
CaptureHud.start(invoke)
```

`DungeonService.luau` (sibling require, same as `LoopService`):

```lua
local WildCaptureService = require(script.Parent.WildCaptureService)
```

On spawn, pass the enemy **kind** (`vine_crawler`), not the `e12` key in `run.enemies`. The service rolls. Remember the result on that enemy:

```lua
local noted = WildCaptureService.noteShiny(player, kind)
enemy.shiny = noted.shiny == true
if enemy.shiny then
	-- Tell that client `kind`. CaptureHud.prompt opens the Tame button.
end
```

When that shiny's hp hits 0 in `damageEnemy` (this replaces calling `tame` on death):

```lua
if enemy.shiny == true then
	WildCaptureService.markDefeated(player, enemy.kind)
end
```

`markDefeated` turns the spawned mark into a defeated mark. The deadline is `os.clock() + WildCapture.TAME_WINDOW` (30 seconds). The client tame spends only that defeated, unexpired mark. A spawned mark returns `"Defeat the shiny first."` An expired one returns `"The shiny slipped away."` Neither of those is consumed. A miss (no charm, or a losing roll) still spends it.

When Grandmother Gnarl dies:

```lua
if enemy.kind == "grandmother_gnarl" and enemy.hp <= 0 then
	WildCaptureService.grantBoss(player, { bossId = "grandmother_gnarl" })
end
```

At run end, at the bottom of `destroyRun` (leave, wipe, and the other endings all go through it):

```lua
WildCaptureService.clear(player)
```

`noteShiny`, `markDefeated`, `grantBoss`, and `clear` stay on the server. Do not add client actions for them. `CombatHud.luau` is unchanged on this branch. When the client learns a shiny kind, call:

```lua
CaptureHud.prompt({ enemyId = kind, displayName = "Vine Sprout" })
```

The Tame button calls `invoke("Capture", "tame", { enemyId = kind })`. Pass `{ onAttempt, onDismiss }` to `prompt` if combat UI should own the click. Marks are per player and per kind, not per `e12` instance.

Charm: `WildCapture.charmEquipped` is true when `equipped.accessories.charm` is the uid of an inventory item with `templateId` `capture_charm`, or when the live profile has `captureCharm == true`. Schema does not save `captureCharm`. Do not add a schema key for it. `Schema.ACCESSORY_SLOTS.charm` already exists, and `Schema.equipItem` already writes `equipped.accessories.charm` for `kind == "Accessory"` and `slot == "charm"`.

`ItemBases` has no `capture_charm` row. Widen `Base.kind` with `"Accessory"` and add this row. It has no combat stats. Price is `WildCapture.CHARM_GOLD` (250 gold) at the vendor that sells it. Do not add a Robux product id or a MarketplaceService prompt.

```lua
kind: "Weapon" | "Armor" | "Pet" | "Accessory",
```

```lua
add({
	id = "capture_charm",
	name = "Capture Charm",
	kind = "Accessory",
	rarity = "Uncommon",
	ascension = 0,
	slot = "charm",
})
```

`Materials.sanitize` drops unknown ids, so do not put the charm in the materials bag.

`WildCaptureService.evolve` spends the recipe inside `DataService.mutate`. No `PetService` edit.

`tests/run.luau` already requires `./PetEvolution.spec` on this branch.

Build stamp files are T-012. This branch does not change them. Stamp on merge if you want the printed build to move.

## Open

No unassigned tasks.

## Done

| id | title | owner | branch | files / folders | status | PR |
|---|---|---|---|---|---|---|
| T-013 | Trading, Haven Market Board, and trade audit log | HELPER | `helper/market-9721` | `src/ReplicatedStorage/Shared/Trading.luau`, `src/ReplicatedStorage/Shared/MarketBoard.luau`, `src/ServerScriptService/ShardfallServer/TradeService.luau`, `src/ServerScriptService/ShardfallServer/MarketService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MarketHud.luau`, `tests/Trading.spec.luau`, `docs/design/shardfall_economy.md` (v1.1 Market Board and Trade Audit) | done | [#16](https://github.com/Itsm00k21/Shardfall/pull/16) |
| T-014 | Pet evolution, wild shiny capture, and boss pets | HELPER | `helper/pets-9721` | `src/ReplicatedStorage/Shared/PetEvolution.luau`, `src/ReplicatedStorage/Shared/WildCapture.luau`, `src/ServerScriptService/ShardfallServer/WildCaptureService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CaptureHud.luau`, `tests/PetEvolution.spec.luau`, `docs/design/shardfall_pets.md` (v1.1 evolution, wild capture, boss pets) | done | [#17](https://github.com/Itsm00k21/Shardfall/pull/17) |
| T-018 | Wire T-013 hooks and save both profiles after a trade | GHOST | `cursor/trade-wiring-9721` | `default.project.json`, `src/ServerScriptService/ShardfallServer/RateLimiter.luau`, `src/ServerScriptService/ShardfallServer/Remotes.luau`, `src/ReplicatedStorage/Shared/Schema.luau`, `src/ServerScriptService/ShardfallServer/init.server.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`, `src/ServerScriptService/ShardfallServer/DataService.luau`, `src/ServerScriptService/ShardfallServer/TradeService.luau`, `src/ServerScriptService/ShardfallServer/MarketService.luau`, `src/ServerScriptService/ShardfallServer/TradeAudit.luau` | done | [#18](https://github.com/Itsm00k21/Shardfall/pull/18) |
