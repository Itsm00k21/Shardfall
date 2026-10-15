--!strict

--[[
	Weapon traits rolled onto a shard drop.

	Add a row to `list` to add a trait. RollMath calls Traits.roll for weapons
	and armor. Pets roll none. Values are rolled uniformly between min and
	max. "percent" is stored as a fraction (0.05 = 5%) and "count" is an
	integer. PLACEHOLDER ranges.

	Combat reads Lifesteal (heal for that fraction of damage dealt) and
	Gold Find (extra gold on a dungeon clear). Chain Lightning and Bonus Pet
	Damage are stored for later. Wild Resin calls Traits.pick to replace one
	trait.
]]

local Rarities = require("./Rarities")

local Traits = {}

export type TraitDefinition = {
	id: string,
	name: string,
	unit: "percent" | "count",
	min: number,
	max: number,
}

export type RolledTrait = {
	id: string,
	name: string,
	value: number,
	unit: string,
	display: string,
}

export type Rng = {
	nextNumber: (self: Rng) -> number,
	nextInteger: (self: Rng, min: number, max: number) -> number,
}

Traits.list = {
	{
		id = "lifesteal",
		name = "Lifesteal",
		unit = "percent",
		min = 0.02,
		max = 0.08,
	},
	{
		id = "chain_lightning",
		name = "Chain Lightning",
		unit = "count",
		min = 1,
		max = 3,
	},
	{
		id = "bonus_pet_damage",
		name = "Bonus Pet Damage",
		unit = "percent",
		min = 0.05,
		max = 0.20,
	},
	{
		id = "gold_find",
		name = "Gold Find",
		unit = "percent",
		min = 0.05,
		max = 0.15,
	},
} :: { TraitDefinition }

function Traits.format(unit: string, value: number): string
	if unit == "percent" then
		return string.format("%.1f%%", value * 100)
	end
	return tostring(value)
end

function Traits.isKnown(id: string): boolean
	for _, definition in ipairs(Traits.list) do
		if definition.id == id then
			return true
		end
	end
	return false
end

-- Rolls `slots` distinct traits. The rarity's slot count comes from Rarities.
function Traits.roll(rarity: string, rng: Rng): { RolledTrait }
	local slots = Rarities.TRAIT_SLOTS[rarity]
	if slots == nil then
		error("Unknown rarity '" .. rarity .. "'", 2)
	end
	if slots <= 0 then
		return {}
	end

	local bag = table.clone(Traits.list)
	local rolled = {}
	local picks = math.min(slots, #bag)
	for _ = 1, picks do
		local index = rng:nextInteger(1, #bag)
		local definition = table.remove(bag, index)
		if definition == nil then
			break
		end
		local value: number
		if definition.unit == "count" then
			value = rng:nextInteger(definition.min, definition.max)
		else
			local alpha = rng:nextNumber()
			value = definition.min + (definition.max - definition.min) * alpha
		end
		table.insert(rolled, {
			id = definition.id,
			name = definition.name,
			value = value,
			unit = definition.unit,
			display = Traits.format(definition.unit, value),
		})
	end
	return rolled
end

local function rollValue(definition: TraitDefinition, rng: Rng): number
	if definition.unit == "count" then
		return rng:nextInteger(definition.min, definition.max)
	end
	local alpha = rng:nextNumber()
	return definition.min + (definition.max - definition.min) * alpha
end

-- One trait, skipping ids in `banned` when another trait can replace them.
-- Used by the Wild Resin craft, which rerolls a single slot.
function Traits.pick(rng: Rng, banned: { [string]: boolean }?): RolledTrait
	local blocked = banned or {}
	local bag = {}
	for _, definition in ipairs(Traits.list) do
		if blocked[definition.id] ~= true then
			table.insert(bag, definition)
		end
	end
	if #bag == 0 then
		for _, definition in ipairs(Traits.list) do
			table.insert(bag, definition)
		end
	end
	local index = rng:nextInteger(1, #bag)
	local definition = bag[index]
	local value = rollValue(definition, rng)
	return {
		id = definition.id,
		name = definition.name,
		value = value,
		unit = definition.unit,
		display = Traits.format(definition.unit, value),
	}
end

table.freeze(Traits.list)
for _, definition in ipairs(Traits.list) do
	table.freeze(definition)
end

return Traits
