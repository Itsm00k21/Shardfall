--!strict

--[[
	Contest Weekend. Pure rules for the first 48 hours of a new raid.

	The server passes plain tables and unix seconds. This module does
	not read players, grant gear, place a statue, or send an
	announcement. It does not touch saved data, memory queues, or
	remotes. It does not read the clock. Thresholds live in CONFIG.
	Nothing here costs Robux. There is no paid skip of the cap, the
	window, or the first clear.

	Shardbreaker is the only difficulty. Story, Normal, Hard, Fracture,
	Practice, and guided are refused. A Guided Shardbreaker clear may
	count. Guided does not waive the item-level cap. A practice clear
	is refused.

	The window is [openedAt, openedAt + durationSeconds). Inside it, a
	whole item level at or under the cap is allowed. Outside it, every
	finite whole level is allowed. The first counted clear sets the
	statue and the announcement once and credits that roster with the
	emblem. Later clears in the window credit roster members who are
	not already credited. The same stored run id is a no-op. A clear
	outside the window counts nothing.

	Each call returns a new table and does not write its input.
]]

local RaidContest = {}

local FRACTURE = "fracture"

RaidContest.CONFIG = table.freeze({
	-- 48 hours. The contest research line says 24-48. This row is 48.
	durationSeconds = 172800,
	-- Placeholder. There is no item-level field in the repo yet.
	itemLevelCap = 200,
	-- Placeholder cap for a raid id and a string run id.
	maxIdLength = 64,
})

RaidContest.DIFFICULTIES = table.freeze({
	shardbreaker = true,
})

-- Guided is a mode. These ids are not contest difficulties.
RaidContest.REFUSED = table.freeze({
	story = true,
	normal = true,
	hard = true,
	fracture = true,
	practice = true,
	guided = true,
})

RaidContest.REASONS = table.freeze({
	window = "window",
	duplicate = "duplicate",
})

RaidContest.ERRORS = table.freeze({
	rules = "The contest rules are unusable.",
	state = "The contest record is unusable.",
	open = "That contest is unusable.",
	raid = "That raid id is unusable.",
	time = "That contest time is unusable.",
	level = "That item level is unusable.",
	gear = "That item level is over the contest cap.",
	record = "That clear is unusable.",
	runId = "That run id is unusable.",
	difficulty = "Contest Weekend counts Shardbreaker only.",
	practice = "Practice Grove is not a contest clear.",
	practiceFlag = "That practice flag is unusable.",
	guided = "That guided flag is unusable.",
	roster = "That roster is unusable.",
	userId = "That player id is unusable.",
	duplicate = "That player is listed twice.",
	empty = "That roster has nobody to credit.",
	skip = "Contest Weekend has no paid skip.",
})

local SKIP = table.freeze({
	skip = true,
	waive = true,
	waiveCap = true,
	bypass = true,
	bypassCap = true,
	paid = true,
	robux = true,
	premium = true,
	force = true,
	forceFirst = true,
	skipCap = true,
	skipWindow = true,
	productId = true,
	gamePass = true,
	price = true,
})

export type RunId = number | string

export type State = {
	raidId: string,
	openedAt: number,
	statue: boolean,
	announce: boolean,
	firstRunId: RunId?,
	firstRoster: { number },
	credited: { number },
	runs: { RunId },
}

export type OpenResult = {
	ok: boolean,
	persist: boolean,
	state: State,
	error: string?,
}

export type GearResult = {
	ok: boolean,
	persist: boolean,
	allowed: boolean,
	inside: boolean,
	state: State,
	itemLevel: number,
	cap: number,
	error: string?,
}

export type ClearResult = {
	ok: boolean,
	persist: boolean,
	counted: boolean,
	statue: boolean,
	announce: boolean,
	emblem: { number },
	runId: RunId?,
	state: State,
	reason: string?,
	error: string?,
}

local ERRORS = RaidContest.ERRORS
local REASONS = RaidContest.REASONS

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

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
	local number = finite(value)
	if number == nil or number < 0 or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function positive(value: any): number?
	local number = whole(value)
	if number == nil or number < 1 then
		return nil
	end
	return number
end

local function rules(): (number?, number?, number?, string?)
	local duration = positive(RaidContest.CONFIG.durationSeconds)
	local cap = whole(RaidContest.CONFIG.itemLevelCap)
	local idCap = positive(RaidContest.CONFIG.maxIdLength)
	if duration == nil or cap == nil or idCap == nil then
		return nil, nil, nil, ERRORS.rules
	end
	return duration, cap, idCap, nil
end

local function endsAt(openedAt: number, duration: number): number?
	local ends = openedAt + duration
	if ends ~= ends or ends == math.huge or ends == -math.huge or ends < openedAt then
		return nil
	end
	return ends
end

local function inWindow(openedAt: number, now: number, duration: number): boolean?
	local ends = endsAt(openedAt, duration)
	if ends == nil then
		return nil
	end
	return now >= openedAt and now < ends
end

local function arraySize(value: any): number?
	if type(value) ~= "table" then
		return nil
	end
	local count = #value
	local seen = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key > count or key ~= math.floor(key) then
			return nil
		end
		seen += 1
	end
	if seen ~= count then
		return nil
	end
	return count
end

local function stringKeyed(value: { [any]: any }): boolean
	for key in pairs(value) do
		if type(key) ~= "string" then
			return false
		end
	end
	return true
end

local function skipField(value: { [any]: any }): boolean
	for key in pairs(SKIP) do
		if value[key] ~= nil then
			return true
		end
	end
	return false
end

local function blankState(): State
	return {
		raidId = "",
		openedAt = 0,
		statue = false,
		announce = false,
		firstRoster = {},
		credited = {},
		runs = {},
	}
end

local function userIdOf(value: any): number?
	return positive(value)
end

local function runKey(id: RunId): string
	if type(id) == "number" then
		return "n" .. tostring(id)
	end
	return "s" .. id
end

local function sameRun(left: RunId, right: RunId): boolean
	return type(left) == type(right) and left == right
end

local function storedRunId(value: any, cap: number): RunId?
	if type(value) == "number" then
		return positive(value)
	end
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = trim(value)
	if trimmed == "" or trimmed ~= value or #trimmed > cap then
		return nil
	end
	return trimmed
end

local function incomingRunId(value: any, cap: number): (RunId?, string?)
	if value == nil then
		return nil, ERRORS.runId
	end
	if type(value) == "number" then
		local id = positive(value)
		if id == nil then
			return nil, ERRORS.runId
		end
		return id, nil
	end
	if type(value) ~= "string" then
		return nil, ERRORS.runId
	end
	local trimmed = trim(value)
	if trimmed == "" or #trimmed > cap then
		return nil, ERRORS.runId
	end
	return trimmed, nil
end

local function readUsers(value: any): { number }?
	local size = arraySize(value)
	if size == nil then
		return nil
	end
	local list = {}
	local seen: { [number]: boolean } = {}
	for index = 1, size do
		local id = userIdOf(value[index])
		if id == nil or seen[id] == true then
			return nil
		end
		seen[id] = true
		list[index] = id
	end
	return list
end

local function readRuns(value: any, cap: number): { RunId }?
	local size = arraySize(value)
	if size == nil then
		return nil
	end
	local runs = {}
	local seen: { [string]: boolean } = {}
	for index = 1, size do
		local id = storedRunId(value[index], cap)
		if id == nil then
			return nil
		end
		local key = runKey(id)
		if seen[key] == true then
			return nil
		end
		seen[key] = true
		runs[index] = id
	end
	return runs
end

local function readState(value: any, duration: number, idCap: number): (State?, string?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.state
	end
	if type(value.raidId) ~= "string" then
		return nil, ERRORS.state
	end
	local raidId = trim(value.raidId)
	if raidId == "" or raidId ~= value.raidId or #raidId > idCap then
		return nil, ERRORS.state
	end
	local openedAt = whole(value.openedAt)
	if openedAt == nil or endsAt(openedAt, duration) == nil then
		return nil, ERRORS.state
	end
	if type(value.statue) ~= "boolean" or type(value.announce) ~= "boolean" then
		return nil, ERRORS.state
	end
	if value.statue ~= value.announce then
		return nil, ERRORS.state
	end
	local firstRoster = readUsers(value.firstRoster)
	local credited = readUsers(value.credited)
	local runs = readRuns(value.runs, idCap)
	if firstRoster == nil or credited == nil or runs == nil then
		return nil, ERRORS.state
	end
	if value.statue then
		if #runs == 0 or #firstRoster == 0 or #credited < #firstRoster then
			return nil, ERRORS.state
		end
		local firstRunId = storedRunId(value.firstRunId, idCap)
		if firstRunId == nil or not sameRun(firstRunId, runs[1]) then
			return nil, ERRORS.state
		end
		for index, userId in ipairs(firstRoster) do
			if credited[index] ~= userId then
				return nil, ERRORS.state
			end
		end
		return {
			raidId = raidId,
			openedAt = openedAt,
			statue = true,
			announce = true,
			firstRunId = firstRunId,
			firstRoster = firstRoster,
			credited = credited,
			runs = runs,
		},
			nil
	end
	if value.firstRunId ~= nil or #firstRoster ~= 0 or #credited ~= 0 or #runs ~= 0 then
		return nil, ERRORS.state
	end
	return {
		raidId = raidId,
		openedAt = openedAt,
		statue = false,
		announce = false,
		firstRoster = firstRoster,
		credited = credited,
		runs = runs,
	},
		nil
end

local function hasRun(runs: { RunId }, id: RunId): boolean
	for _, stored in ipairs(runs) do
		if sameRun(stored, id) then
			return true
		end
	end
	return false
end

local function difficultyOf(value: any, cap: number): (string?, string?)
	if type(value) ~= "string" then
		return nil, ERRORS.difficulty
	end
	local cleaned = string.lower(trim(value))
	if cleaned == "" or #cleaned > cap then
		return nil, ERRORS.difficulty
	end
	if RaidContest.REFUSED[cleaned] == true or string.sub(cleaned, 1, #FRACTURE) == FRACTURE then
		return nil, ERRORS.difficulty
	end
	if RaidContest.DIFFICULTIES[cleaned] ~= true then
		return nil, ERRORS.difficulty
	end
	return cleaned, nil
end

local function practiceOf(value: any): (boolean?, string?)
	if value == nil then
		return false, nil
	end
	if type(value) ~= "boolean" then
		return nil, ERRORS.practiceFlag
	end
	if value then
		return nil, ERRORS.practice
	end
	return false, nil
end

local function guidedError(value: any): string?
	if value == nil or type(value) == "boolean" then
		return nil
	end
	return ERRORS.guided
end

local function readRoster(value: any): ({ number }?, string?)
	local size = arraySize(value)
	if size == nil then
		return nil, ERRORS.roster
	end
	if size == 0 then
		return nil, ERRORS.empty
	end
	local roster = {}
	local seen: { [number]: boolean } = {}
	for index = 1, size do
		local id = userIdOf(value[index])
		if id == nil then
			return nil, ERRORS.userId
		end
		if seen[id] == true then
			return nil, ERRORS.duplicate
		end
		seen[id] = true
		roster[index] = id
	end
	return roster, nil
end

local function openFail(message: string): OpenResult
	return {
		ok = false,
		persist = false,
		state = blankState(),
		error = message,
	}
end

function RaidContest.open(ctx: any, extra: any): OpenResult
	local duration, _, idCap, rulesError = rules()
	if duration == nil or idCap == nil then
		return openFail(rulesError or ERRORS.rules)
	end
	if extra ~= nil then
		return openFail(ERRORS.skip)
	end
	if type(ctx) ~= "table" or not stringKeyed(ctx) then
		return openFail(ERRORS.open)
	end
	if skipField(ctx) then
		return openFail(ERRORS.skip)
	end
	if type(ctx.raidId) ~= "string" then
		return openFail(ERRORS.raid)
	end
	local raidId = trim(ctx.raidId)
	if raidId == "" or #raidId > idCap then
		return openFail(ERRORS.raid)
	end
	local openedAt = whole(ctx.openedAt)
	if openedAt == nil or endsAt(openedAt, duration) == nil then
		return openFail(ERRORS.time)
	end
	return {
		ok = true,
		persist = true,
		state = {
			raidId = raidId,
			openedAt = openedAt,
			statue = false,
			announce = false,
			firstRoster = {},
			credited = {},
			runs = {},
		},
	}
end

local function gearFail(
	message: string,
	state: State,
	itemLevel: number,
	cap: number,
	inside: boolean
): GearResult
	return {
		ok = false,
		persist = false,
		allowed = false,
		inside = inside,
		state = state,
		itemLevel = itemLevel,
		cap = cap,
		error = message,
	}
end

function RaidContest.gear(state: any, itemLevel: any, now: any, extra: any): GearResult
	local duration, cap, idCap, rulesError = rules()
	if duration == nil or cap == nil or idCap == nil then
		return gearFail(rulesError or ERRORS.rules, blankState(), 0, 0, false)
	end
	local record, stateError = readState(state, duration, idCap)
	if record == nil then
		return gearFail(stateError or ERRORS.state, blankState(), 0, cap, false)
	end
	if extra ~= nil then
		return gearFail(ERRORS.skip, record, 0, cap, false)
	end
	local instant = whole(now)
	if instant == nil then
		return gearFail(ERRORS.time, record, 0, cap, false)
	end
	local inside = inWindow(record.openedAt, instant, duration)
	if inside == nil then
		return gearFail(ERRORS.time, record, 0, cap, false)
	end
	local level = whole(itemLevel)
	if level == nil then
		return gearFail(ERRORS.level, record, 0, cap, inside)
	end
	if inside and level > cap then
		return gearFail(ERRORS.gear, record, level, cap, true)
	end
	return {
		ok = true,
		persist = false,
		allowed = true,
		inside = inside,
		state = record,
		itemLevel = level,
		cap = cap,
	}
end

local function failClear(message: string, state: State, runId: RunId?): ClearResult
	local result: ClearResult = {
		ok = false,
		persist = false,
		counted = false,
		statue = false,
		announce = false,
		emblem = {},
		state = state,
		error = message,
	}
	if runId ~= nil then
		result.runId = runId
	end
	return result
end

local function quietClear(state: State, runId: RunId, reason: string): ClearResult
	return {
		ok = true,
		persist = false,
		counted = false,
		statue = false,
		announce = false,
		emblem = {},
		runId = runId,
		state = state,
		reason = reason,
	}
end

function RaidContest.clear(state: any, record: any, now: any, extra: any): ClearResult
	local duration, _, idCap, rulesError = rules()
	if duration == nil or idCap == nil then
		return failClear(rulesError or ERRORS.rules, blankState(), nil)
	end
	local saved, stateError = readState(state, duration, idCap)
	if saved == nil then
		return failClear(stateError or ERRORS.state, blankState(), nil)
	end
	if extra ~= nil then
		return failClear(ERRORS.skip, saved, nil)
	end
	if type(record) ~= "table" or not stringKeyed(record) then
		return failClear(ERRORS.record, saved, nil)
	end
	if skipField(record) then
		return failClear(ERRORS.skip, saved, nil)
	end
	local runId, runError = incomingRunId(record.runId, idCap)
	if runId == nil then
		return failClear(runError or ERRORS.runId, saved, nil)
	end
	if hasRun(saved.runs, runId) then
		return quietClear(saved, runId, REASONS.duplicate)
	end
	local practice, practiceError = practiceOf(record.practice)
	if practice == nil then
		return failClear(practiceError or ERRORS.practice, saved, runId)
	end
	local guided = guidedError(record.guided)
	if guided ~= nil then
		return failClear(guided, saved, runId)
	end
	local difficulty, difficultyError = difficultyOf(record.difficulty, idCap)
	if difficulty == nil then
		return failClear(difficultyError or ERRORS.difficulty, saved, runId)
	end
	local roster, rosterError = readRoster(record.roster)
	if roster == nil then
		return failClear(rosterError or ERRORS.roster, saved, runId)
	end
	local instant = whole(now)
	if instant == nil then
		return failClear(ERRORS.time, saved, runId)
	end
	local inside = inWindow(saved.openedAt, instant, duration)
	if inside == nil then
		return failClear(ERRORS.time, saved, runId)
	end
	if not inside then
		return quietClear(saved, runId, REASONS.window)
	end
	local granted = not saved.statue
	if granted then
		saved.statue = true
		saved.announce = true
		saved.firstRunId = runId
		saved.firstRoster = table.clone(roster)
	end
	local seen: { [number]: boolean } = {}
	for _, userId in ipairs(saved.credited) do
		seen[userId] = true
	end
	local emblem = {}
	for _, userId in ipairs(roster) do
		if seen[userId] ~= true then
			seen[userId] = true
			table.insert(emblem, userId)
			table.insert(saved.credited, userId)
		end
	end
	table.insert(saved.runs, runId)
	return {
		ok = true,
		persist = true,
		counted = true,
		statue = granted,
		announce = granted,
		emblem = emblem,
		runId = runId,
		state = saved,
	}
end

return RaidContest
