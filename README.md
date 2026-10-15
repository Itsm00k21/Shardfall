# Shardfall

Shardfall is a Roblox RPG + RNG game. This repo is the foundation: a [Rojo](https://rojo.space/) project you can sync into Roblox Studio and playtest. There is no combat yet. You can crack a shard, see a rarity-colored result, watch a pity bar fill, and equip or drop what you got.

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
- The odds list is labeled **PLACEHOLDER**. Those numbers are not final.
- **Crack a Shard** spends one token. The server rolls, and a popup uses the rarity color (Secret is a moving rainbow).
- The pity bar moves toward 50. At 50 rolls without a Legendary or better, the next one is forced.
- Weapons and pets can be equipped. Anything can be dropped. Materials cannot be equipped.
- **Paid roll (stub)** asks the server, which checks regional policy and then tells you paid shards are not for sale. Your tokens do not change.
- In Studio only, **Dev: +5 tokens** and **Dev: +25 Shard Luck** exist so you can see luck change the odds. They do nothing in a live server.

The Output window prints whether the profile came from a DataStore or from memory.

Stop the playtest before you expect file edits to show up. Start Play again after Rojo syncs.

### 6. Turn on DataStores

Until you do this, a gold banner says the session is **not saving**. That is normal.

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

Exit code 0 means every assertion passed. The distribution test rolls the starter pool 20,000 times with pity disabled and checks each item against the disclosed odds.

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
2. The server checks the rate limit, that the pool exists and is `public`, that you have a token, and that the inventory is under the cap (100).
3. `RollMath.roll` picks an entry from the weights, rolls weapon traits, and updates that pool's pity counter.
4. The token is spent and the item is inserted in the same profile update. If that update fails, the token is not spent.
5. The client gets the item and a profile snapshot. The popup is just a view of that result.

`RollMath` does not know about players or DataStores. That is why the tests can run it.

### Placeholder odds at 0 Shard Luck

Weights in `Pools.luau` sum to 10,000, so at 0 luck the chance is `weight / 100` percent. Luck and pity are **not** in this table. The in-game list is computed from the same weights, including your current Shard Luck. Pity is a guarantee on top, and the UI says so.

| Drop | Rarity | Kind | Chance |
| --- | --- | --- | --- |
| Splinter | Common | Material | 35% |
| Wooden Sword | Common | Weapon | 25% |
| Training Pup | Uncommon | Pet | 15% |
| Hunter Knife | Uncommon | Weapon | 10% |
| Arc Blade | Rare | Weapon | 6% |
| Storm Finch | Rare | Pet | 4% |
| Grave Lance | Epic | Weapon | 2.5% |
| Void Kitten | Epic | Pet | 1.5% |
| Oathbreaker | Legendary | Weapon | 0.5% |
| Dawn Wolf | Legendary | Pet | 0.3% |
| Kingfall | Mythic | Weapon | 0.1% |
| Ember Phoenix | Mythic | Pet | 0.08% |
| The Unnamed Edge | Secret | Weapon | 0.02% |

Rarity colors: Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic red, Secret rainbow.

Shard Luck uses this weight, with the exponents in `Rarities.luau`:

```text
effectiveWeight = baseWeight * (1 + shardLuck / 100) ^ exponent
```

Common's exponent is 0, so luck does not inflate every drop by the same amount. It shifts chance toward rarer tiers. Negative luck is treated as 0.

Pity is per pool. `pityLegendaryAt` on the starter shard is 50. The roll that would make the counter hit 50 is chosen only from Legendary, Mythic, and Secret (still weighted against each other). Any of those three resets the counter, including a natural pull before the guarantee.

Weapon trait slots: Rare and Epic roll 1, Legendary and Mythic roll 2, Secret rolls 3. Pets and materials roll none. The traits today are Lifesteal, Chain Lightning, Bonus Pet Damage, and Gold Find. Nothing in combat reads them yet.

### Paid rolls

Roblox requires you to check `PolicyService:GetPolicyInfoForPlayerAsync` and refuse when `ArePaidRandomItemsRestricted` is true, **before** a paid random item can be bought. `RollService.rollPaid` does that check first. A missing or non-boolean flag fails closed. When the flag is false, the function still returns "not for sale" and does not roll. That stub is where a developer-product receipt should go later. Free cracks do not consult the policy, because they are not paid.

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

Profile fields in version 1:

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Migration version. Bump `Schema.VERSION` when the shape changes. |
| `level`, `xp` | Stored now. XP to next level is `100 * level`. Combat is what will grant it. |
| `ascension` | Prestige counter. Unused. |
| `gold` | Soft currency. Unused beyond the display. |
| `shardTokens` | Spent by free cracks. New profiles start at 25. |
| `shardLuck` | Luck stat passed into every roll. |
| `inventory` | Weapons and materials, keyed by unique id. |
| `pets` | Pets, keyed by unique id. |
| `pity` | Per-pool `{ rollsSinceLegendary, totalRolls }`. |
| `equipped` | `{ weapon = uid or nil, pet = uid or nil }`. |

`Schema.migrate` fills missing keys and will refuse a profile newer than this server instead of rolling it backwards. There is a commented example in that function for version 2.

## Where to change things

| You want to… | Edit |
| --- | --- |
| Change drop rates or add an item | `src/ReplicatedStorage/Shared/Pools.luau` |
| Change luck, colors, trait slot counts, pity rarities | `src/ReplicatedStorage/Shared/Rarities.luau` |
| Add a weapon trait | `src/ReplicatedStorage/Shared/Traits.luau` |
| Change the pity threshold | `pityLegendaryAt` on the pool |
| Change starter tokens, level curve, or inventory cap | `src/ReplicatedStorage/Shared/Schema.luau` |
| Change autosave timing | `AUTOSAVE_SECONDS` in `DataService.luau` |
| Add a remote | `default.project.json` (the instance) and `Remotes.luau` (the handler) |

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
    Traits.luau               Weapon trait definitions and rolls
    Pools.luau                Drop tables (placeholder odds)
    RollMath.luau             Weights, pity, disclosed odds
    Schema.luau               Profile shape, migrations, snapshots
    SessionLock.luau          Lock / save decisions, no DataStore calls
    PaidRollPolicy.luau       Interprets ArePaidRandomItemsRestricted
src/ServerScriptService/ShardfallServer/
    init.server.luau          Boots remotes, then profiles
    DataService.luau          Load, autosave, mutate, release
    StoreAdapter.luau         DataStore, or memory when it is unavailable
    RollService.luau          Free rolls and the paid stub
    InventoryService.luau     Add (server-only), equip, unequip, remove
    RateLimiter.luau          Per-player burst limits on remotes
    Remotes.luau              Validation in front of the services
src/StarterPlayer/StarterPlayerScripts/ShardfallClient/
    init.client.luau          Calls the remotes
    Ui.luau                   Test panel and result popup
tests/                        Lune specs and the tiny runner
```

## Rules worth keeping

- Do not add a remote that grants items. `InventoryService.add` is server-only on purpose. A crack goes through `RollService`, which spends a token in the same update as the insert.
- Check arguments and the rate limit in `Remotes.luau`. Services still check ownership and currency, because a remote is not a trust boundary.
- If a roll can cost Robux, it has to go through `rollPaid` after `PaidRollPolicy.evaluate` returns `allowed`, and the odds you show have to be `RollMath.odds` for that player's luck. Set `placeholder = false` on the pool only when the numbers are the real ones.
- The dev grant remote checks `RunService:IsStudio()` on the server. Hiding the button on the client is not the security check.

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

- Press Play, crack a few shards, and read the Output. Then publish and confirm a rejoin keeps the inventory.
- Grant XP from a real activity. The level fields and `Schema.xpToNext` are already on the profile.
- Use traits in combat. They are rolled and saved; nothing reads `lifesteal` yet.
- Add another pool next to the starter shard. Copy the table, give it an id, and decide if `public` is true.
- Replace the dev token button with a real source (a daily, a quest, a drop).
- When you sell a shard: a developer product, a receipt handler, and `rollPaid` after the policy check. Keep the disclosed odds exact.
- Swap `DataService`'s storage for ProfileStore when you need cross-server gifting or faster lock handoff.
- Pets that follow the character, and a real HUD, once the test panel gets in the way.

## Troubleshooting

**`rojo` is not found.** Open a new terminal after installing Rokit. Run `rokit install` inside this repo.

**The plugin will not connect.** `rojo serve` has to be running in this folder. Default port is 34872. A VPN or firewall can block localhost.

**Play starts and there is no panel.** In Explorer, confirm `StarterPlayerScripts.ShardfallClient` and `ReplicatedStorage.Remotes` synced. The Output window prints a warning if the client never sees the remotes.

**Level and tokens show, but every button does nothing and odds stay on "Loading…".** The numbers arrive on a RemoteEvent. The buttons are RemoteFunctions, and they all share one caller check. Output prints a `[Shardfall]` line with the reason, and the panel shows that same text. The check uses `typeof` (an Instance), not `type` (`type(player)` is `"userdata"` and rejects every real player).

**The banner says not saving.** Expected until the place is published and Studio API access is enabled. Playtesting still works. Data is thrown away when you stop.

**Kicked the moment you join.** Read the kick reason. The usual ones are: data still locked by another session, DataStores erroring after the probe thought they worked, or a profile saved by a newer `schemaVersion`.

**A `require("./...")` error in Studio.** Update Studio. Relative string requires need the require-by-string support shipped in 2025. The server scripts do not use that form; shared modules do, because the tests load them from disk.
