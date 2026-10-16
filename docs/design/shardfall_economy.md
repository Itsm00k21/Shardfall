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

These notes override the post-beta line that Gems are bound and that trading starts only at level 15. New-tier players may make small item trades. Gems move only from Standard up.

### Shipped Market Board rules
- List, browse, buy, and cancel. Goods stay in the seller's bag and are reserved until the sale, so a crash does not delete them.
- Listing fee is 5% of the gold price, or 5% of `price * 100` when the price is in Gems. Rounded down, minimum 1 gold. Paid when the listing is posted, sunk immediately, not returned on cancel or expiry.
- The buyer pays the asking price. The seller receives the full price. The listing fee is the gold sink.
- Listings last 48 hours. Caps: New 4, Standard 8, Trusted and Patron 20.
- Gem prices require both sides to be allowed to trade Gems. Robux-bought items stay bound (`Trading.ROBUX_ITEM_TRADING_ENABLED = false`).

### Cross-server board
`MarketCross.MARKET_XSERVER_ENABLED` turns on escrowed listings that any server can browse. The durable copy is a DataStore. A MemoryStore sorted map per item category, ordered by price and expired with the 48 hour listing, is the index. Listing still sinks the 5% gold fee and does not tax the sale; the seller's mailbox receives the full price. Goods leave the seller's profile when the listing is created. A buy claims the row with UpdateAsync, gives the goods to the buyer, and writes the seller's payout into the mailbox. Cancel and expiry return the goods through that mailbox. The seller is paid when they are in this server, or when MessagingService pings the server they are in. If the switch is off, or MemoryStore and DataStores do not answer, the server keeps the in-memory board and goods stay reserved in the bag.

## Trade Audit System (protect players without blocking whales)
**Log everything**: every trade and market sale stores both players, items, Gem/gold amounts, estimated value, timestamp, server, account age, and level. Logs kept 180 days; review dashboard with search by player/item.

### Shipped trade rules
- Both players confirm, then both commit. Any offer change clears both confirms and starts a 3 second lock.
- At commit the server re-reads both profiles. Items, materials, chests, gold, and Gems move in one pass or both profiles are restored. A second commit returns the same audit id and does not move anything again.
- Direct trades sink 10% of gold offered (`floor(gold * 0.10)`). Gems move 1 for 1. The receiver of a lopsided window (95% or more of the value) must pass `acceptWarning`.
- Tradeable: materials, shard gear (Weapon, Armor, Accessory, Pet, Shard), unopened chests, and cosmetics. Gems from Standard up.
- Bound: starter gear (`starter` or template id `starter_`), Robux items while the kill switch is off, locked items, equipped items, exploit items, and Mythic shards for 7 days after `obtainedAt` (missing timestamp stays bound).
- Trust tiers, first match wins. An account under 14 days stays New even at a high level, so a fresh mule cannot spend. A Patron, or an opt-in verified trader with 60 clean days, is uncapped. Trusted is level 40+, or 60 clean days, or any Robux receipt, once the account is 14 days old. Standard is level 15+ and 14 days. Everyone else is New.
- Daily value caps, estimated in gold (1 Gem = 100 gold for the estimate only): New 2,000 per trade and per day, and nothing above Rare. Standard starts at 50,000 and adds 5,000 per level above 15, capped at 150,000. Trusted 2,000,000. Patron uncapped.
- Hard blocks: New-tier limits, `tradeLocked` / `tradeFlagged`, exploit items, Robux items. Flags (lopsided 10x between unconnected accounts, a New account receiving 1,500+ estimated value, five New partners in a day, the same template three times in an hour, a 5x spike versus history, a handoff plus a large transfer) are stored on the audit row and do not stop the trade.
- Rollback restores items and the gold that was sunk as tax, once. The market listing fee stays sunk. Search is by player or item. A player can report their own trade.

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
