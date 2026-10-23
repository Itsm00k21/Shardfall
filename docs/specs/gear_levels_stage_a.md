# Gear levels, Stage A

Two tracks, one item. No `item.level`.

- **Gold** spends `Economy.upgradeCost` and writes `item.upgrade` (+0 through +10). That is the Bag UPGRADE button.
- **Duplicates** feed **stars** through `Stars.commit`, the same math as Feed duplicate. They do not change `item.upgrade`.

`LaunchGate.gearLevels` defaults **off**. While it is off, a roll inserts a new row and the reveal has no `oldLevel` / `newLevel`. The manual Feed button stays on its own `stars` flag.

`LaunchGate.upgradeScale` defaults **off**. It is separate so gold can start scaling without also auto-feeding duplicates, and so trying the dupe rule does not have to turn gold scaling on.

## What a duplicate does (`gearLevels` on)

- No owned copy: the caller inserts. Not a star-up, so `oldLevel` / `newLevel` are absent.
- Owned copy under ★5: `Stars.commit` on that copy. The new row is not inserted. `item.upgrade`, uid, and equipped stay put. Other copies stay in the bag. A 100% quality feed is one star. A real roll uses the rolled quality (34% to 100% of a star).
- Which copy: the equipped one if it is under ★5 (legacy `equipped` or `equipLoadout`), otherwise the lowest star count, otherwise the lowest uid.
- Already ★5: stars stay. `profile.gearEssence` increases by the config amount (Common 1, Uncommon 3, Rare 10, Epic 40, Legendary / Mythic / Secret 200). A hook can replace that write. Stage B spends Essence.

## Reveal

On a merge, the existing roll payload gains:

| Field | Meaning |
|---|---|
| `merged` | `true` |
| `oldLevel` | star count before |
| `newLevel` | star count after (equal when the feed did not finish a star, or the piece was ★5) |
| `essence` | 0, or the overflow just recorded |
| `levelText` | `Bramble Fang ★2 -> ★3`, or nil when the star count did not rise |

`item` is the owned copy.

## Stats

Stars write `stat.value = baseValue * (1 + stars * 0.08)`. Gold upgrades are not written into that number.

While `upgradeScale` is on, readers multiply the saved value by `1 + upgrade * 0.08` (+0 is ×1):

- Equip stat totals
- Combat weapon damage and armor HP (defense and attack speed stay on the saved number)
- Item Power, `+10` per upgrade (the same step as one star)

`UpgradeScale.preview` is the Bag helper. It does not mutate the item.

## Dev buttons

Hidden while `gearLevels` is off.

- Grant a dupe. No gear yet: inserts Bramble Fang at ★0. Otherwise: one 100% quality feed (one star), or an Essence line at ★5. Bag count does not grow. `item.upgrade` stays put.
- Fill the Bag. Inserts new rows. Does not edit or delete a row that was already there.

## Not in this PR

Stage B and Stage C. Core numbers in `docs/research/economy_v1.md` are proposals.
