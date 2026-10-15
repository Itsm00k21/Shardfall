--!strict

--[[
	Weapon traits rolled onto a shard drop.

	Add a row to `list` to add a trait. RollMath calls Traits.roll for weapons
	and armor, and Traits.rollPet for pets. Both draw from the same four
	definitions. The pet list is ordered so a minimum roll takes Bonus Pet
	Damage first. Values are rolled uniformly between min and max. "percent"
	is stored as a fraction (0.05 = 5%) and "count" is an integer.
	PLACEHOLDER ranges.

	Combat reads Lifesteal on the swing that owns it (a weapon heals the
	player's hits; a pet heals the pet's hits) and Gold Find (extra gold on
	a dungeon clear, including a pet's Gold Find). Bonus Pet Damage multiplies
	the equipped pet's Pet Damage. Chain Lightning is stored and shown, not
	simulated. Wild Resin calls Traits.pick, which stays on the gear list.
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

local function traitById(id: string): TraitDefinition
	for _, row in ipairs(Traits.list) do
		if row.id == id then
			return row
		end
	end
	error("Missing trait '" .. id .. "'", 2)
end

-- Same traits as gear. Bonus Pet Damage is first so a Rare pet's one slot,
-- and a zero roll, lands on the bonus combat already applies.
Traits.pets = {
	traitById("bonus_pet_damage"),
	traitById("lifesteal"),
	traitById("gold_find"),
	traitById("chain_lightning"),
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

local function rollValue(picked: TraitDefinition, rng: Rng): number
	if picked.unit == "count" then
		return rng:nextInteger(picked.min, picked.max)
	end
	local alpha = rng:nextNumber()
	return picked.min + (picked.max - picked.min) * alpha
end

-- Rolls `slots` distinct traits from `list`. The rarity's slot count comes
-- from Rarities. Common and Uncommon have zero slots.
local function rollFrom(list: { TraitDefinition }, rarity: string, rng: Rng): { RolledTrait }
	local slots = Rarities.TRAIT_SLOTS[rarity]
	if slots == nil then
		error("Unknown rarity '" .. rarity .. "'", 2)
	end
	if slots <= 0 then
		return {}
	end

	local bag = table.clone(list)
	local rolled = {}
	local picks = math.min(slots, #bag)
	for _ = 1, picks do
		local index = rng:nextInteger(1, #bag)
		local picked = table.remove(bag, index)
		if picked == nil then
			break
		end
		local value = rollValue(picked, rng)
		table.insert(rolled, {
			id = picked.id,
			name = picked.name,
			value = value,
			unit = picked.unit,
			display = Traits.format(picked.unit, value),
		})
	end
	return rolled
end

function Traits.roll(rarity: string, rng: Rng): { RolledTrait }
	return rollFrom(Traits.list, rarity, rng)
end

function Traits.rollPet(rarity: string, rng: Rng): { RolledTrait }
	return rollFrom(Traits.pets, rarity, rng)
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
	local picked = bag[index]
	local value = rollValue(picked, rng)
	return {
		id = picked.id,
		name = picked.name,
		value = value,
		unit = picked.unit,
		display = Traits.format(picked.unit, value),
	}
end

table.freeze(Traits.list)
table.freeze(Traits.pets)
for _, row in ipairs(Traits.list) do
	table.freeze(row)
end

return Traits
