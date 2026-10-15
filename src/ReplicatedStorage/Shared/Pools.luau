--!strict

--[[
	Shard pools. A pool is one ascension tier inside one roll area.

	Armory pools drop weapons and armor. Pet pools drop pets. The player's
	ascension has to be at least the pool's ascension or the server will not
	roll it. Odds are PLACEHOLDER. Weights sum to 10_000 so at 0 Shard Luck
	the chance is weight / 100 percent. RollMath.odds reads these weights.

	Higher realms (Sunken Reach, Emberforge, Frostveil, Void Rift) are a
	short placeholder roster: one drop per rarity. Verdant Wilds is the
	ascension 0 roster. Add a drop by adding the base in ItemBases.luau and
	a weight row below.
]]

local ItemBases = require("./ItemBases")

local Pools = {}

export type PoolEntry = {
	templateId: string,
	name: string,
	rarity: string,
	weight: number,
	kind: string,
}

export type Pool = {
	id: string,
	name: string,
	short: string,
	area: string,
	ascension: number,
	theme: string,
	pityLegendaryAt: number,
	placeholder: boolean,
	public: boolean,
	entries: { PoolEntry },
}

-- The pool a brand-new profile cracks in the armory. Tests and the client
-- default both start here.
Pools.DEFAULT_POOL_ID = "verdant_armory"
Pools.MAX_ASCENSION = 4

type Drop = { string | number }

local function line(templateId: string, weight: number): Drop
	return { templateId, weight }
end

local function build(definition): Pool
	local entries = {}
	for _, drop in ipairs(definition.drops) do
		local templateId = drop[1]
		local weight = drop[2]
		if type(templateId) ~= "string" or type(weight) ~= "number" then
			error("Bad drop row in pool '" .. definition.id .. "'", 2)
		end
		local base = ItemBases.get(templateId)
		if base == nil then
			error(
				string.format("Pool '%s' references missing item '%s'", definition.id, templateId),
				2
			)
		end
		table.insert(entries, {
			templateId = templateId,
			name = base.name,
			rarity = base.rarity,
			weight = weight,
			kind = base.kind,
		})
	end
	return {
		id = definition.id,
		name = definition.name,
		short = if type(definition.short) == "string" then definition.short else definition.name,
		area = definition.area,
		ascension = definition.ascension,
		theme = definition.theme,
		pityLegendaryAt = 50,
		placeholder = true,
		public = true,
		entries = entries,
	}
end

local definitions = {
	{
		id = "verdant_armory",
		name = "Verdant Wilds",
		short = "Verdant",
		area = "armory",
		ascension = 0,
		theme = "Nature, beasts, wood, and vines",
		drops = {
			line("vinewood_sword", 1000),
			line("briar_bow", 1000),
			line("sapling_staff", 1000),
			line("thorn_dagger", 1000),
			line("root_mallet", 1000),
			line("woven_bark_vest", 1000),
			line("fernblade", 500),
			line("canopy_bow", 500),
			line("wildgrowth_staff", 500),
			line("bramble_fang", 500),
			line("beastbone_hammer", 500),
			line("hartseeker", 200),
			line("galevine_bow", 200),
			line("mycelium_staff", 200),
			line("nightbriar", 200),
			line("living_bark_cuirass", 200),
			line("grovewarden_hood", 100),
			line("grovewarden_vestments", 100),
			line("grovewarden_greaves", 100),
			line("grovewarden_wraps", 100),
			line("antlerbrand", 40),
			line("worldroot_staff", 40),
			line("green_tyrant", 9),
			line("bloomheart_bow", 9),
			line("unnamed_grove", 2),
		},
	},
	{
		id = "verdant_pets",
		name = "Verdant Wilds",
		short = "Verdant",
		area = "pets",
		ascension = 0,
		theme = "Nature, beasts, wood, and vines",
		drops = {
			line("moss_hare", 3500),
			line("acorn_newt", 2500),
			line("briar_pup", 1500),
			line("pollen_moth", 1000),
			line("fern_stag", 600),
			line("brook_otter", 400),
			line("vine_lynx", 250),
			line("myco_fox", 150),
			line("antler_hart", 50),
			line("dawnbloom_wolf", 30),
			line("thorn_hydra", 10),
			line("grove_phoenix", 8),
			line("sleeping_dryad", 2),
		},
	},
	{
		id = "sunken_armory",
		name = "Sunken Reach",
		short = "Sunken",
		area = "armory",
		ascension = 1,
		theme = "Water and tide",
		drops = {
			line("driftwood_saber", 6000),
			line("tideglass_dagger", 2500),
			line("kelpstrand_bow", 1000),
			line("brineplate_cuirass", 400),
			line("abyssal_staff", 80),
			line("leviathan_mallet", 18),
			line("drowned_name", 2),
		},
	},
	{
		id = "sunken_pets",
		name = "Sunken Reach",
		short = "Sunken",
		area = "pets",
		ascension = 1,
		theme = "Water and tide",
		drops = {
			line("tide_skipper", 6000),
			line("reef_pup", 2500),
			line("lantern_jelly", 1000),
			line("abyss_eel", 400),
			line("moonwhale_calf", 80),
			line("storm_kraken", 18),
			line("quiet_tide", 2),
		},
	},
	{
		id = "ember_armory",
		name = "Emberforge",
		short = "Ember",
		area = "armory",
		ascension = 2,
		theme = "Fire and forge",
		drops = {
			line("cinder_maul", 6000),
			line("soot_dagger", 2500),
			line("kiln_bow", 1000),
			line("slagplate_cuirass", 400),
			line("sunhammer", 80),
			line("dragonkiln_staff", 18),
			line("unquenched", 2),
		},
	},
	{
		id = "ember_pets",
		name = "Emberforge",
		short = "Ember",
		area = "pets",
		ascension = 2,
		theme = "Fire and forge",
		drops = {
			line("coal_newt", 6000),
			line("cinder_whelp", 2500),
			line("forge_hound", 1000),
			line("magma_salamander", 400),
			line("ash_phoenix", 80),
			line("kiln_tyrant", 18),
			line("last_ember", 2),
		},
	},
	{
		id = "frost_armory",
		name = "Frostveil",
		short = "Frost",
		area = "armory",
		ascension = 3,
		theme = "Ice and time",
		drops = {
			line("rimewood_sword", 6000),
			line("hourglass_dagger", 2500),
			line("snowblind_bow", 1000),
			line("chronoplate", 400),
			line("glacial_staff", 80),
			line("minute_mallet", 18),
			line("unthawed", 2),
		},
	},
	{
		id = "frost_pets",
		name = "Frostveil",
		short = "Frost",
		area = "pets",
		ascension = 3,
		theme = "Ice and time",
		drops = {
			line("snow_hare", 6000),
			line("frost_pup", 2500),
			line("clockwork_owl", 1000),
			line("glacier_elk", 400),
			line("aeon_wolf", 80),
			line("white_hour", 18),
			line("paused_hart", 2),
		},
	},
	{
		id = "void_armory",
		name = "Void Rift",
		short = "Void",
		area = "armory",
		ascension = 4,
		theme = "Void and prism",
		drops = {
			line("null_shard", 6000),
			line("prism_bow", 2500),
			line("rift_staff", 1000),
			line("voidplate", 400),
			line("spectrum_hammer", 80),
			line("last_color", 18),
			line("unmaking", 2),
		},
	},
	{
		id = "void_pets",
		name = "Void Rift",
		short = "Void",
		area = "pets",
		ascension = 4,
		theme = "Void and prism",
		drops = {
			line("shade_mote", 6000),
			line("prism_moth", 2500),
			line("rift_hound", 1000),
			line("void_lynx", 400),
			line("spectrum_wyrm", 80),
			line("uncolor", 18),
			line("nameless_rift", 2),
		},
	},
}

local byId: { [string]: Pool } = {}
for _, definition in ipairs(definitions) do
	local pool = build(definition)
	byId[pool.id] = pool
end

for _, pool in pairs(byId) do
	for _, entry in ipairs(pool.entries) do
		table.freeze(entry)
	end
	table.freeze(pool.entries)
	table.freeze(pool)
end

function Pools.get(poolId: string): Pool?
	return byId[poolId]
end

function Pools.all(): { Pool }
	local list = {}
	for _, pool in pairs(byId) do
		table.insert(list, pool)
	end
	table.sort(list, function(a, b)
		if a.area ~= b.area then
			return a.area < b.area
		end
		if a.ascension ~= b.ascension then
			return a.ascension < b.ascension
		end
		return a.id < b.id
	end)
	return list
end

function Pools.forArea(areaId: string): { Pool }
	local list = {}
	for _, pool in ipairs(Pools.all()) do
		if pool.area == areaId then
			table.insert(list, pool)
		end
	end
	return list
end

function Pools.isUnlocked(pool: Pool, ascension: any): boolean
	local level = ascension
	if type(level) ~= "number" or level ~= level then
		level = 0
	end
	return level >= pool.ascension
end

return Pools
