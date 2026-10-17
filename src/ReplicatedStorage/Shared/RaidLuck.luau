--!strict

--[[
	Raid bad-luck protection.

	The server passes a plain record. This module does not roll loot,
	read players, grant items, or touch DataStores and remotes.
	Thresholds live in CONFIG. Nothing here costs Robux.

	A loot-eligible boss clear with no gear drop adds stepPct to that
	player's next gear chance on that difficulty. maxBonus caps the
	bonus. A gear drop resets that difficulty to 0. A reclear after
	lockout does not add. An AFK removal does not add. Pets, mounts,
	titles, dyes, cosmetics, and auras never take the boost and never
	reset it.

	chance clamps base + bonus to 0..1. settle returns a new state.
	The caller rolls. This module has no RNG. The bonus is stored per
	difficulty. Story does not raise Normal.
]]

local RelicSets = require("./RelicSets")

local RaidLuck = {}

local UNITS = 1000000

RaidLuck.CONFIG = table.freeze({
	stepPct = 0.1,
	-- Placeholder. Six dry clears. Live Raids caps the total chance at
	-- 0.8 from a 0.2 base, which is this same 0.6 of bonus.
	maxBonus = 0.6,
})

RaidLuck.DIFFICULTIES = table.freeze({
	story = true,
	normal = true,
	hard = true,
	shardbreaker = true,
})

-- Kinds that are gear with no further check.
RaidLuck.GEAR = table.freeze({
	gear = true,
	raid = true,
	raid_gear = true,
	heartshard = true,
	relic = true,
})

-- Weapon, armor, and accessory count only with a raid source.
RaidLuck.GEAR_KINDS = table.freeze({
	weapon = true,
	armor = true,
	accessory = true,
})

-- Never boosted. Never a reset.
RaidLuck.EXCLUDED = table.freeze({
	pet = true,
	mount = true,
	title = true,
	dye = true,
	cosmetic = true,
	aura = true,
})

-- A clear that drops only these is still a dry gear clear.
RaidLuck.SIDE = table.freeze({
	material = true,
	materials = true,
	dust = true,
	shard_dust = true,
	sharddust = true,
	marks = true,
	mark = true,
	currency = true,
	gold = true,
	shards = true,
	token = true,
	tokens = true,
	emblem = true,
})

RaidLuck.RAID_SOURCES = table.freeze({
	raid = true,
	heartwood = true,
	heartwood_story = true,
	heartwood_normal = true,
	heartwood_hard = true,
	heartwood_shardbreaker = true,
	shardbreaker = true,
})

RaidLuck.REMOVALS = table.freeze({
	afk = true,
	kick = true,
})

RaidLuck.REASONS = table.freeze({
	afk = "afk",
	lockout = "lockout",
	ineligible = "ineligible",
})

RaidLuck.ERRORS = table.freeze({
	state = "The luck record is unusable.",
	base = "That drop chance is unusable.",
	difficulty = "That difficulty has no luck bonus.",
	outcome = "That clear is unusable.",
	drop = "That drop is unusable.",
	removal = "That removal is not a known cause.",
	lock = "That lockout flag is unusable.",
	eligible = "That eligibility flag is unusable.",
})

export type State = {
	bonus: { [string]: number }?,
}

export type Chance = {
	ok: boolean,
	chance: number,
	base: number,
	bonus: number,
	difficulty: string,
	error: string?,
}

export type Settlement = {
	ok: boolean,
	state: { bonus: { [string]: number } },
	difficulty: string,
	bonus: number,
	previous: number,
	added: boolean,
	reset: boolean,
	gear: boolean,
	eligible: boolean,
	capped: boolean,
	reason: string?,
	error: string?,
}

export type Classified = {
	ok: boolean,
	gear: boolean,
	error: string?,
}

type BonusMap = { [string]: number }

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

local function token(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = trim(value)
	if trimmed == "" then
		return nil
	end
	return string.lower(trimmed)
end

local function unitsOf(value: number): number
	return math.floor(value * UNITS + 0.5)
end

local function configUnits(value: any, fallback: number): number
	local number = finite(value)
	if number == nil or number < 0 then
		return unitsOf(fallback)
	end
	return unitsOf(number)
end

local function stepUnits(): number
	return configUnits(RaidLuck.CONFIG.stepPct, 0.1)
end

local function capUnits(): number
	return configUnits(RaidLuck.CONFIG.maxBonus, 0.6)
end

local function fraction(units: number): number
	return units / UNITS
end

local function clamp01(value: number): number
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

local function hasHeartshard(value: any): boolean
	local name = token(value)
	if name == nil then
		return false
	end
	return string.find(name, "heartshard", 1, true) ~= nil
end

local function raidSourced(item: { [string]: any }): boolean
	if item.raid == true then
		return true
	end
	local source = token(item.source)
	if source == nil then
		return false
	end
	return RaidLuck.RAID_SOURCES[source] == true
end

local function kindName(item: { [string]: any }): (string?, string?)
	local kind = token(item.kind)
	local category = token(item.category)
	if kind ~= nil and category ~= nil and kind ~= category then
		return nil, RaidLuck.ERRORS.drop
	end
	return kind or category, nil
end

local function classifyToken(name: string?): (boolean?, string?)
	if name == nil then
		return nil, RaidLuck.ERRORS.drop
	end
	if RelicSets.isRelic(name) then
		return true, nil
	end
	if RaidLuck.EXCLUDED[name] == true then
		return false, nil
	end
	if name == "heartshard" or string.find(name, "heartshard", 1, true) ~= nil then
		return true, nil
	end
	if RaidLuck.GEAR[name] == true then
		return true, nil
	end
	if RaidLuck.SIDE[name] == true then
		return false, nil
	end
	return nil, RaidLuck.ERRORS.drop
end

local function heartshardItem(item: { [string]: any }, name: string?): boolean
	if name == "heartshard" or item.heartshard == true then
		return true
	end
	if token(item.family) == "heartshard" or token(item.weaponFamily) == "heartshard" then
		return true
	end
	return hasHeartshard(item.templateId) or hasHeartshard(item.id) or hasHeartshard(item.pieceId)
end

-- A heartshard flag on an excluded kind is a bad payload. The id is not
-- consulted here: a dye can carry a heartshard substring and stay a dye.
local function itemFlagsHeartshard(item: { [string]: any }): boolean
	if item.heartshard == true then
		return true
	end
	if token(item.family) == "heartshard" then
		return true
	end
	return token(item.weaponFamily) == "heartshard"
end

local function classifyDrop(drop: any): (boolean?, string?)
	if type(drop) == "string" then
		return classifyToken(token(drop))
	end
	if type(drop) ~= "table" then
		return nil, RaidLuck.ERRORS.drop
	end
	local name, nameErr = kindName(drop)
	if nameErr ~= nil then
		return nil, nameErr
	end
	if RelicSets.isRelic(drop) or name == "relic" then
		if name ~= nil and RaidLuck.EXCLUDED[name] == true then
			return nil, RaidLuck.ERRORS.drop
		end
		return true, nil
	end
	if name ~= nil and RaidLuck.EXCLUDED[name] == true then
		if itemFlagsHeartshard(drop) then
			return nil, RaidLuck.ERRORS.drop
		end
		return false, nil
	end
	if heartshardItem(drop, name) then
		return true, nil
	end
	if drop.raidCosmetic == true then
		return false, nil
	end
	if name ~= nil and RaidLuck.GEAR[name] == true then
		return true, nil
	end
	if name ~= nil and RaidLuck.GEAR_KINDS[name] == true and raidSourced(drop) then
		return true, nil
	end
	if name ~= nil and RaidLuck.SIDE[name] == true then
		return false, nil
	end
	return nil, RaidLuck.ERRORS.drop
end

local function readBonus(state: any): (BonusMap?, string?)
	if state == nil then
		return {}, nil
	end
	if type(state) ~= "table" then
		return nil, RaidLuck.ERRORS.state
	end
	local bonus = state.bonus
	if bonus == nil then
		return {}, nil
	end
	if type(bonus) ~= "table" then
		return nil, RaidLuck.ERRORS.state
	end
	local map: BonusMap = {}
	local seen: { [string]: boolean } = {}
	local cap = capUnits()
	for key, value in pairs(bonus) do
		if type(key) ~= "string" then
			return nil, RaidLuck.ERRORS.state
		end
		local id = token(key)
		if id == nil or RaidLuck.DIFFICULTIES[id] ~= true then
			return nil, RaidLuck.ERRORS.state
		end
		if seen[id] == true then
			return nil, RaidLuck.ERRORS.state
		end
		seen[id] = true
		local number = finite(value)
		if number == nil or number < 0 then
			return nil, RaidLuck.ERRORS.state
		end
		local units = unitsOf(number)
		if units > cap then
			units = cap
		end
		map[id] = units
	end
	return map, nil
end

local function publish(map: BonusMap): { bonus: { [string]: number } }
	local bonus: { [string]: number } = {}
	for key, units in pairs(map) do
		bonus[key] = fraction(units)
	end
	return { bonus = bonus }
end

local function optionalBool(value: any, default: boolean, message: string): (boolean?, string?)
	if value == nil then
		return default, nil
	end
	if type(value) ~= "boolean" then
		return nil, message
	end
	return value, nil
end

-- "" means the player was not removed. nil plus a message is a bad cause.
local function readRemoval(value: any): (string?, string?)
	if value == nil then
		return "", nil
	end
	local name = token(value)
	if name == nil or RaidLuck.REMOVALS[name] ~= true then
		return nil, RaidLuck.ERRORS.removal
	end
	return name, nil
end

local function readDrops(drops: any): ({ any }?, string?)
	if drops == nil then
		return {}, nil
	end
	if type(drops) ~= "table" then
		return nil, RaidLuck.ERRORS.drop
	end
	local count = 0
	local maxIndex = 0
	for key in pairs(drops) do
		if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
			return nil, RaidLuck.ERRORS.drop
		end
		count += 1
		if key > maxIndex then
			maxIndex = key
		end
	end
	if count ~= maxIndex then
		return nil, RaidLuck.ERRORS.drop
	end
	local list = {}
	for index = 1, count do
		list[index] = drops[index]
	end
	return list, nil
end

local function failChance(message: string, difficulty: string): Chance
	return {
		ok = false,
		chance = 0,
		base = 0,
		bonus = 0,
		difficulty = difficulty,
		error = message,
	}
end

local function failSettle(difficulty: string, message: string, map: BonusMap?): Settlement
	local units = 0
	if map ~= nil and difficulty ~= "" then
		units = map[difficulty] or 0
	end
	local bonus = fraction(units)
	return {
		ok = false,
		state = publish(map or {}),
		difficulty = difficulty,
		bonus = bonus,
		previous = bonus,
		added = false,
		reset = false,
		gear = false,
		eligible = false,
		capped = false,
		error = message,
	}
end

function RaidLuck.classify(drop: any): Classified
	local gear, message = classifyDrop(drop)
	if gear == nil then
		return {
			ok = false,
			gear = false,
			error = message or RaidLuck.ERRORS.drop,
		}
	end
	return {
		ok = true,
		gear = gear,
	}
end

function RaidLuck.chance(base: any, state: any, difficulty: any): Chance
	local number = finite(base)
	if number == nil then
		return failChance(RaidLuck.ERRORS.base, "")
	end
	local id = token(difficulty)
	if id == nil or RaidLuck.DIFFICULTIES[id] ~= true then
		return failChance(RaidLuck.ERRORS.difficulty, "")
	end
	local map, stateErr = readBonus(state)
	if map == nil then
		return failChance(stateErr or RaidLuck.ERRORS.state, id)
	end
	local bonusUnits = map[id] or 0
	local chance = fraction(unitsOf(number) + bonusUnits)
	return {
		ok = true,
		chance = clamp01(chance),
		base = number,
		bonus = fraction(bonusUnits),
		difficulty = id,
	}
end

function RaidLuck.settle(state: any, outcome: any): Settlement
	local map, stateErr = readBonus(state)
	if map == nil then
		return failSettle("", stateErr or RaidLuck.ERRORS.state, nil)
	end
	if type(outcome) ~= "table" then
		return failSettle("", RaidLuck.ERRORS.outcome, map)
	end
	local id = token(outcome.difficulty)
	if id == nil or RaidLuck.DIFFICULTIES[id] ~= true then
		return failSettle("", RaidLuck.ERRORS.difficulty, map)
	end
	local locked, lockErr = optionalBool(outcome.locked, false, RaidLuck.ERRORS.lock)
	if locked == nil then
		return failSettle(id, lockErr or RaidLuck.ERRORS.lock, map)
	end
	local removal, removalErr = readRemoval(outcome.removal)
	if removal == nil then
		return failSettle(id, removalErr or RaidLuck.ERRORS.removal, map)
	end
	local eligible, eligibleErr = optionalBool(outcome.eligible, true, RaidLuck.ERRORS.eligible)
	if eligible == nil then
		return failSettle(id, eligibleErr or RaidLuck.ERRORS.eligible, map)
	end
	local drops, dropErr = readDrops(outcome.drops)
	if drops == nil then
		return failSettle(id, dropErr or RaidLuck.ERRORS.drop, map)
	end
	local sawGear = false
	for _, drop in ipairs(drops) do
		local gear, message = classifyDrop(drop)
		if gear == nil then
			return failSettle(id, message or RaidLuck.ERRORS.drop, map)
		end
		if gear then
			sawGear = true
		end
	end

	local previous = map[id] or 0
	local nextUnits = previous
	local added = false
	local reset = false
	local gear = false
	local reason: string? = nil
	if removal == RaidLuck.REASONS.afk then
		reason = RaidLuck.REASONS.afk
	elseif locked then
		reason = RaidLuck.REASONS.lockout
	elseif not eligible then
		reason = RaidLuck.REASONS.ineligible
	elseif sawGear then
		nextUnits = 0
		reset = true
		gear = true
		map[id] = 0
	else
		local cap = capUnits()
		local grown = previous + stepUnits()
		if grown > cap then
			grown = cap
		end
		if grown > previous then
			added = true
		end
		nextUnits = grown
		map[id] = grown
	end

	local result: Settlement = {
		ok = true,
		state = publish(map),
		difficulty = id,
		bonus = fraction(nextUnits),
		previous = fraction(previous),
		added = added,
		reset = reset,
		gear = gear,
		eligible = reason == nil,
		capped = reason == nil and not gear and nextUnits >= capUnits(),
	}
	if reason ~= nil then
		result.reason = reason
	end
	return result
end

return RaidLuck
