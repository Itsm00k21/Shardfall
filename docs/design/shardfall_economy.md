# Shardfall Economy v1 (draft, Oct 16 2026)

## Principles
1. Every currency has a clear job, a source (faucet) and a spend (sink).
2. Few currencies: players should explain each in one sentence.
3. Free players can earn everything that affects power; Robux buys time, convenience, status, cosmetics.
4. Sinks scale with progress so gold never becomes meaningless.
5. Server-authoritative everything; log every transaction.

## Currencies (6 total)
| Currency | Job (one sentence) | Main sources | Main sinks |
|---|---|---|---|
| **Gold** | Everyday money | Enemy drops, dungeon clears, quests, selling/salvaging | Forge upgrades, crafting fees, NPC shop, chest merging fees, fast travel is FREE |
| **Shard Keys** | Buy chests | Waves/rooms, daily & weekly quests, events, milestones | Uncommon/Rare/Epic chests (40/150/600) |
| **Shard Dust** | Duplicate protection | Duplicates, salvaging shards | Buy a chosen shard at the Forge, reroll a socket bonus |
| **Materials** (per realm: common/rare/boss mats) | Crafting | Enemies, nodes, bosses, salvage | Crafting, upgrades past +5, Relic Sets |
| **Gems** (premium) | Premium currency | Robux; small free trickle (daily streak, milestones, events ~30-50/week) | Cosmetics, boosts, extra inventory/loadout slots, Quick Roll (time) |
| **Event Tokens** (seasonal) | Event track | Event activities | Event shop; expire/convert to gold at the end |
Removed/merged: no separate "money" vs gold; no paid-only power currency.

## Gold flow per hour (beta targets, Lv ~10)
- Earn: ~8-12k gold/h (dungeon ~60%, quests ~25%, salvage/sell ~15%).
- Spend: upgrades/crafting should eat ~70-85% of income, leaving savings for bigger goals.
- Upgrade cost curve: +1 = 500, roughly x1.6 each level; +8 to +10 also need boss mats (time-gated sink).

## Key sinks (inflation control)
- Forge upgrades (scaling cost), crafting fees, chest merging fees.
- Socket reroll (gold + dust, rising per item).
- Cosmetic dyes with gold (endless sink that players enjoy).
- Housing/guild hall decor later (big late-game sink).
- Trading tax 10% (when trading arrives) and listing fees.
- No free gold faucets that scale infinitely (e.g., AFK farms give capped gold/hour).

## Auto-farm / AFK guardrail
Auto Farm exists, but gives ~40% of active income and caps at 2 h per session; no auto-farm in boss/raid content. Keeps active play worth it and bots unprofitable.

## Trading (post-beta, design hooks)
- Tradeable: materials, most shards, chests (unopened), some cosmetics.
- Untradeable (bound): Gems, Robux items, Mythic shards for 7 days after drop, starter gear.
- Safeguards: double-confirm trade window, value warning on lopsided trades, level 15+ to trade, 10% gold tax, full logs.

## Monetization map (Robux)
| Product | Type | Notes |
|---|---|---|
| Gem packs | currency | best value at larger tiers, first-purchase 2x |
| Patron Pass | monthly/gamepass | aura that boosts everyone nearby, VIP chest, +inventory |
| Timed boosts | consumable | XP / Gold / Luck (luck region-gated), 30 min / 2 h / 24 h |
| Server Blessing | consumable | 30 min server-wide boost + thank-you announcement |
| Quick Roll / Auto Roll+ | gamepass | time savers |
| Inventory & loadout slots | gamepass/gems | convenience |
| Cosmetics | gems | skins, color channels, auras, pet skins, chest skins |
| Season Pass | per event | free + premium track, premium = cosmetics + gems back |
| Starter Pack | one-time | cheap, high value, cosmetic + gems + boosts |
Never sold: Legendary/Mythic chests, raw stat power, exclusive gear. All paid random items show odds and are disabled in restricted regions, with a server kill switch.

## Anti-exploit
- All currency changes server-side with reasons logged (source, amount, balance).
- Daily caps on unusual faucets; anomaly flags (earning 10x the norm).
- Receipt handling via ProcessReceipt with idempotent purchase IDs (no double grants, no lost purchases).
- DataStore session locking to prevent dupes on rejoin.

## Tuning dashboard (once live)
Track average gold balance by level, top 1% balance, gold earned vs spent per day, Gem free vs paid share, conversion rate. If balances keep climbing, add sinks; if players stall, increase faucets.

## v1.1 (Kevin's notes): Warframe/FFXIV-style player economy
- **Tradeable Gems** (like Warframe Platinum): Lv 15+; free players earn Gems by selling farmed items. Everything paid is also farmable.
- **Haven Market Board** (like FFXIV): list/browse/buy; 5% listing/sale fee as a gold sink. Crafters/gatherers can be a real career.
- Mythic shards untradeable for 7 days after drop. Starter gear/Robux-bought items bound.

## Trade Audit System (protect players without blocking whales)
**Log everything**: every trade and market sale stores both players, items, Gem/gold amounts, estimated value, timestamp, server, account age, and level. Logs kept 180 days; review dashboard with search by player/item.

**Trust tiers instead of hard limits**
| Tier | Who | Daily trade value cap |
|---|---|---|
| New | under Lv 15 or account under 14 days | no Gem trades, small item trades |
| Standard | Lv 15+ | moderate cap, grows with Mastery |
| Trusted | Lv 40+ or 60+ days clean history or verified spender (Robux purchase history) | very high cap |
| Patron/Verified Trader | Patrons, or opt-in with clean history | effectively uncapped |
Whales who've bought Gems legitimately and have clean history move up fast, so big trades between established players are never blocked.

**Flag, don't block (for trusted players)**
Automatic flags go to a review queue instead of stopping trades:
- Lopsided value (one side gives 10x+ more) between unconnected accounts
- New account receiving huge value (classic mule/RMT pattern)
- One account funneling to many new accounts (or many feeding one)
- Rapid repeat trades of the same items (laundering loops)
- Sudden spikes vs a player's normal history
- Trades right after an account changes hands (login from new device/region + mass transfer)
Hard blocks only for: New-tier limits, known flagged accounts, and confirmed exploit items.

**Player-side scam protection**
- Two-step confirm with a 3-second lock after any change in the trade window
- Value warning on lopsided trades ("You're giving ~95% of the value. Continue?")
- Clear item tooltips (rarity, sockets, stats) so fakes/look-alikes can't fool anyone
- Trade history in the player's own menu; report button on any trade

**Enforcement**
- Rollback tool: reverse a trade or a chain of trades from logs (dupes, hacked accounts)
- Escalation: warning, trade lock, ban; RMT/scam rings banned together via linked-trade graphs
- Weekly review of the top 50 flags; tune thresholds so whales are rarely flagged
