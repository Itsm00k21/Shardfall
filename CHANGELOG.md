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
- Phase 0.9: this changelog. (open)

### Changed
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
- Hub: players can walk with the Hero, Bag, Pets, Shop and Settings panels
  open; only the Roll screen and the class picker lock movement. [#370] (open)
- Phase 0: the loading tips screen at startup is switched off; a proper
  branded loading screen is parked for Phase S. [#371] (open)

### Fixed
- Gnarl's weak spot sits at chest height, and every boss hit says Guarded or
  Weak!. [#359] (open)
- Loot toasts read "Loot: Spore Cap x2" with no stray lead character. [#360]
  (open)
- Gnarl and every other enemy no longer spawn clipped into walls or slopes.
  [#364] (open)
- Clear card: loot stacks into an icon grid that never hides behind Continue,
  with a single voucher line. [#365] (open)
- Clicking HUD buttons no longer leaves an orange selection that locks WASD
  movement. [#370] (open)

[Unreleased]: https://github.com/Itsm00k21/Shardfall/compare/ce91df5...HEAD
[#359]: https://github.com/Itsm00k21/Shardfall/pull/359
[#360]: https://github.com/Itsm00k21/Shardfall/pull/360
[#364]: https://github.com/Itsm00k21/Shardfall/pull/364
[#365]: https://github.com/Itsm00k21/Shardfall/pull/365
[#366]: https://github.com/Itsm00k21/Shardfall/pull/366
[#367]: https://github.com/Itsm00k21/Shardfall/pull/367
[#370]: https://github.com/Itsm00k21/Shardfall/pull/370
[#371]: https://github.com/Itsm00k21/Shardfall/pull/371
