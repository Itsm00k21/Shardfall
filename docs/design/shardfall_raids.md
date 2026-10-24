# Shardfall Raids v1 (draft, Oct 16 2026)

## Part A: Research

Sources I actually read are linked. Anything marked [GK] is general genre knowledge that I didn't check against a source this pass.

### World of Warcraft
- **4 difficulties, all with the same bosses:** LFR, Normal, Heroic and Mythic. LFR, Normal and Heroic have loot-based weekly lockouts, so you can loot each one once per difficulty per week. Mythic locks the whole group to one instance. The Heroic final boss needs all earlier Heroic bosses killed that week. (https://us.support.blizzard.com/en/article/269958, https://warcraft.wiki.gg/wiki/Lockout)
- **Great Vault:** killing 2, 4 or 6 raid bosses on any difficulty unlocks reward slots. The quality matches the highest difficulty you cleared for that slot. Next week you pick one item. This is bad-luck protection plus a "do a little each week" reward. (https://www.wowhead.com/guide/systems/the-great-vault)
- **Mythic+ [GK]:** timed dungeons with no lockout. Key levels scale HP and damage and add rotating affixes, so it never ends.
- **Race to World First, Raider.io, WarcraftLogs and consumables [GK]:** these are huge parts of the culture. Guilds prep with food, flasks, strategy videos and logs.
- **Downsides:**
  - Players say logs and Raider.io drive PUG gatekeeping. It creates a cycle where fewer invites mean less experience, which means even fewer invites. (https://www.reddit.com/r/wow/comments/9ifcf2/)
  - Raid leads point out that parses ignore who handled the mechanics. One noted lower-geared players avoid optional mechanics to protect their DPS numbers. (https://us.forums.blizzard.com/en/wow/t/fixing-warcraftlogs-for-raid-and-preventing-the-toxicity-it-leads-to/2085777)
  - "Raid logging" (logging in only for raid night) empties guild chat. Geared players stop helping the ones who joined later. (https://www.reddit.com/r/classicwow/comments/pbhuvk/)

### Final Fantasy XIV
- **Ultimate:** needs a full premade party of 8, with no matchmaking and a strict item-level sync. (https://ffxiv.consolegameswiki.com/wiki/Raids)
- **The Echo:** a buff that makes older content easier. It's applied on entry once a Savage tier is no longer new, or it grows after wipes. Patch 7.56 also removed the weekly loot lockout on the current Heavyweight Savage tier and added a 12% Echo. (https://na.finalfantasyxiv.com/lodestone/topics/detail/a8a526ad64db45c8ca8d1c7fdcce8a5eedaa18bc/)
- **Alliance raids:** each party gets its own chest, and you can win only one item per week from Windurst. (Patch 7.5 notes, https://na.finalfantasyxiv.com/lodestone/topics/detail/07320affa7e0fcd9685afcbe54fbf55405b6d822)
- **Matchmaking for hard content is discouraged.** Most players use Party Finder to agree on a strategy first. (https://ffxiv.consolegameswiki.com/wiki/Duty_Finder)
- **Mentor Roulette:**
  - Solo queue only, and it requires a mentor qualification and an item-level minimum.
  - It fills the queues that have waited longest and gives exclusive achievements.
  - Duty Roulettes as a whole give daily bonuses for random queueing.
  - (https://ffxiv.consolegameswiki.com/wiki/Duty_Roulette)
- **Tomestones [GK]:** a weekly-capped token currency that buys gear, which works as deterministic catch-up.

### Destiny 2
- **Format:** 6-player raids with no regular matchmaking. Raid Lairs are shorter raid-like activities. (https://d2.destinygamewiki.com/wiki/Raid)
- **Guided Games:**
  - Solo or duo Seekers join a clan's Guide fireteam.
  - At least half the fireteam must be from that clan.
  - Everyone accepts the Guardian Oath (helpful, attentive, willing to teach).
  - Clans earn an Oathkeeper Score for finishing, and kicking players is disabled.
  - (https://help.bungie.net/hc/en-us/articles/360049198951-Guided-Games)
- **Contest Mode:** for the first 24–48 hours, Power is capped and some gear is disabled so the race is fair. Clearing during contest gives an exclusive emblem. (https://overgear.com/guides/destiny2/the-desert-perpetual-guide/, https://stevivor.com/news/destiny-2-beyond-light-deep-stone-crypt-contest-mode-detailed-bungie/)
- **Craftable weapons:** red-border Deepsight drops unlock weapon patterns you can craft from. (https://help.bungie.net/hc/en-us/articles/4415502983188-Weapon-Crafting-Guide)
- **Other features [GK]:** puzzle and role-callout mechanics (relics, symbols), Master difficulty, and LFG through Discord, 100.io and the in-game Fireteam Finder.

### Other games
- **Lost Ark:** raids are split into gates. Only the first 3 Legion Raids per character per week pay gold, and later clears give materials only. (https://www.reddit.com/r/lostarkgame/comments/1g27o7c/)
- **Guild Wars 2:** has an LFG "Raids (Training)" category, training guilds and kill-proof culture. A Quickplay mode matches you into a curated raid encounter. (https://wiki.guildwars2.com/wiki/Raid)
- **[GK] from other games:**
  - **Monster Hunter:** short repeatable hunts and SOS flares, where you call for help mid-hunt.
  - **Warframe:** Eidolon and Archon hunts are short, high-skill and run on a weekly timer.
  - **Diablo IV:** Uber bosses need summoning materials and have chase drops.
  - **ESO:** trials have score and leaderboard modes.
  - **Elden Ring Nightreign:** 3-player co-op bosses with short sessions.

### Roblox
- **Blox Fruits:**
  - Raids are instanced across 5 islands with a boss on the 5th, for up to 4 players.
  - You need a microchip (bought with in-game currency or a fruit) to start one, and there's a level gate to join or host.
  - Rewards scale with time remaining, dying gives nothing, and Fragments buy fruit awakenings.
  - Sessions are short, and the loop is gated by an entry ticket.
  - (https://www.gamersberg.com/blox-fruits/wiki/mechanics/raids, https://bffr.fr/wiki/en/mecaniques/raids/)
- **[GK] other Roblox games:**
  - Anime defense games run timed raid stages with exclusive units and shops.
  - Dungeon Quest and World // Zero use short 4–6 player dungeons with lobby pads.
  - Deepwoken and Arcane Odyssey bosses are high-risk and social.
  - Common patterns are lobby pads or elevators, a 1–5 minute fill timer, a reserved server per run, runs of 10–20 minutes, and a raid shop.
- **Tech:**
  - MemoryStore queues are built for matchmaking. A read hides the item until a timeout, then the server removes it once processed. (https://create.roblox.com/docs/en-us/cloud-services/memory-stores/queue.md, https://create.roblox.com/docs/en-us/cloud-services/memory-stores.md)
  - The handoff works like this: reserve one server, write the assignment to a MemoryStore hash map, and notify other servers through MessagingService.
  - Each source server then teleports its own players with TeleportAsync inside pcall and handles TeleportInitFailed. (https://crux.supercraft.host/blog/roblox-matchmaking-with-memorystore-and-reserved-servers/)
  - TeleportAsync allows at most 50 players per call, and a reserved server can identify itself through PrivateServerId. (https://birdhouse.tech/docs/roblox-match-handoff/)

### Key lessons
1. Use the same raid at several difficulties, with new mechanics at each tier and not just bigger numbers.
2. Weekly lockouts plus deterministic catch-up (Vault or tokens) keep the chase healthy. Unlimited farming with diminishing rewards (Lost Ark gold cap) also works.
3. Random queue is fine for story and normal difficulty. Hard content needs premades plus a bridge for solo players (Guided Games, Mentor Roulette, GW2 training).
4. Public damage-only numbers breed gatekeeping. Show mechanics and contribution instead.
5. Contest mode and world-first races create server-wide hype.
6. Roblox players expect short sessions, lobby pads, entry tickets, raid shops and exclusive drops.

## Part B: The Shardfall raid system

### Philosophy
- **Every raid is a story.** A full clear takes 20–30 minutes, split into 3–4 "wings". Each wing stands alone (Lost Ark gates), so a mobile session of 8–10 minutes still counts.
- **Party size:**
  - 8-player raids: 1–2 Wardens, 1–2 Tidecallers and 4–5 DPS. Forgeborn can off-tank.
  - Finder fills any missing role with flexible rules (see Matchmaking).
  - 4-player "Lairs": a one-boss version for small groups.
  - Post-launch, 16-player Alliance raids made of 2 parties of 8.
- **Mobile readability:**
  - Every mechanic uses the shared colors: red means dodge, yellow means stack, purple means spread and blue means interrupt.
  - No warning appears for less than 0.8 seconds, or 1.2 seconds on Story.
  - There's a "your job" icon above your head and big text callouts.
- **Mixed skill:** failing a mechanic in Story or Normal hurts the party but doesn't wipe it. Wipe mechanics only start on Hard.

### Difficulty ladder (same bosses)
| Tier | Unlock | What changes | Rewards |
|---|---|---|---|
| Story (Finder) | Lv 15 (beta) | Fewer mechanics. An Echo buff (+5% per wipe, max +25%) stacks after wipes. | Raid Uncommon/Rare gear, story cosmetic |
| Normal | Clear Story | Full mechanic set, soft enrage | Epic, Raid Marks |
| Hard | Clear Normal | Extra mechanic per phase (e.g. soak needs 2 players), hard enrage, wipe mechanics | Epic+ with extra socket chance, Relic Set pieces |
| Shardbreaker (Mythic) | Clear Hard, premade only | Secret 4th phase, new boss attacks, personal assignments (puzzle roles), 1 battle revive per player | Legendary, mount/title, Shardbreaker glow |
| Fracture 1–∞ | Clear Shardbreaker once | Timed, with stacking HP and damage per level plus weekly Fracture affixes (M+ style), no lockout | Fracture score, leaderboard, cosmetic tiers every 5 levels, Shard Dust |

### Loot and the chase
- **Personal loot only,** with a weekly lockout per boss per difficulty (WoW's loot-based model).
- **Unlimited reclears:** after your lockout, a clear still pays Raid Marks, Shard Dust and materials, so helping friends is never wasted.
- **Raid Marks:** a token currency capped at 600 per week that buys raid gear from the Heartwood Vendor. It's deterministic catch-up, like tomestones.
- **Bad-luck protection:** each lockout clear with no gear drop adds +10% to your next drop chance, and it resets when you get something.
- **The Vault (weekly):** killing 2, 4 or 6 raid bosses opens 1, 2 or 3 choices, at the quality of the highest difficulty. You pick 1 at reset.
- **Relic Sets:** a 4-piece raid set per class with a 2- and 4-piece bonus that changes your play (e.g. Frostblade 4pc: shatter spreads Chill).
- **Raid weapons:**
  - "Heartshard" weapons can drop *Resonant* (red border). Collecting 3 unlocks a pattern you can craft at the Forge with Raid Marks and materials.
  - They upgrade from +0 to +10 using the existing Forge system.
- **Exclusive drops:**
  - The Gnarlling pet (Shardbreaker, about 1%), a mount on Shardbreaker final, titles ("Heartbreaker"), dyes and a raid aura.
  - Cosmetics are never sold.
- **Firsts and races:**
  - First clear per difficulty gives a chest and a title.
  - **Contest Weekend:** for the first 48 hours of a new raid, Shardbreaker is item-level capped. The first server-wide clear gets a Haven statue for a season and a global announcement. Everyone who clears during contest gets an exclusive emblem.
- **Leaderboards:** fastest clear per difficulty and size, highest Fracture level per class combo, and guild progression rank.
- **Achievements:** no-death runs, "no one stood in red", and class-specific feats. They reward glory, not power.

### Matchmaking
- **Raid Finder (Story and Normal):**
  - Queue solo or with a party, then pass a role check (Tank, Healer, DPS, or Flex).
  - If no healer turns up within 3 minutes, the group can start with auto-scaling: −15% boss damage and a free Healing Spring totem.
  - Missing Tanks get a Warden NPC golem on Story only.
  - The party size scales from 4 to 8, with HP scaled to the number of players.
- **Newcomer bonus:**
  - First-time players get a "Fresh Shard" icon.
  - Each first-timer adds +10% Marks for the group.
  - Mentors (anyone with 10+ clears who opts in) earn Mentor Tokens and exclusive cosmetics, borrowing the idea from FFXIV Mentor Roulette.
- **Vote-kick protections:**
  - Needs 3/4 of the group and a reason.
  - Unavailable for the first 2 minutes and during combat.
  - Each player gets 1 kick a day, and anyone kicked for being idle loses their queue priority.
  - Players who are kicked unfairly still get their Marks.
- **Guided Raids (Hard and Shardbreaker):**
  - A guild hosts with at least half its members, and solo Seekers join.
  - Everyone takes an Oath of the Grove, and guilds earn a Guide Score and perks.
  - Kicking is disabled.
- **Premade board in the Guild Plaza (Party Finder style):**
  - Listings carry tags like "Learning", "Farm", "Speedrun" or "Achievement", plus a required clear count.
  - No gear-score filter is allowed for Story or Normal.
- **Guild calendar:**
  - Schedule raid nights with RSVPs and role slots.
  - Players get an in-game notice when the raid forms, and attendance is tracked automatically.
- **Cross-server:** everyone queues together through MemoryStore, and the match lands in a reserved server (see Tech).
- **SOS Flare (MH style):** a party that has been wiping can send out an open flare so nearby players can join mid-raid. Those players get a Mentor bonus.

### Guild raid prep
- **Practice Grove:**
  - A free, lootless sandbox for each unlocked boss with practice dummies.
  - You can jump to any phase, slow time to 0.75x and turn individual mechanics on or off.
  - It records damage, deaths and mechanic hits.
- **Strategy Board:** a top-down map of the arena where the raid leader drags markers (stack spots, soak 1, soak 2) that the whole party sees. Presets can be saved per guild.
- **Loadout planner:** saved builds per raid (talents, shards, pet), so you can switch in one tap at the raid entrance.
- **Consumables:**
  - Crafted food (+stat for 30 min), Shard Tonics (elemental resist matching the raid realm) and Revive Seeds.
  - Crafters make them from realm materials, which feeds the Market Board.
  - Buffs are capped at one food and one tonic.
- **Raid roles:** Raid Lead (can place markers, pull timer, ready check) and Assistants.
- **Guild perks from raiding:** guild Raid XP unlocks +Marks, a cheaper Practice Grove and a banner. Points from Guided Raids count double.
- **Recruiting:** guild profiles show their progression (3/4 Hard), raid times and a "Learning-friendly" tag.
- **Post-run recap:** a private personal panel (see Anti-toxicity).

### Encounter design kit
- **Mechanic types that work on Roblox:**
  - Stack (yellow) and spread (purple), and soak circles that need N players.
  - Adds with a priority marker, and interrupts (blue) that fill the stagger bar.
  - Positional mechanics (stand behind a pillar, or the boss's front cone).
  - Puzzle roles: the server tags 2 players with matching symbols and they match plates.
  - Tank swaps on stacking debuffs, DPS checks (break the shield before the timer), arena changes, and phase transitions.
- **Avoid on mobile:** precise jumping, mechanics that need many simultaneous inputs, tiny visual cues, and mechanics you can only catch through voice chat.
- **Every boss** has a stagger bar, 3 phases (4 on Shardbreaker), an enrage timer and a 2-second phase-transition roar.

### The Heartwood (Verdant raid, 8 players, ~25 min)
**Wing 1: The Rootgate (5 min)**
- **Trash flow:** a corrupted grove where you fight Charger and Mender packs. You burn 3 Thorn Seals with fire-shard hits or by killing Menders on them.
- **Boss 1, Thornwarden Twins (Bramble and Briar):**
  - P1: the twins share HP and must stay apart, or they get Enraged Bond.
  - P2: Briar's Thorn Volley (purple spread) while Bramble charges (red line).
  - P3: they merge, and the soak circles need 2 players.
  - *Hard:* tanks must swap at 4 Splinter stacks.

**Wing 2: Sap Hollows (6 min)**
- **Trash:** sap rivers slow you, and a riding mini-event on Leaflings carries you across.
- **Boss 2, Mother Sapwell:**
  - P1: Sap Pools drop under random players (move them to the edge).
  - P2: Sapling adds grow into Treants if not killed in 10 seconds (add-priority check).
  - P3: Amber Prison encases one player, who gets freed by a blue interrupt from their allies.
  - *Shardbreaker:* the Amber Prison target has to solve a 3-symbol match from inside.

**Wing 3: The Canopy (6 min)**
- **Trash:** a vertical climb with Caster turrets, then Shielders on narrow branches.
- **Boss 3, Galecrown, the Owl Matriarch:**
  - P1: Feather Storm cones (red), plus Gust that pushes players toward the edge, so you stand behind a branch.
  - P2: she flies, and Ranged Voidcasters pull her down with Rift anchors. Others get a "Lantern" to throw if no Voidcaster is present.
  - P3: Moonlit Dive (yellow stack, split damage).

**Wing 4: Heart Chamber (8 min)**
- **Final boss, Grandmother Gnarl Awakened (the Heartwood itself):**
  - P1: an updated Rootvault kit with Root Slam and Bramble Spit, plus Heartroots, where 4 roots must be soaked at the same time.
  - P2 (70%): the arena splits into 2 platforms. Each team of 4 must interrupt its own Heartwood Roar (blue).
  - P3 (35%): the corrupted Lumen shard is exposed and a DPS check breaks its shield. Thorn Wall closes in.
  - P4 (Shardbreaker only, 10%): Seasons Turn, rotating arena hazards for spring, summer, autumn and winter.
  - Look: the bark peels away to reveal a glowing amber heart.
  - Drops: Verdant Relic Set, Heartshard weapons, Gnarlling pet, Rootstrider mount (Shardbreaker).

### Sketches for the other realms
- **Sunken Reach, "The Drowned Choir":** rising water forces players onto higher platforms, and a siren boss calls out song notes for players to match. Tidecaller-favoured.
- **Emberforge, "The Crucible":** lava timing and weapon-forging stations where players carry molten ingots to arm the party. The anvil-giant boss has a heat meter.
- **Frostveil, "Glacier Throne":** freezing stacks mean you huddle near braziers, with a mirror-image boss and ice paths that shatter.
- **Void Rift, "The Hollow Crown":** split realities where half the raid fights in the void dimension while the rest hold the real world. Ends with the full Lumen Heart finale.

### Retention
- **Weekly reset** on Tuesday at a fixed time: Vault, lockouts and the Marks cap.
- **Seasonal raid affixes:** each season gives a "Fracture Season" with 2 rotating affixes, like Overgrowth (adds) or Shardstorm (bonus loot orbs to grab during the fight).
- **Cadence:** a new raid each major update, about every 3–4 months, roughly one per realm. A Lair arrives between raids.
- **Catch-up:**
  - When a new raid launches, the old one gets a permanent Echo, double Marks and a gear floor raised one tier.
  - The Marks cap carries over (an unused cap accumulates up to 3 weeks).
  - A "Late Bloomer" quest gives a free Hard-tier item.
- **Reclears stay rewarding:** unlimited Marks, Dust and materials, Resonant weapon patterns, Mentor Tokens, Fracture pushes and cosmetic collections.
- **Server event:** "Heartwood Night", where a weekend 2x Marks event ties into the community goals.

### Anti-toxicity and fairness
- No gear score or clear checks are visible or filterable in Finder for Story or Normal.
- **The post-run panel is private:**
  - It shows your damage, healing and mechanics handled, like "You soaked 6 times".
  - It gives 1–2 tips, such as "Try using Blink on Galecrown's Gust".
  - The public view shows only party kudos and mechanic MVP awards, not a damage ranking.
  - This answers the "parse vs mechanics" complaint.
- **AFK detection:** no input for 60 seconds outside cutscenes brings a warning. At 90 seconds the player is auto-removed and loses their rewards, and a backfill is queued.
- **Leaver penalty:** 3 leaves in a day causes a 15-minute Finder cooldown. Disconnecting gives a 3-minute rejoin window.
- **Loot:** personal loot only. Raid gear is soulbound for 2 hours after it drops, and you can trade it to someone in the same run who was also eligible for that boss (a WoW-style personal loot trade).
- **Market rules:** crafted Heartshard weapons are tradeable after the crafter has 1 clear. Relic Set pieces are raid-drop only and tradeable on the Market Board (per Kevin's decision, docs/design/relic_sets.md, T-031/T-034). Cosmetics from raids are bound so they stay as proof of achievement.
- **Reporting:** a report button feeds the trade and behavior logs from the economy doc.

### Roblox tech notes
- **Places:** Haven (hub) plus a separate Raid place for each raid. Each run gets one reserved server from `ReserveServerAsync`.
- **Queue:**
  - Tickets go into a `MemoryStoreQueue` per raid, difficulty and region, holding the party, roles, class and newcomer flag.
  - A matchmaker server elected by a short MemoryStore lease reads batches and forms groups.
  - It writes the assignment to a `MemoryStoreHashMap` with `UpdateAsync`, then sends a MessagingService ping.
- **Teleport:**
  - Each hub teleports its own players with `TeleportAsync` and `TeleportOptions.ReservedServerAccessCode`, inside pcall with retries, and handles `TeleportInitFailed`.
  - Teleport data carries only the ticket ID. The raid server rebuilds state from DataStore and checks the roster against the hash map.
- **Server-authoritative:** boss AI, telegraph timing, hit detection, loot rolls, lockouts and Marks all run on the server. Clients only render.
- **Telegraphs:** sent as compact remote events (id, shape, position, time) so every device shows them in sync.
- **Lockouts:** stored in the profile with a week key, and loot uses an idempotent claim ID so it can't be granted twice.
- **Performance budget for 8 players on mobile:**
  - At most 30 active enemies and 120 particles per player on Low.
  - Other players' effects run at 50%, or only their silhouettes on Low.
  - Damage numbers are pooled and the boss uses StreamingEnabled.
  - Target at least 30 FPS on mid-range phones.
- **Analytics:** wipe heatmaps per mechanic help with balance.

### Scope
- **Beta:**
  - The Heartwood: Story and Normal, wings 1–4 with 3 phases each.
  - Raid Finder with role check and auto-scaling, the premade board and Practice Grove.
  - Personal loot, weekly lockout, Raid Marks with a vendor, bad-luck protection and the private recap.
  - AFK and kick protections, plus a basic leaderboard (fastest Normal clear).
- **Post-beta:**
  1. Hard, the Vault, Relic Sets and Resonant crafting.
  2. Shardbreaker with contest weekend, the Strategy Board and the guild calendar, and Guided Raids.
  3. Fracture levels and seasonal affixes, then a raid per realm and 16-player Alliance raids.
