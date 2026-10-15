--!strict

--[[
	Roll areas. One area is one Crack button and its own odds.

	Armory rolls weapons and armor. Pets rolls companions. Each area has one
	pool per ascension tier. Areas.pools lists them in ascension order. The
	server refuses a pool above the player's ascension; the panel only offers
	pools Pools.isUnlocked allows.

	A new realm is a pair of pools in Pools.luau (one armory, one pets) plus
	the items in ItemBases.luau. This file does not need a new row unless you
	add a third area.
]]

local Pools = require("./Pools")

local Areas = {}

export type Area = {
	id: string,
	name: string,
	summary: string,
}

local definitions = {
	{
		id = "armory",
		name = "Armory",
		summary = "Weapons and armor",
	},
	{
		id = "pets",
		name = "Pets",
		summary = "Companions",
	},
}

function Areas.all(): { Area }
	local result = {}
	for _, definition in ipairs(definitions) do
		if #Pools.forArea(definition.id) > 0 then
			table.insert(result, {
				id = definition.id,
				name = definition.name,
				summary = definition.summary,
			})
		end
	end
	return result
end

function Areas.get(areaId: string): Area?
	for _, area in ipairs(Areas.all()) do
		if area.id == areaId then
			return area
		end
	end
	return nil
end

function Areas.pools(areaId: string)
	return Pools.forArea(areaId)
end

for _, definition in ipairs(definitions) do
	table.freeze(definition)
end
table.freeze(definitions)

return Areas
