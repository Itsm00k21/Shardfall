--!strict

--[[
	G-103. Suggested cosmetic rows from docs/content/cosmetics.md.

	Thirty looks: 8 auras, 8 trails, 8 weapon dyes, 6 name plates.
	A row is a look. No stat, no luck, no drop odds, no Raid Marks,
	and no raid power. A dye does not change the weapon size. A
	plate does not change the title string. Plate hex values match
	Rarities.COLOR. Mythic looks stay prism or void. Commons stay
	plain. None of these is the Patron aura.

	These ids are not pass ids from docs/data/shard_pass_s1.luau.
	This file does not change RaidLuck or any shop table.

	Flags: Pebble Dust is not Pebble Toad. Sap Wisp is not Sap Glow.
	Brine Ring is not Brine Saber. Foam Wake is not Foam Trail.
	Salt Wake is not Saltcloth. Hoar Wake is not Hoar Prowler.
	Void Wake is not Voidplate. Prism Wash is not Prism Edge.
	Plain Board is not Boardwalker. Lamp Board is not Pool Lamp.
	Margin Board is not Hollow Regent. No other game's cosmetic.
]]

return {
	{
		id = "pebble_dust",
		name = "Pebble Dust",
		kind = "aura",
		rarity = "Common",
		visual = "A few gray pebble specks at the ankles. No glow.",
	},
	{
		id = "linen_haze",
		name = "Linen Haze",
		kind = "aura",
		rarity = "Common",
		visual = "A faint undyed haze on the hem. No glow.",
	},
	{
		id = "sap_wisp",
		name = "Sap Wisp",
		kind = "aura",
		rarity = "Uncommon",
		visual = "One small amber wisp at the shoulder. Soft glow. No beam.",
	},
	{
		id = "brine_ring",
		name = "Brine Ring",
		kind = "aura",
		rarity = "Rare",
		visual = "A teal ring on the ground under the feet. Steady glow. No splash.",
	},
	{
		id = "cinder_crownlet",
		name = "Cinder Crownlet",
		kind = "aura",
		rarity = "Epic",
		visual = "A small coal ring above the head. Bright orange. Does not cover the face. No fire.",
	},
	{
		id = "kiln_shoulders",
		name = "Kiln Shoulders",
		kind = "aura",
		rarity = "Epic",
		visual = "Two orange motes on the shoulders. Bright. No beam.",
	},
	{
		id = "frost_sigh",
		name = "Frost Sigh",
		kind = "aura",
		rarity = "Legendary",
		visual = "A short pale breath cloud. Strong cold glow. No ice left on the ground.",
	},
	{
		id = "prism_shade",
		name = "Prism Shade",
		kind = "aura",
		rarity = "Mythic",
		visual = "A thin cracked-rainbow shade around the body. Face readable. Prism glow across a room.",
	},
	{
		id = "gravel_step",
		name = "Gravel Step",
		kind = "trail",
		rarity = "Common",
		visual = "Three gray gravel specks. No glow.",
	},
	{
		id = "hem_puff",
		name = "Hem Puff",
		kind = "trail",
		rarity = "Common",
		visual = "Two dull linen puffs at the heels. No glow.",
	},
	{
		id = "moss_wake",
		name = "Moss Wake",
		kind = "trail",
		rarity = "Uncommon",
		visual = "Short yellow-green moss puffs. Soft glow.",
	},
	{
		id = "foam_wake",
		name = "Foam Wake",
		kind = "trail",
		rarity = "Uncommon",
		visual = "Short cream foam puffs. Soft teal tint.",
	},
	{
		id = "salt_wake",
		name = "Salt Wake",
		kind = "trail",
		rarity = "Rare",
		visual = "A short line of white salt specks. Steady pale glow.",
	},
	{
		id = "slag_wake",
		name = "Slag Wake",
		kind = "trail",
		rarity = "Epic",
		visual = "Three orange slag sparks behind the feet. Bright. They fade. No fire trail.",
	},
	{
		id = "hoar_wake",
		name = "Hoar Wake",
		kind = "trail",
		rarity = "Legendary",
		visual = "A short blue-white frost line. Strong cold glow.",
	},
	{
		id = "void_wake",
		name = "Void Wake",
		kind = "trail",
		rarity = "Mythic",
		visual = "A thin violet seam on the ground that fades. Seam glow across a room.",
	},
	{
		id = "pine_wash",
		name = "Pine Wash",
		kind = "dye",
		rarity = "Common",
		visual = "A dull pine-brown edge. No glow.",
	},
	{
		id = "moss_wash",
		name = "Moss Wash",
		kind = "dye",
		rarity = "Uncommon",
		visual = "A yellow-green edge. Soft moss glow.",
	},
	{
		id = "kelp_wash",
		name = "Kelp Wash",
		kind = "dye",
		rarity = "Uncommon",
		visual = "A kelp-green edge. Soft sea glow.",
	},
	{
		id = "pearl_wash",
		name = "Pearl Wash",
		kind = "dye",
		rarity = "Rare",
		visual = "A cream pearl edge. Steady pale glow.",
	},
	{
		id = "tide_wash",
		name = "Tide Wash",
		kind = "dye",
		rarity = "Rare",
		visual = "A teal edge. Steady sea glow.",
	},
	{
		id = "coal_wash",
		name = "Coal Wash",
		kind = "dye",
		rarity = "Epic",
		visual = "An orange coal edge. Bright. No beam.",
	},
	{
		id = "gale_wash",
		name = "Gale Wash",
		kind = "dye",
		rarity = "Legendary",
		visual = "A moon-silver edge with a short mist. Strong glow. No beam.",
	},
	{
		id = "prism_wash",
		name = "Prism Wash",
		kind = "dye",
		rarity = "Mythic",
		visual = "A rainbow edge on the weapon only. Prism glow across a room. The weapon stays the same size.",
	},
	{
		id = "plain_board",
		name = "Plain Board",
		kind = "plate",
		rarity = "Common",
		visual = "A flat gray rectangle. #A8A8B0 edge. No glow.",
	},
	{
		id = "stitch_board",
		name = "Stitch Board",
		kind = "plate",
		rarity = "Uncommon",
		visual = "A cream board with a pine-brown stitch. Soft #40BA62 corner glow.",
	},
	{
		id = "salt_board",
		name = "Salt Board",
		kind = "plate",
		rarity = "Rare",
		visual = "White salt-crystal corners. Steady #488EFF pale edge.",
	},
	{
		id = "lamp_board",
		name = "Lamp Board",
		kind = "plate",
		rarity = "Rare",
		visual = "Two small amber lamp marks in the corners. Thin #488EFF edge. Soft warm glow. No beam.",
	},
	{
		id = "frost_board",
		name = "Frost Board",
		kind = "plate",
		rarity = "Epic",
		visual = "Blue-white ice corners. Thin #BA60F0 inner edge. Bright cold glow. Letters stay readable.",
	},
	{
		id = "margin_board",
		name = "Margin Board",
		kind = "plate",
		rarity = "Legendary",
		visual = "A gray board with a thin violet inner line. Strong gold #FFC440 outer edge. Letters stay readable. No face.",
	},
}
