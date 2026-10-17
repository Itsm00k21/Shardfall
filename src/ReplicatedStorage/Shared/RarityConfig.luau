--!strict

--[[
	Shared shard-roll config. The server draws with this table and the client
	only plays it back. Odds, colors, pity, luck, and timings live here so the
	odds panel and the reel cannot drift apart.

	Rarity is checked rarest-first. Each listed 1-in-N is that check. The
	commonest rarity in the pool absorbs whatever is left, so the percents
	sum to 100. Secret is on the ladder because pools can drop it; a hidden
	outcome would break the paid-random disclosure rule.
]]

local Rarities = require("./Rarities")

local RarityConfig = {}

-- Global kill switch for paid luck, Prism rolls, and Quick Roll.
RarityConfig.PAID_LUCK_ENABLED = false
RarityConfig.REGION_MESSAGE = "Unavailable in your region"
RarityConfig.PAID_OFF_MESSAGE = "Paid luck is turned off."
RarityConfig.QUICK_OFF_MESSAGE = "Quick Roll is turned off."
RarityConfig.QUICK_LOCKED_MESSAGE = "Quick Roll is a separate unlock."

RarityConfig.MIN_TAP = 60
RarityConfig.REEL_SLOTS = 10
RarityConfig.TOPIC = "ShardfallMythic"

RarityConfig.COOLDOWN = 0.6
RarityConfig.QUICK_COOLDOWN = 1.0
RarityConfig.BOUNCE = 0.15
RarityConfig.REEL = 1.45
RarityConfig.LAND = 0.4
RarityConfig.CARD = 0.6
RarityConfig.EPIC_EXTRA = 0.5
RarityConfig.QUICK_POP = 0.25
RarityConfig.LEGENDARY_SCENE = 1.5
RarityConfig.MYTHIC_SCENE = 3
RarityConfig.SKIP_AFTER = 1
RarityConfig.SHAKE = 0.3
RarityConfig.AUTO_DISMISS = 1.5

RarityConfig.BONUS_EVERY = 10
RarityConfig.EPIC_PITY = 100
RarityConfig.LEGENDARY_PITY = 1000

local ONE_IN: { [string]: number } = {
	Common = 2,
	Uncommon = 5,
	Rare = 25,
	Epic = 250,
	Legendary = 2500,
	Mythic = 25000,
	Secret = 100000,
}

export type Rng = {
	nextNumber: (self: Rng) -> number,
	nextInteger: (self: Rng, min: number, max: number) -> number,
}

export type PityCounters = {
	sinceEpic: number,
	sinceLegendary: number,
}

local function whole(value: any, fallback: number): number
	local numberValue = tonumber(value)
	if numberValue == nil or numberValue ~= numberValue then
		return fallback
	end
	return math.floor(numberValue)
end

local function entriesOf(pool: any): { any }
	if type(pool) ~= "table" or type(pool.entries) ~= "table" then
		return {}
	end
	return pool.entries
end

function RarityConfig.color(rarity: string): (number, number, number)
	return Rarities.rgb(rarity)
end

function RarityConfig.oneIn(rarity: string): number
	return ONE_IN[rarity] or 2
end

-- (1 + base) * bonusRoll + potion
-- base and potion are luck points / 100. The 10th roll sets bonusRoll to 2.
-- The paid potion drops out while the kill switch is off.
-- vip is cosmetic. It is not a term in this formula.
function RarityConfig.luckMultiplier(input: any): number
	local source = if type(input) == "table" then input else {}
	local base = whole(source.shardLuck, 0) / 100
	if base < 0 then
		base = 0
	end
	local rolls = whole(source.shardRolls, 0)
	if rolls < 0 then
		rolls = 0
	end
	local paid = if source.paidLuck == nil
		then RarityConfig.PAID_LUCK_ENABLED
		else source.paidLuck == true
	local potion = 0
	if paid then
		potion = whole(source.luckBoost, 0) / 100
		if potion < 0 then
			potion = 0
		end
	end
	local bonus = if (rolls + 1) % RarityConfig.BONUS_EVERY == 0 then 2 else 1
	local value = (1 + base) * bonus + potion
	if value ~= value or value < 1 then
		return 1
	end
	return value
end

function RarityConfig.luckFromProfile(data: any): number
	if type(data) ~= "table" then
		return RarityConfig.luckMultiplier({})
	end
	return RarityConfig.luckMultiplier({
		shardLuck = data.shardLuck,
		luckBoost = data.luckBoost,
		shardRolls = data.shardRolls,
		vip = data.vip == true,
	})
end

function RarityConfig.effectiveOneIn(rarity: string, luck: number): number
	local multiplier = luck
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 then
		multiplier = 1
	end
	local threshold = RarityConfig.oneIn(rarity) / multiplier
	if threshold < 1 then
		return 1
	end
	return threshold
end

function RarityConfig.bonusLabel(shardRolls: any): string
	local rolls = whole(shardRolls, 0)
	if rolls < 0 then
		rolls = 0
	end
	local remaining = RarityConfig.BONUS_EVERY - (rolls % RarityConfig.BONUS_EVERY)
	if remaining == 1 then
		return "x2 Luck Ready"
	end
	return "x2 Luck in " .. tostring(remaining)
end

function RarityConfig.pityLine(sinceEpic: any, sinceLegendary: any): string
	local epic = whole(sinceEpic, 0)
	local legendary = whole(sinceLegendary, 0)
	if epic < 0 then
		epic = 0
	end
	if legendary < 0 then
		legendary = 0
	end
	return string.format(
		"Epic %d/%d · Legendary %d/%d",
		epic,
		RarityConfig.EPIC_PITY,
		legendary,
		RarityConfig.LEGENDARY_PITY
	)
end

-- Rarest first, limited to rarities the pool can actually grant.
function RarityConfig.present(pool: any): { string }
	local have: { [string]: boolean } = {}
	for _, entry in ipairs(entriesOf(pool)) do
		if type(entry) == "table" and type(entry.rarity) == "string" then
			local weight = entry.weight
			if type(weight) ~= "number" or weight > 0 then
				have[entry.rarity] = true
			end
		end
	end
	local list = {}
	for index = #Rarities.ORDER, 1, -1 do
		local name = Rarities.ORDER[index]
		if have[name] then
			table.insert(list, name)
		end
	end
	return list
end

local function unit(rng: Rng): number
	local value = rng:nextNumber()
	if value < 0 then
		return 0
	end
	if value >= 1 then
		return 0.999999
	end
	return value
end

local function naturalPick(pool: any, luck: number, rng: Rng): string
	local ladder = RarityConfig.present(pool)
	if #ladder == 0 then
		return "Common"
	end
	for index = 1, #ladder - 1 do
		local rarity = ladder[index]
		local threshold = RarityConfig.effectiveOneIn(rarity, luck)
		if unit(rng) < (1 / threshold) then
			return rarity
		end
	end
	return ladder[#ladder]
end

local function bestAtLeast(pool: any, floor: string): string?
	local floorRank = Rarities.rank(floor)
	local closest = nil
	for _, name in ipairs(RarityConfig.present(pool)) do
		if Rarities.rank(name) >= floorRank then
			closest = name
		end
	end
	return closest
end

function RarityConfig.pick(pool: any, luck: number, pity: any, rng: Rng): (string, boolean, string?)
	local counters = if type(pity) == "table" then pity else {}
	local sinceEpic = whole(counters.sinceEpic, 0)
	local sinceLegendary = whole(counters.sinceLegendary, 0)
	if sinceEpic < 0 then
		sinceEpic = 0
	end
	if sinceLegendary < 0 then
		sinceLegendary = 0
	end
	local floor = nil
	if sinceLegendary + 1 >= RarityConfig.LEGENDARY_PITY then
		floor = "Legendary"
	elseif sinceEpic + 1 >= RarityConfig.EPIC_PITY then
		floor = "Epic"
	end
	local natural = naturalPick(pool, luck, rng)
	local chosen = natural
	if floor ~= nil and Rarities.rank(natural) < Rarities.rank(floor) then
		local raised = bestAtLeast(pool, floor)
		if raised == nil then
			local present = RarityConfig.present(pool)
			raised = present[1] or natural
		end
		chosen = raised
	end
	return chosen, floor ~= nil, floor
end

function RarityConfig.advance(pity: PityCounters, granted: string, floor: string?)
	local rank = Rarities.rank(granted)
	local clearEpic = rank >= Rarities.rank("Epic") or floor == "Epic" or floor == "Legendary"
	local clearLegendary = rank >= Rarities.rank("Legendary") or floor == "Legendary"
	if clearLegendary then
		pity.sinceEpic = 0
		pity.sinceLegendary = 0
	elseif clearEpic then
		pity.sinceEpic = 0
		pity.sinceLegendary = whole(pity.sinceLegendary, 0) + 1
	else
		pity.sinceEpic = whole(pity.sinceEpic, 0) + 1
		pity.sinceLegendary = whole(pity.sinceLegendary, 0) + 1
	end
end

function RarityConfig.chooseEntry(pool: any, rarity: string, rng: Rng): any
	local ladder = RarityConfig.present(pool)
	local startIndex = 1
	for index, name in ipairs(ladder) do
		if name == rarity then
			startIndex = index
			break
		end
	end
	for index = startIndex, #ladder do
		local name = ladder[index]
		local options = {}
		local total = 0
		for _, entry in ipairs(entriesOf(pool)) do
			if type(entry) == "table" and entry.rarity == name then
				local weight = entry.weight
				if type(weight) ~= "number" or weight <= 0 then
					weight = 0
				end
				if weight > 0 then
					table.insert(options, entry)
					total += weight
				end
			end
		end
		if #options > 0 and total > 0 then
			local roll = unit(rng) * total
			local cursor = 0
			for _, entry in ipairs(options) do
				cursor += entry.weight
				if roll < cursor then
					return entry
				end
			end
			return options[#options]
		end
	end
	local all = entriesOf(pool)
	return all[1]
end

local function lcg(seed: number): Rng
	local modulus = 2147483647
	local state = math.floor(seed) % modulus
	if state < 1 then
		state = 1
	end
	local rng = {} :: Rng
	function rng:nextNumber(): number
		state = (state * 48271) % modulus
		return (state - 1) / 2147483646
	end
	function rng:nextInteger(min: number, max: number): number
		local span = max - min + 1
		if span < 1 then
			return min
		end
		return min + math.floor(self:nextNumber() * span)
	end
	return rng
end

function RarityConfig.reel(
	seed: number,
	pool: any,
	luck: number,
	resultName: string,
	resultRarity: string
)
	local rng = lcg(seed)
	local slots = {}
	for _ = 1, RarityConfig.REEL_SLOTS - 1 do
		local rarity = naturalPick(pool, luck, rng)
		local entry = RarityConfig.chooseEntry(pool, rarity, rng)
		local name = rarity
		local shown = rarity
		if type(entry) == "table" then
			name = tostring(entry.name)
			shown = tostring(entry.rarity)
		end
		table.insert(slots, { name = name, rarity = shown })
	end
	table.insert(slots, { name = resultName, rarity = resultRarity })
	return slots
end

-- The label is the luck-adjusted check (Common stays "1 in 2" at x1).
-- The percent beside it is the true rarest-first chance, so Common's
-- percent is whatever the rarer checks did not take.
local function shownOneIn(rarity: string, luck: number): number
	return math.max(1, math.floor(RarityConfig.effectiveOneIn(rarity, luck) + 0.5))
end

function RarityConfig.formatPercent(chance: number): string
	local percent = chance * 100
	if percent >= 1 then
		return string.format("%.2f%%", percent)
	end
	return string.format("%.4f%%", percent)
end

function RarityConfig.disclose(pool: any, luck: number)
	local multiplier = luck
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 then
		multiplier = 1
	end
	local ladder = RarityConfig.present(pool)
	local remaining = 1
	local byRarity: { [string]: number } = {}
	for index, rarity in ipairs(ladder) do
		local chance
		if index == #ladder then
			chance = remaining
		else
			local hit = math.min(1, 1 / RarityConfig.effectiveOneIn(rarity, multiplier))
			chance = remaining * hit
			remaining *= 1 - hit
		end
		byRarity[rarity] = chance
	end
	local rarities = {}
	for _, rarity in ipairs(Rarities.ORDER) do
		local chance = byRarity[rarity]
		if chance ~= nil then
			table.insert(rarities, {
				rarity = rarity,
				chance = chance,
				oneIn = shownOneIn(rarity, multiplier),
			})
		end
	end
	local weightByRarity: { [string]: number } = {}
	for _, entry in ipairs(entriesOf(pool)) do
		if
			type(entry) == "table"
			and type(entry.rarity) == "string"
			and type(entry.weight) == "number"
		then
			weightByRarity[entry.rarity] = (weightByRarity[entry.rarity] or 0) + entry.weight
		end
	end
	local rows = {}
	for _, entry in ipairs(entriesOf(pool)) do
		if type(entry) == "table" and type(entry.weight) == "number" and entry.weight > 0 then
			local rarityChance = byRarity[entry.rarity] or 0
			local total = weightByRarity[entry.rarity] or entry.weight
			table.insert(rows, {
				name = entry.name,
				rarity = entry.rarity,
				templateId = entry.templateId,
				chance = rarityChance * (entry.weight / total),
			})
		end
	end
	return {
		notice = string.format(
			"Luck x%.2f. Every 10th roll is x2. Epic+ at %d, Legendary+ at %d.",
			multiplier,
			RarityConfig.EPIC_PITY,
			RarityConfig.LEGENDARY_PITY
		),
		luck = multiplier,
		rarities = rarities,
		entries = rows,
	}
end

function RarityConfig.formatLine(row: any): string
	return string.format(
		"%s  1 in %d  (%s)",
		tostring(row.rarity),
		row.oneIn,
		RarityConfig.formatPercent(row.chance)
	)
end

function RarityConfig.quickEntitled(data: any, now: number): boolean
	if type(data) ~= "table" then
		return false
	end
	if data.quickRoll == true then
		return true
	end
	local untilTime = data.quickRollUntil
	if type(untilTime) == "number" and untilTime > now then
		return true
	end
	return false
end

function RarityConfig.quickAllowed(
	policyOk: boolean,
	killSwitch: boolean,
	entitled: boolean
): boolean
	return policyOk == true and killSwitch == true and entitled == true
end

function RarityConfig.quickDenial(
	policyOk: boolean,
	killSwitch: boolean,
	entitled: boolean
): string?
	if killSwitch ~= true then
		return RarityConfig.QUICK_OFF_MESSAGE
	end
	if policyOk ~= true then
		return RarityConfig.REGION_MESSAGE
	end
	if entitled ~= true then
		return RarityConfig.QUICK_LOCKED_MESSAGE
	end
	return nil
end

function RarityConfig.cooldown(quick: boolean): number
	if quick then
		return RarityConfig.QUICK_COOLDOWN
	end
	return RarityConfig.COOLDOWN
end

function RarityConfig.particleCap(tier: any, rarity: string): number
	local id = string.lower(tostring(tier or "med"))
	local mythic = rarity == "Mythic" or rarity == "Secret"
	if id == "low" and mythic then
		return 0
	end
	if id == "low" then
		return 30
	end
	if id == "high" then
		return 120
	end
	return 60
end

function RarityConfig.reveal(rarity: string, quick: boolean)
	local mythic = rarity == "Mythic" or rarity == "Secret"
	local legendary = rarity == "Legendary"
	local epic = rarity == "Epic"
	local plain = rarity == "Common" or rarity == "Uncommon"
	local toastOnly = quick == true and plain
	local shake = 0
	if (epic or legendary or mythic) and not toastOnly then
		shake = RarityConfig.SHAKE
	end
	return {
		toastOnly = toastOnly,
		reel = quick ~= true and not mythic,
		reelSeconds = if epic and quick ~= true
			then RarityConfig.REEL + RarityConfig.EPIC_EXTRA
			else RarityConfig.REEL,
		landSeconds = RarityConfig.LAND,
		cardSeconds = RarityConfig.CARD,
		quickPop = quick == true and not toastOnly and not mythic,
		cutscene = if mythic
			then RarityConfig.MYTHIC_SCENE
			elseif legendary and quick ~= true then RarityConfig.LEGENDARY_SCENE
			else 0,
		skipAfter = if mythic then RarityConfig.SKIP_AFTER else 0,
		shake = shake,
		stall = mythic,
		announce = legendary or mythic,
		crossServer = mythic,
		bounce = RarityConfig.BOUNCE,
	}
end

function RarityConfig.cycleSeconds(): number
	return RarityConfig.BOUNCE + RarityConfig.REEL + RarityConfig.LAND + RarityConfig.CARD
end

table.freeze(ONE_IN)

return RarityConfig
