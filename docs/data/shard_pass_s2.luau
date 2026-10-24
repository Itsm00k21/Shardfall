--!strict

--[[
	G-105. Shard Pass season 2 from docs/content/shard_pass_s2.md.

	Bell Tide. Fifty tiers. Cosmetics and convenience only. freeTrack
	and premiumTrack use the same reward fields as Loops.FREE_TRACK
	and Loops.PREMIUM_TRACK. A tier with no row still costs 1000 Pass
	XP and pays nothing.

	Gold, keys, and dust on tiers 1, 5, 10, 20, and 50 match the live
	free track. Foam Collar, Salt Ribbon, and the title Tidewalker are
	suggested additions. Premium gems are 40 on ten tiers. The sum is
	400, the live Loops.PASS_GEMS. Tier 50 is the feat skin and pays
	no gems. No gold, keys, or dust on the premium track. No stats,
	no luck, no drop odds, no raid advantage.

	No Greenwake id. No pass_skin_moss, pass_hat_moss, pass_trail_spores,
	pass_skin_nightmare, or Boardwalker. Kind "weapon glow" in the
	content file is cosmetic "weapon_vfx", matching the live track.
	"pet hat" is "pet_hat". Robux prices and product ids are not in
	the season 2 outline, so they are not here. PREMIUM_ENABLED stays
	false. This file does not change Loops.luau.

	Feat bell_pool is suggested. Until Bell Pool exists, Glass Tide
	cannot be claimed. No Robux bypass.

	Flags: Saltcloth is not Gladecloth. Foam Trail is not Spore Trail.
	Tide Bow is not Root Bow. Bell Glow is not Sap Glow. Veil of Salt
	is not Veil of Leaves. Glass Tide is not Nightmare Bloom.
	Tidewalker is not Boardwalker and not Heartwood Student.
]]

return {
	id = "bell_tide",
	name = "Bell Tide",
	theme = "Saltglass coast. Cream salt, teal water, soft bell light.",
	tiers = 50,
	passXp = 1000,
	premiumEnabled = false,
	passGems = 400,
	skipGems = 80,
	overflowKeys = 4,
	feat = "bell_pool",
	featNote = "Suggested. Stand once at Bell Pool. No Robux bypass.",
	freeTrack = {
		[1] = { gold = 150 },
		[5] = { keys = 4 },
		[10] = { dust = 25 },
		[15] = { cosmetic = "pet_collar", id = "pass_s2_collar_foam", name = "Foam Collar" },
		[20] = { gold = 400 },
		[30] = { title = "Tidewalker" },
		[40] = { cosmetic = "pet_ribbon", id = "pass_s2_ribbon_salt", name = "Salt Ribbon" },
		[50] = { keys = 20 },
	},
	premiumTrack = {
		[2] = { cosmetic = "skin", id = "pass_s2_skin_salt", name = "Saltcloth" },
		[4] = { cosmetic = "skin", id = "pass_s2_skin_foam", name = "Foamweave" },
		[5] = { gems = 40, cosmetic = "pet_hat", id = "pass_s2_hat_bell", name = "Bell Cap" },
		[8] = { cosmetic = "skin", id = "pass_s2_skin_brine", name = "Brineweave" },
		[10] = { gems = 40, cosmetic = "trail", id = "pass_s2_trail_foam", name = "Foam Trail" },
		[12] = { cosmetic = "skin", id = "pass_s2_skin_gull", name = "Gullcloth" },
		[15] = { gems = 40, cosmetic = "skin", id = "pass_s2_skin_lamp", name = "Pool Lamp" },
		[18] = { cosmetic = "skin", id = "pass_s2_skin_pearl", name = "Pearlsheen" },
		[20] = { gems = 40, cosmetic = "emote", id = "pass_s2_emote_tide", name = "Tide Bow" },
		[22] = { cosmetic = "skin", id = "pass_s2_skin_kelp", name = "Kelpbound" },
		[25] = { gems = 40, cosmetic = "weapon_vfx", id = "pass_s2_vfx_bell", name = "Bell Glow" },
		[28] = { cosmetic = "skin", id = "pass_s2_skin_arch", name = "Archcloth" },
		[30] = { gems = 40, cosmetic = "pet_hat", id = "pass_s2_hat_shell", name = "Shell Cap" },
		[35] = { gems = 40, cosmetic = "trail", id = "pass_s2_trail_bell", name = "Bell Trail" },
		[38] = { cosmetic = "skin", id = "pass_s2_skin_veil", name = "Veil of Salt" },
		[40] = { gems = 40 },
		[45] = { gems = 40 },
		[48] = { gems = 40 },
		[50] = {
			cosmetic = "skin",
			id = "pass_s2_skin_glass",
			name = "Glass Tide",
			feat = "bell_pool",
		},
	},
	art = {
		{
			id = "pass_s2_skin_salt",
			name = "Saltcloth",
			tier = 2,
			track = "premium",
			kind = "skin",
			look = "Common",
			visual = "Cream cloth, pale salt speckles. No glow.",
		},
		{
			id = "pass_s2_skin_foam",
			name = "Foamweave",
			tier = 4,
			track = "premium",
			kind = "skin",
			look = "Common",
			visual = "White cloth, a teal foam edge. No glow.",
		},
		{
			id = "pass_s2_hat_bell",
			name = "Bell Cap",
			tier = 5,
			track = "premium",
			kind = "pet_hat",
			look = "Uncommon",
			visual = "Small cream bell on a strap. Soft teal glow.",
		},
		{
			id = "pass_s2_skin_brine",
			name = "Brineweave",
			tier = 8,
			track = "premium",
			kind = "skin",
			look = "Uncommon",
			visual = "Dark teal cloth, salt hem. No glow.",
		},
		{
			id = "pass_s2_trail_foam",
			name = "Foam Trail",
			tier = 10,
			track = "premium",
			kind = "trail",
			look = "Uncommon",
			visual = "Short white foam puffs. Soft teal.",
		},
		{
			id = "pass_s2_skin_gull",
			name = "Gullcloth",
			tier = 12,
			track = "premium",
			kind = "skin",
			look = "Rare",
			visual = "Gull-gray cloak, cream hem. No glow.",
		},
		{
			id = "pass_s2_collar_foam",
			name = "Foam Collar",
			tier = 15,
			track = "free",
			kind = "pet_collar",
			look = "Common",
			visual = "Cream band, one teal stitch. No glow.",
		},
		{
			id = "pass_s2_skin_lamp",
			name = "Pool Lamp",
			tier = 15,
			track = "premium",
			kind = "skin",
			look = "Rare",
			visual = "Blue-white lamp stitches. Soft lamp glow.",
		},
		{
			id = "pass_s2_skin_pearl",
			name = "Pearlsheen",
			tier = 18,
			track = "premium",
			kind = "skin",
			look = "Rare",
			visual = "Cream cloth, one pale pearl button. Soft glow.",
		},
		{
			id = "pass_s2_emote_tide",
			name = "Tide Bow",
			tier = 20,
			track = "premium",
			kind = "emote",
			look = "Rare",
			visual = "A short bow. One teal ripple on the ground. No splash.",
		},
		{
			id = "pass_s2_skin_kelp",
			name = "Kelpbound",
			tier = 22,
			track = "premium",
			kind = "skin",
			look = "Rare",
			visual = "Dark green-teal wrap. No glow.",
		},
		{
			id = "pass_s2_vfx_bell",
			name = "Bell Glow",
			tier = 25,
			track = "premium",
			kind = "weapon_vfx",
			look = "Epic",
			visual = "Soft teal bell glint on the weapon. No beam.",
		},
		{
			id = "pass_s2_skin_arch",
			name = "Archcloth",
			tier = 28,
			track = "premium",
			kind = "skin",
			look = "Epic",
			visual = "White salt-arch pattern. Pale steady glow.",
		},
		{
			id = "pass_s2_title_tide",
			name = "Tidewalker",
			tier = 30,
			track = "free",
			kind = "title",
			look = "Uncommon",
			visual = "Name text in #40BA62. Soft moss glow. No icon.",
		},
		{
			id = "pass_s2_hat_shell",
			name = "Shell Cap",
			tier = 30,
			track = "premium",
			kind = "pet_hat",
			look = "Epic",
			visual = "Cream shell cap, teal rim. Steady glow.",
		},
		{
			id = "pass_s2_trail_bell",
			name = "Bell Trail",
			tier = 35,
			track = "premium",
			kind = "trail",
			look = "Epic",
			visual = "Tiny cream bells. Soft teal glow. Quiet.",
		},
		{
			id = "pass_s2_skin_veil",
			name = "Veil of Salt",
			tier = 38,
			track = "premium",
			kind = "skin",
			look = "Epic",
			visual = "Sheer cream veil, salt glitter. Steady glow.",
		},
		{
			id = "pass_s2_ribbon_salt",
			name = "Salt Ribbon",
			tier = 40,
			track = "free",
			kind = "pet_ribbon",
			look = "Rare",
			visual = "Short cream ribbon, one teal stitch. Soft glow.",
		},
		{
			id = "pass_s2_skin_glass",
			name = "Glass Tide",
			tier = 50,
			track = "premium",
			kind = "skin",
			look = "Mythic",
			visual = "Tall salt-glass coat, teal inner light. Bright, still readable. No face.",
		},
	},
}
