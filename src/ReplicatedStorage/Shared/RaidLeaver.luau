--!strict

--[[
	Raid leaver penalty. Finder cooldown after too many leaves in one UTC day.

	The server passes a plain record and the current time. This module does
	not read players, queue Finder, grant loot, or touch DataStores and
	remotes. Thresholds live in CONFIG. Nothing here costs Robux.

	A voluntary leave counts immediately. A disconnect opens a rejoin
	window and does not count until that window is missed. Rejoining at
	or before the deadline is not a leave. Missing it counts as one.
	An AFK removal and a passed vote-kick are not voluntary leaves. They
	clear a pending window, including one that already expired, and do
	not count.

	The third counted leave in a UTC day starts a 15-minute Raid Finder
	cooldown. A later counted leave does not add time while that cooldown
	is still running. Once it has ended, another counted leave starts a
	new 15 minutes. The day is floor(now / 86400), same as tradeDay.
	Pass os.time(). This module does not read the clock. It does not
	forfeit Marks or rewards.
]]

local RaidLeaver = {}

RaidLeaver.CONFIG = table.freeze({
	leavesPerDay = 3,
	cooldownSeconds = 15 * 60,
	rejoinSeconds = 3 * 60,
	daySeconds = 86400,
})

RaidLeaver.CAUSES = table.freeze({
	leave = true,
	disconnect = true,
	afk = true,
	kick = true,
})

RaidLeaver.ERRORS = table.freeze({
	time = "Raid time is missing.",
	cause = "That departure is not a known cause.",
	record = "The leave record is unusable.",
	cooling = "Raid Finder is cooling down after too many leaves.",
})

export type Outcome = "counted" | "window" | "cleared" | "ignored" | "open" | "cooling" | "invalid"

export type Cause = "leave" | "disconnect" | "afk" | "kick"

export type Record = {
	leaveDay: number?,
	leaveCount: number?,
	cooldownUntil: number?,
	rejoinUntil: number?,
}

export type Result = {
	ok: boolean,
	outcome: Outcome,
	counted: boolean,
	finderBlocked: boolean,
	cooldownStarted: boolean,
	leaveDay: number,
	leaveCount: number,
	cooldownUntil: number,
	rejoinUntil: number,
	remainingSeconds: number,
	missedWindow: boolean,
	error: string?,
}

type State = {
	leaveDay: number,
	leaveCount: number,
	cooldownUntil: number,
	rejoinUntil: number,
}

type Window = "none" | "open" | "missed"

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function RaidLeaver.dayNumber(now: number): number?
	local at = finite(now)
	if at == nil or at < 0 then
		return nil
	end
	return math.floor(at / RaidLeaver.CONFIG.daySeconds)
end

-- Nil becomes 0. A negative becomes 0. Non-finite is corrupt.
-- leaveDay and leaveCount are whole. Deadlines keep a fraction.
local function storedNumber(value: any, floorIt: boolean): (number?, boolean)
	if value == nil then
		return 0, false
	end
	local number = finite(value)
	if number == nil then
		return nil, true
	end
	if number < 0 then
		return 0, false
	end
	if floorIt then
		return math.floor(number), false
	end
	return number, false
end

local function readRecord(record: any): (State?, string?)
	if record == nil then
		return {
			leaveDay = 0,
			leaveCount = 0,
			cooldownUntil = 0,
			rejoinUntil = 0,
		},
			nil
	end
	if type(record) ~= "table" then
		return nil, RaidLeaver.ERRORS.record
	end
	local leaveDay, badDay = storedNumber(record.leaveDay, true)
	local leaveCount, badCount = storedNumber(record.leaveCount, true)
	local cooldownUntil, badCooldown = storedNumber(record.cooldownUntil, false)
	local rejoinUntil, badRejoin = storedNumber(record.rejoinUntil, false)
	if badDay or badCount or badCooldown or badRejoin then
		return nil, RaidLeaver.ERRORS.record
	end
	if leaveDay == nil or leaveCount == nil or cooldownUntil == nil or rejoinUntil == nil then
		return nil, RaidLeaver.ERRORS.record
	end
	return {
		leaveDay = leaveDay,
		leaveCount = leaveCount,
		cooldownUntil = cooldownUntil,
		rejoinUntil = rejoinUntil,
	},
		nil
end

local function invalid(message: string): Result
	return {
		ok = false,
		outcome = "invalid",
		counted = false,
		finderBlocked = true,
		cooldownStarted = false,
		leaveDay = 0,
		leaveCount = 0,
		cooldownUntil = 0,
		rejoinUntil = 0,
		remainingSeconds = 0,
		missedWindow = false,
		error = message,
	}
end

local function refuse(message: string, stored: State?): Result
	local refused = invalid(message)
	if stored == nil then
		return refused
	end
	refused.leaveDay = stored.leaveDay
	refused.leaveCount = stored.leaveCount
	refused.cooldownUntil = stored.cooldownUntil
	refused.rejoinUntil = stored.rejoinUntil
	return refused
end

local function prepare(record: any, now: any): (State?, number?, number?, Result?)
	local stored, recordError = readRecord(record)
	if stored == nil then
		return nil, nil, nil, invalid(recordError or RaidLeaver.ERRORS.record)
	end
	local at = finite(now)
	local today = if at ~= nil then RaidLeaver.dayNumber(at) else nil
	if at == nil or today == nil then
		return nil, nil, nil, refuse(RaidLeaver.ERRORS.time, stored)
	end
	return stored, at, today, nil
end

local function copy(state: State): State
	return {
		leaveDay = state.leaveDay,
		leaveCount = state.leaveCount,
		cooldownUntil = state.cooldownUntil,
		rejoinUntil = state.rejoinUntil,
	}
end

local function onDay(state: State, today: number): State
	local nextState = copy(state)
	if nextState.leaveDay ~= today then
		nextState.leaveDay = today
		nextState.leaveCount = 0
	end
	return nextState
end

local function countLeave(state: State, now: number, today: number): (State, boolean)
	local nextState = onDay(state, today)
	nextState.leaveCount += 1
	nextState.rejoinUntil = 0
	if nextState.leaveCount < RaidLeaver.CONFIG.leavesPerDay then
		return nextState, false
	end
	if now < nextState.cooldownUntil then
		return nextState, false
	end
	nextState.cooldownUntil = now + RaidLeaver.CONFIG.cooldownSeconds
	return nextState, true
end

-- The deadline itself is still inside the window. One second later is a miss.
local function windowKind(rejoinUntil: number, now: number): Window
	if rejoinUntil <= 0 then
		return "none"
	end
	if now <= rejoinUntil then
		return "open"
	end
	return "missed"
end

local function finish(
	outcome: Outcome,
	state: State,
	counted: boolean,
	started: boolean,
	now: number,
	missedWindow: boolean
): Result
	local blocked = state.cooldownUntil > now
	local left = 0
	if blocked then
		left = state.cooldownUntil - now
	end
	local message = nil
	if blocked and outcome == "cooling" then
		message = RaidLeaver.ERRORS.cooling
	end
	return {
		ok = true,
		outcome = outcome,
		counted = counted,
		finderBlocked = blocked,
		cooldownStarted = started,
		leaveDay = state.leaveDay,
		leaveCount = state.leaveCount,
		cooldownUntil = state.cooldownUntil,
		rejoinUntil = state.rejoinUntil,
		remainingSeconds = left,
		missedWindow = missedWindow,
		error = message,
	}
end

local function knownCause(cause: any): boolean
	return type(cause) == "string" and RaidLeaver.CAUSES[cause] == true
end

function RaidLeaver.depart(record: Record?, now: number, cause: any): Result
	local state, at, today, problem = prepare(record, now)
	if state == nil or at == nil or today == nil then
		return problem or invalid(RaidLeaver.ERRORS.time)
	end
	if not knownCause(cause) then
		local refused = refuse(RaidLeaver.ERRORS.cause, state)
		if state.cooldownUntil > at then
			refused.finderBlocked = true
			refused.remainingSeconds = state.cooldownUntil - at
		else
			refused.finderBlocked = false
		end
		return refused
	end
	local kind = windowKind(state.rejoinUntil, at)
	if cause == "afk" or cause == "kick" then
		local cleared = onDay(state, today)
		cleared.rejoinUntil = 0
		return finish("ignored", cleared, false, false, at, false)
	end
	if cause == "disconnect" then
		if kind == "missed" then
			local countedState, started = countLeave(state, at, today)
			countedState.rejoinUntil = at + RaidLeaver.CONFIG.rejoinSeconds
			return finish("window", countedState, true, started, at, false)
		end
		local opened = onDay(state, today)
		if kind == "none" then
			opened.rejoinUntil = at + RaidLeaver.CONFIG.rejoinSeconds
		end
		return finish("window", opened, false, false, at, false)
	end
	local countedState, started = countLeave(state, at, today)
	return finish("counted", countedState, true, started, at, false)
end

function RaidLeaver.rejoin(record: Record?, now: number): Result
	local state, at, today, problem = prepare(record, now)
	if state == nil or at == nil or today == nil then
		return problem or invalid(RaidLeaver.ERRORS.time)
	end
	local kind = windowKind(state.rejoinUntil, at)
	if kind == "open" then
		local cleared = onDay(state, today)
		cleared.rejoinUntil = 0
		return finish("cleared", cleared, false, false, at, false)
	end
	if kind == "missed" then
		local countedState, started = countLeave(state, at, today)
		return finish("counted", countedState, true, started, at, false)
	end
	return finish("ignored", onDay(state, today), false, false, at, false)
end

function RaidLeaver.resolve(record: Record?, now: number): Result
	local state, at, today, problem = prepare(record, now)
	if state == nil or at == nil or today == nil then
		return problem or invalid(RaidLeaver.ERRORS.time)
	end
	local kind = windowKind(state.rejoinUntil, at)
	if kind == "missed" then
		local countedState, started = countLeave(state, at, today)
		return finish("counted", countedState, true, started, at, false)
	end
	if kind == "open" then
		return finish("window", onDay(state, today), false, false, at, false)
	end
	return finish("ignored", onDay(state, today), false, false, at, false)
end

function RaidLeaver.finder(record: Record?, now: number): Result
	local state, at, today, problem = prepare(record, now)
	if state == nil or at == nil or today == nil then
		return problem or invalid(RaidLeaver.ERRORS.time)
	end
	local rolled = onDay(state, today)
	local missed = windowKind(state.rejoinUntil, at) == "missed"
	local outcome: Outcome = "open"
	if rolled.cooldownUntil > at then
		outcome = "cooling"
	end
	return finish(outcome, rolled, false, false, at, missed)
end

return RaidLeaver
