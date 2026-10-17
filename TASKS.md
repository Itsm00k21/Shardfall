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
| AUDIT-A | AUDIT-A (server exploits) | GHOST | `cursor/audit-a-server-exploits-d913` | Practice kill loot, the level 15 gate, and client phase/HP (`DungeonService.luau`, `RaidService.luau`, `init.server.luau` class XP hook, new `PracticeLoot.luau`). Server perfect dodge (`CombatService.luau`, `CombatFeel.luau`, `Remotes.luau`, `RateLimiter.luau`, `CombatHud.luau` dodge payload only). Salvage, remove, and feed of a market or trade hold (`Crafting.luau`, `InventoryView.luau`, `Trading.luau`, `InventoryService.luau`). Tests: `tests/AuditExploit.spec.luau`, `tests/run.luau`. Stamp lines in `Build.luau`, `init.server.luau`, `init.client.luau`, `DungeonService.luau`. Do not bump Schema. Do not edit `docs/offload/`. | claimed | — |

T-010 is the rest of the cut line "Raid Hard, the Vault, and Relic Sets." Raid Hard itself is T-007. Relic Set rules come from T-025. T-010 keeps the Vault and the wiring. Heartwood Vendor sells weaker helper items for Raid Marks or materials, never Relic Set pieces. Ghost wires that vendor later, under T-010.

Next free id is T-059.

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
| T-057 | Raid Story Echo buff rules (pure, no wiring) | HELPER | `helper/raid-echo-9721` | new `src/ReplicatedStorage/Shared/RaidEcho.luau`, new `tests/RaidEcho.spec.luau`, one require line in `tests/run.luau`, and a 'T-057 hooks for GHOST' section in this file. Pure, server-authoritative rules for the Story-tier Echo buff in `docs/design/shardfall_raids.md` (Difficulty ladder: 'An Echo buff (+5% per wipe, max +25%) stacks after wipes'). Frozen CONFIG: 5% per wipe, cap 25%, Story only (Normal live but never gets Echo; Hard/Shardbreaker/Fracture never). A wipe is a whole-party death after a boss pull started; partial deaths, Practice Grove pulls, and resets before the pull do not count. Expose: a fresh per-run state, `wipe(state, ctx)` returning a new state (no input writes), `bonus(state, difficulty)` as a fraction 0 to 0.25, `apply(stat, state, difficulty)` for player damage, healing, and max HP multipliers, and a reset on boss kill or run end. The buff is party-wide and shown to the party, not per player. Time and difficulty are passed in. No services, remotes, DataStores, RNG, or build stamp. Do not edit `Raids.luau`, `RaidService.luau`, `DungeonService.luau`, `Schema.luau`, `CombatMath.luau`, or T-012. Nothing requires it until GHOST wires it, so gameplay is unchanged. Open questions (per-boss vs whole-run stacking, whether a backfill inherits the stacks, whether it shows on the RaidRecap panel) go in the hooks section. | claimed | — |

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
