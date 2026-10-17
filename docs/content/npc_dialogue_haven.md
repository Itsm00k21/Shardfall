# Haven NPC dialogue

G-015. Eight Haven voices, each with a greeting, three idle lines, a shop line, and a quest hand-in line, for a later bark pass.

Places match `Haven.luau`. Chapter lines stay in `docs/content/quests_ch1.md`. Side-quest lines stay in `docs/content/quests_side.md`. This file is the stall bark. Nothing here changes `Haven.luau` or the live stall messages.

Choice: the four chapter speakers stand in Haven after quest `haven_plaza`. Four keepers cover the Armory, Market, Guild Hall, and Observatory. Sable Ilen stays silent. The Lumen Heart stays the plaza crystal, not a person.

| rule | suggested |
|---|---|
| Greeting | First talk of the session. |
| Idle | Rotates. Do not play the same idle twice in a row. |
| Shop | The prompt line. Closed stalls use the live sentence. |
| Hand-in | Plays when a G-014 quest of theirs turns in with no quest line overriding it. |
| Chapter | A chapter hand-in uses the chapter line, not this table. |
| Length | One short sentence. Fit a bark bubble. |

## Roster

| id | name | place | live station | visual note |
|---|---|---|---|---|
| `holt_vetch` | Holt Vetch | Plaza, south of the crystal, near spawn | none | Tall guide, moss-green hood, brown coat, one amber bead on a cord, soft bead glow. No weapon drawn. |
| `nessa_pike` | Nessa Pike | Forge | `craft` | Broad smith, soot-brown apron, iron-gray hair tied up, one orange coal glint on a glove. No flame. |
| `yarrow` | Yarrow | Pet Garden | `pets` | Short keeper, cream tunic, leaf-green sleeves, a basket of dull eggs, one egg with a soft green glow. No wings. |
| `orla_dunn` | Orla Dunn | Verdant portal | portal `verdant` | Tall keeper, dark green coat, a plain walking staff the color of ironbark, no glow. The portal behind them is the live green arch. |
| `pell_rowan` | Pell Rowan | Armory | `armory` | Short attendant, slate-gray coat, a wooden reel token on a cord, soft amber glint on the token. No weapon. |
| `cress_wicker` | Cress Wicker | Market | `soon` | Stall keeper, straw-yellow apron, a closed brown wicker basket, no glow. The awning stays down. |
| `tamsin_burl` | Tamsin Burl | Guild Hall | `soon` | Steward, dark oak-brown coat, a closed ledger, one dull green ribbon bookmark, no glow. No weapon. |
| `ivo_quill` | Ivo Quill | Observatory | `soon` | Tall thin watcher, ink-blue coat, a brass lens on a chain, soft lens glint. No beam. |

Sable Ilen still walks the plaza during chapter quest 8 with no line. Long pale coat, one gold shard circling the shoulders, strong gold glow. No stats. This is not the Patron aura. G-015 does not add a bark.

## Holt Vetch

`holt_vetch`. Plaza guide. He does not sell.

| kind | line |
|---|---|
| Greeting | The plaza holds. What do you need? |
| Idle | The crystal is cracked. It still stands. |
| Idle | The grove is the south corner. It is free. |
| Idle | Far Glade starts past the gate. The raid is the other door. |
| Shop | I do not sell. The grove is free. |
| Hand-in | That one is done. Walk when you are ready. |

## Nessa Pike

`nessa_pike`. Forge. Crafting is open. The free Moss Band stays chapter quest 9.

| kind | line |
|---|---|
| Greeting | Forge is hot. Show me the work. |
| Idle | The apron stays on. The coal stays in the glove. |
| Idle | An upgrade does not break the piece. |
| Idle | The free ring was the first one. |
| Shop | Live recipes charge the live fee. |
| Hand-in | Good. Leave the piece on the anvil. |

## Yarrow

`yarrow`. Pet Garden. Eggs use the live cost in `Pets.EGG_COST` (50 gold). The hatch stays the live eight species.

| kind | line |
|---|---|
| Greeting | The garden is open. Is it with you? |
| Idle | Dull eggs still hatch. One of them glows. |
| Idle | Favorites stay. I do not fuse those. |
| Idle | Affinity and Bond are two different counts. |
| Shop | An egg is 50 gold. Any of the eight. |
| Hand-in | It is well. Keep it close. |

## Orla Dunn

`orla_dunn`. Verdant portal. Rootvault is the open crawl. The other four arches keep their live "coming soon" lines.

| kind | line |
|---|---|
| Greeting | The green arch is the open one. |
| Idle | Rootvault Normal is the first crawl. |
| Idle | Sunken, Ember, Frost, and Void stay shut. |
| Idle | Far Glade is the field past the gate. |
| Shop | I sell nothing. The crawl is the door. |
| Hand-in | You came back. That is enough. |

## Pell Rowan

`pell_rowan`. Armory. The live reel uses `RarityConfig`. Pity text is `Epic n/100 · Legendary n/1000`. Every 10th roll is x2 luck (`RarityConfig.BONUS_EVERY`), not a second pull.

| kind | line |
|---|---|
| Greeting | Armory. The reel is awake. |
| Idle | Six rungs, Common up to Mythic. |
| Idle | The board counts Epic and Legendary pity. |
| Idle | Every tenth roll is double luck. |
| Shop | The reel shows its odds. I sell no power. |
| Hand-in | Counted. The odds did not change. |

## Cress Wicker

`cress_wicker`. Market. The stall message stays the live line: "The daily shop is not open yet." The Market Board is the player listing wall. Its fee stays 5% (`MarketBoard.FEE_RATE`).

| kind | line |
|---|---|
| Greeting | The stall is shut. I can still talk. |
| Idle | Baskets are empty on purpose. |
| Idle | The board lists player goods. |
| Idle | A listing fee stays spent. |
| Shop | The daily shop is not open yet. |
| Hand-in | Crates are straight. Nothing was for sale. |

## Tamsin Burl

`tamsin_burl`. Guild Hall. The stall message stays the live line: "The Guild Hall is coming soon." There is no join button.

| kind | line |
|---|---|
| Greeting | The hall is quiet. You may read the sign. |
| Idle | Eight seats would fill a raid. Not today. |
| Idle | The ledger stays closed. |
| Idle | Come back when the door is a door. |
| Shop | The Guild Hall is coming soon. |
| Hand-in | You read it. That is the whole ask. |

## Ivo Quill

`ivo_quill`. Observatory. The stall message stays the live line: "Hidden combos are coming soon." Live combo rows stay in `Pets.COMBOS`. The cap stays 3 (`Pets.COMBO_CAP`). The plaques do not grant them.

| kind | line |
|---|---|
| Greeting | The lens is for looking, not for sale. |
| Idle | The plaques name old pairs. |
| Idle | A combo cap is three, when they wake. |
| Idle | The lens glints. It does not fire. |
| Shop | Hidden combos are coming soon. |
| Hand-in | You looked. The window stays shut. |

Flags: Pell Rowan, Cress Wicker, Tamsin Burl, and Ivo Quill are new. Holt, Nessa, Yarrow, and Orla keep the chapter 1 look. Sable Ilen stays silent and is not the Patron aura. Shop lines for Market, Guild Hall, and Observatory copy the live `message` strings. Pell's pity line matches `RarityConfig.pityLine`. The tenth-roll line is x2 luck. No other game's character or signature mechanic is used.
