--!strict

--[[
	G-067. Shard Pass season 1 from docs/content/shard_pass_s1.md.

	Fifty tiers. free and premium match Loops.FREE_TRACK and
	Loops.PREMIUM_TRACK. A tier with no free or premium field still
	costs 1000 Pass XP and pays nothing, the same as claimFree and
	claimPremium when the row is missing.

	The track numbers are live. Art notes are paint only. Nothing
	here changes Loops.luau. PREMIUM_ENABLED stays false. Product
	ids stay 0. No gold on the premium track. No stats, no luck,
	no drop odds, no raid advantage.

	Choice: the tracks stay sparse, the same shape as Loops. A
	missing tier is an empty tier. The older wish of two free pet
	cosmetics and a 25% Gem refund is not on the live free track,
	so it is not here.
]]

return {
	id = "greenwake",
	name = "Greenwake",
	tiers = 50,
	passXp = 1000,
	premiumEnabled = false,
	passProductId = 0,
	archiveProductId = 0,
	passRobux = 400,
	archiveRobux = 480,
	passGems = 400,
	skipGems = 80,
	overflowKeys = 4,
	suggestedWeeks = 8,
	freeTrack = {
		[1] = { gold = 150 },
		[5] = { keys = 4 },
		[10] = { dust = 25 },
		[20] = { gold = 400 },
		[30] = { title = "Boardwalker" },
		[50] = { keys = 20 },
	},
	premiumTrack = {
		[2] = { cosmetic = "skin", id = "pass_skin_moss", name = "Mossweave" },
		[4] = { cosmetic = "skin", id = "pass_skin_fern", name = "Fernweave" },
		[5] = { gems = 40, cosmetic = "pet_hat", id = "pass_hat_moss", name = "Moss Cap" },
		[8] = { cosmetic = "skin", id = "pass_skin_bark", name = "Barkweave" },
		[10] = { gems = 40, cosmetic = "trail", id = "pass_trail_spores", name = "Spore Trail" },
		[12] = { cosmetic = "skin", id = "pass_skin_heartwood", name = "Heartwood" },
		[15] = { gems = 40, cosmetic = "skin", id = "pass_skin_lantern", name = "Lantern Glow" },
		[18] = { cosmetic = "skin", id = "pass_skin_sap", name = "Sapshine" },
		[20] = { gems = 40, cosmetic = "emote", id = "pass_emote_bow", name = "Root Bow" },
		[22] = { cosmetic = "skin", id = "pass_skin_root", name = "Rootbound" },
		[25] = { gems = 40, cosmetic = "weapon_vfx", id = "pass_vfx_sap", name = "Sap Glow" },
		[28] = { cosmetic = "skin", id = "pass_skin_shard", name = "Shardfall" },
		[30] = { gems = 40, cosmetic = "pet_hat", id = "pass_hat_crown", name = "Gnarl Crown" },
		[35] = { gems = 40, cosmetic = "trail", id = "pass_trail_lantern", name = "Lantern Trail" },
		[38] = { cosmetic = "skin", id = "pass_skin_veil", name = "Veil of Leaves" },
		[40] = { gems = 40 },
		[45] = { gems = 40 },
		[48] = { gems = 40 },
		[50] = {
			cosmetic = "skin",
			id = "pass_skin_nightmare",
			name = "Nightmare Bloom",
			feat = "nightmare",
		},
	},
	art = {
		{
			id = "pass_skin_moss",
			name = "Mossweave",
			tier = 2,
			kind = "skin",
			look = "Common",
			visual = "Short coat, yellow-green moss speckles on brown cloth. No glow.",
		},
		{
			id = "pass_skin_fern",
			name = "Fernweave",
			tier = 4,
			kind = "skin",
			look = "Common",
			visual = "Knee-length fern-green cloth, one pale frond stitch on the hem. No glow.",
		},
		{
			id = "pass_hat_moss",
			name = "Moss Cap",
			tier = 5,
			kind = "pet_hat",
			look = "Uncommon",
			visual = "Small rounded moss cap on a thin strap. Soft green glow.",
		},
		{
			id = "pass_skin_bark",
			name = "Barkweave",
			tier = 8,
			kind = "skin",
			look = "Uncommon",
			visual = "Short vest of flat brown bark panels. Dark seams. No glow.",
		},
		{
			id = "pass_trail_spores",
			name = "Spore Trail",
			tier = 10,
			kind = "trail",
			look = "Uncommon",
			visual = "Short trail of pale green spore puffs. Soft glow. Quiet.",
		},
		{
			id = "pass_skin_heartwood",
			name = "Heartwood",
			tier = 12,
			kind = "skin",
			look = "Rare",
			visual = "Pale wood-grain coat, one amber crystal vein. Soft amber glow.",
		},
		{
			id = "pass_skin_lantern",
			name = "Lantern Glow",
			tier = 15,
			kind = "skin",
			look = "Rare",
			visual = "Dark green coat, two small amber lantern stitches. Soft warm glow. No beam.",
		},
		{
			id = "pass_skin_sap",
			name = "Sapshine",
			tier = 18,
			kind = "skin",
			look = "Rare",
			visual = "Green cloth, three glossy amber buttons. Soft glow.",
		},
		{
			id = "pass_emote_bow",
			name = "Root Bow",
			tier = 20,
			kind = "emote",
			look = "Rare",
			visual = "A short bow. One thin root ring on the ground, then it fades. No splash.",
		},
		{
			id = "pass_skin_root",
			name = "Rootbound",
			tier = 22,
			kind = "skin",
			look = "Rare",
			visual = "Dark root wraps over green cloth. No glow.",
		},
		{
			id = "pass_vfx_sap",
			name = "Sap Glow",
			tier = 25,
			kind = "weapon_vfx",
			look = "Epic",
			visual = "Thin amber glint along the weapon edge. No beam. The weapon stays the same size.",
		},
		{
			id = "pass_skin_shard",
			name = "Shardfall",
			tier = 28,
			kind = "skin",
			look = "Epic",
			visual = "Deep green coat. Small pale crystal chips rest on the cloth. Steady soft glow.",
		},
		{
			id = "boardwalker",
			name = "Boardwalker",
			tier = 30,
			kind = "title",
			look = "Uncommon",
			visual = "Name text in #40BA62. Soft moss glow. No icon.",
		},
		{
			id = "pass_hat_crown",
			name = "Gnarl Crown",
			tier = 30,
			kind = "pet_hat",
			look = "Epic",
			visual = "Small twig circlet, one dull amber knot. Steady glow. No face.",
		},
		{
			id = "pass_trail_lantern",
			name = "Lantern Trail",
			tier = 35,
			kind = "trail",
			look = "Epic",
			visual = "Three tiny amber lantern motes behind the feet. Soft warm glow. Quiet.",
		},
		{
			id = "pass_skin_veil",
			name = "Veil of Leaves",
			tier = 38,
			kind = "skin",
			look = "Epic",
			visual = "Sheer green leaf veil, pale veins. Steady glow. The face stays readable.",
		},
		{
			id = "pass_skin_nightmare",
			name = "Nightmare Bloom",
			tier = 50,
			kind = "skin",
			look = "Mythic",
			visual = "Tall dark coat, closed crystal buds, thin #E6404E edge. Bright enough to read. No face.",
		},
	},
}
