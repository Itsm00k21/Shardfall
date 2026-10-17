# Chapter 1 quests

G-013. Ten main-story quests for the first session, from the Lumen Heart crack through the first Rootvault Normal clear, for a later quest draft.

The chain follows `docs/design/shardfall_onboarding.md` and the live steps in `Onboarding.STEPS`. Haven, the Forge, the Armory, the Pet Garden, the Guild Hall, and the Verdant portal are the places in `Haven.luau`. Rootvault Normal is the live crawl in `Dungeons.luau`. Every number below is suggested. Nothing here changes `Onboarding.luau`, `RollMath.luau`, `Recipes.luau`, or `ItemBases.luau`.

Choice: quests 1 through 8 are one grant of the starter kit. The played path pays those rows. The skip path pays `Onboarding.starter` instead and opens quest 8. Do not pay both. Quests 9 and 10 pay on top, on both paths. The first reel is one guaranteed Rare or better from the Verdant armory pool. There is no element-shard item in the catalog, so the roll is a normal item. Pity still counts.

| rule | suggested |
|---|---|
| Order | Linear. Each row opens the next. |
| Skip | Mark quests 1–7 done and start at quest 8. `Onboarding.starter` is the only gold, key, tonic, and chest grant on this path: 250 gold, 40 keys, 1 Rare chest, 1 Uncommon chest, 3 tonics. It already sets `onboardStep` to `haven`. Do not also pay the quest 1–8 gold, key, tonic, or chest cells. Quest 8's 20 gold and 40 keys are already inside that grant. Also grant the one Gladecloth Vest, which that function does not contain. |
| Bound | The class weapon, Gladecloth Vest, Moss Band, Heartglow Pin, and the tutorial turtle are bound. |
| Keys | Shard Keys (`shardKeys`). The crawl's 3 shard tokens stay on the clear card. This chapter does not grant tokens or Prism Tokens. |
| Login | Quest 8 asks for the live claim. `ChestConfig.SOURCES.login` pays a Common chest and 5 keys. That payout is not in the quest column. |
| Clear card | Quest 10 does not add the crawl's 45 gold, 40 XP, or materials. The clear card pays those. |
| Seed | Gnarl's Sprout does not drop Gnarl's Seed. That stays Grandmother Gnarl's. |
| Raid | The Heartwood gate stays shut. No wing, no Marks. |
| Guild | The flyover shows the hall. Joining is not an objective. The stall still says it is coming soon. |
| Market | No market objective. The stall still says the shop is not open. |
| Roll odds | One tutorial guarantee. Pool weights and pity stay as they are. |
| Power for sale | None. No Robux item, no paid skip. |

## Chain

| order | id | title | giver | place | opens |
|---|---|---|---|---|---|
| 1 | `sky_crack` | The Sky Cracks | Lumen Heart | Above Haven, then the clearing | `five_pedestals` |
| 2 | `five_pedestals` | Five Pedestals | Lumen Heart | Class ring in the clearing | `third_hit` |
| 3 | `third_hit` | Third Hit | Holt Vetch | Verdant clearing | `red_mark` |
| 4 | `red_mark` | A Red Mark | Holt Vetch | Verdant clearing | `clearing_waystone` |
| 5 | `clearing_waystone` | Carry the Shard | Holt Vetch | Clearing Waystone | `antechamber` |
| 6 | `antechamber` | Two Doors | Holt Vetch | Rootvault Antechamber | `what_follows` |
| 7 | `what_follows` | What Follows | Holt Vetch | Antechamber chest | `haven_plaza` |
| 8 | `haven_plaza` | Haven Remembers | Lumen Heart | Haven plaza | `forge_remembers` |
| 9 | `forge_remembers` | The Forge Remembers | Nessa Pike | Forge | `down_the_roots` |
| 10 | `down_the_roots` | Down the Roots | Orla Dunn | Verdant portal, then Rootvault | — |

## Kit

Quests 1 through 8, added together, equal this kit on the played path. Pay those rows once, and do not also run the gold, key, tonic, and chest increments in `Onboarding.starter`. The skip path uses that function instead of these rows. The Gladecloth Vest is not inside `Onboarding.starter`, so a skipper still receives that one vest. The class weapon and Mossback Turtle stay inside the skipper's unopened Rare chest, and are not granted as items too.

| source | gold | shard keys | also |
|---|---|---|---|
| Quest 1 | 20 | 0 | — |
| Quest 2 | 20 | 0 | The class they picked. |
| Quest 3 | 40 | 0 | — |
| Quest 4 | 40 | 0 | — |
| Quest 5 | 40 | 0 | One Rare-or-better Verdant armory roll. |
| Quest 6 | 40 | 0 | 3 Healing Tonics. Gladecloth Vest. |
| Quest 7 | 30 | 0 | Class weapon. Mossback Turtle. 1 Uncommon chest, unopened. |
| Quest 8 | 20 | 40 | Daily login unlocks. |
| Kit total | 250 | 40 | Matches the gold and keys in `Onboarding.starter`. |

Quests 9 and 10 are extra.

| source | gold | shard keys | also |
|---|---|---|---|
| Quest 9 | 0 | 4 | Moss Band, from the free craft. |
| Quest 10 | 0 | 6 | Heartglow Pin. |
| Extra total | 0 | 10 | — |

Gold from the ten quests is 250. Keys from the ten quests are 50, before the live login's 5. An Uncommon chest in the key shop is 40. A Rare chest is 150. The chapter cannot buy a Rare chest.

## Class weapon

The quest 7 chest grants one bound weapon. Suggested sockets on that instance: 1. Catalog rows stay as they are. The last number on a weapon in `ItemBases.luau` is ascension, not sockets.

| class | id | weapon type | base | name | rarity |
|---|---|---|---|---|---|
| Warden | `warden` | sword | `hartseeker` | Hartseeker | Rare |
| Tidecaller | `tidecaller` | staff | `mycelium_staff` | Mycelium Staff | Rare |
| Forgeborn | `forgeborn` | hammer | `beastbone_hammer` | Beastbone Hammer | Uncommon |
| Frostblade | `frostblade` | dagger | `nightbriar` | Nightbriar | Rare |
| Voidcaster | `voidcaster` | bow | `galevine_bow` | Galevine Bow | Rare |

Choice: Forgeborn gets Beastbone Hammer. `ItemBases.luau` has no Verdant Rare hammer. The other four classes get a Verdant Rare of their type. Thornbound Blade stays a craft. It is not the starter sword.

## Speakers

G-015 can reuse these four people. The Heart is the plaza crystal (`Haven.CRYSTAL`, height 36), not a person.

| id | name | where | offer or hand-in | visual note |
|---|---|---|---|---|
| `lumen_heart` | Lumen Heart | Sky, then the plaza | Quests 1, 2, and 8 | Tall crystal, amber-white crack, shards falling, soft crack glow. No face. |
| `holt_vetch` | Holt Vetch | Clearing, then the waystone | Quests 3 through 7 | Tall guide, moss-green hood, brown coat, one amber bead on a cord, soft bead glow. No weapon drawn. |
| `nessa_pike` | Nessa Pike | Forge | Quest 9, and the quest 8 hand-in | Broad smith, soot-brown apron, iron-gray hair tied up, one orange coal glint on a glove. No flame. |
| `yarrow` | Yarrow | Pet Garden | One line during the quest 8 flyover | Short keeper, cream tunic, leaf-green sleeves, a basket of dull eggs, one egg with a soft green glow. No wings. |
| `orla_dunn` | Orla Dunn | Verdant portal | Quest 10 | Tall keeper, dark green coat, a plain walking staff the color of ironbark, no glow. The portal behind them is the live green arch. |
| `sable_ilen` | Sable Ilen | Plaza, during quest 8 | No lines. Walks past. | Long pale coat, one gold shard circling the shoulders, strong gold glow. No stats. |

## Props

| id | name | where | visual note |
|---|---|---|---|
| `clearing_waystone` | Clearing Waystone | Tutorial clearing | Short gray pillar, one dull amber crystal on top, soft pulse when the shard is set down. |
| `gnarls_sprout` | Gnarl's Sprout | Antechamber | Waist-high green shoot, two vine arms, amber eyes, soft amber glow. It folds into the ground when it falls. |
| `heartglow_pin` | Heartglow Pin | Quest 10 reward | Small round pin, amber glass, soft pulse. Common cosmetic. No stats. |

## The Sky Cracks

`sky_crack`. Cold open. Skippable, same as the 10 second pan.

| step | objective |
|---|---|
| 1 | Play the crack, or skip it. |
| 2 | Land in the Verdant clearing. |

| gold | shard keys | items |
|---|---|---|
| 20 | 0 | — |

| when | speaker | line |
|---|---|---|
| Offer | Lumen Heart | The Heart shattered. Its shards chose you. |
| Hand-in | Holt Vetch | You landed. The wilds are still standing. |

## Five Pedestals

`five_pedestals`. The five live classes. Free swap stays at the Forge later.

| step | objective |
|---|---|
| 1 | Stand at a pedestal. The preview plays that class's first skill. |
| 2 | Choose Warden, Tidecaller, Forgeborn, Frostblade, or Voidcaster. |

| gold | shard keys | items |
|---|---|---|
| 20 | 0 | The class. No item. |

| when | speaker | line |
|---|---|---|
| Offer | Lumen Heart | Five pedestals. Pick the one that fits your hands. |
| Hand-in | Lumen Heart | You can switch anytime at the Forge. |

## Third Hit

`third_hit`. Three sapling grunts. They are tutorial targets, not a field spawn.

| step | objective |
|---|---|
| 1 | Defeat 3 sapling grunts. The third hit on each one launches it. |
| 2 | Use skill 1 once. The button glows if the player waits. |

| gold | shard keys | items |
|---|---|---|
| 40 | 0 | — |

| when | speaker | line |
|---|---|---|
| Offer | Holt Vetch | Saplings break on the third hit. |
| Hand-in | Holt Vetch | Good. The third hit sends them flying. |

Sapling grunt visual: small green shoot, two stubby arms, no eyes that glow, a leaf burst when it pops. No gore.

## A Red Mark

`red_mark`. One Thorn Sprite, using the charger role in `Rootvault.ROLES`.

| step | objective |
|---|---|
| 1 | Dodge the red telegraph once. A perfect dodge may show the praise pop. It is not required. |

| gold | shard keys | items |
|---|---|---|
| 40 | 0 | — |

| when | speaker | line |
|---|---|---|
| Offer | Holt Vetch | A red mark means move. |
| Hand-in | Holt Vetch | You moved. That is the whole lesson. |

## Carry the Shard

`clearing_waystone`. One reel. Guaranteed Rare or better. Pity counts. Weights stay.

| step | objective |
|---|---|
| 1 | Pick up the glowing shard. |
| 2 | Carry it to the Clearing Waystone and finish one reel roll. |

| gold | shard keys | items |
|---|---|---|
| 40 | 0 | One Verdant armory result, Rare or better. |

| when | speaker | line |
|---|---|---|
| Offer | Holt Vetch | Carry the shard to the waystone. |
| Hand-in | Holt Vetch | Socket it. Your swings change color. |

The hand-in is the lesson line. The rolled item is the reward. Socket count on that roll stays whatever the item already has.

## Two Doors

`antechamber`. Rootvault Antechamber. Two short rooms, then one door choice. This is not a `Dungeons` room id.

| step | objective |
|---|---|
| 1 | Clear both short rooms. |
| 2 | Pick Treasure or Elite. Either door completes the step. Both are safe. |
| 3 | Defeat Gnarl's Sprout. Red telegraph first, then one blue interrupt, each shown alone. |

| gold | shard keys | items |
|---|---|---|
| 40 | 0 | 3 Healing Tonics. 1 Gladecloth Vest. |

| when | speaker | line |
|---|---|---|
| Offer | Holt Vetch | Two doors. Look, then choose. |
| Hand-in | Holt Vetch | The sprout is down. Haven is next. |

Gladecloth Vest is the Uncommon chest piece in `docs/content/armor_batch1.md`. Bound. No set bonus. The tonics are `healing_tonic`.

## What Follows

`what_follows`. The chest in the antechamber. The egg hatches now.

| step | objective |
|---|---|
| 1 | Open the chest. The reveal plays. |
| 2 | The egg hatches into Mossback Turtle. It follows the player. |

| gold | shard keys | items |
|---|---|---|
| 30 | 0 | The class weapon. 1 Mossback Turtle. 1 Uncommon chest, unopened. |

| when | speaker | line |
|---|---|---|
| Offer | Holt Vetch | Open the chest. Something wants to follow. |
| Hand-in | Holt Vetch | It hatched. Keep it close. |

Choice: the turtle is fixed. `Pets.hatch` can roll any of the eight species, including an Epic. This egg does not roll, and it does not spend `Pets.EGG_COST` (50). Mossback Turtle is the live Uncommon Guardian.

The Rare chest from `Onboarding.starter` is this open chest. Do not also add a Rare chest to the bag. The Uncommon chest in that function is the same one chest: the played path puts it in the bag here, unopened, and the skip path already has it. Do not give a second one. Suggested.

## Haven Remembers

`haven_plaza`. Arrival. The camera names the Forge, the Armory, the Verdant portal, and the Guild Hall. The design doc calls the Armory the Roll Shrine. The live name is Armory.

| step | objective |
|---|---|
| 1 | Arrive on the plaza. Spawn is south of the crystal. |
| 2 | The flyover plays once, or the player skips it. |
| 3 | Claim daily login once. |

| gold | shard keys | items |
|---|---|---|
| 20 | 40 | Login unlock. The claim pays the live Common chest and 5 keys. |

| when | speaker | line |
|---|---|---|
| Offer | Lumen Heart | Haven. The Forge remembers what you carry. |
| Flyover | Yarrow | It already follows you. The garden is open. |
| Passer | Sable Ilen | No line. Gold glow, then they are gone. |
| Hand-in | Nessa Pike | The plaza is yours. The big arches stay shut. |

Sable Ilen is a person walking past. This is not the Patron aura.

Skip path: do not pay this row's 20 gold or 40 keys. `Onboarding.starter` already paid them. The live login claim is still once, on both paths.

## The Forge Remembers

`forge_remembers`. One free craft. Proposed recipe id `tutorial_moss_band`. It is not in `Recipes.luau`.

| step | objective |
|---|---|
| 1 | Talk to Nessa Pike at the Forge. |
| 2 | Craft once. Suggested cost: Verdant Wood 2, Living Vine 2, Spore Cap 1, gold 0. |
| 3 | If the bag is short, fill up to that cost and stop. |

| gold | shard keys | items |
|---|---|---|
| 0 | 4 | 1 Moss Band, bound. |

| when | speaker | line |
|---|---|---|
| Offer | Nessa Pike | Bring what you gathered. The first ring is free. |
| Hand-in | Nessa Pike | It fits. The crawl will notice. |

Moss Band is the Uncommon ring in `docs/content/accessories.md`. Suggested crit chance stays +2%. The craft does not charge a gold fee. Later crafts use the live recipes and the live fees.

## Down the Roots

`down_the_roots`. Rootvault Normal. Rooms, in live order: Choked Thicket, Spore Canopy, Brute Den, Gnarl's Heart. Boss: Grandmother Gnarl.

| step | objective |
|---|---|
| 1 | Talk to Orla Dunn at the Verdant portal. |
| 2 | Enter `rootvault` on difficulty `normal`. |
| 3 | Clear the crawl. Grandmother Gnarl's defeat completes it. |
| 4 | Hand in to Orla Dunn. |

Hard, Nightmare, Waves, Heartwood, and a practice run do not complete the step. A wipe that still ends in a clear does. The quest is personal. A party may come.

| gold | shard keys | items |
|---|---|---|
| 0 | 6 | 1 Heartglow Pin. |

| when | speaker | line |
|---|---|---|
| Offer | Orla Dunn | Rootvault Normal. Come back when she falls. |
| Hand-in | Orla Dunn | She fell. The Heart is still cracked. |

## After the chapter

These stay on the goal tracker. They are not quests in this file.

| tracker line | why it waits |
|---|---|
| Reach class level 5. | `Classes.TALENT_LEVEL` is 5. The talent pick is the next lesson. |
| Roll 10 shards. | The chapter already used the one guaranteed roll. |
| Read the Guild Hall sign. | The stall is not a join button yet. |
| Training Grove, if you want it. | Optional. A small cosmetic later. Side quests can take it. |

Flags: Holt Vetch, Nessa Pike, Yarrow, Orla Dunn, and Sable Ilen are new. The Lumen Heart, Haven, Rootvault, Grandmother Gnarl, Gnarl's Sprout, the Armory, and the five classes keep their live names. Clearing Waystone is not the Bent Waystone in Far Glade. The Antechamber is not Choked Thicket. Gladecloth Vest is not Woven Bark Vest or Grovewarden. Moss Band is not `verdant_ring`. Beastbone Hammer stays Uncommon. Heartglow Pin is not the Lumen Heart and not a Patron aura. No other game's quest, character, or signature mechanic is used.
