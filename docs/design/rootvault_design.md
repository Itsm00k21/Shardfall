# Rootvault Dungeon Design (v1, Oct 16 2026)

## Goal
Every run feels different, every room asks a small decision, and clearing feels like a payoff. Readable on Low graphics and on phones.

## Beta scope (build now)
1. **Lighting & space** (already queued): dungeon-specific lighting, torches/crystals, enemy rim highlight; rooms 1.6-2x area, corridors >=16 studs, tall ceilings.
2. **Door choices**: after each cleared room, 2 doors with icons: Treasure, Elite Fight, Healing Spring, Shrine (Might, Ward, or Haste), Shop (Shard Keys). Final door is always the boss. Haste is the timed speed buff in "Beta behavior" below. Might's +15% damage and Ward's stored id are unchanged.
3. **Enemy mix** (Verdant themed): Charger (telegraphed dash, dodge it), Caster (ranged, rush it), Shielder (root brute, front block, flank it), Mender (moss crawler heals one ally and is the priority target), plus basic Grunts. Elites = bigger + 1 affix. Shielder and mender numbers are in "Beta behavior" below. Charger dashes and caster kiting are still the existing telegraph and range.
4. **Grandmother Gnarl boss phases**: P1 root slams with ground telegraphs; P2 (60%) summons sapling adds + vine sweep; P3 (25%) enrage, faster slams, arena shrinks with thorns. Loot burst + Rare Chest on kill.
5. **Difficulty tiers**: Normal / Hard (Uncommon+ chest floor, +50% HP/dmg) / Nightmare (Rare+ floor, extra affixes, unlocks at Lv 15).

## Beta behavior (T-017)

Pure rules live in `src/ReplicatedStorage/Shared/EnemyAbilities.luau`. `DungeonService` still stores `run.shrine` and does not call the module yet, so a live run is unchanged until those hooks land. Nothing here is bought with Robux.

### Haste shrine
`applyHaste("haste", now)` starts a 30 second buff. Attack speed is ×1.2 and walk speed is ×1.15, taken from the gear speed and the WalkSpeed captured when the shrine is picked. At `untilAt` the buff expires and both speeds return to those bases. A later Haste shrine refreshes the 30 seconds. The multiplier does not stack, and a result is clamped (attack speed 0.2–4, walk speed 8–24). `"might"` and `"ward"` do not start this buff. The Rootvault door line still says a shrine lasts the rest of the run; that string is unchanged here. Might remains the existing whole-run +15% damage while `run.shrine == "might"`.

### Mender
A living moss crawler with a position heals one other living ally within 18 studs every 4 seconds. The ally is the lowest HP ratio in range, then the lowest id. The pulse is 12% of that ally's max HP, at least 1, at most 24, and never past max HP. The cooldown is written only when a pulse is returned. A dead mender, a dead ally, a full ally, the mender itself, Grandmother Gnarl, and an ally past 18 studs produce no pulse. `priority` is the living mender to focus, preferring one that is ready to heal.

### Shielder
A living root brute blocks when the attacker is in the front 120° of its look (dot ≥ 0.5). That hit deals 0. A side or rear hit deals full damage. A dead brute, any other kind, a zero look, or an attacker standing on the same point does not block. `turnShield` yaws the look toward the player by at most 1.6 rad/s, which is what makes a flank possible. `moveEnemy` still snap-faces every enemy. The T-017 hooks replace that snap for the root brute only.

## Post-beta
- Shuffled room layouts from a hand-built room pool
- Run modifiers (explode-on-death, double chests/tough elites, low gravity...)
- Hades-style stacking run boons (chain lightning, +speed, lifesteal)
- Secrets: breakable walls, hidden chest rooms, rare Golden Room
- Timed leaderboard per difficulty
- Group play: shared revives, combo attacks, party chests

## Run length target
Normal run ~6-8 min: 5-7 rooms + boss.

## Tech notes
Server-authoritative rooms/spawns/loot; data-driven room, enemy, and door configs; enemy count and particles capped by graphics tier. Haste, mender pulses, and shielder blocks are server-side calls into `EnemyAbilities` (see the T-017 hooks). The module does not grant loot or change chest floors.
