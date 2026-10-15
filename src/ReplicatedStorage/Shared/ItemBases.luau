--!strict

--[[
	Item catalog. Pools reference these ids; they do not restate names.

	Weapon, armor, and pet `stats` are the Common, weight-1 ranges. Stats.roll
	scales them by rarity when the item drops. Pets roll Pet Damage and Pet
	HP, and some styles also roll Attack Speed and Crit Chance.

	weaponType is the class-system hook (sword, greatsword, bow, staff, dagger, hammer).
	CombatMath reads it to choose a melee swing or a projectile. Class weights
	still apply when the stats are rolled, not a second time on hit.
]]

local Stats = require("./Stats")

local ItemBases = {}

export type StatRange = {
	id: string,
	min: number,
	max: number,
}

export type Base = {
	id: string,
	name: string,
	kind: "Weapon" | "Armor" | "Pet",
	rarity: string,
	ascension: number,
	weaponType: string?,
	slot: string?,
	setId: string?,
	petStyle: string?,
	stats: { StatRange }?,
}

local WEAPON_STATS: { [string]: { StatRange } } = {
	sword = {
		{ id = "damage", min = 10, max = 14 },
		{ id = "attack_speed", min = 0.95, max = 1.1 },
		{ id = "crit_chance", min = 0.03, max = 0.07 },
		{ id = "crit_damage", min = 1.4, max = 1.7 },
	},
	bow = {
		{ id = "damage", min = 8, max = 12 },
		{ id = "attack_speed", min = 0.9, max = 1.15 },
		{ id = "crit_chance", min = 0.06, max = 0.12 },
		{ id = "crit_damage", min = 1.5, max = 1.9 },
	},
	staff = {
		{ id = "damage", min = 12, max = 18 },
		{ id = "attack_speed", min = 0.7, max = 0.9 },
		{ id = "crit_chance", min = 0.04, max = 0.09 },
		{ id = "crit_damage", min = 1.7, max = 2.2 },
	},
	dagger = {
		{ id = "damage", min = 6, max = 9 },
		{ id = "attack_speed", min = 1.2, max = 1.5 },
		{ id = "crit_chance", min = 0.08, max = 0.16 },
		{ id = "crit_damage", min = 1.45, max = 1.8 },
	},
	greatsword = {
		{ id = "damage", min = 14, max = 20 },
		{ id = "attack_speed", min = 0.7, max = 0.85 },
		{ id = "crit_chance", min = 0.03, max = 0.06 },
		{ id = "crit_damage", min = 1.5, max = 1.85 },
	},
	hammer = {
		{ id = "damage", min = 16, max = 24 },
		{ id = "attack_speed", min = 0.55, max = 0.75 },
		{ id = "crit_chance", min = 0.02, max = 0.05 },
		{ id = "crit_damage", min = 1.6, max = 2 },
	},
}

local ARMOR_STATS: { [string]: { StatRange } } = {
	helm = {
		{ id = "health", min = 20, max = 36 },
		{ id = "defense", min = 4, max = 8 },
	},
	chest = {
		{ id = "health", min = 40, max = 70 },
		{ id = "defense", min = 8, max = 14 },
	},
	legs = {
		{ id = "health", min = 28, max = 48 },
		{ id = "defense", min = 6, max = 11 },
	},
	boots = {
		{ id = "health", min = 14, max = 26 },
		{ id = "defense", min = 3, max = 7 },
	},
}

-- PLACEHOLDER ranges at scale 1. Rarity still multiplies both ends.
-- sprout omits attack speed and crit; combat falls back to a slow swing.
local PET_STYLES: { [string]: { StatRange } } = {
	sprout = {
		{ id = "pet_damage", min = 3, max = 5 },
		{ id = "pet_health", min = 16, max = 28 },
	},
	skitter = {
		{ id = "pet_damage", min = 4, max = 6 },
		{ id = "pet_health", min = 14, max = 24 },
		{ id = "attack_speed", min = 0.9, max = 1.2 },
		{ id = "crit_chance", min = 0.05, max = 0.1 },
	},
	beast = {
		{ id = "pet_damage", min = 5, max = 8 },
		{ id = "pet_health", min = 24, max = 42 },
		{ id = "attack_speed", min = 0.55, max = 0.85 },
		{ id = "crit_chance", min = 0.03, max = 0.07 },
	},
	myth = {
		{ id = "pet_damage", min = 8, max = 13 },
		{ id = "pet_health", min = 36, max = 64 },
		{ id = "attack_speed", min = 0.5, max = 0.75 },
		{ id = "crit_chance", min = 0.06, max = 0.12 },
	},
}

local function styleFor(rarity: string): string
	if rarity == "Common" then
		return "sprout"
	end
	if rarity == "Uncommon" then
		return "skitter"
	end
	if rarity == "Mythic" or rarity == "Secret" then
		return "myth"
	end
	return "beast"
end

local function copyStats(source: { StatRange }): { StatRange }
	local stats = {}
	for _, stat in ipairs(source) do
		table.insert(stats, { id = stat.id, min = stat.min, max = stat.max })
	end
	return stats
end

local byId: { [string]: Base } = {}

local function add(base: Base)
	if byId[base.id] ~= nil then
		error("Duplicate item id '" .. base.id .. "'", 2)
	end
	if base.kind == "Weapon" then
		if base.weaponType == nil or WEAPON_STATS[base.weaponType] == nil then
			error(base.id .. " needs a weapon type", 2)
		end
		base.stats = copyStats(WEAPON_STATS[base.weaponType])
	elseif base.kind == "Armor" then
		if base.slot == nil or ARMOR_STATS[base.slot] == nil then
			error(base.id .. " needs an armor slot", 2)
		end
		base.stats = copyStats(ARMOR_STATS[base.slot])
	end
	if base.stats ~= nil then
		for _, stat in ipairs(base.stats) do
			if Stats.DEFS[stat.id] == nil then
				error(base.id .. " uses unknown stat '" .. stat.id .. "'", 2)
			end
			if stat.min > stat.max then
				error(base.id .. " has a stat min above max", 2)
			end
		end
	end
	byId[base.id] = base
end

local function weapon(
	id: string,
	name: string,
	rarity: string,
	weaponType: string,
	ascension: number
)
	add({
		id = id,
		name = name,
		kind = "Weapon",
		rarity = rarity,
		ascension = ascension,
		weaponType = weaponType,
	})
end

local function armor(
	id: string,
	name: string,
	rarity: string,
	slot: string,
	ascension: number,
	setId: string?
)
	add({
		id = id,
		name = name,
		kind = "Armor",
		rarity = rarity,
		ascension = ascension,
		slot = slot,
		setId = setId,
	})
end

local function pet(id: string, name: string, rarity: string, ascension: number, petStyle: string?)
	local style = if petStyle ~= nil then petStyle else styleFor(rarity)
	local ranges = PET_STYLES[style]
	if ranges == nil then
		error(id .. " needs a pet style", 2)
	end
	add({
		id = id,
		name = name,
		kind = "Pet",
		rarity = rarity,
		ascension = ascension,
		petStyle = style,
		stats = copyStats(ranges),
	})
end

-- Forge defaults. Common gear the bench can make at Crafting Level 1.
weapon("iron_sword", "Iron Sword", "Common", "sword", 0)
weapon("iron_greatsword", "Iron Greatsword", "Common", "greatsword", 0)
weapon("iron_bow", "Iron Bow", "Common", "bow", 0)
weapon("iron_staff", "Iron Staff", "Common", "staff", 0)
weapon("iron_dagger", "Iron Dagger", "Common", "dagger", 0)
weapon("iron_hammer", "Iron Hammer", "Common", "hammer", 0)
weapon("thornbound_blade", "Thornbound Blade", "Rare", "sword", 0)

-- Ascension 0, Verdant Wilds. Nature, beasts, wood, vines.
weapon("vinewood_sword", "Vinewood Sword", "Common", "sword", 0)
weapon("briar_bow", "Briar Bow", "Common", "bow", 0)
weapon("sapling_staff", "Sapling Staff", "Common", "staff", 0)
weapon("thorn_dagger", "Thorn Dagger", "Common", "dagger", 0)
weapon("root_mallet", "Root Mallet", "Common", "hammer", 0)
armor("woven_bark_vest", "Woven Bark Vest", "Common", "chest", 0, nil)

weapon("fernblade", "Fernblade", "Uncommon", "sword", 0)
weapon("canopy_bow", "Canopy Bow", "Uncommon", "bow", 0)
weapon("wildgrowth_staff", "Wildgrowth Staff", "Uncommon", "staff", 0)
weapon("bramble_fang", "Bramble Fang", "Uncommon", "dagger", 0)
weapon("beastbone_hammer", "Beastbone Hammer", "Uncommon", "hammer", 0)

weapon("hartseeker", "Hartseeker", "Rare", "sword", 0)
weapon("galevine_bow", "Galevine Bow", "Rare", "bow", 0)
weapon("mycelium_staff", "Mycelium Staff", "Rare", "staff", 0)
weapon("nightbriar", "Nightbriar", "Rare", "dagger", 0)
armor("living_bark_cuirass", "Living Bark Cuirass", "Rare", "chest", 0, nil)

armor("grovewarden_hood", "Grovewarden Hood", "Epic", "helm", 0, "grovewarden")
armor("grovewarden_vestments", "Grovewarden Vestments", "Epic", "chest", 0, "grovewarden")
armor("grovewarden_greaves", "Grovewarden Greaves", "Epic", "legs", 0, "grovewarden")
armor("grovewarden_wraps", "Grovewarden Wraps", "Epic", "boots", 0, "grovewarden")

weapon("antlerbrand", "Antlerbrand", "Legendary", "sword", 0)
weapon("worldroot_staff", "Worldroot Staff", "Legendary", "staff", 0)

weapon("green_tyrant", "The Green Tyrant", "Mythic", "hammer", 0)
weapon("bloomheart_bow", "Bloomheart Bow", "Mythic", "bow", 0)

weapon("unnamed_grove", "The Unnamed Grove", "Secret", "staff", 0)

pet("moss_hare", "Moss Hare", "Common", 0)
pet("acorn_newt", "Acorn Newt", "Common", 0)
pet("briar_pup", "Briar Pup", "Uncommon", 0)
pet("pollen_moth", "Pollen Moth", "Uncommon", 0)
pet("fern_stag", "Fern Stag", "Rare", 0)
pet("brook_otter", "Brook Otter", "Rare", 0)
pet("vine_lynx", "Vine Lynx", "Epic", 0)
pet("myco_fox", "Myco Fox", "Epic", 0)
pet("antler_hart", "Antler Hart", "Legendary", 0)
pet("dawnbloom_wolf", "Dawnbloom Wolf", "Legendary", 0)
pet("thorn_hydra", "Thorn Hydra", "Mythic", 0)
pet("grove_phoenix", "Grove Phoenix", "Mythic", 0)
pet("sleeping_dryad", "The Sleeping Dryad", "Secret", 0)

-- Ascension 1, Sunken Reach. Water and tide. Placeholder roster.
weapon("driftwood_saber", "Driftwood Saber", "Common", "sword", 1)
weapon("tideglass_dagger", "Tideglass Dagger", "Uncommon", "dagger", 1)
weapon("kelpstrand_bow", "Kelpstrand Bow", "Rare", "bow", 1)
armor("brineplate_cuirass", "Brineplate Cuirass", "Epic", "chest", 1, nil)
weapon("abyssal_staff", "Abyssal Staff", "Legendary", "staff", 1)
weapon("leviathan_mallet", "Leviathan Mallet", "Mythic", "hammer", 1)
weapon("drowned_name", "The Drowned Name", "Secret", "sword", 1)

pet("tide_skipper", "Tide Skipper", "Common", 1)
pet("reef_pup", "Reef Pup", "Uncommon", 1)
pet("lantern_jelly", "Lantern Jelly", "Rare", 1)
pet("abyss_eel", "Abyss Eel", "Epic", 1)
pet("moonwhale_calf", "Moonwhale Calf", "Legendary", 1)
pet("storm_kraken", "Storm Kraken", "Mythic", 1)
pet("quiet_tide", "The Quiet Tide", "Secret", 1)

-- Ascension 2, Emberforge. Fire and forge. Placeholder roster.
weapon("cinder_maul", "Cinder Maul", "Common", "hammer", 2)
weapon("soot_dagger", "Soot Dagger", "Uncommon", "dagger", 2)
weapon("kiln_bow", "Kiln Bow", "Rare", "bow", 2)
armor("slagplate_cuirass", "Slagplate Cuirass", "Epic", "chest", 2, nil)
weapon("sunhammer", "Sunhammer", "Legendary", "hammer", 2)
weapon("dragonkiln_staff", "Dragonkiln Staff", "Mythic", "staff", 2)
weapon("unquenched", "The Unquenched", "Secret", "sword", 2)

pet("coal_newt", "Coal Newt", "Common", 2)
pet("cinder_whelp", "Cinder Whelp", "Uncommon", 2)
pet("forge_hound", "Forge Hound", "Rare", 2)
pet("magma_salamander", "Magma Salamander", "Epic", 2)
pet("ash_phoenix", "Ash Phoenix", "Legendary", 2)
pet("kiln_tyrant", "Kiln Tyrant", "Mythic", 2)
pet("last_ember", "The Last Ember", "Secret", 2)

-- Ascension 3, Frostveil. Ice and time. Placeholder roster.
weapon("rimewood_sword", "Rimewood Sword", "Common", "sword", 3)
weapon("hourglass_dagger", "Hourglass Dagger", "Uncommon", "dagger", 3)
weapon("snowblind_bow", "Snowblind Bow", "Rare", "bow", 3)
armor("chronoplate", "Chronoplate", "Epic", "chest", 3, nil)
weapon("glacial_staff", "Glacial Staff", "Legendary", "staff", 3)
weapon("minute_mallet", "The Minute Mallet", "Mythic", "hammer", 3)
weapon("unthawed", "The Unthawed", "Secret", "sword", 3)

pet("snow_hare", "Snow Hare", "Common", 3)
pet("frost_pup", "Frost Pup", "Uncommon", 3)
pet("clockwork_owl", "Clockwork Owl", "Rare", 3)
pet("glacier_elk", "Glacier Elk", "Epic", 3)
pet("aeon_wolf", "Aeon Wolf", "Legendary", 3)
pet("white_hour", "The White Hour", "Mythic", 3)
pet("paused_hart", "The Paused Hart", "Secret", 3)

-- Ascension 4, Void Rift. Void and prism. Placeholder roster.
weapon("null_shard", "Null Shard", "Common", "dagger", 4)
weapon("prism_bow", "Prism Bow", "Uncommon", "bow", 4)
weapon("rift_staff", "Rift Staff", "Rare", "staff", 4)
armor("voidplate", "Voidplate", "Epic", "chest", 4, nil)
weapon("spectrum_hammer", "Spectrum Hammer", "Legendary", "hammer", 4)
weapon("last_color", "The Last Color", "Mythic", "sword", 4)
weapon("unmaking", "Unmaking", "Secret", "staff", 4)

pet("shade_mote", "Shade Mote", "Common", 4)
pet("prism_moth", "Prism Moth", "Uncommon", 4)
pet("rift_hound", "Rift Hound", "Rare", 4)
pet("void_lynx", "Void Lynx", "Epic", 4)
pet("spectrum_wyrm", "Spectrum Wyrm", "Legendary", 4)
pet("uncolor", "The Uncolor", "Mythic", 4)
pet("nameless_rift", "Nameless", "Secret", 4)

function ItemBases.get(templateId: string): Base?
	return byId[templateId]
end

function ItemBases.all(): { Base }
	local list = {}
	for _, base in pairs(byId) do
		table.insert(list, base)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

for _, base in pairs(byId) do
	if base.stats ~= nil then
		for _, stat in ipairs(base.stats) do
			table.freeze(stat)
		end
		table.freeze(base.stats)
	end
	table.freeze(base)
end

return ItemBases
