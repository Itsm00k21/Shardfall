# Rootvault Dungeon Design (v1, Oct 16 2026)

## Goal
Every run feels different, every room asks a small decision, and clearing feels like a payoff. Readable on Low graphics and on phones.

## Beta scope (build now)
1. **Lighting & space** (already queued): dungeon-specific lighting, torches/crystals, enemy rim highlight; rooms 1.6-2x area, corridors >=16 studs, tall ceilings.
2. **Door choices**: after each cleared room, 2 doors with icons: Treasure, Elite Fight, Healing Spring, Shrine (random run buff), Shop (Shard Keys). Final door is always the boss.
3. **Enemy mix** (Verdant themed): Charger (telegraphed dash, dodge it), Caster (ranged, rush it), Shielder (front block, flank it), Mender (heals allies, priority target), plus basic Grunts. Elites = bigger + 1 affix.
4. **Grandmother Gnarl boss phases**: P1 root slams with ground telegraphs; P2 (60%) summons sapling adds + vine sweep; P3 (25%) enrage, faster slams, arena shrinks with thorns. Loot burst + Rare Chest on kill.
5. **Difficulty tiers**: Normal / Hard (Uncommon+ chest floor, +50% HP/dmg) / Nightmare (Rare+ floor, extra affixes, unlocks at Lv 15).

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
Server-authoritative rooms/spawns/loot; data-driven room, enemy, and door configs; enemy count and particles capped by graphics tier.
