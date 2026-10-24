# Changelog

**Rule: every PR adds a line here (what changed, what moved).**

All notable changes to Shardfall are recorded in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries start at the
locked V1 roadmap (Oct 21, 2026); older work lives in the git log.

Entries marked **(merged)** are on `cursor/live-build-9721`. Entries marked
**(open)** are PRs still waiting on review or a playtest; when one merges, change
its tag to merged and add the merge commit.

## [Unreleased]

### Added
- Phase 3 stuck-enemy check (flag `enemyTypes`, off): a server watchdog
  in the wave flow tracks progress toward the target. No meaningful
  movement or damage for `Enemies.STUCK_SECONDS` (30, rejected above 30)
  nudges and re-paths, then respawns on a clear point inside the arena.
  No HUD edit, no save write, `schemaVersion` stays 26. Stacked on the
  wave-5 boss. (open)
- Phase 3 wave-5 boss (flag `enemyTypes`, off): wave 5 is one boss plus
  4 adds drawn from chaser, ranged, and tank. Boss stats and the adds
  count live in `Shared/Config/Enemies.luau`. `WaveFlowService` spawns
  the gray blocks only while the flag is on, and sends `bossEnter` /
  `bossDown` when `Shared.Analytics.event` exists (that module is not
  in the tree). No HUD edit, no save write, `schemaVersion` stays 26.
  Stacked on the wave flow. (open)
- Phase 3 wave flow (flag `enemyTypes`, off): waves of 6, 8, 10, and 12.
  Each wave mixes chaser, ranged, and tank. Counts and mixes live in
  `Shared/Config/Enemies.luau`. `WaveFlowService` pushes `{ wave, left }`
  on `WaveCounter` only while the flag is on. Boot does not call it.
  No HUD edit, no save write, `schemaVersion` stays 26. Stacked on the
  enemy-type roster. (open)
- Phase 3 enemy types (flag `enemyTypes`, off): chaser, ranged, and tank.
  Numbers live in `Shared/Config/Enemies.luau` and on `Config.Enemies`.
  `EnemyTypeService` steps them and describes gray boxes only while the
  flag is on. Boot does not call it. Waves and rooms do not spawn them.
  No save write and no HUD change. (open)
- Ranged kiting stays inside the `Config/Enemies` arena (90 studs, the
  locked 80–100 span). A ranged shot travels at `projectileSpeed` and a
  server line-of-sight raycast runs before damage. Flag stays off. No
  save write and no HUD change. (open)
- Phase 3: solo wave arena. Shard Gate pad, a round arena 90 studs across
  with 3 edge gates, enemy types 1-3, waves 6/8/10/12 then a boss and 4 adds.
  No Leave. A run ends on clear, wipe, timeout, or disconnect, and the player
  keeps every earned drop once. Ground chips auto-collect at wave end and on
  wipe. A full Bag holds overflow for the session only (`overflowCap` in
  config). At run end or disconnect that overflow is salvaged into existing
  `gearEssence` at the normal salvage rates, once. Settlement is one receipt
  per run id on run end, disconnect, teleport, shutdown, and a failed save
  (the retry pays once). The server owns the wave clock and ignores a
  client time step. No `arenaMail` field.
  schemaVersion stays 26. Stuck enemies teleport or
  despawn. Pickup radius stays 12 studs. Boss HP bar, camera room, slam after
  the red warning, 1.5s boss death pause, hit flash and death puff. Metrics
  add gateSpent, waveClear, and bossEnter. `LaunchGate.waveArena` and
  `WaveArenaConfig.enabled` both stay off. (open)
- Playtest fixes (Ghost, clips 6 and 7): x10 results no longer badge pets as "Salvaged" (`GearHooks.markBatch` only checked `profile.inventory`; it now never marks pets and only infers for weapons/armor at or under an active auto-salvage cap; the server never salvaged them). Pets page: worn pet shows one EQUIPPED state (second tap unequips), pet cards get the star row and padlock, `equipUid` finds pets for the optimistic flip. Bag detail shows "You have N gold" under an affordable UPGRADE (clip 6 had Gold 250 vs cost 150, so bright was correct). Hero Power adds worn gear's Item Power to the combat score (same scale as card Power, per shardfall_progression.md). Intro: Skip intro always closes the card and applies the answer, Continue at a world step shows a hint instead of a dead click, card and goals hide while the hub or Inventory is open, goals get a backing panel beside the card on wide screens. Header padlock tidied (faint well, thin arch, keyhole). Client only. (open)
- Gear detail fixes (Ghost, playtest clip 5): the pet detail panel uses the gear header (icon, rarity-coloured name, "Rarity · Pet", padlock), opens scrolled to the top with stats below, and shows one EQUIPPED state or EQUIP; the Lock button is gone (the header padlock locks). Correction to clip 4: UnequipItem is a live remote, so EQUIPPED on gear and pets now unequips on a second tap within 3 s ("Tap again to unequip"). Padlocks are drawn shapes: a muted grey open lock when unlocked, a gold closed lock when locked, on cards and headers. Every gear card shows a star row, including ☆☆☆☆☆ at 0 stars. Hero panel Crit damage reads as a percent (3.42 -> 342%); Attack speed stays a plain number. Accessories keep the old panel. Client only. (open)
- Gear detail fixes (Ghost, playtest clip 4): UPGRADE dims and says "Need N more gold" when gold is short; Shard Core feeds only the selected weapon (one "Feed N Essence" button, inline confirm, toast "X core Lv N: +perk", new pip and perk row lit), the all-cores picker is gone; Crit Damage shows as a percent (4.51 -> 451%); worn gear shows one EQUIPPED state (no green "Equipped" header, no Unequip button, which called a parked remote). Client only. (open)
- Roll reveal line (Ghost, #390): a merged dupe reads "Uncommon · 23% · ★ 0 -> ★ 1" (no item name; the title already has it) and an auto-salvaged card reads "Auto-salvaged +N Essence". (open)
- One inventory (Ghost, #390, Phase 3): with `oneInventory` on (off by default), the Bag rail button, the B key and the hub Bag tab open the full Inventory directly, and the small Bag's "Open full bag" is retired. The Inventory is a centered modal right of the rail and under the HP card (`InventoryLayout`: 88% wide, max 1180x680, phone sheet). It has a header with capacity, Equip Best, Close and "+ Slots" (DevAccess owners only); one tabs row; ONE filter row (Search plus Rarity/Type/Sort `Dropdown`s, no sideways scroll); and the thin `GearBar` action bar. The 4-6 column grid has square-ish cards with a centered icon, a rarity border and tint, a 2-line name, a +level/stars line, an "E" badge and a gold padlock only when locked (faint on hover). The detail panel starts on the equipped weapon and stays filled in Select mode. Auto-salvage moves behind a settings popover: a toggle plus a cap of Common or Uncommon only (client clamp `GearHooks.safeCap`), with a confirm on turning it on or raising the cap. Default Off. Bulk select is a "Select all ≤" dropdown that says why nothing qualifies. Echo server APIs and saves unchanged. (open)
- Gear UI hooks (Ghost): Bag "Salvage tools" mounts `BagTools` (`gearSalvage`), the details pane shows upgrade-boosted stats via `UpgradeScale.preview` (`upgradeScale`) and the Shard Core on a selected weapon (`shardCore`), a bag-full roll refusal offers "Salvage now" (nudge, then salvageNow with its token), and the reveal card shows `levelText` for a merged dupe. All flags stay off. Builds on #386/#387/#388/#389. (open)
- Inventory polish (Ghost, #390): a build stamp with the real git sha (`scripts/stamp.sh` writes the gitignored `Shared/BuildStamp.luau`; `scripts/install-hooks.sh` refreshes it after commit/merge/checkout), printed as "[Shardfall] build <sha> server/client". New shared gear panel (`GearDetail`) in the small Bag and the full inventory: the item icon instead of the avatar, title in rarity colour with +level and stars, stat deltas, EQUIP and UPGRADE side by side (dark ink on amber), a padlock, and a collapsible Shard Core card (`CoreCard`: level bar, perk ladder, Feed picker grouped by item with counts and a confirm) that replaces the mounted ShardCore panel. Bag cards get padlock glyphs, rarity-coloured names and a +level/stars line; tips hide on click, scroll, tab change and close and never pin; the grid leaves room for the pinned footer. The Auto-salvage pill is first in the full inventory header and amber while on; the Bag warns when it is on. Clear-card loot names wrap and carry a quantity badge. Echo server APIs and saves unchanged. (open)
- Gear UI playtest pass (Ghost, #390): salvage moves to the full inventory (`GearBar`: Select mode, "Select all at or below <rarity>", a "Salvage N for +X Essence" bar, Confirm on every salvage, padlocks on cards, protected gear dimmed). The Auto-salvage toggle reads the server profile, sends explicit on/off with its own cap (default Off, "Auto-salvage: Commons and below"), and no longer shares the bulk picker. The small Bag is a preview with one "Open full bag" and a pinned Capacity/Equip Best footer. The inventory title no longer hides under the rail. An x10 roll toasts how many drops were auto-salvaged. Echo server APIs unchanged. (open)
- Gear Progression Stage C: Shard Core (flag `shardCore`, off). One core per weapon, fed with `profile.gearEssence`. Levels and modest perks live in config. Perks add onto finished Equip totals. (open)
- Phase 2 Equip server (flag `equip`, off) and Gear Progression Stage A. Gold upgrades scale stats when `upgradeScale` is on (off). Exact duplicates feed stars when `gearLevels` is on (off). Essence overflow stays on `gearEssence`. No second level field. (open)
- Stage B: favorited gear stays out of salvage, and Salvage selected
  waits for the same confirm token as salvage-all. [#388] (open)
- Stage B: salvage weapons and armor into `profile.gearEssence` (1/3/10/40/200).
  Lock uses `item.locked`. Auto-salvage is off and only converts a new drop.
  `LaunchGate.gearSalvage` is off. `BagTools.mount` is the client hook. [#388] (open)
- x10 summary fixes (Ghost, playtest clip 4): every tile shows exactly one outcome (NEW only if the item was not owned before the batch; ★ up a -> b chained across repeats; ★ fed for a dupe that adds star progress; +N Essence at ★5; Copy; Salvaged) and the headline counts the same outcomes. Skip sits at the bottom right of the reveal card, off the Shards pill. The Roll page drops the Junk/Below row, the second Streak/Rolls lines and the plain "Odds" rows (`LaunchGate.rollMenuExtras`, off). Client only. (open)
- x10 roll reveal (Ghost): each x10 card cracks in at most 0.3 s (`RollSummary.fast` scales the CrackReveal plan) with a Skip button on screen for the whole batch; Skip lands the rest at once. The batch ends on a 10-tile summary grid (`RollSummaryHud`) with NEW / ★ up / auto-salvaged badges, a headline, and "Roll again" / "Close"; it replaces the "Cracked" text list. The milestone banner is now a small toast at the top of the Roll page. Server, odds and prices unchanged. (open)
- Phase 0.9: this changelog. [#372] (merged, 2b6f81f)
- Phase 0.3: Config folder. One index (`Shared/Config/Index`) for Items,
  Rarities, Elements, SetBonuses, Dungeons, Enemies, Rewards, Economy and
  Strings; V1 rarities, economy, elements and strings added as data only.
  [#373] (merged, ac438b0)
- Phase 0.4: Config validation test (`tests/ConfigValidation.spec.luau`).
  Fails on missing or duplicate ids, bad rarity odds or pity, bad drop
  chances or pool weights, negative or NaN stats, missing strings, and
  broken cross-references. [#374] (merged, d37b2f1)

### Changed
- Phase 1.1-1.3, 1.7: rolls core. The live roll now uses the 5-tier Rev 2
  ladder from `Config/Rarities` (1/2, 1/4, 1/15, 1/100, 1/1000, checked
  rarest first: Common 69%, Uncommon 23%, Rare 6.6%, Epic 1.00%, Legendary
  0.10%). One free Legendary pity at 150 (saved in `sinceLegendary`, soft
  pity +2%/roll from roll 101) with its meter; Epic pity removed (old
  `sinceEpic` is kept in saves and ignored). Odds list and reveal show real
  %. Mythic/Secret parked behind `LaunchGate.SHOW.extraTiers` (owned items
  still load). New `tests/RollOdds.spec.luau` (100k seeded rolls + pity
  150). Dev Tools: Rolls / Pity rows (+100 Shards, Set pity 149/120, Reset
  pity). Branch `phase1/rolls-core`. (open)
- Phase 1 follow-up: the roll reveal now freezes movement for the whole roll
  (press and server wait, every x10 card, auto chains) and always frees it
  after (finish, skip, close, error, 12s failsafe); new
  `tests/RevealLock.spec.luau`. The every-10th-roll x2 luck milestone and its
  "x2 Luck in N" meter are parked behind `LaunchGate.SHOW.luckMilestone`
  (off; `shardRolls` still counts). Branch `phase1/rolls-core`. (open)
- Phase 1 follow-up 2 (Oct 22 retest): the reveal lock now also zeroes the local
  Humanoid's WalkSpeed/jump for the whole roll (x1, x10, auto) and restores the exact
  old values on finish, skip, close, leaving the tab, error and the 12s failsafe, so
  movement stops even when PlayerModule Disable() or the key sink is bypassed (e.g. a
  server MoveTo). The crack no longer shows a blank "Shard" window/card: the crystal
  stays visible and the reveal card always has an icon, title, rarity line and a
  detail line ("Card 3 of 10" while cracking, first two stats once landed).
- Phase 0: dev tools locked to Kevin's Roblox user id (10427235156,
  Damookie21) in `DevAccess.OWNER_IDS`. (open)
- Docs: replaced the roadmap with the locked V1 roadmap (Phases 0-7, Phase S,
  Parking Lot) and the salvage map. [#366] (merged, 6248bb9)
- Phase 0.1: off-plan systems are parked behind LaunchGate flags (classes,
  travel, grove, codex, wild capture, stars, gold shop, events, traits, doors,
  Mireoak), all off. Nothing deleted; no save or monetization changes. [#367]
  (merged, ce91df5)
- Phase 0.1: chest drops from play are off while chests are parked (room,
  clear, boss, daily, enemy, login, streak, Rootvault floor chest, first clear
  of the day, onboarding kit, level 5 milestone, welcome back). Shard Keys still
  pay. Owned chests, opening and the key shop are unchanged. [#367] (merged,
  ce91df5)
- Hub: players can walk with the Hero, Bag, Pets, Roll, Shop and Settings
  panels open; only the roll reveal animation and the class picker lock
  movement. [#370] (merged, 4e4741c)
- Phase 0: the loading tips screen at startup is switched off; a proper
  branded loading screen is parked for Phase S. [#371] (merged, 6603486)
- Phase 0.7: Remotes audit (`docs/qa/remotes_audit.md`, 73 remotes). Live
  remotes now refuse NaN/inf numbers, oversized pet ids and colors, and bad
  gear uids; `Dungeon("enter", "heartwood")` is closed while raids is parked.
  [#375] (merged, f83d5a1)
- Phase 0: Kevin's Oct 22 calls. V1 Config has no Epic pity (Legendary pity
  150, soft from 100, stays); the live 7-tier roll keeps its Epic meter until
  Phase 1.3. The Grovewarden armor keeps its items but drops the set tag (no
  set bonus behind it; sets return in Phase 2). PetCare free XP is parked
  behind `LaunchGate.petCare` for a future pets update. Debug, DevGrant and
  the boss skip work only for the game owner (`Shared/DevAccess`), so Team
  Test guests can no longer use them. [#377] (open)
- Dev tools left Settings for their own owner-only Dev Tools panel (the
  "Dev" button under the Gold / Mastery / Shards pills), with collapsible
  Currency, Progress, Run / Dungeon and Testing sections. Every press toasts
  what changed ("+1000 Gold (now 1547).") and prints a `[Dev]` line in
  Output; buttons for switched-off systems (chests, raids, paid Prisms,
  Shard Pass Gems, event tokens) are hidden and the server refuses them with
  a clear "is off" line. [#377] (open)

### Fixed
- One inventory, flags-on: the Bag rail toggles the full Inventory (the next press closes it and does not reopen it), and skill keys stay blocked while that inventory is on screen. Small-Bag specs pin `oneInventory` off. Parked-remote checks allow GearSalvage while `gearSalvage` is on. Both flags stay off in `LaunchGate`. (open)
- Bag details: the worn item reads "Equipped", other items say "Compared with
  <worn item> (equipped)", stats mark = / + / - on shown values, the title
  shows the forge level, and UPGRADE toasts its result ("Need 1,280 gold")
  and repaints. [fix/bag-compare] (open)
- Gnarl's weak spot sits at chest height, and every boss hit says Guarded or
  Weak!. [#359] (merged, e0bc15b)
- Loot toasts read "Loot: Spore Cap x2" with no stray lead character. [#360]
  (merged, 6aa4216)
- Gnarl and every other enemy no longer spawn clipped into walls or slopes.
  [#364] (merged, 0fdfa00)
- Clear card: loot stacks into an icon grid that never hides behind Continue,
  with a single voucher line. [#365] (merged, deec161)
- Clicking HUD buttons no longer leaves an orange selection that locks WASD
  movement. [#370] (merged, 4e4741c)
- Skills never fail silently: a skill press either casts or shows why not
  (for example "Close the menu to use skills."), number keys reach the action
  bar, and each skill tooltip sits over its own slot. [#376] (merged, 075088d)

[Unreleased]: https://github.com/Itsm00k21/Shardfall/compare/ce91df5...HEAD
[#359]: https://github.com/Itsm00k21/Shardfall/pull/359
[#360]: https://github.com/Itsm00k21/Shardfall/pull/360
[#364]: https://github.com/Itsm00k21/Shardfall/pull/364
[#365]: https://github.com/Itsm00k21/Shardfall/pull/365
[#366]: https://github.com/Itsm00k21/Shardfall/pull/366
[#367]: https://github.com/Itsm00k21/Shardfall/pull/367
[#370]: https://github.com/Itsm00k21/Shardfall/pull/370
[#371]: https://github.com/Itsm00k21/Shardfall/pull/371
[#372]: https://github.com/Itsm00k21/Shardfall/pull/372
[#373]: https://github.com/Itsm00k21/Shardfall/pull/373
[#374]: https://github.com/Itsm00k21/Shardfall/pull/374
[#375]: https://github.com/Itsm00k21/Shardfall/pull/375
[#376]: https://github.com/Itsm00k21/Shardfall/pull/376
[#377]: https://github.com/Itsm00k21/Shardfall/pull/377
