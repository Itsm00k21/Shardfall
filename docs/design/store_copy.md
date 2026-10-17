# Store copy

G-032. Launch-card title and two-line description for every ship sku in G-031. This file does not change code. Nothing here is for sale.

Choice: the 21 ship rows get cards. The five parked pitches do not. A parked card would put luck, chests, or Prism Tokens in the store. Titles are the G-031 titles. Each title is under 30 characters. Line 1 is the look or the convenience. Line 2 is the limit. Prices stay in the price column. A live price quotes the current stub. A suggested price is labeled suggested.

`Loops.PREMIUM_ENABLED` stays false. Product ids stay 0. v0.1 shows none of these cards. The sentences below are the text for the day a sku is allowed on, matching the ship order in `docs/design/monetization_catalog.md`.

## Card rules

| rule | text |
|---|---|
| Power | Looks and bag slots only. No stats, luck, pity skip, keys, gold, dust, or raid perk |
| Quick Roll | A shorter reveal. The earned gap stays. Odds stay the 1-in-N draw |
| Bound | A direct look is one grant and stays bound while Robux-item trading is off |
| Pass | One premium flag. Archive is the same flag. Gear stays on the free track |
| Hidden | A sku with no mesh, or an id still at 0, shows no card |

## Game passes

Permanent. One purchase. Check the game-pass API. Do not write the pass into `data.vip`.

| sku | title | chars | price | line 1 | line 2 |
|---|---|---|---|---|---|
| `gp_quick` | Quick Roll | 10 | suggested 120 | Skips the long card on a Common or Uncommon crack. | Odds, tokens, and pity stay. The Mythic scene stays. |
| `gp_pockets` | Inventory expansion | 19 | suggested 80 | Ten more bag slots, once. | Looks like a brown satchel with one tan stitch. |

## Developer products

`ProcessReceipt` grants these once a product id exists. A second receipt for a one-grant look records the id and does not add a second copy.

### Convenience and the pass

| sku | title | chars | price | line 1 | line 2 |
|---|---|---|---|---|---|
| `dp_pockets` | Extra pockets | 13 | live 80 | Ten more bag slots. You can buy it more than once. | Stops at 50 bonus slots. Same satchel, two stitches. |
| `dp_pass` | Shard Pass | 10 | live 400 | Opens the Greenwake premium looks and the Gem refund. | Looks and Gems only. Nightmare Bloom still needs a clear. |
| `dp_archive` | Shard Pass archive | 18 | live 480 | The same Greenwake premium flag, after the season. | One flag. Owners of the pass are not offered this. |

The pockets pass and Extra pockets share `inventoryBonus`. Suggested ceiling is 50 bonus slots. The base bag is 100 (`Schema.luau:38`). The reconcile clamp of 500 stays a safety cap (`Schema.luau:377-379`). Five Extra pockets reach 50. Four reach 50 if the pass already added 10.

Gem refund is 400 Gems from the track, not a Robux rebate. There is no Gem pack on this list.

### Direct looks

Bound. One grant. Common through Epic. Suggested prices: Common 25, Uncommon 50, Rare 100, Epic 200. Legendary and Mythic stay unsold.

| sku | title | chars | kind | rarity | price | line 1 | line 2 |
|---|---|---|---|---|---|---|---|
| `dp_pebble_dust` | Pebble Dust | 11 | aura | Common | 25 | A few gray pebble specks at the ankles. No glow. | Bound look. The face stays clear. One grant. |
| `dp_pine_wash` | Pine Wash | 9 | dye | Common | 25 | A dull pine-brown edge on the weapon. No glow. | Bound dye. The weapon stays the same size. |
| `dp_plain_board` | Plain Board | 11 | plate | Common | 25 | A flat gray name plate. No glow. | Bound plate. Letters keep the title color. |
| `dp_sap_wisp` | Sap Wisp | 8 | aura | Uncommon | 50 | One small amber wisp at the shoulder. Soft glow. | Bound look. No beam. One grant. |
| `dp_moss_wake` | Moss Wake | 9 | trail | Uncommon | 50 | Short yellow-green moss puffs behind you. Soft glow. | Bound trail. It leaves nothing on the stone. |
| `dp_stitch_board` | Stitch Board | 12 | plate | Uncommon | 50 | A cream plate with one pine-brown stitch. Soft green corner. | Bound plate. Letters keep the title color. |
| `dp_brine_ring` | Brine Ring | 10 | aura | Rare | 100 | A teal ring on the ground under your feet. Steady glow. | Bound look. No splash. One grant. |
| `dp_pearl_wash` | Pearl Wash | 10 | dye | Rare | 100 | A cream pearl edge on the weapon. Steady pale glow. | Bound dye. The weapon stays the same size. |
| `dp_salt_board` | Salt Board | 10 | plate | Rare | 100 | White salt-crystal corners. Steady blue edge. | Bound plate. Letters stay readable. |
| `dp_cinder_crownlet` | Cinder Crownlet | 15 | aura | Epic | 200 | A small coal ring above the head. Bright orange. | Bound look. It does not cover the face. No fire. |
| `dp_coal_wash` | Coal Wash | 9 | dye | Epic | 200 | An orange coal edge on the weapon. Bright. No beam. | Bound dye. The weapon stays the same size. |
| `dp_frost_board` | Frost Board | 11 | plate | Epic | 200 | Blue-white ice corners. Bright cold glow. | Bound plate. Letters stay readable. |
| `dp_bark_sled` | Bark Sled | 9 | mount | Common | 25 | A low pale-bark sled on two root runners. No glow. | Bound mount. Walk pace. You still fight on foot. |
| `dp_sap_drifter` | Sap Drifter | 11 | mount | Uncommon | 50 | A dark-wood sled with one amber sap runner. Soft glow. | Bound mount. Walk pace. The glow stays on the runner. |
| `dp_canopy_glider` | Canopy Glider | 13 | mount | Rare | 100 | A wide seat under a stiff leaf-and-iron wing. Steady green edge. | Bound mount. Walk pace. The wing stays still in a fight. |
| `dp_frost_sledge` | Frost Sledge | 12 | mount | Epic | 200 | Pale crystal runners and a short cold trail that fades. | Bound mount. Walk pace. No ice left on the stone. |

## Parked pitches

No card. They stay at their live numbers and stay unsold.

| pitch | live offer | why it has no card |
|---|---|---|
| Prism pack | 100 Robux for 10 Prism Tokens | A Prism crack grants gear. Paid random item |
| Luck Boost | +25 Shard Luck | Sells drop odds |
| VIP | 1.2x luck, and the Patron trade name | Sells drop odds. No sku may set `vip` |
| Forge Boost | 2x Crafting XP for 60 minutes | Crafting pace is power pace |
| Chest bundle | 1 Rare chest and 1 Epic chest | Paid gear |

## Counts

| group | cards |
|---|---|
| Game passes | 2 |
| Developer products | 19 |
| Ship cards | 21 |
| Parked, no card | 5 |
| Titles over 30 characters | 0 |

## Flags

Quick Roll is the reveal shortcut, not a casino control. Shard Pass is not the platform's Premium membership. Plain Board is not Boardwalker. Stitch Board is not the Shard Board. Pebble Dust is not Pebble Toad. Sap Wisp is not Sap Glow or Sapshine. Brine Ring is not Brineplate. Frost Sledge is not Frost Pelt. Bark Sled is not Ironbark. No other game's pass or crate name is used.
