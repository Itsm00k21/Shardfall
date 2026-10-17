# Icon list

G-044. One icon for every key in `src/ReplicatedStorage/Shared/UiIcons.luau`. The buttons already read `UiIcons.get` and `UiIcons.tintOf`. Swap the `asset` string later. Do not edit `src/`.

Shared style: flat dark-fantasy glyph, one shape, transparent background, no words, no gore, no other game's symbol. Export 64×64 (`UiTheme.TAP` is 64). Keep the glyph inside the center 48 so it still reads at 20px. Source art is a light shape. `ImageColor3` multiplies it by the tint. Kevin can ignore the tint once the baked art is in (`UiIcons.luau:34`).

Live sizes: the HUD rail draws 20×20 inside a 44px button (`HudShell.luau:284-295`, `UiTheme.TOUCH`). Hub tabs draw 22×22 (`MenuHub.luau:4013`). Bag and pet cards draw 36×36. Empty states draw 36×36. The class roster draws 28×28. The hero class card draws 32×32.

Seven keys are reserved. Nothing calls `iconOn` with them yet. The action bar still prints words. Draw them anyway so a later slot can take the key.

## Stand-in collisions

These keys share one Roblox texture today. Final art has to split every row. Tint is only so the copies are not identical.

| stand-in | keys that still share it |
|---|---|
| `HelpTab.png` | `hero`, `skill`, `info`, `class` |
| `RecordTab.png` | `bag` |
| `LeaveTab.png` | `pets`, `raids` |
| `SwitchTab.png` | `roll`, `dodge` |
| `ico_favorite.png` | `market` |
| `iconBase.png` | `pass`, `ult` |
| `GameSettingsTab.png` | `settings`, `attack`, `heavy` |
| `GuiImagePlaceholder.png` | `item`, `pet`, `empty` |

## Keys

| key | purpose | live size | style | tint | prompt |
|---|---|---|---|---|---|
| `hero` | Hero rail button and Hero tab | 20 and 22 | flat helm | `#FFD68C` (255, 214, 140) | A simple closed helm, warm stone, no face. |
| `bag` | Bag rail, Bag tab, and the empty bag | 20, 22, and 36 | flat satchel | `#BAD6FF` (186, 214, 255) | A closed satchel, pale blue-gray, no clasp gem. |
| `pets` | Pets rail, Pets tab, and the empty roster | 20, 22, and 36 | flat collar | `#A0E6AA` (160, 230, 170) | A plain collar tag, leaf green. Not a face, not a hare, not a newt. |
| `roll` | Roll rail and Roll tab | 20 and 22 | flat shard | `#DCB4FF` (220, 180, 255) | A cracked shard, lilac, one clean break. |
| `raids` | Raids tab and the empty raid list. Not on the HUD rail. | 22 and 36 | flat arch | `#FFAA8C` (255, 170, 140) | A small stone arch, ember orange. Not the hub realm arch. |
| `market` | Market rail, Market tab, and the empty board | 20, 22, and 36 | flat stall | `#FFD678` (255, 214, 120) | A stall awning, market gold. No coin that reads as a stat. |
| `pass` | Shard Pass rail, Pass tab, and the empty pass | 20, 22, and 36 | flat ticket | `#AAD2FF` (170, 210, 255) | A short ticket, pale blue. Not a star and not a power pip. |
| `settings` | Settings rail and Settings tab. The rail caption is Gear. | 20 and 22 | flat gear | `#D2CEE0` (210, 206, 224) | A six-tooth gear, cool gray. No letters. |
| `attack` | Reserved combat slot | none yet | flat arc | `#FFC4A0` (255, 196, 160) | A short swing arc, warm peach. One stroke. |
| `heavy` | Reserved heavy slot. Must not match `attack`. | none yet | flat thick arc | `#FF785A` (255, 120, 90) | A thicker swing arc, hot coral. Heavier than Attack. |
| `dodge` | Reserved dodge slot. Dodge is Shift, not Q. | none yet | flat dash | `#A0DCFF` (160, 220, 255) | A sidestep streak, ice blue. No letter. |
| `skill` | Reserved skill slot. Must not match `hero`. | none yet | flat rune | `#BEFFBE` (190, 255, 190) | A small rune ring, pale green. Not a helm. |
| `ult` | Reserved ultimate slot. Must not match `pass`. | none yet | flat burst | `#FFDC78` (255, 220, 120) | A short burst over a ring, gold. Not a ticket. |
| `item` | Bag card. Must not match `pet` or `empty`. | 36 | flat chip | `#DCD6F0` (220, 214, 240) | A plain shard chip, lilac gray. No rarity glow baked in. |
| `pet` | Pet card. A tag, not one species. | 36 | flat tag | `#AAE6B4` (170, 230, 180) | A collar tag, soft green. Not a face. |
| `info` | Reserved status mark. Must not match `hero`, `skill`, or `class`. | none yet | flat ring | `#C8DCFF` (200, 220, 255) | A small open ring, pale blue. No question mark. |
| `class` | Class roster card and the hero class card | 28 and 32 | flat pedestal | `#FFD696` (255, 214, 150) | Five short pedestals in one mark, sand gold. Not one class weapon. |
| `empty` | Fallback when `UiIcons.get` misses a key | fallback only | blank tile | `#B4AEC8` (180, 174, 200) | A dim rounded square, no picture inside. |

| drawn now | reserved |
|---|---|
| 11 (`hero`, `bag`, `pets`, `roll`, `raids`, `market`, `pass`, `settings`, `item`, `pet`, `class`) | 7 (`attack`, `heavy`, `dodge`, `skill`, `ult`, `info`, `empty`) |

The empty-state icon is the tab key (`bag`, `pets`, `raids`, `market`, `pass`), not `empty`. `empty` is only the missing-key fallback (`UiIcons.luau:56-61`).

Flags: no other game's icon, class mark, or currency symbol. Pets stay useful, not cute, matching Kevin's note on 2026-10-17.
