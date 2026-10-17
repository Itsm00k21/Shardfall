# Fair monetization catalog

G-031. Game passes, developer products, and Shard Pass prices in Robux. Cosmetics and convenience only. This file does not change code. Nothing here is for sale.

Choice: the ship list leaves out every live pitch that grants gear, luck, chests, or crafting speed. Those pitches stay in the parked table with their live numbers. `StoreAdapter` is the profile DataStore, not the Roblox catalog (`StoreAdapter.luau:4-8`). Paid random items are gated by `PaidRollPolicy`. The ship list has zero paid random items.

`Loops.PREMIUM_ENABLED` stays false. Product ids stay 0. Suggested prices are labeled suggested. A live number is a quote of the current stub, not a new price.

## How a purchase lands

| step | live | rule for this catalog |
|---|---|---|
| Profile save | `StoreAdapter.connect` uses `ShardfallPlayer_v1`, or memory when the probe fails | Do not store a catalog in this adapter (`StoreAdapter.luau:25`, `StoreAdapter.luau:61-75`) |
| Policy | `PaidRollPolicy.read` fails closed when a flag is missing | Parked buttons use `PaidRollPolicy.evaluate`. The ship list does not (`PaidRollPolicy.luau:33-45`, `PaidRollPolicy.luau:57-70`) |
| Prompt | `LoopService.premium` can return a product id | It already refuses while the switch is off or the id is not positive (`LoopService.luau:191-197`) |
| Receipt | `ReceiptService.start` assigns `ProcessReceipt` and returns `NotProcessedYet` | An unknown product stays pending. Do not record an id and grant nothing (`ReceiptService.luau:6-7`, `ReceiptService.luau:43-45`) |
| Idempotency | `Economy.receipt` marks `data.receipts[id]` | A repeated id must not grant twice (`Economy.luau:109-118`) |
| Pass grant | `Loops.grantPremium` sets `passPremium` only | It does not mint gear. It refuses while premium is off (`Loops.luau:380-407`) |

## Rules

| sell | do not sell |
|---|---|
| Looks: aura, trail, dye, name plate, walk mount | Stats, gear, pets, materials, gold, keys, dust, Raid Marks, Shard Tokens |
| Bag slots, up to the cap below | Luck, pity skips, the VIP multiplier |
| Quick Roll, the shorter reveal already in `RarityConfig.reveal` | Prism Token packs, paid chest bundles |
| Shard Pass cosmetics and the live Gem refund | Forge XP, gold, or combat XP multipliers |
| A bound cosmetic, one grant | Raid lockout skips, extra loot, role, or queue priority |
| | A Gem pack. Gems are not a Robux wallet on this list |

Paid cosmetics use `paid`, `robux`, or a `source` of `robux` or `premium`, so `Trading` keeps them bound while `ROBUX_ITEM_TRADING_ENABLED` is false (`Trading.luau:14-15`, `Trading.luau:366-371`). A dye does not change weapon size. A plate does not change the title string. A mount uses the player's walk and is not ridden in a fight. Shop rarity is a look label, not a gear drop.

## Live pitches, parked

These remotes already return a pitch and grant nothing. Do not give them a product id.

| pitch | live offer | where | why it stays parked |
|---|---|---|---|
| Prism pack | 100 Robux for 10 Prism Tokens | `Currencies.luau:18-19`, `Currencies.luau:67-71` | A Prism crack spends one token and grants gear (`Currencies.luau:57-61`, `RollService.luau:357-359`). That is paid power and a paid random item. |
| Luck Boost | +25 Shard Luck. No Robux price | `Currencies.luau:22`, `Currencies.luau:86-88` | `luckMultiplier` adds `luckBoost / 100` while paid luck is on (`RarityConfig.luau:103-113`). That sells drop odds. |
| VIP | `vip` multiplies luck by 1.2. No product | `RarityConfig.luau:46`, `RarityConfig.luau:115-118` | Same odds path. `vip` is also the Patron trade tier (`MarketService.luau:71`, `Trading.luau:295-296`). |
| Forge Boost | 2x Crafting XP for 60 minutes. No Robux price | `Currencies.luau:27-28`, `Currencies.luau:127-130` | Crafting pace is power pace. The daily-login line in the pitch can stay a free grant later. |
| Chest bundle | 1 Rare chest and 1 Epic chest. No Robux price | `ChestConfig.luau:129-132`, `ChestConfig.luau:347-350` | Paid gear. Legendary and Mythic are already excluded, and the bundle is still a paid random item. |
| Kill switches | `PAID_LUCK_ENABLED` and `PAID_CHESTS_ENABLED` are true | `RarityConfig.luau:19`, `ChestConfig.luau:27` | True only means the stub may show its pitch. `buyPrismPack`, `buyLuckBoost`, `buyForgeBoost`, `buyInventoryExpansion`, and `buyBundle` still return `code = "stub"` (`RollService.luau:372-410`, `ChestService.luau:211-226`). |

Restricted regions keep the parked buttons off (`PolicyCache.luau:136-146`). Earned Shard Token cracks do not use `PaidRollPolicy` (`PaidRollPolicy.luau:11-12`).

## Game passes

Permanent. One purchase. Check ownership with the game-pass API. Do not copy ownership into `data.receipts` or `data.vip`. There is no game-pass id in the repo today.

| sku | title | price | grant | does not grant | visual note |
|---|---|---|---|---|---|
| `gp_quick` | Quick Roll | suggested 120 | `quickRoll = true` | Tokens, odds, pity, or a shorter cooldown | Icon: a pale shard with one short gray crack. No glow. Not a reel of cards. |
| `gp_pockets` | Inventory expansion | suggested 80 | `inventoryBonus += 10`, once | A second grant of this pass | Icon: a brown satchel, one tan stitch. No glow. |

Quick Roll is a reveal shortcut only. It does not grant tokens, odds, pity, or extra rolls. Common and Uncommon become a toast. The reel is skipped. A Legendary scene is skipped. The Mythic scene stays (`RarityConfig.luau:520-542`). It still requires the paid-luck switch and a policy pass in current code (`RarityConfig.luau:473-478`). Suggested: when this pass ships, the entitlement alone should be enough, and the odds table should stay the earned 1-in-N draw.

The tap constants are `COOLDOWN` 0.6 and `QUICK_COOLDOWN` 1.0 (`RarityConfig.luau:29-30`, `RarityConfig.luau:498-502`). The live server gap is the longer of the next tap constant and the previous reveal (`RollLoop.luau:373-392`). Under the default full animation, a Quick Roll chain is slower for Common and Uncommon (0.6s to 1.0s) and faster for Rare (1.1s to 1.0s) and Epic (1.65s to 1.1s) (`RollLoop.luau:72-104`, `Settings.luau:270-277`). Legendary and Mythic stay on the tap constant because the default skip cuts their reveal to 0 (`Settings.luau:91`, `Settings.luau:261-267`). Suggested: ship the reveal change only. Keep the earned gap, so Rare and Epic do not roll faster.

## Developer products

`ProcessReceipt` grants these, once the map exists. A second receipt for a one-grant sku records the id and does not add another look. Titles are under 30 characters so G-032 can reuse them.

### Convenience

| sku | title | price | grant | stop | visual note |
|---|---|---|---|---|---|
| `dp_pockets` | Extra pockets | live 80 | `inventoryBonus += 10` | Refuse when `inventoryBonus + 10` would pass 50 | Icon: the same satchel, two tan stitches. No glow. |

The live stub is one pitch: 10 slots for 80 Robux (`Currencies.luau:94-95`, `Currencies.luau:97-107`). There is no game-pass id. This catalog splits that pitch into one pass and one repeatable product. The product price quotes the stub. The pass price is suggested at the same 80.

The pass and this product share one counter. Suggested paid ceiling is 50 bonus slots (bag 150 with the base 100). The base cap is 100 (`Schema.luau:38`). Reconcile clamps `inventoryBonus` at 500 (`Schema.luau:377-379`). `Schema.inventoryCap` adds that bonus (`Schema.luau:1134-1143`). The 500 clamp stays a safety cap, not a shop target. Five product buys reach 50. Four reach 50 if the pass already added 10.

### Shard Pass

Season name Greenwake, id `greenwake`. Track and cosmetics are already listed in `docs/content/shard_pass_s1.md`. This table is the price only.

| sku | title | price | product kind | grant |
|---|---|---|---|---|
| `dp_pass` | Shard Pass | live 400 | `pass` | `passPremium = true`. Claims then pay the premium track. |
| `dp_archive` | Shard Pass archive | live 480 | `archive` | The same flag. Not a second track. |

Live knobs: `PASS_ROBUX` 400, `ARCHIVE_MARKUP` 20, so `archiveRobux()` is 480 (`Loops.luau:29-31`, `Loops.luau:355-356`). `PASS_PRODUCT_ID` and `ARCHIVE_PRODUCT_ID` are 0, so `productKind` matches nothing (`Loops.luau:27-28`, `Loops.luau:359-370`). Gem refund is 400, ten rows of 40 (`Loops.luau:30`, `Loops.luau:440-447`). Skip is 80 Gems for 1000 Pass XP, and it does not claim the tier-50 feat (`Loops.luau:32`, `Loops.luau:478-493`).

| rule | number | note |
|---|---|---|
| Purchase grant | the flag only | Gear, gold, keys, and dust stay on the free track, which is earned Pass XP |
| Gem refund | 400 Gems | Not a Robux rebate. There is no Gem pack. 400 / 80 = 5 tier skips |
| Feat | Rootvault Nightmare | No Robux bypass. Claim text stays "Clear Nightmare to claim this." |
| Owned | never expires | `Loops.keepsPremium` stays true after the season ends (`Loops.luau:373-376`) |
| Both products | one flag | Suggested: do not prompt archive while `passPremium` is already true. Live `grantPremium` would accept a second receipt |
| Season 2 | suggested 400, archive 480 | Bell Tide reuses these knobs when it replaces the track. Do not add a second price constant. Owners are not charged again |

### Direct looks

Bound. One grant. Common through Epic. Legendary and Mythic stay unsold, including every premium-track skin. Prices are suggested.

| rarity | suggested Robux |
|---|---|
| Common | 25 |
| Uncommon | 50 |
| Rare | 100 |
| Epic | 200 |

| sku | title | look id | kind | rarity | price | visual note |
|---|---|---|---|---|---|---|
| `dp_pebble_dust` | Pebble Dust | `pebble_dust` | aura | Common | 25 | A few gray pebble specks at the ankles. No glow. |
| `dp_pine_wash` | Pine Wash | `pine_wash` | dye | Common | 25 | A dull pine-brown edge. No glow. The weapon stays the same size. |
| `dp_plain_board` | Plain Board | `plain_board` | plate | Common | 25 | A flat gray rectangle. `#A8A8B0` edge. No glow. Letters keep the title tint. |
| `dp_sap_wisp` | Sap Wisp | `sap_wisp` | aura | Uncommon | 50 | One small amber wisp at the shoulder. Soft glow. No beam. |
| `dp_moss_wake` | Moss Wake | `moss_wake` | trail | Uncommon | 50 | Short yellow-green moss puffs. Soft glow. |
| `dp_stitch_board` | Stitch Board | `stitch_board` | plate | Uncommon | 50 | A cream board with a pine-brown stitch. Soft `#40BA62` corner glow. |
| `dp_brine_ring` | Brine Ring | `brine_ring` | aura | Rare | 100 | A teal ring on the ground under the feet. Steady glow. No splash. |
| `dp_pearl_wash` | Pearl Wash | `pearl_wash` | dye | Rare | 100 | A cream pearl edge. Steady pale glow. No beam. |
| `dp_salt_board` | Salt Board | `salt_board` | plate | Rare | 100 | White salt-crystal corners. Steady `#488EFF` pale edge. |
| `dp_cinder_crownlet` | Cinder Crownlet | `cinder_crownlet` | aura | Epic | 200 | A small coal ring above the head. Bright orange. Does not cover the face. No fire. |
| `dp_coal_wash` | Coal Wash | `coal_wash` | dye | Epic | 200 | An orange coal edge. Bright. No beam. |
| `dp_frost_board` | Frost Board | `frost_board` | plate | Epic | 200 | Blue-white ice corners. Thin `#BA60F0` inner edge. Bright cold glow. Letters stay readable. |
| `dp_bark_sled` | Bark Sled | `bark_sled` | mount | Common | 25 | Low sled of pale bark on two root runners. Olive and tan. No glow. Walk pace. |
| `dp_sap_drifter` | Sap Drifter | `sap_drifter` | mount | Uncommon | 50 | Low sled, dark wood, one amber sap runner. Soft amber glow on the runner only. |
| `dp_canopy_glider` | Canopy Glider | `canopy_glider` | mount | Rare | 100 | A wide seat under a stiff leaf-and-iron wing. Steady green edge glow. The wing does not flap in a fight. |
| `dp_frost_sledge` | Frost Sledge | `frost_sledge` | mount | Epic | 200 | Pale crystal runners, a short seat, a cold white trail that fades. Bright trail. No ice left on the stone. |

Looks are from `docs/content/cosmetics.md` and `docs/content/mounts.md`. They are not new names. One Epic look is half of the pass price. The pass is 16 premium cosmetics plus the Gem refund, so it stays the larger bundle.

## Ship order

Suggested, for the first time an id is allowed above 0. v0.1 still sells nothing, matching `docs/design/launch_checklist.md`.

| order | sku | why this late or early |
|---|---|---|
| 1 | none | Receipts stay `NotProcessedYet` until the flags below are done |
| 2 | `gp_pockets`, `dp_pockets` | Convenience, live price, no random |
| 3 | `gp_quick` | Convenience. Confirm the odds sheet did not move |
| 4 | `dp_pass` | After the premium track is the one in `Loops.PREMIUM_TRACK` |
| 5 | `dp_archive` | Only when that season has ended, and only if they do not own it |
| 6 | the 16 looks | After the mesh or icon for that row exists. Unsold rows stay hidden |

## Before any id leaves 0

| flag | risk | cite | required before sale |
|---|---|---|---|
| F1 | high | `MarketService.luau:40-71`, `Trading.luau:303-304`, `Trading.luau:319-320` | Any `data.receipts` entry makes `verifiedSpender` and can raise the account to Trusted (daily cap 2,000,000) once it is 14 days old. A cosmetic receipt must not count. |
| F2 | high | `RarityConfig.luau:115-118`, `Trading.luau:316-317` | `vip` is 1.2x luck and an uncapped Patron trade tier. No sku may set it. |
| F3 | high | `ReceiptService.luau:43-45` | Do not mark a receipt granted until the sku's one grant has been written. |
| F4 | medium | `Loops.luau:380-400` | Buying pass and archive both set the same flag. Hide archive from owners. |
| F5 | medium | `RarityConfig.luau:19`, `ChestConfig.luau:27` | The paid-luck and paid-chest switches are true while the buttons are stubs. Shipping a look must not turn those pitches into real grants. |
| F6 | low | `Loops.luau:413-438` | Pass Gems share the Gem wallet, and Gem trading is on (`Trading.luau:49`). No new Gem sink may buy stats, luck, or raid loot. |
| F7 | medium | `RollLoop.luau:72-104`, `RollLoop.luau:373-392` | Quick Roll is a reveal shortcut. On the default full animation it also shortens the Epic gap from 1.65s to 1.1s and the Rare gap from 1.1s to 1.0s. Do not let the entitlement lower `RollLoop.gap`. |

## Counts

| group | count | Robux |
|---|---|---|
| Game passes | 2 | Quick Roll suggested 120. Pockets suggested 80 |
| Developer products | 19 | 16 looks, Extra pockets, Shard Pass, archive |
| Paid random on the ship list | 0 | Parked pitches stay at their live numbers and stay unsold |
| Suggested look ladder | 4 | 25, 50, 100, 200 |

## Flags

Quick Roll is the live name, not a casino control. Shard Pass is not the platform's Premium membership. No sku is a Patron aura, and none of these looks is that aura. Plain Board is not Boardwalker. Stitch Board is not the Shard Board. Pebble Dust is not Pebble Toad. Sap Wisp is not Sap Glow or Sapshine. Brine Ring is not Brineplate. Frost Sledge is not Frost Pelt. Bark Sled is not Ironbark. No other game's pass, crate, or pity name is used.
