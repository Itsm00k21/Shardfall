# Starter kit inventory

G-052. Modules in `src/` a new game can reuse, what to strip, and a folder layout. This file does not change code.

Choice: the kit is save, net, policy, the UI shell, the roll, the bag, and an optional trade set. Haven, raids, classes, combat content, and item tables stay in Shardfall. Tests are not part of the kit. A new game writes its own specs. `init.server.luau` and `init.client.luau` are rewritten, not copied. Their order is the lesson: bind remotes and the profile listener before the load that yields.

58 modules are listed. `take` is `copy`, `strip`, or `pattern`. Pattern means keep the shape and write a new file. Do not paste the Shardfall body.

## Folder layout

| new path | from | holds |
|---|---|---|
| `src/ReplicatedStorage/Kit/Save` | Shared | CallBudget, MemoryStore, SessionLock, ProfileLoad |
| `src/ReplicatedStorage/Kit/Policy` | Shared | PaidRollPolicy |
| `src/ReplicatedStorage/Kit/Ui` | Shared | Theme, motion, router, sfx, layout, toast, settings shell |
| `src/ReplicatedStorage/Kit/Roll` | Shared | Rarities through RollNear |
| `src/ReplicatedStorage/Kit/Bag` | Shared | Stacks, view, board |
| `src/ReplicatedStorage/Kit/Trade` | Shared | Trading, MarketBoard. Omit the folder if the new game has no trade |
| `src/ServerScriptService/KitServer` | ShardfallServer | Store, data, receipts, rate limit, policy cache, run tick |
| `src/StarterPlayer/StarterPlayerScripts/KitClient` | ShardfallClient | Mobile shell, loading, menu shell, HUD shell, reel |

Keep the names `Kit`, `KitServer`, and `KitClient` so a require cannot collide with `Shared`.

## Save

| module | take | strip |
|---|---|---|
| `CallBudget.luau` | copy | Nothing. The 4 second DataStore budget stays (`CallBudget.luau:13`) |
| `MemoryStore.luau` | copy | Nothing. `updateAsync` returns nil to leave the key (`MemoryStore.luau:6-8`) |
| `SessionLock.luau` | copy | Nothing. Timeout stays 20 minutes, longer than autosave (`SessionLock.luau:25`) |
| `StoreAdapter.luau` | strip | Rename `ShardfallPlayer_v1` and `ShardfallProbe` (`StoreAdapter.luau:25-26`). Keep the probe and the memory fallback |
| `DataService.luau` | strip | Shardfall profile fields and raid hooks. Keep one profile, 60 second autosave, save-before-teleport, and bind-on-close |
| `ProfileLoad.luau` | strip | Shardfall migrate targets. Keep the generation token and the rule that a session profile is not written back (`ProfileLoad.luau:7-10`) |
| `Schema.luau` | pattern | Version, template, migrate, reconcile. Do not copy version 26 or its fields (`Schema.luau:4`) |
| `ReceiptService.luau` | strip | `Loops.grantPremium` as the grant. Keep assign-only `ProcessReceipt`, an unknown product left unprocessed, and one receipt id paying once (`ReceiptService.luau:4-12`) |
| `Economy.luau` | pattern | The receipt map only. Leave gold, dust, and forge costs |

## Net

| module | take | strip |
|---|---|---|
| `RateLimiter.luau` | strip | The action names. Keep the bucket: capacity, refill, forget the player on leave (`RateLimiter.luau:4-12`) |
| `RemoteCaller.luau` | copy | The comment that says Shardfall. Keep `typeof` plus `IsA("Player")` (`RemoteCaller.luau:4-8`) |
| `Remotes.luau` | pattern | Rate limit, then argument types, then pcall. Write a new remote list |
| `RunTick.luau` | strip | Crawl and loot wording. Keep one player fault from stopping the others |

## Policy

| module | take | strip |
|---|---|---|
| `PaidRollPolicy.luau` | copy | Prism comments, if the new game has no Prism. Keep fail closed when a flag is missing (`PaidRollPolicy.luau:11-12`, `PaidRollPolicy.luau:33-45`) |
| `PolicyCache.luau` | strip | Rename `paidRolls` if there is no roll. Keep one lookup per join, the Studio override, and fail closed (`PolicyCache.luau:4-8`, `PolicyCache.luau:136-147`) |

## UI shell

| module | take | strip |
|---|---|---|
| `UiTheme.luau` | strip | Any rarity color that disagrees with `Rarities`. Q-004 says the ladder is canonical. Keep padding, type size, and tap size |
| `UiMotion.luau` | copy | Nothing mechanical. Panel, tab, and press times |
| `UiRouter.luau` | strip | Shardfall tab ids. Keep one owner, and the dim as a number that open sets and close clears |
| `UiSfx.luau` | strip | Sound ids. Keep master times the UI slider |
| `UiIcons.luau` | pattern | The key, purpose, and tint shape. New art. Do not ship the stand-in textures as the kit |
| `ShellLayout.luau` | copy | Panel math |
| `HudLayout.luau` | strip | Raid and Echo rects. Keep the safe margin |
| `BannerFit.luau` | copy | The fit helper |
| `ToastQueue.luau` | copy | The queue |
| `NotifyBadges.luau` | strip | Quest and raid ids. Keep the dot |
| `ClientChrome.luau` | pattern | A tab table of id, label, and key. New tabs. Shardfall's eight are in `ClientChrome.luau:51-59` |
| `Keybinds.luau` | pattern | The map shape. New keys |
| `Settings.luau` | strip | Raid and roll toggles the new game does not have. Keep master, music, SFX, UI, text size, and reduced motion |
| `LoadingTips.luau` | pattern | A line rotator. New lines |
| `MobileShell.luau` | copy | Safe area, scale that does not shrink taps, panel aspect |
| `LoadingHud.luau` | strip | Shardfall tip text. Keep the rotator on join and on teleport |
| `MenuHub.luau` | pattern | One modal, tabs replace each other, Esc and backdrop pop (`MenuHub.luau:4-5`). New tab bodies |
| `HudShell.luau` | pattern | The corners in `HudShell.luau:6-9`. New portrait and currency sources |
| `DebugHud.luau` | pattern | Studio only, closed until a toggle. New grant buttons, or none |
| `DebugService.luau` | pattern | Refuse outside Studio |
| `DebugTools.luau` | pattern | Studio helpers only |

`MenuHud.luau` is a second menu. Leave it. The kit has one.

## Roll

Copy this set only if the new game rolls. Odds, pity, and the reel live together so the panel cannot drift (`RarityConfig.luau:4-6`).

| module | take | strip |
|---|---|---|
| `Rarities.luau` | strip | Luck exponents, or label them suggested. Keep the ladder and the colors, including Mythic red and Secret white |
| `RarityConfig.luau` | strip | `PAID_LUCK_ENABLED`, Prism, the Quick Roll product tie, and the `ShardfallMythic` topic. Keep 1-in-N, disclose, pity, and reveal timings |
| `RollMath.luau` | strip | Any path that still talks about pity at 50. The live promise is `RarityConfig` |
| `RollBoard.luau` | strip | Nothing in the stop helper. Stops are Off through Legendary (`RollBoard.luau:18`) |
| `RollLoop.luau` | strip | Pool ids. Keep the gap between taps and the reveal |
| `RollReveal.luau` | strip | Shard names in comments |
| `RollHype.luau` | strip | Shard copy |
| `CrackReveal.luau` | strip | Shard copy |
| `RollReel.luau` | strip | The Sol's RNG line (`RollReel.luau:4`). Keep server-picks, client-plays, and the focus stop |
| `RollRefuse.luau` | strip | Shard-only sentences. Keep a refuse that does not spend |
| `RollNear.luau` | copy | The near-pity pulse. It does not spend |

`Pools.luau` and `Areas.luau` are content. Leave them.

## Bag

| module | take | strip |
|---|---|---|
| `InventoryStacks.luau` | copy | Stack rules |
| `InventoryView.luau` | strip | Stat lines that are weapon-specific. Keep query, sort, and filter |
| `BagBoard.luau` | strip | Salvage copy that names Shardfall materials. Keep sort, filter, and the new mark |
| `InventoryService.luau` | strip | Item schemas. Keep the rule that the client cannot ask to be given an item |
| `InventoryHud.luau` | strip | The dev side panel. Keep the grid and equip, lock, favorite |

## Trade, optional

Omit the whole set if the new game does not trade. If it does, Robux-bought items start bound.

| module | take | strip |
|---|---|---|
| `Trading.luau` | strip | Patron tiers and Haven copy. Keep the bound check. `ROBUX_ITEM_TRADING_ENABLED` stays false until a reviewed trade exists (`Trading.luau:50`) |
| `TradeService.luau` | strip | Shardfall remote names. Keep two profiles writing together or both rolling back |
| `TradeAudit.luau` | strip | Nothing in the log shape. One DataStore key, memory fallback |
| `MarketService.luau` | strip | Haven board copy. Keep server-owned sales |
| `MarketHud.luau` | strip | Shardfall labels. Keep the lopsided warning and the confirm lock |
| `MarketBoard.luau` | strip | Listing rules that name Shardfall currencies |

## Leave behind

Everything not in the tables above stays in Shardfall. The groups:

| group | why it stays |
|---|---|
| World | Haven, Verdant, Rootvault, travel, the Grove, door choice |
| Combat and classes | Services, HUD, anims, the action bar, class tables |
| Raids | Raid modules, Echo modules, `RaidHud` |
| Content | Items, pets, materials, recipes, relics, drops, traits, codex, capture, loops, onboarding, chests, audio, models |
| Boot | `init.server.luau`, `init.client.luau`, `ForeignScripts.luau`, `Build.luau` |
| Old menu | `MenuHud.luau`, `Ui.luau` |

`Progression.luau` is not in the kit. Its curve is Shardfall's. Copy the idea of a pure function only after reading it for the new level cap.

## Boot order for a new game

| step | who |
|---|---|
| 1 | Create remotes. Rate-limit and type-check inside the handler |
| 2 | Connect the profile listener |
| 3 | `StoreAdapter.connect`, then load. A failed probe uses memory and must not pretend it saved |
| 4 | `PolicyCache.start` before any paid button |
| 5 | Client waits with a timeout. A missing event skips that connect and still asks for the profile |

Do not point the kit at `ShardfallPlayer_v1`.
