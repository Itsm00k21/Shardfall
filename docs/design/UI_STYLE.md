# Hub style

Kevin's target layouts for the hub are the three mockups in `docs/design/mockups/`. Match the structure. Do not match the exact pixels.

- [Roll](mockups/mock_roll.jpg) — a shard on a pedestal on the left, odds bars and pity bars on the right, and a bottom row with the shard count, CRACK x1, CRACK x10, Auto, and Info.
- [Bag](mockups/mock_bag.jpg) — a tile grid with pill tabs, a detail pane with EQUIP and a gold UPGRADE, and slots 1–8 under the grid.
- [Pets](mockups/mock_pets.jpg) — a list of cards on the left and a detail pane with the perk, the stats, EQUIP, and CRACK PET SHARD.

The mockups draw a blue gem next to the shard count and the top bar. That gem is not a currency. Shardfall has no premium currency, and nothing on these screens costs Robux. The currencies on the hub are Gold, Shards, Keys, and Mastery.

The server cracks 1 to 10 shards. The roll row keeps CRACK x1 and CRACK x10. It does not add an x100 button.

Colors come from `UiTheme`. Rarity hues stay on the Q-004 ladder in `Rarities`. `UiTheme.RARITY` Common through Legendary is unchanged. The legacy `Shardfall` panel in `Ui.luau` is Echo's T-182 and is not part of this pass.

## Panels

Dark slate, rounded corners, a thin gold border, white text.

| Token | RGB | Use |
|---|---|---|
| `body` | 20, 24, 32 | Page fill behind cards |
| `panel` | 32, 36, 46 | The hub frame |
| `header` | 42, 48, 60 | Header bar and secondary buttons |
| `text` | 244, 240, 252 | Labels |
| `gold` | 255, 206, 96 | Gold cost and the UPGRADE button |
| `accent` | 255, 206, 96 | Thin panel border |
| `close` | 176, 48, 58 | CLOSE |
| `equip` | 36, 84, 168 | EQUIP |
| `claim` | 28, 110, 70 | CRACK x10 |

White, muted, and gold still clear contrast 4.5 on `body`, `panel`, and `header`.

## Roll

Gear Shards and Pet Shards stay the two kind tabs. The pedestal holds the resting shard. The odds pane lists each rarity as a bar, then the Epic and Legendary pity bars. The crack row shows the shard count (Shard Tokens, labeled Shards), CRACK x10, Auto, and Info. CRACK x1 is the crack button. The reel still plays the reveal. The text-size slider still applies.

## Bag

Pill tabs filter the tile grid. The detail pane names the item, then EQUIP, then UPGRADE with the gold cost from `Economy.upgradeCost`. The upgrade spends gold through the existing UpgradeGear path. Slots 1–8 sit under the grid and mirror the action bar. They do not add a ninth slot.

## Pets

Each companion is a card in the list. The detail pane shows the perk and the stat lines that already exist on the pet (level, bond, affinity, role). EQUIP uses the existing equip path. CRACK PET SHARD opens the pet roll. No gem price sits on that button.

## Play references

These three shots are UI references from another fantasy RPG. Match the structure. Do not copy the world, the plaza, or the character art.

- [Hotbar and quest tracker](refs/ref_hotbar.jpg) — a slim row of square slots at bottom center. Each slot has a small key in the top-left. The selected slot is outlined in white. A red dot marks a new item. Round combat buttons sit at bottom-right: attack is the large one, dodge and jump are smaller.
- [Inventory](refs/ref_inventory.jpg) — gear-type icon tabs above the grid, a detail pane that shows the equipped character, Equip Best, and a `Capacity: N/100` line at the bottom of the Bag.
- [Daily rewards](refs/ref_daily.jpg) — a rewards board only. It is not a store.

Shardfall has no Robux weapon or pet packs. `Loops.PREMIUM_ENABLED` stays false. Nothing on these screens costs Robux.

## Hotbar

The eight slots stay on keys 1–8, centered along the bottom on a desktop. The key letter sits in the top-left of the slot. The selected slot uses a white stroke. A new item (`obtainedAt` newer than the last time that slot was used) shows the `newDot` color. Attack calls the existing light attack. Dodge stays dodge. Jump sets the local humanoid jump. Heavy stays the phone chip from `HeavyChip` and stays hidden on desktop.

## Bag additions

The pill tabs keep their names and gain the gear icons from `UiIcons` (bag, attack, class, ult, pet). The detail pane includes a `Worn` viewport of the equipped character, then the item lines when one is selected. Equip Best asks the existing EquipItem path for each stronger weapon, armor piece, or accessory from `HubStyle.bestGear`. It does not spend gold and it does not equip relics. `Capacity: N/100` uses the item count and `inventoryCap` (100 when the profile has no cap).

## Quest tracker

The starter-goal tracker stays top-left and compact. Each row keeps its sentence and its `N/M` counter, with a diamond bullet in front: `◆  Roll 10 shards 3/10`. The goal data line itself stays `text N/M`.
