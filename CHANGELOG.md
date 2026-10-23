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
- Gear Progression Stage C: Shard Core (flag `shardCore`, off). One core per weapon, fed with `profile.gearEssence`. Levels and modest perks live in config. Perks add onto finished Equip totals. (open)
- Phase 2 Equip server (flag `equip`, off) and Gear Progression Stage A. Gold upgrades scale stats when `upgradeScale` is on (off). Exact duplicates feed stars when `gearLevels` is on (off). Essence overflow stays on `gearEssence`. No second level field. (open)
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
