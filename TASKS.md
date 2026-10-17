# Shardfall task board

Integration branch: `cursor/live-build-9721`.

GHOST is this account. HELPER is the second account. Claim a row by editing this file in its own commit before any code. Status values: `owned` (files stay locked; beta already shipped), `claimed` (not started, or still open), `queued` (waiting on an earlier task), `done`.

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
| T-008 | Raid AFK and vote-kick: wire T-027 hooks into RaidService | GHOST | `cursor/raid-kick-9721` | `src/ServerScriptService/ShardfallServer/RaidService.luau`, `src/ReplicatedStorage/Shared/Raids.luau`. Rules come from HELPER's T-027 `RaidConduct.luau`; wire them after the T-027 hooks section lands. | claimed | — |
| T-009 | Raid loot table (replace the chest stand-in) | GHOST | `cursor/raid-loot-9721` | `src/ReplicatedStorage/Shared/Raids.luau`, `src/ServerScriptService/ShardfallServer/RaidService.luau` | claimed | — |
| T-010 | The Vault and Relic Sets | GHOST | `cursor/raid-vault-9721` | `src/ReplicatedStorage/Shared/Raids.luau`, `src/ServerScriptService/ShardfallServer/RaidService.luau`, `docs/design/shardfall_raids.md`. Relic Set rules come from HELPER's T-025 `RelicSets.luau`. T-010 wires them and does not edit that module. | claimed | — |
| T-011 | Playtest bug fixes | GHOST | `cursor/playtest-fixes-9721` | GHOST-owned files above, plus the shared modules in T-012. Do not edit a HELPER-owned path. | claimed | — |
| T-012 | Core shared modules | GHOST | `cursor/live-build-9721` | `src/ReplicatedStorage/Shared/Schema.luau`, `src/ReplicatedStorage/Shared/Build.luau`, `src/ServerScriptService/ShardfallServer/Remotes.luau`, `src/ServerScriptService/ShardfallServer/RateLimiter.luau`, `src/ServerScriptService/ShardfallServer/DataService.luau`, `src/ServerScriptService/ShardfallServer/init.server.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`, `default.project.json` | owned | — |
| T-020 | Wire T-014 hooks (Capture/EvolvePet remotes, DungeonService noteShiny/markDefeated/grantBoss/clear, capture_charm ItemBases row) | GHOST | `cursor/capture-hooks-9721` | `default.project.json`, `src/ServerScriptService/ShardfallServer/RateLimiter.luau`, `src/ServerScriptService/ShardfallServer/Remotes.luau`, `src/ServerScriptService/ShardfallServer/init.server.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`, `src/ServerScriptService/ShardfallServer/DungeonService.luau`, `src/ReplicatedStorage/Shared/ItemBases.luau`. Snippets are in the T-014 hooks section. Marks are per player per kind, so two same-kind shinies in one run share one mark (acceptable for beta at a 2% spawn rate). Do not edit `Pets.luau` or `PetService.luau`. #22 already added the `CaptureHud` require and `CaptureHud.start(invoke)` in `init.client.luau` and positioned CaptureHud clear of the HP bar and action bar, so T-020 must not add the client mount again. The server side (Capture/EvolvePet remotes in `default.project.json`, RateLimiter rules, Remotes handlers, `WildCaptureService.start` in `init.server`, DungeonService `noteShiny`/`markDefeated`/`grantBoss`/`clear`, `capture_charm` ItemBases row) is still to do. | claimed | — |
| T-022 | Wire T-017 EnemyAbilities hooks into the live run | GHOST | `cursor/enemy-hooks-9721` | `src/ServerScriptService/ShardfallServer/DungeonService.luau` (chooseDoor shrine branch, onHeartbeat mend/priority, damageEnemy block, moveEnemy turnShield for root_brute, destroyRun WalkSpeed restore), `src/ServerScriptService/ShardfallServer/CombatService.luau` (hasteAttack in releaseSwing and companionTick), `src/ReplicatedStorage/Shared/EnemyAbilities.luau` (HASTE duration/expiry), `tests/EnemyAbilities.spec.luau`. Follow the snippets in the T-017 hooks section. (a) Haste lasts the rest of the run like Might, not 30 seconds, to match the Rootvault door text; the wiring changes HASTE duration/expiry to match and updates the spec, and WalkSpeed is still restored when a new shrine replaces Haste and in destroyRun. (b) The CombatService hook is approved (Ghost owns T-001). (c) Menders never heal grandmother_gnarl. Starts after T-020 (capture hooks on `cursor/capture-hooks-9721`) lands and draft #19 is resolved, since all three edit `DungeonService.luau`. Do not implement before then. | claimed | — |
| T-023 | Join chrome: one action bar, closed roll and debug, matching HP | GHOST | `cursor/join-chrome-404b` | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`, new `ActionBar.luau` (replaces `ThumbBar.luau`), `Ui.luau`, `DebugHud.luau`, `RollReel.luau`, `CombatHud.luau`, `src/ServerScriptService/ShardfallServer/CombatService.luau` (MaxHealth sync only; no T-022 haste/mend/shield hooks), `src/ReplicatedStorage/Shared/ClientChrome.luau`, `tests/ClientChrome.spec.luau`. Stamp lines only in `Build.luau`, `init.server.luau`, and `DungeonService.luau`. Hide LoopHud and MarketHud from init; do not edit those modules. Do not remount CaptureHud or implement T-020 hooks. | done | [#29](https://github.com/Itsm00k21/Shardfall/pull/29) |
| T-024 | Class picker stays open, inventory filters, travel clear of the left panel | GHOST | `cursor/hud-followup-404b` | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ClassHud.luau`, `init.client.luau` (Skills toggle and closePanels only), `HavenClient.luau` (prompt echo dedupe), `InventoryHud.luau`, `src/ReplicatedStorage/Shared/InventoryView.luau`, `ShellLayout.luau`, `RollReel.luau` (odds frame position only), `tests/InventoryView.spec.luau`, `tests/ShellLayout.spec.luau`, `tests/ClientChrome.spec.luau`. Stamp lines only in `Build.luau`, `init.server.luau`, `init.client.luau`, and `DungeonService.luau`. Do not edit LoopHud, MarketHud, CombatHud, Pets, or PetService. Do not implement T-020 capture hooks or T-022 ability hooks. | done | [#31](https://github.com/Itsm00k21/Shardfall/pull/31) |
| T-026 | Wire T-016 recap hooks onto the victory card | GHOST | `cursor/recap-hooks-9721` | `CombatHud.luau` (victoryBody line only), `src/ServerScriptService/ShardfallServer/DungeonService.luau` (victory payload `recap`, session maps), `src/ServerScriptService/ShardfallServer/DataService.luau` (session-start level snapshot). Decisions: `epics` counts Epic-or-higher items granted this session (item drops plus chest contents when opened, not the chests themselves); `beforeLevel` is snapshotted when the profile finishes loading in DataService so Haven XP counts; `setPct` stays 0 until T-010. Follow the T-016 hooks section otherwise. Starts after T-020 lands and draft #19 is resolved, since those also edit `DungeonService.luau`. | claimed | — |
| T-028 | UI polish: one theme, opaque panels, join shows HP and the action bar | GHOST | `cursor/ui-polish-404b` | `src/ReplicatedStorage/Shared/UiTheme.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MobileShell.luau`, `DebugHud.luau`, `LoopHud.luau` (chrome and copy only; no premium logic), `RollReel.luau`, `InventoryHud.luau`, `TravelHud.luau`, `ClassHud.luau`, `MarketHud.luau` (OpenMarket hidden and padded only), `CombatHud.luau` (text size and wallet stroke only; no HP math), `Ui.luau` (status banner), `ActionBar.luau`, `tests/UiTheme.spec.luau`, `tests/run.luau`, `tests/ClientChrome.spec.luau`. Stamp lines only in `Build.luau`, `init.server.luau`, `init.client.luau`, and `DungeonService.luau`. Do not implement T-020 capture hooks or T-022 ability hooks. T-025 and T-027 were already taken by HELPER, so this row is T-028. | done | [#32](https://github.com/Itsm00k21/Shardfall/pull/32) |
| T-029 | Action bar stays inside the safe inset | GHOST | `cursor/action-bar-inset-404b` | `src/ReplicatedStorage/Shared/ShellLayout.luau`, `tests/ShellLayout.spec.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau`, `MobileShell.luau`, and ShellLayout placement only in `ClassHud.luau`, `DoorHud.luau`, `CaptureHud.luau`, `CombatHud.luau` (no HP math, no victory card), `Ui.luau` (menu fit), `InventoryHud.luau`, `TravelHud.luau`, `RollReel.luau`, `DebugHud.luau`, `LoopHud.luau`, `MarketHud.luau`, `PetHud.luau`, `RaidHud.luau`, `OnboardHud.luau`. Stamp lines only in `Build.luau`, `init.server.luau`, `init.client.luau`, and `DungeonService.luau`. Do not implement T-020 capture hooks, T-022 ability hooks, or T-026 recap hooks. | done | [#35](https://github.com/Itsm00k21/Shardfall/pull/35) |
| T-030 | Overhead billboard matches CombatService HP | GHOST | `cursor/hp-billboard-404b` | `src/ReplicatedStorage/Shared/CombatMath.luau` (`syncVitals` only), `tests/CombatMath.spec.luau`, `src/ServerScriptService/ShardfallServer/CombatService.luau` (vitals publish, refresh, and the player billboard only; no T-022 haste/mend/shield), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau` (overhead text in the HP draw path only; no victory card). Stamp lines only in `Build.luau`, `init.server.luau`, `init.client.luau`, and `DungeonService.luau`. Do not implement T-020 capture hooks, T-022 ability hooks, or T-026 recap hooks. | done | [#36](https://github.com/Itsm00k21/Shardfall/pull/36) |
| T-032 | Hub walkway tops, debug inset, action-bar labels | GHOST | `cursor/hub-seam-404b` | `src/ReplicatedStorage/Shared/Haven.luau` (layer offset and footprint helper only), `src/ServerScriptService/ShardfallServer/HavenBuilder.luau` (walkway and plate tops only), `src/ReplicatedStorage/Shared/UiTheme.luau` (safe margin only), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/DebugHud.luau`, `ActionBar.luau`, `src/ReplicatedStorage/Shared/ShellLayout.luau` (bottom margin check only), `tests/Haven.spec.luau`, `tests/HavenBuild.spec.luau`, `tests/ClientChrome.spec.luau`, `tests/ShellLayout.spec.luau`, `tests/UiTheme.spec.luau`. Stamp lines only in `Build.luau`, `init.server.luau`, `init.client.luau`, and `DungeonService.luau`. Do not implement T-020 capture hooks, T-022 ability hooks, or T-026 recap hooks. T-031 was already HELPER's relic follow-up, so this playtest is T-032. | done | [#39](https://github.com/Itsm00k21/Shardfall/pull/39) |
| T-033 | Join shows HP and the action bar; Menu, Skills, and Debug fit | GHOST | `cursor/join-menu-404b` | `src/ReplicatedStorage/Shared/ClientChrome.luau`, `ShellLayout.luau`, new `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHud.luau`, `init.client.luau` (menu wiring and join hide only), `ClassHud.luau`, `DebugHud.luau`, `LoopHud.luau` (open/close only), `PetHud.luau`, `RaidHud.luau` (start hidden only), `Ui.luau` (drop the lingering load line only), `tests/ClientChrome.spec.luau`, `tests/ShellLayout.spec.luau`. Stamp lines only in `Build.luau`, `init.server.luau`, `init.client.luau`, and `DungeonService.luau`. Do not implement T-020 capture hooks, T-022 ability hooks, or T-026 recap hooks. Live-build renumbered the hub playtest to T-032, so this follow-up is T-033. | done | [#42](https://github.com/Itsm00k21/Shardfall/pull/42) |

T-010 is the rest of the cut line "Raid Hard, the Vault, and Relic Sets." Raid Hard itself is T-007. Relic Set rules come from T-025. T-010 keeps the Vault and the wiring. Heartwood Vendor sells weaker helper items for Raid Marks or materials, never Relic Set pieces. Ghost wires that vendor later, under T-010.

Next free id is T-036.

## Claimed by HELPER

HELPER takes self-contained systems. New modules listed below are the owned paths. Do not edit a GHOST path. If a hook has to land in a shared module or in `CombatHud.luau` / `DungeonService.luau` / `Rootvault.luau`, write that on the row in this file first and wait for GHOST.

| id | title | owner | branch | files / folders | status | PR |
|---|---|---|---|---|---|---|
| T-025 | Verdant Relic Set rules module (pure, no wiring) | HELPER | `helper/relic-sets-9721` | new `src/ReplicatedStorage/Shared/RelicSets.luau`, new `tests/RelicSets.spec.luau`, one require line in `tests/run.luau`, new `docs/design/relic_sets.md` | done | [#37](https://github.com/Itsm00k21/Shardfall/pull/37) |
| T-027 | Raid conduct rules: AFK detection and vote-kick | HELPER | `helper/raid-conduct-9721` | new `src/ReplicatedStorage/Shared/RaidConduct.luau`, new `tests/RaidConduct.spec.luau`, `tests/run.luau` (one require line). Pure, server-authoritative rules from `docs/design/shardfall_raids.md`: AFK warning at 60 s with no input outside cutscenes, auto-remove at 90 s (rewards forfeited, backfill flagged); vote-kick needs 3/4 of the group plus a reason, is unavailable in the first 2 minutes and during combat, 1 kick per player per day, idle kicks drop queue priority, players kicked unfairly still keep their Marks, and kicking is disabled in Guided Raids. Do not edit `Raids.luau`, `RaidService.luau`, or T-012. Write a 'T-027 hooks for GHOST' section (RaidService call sites, and a suggested schema field for the daily kick count, since HELPER does not edit Schema). | done | [#44](https://github.com/Itsm00k21/Shardfall/pull/44) |
| T-031 | Relic tradeability follow-up | HELPER | `helper/relic-trade-9721` | `src/ReplicatedStorage/Shared/RelicSets.luau` (`stamp` and `isRelic` only), `tests/RelicSets.spec.luau`, `docs/design/relic_sets.md`, and the trade snippet in the T-025 hooks section of this file. Per Kevin, pieces are raid-drop only and tradeable on the Market Board. They are not bound. `stamp` sets `bound = false` and `tradeable = true`. `isRelic` still matches a piece id, a set id, or an item whose `templateId`, `id`, `pieceId`, or `setId` names one, and it must not treat `bound` as the relic test. The T-025 hooks trade snippet has no `Trading.rejection` block for relics (no `"Relic Set pieces are bound."` return). Keep it that way. Do not edit `Trading.luau`, `Raids.luau`, `RaidService.luau`, or T-012. | done | [#41](https://github.com/Itsm00k21/Shardfall/pull/41) |
| T-034 | Relic catalog rows unbound | HELPER | `helper/relic-trade-fix-9721` | `src/ReplicatedStorage/Shared/RelicSets.luau` (`makePiece` only), `tests/RelicSets.spec.luau`, and any matching note in `docs/design/relic_sets.md`. Flip catalog `makePiece` to `bound = false` / `tradeable = true`. Assert every catalog piece is unbound and tradeable. Do not edit `Trading.luau`, `Raids.luau`, `RaidService.luau`, or T-012. | done | [#43](https://github.com/Itsm00k21/Shardfall/pull/43) |
| T-035 | Raid leaver penalty rules | HELPER | `helper/raid-leaver-9721` | new `src/ReplicatedStorage/Shared/RaidLeaver.luau`, new `tests/RaidLeaver.spec.luau`, one require line in `tests/run.luau`, and a 'T-035 hooks for GHOST' section in this file. Pure, server-authoritative rules from `docs/design/shardfall_raids.md`: 3 leaves in one UTC day puts the player on a 15-minute Raid Finder cooldown; a disconnect opens a 3-minute rejoin window, rejoining inside it is not a leave and missing it counts as one; an AFK removal or a passed vote-kick (T-027 RaidConduct) is not a voluntary leave. Thresholds in a frozen CONFIG, time passed in as unix seconds (`os.time()`), no services, remotes, or DataStores. Do not edit `Raids.luau`, `RaidService.luau`, Schema, or T-012; suggest profile fields (leave day/count, cooldown-until) in the hooks section. No build stamp, nothing premium. GHOST reviews and merges. Rules live in `RaidLeaver` and nothing calls them yet, so gameplay is unchanged. Status stays claimed for GHOST. | claimed | — |

Per `docs/design/shardfall_raids.md`, each of the five classes gets a 4-piece Verdant Relic Set from Heartwood Hard, with a 2-piece and a 4-piece bonus that changes play rather than adding raw power creep. The module defines the sets, counts equipped pieces, returns active bonuses, and exposes `setPct(owned)` (0-100) for the session recap. T-025 landed in #37 with pieces bound. Kevin's follow-up is T-031: pieces stay raid-drop only, and they are tradeable on the Market Board, not bound. Heartwood Vendor sells weaker helper items for Raid Marks or materials, never set pieces. Ghost wires that vendor under T-010. T-027 is claimed on `helper/raid-conduct-9721`.

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

### T-017 hooks for GHOST

HELPER did not edit `DungeonService.luau`, `Rootvault.luau`, `CombatHud.luau`, or T-012. `EnemyAbilities` is pure and ready to call. Kinds already match `Rootvault.ROLES`, and `"haste"` is already in `Rootvault.SHRINES`. Do not add a function to `Rootvault`. The door note there still says the boon lasts the rest of the run; Haste in this module expires after `EnemyAbilities.HASTE.duration` (30 seconds). Leave that string unless you want it changed in a T-003 edit.

`$path` already includes `src/ReplicatedStorage/Shared`, so `EnemyAbilities` is in the place file without a `default.project.json` edit. Nothing requires it until the calls below.

`DungeonService.luau`, next to the `Rootvault` require:

```lua
local EnemyAbilities = require(ReplicatedStorage.Shared.EnemyAbilities)
```

On the `Run` type, next to `shrine`:

```lua
	haste: EnemyAbilities.Haste?,
	hasteWalk: number?,
	priority: string?,
```

On the `Enemy` type, next to `stunUntil`:

```lua
	nextHeal: number?,
```

In `enter`, next to `shrine = ""`:

```lua
		haste = nil,
		hasteWalk = nil,
		priority = nil,
```

In the enemy literal inside `spawnEnemy`:

```lua
		nextHeal = nil,
```

`chooseDoor`, replace the shrine branch. A new shrine clears a live Haste buff first so Might does not keep the speed bonus. `applyHaste` returns nil for `"might"` and `"ward"`.

```lua
	elseif picked.id == "shrine" then
		local now = os.clock()
		if run.hasteWalk ~= nil then
			local previous = player.Character
			local body = if previous ~= nil then previous:FindFirstChildOfClass("Humanoid") else nil
			if body ~= nil then
				body.WalkSpeed = run.hasteWalk
			end
		end
		run.haste = nil
		run.hasteWalk = nil
		run.shrine = Rootvault.shrine(math.random(1, 3))
		run.haste = EnemyAbilities.applyHaste(run.shrine, now)
		if run.haste ~= nil then
			local character = player.Character
			local humanoid = if character ~= nil
				then character:FindFirstChildOfClass("Humanoid")
				else nil
			run.hasteWalk = if humanoid ~= nil
				then humanoid.WalkSpeed
				else EnemyAbilities.HASTE.baseWalk
			if humanoid ~= nil then
				humanoid.WalkSpeed = EnemyAbilities.moveSpeed(run.hasteWalk, run.haste, now)
			end
		end
```

`pushRun(player, picked.note)` already follows the branch. When `run.haste ~= nil`, pass `EnemyAbilities.HASTE.gainedNote` instead of `picked.note`.

Expire at the top of the `onHeartbeat` player loop, after the `run.resolving` check and before the `hrp == nil` continue, so a cleared room still drops the buff. `now` is the `os.clock()` already taken at the top of `onHeartbeat`.

```lua
		if run.haste ~= nil and EnemyAbilities.expireHaste(run.haste, now) == nil then
			run.haste = nil
			if run.shrine == EnemyAbilities.HASTE.id then
				run.shrine = ""
			end
			local character = player.Character
			local humanoid = if character ~= nil
				then character:FindFirstChildOfClass("Humanoid")
				else nil
			if humanoid ~= nil and run.hasteWalk ~= nil then
				humanoid.WalkSpeed = run.hasteWalk
			end
			run.hasteWalk = nil
			pushRun(player, EnemyAbilities.HASTE.fadedNote)
		end
```

At the top of `destroyRun`, restore the same way before `runs[player] = nil`, so the hub does not keep the boosted WalkSpeed. Do not copy `haste` onto the profile.

`damageEnemy`, after the `run.echo` multiplier and before `enemy.hp -= amount`. Skip the check when the character has no root, so a missing attacker is not treated as world origin.

```lua
	local hrp = rootPart(player)
	if hrp ~= nil then
		local look = enemy.part.CFrame.LookVector
		local dealt, blocked = EnemyAbilities.block({
			kind = enemy.kind,
			hp = enemy.hp,
			x = enemy.part.Position.X,
			z = enemy.part.Position.Z,
			lookX = look.X,
			lookZ = look.Z,
		}, hrp.Position.X, hrp.Position.Z, amount)
		if blocked then
			pushRun(player, EnemyAbilities.SHIELDER.blockNote)
			return false
		end
		amount = dealt
	end
```

A blocked hit deals 0 and returns before stagger, flash, and the HP write. Pet and projectile hits use this same function, and the position is the player's, because `damageEnemy` does not receive a shot origin.

`moveEnemy`: keep the snap `lookAt` for every kind except `EnemyAbilities.SHIELDER.kind`. Replace the distance branch so both arms share `nextPosition`. `dt` is already an argument.

```lua
	local nextPosition = position
	if distance > hold then
		local step = math.min(distance - hold, enemy.moveSpeed * dt)
		nextPosition = position + offset.Unit * step
		local x, _, z = Dungeons.roomOrigin(roomIndex)
		local limit = floorSize / 2 - 4
		nextPosition = Vector3.new(
			math.clamp(nextPosition.X, x - limit, x + limit),
			position.Y,
			math.clamp(nextPosition.Z, z - limit, z + limit)
		)
	end
	if enemy.kind == EnemyAbilities.SHIELDER.kind then
		local look = enemy.part.CFrame.LookVector
		local lookX, lookZ = EnemyAbilities.turnShield(
			look.X,
			look.Z,
			goal.X - nextPosition.X,
			goal.Z - nextPosition.Z,
			dt
		)
		enemy.part.CFrame = CFrame.lookAt(nextPosition, nextPosition + Vector3.new(lookX, 0, lookZ))
	else
		enemy.part.CFrame =
			CFrame.lookAt(nextPosition, Vector3.new(goal.X, nextPosition.Y, goal.Z))
	end
```

Other kinds stay snapped to the player. A zero aim keeps the previous look, so a brute standing on the player does not spin.

Mender pulses go in `onHeartbeat`, after the `tickEnemy` loop, inside the `not run.cleared` block. `run.enemies` is a map. `mend` and `priority` take an array.

```lua
		local roster = {}
		local byId = {}
		for _, enemy in pairs(run.enemies) do
			local row = {
				id = enemy.id,
				kind = enemy.kind,
				hp = enemy.hp,
				maxHp = enemy.maxHp,
				x = enemy.part.Position.X,
				z = enemy.part.Position.Z,
				nextHeal = enemy.nextHeal,
			}
			table.insert(roster, row)
			byId[enemy.id] = row
		end
		local pulses = EnemyAbilities.mend(roster, now)
		for _, pulse in ipairs(pulses) do
			local target = run.enemies[pulse.targetId]
			local mender = run.enemies[pulse.menderId]
			if target ~= nil and target.hp > 0 then
				target.hp = pulse.hp
				paintEnemy(target)
			end
			if mender ~= nil then
				mender.nextHeal = pulse.nextHeal
			end
			local targetRow = byId[pulse.targetId]
			if targetRow ~= nil then
				targetRow.hp = pulse.hp
			end
			local menderRow = byId[pulse.menderId]
			if menderRow ~= nil then
				menderRow.nextHeal = pulse.nextHeal
			end
		end
		if #pulses > 0 then
			pushRun(player, EnemyAbilities.MENDER.pulseNote)
		end
		run.priority = EnemyAbilities.priority(roster, now)
```

`priority` is the living mender id, or nil. `publicRun` can send it later. `CombatHud.luau` is unchanged on this branch. A moss crawler with no position is still the priority and still produces no pulse.

Attack cooldown is not in `DungeonService`. It is `state.nextAttack` / `state.nextCompanion` in `CombatService` (T-001). This branch does not edit that file. Wire it only if you want the ×1.2 swing speed; walk speed already comes from the heartbeat and `chooseDoor` snippets.

```lua
function DungeonService.hasteAttack(player: Player, attackSpeed: number, now: number): number
	local run = runs[player]
	if run == nil then
		return attackSpeed
	end
	local sped = EnemyAbilities.attackSpeed(attackSpeed, run.haste, now)
	if sped <= 0 then
		return attackSpeed
	end
	return sped
end
```

```lua
	local attackSpeed = DungeonService.hasteAttack(player, offense.attackSpeed, now)
	state.nextAttack = now + CombatMath.cooldown(attackSpeed)
```

Use the same `hasteAttack` call for `state.nextCompanion`. Pass the gear attack speed each swing. Do not pass a value `attackSpeed` already returned, or the bonus stacks.

`tests/run.luau` requires `./EnemyAbilities.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is.

### T-015 hooks for GHOST

HELPER did not edit `ReceiptService.luau`, `Remotes.luau`, `RateLimiter.luau`, `Schema.luau`, `init.server.luau`, `init.client.luau`, or `default.project.json`. `Loops.PREMIUM_ENABLED` stays `false`. Product ids stay `0`. While that is true, `LoopService.grantPremium`, `claimPremium`, and `skipTier` refuse and write nothing. `LoopHud` is already mounted from `init.client.luau`. No new `begin()` line: `LoopService` has no `start()`, and `ReceiptService.start()` already runs inside `begin()` after `DataService.start()`.

Do not read `MarketplaceService.ProcessReceipt`. The new branch below sits inside the existing assignment in `ReceiptService.start`. A `false` from `grantPremium` must stay `NotProcessedYet`, or a real purchase is swallowed.

`ReceiptService.luau`, with the other requires:

```lua
local Loops = require(game:GetService("ReplicatedStorage").Shared.Loops)
local LoopService = require(script.Parent.LoopService)
```

Inside the existing `ProcessReceipt = function(receipt)` callback, after the player and `PurchaseId` checks and in place of the "nothing is sold yet" return:

```lua
			if Loops.productKind(receipt.ProductId) ~= nil then
				if LoopService.grantPremium(player, receipt.PurchaseId, receipt.ProductId) then
					return Enum.ProductPurchaseDecision.PurchaseGranted
				end
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
```

Publish by assigning the module fields from `ReceiptService.start`, before the callback. Leave the source values in `Loops.luau` at `false` and `0`. Do not edit `Loops.luau` to flip the switch.

```lua
Loops.PASS_PRODUCT_ID = 0 -- published developer product id for the 400 Robux pass
Loops.ARCHIVE_PRODUCT_ID = 0 -- published id for the archive pass, 480 Robux
Loops.PREMIUM_ENABLED = true
```

Both ids must be positive and different. The archive grants the same track and does not refund more than 400 Gems. A duplicate `PurchaseId` returns granted and does not pay twice.

`default.project.json`, inside `ReplicatedStorage.Remotes`, next to `PremiumPass`:

```json
        "ShardPass": { "$className": "RemoteFunction" },
```

`RateLimiter.luau` `RULES`. A remote with no rule is rejected:

```lua
	ShardPass = { capacity = 4, perSecond = 1 },
```

`Remotes.luau` already requires `LoopService`. Inside `Remotes.bind`, next to `PremiumPass`. There is no mentor action. Clients must not grant Second Chance.

```lua
	functionRemote("ShardPass").OnServerInvoke = function(player, action)
		return guard(player, "ShardPass", function()
			if action == "retry" then
				return LoopService.retry(player)
			end
			if action == "shuffle" then
				return LoopService.shuffle(player)
			end
			if action == "claim" then
				return LoopService.claimPremium(player)
			end
			if action == "skip" then
				return LoopService.skipTier(player)
			end
			if action == "overflow" then
				return LoopService.overflow(player)
			end
			return { ok = false, error = "Unknown pass action." }
		end)
	end
```

| Remote | action | payload |
|---|---|---|
| ShardPass | `retry` | `nil` |
| ShardPass | `shuffle` | `nil` |
| ShardPass | `claim` | `nil` |
| ShardPass | `skip` | `nil` |
| ShardPass | `overflow` | `nil` |

`PremiumPass` already calls `LoopService.premium()`. While the switch is off it returns `{ ok = false, error = "The premium track is not for sale yet." }`. When the switch is on and the pass id is positive it returns `productId`, `archiveProductId`, `robux`, and `archiveRobux`. The Pass button prompts only in that case. It calls `PromptProductPurchase`. It does not read `ProcessReceipt`.

Server-only, not a remote: `LoopService.noteMentor(player, allyUserId, allyLevel, allyNew)`. Credit requires a different player who is level 1 to 9, or `allyNew == true`. There is no party roster in `DungeonService` today. Do not scan the server. Call it from a real ally on that clear once a party exists. Until then Second Chance stays 0 and Retry / Shuffle refuse.

`LoopHud` does not call `ShardPass` yet. `WaitForChild` on a missing remote would hang the button. After `ShardPass` exists, the client calls are `invoke("ShardPass", "retry")`, `"shuffle"`, `"claim"`, `"skip"`, and `"overflow"`.

Schema can stay at version 20 for this merge. `passPremium`, `passPremiumClaimed`, `passCosmetics`, `passOverflow`, and `boardChance` are written on the profile and `reconcile` keeps unknown keys, so they survive a save. They are not in `Schema.snapshot`. Before you set `PREMIUM_ENABLED`, add these fields so the client can see ownership and Second Chance. Suggested version 21, in `ProfileData`, `template()`, and `if version < 21` in `migrate`:

```lua
passPremium: boolean,
passPremiumClaimed: number,
passCosmetics: { [string]: boolean },
passOverflow: number,
boardChance: number,
```

Defaults: `passPremium = false`, `passPremiumClaimed = 0`, `passCosmetics = {}`, `passOverflow = 0`, `boardChance = 0`. In `snapshot`:

```lua
passPremium = data.passPremium == true,
passPremiumClaimed = data.passPremiumClaimed or 0,
passCosmetics = Schema.deepCopy(data.passCosmetics or {}),
passOverflow = data.passOverflow or 0,
boardChance = data.boardChance or 0,
```

No power fields. Premium rewards are skins, pet hats, trails, one weapon VFX, one emote, and 400 Gems by tier 50. Tier 50 (`pass_skin_nightmare`) also needs `nightmareBest >= 1`. A skip costs 80 Gems and still cannot mint that skin.

`tests/run.luau` already requires `./Loops.spec`. No new spec line.

Build stamp files are T-012. This branch does not change them. The stamp lines are in files other in-flight branches are editing, and prior HELPER branches skipped the stamp the same way.

### T-016 hooks for GHOST

HELPER did not edit `CombatHud.luau`, `DungeonService.luau`, `Progression.luau`, or T-012. `SessionRecap` is pure and ready to call. It does not read the profile, grant rewards, or spend Robux. The client only formats the four numbers it is given. `$path` already includes `src/StarterPlayer/StarterPlayerScripts/ShardfallClient`, so `SessionRecap` is in the place file without a `default.project.json` edit.

This note is against `CombatHud.luau` after #29 (`cbe50bc`). That file has `CombatHud.setWallet` and the HP attribute fallback on `HumanoidRootPart`. `ThumbBar.luau` is gone. The action row is `ActionBar.luau`. Neither of those needs a change for this line.

`CombatHud.luau`, next to the `MobileShell` require:

```lua
local SessionRecap = require(script.Parent.SessionRecap)
```

In `victoryBody`, after the voucher branch (`payload.voucher == "armory"` / `"pets"` / the "No roll voucher" line) and before `return table.concat(lines, "\n")`:

```lua
	local recapLine = SessionRecap.line(payload.recap)
	if recapLine ~= "" then
		table.insert(lines, recapLine)
	end
```

`showCard` in the `payload.kind == "victory"` branch already passes `victoryBody(payload)`. Do not add a second label, and do not append this line on the defeat card. An empty string means the payload had no recap yet, so skip it. A blank row would show up before GHOST sends the table.

`SessionRecap.line` accepts that table, or the four numbers in the same order as `Progression.recap` (`beforeLevel`, `afterLevel`, `epics`, `setPct`). Named fields:

```lua
recap = {
	beforeLevel = sessionStartLevel, -- account level when this server session began
	afterLevel = afterLevel, -- data.level after Progression.addXp
	epics = sessionEpics, -- Epic drops this session. 0 until a counter exists
	setPct = 0, -- Relic Set percent, 0-100. 0 until T-010
}
```

The design sentence is `This session: +3 levels, 2 Epics, 41% to your Relic Set`. That is what `Progression.recap(1, 4, 2, 41)` returns, and what `SessionRecap.line` returns for those same numbers. `Progression.recap` always prints all three clauses, always uses the plural, and `string.format` throws if a field is nil. The card line does not need a change to `Progression.luau`. `SessionRecap` uses the same gain (`max(0, after - before)`) and the same 0-100 clamp, then:

- Drops a missing field, a zero, a negative, NaN, or infinity. No `nil` is concatenated.
- Says `+1 level` and `1 Epic` when the count is one.
- Returns `""` when the table is missing, so the card stays as it is today.
- Returns `This session: a quiet clear.` when the fields arrived and every one is zero.
- Stays within `SessionRecap.MAX_CHARS` (60), about two lines in the current card body (340px card, 16px padding, TextSize 15). A pathological count shortens `41% to your Relic Set` to `41% Relic Set`.

Do not pass `payload.levels` into the recap. In `grant`, `levels` is the return from `Progression.addXp` for this clear only. `SessionRecap` ignores a `levels` key on purpose.

No new remote and no schema field. The existing `CombatFx` victory payload gains `recap`. Hold the two counters in memory for the server session.

`DungeonService.luau`, next to the other player maps:

```lua
local sessionStartLevel: { [Player]: number } = {}
local sessionEpics: { [Player]: number } = {}
```

In `grant`, next to `local levels = 0`, so `afterLevel` is visible after `DataService.mutate`:

```lua
local afterLevel = 0
```

Inside the mutate callback, before `Progression.addXp`, remember the level once:

```lua
	if sessionStartLevel[player] == nil then
		sessionStartLevel[player] = data.level
	end
```

After `levels = Progression.addXp(data, xpGain)`:

```lua
	afterLevel = data.level
```

On the victory `fx` table (`kind = "victory"`, the `else` of `if dismissIn == nil`), next to `levels = levels`:

```lua
			recap = {
				beforeLevel = sessionStartLevel[player],
				afterLevel = afterLevel,
				epics = sessionEpics[player] or 0,
				setPct = 0,
			},
```

`Players.PlayerRemoving` in `DungeonService.start` already clears `idleNoted[player]`. Clear the two maps there too:

```lua
		sessionStartLevel[player] = nil
		sessionEpics[player] = nil
```

That first-grant snapshot misses levels gained in Haven before the first clear. Snapshot `data.level` when the profile finishes loading in `DataService` if the line should include those. There is no session Epic counter and no Relic Set percent on the profile (T-010). Leave `epics` and `setPct` at 0 until those exist. A 0 is omitted, so a real level gain still prints.

`tests/run.luau` already requires `./Progression.spec`. No new spec line.

Build stamp files are T-012. This branch does not change them. The module is not required by the client until the `CombatHud` line above, and prior HELPER branches skipped the stamp the same way.

### T-025 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `Schema.luau`, `Remotes.luau`, `ItemBases.luau`, `Trading.luau`, `DungeonService.luau`, `CombatHud.luau`, or T-012. `RelicSets` is pure and ready to call. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing requires it until the calls below. Gameplay is unchanged.

Class ids match `Classes` (`warden`, `tidecaller`, `forgeborn`, `frostblade`, `voidcaster`). Slots match `Schema.ARMOR_SLOTS` (`helm`, `chest`, `legs`, `boots`). Piece ids are `verdant_<class>_<slot>`. They are not in `ItemBases` yet. `grovewarden_*` is a different set. Do not reuse those ids.

`RelicSets.stamp` copies a drop and does not mutate the table you pass. #37 set `bound = true` and `tradeable = false`. T-031 changes that: pieces are not bound, and `stamp` sets `bound = false` and `tradeable = true`. `RelicSets.isRelic` is true for a piece id, a set id, or an item whose `templateId`, `id`, `pieceId`, or `setId` names one. A starter item with `bound = true` is not a relic. The check does not use the bound flag.

`count` and `active` read what is worn. `setPct` reads what is owned. A duplicate piece counts once. Another class's pieces do not count. 0 or 1 piece is no bonus. 2 or 3 is the 2-piece. 4 is both, 2-piece first. `setPct` returns 0, 25, 50, 75, or 100 for the fullest set in the list. A number is a piece count, not a percent: `setPct(4)` is 100 and `setPct(5)` clamps to 100. A bare id string is 0. Pass a list, an inventory map, or a count.

No bonus has a damage, health, defense, crit, or attack field. If a row has no damage field, do not invent one. Use the skill's existing coefficient. Numbers and the play reason are in `docs/design/relic_sets.md`.

**T-010 / RaidService.** Require it next to `Raids`:

```lua
local RelicSets = require(ReplicatedStorage.Shared.RelicSets)
```

Heartwood Hard only (`RelicSets.RAID == "heartwood"`, `RelicSets.DIFFICULTY == "hard"`). Story and Normal do not drop these. `Raids.DIFFICULTIES` has no `hard` row yet (that is T-007). When the clear is Hard and the loot roll grants a piece, pick one the player's class does not already own:

```lua
local setDef = RelicSets.get(data.classId)
if setDef == nil then
	-- No class yet. Do not drop a relic.
	return
end
local have = {}
for _, item in pairs(data.inventory) do
	if type(item) == "table" and type(item.templateId) == "string" then
		have[item.templateId] = true
	end
end
local missing = {}
for _, piece in ipairs(setDef.pieces) do
	if have[piece.id] ~= true then
		table.insert(missing, piece)
	end
end
-- `missing[1]` is a fair personal drop. Empty means the set is complete.
local piece = missing[1]
if piece ~= nil then
	local drop = RelicSets.stamp({
		templateId = piece.id,
		name = piece.name,
		kind = piece.kind,
		rarity = piece.rarity,
		slot = piece.slot,
		setId = piece.setId,
	})
	-- Insert `drop` into the inventory with a new uid. After T-031 it is tradeable, not bound.
end
```

The Vault uses the same list. A Hard week can offer one id from `missing`. Stamp it before it enters the bag. Do not offer a piece they already own. Do not add a Robux price. Heartwood Vendor sells weaker helper items for Raid Marks or materials, never these set pieces. Ghost wires that vendor under T-010. This module has no vendor prices.

The client must not send the bonus table. Call `active` on the server from the worn armor:

```lua
local equipped = {}
local armor = data.equipped.armor
if type(armor) == "table" then
	for _, uid in pairs(armor) do
		local item = data.inventory[uid]
		if type(item) == "table" then
			table.insert(equipped, item)
		end
	end
end
local bonuses = RelicSets.active(data.classId, equipped)
```

`bonuses[i].id` is what a raid panel can show (`bonuses[i].note`). Applying the taunt, cleanse, cone, or Chill spread is combat (T-001), not this call. T-010 does not need to change `CombatService`.

**Heartwood Hard drop table.** Reference the ids from the module so they cannot drift. One personal piece per class per lockout is the intended shape. The final boss (`awakened`, Grandmother Gnarl Awakened) is the drop named in the raids doc. Other Hard bosses can use the same `setDef.pieces` list if the loot table should spread the set across the wing.

| Class | Set id | Piece ids |
|---|---|---|
| warden | `verdant_warden` | `verdant_warden_helm`, `verdant_warden_chest`, `verdant_warden_legs`, `verdant_warden_boots` |
| tidecaller | `verdant_tidecaller` | `verdant_tidecaller_helm`, `verdant_tidecaller_chest`, `verdant_tidecaller_legs`, `verdant_tidecaller_boots` |
| forgeborn | `verdant_forgeborn` | `verdant_forgeborn_helm`, `verdant_forgeborn_chest`, `verdant_forgeborn_legs`, `verdant_forgeborn_boots` |
| frostblade | `verdant_frostblade` | `verdant_frostblade_helm`, `verdant_frostblade_chest`, `verdant_frostblade_legs`, `verdant_frostblade_boots` |
| voidcaster | `verdant_voidcaster` | `verdant_voidcaster_helm`, `verdant_voidcaster_chest`, `verdant_voidcaster_legs`, `verdant_voidcaster_boots` |

`ItemBases` has no row for these. When you add one, copy `id`, `name`, `kind = "Armor"`, `rarity = "Epic"`, `slot`, and `setId` from `RelicSets.piece(id)`. Use the normal Epic helm/chest/legs/boots stat ranges. Do not put the 2-piece or 4-piece numbers on the item as stats. `RelicSets` stays the bonus source. No product id.

**Trades.** Do not add a `Trading.rejection` block for relics. There is no `"Relic Set pieces are bound."` return, and no `RelicSets.isRelic` check inside `Trading.rejection`. Pieces are raid-drop only and tradeable on the Market Board. They are not bound. `Trading.luau` stays unedited for relics. Cosmetics and the starter check stay as they are. T-031 updates `stamp`, `isRelic`, and `docs/design/relic_sets.md` to match. Until that lands, `stamp` from #37 still sets `bound = true`.

**DungeonService / recap.** T-016's victory payload still says `setPct = 0` until this exists. When T-026 wires that payload, replace the 0. Do not pass the sample 41 from `Progression.recap`. Owned pieces are the inventory, not only the worn ones. Equipped relics are still in the bag.

`DungeonService.luau`, next to the other requires:

```lua
local RelicSets = require(ReplicatedStorage.Shared.RelicSets)
```

Inside the `grant` mutate, next to the level snapshot from the T-016 hooks:

```lua
local relicPct = RelicSets.setPct(data.inventory)
```

On the victory `recap` table, in place of `setPct = 0`:

```lua
setPct = relicPct,
```

`RelicSets.setPct` does not write the profile. No new remote and no schema field. `Schema.snapshot` already deep-copies `inventory`, and `sanitizeGear` does not strip unknown item keys, so `bound` and `tradeable` round-trip without a version bump. Adding them to the `Item` type is optional and belongs to T-012. Until then `isRelic` is the authority.

`tests/run.luau` requires `./RelicSets.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

### T-027 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `Schema.luau`, `Remotes.luau`, `RateLimiter.luau`, `DungeonService.luau`, or any other T-012 file. `RaidConduct` is pure and ready to call. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing requires it until the calls below. Gameplay is unchanged. No build stamp.

Thresholds are `RaidConduct.CONFIG`: warn at 60s, remove at 90s, vote lock 120s, vote `3/4` rounded up, 1 kick per UTC day (`daySeconds` 86400), reason length 80. Idle codes are `RaidConduct.IDLE_REASONS` (`idle` and `afk`, exact match after trim and lowercase). Do not hardcode the numbers beside the module. Pass `os.time()` (unix seconds) in as `now`. The kick day is UTC `floor(now / 86400)`, same as `tradeDay`. `os.clock()` is not wall time and must not be used for conduct timestamps. The module does not read the clock.

`RaidService.luau`, next to the `Raids` require:

```lua
local RaidConduct = require(ReplicatedStorage.Shared.RaidConduct)
```

Keep the roster in memory on `RaidService`, not on the profile. One raid record, one seat per player:

```lua
type Seat = {
	userId: number,
	joinedAt: number,
	lastInputAt: number,
	removed: boolean,
}

type Conduct = {
	raidStartedAt: number,
	guided: boolean,
	inCombat: boolean,
	inCutscene: boolean,
	seats: { [Player]: Seat },
	open: {
		initiator: Player,
		targetUserId: number,
		reason: string,
		votes: { [number]: boolean },
	}?,
}
```

There is no raid roster in `RaidService` today. `launch` starts a solo Heartwood through `DungeonService.enter` and comes straight back. The live heartbeat is `DungeonService.onHeartbeat` (T-003), which T-008's row does not list.

**Where to feed input.** On a successful `launch`, and again when a backfill joins: `joinedAt = now`, `lastInputAt = now`. Joining counts as input. Do not reset `raidStartedAt` for a backfill. After that, stamp `lastInputAt = now` only for a real action: `Humanoid.MoveDirection` magnitude greater than 0, a jump, or an ability the server actually accepted. Camera look, by itself, is not input. The client must not send the timestamp. Suggested stamp from a server heartbeat inside `RaidService` (movement) plus the ability handlers you already own. Those handlers are not in `RaidService` today. See the question below before editing `DungeonService` or `CombatService`.

**Cutscene flag.** Nothing in the current raid run is a cutscene. Pass `inCutscene = false` until one exists. While a cutscene is playing, set the flag true for every seat in it. On the frame it ends, set each of those seats' `lastInputAt` to that `now` before clearing the flag. Otherwise a long scene looks like 90 seconds of idle on the next tick. Only `inCutscene == true` pauses the clock.

**Combat flag.** Pass `inCombat = true` only while the current pull has a living hostile. A cleared room, loot, or the walk between pulls is not combat, so vote-kick can open there once the 2-minute lock is over. The AFK clock does not read this flag. Combat does not pause AFK.

**When to tick AFK.** Once a second is enough. `RaidService` has no `Heartbeat` and no `start` today. Add the connection on `RaidService` so the tick stays inside T-008's file, then skip seats with `removed == true`. For each remaining seat:

```lua
local check = RaidConduct.afk({
	now = now,
	lastInputAt = seat.lastInputAt,
	inCutscene = conduct.inCutscene == true,
})
```

Act on `check.state`, not on a second comparison of `check.idleSeconds`.

| state | what to do |
|---|---|
| `ok` | nothing |
| `paused` | cutscene. Do not warn and do not remove. |
| `warning` | tell that player once per idle stretch. The next call still returns `warning` until they input or hit 90s. A new input that drops them under 60s, then another idle stretch, warns again. |
| `remove` | set `seat.removed = true`, skip later reward grants for this player for the rest of this run, and queue a backfill. `check.forfeitRewards` and `check.queueBackfill` are both true. `check.keepMarks` is false. |
| `invalid` | do not remove. The stamp was missing. |

`forfeitRewards` means do not call `Raids.applyClear` (or any other raid grant) for that player again this run. Do not subtract `raidMarks` they were already paid. This module does not claw rewards back.

**How to call vote-kick.** One open vote at a time. Only the player who starts it goes through `openVote`. Later yes votes call `tally` only. Calling `openVote` per voter would spend their daily kick too.

```lua
local request = {
	now = now,
	raidStartedAt = conduct.raidStartedAt,
	inCombat = conduct.inCombat == true,
	guided = conduct.guided == true,
	initiatorUserId = player.UserId,
	targetUserId = targetUserId,
	reason = reason,
	members = members,
	votes = if conduct.open ~= nil then conduct.open.votes else nil,
	kickDay = data.raidKickDay,
	kickCount = data.raidKicksToday,
}
```

Build `members` from the seats you still count, as `{ { userId = seat.userId, joinedAt = seat.joinedAt } }`. Leave out `removed` seats. `joinedAt` is what starts that player's own 2-minute protection. A bare user id has no join grace. Ignore a client `guided`, `inCombat`, `now`, or yes-count. Store the opener's reason on `conduct.open` and pass that same string into every later `tally`. A later voter's text must not replace it.

`openVote` returns `spentKick == true` only when the vote is legally open. Then persist the daily fields inside `DataService.mutate` (see the schema note). `passed` is still false. Record `votes[initiatorUserId] = true` yourself. The opener is not an automatic yes inside `tally`. A refused open (`spentKick == false`) must not write the profile. `kickCount` on that result is the old value.

`tally` never spends a kick and never changes `kickDay` / `kickCount`. When `passed == true`, remove the target. `keepMarks` is true and `forfeitRewards` is false, including reason `unfair` and reason `idle`. Grant this run's Marks as you would have. `dropQueuePriority` is true only for a passed vote whose stored reason is exactly `idle` or `afk`. `queueBackfill` stays false on every vote result. When `ok == true` and `passed == false`, keep the vote open. When `ok == false` (combat started, Guided, or the window slammed shut), do not apply the kick. Hold the ballots and call `tally` again once the gate is open. This does not refund the daily kick.

`guided == true` is a Guided Raid (guild host, Oath of the Grove, Seekers). A Hard or Shardbreaker premade is not Guided unless that mode is actually on. Kicking is disabled for the whole Guided run. AFK removal still runs there. The design's leaver penalty (3 leaves, 15-minute Finder cooldown, 3-minute rejoin) is not in this module. It is T-035.

The client can send an intent. It cannot send the rules. A remote is T-012, so this branch does not add one. When you add it, a missing rate-limit rule rejects the call:

```lua
RaidConduct = { capacity = 4, perSecond = 1 },
```

| Remote | action | payload | server reads |
|---|---|---|---|
| RaidConduct | `input` | `nil` | stamp `lastInputAt`. Ignore any time in the payload. |
| RaidConduct | `vote` | `{ targetUserId: number, reason: string }` | opener: `openVote` with your reason. Later yes: `tally` only. |

`input` is optional if the server already sees movement and abilities. Without it, a player who only presses abilities on a still character never stamps, and the 60s warning is wrong. Button presses need a server-side stamp somewhere.

**Schema.** HELPER does not edit `Schema.luau`. Suggested fields, same shape as `tradeDay` / `tradeValueToday`. Add them on whichever version is free when you wire this. Version 20 is current. T-015 already sketched 21 for the pass fields, so do not assume 21 is still open. `ProfileData`, `template()`, the matching `migrate` arm, and `snapshot`:

```lua
raidKickDay: number, -- floor(unix / 86400). 0 until the first opened vote.
raidKicksToday: number,
```

Defaults: `raidKickDay = 0`, `raidKicksToday = 0`. Reset rule: `RaidConduct.dayNumber(now)` is the UTC day (`floor(now / 86400)`). If that differs from `raidKickDay`, the module treats the stored count as 0. Write `raidKickDay = result.kickDay` and `raidKicksToday = result.kickCount` only when `openVote` returns `spentKick == true`. Do not reset these on the Tuesday weekly raid reset. Do not write them from `tally`. Queue priority is not one of these fields. On `dropQueuePriority`, sort that player's next Finder ticket last until that UTC day ends.

`tests/run.luau` requires `./RaidConduct.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. Vote size is `ceil(3/4)` of the whole group, and the target cannot vote. A group of 4 needs all 3 others. A group under 4 cannot open a vote. Should the target count in the 3/4, or is it 3/4 of the voters only?
2. The daily kick is spent when the vote opens, even if it never reaches 3/4. A refused attempt (combat, grace, Guided, bad reason, group too small) does not spend it. A vote that becomes impossible because people left is not refunded. Should a failed vote be free?
3. Every passed vote keeps Marks, idle included. Idle only drops queue priority. Only the 90s AFK removal forfeits rewards, and only rewards not yet granted. Should an idle vote-kick also forfeit Marks?
4. `queueBackfill` is true only on AFK removal. A passed vote does not flag one. Should it?
5. The 2-minute lock is the raid's opening, plus 2 minutes from `joinedAt` when you pass it, so a backfill is not kickable on arrival. Is the lock raid-wide only?
6. The AFK clock pauses only in cutscenes. Combat does not pause it. Should combat pause AFK too? There is no cutscene flag on the raid run yet.
7. The kick day is UTC `floor(now / 86400)`, matching `tradeDay`, not the Tuesday weekly reset and not a local midnight. Is that the day you want?
8. `guided` is an explicit flag. Hard and Shardbreaker premades can still vote-kick. Should every Hard or Shardbreaker run count as Guided?
9. T-008 lists `RaidService.luau` and `Raids.luau` only. The run heartbeat and the ability handlers live in `DungeonService` / `CombatService`. Should `noteInput` and the combat flag be called from those files, or do you want a `RaidService` heartbeat that only sees movement until a T-012 remote exists?
10. The leaver penalty in the raids doc (3 leaves, 15-minute Finder cooldown, 3-minute rejoin) is T-035, not this module.

### T-035 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `Schema.luau`, `Remotes.luau`, `RateLimiter.luau`, `DungeonService.luau`, or any other T-012 file. `RaidLeaver` is pure and ready to call. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing requires it until the calls below. Gameplay is unchanged. No build stamp. No remote. Nothing here costs Robux.

Thresholds are `RaidLeaver.CONFIG`: 3 counted leaves in one UTC day (`leavesPerDay`), then a 15-minute Finder cooldown (`cooldownSeconds` = 900), and a 3-minute rejoin window (`rejoinSeconds` = 180). The day length is `daySeconds` (86400). Do not hardcode the numbers beside the module. Pass `os.time()` (unix seconds) in as `now`. The leave day is UTC `floor(now / 86400)`, same as `tradeDay` and `RaidConduct.dayNumber`. `os.clock()` is not wall time. The module does not read the clock.

Causes are exact strings on `RaidLeaver.CAUSES`: `leave`, `disconnect`, `afk`, `kick`. `"AFK"`, `"vote"`, and `"Leave"` are refused. A refused call returns `ok == false` and must not be written.

`RaidService.luau`, next to the `Raids` require:

```lua
local RaidLeaver = require(ReplicatedStorage.Shared.RaidLeaver)
```

Build the record from the profile. Nil fields count as zeros, so a call before the migrate does not throw. It also does not persist.

```lua
local function leaveRecord(data)
	return {
		leaveDay = data.raidLeaveDay,
		leaveCount = data.raidLeavesToday,
		cooldownUntil = data.raidFinderCooldownUntil,
		rejoinUntil = data.raidRejoinUntil,
	}
end
```

The module returns a new result and does not write `data`. Persist only when `result.ok == true`, inside `DataService.mutate`. An `ok == false` result echoes a readable record on a bad clock or a bad cause, and returns zeros when the record itself is non-finite. Writing that would wipe a real cooldown.

```lua
local function persistLeave(player: Player, result)
	if result.ok ~= true then
		return
	end
	DataService.mutate(player, function(data)
		data.raidLeaveDay = result.leaveDay
		data.raidLeavesToday = result.leaveCount
		data.raidFinderCooldownUntil = result.cooldownUntil
		data.raidRejoinUntil = result.rejoinUntil
		return nil
	end)
end
```

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `depart(record, now, "leave")` | the player exits the run on purpose while still connected | one leave now. Clears any rejoin window. Does not open a new one. |
| `depart(record, now, "disconnect")` | `PlayerRemoving`, or the teleport failed and they are gone | opens `rejoinUntil = now + 180` and does not count. A second disconnect while that window is open keeps the original deadline. If the previous window already expired, that miss counts as one leave, then a new window opens. |
| `rejoin(record, now)` | they are back in the same run at or before `rejoinUntil` | `outcome == "cleared"` is not a leave. One second later, `outcome == "counted"`. |
| `resolve(record, now)` | a heartbeat, a login, or the start of `queue`, when they are not back | an open window stays open and does not count (`outcome == "window"`). A missed window counts once. Calling it again does not count again. |
| `finder(record, now)` | the Raid Finder gate, after `resolve` | `finderBlocked == true` refuses a new queue. It does not count a missed window. `missedWindow == true` means `resolve` has not been called yet. |
| `depart(record, now, "afk")` | `RaidConduct.afk` returned `state == "remove"` | not a leave. Clears an open or already-expired window so a later `resolve` cannot count it. |
| `depart(record, now, "kick")` | `RaidConduct.tally` returned `passed == true` | same as `afk`. A passed vote-kick is not a voluntary leave. |

The third counted leave sets `cooldownStarted == true` and `cooldownUntil = now + 900`. A counted leave while that cooldown is still running increments the count and does not move `cooldownUntil`. After `now >= cooldownUntil`, another counted leave starts a fresh 15 minutes. `finder` blocks only while `cooldownUntil > now`. A count of 3 or more does not, by itself, block Finder once the 15 minutes are over. The end instant is free (`now == cooldownUntil` is not blocked). The rejoin deadline is still inside the window (`now == rejoinUntil` is a rejoin).

A rejoin of the same run ignores `finderBlocked`. The cooldown refuses a new Finder queue. It does not lock them out of the run they dropped. `outcome == "cleared"` means put them back. Do not also call `finder` on that path.

This module never forfeits Marks or rewards. Keep using `RaidConduct` for that. `forfeitRewards` on an AFK removal is still the T-027 rule. A leave only feeds this cooldown.

**Finder gate.** `RaidService.queue` is the Finder entry. `join` calls `queue` today, so a premade listing would hit the same gate until those paths are split. `practice` does not call `queue`. Gate Finder only.

At the top of `queue`, after the profile is loaded:

```lua
local now = os.time()
local record = leaveRecord(profile)
local settled = RaidLeaver.resolve(record, now)
persistLeave(player, settled)
if settled.ok == true and settled.outcome == "window" then
	return reject("Rejoin your raid before the timer ends.")
end
local gate = RaidLeaver.finder({
	leaveDay = settled.leaveDay,
	leaveCount = settled.leaveCount,
	cooldownUntil = settled.cooldownUntil,
	rejoinUntil = settled.rejoinUntil,
}, now)
if gate.ok ~= true then
	return reject(gate.error or RaidLeaver.ERRORS.time)
end
if gate.finderBlocked then
	return reject(gate.error or RaidLeaver.ERRORS.cooling)
end
```

The table passed into `finder` is those four fields off `settled`. `finder` does not write. `ERRORS.cooling` is "Raid Finder is cooling down after too many leaves." There is no remote for this. The client does not send the count or the deadline.

While `outcome == "window"`, refuse the new queue and do not count yet. The miss counts when `resolve` later sees `now > rejoinUntil`. Do not call `depart(..., "leave")` from `queue`. That would count a player who still has time to rejoin.

**Rejoin.** `RaidService.receive` currently calls `queue`. A return to the same reserved server inside the window must call `rejoin` and skip the Finder gate:

```lua
local now = os.time()
local record = leaveRecord(profile)
if record.rejoinUntil ~= nil and record.rejoinUntil > 0 then
	local back = RaidLeaver.rejoin(record, now)
	persistLeave(player, back)
	if back.ok == true and back.outcome == "cleared" then
		-- Same run. Do not call queue.
		return
	end
end
```

If `outcome == "counted"`, the window was already over. Do not put them back in the run. Fall through to the Finder gate if this arrival is a new queue. Call `rejoin` only for the run they left. The module does not store a run id. Keep that id in memory on `RaidService` (the reserved code or the run token you already have). A hub visit is not a rejoin. The hub calls `resolve` on login and from `queue`, and counts the miss once the deadline passes.

**Disconnect.** `RaidService` has no `PlayerRemoving`. The one that destroys a live run is `DungeonService`'s `Players.PlayerRemoving` (T-003). That file is not on this row. Suggested shape, called from there into `RaidService` so the rule stays next to Finder:

```lua
function RaidService.noteDepart(player: Player, cause: string)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local result = RaidLeaver.depart(leaveRecord(profile), os.time(), cause)
	persistLeave(player, result)
end
```

On `PlayerRemoving`, if they were in a raid run, call `noteDepart(player, "disconnect")`. Do not call `"leave"`. Closing the client is a disconnect and gets the 3-minute window. There is no leave button today, so `"leave"` has no caller until you add a deliberate exit that fires while the player is still connected. A leave button would be a T-012 remote. This branch does not add one.

**AFK and vote-kick.** When T-008 handles `RaidConduct.afk` and `state == "remove"`, also call `noteDepart(player, "afk")`. When `RaidConduct.tally` returns `passed == true`, call `noteDepart(player, "kick")` for the target. Do those instead of `resolve`. An AFK removal or a passed kick clears the rejoin window, including one that already expired, and does not add a leave. If you `resolve` first, the miss counts and the later `afk` / `kick` cannot take it back.

**Schema.** HELPER does not edit `Schema.luau`. Suggested fields, same shape as `tradeDay` / `tradeValueToday` and the T-027 kick fields. Add them on whichever version is free when you wire this. Version 20 is current. T-015 sketched 21 for the pass fields, and T-027 asked for `raidKickDay` / `raidKicksToday` on the same kind of bump. One migrate can add the kick fields and these together. `ProfileData`, `template()`, the matching `migrate` arm, `sanitize`, and `snapshot` (so a Finder button can show the remaining time):

```lua
raidLeaveDay: number, -- floor(unix / 86400). 0 until the first counted leave.
raidLeavesToday: number,
raidFinderCooldownUntil: number, -- unix seconds. 0 when Finder is not cooling.
raidRejoinUntil: number, -- unix seconds. 0 when no disconnect window is open.
```

Defaults: all four are 0. `RaidLeaver.dayNumber(now)` is the UTC day. If that differs from `raidLeaveDay`, the module treats the stored count as 0 and returns the new day. The cooldown is wall-clock. It still blocks after midnight until `raidFinderCooldownUntil`. Do not clear `raidFinderCooldownUntil` on the day change, and do not reset these on the Tuesday weekly raid reset. `wholeNumber` defaults match `tradeDay`. A non-finite field makes `finder` return `ok == false` and `finderBlocked == true`. If `sanitize` turns that into 0 before the check, the block is gone. Leave a non-finite cooldown for the module to refuse, or treat it as blocked inside `sanitize`.

`tests/run.luau` requires `./RaidLeaver.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. A leave during the 15 minutes does not add time. A counted leave after `cooldownUntil` starts another 15 minutes, even though the count is already past 3. Should that be one cooldown per UTC day instead, or should every leave from the 3rd onward refresh the 15 minutes?
2. The cooldown is wall-clock. Finder stays blocked after UTC midnight until `cooldownUntil`. The leave count resets at `floor(now / 86400)`. Does the cooldown survive midnight?
3. A missed rejoin is counted when `resolve` or a late `rejoin` runs, on that call's UTC day, not backdated to the deadline. A window that crosses midnight rolls today's count to 0 and keeps the deadline. Is that the day you want?
4. `depart` with `afk` or `kick` clears an open or already-expired rejoin window and does not count. Should an expired disconnect still count if the removal was an AFK removal or a passed vote-kick?
5. The Finder gate is written for `RaidService.queue`. `join` calls `queue`, so a premade listing is blocked too. `practice` does not. Should Practice Grove and the premade board stay open during the cooldown?
6. `PlayerRemoving` is `disconnect` (3-minute window), not an instant leave. There is no leave button, and that signal lives in `DungeonService`, which this row does not list. Should closing the client stay a disconnect, and is the one-line handoff from `DungeonService` into `RaidService.noteDepart` the call site you want?
7. Rejoin is on time when `now <= rejoinUntil`. Finder is free when `now >= cooldownUntil`. Both edges favor the player by that instant. Should the deadline instant count as too late instead?
8. A new Finder queue during an open window is refused with "Rejoin your raid before the timer ends." and does not count until the window actually expires. Should starting a new queue count as the leave immediately?
9. This module does not forfeit Marks or ungranted rewards. Only the T-027 AFK removal does. Should a counted leave also forfeit the run?

## Open

No unassigned tasks.

## Done

| id | title | owner | branch | files / folders | status | PR |
|---|---|---|---|---|---|---|
| T-013 | Trading, Haven Market Board, and trade audit log | HELPER | `helper/market-9721` | `src/ReplicatedStorage/Shared/Trading.luau`, `src/ReplicatedStorage/Shared/MarketBoard.luau`, `src/ServerScriptService/ShardfallServer/TradeService.luau`, `src/ServerScriptService/ShardfallServer/MarketService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MarketHud.luau`, `tests/Trading.spec.luau`, `docs/design/shardfall_economy.md` (v1.1 Market Board and Trade Audit) | done | [#16](https://github.com/Itsm00k21/Shardfall/pull/16) |
| T-014 | Pet evolution, wild shiny capture, and boss pets | HELPER | `helper/pets-9721` | `src/ReplicatedStorage/Shared/PetEvolution.luau`, `src/ReplicatedStorage/Shared/WildCapture.luau`, `src/ServerScriptService/ShardfallServer/WildCaptureService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CaptureHud.luau`, `tests/PetEvolution.spec.luau`, `docs/design/shardfall_pets.md` (v1.1 evolution, wild capture, boss pets) | done | [#17](https://github.com/Itsm00k21/Shardfall/pull/17) |
| T-018 | Wire T-013 hooks and save both profiles after a trade | GHOST | `cursor/trade-wiring-9721` | `default.project.json`, `src/ServerScriptService/ShardfallServer/RateLimiter.luau`, `src/ServerScriptService/ShardfallServer/Remotes.luau`, `src/ReplicatedStorage/Shared/Schema.luau`, `src/ServerScriptService/ShardfallServer/init.server.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`, `src/ServerScriptService/ShardfallServer/DataService.luau`, `src/ServerScriptService/ShardfallServer/TradeService.luau`, `src/ServerScriptService/ShardfallServer/MarketService.luau`, `src/ServerScriptService/ShardfallServer/TradeAudit.luau` | done | [#18](https://github.com/Itsm00k21/Shardfall/pull/18) |
| T-021 | Single HUD: menu sheet, action bar, Studio debug | GHOST | `cursor/hud-cleanup-9721` | `src/ReplicatedStorage/Shared/ShellLayout.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau`, `Ui.luau`, `ThumbBar.luau`, `DebugHud.luau`, `CombatHud.luau`, `ClassHud.luau`, `DoorHud.luau`, `InventoryHud.luau`, `TravelHud.luau`, `PetHud.luau`, `RaidHud.luau`, `RollReel.luau`, `tests/ShellLayout.spec.luau`. Stamp lines only in `Build.luau`, `init.server.luau`, and `DungeonService.luau`. Did not change combat HP. | done | [#22](https://github.com/Itsm00k21/Shardfall/pull/22) |
| T-017 | Haste shrines, mender healing, shielder blocking | HELPER | `helper/enemy-abilities-9721` | `src/ReplicatedStorage/Shared/EnemyAbilities.luau`, `tests/EnemyAbilities.spec.luau`, `tests/run.luau`, `docs/design/rootvault_design.md`. Rules are in `EnemyAbilities` and are not called yet, so gameplay is unchanged. Hook points are in the T-017 hooks section. This task does not edit `DungeonService.luau` or `Rootvault.luau`. | done | [#25](https://github.com/Itsm00k21/Shardfall/pull/25) |
| T-015 | Shard Pass premium wiring, kept off, and 4x4 board polish | HELPER | `helper/shard-pass-9721` | `src/ReplicatedStorage/Shared/Loops.luau`, `src/ServerScriptService/ShardfallServer/LoopService.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/LoopHud.luau`, `tests/Loops.spec.luau`, `docs/design/shardfall_loops.md`. `Loops.PREMIUM_ENABLED` stays `false`. No build stamp: the stamp lines live in GHOST files. Snippets are in the T-015 hooks section. Second Chance is `data.boardChance` (0 to 9, survives the weekly reset) so `data.board` stays a pure 16-boolean array. | done | [#28](https://github.com/Itsm00k21/Shardfall/pull/28) |
| T-016 | Session-recap string on the victory card | HELPER | `helper/session-recap-9721` | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/SessionRecap.luau`, `tests/Progression.spec.luau` (recap string only). `Progression.luau` was not edited. `CombatHud.luau` (T-001) was not edited. Call site for GHOST: `victoryBody`, after the voucher line, `require(script.Parent.SessionRecap)`, pass `payload.recap`. Snippet is in the T-016 hooks section. No build stamp. | done | [#30](https://github.com/Itsm00k21/Shardfall/pull/30) |
