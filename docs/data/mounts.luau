--!strict

--[[
	G-104. Suggested mount rows from docs/content/mounts.md.

	Fifteen mounts. Cosmetic speed only. Every rarity uses the
	same Haven walk. pace is "walk" on every row. combatPower is
	false. No luck, no drop odds, no Raid Marks. A mount is not
	ridden in a fight or a dungeon. Suggested rule: a swing or a
	crawl enter dismounts you. Fast travel stays free. Rarity is
	silhouette and glow. Visual note on every row.

	These ids are not in src/. This file does not change a live
	speed number.

	Flags: Bark Sled is not Ironbark. Soot Cart is not Soot Wisp.
	Sap Drifter is not Sap Wisp. Brine Skiff is not Brine Ring.
	Kiln Runner is not Kiln Wisp. Canopy Glider is not Canopy Bear.
	Tide Ray is not Tide Sprite. Ember Wagon is not Ember Fox.
	Frost Sledge is not Frost Pelt. Rift Howdah is not Rift Eye.
	Stormroot Chariot is not Galecrown. Hoar Sleigh is not Hoar
	Prowler. Void Palanquin is not Voidplate. No other game's mount.
]]

return {
	{
		id = "bark_sled",
		name = "Bark Sled",
		rarity = "Common",
		pace = "walk",
		combatPower = false,
		visual = "Low sled of pale bark on two root runners. Olive and tan. No glow.",
	},
	{
		id = "reed_skiff",
		name = "Reed Skiff",
		rarity = "Common",
		pace = "walk",
		combatPower = false,
		visual = "Narrow reed boat a hand above the stone. Dry green reeds, gray lashings. No glow.",
	},
	{
		id = "soot_cart",
		name = "Soot Cart",
		rarity = "Common",
		pace = "walk",
		combatPower = false,
		visual = "Two-wheel iron cart, coal-black boards, dull gray hubs. No glow.",
	},
	{
		id = "plank_strider",
		name = "Plank Strider",
		rarity = "Common",
		pace = "walk",
		combatPower = false,
		visual = "Four bark planks as legs and a flat seat. Brown and sap-green. No glow.",
	},
	{
		id = "sap_drifter",
		name = "Sap Drifter",
		rarity = "Uncommon",
		pace = "walk",
		combatPower = false,
		visual = "Low sled, dark wood, one amber sap runner. Soft amber glow on the runner only.",
	},
	{
		id = "brine_skiff",
		name = "Brine Skiff",
		rarity = "Uncommon",
		pace = "walk",
		combatPower = false,
		visual = "Small skiff, teal boards, a pale salt rim. Soft teal rim glow. No splash.",
	},
	{
		id = "kiln_runner",
		name = "Kiln Runner",
		rarity = "Uncommon",
		pace = "walk",
		combatPower = false,
		visual = "Low iron body of slag plates, a seat in the middle. Soft orange seams. No fire.",
	},
	{
		id = "canopy_glider",
		name = "Canopy Glider",
		rarity = "Rare",
		pace = "walk",
		combatPower = false,
		visual = "A wide seat under a stiff leaf-and-iron wing. Steady green edge glow. The wing does not flap in combat.",
	},
	{
		id = "tide_ray",
		name = "Tide Ray",
		rarity = "Rare",
		pace = "walk",
		combatPower = false,
		visual = "Flat ray of dark glass, teal underside, one rider notch. Steady teal belly glow. It stays a hand above the path.",
	},
	{
		id = "ember_wagon",
		name = "Ember Wagon",
		rarity = "Rare",
		pace = "walk",
		combatPower = false,
		visual = "Closed iron wagon, coal wheels, a small orange hub. Steady hub glow. No smoke column.",
	},
	{
		id = "frost_sledge",
		name = "Frost Sledge",
		rarity = "Epic",
		pace = "walk",
		combatPower = false,
		visual = "Pale crystal runners, a short seat, a cold white trail that fades. Bright trail. No ice left on the stone.",
	},
	{
		id = "rift_howdah",
		name = "Rift Howdah",
		rarity = "Epic",
		pace = "walk",
		combatPower = false,
		visual = "A dark iron seat strapped to a walking rift-stone. Bright violet seams. No beam.",
	},
	{
		id = "stormroot_chariot",
		name = "Stormroot Chariot",
		rarity = "Legendary",
		pace = "walk",
		combatPower = false,
		visual = "Low chariot of gold-green root, two root wheels. Strong short glow on the wheel rims.",
	},
	{
		id = "hoar_sleigh",
		name = "Hoar Sleigh",
		rarity = "Legendary",
		pace = "walk",
		combatPower = false,
		visual = "Crystal sleigh, white-blue, a high back. Strong frost glow. No snow pile.",
	},
	{
		id = "void_palanquin",
		name = "Void Palanquin",
		rarity = "Mythic",
		pace = "walk",
		combatPower = false,
		visual = "A floating slab of black glass with prism cracks, one seat. Void-purple cracks readable across the plaza.",
	},
}
