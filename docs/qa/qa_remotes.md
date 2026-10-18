# Remote coverage

G-059. Every remote in `default.project.json` against `RateLimiter.luau` and the server handler in `Remotes.luau`. This file does not change code.

`default.project.json` lists 72 remotes. 67 accept client calls. Each of those 67 has a `RULES` row (`RateLimiter.luau:27-101`) and a handler in `Remotes.bind`. An unknown action name makes `RateLimiter.take` return false (`RateLimiter.luau:105-109`), so a new handler with no rule fails closed.

Five remotes are server push. They have no rule and no `OnServerEvent`. A client `FireServer` on them has no handler.

| remote | kind | rule | handler |
|---|---|---|---|
| RollAnnounce | event | none | `RollService` fires it. No `OnServerEvent` |
| PolicyUpdated | event | none | `Remotes.pushPolicy` `FireClient` (`Remotes.luau:74-79`) |
| ProfileUpdated | event | none | `Remotes.pushProfile` `FireClient` (`Remotes.luau:82-86`) |
| CombatFx | event | none | Combat, class, raid, and dungeon servers fire it. Clients only listen |
| HavenPrompt | event | none | `HavenBuilder` fires it (`HavenBuilder.luau:2601`) |

Function remotes go through `guard`: player check, rate bucket, `xpcall`, then `respond` (`Remotes.luau:115-133`). Attack, Dodge, and Steer repeat the player check by hand (`Remotes.luau:517-534`, `Remotes.luau:673-701`).

## Inbound

| remote | rule burst / per second | what the handler checks | where the rest is checked |
|---|---|---|---|
| RollShard | 4 / 2 | `skip == true` only | `poolFromClient` (`RollService.luau:148-163`) |
| RollShards | 2 / 0.4 | none on the remote | count 1 to 10, NaN rejected (`RollService.luau:310-317`), then the same pool check |
| RollPaid | 2 / 0.5 | `skip == true` | paid luck off, then policy (`RollService.luau:164-168`) |
| OpenChest | 4 / 2 | none | `ChestService.open` |
| ChooseChest | 4 / 1 | none | `ChestService.choose` |
| MergeChest | 3 / 1 | none | `ChestService.merge` |
| BuyChest | 4 / 1 | none | `ChestService.buy` |
| ClaimLogin | 2 / 0.2 | none | `ChestService.claimLogin` |
| BuyDustShard | 4 / 1 | none | `ChestService.buyDust` |
| BuyChestBundle | 2 / 0.5 | none | `ChestService.buyBundle` |
| SetChestOptions | 4 / 1 | none | `ChestService.setOptions` |
| BuyPrism | 2 / 0.5 | none | `paidStub`, no grant (`RollService.luau:371-388`) |
| BuyBoost | 2 / 0.5 | none | refuses while paid luck is off (`RollService.luau:391-397`) |
| BuyForgeBoost | 2 / 0.5 | none | `paidStub` (`RollService.luau:400-403`) |
| GetProfile | 4 / 1 | loaded profile | snapshot added in `respond` (`Remotes.luau:102-112`) |
| GetOdds | 4 / 1 | `poolId` is a string, pool is public | `RarityConfig.disclose` (`Remotes.luau:157-172`) |
| EquipItem | 6 / 3 | `validUid` | `InventoryService.equip` |
| UnequipItem | 6 / 3 | `validUid` | `InventoryService.unequip` |
| RemoveItem | 4 / 2 | `validUid` | `InventoryService.remove` |
| DevGrant | 4 / 2 | `kind` is a string | Studio only (`RollService.luau:412-414`) |
| Debug | 6 / 2 | none on the remote | Studio only (`DebugService.luau:19-22`) |
| Attack | 8 / 6 | player, then rate, `charged == true` | `direction` rejects a non-number, NaN, and a length outside 0.05 to 3 (`CombatService.luau:595-606`) |
| Dodge | 3 / 2 | player, then rate | `CombatService.dodge`. No `xpcall` |
| SetClass | 4 / 1 | none | `ClassService.select` |
| PickTalent | 4 / 1 | none | `ClassService.pickTalent` |
| UseSkill | 6 / 3 | none | `ClassService.cast` |
| UseActionSlot | 6 / 3 | none | `ActionBarService.use` |
| SetActionBar | 4 / 2 | none | `ActionBarService.set` |
| Onboard | 4 / 1 | `"skip"` or anything else | anything else calls `advance` (`Remotes.luau:646-651`) |
| UpgradeGear | 4 / 1 | none | `CraftService.upgrade`. The uid is not passed through `validUid` |
| HatchPet | 4 / 1 | none | `PetService.hatch` |
| PetCare | 6 / 2 | none | kind is `"pet"` or `"feed"` (`PetService.luau:63-65`) |
| FusePet | 3 / 1 | none | two different strings (`PetService.luau:86-87`). No `consumeBlock` in that function |
| PaintPet | 4 / 1 | none | `PetService.paint` |
| FavoritePet | 4 / 1 | none | `PetService.favorite` |
| Trade | 6 / 2 | `action` is a string | `TradeService.handle` allow-list (`TradeService.luau:461-490`) |
| Market | 8 / 3 | `action` is a string | `MarketService.handle` |
| Loops | 4 / 1 | none | `LoopService.refresh` |
| RerollDaily | 3 / 0.5 | none | `LoopService.reroll` |
| ClaimPass | 4 / 1 | none | `LoopService.claim` |
| PremiumPass | 2 / 0.5 | none | returns a product id or a refusal. It does not grant (`LoopService.luau:191-205`) |
| StartDailyBoss | 2 / 0.3 | none | `DungeonService.startDailyBoss` |
| RaidQueue | 2 / 0.3 | none | `RaidService.queue` |
| RaidPost | 3 / 0.5 | none | `RaidService.post` |
| RaidJoin | 3 / 0.5 | none | `RaidService.join` |
| RaidPractice | 3 / 0.5 | none | `RaidService.practice` |
| RaidBuy | 3 / 0.5 | none | `RaidService.buy` |
| RaidLeave | 3 / 0.5 | none | `RaidService.leave` |
| RaidReady | 3 / 0.5 | none | `RaidService.ready` |
| Dungeon | 4 / 1 | `action` is a string | `DungeonService.action` |
| Craft | 4 / 1 | `targetUid` nil or `validUid` | `CraftService.craft` |
| Salvage | 4 / 1 | `validUid` | `CraftService.salvage` |
| BulkSalvage | 2 / 0.5 | rarity is on the ladder | `CraftService.salvageRarity` |
| SetItemLock | 6 / 3 | `validUid` and a boolean | `InventoryService.setFlag` |
| SetItemFavorite | 6 / 3 | `validUid` and a boolean | `InventoryService.setFlag` |
| BuyInventoryExpansion | 2 / 0.5 | none | `paidStub` (`RollService.luau:406-409`) |
| UseTonic | 3 / 1 | none | `ActionBarService.drink` |
| FeedItem | 4 / 2 | both uids pass `validUid` | `InventoryService.feed` |
| SetAutoAttack | 4 / 1 | boolean | `CombatService.setAutoAttack` |
| SetAutoFarm | 4 / 1 | boolean | `DungeonService.setAutoFarm` |
| Steer | 8 / 4 | boolean before the bucket | a non-boolean does not spend a token (`Remotes.luau:695-698`) |
| Travel | 4 / 1 | `destinationId` is a string | `TravelService.go` |
| BuyTravelPass | 2 / 0.5 | none | `TravelService.buyPass` |
| SetGraphicsQuality | 4 / 1 | `Quality.normalize` | writes one id (`Remotes.luau:416-429`) |
| SetSettings | 4 / 1 | patch is a table | replaces the whole `uiSettings` blob (`Remotes.luau:391-407`). Already the P2 on `docs/qa/AUDIT_FOLLOWUPS.md` |
| SetAudio | 4 / 2 | both arguments pass `tonumber` | `Audio.clampVolume` (`Remotes.luau:373-387`) |
| SetShake | 4 / 1 | boolean | `RollService.setShake` |

`validUid` is a string, length 1 to 64, letters, digits, and hyphen only (`Remotes.luau:136-140`).

## Risks

| id | risk | where | rating | test |
|---|---|---|---|---|
| R1 | A handler error returns a traceback to the client, cut at 300 characters | `Remotes.luau:97-99`, `Remotes.luau:127-131` | medium | Force a throw inside `GetProfile`'s callback. The client `error` string has no file path and no `traceback` |
| R2 | Dodge spends a token and then calls the service with no `xpcall`. Attack wraps the call. Steer does not | `Remotes.luau:673-684`, `Remotes.luau:525-534` | medium | A throw inside `CombatService.dodge` does not surface a raw error to the client. The next dodge still works. The bucket still spent one token |
| R3 | `UpgradeGear` does not use `validUid`. A huge string reaches the service | `Remotes.luau:640-643` | medium | uid `""`, uid longer than 64, and uid with a slash each return the same "do not have that item" style refusal and do not write the profile |
| R4 | `Onboard` treats every value except the string `"skip"` as advance | `Remotes.luau:646-651` | low | `nil`, `1`, and `"advance"` on step `swing` return "Try it in the world first." and do not set `onboardDone`. `"skip"` pays the skip path once |
| R5 | Debug and DevGrant are live remotes. The gate is inside the service | `DebugService.luau:19-22`, `RollService.luau:412-414` | high | Outside Studio, `Debug` "dungeon" and `DevGrant` "tokens" change nothing. Inside Studio they still respect the level gate the service already has |
| R6 | Paid stubs and the premium remote must not grant | `RollService.luau:371-409`, `LoopService.luau:191-205` | high | `BuyPrism`, `BuyBoost`, `BuyForgeBoost`, and `BuyInventoryExpansion` leave currencies and bag size unchanged. `PremiumPass` does not set a premium flag. `RollPaid` while paid luck is off grants no item |
| R7 | `SetSettings` last-write-wins a full blob | `Remotes.luau:396-398` | medium | Already tracked. Two snapshots in flight: the slower one must not erase a hotkey the faster one saved. Covered here so the remote table is not read as "no check" |

## Push events

| case | do this | pass |
|---|---|---|
| RM-1 | Client `FireServer` on RollAnnounce, PolicyUpdated, ProfileUpdated, CombatFx, and HavenPrompt | No profile write, no rate-limit warn, no client payload echoed |
| RM-2 | Server `FireClient` on ProfileUpdated and PolicyUpdated | The matching client listener runs. The other four push names are not required for this case |
| RM-3 | Call `RateLimiter.take` with a name that is not in `RULES` | Returns false. Forget on `PlayerRemoving` still clears that user (`Remotes.luau:704-706`) |
| RM-4 | Burst `RollShard` past 4, then wait | The fifth call in the same instant is "Slow down a moment." (`Remotes.luau:124-125`). A later call inside the 2 per second refill succeeds |
| RM-5 | `GetOdds` with a pool whose `public` is not true, and with a number | Both return "Unknown shard." No disclose table |

## Flags

None. Product ids stay 0 on the stub path. This list does not add a remote.
