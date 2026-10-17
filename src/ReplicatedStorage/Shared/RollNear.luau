--!strict

--[[
	Roll and reroll screen: streak and near-miss. Pure display rules.

	A near-miss is a real close call only.
	  The landed rarity is exactly one Rarities.ORDER step under the
	  caller-supplied watched rarity.
	  Or the caller-supplied pity counter is exactly one short of its
	  goal and the landed rarity is below that pity rarity.

	The rarity on the result is the one that landed. This module does
	not name a rarity that was not rolled, and it does not change the
	roll or the odds. A paid roll uses the same rules as a free roll.

	Streak is consecutive landed rolls. A miss resets it. A land
	increments it. That is the same numeric rule as RollLoop.streak
	for a whole current count. This module does not require RollLoop
	or RollHype, and it does not repeat milestone callouts.

	fresh, streak, near, and note each return a new table and do not
	write the input. Store state only when ok == true. No clock. No
	RNG. Nothing here costs Robux.

	It requires Rarities for the ladder and nothing else. UiRouter
	requires this module for the close-call flag.
]]

local Rarities = require("./Rarities")

local RollNear = {}

RollNear.ERRORS = table.freeze({
	state = "That streak is unusable.",
	roll = "That roll note is unusable.",
	rarity = "That rarity is not on the ladder.",
	watched = "That watched rarity is not on the ladder.",
	pity = "That pity note is unusable.",
})

export type StreakState = {
	streak: number,
}

export type Opened = {
	ok: boolean,
	state: StreakState,
}

export type Streaked = {
	ok: boolean,
	state: StreakState,
	streak: number,
	landed: boolean,
	error: string?,
}

export type Near = {
	ok: boolean,
	nearMiss: boolean,
	watchedStep: boolean,
	pityShort: boolean,
	rarity: string?,
	error: string?,
}

export type Noted = {
	ok: boolean,
	state: StreakState,
	streak: number,
	landed: boolean,
	nearMiss: boolean,
	watchedStep: boolean,
	pityShort: boolean,
	rarity: string?,
	error: string?,
}

local ERRORS = RollNear.ERRORS

local function whole(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < 0 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function rankOf(rarity: any): number?
	if type(rarity) ~= "string" then
		return nil
	end
	local rank = Rarities.INDEX[rarity]
	if type(rank) ~= "number" then
		return nil
	end
	return rank
end

local function named(rank: number): string
	return Rarities.ORDER[rank]
end

local function readStreak(value: any): (number?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local streak = whole(value.streak)
	if streak == nil then
		return nil, ERRORS.state
	end
	return streak, nil
end

local function stateOf(streak: number): StreakState
	return { streak = streak }
end

local function missedNear(): Near
	return {
		ok = true,
		nearMiss = false,
		watchedStep = false,
		pityShort = false,
		rarity = nil,
	}
end

local function failedNear(err: string): Near
	return {
		ok = false,
		nearMiss = false,
		watchedStep = false,
		pityShort = false,
		rarity = nil,
		error = err,
	}
end

local function judge(roll: { [string]: any }): Near
	local landed = roll.landed
	if landed == nil then
		landed = true
	elseif type(landed) ~= "boolean" then
		return failedNear(ERRORS.roll)
	end
	if landed == false then
		return missedNear()
	end

	local rank = rankOf(roll.rarity)
	if rank == nil then
		return failedNear(ERRORS.rarity)
	end

	local watchedStep = false
	if roll.watched ~= nil then
		local watchedRank = rankOf(roll.watched)
		if watchedRank == nil then
			return failedNear(ERRORS.watched)
		end
		watchedStep = rank == watchedRank - 1
	end

	local pityShort = false
	if roll.counter ~= nil or roll.goal ~= nil or roll.pity ~= nil then
		local counter = whole(roll.counter)
		local goal = whole(roll.goal)
		local pityRank = rankOf(roll.pity)
		if counter == nil or goal == nil or pityRank == nil then
			return failedNear(ERRORS.pity)
		end
		if goal < 1 then
			return failedNear(ERRORS.pity)
		end
		pityShort = counter + 1 == goal and rank < pityRank
	end

	return {
		ok = true,
		nearMiss = watchedStep or pityShort,
		watchedStep = watchedStep,
		pityShort = pityShort,
		rarity = named(rank),
	}
end

local function failedStreak(streak: number, err: string): Streaked
	return {
		ok = false,
		state = stateOf(streak),
		streak = streak,
		landed = false,
		error = err,
	}
end

local function failedNote(streak: number, err: string): Noted
	return {
		ok = false,
		state = stateOf(streak),
		streak = streak,
		landed = false,
		nearMiss = false,
		watchedStep = false,
		pityShort = false,
		rarity = nil,
		error = err,
	}
end

function RollNear.fresh(): Opened
	return {
		ok = true,
		state = stateOf(0),
	}
end

function RollNear.streak(state: any, landed: any): Streaked
	local current, stateErr = readStreak(state)
	if current == nil then
		return failedStreak(0, stateErr or ERRORS.state)
	end
	if type(landed) ~= "boolean" then
		return failedStreak(current, ERRORS.roll)
	end
	local nextCount = if landed then current + 1 else 0
	return {
		ok = true,
		state = stateOf(nextCount),
		streak = nextCount,
		landed = landed,
	}
end

function RollNear.near(roll: any): Near
	if type(roll) ~= "table" then
		return failedNear(ERRORS.roll)
	end
	return judge(roll)
end

function RollNear.note(state: any, roll: any): Noted
	local current, stateErr = readStreak(state)
	if current == nil then
		return failedNote(0, stateErr or ERRORS.state)
	end
	if type(roll) ~= "table" then
		return failedNote(current, ERRORS.roll)
	end
	local judged = judge(roll)
	if not judged.ok then
		return failedNote(current, judged.error or ERRORS.roll)
	end
	local landed = judged.rarity ~= nil
	local nextCount = if landed then current + 1 else 0
	return {
		ok = true,
		state = stateOf(nextCount),
		streak = nextCount,
		landed = landed,
		nearMiss = judged.nearMiss,
		watchedStep = judged.watchedStep,
		pityShort = judged.pityShort,
		rarity = judged.rarity,
	}
end

return RollNear
