# Gear levels, Stage A

An exact duplicate (same `templateId`) grants **+1 forge upgrade** on the owned copy. It does not take a Bag slot. This is the field the Bag **UPGRADE** button already writes: `item.upgrade`. There is no `item.level`.

`LaunchGate.gearLevels` defaults **off**. While it is off, rolls insert a new row the way they do today, and the reveal payload has no `oldLevel` / `newLevel`.

## Cap

Every rarity stops at `Economy.UPGRADE_MAX` (**+10**). The per-rarity caps Common 5 / Uncommon 6 / Rare 7 / Epic 8 / Legendary 10 do not fit that curve: the UPGRADE button still sells +6 through +10 on a Common piece. One cap keeps the free duplicate and the paid forge on the same track.

The button's price is gold from `Economy.upgradeCost`, plus one Gnarl's Seed from +7 upward (`+8`, `+9`, `+10`). A duplicate does not spend gold or materials. The curve is in `docs/research/economy_v1.md`.

## What a duplicate does

- Flag off: no read, no write. Caller inserts the new item. Reveal fields are absent.
- No owned copy: caller inserts. `item.upgrade` stays unset (Schema saves `+0`). Not a level-up, so `oldLevel` / `newLevel` are absent.
- Owned copy under +10: `item.upgrade` becomes `old + 1`. Stats, uid, and equipped stay put. Other copies stay in the bag.
- Which copy: the equipped one if it is under the cap (legacy `equipped` or `equipLoadout`), otherwise the lowest upgrade under the cap, otherwise the lowest uid.
- Already +10: upgrade stays. `profile.gearEssence` increases by the config amount (Common 1, Uncommon 3, Rare 10, Epic 40, Legendary / Mythic / Secret 200). A hook argument can replace that write. Stage B spends Essence. This PR only records it.

`gearEssence` is additive and defaults to 0. `item.upgrade` was already saved, so no new per-item field and no schema bump. `Accept.migrate` copies first and only fills `gearEssence`.

## Reveal

On a merge, the existing roll payload (`RollShard` / `RollShards`, not a new remote) gains:

| Field | Meaning |
|---|---|
| `merged` | `true` |
| `oldLevel` | upgrade before |
| `newLevel` | upgrade after (same number when the piece was capped) |
| `essence` | 0, or the overflow just recorded |
| `levelText` | `Bramble Fang +3 -> +4`, or nil when the upgrade did not rise |

`item` on that payload is the owned copy, not a new row.

## Stats

Equip totals, only while `gearLevels` is on: `stat.value * (1 + upgrade * 0.08)`, then the element multiplier. `+0` is ×1. The product is not written back. Stars already live in the saved `value`.

## Dev buttons

Both are Debug actions, hidden and refused while `gearLevels` is off.

- Grant a dupe. No gear yet: inserts Bramble Fang at +0. Otherwise: one free upgrade, or an Essence line at +10. Bag count does not grow.
- Fill the Bag. Inserts new rows up to the inventory cap. Does not edit or delete a row that was already there.

## Not in this PR

Stage B (salvage, lock, bulk salvage, auto-salvage, BagTools, the #384 fragment path) and Stage C (Shard Core) are later PRs. Core numbers in the economy note are proposals and nothing reads them.
