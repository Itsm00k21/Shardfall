# Achievements

G-016. Fifty achievements across combat, rolls, pets, raids, social, and collection, for a later achievement draft.

Unlocks use live systems. Every gold, key, and count below is suggested. Nothing here changes `RollMath.luau`, `RarityConfig.luau`, `ChestConfig.luau`, `Raids.luau`, or drop odds. Rewards are gold, Shard Keys, titles, and bound cosmetics. No stat gear, no luck, no drop chance, no Raid Marks, no Robux item.

| category | count |
|---|---|
| Combat | 10 |
| Rolls | 8 |
| Pets | 8 |
| Raids | 8 |
| Social | 8 |
| Collection | 8 |
| Total | 50 |

| rule | suggested |
|---|---|
| Repeat | Once each. |
| Stack | Two rows may complete on the same clear. Each pays once. |
| Practice | Heartwood Practice Grove clears do not count. `RaidPractice.rewards` is empty. |
| Secret | Secret stays on the odds ladder. No row requires it. |
| Pity | Epic pity stays 100. Legendary pity stays 1000. Chest pity is a different counter and is not used here. |
| Titles | Three new titles. Heartwood Student stays the Marks shop title at 200 marks. |
| Bound | Every cosmetic in this file is bound. No stats. |

## Pay

| category | gold | shard keys | titles | cosmetics |
|---|---|---|---|---|
| Combat | 200 | 4 | 1 | 1 |
| Rolls | 85 | 20 | 1 | 1 |
| Pets | 130 | 4 | 0 | 1 |
| Raids | 160 | 6 | 0 | 1 |
| Social | 95 | 0 | 0 | 2 |
| Collection | 105 | 0 | 1 | 1 |
| Total | 775 | 34 | 3 | 7 |

An Uncommon chest in the key shop is 40 keys. This list pays 34.

## Already paid elsewhere

| row | also paid by | this row adds |
|---|---|---|
| `vault_clear` | Chapter quest 10 (Heartglow Pin, 6 keys) | 15 gold |
| `ten_reels` | The chapter tracker has no payout | 10 gold |
| `it_follows` | Chapter quest 7 (Mossback Turtle) | 10 gold |
| `seven_mornings` | Each login claim pays the live chest | 15 gold, once, at claim 7 |
| `already_student` | Marks shop sells the title for 200 marks | 10 gold, and no second title |

## Combat

Rootvault difficulties are the live rows in `Rootvault.DIFFICULTIES`: Normal level 1, Hard level 10, Nightmare level 15.

| id | name | unlock | suggested reward | visual note |
|---|---|---|---|---|
| `first_spark` | First Spark | Land 1 attack. | 10 gold | Icon: one dull iron spark. No glow. |
| `ten_launches` | Ten Launches | Launch 10 foes with a third hit. Tutorial saplings count. | 20 gold | Icon: a small green leaf burst. No glow. |
| `sidestep` | Sidestep | Perfect-dodge 25 red telegraphs. | Title Sidestep | Name text in plain warm gray. Common tint. No icon glow. |
| `hundred_skills` | Hundred Skills | Use class skills 100 times. | 25 gold | Icon: a small round pebble the size of a skill button. No glow. |
| `vault_clear` | Vault Clear | Clear Rootvault on Normal once. | 15 gold | Icon: a small gray root arch. No glow. |
| `hard_roots` | Hard Roots | Clear Rootvault on Hard once. | 30 gold | Icon: a darker root arch, soft green edge. |
| `night_crawl` | Night Crawl | Clear Rootvault on Nightmare once. | 40 gold, 4 keys | Icon: a dark green arch with one steady amber crack. Not the Heart. |
| `ten_falls` | Ten Falls | Defeat Grandmother Gnarl 10 times on any Rootvault difficulty. | 40 gold | Icon: a small green shoot folded down, soft amber eye glint. No gore. |
| `five_hands` | Five Hands | Land one hit as each of the five classes. | Five-Thread | Five dull threads: moss green, tide blue, forge orange, ice pale, void violet. No glow. |
| `red_then_blue` | Red Then Blue | In one Rootvault run, dodge one red telegraph and land one blue interrupt. | 20 gold | Icon: a short red dash beside a small blue tick. No glow. |

## Rolls

Armory rolls. Epic pity is `RarityConfig.EPIC_PITY` (100). Legendary pity is `RarityConfig.LEGENDARY_PITY` (1000). Every 10th roll is x2 luck (`RarityConfig.BONUS_EVERY`), not a second pull.

| id | name | unlock | suggested reward | visual note |
|---|---|---|---|---|
| `first_reel` | First Reel | Finish 1 Armory roll. The tutorial reel counts. | 5 gold | Icon: a small wooden reel. No glow. |
| `ten_reels` | Ten Reels | Finish 10 Armory rolls. | 10 gold | Icon: ten dull ticks in a row. No glow. |
| `double_tenth` | Double Tenth | Finish one roll while the live x2 luck bonus is ready. | 10 gold | Icon: a wooden reel with a small x2, soft amber glint. |
| `a_rare` | A Rare | Roll a Rare or better once. | 15 gold | Icon: one shard chip in the live Rare color, steady glow. |
| `pity_line` | Pity Line | Arm the Epic pity guarantee once (the next roll is the guarantee). | 20 gold | Icon: a counter showing 100, bright, the live Epic color. |
| `one_legend` | One Legend | Roll a Legendary or better once. | 25 gold, title Reel Light | Name text in soft moss green. Uncommon tint. Icon: one bright shard chip. |
| `six_rungs` | Six Rungs | Roll each of Common, Uncommon, Rare, Epic, Legendary, and Mythic at least once. | Six-Chip Cord | Six small chips in rarity order on a cord. The Mythic chip is bright. No stats. |
| `hundred_reels` | Hundred Reels | Finish 100 Armory rolls. | 20 keys | Icon: a full wooden reel, steady amber hub. |

## Pets

The live eight are `Pets.SPECIES`. Egg cost stays 50. Affinity cap and Bond cap stay 5. Combo cap stays 3. Evolution steps exist for Ember Fox, Mossback Turtle, and Root Mole (`PetEvolution.STEPS`), at levels 25 and 50.

| id | name | unlock | suggested reward | visual note |
|---|---|---|---|---|
| `it_follows` | It Follows | Hatch 1 pet. The tutorial turtle counts. | 10 gold | Icon: a dull egg with one soft green crack. |
| `garden_bowl` | Garden Bowl | Visit the Pet Garden with a pet following. | 10 gold | Icon: a leaf-green bowl. No glow. |
| `five_stars` | Five Stars | Reach Affinity 5 on one pet. | 25 gold | Icon: five soft green dots. |
| `five_bonds` | Five Bonds | Reach Bond 5 on one pet. Affinity does not count for this row. | 25 gold | Icon: five dull cord knots. No glow. |
| `eight_companions` | Eight Companions | Hatch all 8 live species. Docs-only pets are not required. | 30 gold, 4 keys | Icon: eight tiny silhouettes in a ring, soft green glow. |
| `one_combo` | One Combo | Trigger one live combo in `Pets.COMBOS`. | 20 gold | Icon: two small silhouettes and one dull spark. |
| `kept` | Kept | Mark one pet favorite. | 10 gold | Icon: a small cream ribbon. No glow. |
| `first_change` | First Change | Complete one `PetEvolution.evolve` on Ember Fox, Mossback Turtle, or Root Mole. | Shed Scale | A small dull green scale on a cream cord. No glow. |

## Raids

The Heartwood. Live difficulties are Story and Normal, both level 15 (`Raids.DIFFICULTIES`). Wings are Thornwarden Twins, Mother Sapwell, Galecrown, and Grandmother Gnarl Awakened. A full party is 8: 1 tank, 1 healer, 6 DPS. Marks cap stays 600. The shop title stays Heartwood Student at 200 marks.

| id | name | unlock | suggested reward | visual note |
|---|---|---|---|---|
| `one_wing` | One Wing | Clear one wing on Story. | 20 gold | Icon: one small amber leaf, soft glow. |
| `wing_normal` | Wing, Normal | Clear one wing on Normal. | 30 gold | Icon: one amber leaf, steady glow. |
| `both_depths` | Both Depths | Clear the same wing id on Story and on Normal. | 25 gold | Icon: two leaves, one soft and one steady. |
| `all_four` | All Four | Clear all four wing ids on any live difficulty. | 40 gold, 6 keys | Icon: four amber leaves on a ring, steady glow. |
| `eight_seats` | Eight Seats | Clear one wing in a party of 8 with 1 tank, 1 healer, and 6 DPS. | Seat Ribbon | A brown ribbon with eight dull stitches. No glow. |
| `already_student` | Already a Student | Own the shop title Heartwood Student. | 10 gold | Icon: the words Heartwood Student in the live title color. No new title. |
| `two_hundred_marks` | Two Hundred Marks | Earn 200 Raid Marks across clears. Spent marks still count. | 20 gold | Icon: a small brown pouch, dull amber stitch, no glow. |
| `clean_recap` | Clean Recap | Finish a wing whose recap row for you has no `afk` and no `kick` removal. | 15 gold | Icon: a small closed card, cream paper, no glow. |

## Social

Direct trade tax stays 10% (`Trading.GOLD_TAX`). The Standard trade level stays 15. The Market Board listing fee stays 5%. The daily shop stall stays shut. Guild join stays off.

| id | name | unlock | suggested reward | visual note |
|---|---|---|---|---|
| `fair_trade` | Fair Trade | Finish one direct trade. | 15 gold | Icon: two small hands and a coin. No glow. |
| `notch_tax` | Notch | Pay 1,000 gold in trade tax across trades. | Notch Charm | A dull iron coin with one notch, hung on hemp. No glow. Not currency. |
| `one_listing` | One Listing | Post one Market Board listing. | 10 gold | Icon: a small wicker tag. No glow. |
| `one_purchase` | One Purchase | Buy one Market Board listing from another player. | 10 gold | Icon: a small open crate, straw-yellow band. No glow. |
| `with_a_friend` | With a Friend | Clear Rootvault Normal in a party with a Roblox friend. | 20 gold | Icon: two small hoods, soft green glint. |
| `four_at_the_door` | Four at the Door | Enter Rootvault in a party of 4. | 15 gold | Icon: four short pine marks. No glow. |
| `show_the_roots` | Show the Roots | Clear Rootvault Normal while a party member is under level 10. | 25 gold | Icon: a tall hood beside a short hood. No glow. |
| `plaza_eight` | Plaza Eight | Stand on the Haven plaza in a party of 8. No raid required. | Plaza Ring | Eight dull gray stones in a circle on a cord. No glow. |

## Collection

Weapon types are the six in `ItemBases.luau`: sword, greatsword, dagger, hammer, staff, bow. Relic sets are the five Verdant sets, 4 pieces each. `RelicSets.DIFFICULTY` says Hard, and `Raids.DIFFICULTIES` lists Story and Normal. This row counts pieces you own. It does not add a Hard raid.

| id | name | unlock | suggested reward | visual note |
|---|---|---|---|---|
| `six_types` | Six Types | Own one weapon of each of the six types at the same time. | 20 gold | Icon: six tiny weapon silhouettes in a row. No glow. |
| `full_set` | Full Set | Own all 4 pieces of one Verdant relic set. Equipping is not required. | Set Thread | A dull brown thread with four knots. No glow. No set bonus. |
| `thornbound_made` | Thornbound Made | Craft Thornbound Blade once at the Forge. | 15 gold | Icon: a small thornbound sword, dull green, no glow. |
| `one_tonic` | One Tonic | Craft one Healing Tonic. | 10 gold | Icon: a small green vial, soft glass glint. |
| `seed_once` | Seed Once | Hold at least 1 Gnarl's Seed. The row does not grant one. | 20 gold | Icon: a small dark green seed, soft glow. |
| `twenty_bases` | Twenty Bases | Own 20 distinct item-base ids at the same time. | 25 gold | Icon: a short stack of dull cards. No glow. |
| `seven_mornings` | Seven Mornings | Claim the daily login chest 7 times. | 15 gold | Icon: seven small sun ticks, soft amber. |
| `mythic_hand` | Mythic Hand | Own one Mythic item. | Title Mythic Hand | Name text with a thin prism edge. Mythic tint. Readable on a nameplate. |

## Reserved for the title list

G-017 should leave these display names alone. Heartwood Student is already live.

| id | display name | tint | source |
|---|---|---|---|
| `sidestep` | Sidestep | Common, plain warm gray | `sidestep` |
| `reel_light` | Reel Light | Uncommon, soft moss green | `one_legend` |
| `mythic_hand` | Mythic Hand | Mythic, thin prism edge | `mythic_hand` |
| `heartwood_student` | Heartwood Student | live shop color | `Raids.SHOP` title, 200 marks |

## Cosmetic notes

| id | name | from | visual note |
|---|---|---|---|
| `five_thread` | Five-Thread | `five_hands` | Five dull threads: moss green, tide blue, forge orange, ice pale, void violet. No glow. |
| `six_chip_cord` | Six-Chip Cord | `six_rungs` | Six rarity chips on a cord, Mythic chip bright. |
| `shed_scale` | Shed Scale | `first_change` | Small dull green scale, cream cord, no glow. |
| `seat_ribbon` | Seat Ribbon | `eight_seats` | Brown ribbon, eight dull stitches, no glow. |
| `notch_charm` | Notch Charm | `notch_tax` | Dull iron coin with one notch, hemp cord, no glow. |
| `plaza_ring` | Plaza Ring | `plaza_eight` | Eight dull gray stones in a circle, no glow. |
| `set_thread` | Set Thread | `full_set` | Dull brown thread, four knots, no glow. |

Flags: Five-Thread, Six-Chip Cord, Shed Scale, Seat Ribbon, Notch Charm, Plaza Ring, and Set Thread are new. They are not Grove Ribbon, Nest Thread, Mudstep Ribbon, Heartglow Pin, or Mire Lamp. Sidestep, Reel Light, and Mythic Hand are new titles. Heartwood Student is the live shop title. Secret is on the ladder only. Relic Hard and the raid difficulty list disagree; Full Set does not paper over that. No other game's achievement, title, or signature mechanic is used.
