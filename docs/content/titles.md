# Titles

G-017. Forty nameplate titles with an unlock and a rarity tint, for a later title draft.

Each tint is the live color in `Rarities` (`src/ReplicatedStorage/Shared/Rarities.luau`). Counters are suggested. A title is nameplate text only. No stat, no luck, no drop chance, no Raid Marks, no Robux item. Nothing here changes `Raids.luau`, `RarityConfig.luau`, or `Loops.luau`.

Choice: these 40 are new. Reserved names stay on their old sources. `Boardwalker` stays the live free-track title at tier 30 (`Loops.FREE_TRACK`). `Legend Chip` asks for 3 Legendary-or-better rolls so `Reel Light` stays the first one. `Capped Pouch` fills the weekly earn cap (`raidMarksEarned` reaches 600). It is not the lifetime 200 in `two_hundred_marks`.

| rarity | count | hex | letters |
|---|---|---|---|
| Common | 8 | `#A8A8B0` | Flat gray. No glow. |
| Uncommon | 8 | `#40BA62` | Moss green. Soft glow. |
| Rare | 8 | `#488EFF` | Steady blue. |
| Epic | 6 | `#BA60F0` | Bright purple. Steady glow. |
| Legendary | 6 | `#FFC440` | Bright gold. Soft gold glow. |
| Mythic | 4 | `#E6404E` | Bright red edge. Readable. Stronger glow. |
| Total | 40 | | |

## Titles

| id | name | rarity | unlock (suggested) | visual note |
|---|---|---|---|---|
| `soft_step` | Soft Step | Common | Perfect-dodge 10 red telegraphs. Sidestep stays the title for 25. | Flat `#A8A8B0` letters. No glow. |
| `room_one` | Room One | Common | Clear 1 Rootvault room. | Flat `#A8A8B0` letters. No glow. |
| `tenth_launch` | Tenth Launch | Common | Land 10 third-hit launches. Tutorial saplings count. | Flat `#A8A8B0` letters. No glow. |
| `one_pull` | One Pull | Common | Finish 1 Armory crack. The tutorial crack counts. | Flat `#A8A8B0` letters. No glow. |
| `first_hatch` | First Hatch | Common | Hatch 1 pet. | Flat `#A8A8B0` letters. No glow. |
| `one_trade` | One Trade | Common | Finish 1 direct trade. | Flat `#A8A8B0` letters. No glow. |
| `tonic_made` | Tonic Made | Common | Craft 1 Healing Tonic. | Flat `#A8A8B0` letters. No glow. |
| `listed_once` | Listed Once | Common | Post 1 Market Board listing. | Flat `#A8A8B0` letters. No glow. |
| `vault_walker` | Vault Walker | Uncommon | Clear Rootvault on Normal once. | `#40BA62` letters. Soft moss glow. |
| `skill_hand` | Skill Hand | Uncommon | Use class skills 50 times. | `#40BA62` letters. Soft moss glow. |
| `tenth_luck` | Tenth Luck | Uncommon | Finish one crack while the live x2 luck bonus is the crack being rolled. | `#40BA62` letters. Soft moss glow. |
| `story_leaf` | Story Leaf | Uncommon | Clear one Heartwood wing on Story. | `#40BA62` letters. Soft moss glow. |
| `door_four` | Door Four | Uncommon | Enter Rootvault in a party of 4. | `#40BA62` letters. Soft moss glow. |
| `morning_seven` | Morning Seven | Uncommon | Claim the daily login chest 7 times. | `#40BA62` letters. Soft moss glow. |
| `combo_spark` | Combo Spark | Uncommon | Trigger one live combo in `Pets.COMBOS`. | `#40BA62` letters. Soft moss glow. |
| `thorn_made` | Thorn Made | Uncommon | Craft Thornbound Blade once. | `#40BA62` letters. Soft moss glow. |
| `deep_vault` | Deep Vault | Rare | Clear Rootvault on Hard once. | `#488EFF` letters. Steady blue. |
| `five_classes` | Five Classes | Rare | Land one hit as each of the five classes. | `#488EFF` letters. Steady blue. |
| `rare_chip` | Rare Chip | Rare | Roll a Rare or better once. | `#488EFF` letters. Steady blue. One small chip glint. |
| `hundred_pulls` | Hundred Pulls | Rare | Finish 100 Armory cracks. | `#488EFF` letters. Steady blue. |
| `full_stars` | Full Stars | Rare | Reach Affinity 5 on one pet. | `#488EFF` letters. Steady blue. Five soft dots. |
| `full_bond` | Full Bond | Rare | Reach Bond 5 on one pet. Affinity does not count. | `#488EFF` letters. Steady blue. |
| `normal_leaf` | Normal Leaf | Rare | Clear one Heartwood wing on Normal. | `#488EFF` letters. Steady blue. |
| `friend_clear` | Friend Clear | Rare | Clear Rootvault Normal in a party with a Roblox friend. | `#488EFF` letters. Steady blue. |
| `night_root` | Night Root | Epic | Clear Rootvault on Nightmare once. | `#BA60F0` letters. Bright purple. Steady glow. |
| `pity_ready` | Pity Ready | Epic | Arm the Epic pity guarantee (the next crack is at least Epic). | `#BA60F0` letters. Bright purple. Steady glow. |
| `epic_seen` | Epic Seen | Epic | Roll an Epic or better once. | `#BA60F0` letters. Bright purple. Steady glow. |
| `all_eight` | All Eight | Epic | Hatch all 8 live species in `Pets.SPECIES`. | `#BA60F0` letters. Bright purple. Steady glow. |
| `four_wings` | Four Wings | Epic | Clear all four Heartwood wing ids on any live difficulty. | `#BA60F0` letters. Bright purple. Steady glow. |
| `card_stack` | Card Stack | Epic | Own 20 distinct item-base ids at the same time. | `#BA60F0` letters. Bright purple. Steady glow. |
| `legend_chip` | Legend Chip | Legendary | Roll a Legendary or better 3 times. Reel Light stays the first. | `#FFC440` letters. Bright gold. Soft gold glow. |
| `gold_ladder` | Gold Ladder | Legendary | Roll each of Common, Uncommon, Rare, Epic, and Legendary at least once. | `#FFC440` letters. Bright gold. Soft gold glow. |
| `two_depths` | Two Depths | Legendary | Clear the same Heartwood wing id on Story and on Normal. | `#FFC440` letters. Bright gold. Soft gold glow. |
| `long_count` | Long Count | Legendary | Arm the Legendary pity guarantee (the next crack is at least Legendary). | `#FFC440` letters. Bright gold. Soft gold glow. |
| `full_garden` | Full Garden | Legendary | Hatch all 8 live species and reach Affinity 5 on one of them. | `#FFC440` letters. Bright gold. Soft gold glow. |
| `capped_pouch` | Capped Pouch | Legendary | Fill the weekly Raid Mark cap once (`raidMarksEarned` reaches 600). A later week reset does not remove the title. | `#FFC440` letters. Bright gold. Soft gold glow. A small pouch shape in the glow, no coins. |
| `awakened_name` | Awakened Name | Mythic | Clear Grandmother Gnarl Awakened on Normal. | `#E6404E` letters. Thin bright edge. Soft pulse. Readable. |
| `mythic_reel` | Mythic Reel | Mythic | Roll a Mythic once. Mythic Hand stays the title for owning a Mythic item. | `#E6404E` letters. Thin bright edge. One reel-shaped glint. Readable. |
| `nightglass` | Nightglass | Mythic | Clear Rootvault Nightmare and one Heartwood wing on Normal. | `#E6404E` letters. Thin glass edge. Steady glow. Readable. |
| `prism_name` | Prism Name | Mythic | Own one Mythic item and finish 1000 Armory cracks. | `#E6404E` letters. Thin prism edge. Stronger glow. Readable on a nameplate. |

## Reserved

Leave these display names alone.

| id | display name | why |
|---|---|---|
| `sidestep` | Sidestep | Achievement title. Common, plain warm gray. 25 perfect dodges. |
| `reel_light` | Reel Light | Achievement title. Uncommon, soft moss green. First Legendary or better. |
| `mythic_hand` | Mythic Hand | Achievement title. Mythic, thin prism edge. Own one Mythic item. |
| `heartwood_student` | Heartwood Student | Live shop title. `Raids.SHOP` title, 200 marks. |
| `boardwalker` | Boardwalker | Live free-track title. `Loops.FREE_TRACK` tier 30. |

## Rules that the unlocks use

| rule | live source |
|---|---|
| Red telegraph is a dodge. | `CombatFeel` red verb `dodge`. |
| Epic pity is 100. Legendary pity is 1000. | `RarityConfig.EPIC_PITY`, `RarityConfig.LEGENDARY_PITY`. |
| Every 10th crack is x2 luck, still one crack. | `RarityConfig.BONUS_EVERY`. |
| Rootvault Normal is level 1, Hard is 10, Nightmare is 15. | `Rootvault.DIFFICULTIES`. |
| Heartwood Story and Normal are both level 15. | `Raids.DIFFICULTIES`. |
| Weekly Raid Mark room is 600. Story pays 25, Normal pays 40. | `Raids.MARK_CAP`, `Raids.applyClear`. |
| Eight live pets. Affinity cap 5. Bond cap 5. | `Pets.SPECIES`, `Pets.AFFINITY_MAX`, `Pets.BOND_MAX`. |
| Practice Grove pays no loot. | `RaidPractice.rewards` returns empty loot. |

Flags: Tenth Launch is not the chapter quest Third Hit. Deep Vault is not the achievement Hard Roots and not the words Hard Rootvault. Nightglass is not Nightmare Bloom. Prism Name is not Mythic Hand and not Prism Bow. Capped Pouch is not the 200-mark shop title and not the lifetime counter for Two Hundred Marks. No other game's title is used.
