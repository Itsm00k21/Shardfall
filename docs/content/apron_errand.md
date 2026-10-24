# Soot and Apron hand-in

G-075. Hand-in contract for side quest `apron_errand`. Success spends Verdant Wood x4. A short bag stays open and does not mint wood. This file does not edit `docs/content/quests_side.md`.

Choice: this quest does not fill a short bag. The fill sentence on the side-quest sheet is not the contract for this id.

## Who

| field | value |
|---|---|
| id | `apron_errand` |
| title | Soot and Apron |
| giver | Nessa Pike, Forge |
| suggested level | 6 |
| repeat | Once |
| gold | 25, suggested |
| shard keys | 0 |

Offer, kept from the side-quest sheet: "Four Verdant Wood. The free ring was yesterday."

Hand-in, kept from the side-quest sheet: "Fair trade. The apron stays sooty."

Those two lines play only after a success. A short bag does not play the hand-in line.

## Spend

The bag is `profile.materials` (`Schema.luau:253`). The id is `wood`. The live name is Verdant Wood (`Materials.luau:51-57`). Stack cap is 999. Color is 120, 150, 70.

Check the count first. Subtract only when the check passes. Do not call `Materials.add`.

| `materials.wood` before | result | wood after | gold |
|---|---|---|---|
| 0, 1, 2, or 3 | Quest stays open. No hand-in line | Unchanged | Unchanged |
| 4 | Success | 0 | +25 suggested |
| 5 or more, up to 999 | Success | count − 4 | +25 suggested |

A missing `materials` table, a missing `wood` key, or a non-number counts as 0. The quest stays open. Nothing is written.

## Not these

| source | why it is not this hand-in |
|---|---|
| Daily `forge` | `Loops.POOL` id `forge`, text "Upgrade a piece of gear", goal 1 (`Loops.luau:43`). This hand-in does not increment it |
| Weekly `forge` | "Upgrade 3 pieces of gear", goal 3 (`Loops.luau:55`). Same refusal |
| Chapter quest 9 | `forge_remembers` crafts Moss Band. Suggested cost there is Verdant Wood 2, Living Vine 2, Spore Cap 1, gold 0. This quest spends wood 4 only and grants no ring |
| `heartwood` | The rare material Heartwood. Not the wood id |
| `verdant_bark` | Verdant Bark. Not the wood id |

## Visual note

| id | name | visual note |
|---|---|---|
| `wood` | Verdant Wood | Short log, olive cut face, moss flecks. No glow. Four of them leave the bag |
| `soot_apron` | Nessa's apron | Canvas apron, soot-gray stains, dull iron buckle. No glow. It is not a reward and not a bag item |

## Flags

Soot and Apron is not the daily Forge commission and not Moss Band. The apron is not Grove Ribbon, Nest Thread, or Mudstep Ribbon. No Robux item. No stat. No other game's errand is used.
