--!strict

--[[
	Feed checks. Pure: it reads the profile and does not write it.
	It does not read item.upgrade. A pet is not a weapon.
]]

local Validate = {}

Validate.OFF = "Shard Core is off."
Validate.SLOW = "Slow down a moment."
Validate.PROFILE = "Profile is not loaded."
Validate.UPDATE = "Could not update your profile."
Validate.ID = "Unknown weapon."
Validate.MISSING = "You do not have that item."
Validate.WEAPON = "Only a weapon has a Shard Core."
Validate.CAP = "That core is at its cap."
Validate.ESSENCE = "Not enough Essence."

function Validate.feed(profile: any, itemId: any, config: any): string?
	if type(profile) ~= "table" or type(config) ~= "table" then
		return Validate.PROFILE
	end
	if type(config.validId) ~= "function" or config.validId(itemId) ~= true then
		return Validate.ID
	end
	local bag = profile.inventory
	if type(bag) ~= "table" or type(bag[itemId]) ~= "table" then
		return Validate.MISSING
	end
	local item = bag[itemId]
	if item.kind ~= "Weapon" then
		return Validate.WEAPON
	end
	local level = 0
	if type(config.levelOf) == "function" then
		level = config.levelOf(profile, itemId)
	end
	local cost = nil
	if type(config.costToNext) == "function" then
		cost = config.costToNext(level)
	end
	if type(cost) ~= "number" then
		return Validate.CAP
	end
	local essence = 0
	if type(config.essenceOf) == "function" then
		essence = config.essenceOf(profile)
	end
	if type(essence) ~= "number" or essence < cost then
		return Validate.ESSENCE
	end
	return nil
end

return Validate
