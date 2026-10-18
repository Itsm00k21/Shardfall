# Soot and Apron

G-075. Hand-in contract for side quest `apron_errand`. Spend Verdant Wood x4 on success. This file does not edit `docs/content/quests_side.md`.

Choice: a short bag stays open and does not mint wood. "Fill up to 4" means stop at 4. It does not create the missing sticks.

## Contract

| field | value |
|---|---|
| id | `apron_errand` |
| title | Soot and Apron |
| giver | Nessa Pike, Forge |
| suggested level | 6 |
| cost | `wood` x4 |
| material name | Verdant Wood (`Materials.luau:51-58`) |
| on success | Remove 4 from `profile.materials.wood`. Pay the quest gold. Close the quest |
| short bag | `wood` under 4, including 0. The quest stays open. Wood count stays. Gold stays |
| extra wood | A bag above 4 spends 4 and keeps the rest |
| keys | 0 |
| suggested gold | 25 |

`Materials.sanitize` turns a missing, NaN, or negative `wood` into 0 (`Materials.luau:327-335`). `Materials.empty` starts `wood` at 0 (`Materials.luau:301-305`). Stack cap is 999, so 4 fits. Do not call `Materials.add` to fill the gap.

The offer and hand-in lines stay in `docs/content/quests_side.md`.

| when | line |
|---|---|
| Offer | Four Verdant Wood. The free ring was yesterday. |
| Hand-in | Fair trade. The apron stays sooty. |

Hand-in plays only after the spend. A short bag keeps the offer line.

## What this quest is not

| other row | why it stays separate |
|---|---|
| Daily `forge` | `Loops.POOL` text is "Upgrade a piece of gear", goal 1 (`Loops.luau:43`). The weekly row is goal 3 (`Loops.luau:53`). Progress comes from `CraftService.upgrade` only. Turning in wood does not finish it. An upgrade does not hand in `apron_errand` |
| Quest 9, `forge_remembers` | Chapter quest 9 crafts Moss Band (`docs/content/quests_ch1.md:36`, `docs/content/quests_ch1.md:59`, `docs/content/quests_ch1.md:261-273`). Suggested cost there is Verdant Wood 2, Living Vine 2, Spore Cap 1. This errand spends wood x4 and grants no ring |
| `tutorial_moss_band` | Proposed recipe id for quest 9. It is not in `Recipes.luau` (`docs/content/quests_ch1.md:263`). This errand does not call a recipe |
| `coal_glove` | The other Nessa Forge quest. It watches one anvil tap and does not spend wood |

## Pay

| id | suggested gold | keys | also | visual note |
|---|---|---|---|---|
| `apron_errand` | 25 | 0 | Wood x4 is spent. No item | Four short sticks, green-brown, the live wood color `(120, 150, 70)`, no glow. Nessa's apron stays the soot-brown one in `docs/content/quests_ch1.md:87`. No new apron |

No stats, no luck, no drop chance, no Robux.

## Flags

Soot and Apron is not the daily Forge commission and not Moss Band. Verdant Wood is not Heartwood, Living Vine, or Spore Cap. The spent sticks are not Seed Pods. No other game's quest or recipe is used.
