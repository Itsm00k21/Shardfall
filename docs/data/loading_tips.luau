--!strict

--[[
	G-066. Loading-tip rows from docs/content/loading_tips.md.

	Sixty strings, same order as LoadingTips.TIPS (tip_01 through
	tip_60). This draft is not required by the client. Do not edit
	LoadingTips.luau from here. Numbers inside the strings are the
	live ones. Each line is under 90 characters.
]]

return {
	{
		id = "tip_01",
		topic = "controls",
		text = "Attack is E. Dodge is Q. Heavy is R. Sprint is Shift.",
	},
	{
		id = "tip_02",
		topic = "controls",
		text = "Class skills are 1 and 2. The ultimate is F.",
	},
	{
		id = "tip_03",
		topic = "controls",
		text = "The Roll tab is T. R stays the heavy attack.",
	},
	{
		id = "tip_04",
		topic = "controls",
		text = "Hotkeys: Hero C, Bag B, Pets P, Raids I, Market M.",
	},
	{
		id = "tip_05",
		topic = "controls",
		text = "Esc closes the hub. Controller B closes it too.",
	},
	{
		id = "tip_06",
		topic = "controls",
		text = "Red marks are dodged. Blue marks are interrupted.",
	},
	{
		id = "tip_07",
		topic = "controls",
		text = "Controller heavy is ButtonX. Keyboard heavy stays R.",
	},
	{
		id = "tip_08",
		topic = "controls",
		text = "Menu hotkeys can change in Settings. Combat keys stay put.",
	},
	{
		id = "tip_09",
		topic = "controls",
		text = "WASD moves you. Space jumps.",
	},
	{
		id = "tip_10",
		topic = "controls",
		text = "Hide HUD, UI scale, and damage numbers are in Settings.",
	},
	{
		id = "tip_11",
		topic = "rolls",
		text = "One crack spends one Shard Token. Tokens are earned.",
	},
	{
		id = "tip_12",
		topic = "rolls",
		text = "Prism Tokens are bought. They are not Shard Tokens.",
	},
	{
		id = "tip_13",
		topic = "rolls",
		text = "Every 10th crack has x2 luck. It is still one crack.",
	},
	{
		id = "tip_14",
		topic = "rolls",
		text = "The odds line includes luck. Pity sits outside those percents.",
	},
	{
		id = "tip_15",
		topic = "rolls",
		text = "When the bonus is next, the label reads x2 Luck Ready.",
	},
	{
		id = "tip_16",
		topic = "rolls",
		text = "Auto cracks again until you turn it off or Stop at hits.",
	},
	{
		id = "tip_17",
		topic = "rolls",
		text = "Quick shortens the reveal. It does not change the odds.",
	},
	{
		id = "tip_18",
		topic = "rolls",
		text = "Info shows the odds. The card tint is the real rarity.",
	},
	{
		id = "tip_19",
		topic = "rolls",
		text = "At x1 luck, Common reads 1 in 2. Mythic reads 1 in 25000.",
	},
	{
		id = "tip_20",
		topic = "rolls",
		text = "Stop at halts Auto on a rarity. It does not change the draw.",
	},
	{
		id = "tip_21",
		topic = "pity",
		text = "The pity line shows Epic progress out of 100 and Legendary out of 1000.",
	},
	{
		id = "tip_22",
		topic = "pity",
		text = "When Epic pity shows 99/100, the next crack is at least Epic.",
	},
	{
		id = "tip_23",
		topic = "pity",
		text = "At 999/1000 Legendary pity, the next crack is Legendary or better.",
	},
	{
		id = "tip_24",
		topic = "pity",
		text = "An Epic or better resets the Epic pity counter.",
	},
	{
		id = "tip_25",
		topic = "pity",
		text = "A Legendary or better resets both Armory pity counters.",
	},
	{
		id = "tip_26",
		topic = "pity",
		text = "Rare has no Armory countdown. Next Epic is the real remainder.",
	},
	{
		id = "tip_27",
		topic = "pity",
		text = "Chest pity is a different counter from Armory pity.",
	},
	{
		id = "tip_28",
		topic = "pity",
		text = "A Rare chest reaches Epic or better by 20 opens with no Epic.",
	},
	{
		id = "tip_29",
		topic = "pity",
		text = "An Epic chest reaches Legendary by 15 opens with none.",
	},
	{
		id = "tip_30",
		topic = "pity",
		text = "The guarantee shows the rarity you received. It is not a fake tint.",
	},
	{
		id = "tip_31",
		topic = "raids",
		text = "The Heartwood is the raid. Rootvault is the dungeon.",
	},
	{
		id = "tip_32",
		topic = "raids",
		text = "Heartwood Story and Normal are both level 15.",
	},
	{
		id = "tip_33",
		topic = "raids",
		text = "A Story clear pays 25 Raid Marks. Normal pays 40.",
	},
	{
		id = "tip_34",
		topic = "raids",
		text = "Marks earned this week cap at 600. The wallet does not reset.",
	},
	{
		id = "tip_35",
		topic = "raids",
		text = "Heartwood Student costs 200 Raid Marks at the vendor.",
	},
	{
		id = "tip_36",
		topic = "raids",
		text = "Wings: Thornwarden Twins, Mother Sapwell, Galecrown, Grandmother Gnarl Awakened.",
	},
	{
		id = "tip_37",
		topic = "raids",
		text = "A Heartwood party needs 4 players. Practice Grove is the solo path.",
	},
	{
		id = "tip_38",
		topic = "raids",
		text = "Warden can tank. Tidecaller can heal. Any class can be DPS.",
	},
	{
		id = "tip_39",
		topic = "raids",
		text = "Practice Grove is free and pays no loot.",
	},
	{
		id = "tip_40",
		topic = "raids",
		text = "Each boss rolls loot once per difficulty each week. Marks still pay.",
	},
	{
		id = "tip_41",
		topic = "pets",
		text = "Hatching spends an egg, or 50 gold if you have no egg.",
	},
	{
		id = "tip_42",
		topic = "pets",
		text = "Eight pets can hatch, from Ember Fox through Bark Owl.",
	},
	{
		id = "tip_43",
		topic = "pets",
		text = "Affinity and Bond are separate. Each one caps at 5.",
	},
	{
		id = "tip_44",
		topic = "pets",
		text = "Petting raises Affinity by 1, up to 5.",
	},
	{
		id = "tip_45",
		topic = "pets",
		text = "Feeding adds 25 pet XP. Each level costs 50 XP, up to 50.",
	},
	{
		id = "tip_46",
		topic = "pets",
		text = "Hidden pet combos cap at 3. A fourth does not fire.",
	},
	{
		id = "tip_47",
		topic = "pets",
		text = "A favorite pet cannot be fused.",
	},
	{
		id = "tip_48",
		topic = "pets",
		text = "Fusion stays on one species and adds a Bond star, up to 5.",
	},
	{
		id = "tip_49",
		topic = "pets",
		text = "A combo needs its listed pet, and sometimes a class or item.",
	},
	{
		id = "tip_50",
		topic = "pets",
		text = "An egg in your bag shows a dot on Pets.",
	},
	{
		id = "tip_51",
		topic = "crafting",
		text = "A Healing Tonic takes 1 Spore Cap and 1 Living Vine.",
	},
	{
		id = "tip_52",
		topic = "crafting",
		text = "A Healing Tonic restores 40% of your max HP.",
	},
	{
		id = "tip_53",
		topic = "crafting",
		text = "Briar Edge forges a Thorn Dagger: 4 Verdant Wood, 2 Living Vine.",
	},
	{
		id = "tip_54",
		topic = "crafting",
		text = "Thornbound Blade needs Crafting Level 10 and a Thornbound Scroll.",
	},
	{
		id = "tip_55",
		topic = "crafting",
		text = "The Thornbound Scroll is not spent when you craft the blade.",
	},
	{
		id = "tip_56",
		topic = "crafting",
		text = "Wild Resin rerolls one trait on a Rare or better weapon or armor.",
	},
	{
		id = "tip_57",
		topic = "crafting",
		text = "Iron weapons are forged from Verdant Bark.",
	},
	{
		id = "tip_58",
		topic = "crafting",
		text = "An Uncommon chest is 40 Shard Keys. A Rare chest is 150.",
	},
	{
		id = "tip_59",
		topic = "crafting",
		text = "An Epic chest is 600 Shard Keys. Legendary chests are not sold.",
	},
	{
		id = "tip_60",
		topic = "crafting",
		text = "Duplicates can pay Dust. A higher rarity pays more Dust.",
	},
}
