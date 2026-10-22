--!strict

--[[
	Shared shard-roll config. The server draws with this table and the client
	only plays it back. Odds, colors, pity, luck, and timings live here so the
	odds panel and the reel cannot drift apart.

	Rarity is checked rarest-first. Each listed 1-in-N is that check. The
	commonest rarity in the pool absorbs whatever is left, so the percents
	sum to 100.

	Phase 1.3 (Kevin, Oct 22 2026): rolls use the 5-tier V1 ladder in
	Config/Rarities (Common 1/2 remainder, Uncommon 1/4, Rare 1/15,
	Epic 1/100, Legendary 1/1000) with one free Legendary pity (hard 150,
	soft from 100). The checks give Common 69.2%, Uncommon 23.1%,
	Rare 6.59%, Epic 0.999% and Legendary 0.1% at luck x1, and the odds
	sheet prints those percentages.

	Mythic and Secret stay on the Rarities ladder so owned items keep
	their color and rank, but they are parked for Phase 5: they do not
	roll while LaunchGate.extraTiers is off. Their old 1-in-N sits in
	PARKED_ONE_IN for when that switch comes on.
]]

local V1 = require("./Config/Rarities")
local LaunchGate = require("./LaunchGate")
local Rarities = require("./Rarities")
local RollConfig = require("./RollConfig")

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

-- Timings and pity live in RollConfig (one config for every roll number).
-- These aliases keep the old names readable for existing callers.
RarityConfig.COOLDOWN = RollConfig.COOLDOWN
RarityConfig.QUICK_COOLDOWN = RollConfig.QUICK_COOLDOWN
RarityConfig.BOUNCE = RollConfig.BOUNCE
RarityConfig.REEL = RollConfig.REEL
RarityConfig.LAND = RollConfig.LAND
RarityConfig.CARD = RollConfig.CARD
RarityConfig.EPIC_EXTRA = RollConfig.EPIC_EXTRA
RarityConfig.QUICK_POP = RollConfig.QUICK_POP
RarityConfig.LEGENDARY_SCENE = RollConfig.LEGENDARY_SCENE
RarityConfig.MYTHIC_SCENE = RollConfig.MYTHIC_SCENE
RarityConfig.SKIP_AFTER = RollConfig.SKIP_AFTER
RarityConfig.SHAKE = RollConfig.SHAKE
RarityConfig.AUTO_DISMISS = RollConfig.AUTO_DISMISS

RarityConfig.BONUS_EVERY = RollConfig.BONUS_EVERY
RarityConfig.LEGENDARY_PITY = RollConfig.LEGENDARY_PITY
RarityConfig.ROUNDING_NOTE =
	"Probabilities are rounded; total of displayed individual probabilities may not equal 100%."

-- The rolling ladder: Config/Rarities (V1, 5 tiers).
local ONE_IN: { [string]: number } = {}
for _, id in ipairs(V1.ORDER) do
	ONE_IN[id] = V1.TIERS[id].oneIn
end

-- Parked tiers (Phase 5). Only read while LaunchGate.extraTiers is on.
local PARKED_ONE_IN: { [string]: number } = {
	Mythic = 25000,
	Secret = 100000,
}

export type Rng = {
	nextNumber: (self: Rng) -> number,
	nextInteger: (self: Rng, min: number, max: number) -> number,
}

-- sinceEpic may still sit on old saves. Nothing reads it any more.
export type PityCounters = {
	sinceEpic: number?,
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

-- True when this tier can come out of a roll. Owned items of a parked
-- tier still load and display; they just are not drawn.
function RarityConfig.rolls(rarity: any): boolean
	if type(rarity) ~= "string" then
		return false
	end
	if ONE_IN[rarity] ~= nil then
		return true
	end
	return PARKED_ONE_IN[rarity] ~= nil and LaunchGate.on("extraTiers")
end

function RarityConfig.oneIn(rarity: string): number
	return ONE_IN[rarity] or PARKED_ONE_IN[rarity] or 2
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

function RarityConfig.pityLine(sinceLegendary: any): string
	local legendary = whole(sinceLegendary, 0)
	if legendary < 0 then
		legendary = 0
	end
	return string.format("Legendary pity %d/%d", legendary, RarityConfig.LEGENDARY_PITY)
end

-- Rarest first, limited to rarities the pool can actually grant.
function RarityConfig.present(pool: any): { string }
	local have: { [string]: boolean } = {}
	for _, entry in ipairs(entriesOf(pool)) do
		if type(entry) == "table" and RarityConfig.rolls(entry.rarity) then
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

-- One check per tier, rarest first. soft is the extra absolute
-- Legendary chance from soft pity (0 when not in the soft window).
local function naturalPick(pool: any, luck: number, rng: Rng, soft: number?): string
	local ladder = RarityConfig.present(pool)
	if #ladder == 0 then
		return "Common"
	end
	for index = 1, #ladder - 1 do
		local rarity = ladder[index]
		local threshold = RarityConfig.effectiveOneIn(rarity, luck)
		local hit = 1 / threshold
		if rarity == "Legendary" and soft ~= nil and soft > 0 then
			hit = math.min(1, hit + soft)
		end
		if unit(rng) < hit then
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

-- One draw. Only the Legendary pity floor exists: the roll that would
-- be number LEGENDARY_PITY since the last Legendary+ is raised to
-- Legendary. From SOFT_FROM on, the Legendary check also gets the
-- soft-pity bonus. A saved sinceEpic is ignored.
function RarityConfig.pick(pool: any, luck: number, pity: any, rng: Rng): (string, boolean, string?)
	local counters = if type(pity) == "table" then pity else {}
	local sinceLegendary = whole(counters.sinceLegendary, 0)
	if sinceLegendary < 0 then
		sinceLegendary = 0
	end
	local floor = nil
	if sinceLegendary + 1 >= RarityConfig.LEGENDARY_PITY then
		floor = "Legendary"
	end
	local natural = naturalPick(pool, luck, rng, RollConfig.softBonus(sinceLegendary))
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

-- Legendary or better (natural, soft or forced) clears the meter;
-- anything else adds one. sinceEpic is left exactly as it was saved.
function RarityConfig.advance(pity: PityCounters, granted: string, floor: string?)
	local rank = Rarities.rank(granted)
	if rank >= Rarities.rank("Legendary") or floor == "Legendary" then
		pity.sinceLegendary = 0
	else
		local since = whole(pity.sinceLegendary, 0)
		if since < 0 then
			since = 0
		end
		pity.sinceLegendary = since + 1
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

-- oneIn on a disclose row stays the luck-adjusted check. The printed
-- line does not use that check. It prints one 1-in and one percent, both
-- taken from the disclosed chance, so the two figures agree.
local function shownOneIn(rarity: string, luck: number): number
	return math.max(1, math.floor(RarityConfig.effectiveOneIn(rarity, luck) + 0.5))
end

local function shownPair(chance: number): (number, number, string)
	local percent = 0
	if type(chance) == "number" and chance == chance and chance > 0 and chance < math.huge then
		percent = chance * 100
	end
	if percent > 100 then
		percent = 100
	end
	local shown: number
	local text: string
	if percent >= 9.95 then
		shown = math.floor(percent + 0.5)
		text = string.format("%d%%", shown)
	elseif percent >= 1 then
		shown = math.floor(percent * 10 + 0.5) / 10
		if math.abs(shown - math.floor(shown + 1e-9)) < 1e-6 then
			text = string.format("%d%%", math.floor(shown + 0.5))
		else
			text = string.format("%.1f%%", shown)
		end
	else
		shown = math.floor(percent * 100 + 0.5) / 100
		if shown <= 0 and percent > 0 then
			shown = 0.01
		end
		text = string.format("%.2f%%", shown)
	end
	local oneIn = 1
	if shown > 0 then
		oneIn = math.max(1, math.floor((100 / shown) + 0.5))
	end
	return oneIn, shown, text
end

function RarityConfig.formatPercent(chance: number): string
	local _, _, text = shownPair(chance)
	return text
end

function RarityConfig.disclose(pool: any, luck: number, sinceLegendary: any?)
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
	local guarantee = if sinceLegendary ~= nil
		then RollConfig.pityText(sinceLegendary) .. " (free pity, never sold). "
		else ""
	return {
		notice = string.format(
			"Luck x%.2f. Every %dth roll is x2. Legendary+ guaranteed by roll %d; from roll %d each roll adds +%d%% Legendary chance. %s%s",
			multiplier,
			RarityConfig.BONUS_EVERY,
			RarityConfig.LEGENDARY_PITY,
			RollConfig.SOFT_FROM + 1,
			math.floor(RollConfig.SOFT_STEP * 100 + 0.5),
			guarantee,
			RarityConfig.ROUNDING_NOTE
		),
		pityLeft = if sinceLegendary ~= nil then RollConfig.pityLeft(sinceLegendary) else nil,
		luck = multiplier,
		rarities = rarities,
		entries = rows,
	}
end

function RarityConfig.formatLine(row: any): string
	local chance = 0
	local rarity = "Common"
	if type(row) == "table" then
		if type(row.chance) == "number" then
			chance = row.chance
		end
		if type(row.rarity) == "string" and row.rarity ~= "" then
			rarity = row.rarity
		end
	end
	local _, _, text = shownPair(chance)
	return string.format("%s  %s", rarity, text)
end

-- Base chance (luck x1, no pity) of landing this tier on the full V1
-- ladder. nil for a tier that does not roll (a parked Mythic/Secret an
-- old save still owns).
function RarityConfig.tierChance(rarity: any): number?
	if not RarityConfig.rolls(rarity) then
		return nil
	end
	local ladder = {}
	for index = #Rarities.ORDER, 1, -1 do
		local name = Rarities.ORDER[index]
		if RarityConfig.rolls(name) then
			table.insert(ladder, name)
		end
	end
	local remaining = 1
	for index, name in ipairs(ladder) do
		local chance
		if index == #ladder then
			chance = remaining
		else
			local hit = math.min(1, 1 / RarityConfig.oneIn(name))
			chance = remaining * hit
			remaining *= 1 - hit
		end
		if name == rarity then
			return chance
		end
	end
	return nil
end

-- The reveal's rarity line: "Rare · 6.6%". A parked tier shows its name.
function RarityConfig.revealText(rarity: any): string
	local name = if type(rarity) == "string" and rarity ~= "" then rarity else "Common"
	local chance = RarityConfig.tierChance(name)
	if chance == nil then
		return name
	end
	return string.format("%s · %s", name, RarityConfig.formatPercent(chance))
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
table.freeze(PARKED_ONE_IN)

return RarityConfig
