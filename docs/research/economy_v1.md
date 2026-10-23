# Economy v1 — Essence (Stage B salvage)

This file is also added by PR #387 (`echo/2-equip-server`). On merge, keep both sections. #387 is being revised (issue #15, comment 6358371837): duplicates may grant stars through `Stars.applyStats`, and gold upgrades get stat scaling. This section does not assume a duplicate writes `item.upgrade`.

## Wallet

`profile.gearEssence`. Default 0. A missing, non-number, NaN, negative, or infinite value becomes 0. A fraction floors. The stored number stops at 1_000_000_000.

There is no second wallet. Nothing here is sold for Robux.

## Salvage amounts

One piece of gear becomes this much Essence. The numbers match the overflow table #387 named `GearLevels.ESSENCE` (live Shard Dust / 5, with Mythic and Secret folded to 200).

| Rarity | Essence |
| --- | --- |
| Common | 1 |
| Uncommon | 3 |
| Rare | 10 |
| Epic | 40 |
| Legendary | 200 |
| Mythic | 200 |
| Secret | 200 |

## Rules that stay on this path

Salvage, lock, auto-salvage, and the bag-full confirm read `LaunchGate.gearSalvage` (off by default).

Equipped gear stays, including `equipLoadout` when that table exists. `item.locked` is the lock. `item.favorite` stays out of salvage the same way: an explicit list returns "That item is a favorite." and a rarity sweep skips that piece. There is no second lock field.

An explicit uid list is all-or-nothing. Auto-salvage is off by default and only converts a new drop. Turning it on leaves the bag as it is.

A capped duplicate calls `GearSalvage.grant(profile, amount)` or `GearSalvage.grantCappedDupe(profile, rarity, key, ownerId)`. That write does not look at the owned item. Stage A decides when a duplicate is capped. `Accept.record` on #387 can pass `grant` as its hook so both paths share one write. Calling `grant` and `Accept.record`'s default write on the same duplicate pays twice.

## Replacing #384 Fragments

PR #384 (`echo/4-payouts`) converts duplicates to Fragments (Dust/5: 1/3/10/40/200, Mythic and Secret 200) through `PayoutService.grant`. There is no fragments save field. `LaunchGate.payouts` is off. That branch is not edited here.

When that path is wired, call `GearSalvage.grant(profile, amount)` or `GearSalvage.grantCappedDupe(profile, rarity, rollId, userId)` into `profile.gearEssence`. Do not add a fragments field. Do not also call `Accept.record`'s default write on the same duplicate.

## Save plug-in

`#381` (`echo/0.5-save-system`) is not on this base. `schemaVersion` stays 26. `GearSalvage.migrate` copies first and fills `gearEssence`, `autoSalvage`, and `autoSalvageRarity`. `Schema.template` and `Schema.reconcile` default the same fields on load. When #381's migration list lands, register that copy as one step. Do not bump the version before then.
