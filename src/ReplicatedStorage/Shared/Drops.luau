--!strict

--[[
	Kill drops. Normal enemies pay the realm's common material, elites the
	rare, bosses the boss material. Elites and bosses can also drop a recipe
	scroll. Verdant enemies also drop the older forage (wood, vine, spore,
	bark) so every recipe cost is something a player can pick up. Auto-Farm
	kills go through the same table as a manual swing.
]]

local Materials = require("./Materials")

local Drops = {}

export type Entry = {
	id: string,
	chance: number,
	min: number,
	max: number,
}

export type EnemyDrop = {
	realm: string,
	role: "normal" | "elite" | "boss",
}

local function row(id: string, chance: number, minCount: number, maxCount: number): Entry
	return {
		id = id,
		chance = chance,
		min = minCount,
		max = maxCount,
	}
end

local function bundle(
	realm: string,
	scrollId: string?,
	scrollChance: number
): { [string]: { Entry } }
	local common = Materials.primary(realm, "common")
	local rare = Materials.primary(realm, "rare")
	local boss = Materials.primary(realm, "boss")
	assert(common ~= nil and rare ~= nil and boss ~= nil, realm .. " is missing a material")
	local elite = { row(rare, 1, 1, 1) }
	local bossRows = { row(boss, 1, 1, 1) }
	if scrollId ~= nil then
		table.insert(elite, row(scrollId, scrollChance, 1, 1))
		table.insert(bossRows, row(scrollId, math.min(1, scrollChance + 0.2), 1, 1))
	end
	return {
		normal = { row(common, 1, 1, 2) },
		elite = elite,
		boss = bossRows,
	}
end

-- Realm id is the key. Entries are built from Materials so names stay in one place.
local BY_REALM: { [string]: { [string]: { Entry } } } = {
	verdant = bundle("Verdant Wilds", "scroll_thornbound", 0.15),
	sunken = bundle("Sunken Reach", nil, 0),
	ember = bundle("Emberforge", nil, 0),
	frost = bundle("Frostveil", nil, 0),
	void = bundle("Void Rift", nil, 0),
}

Drops.ENEMIES = {
	vine_crawler = { realm = "verdant", role = "normal" },
	spore_bat = { realm = "verdant", role = "normal" },
	root_brute = { realm = "verdant", role = "elite" },
	moss_crawler = { realm = "verdant", role = "normal" },
	thorn_sprite = { realm = "verdant", role = "elite" },
	grandmother_gnarl = { realm = "verdant", role = "boss" },
	mud_tusk = { realm = "verdant", role = "normal" },
	hedge_lurker = { realm = "verdant", role = "normal" },
	seed_flinger = { realm = "verdant", role = "normal" },
	sap_mouth = { realm = "verdant", role = "normal" },
	mite_cloud = { realm = "verdant", role = "normal" },
	-- Elite, not boss: the Waves Mireoak pays the realm rare, not a boss part.
	mireoak = { realm = "verdant", role = "elite" },
	-- V1 roster. Live rooms and waveKinds do not spawn them, so a live run
	-- does not pay these. The gated 6/8/10/12 flow can name them while
	-- enemyTypes is on, and that flow does not grant drops.
	chaser = { realm = "verdant", role = "normal" },
	ranged = { realm = "verdant", role = "normal" },
	tank = { realm = "verdant", role = "normal" },
} :: { [string]: EnemyDrop }

-- Extra forage on top of the realm bundle. Living Vine is a Vine Crawler
-- drop, including Auto-Farm, because the older recipes still spend it.
local BONUS: { [string]: { Entry } } = {
	vine_crawler = {
		row("vine", 1, 1, 2),
		row("wood", 1, 1, 1),
	},
	spore_bat = {
		row("spore", 1, 1, 2),
	},
	root_brute = {
		row("bark", 1, 1, 1),
	},
	moss_crawler = {
		row("spore", 1, 1, 2),
	},
	thorn_sprite = {
		row("vine", 1, 1, 1),
	},
	mud_tusk = {
		row("wood", 1, 1, 2),
	},
	hedge_lurker = {
		row("vine", 1, 1, 1),
	},
	seed_flinger = {
		row("spore", 0.6, 1, 1),
	},
	sap_mouth = {
		row("bark", 0.5, 1, 1),
	},
	mite_cloud = {
		row("spore", 0.4, 1, 1),
	},
}

function Drops.entries(enemyId: string): { Entry }?
	local enemy = Drops.ENEMIES[enemyId]
	if enemy == nil then
		return nil
	end
	local realm = BY_REALM[enemy.realm]
	if realm == nil then
		return nil
	end
	local base = realm[enemy.role]
	local bonus = BONUS[enemyId]
	if bonus == nil then
		return base
	end
	local rows = table.clone(base)
	for _, entry in ipairs(bonus) do
		table.insert(rows, entry)
	end
	return rows
end

function Drops.roll(enemyId: string, rng: any): { [string]: number }
	local entries = Drops.entries(enemyId)
	local granted = {}
	if entries == nil or type(rng) ~= "table" then
		return granted
	end
	for _, entry in ipairs(entries) do
		local roll = rng:nextNumber()
		if type(roll) == "number" and roll < entry.chance then
			local count = entry.min
			if entry.max > entry.min then
				count = rng:nextInteger(entry.min, entry.max)
			end
			if type(count) ~= "number" or count < 1 then
				count = entry.min
			end
			granted[entry.id] = (granted[entry.id] or 0) + count
		end
	end
	return granted
end

-- Adds the roll to a material bag. Returns the counts that fit under the cap.
function Drops.apply(
	materials: { [string]: number },
	enemyId: string,
	rng: any
): { [string]: number }
	local rolled = Drops.roll(enemyId, rng)
	local landed = {}
	for id, count in pairs(rolled) do
		local added = Materials.add(materials, id, count)
		if added > 0 then
			landed[id] = added
		end
	end
	return landed
end

for _, realm in pairs(BY_REALM) do
	for _, entries in pairs(realm) do
		for _, entry in ipairs(entries) do
			table.freeze(entry)
		end
		table.freeze(entries)
	end
	table.freeze(realm)
end
table.freeze(BY_REALM)
for _, enemy in pairs(Drops.ENEMIES) do
	table.freeze(enemy)
end
table.freeze(Drops.ENEMIES)
for _, entries in pairs(BONUS) do
	for _, entry in ipairs(entries) do
		table.freeze(entry)
	end
	table.freeze(entries)
end
table.freeze(BONUS)

return Drops
