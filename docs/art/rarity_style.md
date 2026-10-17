# Rarity style sheet

G-045. Color, border, particle, and sound for each rarity. Live numbers stay in code. New looks are suggested. Do not change `UiTheme.luau`, `Rarities.luau`, or `RarityConfig.luau`.

Choice until Kevin answers Q-004: paint each surface with the palette that surface already uses. Do not recolor the bag to match the loot beam, or the loot beam to match the bag.

## Two palettes

`UiTheme.RARITY` stops at Legendary (`UiTheme.luau:40-47`). `UiTheme.rarityColor` maps Mythic to Legendary gold and every unknown name, including Secret, to Common (`UiTheme.luau:94-99`).

`Rarities.COLOR` is the ladder `RarityConfig.color` returns (`Rarities.luau:38-46`, `RarityConfig.luau:82-84`). Secret is white in that table and a moving rainbow in the old popup (`Rarities.luau:48-50`, `Ui.luau:122-136`).

| rarity | UiTheme | Rarities | delta |
|---|---|---|---|
| Common | `#C6C4CE` (198, 196, 206) | `#A8A8B0` (168, 168, 176) | theme is lighter |
| Uncommon | `#60C478` (96, 196, 120) | `#40BA62` (64, 186, 98) | theme is paler green |
| Rare | `#60A8E8` (96, 168, 232) | `#488EFF` (72, 142, 255) | ladder is a harder blue |
| Epic | `#BA78E8` (186, 120, 232) | `#BA60F0` (186, 96, 240) | ladder is more magenta |
| Legendary | `#FFC448` (255, 196, 72) | `#FFC440` (255, 196, 64) | 8 points of blue |
| Mythic | same gold `#FFC448` | `#E6404E` (230, 64, 78) | gold versus red |
| Secret | falls through to Common `#C6C4CE` | `#FFFFFF`, plus the rainbow | missing versus white |

## Where each palette is drawn

| surface | call | Mythic shows | Secret shows |
|---|---|---|---|
| Bag and pet card stroke | `UiTheme.rarityColor` (`MenuHub.luau:1607`) | gold | Common |
| Item detail line | `UiTheme.rarityColor` (`MenuHub.luau:1512`) | gold | Common |
| Roll history chip fill | `UiTheme.rarityColor` (`MenuHub.luau:2876`) | gold | Common |
| Action-slot border | `UiTheme.RARITY`, then `UiTheme.lift` (`ActionSlots.luau:531-534`, `ActionBar.luau:412`) | lifted gold | lifted Common |
| Roll reveal, flash, cracked list | `Rarities.COLOR` (`MenuHub.luau:1029-1036`) | red | white |
| RollReel shard and card | `RarityConfig.color`, then `lift` (`RollReel.luau:50-53`) | lifted red `#F3A1A7` | white |
| Inventory HUD and the old roll popup | `Rarities.rgb` | red | white, and the popup adds the rainbow gradient |
| Loot orb and `RarityBeam` | `Rarities.rgb` (`DungeonService.luau:612-637`) | red | white |

`UiTheme.lift` brightens a color whose simple luma is under 0.62 until it aims at 0.7 (`UiTheme.luau:108-122`). It is not the WCAG contrast helper lower in the same file. RollReel lifts. Bag cards do not.

| rarity | Rarities luma | after lift on RollReel |
|---|---|---|
| Common | 0.661 | stays `#A8A8B0` |
| Uncommon | 0.603 | `#6FCB88` (111, 203, 136) |
| Rare | 0.530 | `#8AB7FF` (138, 183, 255) |
| Epic | 0.492 | `#D6A1F6` (214, 161, 246) |
| Legendary | 0.780 | stays `#FFC440` |
| Mythic | 0.393 | `#F3A1A7` (243, 161, 167) |
| Secret | 1.000 | stays `#FFFFFF` |

## Border

Live strokes: `UiTheme.STROKE` is 1 and `UiTheme.STROKE_BOLD` is 2. Bag cards use the bold stroke. The hub reel uses thickness 2 plus glow times 5 on the burst, 5 while the tension beat holds, and 2 plus glow times 3 otherwise (`MenuHub.luau:3472-3484`).

Suggested frame, only where a new border is still open:

| rarity | border | glow |
|---|---|---|
| Common | 1px, no outer glow | none |
| Uncommon | 1px | soft edge |
| Rare | 2px | steady core |
| Epic | 2px | bright, reads at 20 studs |
| Legendary | 2px | strong, plus a short trail |
| Mythic | 2px | prism if the surface is gold, red core if the surface is the ladder |
| Secret | 2px white | the rainbow moves. No extra room light (`docs/art/shot_list.md`). |

## Particles

Live cap from `RarityConfig.particleCap` (`RarityConfig.luau:501-514`). Mythic and Secret on the low graphics tier emit nothing.

| graphics tier | Common through Legendary | Mythic or Secret |
|---|---|---|
| low | 30 | 0 |
| med | 60 | 60 |
| high | 120 | 120 |

`RollReveal.particles` is on only for Legendary or better, and only from 1.15s to 1.65s of the 1.65s reel (`RollReveal.luau:46-50`, `RollReveal.luau:251-257`). `RollReveal.glow` is Epic or better from 1.0s to 1.4s (`RollReveal.luau:214-219`). The hub crack is a second clock. See `docs/art/vfx_list.md`.

Suggested particle shape. Counts stay the live cap.

| rarity | particle |
|---|---|
| Common | none |
| Uncommon | a few soft motes |
| Rare | a steady ring |
| Epic | a rising column |
| Legendary | a short trail plus the ring |
| Mythic | room-wide sparks in that surface's Mythic color |
| Secret | a slow rainbow drift, fewer motes than Mythic |

## Sound

Live `Audio.CUES` for every rarity is `""`, so `Audio.cue` returns nothing (`Audio.luau:88-95`). The design ladder is the target. It is suggested. Cue words are in `docs/art/audio_cues.md`.

| rarity | suggested sound |
|---|---|
| Common | soft click |
| Uncommon | light chime |
| Rare | bright two-note chime, then a shimmer |
| Epic | rising arpeggio, then a bass hit |
| Legendary | choir swell, a big impact, a short main-theme snippet |
| Mythic | 0.3s of silence, then a full hit and a horn |
| Secret | the Mythic hit, plus one extra high bell. Not a second horn. |

The old popup rainbow, in order: `#FF5A5A`, `#FFC450`, `#FFFF82`, `#5ADC96`, `#5AA0FF`, `#D26EFF` (`Ui.luau:129-134`).

Flags: Mythic gold and Mythic red are both live. Do not pick one in art until Q-004. No other game's rarity names or signature shine.
