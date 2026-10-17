# Discovery plan

G-039. Title, page description, genre, and the first icon and thumbnail set. This file does not change code. Nothing here is a live page setting.

Choice: keep the experience name **Shardfall**. The crystal, the dungeon, and the raid already use other names. Putting one of those in the title makes the page sound smaller than the game. No emoji. No "simulator". No second game's title.

Roblox shows a genre and an optional subgenre on the page and uses them for Charts. There is no free tag list. A missing age questionnaire is treated as 13+, so younger players are not recommended the page. Fill the questionnaire in the same pass as `docs/design/launch_checklist.md`.

## Title

| pick | title | characters | use |
|---|---|---|---|
| A | Shardfall | 9 | Ship this. It is the product name in code and in Haven. |
| B | The Lumen Heart | 15 | The hub crystal only (`HavenBuilder.luau` names the part `LumenHeart`). Too narrow. |
| C | Rootvault | 9 | The first dungeon only. Too narrow. |

Tile length under 30 characters is a suggestion for the home tile, not a measured platform cap.

## Genre

| field | pick | why |
|---|---|---|
| Genre | RPG | The player is a class with stats, gear, pets, and a level. |
| Subgenre | Action RPG | Combat is real time. Dodge, swing, and raid marks are the verbs. |
| Not Simulation / Incremental Simulator | | The roll is one loop. It is not the only verb. |
| Not Roleplay & Avatar Sim | | Haven is a hub. It is not a life sim. |
| Not Shooter | | Bows are gear. The camera is not a gun. |
| Not Party & Casual / Minigame | | A run is a dungeon or a raid, not a round of minigames. |

Primary loop for the form: fight, roll a shard, grow a pet, clear Rootvault, then the Heartwood. Say that if the dashboard asks for a core loop.

## Description

Put the beta paragraph on the page. The first sentence is the one a search preview can cut.

Beta, 212 characters:

The Lumen Heart cracked, and the shards fell on Haven. Clear Rootvault, dodge the red marks, and bring a party to the Heartwood. Five classes, a pet that works for its keep, and odds you can read before you roll.

Later, when the six field zones exist. Do not post this while those zones are still drafts:

The shards fell on Haven. Clear Rootvault, raid the Heartwood, and walk Far Glade out to the Rift Margin. Five classes, pets, and a roll whose odds stay on the card.

| rule | beta paragraph |
|---|---|
| Names that are live | Haven, Rootvault, Heartwood, the Lumen Heart, five classes |
| Odds | "odds you can read" matches the Roll tab. It does not quote a percent |
| Party size | "a party". Premade is 4 to 8. The line does not say only 8 |
| Money | No price, no Robux, no "free luck" |
| Not live, so not in the beta line | Far Glade, the other five zones, world bosses, guild halls |

Do not add a keyword list under the paragraph. Do not repeat "RPG", "pet", or "raid" to chase search.

## Age and descriptors

Answer the live questionnaire. Suggested answers stay the ones in `docs/design/launch_checklist.md`: fantasy combat, no gore, no real-world weapons as the fantasy, no romance, no player betting. Paid random stays off the page until a product exists. `Loops.PREMIUM_ENABLED` stays false. No product id leaves 0.

| do say | do not say |
|---|---|
| Fantasy plants, beasts, and a raid boss | Blood, gore, or a real weapon |
| Dark woods and a cracked sky | Horror chase, jump scare |
| Odds are on the card before a roll | Casino, bet, jackpot, gacha |
| Cosmetics later, if a shop opens | Paid damage, paid health, paid luck |

## Icon

The page asks for the icon size. One image, no words. It has to read as a cracked crystal at a tiny tile.

| pick | image | ship |
|---|---|---|
| A | The live Lumen Heart: pale glass column `(186, 168, 204)`, warm core `(255, 214, 164)`, six lilac glass spikes, slate pedestal. A bright crack, no text | Yes |
| B | Shardjaw's jaw, gray plates, dull green cracks, no glow | Hold. It is a pet, and the page then looks like a pet game |
| C | Five class colors in one shard | No. It turns to mud at tile size |

Background `(16, 14, 24)` from `UiTheme` `background`, so the glass edge stays visible. No Robux mark. No sword across the crystal.

## Thumbnails

16:9. Order them as the row a cold player sees. Shots use live places and live creatures. No gore pile. No other game's UI.

| order | shot | what is in frame | hold until |
|---|---|---|---|
| 1 | Five spikes and the cracked heart, Haven plaza, no people in front of the glass | Icon idea, wider | Now. The heart is in `HavenBuilder` |
| 2 | A party at the Verdant arch, color `(64, 196, 96)`, dungeon prompt | Rootvault is the first clear | Now. The arch is live |
| 3 | A red telegraph and a dodge, Glass Kestrel's pane only if the flash follows the dodge | The combat verb | After KF-1 in `docs/qa/qa_kestrel_flash.md` passes |
| 4 | One roll card at Epic, rarity color `(186, 120, 232)`, odds line readable | The roll, without a fake percent | Now, if the card shows the live odds |
| 5 | Shardjaw beside the player, low and angular, no smile | A pet that is useful | When the mesh exists. Block pet is honest until then |
| 6 | Heartwood gate, four to eight players, no loot pile | The raid | When the gate has a mesh. Today Heartwood has no arch |

Thumbnail 4 must not show Epic as 4% or Legendary as 0.0%. The live sheet is the 1-in-N draw. Do not invent a new percent on the art.

## Search words inside the sentences

Use each once, in the beta paragraph or the genre form. Do not paste them as a footer.

| word | where it already is true |
|---|---|
| shard | The heart, the roll, the pet shards |
| Haven | The hub |
| Rootvault | The dungeon |
| Heartwood | The raid |
| class | Warden, Tidecaller, Forgeborn, Frostblade, Voidcaster |
| pet | Hatch roster and the three starter shards |
| dodge | The red mark |
| raid | Heartwood, 4 to 8 players |

Flags: none. No borrowed title, character, or UI shape.
