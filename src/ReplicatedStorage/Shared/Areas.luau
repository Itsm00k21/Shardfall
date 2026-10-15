--!strict

--[[
	Roll areas. One area is one Crack button and one disclosed odds table.

	The starter area still rolls starter_shard, which mixes weapons, pets,
	and materials. Splitting that later (one area for weapons and armor, one
	for pets) means:

	  1. Add a pool in Pools.luau.
	  2. Add a row to `definitions` below.

	Areas.all() is what the client lists. With one public area the panel
	does not show a picker. With two or more, it does. Do not hard-code the
	starter id in the UI.
]]

local Pools = require("./Pools")

local Areas = {}

export type Area = {
	id: string,
	name: string,
	poolId: string,
	summary: string,
	pityLegendaryAt: number,
}

local definitions = {
	{
		id = "starter",
		name = "Starter Shard",
		poolId = Pools.STARTER_ID,
		summary = "Weapons, pets, and materials",
	},
}

local function publish(definition): Area?
	local pool = Pools.get(definition.poolId)
	if pool == nil or pool.public ~= true then
		return nil
	end
	return {
		id = definition.id,
		name = definition.name,
		poolId = definition.poolId,
		summary = definition.summary,
		pityLegendaryAt = pool.pityLegendaryAt,
	}
end

function Areas.all(): { Area }
	local result = {}
	for _, definition in ipairs(definitions) do
		local area = publish(definition)
		if area ~= nil then
			table.insert(result, area)
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

for _, definition in ipairs(definitions) do
	table.freeze(definition)
end
table.freeze(definitions)

return Areas
