--!strict

--[[
	G-106. Suggested evolution lines from docs/content/pet_evolutions.md.

	Eight lines, three stages each. Live rule from PetEvolution.luau:
	level 25, then level 50. A line cannot skip a stage. Personal
	name, uid, Bond, Affinity, favorite, colors, journal, and
	personality stay. Species, display name, ability id, and rarity
	change. Role is written again as the same role. The journal
	gains "Evolved to <display name>". evolve stores one count per
	material id, so a step never repeats an id.

	Each step uses the live Step fields: from, level, species,
	displayName, ability, role, rarity, materials. abilityNote and
	visual are art notes. Drop those two before a paste into
	PetEvolution.STEPS. Material counts are suggested.

	The live Verdant chains stay in PetEvolution.STEPS and are not
	copied here: ember_fox, blaze_fox, inferno_kitsune, mossback,
	ridgeback, elder_mossback, root_mole, burrow_mole, den_architect.
	This file does not add a row to Pets.SPECIES. tide_sprite is the
	only hatch already in Pets.luau. The other seven hatches are
	suggested. Their ability ids are suggestions. Pets.luau does not
	store an ability today.

	Boss materials stay off the level-25 step. Tide Sprite spends
	Verdant materials, the same family as the three live chains.

	Flags: Crownscale Crab is not the Leviathan Crown-Scale material.
	Everfrost Ram is not the Everfrost Gem. Hollow Moth is not
	Sovereign's Hollow Core and not Void Moth. Hearth Vole is not
	Kilnheart. Veil Lark is not Veil of Leaves. No outside creature.
]]

return {
	{
		id = "dew_beetle",
		realm = "Verdant Wilds",
		hatch = {
			species = "dew_beetle",
			displayName = "Dew Beetle",
			rarity = "Common",
			role = "Striker",
			personality = "Brave",
			ability = "dew_jab",
			abilityNote = "Suggested. A quick dew bite.",
			visual = "Small oval beetle, dull green shell, one clear dew bead, no glow.",
			inPets = false,
		},
		steps = {
			{
				from = "dew_beetle",
				level = 25,
				species = "resin_beetle",
				displayName = "Resin Beetle",
				ability = "resin_rush",
				abilityNote = "Suggested. A sticky charge at the target.",
				role = "Striker",
				rarity = "Rare",
				visual = "Stockier beetle, honey-brown shell plates, steady amber seams.",
				materials = {
					{ id = "heartwood", count = 4 },
					{ id = "bark", count = 8 },
					{ id = "vine", count = 6 },
				},
			},
			{
				from = "resin_beetle",
				level = 50,
				species = "amber_borer",
				displayName = "Amber Borer",
				ability = "amber_horn",
				abilityNote = "Suggested. A horn hit that shines.",
				role = "Striker",
				rarity = "Epic",
				visual = "Large horned beetle, dark shell under a clear amber dome, bright amber horn glow.",
				materials = {
					{ id = "gnarl_seed", count = 1 },
					{ id = "heartwood", count = 8 },
					{ id = "verdant_bark", count = 10 },
				},
			},
		},
	},
	{
		id = "lagoon_crab",
		realm = "Sunken Reach",
		hatch = {
			species = "lagoon_crab",
			displayName = "Lagoon Crab",
			rarity = "Uncommon",
			role = "Guardian",
			personality = "Loyal",
			ability = "lagoon_pinch",
			abilityNote = "Suggested. A pinch that guards you.",
			visual = "Wide low crab, teal shell, pale kelp fringe, soft rim glow.",
			inPets = false,
		},
		steps = {
			{
				from = "lagoon_crab",
				level = 25,
				species = "breakwater_crab",
				displayName = "Breakwater Crab",
				ability = "reef_brace",
				abilityNote = "Suggested. A shell brace when you are hit.",
				role = "Guardian",
				rarity = "Rare",
				visual = "Heavier crab, coral-pink plates on a gray shell, steady teal claw glow.",
				materials = {
					{ id = "black_pearl", count = 3 },
					{ id = "coral_shard", count = 12 },
				},
			},
			{
				from = "breakwater_crab",
				level = 50,
				species = "crownscale_crab",
				displayName = "Crownscale Crab",
				ability = "crown_aegis",
				abilityNote = "Suggested. A bright shell over you.",
				role = "Guardian",
				rarity = "Epic",
				visual = "Tall crab, deep blue shell, one gold-blue crown scale, bright scale glow.",
				materials = {
					{ id = "leviathan_scale", count = 1 },
					{ id = "black_pearl", count = 6 },
					{ id = "coral_shard", count = 12 },
				},
			},
		},
	},
	{
		id = "tide_sprite",
		realm = "Verdant Wilds",
		hatch = {
			species = "tide_sprite",
			displayName = "Tide Sprite",
			rarity = "Uncommon",
			role = "Mender",
			personality = "Playful",
			ability = "tide_mend",
			abilityNote = "Suggested. Small heal. The design note already says every 8s.",
			visual = "Small water sprite, pale blue, soft tide glow.",
			inPets = true,
		},
		steps = {
			{
				from = "tide_sprite",
				level = 25,
				species = "neap_sprite",
				displayName = "Neap Sprite",
				ability = "neap_mend",
				abilityNote = "Suggested. A wider small heal.",
				role = "Mender",
				rarity = "Rare",
				visual = "Taller sprite, cream and pale blue, a pearl on the brow, steady pale glow.",
				materials = {
					{ id = "heartwood", count = 4 },
					{ id = "verdant_bark", count = 6 },
					{ id = "spore", count = 8 },
				},
			},
			{
				from = "neap_sprite",
				level = 50,
				species = "flood_sprite",
				displayName = "Flood Sprite",
				ability = "flood_mend",
				abilityNote = "Suggested. A bright tide heal.",
				role = "Mender",
				rarity = "Epic",
				visual = "Tall sprite, rose and deep teal, a ribbon of water, bright tide glow.",
				materials = {
					{ id = "gnarl_seed", count = 1 },
					{ id = "heartwood", count = 6 },
					{ id = "vine", count = 10 },
				},
			},
		},
	},
	{
		id = "ash_vole",
		realm = "Emberforge",
		hatch = {
			species = "ash_vole",
			displayName = "Ash Vole",
			rarity = "Common",
			role = "Gatherer",
			personality = "Curious",
			ability = "ash_sift",
			abilityNote = "Suggested. Sifts a bonus material.",
			visual = "Small round vole, soot-gray fur, ash-white belly, no glow.",
			inPets = false,
		},
		steps = {
			{
				from = "ash_vole",
				level = 25,
				species = "slag_vole",
				displayName = "Slag Vole",
				ability = "slag_pocket",
				abilityNote = "Suggested. Pockets an extra material.",
				role = "Gatherer",
				rarity = "Rare",
				visual = "Stocky vole, black fur with orange slag cracks, steady crack glow.",
				materials = {
					{ id = "molten_core", count = 3 },
					{ id = "cinder_ore", count = 12 },
				},
			},
			{
				from = "slag_vole",
				level = 50,
				species = "hearth_vole",
				displayName = "Hearth Vole",
				ability = "hearth_vault",
				abilityNote = "Suggested. A brighter bonus dig.",
				role = "Gatherer",
				rarity = "Epic",
				visual = "Plump vole, charcoal fur, a coal-bright chest pocket, bright pocket glow.",
				materials = {
					{ id = "tyrant_heart", count = 1 },
					{ id = "molten_core", count = 6 },
					{ id = "cinder_ore", count = 10 },
				},
			},
		},
	},
	{
		id = "soot_wisp",
		realm = "Emberforge",
		hatch = {
			species = "soot_wisp",
			displayName = "Soot Wisp",
			rarity = "Uncommon",
			role = "Hexer",
			personality = "Grumpy",
			ability = "soot_dust",
			abilityNote = "Suggested. Dust that marks a foe.",
			visual = "Small floating wisp, gray soot body, one orange eye, soft dim glow.",
			inPets = false,
		},
		steps = {
			{
				from = "soot_wisp",
				level = 25,
				species = "slag_wisp",
				displayName = "Slag Wisp",
				ability = "slag_mark",
				abilityNote = "Suggested. A hotter mark on a foe.",
				role = "Hexer",
				rarity = "Rare",
				visual = "Taller wisp, cracked black glass, steady orange seams.",
				materials = {
					{ id = "molten_core", count = 4 },
					{ id = "cinder_ore", count = 8 },
				},
			},
			{
				from = "slag_wisp",
				level = 50,
				species = "kiln_wisp",
				displayName = "Kiln Wisp",
				ability = "kiln_hex",
				abilityNote = "Suggested. A bright mark that lingers.",
				role = "Hexer",
				rarity = "Epic",
				visual = "Tall wisp, a cage of dark iron around a coal core, bright core glow.",
				materials = {
					{ id = "tyrant_heart", count = 1 },
					{ id = "molten_core", count = 8 },
					{ id = "cinder_ore", count = 8 },
				},
			},
		},
	},
	{
		id = "rime_ram",
		realm = "Frostveil",
		hatch = {
			species = "rime_ram",
			displayName = "Rime Ram",
			rarity = "Common",
			role = "Guardian",
			personality = "Loyal",
			ability = "rime_brace",
			abilityNote = "Suggested. A cold brace when you are hit.",
			visual = "Sturdy ram, white-gray wool, short dull horns, no glow.",
			inPets = false,
		},
		steps = {
			{
				from = "rime_ram",
				level = 25,
				species = "snowpack_ram",
				displayName = "Snowpack Ram",
				ability = "snow_guard",
				abilityNote = "Suggested. A thicker snow guard.",
				role = "Guardian",
				rarity = "Rare",
				visual = "Heavy ram, packed snow on the shoulders, ice horns, steady blue horn glow.",
				materials = {
					{ id = "everfrost_gem", count = 3 },
					{ id = "frost_pelt", count = 12 },
				},
			},
			{
				from = "snowpack_ram",
				level = 50,
				species = "everfrost_ram",
				displayName = "Everfrost Ram",
				ability = "ever_aegis",
				abilityNote = "Suggested. A bright frost shell.",
				role = "Guardian",
				rarity = "Epic",
				visual = "Huge ram, blue-white crystal horns, bright horn glow and a short frost trail.",
				materials = {
					{ id = "matriarch_fang", count = 1 },
					{ id = "everfrost_gem", count = 6 },
					{ id = "frost_pelt", count = 10 },
				},
			},
		},
	},
	{
		id = "frost_lark",
		realm = "Frostveil",
		hatch = {
			species = "frost_lark",
			displayName = "Frost Lark",
			rarity = "Uncommon",
			role = "Mender",
			personality = "Lazy",
			ability = "frost_note",
			abilityNote = "Suggested. A soft heal on a note.",
			visual = "Small round bird, pale blue-gray feathers, soft cold glint on the beak.",
			inPets = false,
		},
		steps = {
			{
				from = "frost_lark",
				level = 25,
				species = "glaze_lark",
				displayName = "Glaze Lark",
				ability = "glaze_mend",
				abilityNote = "Suggested. A clearer heal.",
				role = "Mender",
				rarity = "Rare",
				visual = "Slim bird, ice-clear wing edges, steady blue wing glow.",
				materials = {
					{ id = "everfrost_gem", count = 4 },
					{ id = "frost_pelt", count = 8 },
				},
			},
			{
				from = "glaze_lark",
				level = 50,
				species = "veil_lark",
				displayName = "Veil Lark",
				ability = "veil_song",
				abilityNote = "Suggested. A bright frost heal.",
				role = "Mender",
				rarity = "Epic",
				visual = "Wide-wing bird, a walking frost veil for a tail, bright white trail.",
				materials = {
					{ id = "matriarch_fang", count = 1 },
					{ id = "everfrost_gem", count = 8 },
					{ id = "frost_pelt", count = 6 },
				},
			},
		},
	},
	{
		id = "hollow_moth",
		realm = "Void Rift",
		hatch = {
			species = "hollow_moth",
			displayName = "Hollow Moth",
			rarity = "Common",
			role = "Hexer",
			personality = "Grumpy",
			ability = "hollow_dust",
			abilityNote = "Suggested. Dim dust on a foe.",
			visual = "Small moth, dull gray wings, a dark empty spot on each wing, no glow.",
			inPets = false,
		},
		steps = {
			{
				from = "hollow_moth",
				level = 25,
				species = "rift_moth",
				displayName = "Rift Moth",
				ability = "rift_mark",
				abilityNote = "Suggested. A violet mark on a foe.",
				role = "Hexer",
				rarity = "Rare",
				visual = "Wide moth, charcoal wings with one violet slit, steady slit glow.",
				materials = {
					{ id = "rift_eye", count = 4 },
					{ id = "void_dust", count = 8 },
				},
			},
			{
				from = "rift_moth",
				level = 50,
				species = "voidglass_moth",
				displayName = "Voidglass Moth",
				ability = "voidglass_hex",
				abilityNote = "Suggested. A bright void mark.",
				role = "Hexer",
				rarity = "Epic",
				visual = "Large moth, mirrorless gray-violet glass wings, bright violet body glow.",
				materials = {
					{ id = "hollow_core", count = 1 },
					{ id = "rift_eye", count = 8 },
					{ id = "void_dust", count = 10 },
				},
			},
		},
	},
}
