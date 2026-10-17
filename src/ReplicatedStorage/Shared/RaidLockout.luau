--!strict

--[[
	Weekly personal-loot lockout.

	The server passes a plain profile-shaped record and unix seconds.
	This module does not grant loot, pay Marks, Dust, or materials,
	read players, or touch saved data and remotes. It does not read
	the clock. Pass unix seconds as now. Tunables live in CONFIG.
	Nothing here costs Robux. There is no paid skip of the lockout.

	The week key is RaidMarks.weekKey. This file does not restate
	that Tuesday rule.

	Story, Normal, Hard, and Shardbreaker each lock once per boss per
	week. Fracture has no lockout. Practice never locks and never
	loots. The same claim id is a no-op, so a retry cannot grant loot
	again. A later clear of a locked pair returns lootEligible false
	and still allows reclear rewards. Old weeks are pruned on read.

	Each call returns a new table and does not write its input.
]]

local RaidMarks = require("./RaidMarks")

local RaidLockout = {}

local MAX_SAFE = 9007199254740991
local FRACTURE = "fracture"
local SEPARATOR = ":"

RaidLockout.CONFIG = table.freeze({
	-- Placeholder cap for a boss id and a string claim id. A GUID fits.
	maxIdLength = 64,
	-- Weeks kept on read. 1 keeps the current Tuesday week only.
	retainWeeks = 1,
	-- Placeholder. One stored id per accepted claim in that week.
	-- A full week refuses a new id instead of forgetting one.
	maxClaims = 256,
})

-- These four each lock once per boss per week.
RaidLockout.LOCKED = table.freeze({
	story = true,
	normal = true,
	hard = true,
	shardbreaker = true,
})

-- Fracture has no lockout. A level suffix stays open too.
RaidLockout.OPEN = table.freeze({
	fracture = true,
})

-- Not difficulties here. Practice is a flag. Guided is a mode.
RaidLockout.REFUSED = table.freeze({
	practice = true,
	guided = true,
})

RaidLockout.REASONS = table.freeze({
	loot = "loot",
	lockout = "lockout",
	fracture = "fracture",
	practice = "practice",
	duplicate = "duplicate",
})

RaidLockout.ERRORS = table.freeze({
	rules = "The lockout rules are unusable.",
	state = "The lockout record is unusable.",
	claim = "That claim is unusable.",
	query = "That lockout query is unusable.",
	claimId = "That claim id is unusable.",
	boss = "That boss id is unusable.",
	difficulty = "That difficulty cannot take a loot lock.",
	practice = "That practice flag is unusable.",
	guided = "That guided flag is unusable.",
	time = "That raid time is unusable.",
	clock = "Raid time moved backwards.",
	full = "That week's claim list is full.",
	skip = "The loot lockout has no paid skip.",
})

local SKIP = table.freeze({
	skip = true,
	waive = true,
	waiveLock = true,
	waiveLockout = true,
	bypass = true,
	bypassLock = true,
	paid = true,
	robux = true,
	premium = true,
	price = true,
	productId = true,
	gamePass = true,
	force = true,
	unlock = true,
	skipLock = true,
	skipLockout = true,
})

export type ClaimId = number | string

export type Week = {
	weekKey: number,
	locks: { string },
	claims: { ClaimId },
}

export type State = {
	weeks: { Week },
}

export type Result = {
	ok: boolean,
	persist: boolean,
	lootEligible: boolean,
	reclearRewards: boolean,
	locked: boolean,
	reason: string?,
	weekKey: number,
	bossId: string,
	difficulty: string,
	claimId: ClaimId?,
	state: State,
	error: string?,
}

export type View = {
	ok: boolean,
	persist: boolean,
	state: State,
	weekKey: number,
	error: string?,
}

type Ready = {
	state: State,
	weekKey: number,
	pruned: boolean,
	idCap: number,
	maxClaims: number,
}

local ERRORS = RaidLockout.ERRORS
local REASONS = RaidLockout.REASONS

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function wholeBetween(value: any, minimum: number, maximum: number): number?
	local number = finite(value)
	if number == nil or number < minimum or number > maximum or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function positive(value: any): number?
	return wholeBetween(value, 1, MAX_SAFE)
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

local function blank(): State
	return {
		weeks = {},
	}
end

local function copyWeek(week: Week): Week
	local locks = {}
	local claims = {}
	for _, lock in ipairs(week.locks) do
		table.insert(locks, lock)
	end
	for _, id in ipairs(week.claims) do
		table.insert(claims, id)
	end
	return {
		weekKey = week.weekKey,
		locks = locks,
		claims = claims,
	}
end

local function lockedDifficulty(id: string): boolean
	return (RaidLockout.LOCKED :: any)[id] == true
end

local function splitLock(stored: string): (string?, string?)
	local colon = string.find(stored, SEPARATOR, 1, true)
	if colon == nil or colon < 2 then
		return nil, nil
	end
	local boss = string.sub(stored, 1, colon - 1)
	local difficulty = string.sub(stored, colon + 1)
	if difficulty == "" or string.find(difficulty, SEPARATOR, 1, true) ~= nil then
		return nil, nil
	end
	return boss, difficulty
end

local function pairKey(bossId: string, difficulty: string): string
	return bossId .. SEPARATOR .. difficulty
end

local function storedClaimId(value: any, idCap: number): ClaimId?
	if type(value) == "number" then
		return wholeBetween(value, 1, MAX_SAFE)
	end
	if type(value) ~= "string" then
		return nil
	end
	if value ~= trim(value) or value == "" or #value > idCap then
		return nil
	end
	return value
end

local function readLocks(value: any, idCap: number, maxClaims: number): ({ string }?, string?)
	local count = arraySize(value)
	if count == nil or count > maxClaims then
		return nil, ERRORS.state
	end
	local locks = {}
	local seen: { [string]: boolean } = {}
	for index = 1, count do
		local stored = value[index]
		if type(stored) ~= "string" then
			return nil, ERRORS.state
		end
		local boss, difficulty = splitLock(stored)
		if boss == nil or difficulty == nil or not lockedDifficulty(difficulty) then
			return nil, ERRORS.state
		end
		if #boss > idCap or boss ~= trim(boss) or boss ~= string.lower(boss) then
			return nil, ERRORS.state
		end
		local canonical = pairKey(boss, difficulty)
		if stored ~= canonical or seen[canonical] == true then
			return nil, ERRORS.state
		end
		seen[canonical] = true
		table.insert(locks, canonical)
	end
	return locks, nil
end

local function readClaims(
	value: any,
	idCap: number,
	maxClaims: number,
	seenClaims: { [any]: boolean }
): ({ ClaimId }?, string?)
	local count = arraySize(value)
	if count == nil or count > maxClaims then
		return nil, ERRORS.state
	end
	local claims = {}
	for index = 1, count do
		local id = storedClaimId(value[index], idCap)
		if id == nil or seenClaims[id] == true then
			return nil, ERRORS.state
		end
		seenClaims[id] = true
		table.insert(claims, id)
	end
	return claims, nil
end

local function readWeek(
	value: any,
	idCap: number,
	maxClaims: number,
	seenWeeks: { [number]: boolean },
	seenClaims: { [any]: boolean }
): (Week?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	for key in pairs(value) do
		if type(key) ~= "string" then
			return nil, ERRORS.state
		end
	end
	local weekKey = wholeBetween(value.weekKey, 0, MAX_SAFE)
	if weekKey == nil then
		return nil, ERRORS.state
	end
	if seenWeeks[weekKey] == true then
		return nil, ERRORS.state
	end
	local locks, lockError = readLocks(value.locks, idCap, maxClaims)
	if locks == nil then
		return nil, lockError or ERRORS.state
	end
	local claims, claimError = readClaims(value.claims, idCap, maxClaims, seenClaims)
	if claims == nil then
		return nil, claimError or ERRORS.state
	end
	seenWeeks[weekKey] = true
	return {
		weekKey = weekKey,
		locks = locks,
		claims = claims,
	}, nil
end

local function readState(value: any, idCap: number, maxClaims: number): (State?, string?)
	if value == nil then
		return blank(), nil
	end
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	for key in pairs(value) do
		if type(key) ~= "string" then
			return nil, ERRORS.state
		end
	end
	if value.weeks == nil then
		return blank(), nil
	end
	local count = arraySize(value.weeks)
	if count == nil then
		return nil, ERRORS.state
	end
	local weeks = {}
	local seenWeeks: { [number]: boolean } = {}
	local seenClaims: { [any]: boolean } = {}
	for index = 1, count do
		local week, weekError =
			readWeek(value.weeks[index], idCap, maxClaims, seenWeeks, seenClaims)
		if week == nil then
			return nil, weekError or ERRORS.state
		end
		table.insert(weeks, week)
	end
	return {
		weeks = weeks,
	}, nil
end

local function rules(): (number?, number?, number?, string?)
	local idCap = positive(RaidLockout.CONFIG.maxIdLength)
	local retain = positive(RaidLockout.CONFIG.retainWeeks)
	local maxClaims = positive(RaidLockout.CONFIG.maxClaims)
	if idCap == nil or retain == nil or maxClaims == nil then
		return nil, nil, nil, ERRORS.rules
	end
	local locked = RaidLockout.LOCKED :: any
	if
		locked.story ~= true
		or locked.normal ~= true
		or locked.hard ~= true
		or locked.shardbreaker ~= true
	then
		return nil, nil, nil, ERRORS.rules
	end
	if (RaidLockout.OPEN :: any)[FRACTURE] ~= true then
		return nil, nil, nil, ERRORS.rules
	end
	return idCap, retain, maxClaims, nil
end

-- Same function RaidMarks exports. Do not restate the Tuesday rule here.
function RaidLockout.weekKey(now: number): number?
	return RaidMarks.weekKey(now)
end

local function currentKey(now: any): number?
	if type(now) ~= "number" then
		return nil
	end
	local key = RaidLockout.weekKey(now)
	if key == nil or key ~= math.floor(key) or key < 0 or key > MAX_SAFE then
		return nil
	end
	return key
end

local function newerThan(state: State, key: number): boolean
	for _, week in ipairs(state.weeks) do
		if week.weekKey > key then
			return true
		end
	end
	return false
end

local function prune(state: State, current: number, retain: number): (State, boolean)
	local floor = current - (retain - 1)
	local kept = {}
	local dropped = false
	for _, week in ipairs(state.weeks) do
		if week.weekKey >= floor and week.weekKey <= current then
			table.insert(kept, copyWeek(week))
		else
			dropped = true
		end
	end
	return {
		weeks = kept,
	}, dropped
end

local function load(state: any, now: any, extra: any): (Ready?, string?, State?, number?)
	if extra ~= nil then
		return nil, ERRORS.skip, nil, nil
	end
	local idCap, retain, maxClaims, rulesError = rules()
	if idCap == nil or retain == nil or maxClaims == nil then
		return nil, rulesError or ERRORS.rules, nil, nil
	end
	local record, stateError = readState(state, idCap, maxClaims)
	if record == nil then
		return nil, stateError or ERRORS.state, nil, nil
	end
	local key = currentKey(now)
	if key == nil then
		return nil, ERRORS.time, record, nil
	end
	if newerThan(record, key) then
		return nil, ERRORS.clock, record, key
	end
	local pruned, dropped = prune(record, key, retain)
	return {
		state = pruned,
		weekKey = key,
		pruned = dropped,
		idCap = idCap,
		maxClaims = maxClaims,
	},
		nil,
		nil,
		nil
end

local function isFracture(id: string): boolean
	if (RaidLockout.OPEN :: any)[FRACTURE] ~= true then
		return false
	end
	if id == FRACTURE then
		return true
	end
	if string.sub(id, 1, #FRACTURE) ~= FRACTURE then
		return false
	end
	local mark = string.sub(id, #FRACTURE + 1, #FRACTURE + 1)
	if mark == " " or mark == "-" or mark == "_" then
		return string.sub(id, #FRACTURE + 2) ~= ""
	end
	if mark >= "0" and mark <= "9" then
		return true
	end
	return false
end

local function classify(id: string): string?
	if (RaidLockout.REFUSED :: any)[id] == true then
		return nil
	end
	if isFracture(id) then
		return REASONS.fracture
	end
	if lockedDifficulty(id) then
		return REASONS.loot
	end
	return nil
end

local function optionalFlag(value: any, message: string): (boolean?, string?)
	if value == nil or value == false then
		return false, nil
	end
	if value == true then
		return true, nil
	end
	return nil, message
end

-- True and false are both accepted. Anything else was already refused.
local function modeAccepted(guided: boolean): string?
	if guided == true or guided == false then
		return nil
	end
	return ERRORS.guided
end

local function parseClaimId(value: any, idCap: number): (ClaimId?, string?)
	if type(value) == "number" then
		local number = wholeBetween(value, 1, MAX_SAFE)
		if number == nil then
			return nil, ERRORS.claimId
		end
		return number, nil
	end
	if type(value) ~= "string" then
		return nil, ERRORS.claimId
	end
	local trimmed = trim(value)
	if trimmed == "" or #trimmed > idCap then
		return nil, ERRORS.claimId
	end
	return trimmed, nil
end

local function parseBoss(value: any, idCap: number): (string?, string?)
	local text = token(value)
	if text == nil or #text > idCap or string.find(text, SEPARATOR, 1, true) ~= nil then
		return nil, ERRORS.boss
	end
	return text, nil
end

local function weekRow(state: State, key: number): Week?
	for _, week in ipairs(state.weeks) do
		if week.weekKey == key then
			return week
		end
	end
	return nil
end

local function lockHeld(week: Week?, lockId: string): boolean
	if week == nil then
		return false
	end
	for _, stored in ipairs(week.locks) do
		if stored == lockId then
			return true
		end
	end
	return false
end

local function claimHeld(state: State, id: ClaimId): boolean
	for _, week in ipairs(state.weeks) do
		for _, stored in ipairs(week.claims) do
			if stored == id then
				return true
			end
		end
	end
	return false
end

local function hasRoom(state: State, key: number, maxClaims: number): boolean
	local row = weekRow(state, key)
	if row == nil then
		return true
	end
	return #row.claims < maxClaims
end

local function ensureRow(state: State, key: number): Week
	local found = weekRow(state, key)
	if found ~= nil then
		return found
	end
	local created: Week = {
		weekKey = key,
		locks = {},
		claims = {},
	}
	table.insert(state.weeks, created)
	return created
end

local function finish(result: Result): Result
	return result
end

local function denied(message: string, state: State?, week: number?): Result
	local kept = state
	if kept == nil then
		kept = blank()
	end
	local key = -1
	if week ~= nil then
		key = week
	end
	return finish({
		ok = false,
		persist = false,
		lootEligible = false,
		reclearRewards = false,
		locked = false,
		reason = nil,
		weekKey = key,
		bossId = "",
		difficulty = "",
		claimId = nil,
		state = kept,
		error = message,
	})
end

local function failedView(message: string, state: State?, week: number?): View
	local kept = state
	if kept == nil then
		kept = blank()
	end
	local key = -1
	if week ~= nil then
		key = week
	end
	return {
		ok = false,
		persist = false,
		state = kept,
		weekKey = key,
		error = message,
	}
end

function RaidLockout.fresh(): State
	return blank()
end

function RaidLockout.view(state: any, now: any, extra: any): View
	local ready, err, echo, echoWeek = load(state, now, extra)
	if ready == nil then
		return failedView(err or ERRORS.state, echo, echoWeek)
	end
	return {
		ok = true,
		persist = ready.pruned,
		state = ready.state,
		weekKey = ready.weekKey,
		error = nil,
	}
end

local function practiceResult(ready: Ready, claimId: ClaimId?): Result
	return finish({
		ok = true,
		persist = ready.pruned,
		lootEligible = false,
		reclearRewards = false,
		locked = false,
		reason = REASONS.practice,
		weekKey = ready.weekKey,
		bossId = "",
		difficulty = "",
		claimId = claimId,
		state = ready.state,
		error = nil,
	})
end

local function duplicateResult(ready: Ready, claimId: ClaimId): Result
	return finish({
		ok = true,
		persist = ready.pruned,
		lootEligible = false,
		reclearRewards = false,
		locked = false,
		reason = REASONS.duplicate,
		weekKey = ready.weekKey,
		bossId = "",
		difficulty = "",
		claimId = claimId,
		state = ready.state,
		error = nil,
	})
end

local function fractureResult(
	ready: Ready,
	bossId: string,
	difficulty: string,
	claimId: ClaimId?,
	persist: boolean
): Result
	return finish({
		ok = true,
		persist = persist,
		lootEligible = true,
		reclearRewards = true,
		locked = false,
		reason = REASONS.fracture,
		weekKey = ready.weekKey,
		bossId = bossId,
		difficulty = difficulty,
		claimId = claimId,
		state = ready.state,
		error = nil,
	})
end

local function lootResult(
	ready: Ready,
	bossId: string,
	difficulty: string,
	claimId: ClaimId?,
	persist: boolean,
	eligible: boolean,
	locked: boolean
): Result
	local reason = REASONS.lockout
	if eligible then
		reason = REASONS.loot
	end
	return finish({
		ok = true,
		persist = persist,
		lootEligible = eligible,
		reclearRewards = true,
		locked = locked,
		reason = reason,
		weekKey = ready.weekKey,
		bossId = bossId,
		difficulty = difficulty,
		claimId = claimId,
		state = ready.state,
		error = nil,
	})
end

local function readFlags(value: { [any]: any }): (boolean?, string?)
	local practice, practiceError = optionalFlag(value.practice, ERRORS.practice)
	if practice == nil then
		return nil, practiceError or ERRORS.practice
	end
	local guided, guidedError = optionalFlag(value.guided, ERRORS.guided)
	if guided == nil then
		return nil, guidedError or ERRORS.guided
	end
	local modeError = modeAccepted(guided)
	if modeError ~= nil then
		return nil, modeError
	end
	return practice, nil
end

local function readPair(value: { [any]: any }, idCap: number): (string?, string?, string?, string?)
	local difficulty = token(value.difficulty)
	if difficulty == nil then
		return nil, nil, nil, ERRORS.difficulty
	end
	local kind = classify(difficulty)
	if kind == nil then
		return nil, nil, nil, ERRORS.difficulty
	end
	local bossId, bossError = parseBoss(value.bossId, idCap)
	if bossId == nil then
		return nil, nil, nil, bossError or ERRORS.boss
	end
	return bossId, difficulty, kind, nil
end

function RaidLockout.status(state: any, query: any, now: any, extra: any): Result
	local ready, err, echo, echoWeek = load(state, now, extra)
	if ready == nil then
		return denied(err or ERRORS.state, echo, echoWeek)
	end
	if type(query) ~= "table" or not stringKeyed(query) then
		return denied(ERRORS.query, ready.state, ready.weekKey)
	end
	if skipField(query) then
		return denied(ERRORS.skip, ready.state, ready.weekKey)
	end
	local practice, flagError = readFlags(query)
	if practice == nil then
		return denied(flagError or ERRORS.practice, ready.state, ready.weekKey)
	end
	if practice then
		return practiceResult(ready, nil)
	end
	local bossId, difficulty, kind, pairError = readPair(query, ready.idCap)
	if bossId == nil or difficulty == nil or kind == nil then
		return denied(pairError or ERRORS.difficulty, ready.state, ready.weekKey)
	end
	if kind == REASONS.fracture then
		return fractureResult(ready, bossId, difficulty, nil, ready.pruned)
	end
	local held = lockHeld(weekRow(ready.state, ready.weekKey), pairKey(bossId, difficulty))
	return lootResult(ready, bossId, difficulty, nil, ready.pruned, not held, held)
end

function RaidLockout.claim(state: any, claim: any, now: any, extra: any): Result
	local ready, err, echo, echoWeek = load(state, now, extra)
	if ready == nil then
		return denied(err or ERRORS.state, echo, echoWeek)
	end
	if type(claim) ~= "table" or not stringKeyed(claim) then
		return denied(ERRORS.claim, ready.state, ready.weekKey)
	end
	if skipField(claim) then
		return denied(ERRORS.skip, ready.state, ready.weekKey)
	end
	local claimId, idError = parseClaimId(claim.claimId, ready.idCap)
	if claimId == nil then
		return denied(idError or ERRORS.claimId, ready.state, ready.weekKey)
	end
	if claimHeld(ready.state, claimId) then
		return duplicateResult(ready, claimId)
	end
	local practice, flagError = readFlags(claim)
	if practice == nil then
		return denied(flagError or ERRORS.practice, ready.state, ready.weekKey)
	end
	if practice then
		return practiceResult(ready, claimId)
	end
	local bossId, difficulty, kind, pairError = readPair(claim, ready.idCap)
	if bossId == nil or difficulty == nil or kind == nil then
		return denied(pairError or ERRORS.difficulty, ready.state, ready.weekKey)
	end
	if not hasRoom(ready.state, ready.weekKey, ready.maxClaims) then
		return denied(ERRORS.full, ready.state, ready.weekKey)
	end
	local row = ensureRow(ready.state, ready.weekKey)
	table.insert(row.claims, claimId)
	if kind == REASONS.fracture then
		return fractureResult(ready, bossId, difficulty, claimId, true)
	end
	local lockId = pairKey(bossId, difficulty)
	if lockHeld(row, lockId) then
		return lootResult(ready, bossId, difficulty, claimId, true, false, true)
	end
	table.insert(row.locks, lockId)
	return lootResult(ready, bossId, difficulty, claimId, true, true, true)
end

return RaidLockout
