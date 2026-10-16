# Shardfall First 5 Minutes v1 (draft, Oct 16 2026)

## Goal
In 5 minutes a new player has: fought, felt powerful, rolled a shard, opened a chest, cleared a mini dungeon, and seen something they want. No walls of text. Every step skippable for returning players.

## Rules
- Show, don't tell: one short line of text max per prompt, with an arrow/glow.
- Reward every step (the first 5 minutes rain rewards).
- First roll and first chest are rigged a little to feel good (guaranteed Rare+), clearly fair after that.
- Works on touch: big prompts, no keyboard hints on mobile.

## Timeline
**0:00-0:20 - Cold open (the hook)**
Load straight into the sky above Haven: the Lumen Heart cracks, shards rain across the five realms (short 10s cutscene, skippable). Narrator line: "The Heart shattered. Its shards chose you."

**0:20-0:50 - Pick your class**
5 class pedestals in a ring. Walk up to one = 3-second preview: the class does its signature move on a dummy. Tap "Choose" (note: "You can switch anytime at the Forge").

**0:50-1:40 - First fight (feel powerful)**
Land in a small Verdant clearing. Prompts appear only when needed: attack -> 3 sapling grunts die in hits with full juice. Then skill 1 on a group. Then a Charger shows a red telegraph -> "Dodge!" prompt; a perfect dodge gets slow-mo + praise. Level up mid-fight (big flash, +skill 2).

**1:40-2:20 - First shard roll**
A glowing shard on the ground -> carry it to a waystone shrine -> first reel roll (guaranteed Rare+). Socket it into your weapon right away; your attacks change color/effect. The aha: "shards change how you fight."

**2:20-3:40 - Mini dungeon (Rootvault Antechamber)**
2 short rooms + a door choice (Treasure vs. Elite, both safe) + a mini-boss (Gnarl's Sprout, 2 telegraphed attacks). Kill = loot burst.

**3:40-4:20 - First chest**
A Rare Chest drops (guaranteed). Full reveal animation. Gives a gear piece + a pet egg that hatches immediately: the pet follows you from now on.

**4:20-5:00 - Arrive in Haven (the world opens)**
Teleport to the Haven plaza. A quick camera flyover shows the Forge, the Roll Shrine, the Rootvault gate, and the Guild Plaza (each lights up as the guide names it). Unlock the daily login chest. First goal on screen: "Clear Rootvault (Normal)".
Tease: a passing NPC with a glowing Legendary aura/shard = something to want.

## After minute 5: guided goals (no forced tutorial)
A short goal tracker (top left), 3 at a time: Craft your first item at the Forge / Clear Rootvault / Roll 10 shards / Reach Lv 5 (unlock talent) / Join or browse a guild. Each gives Shard Keys.

## Retention hooks set up by minute 5
- Daily login chest (with a streak preview)
- A pet that already helps
- A visible next goal + a visible "want" (Legendary aura)
- Pity counter started

## Skip & returning players
"Skip intro" on first join -> drop into Haven with the same starter rewards. Alts/returning players never see it again.

## Metrics to watch (once published)
% who finish the tutorial, % who reach Haven, D1 retention, time to first Rootvault clear. Biggest drop-off step = what to fix first.

## Beta scope
Everything above; the cold-open cutscene can start as a simple camera pan + text and get upgraded later.

## v1.1 additions: Teach through play (Kevin's notes)
Principle: the level teaches, not text. Each mechanic gets a safe, fun "moment" where the player discovers it, then the game trusts them. Max 1 short hint, and only if they're stuck for ~8s.

| Mechanic | How the world teaches it (no lecture) | Hint only if stuck |
|---|---|---|
| Attack/combos | Saplings die in 3 hits; the 3rd hit visibly launches them | "Keep swinging" |
| Dodge | A Charger's red telegraph aims at a narrow bridge; dodging through it feels obvious, getting hit only costs a little | "Dodge!" icon pulses |
| Perfect dodge | Slow-mo the first time it happens by accident + "PERFECT" pop; players chase it | none |
| Skills | A tight cluster of grunts begging for an AoE; the skill button glows | button glow |
| Telegraph colors | Mini-boss uses red (dodge) then blue (interrupt), each shown alone first in a safe moment | color icon over the boss |
| Shards/sockets | Socketing a fire shard sets your weapon on fire; a log barrier blocks the path and burns away | glow on the socket |
| Door choices | Two doors with clear icons + a peek of what's inside; both safe | none |
| Pets | The pet grabs a coin you missed, then helps finish a grunt | none |
| Crafting | In Haven, the Forge smith asks you to upgrade the gear from your chest using the materials you already have | arrow to the Forge |
| Rarity colors | Loot beams in rarity colors from the first drop | none |

Extras:
- **Optional Training Grove** in Haven: dummies, a dodge course, and a "boss mechanics" room with each telegraph color; clearing it gives a small cosmetic (for players who want to learn more).
- **Loading-screen tips** and a short **"Codex"** in the menu that unlocks entries as you discover mechanics (looks up info, doesn't nag).
- Never block progress with a tutorial popup; never force reading.

## v1.1 additions: Starter gear that feels like progress
- First roll: guaranteed **Rare** shard matched to your class element (or the player's pick of 2).
- First chest: a **Rare weapon with 1 socket** (sockets normally start at Uncommon+), class-appropriate, plus a pet egg (Uncommon+).
- Mini-boss drop: an **Uncommon armor piece**, so 2 slots feel upgraded already.
- First Forge visit: craft a free Uncommon ring with the materials collected in the tutorial; it teaches crafting and fills a 3rd slot.
- Result: by minute 6 the player has ~4 upgraded slots + a socketed Rare shard, enough to clear Rootvault Normal comfortably, but with clear Epic/Legendary upgrades still to chase.
- Balance guardrail: starter gear tops out around the realm 1 midpoint so it never trivializes Hard mode.
