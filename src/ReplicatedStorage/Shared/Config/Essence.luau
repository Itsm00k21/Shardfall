--!strict

--[[
	Essence paid for salvaged gear, and for a capped duplicate that calls
	GearSalvage.grant. One table.

	The numbers match the overflow record on #387 (GearLevels.ESSENCE):
	live Shard Dust / 5, with Mythic and Secret folded to Legendary.
	#387 is being revised (issue #15, comment 6358371837). Dupes may grant
	stars. These salvage amounts do not depend on that.

	CAP is the same 1_000_000_000 clamp #387 puts on profile.gearEssence.
	There is no second wallet and nothing here costs Robux.
]]

local Essence = {}

Essence.CAP = 1000000000

Essence.AMOUNT = table.freeze({
	Common = 1,
	Uncommon = 3,
	Rare = 10,
	Epic = 40,
	Legendary = 200,
	Mythic = 200,
	Secret = 200,
})

function Essence.amount(rarity: any): number?
	if type(rarity) ~= "string" then
		return nil
	end
	local value = Essence.AMOUNT[rarity]
	if type(value) ~= "number" or value ~= value or value < 1 or value >= math.huge then
		return nil
	end
	return math.floor(value)
end

return table.freeze(Essence)
