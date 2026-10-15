--!strict

--[[
	Stackable materials and the healing tonic.

	Dungeon clears add these counts. Crafting spends them. They are not
	unique items: two pieces of Verdant Wood are just `materials.wood = 2`.
	Gear stays in the inventory, with its own rolled stats.
]]

local Materials = {}

Materials.ORDER = { "wood", "vine", "spore", "bark", "heartwood" }

Materials.DEFS = {
	wood = { name = "Verdant Wood" },
	vine = { name = "Living Vine" },
	spore = { name = "Spore Cap" },
	bark = { name = "Ironbark" },
	heartwood = { name = "Heartwood" },
}

Materials.TONIC_ID = "healing_tonic"
Materials.TONIC_NAME = "Healing Tonic"
-- Fraction of max HP restored by one tonic. 0.4 is 40%.
Materials.TONIC_HEAL = 0.4
Materials.TONIC_CAP = 20

Materials.VOUCHER_AREAS = { "armory", "pets" }

function Materials.displayName(id: string): string
	local definition = Materials.DEFS[id]
	if definition == nil then
		return id
	end
	return definition.name
end

function Materials.empty(): { [string]: number }
	local counts = {}
	for _, id in ipairs(Materials.ORDER) do
		counts[id] = 0
	end
	return counts
end

function Materials.sanitize(source: any): { [string]: number }
	local counts = Materials.empty()
	if type(source) ~= "table" then
		return counts
	end
	for _, id in ipairs(Materials.ORDER) do
		local numberValue = tonumber(source[id])
		if numberValue == nil or numberValue ~= numberValue or numberValue < 0 then
			counts[id] = 0
		else
			counts[id] = math.floor(numberValue)
		end
	end
	return counts
end

function Materials.sanitizeCounts(source: any, keys: { string }): { [string]: number }
	local counts = {}
	for _, id in ipairs(keys) do
		local numberValue = if type(source) == "table" then tonumber(source[id]) else nil
		if numberValue == nil or numberValue ~= numberValue or numberValue < 0 then
			counts[id] = 0
		else
			counts[id] = math.floor(numberValue)
		end
	end
	return counts
end

for _, definition in pairs(Materials.DEFS) do
	table.freeze(definition)
end
table.freeze(Materials.DEFS)
table.freeze(Materials.ORDER)
table.freeze(Materials.VOUCHER_AREAS)

return Materials
