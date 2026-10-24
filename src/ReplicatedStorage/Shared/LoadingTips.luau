--!strict

--[[
	Loading-screen tips. Pure list.

	Sixty lines, in the same order as the G-020 content file:
	tip_01 through tip_60. The strings live here. This module
	does not read that file, and it does not load another module.

	line(step) returns the row at that whole-number step. Step 0
	is tip_01. The list wraps at 60, so step 60 is tip_01 again.
	A negative, fractional, or non-number step returns nothing
	and does not throw.

	paid, a product id, Robux, cost, and skip do not select a
	different line. Pass them on the optional second argument;
	they are ignored. No RNG. No clock. No services. Nothing
	here costs Robux.
]]

local LoadingTips = {}

export type Tip = {
	id: string,
	topic: string,
	text: string,
}

local function tip(id: string, topic: string, text: string): Tip
	return table.freeze({
		id = id,
		topic = topic,
		text = text,
	})
end

LoadingTips.TIPS = table.freeze({
	tip("tip_01", "controls", "Attack is E. Dodge is Q. Heavy is R. Sprint is Shift."),
	tip("tip_02", "controls", "Class skills are 1 and 2. The ultimate is F."),
	tip("tip_03", "controls", "The Roll tab is T. R stays the heavy attack."),
	tip("tip_04", "controls", "Hotkeys: Hero C, Bag B, Pets P, Raids I, Market M."),
	tip("tip_05", "controls", "Esc closes the hub. Controller B closes it too."),
	tip("tip_06", "controls", "Red marks are dodged. Blue marks are interrupted."),
	tip("tip_07", "controls", "Controller heavy is ButtonX. Keyboard heavy stays R."),
	tip("tip_08", "controls", "Menu hotkeys can change in Settings. Combat keys stay put."),
	tip("tip_09", "controls", "WASD moves you. Space jumps."),
	tip("tip_10", "controls", "Hide HUD, UI scale, and damage numbers are in Settings."),
	tip("tip_11", "rolls", "One crack spends one Shard Token. Tokens are earned."),
	tip("tip_12", "rolls", "Prism Tokens are bought. They are not Shard Tokens."),
	tip("tip_13", "rolls", "Every 10th crack has x2 luck. It is still one crack."),
	tip("tip_14", "rolls", "The odds line includes luck. Pity sits outside those percents."),
	tip("tip_15", "rolls", "When the bonus is next, the label reads x2 Luck Ready."),
	tip("tip_16", "rolls", "Auto cracks again until you turn it off or Stop at hits."),
	tip("tip_17", "rolls", "Quick shortens the reveal. It does not change the odds."),
	tip("tip_18", "rolls", "Info shows the odds. The card tint is the real rarity."),
	tip("tip_19", "rolls", "At x1 luck, Common reads 1 in 2. Mythic reads 1 in 25000."),
	tip("tip_20", "rolls", "Stop at halts Auto on a rarity. It does not change the draw."),
	tip(
		"tip_21",
		"pity",
		"The pity line shows Epic progress out of 100 and Legendary out of 1000."
	),
	tip("tip_22", "pity", "When Epic pity shows 99/100, the next crack is at least Epic."),
	tip("tip_23", "pity", "At 999/1000 Legendary pity, the next crack is Legendary or better."),
	tip("tip_24", "pity", "An Epic or better resets the Epic pity counter."),
	tip("tip_25", "pity", "A Legendary or better resets both Armory pity counters."),
	tip("tip_26", "pity", "Rare has no Armory countdown. Next Epic is the real remainder."),
	tip("tip_27", "pity", "Chest pity is a different counter from Armory pity."),
	tip("tip_28", "pity", "A Rare chest reaches Epic or better by 20 opens with no Epic."),
	tip("tip_29", "pity", "An Epic chest reaches Legendary by 15 opens with none."),
	tip("tip_30", "pity", "The guarantee shows the rarity you received. It is not a fake tint."),
	tip("tip_31", "raids", "The Heartwood is the raid. Rootvault is the dungeon."),
	tip("tip_32", "raids", "Heartwood Story and Normal are both level 15."),
	tip("tip_33", "raids", "A Story clear pays 25 Raid Marks. Normal pays 40."),
	tip("tip_34", "raids", "Marks earned this week cap at 600. The wallet does not reset."),
	tip("tip_35", "raids", "Heartwood Student costs 200 Raid Marks at the vendor."),
	tip(
		"tip_36",
		"raids",
		"Wings: Thornwarden Twins, Mother Sapwell, Galecrown, Grandmother Gnarl Awakened."
	),
	tip("tip_37", "raids", "A Heartwood party needs 4 players. Practice Grove is the solo path."),
	tip("tip_38", "raids", "Warden can tank. Tidecaller can heal. Any class can be DPS."),
	tip("tip_39", "raids", "Practice Grove is free and pays no loot."),
	tip("tip_40", "raids", "Each boss rolls loot once per difficulty each week. Marks still pay."),
	tip("tip_41", "pets", "Hatching spends an egg, or 50 gold if you have no egg."),
	tip("tip_42", "pets", "Eight pets can hatch, from Ember Fox through Bark Owl."),
	tip("tip_43", "pets", "Affinity and Bond are separate. Each one caps at 5."),
	tip("tip_44", "pets", "Petting raises Affinity by 1, up to 5."),
	tip("tip_45", "pets", "Feeding adds 25 pet XP. Each level costs 50 XP, up to 50."),
	tip("tip_46", "pets", "Hidden pet combos cap at 3. A fourth does not fire."),
	tip("tip_47", "pets", "A favorite pet cannot be fused."),
	tip("tip_48", "pets", "Fusion stays on one species and adds a Bond star, up to 5."),
	tip("tip_49", "pets", "A combo needs its listed pet, and sometimes a class or item."),
	tip("tip_50", "pets", "An egg in your bag shows a dot on Pets."),
	tip("tip_51", "crafting", "A Healing Tonic takes 1 Spore Cap and 1 Living Vine."),
	tip("tip_52", "crafting", "A Healing Tonic restores 40% of your max HP."),
	tip("tip_53", "crafting", "Briar Edge forges a Thorn Dagger: 4 Verdant Wood, 2 Living Vine."),
	tip("tip_54", "crafting", "Thornbound Blade needs Crafting Level 10 and a Thornbound Scroll."),
	tip("tip_55", "crafting", "The Thornbound Scroll is not spent when you craft the blade."),
	tip("tip_56", "crafting", "Wild Resin rerolls one trait on a Rare or better weapon or armor."),
	tip("tip_57", "crafting", "Iron weapons are forged from Verdant Bark."),
	tip("tip_58", "crafting", "An Uncommon chest is 40 Shard Keys. A Rare chest is 150."),
	tip("tip_59", "crafting", "An Epic chest is 600 Shard Keys. Legendary chests are not sold."),
	tip("tip_60", "crafting", "Duplicates can pay Dust. A higher rarity pays more Dust."),
})

local COUNT = #LoadingTips.TIPS
LoadingTips.COUNT = COUNT

local function whole(step: any): number?
	if type(step) ~= "number" then
		return nil
	end
	if step ~= step or step == math.huge or step == -math.huge then
		return nil
	end
	if step < 0 or step % 1 ~= 0 then
		return nil
	end
	return step
end

function LoadingTips.line(step: any, _context: any?): Tip?
	local index = whole(step)
	if index == nil or COUNT <= 0 then
		return nil
	end
	return LoadingTips.TIPS[(index % COUNT) + 1]
end

return LoadingTips
