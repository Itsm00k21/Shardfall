--!strict

--[[
	Pet evolution.

	A companion evolves at level 25 and again at level 50 when the den
	has the realm materials on its recipe. The personal name, journal,
	Affinity, Bond, favorite lock, colors, and uid stay. The species,
	display name, and ability id change.

	Pets.luau and PetService.luau stay the hatchery. This module only
	reads the companion shape they already save. WildCaptureService.evolve
	is the server call that spends the materials.
]]

local Materials = require("./Materials")

local PetEvolution = {}

export type Cost = {
	id: string,
	count: number,
}

export type Step = {
	from: string,
	level: number,
	species: string,
	displayName: string,
	ability: string,
	role: string,
	rarity: string,
	materials: { Cost },
}

PetEvolution.LEVELS = { 25, 50 }

local function cost(id: string, count: number): Cost
	return { id = id, count = count }
end

-- Verdant chains. Each row is the next form, not a skip.
PetEvolution.STEPS = {
	{
		from = "ember_fox",
		level = 25,
		species = "blaze_fox",
		displayName = "Blaze Fox",
		ability = "blaze_bite",
		role = "Striker",
		rarity = "Rare",
		materials = {
			cost("heartwood", 4),
			cost("verdant_bark", 8),
			cost("vine", 6),
		},
	},
	{
		from = "blaze_fox",
		level = 50,
		species = "inferno_kitsune",
		displayName = "Inferno Kitsune",
		ability = "inferno_pounce",
		role = "Striker",
		rarity = "Epic",
		materials = {
			cost("gnarl_seed", 1),
			cost("heartwood", 8),
			cost("bark", 10),
		},
	},
	{
		from = "mossback",
		level = 25,
		species = "ridgeback",
		displayName = "Ridgeback",
		ability = "ridge_guard",
		role = "Guardian",
		rarity = "Rare",
		materials = {
			cost("bark", 8),
			cost("verdant_bark", 6),
			cost("wood", 8),
		},
	},
	{
		from = "ridgeback",
		level = 50,
		species = "elder_mossback",
		displayName = "Elder Mossback",
		ability = "canopy_aegis",
		role = "Guardian",
		rarity = "Epic",
		materials = {
			cost("heartwood", 6),
			cost("gnarl_seed", 1),
			cost("spore", 8),
		},
	},
	{
		from = "root_mole",
		level = 25,
		species = "burrow_mole",
		displayName = "Burrow Mole",
		ability = "deep_dig",
		role = "Gatherer",
		rarity = "Rare",
		materials = {
			cost("wood", 12),
			cost("vine", 6),
			cost("spore", 4),
		},
	},
	{
		from = "burrow_mole",
		level = 50,
		species = "den_architect",
		displayName = "Den Architect",
		ability = "vault_harvest",
		role = "Gatherer",
		rarity = "Epic",
		materials = {
			cost("heartwood", 6),
			cost("bark", 8),
			cost("verdant_bark", 8),
		},
	},
} :: { Step }

local byFrom: { [string]: Step } = {}
for _, step in ipairs(PetEvolution.STEPS) do
	byFrom[step.from] = step
	for _, row in ipairs(step.materials) do
		table.freeze(row)
	end
	table.freeze(step.materials)
	table.freeze(step)
end
table.freeze(PetEvolution.STEPS)

function PetEvolution.next(species: string): Step?
	return byFrom[species]
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function levelOf(pet: any): number
	local level = pet.level
	if type(level) ~= "number" or level ~= level then
		return 1
	end
	return math.floor(level)
end

local function owned(materials: any, id: string): number
	if type(materials) ~= "table" then
		return 0
	end
	local count = materials[id]
	if type(count) ~= "number" or count ~= count or count <= 0 then
		return 0
	end
	return count
end

local function missingLine(step: Step, materials: any): string?
	local missing = {}
	for _, row in ipairs(step.materials) do
		if owned(materials, row.id) < row.count then
			table.insert(missing, string.format("%d %s", row.count, Materials.displayName(row.id)))
		end
	end
	if #missing == 0 then
		return nil
	end
	if #missing == 1 then
		return "Need " .. missing[1] .. "."
	end
	local last = table.remove(missing)
	if last == nil then
		return nil
	end
	if #missing == 1 then
		return "Need " .. missing[1] .. " and " .. last .. "."
	end
	return "Need " .. table.concat(missing, ", ") .. ", and " .. last .. "."
end

local function stepFor(pet: any): (Step?, string)
	if type(pet) ~= "table" or type(pet.species) ~= "string" then
		return nil, "That companion cannot evolve."
	end
	local step = byFrom[pet.species]
	if step == nil then
		return nil, "That companion cannot evolve."
	end
	return step, ""
end

function PetEvolution.canEvolve(pet: any, materials: any): (boolean, string)
	local step, err = stepFor(pet)
	if step == nil then
		return false, err
	end
	if levelOf(pet) < step.level then
		return false, string.format("Reach level %d to evolve.", step.level)
	end
	local need = missingLine(step, materials)
	if need ~= nil then
		return false, need
	end
	return true, "Ready to evolve."
end

function PetEvolution.evolve(
	pet: any,
	materials: any
): (boolean, string, any?, { [string]: number }?)
	local ok, reason = PetEvolution.canEvolve(pet, materials)
	if not ok then
		return false, reason, nil, nil
	end
	local species = pet.species
	if type(species) ~= "string" then
		return false, "That companion cannot evolve.", nil, nil
	end
	local step = byFrom[species]
	if step == nil then
		return false, "That companion cannot evolve.", nil, nil
	end
	local nextPet = deepCopy(pet)
	nextPet.species = step.species
	nextPet.speciesName = step.displayName
	nextPet.ability = step.ability
	nextPet.role = step.role
	nextPet.rarity = step.rarity
	if type(nextPet.journal) ~= "table" then
		nextPet.journal = {}
	end
	table.insert(nextPet.journal, "Evolved to " .. step.displayName)
	local spent: { [string]: number } = {}
	for _, row in ipairs(step.materials) do
		spent[row.id] = row.count
	end
	return true, "Evolved to " .. step.displayName, nextPet, spent
end

return PetEvolution
