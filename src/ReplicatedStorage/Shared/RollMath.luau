--!strict

--[[
	Shard rolls, as plain functions.

	The server is the only place a roll is allowed to change a profile, but
	the math itself lives here so tests can run without Roblox.

	The player sheet is RarityConfig.disclose. The live crack is
	RarityConfig.pick (Epic at 100, Legendary at 1000). RollMath.odds is the
	weight table, not that sheet. Pity on this table follows
	pool.pityLegendaryAt. Live pools set that to RarityConfig.LEGENDARY_PITY.
	There is no Legendary guarantee at 50. Pity is not baked into the
	weight percentages until that guarantee is the next roll.

	Rng contract (matches Roblox Random):
	  nextNumber() -> number in [0, 1)
	  nextInteger(min, max) -> integer, inclusive on both ends
]]

local ItemBases = require("./ItemBases")
local Rarities = require("./Rarities")
local Stats = require("./Stats")
local Traits = require("./Traits")
local LaunchGate = require("./LaunchGate")

local RollMath = {}

export type Rng = Traits.Rng

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
	pityLegendaryAt: number,
	placeholder: boolean?,
	entries: { PoolEntry },
}

export type PityState = {
	rollsSinceLegendary: number,
	totalRolls: number,
}

export type RollContext = {
	luck: number,
	uid: string,
	now: number,
}

export type Item = {
	uid: string,
	templateId: string,
	name: string,
	kind: string,
	rarity: string,
	traits: { Traits.RolledTrait },
	stats: { any }?,
	quality: number?,
	weaponType: string?,
	slot: string?,
	setId: string?,
	poolId: string,
	obtainedAt: number,
}

export type RollResult = {
	item: Item,
	pityTriggered: boolean,
	rarity: string,
}

export type OddsEntry = {
	templateId: string,
	name: string,
	kind: string,
	rarity: string,
	weight: number,
	chance: number,
}

export type OddsRarity = {
	rarity: string,
	chance: number,
}

export type OddsQuery = {
	rollsSinceLegendary: number?,
	luckBoost: number?,
}

export type OddsTable = {
	poolId: string,
	poolName: string,
	luck: number,
	luckBoost: number,
	placeholder: boolean,
	pityLegendaryAt: number,
	rollsSinceLegendary: number,
	pityActive: boolean,
	notice: string,
	entries: { OddsEntry },
	rarities: { OddsRarity },
}

-- Kept so older notes still describe the same rule. odds() builds the
-- string the panel shows, including pity progress and an active boost.
RollMath.PLACEHOLDER_NOTICE =
	"PLACEHOLDER rates. Luck included. The pity guarantee is extra and not in these percentages."

RollMath.LIVE_NOTICE = "Luck included. The pity guarantee is extra and not in these percentages."

local function clampLuck(luckPoints: any): number
	if type(luckPoints) ~= "number" then
		return 0
	end
	if luckPoints ~= luckPoints or luckPoints < 0 then
		return 0
	end
	return luckPoints
end

-- Weight after luck. Common's exponent is 0, so luck never changes it;
-- rarer tiers grow, which is what shifts the percentages.
function RollMath.entryWeight(entry: PoolEntry, luckPoints: number): number
	local exponent = Rarities.LUCK_EXPONENT[entry.rarity]
	if exponent == nil then
		error(
			string.format(
				"Unknown rarity '%s' on '%s'",
				tostring(entry.rarity),
				tostring(entry.templateId)
			),
			2
		)
	end
	if type(entry.weight) ~= "number" or entry.weight < 0 then
		error("Bad weight on '" .. tostring(entry.templateId) .. "'", 2)
	end
	local luck = clampLuck(luckPoints)
	return entry.weight * ((1 + luck / 100) ^ exponent)
end

local function weighted(pool: Pool, luckPoints: number, allowed: { [string]: boolean }?)
	local weights = table.create(#pool.entries, 0)
	local total = 0
	for index, entry in ipairs(pool.entries) do
		local weight = 0
		local rarityOk = allowed == nil or allowed[entry.rarity] == true
		if rarityOk and entry.weight > 0 then
			weight = RollMath.entryWeight(entry, luckPoints)
		end
		weights[index] = weight
		total += weight
	end
	return weights, total
end

local function pickFrom(pool: Pool, weights: { number }, total: number, rng: Rng): PoolEntry
	if total <= 0 then
		error(
			string.format("Pool '%s' has nothing to roll. Check weights and rarities.", pool.id),
			2
		)
	end
	local cursor = rng:nextNumber() * total
	if cursor < 0 then
		cursor = 0
	end
	local walked = 0
	for index, entry in ipairs(pool.entries) do
		walked += weights[index]
		if cursor < walked then
			return entry
		end
	end
	for index = #pool.entries, 1, -1 do
		if weights[index] > 0 then
			return pool.entries[index]
		end
	end
	error(string.format("Pool '%s' has nothing to roll.", pool.id), 2)
end

function RollMath.formatChance(chance: number): string
	local percent = chance * 100
	if percent >= 1 then
		return string.format("%.2f%%", percent)
	end
	return string.format("%.3f%%", percent)
end

-- Counts up. 0 is an empty bar, and `goal` is the guaranteed Legendary roll.
-- The number is the rolls already made since the last Legendary or better,
-- not a countdown of rolls remaining.
function RollMath.pityText(current: number, goal: number): string
	local shown = current
	if type(shown) ~= "number" or shown ~= shown or shown < 0 then
		shown = 0
	end
	shown = math.floor(shown)
	local target = goal
	if type(target) ~= "number" or target ~= target or target < 1 then
		target = 1
	end
	target = math.floor(target)
	if shown > target then
		shown = target
	end
	return string.format("Pity %d / %d toward Legendary", shown, target)
end

local function queryParts(query: any): (number, number)
	if type(query) == "number" then
		if query ~= query or query < 0 then
			return 0, 0
		end
		return math.floor(query), 0
	end
	if type(query) ~= "table" then
		return 0, 0
	end
	local since = query.rollsSinceLegendary
	if type(since) ~= "number" or since ~= since or since < 0 then
		since = 0
	else
		since = math.floor(since)
	end
	local boost = query.luckBoost
	if type(boost) ~= "number" or boost ~= boost or boost < 0 then
		boost = 0
	end
	return since, boost
end

local function oddsNotice(
	placeholder: boolean,
	luck: number,
	boost: number,
	since: number,
	goal: number,
	pityActive: boolean
): string
	local lines = {}
	if placeholder then
		table.insert(lines, "PLACEHOLDER rates.")
	end
	if boost > 0 then
		table.insert(lines, string.format("Luck %d, including +%d Luck Boost.", luck, boost))
	else
		table.insert(lines, string.format("Luck %d.", luck))
	end
	if pityActive then
		table.insert(
			lines,
			"Next roll is the pity guarantee: Legendary or better. These percentages are that roll."
		)
	else
		table.insert(
			lines,
			string.format(
				"Pity %d/%d toward Legendary. The pity guarantee is extra and not in these percentages until it is the next roll.",
				since,
				goal
			)
		)
	end
	table.insert(lines, "Every outcome is an item.")
	table.insert(
		lines,
		"Probabilities are rounded; total of displayed individual probabilities may not equal 100%."
	)
	return table.concat(lines, " ")
end

function RollMath.odds(pool: Pool, luckPoints: number, query: any): OddsTable
	local since, boost = queryParts(query)
	local luck = clampLuck(luckPoints) + clampLuck(boost)
	local pityActive = since + 1 >= pool.pityLegendaryAt
	local allowed = if pityActive then Rarities.PITY_RESET else nil
	local weights, total = weighted(pool, luck, allowed)
	if total <= 0 then
		error(string.format("Pool '%s' has no positive weights.", pool.id), 2)
	end

	local entries = {}
	local chanceSum = 0
	for index, entry in ipairs(pool.entries) do
		if weights[index] > 0 then
			if
				type(entry.name) ~= "string"
				or entry.name == ""
				or entry.kind == ""
				or entry.kind == "Nothing"
			then
				error(string.format("Pool '%s' has an empty outcome.", pool.id), 2)
			end
			local chance = weights[index] / total
			if chance <= 0 then
				error(string.format("Pool '%s' has an empty outcome.", pool.id), 2)
			end
			chanceSum += chance
			table.insert(entries, {
				templateId = entry.templateId,
				name = entry.name,
				kind = entry.kind,
				rarity = entry.rarity,
				weight = entry.weight,
				chance = chance,
			})
		end
	end
	-- Float division can leave the table 0.0000000001 short of 1. Put the
	-- dust on the last row so a player adding the disclosed chances gets 100%.
	if #entries > 0 and chanceSum ~= 1 then
		local last = entries[#entries]
		last.chance += 1 - chanceSum
	end

	local rarityChance: { [string]: number } = {}
	for _, row in ipairs(entries) do
		rarityChance[row.rarity] = (rarityChance[row.rarity] or 0) + row.chance
	end
	local rarities = {}
	for _, rarity in ipairs(Rarities.ORDER) do
		local chance = rarityChance[rarity]
		if chance ~= nil and chance > 0 then
			table.insert(rarities, {
				rarity = rarity,
				chance = chance,
			})
		end
	end

	local placeholder = pool.placeholder == true
	return {
		poolId = pool.id,
		poolName = pool.name,
		luck = luck,
		luckBoost = boost,
		placeholder = placeholder,
		pityLegendaryAt = pool.pityLegendaryAt,
		rollsSinceLegendary = since,
		pityActive = pityActive,
		notice = oddsNotice(placeholder, luck, boost, since, pool.pityLegendaryAt, pityActive),
		entries = entries,
		rarities = rarities,
	}
end

local function finiteCount(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function normalizePity(pity: PityState)
	if not finiteCount(pity.rollsSinceLegendary) then
		pity.rollsSinceLegendary = 0
	end
	if not finiteCount(pity.totalRolls) then
		pity.totalRolls = 0
	end
end

--[[
	Rolls once and updates `pity` in place.

	When rollsSinceLegendary + 1 would reach the pool's pityLegendaryAt, the
	roll is taken only from Legendary / Mythic / Secret (still weighted, so a
	Mythic can satisfy the guarantee). Any Legendary-or-better result, forced
	or not, resets the counter.
]]
local function gearWeight(base: ItemBases.Base?): any
	if base ~= nil and base.kind == "Pet" then
		return "pet"
	end
	if base ~= nil then
		return base.weaponType
	end
	return nil
end

-- Stats come from the catalog base. Traits follow the drop's kind even when
-- the template id is not in the catalog (test pools). Materials roll none.
local function rollGear(
	base: ItemBases.Base?,
	rarity: string,
	kind: string,
	rng: Rng
): ({ any }, number?, { Traits.RolledTrait })
	local stats = {}
	local quality = nil
	if base ~= nil and type(base.stats) == "table" and #base.stats > 0 then
		stats, quality = Stats.roll(base.stats, rarity, gearWeight(base), rng)
	end
	local traits = {}
	if not LaunchGate.on("traits") then
		return stats, quality, traits
	end
	if kind == "Weapon" or kind == "Armor" then
		traits = Traits.roll(rarity, rng)
	elseif kind == "Pet" then
		traits = Traits.rollPet(rarity, rng)
	end
	return stats, quality, traits
end

function RollMath.roll(pool: Pool, pity: PityState, context: RollContext, rng: Rng): RollResult
	if type(pool) ~= "table" or type(pool.entries) ~= "table" then
		error("RollMath.roll expected a pool", 2)
	end
	if type(pool.pityLegendaryAt) ~= "number" or pool.pityLegendaryAt < 1 then
		error(string.format("Pool '%s' needs pityLegendaryAt >= 1", tostring(pool.id)), 2)
	end
	if type(context) ~= "table" or type(context.uid) ~= "string" or context.uid == "" then
		error("Roll context is missing a uid", 2)
	end
	normalizePity(pity)

	local pityTriggered = pity.rollsSinceLegendary + 1 >= pool.pityLegendaryAt
	local allowed = if pityTriggered then Rarities.PITY_RESET else nil
	local weights, total = weighted(pool, context.luck, allowed)
	local entry = pickFrom(pool, weights, total, rng)

	local base = ItemBases.get(entry.templateId)
	local stats, quality, traits = rollGear(base, entry.rarity, entry.kind, rng)

	if Rarities.isLegendaryOrBetter(entry.rarity) then
		pity.rollsSinceLegendary = 0
	else
		pity.rollsSinceLegendary += 1
	end
	pity.totalRolls += 1

	local obtainedAt = context.now
	if type(obtainedAt) ~= "number" then
		obtainedAt = 0
	end

	return {
		item = {
			uid = context.uid,
			templateId = entry.templateId,
			name = entry.name,
			kind = entry.kind,
			rarity = entry.rarity,
			traits = traits,
			stats = stats,
			quality = quality,
			weaponType = if base ~= nil then base.weaponType else nil,
			slot = if base ~= nil then base.slot else nil,
			setId = if base ~= nil then base.setId else nil,
			poolId = pool.id,
			obtainedAt = obtainedAt,
		},
		pityTriggered = pityTriggered,
		rarity = entry.rarity,
	}
end

export type MintContext = {
	uid: string,
	now: number,
	poolId: string?,
}

-- Builds one specific item. Crafting uses this so a bench result rolls stats
-- and traits the same way a shard drop does, without touching pity.
function RollMath.mint(templateId: string, context: MintContext, rng: Rng): Item
	local base = ItemBases.get(templateId)
	if base == nil then
		error("Unknown item '" .. tostring(templateId) .. "'", 2)
	end
	if type(context) ~= "table" or type(context.uid) ~= "string" or context.uid == "" then
		error("Mint context is missing a uid", 2)
	end

	local stats, quality, traits = rollGear(base, base.rarity, base.kind, rng)

	local obtainedAt = context.now
	if type(obtainedAt) ~= "number" then
		obtainedAt = 0
	end
	local poolId = context.poolId
	if type(poolId) ~= "string" or poolId == "" then
		poolId = "craft"
	end

	return {
		uid = context.uid,
		templateId = base.id,
		name = base.name,
		kind = base.kind,
		rarity = base.rarity,
		traits = traits,
		stats = stats,
		quality = quality,
		weaponType = base.weaponType,
		slot = base.slot,
		setId = base.setId,
		poolId = poolId,
		obtainedAt = obtainedAt,
	}
end

-- Roblox Random when the engine provides it; math.random under Lune.
function RollMath.defaultRng(): Rng
	local ok, randomLib = pcall(function()
		return Random :: any
	end)
	if ok and type(randomLib) == "table" and type(randomLib.new) == "function" then
		local rng = randomLib.new()
		return {
			nextNumber = function(_self: Rng): number
				return rng:NextNumber()
			end,
			nextInteger = function(_self: Rng, min: number, max: number): number
				return rng:NextInteger(min, max)
			end,
		}
	end
	return {
		nextNumber = function(_self: Rng): number
			return math.random()
		end,
		nextInteger = function(_self: Rng, min: number, max: number): number
			return math.random(min, max)
		end,
	}
end

return RollMath
