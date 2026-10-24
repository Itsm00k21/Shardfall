# Shardfall Pets v1 (draft, Oct 16 2026)

## Pillars
Pets are companions, not just stat sticks: they fight, react, and have personality. Collecting them is a chase; building around them is a strategy.

## Getting pets
- **Eggs**: realm eggs drop from enemies/bosses/chests (Verdant Egg, Tidal Egg, Ember Egg, Frost Egg, Void Egg). Hatch at the Haven Hatchery (cheap gold) with a crack animation; Open Many supported.
- **Rarity**: Common to Mythic, same colors/odds style as shards; egg tier sets a rarity floor.
- **Wild capture (rare)**: a rare "Shiny" variant of an enemy can appear in a realm; defeat it with a Capture Charm equipped for a chance to tame it.
- **Boss pets**: tiny versions of bosses (Gnarlling) at very low drop rates; cosmetic flex + unique ability.
- **Event pets**: seasonal, limited, return in later years.
- Robux: pet skins and extra pet slots, never stronger pets. Paid eggs, if any, show odds and are region-gated.

## Slots
Equip 1 pet at start, 2 at Lv 10, 3 at Lv 25 (+1 via Patron/gems as convenience, capped at 4). Only one pet is "Active Fighter"; the others give passive bonuses.

## Pet roles (Active Fighter)
| Role | Does | Example |
|---|---|---|
| Striker | attacks your target | Ember Fox: fire bites that burn |
| Guardian | taunts / absorbs hits | Mossback Turtle: shell shield on you at low HP |
| Mender | heals / cleanses | Tide Sprite: small heal every 8s |
| Gatherer | loot & utility | Root Mole: auto-picks loot, digs up bonus mats |
| Hexer | debuffs | Void Moth: dust that makes enemies take +5% damage |
Each pet has 1 active ability (auto-cast; or tap to trigger on PC/mobile) + 1 passive.

## Leveling & growth
- Pets level from XP while equipped (1-50).
- **Pet Food** (from mats) for faster leveling; feeding duplicates gives "Bond" stars (1-5) that boost stats and unlock a second passive at 3 stars.
- **Evolution**: at Lv 25 and 50 with realm materials, a pet evolves (new model, bigger ability). Ember Fox -> Blaze Fox -> Inferno Kitsune.
- **Shiny/Golden variants**: rare cosmetic variants with +5% stats; flex.

## Hidden combos (Kevin's idea)
Secret synergies discovered by experimenting, logged in the Pet Codex once found:
- **Pet + item**: Ember Fox + Emberforge Relic weapon = +10% gold. Root Mole + Verdant ring = +15% material drops.
- **Pet + class**: Tide Sprite with Tidecaller = heals chain to a second ally. Mossback Turtle with Warden = shield also taunts.
- **Pet + pet**: Frost Owl + Void Moth = "Eclipse" combo, +8% XP.
- **Discovery**: a sparkle + chime + "Hidden Combo discovered!" announcement (first finder on a server gets their name shown). Hints drop from NPCs and lore scrolls; the community will hunt and share them (great for wikis and TikTok).
- Balance: combo bonuses are small (5-15%), cap at 3 active combos.

## Personality
- Idle animations, react to rolls (dance on a Legendary), sit near you in Haven, emote when you emote.
- Name your pet; show it on your profile.
- Pets visible to others in Haven (big flex), lower detail on Low graphics.

## Performance (mobile)
Other players' pets are simplified at distance; cap visible pets per player on Low; pet AI runs light on the client, damage is resolved on the server.

## Beta scope
Verdant eggs + Hatchery, 8-10 Verdant pets across rarities, 5 roles, leveling, Bond stars, 3-5 hidden combos. Evolution, wild capture, boss pets post-beta.

## v1.1 Evolution, wild capture, and boss pets

The hatchery in `Pets.luau` does not call these. `PetEvolution`, `WildCapture`, and `WildCaptureService` hold the rules. Nothing here is sold for Robux.

### Evolution
Level 25, then level 50. Each step spends Verdant materials. The personal name, uid, Bond, Affinity, favorite lock, colors, and journal stay. The journal gains `Evolved to <display name>`. Species id, display name (`speciesName`), role, rarity, and ability id change. A form does not skip a step.

| From | Level | Species | Ability | Materials |
|---|---|---|---|---|
| Ember Fox | 25 | Blaze Fox | `blaze_bite` | 4 Heartwood, 8 Verdant Bark, 6 Living Vine |
| Blaze Fox | 50 | Inferno Kitsune | `inferno_pounce` | 1 Gnarl's Seed, 8 Heartwood, 10 Ironbark |
| Mossback Turtle | 25 | Ridgeback | `ridge_guard` | 8 Ironbark, 6 Verdant Bark, 8 Verdant Wood |
| Ridgeback | 50 | Elder Mossback | `canopy_aegis` | 6 Heartwood, 1 Gnarl's Seed, 8 Spore Cap |
| Root Mole | 25 | Burrow Mole | `deep_dig` | 12 Verdant Wood, 6 Living Vine, 4 Spore Cap |
| Burrow Mole | 50 | Den Architect | `vault_harvest` | 6 Heartwood, 8 Ironbark, 8 Verdant Bark |

### Wild shiny capture
`SHINY_SPAWN_RATE` is 0.02. `CAPTURE_CHANCE` is 0.25 and only applies when a Capture Charm is equipped. The charm id is `capture_charm`. It costs 250 gold (`CHARM_GOLD`) or drops as loot. It is not a Robux item.

The tame writes a companion in the hatchery shape plus `shiny`, `golden`, `statBonus` 0.05, and `statNote` `+5% stats`. Enemy ids map to species: Vine Crawler to Vine Sprout, Spore Bat to Spore Mote, Moss Crawler to Moss Kit, Root Brute to Root Pup, Thorn Sprite to Thorn Wisp.

The charm counts as equipped when `equipped.accessories.charm` is the uid of an inventory item with `templateId` `capture_charm`. A live `captureCharm` flag is also read. Schema does not save that flag.

### Boss pets
`BOSS_PETS.grandmother_gnarl` drops Gnarlling (`gnarlling`, ability `tiny_gnarl`) at 0.01. The pet is a cosmetic flex with that ability. `statBonus` is 0. It is not a shiny.

## v1.1 (Kevin's notes): Deep companion bond
Goal: players feel their pet is *theirs* - a buddy with history, not a stat item.

### Bond / Affinity (separate from Bond stars)
- Affinity 1-10 grows by adventuring together, petting, feeding favorite treats, and finishing runs with them.
- Unlocks at levels: new idle animations, emotes, a nickname tag, a unique trick, a pet-only cosmetic, and at 10 a "Soulbound" glow + small loyalty perk (pet revives you once per dungeon).
- Never lost; never decays harshly (pets "miss you" when you return, with a happy greeting animation).

### Pet memory & personality
- Each pet rolls a **Personality** at hatch (Brave, Playful, Lazy, Curious, Grumpy, Loyal) that changes idle behavior and gives a tiny flavor bonus (Curious digs up more loot; Brave charges in first).
- **Favorite food & toy** discovered over time.
- **Pet Journal**: auto-logs milestones - "Hatched Oct 16", "First Legendary roll together", "Defeated Grandmother Gnarl x50", bosses killed, distance walked. Shareable card for screenshots.
- Pets react to the world: shiver in Frostveil, splash in Sunken Reach, hide from bosses at low HP, celebrate level-ups.

### Interaction
- Pet, play fetch, feed treats, and take photos (Photo Mode with pet poses).
- **Pet Den** in Haven: a cozy area (later in personal housing) where your pets hang out, nap, and play together; visit friends' dens.
- Pets you're not using live in the Den, not in a menu.

### Customization (Warframe-style)
- Color channels (primary/secondary/glow), accessories (hats, scarves, armor), trails and aura colors, name tags.
- Cosmetics via gold, gems, events, and Affinity milestones.

### Never betray the bond
- No pets lost in trades by accident (favorite lock); no permadeath; fusing/feeding never consumes a favorited pet.
- Max-Affinity pets are untradeable by default (opt-in only), so scammers can't steal a beloved pet.
- Evolving keeps the name, memories, and Affinity.

### Pet community
- Pet show-off spot in Haven (podium, weekly community-voted "Pet of the Week").
- Pet races/mini-games post-beta.
- Pet Codex completion rewards + title.

### Beta additions
Affinity 1-5, personalities, Pet Journal basics, petting/feeding, color channels, favorite lock.

---

## v2 Research & System (Oct 16, 2026)

### Part A: What works elsewhere
Sources checked: Warframe support article and wiki (Kubrow breeding, Genetic Code Template), Palworld wiki (Breeding, Pal Essence Condenser) plus guides, Uplift Games' Adopt Me Neon help page, and the Pet Simulator 99 wiki (Fuse Machine). Anything marked *(GK)* comes from general knowledge and wasn't checked against a source this round.

| Game | What keeps players attached | Breeding/fusion | Lesson / pitfall |
|---|---|---|---|
| **Warframe** Kubrow/Kavat | Players name and raise them from puppies, the colors and patterns are unique, and a companion's look can be imprinted and passed down | You make **Genetic imprints** of a pet (2 per Kubrow, 3 per Kavat). Imprints store breed, body type, fur pattern, base, secondary and tertiary colors, and energy color. Two matching imprints guarantee that trait. Different imprints give a **50/50 per trait**. Gender and height are always random, so "Omega" size is pure luck. Imprints can be traded. Incubation takes 48h, or 24h with the Nutrio upgrade | Warframe **removed Loyalty and DNA decay plus Stasis in 2020**, because care meters that punish you felt like chores. Rule we take from this: **bonds only add, they never decay.** Moa and Hound modular part companions *(GK)* show that mix-and-match parts work well. Masking kits change how a pet looks but not its genes, which keeps cosmetics separate from breeding |
| **Pokémon** *(GK)* | Shinies (rare colors you can show off), friendship evolutions, natures, partner moments | IVs and natures, plus held items (Everstone, Destiny Knot) that let you steer what passes down | Steerable inheritance is what makes breeding a skill. The pitfall is that hiding stats like IVs creates a grind that can feel bad |
| **Palworld** | Partner skills, base work, rare finds | Passives from both parents go into one pool with duplicates removed. A child gets 1–4 of them, and random ones can fill the rest. **4 wanted passives with no extras is only about a 10% roll.** The 1.0 version added Mutation, which gives a rare unique passive. The **Condenser** uses up copies of the same species for up to 4 stars of stats and partner skill, but **doesn't transfer passives** | Duplicates become fuel, so a bad roll still pays. The pitfall is that pets you sacrifice are gone for good, which is fine for fodder but never OK for a bonded pet |
| **Monster Hunter** Palicos/Palamutes *(GK)* | Character creator, gear you craft that shows up on the pet, voice and personality | None | Crafted gear you can see on the pet is a strong hook. Pets are tied to your progression, so they never go stale |
| **FFXIV** *(GK)* | Collecting minions (a huge collection with no stats), chocobo training and barding | Chocobo stable breeding, mostly for racing | Collections and cosmetics with **no power attached** don't cause power creep and keep players for years |
| **DQ Monsters / Monster Rancher / Digimon** *(GK)* | Synthesis creates new species, care shapes how they evolve | Synthesis consumes both parents, and the child inherits skills | Discovering recipes is fun. Losing both parents feels bad, so offer a choice that keeps a parent |
| **Adopt Me** | Daily care tasks age the pet, plus a trading economy | **Neon = 4 Full Grown of the same species. Mega Neon = 4 Luminous Neons (16 base pets).** Fly and Ride carry over from any input. Mega glow cycles through colors | A visual upgrade with no stats is a huge chase. They changed icons to stop trading scams. The pitfall is that 16 copies pushes spending on duplicates |
| **Pet Simulator 99** | Mass collecting, Golden and Rainbow tiers, trading | **Fuse Machine:** 3–100 pets in, 1 out. Fusing Mastery unlocks guaranteed Gold or Rainbow and a chance at 2 pets out. Shiny and limited pets can't come from fusing | Mastery for using a system rewards your time. The pitfall is that pets turn into disposable numbers, which is the opposite of bonding |
| **Bee Swarm** *(GK)* | Every bee has a role in the hive, gifted variants, mutations | Royal Jelly rerolls (random) | Paid rerolls are loot-box territory and have to be gated by region |
| **Tamagotchi** *(GK)* | Care habits | — | Neglect, sickness or death feels awful in a game. Make care rewarding, never required |
| **Genshin / gacha** *(GK)* | Dailies, friendship levels that unlock voice lines and stories, a housing companion | — | Stories unlocked by bond level create real attachment. The pitfall is paid odds and power creep |

**Takeaways:** (1) bond meters only ever add; (2) players can steer genetics, with luck on top; (3) duplicates become fuel and never a bonded pet; (4) big visual tiers like Neon or Golden with little or no power; (5) mastery for using systems; (6) keep anything purely random and paid out of restricted regions.

### Part B: The Shardfall pet system

**1. Full modular customization (Warframe-style)**
- **Parts:** each species has 3–5 slots: head/horns, body or coat, tail, wings or fins, and eyes. Parts unlock by realm, by evolution, and by Affinity. Moas, for example, mix any head with any body.
- **Colors:** Primary, Secondary, Accent, Eyes, and Energy/Glow, from palettes you earn by playing or buy with Gems. Plus **Patterns** (stripes, spots, runes, galaxy) and **Accessories** (hats, scarves, armor, saddles, trails).
- **Transmog/Glamour:** a pet's look is stored separately from its genes, the way Warframe's masking kits work. Players can save and share loadouts.

**2. Breeding (the Nest, in Haven)**
- Two adult pets (level 20+, Affinity 3+) produce **1 egg**. **Neither parent is consumed.** Each pet can breed again after a 20h cooldown, and each pet has 5 breeds per Bond star.
- **Genes:** species (either parent, plus secret cross recipes), color genes per channel, pattern, size, and personality. Matching traits on both parents are **guaranteed**, and different ones are a 50/50 per trait (Warframe model).
- **Passives:** both parents' passives go into one pool with duplicates removed, and the child gets 1–3. A **Heirloom Charm** lets you lock 1 passive (Destiny Knot/Everstone idea). Charms are **earned by playing only**.
- **Mutation:** about a 2% base chance of a rare color or pattern or a unique "Shardborn" passive. Pairing parents with high Affinity raises it to around 4%. **All odds show in the Nest UI.**
- Incubation takes 4–12h by rarity. Gems can speed it up but **never change the outcome**.

**3. Fusion and Ascension (honors the bond)**
- **Condense:** feed duplicates or "Wisps" (fodder made from unwanted eggs) into a base pet for Bond stars ★1–5 (stats and partner skill). Inputs pass on no passives (Palworld).
- **Radiant / Prismatic visual tiers (our Neon/Mega):** Radiant costs 3 matching pets *or* Shard Essence plus 1 pet. Prismatic costs 3 Radiants. **Gold/Essence paths always exist** so nobody is forced to sacrifice a pet. The result keeps the base pet's name, Journal, Affinity and customization.
- **Hard rules:** pets that are favorited, Affinity 6+, or in your loadout **can't be chosen as fuel**. The confirm screen lists every pet being consumed, and there's a **24h Undo Fusion**.
- **Fusing Mastery** (PS99 idea): cuts the cost, unlocks guaranteed Radiant outcomes and a 5% bonus Wisp refund.
- **Power cap:** Radiant/Prismatic add no more than +5% to stats. The rest is visual.

**4. Loyalty / Affinity:** keep Affinity 1–10 from v1. It **never decays** (lesson from Warframe's removal). Each level unlocks Journal story beats, voice/emote lines, a part and a color. Affinity 10 adds the revive plus a unique Soulbound pattern.

**5. Retention hooks:** a weekly **Pet Expedition** sends idle pets out for materials, a daily "pet wants" request with small rewards and no penalty for skipping, a Hidden Combo hunt, a server-first mutation announcement, seasonal parts, a Pet Codex with every color and mutation (the FFXIV collection hook), Pet of the Week, and a pet race mini-game (post-beta).

**6. Fair monetization**
- **Sold:** cosmetic parts, colors, patterns, accessories, extra Nest and Den slots, incubation speed-ups, and a Pet Pass cosmetic track.
- **Never sold:** passives, mutation chance, stat-boosting fusion items, or eggs/rerolls with random outcomes for Robux in restricted regions (Roblox policy marks paid random items. Policy-gated regions only get direct-purchase items). **Show odds on every random roll**, even free ones. *(The Roblox and regional policy specifics are GK. Verify against current Roblox PolicyService docs before building.)*

**7. Trading**
- Eggs and pets can be traded under the economy trust tiers. **Gene imprints ("Nest Records") can be traded**, Warframe-style, so breeders can earn without selling a bonded pet.
- Pets with Affinity 6+ are untradeable unless the owner opts in. Bred pets show a lineage tag. Radiant (R) and Prismatic (P) get scam-safe icon badges, as Adopt Me did. Every trade is logged.

**8. Scope**
- **Beta:** customization with colors, patterns and accessories (parts for 3 species), Affinity 1–5 that never decays, Condense with Bond stars, all the fusion safety rules, and odds UI.
- **Post-beta 1:** the Nest breeding system (genes, passives, Heirloom Charm, mutation), Radiant tier, and Nest Records trading.
- **Post-beta 2:** Prismatic, cross-species recipes, Expeditions, Fusing Mastery, full modular parts for every species, and pet races.
