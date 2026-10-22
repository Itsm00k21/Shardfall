# Remotes audit (roadmap 0.7)

Date: 2026-10-22. Base: `cursor/live-build-9721` @ ce91df5 (after the Phase 0.1 park, #367).
Test: `tests/RemotesAudit.spec.luau` loads the real `Remotes.luau` with stub services.

## Summary

- **One module: yes.** All 73 remotes are declared in `default.project.json` (`ReplicatedStorage.Remotes`). Every server handler is bound in `src/ServerScriptService/ShardfallServer/Remotes.luau`. Nothing under `src/` creates a remote at runtime, and no other script connects `OnServerEvent`/`OnServerInvoke`.
- **73 remotes:** 65 RemoteFunctions and 8 RemoteEvents.
  - 5 are server-to-client pushes with no server handler: `PolicyUpdated`, `ProfileUpdated`, `RollAnnounce`, `CombatFx`, `HavenPrompt`.
  - 68 are client-to-server: **39 live** (36 functions plus `Attack`, `Dodge`, `Steer`) and **29 parked** by `PARKED_ACTION` + LaunchGate. `ParkedRemotes.spec` already tests that every parked remote refuses "That is closed." before its handler runs.
- **Shared guard.** Every function goes through `guard()`: a `typeof` Player check (`RemoteCaller`), then `RateLimiter.take`, then the LaunchGate park, then `xpcall`, and only the first error line goes back to the client. The three events do the same checks inline.
- **Rate limits: all 68 client remotes pass.** Every one has a `RateLimiter` rule. An action with no rule fails closed (`take` returns false).
- **Client outcomes: no live remote trusts one.** `Attack` sends only a look direction. The server finite-checks it, bounds its magnitude and clamps it to the facing cone, then computes the damage itself. Rolls, loot, chests, currency and XP are all decided on the server.
- **Live results:** 29 of 39 passed every check as found, and 10 had gaps. All 10 are fixed here. After the fix, 39 of 39 live remotes pass type, range and rate checks. The open items below are design or park questions, not validation gaps.

## Live remotes

Legend: **pass**, **gap** (missing as found), **fixed** (closed in this PR), **n/a** (no arguments).

| Remote | Kind | Type | Range / size | Rate limit | Trusts client outcome | Notes |
|---|---|---|---|---|---|---|
| GetProfile | fn | n/a | n/a | pass | no | |
| GetOdds | fn | pass | pass | pass | no | String id, must be a public pool. |
| RollShard | fn | pass | pass | pass | no | `poolFromClient`: `^[%w_]+$`, ≤64, public pool. Server cooldown clock. |
| RollShards | fn | pass | pass | pass | no | count: NaN/inf refused, 1..MAX_BATCH. |
| OpenChest | fn | pass | **fixed** | pass | no | tier must be in FLOOR. A NaN/inf count used to fall back to 1 or clamp; it is now refused. |
| ChooseChest | fn | pass | **fixed** | pass | no | A NaN index used to reach `ChestConfig.choose` (it was harmless, a nil read). It is now refused at the remote. |
| MergeChest | fn | pass | pass | pass | no | tier is looked up in MERGE. |
| BuyChest | fn | pass | pass | pass | no | `forSale` tier; spends Shard Keys (not Robux). |
| ClaimLogin | fn | n/a | n/a | pass | no | Daily gate is server-side. With chests parked it pays only keys (#367). |
| EquipItem / UnequipItem / RemoveItem | fn | pass | pass | pass | no | `validUid` (`^[%w%-]+$`, ≤64), ownership checked in Schema. |
| SetItemLock / SetItemFavorite | fn | pass | pass | pass | no | uid and a boolean. |
| Debug | fn | pass | pass | pass | no | Studio only (`RunService:IsStudio`). |
| DevGrant | fn | pass | pass | pass | no | Studio only. Each grant is capped (tokens ≤9999 and so on). |
| Dungeon | fn | pass | **fixed** | pass | no | action is a string compared to literals. `enter` used to accept `"heartwood"`, a parked raid; it is now closed by `LaunchGate.dungeonOpen`. |
| Craft | fn | pass | pass | pass | no | recipe `^[%w_]+$` ≤64, targetUid is a `validUid`; forgeCraft/forgeReroll are off, so every recipe is closed. |
| UpgradeGear | fn | pass | **fixed** | pass | no | Only `type == string` was checked before; it now uses `validUid`. |
| Onboard | fn | pass | pass | pass | no | Only `"skip"` is matched; the step machine is server-side. |
| UseSkill | fn | pass | **fixed** | pass | no | A NaN/inf slot is now refused (it was harmless, a nil read). |
| UseActionSlot | fn | pass | **fixed** | pass | no | NaN passed both sides of `1..COUNT` and only failed at the slot read. It is now refused. |
| SetActionBar | fn | pass | pass | pass | no | `ActionSlots.accept`: the class must exist, 8 slots, each one validated, no duplicates. |
| UseTonic | fn | n/a | n/a | pass | no | Server cooldown. |
| HatchPet | fn | n/a | n/a | pass | no | Costs an egg or 50 gold, server-side. |
| PetCare | fn | pass | **fixed** | pass | no | uid size is now capped at 64. **See open item 1.** |
| PaintPet | fn | pass | **fixed** | pass | no | Colors were saved as any string of any size. They are now `^[%w_]+$` ≤32 and the uid is ≤64. **See open item 2.** |
| FavoritePet | fn | pass | **fixed** | pass | no | uid size is now capped at 64. |
| Loops | fn | n/a | n/a | pass | no | Leaderboard stripped while parked. |
| RerollDaily | fn | pass | **fixed** | pass | no | NaN passed `1..3` and only failed at the daily read. It is now refused. |
| SetAutoAttack / SetAutoFarm / SetShake | fn | pass | pass | pass | no | Boolean. |
| SetGraphicsQuality | fn | pass | pass | pass | no | `Quality.normalize` allowlist. |
| SetSettings | fn | pass | pass | pass | no | `Settings.normalize` rebuilds from known keys only. |
| SetAudio | fn | pass | pass | pass | no | `tonumber`, negatives refused, `clampVolume` maps NaN to the default and clamps to 0..1. It accepts numeric strings (harmless). |
| Attack | event | pass | pass | pass | no | Look x/y/z NaN-guarded, magnitude 0.05..3, cone clamp; `charged` only matches `"begin"`. |
| Dodge | event | n/a | n/a | pass | no | Charges and cooldown are server-side. |
| Steer | event | pass | pass | pass | no | Boolean. |

(Grouped rows count once per remote: 36 functions + 3 events = 39.)

## Parked remotes (29). Refused before the handler; not changed tonight

Salvage, BulkSalvage, FusePet, Trade, Market, ClaimPass, PremiumPass, StartDailyBoss, RaidQueue, RaidPost, RaidJoin, RaidPractice, RaidBuy, RaidLeave, RaidReady, BuyTravelPass, BuyDustShard, SetChestOptions, BuyChestBundle, BuyForgeBoost, SetClass, PickTalent, Travel, FeedItem, BuyGoldShop, BuyBoost, BuyPrism, RollPaid, BuyInventoryExpansion.

All pass the rate limit and the park gate, which `ParkedRemotes.spec` tests. Re-audit each one when its switch turns on (follow-up F1).

## Server-to-client pushes (5)

`PolicyUpdated`, `ProfileUpdated`, `RollAnnounce`, `CombatFx`, `HavenPrompt`. The server never listens on them, so a client firing them does nothing. Haven world prompts are server-side `ProximityPrompt.Triggered` handlers, not remotes. Heartwood and Waves have a 1 s per-player throttle, and Heartwood/practice check `raids`.

## Purchases and receipts (report only, unchanged)

`ReceiptService` sets `ProcessReceipt` assign-only. It returns `NotProcessedYet` for every receipt because nothing is sold, so no purchase can be swallowed. `ReceiptService.grant` is idempotent by receipt id. Every paid remote is parked (`paid = false`), and `crack()` re-checks `PAID_LUCK_ENABLED` and `PolicyCache.allowPaid` for Prism rolls.

## Open items, highest risk first (not fixed tonight)

1. **PetCare is live, free and has no client caller.** No UI calls it. A scripted client can feed any companion for +25 XP (up to level 50) and push the `pet` daily quest forward 2 times a second, at no cost and with no cooldown. The pay-out is capped by the daily quests, but pet levels are free. *Fix later:* park PetCare/PaintPet/FavoritePet behind a pets switch until a UI uses them, or add a cost or cooldown. This changes design, so it's Kevin's call.
2. **PaintPet has no palette.** There's no color allowlist, so any short id is saved as-is. The size is capped now; check against a real palette when pet paint ships.
3. **Live chest remotes while `chests = false`.** OpenChest, ChooseChest, MergeChest and BuyChest stay live for chests a player already owns, which #367 chose on purpose. BuyChest still turns Shard Keys into chests. Decide whether the Key shop should follow the chest switch before Phase 1.
4. **UseSkill is live while `classes = false`.** A profile that picked a class before the park can still cast. New profiles can't, because they have no class. Decide whether the class gate should cover casting.
5. **Waves are live while `waveArena = false`.** Both `Dungeon("enter","rootvault_waves")` and the pier prompt enter the endless waves. The flag is declared only. I left it open because it's in the playtest; add `rootvault_waves = "waveArena"` to `PARKED_DUNGEON` if it should close.
6. **Dev tools rely on `IsStudio()` only.** Debug, DevGrant and Dungeon `skip` have no owner allowlist. That's fine for live servers. In a Team Test every player in the session can use them.
7. **`Dungeon("leave")` with no run teleports to the hub.** It's a free hub recall, rate-limited to once a second. Low risk.
8. **Loose string sizes on lookup-only ids** (GetOdds pool, chest tiers, SetActionBar classId). They're only used as table keys and never stored. Low risk; Roblox already caps the remote payload.
9. **Formatting drift:** `stylua --check` flags one existing line in Remotes.luau (the GetOdds `disclose` call). It's untouched here, per the format-only-touched-lines rule.

## Follow-ups

- **F1.** When a parked switch turns on, audit that remote before shipping. Trade and Market take nested payload tables. RaidJoin takes a listing id. BuyGoldShop takes an offer id. FeedItem has two uids. SetChestOptions takes a mode and a rarity. Travel takes a destination.
- **F2.** Move `finite`, `validUid`, `validKey` and `validColor` into a shared `RemoteArgs` module if more remotes need them.
