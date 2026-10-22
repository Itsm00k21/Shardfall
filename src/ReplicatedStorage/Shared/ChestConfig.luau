--!strict

--[[
	Chest tiers, odds, pity, keys, dust, and merge costs.

	A chest is a shard roll with a floor. The server draws with Random.new.
	The client only plays the tier timing and the filler seed. Luck moves
	weight inside the rarities that chest already allows. A zero stays zero.

	Later ideas stay in LATER and are not implemented: realm chests, a Key
	Shard socket, cracked chests, party chests, and an upgrade gamble.
]]

local Drops = require("./Drops")
local Materials = require("./Materials")
local Pools = require("./Pools")
local Rarities = require("./Rarities")
local RarityConfig = require("./RarityConfig")
local RollMath = require("./RollMath")
local Schema = require("./Schema")
local Stars = require("./Stars")

local Loops = require("./Loops")
local LaunchGate = require("./LaunchGate")

local ChestConfig = {}

ChestConfig.PAID_CHESTS_ENABLED = false
ChestConfig.REGION_MESSAGE = "Unavailable in your region."
ChestConfig.PAID_OFF_MESSAGE = "Paid chests are turned off."
ChestConfig.OPEN_MANY_MAX = 10
ChestConfig.MERGE_COUNT = 5
ChestConfig.RARE_PITY = 20
ChestConfig.EPIC_PITY = 15
ChestConfig.ENEMY_CHEST_CHANCE = 0.02
ChestConfig.DUST_EPIC = 2000
ChestConfig.DUST_LEGENDARY = 10000

ChestConfig.TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- Percents. Each row sums to 100. A 0 is outside that chest's floor.
local ODDS: { [string]: { [string]: number } } = {
	Common = { Common = 70, Uncommon = 25, Rare = 4.5, Epic = 0.5, Legendary = 0, Mythic = 0 },
	Uncommon = { Common = 0, Uncommon = 75, Rare = 20, Epic = 4.5, Legendary = 0.5, Mythic = 0 },
	Rare = { Common = 0, Uncommon = 0, Rare = 80, Epic = 17, Legendary = 2.8, Mythic = 0.2 },
	Epic = { Common = 0, Uncommon = 0, Rare = 0, Epic = 85, Legendary = 13.5, Mythic = 1.5 },
	Legendary = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 92, Mythic = 8 },
	Mythic = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 100 },
}

ChestConfig.FLOOR = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythic = "Mythic",
}

-- Shard Keys buy these three. Legendary and Mythic are never sold.
ChestConfig.KEY_SHOP = {
	Uncommon = 40,
	Rare = 150,
	Epic = 600,
}

-- Dust from a duplicate. The material beside it is one realm drop, so a
-- Mythic duplicate does not mint thousands of boss seeds.
ChestConfig.DUST = {
	Common = 5,
	Uncommon = 15,
	Rare = 50,
	Epic = 200,
	Legendary = 1000,
	Mythic = 5000,
}

ChestConfig.DUST_MATERIAL = {
	Common = { id = "verdant_bark", count = 1 },
	Uncommon = { id = "verdant_bark", count = 2 },
	Rare = { id = "heartwood", count = 1 },
	Epic = { id = "heartwood", count = 2 },
	Legendary = { id = "gnarl_seed", count = 1 },
	Mythic = { id = "gnarl_seed", count = 1 },
}

ChestConfig.DUST_PRICE = {
	Epic = ChestConfig.DUST_EPIC,
	Legendary = ChestConfig.DUST_LEGENDARY,
}

ChestConfig.MERGE = {
	Common = { next = "Uncommon", materials = { verdant_bark = 8 } },
	Uncommon = { next = "Rare", materials = { heartwood = 2 } },
	Rare = { next = "Epic", materials = { heartwood = 6 } },
	Epic = { next = "Legendary", materials = { gnarl_seed = 1 } },
	Legendary = { next = "Mythic", materials = { gnarl_seed = 2 } },
}

ChestConfig.OPEN_SECONDS = {
	Common = 1.5,
	Uncommon = 1.5,
	Rare = 2.2,
	Epic = 2.8,
	Legendary = 3.5,
	Mythic = 4,
}

ChestConfig.REEL_SECONDS = {
	Common = 1,
	Uncommon = 1,
	Rare = 1.4,
	Epic = 1.6,
	Legendary = 2,
	Mythic = 0,
}

ChestConfig.SOURCES = {
	enemy = { tier = "Common", chance = ChestConfig.ENEMY_CHEST_CHANCE },
	room = { tier = "Common", keys = 2 },
	login = { tier = "Common", keys = 5 },
	clear = { tier = "Uncommon", keys = 8 },
	boss = { tier = "Rare", keys = 10 },
	dailyBoss = { tier = "Epic", keys = 0 },
	streak = { tier = "Epic", keys = 0 },
	weeklyBoss = { tier = "Legendary", keys = 0 },
}

-- Paid bundle may contain Rare and Epic only. Odds are part of the pitch.
ChestConfig.PAID_BUNDLE = {
	name = "Rare and Epic chest bundle",
	chests = { Rare = 1, Epic = 1 },
}

-- Art request. One mesh, six recolors. This pass uses a colored frame.
ChestConfig.ART = {
	note = "One Tripo chest mesh, recolored per tier. Not built in this pass.",
}

-- Design hooks. ChestConfig.later(id) refuses these. Do not grant from them.
ChestConfig.LATER = {
	realmChests = "Realm chests are not built yet.",
	keyShardSocket = "Key Shard sockets are not built yet.",
	crackedChests = "Cracked chests are not built yet.",
	partyChests = "Party chests are not built yet.",
	upgradeGamble = "The chest upgrade gamble is not built yet.",
}

local RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
}

-- -1 means the daily or weekly reward has never been claimed.
local function stamp(value: any): number
	local numberValue = tonumber(value)
	if numberValue == nil or numberValue ~= numberValue then
		return -1
	end
	return math.floor(numberValue)
end

local function whole(value: any, fallback: number): number
	local numberValue = tonumber(value)
	if numberValue == nil or numberValue ~= numberValue then
		return fallback
	end
	local floored = math.floor(numberValue)
	if floored < 0 then
		return 0
	end
	return floored
end

local function unit(rng: any): number
	local value = rng:nextNumber()
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	if value < 0 then
		return 0
	end
	if value >= 1 then
		return 0.999999
	end
	return value
end

function ChestConfig.later(id: any)
	local message = nil
	if type(id) == "string" then
		message = ChestConfig.LATER[id]
	end
	if message == nil then
		return { ok = false, error = "Unknown chest hook." }
	end
	return { ok = false, error = message }
end

function ChestConfig.forSale(tier: string): boolean
	return ChestConfig.KEY_SHOP[tier] ~= nil
end

function ChestConfig.quickOpen(tier: string): boolean
	return tier == "Common" or tier == "Uncommon" or tier == "Rare"
end

function ChestConfig.playFullReveal(tier: string, rarity: string, many: boolean): boolean
	if rarity == "Legendary" or rarity == "Mythic" then
		return true
	end
	if many and ChestConfig.quickOpen(tier) then
		return false
	end
	return true
end

function ChestConfig.ensure(data: any)
	if type(data.chests) ~= "table" then
		data.chests = {}
	end
	for _, tier in ipairs(ChestConfig.TIERS) do
		data.chests[tier] = math.min(999, whole(data.chests[tier], 0))
	end
	data.shardKeys = math.min(99999, whole(data.shardKeys, 0))
	data.shardDust = math.min(999999, whole(data.shardDust, 0))
	data.rareChestsSinceEpic = whole(data.rareChestsSinceEpic, 0)
	data.epicChestsSinceLegendary = whole(data.epicChestsSinceLegendary, 0)
	data.lastLoginDay = stamp(data.lastLoginDay)
	data.loginStreak = whole(data.loginStreak, 0)
	data.lastDailyBossDay = stamp(data.lastDailyBossDay)
	data.lastWeeklyBossWeek = stamp(data.lastWeeklyBossWeek)
	if data.chestDuplicates ~= "star" then
		data.chestDuplicates = "dust"
	end
	if
		type(data.chestSalvageBelow) ~= "string"
		or Rarities.INDEX[data.chestSalvageBelow] == nil
	then
		data.chestSalvageBelow = ""
	end
	if type(data.materials) ~= "table" then
		data.materials = Materials.empty()
	end
	if type(data.inventory) ~= "table" then
		data.inventory = {}
	end
	if type(data.pets) ~= "table" then
		data.pets = {}
	end
end

function ChestConfig.addChest(data: any, tier: string, count: number): number
	ChestConfig.ensure(data)
	local amount = whole(count, 0)
	if ChestConfig.FLOOR[tier] == nil or amount < 1 then
		return 0
	end
	local nextCount = math.min(999, data.chests[tier] + amount)
	local gained = nextCount - data.chests[tier]
	data.chests[tier] = nextCount
	return gained
end

function ChestConfig.chances(
	tier: string,
	luck: number,
	floorOverride: string?
): { [string]: number }
	local row = ODDS[tier]
	local chances: { [string]: number } = {}
	if row == nil then
		return chances
	end
	local multiplier = luck
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 then
		multiplier = 1
	end
	local floorName = ChestConfig.FLOOR[tier] or "Common"
	local floorRank = RANK[floorName] or 1
	local total = 0
	for _, rarity in ipairs(ChestConfig.TIERS) do
		local base = row[rarity] or 0
		local weight = 0
		if base > 0 then
			local steps = (RANK[rarity] or 1) - floorRank
			if steps < 0 then
				steps = 0
			end
			weight = base * (multiplier ^ (steps * 0.5))
		end
		chances[rarity] = weight
		total += weight
	end
	if floorOverride ~= nil and RANK[floorOverride] ~= nil then
		local minRank = RANK[floorOverride]
		local kept = 0
		for _, rarity in ipairs(ChestConfig.TIERS) do
			if (RANK[rarity] or 0) < minRank then
				chances[rarity] = 0
			else
				kept += chances[rarity]
			end
		end
		total = kept
		if total <= 0 then
			for _, rarity in ipairs(ChestConfig.TIERS) do
				chances[rarity] = 0
			end
			chances[floorOverride] = 1
			total = 1
		end
	end
	if total <= 0 then
		return chances
	end
	for _, rarity in ipairs(ChestConfig.TIERS) do
		chances[rarity] = chances[rarity] / total
	end
	return chances
end

function ChestConfig.oddsLines(tier: string, luck: number): { string }
	local lines = {}
	local row = ChestConfig.chances(tier, luck, nil)
	for _, rarity in ipairs(ChestConfig.TIERS) do
		table.insert(lines, string.format("%s  %.2f%%", rarity, (row[rarity] or 0) * 100))
	end
	return lines
end

function ChestConfig.pityLine(data: any): string
	local rare = if type(data) == "table" then whole(data.rareChestsSinceEpic, 0) else 0
	local epic = if type(data) == "table" then whole(data.epicChestsSinceLegendary, 0) else 0
	return string.format(
		"Rare chests %d/%d to Epic+  ·  Epic chests %d/%d to Legendary",
		rare,
		ChestConfig.RARE_PITY,
		epic,
		ChestConfig.EPIC_PITY
	)
end

function ChestConfig.bundlePitch(): string
	local lines = {
		ChestConfig.PAID_BUNDLE.name .. ". Not for sale yet.",
		"Contains 1 Rare Chest and 1 Epic Chest. Legendary and Mythic chests are not sold.",
	}
	for _, tier in ipairs({ "Rare", "Epic" }) do
		table.insert(lines, tier .. " Chest")
		for _, line in ipairs(ChestConfig.oddsLines(tier, 1)) do
			table.insert(lines, "  " .. line)
		end
	end
	return table.concat(lines, "\n")
end

local function dayNumber(now: number): number
	return math.floor(now / 86400)
end

local function weekNumber(now: number): number
	return math.floor(now / (86400 * 7))
end

-- Chests are parked (roadmap 0.1). Play sources stop granting them; owned
-- chests, the key shop, merges, and opening are untouched.
function ChestConfig.dropsOn(): boolean
	return LaunchGate.on("chests")
end

local function grantListed(data: any, source: string)
	local spec = ChestConfig.SOURCES[source]
	if spec == nil or type(spec.tier) ~= "string" then
		return nil
	end
	if not ChestConfig.dropsOn() then
		-- Shard Keys still pay. No chest, so no label for a toast.
		local parkedKeys = whole(spec.keys, 0)
		if parkedKeys > 0 then
			data.shardKeys = math.min(99999, data.shardKeys + parkedKeys)
		end
		return nil
	end
	local gained = ChestConfig.addChest(data, spec.tier, 1)
	local keys = whole(spec.keys, 0)
	if keys > 0 then
		data.shardKeys = math.min(99999, data.shardKeys + keys)
	end
	return {
		source = source,
		tier = spec.tier,
		count = gained,
		keys = keys,
		label = string.format("%s Chest", spec.tier),
	}
end

function ChestConfig.grantSource(data: any, source: string, _now: number)
	ChestConfig.ensure(data)
	return grantListed(data, source)
end

function ChestConfig.enemyDrop(data: any, enemyId: string, rng: any)
	ChestConfig.ensure(data)
	local enemy = Drops.ENEMIES[enemyId]
	if enemy == nil or enemy.realm ~= "verdant" or enemy.role == "boss" then
		return nil
	end
	if unit(rng) >= ChestConfig.ENEMY_CHEST_CHANCE then
		return nil
	end
	return grantListed(data, "enemy")
end

function ChestConfig.bossKill(data: any, now: number)
	ChestConfig.ensure(data)
	local granted = {}
	local boss = grantListed(data, "boss")
	if boss ~= nil then
		table.insert(granted, boss)
	end
	local day = dayNumber(now)
	if data.lastDailyBossDay ~= day then
		data.lastDailyBossDay = day
		local daily = grantListed(data, "dailyBoss")
		if daily ~= nil then
			table.insert(granted, daily)
		end
	end
	local week = weekNumber(now)
	if data.lastWeeklyBossWeek ~= week then
		data.lastWeeklyBossWeek = week
		local weekly = grantListed(data, "weeklyBoss")
		if weekly ~= nil then
			table.insert(granted, weekly)
		end
	end
	return granted
end

function ChestConfig.claimLogin(data: any, now: number): (any?, string?)
	ChestConfig.ensure(data)
	local day = dayNumber(now)
	local streak, paid = Loops.login(data.loginStreak or 0, data.lastLoginDay, day)
	if not paid then
		return nil, "Daily login is already claimed."
	end
	data.loginStreak = streak
	data.lastLoginDay = day
	local granted = { grantListed(data, "login") }
	if data.loginStreak % 7 == 0 then
		table.insert(granted, grantListed(data, "streak"))
	end
	return granted, nil
end

function ChestConfig.buyWithKeys(data: any, tier: string): (any?, string?)
	ChestConfig.ensure(data)
	local price = ChestConfig.KEY_SHOP[tier]
	if price == nil then
		return nil, "That chest is not sold."
	end
	if data.shardKeys < price then
		return nil, "Not enough Shard Keys."
	end
	data.shardKeys -= price
	ChestConfig.addChest(data, tier, 1)
	return { tier = tier, keys = price }, nil
end

local function payMaterials(data: any, cost: { [string]: number }): boolean
	for id, count in pairs(cost) do
		local owned = data.materials[id]
		if type(owned) ~= "number" or owned < count then
			return false
		end
	end
	for id, count in pairs(cost) do
		data.materials[id] -= count
	end
	return true
end

function ChestConfig.merge(data: any, tier: string): (any?, string?)
	ChestConfig.ensure(data)
	local spec = ChestConfig.MERGE[tier]
	if spec == nil then
		return nil, "That chest cannot be merged."
	end
	if data.chests[tier] < ChestConfig.MERGE_COUNT then
		return nil, "Merge needs 5 chests."
	end
	if not payMaterials(data, spec.materials) then
		return nil, "Not enough materials to merge."
	end
	data.chests[tier] -= ChestConfig.MERGE_COUNT
	ChestConfig.addChest(data, spec.next, 1)
	return { from = tier, to = spec.next }, nil
end

local function ownedSet(data: any): { [string]: any }
	local set = {}
	for _, bagName in ipairs({ "inventory", "pets" }) do
		local bag = data[bagName]
		if type(bag) == "table" then
			for _, item in pairs(bag) do
				if type(item) == "table" and type(item.templateId) == "string" then
					set[item.templateId] = item
				end
			end
		end
	end
	return set
end

local function entriesFor(data: any, rarity: string): { any }
	local list = {}
	for _, area in ipairs({ "armory", "pets" }) do
		for _, pool in ipairs(Pools.forArea(area)) do
			if pool.public == true and Pools.isUnlocked(pool, data.ascension) then
				for _, entry in ipairs(pool.entries) do
					if entry.rarity == rarity and entry.weight > 0 then
						table.insert(list, {
							templateId = entry.templateId,
							name = entry.name,
							rarity = entry.rarity,
							weight = entry.weight,
							poolId = pool.id,
						})
					end
				end
			end
		end
	end
	return list
end

local function pickEntry(data: any, rarity: string, rng: any, owned: { [string]: any }): any
	local rarityName = rarity
	local entries = entriesFor(data, rarityName)
	local guard = 0
	while #entries == 0 and guard < 8 do
		local rank = Rarities.INDEX[rarityName]
		if rank == nil or rank <= 1 then
			break
		end
		rarityName = Rarities.ORDER[rank - 1]
		entries = entriesFor(data, rarityName)
		guard += 1
	end
	if #entries == 0 then
		return nil
	end
	local total = 0
	local weights = {}
	for index, entry in ipairs(entries) do
		local weight = entry.weight
		if Rarities.isLegendaryOrBetter(entry.rarity) and owned[entry.templateId] == nil then
			weight *= 2
		end
		weights[index] = weight
		total += weight
	end
	local roll = unit(rng) * total
	local cursor = 0
	for index, entry in ipairs(entries) do
		cursor += weights[index]
		if roll < cursor then
			return entry
		end
	end
	return entries[#entries]
end

local function pickRarity(chances: { [string]: number }, rng: any): string
	local roll = unit(rng)
	local cursor = 0
	local last = "Common"
	for _, rarity in ipairs(ChestConfig.TIERS) do
		local chance = chances[rarity] or 0
		if chance > 0 then
			last = rarity
		end
		cursor += chance
		if roll < cursor then
			return rarity
		end
	end
	return last
end

local function forcedFloor(data: any, tier: string): string?
	if tier == "Rare" and data.rareChestsSinceEpic + 1 >= ChestConfig.RARE_PITY then
		return "Epic"
	end
	if tier == "Epic" and data.epicChestsSinceLegendary + 1 >= ChestConfig.EPIC_PITY then
		return "Legendary"
	end
	return nil
end

local function advancePity(data: any, tier: string, rarity: string)
	local rank = Rarities.rank(rarity)
	if tier == "Rare" then
		if rank >= Rarities.rank("Epic") then
			data.rareChestsSinceEpic = 0
		else
			data.rareChestsSinceEpic += 1
		end
	elseif tier == "Epic" then
		if rank >= Rarities.rank("Legendary") then
			data.epicChestsSinceLegendary = 0
		else
			data.epicChestsSinceLegendary += 1
		end
	end
end

local function giveDust(data: any, rarity: string)
	local dust = ChestConfig.DUST[rarity] or 0
	data.shardDust = math.min(999999, data.shardDust + dust)
	local material = ChestConfig.DUST_MATERIAL[rarity]
	local materialId = nil
	local materialCount = 0
	if material ~= nil then
		materialId = material.id
		materialCount = Materials.add(data.materials, material.id, material.count)
	end
	return dust, materialId, materialCount
end

local function salvageDuplicate(data: any, rarity: string): boolean
	local below = data.chestSalvageBelow
	if type(below) ~= "string" or below == "" then
		return data.chestDuplicates ~= "star"
	end
	return Rarities.rank(rarity) <= Rarities.rank(below) or data.chestDuplicates ~= "star"
end

local function findStarTarget(data: any, templateId: string): any?
	for _, bagName in ipairs({ "inventory", "pets" }) do
		local bag = data[bagName]
		if type(bag) == "table" then
			for _, item in pairs(bag) do
				if
					type(item) == "table"
					and item.templateId == templateId
					and whole(item.stars, 0) < Stars.MAX
				then
					return item
				end
			end
		end
	end
	return nil
end

local function resolveDrop(
	data: any,
	entry: any,
	rng: any,
	now: number,
	uid: () -> string,
	owned: { [string]: any }
)
	local existing = owned[entry.templateId]
	local dustIt = existing ~= nil and salvageDuplicate(data, entry.rarity)
	if existing ~= nil and not dustIt then
		local target = findStarTarget(data, entry.templateId)
		if target ~= nil then
			local preview = Stars.advance(target.stars, target.starProgress, 1)
			if preview ~= nil then
				target.stars = preview.stars
				target.starProgress = preview.starProgress
				target.perks = preview.perks
				Stars.applyStats(target)
				return {
					kind = "star",
					rarity = entry.rarity,
					name = entry.name,
					templateId = entry.templateId,
					stars = preview.stars,
					uid = target.uid,
				}
			end
		end
		dustIt = true
	end
	if dustIt or (existing ~= nil) then
		local dust, materialId, materialCount = giveDust(data, entry.rarity)
		return {
			kind = "dust",
			rarity = entry.rarity,
			name = entry.name,
			templateId = entry.templateId,
			dust = dust,
			materialId = materialId,
			materialCount = materialCount,
		}
	end
	if Schema.countItems(data) >= Schema.inventoryCap(data) then
		local dust, materialId, materialCount = giveDust(data, entry.rarity)
		return {
			kind = "dust",
			rarity = entry.rarity,
			name = entry.name,
			templateId = entry.templateId,
			dust = dust,
			materialId = materialId,
			materialCount = materialCount,
			bagFull = true,
		}
	end
	local item = RollMath.mint(entry.templateId, {
		uid = uid(),
		now = now,
		poolId = entry.poolId,
	}, rng)
	Schema.insertItem(data, item)
	owned[entry.templateId] = item
	return {
		kind = "item",
		rarity = item.rarity,
		name = item.name,
		templateId = item.templateId,
		uid = item.uid,
		item = item,
	}
end

local function fillerSeed(rng: any): number
	local seed = rng:nextInteger(1, 2147483646)
	if type(seed) ~= "number" then
		return 1
	end
	return seed
end

function ChestConfig.bestIndex(results: { any }): number
	local best = 1
	local bestRank = -1
	for index, row in ipairs(results) do
		local rank = Rarities.INDEX[row.rarity] or 0
		if rank > bestRank then
			bestRank = rank
			best = index
		end
	end
	return best
end

function ChestConfig.open(
	data: any,
	tier: string,
	count: number,
	rng: any,
	now: number,
	uid: () -> string
)
	ChestConfig.ensure(data)
	if ChestConfig.FLOOR[tier] == nil then
		return { ok = false, error = "Unknown chest." }
	end
	if type(data.pendingChest) == "table" then
		return { ok = false, error = "Choose a Mythic card first." }
	end
	local amount = whole(count, 1)
	if amount < 1 then
		amount = 1
	end
	if amount > ChestConfig.OPEN_MANY_MAX then
		amount = ChestConfig.OPEN_MANY_MAX
	end
	if tier == "Mythic" and amount ~= 1 then
		return { ok = false, error = "Open Mythic chests one at a time." }
	end
	if data.chests[tier] < amount then
		return { ok = false, error = "Not enough chests." }
	end
	local luck = RarityConfig.luckFromProfile(data)
	if tier == "Mythic" then
		local owned = ownedSet(data)
		local options = {}
		for _ = 1, 3 do
			local entry = pickEntry(data, "Mythic", rng, owned)
			if entry == nil then
				return { ok = false, error = "That chest has nothing to roll." }
			end
			table.insert(options, {
				templateId = entry.templateId,
				name = entry.name,
				rarity = entry.rarity,
				poolId = entry.poolId,
			})
		end
		data.chests[tier] -= 1
		local pending = {
			tier = "Mythic",
			options = options,
			fillerSeed = fillerSeed(rng),
		}
		data.pendingChest = pending
		return {
			ok = true,
			tier = tier,
			results = {},
			pending = pending,
			announces = {},
			bestIndex = 1,
			luck = luck,
		}
	end
	data.chests[tier] -= amount
	local owned = ownedSet(data)
	local results = {}
	local announces = {}
	for _ = 1, amount do
		local floor = forcedFloor(data, tier)
		local chances = ChestConfig.chances(tier, luck, floor)
		local rarity = pickRarity(chances, rng)
		local entry = pickEntry(data, rarity, rng, owned)
		if entry == nil then
			return { ok = false, error = "That chest has nothing to roll." }
		end
		advancePity(data, tier, entry.rarity)
		local drop = resolveDrop(data, entry, rng, now, uid, owned)
		drop.fillerSeed = fillerSeed(rng)
		drop.pity = floor ~= nil
		table.insert(results, drop)
		if drop.kind == "item" and Rarities.isLegendaryOrBetter(drop.rarity) then
			table.insert(announces, {
				name = drop.name,
				rarity = drop.rarity,
				crossServer = drop.rarity == "Mythic",
			})
		end
	end
	return {
		ok = true,
		tier = tier,
		results = results,
		pending = nil,
		announces = announces,
		bestIndex = ChestConfig.bestIndex(results),
		luck = luck,
	}
end

function ChestConfig.choose(data: any, index: number, rng: any, now: number, uid: () -> string)
	ChestConfig.ensure(data)
	local pending = data.pendingChest
	if type(pending) ~= "table" or type(pending.options) ~= "table" then
		return { ok = false, error = "No Mythic chest is waiting." }
	end
	local choice = pending.options[index]
	if type(choice) ~= "table" or type(choice.templateId) ~= "string" then
		return { ok = false, error = "Pick one of the three cards." }
	end
	data.pendingChest = nil
	local owned = ownedSet(data)
	local drop = resolveDrop(data, choice, rng, now, uid, owned)
	drop.fillerSeed = pending.fillerSeed or fillerSeed(rng)
	local announces = {}
	if drop.kind == "item" and Rarities.isLegendaryOrBetter(drop.rarity) then
		table.insert(announces, {
			name = drop.name,
			rarity = drop.rarity,
			crossServer = drop.rarity == "Mythic",
		})
	end
	return {
		ok = true,
		tier = "Mythic",
		results = { drop },
		pending = nil,
		announces = announces,
		bestIndex = 1,
		luck = RarityConfig.luckFromProfile(data),
	}
end

function ChestConfig.buyDustShard(
	data: any,
	templateId: string,
	rng: any,
	now: number,
	uid: () -> string
)
	ChestConfig.ensure(data)
	if type(templateId) ~= "string" or string.match(templateId, "^[%w_]+$") == nil then
		return { ok = false, error = "Unknown shard." }
	end
	local found = nil
	for _, rarity in ipairs({ "Epic", "Legendary" }) do
		for _, entry in ipairs(entriesFor(data, rarity)) do
			if entry.templateId == templateId then
				found = entry
				break
			end
		end
		if found ~= nil then
			break
		end
	end
	if found == nil then
		return { ok = false, error = "Dust cannot buy that shard." }
	end
	local price = ChestConfig.DUST_PRICE[found.rarity]
	if data.shardDust < price then
		return { ok = false, error = "Not enough Shard Dust." }
	end
	if Schema.countItems(data) >= Schema.inventoryCap(data) then
		return { ok = false, error = "Inventory is full." }
	end
	data.shardDust -= price
	local item = RollMath.mint(found.templateId, {
		uid = uid(),
		now = now,
		poolId = found.poolId,
	}, rng)
	Schema.insertItem(data, item)
	return {
		ok = true,
		item = item,
		name = item.name,
		rarity = item.rarity,
		dust = price,
	}
end

function ChestConfig.dustCatalog(data: any): { any }
	ChestConfig.ensure(data)
	local rows = {}
	for _, rarity in ipairs({ "Epic", "Legendary" }) do
		for _, entry in ipairs(entriesFor(data, rarity)) do
			table.insert(rows, {
				templateId = entry.templateId,
				name = entry.name,
				rarity = entry.rarity,
				cost = ChestConfig.DUST_PRICE[rarity],
			})
		end
	end
	return rows
end

for _, row in pairs(ODDS) do
	table.freeze(row)
end
table.freeze(ODDS)
table.freeze(ChestConfig.FLOOR)
table.freeze(ChestConfig.KEY_SHOP)
table.freeze(ChestConfig.DUST)
table.freeze(ChestConfig.DUST_PRICE)
table.freeze(ChestConfig.OPEN_SECONDS)
table.freeze(ChestConfig.REEL_SECONDS)
table.freeze(ChestConfig.LATER)
table.freeze(ChestConfig.TIERS)

return ChestConfig
