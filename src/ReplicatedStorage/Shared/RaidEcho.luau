--!strict

--[[
	Story Echo. A party-wide buff that grows after wipes.

	The server passes plain tables. This module does not read players,
	grant loot, or touch DataStores, MemoryStore, and remotes.
	It does not require Raids, RaidService, CombatMath, or RaidRecap.
	It has no RNG and it does not read the clock. Thresholds live in
	CONFIG. Nothing here costs Robux.

	Story only. Normal, Hard, Shardbreaker, and Fracture are known
	and never get Echo. A wipe is a whole-party death after the boss
	pull started. Practice Grove, a partial death, and a reset before
	the pull do not count.

	+5% per counted wipe, capped at +25%. The same fraction applies
	to player damage, healing, and max HP. wipe and reset return a
	new state and do not write the input. Call reset on a boss kill
	or when the run ends. Stacks stay until that call.
]]

local RaidEcho = {}

RaidEcho.CONFIG = table.freeze({
	-- Difficulty ladder: +5% per wipe, max +25%.
	perWipe = 0.05,
	cap = 0.25,
})

-- Fracture is known and never receives Echo. Guided is not a difficulty.
RaidEcho.DIFFICULTIES = table.freeze({
	story = true,
	normal = true,
	hard = true,
	shardbreaker = true,
	fracture = true,
})

RaidEcho.ECHO = table.freeze({
	story = true,
})

RaidEcho.STATS = table.freeze({
	damage = true,
	healing = true,
	maxHp = true,
})

RaidEcho.SKIPS = table.freeze({
	practice = true,
	pull = true,
	partial = true,
	difficulty = true,
})

RaidEcho.REASONS = table.freeze({
	kill = true,
	["end"] = true,
})

RaidEcho.ERRORS = table.freeze({
	state = "That echo record is unusable.",
	ctx = "That wipe is unusable.",
	difficulty = "That difficulty has no echo.",
	practice = "That practice flag is unusable.",
	pull = "That pull flag is unusable.",
	party = "That party wipe is unusable.",
	partySize = "That party size is unusable.",
	alive = "That alive count is unusable.",
	disagree = "Those fields disagree.",
	stat = "That stat is unusable.",
	kind = "That stat is not damage, healing, or max HP.",
	value = "That stat value is unusable.",
	reason = "That reset is not a boss kill or a run end.",
})

export type State = {
	stacks: number,
}

export type Bonus = {
	ok: boolean,
	bonus: number,
	stacks: number,
	difficulty: string,
	active: boolean,
	capped: boolean,
	error: string?,
}

export type WipeResult = {
	ok: boolean,
	state: State,
	counted: boolean,
	added: boolean,
	capped: boolean,
	stacks: number,
	bonus: number,
	reason: string?,
	error: string?,
}

export type ResetResult = {
	ok: boolean,
	state: State,
	stacks: number,
	previous: number,
	cleared: boolean,
	reason: string?,
	error: string?,
}

export type Applied = {
	ok: boolean,
	kind: string,
	value: number,
	base: number,
	bonus: number,
	multiplier: number,
	difficulty: string,
	error: string?,
}

local UNITS = 1000000

local STAT_KINDS: { [string]: string } = {
	damage = "damage",
	healing = "healing",
	heal = "healing",
	maxhp = "maxHp",
	maxhealth = "maxHp",
}

local RESET_KINDS: { [string]: string } = {
	kill = "kill",
	boss = "kill",
	bosskill = "kill",
	["end"] = "end",
	run = "end",
	runend = "end",
}

local CONFIG = RaidEcho.CONFIG

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

local function compact(value: string): string
	local squashed = string.gsub(value, "[%s_%-]", "")
	return squashed
end

local function whole(value: any): number?
	local number = finite(value)
	if number == nil or number < 0 or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function unitsOf(value: number): number
	return math.floor(value * UNITS + 0.5)
end

local function fraction(units: number): number
	return units / UNITS
end

local function configUnits(value: any, fallback: number): number
	local number = finite(value)
	if number == nil or number < 0 then
		return unitsOf(fallback)
	end
	return unitsOf(number)
end

local function stepUnits(): number
	return configUnits(CONFIG.perWipe, 0.05)
end

local function capUnits(): number
	return configUnits(CONFIG.cap, 0.25)
end

local function bonusUnits(stacks: number): number
	local step = stepUnits()
	local cap = capUnits()
	if step <= 0 or cap <= 0 or stacks <= 0 then
		return 0
	end
	local total = stacks * step
	if total ~= total or total == math.huge or total > cap then
		return cap
	end
	return total
end

local function roomToStack(stacks: number): boolean
	local step = stepUnits()
	local cap = capUnits()
	if step <= 0 or cap <= 0 then
		return false
	end
	local total = (stacks + 1) * step
	if total ~= total or total == math.huge then
		return false
	end
	return total <= cap
end

local function atCap(units: number): boolean
	local cap = capUnits()
	return cap > 0 and units >= cap
end

local function pack(stacks: number): State
	return { stacks = stacks }
end

local function readStacks(state: any): (number?, string?)
	if state == nil then
		return 0, nil
	end
	if type(state) ~= "table" then
		return nil, RaidEcho.ERRORS.state
	end
	if state.stacks == nil then
		return 0, nil
	end
	local stacks = whole(state.stacks)
	if stacks == nil then
		return nil, RaidEcho.ERRORS.state
	end
	return stacks, nil
end

local function readDifficulty(value: any): (string?, string?)
	local name = token(value)
	if name == nil or RaidEcho.DIFFICULTIES[name] ~= true then
		return nil, RaidEcho.ERRORS.difficulty
	end
	return name, nil
end

local function readBool(value: any, message: string): (boolean?, string?)
	if value == nil then
		return nil, nil
	end
	if type(value) ~= "boolean" then
		return nil, message
	end
	return value, nil
end

local function oneFlag(primary: any, alias: any, message: string): (boolean?, string?)
	local first, firstErr = readBool(primary, message)
	if firstErr ~= nil then
		return nil, firstErr
	end
	local second, secondErr = readBool(alias, message)
	if secondErr ~= nil then
		return nil, secondErr
	end
	if first ~= nil and second ~= nil and first ~= second then
		return nil, RaidEcho.ERRORS.disagree
	end
	if first ~= nil then
		return first, nil
	end
	return second, nil
end

local function readCount(value: any, message: string): (number?, string?)
	if value == nil then
		return nil, nil
	end
	local number = whole(value)
	if number == nil then
		return nil, message
	end
	return number, nil
end

local function oneCount(primary: any, alias: any, message: string): (number?, string?)
	local first, firstErr = readCount(primary, message)
	if firstErr ~= nil then
		return nil, firstErr
	end
	local second, secondErr = readCount(alias, message)
	if secondErr ~= nil then
		return nil, secondErr
	end
	if first ~= nil and second ~= nil and first ~= second then
		return nil, RaidEcho.ERRORS.disagree
	end
	if first ~= nil then
		return first, nil
	end
	return second, nil
end

local function readPractice(ctx: { [string]: any }): (boolean?, string?)
	local practice, practiceErr = oneFlag(ctx.practice, ctx.practiceGrove, RaidEcho.ERRORS.practice)
	if practiceErr ~= nil then
		return nil, practiceErr
	end
	if practice == nil then
		return false, nil
	end
	return practice, nil
end

local function readPull(ctx: { [string]: any }): (boolean?, string?)
	local pulled, pullErr = oneFlag(ctx.pullStarted, ctx.pulled, RaidEcho.ERRORS.pull)
	if pullErr ~= nil then
		return nil, pullErr
	end
	if pulled == nil then
		return false, nil
	end
	return pulled, nil
end

local function readWhole(ctx: { [string]: any }): (boolean?, string?)
	local flagged, flagErr = oneFlag(ctx.wholeParty, ctx.partyDead, RaidEcho.ERRORS.party)
	if flagErr ~= nil then
		return nil, flagErr
	end
	local alive, aliveErr = oneCount(ctx.alive, ctx.living, RaidEcho.ERRORS.alive)
	if aliveErr ~= nil then
		return nil, aliveErr
	end
	local party, partyErr = oneCount(ctx.party, ctx.partySize, RaidEcho.ERRORS.partySize)
	if partyErr ~= nil then
		return nil, partyErr
	end
	if alive ~= nil or party ~= nil then
		if alive == nil then
			return nil, RaidEcho.ERRORS.alive
		end
		if party == nil or party < 1 then
			return nil, RaidEcho.ERRORS.partySize
		end
		if alive > party then
			return nil, RaidEcho.ERRORS.alive
		end
		local fromCounts = alive == 0
		if flagged ~= nil and flagged ~= fromCounts then
			return nil, RaidEcho.ERRORS.disagree
		end
		return fromCounts, nil
	end
	if flagged == nil then
		return nil, RaidEcho.ERRORS.party
	end
	return flagged, nil
end

-- Practice first, then a pull that never started, then a partial death,
-- then a difficulty that never gets Echo. The first hit is the reason.
local function skipReason(
	practice: boolean,
	pulled: boolean,
	wholeParty: boolean,
	difficulty: string
): string?
	if practice then
		return "practice"
	end
	if not pulled then
		return "pull"
	end
	if not wholeParty then
		return "partial"
	end
	if RaidEcho.ECHO[difficulty] ~= true then
		return "difficulty"
	end
	return nil
end

local function appliedUnits(stacks: number, difficulty: string): number
	if RaidEcho.ECHO[difficulty] ~= true then
		return 0
	end
	return bonusUnits(stacks)
end

local function failBonus(message: string, stacks: number?, difficulty: string?): Bonus
	return {
		ok = false,
		bonus = 0,
		stacks = stacks or 0,
		difficulty = difficulty or "",
		active = false,
		capped = false,
		error = message,
	}
end

local function failWipe(message: string, stacks: number): WipeResult
	return {
		ok = false,
		state = pack(stacks),
		counted = false,
		added = false,
		capped = false,
		stacks = stacks,
		bonus = 0,
		error = message,
	}
end

local function failReset(message: string, stacks: number): ResetResult
	return {
		ok = false,
		state = pack(stacks),
		stacks = stacks,
		previous = stacks,
		cleared = false,
		error = message,
	}
end

local function failApply(
	message: string,
	kind: string?,
	base: number?,
	difficulty: string?
): Applied
	local amount = base or 0
	return {
		ok = false,
		kind = kind or "",
		value = amount,
		base = amount,
		bonus = 0,
		multiplier = 1,
		difficulty = difficulty or "",
		error = message,
	}
end

local function mappedToken(
	value: any,
	kinds: { [string]: string },
	message: string
): (string?, string?)
	if type(value) ~= "string" then
		return nil, message
	end
	local name = token(value)
	if name == nil then
		return nil, message
	end
	local mapped = kinds[compact(name)]
	if mapped == nil then
		return nil, message
	end
	return mapped, nil
end

local function takeMapped(
	found: string?,
	saw: boolean,
	value: any,
	kinds: { [string]: string },
	message: string
): (string?, boolean, string?)
	if value == nil then
		return found, saw, nil
	end
	local mapped, mappedErr = mappedToken(value, kinds, message)
	if mapped == nil then
		return nil, true, mappedErr or message
	end
	if found ~= nil and found ~= mapped then
		return nil, true, RaidEcho.ERRORS.disagree
	end
	return mapped, true, nil
end

local function oneMapped(
	primary: any,
	alias: any,
	extra: any,
	kinds: { [string]: string },
	message: string
): (string?, string?)
	local found: string? = nil
	local saw = false
	local err: string? = nil
	found, saw, err = takeMapped(found, saw, primary, kinds, message)
	if err ~= nil then
		return nil, err
	end
	found, saw, err = takeMapped(found, saw, alias, kinds, message)
	if err ~= nil then
		return nil, err
	end
	found, saw, err = takeMapped(found, saw, extra, kinds, message)
	if err ~= nil then
		return nil, err
	end
	if not saw then
		return nil, nil
	end
	return found, nil
end

local function readValue(value: any): (number?, string?)
	if value == nil then
		return nil, nil
	end
	local number = finite(value)
	if number == nil or number < 0 then
		return nil, RaidEcho.ERRORS.value
	end
	return number, nil
end

local function takeValue(found: number?, saw: boolean, value: any): (number?, boolean, string?)
	if value == nil then
		return found, saw, nil
	end
	local number, numberErr = readValue(value)
	if number == nil then
		return nil, true, numberErr or RaidEcho.ERRORS.value
	end
	if found ~= nil and found ~= number then
		return nil, true, RaidEcho.ERRORS.disagree
	end
	return number, true, nil
end

local function oneValue(primary: any, alias: any, extra: any): (number?, string?)
	local found: number? = nil
	local saw = false
	local err: string? = nil
	found, saw, err = takeValue(found, saw, primary)
	if err ~= nil then
		return nil, err
	end
	found, saw, err = takeValue(found, saw, alias)
	if err ~= nil then
		return nil, err
	end
	found, saw, err = takeValue(found, saw, extra)
	if err ~= nil then
		return nil, err
	end
	if not saw then
		return nil, nil
	end
	return found, nil
end

local function readStat(stat: any): (string?, number?, string?)
	if type(stat) ~= "table" then
		return nil, nil, RaidEcho.ERRORS.stat
	end
	local kind, kindErr =
		oneMapped(stat.kind, stat.stat, stat.name, STAT_KINDS, RaidEcho.ERRORS.kind)
	local base, valueErr = oneValue(stat.value, stat.amount, stat.base)
	if kindErr ~= nil then
		return nil, base, kindErr
	end
	if valueErr ~= nil then
		return kind, nil, valueErr
	end
	if kind == nil or base == nil then
		return kind, base, RaidEcho.ERRORS.stat
	end
	return kind, base, nil
end

local function readReset(ctx: any): (string?, string?)
	if type(ctx) == "string" then
		return mappedToken(ctx, RESET_KINDS, RaidEcho.ERRORS.reason)
	end
	if type(ctx) ~= "table" then
		return nil, RaidEcho.ERRORS.reason
	end
	local reason, reasonErr =
		oneMapped(ctx.reason, ctx.kind, nil, RESET_KINDS, RaidEcho.ERRORS.reason)
	if reasonErr ~= nil then
		return nil, reasonErr
	end
	if reason == nil then
		return nil, RaidEcho.ERRORS.reason
	end
	return reason, nil
end

function RaidEcho.fresh(): State
	return pack(0)
end

function RaidEcho.bonus(state: any, difficulty: any): Bonus
	local stacks, stateErr = readStacks(state)
	if stacks == nil then
		return failBonus(stateErr or RaidEcho.ERRORS.state, nil, nil)
	end
	local name, diffErr = readDifficulty(difficulty)
	if name == nil then
		return failBonus(diffErr or RaidEcho.ERRORS.difficulty, stacks, nil)
	end
	local units = appliedUnits(stacks, name)
	return {
		ok = true,
		bonus = fraction(units),
		stacks = stacks,
		difficulty = name,
		active = units > 0,
		capped = atCap(units),
		error = nil,
	}
end

function RaidEcho.wipe(state: any, ctx: any): WipeResult
	local stacks, stateErr = readStacks(state)
	if stacks == nil then
		return failWipe(stateErr or RaidEcho.ERRORS.state, 0)
	end
	if type(ctx) ~= "table" then
		return failWipe(RaidEcho.ERRORS.ctx, stacks)
	end
	local difficulty, diffErr = readDifficulty(ctx.difficulty)
	if difficulty == nil then
		return failWipe(diffErr or RaidEcho.ERRORS.difficulty, stacks)
	end
	local practice, practiceErr = readPractice(ctx)
	if practice == nil then
		return failWipe(practiceErr or RaidEcho.ERRORS.practice, stacks)
	end
	local pulled, pullErr = readPull(ctx)
	if pulled == nil then
		return failWipe(pullErr or RaidEcho.ERRORS.pull, stacks)
	end
	local wholeParty, partyErr = readWhole(ctx)
	if wholeParty == nil then
		return failWipe(partyErr or RaidEcho.ERRORS.party, stacks)
	end
	local reason = skipReason(practice, pulled, wholeParty, difficulty)
	local nextStacks = stacks
	local added = false
	if reason == nil and roomToStack(stacks) then
		nextStacks = stacks + 1
		added = true
	end
	local units = appliedUnits(nextStacks, difficulty)
	return {
		ok = true,
		state = pack(nextStacks),
		counted = reason == nil,
		added = added,
		capped = atCap(units),
		stacks = nextStacks,
		bonus = fraction(units),
		reason = reason,
		error = nil,
	}
end

function RaidEcho.reset(state: any, ctx: any): ResetResult
	local stacks, stateErr = readStacks(state)
	if stacks == nil then
		return failReset(stateErr or RaidEcho.ERRORS.state, 0)
	end
	local reason, reasonErr = readReset(ctx)
	if reason == nil then
		return failReset(reasonErr or RaidEcho.ERRORS.reason, stacks)
	end
	return {
		ok = true,
		state = pack(0),
		stacks = 0,
		previous = stacks,
		cleared = stacks > 0,
		reason = reason,
		error = nil,
	}
end

function RaidEcho.apply(stat: any, state: any, difficulty: any): Applied
	local stacks, stateErr = readStacks(state)
	if stacks == nil then
		return failApply(stateErr or RaidEcho.ERRORS.state, nil, nil, nil)
	end
	local name, diffErr = readDifficulty(difficulty)
	if name == nil then
		local _, base = readStat(stat)
		return failApply(diffErr or RaidEcho.ERRORS.difficulty, nil, base, nil)
	end
	local kind, base, statErr = readStat(stat)
	if kind == nil or base == nil then
		return failApply(statErr or RaidEcho.ERRORS.stat, kind, base, name)
	end
	local units = appliedUnits(stacks, name)
	local bonus = fraction(units)
	local multiplier = (UNITS + units) / UNITS
	return {
		ok = true,
		kind = kind,
		value = base * multiplier,
		base = base,
		bonus = bonus,
		multiplier = multiplier,
		difficulty = name,
		error = nil,
	}
end

return RaidEcho
