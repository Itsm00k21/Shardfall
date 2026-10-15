--!strict

--[[
	Stackable materials and the healing tonic.

	Dungeon clears still pay the original Verdant forage (wood, vine, spore,
	bark, heartwood). Phase 1 adds one common, one rare, and one boss material
	per realm. Heartwood is the Verdant rare. Kill drops and salvage use the
	primary row for that realm and grade. Counts clamp to `stack`.
]]

local Materials = {}

export type Grade = "common" | "rare" | "boss" | "scroll"

export type Def = {
	name: string,
	realm: string,
	grade: Grade,
	color: { number },
	stack: number,
	primary: boolean,
}

Materials.REALMS = { "Verdant Wilds", "Sunken Reach", "Emberforge", "Frostveil", "Void Rift" }

Materials.ORDER = {
	"wood",
	"vine",
	"spore",
	"bark",
	"heartwood",
	"verdant_bark",
	"gnarl_seed",
	"scroll_thornbound",
	"coral_shard",
	"black_pearl",
	"leviathan_scale",
	"cinder_ore",
	"molten_core",
	"tyrant_heart",
	"frost_pelt",
	"everfrost_gem",
	"matriarch_fang",
	"void_dust",
	"rift_eye",
	"hollow_core",
}

Materials.DEFS = {
	wood = {
		name = "Verdant Wood",
		realm = "Verdant Wilds",
		grade = "common",
		color = { 120, 150, 70 },
		stack = 999,
		primary = false,
	},
	vine = {
		name = "Living Vine",
		realm = "Verdant Wilds",
		grade = "common",
		color = { 72, 160, 90 },
		stack = 999,
		primary = false,
	},
	spore = {
		name = "Spore Cap",
		realm = "Verdant Wilds",
		grade = "common",
		color = { 156, 96, 210 },
		stack = 999,
		primary = false,
	},
	bark = {
		name = "Ironbark",
		realm = "Verdant Wilds",
		grade = "common",
		color = { 110, 84, 58 },
		stack = 999,
		primary = false,
	},
	heartwood = {
		name = "Heartwood",
		realm = "Verdant Wilds",
		grade = "rare",
		color = { 196, 120, 64 },
		stack = 999,
		primary = true,
	},
	verdant_bark = {
		name = "Verdant Bark",
		realm = "Verdant Wilds",
		grade = "common",
		color = { 86, 140, 72 },
		stack = 999,
		primary = true,
	},
	gnarl_seed = {
		name = "Gnarl's Seed",
		realm = "Verdant Wilds",
		grade = "boss",
		color = { 48, 110, 56 },
		stack = 99,
		primary = true,
	},
	scroll_thornbound = {
		name = "Thornbound Scroll",
		realm = "Verdant Wilds",
		grade = "scroll",
		color = { 220, 186, 96 },
		stack = 1,
		primary = true,
	},
	coral_shard = {
		name = "Coral Shard",
		realm = "Sunken Reach",
		grade = "common",
		color = { 80, 170, 186 },
		stack = 999,
		primary = true,
	},
	black_pearl = {
		name = "Black Pearl",
		realm = "Sunken Reach",
		grade = "rare",
		color = { 48, 90, 120 },
		stack = 999,
		primary = true,
	},
	leviathan_scale = {
		name = "Leviathan Crown-Scale",
		realm = "Sunken Reach",
		grade = "boss",
		color = { 36, 70, 130 },
		stack = 99,
		primary = true,
	},
	cinder_ore = {
		name = "Cinder Ore",
		realm = "Emberforge",
		grade = "common",
		color = { 196, 96, 48 },
		stack = 999,
		primary = true,
	},
	molten_core = {
		name = "Molten Core",
		realm = "Emberforge",
		grade = "rare",
		color = { 230, 120, 40 },
		stack = 999,
		primary = true,
	},
	tyrant_heart = {
		name = "Tyrant's Ember Heart",
		realm = "Emberforge",
		grade = "boss",
		color = { 180, 40, 30 },
		stack = 99,
		primary = true,
	},
	frost_pelt = {
		name = "Frost Pelt",
		realm = "Frostveil",
		grade = "common",
		color = { 186, 220, 236 },
		stack = 999,
		primary = true,
	},
	everfrost_gem = {
		name = "Everfrost Gem",
		realm = "Frostveil",
		grade = "rare",
		color = { 120, 180, 230 },
		stack = 999,
		primary = true,
	},
	matriarch_fang = {
		name = "Matriarch's Frozen Fang",
		realm = "Frostveil",
		grade = "boss",
		color = { 90, 140, 210 },
		stack = 99,
		primary = true,
	},
	void_dust = {
		name = "Void Dust",
		realm = "Void Rift",
		grade = "common",
		color = { 140, 90, 200 },
		stack = 999,
		primary = true,
	},
	rift_eye = {
		name = "Rift Eye",
		realm = "Void Rift",
		grade = "rare",
		color = { 170, 80, 220 },
		stack = 999,
		primary = true,
	},
	hollow_core = {
		name = "Sovereign's Hollow Core",
		realm = "Void Rift",
		grade = "boss",
		color = { 80, 40, 140 },
		stack = 99,
		primary = true,
	},
} :: { [string]: Def }

Materials.TONIC_ID = "healing_tonic"
Materials.TONIC_NAME = "Healing Tonic"
-- Fraction of max HP restored by one tonic. 0.4 is 40%.
Materials.TONIC_HEAL = 0.4
Materials.TONIC_CAP = 20

Materials.VOUCHER_AREAS = { "armory", "pets" }

local REALM_BY_ASCENSION = {
	[0] = "Verdant Wilds",
	[1] = "Sunken Reach",
	[2] = "Emberforge",
	[3] = "Frostveil",
	[4] = "Void Rift",
}

-- Grade shown with the same colors as gear rarity. Boss materials use
-- Legendary gold. Scrolls use Epic.
local GRADE_RARITY: { [string]: string } = {
	common = "Common",
	rare = "Rare",
	boss = "Legendary",
	scroll = "Epic",
}

function Materials.displayName(id: string): string
	local definition = Materials.DEFS[id]
	if definition == nil then
		return id
	end
	return definition.name
end

function Materials.realmForAscension(ascension: any): string
	local level = ascension
	if type(level) ~= "number" or level ~= level then
		level = 0
	end
	local realm = REALM_BY_ASCENSION[math.floor(level)]
	if realm == nil then
		return "Verdant Wilds"
	end
	return realm
end

-- The salvage and drop row for a realm. Legacy forage is not primary.
function Materials.primary(realm: string, grade: Grade): string?
	for _, id in ipairs(Materials.ORDER) do
		local definition = Materials.DEFS[id]
		if
			definition.primary == true
			and definition.realm == realm
			and definition.grade == grade
		then
			return id
		end
	end
	return nil
end

function Materials.empty(): { [string]: number }
	local counts = {}
	for _, id in ipairs(Materials.ORDER) do
		counts[id] = 0
	end
	return counts
end

-- Adds `amount` and returns how many actually landed under the stack cap.
function Materials.add(counts: { [string]: number }, id: string, amount: number): number
	local definition = Materials.DEFS[id]
	if definition == nil or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	local owned = counts[id]
	if type(owned) ~= "number" or owned ~= owned or owned < 0 then
		owned = 0
	end
	local nextCount = math.floor(owned) + math.floor(amount)
	if nextCount > definition.stack then
		nextCount = definition.stack
	end
	counts[id] = nextCount
	return nextCount - math.floor(owned)
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
			local stacked = math.floor(numberValue)
			local cap = Materials.DEFS[id].stack
			if stacked > cap then
				stacked = cap
			end
			counts[id] = stacked
		end
	end
	return counts
end

function Materials.rarityName(id: string): string
	local definition = Materials.DEFS[id]
	if definition == nil then
		return "Common"
	end
	local rarity = GRADE_RARITY[definition.grade]
	if rarity == nil then
		return "Common"
	end
	return rarity
end

function Materials.merge(into: { [string]: number }, source: { [string]: number }?)
	if type(source) ~= "table" then
		return
	end
	for id, count in pairs(source) do
		if Materials.DEFS[id] ~= nil and type(count) == "number" and count > 0 then
			into[id] = (into[id] or 0) + count
		end
	end
end

-- "Verdant Wood x4". Used by the clear dialog so a grant is a quantity,
-- not an owned/needed counter.
function Materials.gainLines(counts: { [string]: number }): { string }
	local lines = {}
	for _, id in ipairs(Materials.ORDER) do
		local count = counts[id]
		if type(count) == "number" and count > 0 then
			table.insert(
				lines,
				string.format("%s x%d", Materials.displayName(id), math.floor(count))
			)
		end
	end
	return lines
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
	table.freeze(definition.color)
	table.freeze(definition)
end
table.freeze(Materials.DEFS)
table.freeze(Materials.ORDER)
table.freeze(Materials.REALMS)
table.freeze(Materials.VOUCHER_AREAS)
table.freeze(REALM_BY_ASCENSION)
table.freeze(GRADE_RARITY)

return Materials
