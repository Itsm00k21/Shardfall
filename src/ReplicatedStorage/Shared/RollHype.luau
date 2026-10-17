--!strict

--[[
	Roll screen hype. Pure display rules.

	The caller passes the rarity that was actually rolled and the real
	pity counter. This module does not roll, does not read the clock,
	and does not use RNG. A paid roll and a free roll share every
	display rule. Nothing here costs Robux.

	fresh, note, pity, and tempo each return a new table and do not
	write the input. Store a session only when ok == true.

	Honesty:
	  Never surface a rarity that was not rolled.
	  No near-miss and no teased next rarity.
	  The pity meter shows only the counter and goal the caller passed.
	  An unknown rarity is refused and is not echoed.

	It requires Rarities for the ladder and nothing else. It does not
	require RollLoop, RollReveal, RollMath, RollBoard, or PaidRollPolicy.
	Nothing in src requires this module.
]]

local Rarities = require("./Rarities")

local RollHype = {}

RollHype.CONFIG = table.freeze({
	-- Landed rolls in one session. The callout is the count, not a rarity.
	milestones = table.freeze({ 10, 25, 50, 100 }),
	-- Full-animation build-up, in seconds. Higher rarities take longer.
	-- Placeholders. Short, instant, and reduced motion stay in Settings.
	buildUp = table.freeze({
		Common = 0.45,
		Uncommon = 0.6,
		Rare = 0.9,
		Epic = 1.2,
		Legendary = 1.65,
		Mythic = 2.4,
		Secret = 3,
	}),
})

RollHype.ERRORS = table.freeze({
	state = "That roll session is unusable.",
	roll = "That roll note is unusable.",
	rarity = "That rarity is not on the ladder.",
	allTime = "That personal best is unusable.",
	disagree = "Those fields disagree.",
	goal = "That pity goal is unusable.",
	counter = "That pity counter is unusable.",
	which = "That pity note names two counters.",
})

export type Session = {
	rolls: number,
	streak: number,
	best: string?,
	personalBest: boolean,
	allTime: string?,
}

export type Opened = {
	ok: boolean,
	state: Session,
	error: string?,
}

export type Noted = {
	ok: boolean,
	state: Session,
	rarity: string?,
	rolls: number,
	streak: number,
	best: string?,
	personalBest: boolean,
	newPersonalBest: boolean,
	raisedBest: boolean,
	milestone: number?,
	callout: string?,
	error: string?,
}

export type Meter = {
	ok: boolean,
	fill: number,
	counter: number,
	goal: number?,
	error: string?,
}

export type Tempo = {
	ok: boolean,
	rarity: string?,
	tier: number?,
	buildUp: number?,
	error: string?,
}

local MILESTONE_AT: { [number]: boolean } = {}
for _, count in ipairs(RollHype.CONFIG.milestones) do
	MILESTONE_AT[count] = true
end
table.freeze(MILESTONE_AT)

local CONFIG = RollHype.CONFIG
local ERRORS = RollHype.ERRORS

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function whole(value: any): number?
	local numberValue = finite(value)
	if numberValue == nil or numberValue < 0 then
		return nil
	end
	if numberValue ~= math.floor(numberValue) then
		return nil
	end
	return numberValue
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

local function blank(): Session
	return {
		rolls = 0,
		streak = 0,
		best = nil,
		personalBest = false,
		allTime = nil,
	}
end

local function copy(state: Session): Session
	return {
		rolls = state.rolls,
		streak = state.streak,
		best = state.best,
		personalBest = state.personalBest,
		allTime = state.allTime,
	}
end

local function readState(value: any): (Session?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local rolls = whole(value.rolls)
	local streak = whole(value.streak)
	if rolls == nil or streak == nil then
		return nil, ERRORS.state
	end
	if type(value.personalBest) ~= "boolean" then
		return nil, ERRORS.state
	end
	local bestRank: number? = nil
	local bestName: string? = nil
	if value.best ~= nil then
		local parsedBest = rankOf(value.best)
		if parsedBest == nil then
			return nil, ERRORS.state
		end
		bestRank = parsedBest
		bestName = named(parsedBest)
	end
	local allRank: number? = nil
	local allName: string? = nil
	if value.allTime ~= nil then
		local parsedAll = rankOf(value.allTime)
		if parsedAll == nil then
			return nil, ERRORS.state
		end
		allRank = parsedAll
		allName = named(parsedAll)
	end
	if streak > rolls then
		return nil, ERRORS.disagree
	end
	if rolls == 0 and bestName ~= nil then
		return nil, ERRORS.disagree
	end
	if rolls >= 1 and bestName == nil then
		return nil, ERRORS.disagree
	end
	if value.personalBest and (bestName == nil or allName == nil) then
		return nil, ERRORS.disagree
	end
	if bestName ~= nil and bestRank ~= nil and (allRank == nil or allRank < bestRank) then
		return nil, ERRORS.disagree
	end
	return {
		rolls = rolls,
		streak = streak,
		best = bestName,
		personalBest = value.personalBest,
		allTime = allName,
	},
		nil
end

local function refused(state: Session, err: string): Noted
	return {
		ok = false,
		state = state,
		rarity = nil,
		rolls = state.rolls,
		streak = state.streak,
		best = state.best,
		personalBest = state.personalBest,
		newPersonalBest = false,
		raisedBest = false,
		milestone = nil,
		callout = nil,
		error = err,
	}
end

function RollHype.fresh(allTime: any?): Opened
	if allTime == nil or allTime == "" then
		return {
			ok = true,
			state = blank(),
		}
	end
	local rank = rankOf(allTime)
	if rank == nil then
		return {
			ok = false,
			state = blank(),
			error = ERRORS.allTime,
		}
	end
	local state = blank()
	state.allTime = named(rank)
	return {
		ok = true,
		state = state,
	}
end

local function higher(left: string?, right: string?): string?
	if left == nil then
		return right
	end
	if right == nil then
		return left
	end
	local leftRank = rankOf(left)
	local rightRank = rankOf(right)
	if leftRank == nil or rightRank == nil then
		return nil
	end
	if rightRank > leftRank then
		return right
	end
	return left
end

function RollHype.note(state: any, roll: any): Noted
	local parsed, stateErr = readState(state)
	if parsed == nil then
		return refused(blank(), stateErr or ERRORS.state)
	end
	if type(roll) ~= "table" then
		return refused(copy(parsed), ERRORS.roll)
	end
	local landed = roll.landed
	if landed == nil then
		landed = true
	elseif type(landed) ~= "boolean" then
		return refused(copy(parsed), ERRORS.roll)
	end
	if landed == false then
		local missed = copy(parsed)
		missed.streak = 0
		return {
			ok = true,
			state = missed,
			rarity = nil,
			rolls = missed.rolls,
			streak = 0,
			best = missed.best,
			personalBest = missed.personalBest,
			newPersonalBest = false,
			raisedBest = false,
			milestone = nil,
			callout = nil,
		}
	end

	local rank = rankOf(roll.rarity)
	if rank == nil then
		return refused(copy(parsed), ERRORS.rarity)
	end
	local rarity = named(rank)
	local passedAll = parsed.allTime
	if roll.allTime ~= nil then
		local passedRank = rankOf(roll.allTime)
		if passedRank == nil then
			return refused(copy(parsed), ERRORS.allTime)
		end
		passedAll = higher(parsed.allTime, named(passedRank))
	end

	local nextState = copy(parsed)
	nextState.rolls += 1
	nextState.streak += 1
	local bestRank = rankOf(nextState.best)
	local raisedBest = bestRank == nil or rank > bestRank
	if raisedBest then
		nextState.best = rarity
	end
	local barRank = rankOf(passedAll)
	local newPersonalBest = barRank == nil or rank > barRank
	if newPersonalBest then
		nextState.personalBest = true
		nextState.allTime = rarity
	else
		nextState.allTime = passedAll
	end

	local milestone = nil
	local callout = nil
	if MILESTONE_AT[nextState.rolls] == true then
		milestone = nextState.rolls
		callout = string.format("%d rolls", nextState.rolls)
	end

	return {
		ok = true,
		state = nextState,
		rarity = rarity,
		rolls = nextState.rolls,
		streak = nextState.streak,
		best = nextState.best,
		personalBest = nextState.personalBest,
		newPersonalBest = newPersonalBest,
		raisedBest = raisedBest,
		milestone = milestone,
		callout = callout,
	}
end

local function meter(counter: any, goal: any, whichErr: string?): Meter
	if whichErr ~= nil then
		return {
			ok = false,
			fill = 0,
			counter = 0,
			goal = nil,
			error = whichErr,
		}
	end
	local cap = finite(goal)
	if cap == nil or cap <= 0 then
		return {
			ok = false,
			fill = 0,
			counter = 0,
			goal = nil,
			error = ERRORS.goal,
		}
	end
	if counter == nil then
		return {
			ok = false,
			fill = 0,
			counter = 0,
			goal = cap,
			error = ERRORS.counter,
		}
	end
	local value = finite(counter)
	if value == nil or value < 0 then
		return {
			ok = false,
			fill = 0,
			counter = 0,
			goal = cap,
			error = ERRORS.counter,
		}
	end
	return {
		ok = true,
		fill = math.clamp(value / cap, 0, 1),
		counter = value,
		goal = cap,
		error = nil,
	}
end

local function fromTable(source: { [string]: any }): (any, any, string?)
	local hasEpic = source.sinceEpic ~= nil or source.epicGoal ~= nil
	local hasLegendary = source.sinceLegendary ~= nil or source.legendaryGoal ~= nil
	local hasMath = source.rollsSinceLegendary ~= nil or source.pityLegendaryAt ~= nil
	local hasPlain = source.counter ~= nil or source.since ~= nil or source.goal ~= nil
	local kinds = 0
	if hasEpic then
		kinds += 1
	end
	if hasLegendary then
		kinds += 1
	end
	if hasMath then
		kinds += 1
	end
	if hasPlain then
		kinds += 1
	end
	if kinds > 1 then
		return nil, nil, ERRORS.which
	end
	if hasMath then
		return source.rollsSinceLegendary, source.pityLegendaryAt, nil
	end
	if hasEpic then
		return source.sinceEpic, source.epicGoal, nil
	end
	if hasLegendary then
		return source.sinceLegendary, source.legendaryGoal, nil
	end
	if source.counter ~= nil then
		return source.counter, source.goal, nil
	end
	return source.since, source.goal, nil
end

function RollHype.pity(counter: any, goal: any?): Meter
	if goal == nil and type(counter) == "table" then
		local picked, pickedGoal, whichErr = fromTable(counter)
		return meter(picked, pickedGoal, whichErr)
	end
	return meter(counter, goal, nil)
end

-- `_paid` is accepted so the wire can pass the paid flag through.
-- It does not change the tier or the build-up.
function RollHype.tempo(rarity: any, _paid: any?): Tempo
	local rank = rankOf(rarity)
	if rank == nil then
		return {
			ok = false,
			rarity = nil,
			tier = nil,
			buildUp = nil,
			error = ERRORS.rarity,
		}
	end
	local name = named(rank)
	local buildUp = CONFIG.buildUp[name]
	if type(buildUp) ~= "number" then
		return {
			ok = false,
			rarity = nil,
			tier = nil,
			buildUp = nil,
			error = ERRORS.rarity,
		}
	end
	return {
		ok = true,
		rarity = name,
		tier = rank,
		buildUp = buildUp,
		error = nil,
	}
end

return RollHype
