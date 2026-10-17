# Side quests

G-014. Twenty one-time side quests for Haven and Far Glade, for a later quest draft.

Haven is the hub in `Haven.luau`. Far Glade is the first field in `docs/content/zones.md`, levels 16–20, inside the beta cap. Chapter 1 in `docs/content/quests_ch1.md` keeps the Verdant clearing, the Antechamber, and the first Rootvault Normal clear. Every number below is suggested. Nothing here changes `Onboarding.luau`, `Recipes.luau`, `Dungeons.luau`, or `Raids.luau`.

Choice: the first zone is Far Glade. Haven quests open after chapter quest `haven_plaza`. Far Glade quests open at suggested level 16. They are not a chain. A party may come. Only the quest holder gets the kill credit and the reward.

| rule | suggested |
|---|---|
| Count | 10 Haven, 10 Far Glade. |
| Order | Any order inside the zone. |
| Repeat | Once each. |
| Haven gate | Chapter quest 8 is done. |
| Far Glade gate | Suggested level 16. Walking past the Heartwood gate into the field. The raid queue stays a raid. |
| Fill | If a turn-in asks for a material and the bag is short, fill up to that cost and stop. |
| Bound | Grove Ribbon, Nest Thread, and Mudstep Ribbon are bound cosmetics. No stats. |
| Keys | Shard Keys (`shardKeys`). No Prism Tokens. No shard tokens from the crawl. |
| Boss pay | Mireoak still pays the daily Heartwood and the first-kill Mire Lamp. This file does not add them. |
| Seed | No quest grants Gnarl's Seed. |
| Power for sale | None. No Robux item. |

## Cast

Givers are the eight Haven voices in `docs/content/npc_dialogue_haven.md`. The quest line plays on offer and on hand-in. Their generic stall hand-in plays only when no quest line is set.

| id | name | Haven place |
|---|---|---|
| `holt_vetch` | Holt Vetch | Plaza |
| `nessa_pike` | Nessa Pike | Forge |
| `yarrow` | Yarrow | Pet Garden |
| `orla_dunn` | Orla Dunn | Verdant portal |
| `pell_rowan` | Pell Rowan | Armory |
| `cress_wicker` | Cress Wicker | Market |
| `tamsin_burl` | Tamsin Burl | Guild Hall |
| `ivo_quill` | Ivo Quill | Observatory |

## Index

| id | title | giver | where | suggested level |
|---|---|---|---|---|
| `closed_stall` | Closed Stall | Cress Wicker | Market | 5 |
| `plaza_sweep` | Plaza Sweep | Holt Vetch | Plaza | 5 |
| `grove_course` | Training Grove | Holt Vetch | Plaza grove | 5 |
| `dull_eggs` | Dull Eggs | Yarrow | Pet Garden | 6 |
| `apron_errand` | Soot and Apron | Nessa Pike | Forge | 6 |
| `arch_count` | Five Arches | Orla Dunn | South portals | 7 |
| `reel_colors` | Six Colors | Pell Rowan | Armory | 7 |
| `hall_sign` | The Hall Sign | Tamsin Burl | Guild Hall | 8 |
| `combo_window` | One Window | Ivo Quill | Observatory | 8 |
| `coal_glove` | Coal Glove | Nessa Pike | Forge | 9 |
| `gate_post` | The Far Post | Holt Vetch | Heartwood gate, field side | 16 |
| `bent_stone` | The Bent Stone | Holt Vetch | Bent Waystone | 16 |
| `thorn_lintel` | Thorn Lintel | Orla Dunn | Thorn Arch | 16 |
| `mud_lane` | Mud Lane | Orla Dunn | Far Glade path | 17 |
| `hedge_quiet` | Quiet Hedge | Yarrow | Far Glade hedges | 17 |
| `pod_sack` | Pod Sack | Cress Wicker | Far Glade | 17 |
| `sap_lamps` | Sap Lamps | Ivo Quill | Far Glade | 18 |
| `mite_basket` | Mite Basket | Yarrow | Far Glade | 18 |
| `bowl_rim` | Bowl Rim | Pell Rowan | Mireoak's Bowl | 18 |
| `oak_walk` | The Walking Oak | Nessa Pike | Mireoak's Bowl | 19 |

## Pay

| zone | gold | shard keys | also |
|---|---|---|---|
| Haven | 167 | 2 | Grove Ribbon, Nest Thread |
| Far Glade | 275 | 8 | Mudstep Ribbon, Verdant Bark 4, Living Vine 3, Spore Cap 2 |
| Total | 442 | 10 | Three bound cosmetics |

An Uncommon chest in the key shop is 40 keys. These twenty quests together pay 10.

## Haven

| id | objective | gold | keys | also |
|---|---|---|---|---|
| `closed_stall` | Read the Market stall. Sort 3 Stall Crates beside it. Buy nothing. | 15 | 0 | — |
| `plaza_sweep` | Pick up 5 Amber Chips around the Lumen Heart. They are props. | 12 | 0 | — |
| `grove_course` | In the Training Grove: hit the dummy once, dodge one red mark, land one blue interrupt. | 15 | 0 | 1 Grove Ribbon |
| `dull_eggs` | Bring the following pet to Yarrow. The tutorial Mossback Turtle counts. Hatch nothing new. | 15 | 0 | 1 Nest Thread |
| `apron_errand` | Turn in Verdant Wood 4. Fill up to 4 if the bag is short. This is not the daily Forge commission and not Moss Band. | 25 | 0 | Wood is spent |
| `arch_count` | Visit all five realm arches. Do not enter Rootvault. | 20 | 0 | — |
| `reel_colors` | At the Armory, look at the six rungs from Common through Mythic. Do not roll. | 10 | 2 | — |
| `hall_sign` | Read the Guild Hall sign. Joining stays off. | 15 | 0 | — |
| `combo_window` | Read one Combo Plaque in the Observatory window. No combo bonus is granted. | 20 | 0 | — |
| `coal_glove` | Watch Nessa tap the anvil once. Do not require a gold upgrade. | 20 | 0 | — |

## Far Glade

Enemies and landmarks keep the names in `docs/content/enemies.md`, `docs/content/zones.md`, and `docs/content/bosses.md`.

| id | objective | gold | keys | also |
|---|---|---|---|---|
| `gate_post` | Read the Far Post on the field side of the Heartwood gate. Do not queue the raid. | 20 | 0 | — |
| `bent_stone` | Visit the Bent Waystone. It is the Far Glade stone. | 25 | 2 | — |
| `thorn_lintel` | Walk under the Thorn Arch. No boss. | 20 | 0 | — |
| `mud_lane` | Defeat 6 Mud Tusks. | 30 | 0 | Verdant Bark 4 |
| `hedge_quiet` | Defeat 4 Hedge Lurkers. | 30 | 0 | — |
| `pod_sack` | Defeat 5 Seed Flingers. Turn in 3 Seed Pods. The pods are removed. | 25 | 0 | Living Vine 3 |
| `sap_lamps` | Step out of 3 Sap Glob puddles from Sap Mouth. | 30 | 0 | — |
| `mite_basket` | Scatter 3 Mite Clouds. | 25 | 0 | Spore Cap 2 |
| `bowl_rim` | Stand on the rim of Mireoak's Bowl. A kill is not required. | 30 | 2 | — |
| `oak_walk` | Defeat Mireoak once. The boss table still pays its own loot. | 40 | 4 | 1 Mudstep Ribbon |

## Lines

| id | offer | hand-in |
|---|---|---|
| `closed_stall` | The daily shop is not open yet. The crates still tip. | Straight crates. Nothing was for sale. |
| `plaza_sweep` | Amber chips fell in the night. They are glass, not shards. | Five chips. The Heart keeps its crack. |
| `grove_course` | Dummy, red mark, blue mark. Then you are done. | The grove is clear. Wear the ribbon. |
| `dull_eggs` | Bring the one that follows you. I only want to see it. | It is well. The thread is for the basket. |
| `apron_errand` | Four Verdant Wood. The free ring was yesterday. | Fair trade. The apron stays sooty. |
| `arch_count` | Five arches. Only the green one opens. | You looked. The four stay shut. |
| `reel_colors` | Six colors on the board. Read them. Do not pull. | You can see the ladder. Odds stay put. |
| `hall_sign` | Read the sign. I am not taking names. | You read it. That is the whole ask. |
| `combo_window` | One plaque in the window. The bonus stays asleep. | You looked. The window stays shut. |
| `coal_glove` | Watch the anvil. Keep your gold. | Seen. The glove does the hot work. |
| `gate_post` | The post is on the field side. The raid door is the other one. | You can read the wood. The queue can wait. |
| `bent_stone` | The bent stone is in Far Glade. The clearing stone stays home. | That is the far stone. Leave the shard in your bag. |
| `thorn_lintel` | Walk under the arch. Nothing lives on the lintel. | Through. The thorns are only a gate. |
| `mud_lane` | Six Mud Tusks on the path. They charge in a line. | Path is quieter. Bark for the trouble. |
| `hedge_quiet` | Four lurkers in the hedge. They hop short. | The hedge is quiet. Step easy. |
| `pod_sack` | Five flingers. Bring three pods. They are not a material. | Pods in the basket. Vine for the walk. |
| `sap_lamps` | Three sap puddles. Step out. The lamp is only sap. | Clean boots. The stumps keep their lamps. |
| `mite_basket` | Three mite clouds. Scatter them before they nip. | Basket is clear. A little spore for the garden. |
| `bowl_rim` | Stand on the rim. You do not have to wake the oak. | You saw the bowl. The oak can sleep. |
| `oak_walk` | Mireoak walks. Drop it once, then come back. | It sat down. The lamp from the oak is its own gift. |

## Props and rewards

| id | name | where | visual note |
|---|---|---|---|
| `amber_chip` | Amber Chip | Plaza, around the crystal | Small amber glass chip, soft pulse. No socket, no face. |
| `grove_dummy` | Grove Dummy | Training Grove, south edge of the plaza | Straw figure on a pine post, one moss-green target circle, no face, no glow. |
| `stall_crate` | Stall Crate | Market | Closed wicker crate, straw-yellow band, no glow. |
| `combo_plaque` | Combo Plaque | Observatory window | Small brass plate, two pet silhouettes etched, soft lens glint. It names a live combo. It does not pay one. |
| `far_post` | Far Post | Field side of the Heartwood gate | Short ironbark post, one dull green ribbon, no glow. |
| `seed_pod` | Seed Pod | Dropped by Seed Flingers for `pod_sack` | Brown oval pod, no glow. Removed on hand-in. Not a material row. |
| `grove_ribbon` | Grove Ribbon | `grove_course` | Short moss-green ribbon, one dull amber stitch, no glow. Common cosmetic. |
| `nest_thread` | Nest Thread | `dull_eggs` | Cream thread loop, one leaf-green strand, no glow. Common cosmetic. |
| `mudstep_ribbon` | Mudstep Ribbon | `oak_walk` | Short mud-brown ribbon, one dull amber stitch, no glow. Common cosmetic. |

The Training Grove is the optional corner from `docs/design/shardfall_onboarding.md`. It is not a new `Haven` district. One dummy, one red dodge, one blue interrupt. The ribbon is the cosmetic that note promised.

Flags: Pell Rowan, Cress Wicker, Tamsin Burl, and Ivo Quill are new. Holt Vetch, Nessa Pike, Yarrow, Orla Dunn, and Sable Ilen stay as in chapter 1. Sable still has no lines. The Bent Waystone is the Far Glade landmark. The Clearing Waystone stays the tutorial stone. Grove Ribbon, Nest Thread, and Mudstep Ribbon are not Heartglow Pin, Mire Lamp, Moss Band, or Waycloth. Seed Pod is not Spore Cap and not Gnarl's Seed. The Far Post is not a raid queue. No other game's quest, character, or signature mechanic is used.
