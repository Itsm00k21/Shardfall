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
| T-036 | Wire T-035 RaidLeaver hooks into RaidService and add the four save fields | GHOST | `cursor/raid-leaver-9721` | `src/ServerScriptService/ShardfallServer/RaidService.luau`, `src/ReplicatedStorage/Shared/Schema.luau` (`raidLeaveDay`, `raidLeavesToday`, `raidFinderCooldownUntil`, `raidRejoinUntil`). Follow the T-035 hooks section. | claimed | — |
| T-038 | Wire T-037 RaidLootTrade into trading and stamp raid loot | GHOST | `cursor/raid-loot-trade-9721` | `src/ReplicatedStorage/Shared/Trading.luau` (`rejection` optional context arg plus the preview/finish/inspect callers only), the personal-loot grant in `src/ServerScriptService/ShardfallServer/RaidService.luau` (stamp `droppedAt`/`runId`/`bossId`/`droppedFor`/`roster`/`eligible`/`traded`; depends on T-009), `src/ServerScriptService/ShardfallServer/CraftService.luau` (Heartshard stamp: `crafterClears` frozen at craft from profile `raidClears`), and `src/ReplicatedStorage/Shared/Schema.luau` (`raidClears` on the next free version). Follow the T-037 hooks section. Also stamp the Gnarlling pet, Rootstrider mount, raid dyes, and the raid aura with `raidCosmetic = true` at grant. Heartwood Vendor gear is stamped bound on purchase through the existing Trading bound check (not in RaidLootTrade). Kill switches unchanged. | open | — |
| T-040 | Wire T-039 RaidMarks into raid clears and the Heartwood Vendor | GHOST | `cursor/raid-marks-9721` | `src/ReplicatedStorage/Shared/Raids.luau` (applyClear mark lines and lockout week key, buy), `src/ServerScriptService/ShardfallServer/RaidService.luau`, `src/ReplicatedStorage/Shared/Schema.luau` (new raidMarksBank field on the next free version, snapshot fields). Follow the T-039 hooks section. Replace the old applyClear mark lines (no double pay). Stop subtracting in Raids.buy when canSpend is wired (no double charge). Migrate passes raidMarkWeek = -1 once so the first settle stamps the Tuesday key and keeps raidMarksEarned. Switch the loot lockout key to RaidMarks.weekKey in the same change so loot lock and Marks share the Tuesday reset. freshCount excludes AFK-removed players. Practice Grove stays off the path. doubleMarks stays false. Do not edit `RaidMarks.luau` (HELPER owns it). | open | — |
| T-042 | Wire T-041 RaidFinder into Raid Finder queue and launch | GHOST | `cursor/raid-finder-9721` | `src/ServerScriptService/ShardfallServer/RaidService.luau` (queue: canQueue after the existing level/Story-clear/roleOk gates, in-memory roster per difficulty sorted by priority, form + launch with form.hpScale and form.bossDamageScale so the healerless 15% cut happens once and only after the 180 s wait, Warden golems on Story, Healing Spring flag, freshCount to RaidMarks firstTimers), `src/ReplicatedStorage/Shared/Raids.luau` (combatScale skips its healer-false damage cut for Finder launches), `src/ReplicatedStorage/Shared/Schema.luau` (`raidQueuePriority`, `raidQueuePriorityDay`, `raidMentor` on the next free version), RaidConduct idle-kick priority drop. Follow the T-041 hooks section. Decisions: Fresh Shard means no Heartwood clear on any difficulty; golems do not count toward HP; class stays gated by `Raids.roleOk`; level and Story-before-Normal gates stay in RaidService. Do not edit `RaidFinder.luau`. | claimed | — |
| T-044 | Wire T-043 RaidPremade board rules into the raid server | GHOST | `cursor/premade-board-9721` | `src/ServerScriptService/ShardfallServer/RaidService.luau`. Follow the T-043 hooks section. Do not edit `RaidPremade.luau`. | claimed | — |
| T-048 | Combat feel: weapon, VFX, loot, and camera | GHOST | `cursor/combat-feel-404b` | new `src/ReplicatedStorage/Shared/CombatAnims.luau`, `src/ReplicatedStorage/Shared/CombatFeel.luau` (new helpers only), `src/ReplicatedStorage/Shared/ModelFactory.luau` (dissolve fade and flinch pitch), `src/ServerScriptService/ShardfallServer/DungeonService.luau` (HP tween, flinch attribute, loot burst), new `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatStage.luau`, `CombatHud.luau` (crit number, hit-stop), `HudShell.luau` (press and cooldown), `init.client.luau` (start the stage and toast). Tests: `tests/CombatFeel.spec.luau`. Do not edit RaidFinder, RaidMarks, RaidLootTrade, RaidLeaver, or MarketBoard. Do not implement T-020, T-022, or T-026. Do not change HP clamp or hit-stop tables already pinned by the spec. | done | https://github.com/Itsm00k21/Shardfall/pull/52 |
| T-047 | Roll reveal: one roll id for the spin and the card | GHOST | `cursor/roll-reveal-404b` | new `src/ReplicatedStorage/Shared/RollReveal.luau`, `src/ServerScriptService/ShardfallServer/RollService.luau` (add `rollId` on the crack result only), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RollReel.luau` (playback only), `tests/RollReveal.spec.luau`, `tests/run.luau`. Do not edit RaidFinder, RaidMarks, RaidLootTrade, RaidLeaver, or MarketBoard. Do not implement T-020, T-022, or T-026. | done | https://github.com/Itsm00k21/Shardfall/pull/51 |
| T-046 | HUD shell, menu hub, settings, and legacy ScreenGui sweep | GHOST | `cursor/hud-shell-404b` | `src/ReplicatedStorage/Shared/LegacyChrome.luau`, `HudLayout.luau`, `Settings.luau`, `UiTheme.luau`, `ClientChrome.luau`, `Schema.luau` (version 21 `uiSettings` only), `src/ServerScriptService/ShardfallServer/Remotes.luau` (`SetSettings` only), `RateLimiter.luau` (one rule), `default.project.json` (one remote), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau`, `MenuHub.luau`, `init.client.luau` (sweep, shell, hub), `CombatHud.luau` (hide the old HP and wallet frames only). Tests: `LegacyChrome.spec.luau`, `HudLayout.spec.luau`, `Settings.spec.luau`, `UiTheme.spec.luau`, `ClientChrome.spec.luau`, `tests/run.luau`. Do not edit RaidFinder, RaidMarks, RaidLootTrade, RaidLeaver, or MarketBoard. Do not implement T-020, T-022, or T-026. Live-build took T-044 for the premade board and T-045 for raid luck, so this playtest is T-046. | done | https://github.com/Itsm00k21/Shardfall/pull/50 |
| T-051 | HUD and menu visual polish | GHOST | `cursor/hud-polish-404b` | `src/ReplicatedStorage/Shared/UiTheme.luau`, new `src/ReplicatedStorage/Shared/UiIcons.luau`, new `src/ReplicatedStorage/Shared/UiRouter.luau`, `src/ReplicatedStorage/Shared/HudLayout.luau` (card and rail rects only), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau`, `HudShell.luau`, `init.client.luau` (class prompt, stamp label, and menu routing only). Tests: `tests/UiTheme.spec.luau`, `tests/HudLayout.spec.luau`, new `tests/UiIcons.spec.luau`, new `tests/UiRouter.spec.luau`, `tests/ClientChrome.spec.luau`, `tests/run.luau`. Do not edit RaidFinder, RaidMarks, RaidLootTrade, RaidLeaver, RaidLuck, RaidRecap, or MarketBoard. Do not implement T-020, T-022, or T-026. | done | https://github.com/Itsm00k21/Shardfall/pull/54 |
| T-049 | Wire T-045 RaidLuck into the Heartwood boss clear | GHOST | `cursor/raid-luck-9721` | `src/ServerScriptService/ShardfallServer/DungeonService.luau` (Heartwood boss mutate that calls `Raids.applyClear`), `src/ReplicatedStorage/Shared/Raids.luau` (remove the `raidPity` roll so only one bonus runs; keep the Marks lines until T-040), `src/ReplicatedStorage/Shared/Schema.luau` (new `raidLuck` map, difficulty to bonus fraction, on schema version 22; `template` and migrate start everyone at `{}`, do not copy from `raidPity`), `tests/Raids.spec.luau`, `tests/Schema.spec.luau`, `tests/ProfileLoad.spec.luau`. Follow the T-045 hooks section. Decisions: the bonus stays per difficulty, not per boss and not shared across difficulties. The cap stays on the bonus (`maxBonus` 0.6) and `chance` clamps the sum to 1. A gear drop (raid gear, a Heartshard weapon, or a Relic piece) resets only that difficulty. A clear that drops only dust, marks, materials, pets, mounts, titles, dyes, cosmetics, or auras counts as dry and adds `stepPct`. Fracture tracks no bonus. `eligible = false` is the Practice Grove switch; the live path already skips `applyClear` when `run.practice ~= true`, so leave that skip and do not roll. Several gear rolls in one clear read `chance` from the same record and `settle` once. A vote-kicked or AFK-removed player gets no gear roll and `settle` is not called for them (do not follow the hook snippet that still calls `settle` for those players). A lockout skip that normalizes a stored value above the cap down to the cap is fine to persist. In reconcile, a non-table `raidLuck` becomes `{}`; leave a bad entry in place. Starts only after T-009 grants real raid gear, Heartshard weapons, and Relic pieces. Passing today's chest stand-in would fail `settle`. Until T-009 lands, `raidPity` stays live. Do not implement before then. Do not edit `RaidLuck.luau`. | claimed | — |
| T-052 | Wire T-050 RaidRecap into the raid end of run | GHOST | `cursor/raid-recap-9721` | `src/ServerScriptService/ShardfallServer/RaidService.luau` (in-memory per-player tallies on the raid run: damage, healing, deaths, soak/interrupt/stack/add counts, failures list, kudos list; call `RaidRecap.recap` once when the run ends), `src/ServerScriptService/ShardfallServer/DungeonService.luau` (feed the tallies from the Heartwood path), `src/ServerScriptService/ShardfallServer/Remotes.luau` + `default.project.json` (private panel event, party view event, GiveKudos request), `RateLimiter.luau` (one kudos rule), a new client recap panel. Follow the T-050 hooks section. Decisions: tie goes to the lower userId; MVP types stay soak, interrupt, stack, add (named mechanics like gust/spread/pool/shield are tips only); tips keep the module's order and a clean run gets no tip; 0 stats stay on the private panel; build the roster from members still in the run at the end plus AFK removals, so a vote-kicked player is off the roster and gets no panel, kudos, or MVP; kudos carry no note and no TextService; the public award has no count; one recap per run, not per wing; no `raidKudosReceived` schema field for beta; Practice Grove gets private panels and tips but no public view and no kudos button; callers pass canonical mechanic keys (no plurals); the display path keeps dropping rule-breaking stored kudos rows; tips come only from the server's failure list, never inferred from tallies. Send `panels[userId]` only to that player and `public` only when `ok == true`. Do not append to the T-016 victory card. Do not edit `RaidRecap.luau`. Queued until the Heartwood raid run has a shared roster and an end-of-run call. | queued | — |
| T-054 | Bag filters, notification badges, and the roll board | GHOST | `cursor/bag-roll-404b` | new `src/ReplicatedStorage/Shared/BagBoard.luau`, new `src/ReplicatedStorage/Shared/NotifyBadges.luau`, new `src/ReplicatedStorage/Shared/RollBoard.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau` (bag bar, badges, roll board), `HudShell.luau` (rail badges only), `init.client.luau` (badge hook only). Tests: `tests/BagBoard.spec.luau`, `tests/NotifyBadges.spec.luau`, `tests/RollBoard.spec.luau`, `tests/run.luau`. Do not edit RaidFinder, RaidMarks, RaidLootTrade, RaidLeaver, RaidLuck, RaidRecap, or MarketBoard. Do not implement T-020, T-022, or T-026. Stacks on T-051. | done | https://github.com/Itsm00k21/Shardfall/pull/56 |
| T-055 | Toasts, motion, hero viewport, and responsive layout | GHOST | `cursor/toast-hero-404b` | new `src/ReplicatedStorage/Shared/ToastQueue.luau`, new `src/ReplicatedStorage/Shared/UiSfx.luau`, new `src/ReplicatedStorage/Shared/UiMotion.luau`, new `src/ReplicatedStorage/Shared/HeroBoard.luau`, `src/ReplicatedStorage/Shared/UiTheme.luau` (`MOTION.panel` only), `src/ReplicatedStorage/Shared/HudLayout.luau` (stamp inset and breakpoints), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau` (toast stack, prompt, stamp inset), `MenuHub.luau` (motion, sfx, hero viewport and bars). Tests: `tests/ToastQueue.spec.luau`, `tests/UiSfx.spec.luau`, `tests/HeroBoard.spec.luau`, `tests/HudLayout.spec.luau`, `tests/UiTheme.spec.luau`, `tests/run.luau`. Do not edit RaidFinder, RaidMarks, RaidLootTrade, RaidLeaver, RaidLuck, RaidRecap, or MarketBoard. Do not implement T-020, T-022, or T-026. Stacks on T-054. | done | https://github.com/Itsm00k21/Shardfall/pull/57 |
| T-056 | In-panel roll loop | GHOST | `cursor/roll-loop-404b` | new `src/ReplicatedStorage/Shared/RollLoop.luau`, `src/ReplicatedStorage/Shared/Settings.luau` (`rolls.autoJunk` and `rolls.junkBelow` only), `src/ReplicatedStorage/Shared/UiSfx.luau` (click and stinger), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau` (roll tab stays open), `init.client.luau` (hub roll does not close the menu). Tests: `tests/RollLoop.spec.luau`, `tests/Settings.spec.luau`, `tests/UiSfx.spec.luau`, `tests/UiRouter.spec.luau`, `tests/run.luau`. Do not edit RaidFinder, RaidMarks, RaidLootTrade, RaidLeaver, RaidLuck, RaidRecap, or MarketBoard. Do not implement T-020, T-022, or T-026. Do not bump Schema. Stacks on T-055. | done | https://github.com/Itsm00k21/Shardfall/pull/59 |
| T-058 | Roll hotkey off the heavy attack | GHOST | `cursor/roll-key-404b` | new `src/ReplicatedStorage/Shared/Keybinds.luau`, `Settings.luau` (menu defaults and a saved Roll = R), `ClientChrome.luau` (tab letters), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau` (heavy stays R), `HudShell.luau` (skill labels and rail key), `MenuHub.luau` (tab label, sink, rebind swap or warning), `InventoryHud.luau` (drop the I toggle that fought Raids). Tests: `tests/Keybinds.spec.luau`, `tests/Settings.spec.luau`, `tests/UiRouter.spec.luau`, `tests/ClientChrome.spec.luau`, `tests/run.luau`. Do not edit RaidFinder, RaidMarks, RaidLootTrade, RaidLeaver, RaidLuck, RaidRecap, RaidLeaderboard, MarketBoard, or RaidEcho. Do not implement T-020, T-022, or T-026. Do not bump Schema. Do not edit `docs/offload/`. | done | https://github.com/Itsm00k21/Shardfall/pull/62 |
| T-059 | Wire T-057 RaidEcho into the live raid fight | GHOST | `cursor/raid-echo-wire-9721` | `src/ServerScriptService/ShardfallServer/DungeonService.luau` and/or `RaidService.luau` (wherever a whole-party death after a boss pull is detected; `DungeonService.aliveCount` counts living enemies, not players, and `RaidService` has no wipe call today), `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RaidHud.luau` (the party buff chip), and tests for the wire. Follow the T-057 hooks section. Decisions, answering the T-057 open questions: stacks are per boss, so reset on that boss's kill and on run end. A backfill who joins mid-fight inherits the party's current stacks because the buff is party-wide. While stacks are above 0 the raid HUD shows an "Echo +X%" chip. A RaidRecap line is optional, not required. Pass the unbuffed damage, healing, and max HP bases to `apply` every time so the bonus does not compound. One `wipe` per death. Practice Grove stays `practice = true` and adds nothing. Do not edit `RaidEcho.luau`. | done | https://github.com/Itsm00k21/Shardfall/pull/71 |
| T-061 | input/menu | GHOST | `cursor/audit-b-input-menu-20f9` | `src/ReplicatedStorage/Shared/Keybinds.luau` (skill 1 off Shift, tab letters stay out of the menu sink, a tab cannot stack on Q E F R Shift or a skill key), `HudLayout.luau` (sixth skill slot), `UiIcons.luau` (heavy icon), `UiRouter.luau` (Haven stall to hub tab), `RollLoop.luau` (chain gate and reveal gap), `Settings.luau` (Heavy layout slot only), `src/ServerScriptService/ShardfallServer/RollService.luau` (ignore a roll faster than the reveal cadence). Client: `HudShell.luau`, `MenuHub.luau`, `CombatHud.luau` (gamepad heavy only), `init.client.luau` (Haven prompts). Tests: `tests/Keybinds.spec.luau`, `tests/UiRouter.spec.luau`, `tests/RollLoop.spec.luau`, `tests/HudLayout.spec.luau`, `tests/UiIcons.spec.luau`. Do not edit `CombatService.luau` or `DungeonService.luau` (AUDIT-A). Do not bump Schema. Do not edit `docs/offload/`. Stamp lines in `Build.luau`, `init.server.luau`, `init.client.luau`, and the `[Rootvault] build` print in `DungeonService.luau` only (`tests/Build.spec.luau` requires that print to match). No other dungeon or combat edits. | done | https://github.com/Itsm00k21/Shardfall/pull/66 |
| T-062 | AUDIT-A (server exploits) | GHOST | `cursor/audit-a-server-exploits-d913` | Practice kill loot, the level 15 gate, and client phase/HP (`DungeonService.luau`, `RaidService.luau`, `init.server.luau` class XP hook, new `PracticeLoot.luau`). Server perfect dodge (`CombatService.luau`, `CombatFeel.luau`, `Remotes.luau`, `RateLimiter.luau`, `CombatHud.luau` dodge payload only). Salvage, remove, and feed of a market or trade hold (`Crafting.luau`, `InventoryView.luau`, `Trading.luau`, `InventoryService.luau`). Tests: `tests/AuditExploit.spec.luau`, `tests/run.luau`. Stamp lines in `Build.luau`, `init.server.luau`, `init.client.luau`, `DungeonService.luau`. Do not bump Schema. Do not edit `docs/offload/`. | done | https://github.com/Itsm00k21/Shardfall/pull/65 |
| T-064 | Practice Grove Heartwood boss kill cannot reach kill loot from `DungeonService.damageEnemy` | GHOST | `cursor/raid-echo-wire-9721` | `src/ServerScriptService/ShardfallServer/DungeonService.luau` (`damageEnemy` only if a leak remains), `tests/RaidEchoWire.spec.luau`. PR #65 gates the kill with `PracticeLoot.pays` before `PracticeLoot.applyKill`. Confirm a practice Heartwood boss kill cannot reach `Drops.apply`, `ChestConfig.enemyDrop`, or `ChestConfig.bossKill`, and lock that with a regression test. Do not edit `RaidEcho.luau`. | done | https://github.com/Itsm00k21/Shardfall/pull/71 |
| T-065 | Session lock before raid teleport | GHOST | `cursor/session-lock-teleport-9721` | `src/ServerScriptService/ShardfallServer/DataService.luau` (`release`, `BindToClose`, save and clear the lock before teleport), `src/ServerScriptService/ShardfallServer/RaidService.luau` (`queue` teleport only), `src/ReplicatedStorage/Shared/ProfileLoad.luau`, `tests/SessionHandoff.spec.luau`, `tests/run.luau`. Do not edit `DungeonService.luau`, `RaidHud.luau`, `RaidEcho.luau`, or `Build.luau`. Do not bump Schema. Leave the 60 second autosave and `SessionLock.TIMEOUT_SECONDS` (20 min) unchanged. | done | https://github.com/Itsm00k21/Shardfall/pull/70 |
| T-067 | Raid teleport follow-ups | GHOST | `cursor/raid-teleport-followups-9721` | (a) after TeleportAsync returns, listen for TeleportService.TeleportInitFailed for that player; if the hop fails, reclaim the lock with ProfileLoad.reclaim and restore a loaded record (or kick with a rejoin message if reclaim reports stolen), so the player isn't stuck on this server with a released record where every mutate fails; (b) verify whether RaidService.receive -> queue can reserve and hop again from inside a reserved raid server (a possible repeat-hop loop outside Studio); if so, make receive launch locally on a reserved server; (c) a second queue call while the record is `closing` currently returns the 'could not save your profile' message; return a neutral 'teleport already in progress' message instead. Files: DataService.luau, RaidService.luau, ProfileLoad.luau, tests. Do not bump Schema. | done | https://github.com/Itsm00k21/Shardfall/pull/77 |
| T-068 | Story Echo party follow-ups | GHOST | `cursor/story-echo-followups-9721` | (1) `DungeonService.backfill` has no caller, so Echo stacks aren't shared across the party. (2) In a shared fight, one player going down ejects them, so only the last survivor gets the wipe retry. (3) The Echo max-HP bonus is calculated, but CombatService max HP and the HP bar don't apply it. (4) RaidService still passes the stale `profile.raidEcho` value. (5) Replace the `CombatService.healAmount` monkeypatch with a direct hook. | open | — |
| T-069 | Wire RollHype into the Roll screen | GHOST | `cursor/roll-hype-wire-9721` | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau` (Roll tab: `beginRoll`, `paintRoll`, milestone toast, personal-best flash) and the Roll route in `src/ReplicatedStorage/Shared/UiRouter.luau`. Call `RollHype.note`, `RollHype.pity`, and `RollHype.tempo` from that screen. Store `state` only when `ok == true`. One legendary pity bar, driven by the server's real post-roll counter: verify `RollMath.rollsSinceLegendary` and the pool's `pityLegendaryAt` against profile `sinceLegendary` and `RarityConfig.LEGENDARY_PITY`, and use whichever counter the server actually uses for the guarantee. Show the counter after the roll so a Legendary visibly resets the bar. `totalRolls` is not pity. One `pity` call for that one bar. Full-animation build-up only (`RollHype.tempo` when the animation is full and reduced motion is off). `RollLoop.seconds` and `RollReveal.duration` stay for short, instant, skip, and reduced motion. Milestone toasts use `callout` at 10, 25, 50, and 100 and stay rarity-free. Personal-best flash only when `newPersonalBest == true`, using `noted.rarity`. A miss does not show `state.best`. A bad rarity shows nothing. A Prism crack counts as a real roll. Streak stays consecutive landed rolls. The session stays in client memory. Goal: a compelling slot-machine feel with honest odds. Do not edit `RollHype.luau`, `RollLoop.luau`, `RollReveal.luau`, `RollMath.luau`, `RollBoard.luau`, `PaidRollPolicy.luau`, or Schema. No near-miss. | done | [#79](https://github.com/Itsm00k21/Shardfall/pull/79) |
| T-072 | Roll chain ignores combat down | GHOST | `cursor/roll-chain-death-9721` | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau` (`bindLife` / `playerAlive` only). The chain treats `Humanoid.Died` and `Health <= 0` as death. `CombatService.syncBody` pins `Humanoid.Health` to `MaxHealth`, so a dungeon down never fires `Died` and auto-roll keeps sending `RollShard` through a wipe and a defeat card. A humanoid first seen at 0 Health, or a late `Died` from the previous character, latches `playerAlive` false for the new life. Drive the flag from combat HP (`ShardfallHp`, or a defeat / down `CombatFx`) and ignore a `Died` whose character is no longer `LocalPlayer.Character`. Do not unpin Health. Do not edit `RollLoop.canChain`. Do not bump Schema. From the 2026-10-17 sweep at `163b9901`. Source assertion only in `tests/RollLoop.spec.luau`. | done | https://github.com/Itsm00k21/Shardfall/pull/81 |
| T-073 | Story wipe retry can add another Echo stack during the stream yield | GHOST | `cursor/echo-retry-yield-9721` | `src/ServerScriptService/ShardfallServer/DungeonService.luau` (`retryPull` and `onPlayerDown` only) and a regression test. `retryPull` revives and `PivotTo`s, then yields in `RequestStreamAroundAsync` before `spawnRoom` clears the boss and `CombatService.clearShots`. The boss is still alive in range of the room spawn. `onPlayerDown` has no re-entry guard, and `setAlive(true)` has cleared the wipe latch, so a hit during the yield calls `RaidEcho.wipe` again and starts a nested retry. Clear shots and despawn the old room before any yield. Hold a retry guard so `onPlayerDown` in that window does not wipe or retry. One stack per down. Do not edit `RaidEcho.luau`. Do not bump Schema. From the 2026-10-17 sweep at `163b9901`. | done | https://github.com/Itsm00k21/Shardfall/pull/82 |
| T-076 | Dungeon Heartbeat per-player isolation | GHOST | `cursor/echo-retry-yield-9721` | `src/ServerScriptService/ShardfallServer/DungeonService.luau` (`onHeartbeat` only) and a regression test. The heartbeat walks every run, then the restart queue, then Haven falls, in one function with no per-player `pcall`. One player's tick error aborts the rest of that frame, including other runs and the hub rescue. Isolate each player so one failure cannot skip the others. P1. From Grok's second opinion (2026-10-16 23:09). The parallel agent on this branch owns the edit. Do not edit `RaidEcho.luau`. Do not bump Schema. | done | https://github.com/Itsm00k21/Shardfall/pull/82 |
| T-077 | Ignore a profile load that finishes after the budget | GHOST | — | `src/ServerScriptService/ShardfallServer/DataService.luau` (`load`) and `src/ReplicatedStorage/Shared/ProfileLoad.luau`. `CallBudget.run` returns at the timeout, but the spawned `UpdateAsync` keeps running. A late transform can still claim the lock and run `Progression.applyReturn` / `lastSeen` after that attempt was abandoned. Ignore late transforms with a per-attempt generation token. P1. Do not bump Schema. | open | — |
| T-078 | Equip prompt only dequeues, and prompts have no cap | GHOST | — | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau` (`prompt`) and `src/ReplicatedStorage/Shared/ToastQueue.luau` (`pushPrompt`). Equip and Keep both call `ToastQueue.answer` and never an `onYes` or `onNo`. `pushPrompt` appends with no cap (`pushToast` stops at `ToastQueue.MAX`). P2. | open | — |
| T-079 | Client remote waits have no timeout | GHOST | — | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau` (`invoke`) and `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau` (`start`). `invoke` calls `WaitForChild(name)` with no timeout, and `CombatHud.start` waits on Attack, Dodge, and CombatFx the same way. A missing remote stalls the client script. P2. | open | — |
| T-080 | Menu hotkeys match only a single letter | GHOST | `cursor/roll-chain-death-9721` | `src/ReplicatedStorage/Shared/UiRouter.luau` (`hotkey` only) and `tests/UiRouter.spec.luau`. `string.sub(keyName, 1, 1)` of `KeyCode.Name` treats `Two` as T (Roll), `Tab` as T, `Space` as S, `LeftShift` as L, `Backspace` as B, `Comma` as C, `Period` as P, `Minus` as M, and `Insert` as I. Match only a single-letter key name (KeyCode A-Z) against the bound hotkeys. P1. From Grok's second opinion (2026-10-16 23:09). Filed as T-080 because T-075 is already HELPER's Contest Weekend on the tip. Do not bump Schema. | done | https://github.com/Itsm00k21/Shardfall/pull/81 |
| T-082 | Wire T-075 RaidContest into RaidService | GHOST | `cursor/raid-contest-wire-9721` | `src/ServerScriptService/ShardfallServer/RaidService.luau` (`openContest`, `contestGear`, `contestClear`) and `src/ReplicatedStorage/Shared/Raids.luau` (add `id = "heartwood"` to the Heartwood entry). Follow the T-075 hooks section. Do not edit `RaidContest.luau`. RaidService owns `openContest`, `contestGear`, and `contestClear`. The canonical raid id is lowercase `"heartwood"`. Pass that string. The contest record is one server-wide record per raid, in a DataStore key (for example `contest/heartwood`), written with `UpdateAsync` so two servers cannot both take the statue. Never copy it onto player profiles. Save whenever `result.persist == true`. Never replace the live record when `persist == false`. Grant the emblem and send the announcement from the result, not the sticky state. The announcement send must be idempotent per `raidId`. The run id is a server-generated `HttpService:GenerateGUID(false)` string. Party size is enforced at entry by RaidService (Shardbreaker is premade-only), not by the module. Guided Shardbreaker still calls `contestGear` before entry. Call `contestClear` only after a real clear. The emblem render flag on the profile comes later with a GHOST-owned schema bump. Schema stays 21 for now. Nothing costs Robux. `RaidMarks.CONFIG.doubleMarks` stays false. Blocked until gear has a whole-number item level. | queued | — |
| T-084 | Wire T-081 RaidLockout into the boss clear | GHOST | `cursor/raid-lockout-wire-9721` | `src/ServerScriptService/ShardfallServer/RaidService.luau` (`claimLoot`, `lootLock`), the Heartwood boss-death mutate in `src/ServerScriptService/ShardfallServer/DungeonService.luau` (the `PracticeLoot.applyKill` block only), and `src/ReplicatedStorage/Shared/Schema.luau` (`raidLootLock` on the next free schema version). Follow the T-081 hooks section. Do not edit `RaidLockout.luau`. Do not reuse `raidLock` and do not copy Thursday `raidLock` rows into `raidLootLock`. Nil means no locks. Save only when `persist == true`. A state error returns empty `weeks` with `persist == false`. Never write that blank over the profile. Mint the claim id on the server with `HttpService:GenerateGUID(false)` once per boss death. Do not take it from the client. Pass `practice == true` for Practice Grove so it neither locks nor loots. Pass a server-chosen fracture id so Fracture does not lock. Do not call `claim` for an AFK removal. Story, Normal, Hard, and Shardbreaker lock separately. A reclear pays Marks, Dust, and materials only. Call `RaidLuck` only when `lootEligible == true`. Call `view` on profile load so old weeks prune. Do not also write the Thursday lock in `Raids.applyClear` for the same clear. Coordinate with T-040 so Marks and loot share the Tuesday key without two lock tables. No paid skip. Schema stays 21 until this row runs. Queued. Nothing costs Robux. | queued | — |

T-010 is the rest of the cut line "Raid Hard, the Vault, and Relic Sets." Raid Hard itself is T-007. Relic Set rules come from T-025. T-010 keeps the Vault wiring. The rules are HELPER's T-070 `RaidVault.luau`, and T-010 does not edit that module. Heartwood Vendor sells weaker helper items for Raid Marks or materials, never Relic Set pieces. Ghost wires that vendor later, under T-010. Wiring must surface a clear claim reminder before an unpicked Vault expires. Do not auto-grant. Revisit that reminder after playtest.

Next free id is T-085. T-081 landed in #86 (`532c802`). T-083 is Echo's Strategy Board marker rules on `helper/raid-strategy-9721`. T-084 is queued for GHOST to wire `raidLootLock`. T-082 stays queued until gear has an item level. T-075 landed in #84 (`cab172d`). T-072 and T-080 landed in #81 (`eae33b1`). T-073 and T-076 landed in #82. T-077, T-078, and T-079 are open. T-068 Story Echo party follow-ups stays open.

## Claimed by HELPER

HELPER takes self-contained systems. New modules listed below are the owned paths. Do not edit a GHOST path. If a hook has to land in a shared module or in `CombatHud.luau` / `DungeonService.luau` / `Rootvault.luau`, write that on the row in this file first and wait for GHOST.

| id | title | owner | branch | files / folders | status | PR |
|---|---|---|---|---|---|---|
| T-025 | Verdant Relic Set rules module (pure, no wiring) | HELPER | `helper/relic-sets-9721` | new `src/ReplicatedStorage/Shared/RelicSets.luau`, new `tests/RelicSets.spec.luau`, one require line in `tests/run.luau`, new `docs/design/relic_sets.md` | done | [#37](https://github.com/Itsm00k21/Shardfall/pull/37) |
| T-027 | Raid conduct rules: AFK detection and vote-kick | HELPER | `helper/raid-conduct-9721` | new `src/ReplicatedStorage/Shared/RaidConduct.luau`, new `tests/RaidConduct.spec.luau`, `tests/run.luau` (one require line). Pure, server-authoritative rules from `docs/design/shardfall_raids.md`: AFK warning at 60 s with no input outside cutscenes, auto-remove at 90 s (rewards forfeited, backfill flagged); vote-kick needs 3/4 of the group plus a reason, is unavailable in the first 2 minutes and during combat, 1 kick per player per day, idle kicks drop queue priority, players kicked unfairly still keep their Marks, and kicking is disabled in Guided Raids. Do not edit `Raids.luau`, `RaidService.luau`, or T-012. Write a 'T-027 hooks for GHOST' section (RaidService call sites, and a suggested schema field for the daily kick count, since HELPER does not edit Schema). | done | [#44](https://github.com/Itsm00k21/Shardfall/pull/44) |
| T-031 | Relic tradeability follow-up | HELPER | `helper/relic-trade-9721` | `src/ReplicatedStorage/Shared/RelicSets.luau` (`stamp` and `isRelic` only), `tests/RelicSets.spec.luau`, `docs/design/relic_sets.md`, and the trade snippet in the T-025 hooks section of this file. Per Kevin, pieces are raid-drop only and tradeable on the Market Board. They are not bound. `stamp` sets `bound = false` and `tradeable = true`. `isRelic` still matches a piece id, a set id, or an item whose `templateId`, `id`, `pieceId`, or `setId` names one, and it must not treat `bound` as the relic test. The T-025 hooks trade snippet has no `Trading.rejection` block for relics (no `"Relic Set pieces are bound."` return). Keep it that way. Do not edit `Trading.luau`, `Raids.luau`, `RaidService.luau`, or T-012. | done | [#41](https://github.com/Itsm00k21/Shardfall/pull/41) |
| T-034 | Relic catalog rows unbound | HELPER | `helper/relic-trade-fix-9721` | `src/ReplicatedStorage/Shared/RelicSets.luau` (`makePiece` only), `tests/RelicSets.spec.luau`, and any matching note in `docs/design/relic_sets.md`. Flip catalog `makePiece` to `bound = false` / `tradeable = true`. Assert every catalog piece is unbound and tradeable. Do not edit `Trading.luau`, `Raids.luau`, `RaidService.luau`, or T-012. | done | [#43](https://github.com/Itsm00k21/Shardfall/pull/43) |
| T-035 | Raid leaver penalty rules | HELPER | `helper/raid-leaver-9721` | new `src/ReplicatedStorage/Shared/RaidLeaver.luau`, new `tests/RaidLeaver.spec.luau`, one require line in `tests/run.luau`, and a 'T-035 hooks for GHOST' section in this file. Pure, server-authoritative rules from `docs/design/shardfall_raids.md`: 3 leaves in one UTC day puts the player on a 15-minute Raid Finder cooldown; a disconnect opens a 3-minute rejoin window, rejoining inside it is not a leave and missing it counts as one; an AFK removal or a passed vote-kick (T-027 RaidConduct) is not a voluntary leave. Thresholds in a frozen CONFIG, time passed in as unix seconds (`os.time()`), no services, remotes, or DataStores. Do not edit `Raids.luau`, `RaidService.luau`, Schema, or T-012; suggest profile fields (leave day/count, cooldown-until) in the hooks section. No build stamp, nothing premium. Rules live in `RaidLeaver` and nothing calls them yet, so gameplay is unchanged. | done | [#45](https://github.com/Itsm00k21/Shardfall/pull/45) |
| T-037 | Raid personal loot trade rules | HELPER | `helper/raid-loot-trade-9721` | Pure rules. Raid gear stays soulbound for 2 hours and can only go to eligible players from the same run. Crafted Heartshard weapons become tradeable after the crafter's first clear. Raid cosmetics stay bound. Relic set pieces are exempt and stay freely tradeable. Do not edit raid code, Schema, or remotes. | done | [#46](https://github.com/Itsm00k21/Shardfall/pull/46) |
| T-039 | Raid Marks rules (pure, no wiring) | HELPER | `helper/raid-marks-9721` | new `src/ReplicatedStorage/Shared/RaidMarks.luau`, new `tests/RaidMarks.spec.luau`, one require line in `tests/run.luau`, and a 'T-039 hooks for GHOST' section in this file. Pure rules from `docs/design/shardfall_raids.md`: Raid Marks are capped at 600 per week; the weekly reset is Tuesday at a fixed UTC time (give a pure week-key function taking unix seconds); an unused cap carries over and accumulates up to 3 weeks; reclears after lockout still pay Marks; each first-timer in the group adds +10% Marks for the group; a player kicked unfairly (a T-027 passed vote-kick that was not AFK) still gets their Marks, while an AFK removal forfeits; a double-Marks event multiplier exists but defaults OFF in a frozen CONFIG. Provide `earn(amount, state, now)` and `canSpend(cost, state)` style pure functions that return new values and never mutate. Payout amounts per difficulty are placeholders in CONFIG. Thresholds live in a frozen CONFIG, unix seconds come in (`os.time()`), and there are no services, remotes, or DataStores. Do not edit `Raids.luau`, `RaidService.luau`, Schema, Trading, MarketBoard, the Heartwood Vendor catalog (T-010 owns it), or T-012 files. Suggest profile fields (marks balance, week key, earned this week, banked cap) in the hooks section. No build stamp, nothing premium, no Robux price. Rules live in `RaidMarks` and nothing calls them yet, so gameplay is unchanged. | done | [#47](https://github.com/Itsm00k21/Shardfall/pull/47) |
| T-041 | Raid Finder role check and group-forming rules (pure, no wiring) | HELPER | `helper/raid-finder-9721` | new `src/ReplicatedStorage/Shared/RaidFinder.luau`, new `tests/RaidFinder.spec.luau`, one require line in `tests/run.luau`, and a 'T-041 hooks for GHOST' section in this file. Pure, server-authoritative rules from `docs/design/shardfall_raids.md` Matchmaking: Finder covers Story and Normal only (Hard/Shardbreaker refused; Guided Raids come later); role check with Tank, Healer, DPS, Flex where Flex fills any missing role; party size 4 to 8 with a boss HP scale for the player count; if no healer is found within 3 minutes (180 s, unix seconds passed in) the group may start with auto-scaling (-15% boss damage and a free Healing Spring totem flag); a missing Tank gets a Warden NPC golem on Story only; Fresh Shard flag for first-timers and a fresh count for RaidMarks; mentor eligibility (10+ clears and opted in); an idle vote-kick (T-027) drops queue priority; no gear-score or clear-count filter for Story/Normal; a player on a RaidLeaver (T-035) cooldown can't queue (take the cooldown-until value as input, do not require RaidLeaver). Role targets per party size and all thresholds are placeholders in a frozen CONFIG. No MemoryStore, services, remotes, or DataStores. Do not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, Schema, Trading, MarketBoard, or any T-012 file. Suggest profile fields (queue priority, mentor opt-in) in the hooks section. No build stamp, nothing premium. | done | [#48](https://github.com/Itsm00k21/Shardfall/pull/48) |
| T-043 | Premade board listing rules (pure, no wiring) + RaidFinder 8-player tank target | HELPER | `helper/premade-board-9721` | new `src/ReplicatedStorage/Shared/RaidPremade.luau`, new `tests/RaidPremade.spec.luau`, one require line in `tests/run.luau`, a 'T-043 hooks for GHOST' section in this file, plus a one-line CONFIG change in `src/ReplicatedStorage/Shared/RaidFinder.luau` and its spec. Pure, server-authoritative rules from `docs/design/shardfall_raids.md` Matchmaking "Premade board in the Guild Plaza (Party Finder style)": a listing has a difficulty (Story, Normal, Hard, Shardbreaker; Guided mode is out of scope), one or more tags from Learning, Farm, Speedrun, Achievement, an optional required clear count (non-negative integer), a party size of 4 to 8, and role slots using RaidFinder's role names (tank, healer, dps, flex). No gear-score requirement or filter is allowed on Story or Normal (refuse one). Provide pure functions to validate a listing, check whether a player may join (open slot for their role, flex takes any open slot, meets the required clear count), and report when a listing is full or expired. One active listing per host; the listing closes when the host leaves; listings expire after a placeholder time in a frozen CONFIG. The premade board ignores the RaidLeaver Finder cooldown (T-035 decision: Finder only). Listing title text is filtered by the caller with TextService, not in this module. Time comes in as unix seconds (`os.time()`). No MemoryStore, services, remotes, or DataStores. Do not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, Schema, Trading, MarketBoard, or any T-012 file. RaidFinder change: set `roleTargets[8]` to 1 tank, 1 healer, 6 DPS (the design's 1–2 Wardens means the minimum is 1) and update the spec. No build stamp, nothing premium. | done | [#49](https://github.com/Itsm00k21/Shardfall/pull/49) |
| T-045 | Raid bad-luck protection rules | HELPER | `helper/raid-luck-9721` | new `src/ReplicatedStorage/Shared/RaidLuck.luau`, new `tests/RaidLuck.spec.luau`, one require line in `tests/run.luau`, and a 'T-045 hooks for GHOST' section in this file. Pure rules from `docs/design/shardfall_raids.md`: each lockout clear with no gear drop adds +10% to the next drop chance, and the bonus resets when something drops. Do not edit raid code, Schema, or remotes. | done | [#53](https://github.com/Itsm00k21/Shardfall/pull/53) |
| T-050 | Raid post-run recap rules (pure, no wiring) | HELPER | `helper/raid-recap-9721` | new `src/ReplicatedStorage/Shared/RaidRecap.luau`, new `tests/RaidRecap.spec.luau`, one require line in `tests/run.luau`, and a 'T-050 hooks for GHOST' section in this file. Pure rules from `docs/design/shardfall_raids.md` Anti-toxicity and fairness: each player gets a private panel built from caller-supplied per-player stats (damage, healing, deaths, mechanics handled by type such as soaks, interrupts, stacks, add kills, for example "You soaked 6 times") plus 1 to 2 tips picked from that player's mechanic failures using a placeholder tip table keyed by boss and mechanic in a frozen CONFIG. The public view shows only party kudos and mechanic MVP awards and never a damage or healing ranking or anyone else's numbers. Each player may give one kudos per run to another party member (not themselves, only members of that run). One MVP per mechanic type goes to the player who handled the most, with a deterministic tiebreak and no award when nobody handled any. An AFK-removed player (T-027 RaidConduct) gets their own private panel but is excluded from kudos and MVP. Inputs are plain tables. No services, remotes, DataStores, or TextService. Do not edit `DungeonService.luau`, `RaidService.luau`, `Raids.luau`, Schema, `CombatHud.luau`, the existing T-016 dungeon recap code, or any T-012 file. No build stamp, nothing premium. | done | [#55](https://github.com/Itsm00k21/Shardfall/pull/55) |
| T-053 | Raid leaderboard rules: fastest clear (pure, no wiring) | HELPER | `helper/raid-leaderboard-9721` | new `src/ReplicatedStorage/Shared/RaidLeaderboard.luau`, new `tests/RaidLeaderboard.spec.luau`, one require line in `tests/run.luau`, and a 'T-053 hooks for GHOST' section in this file. Pure rules for the beta 'basic leaderboard (fastest Normal clear)' in `docs/design/shardfall_raids.md` (Firsts and races, Scope). Boards are keyed by difficulty and party size; a frozen CONFIG lists which boards are live (beta: normal only, story off), a top-N size, and a sanity floor on clear time. `submit(board, record)` takes a plain clear record (runId, difficulty, size, start and end times or duration, roster userIds, practice flag, removals) and returns a new board without writing the input: reject practice runs, unknown or disabled difficulties, bad times, and clears under the floor; credit only roster members who were not AFK-removed or vote-kicked; the same runId twice is a no-op; sort by duration with a deterministic tiebreak (earlier clear, then lower runId) and trim to top N. Also `personalBest(board, userId)` and a `rankOf` helper. Inputs are plain tables. No OrderedDataStore, MemoryStore, remotes, Schema, or TextService. Do not edit `RaidService.luau`, `DungeonService.luau`, `Raids.luau`, Schema, or any T-012 file. No build stamp, nothing premium. | done | [#58](https://github.com/Itsm00k21/Shardfall/pull/58) |
| T-057 | Raid Story Echo buff rules (pure, no wiring) | HELPER | `helper/raid-echo-9721` | new `src/ReplicatedStorage/Shared/RaidEcho.luau`, new `tests/RaidEcho.spec.luau`, one require line in `tests/run.luau`, and a 'T-057 hooks for GHOST' section in this file. Pure, server-authoritative rules for the Story-tier Echo buff in `docs/design/shardfall_raids.md` (Difficulty ladder: 'An Echo buff (+5% per wipe, max +25%) stacks after wipes'). Frozen CONFIG: 5% per wipe, cap 25%, Story only (Normal live but never gets Echo; Hard/Shardbreaker/Fracture never). A wipe is a whole-party death after a boss pull started; partial deaths, Practice Grove pulls, and resets before the pull do not count. Expose: a fresh per-run state, `wipe(state, ctx)` returning a new state (no input writes), `bonus(state, difficulty)` as a fraction 0 to 0.25, `apply(stat, state, difficulty)` for player damage, healing, and max HP multipliers, and a reset on boss kill or run end. The buff is party-wide and shown to the party, not per player. Time and difficulty are passed in. No services, remotes, DataStores, RNG, or build stamp. Do not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `CombatMath.luau`, or T-012. Nothing requires it until GHOST wires it, so gameplay is unchanged. Open questions (per-boss vs whole-run stacking, whether a backfill inherits the stacks, whether it shows on the RaidRecap panel) go in the hooks section. | done | [#61](https://github.com/Itsm00k21/Shardfall/pull/61) (f1f79e41bff4b8b5b86756cd1e5eeb85390959f7) |
| T-060 | Practice Grove rules (pure, no wiring) | HELPER | `helper/raid-practice-9721` | new `src/ReplicatedStorage/Shared/RaidPractice.luau`, new `tests/RaidPractice.spec.luau`, one require line in `tests/run.luau`, and a 'T-060 hooks for GHOST' section in this file. Pure, server-authoritative rules for Practice Grove in `docs/design/shardfall_raids.md` (Guild raid prep, and the beta Scope line): a free, lootless sandbox for each unlocked boss, with practice dummies, a jump to any phase, time slowed to 0.75x, individual mechanics turned on or off, and a record of damage, deaths, and mechanic hits. Frozen CONFIG: `slowScale` 0.75, `phases` 3, `shardbreakerPhases` 4 (every boss has 3 phases, 4 on Shardbreaker). Boss ids are `twins`, `sapwell`, `galecrown`, and `awakened`. Difficulties are story, normal, hard, and shardbreaker. Fracture and guided are not difficulties in this module. Cost is 0. `rewards` is always empty: no gear, Marks, dust, materials, pets, titles, or cosmetics. API, each call returns a new table and does not write the input: `fresh(ctx)` starts `{ bossId, difficulty, phase = 1, slow = false, dummies = true, mechanics = {}, damage = 0, deaths = 0, hits = {} }` and requires `ctx.unlocked == true` (unknown boss or difficulty is an error); `jump(state, phase)` moves to an integer phase from 1 through 3, or 1 through 4 on shardbreaker; `setSlow(state, on)` selects 0.75 when on and 1 when off, and no other scale exists; `scale(state)` returns that number; `toggle(state, mechanicId, enabled)` stores an override for a non-empty mechanic id, with a missing id meaning the mechanic is on (there is no frozen mechanic catalog; T-007 owns Hard mechanic design); `note(state, event)` adds a non-negative finite `damage` amount, adds 1 `death`, or increments `hits[mechanicId]`; `rewards(state)` stays empty even after notes. Store `state` only when `ok == true`. A failure returns a copy and the caller keeps the previous save. Phase jump and slow do not reset the record. Dummies are a flag, default true, and are not a second boss. A practice session is not a clear, a lockout, a Marks payout, or a leaderboard row. Do not require `Raids`, `RaidService`, `DungeonService`, `RaidEcho`, `RaidMarks`, `RaidLuck`, `RaidLeaderboard`, or `RaidRecap`. `RaidService.practice` already launches a lootless Story run. Do not edit that function. Nothing in `src` requires this module, so the live launch stays as it is. No services, remotes, DataStores, MemoryStore, RNG, clock, or build stamp. Do not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `CombatMath.luau`, `RaidEcho.luau`, `Remotes.luau`, any T-012 file, or `docs/offload/`. Open questions go in the hooks section: the guild perk "cheaper Practice Grove" has no price and the sandbox stays free, whether live practice stays Story-only while this module accepts Normal, Hard, and Shardbreaker, whether mechanic ids stay caller-supplied, whether 0.75x should scale an enrage timer (no enrage number lives here), and whether the record stays on the in-memory session. | done | [#67](https://github.com/Itsm00k21/Shardfall/pull/67) |
| T-063 | Practice Grove input guard (pure, no wiring) | HELPER | `helper/raid-practice-guard-9721` | new `src/ReplicatedStorage/Shared/RaidPracticeGuard.luau`, new `tests/RaidPracticeGuard.spec.luau`, one require line in `tests/run.luau`, and a 'T-063 hooks for GHOST' section in this file. Pure, server-authoritative validation of raw remote-style args before the server calls RaidPractice. Never throws on nil, NaN, huge strings, tables, or wrong types. Returns `ok, value, err`. A wing number maps through `Raids.WINGS` (1 twins, 2 sapwell, 3 galecrown, 4 awakened) and an unknown wing is refused. Difficulty and phase match RaidPractice: story, normal, hard, and shardbreaker only; phase 1 through 3, or 1 through 4 only on shardbreaker. Mechanic ids must be on a caller-supplied allowlist, because `Raids.luau` has no frozen per-boss mechanic list. A frozen CONFIG caps distinct mechanic ids on one session and caps damage on one call (finite and at least 0). A hit for a mechanic that is toggled off is refused. No services, remotes, DataStores, MemoryStore, RNG, or clock. Nothing in `src` requires this module. Do not edit `Raids.luau`, `RaidPractice.luau`, `RaidService.luau`, `DungeonService.luau`, `PracticeLoot.luau`, Schema, remotes, or any T-012 file. No build stamp. Nothing costs Robux. Open questions go in the hooks section. | done | [#68](https://github.com/Itsm00k21/Shardfall/pull/68) |
| T-066 | RollHype rules (pure, no wiring) | HELPER | `helper/roll-hype-9721` | new `src/ReplicatedStorage/Shared/RollHype.luau`, new `tests/RollHype.spec.luau`, one require line in `tests/run.luau`, and a 'T-066 hooks for GHOST' section in this file. Pure display rules for the Roll screen. A session tracks the roll count, the current streak, the best rarity this session, and an all-time personal-best flag. Milestone callouts fire at 10, 25, 50, and 100 landed rolls. The pity meter is a fill from 0 to 1 taken from a caller-supplied counter and goal, because `RollMath` has no 0-1 fill. Reveal tempo is a tier per rarity, with a longer build-up for a higher rarity. Honesty: never surface a rarity that was not rolled, no fake near-miss, the pity meter shows only real progress, and a paid roll uses the same display rules as a free roll. Each call returns a new table and does not write the input. No clock. No RNG. No services, remotes, or DataStores. Do not edit `RollLoop`, `RollReveal`, `RollMath`, `RollBoard`, `PaidRollPolicy`, Schema, Remotes, or any T-012 file. No build stamp. Nothing costs Robux. Nothing in `src` requires this module. Open questions go in the hooks section. | done | [#72](https://github.com/Itsm00k21/Shardfall/pull/72) |
| T-070 | Weekly Vault rules (pure, no wiring) | HELPER | `helper/raid-vault-rules-9721` | new `src/ReplicatedStorage/Shared/RaidVault.luau`, new `tests/RaidVault.spec.luau`, one require line in `tests/run.luau`, and a 'T-070 hooks for GHOST' section in this file. Pure rules for the weekly Vault in `docs/design/shardfall_raids.md` (Loot and the chase, and the Tuesday reset): killing 2, 4, or 6 distinct (boss, difficulty) pairs opens 1, 2, or 3 choices, at the difficulty of the 2nd, 4th, or 6th highest pair, and the player picks 1 when the week resets. The same pair counts once. The first offer locks. An item whose difficulty does not match its slot is refused. Frozen CONFIG holds the thresholds, the choice counts, and the difficulty rank. The week key is Tuesday 00:00 UTC, the same shape as `RaidMarks.weekKey`, and this module does not require `RaidMarks`. Each call returns a new table and does not write the input. No RNG: the caller supplies the choice items. No services, remotes, DataStores, MemoryStore, or clock. Unix seconds come in. Do not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `RelicSets.luau`, `RaidMarks.luau`, `RaidLuck.luau`, Schema, remotes, or any T-012 file. T-010 wires the Vault later and does not edit this module. No build stamp. Nothing costs Robux. Nothing in `src` requires this module. Decisions are in the hooks section. | done | [#74](https://github.com/Itsm00k21/Shardfall/pull/74) |
| T-071 | Resonant Heartshard pattern rules (pure, no wiring) | HELPER | `helper/raid-resonant-9721` | new `src/ReplicatedStorage/Shared/RaidResonant.luau`, new `tests/RaidResonant.spec.luau`, one require line in `tests/run.luau`, and a 'T-071 hooks for GHOST' section in this file. Pure rules from `docs/design/shardfall_raids.md` (Heartshard weapons): a Resonant drop (red border) counts toward that weapon. Three Resonant drops of the same weapon unlock its Forge pattern. Frozen CONFIG holds the threshold 3. A drop is `{ weaponId, resonant, practice, uid }`. `weaponId` is a trimmed non-empty string; do not hardcode the content catalog and do not require `docs/content/`. The same `uid` does not count twice. A missing `uid` is refused so a retry cannot double-count. `resonant ~= true` does not count. Practice Grove does not count. The count sticks at 3. Unlock stays set. Each call returns a new table and does not write the input. No craft, no Marks spend, no materials, no RNG, no clock, no services, remotes, DataStores, or MemoryStore. Nothing costs Robux. No paid skip of the three drops. Do not edit `Crafting.luau`, `Recipes.luau`, `Raids.luau`, `RaidService.luau`, `RaidLootTrade.luau`, Schema, remotes, or any T-012 file. Suggest profile fields in the hooks section for the next free schema version at wiring time. No build stamp. Nothing in `src` requires this module. Open questions go in the hooks section. | done | [#78](https://github.com/Itsm00k21/Shardfall/pull/78) |
| T-074 | Guided Raid oath and guide-score rules (pure, no wiring) | HELPER | `helper/raid-guided-9721` | new `src/ReplicatedStorage/Shared/RaidGuided.luau`, new `tests/RaidGuided.spec.luau`, one require line in `tests/run.luau`, and a 'T-074 hooks for GHOST' section in this file. Pure rules from `docs/design/shardfall_raids.md` (Guided Raids, and guild perks): Guided is a mode on Hard and Shardbreaker, not its own difficulty. Story, Normal, Fracture, and Practice are refused. Party size stays 4 to 8. A guild hosts, and at least half the roster shares that host guild (half the run, not half of the whole guild). Solo Seekers fill the rest, one player per join. Everyone accepts the Oath of the Grove before a finish counts. Accept is one boolean, not free text. A finish awards the host guild `CONFIG.guideScore` (placeholder 1) and Guided points scale by `CONFIG.guidedPointScale` (2) toward guild raid XP. This does not multiply Raid Marks. `RaidMarks.CONFIG.doubleMarks` stays false. Kicking is refused for the whole run. AFK removal stays in `RaidConduct` and is not a kick. Each call returns a new table and does not write the input. No services, remotes, DataStores, MemoryStore, RNG, or clock. No build stamp. Nothing costs Robux. No paid skip of the oath, the half-guild rule, or the score. Do not require `RaidConduct`, `RaidFinder`, or `RaidPremade`. Do not edit `RaidConduct.luau`, `RaidFinder.luau`, `RaidPremade.luau`, `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `MenuHub.luau`, `UiRouter.luau`, `RollHype.luau`, `Keybinds.luau`, remotes, or any T-012 file. T-072 owns `MenuHub.luau` and T-073 owns `DungeonService.luau`. Nothing in `src` requires this module. Suggest the guild score field in the hooks section. Open questions go in the hooks section. | done | [#80](https://github.com/Itsm00k21/Shardfall/pull/80) |
| T-075 | Contest Weekend rules (pure, no wiring) | HELPER | `helper/raid-contest-9721` | new `src/ReplicatedStorage/Shared/RaidContest.luau`, new `tests/RaidContest.spec.luau`, one require line in `tests/run.luau`, and a 'T-075 hooks for GHOST' section in this file. Pure rules from `docs/design/shardfall_raids.md` (Firsts and races, Contest Weekend): for the first 48 hours of a new raid, Shardbreaker is item-level capped. The first server-wide clear gets a Haven statue for a season and a global announcement. Everyone who clears during the window gets an exclusive emblem. Frozen CONFIG: `durationSeconds` 172800 and `itemLevelCap` placeholder 200. There is no item-level field in the repo yet. The caller passes a whole number. Shardbreaker only. Story, Normal, Hard, Fracture, Practice, and `guided` as a difficulty are refused. A Guided Shardbreaker clear may count. Guided does not waive the cap. `practice = true` is refused. `open(ctx)` takes `{ raidId, openedAt }` and starts an empty contest. `gear(state, itemLevel, now)` allows a whole item level at or under the cap while `now` is inside `[openedAt, openedAt + durationSeconds)`, and allows every finite whole level outside that window. `clear(state, record, now)` takes `{ runId, difficulty, practice, roster }` of user ids. The first counted clear sets `statue` and `announce` once. Later clears in the window set `emblem` for roster members not already credited and do not set the statue again. The same `runId` is a no-op. A missing `runId` is refused. Clears outside the window count nothing. Each call returns a new table and does not write the input. Unix seconds come in. No services, remotes, DataStores, MemoryStore, RNG, or clock. Nothing costs Robux. No paid skip of the cap, the window, or the first clear. Do not require `RaidGuided` or `RaidMarks`. Do not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `RaidGuided.luau`, `RaidMarks.luau`, `Schema.luau`, `MenuHub.luau`, `UiRouter.luau`, `RollHype.luau`, remotes, or any T-012 file. T-072 owns `MenuHub.luau` and T-073 owns `DungeonService.luau`. `RaidMarks.CONFIG.doubleMarks` stays false. No build stamp. Nothing in `src` requires this module. Suggest the contest fields in the hooks section. They are not player-schema fields. Open questions go in the hooks section. | done | [#84](https://github.com/Itsm00k21/Shardfall/pull/84) |
| T-081 | Raid weekly loot lockout rules (pure, no wiring) | HELPER | `helper/raid-lockout-9721` | new `src/ReplicatedStorage/Shared/RaidLockout.luau`, new `tests/RaidLockout.spec.luau`, one require line in `tests/run.luau`, and a 'T-081 hooks for GHOST' section in this file. Pure rules from `docs/design/shardfall_raids.md` (Loot and the chase, Retention, Roblox tech notes). Personal loot has a weekly lockout per boss per difficulty. The week key uses the same Tuesday fixed-UTC reset as RaidMarks: reuse `RaidMarks.weekKey`, and do not redefine that rule, copy its offset, or use `Raids.weekNumber`. A claim takes an idempotent claim id so loot can never be granted twice. The same claim id is a no-op. After the lockout, a reclear still returns `lootEligible = false`, but reclear rewards (Marks, Dust, materials) stay allowed. Fracture has no lockout. Practice never locks and never loots. Story, Normal, Hard, and Shardbreaker each lock separately. Store the lockout compactly in a profile-shaped table passed by the caller. Prune old weeks on read so the table cannot grow forever. Each call returns a new table and never writes its inputs. Unix seconds come in. No services, remotes, DataStores, RNG, or clock reads. Nothing costs Robux. No paid skip of the lockout. Do not edit `Schema.luau`, `RaidService.luau`, `DungeonService.luau`, `Raids.luau`, or `RaidMarks.luau`. No build stamp. Nothing in `src` requires this module, so gameplay is unchanged. Suggest the profile field in the hooks section. Schema stays 21. Open questions go in the hooks section. | done | [#86](https://github.com/Itsm00k21/Shardfall/pull/86) |
| T-083 | Strategy Board marker rules (pure, no wiring) | HELPER | `helper/raid-strategy-9721` | new `src/ReplicatedStorage/Shared/RaidStrategy.luau`, new `tests/RaidStrategy.spec.luau`, one require line in `tests/run.luau`, and a 'T-083 hooks for GHOST' section in this file. Pure rules from `docs/design/shardfall_raids.md` (Guild raid prep, Strategy Board): a top-down arena map where the raid lead places markers the whole party reads. Marker kinds are `stack`, `soak1`, and `soak2` in a frozen CONFIG. A marker is `{ id, kind, x, y }` with `x` and `y` in 0..1 inclusive. `place` upserts by id: the same id moves that marker, and a new id adds one. The lead removes by id. A missing id on remove is refused. Assistants and other roles cannot place, move, or remove. An unknown kind, a blank id, or a coordinate outside 0..1 (including NaN and inf) is refused. Frozen CONFIG caps markers on one board (placeholder 16) and saved presets per guild (placeholder 8). A full board refuses a new marker instead of dropping one. Presets are named, keyed by a caller-supplied guild id, and `save` copies the current markers. `load` returns a new board from that preset and does not write the preset. One board is shared. It is not per player and it is not loot. Practice, difficulty, and the Tuesday week do not change these rules. Each call returns a new table and does not write the input. No services, remotes, DataStores, MemoryStore, RNG, or clock. Nothing costs Robux. No paid marker, preset, or skip. Do not edit `RaidLockout.luau`, `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `Keybinds.luau`, `UiRouter.luau`, remotes, or any T-012 file. No build stamp. Nothing in `src` requires this module. Suggest where guild presets live in the hooks section. They are not player-schema fields. Open questions go in the hooks section. | claimed | — |

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

### T-037 hooks for GHOST

HELPER did not edit `Trading.luau`, `MarketBoard.luau`, `Raids.luau`, `RaidService.luau`, `RelicSets.luau`, `Schema.luau`, `Remotes.luau`, `RateLimiter.luau`, `DungeonService.luau`, `CraftService.luau`, or any other T-012 file. `RaidLootTrade` is pure and ready to call. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing requires it until the calls below. Gameplay is unchanged. No build stamp. No remote. Nothing here costs Robux. The T-037 row is `done`.

Thresholds are `RaidLootTrade.CONFIG`: `bindSeconds` is 7200 (2 hours), `heartshardClears` is 1. Do not hardcode the numbers beside the module. Pass `os.time()` (unix seconds) in as `now`. The module does not read the clock. `os.clock()` is not wall time.

`RaidLootTrade.check(item, transfer)` returns `ok` and `reason`. `reason` is nil when `ok` is true. It does not write the item. Pass the profile copy, never a client table. `item.bound` and `item.tradeable` are ignored.

`applies == false` and `category == "other"` means this module has no rule. Keep going with the existing Trading checks. `category == "invalid"` or (`applies == true` and `ok ~= true`) must return `reason` and must not move the item. A relic comes back `ok == true`, `category == "relic"`, `bound == false`. Do not add a `"Relic Set pieces are bound."` return, and do not put `RelicSets.isRelic` inside `Trading.rejection` as a refusal. `RelicSets.isRelic` is called from this module only, and it skips the 2-hour rule.

`bound == true` means no legal recipient remains under these rules. `tradeable == true` means some legal trade still exists, even when this proposal is refused. Inside the window, an ineligible recipient is `ok == false`, `bound == false`, `tradeable == true`. After the window, `bound == true` and `tradeable == false`.

`windowOpen` is the gear window. `remainingSeconds` on a check is 0 when the window does not apply. `RaidLootTrade.remaining(item, now)` is nil in that case, and nil when `now` or `droppedAt` cannot be used. For gear it is the seconds until `droppedAt + bindSeconds`. That value is 0 at the last instant and 0 after it. `RaidLootTrade.window(item, now).open` is how those two differ. A future `droppedAt` reports a remaining time longer than `bindSeconds` and `open == false`.

Categories, first match: `relic`, `cosmetic`, `heartshard`, `gear`, `other`. Kind and source compares are lowercase, so `Weapon` and `WEAPON` are the same. Boss ids and run ids are exact, with no trim.

**Item fields to stamp.** Gear, at the moment the personal loot is granted:

```lua
droppedAt = now, -- os.time(). Do not stamp 0. A 0 with a present-day now is already bound.
runId = runId,
bossId = bossId, -- optional. Exact id, such as "twins" or "awakened".
droppedFor = player.UserId, -- the player this personal loot was awarded to
roster = roster, -- { number } userIds in the run when the boss died, or { [userId] = true }
eligible = eligible, -- the subset who could loot that boss
traded = false,
kind = "Weapon", -- or "Armor" or "Accessory"
source = "raid",
```

`roster` and `eligible` accept a list of positive integer userIds or a set whose values are `true`. A string id does not match. One list per drop, for that boss. This module does not read the weekly lockout.

Crafted Heartshard, at the Forge, not as a raid drop. Do not set `droppedAt` on a craft. If both are set, the clear rule wins and the window does not.

```lua
heartshard = true,
crafted = true,
kind = "Weapon",
source = "forge", -- or "craft" / "crafted", or crafted = true
templateId = templateId, -- a lowercase "heartshard" in templateId or id also counts
crafterClears = clears, -- whole number. 0 until the crafter has a clear
crafterUserId = player.UserId,
```

Raid cosmetic:

```lua
kind = "Cosmetic",
source = "raid",
raidCosmetic = true, -- also binds a Pet, mount, title, dye, or aura
```

A relic stays on `RelicSets.stamp`. Do not also treat it as gear. Extra `droppedAt` or `runId` fields do not put it back under the window.

**Where to stamp.** The personal-loot grant is not in `RaidService` yet. T-010 owns that grant. When it lands, stamp the gear fields there, in the same server mutate that inserts the item, using the run's reserved id as `runId` and the boss that just died as `bossId`. Build `roster` from the seats still in the run. Build `eligible` as the players who were in the run when that boss died, were not weekly-locked for that boss and difficulty, and were not removed for AFK (T-027 forfeits rewards). A disconnect that is still inside the T-035 rejoin window can stay eligible if they were present for the kill. The client must not send these lists.

The Heartshard craft stamp belongs in `CraftService` when the resonant pattern is crafted. That file is not on this row. Until `crafterClears` is updated, pass the live count into `check` from the crafter's profile. A buyer does not need their own clear. The number is the crafter's.

Suggested profile field, same shape as `tradeDay`. HELPER does not edit `Schema.luau`. Optional, because the item field is enough when the trade passes it or the item already has it. Add it on whichever version is free. Version 20 is current. T-015 sketched 21, and T-027 / T-035 asked for raid fields on the same kind of bump.

```lua
raidClears: number, -- whole raid clears. 0 until the first. Not a weekly lockout.
```

Default `0`. This module does not know which raid that number is. Question 6 asks what "1 clear" counts.

**Trading.rejection.** The only caller today is the local `checkOffer` in `Trading.luau`. `Trading.preview` and `Trading.finish` know both actors. `Trading.inspect` is one-sided (a Market Board list). Add an optional context argument. Existing 4-arg calls keep working. `toUserId` nil means there is no named buyer.

Inside `Trading.rejection`, after the exploit check and before `isStarter`:

```lua
local RaidLootTrade = require(ReplicatedStorage.Shared.RaidLootTrade)

local context = context or {}
local loot = RaidLootTrade.check(item, {
	now = now,
	fromUserId = actor.userId,
	toUserId = context.toUserId,
	crafterClears = context.crafterClears,
	runId = context.runId,
	bossId = context.bossId,
})
if loot.category == "invalid" or (loot.applies == true and loot.ok ~= true) then
	return loot.reason or "That item cannot be traded."
end
```

There is no `RelicSets.isRelic` branch and no `"Relic Set pieces are bound."` string. A relic falls through. Cosmetics and the starter check stay as they are after this block.

`runId` on that table is the recipient's run, not a copy of `item.runId`. Omit it when you do not know where the recipient was. A mismatch refuses the trade even if that user is on `eligible`. `bossId`, when you pass it, must equal `item.bossId`.

From `Trading.finish` / `Trading.preview`, each side's items use the other actor as `toUserId`. A direct trade of in-window gear fails closed until that id is passed. From `Trading.inspect`, leave `toUserId` nil, so in-window raid gear cannot be listed. Relics, a crafted Heartshard with at least 1 clear, and items with `applies == false` can still be listed.

`crafterClears` is optional. When it is nil, the module reads `item.crafterClears`, then `item.clears`, then 0. Pass the crafter's count, not the buyer's. An explicit 0 overrides a higher number stored on the item.

On a successful gear trade, set `traded = true` on the copy that arrives, or set `droppedFor` to the new owner before any later trade. This module will refuse the next one while the window is open. After the window it is bound either way. Do not clear `droppedAt` to keep the window alive.

`tests/run.luau` requires `./RaidLootTrade.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. The window includes the exact end: `now == droppedAt + bindSeconds` still allows an eligible same-run trade, and `remaining` is 0 at that instant. One second later the piece is bound for good. Should the end instant be too late instead?
2. A missing `droppedAt` is bound, so a forgotten stamp cannot stay tradeable. A missing `runId` while the window is open refuses the trade and does not bind it, so a repaired stamp can still move inside the window. A `droppedAt` of 0 with a present-day `now` is already past the window and bound. Should a missing `runId` bind the piece too?
3. `now < droppedAt` refuses with "That drop is not live yet" and does not bind. Should a future stamp be treated as open, or as bound?
4. `RelicSets.isRelic` skips the 2-hour rule, the run, and the roster, even if the row is also stamped `bound`, `raidCosmetic`, or crafted Heartshard, and even though `docs/design/shardfall_raids.md` still says relics are bound. This follows `docs/design/relic_sets.md` and T-031/T-034. The snippet does not return "Relic Set pieces are bound." Confirm that is still the call.
5. Raid cosmetics are `raidCosmetic == true`, or `kind == "Cosmetic"` with raid provenance or a `runId`. The Gnarlling pet, Rootstrider mount, titles ("Heartbreaker"), dyes, and the raid aura are not bound unless stamped that way. A plain raid Pet stays outside this module. Should those exclusive drops be raid cosmetics?
6. Crafted Heartshard weapons unlock at `crafterClears >= 1` (the call, else `item.crafterClears`, else `item.clears`, else 0). A non-integer or negative count is refused. A dropped Heartshard that is not crafted uses the 2-hour rule, and a high clear count does not skip that window. Is "1 clear" any raid clear, or a clear of that weapon's raid and difficulty? Should the count be frozen onto the item at the first clear, or read from the crafter's profile at trade time?
7. Inside the window, `traded == true` or a `droppedFor` user id other than the sender binds the piece (one trade). If `droppedFor` is absent, the current holder may trade once. Should repeat trades stay legal until the window ends?
8. `runId` on the proposal is the recipient's run. If it is set and differs from `item.runId`, the trade is refused even when that user is on `eligible`. If it is omitted, `eligible` is enough even when `roster` omits them. On `roster` but not `eligible` is "not eligible". On neither is "not in this run". The sender does not have to be on either list. Should an eligible player also have to be on the roster?
9. A Market Board list has no buyer, so `toUserId` nil is refused for in-window raid gear ("Name someone from that run.") and allowed for relics, unlocked Heartshards, and items this module does not govern. Direct trades pass the other party's user id. Should in-window raid gear be direct-trade only?
10. Heartwood Vendor gear, Raid Marks purchases, and raid materials are not bound here. Only weapon, armor, and accessory drops, raid cosmetics, crafted Heartshards, and the relic exemption. Should vendor gear be soulbound?
11. User ids must be positive integers. Strings are not coerced. A self-trade is refused. Boss ids are exact strings. A proposal `bossId` that differs from the item, or a proposal boss with no item boss, is "not eligible". A missing item `bossId` is fine when the proposal omits it. Is that the stamp shape you want?
12. Eligible means the list you stamp. The suggestion is: in the run when the boss died, not weekly-locked for that boss and difficulty, and not removed for AFK. A disconnect inside the T-035 rejoin window can stay eligible if they were present for the kill. This module does not compute that. Is that the list you want?

### T-039 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `Trading.luau`, `MarketBoard.luau`, `Remotes.luau`, `RateLimiter.luau`, or any other T-012 file. The Heartwood Vendor catalog stays yours (T-010). `RaidMarks` is pure and ready to call. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing requires it until the calls below. Gameplay is unchanged. No build stamp. No remote. Nothing here costs Robux. The T-039 row stays `claimed`.

Thresholds are `RaidMarks.CONFIG`: `weeklyCap` 600, `bankWeeks` 3 (bank max 1800), `weekSeconds` 604800, `tuesdayOffset` 432000 (1970-01-06 00:00:00 UTC), first-timer bonus `1/10`, `eventMultiplier` 2, `doubleMarks` false. Payout placeholders: story 25, normal 40, hard 60, shardbreaker 80, fracture 20. Story and normal match the numbers `Raids.applyClear` pays today. Do not hardcode the numbers beside the module. Pass `os.time()` (unix seconds) in as `now`. The module does not read the clock. `os.clock()` is not wall time.

`RaidMarks.weekKey(now)` is the Tuesday week. Week 1 is `tuesdayOffset`. The reset instant belongs to the new week: `1791849600` (2026-10-13 00:00:00 UTC) is key 2963, and one second earlier is 2962. A time before the first Tuesday is key 0. A negative, NaN, or infinite time returns nil.

`Raids.weekNumber` and `Loops.weekNumber` stay `floor(now / 604800)`, which is Thursday 00:00 UTC. On that same Tuesday they return 2962. This module does not change them. Pass only keys from `RaidMarks.weekKey`, or a stored key below 0 for "never stamped".

`RaidService.luau`, next to the `Raids` require, when you wire the calls. The live grant is `Raids.applyClear`, which `DungeonService` already calls. You can keep that call and do the mark math inside `applyClear`.

```lua
local RaidMarks = require(ReplicatedStorage.Shared.RaidMarks)
```

Build the record from the profile. Nil fields count as zeros, and a missing week key counts as -1, so a call before the migrate does not throw. It also does not persist.

```lua
local function marksState(data)
	return {
		balance = data.raidMarks,
		weekKey = data.raidMarkWeek,
		earnedThisWeek = data.raidMarksEarned,
		bankedCap = data.raidMarksBank,
	}
end
```

The module returns a new result and does not write `data`. Persist only when `result.ok == true`. An `ok == false` result is a bad clock, a bad amount, a backwards week, or a non-finite record. The record failure returns zeros. Writing that would wipe a real balance.

`earn` rolls the week, then adds `min(amount, room)` to the balance and to `earnedThisWeek`. `granted` may be smaller than `amount`. `capped == true` means the room ran out. `room` is what is left after this call. `rolled == true` means the week key changed. `settle(state, now)` is `earn(0, state, now)`.

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `weekKey(now)` | you need the Tuesday key and nothing else | the key, or nil when `now` cannot be used |
| `settle(state, now)` | profile load, and any time the cap UI should be current | the week rolled, `granted == 0`. Idempotent in the same week. |
| `payout(difficulty, clear)` | a boss clear is about to pay Marks | the per-player grant in `amount`. `gross` is that grant before an AFK forfeit. |
| `earn(amount, state, now)` | `payout` returned `ok == true` | pass `payout.amount`. An AFK clear has amount 0, so the week rolls and the balance stays. |
| `canSpend(cost, state)` | Heartwood Vendor, before the chest or title is granted | `ok == true` carries the balance after the price. It does not take a clock and does not roll the week. |

A stored week key below 0 (the schema default is -1) stamps the current Tuesday, keeps `earnedThisWeek`, and does not bank the years since 1970. A new profile therefore starts with room 600. After that stamp is saved, a later week banks the gap even if they never logged in: unused room from the stored week, plus 600 for each fully skipped week, clamped to 1800. The new week then adds its own 600. A full bank has room 2400. Two settles in one week do not add a second bank. A week key ahead of `now` returns `ERRORS.clock` and grants 0.

`payout` lowercases and trims the difficulty. `" Normal "` is normal. `locked == true` sets `reclear` and pays the same `amount` as a first clear. The module does not read `raidLock`. Each `firstTimers` adds 10% to that per-player amount. 25 with one first-timer rounds half up to 28. Two first-timers on normal pay 48. The amount is not split across the group.

`removal` is nil, `"afk"`, or `"kick"`. `"afk"` is the T-027 90s removal: `amount` is 0, `keepMarks` is false, `forfeited` is true, `gross` still shows the grant. `"kick"` is a T-027 passed vote-kick: the full grant, including an idle reason. Already-paid balance is never subtracted. `"AFK"`, `"idle"`, and `"leave"` are refused. A refused payout must not be passed to `earn`.

`event == true` multiplies only when `CONFIG.doubleMarks == true`. The switch is false, so Heartwood Night and the old-raid Echo pay 1x until you change it. The spec pins that false. `eventMultiplier` is 2.

**Clear grant.** `Raids.applyClear` still adds Marks itself (`25` / `40`, Thursday `raidMarkWeek`, no bank). Leave that function as it is until the wiring change. In that change, replace the mark lines and keep the loot lock, pity, and `raidStory` flag. Calling `earn` and the old mark lines on the same clear pays twice. Practice Grove stays off this path. `DungeonService` already skips `applyClear` when `run.practice == true`.

Inside the same `DataService.mutate` that grants the clear, after you know whether this player was removed:

```lua
local now = os.time()
local removal = nil
if afkRemoved then
	removal = "afk"
elseif voteKicked then
	removal = "kick"
end
local grant = RaidMarks.payout(difficulty, {
	firstTimers = freshCount,
	locked = locks[bossId .. ":" .. difficulty] == RaidMarks.weekKey(now),
	removal = removal,
	event = heartwoodNight == true,
})
local paid = 0
if grant.ok == true then
	local ledger = RaidMarks.earn(grant.amount, marksState(data), now)
	if ledger.ok == true then
		data.raidMarks = ledger.balance
		data.raidMarkWeek = ledger.weekKey
		data.raidMarksEarned = ledger.earnedThisWeek
		data.raidMarksBank = ledger.bankedCap
		paid = ledger.granted
	end
end
```

`freshCount` is yours. This module does not know who is new. Count the Fresh Shard seats you want included. `afkRemoved` is `RaidConduct.afk` returning `state == "remove"` for this player before this grant. `voteKicked` is `RaidConduct.tally` returning `passed == true`. A removal after the grant does not claw the Marks back. `paid` is what the toast should show. `grant.amount` can be larger when `ledger.capped` is true.

The lockout compare above uses the Tuesday key. `locks[key] == week` inside `applyClear` still uses `Raids.weekNumber` until you switch that too. Loot lock and Marks week should share one key when you wire this, or a Tuesday clear can pay Marks and still look unlocked for loot.

**Vendor.** Prices stay in `Raids.SHOP`. This module has no catalog and no Robux price. `RaidService.buy` calls `Raids.buy`, which subtracts `raidMarks` itself. When you wire `canSpend`, stop subtracting in that same path or the price is paid twice.

```lua
local row = Raids.SHOP[itemId]
if row == nil then
	return "The vendor does not sell that."
end
local spent = RaidMarks.canSpend(row.marks, marksState(data))
if spent.ok ~= true then
	return spent.error or RaidMarks.ERRORS.short
end
data.raidMarks = spent.balance
```

Then grant the chest or title the way `Raids.buy` already does. `canSpend` does not roll the week. Call `settle` first when the purchase should also stamp a new Tuesday, and persist that settle before you read `marksState` for the price. A short wallet leaves the balance alone. Cost 0 returns `ok` with `spent` 0.

**Login.** `earn` on a later clear banks a gap from the saved week key, so a missed login does not lose the bank. `settle` on profile load is what makes `raidMarksBank` and `earnedThisWeek` current for a vendor label before the next clear. Persist it the same way, and skip the write when `ok ~= true`.

**Schema.** HELPER does not edit `Schema.luau`. Three fields already exist. One is new. Add the new one on whichever version is free when you wire this. Version 20 is current. T-015 sketched 21 for the pass fields, and T-027 / T-035 asked for raid fields on the same kind of bump. One migrate can add the bank with those.

```lua
raidMarks: number, -- wallet. Already in the template. Survives Tuesday.
raidMarksEarned: number, -- already in the template. Earned against this week's room.
raidMarkWeek: number, -- already in the template, default -1. Store RaidMarks.weekKey here.
raidMarksBank: number, -- new. Unused earning room carried in, 0 to 1800.
```

`raidMarks`, `raidMarksEarned`, and `raidMarkWeek` are already on `ProfileData`, `template()`, `sanitize`, and the version 19 migrate (`raidMarkWeek = -1`). `snapshot` already sends `raidMarks`. Add `raidMarksBank = 0` beside those, and send `raidMarksEarned`, `raidMarkWeek`, and `raidMarksBank` on the snapshot when the vendor should show the room. `wholeNumber` defaults match `raidMarks`. A non-finite field makes `earn` and `canSpend` return `ok == false`. If `sanitize` turns that into 0 before the check, a broken wallet becomes spendable. Leave a non-finite balance for the module to refuse.

Until `raidMarksBank` survives a load, the returned bank is dropped on the next read (nil counts as 0) and the carry will not hold.

`tests/run.luau` requires `./RaidMarks.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. The bank holds unused earning room up to 3 × 600 = 1800, and the current week adds a fresh 600, so a full bank can earn 2400 in one week. Should 3 weeks be the total room instead (1800, with the bank holding 1200)?
2. Leftover marks carry exactly (earn 100 of 600, the next week banks 500). A fully skipped week adds 600. Is that the carry you want?
3. A week key below 0 (schema `raidMarkWeek` default -1) stamps the current Tuesday and does not bank the years since 1970. `Raids.weekNumber` is Thursday 00:00 UTC. On 2026-10-13 the Thursday week is 2962 and this key is 2963. Passing the old Thursday number can bank one extra week. Should wiring pass `weekKey = -1` once, keep `raidMarksEarned`, and store the Tuesday key from that result?
4. The balance survives Tuesday and has no wallet cap. The 600 is the earning room. Is an uncapped wallet right?
5. Placeholders are story 25, normal 40 (what `Raids.applyClear` pays now), hard 60, shardbreaker 80, and fracture 20. The design's Fracture row lists score, dust, and cosmetics. Should fracture pay Marks, and are the hard and shardbreaker stand-ins the numbers you want?
6. The amount is the per-player grant. Each first-timer adds 10% for every member who keeps Marks. It is not split across the group. There is no cap on the count. 25 with one first-timer rounds half up to 28. Is that the grant?
7. An AFK removal pays 0 for this clear and does not subtract Marks already in the balance. A passed vote-kick pays the full grant, including an `idle` or `afk` reason, matching T-027 `keepMarks`. Should an idle-reason vote-kick forfeit this clear?
8. The module uses the first-timer count you pass. An AFK first-timer still adds 10% for everyone else when you leave them in that count. Should a removed player stop counting?
9. A clear larger than the remaining room grants the room, returns `ok` true, and sets `capped` true. Should that clear be refused with no Marks instead?
10. `doubleMarks` is false and `eventMultiplier` is 2. `event = true` pays 1x until the switch is true. One switch covers Heartwood Night and the old-raid Echo. Guild "+Marks" and Guided double guild points are outside this module. Should those live here later, and is one switch enough?
11. `canSpend` takes no clock and does not roll the week. A cost of 0 returns `ok` and `spent` 0. A short wallet returns "Not enough Raid Marks." Is a zero cost a legal no-op?

### T-041 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `Trading.luau`, `MarketBoard.luau`, `Remotes.luau`, `RateLimiter.luau`, or any other T-012 file. `RaidFinder` is pure and ready to call. It does not require `RaidLeaver` or `RaidConduct`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing requires it until the calls below. Gameplay is unchanged. No build stamp. No remote. No MemoryStore. Nothing here costs Robux. The T-041 row stays `claimed`.

Thresholds are `RaidFinder.CONFIG`. Party size is `minParty` 4 through `maxParty` 8. Healer wait is `healerWaitSeconds` 180. Boss damage is `bossDamage` 1, and a healerless start uses `healerlessDamage` 0.85 (15% less). `healingSpring` is true, so that start also flags a free Healing Spring. Mentor eligibility is `mentorClears` 10. Queue priority starts at `defaultPriority` 0 and an idle kick stores `droppedPriority` -1. Higher sorts first. The UTC day is `daySeconds` 86400, `floor(now / 86400)`, same as `tradeDay`. Role targets are placeholders: 4 is 1 tank / 1 healer / 2 DPS, 5 is 1 / 1 / 3, 6 is 1 / 1 / 4, 7 is 1 / 1 / 5, and 8 is 1 tank / 1 healer / 6 DPS. HP scale placeholders are 0.5, 0.625, 0.75, 0.875, and 1 for sizes 4 through 8. `fillOrder` is tank, then healer, then DPS. Do not hardcode the numbers beside the module. Pass `os.time()` (unix seconds) in as `now`. The module does not read the clock. `os.clock()` is not wall time.

`RaidFinder.DIFFICULTIES` is story and normal. `RaidFinder.REFUSED` is hard and shardbreaker. `RaidFinder.ROLES` is tank, healer, dps, and flex. `RaidFinder.IDLE_REASONS` is `idle` and `afk`, the same two strings as `RaidConduct.IDLE_REASONS`. `RaidFinder.WARDEN_ID` is the placeholder `"warden_golem"`. Strings are trimmed and lowercased. `" Story "` is story. `" AFK "` is an idle kick.

`RaidService.luau`, next to the `Raids` require, when you wire the calls:

```lua
local RaidFinder = require(ReplicatedStorage.Shared.RaidFinder)
```

The live `RaidService.queue` still checks `Raids.difficulty`, `Raids.roleOk`, level 15, and a Story clear before Normal, then launches one player. Leave those four checks where they are. Call `canQueue` after them, before a ticket is accepted. This module does not repeat the level gate or the Story-before-Normal gate.

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `canQueue(ticket, now)` | a player asks to enter Finder | `queued == true` means they may sit in the list. Gear score and clear count are ignored. |
| `filters(difficulty)` | a Finder screen is about to show a gear or clear slider | story and normal return both filters false. |
| `form(proposal, now)` | one difficulty has 4 to 8 tickets | `mayStart == true` is the only launch signal. `freshCount` is the RaidMarks first-timer count. |
| `priority(record, now, idleKick)` | an idle vote-kick passes, and again at the start of `queue` so a new UTC day restores 0 | the number to store. Higher sorts first. |
| `mentor(clears, optedIn)` | a mentor badge, with no group | `eligible` when clears are at least 10 and they opted in. |
| `hpScale(players)` | you have a count and no proposal | the CONFIG scale, or nil outside 4 to 8. |

`canQueue` reads `difficulty`, `role`, and `cooldownUntil`. It does not read `gearScore`, `clearCount`, `clears`, `level`, or `raidStory`. A missing cooldown is 0. A negative cooldown is 0. `cooldownUntil > now` returns `ok == true`, `queued == false`, `finderBlocked == true`, and `remainingSeconds`. The deadline itself may queue, same as `RaidLeaver.finder`. Pass `data.raidFinderCooldownUntil` from the T-035 field. This module does not call `RaidLeaver`.

Hard and Shardbreaker return `ok == false` and `ERRORS.guided` ("Hard and Shardbreaker are premade. Guided Raids come later."). Fracture and any other name return `ERRORS.difficulty`. A bad role returns `ERRORS.role`. A bad clock, a non-finite cooldown, or a missing ticket returns `ok == false` and `finderBlocked == true`, so a broken stamp does not enter the list. `gearFiltered` and `clearFiltered` stay false on every result. Show `error` whenever `queued ~= true`.

Hold accepted tickets in memory on `RaidService`, one list per difficulty. The design's MemoryStore queue is a later cross-server task. This module does not create one. Sort that list by `priority` descending before you pick a proposal. A dropped player still queues. They sort last.

`form` takes the players you already chose. It does not pull from a queue. `waitingSince` is the unix time this roster started waiting on a healer. Nil means the wait is 0, so a missing stamp cannot auto-scale. A `waitingSince` later than `now` returns `ERRORS.clock` and `mayStart == false`.

Flex seats fill `fillOrder` in party order. The first flex takes the first short target. One flex with both tank and healer missing becomes the tank. A later flex, or a flex when a tank is already seated, becomes the healer. Leftover flex becomes DPS. A queued tank, healer, or DPS keeps that role. Extra tanks do not convert into healers. A short DPS count does not block `mayStart`.

`mayStart` is true when the tank target is covered and the healer target is covered. Story covers a missing tank with `wardenCount` golems, one per missing tank (`WARDEN_ID`). Normal leaves `wardenCount` at 0 and will not start while a tank is missing. A missing healer covers itself only when `waitedSeconds >= healerWaitSeconds`. That sets `autoScale`, `bossDamageScale` to 0.85, and `healingSpring`. Under 180 seconds those stay off and `mayStart` is false. A healer already in the group, including a flex who filled healer, keeps `bossDamage` at 1 even after the clock has run out. `healerTimeout` is only the clock. Launch on `mayStart`, not on `healerTimeout` or `autoScale` alone. HP scale is the player count. Golems are not players, so they do not change `hpScale`.

`Raids.combatScale` already multiplies boss damage by 0.85 whenever `healer` is false, with no wait, and it scales HP as `difficulty.hp * count/8`. Wiring both that branch and `bossDamageScale` cuts twice. Use `form.hpScale` and `form.bossDamageScale` for a Finder launch. The difficulty row in `Raids.DIFFICULTIES` can still supply the tier (story damage 0.85, normal 1, story HP 1, normal 1.35). This module's scale is the player-count multiplier and the Finder healer rule on top of that choice. See question 3 before you multiply them.

`fresh == true` sets `freshShard` on that seat. Nil is false. A number is refused. `freshCount` is how many seats are fresh. Pass it to `RaidMarks.payout` as `firstTimers` when T-040 wires the clear. This module does not decide what "first time" means. You set the boolean. `clears` is only the mentor count. It is not a Finder filter, and it does not turn the Fresh Shard on.

`mentor` on a seat is `clears >= 10` and `mentorOptIn == true`. Nil opt-in is false. A non-boolean is refused. The module does not grant Mentor Tokens or cosmetics. `form` echoes `priority` and does not roll the UTC day. Call `priority` first, persist it, and pass that number on the seat.

A member with `cooldownUntil > now` makes `form` return `ok == false`, `mayStart == false`, and `ERRORS.cooling`. The deadline itself is allowed. A repeated `userId` returns `ERRORS.duplicate`. A missing `userId` is allowed. `form` returns new tables and does not write the proposal. An `ok == false` result has empty `seats`. Do not launch it.

`priority` returns a new record. It does not write the one you passed. Nil becomes priority 0 and day 0. A new UTC day restores `defaultPriority` unless this call is also an idle kick. An idle kick then stores `droppedPriority` and stamps today. Pass `true`, or the reason `"idle"` or `"afk"`. `"unfair"` leaves the stored number alone. A second idle kick on the same day stays at -1. A bad flag returns `ok == false`. Persist only when `ok == true`.

When `RaidConduct.tally` returns `dropQueuePriority == true` for the kicked player, inside the same mutate that already records the kick:

```lua
local now = os.time()
local nextPriority = RaidFinder.priority({
	priority = data.raidQueuePriority,
	priorityDay = data.raidQueuePriorityDay,
}, now, true)
if nextPriority.ok == true then
	data.raidQueuePriority = nextPriority.priority
	data.raidQueuePriorityDay = nextPriority.priorityDay
end
```

At the start of `queue`, roll the day before you sort. `idleKick` is false here. The kick already happened.

```lua
local now = os.time()
local rolled = RaidFinder.priority({
	priority = data.raidQueuePriority,
	priorityDay = data.raidQueuePriorityDay,
}, now, false)
local changed = rolled.priority ~= data.raidQueuePriority
	or rolled.priorityDay ~= data.raidQueuePriorityDay
if rolled.ok == true and changed then
	data.raidQueuePriority = rolled.priority
	data.raidQueuePriorityDay = rolled.priorityDay
end
local ticket = {
	difficulty = difficulty,
	role = role,
	cooldownUntil = data.raidFinderCooldownUntil,
}
local gate = RaidFinder.canQueue(ticket, now)
if gate.queued ~= true then
	return { ok = false, error = gate.error }
end
```

Ignore `gearScore` and `clearCount` on the client payload. `filters` is the same rule for the Finder screen: story and normal keep both false, so the slider should not exist there. The premade board's clear-count tag is a different surface. This module does not read it.

When the in-memory list for that difficulty has between 4 and 8 players, build `members` from those tickets and call `form`. Launch only when `formed.ok == true` and `formed.mayStart == true`. Pass `formed.playerCount`, `formed.hpScale`, `formed.bossDamageScale`, `formed.healingSpring`, and `formed.wardenCount` into the raid. Spawn `wardenCount` copies of `RaidFinder.WARDEN_ID` on Story. `healingSpring` means the run gets the free totem. This module does not spawn it. `formed.freshCount` is the number T-040 should pass as `firstTimers`. The solo Studio fallback in `queue` can stay until that roster exists, so a one-player test still runs. A Finder start uses `form`.

```lua
local formed = RaidFinder.form({
	difficulty = difficulty,
	waitingSince = roster.waitingSince,
	members = members,
}, now)
if formed.ok ~= true or formed.mayStart ~= true then
	return { ok = false, error = formed.error }
end
```

Reset `waitingSince` when the roster changes: a healer (or a flex who will fill healer) joins, or the group drops someone and is no longer the group you are forming. Stamp it to `now` the first time the roster is short a healer. Leaving it nil keeps the wait at 0.

**Schema.** HELPER does not edit `Schema.luau`. Two new fields, plus one boolean. Add them on whichever version is free when you wire this. Version 20 is current. T-015 sketched 21 for the pass fields, and T-027 / T-035 / T-039 asked for raid fields on the same kind of bump. One migrate can add these with those. `raidFinderCooldownUntil` is the T-035 field. Reuse it. Mentor clears should reuse `raidClears` once T-038 adds it. Until that field exists, pass 0 into `mentor` and into the seat, so nobody is a mentor yet.

```lua
raidQueuePriority: number, -- 0 normal. Idle kick stores droppedPriority (-1). Higher sorts first.
raidQueuePriorityDay: number, -- UTC day the priority was stamped. 0 until the first call.
raidMentor: boolean, -- opted in. Clears are raidClears, passed in by the caller.
```

`ProfileData`, `template()`, the matching `migrate` arm, `sanitize`, and `snapshot` (so a queue icon can show a dropped priority and a mentor opt-in): defaults `raidQueuePriority = 0`, `raidQueuePriorityDay = 0`, `raidMentor = false`. A non-finite priority makes `priority` return `ok == false`. Leave that value for the module to refuse. Do not reset these on the Tuesday weekly raid reset. The UTC day inside `priority` restores 0.

There is no mentor opt-in remote yet. A remote is T-012. When you add one, write `data.raidMentor` from a server mutate. The client must not send `now`, `cooldownUntil`, `fresh`, or `clears`.

`tests/run.luau` requires `./RaidFinder.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. Role targets are placeholders. Sizes 4 through 7 are 1 tank, 1 healer, and the rest DPS. Size 8 is 1 tank / 1 healer / 6 DPS. The design's 8-player line is 1–2 Wardens, 1–2 Tidecallers, and 4–5 DPS. Are these the minimums to start without a golem or a healer timeout?
2. Flex fills tank, then healer, then DPS, walking the party in order. One flex with both roles missing becomes the tank, so the healer timeout still applies. Should that flex become the healer instead?
3. Story spawns one `warden_golem` per missing tank (two if an 8-player group has none). Normal never spawns one and cannot start while short a tank. HP scale is the player count only (0.5 at 4 through 1 at 8) and ignores golems. `Raids.combatScale` is `difficulty.hp * count/8` and also cuts damage 15% whenever `healer` is false, with no 180s wait. Should a Finder launch use this module's scales instead of that function, so the cut happens once and only after the wait? Should golems count toward HP?
4. Fresh Shard is the `fresh` boolean you pass. `freshCount` is how many seats have it, for `RaidMarks.payout` `firstTimers`. It is not `clears == 0`. Is fresh "never cleared this raid", "never cleared this difficulty", or a new account? A seat can be fresh and a mentor together if you set both.
5. Mentor is `clears >= 10` and `mentorOptIn == true`. This module does not grant Mentor Tokens or cosmetics. Queue priority is a number, higher first: 0 is normal, an idle kick sets -1, and the next UTC day restores 0. A dropped player can still queue. Should the drop last the rest of that UTC day, and do you want any priority besides 0 and -1?
6. Story and Normal ignore gear score and clear count. Level 15 and "clear Story before Normal" stay in `RaidService.queue`. Hard and Shardbreaker are refused. Anything else, including fracture, is refused as not Finder. Should those two `RaidService` gates move into this module?
7. `canQueue` blocks one player while `cooldownUntil > now`. The deadline may queue, same as `RaidLeaver`. `form` refuses the whole proposal if any member is still cooling. Should `form` drop that member and form the rest instead? This module does not require `RaidLeaver`.
8. Class is not checked. `Raids.roleOk` still requires Warden for tank and Tidecaller for healer, and it allows any class as DPS or Flex. Forgeborn off-tank is not a rule here. Should Finder refuse a tank who is not a Warden?
9. Extra tanks and healers keep the role they queued. A short DPS count does not block `mayStart`. Only a missing tank on Normal, or a missing healer before 180s, holds the launch. Is that the start rule?
10. `waitingSince` is the unix time this roster started waiting on a healer. Nil means the wait is 0. Should that stamp be the oldest ticket in the queue, or the moment this forming roster first had everyone except a healer?

### T-043 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `Trading.luau`, `MarketBoard.luau`, `Remotes.luau`, `RateLimiter.luau`, `RaidHud.luau`, or any other T-012 file. `RaidPremade` is pure and ready to call. It does not require `RaidFinder`, `RaidLeaver`, or `Raids`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires `RaidPremade` or `RaidFinder` yet, so this branch does not change a live run. No build stamp. No remote. No MemoryStore. No DataStore. Nothing here costs Robux. The T-043 row is `done` on #49.

`RaidFinder.CONFIG.roleTargets[8]` is now 1 tank, 1 healer, and 6 DPS. Sizes 4 through 7 are unchanged. An 8-player Story group with no tank gets one Warden golem, not two. A group that already has 1 tank, 1 healer, and 6 DPS starts with `wardenCount` 0. The T-041 hooks paragraph says size 8 is 1 tank / 1 healer / 6 DPS.

Thresholds are `RaidPremade.CONFIG`. Party size is `minParty` 4 through `maxParty` 8. A listing lasts `listingSeconds` 1800 (30 minutes, a placeholder). `minClears` is 0. Do not hardcode the numbers beside the module. Pass `os.time()` (unix seconds) in as `now`. The module does not read the clock. `os.clock()` is not wall time.

`RaidPremade.DIFFICULTIES` is story, normal, hard, and shardbreaker. `RaidPremade.REFUSED` is guided. `RaidPremade.GEAR_FREE` is story and normal. `RaidPremade.ROLES` is tank, healer, dps, and flex, the same four names as `RaidFinder.ROLES`. `RaidPremade.TAGS` is learning, farm, speedrun, and achievement, the same four labels as `Raids.TAGS` after trim and lowercase. Strings are trimmed and lowercased. `" Story "` is story. `" Learning "` is learning.

`RaidService.luau`, next to the `Raids` require, when you wire the calls:

```lua
local RaidPremade = require(ReplicatedStorage.Shared.RaidPremade)
```

The live `listings` array, `RaidService.post`, `RaidService.join`, and `RaidService.board` stay the home for the plaza board. Replace the checks inside those functions. Do not send a premade join through `RaidService.queue`. `queue` still means Finder: it launches one player, and `Raids.difficulty` only accepts Story and Normal. A premade listing is Hard and Shardbreaker too, and it must not start on the first click.

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `validate(draft, now)` | you already built a listing and want the normalized copy | `ok == true` and a new `listing`. An expired shape still validates. |
| `open(board, draft, now)` | a host posts | `ok == true` is the only signal to store it. Nil `board` is an empty board. |
| `canJoin(listing, player, now)` | a player asks to take a seat | `allowed == true` means the seat is open. This does not write. |
| `join(listing, player, now)` | `canJoin` would allow it and you want the next listing | a new `listing` with that player seated. The input is not written. |
| `depart(listing, userId, now)` | a member leaves, or the host disconnects | `hostLeft == true` means the listing is closed. A new `listing` comes back. |
| `status(listing, now)` | the plaza paints a row, or you sweep | `full`, `expired`, `closed`, `active`, and `openCount`. |

`open` stores nothing. Keep the id and the filtered title on a wrapper in `RaidService`, and pass `row.listing` into later calls. This module drops fields it does not know, including `title` and `id`.

```lua
{
	id = id, -- RaidService nextId. Not inside the module.
	title = filtered, -- TextService result. Never passed into RaidPremade.
	hostName = player.Name, -- display only. The rule keys hostUserId.
	listing = normalized, -- the table open / join / depart return.
}
```

`validate` reads `difficulty`, `tags`, `requiredClears`, `gearScore`, `partySize`, `slots`, `hostUserId`, `createdAt`, `closed`, `members`, and `guided`. It does not read `title`, `cooldownUntil`, `expiresAt`, or a gear score on the player. A missing `requiredClears` becomes 0. A missing `closed` becomes false. `createdAt` has to be a unix time no later than `now`. A later stamp returns `ERRORS.clock` ("Raid time moved backwards."). The returned `expiresAt` is `createdAt + listingSeconds`. A caller-supplied `expiresAt` is ignored. `validate` returns a new table and does not write the draft. Show `error` whenever `ok ~= true`.

Tags are one or more of the four names. A single string is one tag, so today's `RaidPost` string still validates. An array keeps the host's order after lowercase. An empty list, a blank string, an unknown tag, and a duplicate are refused. Guided is refused two ways: difficulty `"guided"`, or `guided == true` on a Hard or Shardbreaker listing. A non-boolean `guided` is `ERRORS.guidedFlag`. Fracture and any other name are `ERRORS.difficulty`.

Story and Normal refuse `gearScore`, including 0. A negative or fractional gear score is unusable on every difficulty. Hard and Shardbreaker may store a non-negative integer. `canJoin` does not compare it. A Hard listing that says 500 still accepts a player with no gear score. See question 5.

The host has to be one of `members`, once. Build that list on the server. Do not trust a client member list. The host's role is the role they picked, after you decide whether `Raids.roleOk` still applies (question 14). Seats are assigned in member order. A tank, healer, or DPS takes the first open slot of that role, then the first open flex slot. A flex player takes the first open slot in the host's slot list, whatever role that slot is. Two tanks and only one tank slot, with no flex slot, return `ERRORS.fit`. A party of four DPS is valid. This module does not apply the Finder tank and healer minimums.

`open` refuses a closed draft, a draft that is already expired, and a host who already has an active row on `board`. Active means not closed and not expired. A full listing is still active, so that host cannot post a second one. An expired or closed row for the same host does not block. A player who is only seated in someone else's listing can host their own. Pass the current normalized listings as a dense array. A bad row fails the whole `open`. The function does not append and does not write `board`.

A listing is expired when `now >= createdAt + listingSeconds`. The deadline second is already expired. One second earlier it is still open. `status.active` is false when the row is expired or closed. `status.full` is `openCount == 0`. A full expired row reports both.

`canJoin` and `join` read `userId`, `role`, and `clears` on the player. Nil `clears` is 0. The player needs `clears >= requiredClears`. The exact count may join. A negative or fractional count is unusable (`ok == false`). They do not read `cooldownUntil` or `gearScore`. A RaidLeaver Finder cooldown does not block the premade board. Do not pass `data.raidFinderCooldownUntil` in. Rule refusals return `ok == true` and `allowed == false`, in this order: closed, expired, already seated, not enough clears, full, no open slot for that role. Corrupt input returns `ok == false`. Store the new listing only when `join` returns `allowed == true`. Show `error` whenever `allowed ~= true`. `join` appends the player and reseats. It does not write the old listing. Replace the wrapper's `listing` with the returned one.

`depart` closes the listing when `userId` is the host and leaves the other members on the record. A non-host leave removes that seat and reseats whoever remains. The listing stays open. A second host depart on an already closed listing returns `ok == true` and `hostLeft == true`. Anyone else on a closed listing gets `ERRORS.closed`. A user who is not seated gets `ERRORS.absent`. Replace the stored listing only when `ok == true`. Drop it from the plaza copy when `status.active ~= true`.

`RaidService.post` today checks `Raids.tagOk` and `Raids.difficulty`, so Hard, Shardbreaker, and a second tag never land. Stop using those two as the board gate. Stamp the host and the clock yourself. Filter the title here, with `TextService`, before you store the wrapper. If the filter fails, refuse the post. Do not pass the title into `RaidPremade`.

```lua
local now = os.time()
local draft = {
	hostUserId = player.UserId,
	difficulty = difficulty,
	tags = tags,
	requiredClears = requiredClears,
	gearScore = gearScore,
	partySize = partySize,
	slots = slots,
	createdAt = now,
	members = {
		{ userId = player.UserId, role = role },
	},
}
local opened = RaidPremade.open(listings, draft, now)
if opened.ok ~= true then
	return { ok = false, error = opened.error }
end
```

`listings` in that snippet is the array of normalized listings already stored. The old `while #listings > 20` drop is not in this module. Dropping the oldest row can remove a host's active listing without them leaving. See question 8.

`RaidService.join` today finds the id and calls `queue`, which starts a raid immediately. Do not do that. Load `data.raidClears` (nil until T-038 adds it) and call `join`. Ignore `data.raidFinderCooldownUntil`.

```lua
local now = os.time()
local gate = RaidPremade.join(found.listing, {
	userId = player.UserId,
	role = role,
	clears = data.raidClears,
}, now)
if gate.allowed ~= true then
	return { ok = false, error = gate.error }
end
found.listing = gate.listing
```

Launch only from a row whose `status` is `full == true`, `expired == false`, and `closed == false`, and not from this module. Story and Normal can use the existing launch once you have a real roster. Hard and Shardbreaker need a launch path that is not `Raids.difficulty`. Finder healer-timeout, boss-damage scale, and Warden golems are `RaidFinder.form`. Do not apply them to a premade.

`RaidService.board` should skip a row whose `status.active ~= true`, and it can show `difficulty`, `tags`, `requiredClears`, `partySize`, `openCount`, `full`, the slots, and the filtered title. The client must not send `now`, `createdAt`, `hostUserId`, or `clears`.

When a seated player leaves on purpose, call `depart` with their user id. There is no leave button yet. Closing the client is the same depart. `Players.PlayerRemoving` in `DungeonService` is the live hook, and that file is not on this row. One call from there into `RaidService` is enough. If the removed player is the host, `hostLeft` is true and the listing is closed. If they were only a member, the slot opens.

**Schema.** HELPER does not edit `Schema.luau`. No new field. The join check reuses `raidClears` once T-038 adds it. Until that field exists, pass nil and the module treats it as 0, so a listing with `requiredClears` above 0 accepts nobody. Do not add `raidFinderCooldownUntil` to this path. The board is the in-memory `listings` array already on `RaidService`. It does not belong on the profile. A restart clears it. MemoryStore and DataStore are out of scope.

`tests/run.luau` requires `./RaidPremade.spec` on this branch.

Build stamp files are T-012. This branch does not change them. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. `listingSeconds` is 1800. A listing expires when `now >= createdAt + 1800`, so the deadline second is already closed. Should that second still be open, the way a RaidLeaver cooldown still lets you queue at the exact `cooldownUntil`?
2. A tank, healer, or DPS takes the first open slot of that role, then the first open flex slot. A flex player takes the first open slot in the host's list. Should flex prefer tank, then healer, then DPS, the way `RaidFinder.fillOrder` does?
3. A dedicated role can sit in a flex slot once its own slots are full. Should a flex slot be only for players who signed as flex?
4. Four DPS is a valid listing. Finder's 1 tank / 1 healer minimum is not applied. Should a premade still require those minimums before it can be posted or before it can launch?
5. Hard and Shardbreaker may store a non-negative integer `gearScore`, including 0. Story and Normal refuse the field, including 0. `canJoin` does not compare gear on any difficulty, so a Hard listing that stores 500 still accepts everyone. Should join refuse a player under that score, and is a missing score 0?
6. A missing `requiredClears` becomes 0. `1.5` is refused, not floored. The exact count may join. The host is not checked against their own number. Should the host have to meet it, and should a fraction floor instead?
7. One active listing is per host. A player seated in someone else's listing can still host their own. Should any seat in an active listing block hosting?
8. The board is the in-memory `listings` array. Expired and closed rows do not count as the host's active listing. `post` currently drops the oldest row at 20. This module has no cap. Should a full board refuse the new post instead of dropping someone else's listing? Nothing is persisted across a restart.
9. A host leave sets `closed` and keeps the other members on the record. A non-host leave only frees that slot. Should the closed listing drop the other members, and should the plaza remove the row immediately?
10. Title text is not read, stored, or filtered here. `RaidService.post` should filter it with `TextService` and keep the string on the wrapper. There is no length cap. Do you want one in `CONFIG`? `RaidPost` currently sends one tag and a difficulty. The new payload needs tags, party size, slots, the host role, optional clears, optional gear, and a title. That remote is T-012, so it was not edited. A single tag string still validates.
11. Guided is refused as the difficulty `"guided"` and as `guided == true` on any listing. Fracture and any other name are refused as not a premade difficulty. Is the extra `guided` flag the right shape for "out of scope"?
12. The clear count should be `raidClears` once T-038 adds it. No new profile field. This path does not read `raidFinderCooldownUntil`. Is the total clear count right, or do you want clears of this raid or this difficulty?
13. `roleTargets[8]` is 1 tank / 1 healer / 6 DPS, including the T-041 hooks paragraph.
14. `join` must not call `queue`. A full listing does not launch by itself. Hard and Shardbreaker cannot go through `Raids.difficulty`. Level 15, Story-before-Normal, and `Raids.roleOk` stay out of this module. Should a full premade launch immediately or wait for a ready check, and should post and join still call `roleOk`?

### T-045 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `Trading.luau`, `MarketBoard.luau`, `RaidMarks.luau`, `RaidLootTrade.luau`, `Remotes.luau`, `RateLimiter.luau`, or any other T-012 file. The T-009 loot table was not edited. `RaidLuck` is pure and ready to call. It requires `RelicSets` so a piece id counts as gear. It does not require `Raids`, `RaidMarks`, or `RaidLootTrade`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires `RaidLuck` yet, so this branch does not change a live run. No build stamp. No remote. No DataStore. Nothing here costs Robux. The T-045 row is `done` on #53. Wiring is T-049.

Thresholds are `RaidLuck.CONFIG`. `stepPct` is 0.1. `maxBonus` is 0.6, a placeholder. Six dry clears fill the bonus. Do not hardcode those numbers beside the module. The stored bonus is a fraction. The add is done in millionths, so three steps land on 0.3. There is no RNG in this module. The caller rolls.

`RaidLuck.DIFFICULTIES` is story, normal, hard, and shardbreaker. Strings are trimmed and lowercased. `" Story "` is story. Fracture, guided, and any other name are refused. Hard and shardbreaker are accepted here even though `Raids.DIFFICULTIES` is still story and normal. The bonus is one number per difficulty on one player's record. Story does not raise Normal. `bossId` is not read, so the Twins and Sapwell share the Story bonus.

`RaidService.luau` is not the live grant. The live call is `Raids.applyClear` inside the Heartwood boss mutate in `DungeonService.luau` (`enemy.boss`, Heartwood, `run.practice ~= true`). That file is yours. When you wire this, require the module next to `Raids`:

```lua
local RaidLuck = require(ReplicatedStorage.Shared.RaidLuck)
```

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `chance(base, state, difficulty)` | you are about to roll gear | `ok == true` and `chance` in 0..1. `bonus` is the fraction added to `base`. |
| `settle(state, outcome)` | the clear's grants are known | `ok == true` is the only signal to store `state`. The input record is not written. |
| `classify(drop)` | you want to know if one drop is gear | `gear == true` means it resets. `ok == false` means the drop is unusable. |

`chance` reads `state.bonus[difficulty]`. A missing record, a missing `bonus`, and a missing key are 0. A stored value above `maxBonus` is read as the cap. The returned chance is `base + bonus`, then clamped to 0..1. A base of -0.1 with a 0.6 bonus is 0.5. A base of 0.95 with a 0.6 bonus is 1. A non-finite base is `ERRORS.base`. Pass `Raids.DROP_BASE` (0.2) until T-009 has a real per-item base. This number is the gear roll only. Pets, mounts, titles, dyes, cosmetics, and auras keep their own rates and must not use this chance.

`settle` returns a new `state`. Persist `result.state.bonus` only when `ok == true`. An `ok == false` result is a bad record, a bad difficulty, a bad flag, or a drop the module cannot classify. The caller's table is left alone. Writing the failure would be a guess.

A loot-eligible clear with no gear drop adds `stepPct` on that difficulty, and the sum stops at `maxBonus`. The sixth dry clear lands on 0.6 with `added == true` and `capped == true`. A seventh stays at 0.6 with `added == false`. A gear drop sets that difficulty to 0 (`reset == true`) and leaves the other difficulties alone. `capped` means this clear was allowed to add and the bonus is now at the cap. A skip reports `capped == false`.

`outcome` fields that are read: `difficulty`, `locked`, `removal`, `eligible`, `drops`. Anything else is ignored, including `bossId`, `userId`, and `clears`. `locked` nil means false. `eligible` nil means true. `drops` nil means nothing dropped.

`removal` nil means the player stayed. `"afk"` is the T-027 90s removal. `"kick"` is a T-027 passed vote-kick. `" AFK "` is afk. `"idle"`, `"leave"`, and `"vote"` are refused.

Skips do not add and do not reset, including when `drops` lists gear. The reason order is afk, then lockout, then ineligible. `reason` is omitted when the clear was allowed to change the bonus. `eligible` on the result is true only then.

| outcome | what settle does |
|---|---|
| `removal == "afk"` | `reason = "afk"`. Bonus stays. |
| `locked == true` | `reason = "lockout"`. Bonus stays. A reclear after lockout. |
| `eligible == false` | `reason = "ineligible"`. Practice Grove and any clear that should not roll. |
| a gear drop, and none of the above | that difficulty becomes 0 |
| no gear drop, and none of the above | add `stepPct`, capped at `maxBonus` |

Gear is raid gear, a Heartshard weapon, or a Relic Set piece. `classify` returns gear for those. An excluded kind is a pet, mount, title, dye, cosmetic, or aura: it does not reset, and a dye whose id contains `"heartshard"` stays a dye. Dust, marks, materials, gold, shards, tokens, and emblems do not reset either. A clear that drops only those still takes the +10%. A pet and a piece of gear in the same list resets. A chest string, a bare `"weapon"`, and a Rootvault armor are `ERRORS.drop`, so the bonus does not move. A Relic piece is `RelicSets.isRelic`, including `{ id = "verdant_warden_helm" }` and `{ kind = "Armor", id = "verdant_warden_helm" }`. A Heartshard is `heartshard == true`, family or weaponFamily `"heartshard"`, kind `"heartshard"`, or an id that contains `"heartshard"`. Raid gear is kind `gear`, `raid`, or `raid_gear`, or kind weapon, armor, or accessory with `raid == true` or a raid `source` (`raid`, `heartwood`, `heartwood_story`, `heartwood_normal`, `heartwood_hard`, `heartwood_shardbreaker`, `shardbreaker`). An excluded kind combined with a heartshard flag is refused. Kind and category must match when both are set.

Inside the same `DataService.mutate` that already calls `Raids.applyClear`, after you know the lock and whether this player was removed. Keep the mark lines until T-040. Replace the pity roll. Calling `settle` and leaving the `raidPity` lines in `applyClear` runs two bonuses.

```lua
local removal = nil
if afkRemoved then
	removal = "afk"
elseif voteKicked then
	removal = "kick"
end
local record = { bonus = data.raidLuck }
local locked = lockoutThisBoss
local view = RaidLuck.chance(Raids.DROP_BASE, record, difficulty)
local drops = {}
local rollGear = view.ok == true and removal ~= "afk" and locked ~= true
if rollGear then
	local roll = math.random()
	if roll < view.chance then
		-- T-009 appends the gear item it actually granted.
		-- Do not append the Rare/Epic chest stand-in.
	end
end
-- Pet, mount, title, dye, and cosmetic rolls stay on their own rates.
local settled = RaidLuck.settle(record, {
	difficulty = difficulty,
	locked = locked,
	removal = removal,
	eligible = true,
	drops = drops,
})
if settled.ok == true then
	data.raidLuck = settled.state.bonus
end
```

`lockoutThisBoss` is the same test `applyClear` uses today: this boss, this difficulty, this week. A locked Twins reclear does not grow Story, and a first Sapwell clear that same week still can. `afkRemoved` is `RaidConduct.afk` returning `state == "remove"` for this player before this grant. `voteKicked` is `RaidConduct.tally` returning `passed == true`. The `math.random()` stays in `DungeonService`. Practice Grove already skips `applyClear` because `run.practice ~= true`. Leave that skip. If a later path calls `settle` for practice, pass `eligible = false` and do not roll.

Several gear pieces in one clear read `chance` from the same record, then `settle` once. Settling between those rolls would raise the second roll in the same clear.

**Schema.** HELPER does not edit `Schema.luau`. One new field. Add it on whichever version is free when you wire this. Version 21 is current.

```lua
raidLuck: { [string]: number }, -- difficulty -> bonus fraction, 0 to maxBonus. Missing key is 0.
```

`template()` and the migrate set `raidLuck = {}`. A missing field is an empty bonus, so a call before the migrate does not throw. It also does not persist until you write `settled.state.bonus`. Do not reuse `raidPity`. That map is a miss count per `bossId:difficulty`, and `Raids.applyClear` still writes it. This bonus is a fraction per difficulty. Sanitizing a non-table to `{}` is enough. Leave a non-finite or negative entry in place: `chance` and `settle` return `ok == false` for that record, and the hook above skips the write. Turning the bad entry into 0 would wipe the streak. An unknown key, including `fracture`, also refuses the record. `"Story"` and `"story"` together refuse it. A stored fraction above `maxBonus` is returned as the cap, including on a lockout skip, so persisting `ok == true` pulls 0.9 down to 0.6.

This module does not read a clear count. The beta clear count on the other raid rows is total Heartwood `raidClears` once T-038 adds it. Luck does not scale with that number. No second clear counter.

`tests/run.luau` requires `./RaidLuck.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. The bonus is per difficulty. A dry Story clear does not raise Normal. I would keep it that way: Story gear and Normal gear are different chases. Should one bonus be shared across difficulties instead?
2. `bossId` is ignored, so every Heartwood boss on Story shares one bonus. Live `raidPity` is per boss (`bossId:difficulty`), so a Twins miss does not help Sapwell today. Should this stay per difficulty, or match the live per-boss key?
3. `maxBonus` is 0.6. Live `Raids.DROP_CAP` is 0.8 on a 0.2 base, which is the same 0.6 of bonus, and the total chance stops at 0.8. Here the bonus stops at 0.6 and `chance` still clamps the sum to 1, so a base above 0.4 can reach 1. Should the cap stay on the bonus, or should the total chance stay at 0.8?
4. A gear drop resets only that difficulty. Should a Heartwood drop reset every difficulty?
5. An AFK removal and a lockout reclear do not add and do not reset, even when `drops` lists gear. A passed vote-kick still settles: a dry clear adds, a gear drop resets. Should a kick skip the way AFK does?
6. Pets, mounts, titles, dyes, cosmetics, auras, dust, marks, and materials do not reset. A clear that drops only those still adds 10%. Is a dust-and-pet clear a dry gear clear?
7. A Relic piece matches `RelicSets.isRelic`. A Heartshard is a flag, a family, or an id that contains `"heartshard"`. Raid gear is kind `gear` / `raid` / `raid_gear`, or weapon, armor, or accessory with a raid source. A bare `"weapon"`, a Rootvault armor, and a `"chest"` are refused. Are those the shapes T-009 will pass?
8. `eligible = false` is the Practice Grove switch. Fracture is refused. Hard and shardbreaker are accepted now. Should fracture track a bonus, and is `eligible = false` the right practice switch?
9. The suggested field is `raidLuck`, a map of difficulty to the bonus fraction. `raidPity` stays until you stop writing it. Version 21 is current. Should the migrate start everyone at `{}`, or copy something out of `raidPity`?
10. Today's `applyClear` grants a chest. A chest is refused, so passing `"chest"` fails the settle, and passing no drops would add 10% on every loot-eligible clear, including chest grants. Should this call wait until T-009 grants real gear, Heartshard weapons, and Relic pieces?
11. One boss with several gear rolls should read `chance` from the same record and `settle` once. Should each piece settle on its own?
12. A stored bonus above `maxBonus` comes back as the cap on any `ok == true` settle, including a lockout skip. Persisting that pulls 0.9 down to 0.6. `chance` already uses the cap. Should a skip leave the stored number alone?

Ghost's answers are on T-049. Short form: the bonus stays per difficulty, not per boss. The cap stays on the bonus (`maxBonus` 0.6) and the sum clamps to 1. A gear drop resets only that difficulty. Dust, marks, materials, pets, and cosmetics are a dry clear. Fracture tracks no bonus. `eligible = false` is the Practice Grove switch. `raidLuck` is added on schema version 22, and template plus migrate start at `{}` with nothing copied from `raidPity`. Do not wire this until T-009 grants real raid gear, Heartshard weapons, and Relic pieces; until then `raidPity` stays live. Several gear rolls in one clear read `chance` once and `settle` once. A vote-kicked or AFK-removed player gets no gear roll and `settle` is not called for them, which overrides the snippet above. A skip that pulls a stored value above the cap down to the cap is fine to persist.

### T-050 hooks for GHOST

HELPER did not edit `DungeonService.luau`, `RaidService.luau`, `Raids.luau`, `Schema.luau`, `CombatHud.luau`, `SessionRecap.luau`, `RaidConduct.luau`, `Remotes.luau`, `RateLimiter.luau`, or any other T-012 file. `RaidRecap` is pure and ready to call. It does not require `RaidConduct`, `Raids`, or `SessionRecap`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires `RaidRecap` yet, so this branch does not change a live run. No build stamp. No remote. No DataStore. No TextService. Nothing here costs Robux. The T-050 row stays `claimed`. Wiring is yours.

The live Heartwood grant is still the per-player boss mutate in `DungeonService.damageEnemy`. That file has no shared roster and no mechanic counter, and it is not on this row. `RaidService` has no end-of-run call. Keep the tallies on the in-memory raid run and call `recap` once when the run ends. Do not append these lines to `SessionRecap.line` or `CombatHud.victoryBody`. That card stays the T-016 session line (level, epics, set percent).

When you wire this, require the module next to the other raid rules:

```lua
local RaidRecap = require(ReplicatedStorage.Shared.RaidRecap)
```

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `panel(member)` | you want one player's private panel | `ok == true` and that player's lines, tips, and own numbers. |
| `give(members, kudos, fromUserId, toUserId)` | a player clicks kudos | `ok == true` is the only signal to store `kudos`. The input list is not written. |
| `publicView(members, kudos)` | you are about to broadcast the party view | `ok == true` and `public`. Kudos and MVP awards only. |
| `recap(run)` | the run has ended | `panels[userId]` for each player, plus the same `public` view. |

`run` fields that are read: `members`, `kudos`. Anything else is ignored, including `bossId` and `difficulty`. Boss ids live on each failure. `kudos` nil means nobody has given one.

Send `panels[userId]` only to that player. Send `public` to the party, and only when `ok == true`. Do not put the whole `recap` result on one remote. `public` has no damage, no healing, no deaths, no mechanic counts, no tips, and no private lines.

A roster error (`ok == false` and `panels` empty) means send nothing. A malformed kudos list still returns the private panels, with `ok == false` and an empty `public`. Send those panels. Do not broadcast `public` until the list is fixed.

**Private panel.** `panel` reads `userId`, `damage`, `healing`, `deaths`, `mechanics`, `failures`, and `removal`. A missing damage, healing, or deaths value is 0. The three stat lines are always there. A mechanic line is there only when that count is at least 1. The lines have no period, matching the design example.

| count | line |
|---|---|
| damage 1200 | `You dealt 1200 damage` |
| healing 400 | `You healed 400` |
| deaths 0, 1, 2 | `You died 0 times`, `You died 1 time`, `You died 2 times` |
| soak 1, soak 6 | `You soaked 1 time`, `You soaked 6 times` |
| interrupt 1 | `You interrupted 1 time` |
| stack 2 | `You stacked 2 times` |
| add 1, add 3 | `You killed 1 add`, `You killed 3 adds` |

`mechanics` is a map, not an array. Keys are `soak`, `interrupt`, `stack`, and `add` from `RaidRecap.MECHANICS`. Strings are trimmed and lowercased, so `" Soak "` is soak. `"soaks"` is `ERRORS.mechanic`. A second key that normalizes to the same mechanic is also `ERRORS.mechanic`. A negative, fractional, or non-number count is `ERRORS.mechanics`. The returned `mechanics` map always has all four keys. Zeros stay on the map and stay off the lines.

`failures` is a dense array of `{ bossId, mechanic, count? }`. A missing count means the failure happened. `count` 0 is skipped. A negative count is `ERRORS.failure`. Tips come from `CONFIG.tips[bossId][mechanic]`. Keys are trimmed and lowercased. Duplicates collapse. The list is sorted by boss id, then mechanic id, and cut to `CONFIG.tipLimit` (2). A boss with no row, including `grandmother_gnarl`, adds no tip and does not fail the panel. A clean run gets no tips. The placeholder bosses are the wing ids in `Raids.WINGS`: `twins`, `sapwell`, `galecrown`, `awakened`. Galecrown's gust tip is `Try using Blink on Galecrown's Gust.`

**AFK.** This matches T-027. `RaidConduct.afk` returns `state == "remove"` for the 90s removal (`AFK_STATE`). Pass that result table as `removal`, or pass the string `"afk"` or `"remove"`. `" AFK "` and `" Remove "` are the same. `ok == false` on that table is `ERRORS.removal`, including when `state` is `"remove"`, so an invalid check is not treated as a removal. `state` `"ok"`, `"warning"`, and `"paused"` mean the player is still here (`PRESENT_STATES`). A passed vote-kick is the string `"kick"`. A tally table with `passed` and no `state` is refused. `"idle"`, `"leave"`, and `"vote"` are refused.

An AFK player still gets a private panel, with `afk == true`, their own numbers, and their own tips. They are skipped for every MVP, and they cannot give or receive kudos. A warning, a paused cutscene, and a vote-kick stay in kudos and MVP. The public view does not list who was AFK.

**MVP.** One award per mechanic type, in `MECHANICS` order. The winner handled the most. A tie goes to the lower `userId`, so roster order does not matter. A count of 0 is not a candidate. If every eligible count is 0, or only an AFK player handled that mechanic, that type has no award. The award is `{ mechanic, userId }`. The count is not on it. There is no damage award and no healing award.

**Kudos.** One per player per run, to another member of that run. The stored row is `{ fromUserId, toUserId }`. Extra fields on the input, including a damage number, are not copied. `give` does not write the caller's list. Store `given.kudos` only when `given.ok == true`. A refused click returns a copy of the previous valid list so you can see it, and that copy is not the table you passed in.

`give` checks, in order: the roster (stats included), the existing list in strict mode, the two user ids, the giver is in the run, the receiver is in the run, not yourself, the giver is not AFK, the receiver is not AFK, the giver has not already given. The messages are `absentSelf`, `absent`, `selfKudos`, `afkGive`, `afkReceive`, and `already`.

`publicView` and `recap` are the display path. A malformed row or a sparse list fails the public view. A self kudos, an outsider, an AFK kudos, and a second kudos from the same player are omitted. The first legal row from each player is kept, in input order. That is why a kudos given before someone is marked AFK drops out of the party view at the end, and the private panels still build.

```lua
local removal = nil
local afk = RaidConduct.afk({
	now = now,
	lastInputAt = member.lastInputAt,
	inCutscene = member.inCutscene == true,
})
if afk.state == "remove" then
	removal = afk
elseif votePassed then
	removal = "kick"
end

local view = RaidRecap.recap({
	members = {
		{
			userId = player.UserId,
			damage = tally.damage,
			healing = tally.healing,
			deaths = tally.deaths,
			mechanics = {
				soak = tally.soak,
				interrupt = tally.interrupt,
				stack = tally.stack,
				add = tally.add,
			},
			failures = tally.failures,
			removal = removal,
		},
	},
	kudos = run.kudos,
})
local mine = view.panels[player.UserId]
if mine ~= nil and mine.ok == true then
	-- Send `mine` to this player only.
end
if view.ok == true then
	-- Send `view.public` to the party.
end
```

On a kudos click:

```lua
local given = RaidRecap.give(members, run.kudos, fromUserId, toUserId)
if given.ok == true then
	run.kudos = given.kudos
	local party = RaidRecap.publicView(members, run.kudos)
	if party.ok == true then
		-- Send `party.public` to the party.
	end
end
```

There is no RNG. The same input returns the same panels, the same tips, and the same awards. Thresholds and the tip copy live in `RaidRecap.CONFIG`. `tipLimit` is 2. Do not hardcode that number beside the module.

**Schema.** HELPER does not edit `Schema.luau`. No new field is required. The tallies and the kudos list live on the in-memory run for that reserved server. They do not have to survive a rejoin. Version 21 is current. T-049's row already plans `raidLuck` on version 22, so do not take 22 for this.

If you want a lifetime received count, add it on whichever version is free after that:

```lua
raidKudosReceived: number, -- kudos received across runs. template 0. Missing is 0.
```

This module does not read or write that field. Increment it yourself when `give` returns `ok == true`, once per accepted kudos.

`tests/run.luau` requires `./RaidRecap.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. A tie goes to the lower `userId`. I built it that way so a shuffled roster still picks the same player. Should a tie go to whoever joined first instead?
2. MVP types are soak, interrupt, stack, and add, in that order. Gust, spread, pools, and the Lumen shield are tips only, and I did not give them an award. Should each named mechanic get its own MVP?
3. Tips are sorted by boss id, then mechanic id, and cut to `tipLimit` (2). A failure with no CONFIG row adds nothing. A clean run gets no tips. I did not add a general tip. Should the order follow the wings (twins, sapwell, galecrown, awakened), and should a clean run still get one tip?
4. Damage, healing, and deaths are always on the private panel, including 0. A mechanic line appears only at 1 or more. The soak line is `You soaked 6 times`, with no period. Should a 0 stat be left off?
5. AFK is `"afk"`, `"remove"`, or a `RaidConduct.afk` result with `state == "remove"` and `ok ~= false`. A warning, a paused cutscene, and `"kick"` stay in kudos and MVP. A tally table with no `state` is refused. Should a passed vote-kick be left out as well?
6. Kudos are `{ fromUserId, toUserId }` with no message, so this module never calls TextService. Should a kudos carry a short note, and would you filter that note beside the other TextService calls?
7. A public award is `{ mechanic, userId }`. The count stays on that player's panel. There is no damage sort and no healing sort. Should the party line include the count?
8. One call covers whatever stats you pass. `run.bossId` is ignored. Tip keys are the wing ids, not `grandmother_gnarl`. I would call it once at the end of the run. Should each wing get its own panel?
9. No profile field. Stats and kudos live on the in-memory run. A lifetime count would be `raidKudosReceived` on the next free schema version after T-049's version 22. Version 21 is current. Do you want that counter?
10. There is no practice switch. The same functions run if you pass Practice Grove stats. Should practice skip kudos and MVP?
11. Mechanic keys are soak, interrupt, stack, and add. `" Soak "` works. `"soaks"` is refused. A bad tally fails the roster, including a `give` click. Should the plurals be accepted?
12. `give` refuses a bad click. `publicView` drops a stored row that `give` would refuse and keeps the first legal row from that player. A malformed row fails `recap.ok`, empties `public`, and still returns the private panels. A kudos given before an AFK removal drops out of the party view. Should a rule-breaking stored row fail the recap instead of being dropped?
13. Failures are the list you pass. A missing `count` means it happened, and 0 is ignored. I do not infer a missed soak from a low handled count. Should a tip be derived from the tally?

### T-053 hooks for GHOST

HELPER did not edit `RaidService.luau`, `DungeonService.luau`, `Raids.luau`, `Schema.luau`, `RaidConduct.luau`, `RaidRecap.luau`, or any other T-012 file. `RaidLeaderboard` is pure and ready to call. It does not require `RaidConduct`, `Raids`, or `RaidRecap`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires `RaidLeaderboard` yet, so this branch does not change a live run. No build stamp. No remote. No OrderedDataStore. No MemoryStore. No TextService. Nothing here costs Robux. The T-053 row stays `claimed`. Wiring is yours.

Call `submit` once when the raid run ends, with the whole roster. Do not call it from the per-player boss mutate in `DungeonService.damageEnemy`. A second call with the same `runId` is a no-op, so the first player's payload would stick and everyone else would be dropped. Do not append a leaderboard line to `SessionRecap.line` or `CombatHud.victoryBody`. That card stays the T-016 session line. T-052 owns the recap panel. This board is separate.

When you wire this, require the module next to the other raid rules:

```lua
local RaidLeaderboard = require(ReplicatedStorage.Shared.RaidLeaderboard)
```

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `submit(board, record)` | the run has cleared | `ok == true` is the only signal to store `board`. `accepted == true` means this clear took a row. |
| `personalBest(board, userId)` | you want one player's fastest clear | `found == true` and `entry`. That entry may be on any live board. |
| `rankOf(board, userId)` | you want the rank of that fastest clear | `rank` is that row's place on its own difficulty and size. |
| `rankOf(board, userId, difficulty, size)` | you want one board | `rank` is their best row on that key. `" Normal "` is normal. |

`nil` starts an empty board. `{}` does too. A bare array is `ERRORS.board`. Store `result.board` only when `result.ok == true`. A duplicate and a clear that misses the top N are still `ok == true` (the copy has the same rows). A bad record is `ok == false`. If the saved board itself does not parse, `ok == false` and `board` is `{ entries = {} }`. Do not write that over a save you could not read.

`record` fields that are read: `runId`, `difficulty`, `size`, `start` or `startedAt`, `end` or `endedAt`, `duration`, `roster`, `practice`, `removals`. Anything else is ignored. A `removal` field on a roster entry is ignored. Put removals on `removals`.

Checks run in this order: the board, the record type, `runId`, an already stored `runId` (no-op, the rest of the payload is not read), the practice flag, a practice run, difficulty, the clock, the floor, the roster, the size, removals, then an empty credited roster. The first failure is the error you get. A practice Story clear reports practice, not the disabled board.

**Boards.** One table holds every key. A key is difficulty plus party size. Rows come back ordered by difficulty name, then size, then rank. Beta live set is `CONFIG.live`: normal only. Story, Hard, and Shardbreaker are known and return `ERRORS.disabled`. Fracture and Guided are not fastest-clear boards and return `ERRORS.difficulty`. Strings are trimmed and lowercased.

Party size is 4 to 8 (`CONFIG.minParty`, `CONFIG.maxParty`). `size` must equal `#roster`. The roster includes players you then mark removed. A missing `size` uses the roster length. The stored row keeps that size and lists only the credited ids, sorted ascending, so a 5-player group with one kick still ranks on the size-5 board.

**Clock.** Pass `start` and `end`, or the aliases `startedAt` and `endedAt`. Duration is `end - start`. If you also pass `duration`, it has to match that difference exactly. `end` plus `duration` without a start is allowed, and `end` is the clear time. Duration alone is allowed, and that row has no `clearedAt`. A start without an end is `ERRORS.time`. So is a zero, negative, or non-finite time, `end` before `start`, and two aliases that disagree. A positive duration under `CONFIG.floorSeconds` (300) is `ERRORS.floor`. 300 is ranked. The floor is not applied again when a saved row is read, so a later CONFIG change does not make an old row unreadable.

**Credit.** An AFK removal or a passed vote-kick is left off the row. Anyone else on the roster is credited. This matches T-027's shapes and is stricter than T-050: T-050 keeps a vote-kick in kudos, and this board does not.

| removal | credit |
|---|---|
| missing | credited |
| `"afk"`, `"remove"`, `" AFK "` | not credited |
| `RaidConduct.afk` with `state == "remove"` and `ok ~= false` | not credited |
| `"kick"` | not credited |
| a tally with `passed == true` | not credited |
| `state` `"ok"`, `"warning"`, or `"paused"`, or `passed == false` | credited |
| `ok == false`, `"leave"`, `"idle"`, `"vote"` | `ERRORS.removal` |

`AFK_STATE` is `"remove"`. `ok` has to be a boolean when it is present. A warning is still a finisher. A removal whose user id is not on the roster is `ERRORS.absent`. The same user twice is `ERRORS.removalTwice`. A string key such as `"20"` is `ERRORS.userId`. If nobody is left, the error is `ERRORS.empty` and the `runId` is not consumed, so a later legal submit of that id can still rank.

`removals` is either a map of user id to cause, or a dense list of `{ userId, removal }` (or `cause`). A dense list of cause strings is read as a map keyed by those indexes, so do not pass `{ "afk", "kick" }`. User id 1 with a conduct table is the map form. An empty table means nobody was removed.

**Rank.** Sort is shortest duration, then earlier `clearedAt`, then lower `runId`. A row with no `clearedAt` loses a tie to a row that has one. Each difficulty and size keeps `CONFIG.topN` (10) rows. A clear that misses the cut returns `ok == true`, `accepted == false`, `trimmed == true`, and that `runId` is not remembered. The same `runId` already on any key is `duplicate == true` and does not replace a slower time. A positive integer and a string are different ids. `2` and `"2"` can both be on the board. On a tie, numbers rank before strings. `2` beats `10`. `"10"` beats `"2"`. Strings are trimmed and not lowercased. Two players on the same clear share that row's rank. `rank` is 1 for the fastest row.

```lua
local removals = {}
for _, member in ipairs(roster) do
	local afk = RaidConduct.afk({
		now = now,
		lastInputAt = member.lastInputAt,
		inCutscene = member.inCutscene == true,
	})
	if afk.state == "remove" then
		removals[member.userId] = afk
	elseif member.vote ~= nil and member.vote.passed == true then
		removals[member.userId] = member.vote
	end
end

if run.practice ~= true then
	local ranked = RaidLeaderboard.submit(board, {
		runId = run.id,
		difficulty = run.difficulty,
		size = #roster,
		start = run.startedAt,
		["end"] = now,
		roster = roster,
		practice = false,
		removals = removals,
	})
	if ranked.ok == true then
		board = ranked.board
	end
end
```

On a lookup:

```lua
local best = RaidLeaderboard.personalBest(board, player.UserId)
if best.found == true then
	-- best.entry.duration, best.entry.difficulty, best.entry.size
end
local rank = RaidLeaderboard.rankOf(board, player.UserId, "normal", #roster)
if rank.found == true then
	-- rank.rank is 1 for the fastest credited row on that board
end
```

There is no RNG. The same input returns the same board. Thresholds live in `RaidLeaderboard.CONFIG`. Do not hardcode 10 or 300 beside the module.

**Schema.** HELPER does not edit `Schema.luau`. No new field is required. The board is the plain `{ entries }` table. It does not have to live on a profile. Version 21 is current. T-049's row already plans `raidLuck` on version 22, so do not take 22 for this. This module does not call OrderedDataStore or MemoryStore. An in-memory table on one server dies on restart.

`tests/run.luau` requires `./RaidLeaderboard.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. The sanity floor is 300 seconds. A full clear is designed at 20–30 minutes. Is 300 the right floor, or should it sit closer to a real wing?
2. `topN` is 10 for each difficulty and party size. Is that the beta length?
3. Party size is 4 to 8. `size` must equal the roster length, and that roster includes AFK-removed and vote-kicked players. A 5-player group with one kick still ranks on the size-5 board. The stored row lists only the players who finished. Should the key be the number who finished?
4. A backfill is credited when you put them on the roster and leave them out of `removals`. The kicked player has to stay on that same roster to be excluded. Dropping the kicked player and also listing them in `removals` is `ERRORS.absent`. Is the ranked roster the group that pulled, or the group that finished, including a backfill?
5. A clear with nobody left is rejected and does not consume the `runId`. Should that clear still take a row?
6. A `runId` already on any board is a no-op, even when the new time is faster or the payload is practice. A clear that misses the top N is not remembered, so a later submit of that id can still place. Should a missed id stay seen, and should a faster retry replace the row?
7. Times are `start`/`startedAt` plus `end`/`endedAt`, or `duration`. If start and end are both set, duration is `end - start`, and a `duration` field must match exactly. Duration alone is allowed and loses a tie to a row that has an end time. `end` plus `duration` without `start` uses `end` as the clear time. Should a duration-only clear be refused?
8. `personalBest(board, userId)` is the single fastest credited row across every difficulty and size. A shorter 4-player clear beats a longer 8-player clear. `rankOf(board, userId)` is that row's rank on its own board. `rankOf(board, userId, difficulty, size)` is their best row on that key. Two players on the same clear share that row's rank. Should a personal best stay on one board, and should the shown rank be per player instead of per clear?
9. Removals follow T-027. `"afk"`, `"remove"`, or a `RaidConduct.afk` result with `state == "remove"` and `ok ~= false` are AFK. `"kick"` or a tally with `passed == true` is a vote-kick. Both are left off the row. `"ok"`, `"warning"`, and `"paused"` stay on it. `ok == false` is an error. `"leave"` and `"idle"` are errors. A `removal` field on a roster entry is ignored. Should a warning be left off, and should the roster entry's own removal count?
10. Story, Hard, and Shardbreaker are known and switched off in `CONFIG.live`. Fracture and Guided are unknown. Only Normal is live. Should Hard stay unknown until T-007 names it?
11. A run id is a positive integer or a trimmed non-empty string. Numbers rank before strings. `2` beats `10`. `"10"` beats `"2"`. The number `2` and the string `"2"` are different runs. Should run ids be strings only?
12. No profile field. The board is the plain `{ entries }` table the caller keeps. There is no OrderedDataStore in this module. An in-memory table dies on restart. Where should the beta board live?
13. Returned boards keep `entries` only. Other keys on the table you pass are dropped. A bare array is refused. `nil` starts an empty board. Is that the shape you want to store?
14. This module does not rank Fracture level, class combo, or guild progression. Beta is fastest clear only. Confirm those stay out.

### T-057 hooks for GHOST

HELPER did not edit `RaidService.luau`, `DungeonService.luau`, `Raids.luau`, `Schema.luau`, `CombatMath.luau`, `RaidRecap.luau`, or any other T-012 file. `RaidEcho` is pure and ready to call. It does not require `Raids`, `RaidService`, `CombatMath`, or `RaidRecap`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires `RaidEcho` yet, so this branch does not change a live run. No build stamp. No remote. No DataStore. No MemoryStore. No RNG. Nothing here costs Robux. The T-057 row stays `claimed`. Wiring is yours.

Call `wipe` once for each whole-party death after a boss pull has started. Call `reset` when that boss dies, and again when the run ends. Do not call either from the per-player boss mutate in `DungeonService.damageEnemy`. One call per death, with the shared run state. A second `wipe` on the same table before you store `state` counts a second stack. Practice Grove stays on `practice = true` and adds nothing. The live fight is in `DungeonService`, which this row does not list. `RaidService` has no wipe call today.

When you wire this, require the module next to the other raid rules:

```lua
local RaidEcho = require(ReplicatedStorage.Shared.RaidEcho)
```

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `fresh()` | the run is created | `{ stacks = 0 }`. A new table every call. |
| `wipe(state, ctx)` | the party might have wiped | `ok == true` is the only signal to store `state`. `counted == true` means this was a Story wipe. `added == true` means `stacks` grew by one. |
| `bonus(state, difficulty)` | you want the party fraction | `bonus` is a fraction from 0 to 0.25. `active == true` means Story and the fraction is above 0. |
| `apply(stat, state, difficulty)` | you scale one player stat | `value` is `base * multiplier`. `multiplier` is `1 + bonus` (1 to 1.25). |
| `reset(state, ctx)` | the boss dies, or the run ends | `ok == true` stores `{ stacks = 0 }`. `reason` is `"kill"` or `"end"`. |

`nil` starts at 0 stacks. `{}` does too. A non-table is `ERRORS.state`. Store `result.state` only when `result.ok == true`. A skip (`counted == false`) is still `ok == true`: the copy has the same `stacks`. If the saved record itself does not parse, `ok == false` and `state` is `{ stacks = 0 }`. Keep the previous save.

`wipe` reads `difficulty`, `practice` or `practiceGrove`, `pullStarted` or `pulled`, and the party. The party is `wholeParty` or `partyDead`, or `alive` / `living` together with `party` / `partySize`. Anything else on `ctx` is ignored, including `now`, `bossId`, and `userId`. `bonus` and `apply` take the difficulty as their own argument. The state does not remember it.

Checks on `wipe` run in this order: the record, the context type, the difficulty, the practice flags, the pull flags, the party flags. The first failure is the error you get. After that, a real event can still be skipped. Skip order is practice, then a pull that has not started, then a partial death, then a difficulty that never gets Echo.

**Stacks.** One number for the whole party. There is no per-player map. Returned states keep `stacks` only. A `userId` or `bossId` on the table you pass is dropped. `bonus` reads that count. Story pays `CONFIG.perWipe` (0.05) times the count, and `CONFIG.cap` (0.25) stops the fraction. Five counted wipes reach 0.25. The sixth stays `counted` with `added == false` and `capped == true`. A stored count above 5 still pays 0.25 and does not grow. Normal, Hard, Shardbreaker, and Fracture are known, return `bonus == 0`, and a qualifying death there is `reason == "difficulty"`. `" Story "` is story. Strings are trimmed and lowercased.

**What counts.** A counted wipe is Story, the boss pull has started, the whole party is dead, and the run is not Practice Grove.

| ctx | result |
|---|---|
| `pullStarted == true`, `wholeParty == true`, `practice` omitted or false, difficulty story | one stack, until the cap |
| `alive == 0` and `party >= 1` (or `living` / `partySize`) | same as `wholeParty == true` |
| `practice == true` or `practiceGrove == true` | `reason == "practice"`, stacks unchanged |
| `pullStarted` missing or false | `reason == "pull"`, stacks unchanged |
| `wholeParty == false`, or `alive >= 1` | `reason == "partial"`, stacks unchanged |
| normal, hard, shardbreaker, fracture, after a real wipe shape | `reason == "difficulty"`, stacks unchanged |
| `guided`, `fracture1`, a blank difficulty | `ERRORS.difficulty` |

A missing pull flag means the pull has not started. A missing practice flag means this is not Practice Grove. A missing party signal is `ERRORS.party`: pass the boolean or both counts. `party == 0`, a fractional count, or `alive > party` is an error. Two aliases that disagree (`practice` true and `practiceGrove` false, or `wholeParty` false while `alive == 0`) are `ERRORS.disagree`. `"guided"` is not a difficulty. An exact `"fracture"` is known and pays nothing.

**Apply.** Pass the unbuffed number. `apply` multiplies whatever you give it, so a second call on the buffed result compounds. Keep the base damage, the base heal, and the base max HP on the combat record, and pass those bases after every wipe and every reset.

| kind | canonical | accepted text |
|---|---|---|
| damage | `damage` | `"damage"` |
| healing | `healing` | `"healing"`, `"heal"` |
| max HP | `maxHp` | `"maxHp"`, `"max HP"`, `"max_hp"`, `"max_health"` |

`kind`, `stat`, and `name` are the same field. `value`, `amount`, and `base` are the same number. Two of them that disagree are `ERRORS.disagree`. `"health"`, `"hp"`, `"currentHp"`, `"bossDamage"`, and `"defense"` are `ERRORS.kind`, and `value` comes back unchanged. A negative, NaN, or infinite number is `ERRORS.value`. Zero stays zero. This module does not round max HP and does not read current HP.

**Reset.** `"kill"`, `"boss"`, and `"boss kill"` are a boss kill. `"end"`, `"run"`, and `"run end"` are the run ending. Both store `{ stacks = 0 }`. `"wipe"` and `"reset"` are `ERRORS.reason`, and the stacks stay. Pass a string or `{ reason = "kill" }` or `{ kind = "end" }`. `cleared == true` means the previous count was above 0. A changed `bossId` on `wipe` does not clear stacks. Call `reset` yourself between bosses if each boss starts at 0.

```lua
run.echo = RaidEcho.fresh()

local wiped = RaidEcho.wipe(run.echo, {
	difficulty = run.difficulty,
	practice = run.practice == true,
	pullStarted = run.pullStarted == true,
	alive = aliveCount,
	party = #roster,
})
if wiped.ok == true then
	run.echo = wiped.state
	-- One party readout. Hidden while wiped.bonus is 0.
	-- Recompute damage, healing, and max HP from the unbuffed bases.
end

local killed = RaidEcho.reset(run.echo, "kill")
if killed.ok == true then
	run.echo = killed.state
	-- Restore max HP from the unbuffed base. The fraction is 0.
end
```

On a hit, a heal, or a max-HP publish:

```lua
local dealt = RaidEcho.apply({
	kind = "damage",
	value = baseDamage,
}, run.echo, run.difficulty)
if dealt.ok == true then
	damage = dealt.value
end
```

Use `"healing"` for a player heal and `"maxHp"` for max HP. The same `run.echo` is the whole party, including a backfill who joins on a later pull. There is no RNG. The same input returns the same state. Thresholds live in `RaidEcho.CONFIG`. Do not hardcode 0.05 or 0.25 beside the module.

**Schema.** HELPER does not edit `Schema.luau`. No new field is required. The state is the plain `{ stacks }` table on the in-memory run. It does not have to live on a profile. Version 21 is current. T-049's row already plans `raidLuck` on version 22, so do not take 22 for this. An in-memory table on one server dies on restart.

`tests/run.luau` requires `./RaidEcho.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. Stacks stay until `reset`. The recommended wire calls `reset(..., "kill")` on each boss kill and `reset(..., "end")` when the run ends, so the next boss starts at 0. A changed `bossId` does not clear stacks. Call `reset` only on run end if the buff should last the whole run. Which one is the Story Echo?
2. The state is one party `stacks` count, with no per-player map. A backfill, including an SOS flare join, reads that same table and inherits the current buff. Confirm a backfill inherits the stacks.
3. Echo stays off the T-050 private panel and off the public kudos view. Show one party readout during the fight (`bonus` 0, 0.05, 0.10, 0.15, 0.20, 0.25). Confirm the RaidRecap panel does not list it.
4. The catch-up rule (a new raid gives the old one a permanent Echo) is not in this module. Beta is the wipe stack only. Confirm the permanent Echo stays out.
5. Difficulty `"story"` receives Echo. `"guided"` is not a difficulty and returns `ERRORS.difficulty`. A `guided` field on the wipe context is ignored. Confirm a Guided Story run still gets Echo.
6. Only the exact token `"fracture"` is known, and it pays nothing. `"fracture1"` is `ERRORS.difficulty`. Confirm one token covers every Fracture level.
7. The fifth counted wipe is `added == true` and `capped == true` (fraction 0.25). A later counted wipe stays `counted` with `added == false`. A stored count above 5 still pays 0.25 and does not grow. Confirm the cap stops the count there.
8. A counted wipe is the whole party dead after `pullStarted`. Practice Grove, a death before the pull, and a reset while someone is still alive do not count. Confirm a deliberate boss reset with someone alive is not a wipe.
9. When several skip rules match, the reason is practice, then pull, then partial, then difficulty. A Practice Grove wipe on Normal reports `practice`. A Normal partial after the pull reports `partial`. A real Normal wipe reports `difficulty`. Confirm that order.
10. Player damage, healing, and max HP share `1 + bonus`. `"health"`, `"hp"`, and `"currentHp"` are refused so current HP is not scaled. Boss damage and defense are refused. Max HP is not rounded here. `apply` multiplies the number you pass, so pass the unbuffed base. Confirm those three stats, that you floor max HP at the call site, and whether a full bar refills when Echo raises max HP. `CombatMath.luau` was not edited.
11. Difficulty is an argument on every call and is not stored. A Normal call returns 0 even when `stacks` is 5. Confirm the caller passes the run difficulty each time.
12. Each `wipe` call can add one stack. There is no pull id, so two calls for the same death add two stacks. The caller dedupes. Confirm.
13. No profile field. `{ stacks }` lives on the in-memory run and dies on restart. No clock is read. A `now` field is ignored. Confirm that home for the beta state.
14. A phase change does not call `reset`. Only a boss-kill or run-end reason clears stacks. `"wipe"` and `"reset"` are refused as reset reasons. Confirm phases leave the stacks in place.
15. `"heal"` is healing. `"max HP"`, `"max_hp"`, `"max_health"`, and `"maxHp"` are max HP. `"health"` is refused. Confirm those aliases.

Ghost's answers for the wire are on T-059. Stacks are per boss: reset on that boss's kill and again when the run ends. A backfill inherits the party's current stacks. While stacks are above 0, RaidHud shows one "Echo +X%" chip. A RaidRecap line is optional and not required. Pass unbuffed bases to `apply` every time. Do not edit `RaidEcho.luau`.

### T-060 hooks for GHOST

HELPER did not edit `RaidService.luau`, `DungeonService.luau`, `Raids.luau`, `Schema.luau`, `CombatMath.luau`, `RaidEcho.luau`, `Remotes.luau`, or any other T-012 file. `RaidPractice` is pure and ready to call. It does not require `Raids`, `RaidService`, `DungeonService`, `RaidEcho`, `RaidMarks`, `RaidLuck`, `RaidLeaderboard`, or `RaidRecap`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires `RaidPractice` yet, so this branch does not change a live run. `RaidService.practice` still launches a lootless Story run. The `RaidPractice` remote still calls that function with a wing and a phase. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. Cost is 0. The T-060 row stays `claimed`. Wiring is yours.

Call `fresh` when a Practice Grove session starts. Call `jump` for a phase the player picks. Call `setSlow` when they turn slow time on or off, and multiply your own timers by `scale`. Call `toggle` when they switch one mechanic. Call `note` for damage, a death, or a mechanic hit. Call `rewards` at the end and grant nothing. Do not call `Raids.applyClear`, `RaidMarks.earn`, or `RaidLeaderboard.submit` for this session. Do not call `RaidEcho.wipe` for it either. Practice Grove is not a clear, a lockout, a Marks payout, or a leaderboard row.

When you wire this, require the module next to the other raid rules:

```lua
local RaidPractice = require(ReplicatedStorage.Shared.RaidPractice)
```

**What each call does.**

| call | when | what it returns |
|---|---|---|
| `fresh(ctx)` | the sandbox starts | `ok == true` is the only signal to store `state`. `cost` is 0. |
| `jump(state, phase)` | the player jumps | `ok == true` stores `state`. `phase` is the integer you asked for. |
| `setSlow(state, on)` | slow time is switched | `ok == true` stores `state`. `scale` is 0.75 or 1. |
| `scale(state)` | you need the multiplier | the number 0.75 or 1. This call returns a number, not a table. |
| `toggle(state, mechanicId, enabled)` | one mechanic is switched | `ok == true` stores `state`. The id is the trimmed text you passed. |
| `note(state, event)` | damage, a death, or a hit | `ok == true` stores `state`. Exactly one of those three. |
| `rewards(state)` | the session ends | loot lists stay empty. `marks`, `dust`, and `cost` are 0. |

`fresh` starts `{ bossId, difficulty, phase = 1, slow = false, dummies = true, mechanics = {}, damage = 0, deaths = 0, hits = {} }`. It requires `ctx.unlocked == true`. Store `result.state` only when `result.ok == true`. A failure does not write the input. When the record you passed is readable, the failure `state` is a normalized copy and the phase, the record, and the switches stay as they were. When the record itself does not parse, `state` is a blank shell (`bossId == ""`). Keep the previous save either way.

`fresh` checks run in this order: the context type, the boss, the difficulty, the unlock flag, the dummy flag. The first failure is the error you get. `ctx.phase`, `ctx.slow`, `ctx.damage`, `ctx.deaths`, `ctx.now`, and `ctx.userId` are ignored. The session always starts at phase 1 with slow off and an empty record.

| ctx | result |
|---|---|
| `bossId` or `boss` is twins, sapwell, galecrown, or awakened, difficulty is story, normal, hard, or shardbreaker, `unlocked == true` | a new session, `cost == 0` |
| `" Twins "` or `" Awakened "` | that boss id, trimmed and lowercased |
| `bossId` and `boss` name two different bosses | `ERRORS.disagree` |
| missing boss, `"grandmother"`, `"dummy"`, `"heartwood"` | `ERRORS.boss` |
| `"fracture"`, `"guided"`, `"fracture1"`, `"shard-breaker"`, a blank difficulty | `ERRORS.difficulty` |
| `unlocked == false` | `ERRORS.unlocked`, and `state.bossId == ""` |
| `unlocked` missing or not a boolean | `ERRORS.unlock` |
| `dummies` omitted | `dummies == true` |
| `dummies == false` | the flag starts false and stays until a new `fresh` |
| `dummies` is any other value | `ERRORS.dummies` |
| `ctx` is not a table | `ERRORS.ctx` |

Boss ids are `twins`, `sapwell`, `galecrown`, and `awakened`. Difficulties are story, normal, hard, and shardbreaker. Fracture and guided are not difficulties. `" Story "` is story. Strings are trimmed and lowercased. Dummies are the `dummies` flag, not a boss.

**Phases.** `jump(state, phase)` moves to an integer from 1 through `CONFIG.phases` (3). On shardbreaker the top is `CONFIG.shardbreakerPhases` (4). Phase 4 on story, normal, or hard is `ERRORS.phase`, and the copy stays on the old phase. `0`, a fraction, a string, and a missing phase are the same error. Jumping to the current phase is `ok == true` and returns a new table. A stored phase the difficulty cannot hold is `ERRORS.state`, not `ERRORS.phase`, and the shell is blank. The jump does not reset damage, deaths, hits, mechanic overrides, slow, or dummies.

**Slow.** `setSlow(state, true)` selects `CONFIG.slowScale` (0.75). `setSlow(state, false)` selects 1. No other scale exists. `0.5`, `1`, and `"true"` are `ERRORS.slow`, and the copy keeps the previous flag. `scale(state)` returns that same number: 0.75 when the stored `slow` flag is true, and 1 otherwise. A record that does not parse returns 1. Call `scale` on a state you stored. Slow does not reset the record. The session does not start slowed.

**Mechanics.** There is no frozen catalog. T-007 owns Hard mechanic design. `toggle` stores an override for a non-empty id. The id is trimmed and otherwise kept as the caller spelled it, so `"Gust"` and `"gust"` are different keys. A missing key means the mechanic is on. `mechanics[id] == true` is also on. Only `false` is off. Treat `session.mechanics[id] ~= false` as on. An empty id is `ERRORS.mechanic`. `enabled` must be a boolean. `"false"` and `nil` are `ERRORS.enabled`. A toggle does not reset the record.

**Notes.** One event does one thing. Damage adds a non-negative finite amount, and 0 is allowed. A death adds 1. A hit adds 1 to `hits[mechanicId]`. A `deaths` or `hits` count on the event is not a batch. `now` and `userId` are ignored.

| kind | canonical | accepted text |
|---|---|---|
| damage | `damage` | `"damage"`, or `damage` / `amount` with no kind |
| death | `death` | `"death"`, `"dead"`, or `death = true` |
| hit | `hit` | `"hit"`, `"hits"`, `"mechanic"`, or `mechanicId` / `mechanic` / `hit` |

`kind` and `note` are the same field. `damage` and `amount` are the same number. `mechanicId`, `mechanic`, and `hit` are the same id. Two of them that disagree are `ERRORS.disagree`. A negative, NaN, or infinite amount is `ERRORS.damage`. A hit still records when that mechanic is toggled off. This module does not spawn the mechanic. The note does not change phase, slow, dummies, or the override map, except to add the hit count.

**Rewards.** `rewards(state)` stays empty after every note. `gear`, `materials`, `pets`, `titles`, and `cosmetics` are new empty tables each call. `marks` is 0. `dust` is 0. `cost` is 0. `clear`, `lockout`, and `leaderboard` are false. A record that does not parse is `ok == false` and the lists are still empty. Do not grant from this table.

```lua
local started = RaidPractice.fresh({
	bossId = bossId,
	difficulty = "story",
	unlocked = unlocked == true,
})
if started.ok == true then
	session = started.state
end

local jumped = RaidPractice.jump(session, phase)
if jumped.ok == true then
	session = jumped.state
end

local slowed = RaidPractice.setSlow(session, true)
if slowed.ok == true then
	session = slowed.state
	-- Multiply your cast and telegraph times by slowed.scale (0.75).
	-- RaidPractice.scale(session) is the same number. Off is 1.
end

local switched = RaidPractice.toggle(session, mechanicId, false)
if switched.ok == true then
	session = switched.state
end
-- Run the mechanic when session.mechanics[mechanicId] ~= false.

local noted = RaidPractice.note(session, { damage = dealt })
if noted.ok == true then
	session = noted.state
end
-- { death = true } adds one death. { mechanicId = id } adds one hit.

local loot = RaidPractice.rewards(session)
-- loot.cost == 0, loot.marks == 0, loot.clear == false, loot.leaderboard == false.
```

The live button sends `RaidPractice` with wing 1 and phase 1. `RaidService.practice` floors a non-number to 1 and launches Story with `practice = true`. Leave that function as it is until the wire. `Raids.WINGS` is 1 `twins`, 2 `sapwell`, 3 `galecrown`, 4 `awakened`. Pass the boss id into `fresh`, then `jump` to the phase. A Story phase 4 fails closed here. The live floor does not.

`DungeonService.grant` already returns before loot when `run.practice == true`. The Heartwood boss mutate skips `Raids.applyClear` on that flag. Keep both guards. There is no RNG. The same input returns the same state. Thresholds live in `RaidPractice.CONFIG`. Do not hardcode 0.75, 3, or 4 beside the module.

**Schema.** HELPER does not edit `Schema.luau`. No new field is required. The state is the plain session table. It does not have to live on a profile. An in-memory table on one server dies on restart. Version 21 is current. Do not take a schema version for this record.

`tests/run.luau` requires `./RaidPractice.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. The guild perk "cheaper Practice Grove" has no price in this module. Cost is 0 on `fresh` and on `rewards`. There is no discount field and no Robux product. The sandbox stays free. Confirm a later perk does not add a gold or Robux price here.
2. `RaidService.practice` still launches a lootless Story run. This module also accepts normal, hard, and shardbreaker. Confirm live practice stays Story-only until you wire the other difficulties.
3. Mechanic ids stay caller-supplied. There is no frozen catalog. T-007 owns Hard mechanic design. A missing id means the mechanic is on, and a stored `false` turns it off. Confirm ids stay caller-supplied.
4. `scale` returns 0.75 or 1. No enrage number lives here. Confirm whether 0.75x should scale an enrage timer at the call site, or only cast time and telegraphs.
5. The record is the plain state table. No profile field. Confirm it stays on the in-memory session and dies on restart.
6. The live `RaidPractice` remote passes a wing number and a phase number into `RaidService.practice`. This module takes a boss id. `Raids.WINGS` is 1 `twins`, 2 `sapwell`, 3 `galecrown`, 4 `awakened`. Confirm that map when you wire it. `Remotes.luau` was not edited.
7. `fresh` requires `unlocked == true`. This module does not know which bosses the player has cleared. Confirm the wire passes that flag, and a locked boss never starts a session.
8. Fracture and guided are not difficulties. `"fracture"`, `"guided"`, `"fracture1"`, and `"shard-breaker"` return `ERRORS.difficulty`. Confirm they stay out.
9. Dummies default to true. `fresh` accepts `dummies = false`. There is no setter after the session starts. `"dummy"` is not a boss id. Confirm the flag can start false, and that a later toggle is not required for beta.
10. A phase jump keeps damage, deaths, hits, mechanic overrides, the slow flag, and dummies. Slow does not reset the record. Confirm a jump should not turn mechanics back on.
11. Phase 4 is legal only on shardbreaker. Story, normal, and hard stop at `CONFIG.phases` (3). The live `practice` function floors any number and does not reject phase 4. Confirm the wire uses `jump` so a Story phase 4 is refused.
12. `note` adds one death per call and one hit per call. A `deaths` or `hits` count on the event is not a batch. Damage adds the non-negative finite amount, including 0. Confirm.
13. A hit still records when that mechanic is toggled off. This module does not spawn mechanics. Confirm the caller skips a mechanic whose override is false, and may still `note` a hit if one lands.
14. Mechanic ids are trimmed and then stored as the caller spelled them. `"Gust"` and `"gust"` are different keys. Confirm they stay case-sensitive.
15. `rewards` is empty after every note: no gear, Marks, dust, materials, pets, titles, or cosmetics. `clear`, `lockout`, and `leaderboard` stay false. Cost stays 0. Confirm the wire does not call `Raids.applyClear`, `RaidMarks.earn`, or `RaidLeaderboard.submit` for a practice session.
16. `RaidEcho` already skips `practice = true`. This module does not call it. Confirm a Practice Grove wipe does not call `RaidEcho.wipe`.
17. Slow starts off. `scale` is 1 until `setSlow(state, true)`, which selects 0.75. A number such as 0.5 or 1 is `ERRORS.slow`. Confirm the sandbox does not start slowed, and that no other scale should exist.
18. One session is one boss and one difficulty. `jump` does not change them. `fresh` ignores `ctx.phase`, `ctx.slow`, `ctx.damage`, and `ctx.deaths` and always starts at phase 1 with slow off and an empty record. A different boss is a new `fresh`. Confirm.
19. Store `state` only when `ok == true`. A failure of a readable record returns a copy and does not write the input. A record that does not parse returns a blank shell (`bossId == ""`) instead of that bad table. Confirm the wire keeps the previous save when `ok ~= true`.
20. The record has one damage total, one death total, and one hit map. There is no per-player split. The live practice launch is one player. Confirm the beta record stays a single total.
21. `scale` on a record that does not parse returns 1. Confirm you only call it with a stored state, and that 1 means full speed rather than an error.
22. There is no clock and no duration on the record. A `now` field is ignored. Confirm practice time is not a leaderboard time and not an enrage timestamp.
23. Boss ids are `twins`, `sapwell`, `galecrown`, and `awakened`. `"grandmother"`, `"dummy"`, and `"heartwood"` are `ERRORS.boss`. Confirm those four ids, with wing 4 as `awakened`.
24. An explicit `mechanics[id] == true` and a missing id both mean on. Only `false` means off. Confirm the caller treats `~= false` as on.
25. In `DungeonService.damageEnemy`, a Heartwood boss kill skips `Raids.applyClear` when `run.practice == true`, and still calls `Drops.apply`, `ChestConfig.enemyDrop`, and `ChestConfig.bossKill` inside the same mutate. `grant` already returns before loot when practice is true. This row does not list `DungeonService.luau`. Confirm those other writes should stay off a Practice Grove kill.

### T-063 hooks for GHOST

HELPER did not edit `RaidService.luau`, `DungeonService.luau`, `Raids.luau`, `RaidPractice.luau`, `PracticeLoot.luau`, `Schema.luau`, `Remotes.luau`, or any other T-012 file. `RaidPracticeGuard` is pure and ready to call. It requires `Raids` and reads `Raids.WINGS` only. It does not call `applyClear`, `buy`, or `weekNumber`. It does not require `RaidPractice`, so loading the guard does not load the practice rules. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires `RaidPracticeGuard` yet, so this branch does not change a live run. `RaidService.practice` still clamps a bad wing and still launches a lootless Story run. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. The T-063 row stays `claimed`. Wiring is yours.

Call the guard on the raw remote args, and only call `RaidPractice` when `ok == true`. The guard does not start a session and it does not grant loot.

When you wire this, require it next to the other raid rules:

```lua
local RaidPracticeGuard = require(ReplicatedStorage.Shared.RaidPracticeGuard)
local RaidPractice = require(ReplicatedStorage.Shared.RaidPractice)
```

**Return shape.** Every call returns three values: `ok`, `value`, `err`. This is not a `RaidPractice` result table. On success `ok == true`, `value` is the cleaned arg, and `err` is nil. On failure `ok == false`, `value` is nil, and `err` is one string from `RaidPracticeGuard.ERRORS`. Check `ok == true` before you read `value`. A bad arg does not throw. nil, NaN, a huge string, a table, and a wrong type all take the failure path.

| call | when | value on success |
|---|---|---|
| `boss(wing)` | the remote sends a wing number | the boss id string |
| `difficulty(value)` | the server picks a difficulty | `story`, `normal`, `hard`, or `shardbreaker` |
| `phase(difficulty, phase)` | the remote sends a phase | the integer phase |
| `start(wing, difficulty, phase)` | a practice session is requested | `{ bossId, difficulty, phase }` |
| `mechanic(bossId, mechanicId, allowlist, state)` | an id must be legal for this session | the trimmed mechanic id |
| `toggle(bossId, mechanicId, enabled, allowlist, state)` | the player switches one mechanic | `{ mechanicId, enabled }` |
| `hit(state, mechanicId, allowlist)` | a mechanic hit is about to be recorded | the trimmed mechanic id |
| `damage(amount)` | a damage note is about to be recorded | the finite number |

`start` does not call `RaidPractice.fresh`. `fresh` always begins at phase 1 and ignores a phase on the context. After `fresh` succeeds, call `jump` with `opening.phase`. Pass `opening.bossId` and `opening.difficulty`. Keep passing `unlocked` yourself. This module does not know which bosses the player has cleared.

```lua
local ok, opening, err = RaidPracticeGuard.start(wing, "story", phase)
if ok ~= true or opening == nil then
	return reject(err or RaidPracticeGuard.ERRORS.wing)
end
local started = RaidPractice.fresh({
	bossId = opening.bossId,
	difficulty = opening.difficulty,
	unlocked = unlocked == true,
})
if started.ok ~= true then
	return reject(started.error)
end
session = started.state
local jumped = RaidPractice.jump(session, opening.phase)
if jumped.ok == true then
	session = jumped.state
end
```

**Wings.** `boss` reads `Raids.WINGS`. Index 1 is `twins`, 2 is `sapwell`, 3 is `galecrown`, 4 is `awakened`. The id is the row's `id`, trimmed and lowercased, and it has to be one of those four. An unknown index is `ERRORS.wing`. This module does not floor and does not clamp. `PracticeLoot.wing` still clamps to `1..count`. Leave that function alone. A string `"1"`, a fraction, `0`, `5`, NaN, and a table are `ERRORS.wing`. `1.0` is wing 1.

**Difficulty and phase.** The same four difficulties as `RaidPractice`. Fracture and guided are refused. `" Story "` and `"HARD"` are trimmed and lowercased. Phase is an integer from 1 through `CONFIG.phases` (3). On shardbreaker the top is `CONFIG.shardbreakerPhases` (4). Those two numbers are copies of `RaidPractice.CONFIG`, checked by the spec, because this module does not require `RaidPractice`. Phase 4 on story, normal, or hard is `ERRORS.phase`. A bad difficulty is `ERRORS.difficulty`, including when it is passed to `phase`. `start` checks the wing, then the difficulty, then the phase. A missing difficulty is an error. It does not default to story.

**Mechanics.** `Raids.luau` has no frozen per-boss mechanic list. T-007 still owns Hard mechanic design. This module ships no mechanic names. The caller passes an allowlist. An id that is not on that boss's list is `ERRORS.catalog`. There is no allow-all mode. `nil` is `ERRORS.allow`. An empty table is a real list of zero ids, so every id is `ERRORS.catalog`.

The allowlist is one of these:

- A flat array of strings. Each string is trimmed. `" Gust "` is the id `Gust`.
- A flat set. A key whose value is `true` is on the list, after trim. `false` means that id is not on the list.
- Keyed by boss id. `allowlist[bossId]` is a table, and that inner table is the list for that boss. The boss id is the lowercase id (`twins`, `sapwell`, `galecrown`, `awakened`). A boss table wins over any flat keys on the same table. A different boss falls through to the flat keys. A string key whose value is a table is a boss bucket only when that key is already a lowercase boss id. Any other shape is `ERRORS.allow`.

Mechanic ids are trimmed and then kept as the caller spelled them. `"Gust"` and `"gust"` are different ids. Difficulty and boss ids are the ones that get lowercased. A raw string longer than `CONFIG.maxIdLength` (64) is refused. `CONFIG.allowCap` (64) is how many allowlist entries one call will read. A longer list is `ERRORS.allow`.

`CONFIG.mechanicCap` (12) is how many distinct mechanic ids one session may hold. The count is the keys of `state.mechanics` plus the keys of `state.hits`. An id that is already in either map does not take a new slot. A new id at the cap is `ERRORS.cap`, including a toggle that turns that new id off. A stored map that is already over the cap, or a map that is not a boolean or hit-count table, is `ERRORS.state`. Pass the stored session. `nil` means nothing is held yet. `mechanic` and `toggle` take the boss id you already resolved. A wing number is `ERRORS.boss`. If the session's `bossId` or `boss` names a different boss, the error is `ERRORS.disagree`.

`hit` reads the boss from `state.bossId` or `state.boss`. A missing boss is `ERRORS.state`. The check order is the mechanic id, then the record, then the allowlist, then the cap, then the off switch. `mechanic` checks the boss, then the id, then the record, then the allowlist, then the cap. `toggle` checks the boss, then the id, then that `enabled` is a boolean, then the same path as `mechanic`. `"true"` is `ERRORS.enabled`.

**Hits that are off.** `RaidPractice` still records a hit when `mechanics[id] == false`. This guard refuses that hit with `ERRORS.off`, so do not call `RaidPractice.note` after a failed `hit`. A missing key and an explicit `true` both mean the mechanic is on. Only `false` is off. An id that is off and also missing from the allowlist is `ERRORS.catalog`, because the list is checked first.

**Damage.** `damage` accepts a finite number `>= 0`, including `0` and a fraction. The per-call ceiling is `CONFIG.maxDamage` (100000). The ceiling is included. Above it is `ERRORS.ceiling`. A negative, NaN, infinity, or a non-number is `ERRORS.damage`. This is one call, not the session total. `RaidPractice.note` still adds the amount after the guard says yes.

```lua
local allowed, dealt, damageErr = RaidPracticeGuard.damage(rawDamage)
if allowed == true and dealt ~= nil then
	local noted = RaidPractice.note(session, { damage = dealt })
	if noted.ok == true then
		session = noted.state
	end
end

local hitOk, mechanicId, hitErr = RaidPracticeGuard.hit(session, rawId, allowlist)
if hitOk == true and mechanicId ~= nil then
	local noted = RaidPractice.note(session, { mechanicId = mechanicId })
	if noted.ok == true then
		session = noted.state
	end
end

local switchedOk, switch, switchErr =
	RaidPracticeGuard.toggle(session.bossId, rawId, rawEnabled, allowlist, session)
if switchedOk == true and switch ~= nil then
	local switched = RaidPractice.toggle(session, switch.mechanicId, switch.enabled)
	if switched.ok == true then
		session = switched.state
	end
end
```

Store a `RaidPractice` state only when that call's `ok == true`. Store nothing from this guard except the cleaned args you just passed in. The guard returns new tables from `start` and `toggle` and does not write the session or the allowlist.

`tests/run.luau` requires `./RaidPracticeGuard.spec` on this branch.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER branches skipped the stamp the same way.

Questions for Ghost:

1. The return shape is `(ok, value, err)`, not a `RaidPractice` result table. Confirm the wire checks `ok == true` before it reads `value`.
2. Unknown wings are refused. `PracticeLoot.wing` still clamps to `1..count`, and `RaidService.practice` still uses that clamp. Confirm the wire uses `boss` or `start` and stops clamping. `PracticeLoot.luau` was not edited.
3. A missing difficulty is `ERRORS.difficulty`. The live practice path forces story and the remote does not send one. Confirm the wire passes `"story"` until normal, hard, and shardbreaker are actually playable.
4. `Raids.luau` has no per-boss mechanic list, so the allowlist is caller-supplied. This module contains no mechanic names. Confirm you will pass the list, that an empty list refuses every id, and that there is no allow-all bypass while the catalog is missing.
5. Which allowlist shape should the wire pass: a flat array, a `id = true` set, or a table keyed by `twins` / `sapwell` / `galecrown` / `awakened`? A boss table wins over flat keys on that same boss.
6. `CONFIG.mechanicCap` is 12, a placeholder. Distinct ids are the keys in `mechanics` and `hits`. Turning a new mechanic off still uses a slot. Confirm the cap and that a toggle-off should count.
7. `CONFIG.maxDamage` is 100000 per call, a placeholder. `0` is allowed. A fraction is allowed. Confirm the ceiling, and whether one note must be a whole number.
8. A hit with `mechanics[id] == false` is `ERRORS.off` here. `RaidPractice.note` would still record it. Confirm the wire drops that hit and does not call `note`.
9. A missing mechanic key still means on. Only `false` means off. Confirm the wire keeps that `RaidPractice` rule.
10. Mechanic ids stay case-sensitive after trim. Boss ids and difficulties are trimmed and lowercased. Confirm `"Gust"` and `"gust"` stay different.
11. Phase 4 is legal only on shardbreaker. The guard does not floor. `fresh` ignores the phase and starts at 1, so the wire has to `jump` to `opening.phase`. Confirm a Story phase 4 is refused before `fresh`.
12. This module does not require `RaidPractice`. Nothing in `src` requires this module. The phase numbers are copied and the spec checks them against `RaidPractice.CONFIG`. Confirm they stay unwired until this pass, and that the copy is acceptable.
13. `CONFIG.maxIdLength` is 64 and `CONFIG.allowCap` is 64. A longer remote string or a longer allowlist is refused and does not throw. Confirm those bounds.
14. No profile field, no new remote, and no build stamp. The session stays the in-memory `RaidPractice` state. Confirm.
15. T-064 is reserved for a `DungeonService` practice-loot leak check. This branch does not touch `DungeonService` or `PracticeLoot`. Confirm that leak check stays on T-064.

### T-066 hooks for GHOST

HELPER did not edit `RollLoop.luau`, `RollReveal.luau`, `RollMath.luau`, `RollBoard.luau`, `PaidRollPolicy.luau`, `MenuHub.luau`, `RollReel.luau`, `RollService.luau`, `Schema.luau`, `Remotes.luau`, `RateLimiter.luau`, `default.project.json`, `Build.luau`, the init scripts, or `DungeonService.luau`. `RollHype` is pure and ready to call. It requires `Rarities` and reads `Rarities.ORDER` and `Rarities.INDEX` only. It does not require `RollLoop`, `RollReveal`, `RollMath`, `RollBoard`, or `PaidRollPolicy`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires `RollHype` yet, so this branch does not change a live run. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. The T-066 row is done in #72. Wiring is T-069.

When you wire this, require it next to the other roll rules:

```lua
local RollHype = require(ReplicatedStorage.Shared.RollHype)
```

**Return shape.** `fresh`, `note`, `pity`, and `tempo` each return one new table. They do not write the input. Check `ok == true` before you store `state` or show a rarity. A bad arg does not throw. nil, NaN, a huge string, and a wrong type take the failure path. Store a session only when `ok == true`. A failure returns a copy, or a blank session when the input session itself did not parse.

| call | when | on success |
|---|---|---|
| `fresh(allTime)` | the roll tab opens, or the player joins | `{ rolls = 0, streak = 0, best = nil, personalBest = false, allTime }` |
| `note(state, roll)` | a RollShard result comes back, or the invoke fails | a new session plus the display for this roll |
| `pity(counter, goal)` | the meter is drawn | `fill` from 0 to 1 |
| `tempo(rarity, paid)` | the reveal is about to play | `tier` and `buildUp` for that rarity |

**Session.** `rolls` counts landed rolls. `streak` matches `RollLoop.streak`: it increments when a roll lands and goes to 0 when `landed == false`. A miss does not increment `rolls`, does not change `best`, and does not set a personal best. `best` is the highest rarity actually landed this session, or nil before the first land. `personalBest` is sticky. It becomes true once a landed rarity strictly outranks the all-time best that was on file, and it stays true. `allTime` is the running best used for that comparison. It starts as the rarity string passed to `fresh` (`nil` or `""` means none on file). It moves up when the player beats it. It is a record, not a drop. Do not paint `state.best` or `state.allTime` on the card for the roll that just finished. Those can belong to an earlier roll.

**This roll.** Pass `{ rarity, landed, paid, allTime }`. `landed` defaults to true. `paid` is accepted and ignored. On a land, `rarity` is the rarity that was rolled, spelled as in `Rarities.ORDER`. `raisedBest` is true when that rarity is a new session high. `newPersonalBest` is true only on the roll that beat the running all-time best. `personalBest` on the result is the sticky flag after the note. `milestone` is 10, 25, 50, or 100 when the landed count becomes that number, and `callout` is `"10 rolls"`, `"25 rolls"`, `"50 rolls"`, or `"100 rolls"`. The callout does not name a rarity. On a miss, pass `{ landed = false }`. Any rarity on that table is ignored. `rarity`, `milestone`, and `callout` come back nil, and `streak` is 0.

```lua
local opened = RollHype.fresh(profileRollBest)
if opened.ok == true then
	session = opened.state
end

local noted = RollHype.note(session, {
	rarity = record.rarity,
	paid = paid == true,
})
if noted.ok == true then
	session = noted.state
end
-- Card rarity is noted.rarity. Toast noted.callout when noted.milestone ~= nil.
-- Toast a personal-best line only when noted.newPersonalBest == true, using noted.rarity.
```

A failed invoke is `RollHype.note(session, { landed = false })`. Keep the previous session when that call's `ok ~= true`.

**Paid.** A paid roll and a free roll with the same rarity return the same session numbers, the same callout, and the same build-up. `pity` has no paid argument. Do not add a longer reveal, a different meter, or a different milestone for a Prism crack.

**Pity.** `RollMath` stores `rollsSinceLegendary` and the pool's `pityLegendaryAt`. It has no 0-1 fill. `RollBoard.fill` and `RollBoard.bars` already draw `sinceEpic / RarityConfig.EPIC_PITY` (100) and `sinceLegendary / RarityConfig.LEGENDARY_PITY` (1000). This module does not read those caps. Pass the real counter and the real goal. A real 0 is an empty bar (`ok == true`, `fill == 0`). A counter above the goal is `fill == 1`, and the returned `counter` stays the number you passed. A missing goal, a goal of 0 or less, NaN, or infinity is `ERRORS.goal` and `fill == 0`. A missing, negative, or non-finite counter is `ERRORS.counter` and `fill == 0`. Infinity does not fill the bar. Check `ok == true` before showing the meter. The meter has no rarity field.

```lua
local meter = RollHype.pity(pityState.rollsSinceLegendary, pool.pityLegendaryAt)
local epic = RollHype.pity(sinceEpic, RarityConfig.EPIC_PITY)
local legendary = RollHype.pity(sinceLegendary, RarityConfig.LEGENDARY_PITY)
```

One table with one pair also works: `{ rollsSinceLegendary, pityLegendaryAt }`, `{ sinceEpic, epicGoal }`, `{ sinceLegendary, legendaryGoal }`, `{ counter, goal }`, or `{ since, goal }`. A table that names two of those pairs is `ERRORS.which` and `fill == 0`. `totalRolls` is not a pity counter. Pass the counter from after `RollMath.roll` if the bar should show the post-roll count. A Legendary-or-better result resets `rollsSinceLegendary` to 0 inside `RollMath.roll`. Pass the pre-roll count if the bar should show the progress that led into this spin. This module does not call `RollMath.roll`. Do not tween the bar past `fill`.

**Tempo.** `tier` is `Rarities.INDEX`. `buildUp` seconds are placeholders in `CONFIG`: Common 0.45, Uncommon 0.6, Rare 0.9, Epic 1.2, Legendary 1.65, Mythic 2.4, Secret 3. Each step is longer than the one below it. `tempo` does not read Settings. `RollLoop.seconds` and `RollReveal.duration` still own short, instant, skip, and reduced motion. Suggested wire: when the animation is full and reduced motion is off, use `tempo.buildUp` as the reveal duration. Otherwise keep `RollLoop.seconds`. Paid and free share `buildUp`, so `RollReveal`'s rule that a paid roll is never longer than the free roll stays true when you pass that same duration. An unknown rarity is `ERRORS.rarity` with `tier` nil and `buildUp` nil. Do not fall back to Common.

```lua
local pace = RollHype.tempo(record.rarity, paid)
if pace.ok == true and pace.buildUp ~= nil and fullAnimation and not reduced then
	duration = pace.buildUp
else
	duration = RollLoop.seconds(settings, record.rarity, quick, reduced)
end
```

**Call sites, still yours.** In `MenuHub` `beginRoll`, after `RollReveal.capture` succeeds, `note` the session with `record.rarity`. On a failed invoke, `note` `{ landed = false }`. Replace the local `streak` with `state.streak`. Toast `callout` when `milestone ~= nil`. The pity labels in `paintRoll` can keep `RollBoard.bars`, or switch the fill to `RollHype.pity` with the same `sinceEpic` / `sinceLegendary` numbers. `RollReveal.strip` already refuses a landing slot above the rolled rarity. Leave that function alone. Do not add a near-miss slot.

**Profile.** No schema field was added. `allTime` lives in the session you keep in memory. `fresh(nil)` means nothing is on file, and the first landed roll sets `personalBest`. If that best should survive a rejoin, a later pass can store one rarity string. This branch does not edit `Schema.luau`.

`tests/run.luau` requires `./RollHype.spec` on this branch. That require is in `tests`, not in `src`.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is. Prior HELPER pure modules skipped the stamp the same way.

Questions for Ghost:

1. Streak matches `RollLoop.streak`: consecutive landed rolls, reset to 0 when `landed == false`. Roll count only counts landed rolls, so after a miss the streak is 0 and the count stays. Confirm, or should a streak be consecutive copies of the same rarity?
2. Milestones fire when the landed count becomes exactly 10, 25, 50, or 100. The text is `"10 rolls"` and does not name a rarity. Confirm the four counts and that the toast should stay rarity-free.
3. `personalBest` on the session is sticky once a landed rarity strictly outranks the all-time best. `newPersonalBest` is true only on that roll. A tie is not a new best. With no all-time rarity on file, the first landed roll is a personal best. Confirm the tie rule and the empty-record rule.
4. When both the session and the note carry an all-time rarity, the bar is the higher rank. A lower string does not downgrade the record. Confirm.
5. `best` is the highest rarity landed this session. `RollLoop.best` can still pick a higher-power item of the same rarity. Confirm the shout is rarity-only, and that the card keeps using the captured item rather than `state.best`.
6. A miss ignores any rarity on the note. `note.rarity` is nil. Confirm the card must not show `state.best` as if this roll landed it.
7. Pity fill matches `RollBoard.fill` for a real non-negative counter and a goal above 0. A missing goal, a goal of 0 or less, or a non-finite counter returns `ok == false` and `fill == 0`, so the meter does not assume `EPIC_PITY` (100) or `LEGENDARY_PITY` (1000) and does not treat infinity as a full bar. Confirm whether the wire shows one meter or both bars, and which goal belongs to the `RollMath` path versus the profile path.
8. A table that carries two counter pairs is `ERRORS.which`. Confirm the wire calls `pity` twice for the epic bar and the legendary bar, and that `totalRolls` must not be read as pity.
9. Should the bar show the counter from before `RollMath.roll` or after it? A Legendary-or-better result resets `rollsSinceLegendary` to 0 inside `RollMath.roll`. This module does not call `roll`.
10. Tempo seconds are placeholders: Common 0.45, Uncommon 0.6, Rare 0.9, Epic 1.2, Legendary 1.65, Mythic 2.4, Secret 3. Tier is `Rarities.INDEX`. Paid does not change them. Confirm the wire uses this build-up only for the full animation, and still uses `RollLoop.seconds` / `RollReveal.duration` for short, instant, skip, and reduced motion. Confirm the placeholder seconds.
11. An unknown rarity is an error and is not echoed. There is no Common fallback and no near-miss field. Confirm a bad server rarity shows nothing rather than Common.
12. Paid rolls advance the same streak, milestones, meter, and tempo as free rolls. Confirm a Prism crack should count as a real roll in this session.
13. No profile field, no remote, and no build stamp. The session stays in client memory for one menu visit. `allTime` is caller-supplied. Confirm a Schema field for the all-time best rarity waits for a later GHOST pass.
14. A failed note returns a copy and does not write the input. Store `state` only when `ok == true`. Confirm.

### T-070 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `RelicSets.luau`, `RaidMarks.luau`, `RaidLuck.luau`, `Schema.luau`, `Remotes.luau`, `RateLimiter.luau`, `default.project.json`, `Build.luau`, the init scripts, or any other T-012 file. `RaidVault` is pure and ready to call. It does not require `RaidMarks`, `Raids`, `RelicSets`, or `RaidLuck`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires it. Gameplay is unchanged. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. T-070 is done. T-010 wires the Vault and does not edit this module. Wiring must surface a clear claim reminder before an unpicked Vault expires, and must not auto-grant. Revisit that reminder after playtest.

Thresholds are `RaidVault.CONFIG`. `thresholds` is 2, 4, 6. `choiceCounts` is 1, 2, 3. `rank` is story 1, normal 2, hard 3, shardbreaker 4. Fracture and guided are not ranks. `weekSeconds` is 604800. `tuesdayOffset` is 432000 (1970-01-06 00:00:00 UTC), the same Tuesday as `RaidMarks.weekKey`. Do not hardcode the numbers beside the module. Pass unix seconds in as `now`. The module does not read the clock. `os.clock()` is not wall time.

`RaidVault.weekKey(now)` is that Tuesday week. Week 1 is `tuesdayOffset`. The reset instant belongs to the new week: `1791849600` (2026-10-13 00:00:00 UTC) is key 2963, and one second earlier is 2962. A time before the first Tuesday is key 0. A negative, NaN, or infinite time returns nil. `Raids.weekNumber` stays Thursday 00:00 UTC. On that same Tuesday it returns 2962. This module does not change it. Pass only keys from `RaidVault.weekKey`, or a stored key below 0 for "never stamped".

`RaidService.luau`, next to the `Raids` require, when you wire T-010:

```lua
local RaidVault = require(ReplicatedStorage.Shared.RaidVault)
```

**Return shape.** `fresh`, `note`, `view`, `offer`, and `pick` each return one new table. They do not write the input. `weekKey` returns a number or nil, the same shape as `RaidMarks.weekKey`. A bad arg does not throw. nil, NaN, a non-table, and a wrong type take the failure path. Store `state` when `persist == true`, including a failed `offer` or `pick` whose week rolled (`expired` or a count mismatch after the reset). Grant `pick.item` only when `pick.ok == true`. An `ok == false` result with `persist == false` is a bad clock, a bad record, or a bad arg. Writing the blank record from a state error would wipe a real Vault.

| call | when | on success |
|---|---|---|
| `weekKey(now)` | you need the Tuesday key and nothing else | the key, or nil when `now` cannot be used |
| `fresh()` | a brand-new profile, before the first stamp | `{ weekKey = -1, kills = {}, vault = nil }` |
| `note(state, kill, now)` | a Heartwood boss dies | a new state. `counted` means a new (boss, difficulty) row. `upgraded` stays false. |
| `view(state, now)` | profile load, and when the raids panel should be current | the week rolled, progress slots, and the claim Vault if one is open |
| `offer(state, items, now)` | you have built one item per open slot | the choices, tagged with that slot's difficulty. No loot roll lives here. |
| `pick(state, index, now)` | the player takes one choice during the claim week | `item` is the copy to grant. `index` is 1-based into the offer. |

**What a kill is.** Pass `{ bossId, difficulty, practice, guided, removal }`. `bossId` and `difficulty` are trimmed and lowercased. `" Twins "` / `" Hard "` is `twins` / `hard`. Boss ids are not checked against `Raids.WINGS`. Heartwood's room ids are `twins`, `sapwell`, `galecrown`, and `awakened`. A later raid can pass a new id. Each distinct `(bossId, difficulty)` pair counts once per week. The same boss on a second difficulty is a new row and sets `counted`. It does not replace the earlier row, and `upgraded` stays false. The same pair again sets `duplicate` and keeps the stored `guided` flag. One difficulty of the four Heartwood bosses opens at most 2 choices. Those four bosses on two difficulties are 8 pairs and can open 3 choices. The 6-pair slot does not need six different boss ids.

Practice Grove (`practice = true`) does not count. `removal = "afk"` (the T-027 90s removal) and `removal = "kick"` (a passed vote-kick) do not count. `" AFK "` is afk. `"idle"`, `"leave"`, and `""` are refused, so a typo is not a kill. Guided is a flag, not a difficulty. `guided = true` counts and is stored on that pair. A repeat of the same pair keeps the stored flag. A second difficulty stores its own flag on the new row. Practice wins when a removal is also set. Fracture is `ERRORS.difficulty`.

**Slot quality.** Sort the week's pairs from highest rank to lowest. Ties keep record order. Slot 1 (2 pairs) uses the 2nd pair in that list. Slot 2 (4 pairs) uses the 4th. Slot 3 (6 pairs) uses the 6th. The slot's quality is that pair's difficulty. One shardbreaker and one hard open a single choice at hard, not shardbreaker. Three hard and one story open two choices: the first hard, the second story. Six shardbreaker pairs open three shardbreaker choices. A 7th pair does not open a fourth choice. `choiceCount` on the progress result is how many choices this earning week would open at the next reset. It is 0 below 2 pairs.

**The week.** Kills during week W open the Vault at the next Tuesday (week W + 1). The player may pick from that Tuesday until the following Tuesday, exclusive of that next reset instant. A kill at exactly Tuesday 00:00 UTC lands in the new week, and that same `note` opens last week's Vault. A week key below 0 stamps the current Tuesday and does not carry any kills that were sitting on the unstamped record. Save `weekKey` and `kills` from the same result.

An unpicked Vault is dropped at the following Tuesday. `expired == true`. `item` is nil. Do not grant it and do not bank it. If that same roll also opens a new Vault from the week just finished, `vault` is the new one and `expired` still means the previous unclaimed Vault was discarded. A Vault that was already picked is dropped the same way and `expired` stays false, so you do not grant it twice. One boss, or zero, never sets `expired`. Skipping the whole claim week (no login during W + 1) also sets `expired` when the missed week would have opened a slot, and it does not grant.

`offer` before the reset returns `ERRORS.early` when this week already has 2 or more pairs. `ERRORS.closed` means there is nothing to claim and this week has not opened a slot. `offer` takes one item per open slot, in slot order. Each item is a table. A string has no tier and is `ERRORS.quality`. A table is deep-copied: nested tables are new, and a cycle, a function, or a non-finite number is `ERRORS.item`. The item's vault tier is `difficulty`, or a string `quality` when `difficulty` is absent. A numeric gear-roll `quality` is not a tier. Both strings, when present, must agree. The tier must equal that slot's difficulty or the offer is `ERRORS.quality` and `choices` stay nil. `" Hard "` matches `hard`. The first successful offer locks. A second `offer` before the pick returns `ERRORS.locked` and does not replace the items. `offer` after the pick returns `ERRORS.picked`. `pick` before `offer` returns `ERRORS.offer`. `pick` also refuses a stored item whose tier does not match its slot, does not set `picked`, and does not grant it. A second `pick` returns `ERRORS.picked` and `item` nil. Index 0, 1.5, `"1"`, NaN, and inf return `ERRORS.pick`. A week key above `2^53 - 1` is `ERRORS.state` on a stored record and nil from `weekKey`. A negative stored key is still unstamped.

```lua
local function vaultState(data)
	return {
		weekKey = data.raidVaultWeek,
		kills = data.raidVaultKills,
		vault = data.raidVaultClaim,
	}
end

local function saveVault(data, result)
	if result.persist ~= true then
		return
	end
	data.raidVaultWeek = result.state.weekKey
	data.raidVaultKills = result.state.kills
	data.raidVaultClaim = result.state.vault
end
```

Nil fields are a fresh record (`weekKey` nil counts as -1, `kills` nil counts as empty). A call before the migrate does not throw. It also does not persist when `persist ~= true`.

**Call sites, still yours.** The boss death is the `enemy.hp <= 0` block in `DungeonService` that already calls `PracticeLoot.applyKill` for a Heartwood boss. T-010's row lists `RaidService.luau` and `Raids.luau`, not `DungeonService`. Add the four functions below on `RaidService` and call `noteVault` from that mutate. Do not fold the rules into `Raids.applyClear`. Calling both is fine: `applyClear` still owns loot, Marks, and the Thursday lock. This module does not read `raidLock`.

```lua
function RaidService.noteVault(player, bossId, difficulty, practice, guided, removal)
	local now = os.time()
	return DataService.mutate(player, function(data)
		local result = RaidVault.note(vaultState(data), {
			bossId = bossId,
			difficulty = difficulty,
			practice = practice == true,
			guided = guided == true,
			removal = removal,
		}, now)
		saveVault(data, result)
		return nil
	end)
end

function RaidService.vault(player)
	local now = os.time()
	DataService.mutate(player, function(data)
		saveVault(data, RaidVault.view(vaultState(data), now))
		return nil
	end)
	return DataService.snapshot(player)
end

function RaidService.offerVault(player, items)
	local now = os.time()
	local offered = nil
	local ok, err = DataService.mutate(player, function(data)
		offered = RaidVault.offer(vaultState(data), items, now)
		saveVault(data, offered)
		if offered.ok ~= true then
			return offered.error
		end
		return nil
	end)
	return ok, offered, err
end

function RaidService.pickVault(player, index)
	local now = os.time()
	local picked = nil
	local ok, err = DataService.mutate(player, function(data)
		picked = RaidVault.pick(vaultState(data), index, now)
		saveVault(data, picked)
		if picked.ok ~= true then
			return picked.error
		end
		-- Grant picked.item here. This module does not know your bag.
		return nil
	end)
	return ok, picked, err
end
```

`practice` on the live run is `run.practice == true`. `RaidService.practice` launches with that flag set. Pass it through. A practice `note` returns `ok` and `counted == false`, and `persist` is true only when the week also rolled. Guided is not live. Pass `guided = true` only for a real Guided clear. `removal` is nil, `"afk"`, or `"kick"`. Leave it nil for a player who finished the boss. `RaidService.vault` on profile load is what expires an unclaimed Vault before the panel draws. `items` are yours: one per `vault.choiceCount`, in slot order, each stamped with `difficulty` equal to `vault.slots[i].difficulty` (a string `quality` of that same tier also passes). This module will not roll them. There is no paid reroll, no paid extra choice, and no paid skip of the thresholds. The first offer locks, so build the items once.

**Schema.** HELPER does not edit `Schema.luau`. Add these on the next free schema version at wiring time. Do not assume a version number from this branch. Version 21 was current when T-070 opened. Do not assume 22 is still free.

```lua
raidVaultWeek: number, -- RaidVault.weekKey. Default -1.
raidVaultKills: { any }, -- { { bossId, difficulty, guided } } for the earning week.
raidVaultClaim: any, -- nil, or { earnedWeek, kills, choices, picked }.
```

`choices` is nil until `offer`. `picked` is nil until `pick`, then the 1-based index into `choices`. The slot difficulties are derived from `kills` and `CONFIG`, so they do not need their own fields. `wholeNumber` fits `raidVaultWeek` with default -1, the same way `raidMarkWeek` works. Leave a non-finite week or a bad kill row for the module to refuse. If `sanitize` turns a broken week into -1 and drops the kills, a corrupt record looks like a new player. `snapshot` should send the view (`choiceCount`, slot difficulties, `offered`, `picked`) when the raids panel shows the Vault. The profile can keep the raw state.

`tests/run.luau` requires `./RaidVault.spec`. That require is in `tests`, not in `src`.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is.

Answers from Ghost:

1. Each distinct `(boss, difficulty)` pair counts once per week. The four Heartwood bosses cleared on two difficulties can open 3 choices. The same boss on the same difficulty still counts once and does not replace the stored row.
2. Keep the 2nd, 4th, and 6th highest rule. Slot quality is that pair's difficulty.
3. Keep expiry in this module. Nothing is auto-granted or banked. T-010 must surface a clear claim reminder before the Vault expires. Revisit that reminder after playtest.
4. Confirmed. Guided counts. Practice Grove, an AFK removal, and a passed vote-kick do not.
5. The first offer locks. A second offer before the pick is `ERRORS.locked`. That blocks a reroll.
6. Confirmed. The player picks exactly one index during the claim week. A pick during the earning week is `ERRORS.early`. A second pick is refused.
7. Confirmed. The fields stay `raidVaultWeek`, `raidVaultKills`, and `raidVaultClaim`. T-010 adds them on the next free schema version at wiring time.
8. Confirmed. No paid reroll, no paid extra choice, and no paid skip of the boss thresholds, ever.
9. Confirmed. Fracture stays out, including Fracture boss kills.
10. Confirmed. The week key is Tuesday, the same shape as `RaidMarks.weekKey`. Do not use `Raids.weekNumber`.
11. Confirmed. Do not carry kills stored on a week key below 0.
12. `offer` refuses an item whose tier does not match its slot. `pick` refuses a stored mismatch and does not grant it. The loot builder still stamps the slot difficulty. This check is defense in depth.

### T-071 hooks for GHOST

HELPER did not edit `Crafting.luau`, `Recipes.luau`, `Raids.luau`, `RaidService.luau`, `RaidLootTrade.luau`, `DungeonService.luau`, `PracticeLoot.luau`, `CraftService.luau`, `Schema.luau`, `Remotes.luau`, `RateLimiter.luau`, `default.project.json`, `Build.luau`, the init scripts, or any other T-012 file. `RaidResonant` is pure and ready to call. It does not require `Crafting`, `Recipes`, `Raids`, `RaidMarks`, `RaidLootTrade`, or the weapon catalog. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires it. Gameplay is unchanged. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. There is no paid skip of the three drops. T-071 is done. Wiring is still yours.

Thresholds are `RaidResonant.CONFIG`. `threshold` is 3. `maxIdLength` is 64, the same placeholder cap as the practice guard. A GUID from `HttpService:GenerateGUID(false)` is 36 characters and fits. Do not hardcode 3 beside the module. Read `result.threshold` or `CONFIG.threshold`.

`RaidService.luau`, next to the other raid requires, when you wire this:

```lua
local RaidResonant = require(ReplicatedStorage.Shared.RaidResonant)
```

**Return shape.** `fresh`, `note`, and `view` each return one new table. They do not write the input. A bad arg does not throw. nil, a non-table, a blank id, and a wrong type take the failure path. Store `state` only when `note.persist == true`. `view.persist` is always false. An `ok == false` result with `persist == false` is a bad record or a bad drop. Writing the blank record from a state error would wipe real pattern progress.

| call | when | on success |
|---|---|---|
| `fresh()` | a brand-new profile, before the first resonant drop | `{ weapons = {} }` |
| `note(state, drop)` | the server grants one Heartshard drop | a new state. `counted` means this uid was stored. `unlocked` means this weapon's pattern is open. |
| `view(state)` | the raids panel wants every weapon | the progress list. Top-level `count` is 0 and `unlocked` is false. |
| `view(state, weaponId)` | the Forge asks if this pattern is open | that weapon's `count` and `unlocked`. An unseen weapon is 0 and false. |

**What a drop is.** Pass `{ weaponId, resonant, practice, uid }`. `weaponId` is trimmed. `" axe "` is `axe`. It is not lowercased, so `Axe` and `axe` are two weapons. It is not checked against a catalog. A blank, missing, non-string, or over-long weapon id is `ERRORS.weapon`. `uid` is trimmed the same way. A missing or blank uid is `ERRORS.uid`. A non-string uid, or one longer than `maxIdLength`, is `ERRORS.uidShape`. A missing uid is refused on purpose, so a retry cannot invent a second count by omitting the id the first time and sending it the second. Extra fields (`difficulty`, a forged `unlocked`) are ignored.

Only `resonant == true` counts. `false`, nil, `1`, and `"true"` return `ok == true`, `counted == false`, `reason == "resonant"`, and they do not store the uid. `practice == true` does not count (`reason == "practice"`), even when the drop is also resonant. `practice` nil or false is a live drop. Any other practice type is `ERRORS.practice`. Practice is not a difficulty.

The same uid does not count twice. Uids are global across weapons: a uid stored on `axe` cannot count for `bow`. A replay is `reason == "duplicate"` and `duplicate == true`, including a retry that flips `practice` or `resonant` after the uid was stored. That check happens before the practice and resonant skips. A practice drop, a non-resonant drop, and a drop past the cap do not store the uid. A later live resonant call with that same uid can still count.

The count sticks at 3. The third stored uid sets `unlocked`. A fourth new uid returns `reason == "capped"`, `counted == false`, `persist == false`, `count == 3`, and `unlocked == true`. That fourth uid is not stored, so a replay of it is capped again, not a duplicate. A replay of one of the three is a duplicate. Unlock stays set. Nothing in this module clears it. There is no skip, no Marks spend, and no material cost.

Nil `state`, or `weapons` nil, is an empty record. The first counted drop should be saved. A broken row (count above 3, `unlocked` disagreeing with the count, a duplicate weapon id, a uid used twice, a non-array, a stored id that still has surrounding spaces) is `ERRORS.state`. The returned `state.weapons` is empty and `persist` is false. Do not write that blank over the profile.

`view` copies the record and does not change counts. `view(state, "  axe  ")` trims. The `weapons` list on a successful view is every stored weapon, in the order they were first counted, not only the one you asked about. Do not save `view`. On a view error the progress list is empty. A state error's `state` is blank. A weapon-id error still carries the copied record on `state`, with `ok == false`.

```lua
local function resonantState(data)
	return {
		weapons = data.raidResonant,
	}
end

local function saveResonant(data, result)
	if result.persist ~= true then
		return
	end
	data.raidResonant = result.state.weapons
end
```

**Call sites, still yours.** Heartshard weapon drops are not granted yet. `PracticeLoot.applyKill` pays materials, chests, and `Raids.applyClear`. It does not mint a resonant weapon. Add `noteResonant` on `RaidService` and call it from the server mutate that grants the weapon, after the item uid exists. The kill path today is the `enemy.hp <= 0` block in `DungeonService.damageEnemy`, inside the `DataService.mutate` that already calls `PracticeLoot.applyKill` for a Heartwood boss. Do not fold these rules into `Raids.applyClear`, `PracticeLoot`, `Crafting`, or `Recipes`. Pass `practice = run.practice == true`. Pass `resonant = true` only when that granted item is a red-border Resonant drop. Pass that item's `uid`. Do not pass a material pile. The client does not get to set `resonant`.

```lua
function RaidService.noteResonant(player, drop)
	return DataService.mutate(player, function(data)
		local result = RaidResonant.note(resonantState(data), {
			weaponId = drop.weaponId,
			resonant = drop.resonant == true,
			practice = drop.practice == true,
			uid = drop.uid,
		})
		saveResonant(data, result)
		if result.ok ~= true then
			return result.error
		end
		return nil
	end)
end
```

The Forge check belongs in `CraftService.craft`, before `Crafting` runs, and only for a Heartshard pattern recipe. `RaidResonant.view(resonantState(data), weaponId).unlocked` must be true. This module does not know recipe ids, does not spend Marks, and does not take materials. `Crafting.luau` still owns the cost. A locked pattern does not craft. There is no Robux product that sets `unlocked`.

The red border is paint. Show it from the drop the server already marked resonant. Do not let the client send the flag. The pattern progress for the panel is `RaidResonant.view`.

**Schema.** HELPER does not edit `Schema.luau`. Add this on the next free schema version at wiring time. Do not assume a version number from this branch. Version 21 was current when T-071 opened. Do not assume 22 is still free.

```lua
raidResonant: { any }, -- { { weaponId, count, unlocked, uids } }. Default {}.
```

`count` is 1 to 3 for a stored row. `unlocked` is true only when `count` is 3. `uids` is the list of uids that counted, and its length is `count`. Weapons with no drops are absent. The threshold is `CONFIG`, so it does not need its own field. Leave a non-array or a bad row for the module to refuse. If `sanitize` turns a broken record into `{}`, a corrupt profile looks like a new player and the same three drops can count again under new uids. `snapshot` can send the view (`weaponId`, `count`, `unlocked`, `threshold`) when the panel or the Forge asks. The profile keeps the raw rows, including `uids`.

`tests/run.luau` requires `./RaidResonant.spec`. That require is in `tests`, not in `src`.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is.

Questions for Ghost:

1. Weapon ids are trimmed and not lowercased. `"Axe"` and `"axe"` are different weapons. Should the wire pass a canonical id, or should this module fold case?
2. A uid is global across weapons. The same uid cannot count toward a second weapon. Confirm.
3. Practice, a non-resonant drop, and a drop past 3 do not store the uid. A later live resonant call with that same uid still counts. A replay of a uid that already counted is `duplicate` even if the retry sets `practice` or clears `resonant`. Confirm, including that a practice attempt must not burn the uid.
4. Only `resonant == true` counts. `false`, nil, `1`, and `"true"` do not count and are not errors. Confirm, or should a non-boolean be refused?
5. `practice` nil and false mean a live drop. Any other type is refused. Confirm.
6. Difficulty, guided, lockout, AFK, and vote-kick are not fields. A reclear can still add a resonant drop. The design line that reclears keep paying toward Resonant patterns is read that way. Confirm, including whether a resonant drop is eligible during the loot lockout.
7. One pattern per `weaponId`, not per difficulty and not per class. Confirm.
8. Unlock does not grant the weapon, spend Marks, or consume the three items. Salvage and trade do not reduce the count. The Forge pattern id is this same `weaponId` until you map it to a recipe. Confirm the map, and that `CraftService.craft` stays closed until `view` says `unlocked`.
9. The field name is `raidResonant`, the weapons array only. Confirm. Version 21 was current. Add it on whichever version is free at wiring time.
10. `CONFIG.maxIdLength` is 64. Confirm or raise it.
11. The loot builder owns the red-border flag. This module does not read the item or the catalog. Confirm `resonant = true` is set only for a Resonant Heartshard weapon, and that a normal drop of the same weapon does not count.
12. There is no bad-luck bump and no paid skip. Three is the whole rule. A 4th new uid returns `capped` and is not stored, so a replay of that 4th uid also returns capped rather than duplicate. Confirm that reporting is fine.
13. Should the wire live as `RaidService.noteResonant`, called from the Heartwood boss mutate in `DungeonService.damageEnemy`, or only once a real Heartshard weapon drop exists inside that mutate? This branch does not edit either file.

Answers from Ghost:

1. The wire passes a canonical id from ItemBases. This module does not fold case. `Axe` and `axe` stay two weapons. The Heartshard ids are not in ItemBases yet; when they land, pass that catalog id. The content ids are the lowercase `heartshard_*` strings.
2. Yes. A stored uid is global and cannot count toward a second weapon.
3. Correct. Practice, a non-resonant drop, and a drop past 3 do not store the uid. A later live resonant call with that same uid still counts. A replay of a stored uid is `duplicate` even if the retry changes `practice` or `resonant`.
4. Only boolean `true` counts. `false`, nil, `1`, and `"true"` are not errors. That is fine.
5. Confirmed. `practice` nil and false mean a live drop. Any other type is refused.
6. Confirmed. Reclears count. Lockout, difficulty, guided, AFK, and vote-kick are the loot builder's job, not this module's.
7. One pattern per `weaponId`. Not per difficulty and not per class.
8. Confirmed. The Forge maps `weaponId` to a recipe. Craft stays closed until `view` says `unlocked`. Unlock does not grant the weapon, spend Marks, or consume the three items. Salvage and trade do not reduce the count.
9. The field is `raidResonant`, the weapons array only, on whichever schema version is free at wiring time. Version 21 is still current. Do not assume 22.
10. 64 is fine. A GUID fits.
11. Confirmed. Only a Resonant Heartshard drop sets `resonant = true`. A normal drop of the same weapon does not count. The client does not send the flag.
12. Confirmed. No bad-luck bump and no paid skip. A 4th new uid returns `capped` and is not stored, so a replay of that uid is capped again rather than `duplicate`.
13. Yes. `RaidService.noteResonant`, called from the Heartwood boss path in `DungeonService.damageEnemy`, once a real weapon drop exists. Ghost owns that wiring.

### T-074 hooks for GHOST

HELPER did not edit `RaidConduct.luau`, `RaidFinder.luau`, `RaidPremade.luau`, `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `MenuHub.luau`, `UiRouter.luau`, `RollHype.luau`, `Keybinds.luau`, `Remotes.luau`, `RateLimiter.luau`, `default.project.json`, `Build.luau`, the init scripts, or any other T-012 file. `RaidGuided` is pure and ready to call. It does not require `RaidConduct`, `RaidFinder`, `RaidPremade`, `RaidMarks`, or `Raids`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires it. Gameplay is unchanged. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. There is no paid skip of the oath, the half rule, or the score. T-074 is done. Wiring is still yours. T-072 owns `MenuHub.luau`. T-073 owns `DungeonService.luau`. Do not edit either for this.

Where the row and `docs/design/shardfall_raids.md` disagree, the row won:

- The design says a guild hosts "with at least half its members." The row says at least half the roster shares the host guild, half the run and not half of the whole guild. This module counts the run. A guild of any size with 2 of 4 in the run passes. Two hosts cannot fill a run of 8 with Seekers, because 2 is not half of 8. The whole guild being present does not waive that.
- The Destiny research line says "Guardian Oath" and "Oathkeeper Score." The Shardfall section and the row say Oath of the Grove and a Guide Score. Accept is one boolean. No oath text is stored.
- The design says kicking is disabled. The row says kicking is refused for the whole run, and an AFK removal stays in `RaidConduct` and is not a kick. This module does not edit `RaidConduct`. That module already refuses a vote when `guided == true`.

`RaidMarks.CONFIG.doubleMarks` stays false. This module does not read it. A finish does not multiply Raid Marks. `marksMultiplier` on the result is 1.

Thresholds are `RaidGuided.CONFIG`. `guideScore` is 1. `guidedPointScale` is 2. `minParty` is 4. `maxParty` is 8. `maxIdLength` is 64, the same placeholder cap as the practice guard. Do not hardcode those numbers beside the module. `DIFFICULTIES` is `hard` and `shardbreaker`. `REFUSED` is `story`, `normal`, `fracture`, `practice`, and `guided`. Guided is a mode, not a difficulty. `Raids.DIFFICULTIES` is still Story and Normal. Do not gate this on `Raids.difficulty("hard")`. Pass the string.

`RaidService.luau`, next to the other raid requires, when you wire this:

```lua
local RaidGuided = require(ReplicatedStorage.Shared.RaidGuided)
```

**Return shape.** `open`, `join`, `oath`, `kick`, `release`, `finish`, and `view` each return one new table. They do not write the input. A bad arg does not throw. nil, a non-table, a blank id, and a wrong type take the failure path. Store the run when `persist == true`. `view.persist` is always false. An `ok == false` result with `persist == false` is a bad record or a refused call. Writing the blank record from a state error would wipe a real run. The run lives in memory on the raid server. It is not a player profile.

| call | when | on success |
|---|---|---|
| `open(ctx)` | a guild opens Guided on Hard or Shardbreaker | `{ difficulty, hostGuildId, members = {}, finished = false, guideScore = 0, raidXp = 0, guidedPoints = 0 }` |
| `join(state, player)` | one player joins | a new roster. The new member's `oath` is false. |
| `oath(state, userId, accepted)` | that player accepts or declines | that member's boolean. `accepted` is how many have sworn. |
| `kick(state, request)` | anything tries to kick | always refused. `removed` is false. The roster is unchanged. |
| `release(state, userId, cause)` | `RaidConduct.afk` already returned `state == "remove"` | that player is off the roster. `kick` is false. |
| `finish(state, raidXp)` | the clear is real and you have the unscaled guild raid XP | `counted == true`. Add `guideScore` and `guidedPoints` once. |
| `view(state)` | the panel wants the roster math | `ready` means finish would pass the gates. It does not finish. |

**Open.** `ctx` is `{ difficulty, hostGuildId }`. `difficulty` is trimmed and lowercased. `" Hard "` is `hard`. `"SHARDBREAKER"` is `shardbreaker`. Story, Normal, Fracture, Practice, and `guided` are `ERRORS.difficulty`. A Fracture id with a level (`"Fracture 3"`, `"fracture-1"`) is refused too. `practice = true` is `ERRORS.practice` even on Hard. `guided = false` is refused. `guided` nil means this call is the Guided open. `hostGuildId` is trimmed and not lowercased. A preloaded `members` list, a `guildSize`, and a starting `guideScore` are ignored. The run starts empty. One `open` does not admit the roster.

**Join.** One player per call. A list, a `party`, `with`, or `companions` field, or a second argument is `ERRORS.seeker` and adds nobody. `userId` is a positive whole number. A duplicate is `ERRORS.duplicate`. The 9th player is `ERRORS.full`.

A player whose trimmed guild id equals `hostGuildId` is a guide. Anyone else, including no guild and another guild, is a Seeker. `"Grove"` and `"grove"` are different. Omit `seeker` and the module infers it. `seeker = true` on a host member is `ERRORS.seeker`. `seeker = false` on anyone else is `ERRORS.host`. A join that sets `oath = true` still stores `oath = false`. There is no skip.

Half is `ceil(size / 2)` of the run after the join, and of any larger size up to 8 if the empty slots can still be filled with hosts. A Seeker join that makes that impossible is `ERRORS.half` and does not add them. 4 Seekers and 0 hosts can still be joined, because 4 hosts can still be added to reach 4 of 8. A 5th Seeker with 0 hosts cannot, and is refused. 2 hosts and 4 Seekers can be joined. A 5th Seeker beside those 2 hosts is refused. Adding a host never needs a guild-wide census. `guildSize` is not a field.

**Oath.** `accepted` must be a boolean. A string, a number, nil, or a fourth argument (the phrase) is `ERRORS.oath` and stores nothing. `true` swears. `false` is a decline, not an error, and `persist` is true only when the boolean changes. A repeat of the same boolean is `ok` and `persist == false`. The member must already be on the roster.

**Finish.** Call it only for a real clear. This module does not know bosses, wipes, or roles. The gates, in order, are party size, half, then oath. Size must be 4 to 8. Hosts must be at least `ceil(size / 2)`. 5 needs 3. 7 needs 4. 2 of 4 passes. 1 of 4 does not. 4 of 8 passes. Every member still on the roster must have `oath == true`. One missing oath is `ERRORS.oath`, `counted == false`, and `guideScore` 0. The run stays unfinished.

`raidXp` is the unscaled guild raid XP for this clear. You supply it. There is no per-difficulty table here. It must be a whole number >= 0. `guidedPoints = raidXp * CONFIG.guidedPointScale`. That replaces the base. Do not also add `raidXp`. `guideScore` is `CONFIG.guideScore` (1) for the host guild. Both numbers on the result are the delta. `marksMultiplier` is 1. There is no `marks` amount. Hard and Shardbreaker use the same placeholder score. `raidXp` 0 still counts and awards the score with 0 points. A negative, a fraction, a string, NaN, or inf is `ERRORS.points` and does not finish. A third argument (`{ skipOath = true }`) is `ERRORS.finish`.

A second `finish` returns `ok == true`, `counted == false`, `persist == false`, `reason == "finished"`, and a zero delta. `state.guideScore` stays 1. Add to the guild only when `counted == true`.

**Kick and AFK.** `kick` always returns `ok == false`, `removed == false`, `kick == false`, and the same roster. That holds before anyone joins, during the run, and after finish. A vote is a kick, including `passed == true` and a vote whose `reason` is `"afk"` or `"idle"`. Passing the AFK signal to `kick` (`"afk"`, `"remove"`, or `{ state = "remove" }`) returns `ERRORS.afk` and still removes nobody.

`release` is the roster update after `RaidConduct.afk` has already decided. This module does not count idle seconds. Pass `"afk"`, `"remove"`, `" AFK "`, or `{ state = "remove" }`. `removed` is true and `kick` is false. `"kick"`, `"idle"`, `"vote"`, and `{ passed = true }` are `ERRORS.kick` and remove nobody. `"warning"` is `ERRORS.removal` and removes nobody. A table with `reason`, `votes`, `initiatorUserId`, `passed == true`, or `spentKick == true` is a kick even when it also says `removal = "afk"` or `state = "remove"`. The `RaidConduct.afk` remove result has none of those fields, so passing that table still removes. The released player's oath leaves with them. If the roster drops under 4, or under half (4 hosts and 4 Seekers, then one host leaves, is 3 of 7), `finish` does not count until a later `join` repairs it. `release` after `finish` is `ERRORS.finished`. The award is not clawed back.

```lua
local function saveGuided(run, result)
	if result.persist ~= true then
		return run
	end
	return result.state
end
```

Nil `state` on `join`, `oath`, `kick`, `release`, `finish`, or `view` is `ERRORS.state`. It does not throw. Do not write that blank over the run.

**Call sites, still yours.** Keep the run on the reserved server, next to the live roster. Do not fold these rules into `Raids`, `RaidConduct`, `RaidFinder`, or `RaidPremade`. Finder stays Story and Normal. The premade board does not list Guided. Pass `practice = true` only if you must refuse it. A normal Hard run does not call this module.

```lua
function RaidService.openGuided(difficulty, hostGuildId)
	return RaidGuided.open({
		difficulty = difficulty,
		hostGuildId = hostGuildId,
	})
end

function RaidService.joinGuided(run, userId, guildId)
	local result = RaidGuided.join(run, {
		userId = userId,
		guildId = guildId,
	})
	return saveGuided(run, result), result
end

function RaidService.oathGuided(run, userId, accepted)
	local result = RaidGuided.oath(run, userId, accepted)
	return saveGuided(run, result), result
end

function RaidService.kickGuided(run, request)
	return RaidGuided.kick(run, request)
end

function RaidService.releaseGuided(run, userId, afkResult)
	local cause = if type(afkResult) == "table" then afkResult else "afk"
	local result = RaidGuided.release(run, userId, cause)
	return saveGuided(run, result), result
end

function RaidService.finishGuided(run, raidXp)
	local result = RaidGuided.finish(run, raidXp)
	if result.counted == true then
		-- Add result.guideScore to the host guild's guideScore.
		-- Add result.guidedPoints to the host guild's guidedPoints.
		-- Do not add result.raidXp. Do not fold guidedPoints into raid XP.
		-- Do not multiply Raid Marks.
	end
	return saveGuided(run, result), result
end
```

Call `releaseGuided` only when `RaidConduct.afk` returned `state == "remove"`. Keep passing `guided = true` into `RaidConduct.openVote` so the vote dies there too. `kickGuided` is the same refusal for a caller that did not go through `RaidConduct`. Do not treat either call as the removal.

`view` is safe to call for a panel. Do not save it. `ready == true` means the gates pass and the run has not finished. `reason` is nil when the run is ready. Otherwise it is `party`, `half`, `oath`, or `finished`.

**Schema.** HELPER does not edit `Schema.luau`. Do not add this to the player profile. A per-player copy would diverge. Version 21 was current when T-074 opened. Do not assume 22 is still free. There is no guild schema in this repo. When a guild record exists, add this on that record. Do not assume its version number.

```lua
guideScore: number, -- default 0. Add finish.guideScore only when counted == true.
guidedPoints: number, -- default 0. Separate from guideScore and from raid XP.
```

`guideScore` and `guidedPoints` are separate guild fields. Do not fold `guidedPoints` into the base guild raid XP total. Add `result.guidedPoints` only when `counted == true`. The +Marks perk, the cheaper Practice Grove, and the banner wait. Practice Grove stays free (T-060). `doubleMarks` stays false.

`tests/run.luau` requires `./RaidGuided.spec`. That require is in `tests`, not in `src`.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is.

Questions for Ghost:

1. Odd sizes use `ceil(size / 2)`. 5 needs 3 hosts. 7 needs 4. Confirm.
2. The design's "at least half its members" was not followed. Half is half of this run. A guild of 100 with 2 of 4 passes. Two hosts cannot take a 5th Seeker, even when those two are the whole guild. Confirm the row.
3. Guild ids are trimmed and not lowercased. `"Grove"` and `"grove"` are different. Seekers are everyone who does not match the host guild, including no guild and another guild. A host member cannot join as a Seeker. Confirm, and confirm the wire passes a canonical guild id.
4. A Seeker join that cannot reach half by filling the rest with hosts is refused at join. 4 Seekers with 0 hosts are still allowed. A 5th is not. Confirm, or should join always succeed and only `finish` enforce half?
5. One player per join. A list, `party`, `with`, `companions`, or a second argument is refused. Hosts use the same one-player call. `oath = true` on the join is ignored and stored false. Confirm.
6. The oath is one boolean, default false. `false` stores a decline. A string, a number, or a trailing phrase is refused and stored nowhere. The design line "helpful, attentive, willing to teach" is not a form. Everyone still on the roster must be true. Confirm.
7. `kick` never removes, before the first join and after finish. A vote whose reason is `"afk"` or `"idle"` is still a kick. The 90s removal is `release` with `"afk"`, `"remove"`, or `{ state = "remove" }` after `RaidConduct.afk`. This module does not watch the clock. `"warning"` does not remove. Confirm that split.
8. An AFK release that drops the run under 4, or under half, blocks the score until a later join repairs it. 4 hosts and 4 Seekers, then one host leaves, is 3 of 7 and does not count. The removed player's oath leaves with them. `release` after finish is refused, so the award is not clawed back. Confirm.
9. A counted finish adds `guideScore` 1 and `guidedPoints = raidXp * 2`. That replaces the base guild raid XP. It does not add `raidXp` again. `marksMultiplier` is 1. `RaidMarks.CONFIG.doubleMarks` stays false. Confirm.
10. `raidXp` is caller-supplied. There is no per-difficulty guild XP table here. It must be a whole number >= 0. 0 still awards the score and 0 points. Hard and Shardbreaker use the same placeholder. Confirm the base, and whether 0 should be refused.
11. A second finish returns `counted == false` and a zero delta. `state` keeps the award. Add to the guild only when `counted == true`. Confirm.
12. The suggested field is `guideScore` on a guild record, not on the player schema. There is no guild schema here. Version 21 is still the player schema. Do not assume 22. Should Guided points go into the guild raid XP total, or into a separate field? The +Marks perk, the cheaper Practice Grove, and the banner are not in this module. Practice Grove stays free. Confirm where the score lives and that those perks wait.
13. No role check and no boss check. Do not call `Raids.difficulty` for Hard or Shardbreaker. Call `finish` only after a real clear, never on a wipe, and not from Finder or the premade board. `practice = true` is refused even on Hard. Any difficulty id that starts with `"fracture"` is refused. Confirm.
14. The host is a guild id, not a player. The run can still finish if that guild still fills half after the original leader is AFK-removed. Confirm.
15. There is no paid skip. A third argument on `finish` is refused, so a skip flag cannot count. Nothing here costs Robux. Confirm that stays true at wiring.

Answers from Ghost:

Issue #15 rejected this note (`addComment` is not available to this token). The same answers are on PR #80.

1. Confirmed. Odd sizes use `ceil(size / 2)`. 5 needs 3 hosts. 7 needs 4. 6 needs 3. 2 of 4 and 4 of 8 pass.
2. Confirmed. Half is half of this run, not half of the whole guild. A guild of 100 with 2 of 4 passes. Two hosts cannot take a 5th Seeker, even when those two are the whole guild. The row won.
3. Confirmed. Do not fold case. The wire passes a canonical guild id. `"Grove"` and `"grove"` stay different. Seekers are everyone who does not match that id, including no guild and another guild. A host member cannot join as a Seeker. Trim is fine.
4. Confirmed. Refuse the Seeker join when the remaining slots cannot restore half. 4 Seekers with 0 hosts stay allowed. A 5th is refused. Do not defer the check to finish.
5. Confirmed. One player per join. A list, `party`, `with`, `companions`, or a second argument is refused. Hosts use the same call. `oath = true` on the join is ignored and stored false.
6. Confirmed. The oath is one boolean, default false. `false` stores a decline. A string, a number, or a trailing phrase is refused and stored nowhere. "helpful, attentive, willing to teach" is not a form. Everyone still on the roster must be true.
7. Confirmed. `kick` never removes, before the first join and after finish. A vote whose reason is `"afk"` or `"idle"` is still a kick. The 90s removal is `release` with `"afk"`, `"remove"`, or `{ state = "remove" }` after `RaidConduct.afk`. This module does not watch the clock. `"warning"` does not remove. A table with `reason`, `votes`, `initiatorUserId`, `passed == true`, or `spentKick == true` is a kick even if it also says `removal = "afk"` or `state = "remove"`. The `RaidConduct.afk` remove result has none of those fields, so passing that table still removes.
8. Confirmed. An AFK release that drops the run under 4, or under half, blocks the score until a later join repairs it. 4 hosts and 4 Seekers, then one host leaves, is 3 of 7 and does not count. The removed player's oath leaves with them. `release` after finish is refused, so the award is not clawed back.
9. Confirmed. A counted finish adds `guideScore` 1 and `guidedPoints = raidXp * 2`. Do not also add `raidXp` into that delta. `marksMultiplier` is 1. `RaidMarks.CONFIG.doubleMarks` stays false.
10. Confirmed. `raidXp` is caller-supplied. There is no per-difficulty table here. It must be a whole number >= 0. 0 still awards the score and 0 points. Hard and Shardbreaker use the same placeholder. Do not refuse 0.
11. Confirmed. A second finish returns `counted == false` and a zero delta. `state` keeps the award. Add to the guild only when `counted == true`. Use the result delta, not `state.guideScore`, on a retry.
12. `guideScore` and `guidedPoints` are separate guild fields, side by side. Not player profile fields. There is no guild schema yet. Version 21 is still the player schema. Do not assume 22. Do not fold `guidedPoints` into the base guild raid XP total. The +Marks perk, the cheaper Practice Grove, and the banner wait. Practice Grove stays free.
13. Confirmed. No role check and no boss check. Do not call `Raids.difficulty` for Hard or Shardbreaker. Call `finish` only after a real clear, never on a wipe, and not from Finder or the premade board. `practice = true` is refused even on Hard. Any difficulty id that starts with `"fracture"` is refused.
14. Confirmed. The host is a guild id, not a player. The run can still finish if that guild still fills half after the original leader is AFK-removed.
15. Confirmed. There is no paid skip. A third argument on `finish` is refused. Nothing here costs Robux. That stays true at wiring. `Loops.PREMIUM_ENABLED` stays false.

### T-075 hooks for GHOST

HELPER did not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `RaidGuided.luau`, `RaidMarks.luau`, `Schema.luau`, `MenuHub.luau`, `UiRouter.luau`, `RollHype.luau`, `Remotes.luau`, `RateLimiter.luau`, `default.project.json`, `Build.luau`, the init scripts, or any other T-012 file. `RaidContest` is pure and ready to call. It does not require `RaidGuided`, `RaidMarks`, or `Raids`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires it. Gameplay is unchanged. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. There is no paid skip of the cap, the window, or the first clear. T-075 is done. Wiring is still yours. T-072 owns `MenuHub.luau`. T-073 owns `DungeonService.luau`. Do not edit either for this.

Where the row and `docs/design/shardfall_raids.md` disagree, the row won:

- The Contest Mode research line says the first 24–48 hours, with Power capped and some gear disabled. The row says exactly 48 hours (`durationSeconds` 172800) and an item-level cap (placeholder 200). This module does not disable gear pieces and does not read a Power stat. Twenty-four hours after open is still inside the window, so 201 is still over the cap. The row won.
- The design says everyone who clears during contest gets an exclusive emblem, and the first server-wide clear also gets a Haven statue and a global announcement. The row says the first counted clear sets `statue` and `announce` once, and later clears set `emblem` for roster members not already credited. This module gives the first roster the emblem too, so "everyone" includes them. Those ids are then already credited. A later clear does not emblem them again and does not set the statue again.
- The design does not mention practice, `guided` as a difficulty, or a half-open end. The row does. `practice = true` is refused. `guided` is not a difficulty. The second at `openedAt + durationSeconds` is outside the window.

`RaidMarks.CONFIG.doubleMarks` stays false. This module does not read it and does not pay Marks. A contest clear is not a Marks payout.

Thresholds are `RaidContest.CONFIG`. `durationSeconds` is 172800. `itemLevelCap` is 200, a placeholder, because there is no item-level field in the repo. The caller passes a whole number. `maxIdLength` is 64, the same placeholder cap used for other raid ids. Do not hardcode those numbers beside the module. `DIFFICULTIES` is `shardbreaker` only. `REFUSED` is `story`, `normal`, `hard`, `fracture`, `practice`, and `guided`. Guided is a mode, not a difficulty. `Raids.DIFFICULTIES` is still Story and Normal. Do not gate this on `Raids.difficulty("shardbreaker")`. Pass the string.

`RaidService.luau`, next to the other raid requires, when you wire this:

```lua
local RaidContest = require(ReplicatedStorage.Shared.RaidContest)
```

**Return shape.** `open`, `gear`, and `clear` each return one new table. They do not write the input. A bad arg does not throw. nil, a non-table, a blank id, and a wrong type take the failure path. Store the contest when `persist == true`. `gear.persist` is always false. An `ok == false` result with `persist == false` is a bad record or a refused call. Writing the blank record from a state error would wipe a real contest. The contest is one server-wide record per raid. It is not a player profile.

| call | when | on success |
|---|---|---|
| `open(ctx)` | a raid's contest starts | `{ raidId, openedAt, statue = false, announce = false, firstRoster = {}, credited = {}, runs = {} }` |
| `gear(state, itemLevel, now)` | a Shardbreaker entry asks the cap | `allowed` and `inside`. `persist` is false. Do not save it. |
| `clear(state, record, now)` | a real Shardbreaker clear, including Guided | the first counted clear sets `statue`, `announce`, and `emblem`. Later clears set `emblem` only for new ids. |

**Open.** `ctx` is `{ raidId, openedAt }`. `raidId` is trimmed and not lowercased. `" Heartwood "` is `Heartwood`. `"Heartwood"` and `"heartwood"` are different contests. A blank id, a non-string, and an id longer than `maxIdLength` are `ERRORS.raid`. `openedAt` is a whole number of unix seconds `>= 0`. A fraction, a negative, NaN, inf, or a string is `ERRORS.time`. A second argument is `ERRORS.skip`. A `skip`, `waive`, `waiveCap`, `paid`, `robux`, `premium`, `price`, or `forceFirst` field is `ERRORS.skip` and does not open. A preloaded `statue`, `announce`, `credited`, `runs`, `firstRoster`, `durationSeconds`, `itemLevelCap`, `practice`, or `guided` is ignored. The contest starts empty. One `open` does not award anything.

**Gear.** `itemLevel` is a whole number `>= 0`. There is no item-level field to read. `0` and `200` are allowed inside the window. `201` is `ERRORS.gear` inside the window. Outside the window every finite whole level is allowed, including `0` and levels over the cap. Negatives, fractions, NaN, inf, and non-numbers are `ERRORS.level` on both sides of the window. `now` is a whole number of unix seconds `>= 0`. A fraction is `ERRORS.time`, not "inside" and not "outside".

The window is `[openedAt, openedAt + durationSeconds)`. `now == openedAt` is inside. `now == openedAt + durationSeconds - 1` is inside. `now == openedAt + durationSeconds` is outside. `now < openedAt` is outside. `inside` on the result is that test. `allowed` is the cap decision. `cap` is `CONFIG.itemLevelCap`. `persist` is false. A fourth argument is `ERRORS.skip`, including `{ guided = true }` and `{ waiveCap = true }`. A `waiveCap` field left on the saved record does not lift the cap. Guided does not waive it. This function does not take a difficulty. Call it for Shardbreaker entry only.

**Clear.** `record` is `{ runId, difficulty, practice, roster }`. `guided` may also be a boolean. A list, a non-table, or a record with a non-string key is `ERRORS.record`. The checks, in order, are: skip argument, skip field, `runId`, stored run, practice, guided flag, difficulty, roster, `now`, window.

`runId` is a positive whole number or a trimmed string. It is not lowercased. `1` and `"1"` are different runs. A missing `runId`, a blank string, `0`, a negative, a fraction, or a string longer than `maxIdLength` is `ERRORS.runId`. A stored run id is a no-op: `ok == true`, `persist == false`, `counted == false`, `reason == "duplicate"`, empty `emblem`. That holds even when the retry changes the roster, sets `practice = true`, uses another difficulty, or passes a `now` outside the window. The first stored roster stays credited.

`practice = true` is `ERRORS.practice` and awards nothing. That is checked before difficulty, so a practice Story clear is the practice error. `practice` nil and false mean a live clear. Any other type is `ERRORS.practiceFlag`. `guided` nil, true, and false are accepted. Any other type is `ERRORS.guided`. The flag is not stored. It does not change the award and it does not waive the cap.

`difficulty` is trimmed and lowercased. `" Shardbreaker "` and `"SHARDBREAKER"` count. Story, Normal, Hard, Fracture, Practice, and `guided` are `ERRORS.difficulty`. A Fracture id with a level (`"Fracture 3"`, `"fracture-1"`) is refused too. Hard is refused even when `guided = true`. An unknown id is refused. Do not call `Raids.difficulty`.

`roster` is a dense list of unique positive whole user ids, in the order you send. A member table, a string id, an empty list, a hole, or a duplicate is refused. There is no 4-to-8 party check in this module. A one-player roster can take the statue. Order is kept. The list is not sorted.

A valid Shardbreaker clear outside the window counts nothing: `ok == true`, `persist == false`, `counted == false`, `reason == "window"`, empty `emblem`. The run id is not stored. A later in-window call with that same run id can still be the first clear. A practice clear or a non-Shardbreaker clear outside the window is still an error, not a window no-op. A bad `now` is `ERRORS.time`.

The first counted clear sets `result.statue` and `result.announce` true and sets `result.emblem` to that whole roster. `state.statue` and `state.announce` stay true. `state.firstRunId` is that run. `state.firstRoster` is that roster. `state.credited` starts as that roster. `state.runs` starts as that run. Later in-window clears leave `result.statue` and `result.announce` false. They append the run id and set `result.emblem` to roster members not already in `credited`, in roster order. A later clear whose roster is already credited still counts: `counted == true`, `persist == true`, `emblem` empty. Save it so the run id is a no-op next time. Grant nothing when `emblem` is empty.

```lua
local function saveContest(contest, result)
	if result.persist ~= true then
		return contest
	end
	return result.state
end
```

Nil `state` on `gear` or `clear` is `ERRORS.state`. It does not throw. The blank state has `raidId = ""`. Do not write that blank over the contest.

**Call sites, still yours.** Keep one contest record for the raid. Do not keep a per-server copy, or two servers can each award a statue. Do not fold these rules into `Raids` or `RaidGuided`. Pass `practice = true` only if you must refuse it. A Story, Normal, Hard, Fracture, or Practice run does not call this module. A Guided Shardbreaker run does, and it still calls `gear`.

```lua
function RaidService.openContest(raidId, openedAt)
	return RaidContest.open({
		raidId = raidId,
		openedAt = openedAt,
	})
end

function RaidService.contestGear(contest, itemLevel, now)
	return RaidContest.gear(contest, itemLevel, now)
end

function RaidService.contestClear(contest, record, now)
	local result = RaidContest.clear(contest, record, now)
	if result.counted == true and result.statue == true then
		-- Place one Haven statue for result.state.firstRoster.
		-- The season length is not in this module. state.statue stays true.
	end
	if result.counted == true and result.announce == true then
		-- Global announcement once. Do not repeat it from state.announce.
	end
	if result.counted == true then
		-- Grant the emblem to result.emblem only. An empty list grants nobody.
	end
	return saveContest(contest, result), result
end
```

Call `contestGear` at Shardbreaker entry. `clear` does not re-check item level. A player who never passed `gear` is not caught here. Call `contestClear` only after a real clear, never on a wipe. `gear` never persists.

If you save the state and the announcement send then fails, a retry of that run id is a duplicate and `result.announce` is false. `state.announce` is already true. Send from the result before you drop it. This module has no separate "announcement delivered" flag.

**Schema.** HELPER does not edit `Schema.luau`. Do not add this to the player profile. A per-player copy would diverge, and two profiles could each think they took the statue. Version 21 is current. Do not assume 22 is free. There is no contest record in this repo. When you add one, add it on the server-wide record, not on the player. Do not assume its store or its version.

```lua
raidContest = {
	raidId = "heartwood", -- trimmed, not lowercased. Confirm the canonical id.
	openedAt = 0, -- unix seconds, whole, >= 0.
	statue = false, -- sticky. True after the first counted clear. Not "grant it again".
	announce = false, -- sticky. True after the first counted clear. Not "send it again".
	-- firstRunId is absent until the first counted clear, then a number or a string.
	firstRoster = {}, -- user ids on the statue clear, in roster order.
	credited = {}, -- user ids who already received the emblem. The statue roster is the prefix.
	runs = {}, -- counted in-window run ids, in order. runs[1] is firstRunId once the statue is set.
}
```

`statue`, `announce`, `firstRunId`, `firstRoster`, `credited`, and `runs` are contest fields. They are not player-schema fields. Grant the emblem from `result.emblem` when `counted == true`. The cosmetic id is not in this module. `doubleMarks` stays false. This clear does not multiply Marks.

`tests/run.luau` requires `./RaidContest.spec`. That require is in `tests`, not in `src`.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is.

Questions for Ghost:

1. Item level is a whole number `>= 0` passed by the caller. There is no item-level field in the repo. `0` and `200` are allowed inside the window. `201` is over the cap. Negatives, fractions, NaN, and inf are refused inside and outside. Confirm `0`, and confirm the wire will pass a whole number once gear has a level.
2. The window is `[openedAt, openedAt + 172800)`. The end second is outside: the cap is off and a clear counts nothing. Before `openedAt` is outside too. `now` must be a whole number of unix seconds `>= 0`. A fractional `now` is refused, not treated as inside. Confirm.
3. The research line says 24–48 hours, Power capped, and some gear disabled. The row says exactly 48 hours and item-level cap 200. This module does not disable gear and does not read Power. A clear 24 hours after open is still inside the window. Confirm the row won.
4. Shardbreaker only. Story, Normal, Hard, Fracture (any id that starts with `"fracture"`), Practice, and `guided` as a difficulty are refused. `" Shardbreaker "` counts. Hard is refused even when `guided = true`. `guided = true` on Shardbreaker counts and is not stored. It does not waive the cap. `gear` has no guided argument. Confirm Guided Shardbreaker still calls `gear` before entry.
5. `practice = true` is refused, including inside the window, and it is checked before difficulty. A practice Story clear returns the practice error. `practice` nil and false count. Any other type is refused. A difficulty of `"practice"` with the flag unset is the difficulty error. Confirm.
6. The first counted clear sets `result.statue`, `result.announce`, and `result.emblem` for that whole roster. Later clears set `emblem` only for user ids not already credited, and their `result.statue` and `result.announce` are false. `state.statue` and `state.announce` stay true. Grant and send from the result, not from the sticky state. If you save and the send then fails, a retry is a duplicate and will not say `announce` again. Confirm the first roster gets the emblem too, and say if you want a separate delivered flag in this module.
7. An out-of-window clear counts nothing and does not store the run id. A later in-window call with that same run id can still be the first clear. A practice or non-Shardbreaker clear outside the window is still an error. Confirm, or should the out-of-window attempt burn the run id?
8. A stored run id is a no-op even if the retry changes the roster, the difficulty, or sets `practice`. The first roster stays credited. `1` and `"1"` are different. String run ids are trimmed and not lowercased. `CONFIG.maxIdLength` is 64. Confirm the wire's run id and the cap.
9. Raid ids are trimmed and not lowercased. `"Heartwood"` and `"heartwood"` differ. `Raids.luau` has no raid id. Preloaded awards, duration, and cap on `open` are ignored. Confirm the canonical raid id.
10. The roster is a dense list of unique positive whole user ids. Member tables and string ids are refused. Empty is refused. There is no 4-to-8 check. A one-player clear can take the statue. Order is the order you send. Confirm, or should a contest clear require 4 to 8?
11. A later in-window clear whose roster is already credited still stores the run id. `counted` is true, `emblem` is empty, `persist` is true. Save whenever `persist == true`. Grant nobody when `emblem` is empty. Confirm.
12. The contest fields above are not player-schema fields. One server-wide record per raid, or two servers can each award a statue. Schema stays 21. Do not assume 22. Do not copy the record onto each profile. The season length is not here, and `state.statue` stays true. The emblem cosmetic id is not here. Confirm where the record lives, and whether a profile flag is still needed later so the emblem can render.
13. Nothing here costs Robux. An extra argument, or a skip / waive / paid / robux / premium / price field, is refused. It does not open, lift the cap, or force the first clear. `RaidMarks.CONFIG.doubleMarks` stays false. This module does not pay Marks. `gear` never persists. `clear` does not re-check item level. A broken record returns `persist == false` and a blank state that must not replace the live record. Confirm that stays true at wiring, and that `RaidService` owns `openContest`, `contestGear`, and `contestClear`.

### T-081 hooks for GHOST

HELPER did not edit `Schema.luau`, `RaidService.luau`, `DungeonService.luau`, `Raids.luau`, `RaidMarks.luau`, `PracticeLoot.luau`, `RaidLuck.luau`, `Remotes.luau`, `RateLimiter.luau`, `default.project.json`, `Build.luau`, the init scripts, or any other T-012 file. `RaidLockout` is pure and ready to call. It requires `RaidMarks` only to call `RaidMarks.weekKey`. It does not require `Raids`, `RaidLuck`, or `PracticeLoot`. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires it. Gameplay is unchanged. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. There is no paid skip of the lockout. T-081 is done. Wiring is still yours. Live loot still goes through `PracticeLoot.applyKill` into `Raids.applyClear`. Do not edit that path for this branch.

Where the row and the live code disagree, the row won:

- `docs/design/shardfall_raids.md` says personal loot locks once per boss per difficulty, and the Tuesday reset covers Vault, lockouts, and the Marks cap. `Raids.applyClear` still locks with `Raids.weekNumber` (Thursday epoch, `raidLock[boss .. ":" .. difficulty] = week`) and has no claim id. This module does not change that function. It calls `RaidMarks.weekKey` and does not copy `tuesdayOffset`, `weekSeconds`, or the Thursday helper.
- On `1791849600` (2026-10-13 00:00:00 UTC, a Tuesday) `RaidLockout.weekKey` is 2963, the same as `RaidMarks.weekKey`. One second earlier is 2962. `Raids.weekNumber` on that Tuesday is 2962. Do not pass that number in.
- Fracture has no lockout. Practice never locks and never loots. A reclear after a lock returns `lootEligible = false` and still allows Marks, Dust, and materials. This module does not pay them and does not roll gear.

`RaidMarks.CONFIG.doubleMarks` stays false. This module does not read it and does not pay Marks.

Tunables are `RaidLockout.CONFIG`. `maxIdLength` is 64. `retainWeeks` is 1, so a read keeps the current Tuesday week and drops every older week. `maxClaims` is 256 stored claim ids in that week. A full week refuses a new id. It does not forget an old one. Do not hardcode those numbers beside the module. There is no Tuesday offset in this CONFIG. `LOCKED` is story, normal, hard, and shardbreaker. `OPEN` is fracture. `REFUSED` is practice and guided. Guided is a mode, not a difficulty. `Raids.DIFFICULTIES` is still Story and Normal. Do not gate Hard or Shardbreaker on `Raids.difficulty`.

`RaidService.luau`, next to the other raid requires, when you wire this:

```lua
local RaidLockout = require(ReplicatedStorage.Shared.RaidLockout)
```

**Return shape.** `fresh`, `view`, `status`, and `claim` each return a new table. They do not write the input. `weekKey` returns a number or nil, the same value as `RaidMarks.weekKey`, including a fractional unix second. A bad arg does not throw. nil, NaN, a non-table, and a wrong type take the failure path. Store `state` only when `persist == true`. An `ok == false` result with `persist == false` is a bad record, a bad clock, or a bad arg. A state error's `state.weeks` is empty. Writing that blank over the profile would wipe real locks. A clock error returns a copy of the record, including a future week, and `persist` is false.

| call | when | on success |
|---|---|---|
| `weekKey(now)` | you need the Tuesday key and nothing else | the key, or nil when `now` cannot be used |
| `fresh()` | a brand-new profile shape, if you want one | `{ weeks = {} }` |
| `view(state, now)` | profile load, so old weeks can be dropped | the pruned record. `persist` is true only when a week was dropped |
| `status(state, query, now)` | the raids panel asks if this pair is locked | `locked`, `lootEligible`, and `reclearRewards` for that pair. No claim id is stored |
| `claim(state, claim, now)` | a boss clear is ready to resolve loot | the grant decision. The same claim id is a no-op |

**What a claim is.** Pass `{ claimId, bossId, difficulty, practice, guided }`. `claimId` is a trimmed string or a positive whole number. It is not lowercased. `" same "` is `same`. `1` and `"1"` are different claims. A missing id, a blank, `0`, a negative, a fraction, NaN, inf, or a string longer than `maxIdLength` is `ERRORS.claimId`. A GUID from `HttpService:GenerateGUID(false)` is 36 characters and fits. `bossId` and `difficulty` are trimmed and lowercased. `" Twins "` / `" Hard "` is `twins` / `hard`. A colon in the boss id is `ERRORS.boss`. Boss ids are not checked against `Raids.WINGS`. Heartwood's room ids are `twins`, `sapwell`, `galecrown`, and `awakened`. A later raid can pass a new id.

`practice` nil and false are a live clear. `practice = true` never locks and never loots: `lootEligible` false, `reclearRewards` false, `locked` false, `reason` `practice`. The id is not stored, so a later live claim with that same id can still loot. Any other practice type is `ERRORS.practice`, unless the id is already stored. `guided` nil, true, and false are accepted. Any other type is `ERRORS.guided`. Guided does not waive the lock and is not stored. Difficulty `practice` and difficulty `guided` are `ERRORS.difficulty`.

The checks on `claim`, in order, are: extra argument, rules, state, time, a stored week newer than `now`, prune, claim shape, skip field, claim id, stored claim id, practice flag, guided flag, practice result, difficulty, boss, cap, then store.

A stored claim id is a no-op even when the retry changes the boss, the difficulty, or sets `practice`. `ok` is true, `persist` is true only when prune dropped a week, `lootEligible` is false, `reclearRewards` is false, `locked` is false, `reason` is `duplicate`. Grant nothing. A skip field on that retry is `ERRORS.skip` instead, and it does not clear the lock. `1` replayed as `"1"` is not a duplicate.

Story, Normal, Hard, and Shardbreaker each lock separately. The first accepted claim for that boss and difficulty this week is `reason` `loot`, `lootEligible` true, `reclearRewards` true, `locked` true. The lock string is `bossId .. ":" .. difficulty`, for example `twins:story`. A later new claim id for that same pair is `reason` `lockout`, `lootEligible` false, `reclearRewards` true, `locked` true. The lock list does not grow a duplicate. `reclearRewards` means Marks, Dust, and materials are allowed. It is also true on the first clear, so the wire can pay them from that flag alone. It is false for practice and for a duplicate.

Fracture has no lockout. `fracture`, `Fracture-3`, `fracture 12`, and `fracture_2` are open. Each new claim id is `lootEligible` true, `reclearRewards` true, `locked` false, and no lock is stored. The same claim id is still a no-op. `fractured` and `fracture-` are `ERRORS.difficulty`. A `level` field is ignored. A `removal` field is ignored: `removal = "afk"` still locks and can loot. That is an open question.

`status` uses the same difficulty rules and does not store a claim. `claimId` on the result is nil. A `claimId` on the query is ignored, so the panel cannot burn an id. `locked` false and `reason` `loot` means the next new claim would be loot eligible. `locked` true and `reason` `lockout` means a reclear. `status` does not check the cap. A full week can still look eligible until `claim` returns `ERRORS.full`. `view` only prunes.

Nil `state`, or a table whose `weeks` is nil, is an empty record. The first accepted claim should be saved. A broken row (a hole, a duplicate week, a duplicate claim id, a lock that is not `boss:difficulty` of a locking difficulty, an uppercase boss, a claim id that still has spaces, a non-whole week, a week key below 0) is `ERRORS.state`. `persist` is false and `state.weeks` is empty. Do not write that blank over the profile. A week key above `2^53 - 1` is refused the same way. A negative, NaN, or infinite `now` is `ERRORS.time`. `weekKey` on that error is -1. A stored week newer than `now` is `ERRORS.clock`. Do not prune it and do not grant.

An extra argument, or a `skip`, `waive`, `waiveLock`, `waiveLockout`, `bypass`, `bypassLock`, `paid`, `robux`, `premium`, `price`, `productId`, `gamePass`, `force`, `unlock`, `skipLock`, or `skipLockout` field, is `ERRORS.skip`. `false` still counts as present. It does not lock and it does not grant. The same field names already sitting on a saved profile are ignored. They do not waive the lock, and they are not copied onto the returned state.

The cap is per kept week. Claim 256 stores. Claim 257 is `ERRORS.full`, `persist` false, `lootEligible` false, `reclearRewards` false. A duplicate of a stored id still no-ops when the week is full. The next Tuesday starts empty because the old week was pruned. Fracture ids count toward the same cap. A Fracture week that fills it also blocks a new Story lock until the reset.

```lua
local function lockoutState(data)
	return data.raidLootLock
end

local function saveLockout(data, result)
	if result.persist ~= true then
		return
	end
	data.raidLootLock = result.state
end
```

**Call sites, still yours.** Do not fold these rules into `Raids.applyClear`. That function still writes Thursday `raidLock` and may grant a chest. Calling both for one clear would lock the player on two different week keys. Add the functions below on `RaidService`. The boss death is the `enemy.hp <= 0` block in `DungeonService` that already calls `PracticeLoot.applyKill` for a Heartwood boss. Call `claimLoot` from that mutate when you are ready to switch, and stop using `applyClear` for the lock. Until that wire, leave the live path alone.

```lua
function RaidService.claimLoot(player, claim)
	local now = os.time()
	local claimed = nil
	local ok, err = DataService.mutate(player, function(data)
		claimed = RaidLockout.claim(lockoutState(data), claim, now)
		saveLockout(data, claimed)
		if claimed.ok ~= true then
			return claimed.error
		end
		if claimed.reason == "duplicate" then
			return nil
		end
		if claimed.lootEligible then
			-- Roll personal loot once. This module does not know the bag.
		end
		if claimed.reclearRewards then
			-- Marks, Dust, and materials. Not a second loot roll.
		end
		return nil
	end)
	return ok, claimed, err
end

function RaidService.lootLock(player, bossId, difficulty, practice, guided)
	local now = os.time()
	local status = nil
	DataService.mutate(player, function(data)
		status = RaidLockout.status(lockoutState(data), {
			bossId = bossId,
			difficulty = difficulty,
			practice = practice == true,
			guided = guided == true,
		}, now)
		saveLockout(data, status)
		return nil
	end)
	return status
end
```

`practice` on the live run is `run.practice == true`. Pass it through. A practice claim returns `ok` and does not loot. `guided` is not live. Pass `guided = true` only for a real Guided clear. It still locks Hard or Shardbreaker. `RaidService.lootLock` is a read. Save it when `persist` is true so a Tuesday login drops last week's rows. Grant from `claim`, in the same mutate as the save. A retry of a saved id must grant nothing. There is no paid skip of the lockout.

**Schema.** HELPER does not edit `Schema.luau`. Add this on the next free schema version at wiring time. Do not assume a version number from this branch. Version 21 was current when T-081 opened. Do not assume 22 is still free. Do not reuse `raidLock`. That field stays the live Thursday map until you switch. Do not copy those rows into this table. The week keys do not match, and they have no claim ids.

```lua
raidLootLock: any, -- nil, or { weeks = { { weekKey, locks, claims } } }. Default nil.
```

Nil reads as no locks. `{ weeks = {} }` is the same. `weekKey` is `RaidLockout.weekKey`. `locks` is `{ "twins:story" }` for the current week. `claims` is the ids already resolved, in order, each a string or a positive whole number. One row per kept week. With `retainWeeks` 1, a saved profile holds at most one row after a successful read. Leave a broken row for the module to refuse. If `sanitize` turns it into nil, a corrupt record looks like a new player and can loot again.

`tests/run.luau` requires `./RaidLockout.spec`. That require is in `tests`, not in `src`.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is.

Questions for Ghost:

1. The suggested profile field is `raidLootLock`, shaped as `{ weeks = { { weekKey, locks, claims } } }`. Nil means no locks. `raidLock` stays the live Thursday map and is not reused. Schema stays 21. Do not assume 22 is free. Confirm the name, and confirm you will not copy `raidLock` rows into this table.
2. `retainWeeks` is 1. A read in the new Tuesday drops every older week, including claim ids. A retry after the reset of an id that was saved last week is not recognized, so that id can loot again. Confirm, or should last week's ids stay idempotent (`retainWeeks` 2) while last week's locks do not block?
3. `maxClaims` is 256 per kept week. The next new id is `ERRORS.full` and grants nothing, so an id is never dropped. Fracture stores one id per clear and never a lock, and those ids share the cap with Story, Normal, Hard, and Shardbreaker. A full Fracture week also blocks a new Story lock until Tuesday. Confirm the cap.
4. Practice does not store the claim id. A later live claim with that same id can still loot. A stored live id replayed with `practice = true` is a duplicate and grants nothing. `practice = "true"` is an error unless that id is already stored. Confirm.
5. Fracture never writes a lock. `fracture`, `fracture-3`, `fracture 12`, and `fracture_2` each stay loot eligible per new claim id. `fractured` and `fracture-` are refused. A `level` field is ignored, so every call that passes difficulty `fracture` shares "no lockout" and does not lock the others. Confirm the wire's fracture id.
6. `guided = true` does not waive the lock and is not stored. Difficulty `guided` is refused. Guided Hard and Guided Shardbreaker share the lock with an unguided clear of that same boss and difficulty. Confirm.
7. `removal` is not read. `removal = "afk"` or `"kick"` still locks and can loot. The raid design says an AFK removal loses rewards. Confirm whether the wire should skip `claim` for those removals, or this module should refuse them.
8. A duplicate returns `ok` true, `lootEligible` false, `reclearRewards` false, and `persist` only when an older week was pruned. Grant nothing. Do the grant in the same mutate as the save. `1` and `"1"` differ. String ids are trimmed and not lowercased. Boss ids are trimmed and lowercased. `maxIdLength` is 64. Confirm the wire's claim id.
9. The first clear returns `lootEligible` true and `reclearRewards` true. A reclear returns `lootEligible` false and `reclearRewards` true. This module does not pay Marks, Dust, or materials and does not roll gear. Confirm `RaidService` owns that split, and that the wire will not also call `Raids.applyClear` for the lock.
10. Boss ids are not checked against `Raids.WINGS`. `" Twins "` is `twins`. A colon in the boss id is refused. Confirm Heartwood ids `twins`, `sapwell`, `galecrown`, and `awakened`, and that a later raid can pass a new id.
11. The week key is `RaidMarks.weekKey`, called, not copied. `1791849600` is 2963. One second earlier is 2962. `Raids.weekNumber` on that Tuesday is 2962. A stored week newer than `now` is `ERRORS.clock` and must not replace the profile. A state error returns an empty `weeks` with `persist` false. Confirm the wire passes unix seconds and never saves `persist == false`.
12. Nothing here costs Robux. An extra argument, or a skip / waive / paid / robux / premium / price field, is refused and does not clear the lock. The same names already stored on the profile are ignored. Confirm no paid skip will be added at wiring.
13. `RaidLuck` should not gain pity when `lootEligible` is false. This module does not call `RaidLuck`. Confirm the wire passes that flag into the pity settle. T-045 called a dry lockout clear the clear that adds pity. A reclear is not that clear.
14. `status` does not store a claim and does not check the cap. `view` on profile load is what prunes. Confirm the panel reads `status`, and that a full week is allowed to look eligible until `claim` returns `ERRORS.full`.

### T-083 hooks for GHOST

HELPER did not edit `RaidLockout.luau`, `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `Keybinds.luau`, `UiRouter.luau`, `RaidMarks.luau`, `RaidPractice.luau`, `Remotes.luau`, `RateLimiter.luau`, `default.project.json`, `Build.luau`, the init scripts, or any other T-012 file. `RaidStrategy` is pure and ready to call. It requires nothing. `$path` already includes `src/ReplicatedStorage/Shared`, so the module is in the place file without a `default.project.json` edit. Nothing in `src` requires it. Gameplay is unchanged. No build stamp. No new remote. No DataStore. No MemoryStore. No RNG. No clock. Nothing here costs Robux. There is no paid marker, preset, or skip. T-083 is done. Wiring is still yours. The row stays `claimed`.

Where the row and `docs/design/shardfall_raids.md` disagree, the row won:

- The design says the raid leader drags markers (stack spots, soak 1, soak 2). The row says `place` upserts by id, and the kinds are `stack`, `soak1`, and `soak2`. There is no drag delta here. Send the new `x` and `y`.
- The design says presets can be saved per guild. The row caps one board at 16 markers and one guild at 8 presets. A full list refuses a new entry. It does not drop an old one. `load` does not write the preset.
- The design names Raid Lead and Assistants. `RaidFinder` seats are tank, healer, dps, and flex. Those are other roles. They cannot place, move, or remove. The accepted token is `lead`, not `Raid Lead`.
- Practice Grove, difficulty, and the Tuesday reset do not change this board. This module does not require `RaidPractice`, `RaidMarks`, or `Raids`. It has no week key.

`RaidMarks.CONFIG.doubleMarks` stays false. This module does not read it and does not pay Marks. A marker is not loot.

Tunables are `RaidStrategy.CONFIG`. `maxMarkers` is 16. `maxPresets` is 8, per guild id, not a global cap. `maxIdLength` is 64, the same placeholder cap used for other raid ids. `leadRole` is `lead`. `kinds` is `stack`, `soak1`, and `soak2`, and that inner table is frozen too. Do not hardcode those numbers beside the module.

`RaidService.luau`, next to the other raid requires, when you wire this:

```lua
local RaidStrategy = require(ReplicatedStorage.Shared.RaidStrategy)
```

**Return shape.** `fresh`, `freshPresets`, `view`, `place`, `remove`, `save`, and `load` each return a new table. They do not write the input. A bad arg does not throw. nil, NaN, a non-table, a blank id, and a wrong type take the failure path. `persist` means "write this call's `state`". `place` and `remove` use `state` as the shared board. `save` and `load` use `state` as the preset book, and they also return `board`. Store the board or the book only when `persist == true`. An `ok == false` result with `persist == false` must not replace the live board or the guild book. A broken board's `state.markers` is empty. A broken book's `state.guilds` is empty. Writing that blank would wipe the real one.

| call | when | on success |
|---|---|---|
| `fresh()` | a raid server wants an empty shared board | `{ markers = {} }` |
| `freshPresets()` | a guild has no preset book yet | `{ guilds = {} }` |
| `view(board)` | any party member reads the board | a canonical copy. `persist` is false. No role |
| `place(board, request)` | the lead adds or moves one marker | the board. The same id keeps its slot. A new id appends |
| `remove(board, request)` | the lead removes one id | the board without that marker |
| `save(book, request)` | someone copies the current board under a guild and a name | the book, with a new copy of the markers. `persist` is false when that copy was already stored |
| `load(book, request)` | the party wants a preset on the shared board | `board` is a new board. `persist` is false. The preset is not written |

**Place and remove.** `request` for `place` is `{ role, id, kind, x, y }`. `request` for `remove` is `{ role, id }`. `role` is trimmed and lowercased. `" Lead "` is `lead`. `"Raid Lead"`, `"assistant"`, `"tank"`, `"healer"`, `"dps"`, `"flex"`, a blank, and a missing role are `ERRORS.role`. The board is unchanged. `id` is trimmed and not lowercased. `" a "` and `"a"` are the same marker. `"A"` and `"a"` differ. A number, a blank, or a string longer than `maxIdLength` is `ERRORS.id`. `kind` is trimmed and lowercased. `" Soak1 "` is `soak1`. `spread`, `soak`, `soak 1`, and `soak3` are `ERRORS.kind`. `x` and `y` must each be a number in 0..1 inclusive. `0` and `1` are on the board. A string, nil, NaN, inf, or -inf is `ERRORS.coord`. Nothing is clamped. `-0` is stored as `0`.

The checks on `place`, in order, are: extra argument, rules, board, request shape, skip field, role, id, kind, coordinates, cap, then upsert. An assistant with a bad coordinate still gets `ERRORS.role`. A lead with kind `spread` and `x = 5` gets `ERRORS.kind`. `remove` uses the same order through the id, then `ERRORS.missing` when that id is not on the board. A missing id removes nothing.

The same id updates `kind`, `x`, and `y` and stays in its slot. A new id appends. A repeat of the same kind and coordinates is `ok` with `persist == false`. The 17th new id is `ERRORS.full`. The 16 stay, including the first. Moving an existing id still works on a full board. After a remove, a new id fits again.

**Presets.** `request` for `save` is `{ guildId, name, board }`. `request` for `load` is `{ guildId, name }`. `guildId` and `name` are trimmed and not lowercased. `" Grove "` is `Grove`. `"P1"` and `"p1"` differ. `"Grove"` and `"grove"` are different guilds, and each gets 8 names. A blank or a string longer than `maxIdLength` is `ERRORS.guild` or `ERRORS.name`. `save` copies `request.board`. A later `place` on the live board does not change the preset. The marker tables in the book are not the live marker tables. `load` copies them out again. `load`'s `persist` is false even when `ok` is true. Do not write `load`'s `state`. Replace the shared board with `load`'s `board` only when `ok == true`. A missing name is `ERRORS.preset`, `persist` false, and `board` is empty. Adopting that empty board would clear the live one. An empty live board can be saved. `role` on `save` or `load` is ignored, so an assistant can overwrite a preset today.

A new name on a guild that already has 8 is `ERRORS.presetsFull`. Those 8 stay. Saving an existing name still copies when the list is full. A second guild can still take its first preset. An identical copy is `ok` with `persist == false`.

The checks on `save`, in order, are: extra argument, rules, book, request shape, skip field, guild id, name, board, cap for a new name, then copy. `load` uses the same order through the name, then the missing preset. Neither call reads `role`.

**One board.** Nil `board` is `{ markers = {} }`. Nil book, or a book whose `guilds` is nil, is `{ guilds = {} }`. A missing `markers` key is an empty board. `practice`, `difficulty`, `week`, `weekKey`, `userId`, `player`, `loot`, `rewards`, `marks`, `bossId`, `guided`, and `phase` on a request are ignored. They are not copied onto the marker or the result. Two places with different `userId`s append to the same marker list. `loot` grants nothing. There is no `marks` field on the result. `bossId` does not split the book. The preset name is the only label. Unknown string keys on a stored board are dropped on the copy. A non-string key, a hole, a duplicate id, a stored id that still has spaces, a stored kind that is not exactly `stack`, `soak1`, or `soak2`, a stored coordinate outside 0..1, NaN, or inf is `ERRORS.state`. A stored board with more than 16 markers is `ERRORS.state`. It is not trimmed. A duplicate guild id, a duplicate preset name, or a guild with more than 8 presets is `ERRORS.presets`. It is not trimmed.

An extra argument is `ERRORS.skip` and the returned `state` is blank, because the record is not read. A skip field on the request is also `ERRORS.skip`, and that result keeps a canonical copy of the valid record. `false` still counts as present. The names are `skip`, `waive`, `waiveLock`, `waiveLockout`, `bypass`, `bypassLock`, `paid`, `robux`, `premium`, `price`, `productId`, `gamePass`, `force`, `unlock`, `skipLock`, `skipLockout`, `paidMarker`, `paidPreset`, `skipCap`, `buyMarker`, and `buyPreset`. `force` does not place, does not beat the cap, and does not make an assistant into the lead. It is refused before the role check.

```lua
local function saveBoard(board, result)
	if result.persist ~= true then
		return board
	end
	return result.state
end

local function saveBook(book, result)
	if result.persist ~= true then
		return book
	end
	return result.state
end
```

**Call sites, still yours.** Keep one board in memory on the raid server and replicate it to the whole party. Do not fold these rules into `Raids` or `RaidFinder`. Do not trust a client that sends `role = "lead"`. Pass `lead` only when that player is the raid lead on the server roster.

```lua
function RaidService.placeMarker(board, role, marker)
	local result = RaidStrategy.place(board, {
		role = role,
		id = marker.id,
		kind = marker.kind,
		x = marker.x,
		y = marker.y,
	})
	return saveBoard(board, result), result
end

function RaidService.removeMarker(board, role, id)
	local result = RaidStrategy.remove(board, {
		role = role,
		id = id,
	})
	return saveBoard(board, result), result
end

function RaidService.readBoard(board)
	return RaidStrategy.view(board)
end

function RaidService.saveStrategy(book, guildId, name, board)
	local result = RaidStrategy.save(book, {
		guildId = guildId,
		name = name,
		board = board,
	})
	return saveBook(book, result), result
end

function RaidService.loadStrategy(book, guildId, name)
	local result = RaidStrategy.load(book, {
		guildId = guildId,
		name = name,
	})
	-- persist is false. Do not write the book.
	-- When result.ok == true, the shared board becomes result.board.
	return result
end
```

`readBoard` is safe for a panel. Do not save it. Replicate after `placeMarker` or `removeMarker` only when `persist == true`. `saveStrategy` writes the book only when `persist == true`. `loadStrategy` never writes the book.

**Where the presets live.** HELPER does not edit `Schema.luau`. Do not add this to the player profile. A per-player copy would diverge, and the row says the board is not per player. Version 21 was current when T-083 opened. Do not assume 22 is still free. There is no guild schema in this repo. When a guild record exists, add this on that record, beside the T-074 `guideScore` field. Do not assume that record's version.

```lua
strategyPresets: any, -- nil, or { presets = { { name, markers = { { id, kind, x, y } } } } }
```

Nil means that guild has no presets. The live board is not this field. The live board is one table on the raid server. Wrap one guild for the module, or pass a book of guilds if one record holds all of them:

```lua
{
	guilds = {
		{
			guildId = "Grove",
			presets = {
				{
					name = "Twins P2",
					markers = {
						{ id = "A", kind = "stack", x = 0.25, y = 0.5 },
					},
				},
			},
		},
	},
}
```

Pass the caller's guild id into `save` and `load`. Do not copy the book onto a profile. Do not key it by user id, boss, difficulty, or Tuesday week.

`tests/run.luau` requires `./RaidStrategy.spec`. That require is in `tests`, not in `src`.

Build stamp files are T-012. This branch does not change them. The module is not required by the server or the client, so the printed stamp stays where it is.

Questions for Ghost:

1. The lead token is `lead` after trim and lowercase. `" Lead "` may place. `"Raid Lead"`, `"assistant"`, `"tank"`, `"healer"`, `"dps"`, and `"flex"` may not. Confirm the roster token, and that `RaidService` sets `role` from the server roster rather than from the client payload.
2. `place` and `remove` are the only role checks. `save` and `load` do not read `role`. An assistant can overwrite a guild preset and can load one. Confirm, or should `save` be lead-only while `load` stays open to the whole party?
3. Guild presets are not player-schema fields. The live board is one shared table on the raid server. The preset book is suggested as `strategyPresets` on the guild record, passed in as `{ guilds = { { guildId, presets } } }`. There is no guild schema in this repo. Player schema was 21 when this opened. Do not assume 22 is free. Do not add the book to `Schema.luau`. Confirm where the book lives.
4. `maxMarkers` is 16. A new id on a full board is `ERRORS.full` and drops nothing. A place of an existing id still moves it when the board is full. A stored board with more than 16 markers is `ERRORS.state` and is not trimmed. Confirm the cap.
5. `maxPresets` is 8 per guild id, not a global cap. A new name on a full guild is `ERRORS.presetsFull` and drops nothing. Saving an existing name still copies when that guild is full. `"Grove"` and `"grove"` each get 8. A stored guild with more than 8 presets is `ERRORS.presets` and is not trimmed. Confirm.
6. Marker ids, preset names, and guild ids are trimmed and not lowercased. `" a "` and `"a"` are the same marker. `"P1"` and `"p1"` are different presets. A number is refused. `maxIdLength` is 64. Confirm the wire's ids and the cap.
7. Kinds are trimmed and lowercased to `stack`, `soak1`, and `soak2`. `" Soak1 "` is `soak1`. `spread`, `soak`, and `soak3` are refused. This module does not size a soak or store a color. Confirm the catalog.
8. `x` and `y` must be numbers in 0..1 inclusive. `0` and `1` are on the board. A string, nil, NaN, inf, or -inf is refused. Values are not clamped. `-0` is stored as `0`. Confirm the arena uses that unit square.
9. The same id updates kind, x, and y and keeps its slot. A new id appends. `remove` of an id that is not on the board is `ERRORS.missing` and removes nothing. A repeat place of the same kind and coordinates is `ok` with `persist == false`. Confirm.
10. `save` copies the markers from `request.board`. Later places on the live board do not change the preset. `load` returns that copy as `board` and does not write the preset (`persist` is false). Replace the shared board with `result.board` only when `load` returns `ok == true`. An empty board can be saved. Confirm that adopt rule, and whether an empty preset should be refused.
11. `practice`, `difficulty`, `week`, `weekKey`, `userId`, `loot`, and `bossId` on a request are ignored. They are not stored. A practice place uses the same cap, kinds, and lead rule. `userId` does not make a second board. `loot` grants nothing. `bossId` is ignored, so the book is not split by boss. The preset name is the only label. Confirm the wire will not expect a per-player, per-boss, or per-week board.
12. A broken board returns `ok == false`, `persist == false`, and `{ markers = {} }`. A broken preset book returns `ok == false`, `persist == false`, and `{ guilds = {} }`. Writing that blank would wipe the live board or the guild book. An extra argument does the same. A skip field on a valid request returns a copy of the valid record and still does not persist. Confirm the wire writes `state` only when `persist == true`, and adopts a loaded board only when `ok == true`.
13. Nothing here costs Robux. An extra argument, or a `skip`, `waive`, `paid`, `robux`, `premium`, `price`, `productId`, `gamePass`, `force`, `unlock`, `paidMarker`, `paidPreset`, `skipCap`, `buyMarker`, or `buyPreset` field, is `ERRORS.skip`. `false` still counts as present. `force` does not place, bypass the cap, or bypass the lead. Confirm no paid marker, preset, or skip will be added at wiring.

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
