--!strict

--[[
	Verdant pets for the beta.

	Eggs hatch into one of eight companions. Bond stars and Affinity are
	separate. Favorites cannot be fused. Hidden combos are small and cap
	at three.
]]

local Pets = {}

Pets.EGG_COST = 50
Pets.AFFINITY_MAX = 5
Pets.BOND_MAX = 5
Pets.COMBO_CAP = 3

Pets.SPECIES = {
	{
		id = "ember_fox",
		name = "Ember Fox",
		rarity = "Common",
		role = "Striker",
		personality = "Brave",
	},
	{
		id = "mossback",
		name = "Mossback Turtle",
		rarity = "Uncommon",
		role = "Guardian",
		personality = "Loyal",
	},
	{
		id = "tide_sprite",
		name = "Tide Sprite",
		rarity = "Uncommon",
		role = "Mender",
		personality = "Playful",
	},
	{
		id = "root_mole",
		name = "Root Mole",
		rarity = "Common",
		role = "Gatherer",
		personality = "Curious",
	},
	{
		id = "void_moth",
		name = "Void Moth",
		rarity = "Rare",
		role = "Hexer",
		personality = "Grumpy",
	},
	{
		id = "fern_stag",
		name = "Fern Stag",
		rarity = "Rare",
		role = "Striker",
		personality = "Brave",
	},
	{
		id = "pollen_wisp",
		name = "Pollen Wisp",
		rarity = "Epic",
		role = "Mender",
		personality = "Lazy",
	},
	{
		id = "bark_owl",
		name = "Bark Owl",
		rarity = "Epic",
		role = "Hexer",
		personality = "Curious",
	},
}

Pets.COMBOS = {
	{
		id = "fox_gold",
		needs = { pet = "ember_fox", item = "relic" },
		bonus = "gold",
		amount = 0.1,
	},
	{
		id = "mole_mats",
		needs = { pet = "root_mole", item = "verdant_ring" },
		bonus = "materials",
		amount = 0.15,
	},
	{
		id = "sprite_tide",
		needs = { pet = "tide_sprite", classId = "tidecaller" },
		bonus = "heal",
		amount = 0.1,
	},
	{
		id = "turtle_warden",
		needs = { pet = "mossback", classId = "warden" },
		bonus = "taunt",
		amount = 0.1,
	},
	{
		id = "eclipse",
		needs = { pet = "bark_owl", other = "void_moth" },
		bonus = "xp",
		amount = 0.08,
	},
}

local byId = {}
for _, row in ipairs(Pets.SPECIES) do
	byId[row.id] = row
end

function Pets.get(id: string)
	return byId[id]
end

function Pets.hatch(roll: number)
	local index = math.clamp(math.floor(roll * #Pets.SPECIES) + 1, 1, #Pets.SPECIES)
	local species = Pets.SPECIES[index]
	return {
		species = species.id,
		name = species.name,
		role = species.role,
		rarity = species.rarity,
		personality = species.personality,
		level = 1,
		xp = 0,
		bond = 1,
		affinity = 1,
		favorite = false,
		colors = { primary = "verdant", secondary = "sap", glow = "none" },
		journal = { "Hatched" },
	}
end

function Pets.pet(dataPet: any)
	if type(dataPet) ~= "table" then
		return false
	end
	dataPet.affinity = math.min(Pets.AFFINITY_MAX, (dataPet.affinity or 1) + 1)
	return true
end

function Pets.feed(dataPet: any)
	if type(dataPet) ~= "table" then
		return false
	end
	dataPet.xp = (dataPet.xp or 0) + 25
	local level = dataPet.level or 1
	while dataPet.xp >= 50 and level < 50 do
		dataPet.xp -= 50
		level += 1
	end
	dataPet.level = level
	dataPet.affinity = math.min(Pets.AFFINITY_MAX, (dataPet.affinity or 1))
	return true
end

function Pets.bond(keeper: any, feeder: any): (boolean, string)
	if type(keeper) ~= "table" or type(feeder) ~= "table" then
		return false, "Pick two pets."
	end
	if keeper.favorite == true or feeder.favorite == true then
		return false, "A favorite cannot be fused."
	end
	if keeper.species ~= feeder.species then
		return false, "Fusion keeps the same species."
	end
	if (keeper.bond or 1) >= Pets.BOND_MAX then
		return false, "Already at five Bond stars."
	end
	keeper.bond = (keeper.bond or 1) + 1
	if keeper.bond >= 3 and type(keeper.journal) == "table" then
		table.insert(keeper.journal, "Second passive")
	end
	return true, "Bond star " .. tostring(keeper.bond)
end

function Pets.colors(dataPet: any, primary: string, secondary: string, glow: string): boolean
	if type(dataPet) ~= "table" then
		return false
	end
	dataPet.colors = {
		primary = primary,
		secondary = secondary,
		glow = glow,
	}
	return true
end

function Pets.combos(speciesIds: { string }, classId: string?, hasRelic: boolean, hasRing: boolean)
	local found = {}
	local have = {}
	for _, id in ipairs(speciesIds) do
		have[id] = true
	end
	for _, combo in ipairs(Pets.COMBOS) do
		local needs = combo.needs
		local ok = have[needs.pet] == true
		if needs.other ~= nil and have[needs.other] ~= true then
			ok = false
		end
		if needs.classId ~= nil and needs.classId ~= classId then
			ok = false
		end
		if needs.item == "relic" and not hasRelic then
			ok = false
		end
		if needs.item == "verdant_ring" and not hasRing then
			ok = false
		end
		if ok then
			table.insert(found, combo.id)
		end
		if #found >= Pets.COMBO_CAP then
			break
		end
	end
	return found
end

return Pets
