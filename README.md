# Shardfall

Shardfall is a Roblox RPG + RNG game. This repo is a [Rojo](https://rojo.space/) project you can sync into Roblox Studio and playtest. You can crack a shard, equip the rolled weapon, fight through the Rootvault, and craft with what the dungeon drops.

The server decides every roll. The client only asks and displays the answer.

## What is in this repo

- A Rojo project (`default.project.json`) that maps `src/` onto `ServerScriptService`, `ReplicatedStorage.Shared`, and `StarterPlayerScripts`.
- [Rokit](https://github.com/rojo-rbx/rokit) and [Aftman](https://github.com/LPGhatguy/aftman) manifests for the same tool versions. Rokit is the one to install if you are starting fresh. Aftman still works if you already use it.
- A [Wally](https://wally.run/) manifest with no packages yet. See [Adding a Wally package](#adding-a-wally-package).
- [Selene](https://kampfkarren.github.io/selene/) and [StyLua](https://github.com/JohnnyMorganz/StyLua) configs.
- Player profiles with a versioned schema, session locking, and autosave. If DataStores are unavailable, the game still runs in memory and says so.
- One starter shard pool. Odds are **placeholders** and the UI says that out loud.
- A paid-roll remote that checks `PolicyService` and then refuses. It does not charge anyone.
- Unit tests for the roll math, pity, luck, the profile schema, the session lock, and the paid-roll gate.

## Playtest it in Studio

### 1. Install Rokit

Rokit downloads the tools this repo pins, so your Rojo version matches the project.

macOS or Linux:

```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | iex
```

Close the terminal and open it again. `rojo` has to be on your PATH (`~/.rokit/bin` on macOS and Linux).

Already on Aftman? Skip Rokit. `aftman.toml` lists the same tools. Install Aftman from its repo, then run `aftman install` in this folder.

### 2. Install the project tools

From the repo root:

```bash
rokit install
```

The first time, Rokit asks you to trust each tool. Accept the five in `rokit.toml`: Rojo, Wally, Lune, StyLua, and Selene.

Check:

```bash
rojo --version
```

You want Rojo 7.7.1.

### 3. Install the Rojo Studio plugin

Either:

```bash
rojo plugin install
```

or install it from the [Creator Store](https://create.roblox.com/store/asset/13916111004/Rojo). Restart Studio if the plugin was not there when Studio opened.

### 4. Sync the project

In this folder:

```bash
rojo serve
```

Leave that terminal running. In Studio, create a Baseplate (or open any place), open the Rojo plugin, and connect to `localhost:34872`.

Rojo only writes the instances this project describes. It will not delete your baseplate, lighting, or scripts you add later in those services (`$ignoreUnknownInstances` is on).

You should see:

- `ReplicatedStorage.Shared` — roll math, pools, profile schema
- `ReplicatedStorage.Remotes` — the remote functions the UI calls
- `ServerScriptService.ShardfallServer` — the server script
- `StarterPlayer.StarterPlayerScripts.ShardfallClient` — the test UI

### 5. Press Play

A panel named **SHARDFALL** sits on the right.

- You start at level 1 with **25 shard tokens**, 0 gold, 0 Shard Luck.
- **Armory** and **Pets** are separate roll areas. You start in Verdant Wilds (Ascension 0). Sunken Reach, Emberforge, Frostveil, and Void Rift show as locked until your ascension reaches them.
- **Crack a Shard** spends one token in the selected area. The popup shows the rarity color (Secret is a moving rainbow), the rolled stats, and a quality such as `92% roll`.
- Pity counts **up**: `Pity 18 / 50 toward Legendary`. The bar fills with that same number. At 50, the next roll is Legendary or better, then the counter resets. Armory and pets keep separate counters.
- **Odds** (the word, not an icon) opens the disclosure for the realm you have selected, above the Prism buttons. Those numbers are `RollMath.odds`. They include Shard Luck and an active Luck Boost. Pity stays out of the percentages until the next roll is the guarantee, and then the list is only Legendary or better and still sums to 100%. Every pool's rarity totals at 0 luck are Common 60%, Uncommon 25%, Rare 10%, Epic 4%, Legendary 0.80%, Mythic 0.18%, Secret 0.02%.
- A **Not saved** badge means this session is memory-only. Click it for one line about publishing, then click it again to hide that line.
- Out of tokens, Crack dims and a line under the button says "Not enough tokens."
- **Inventory** opens from the button under the health bar, or the **I** key. It is a grid of item cards with rarity-colored borders (Mythic and Secret use a moving prismatic stroke). Tabs are Weapons, Armor, Accessories, Pets, Materials, and Items. Filters cover rarity (more than one at once), realm, slot or weapon type, socket count, equipped, and locked. Sort is power, rarity, newest, or name, and there is a search box. Select a card for stats, realm, equip, lock, favorite, salvage, and a compare against the piece you have equipped. Salvage is refused while the piece is locked or equipped. Bulk salvage asks you to confirm a rarity, then skips locked and equipped copies. The capacity line is `used / cap`. **+ Slots** is a paid expansion stub and does not charge Robux. Accessories (ring, amulet, charm) can be empty. The side panel no longer lists the bag. **Dev** stays collapsed and only appears in Studio.
- Each piece keeps its own id. When you own a second copy, **Feed** on the detail pane asks you to confirm, then consumes an unlocked duplicate. Five stars is the cap. Each star is +8% to the rolled stats. ★3 unlocks Starforged and ★5 unlocks Ascendant (placeholder perks). Armor equips into helm, chest, legs, or boots.
- **Crack (Shard Token)** spends an earned Shard Token. **Crack (Prism Token)**, **Buy Prism Tokens**, and **Buy Luck Boost** are the paid random items. They stay hidden until the server has a policy result, and they stay hidden with a region line when `ArePaidRandomItemsRestricted` is true. Prism cracks spend Prism Tokens. The Robux pack (100 Robux for 10 Prism Tokens) and the Luck Boost (+25 Shard Luck) are stubs and do not charge.
- You spawn on the Haven plaza, under the Lumen Heart. The hub is a sky island: the walk surface is at y=120, and the server removes Studio's default Baseplate and SpawnLocation so the floors are not buried in the grid. In Explorer, **Haven** is a direct child of Workspace (Persistent), next to Terrain. StreamingEnabled is a Workspace property in the Rojo project, because a script cannot set it. The plaza stays loaded at spawn, and the crawl rooms stream in when you enter them. Walking from the Forge to the far realm arch takes about 20–30 seconds. A straight bridge runs from the plaza to each island and to the south shelf, where Verdant Wilds, Sunken Reach, Emberforge, Frostveil, and Void Rift stand in one row. District names float on the far side of each island. Falling below y=60 puts you back on the plaza. **Menu**, **Inventory**, **Travel**, **Attack**, **Tonic**, and **Auto Farm** sit on the bottom corners for a thumb. **Graphics** cycles Low, Med, and High and saves the choice. A touch device with no saved tier starts on Low, which hides extra dressing, cuts particles, and eases fog and bloom. **Travel** opens a map of Spawn, Forge, Armory Rolls, Pet Rolls, Market, and Dungeon Portals. A waystone in each district unlocks on first touch and stays in the save; locked stones stay grey. Travel waits about 10 seconds, streams the destination, then moves you. The travel pass that skips that wait is not for sale yet. The Lumen Heart is a tall crystal with light beams and orbiting shards. Waterfalls drop off the island edges, clouds sit under the rock, and giant shards drift in the sky. Lanterns turn on after dusk. Townsfolk walk the plaza. Ambience slots stay empty until a free Roblox audio id is verified. **E** on a station opens the panel that already exists: Armory for weapons and armor, Pet Garden for pets, Forge for craft. Market, Guild Hall, and the Observatory say coming soon. The green Verdant arch enters the Rootvault the same way as **Enter Rootvault**. The first room is a grass clearing with trees, a few thousand studs south of the hub. The other four arches glow and stay sealed. **Enter Rootvault** on the panel still works. **Auto Attack** starts on: the server swings at the nearest enemy inside your weapon's range, on that weapon's attack speed. Melee aims the arc at that enemy. Bows and staffs fire at it. Click the world, or press **Attack**, when you want to aim yourself. If nothing is in range the status line says "No target in range." Damage, attack speed, and crits come from the equipped weapon. HP and Defense come from armor. An equipped pet hits the nearest enemy on its own timer using Pet Damage. Bonus Pet Damage on the pet or the weapon multiplies those hits. There is no pet model yet; the gold or white number is the swing. Numbers float off the target; crits are gold. A bar sits at the top left and above your head.
- The crawl is hub, three rooms, then Grandmother Gnarl. Choked Thicket is two Vine Crawlers. Spore Canopy adds a Moss Crawler. Brute Den is a Root Brute and a Thorn Sprite. Monsters are anchored part rigs (segments, wings, root fists, a giant tree witch) with a sway or wing beat, a hit flash, and a leaf burst when they die. The boss is about five times a normal creature. Her slam paints a root warning, half health fills the room with spore fog unless you stand in the sunbeam, and saplings sprout in the root ring. Rooms are dressed with pines, a world-tree, mushroom trees, willows, ruins, ponds, and fireflies. Clear rewards gold, shard tokens, XP, Verdant materials, and sometimes a free Armory or Pets crack. A card lists what you got, then hides itself after a few seconds.
- A cleared room counts down about 3 seconds (the status line and the dungeon row both show it) and then teleports you to the next room. **Next room** still skips the wait. **Rootvault Waves** is a second entry: one arena, bigger packs, more HP and damage each wave, a boss every 5 waves, and a payout when the wave dies. It stops when you fall.
- **Auto Farm** starts off. Turn it on and a win or a loss sends you back into the same mode after the card closes. With Auto Attack also on, the server walks you toward the nearest enemy until you are in weapon range. Melee closes in. Bows and staffs stop at a comfortable distance. Your own movement (keyboard, gamepad, or the touch thumbstick) overrides that walk.
- **Forge** (the Craft tab) has Craft, Salvage, and Materials. Crafting Level runs from 1 to 100. The six iron weapons craft at level 1 from Verdant Bark. Thornbound Blade needs level 10 and a Thornbound Scroll. Salvage breaks unequipped gear into that realm's materials. Killing a Vine Crawler drops Verdant Bark, Living Vine, and Verdant Wood. Spore Bats drop Verdant Bark and Spore Caps. Root Brutes drop Heartwood and Ironbark, and can drop the scroll. Grandmother Gnarl drops Gnarl's Seed, and that seed is listed on the clear card. Auto-Farm uses the same kill drops. Forge Boost is a 2x Crafting XP hook and is not for sale yet. In Studio, Dev can grant the boost for an hour.
- In Studio, **Dev** is collapsed at the bottom. Open it for +5 tokens, +25 Shard Luck, +1 Ascension, craft materials, or Skip to Rootvault boss. A live server rejects those grants. Ascension 1 unlocks Sunken Reach in both areas. Tidecrypt (the Sunken dungeon) stays locked until then, and it is not built yet.

The Output window prints whether the profile came from a DataStore or from memory.

Stop the playtest before you expect file edits to show up. Start Play again after Rojo syncs.

### 6. Turn on DataStores

Until you do this, the panel header shows a **Not saved** badge. That is normal.

DataStores belong to a published universe, and Studio will not touch them unless you allow it:

1. **File → Publish to Roblox**. An unpublished baseplate has nowhere to store data.
2. **Home → Game Settings → Security → Enable Studio Access to API Services**.
3. Save, press Play again.

Output should say `via DataStore`, and the banner goes away. Leave and rejoin: tokens and inventory should still be there.

`HttpService:GenerateGUID` does **not** need "Allow HTTP Requests". Leave that off.

If two Studio sessions load the same account, the second one waits, then kicks with a "still open on another server" message. That is the session lock. Stop the other playtest, or wait. A crashed server's lock expires after 20 minutes.

## Tests and a place file

Tests run in [Lune](https://lune-org.github.io/docs/), not in Studio. They use `describe` / `it` / `expect`, the same shape as [TestEZ](https://roblox.github.io/testez/). TestEZ's own runner walks Roblox instances, so this repo ships a small runner that Lune can execute on its own.

```bash
lune run tests/run
```

Exit code 0 means every assertion passed. The distribution test rolls the Verdant armory 20,000 times with pity disabled and checks each item against the disclosed odds. Stat tests check that a roll stays inside its scaled range and that quality is 0% at the minimum and 100% at the maximum. Combat tests check defense, crits, weapon-type range, and the boss weak spot. Craft tests check that a short recipe spends nothing and that a paid one grants the item.

Build a place file (gitignored, under `build/`):

```bash
rojo build -o build/Shardfall.rbxlx
```

Open that file in Studio if you want a copy with the scripts already inside. You can still connect `rojo serve` to it afterwards.

Format and lint, when you want them:

```bash
stylua src tests
selene src
```

## How a roll works

1. The client sends a pool id to `RollShard`. It does not send the item.
2. The server checks the rate limit, that the pool exists and is `public`, that your ascension is high enough, that you have a shard token or a voucher for that area, and that the inventory is under the cap (100).
3. `RollMath.roll` picks an entry from the weights, rolls that item's stats inside the rarity-scaled range, rolls weapon or armor traits, and updates that pool's pity counter. The rolled numbers and the quality percent are stored on the item.
4. The token is spent and the item is inserted in the same profile update. If that update fails, the token is not spent.
5. The client gets the item and a profile snapshot. The popup is just a view of that result.

`RollMath` does not know about players or DataStores. That is why the tests can run it.

### Placeholder odds at 0 Shard Luck

Weights in `Pools.luau` sum to 10,000, so at 0 luck the chance is `weight / 100` percent. Luck and pity are **not** in this table. The in-game list is computed from the same weights, including your current Shard Luck. Pity is a guarantee on top, and the UI says so.

Every pool uses the same rarity budget, so at 0 luck the totals are Common 60%, Uncommon 25%, Rare 10%, Epic 4%, Legendary 0.80%, Mythic 0.18%, Secret 0.02%. View odds prints those totals and then each drop. Both come from `RollMath.odds`. Shard Luck shifts the percentages toward rarer tiers. At 25 luck, Common is about 57.05% and Secret is 0.030%. An individual drop's chance is its weight over 10,000 before luck. In Verdant Wilds the Vinewood Sword is 10%. In a placeholder realm the single Common drop is 60%, because that roster is one item per rarity.

Verdant Wilds (Ascension 0) is the full roster: swords, bows, staffs, daggers, and hammers, the four-piece Grovewarden armor set, and a pet list from Moss Hare through The Sleeping Dryad. Sunken Reach, Emberforge, Frostveil, and Void Rift each have one weapon or armor piece and one pet per rarity. Those names are thematic placeholders. All of it is marked `placeholder = true`.

Rarity colors: Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic red, Secret rainbow.

Shard Luck uses this weight, with the exponents in `Rarities.luau`:

```text
effectiveWeight = baseWeight * (1 + shardLuck / 100) ^ exponent
```

Common's exponent is 0, so luck does not inflate every drop by the same amount. It shifts chance toward rarer tiers. Negative luck is treated as 0.

Pity is per pool. `pityLegendaryAt` is 50. The roll that would make the counter hit 50 is chosen only from Legendary, Mythic, and Secret (still weighted against each other). Any of those three resets the counter, including a natural pull before the guarantee. The panel shows that counter going up (`Pity 12 / 50 toward Legendary`), and the bar uses the same number.

### Roll areas and ascension

**Armory** rolls weapons and armor. **Pets** rolls companions. Each area has one pool per realm:

| Ascension | Realm | Theme |
| --- | --- | --- |
| 0 | Verdant Wilds | Nature, beasts, wood, vines |
| 1 | Sunken Reach | Water and tide |
| 2 | Emberforge | Fire and forge |
| 3 | Frostveil | Ice and time |
| 4 | Void Rift | Void and prism |

The server rejects a roll when `ascension` is below the pool's ascension. The panel lists the next locked realm under the area picker. Raising ascension (the Studio **+1 Ascension** button, until a real prestige exists) unlocks that realm in both areas. A third area would be a new row in `Areas.luau` plus pools whose `area` field matches it.

### Gear stats and quality

Each weapon and armor base in `ItemBases.luau` lists stat ranges (Damage, Attack Speed, Crit Chance, Crit Damage, HP, Defense). `Stats.roll` multiplies both ends by the rarity scale, then by `Stats.CLASS_WEIGHTS` for the weapon type. Those weights are all **1** today. That table is the class-system hook: a future class edits the numbers, and the roll already multiplies by them. Weapon type (`sword`, `bow`, `staff`, `dagger`, `hammer`) is stored on the item. There is no class yet.

Quality is the average of how close each stat landed to its own maximum. `0%` is every minimum, `100%` is every maximum, `92%` is near the top of that item's range. It does not compare a Common to a Secret. The value is stored on the item with the rolled stats.

Pets use the same roll. Every pet base lists Pet Damage and Pet HP. Common pets stop there. Uncommon pets also roll Attack Speed and Crit Chance, and so do Rare, Epic, Legendary, Mythic, and Secret pets, with wider ranges on the last two. The class-weight key for that roll is `pet`, still all 1s. The item does not store a weapon type.

Trait slots are shared: Rare and Epic roll 1, Legendary and Mythic roll 2, Secret rolls 3. Common and Uncommon roll none, pets included. Weapons and armor draw Lifesteal first. Pets draw the same four traits with Bonus Pet Damage first: Bonus Pet Damage, Lifesteal, Gold Find, Chain Lightning. Combat applies Pet Damage, Bonus Pet Damage, pet Lifesteal, and Gold Find. Chain Lightning is shown on the item and not simulated.

### Paid random items

Roblox's Paid Random Items policy covers anything bought with Robux, or with a currency bought with Robux. Shard Tokens are earned, so a Shard Token crack is not a paid random item. Prism Tokens are the Robux wallet. A Prism crack, a Prism pack, and the Luck Boost are paid random items.

`PolicyCache` calls `PolicyService:GetPolicyInfoForPlayerAsync` when the player joins and keeps `ArePaidRandomItemsRestricted` and `IsPaidItemTradingAllowed`. A failed call or a missing flag fails closed: paid buttons stay hidden and the server rejects the remote. Restricted players still crack with Shard Tokens. There is no trade UI. `PaidRollPolicy.canTrade` is the check to use if trading is added later, and it fails closed when `IsPaidItemTradingAllowed` is not true.

The **Odds** button sits above the Prism buttons. The list is every drop, as a percentage, and the chances sum to 100%. Luck, an active Luck Boost, and a pity roll that is about to fire all change that list. No outcome is empty. The Robux buttons state the number before you press them: 100 Robux for 10 Prism Tokens, and +25 Shard Luck for the boost. Both purchases return "not for sale" after the policy check. That is where a developer-product receipt should go later.

To test a restricted player without living in a regulated region, use Studio's **Player Emulator** (Test menu) and turn on `ArePaidRandomItemsRestricted`. You can also open **Dev** and press **Simulate restricted region**, which forces the same path in Studio only. `IsPaidItemTradingAllowed` is the other emulator toggle. When you publish, the **Maturity & Compliance Questionnaire** has to say this experience offers paid random items. Earned Shard Token cracks do not.

`GetOdds` returns the same table `RollMath.odds` builds. Keep using that for anything a player can pay for. Do not hand-write a second percentage list.

## How saving works

`DataService` keeps one profile in memory on this server and writes a document shaped like:

```lua
{
    Data = { -- the profile, see Schema.luau
    },
    Lock = { jobId = "...", placeId = 0, lockedAt = 0 },
}
```

The server that loads a player writes its job id into `Lock`. Another server sees a fresh lock and will not load or save that key, so two servers cannot clobber the same gold. On leave, this server writes the latest data and clears the lock. Autosave runs every 60 seconds and refreshes the timestamp. A crash can lose up to one interval of progress. If autosave stops, another server may take the lock after 20 minutes (`SessionLock.TIMEOUT_SECONDS`).

Those rules live in `SessionLock.luau` as plain functions, which is what the tests call. `DataService` is the only module that talks to `DataStoreService`. When you outgrow this (gifting, instant handoff between servers), replace the inside of `DataService` with [ProfileStore](https://madstudioroblox.github.io/ProfileStore/). ProfileStore is not on the official Wally index; unofficial copies are not worth the risk. The rest of the game already goes through `mutate`, `snapshot`, and `release`.

Profile fields in version 6:

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Migration version. Bump `Schema.VERSION` when the shape changes. |
| `level`, `xp` | XP to next level is `100 * level`. A Rootvault clear grants XP and can level you up. |
| `ascension` | Unlocks roll pools and, later, dungeons. 0 is Verdant Wilds. 4 is Void Rift. |
| `gold` | Soft currency. A Rootvault clear pays gold. Gold Find on the equipped weapon, armor, or pet adds a fraction. |
| `shardTokens` | Earned wallet. Spent by Shard Token cracks. New profiles start at 25. Not bought with Robux. |
| `prismTokens` | Robux wallet. Spent by Prism Token cracks. New and migrated profiles start at 0. |
| `shardLuck` | Earned luck stat passed into every roll. |
| `luckBoost` | Purchased luck added on top of `shardLuck`. 0 until a Luck Boost is applied. The stub does not set this; the Studio dev button does, so you can see the odds move. |
| `inventory` | Weapons, armor, and accessories, keyed by unique id. Each piece stores `stats`, `quality`, `stars`, `starProgress`, `locked`, `favorite`, and `sockets`. |
| `pets` | Pets, keyed by unique id. They use the same star feed as gear. |
| `pity` | Per-pool `{ rollsSinceLegendary, totalRolls }`. |
| `equipped` | `{ weapon, pet, armor = { helm, chest, legs, boots }, accessories = { ring, amulet, charm } }`. Ids must exist in the bag. |
| `materials` | Stack counts. Verdant forage is still Wood, Vine, Spore Cap, Ironbark, and Heartwood. Each realm also has one common, one rare, and one boss material, plus the Thornbound Scroll. |
| `consumables` | Healing Tonics. One drink restores 40% of max HP. |
| `vouchers` | Free cracks for `armory` or `pets`. A dungeon clear can grant one. |
| `craftingLevel`, `craftingXp` | Forge level, 1 to 100. Separate from combat level. |
| `craftingMilestones`, `milestoneTable` | Levels 10, 20, … 100 already reached, and the milestone rows (tier, roll bias, rarity-up, Masterwork). |
| `forgeBoostUntil` | Unix time when 2x Crafting XP ends. 0 means off. |
| `inventoryBonus` | Extra slots from a future purchase. The cap is 100 plus this. The buy remote is a stub. |

`Schema.migrate` fills missing keys and will refuse a profile newer than this server instead of rolling it backwards. Version 2 added armor slots. Version 3 added materials, tonics, and vouchers. Version 4 added star level on weapons, armor, and pets. Version 5 split Prism Tokens from Shard Tokens. Version 6 added Crafting Level. Version 7 added item locks, favorites, socket counts, accessory slots, and `inventoryBonus`.

## Where to change things

| You want to… | Edit |
| --- | --- |
| Add an item | `ItemBases.luau`, then a weight row in `Pools.luau` |
| Change drop rates | The weight rows in `Pools.luau` |
| Change stat ranges or rarity scaling | `ItemBases.luau` and `Stats.luau` |
| Sketch a future class | `Stats.CLASS_WEIGHTS` and the item's `weaponType` |
| Change luck, colors, trait slot counts, pity rarities | `src/ReplicatedStorage/Shared/Rarities.luau` |
| Add a weapon trait | `src/ReplicatedStorage/Shared/Traits.luau` |
| Change the pity threshold | `pityLegendaryAt` on the pool |
| Add a realm | Items in `ItemBases.luau`, then an armory pool and a pet pool |
| Add a roll area | A row in `Areas.luau`, and pools whose `area` matches it |
| Change starter tokens, level curve, or inventory cap | `src/ReplicatedStorage/Shared/Schema.luau` |
| Change autosave timing | `AUTOSAVE_SECONDS` in `DataService.luau` |
| Add a remote | `default.project.json` (the instance) and `Remotes.luau` (the handler) |
| Change hit math or weapon reach | `CombatMath.luau` |
| Change star feed or the per-star bonus | `Stars.luau` (`STAT_PER_STAR`, `MIN_FEED`, `MAX_FEED`) |
| Add a material or tonic | `Materials.luau`, then the profile defaults |
| Add a recipe | `Recipes.luau` |
| Add a dungeon or enemy | `Dungeons.luau`. Set `ascension` and leave `implemented = false` until the rooms exist |

Shared modules are siblings in a Folder, and they load each other with `require("./Rarities")`. That path works in current Studio (require-by-string) and in the Lune tests. Do not convert `Shared` into an `init.luau` module or those `./` requires will point at the wrong place. Server and client scripts use the usual `require(ReplicatedStorage.Shared.RollMath)` form.

## Project layout

```text
default.project.json          Rojo tree
rokit.toml                    Tool versions (Rokit)
aftman.toml                   The same tools, for Aftman
wally.toml / wally.lock       Package manifest; no dependencies yet
selene.toml / stylua.toml     Lint and format
src/ReplicatedStorage/Shared/
    Rarities.luau             Ladder, colors, luck exponents, trait slots
    Stats.luau                Stat ranges, rarity scale, quality, class weights
    Stars.luau                Duplicate feed, star level, stat multiplier
    ItemBases.luau            Weapon, armor, and pet catalog
    Traits.luau               Weapon and armor trait rolls
    Pools.luau                Per-realm drop tables (placeholder odds)
    Areas.luau                Armory and Pets, the two roll areas
    RollMath.luau             Weights, pity, stats, disclosed odds
    Currencies.luau           Shard Tokens and Prism Tokens, separate wallets
    PaidRollPolicy.luau       ArePaidRandomItemsRestricted and trading flag
    CombatMath.luau           Damage, crits, defense, melee and projectile reach
    Materials.luau            Stackable materials, one common/rare/boss row per realm
    Drops.luau                Kill drops for normal, elite, and boss enemies
    CraftingLevel.luau        Crafting Level 1–100, XP curve, milestone table
    Recipes.luau              Crafting costs, level gates, and scroll gates
    Crafting.luau             Craft, salvage, and the profile change
    Dungeons.luau             Rootvault rooms, wave scaling, boss, clear rewards
    Haven.luau                Haven island positions and the walk across them
    HavenLife.luau            Extra hub dressing, day cycle, ambience slots
    Travel.luau               Waystone unlocks and the travel cooldown
    Quality.luau              Low, Med, and High graphics budgets
    InventoryStacks.luau      Loadout line and star feeders
    InventoryView.luau        Inventory filters, sorts, and compare
    ModelFactory.luau         Part rigs for monsters and the forest kit
    VerdantScatter.luau       Seeded room dressing and Haven foliage
    VerdantLook.luau          Verdant lighting and boss telegraph sizes
    Schema.luau               Profile shape, migrations, snapshots
    SessionLock.luau          Lock / save decisions, no DataStore calls
src/ServerScriptService/ShardfallServer/
    init.server.luau          Boots remotes, then profiles
    DataService.luau          Load, autosave, mutate, release
    StoreAdapter.luau         DataStore, or memory when it is unavailable
    RollService.luau          Shard cracks, Prism cracks, purchase stubs
    PolicyCache.luau          Join-time PolicyService cache, fail closed
    InventoryService.luau     Add (server-only), equip, unequip, remove
    CombatService.luau        Swings, projectiles, player HP
    DungeonService.luau       Runs the Rootvault enemy loop
    HavenBuilder.luau         Scripted Haven blockout, streaming, prompts
    TravelService.luau        Waystone touch, stream, and teleport
    CraftService.luau         Craft remote, one mutate per recipe
    RateLimiter.luau          Per-player burst limits on remotes
    Remotes.luau              Validation in front of the services
src/StarterPlayer/StarterPlayerScripts/ShardfallClient/
    init.client.luau          Calls the remotes
    Ui.luau                   Test panel, craft tab, dungeon buttons
    CombatHud.luau            Health bar, floating numbers, victory card
    TravelHud.luau            Travel map for the six Haven stands
    MobileShell.luau          Safe-area insets and panel scale
    ThumbBar.luau             Bottom-corner buttons for touch
tests/                        Lune specs and the tiny runner
```

## Rules worth keeping

- Shardfall has to run well on iOS and Android. Keep a Low graphics tier, 44px tap targets, safe-area insets, and a button for every action. Do not add a hover-only or keyboard-only control.

- Do not add a remote that grants items. `InventoryService.add` is server-only on purpose. A crack goes through `RollService`, which spends a token in the same update as the insert.
- Check arguments and the rate limit in `Remotes.luau`. Services still check ownership and currency, because a remote is not a trust boundary.
- If a roll can cost Robux or Prism Tokens, it has to go through `PolicyCache.allowPaid` first, and the odds you show have to be `RollMath.odds` for that player's luck, boost, and pity. Set `placeholder = false` on the pool only when the numbers are the real ones.
- The dev grant remote checks `RunService:IsStudio()` on the server. Hiding the button on the client is not the security check.
- Roblox kicks a player who sends no input for about 20 minutes. `Player.Idled` in `DungeonService.start` is the hook: after 15 minutes of idle it warns once. That is not a reward cap. If AFK payouts need a cutoff later, stop Auto Farm grants in that callback before the engine kick. Do not trust the client to report idle time.

## Adding a Wally package

`wally install` works today and downloads nothing. ProfileStore is intentionally not a dependency. To add a real package, put it in `wally.toml`:

```toml
[dependencies]
promise = "evaera/promise@4.0.0"
```

Shared libraries go in `[dependencies]`. Server-only libraries go in `[server-dependencies]`. Then:

```bash
wally install
```

Point `default.project.json` at the folder Wally created (`Packages` for shared, `ServerPackages` for server-only) and require the module from there.

## Next steps

- Press Play, crack a shard, equip it, and clear the Rootvault. Then publish and confirm a rejoin keeps the inventory and the materials.
- Fill in `Stats.CLASS_WEIGHTS` when a class exists. The weapon type already chooses melee or a projectile, and rolls already multiply by that table.
- Chain Lightning is stored on items and not simulated. Bonus Pet Damage multiplies the equipped pet's hits. Lifesteal heals the swing that rolled it. Gold Find adds to clear gold.
- A floating pet model, once the timer companion is enough to playtest.
- Build Tidecrypt by setting `implemented = true` and filling its rooms in `Dungeons.luau`. The ascension gate is already there.
- Replace the dev token button with a real source (a daily, a quest, a drop).
- When you sell Prism Tokens or the Luck Boost: a developer product and a receipt handler inside the stubs, after `PolicyCache.allowPaid`. Keep the disclosed odds exact. Mark paid random items on the Maturity & Compliance Questionnaire.
- Swap `DataService`'s storage for ProfileStore when you need cross-server gifting or faster lock handoff.
- Pets that follow the character, once the test panel gets in the way.

## Troubleshooting

**`rojo` is not found.** Open a new terminal after installing Rokit. Run `rokit install` inside this repo.

**The plugin will not connect.** `rojo serve` has to be running in this folder. Default port is 34872. A VPN or firewall can block localhost.

**Play starts and there is no panel.** In Explorer, confirm `StarterPlayerScripts.ShardfallClient` and `ReplicatedStorage.Remotes` synced. The Output window prints a warning if the client never sees the remotes.

**Level and tokens show, but every button does nothing and odds stay on "Loading…".** The numbers arrive on a RemoteEvent. The buttons are RemoteFunctions, and they all share one caller check. Output prints a `[Shardfall]` line with the reason, and the panel shows that same text. The check uses `typeof` (an Instance), not `type` (`type(player)` is `"userdata"` and rejects every real player).

**The banner says not saving.** Expected until the place is published and Studio API access is enabled. Playtesting still works. Data is thrown away when you stop.

**Kicked the moment you join.** Read the kick reason. The usual ones are: data still locked by another session, DataStores erroring after the probe thought they worked, or a profile saved by a newer `schemaVersion`.

**A `require("./...")` error in Studio.** Update Studio. Relative string requires need the require-by-string support shipped in 2025. The server scripts do not use that form; shared modules do, because the tests load them from disk.
