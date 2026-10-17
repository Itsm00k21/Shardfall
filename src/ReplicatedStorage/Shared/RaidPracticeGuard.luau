--!strict

--[[
	Practice Grove input guard.

	The server calls this before the practice rules. Remote args are
	untrusted. Every call returns ok, value, err. On success err is nil
	and value is set. On failure value is nil and err is a string from
	ERRORS. A bad arg returns that failure. It does not throw. nil, NaN,
	a huge string, a table, and a wrong type all take the failure path.

	Wing numbers are indexes into Raids.WINGS. Today that is 1 twins,
	2 sapwell, 3 galecrown, 4 awakened. An index that is not a row in
	that array is refused. This module does not clamp a bad wing to 1.

	Raids.luau has no per-boss mechanic list. The caller passes an
	allowlist. CONFIG.mechanicCap is how many distinct mechanic ids one
	session may hold. CONFIG.maxDamage is the most damage one call may
	carry. A hit whose stored switch is false is refused.

	This module reads Raids.WINGS and nothing else from that module.
	It does not load the practice rules module. It does not write the
	tables it is given. No services, remotes, saved data, MemoryStore,
	RNG, or clock. Nothing here costs Robux.
]]

local Raids = require("./Raids")

local RaidPracticeGuard = {}

RaidPracticeGuard.CONFIG = table.freeze({
	-- Same phase counts as the practice rules. 4 only on shardbreaker.
	phases = 3,
	shardbreakerPhases = 4,
	-- Distinct mechanic ids one session may hold. Placeholder until Raids
	-- freezes a per-boss mechanic list.
	mechanicCap = 12,
	-- One call's damage. 0 is allowed. Above this is refused.
	maxDamage = 100000,
	-- Raw remote text longer than this is refused before it is stored.
	maxIdLength = 64,
	-- How many allowlist entries one call will read. A longer list is refused.
	allowCap = 64,
	-- Wing indexes above this are refused without reading WINGS.
	maxWing = 32,
})

RaidPracticeGuard.BOSSES = table.freeze({
	twins = true,
	sapwell = true,
	galecrown = true,
	awakened = true,
})

-- Fracture and guided are not difficulties here.
RaidPracticeGuard.DIFFICULTIES = table.freeze({
	story = true,
	normal = true,
	hard = true,
	shardbreaker = true,
})

RaidPracticeGuard.ERRORS = table.freeze({
	wing = "That wing has no grove.",
	boss = "That boss has no grove.",
	difficulty = "That difficulty has no grove.",
	phase = "That phase is not in this grove.",
	mechanic = "That mechanic is unusable.",
	allow = "That mechanic list is unusable.",
	catalog = "That mechanic is not on this boss.",
	cap = "That grove is holding too many mechanics.",
	off = "That mechanic is turned off.",
	state = "That practice record is unusable.",
	enabled = "That mechanic switch is unusable.",
	damage = "That damage amount is unusable.",
	ceiling = "That damage amount is too high.",
	disagree = "Those fields disagree.",
})

export type Opening = {
	bossId: string,
	difficulty: string,
	phase: number,
}

export type Switch = {
	mechanicId: string,
	enabled: boolean,
}

type Flags = { [string]: boolean }

type Inspected = {
	bossId: string?,
	sawBoss: boolean,
	mechanics: Flags,
	hits: Flags,
}

local CONFIG = RaidPracticeGuard.CONFIG
local BOSSES = RaidPracticeGuard.BOSSES
local DIFFICULTIES = RaidPracticeGuard.DIFFICULTIES
local ERRORS = RaidPracticeGuard.ERRORS

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

local function wholeBetween(value: any, minimum: number, maximum: number): number?
	local number = finite(value)
	if number == nil then
		return nil
	end
	if number < minimum or number > maximum or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function requiredBoss(value: any): (string?, string?)
	if type(value) ~= "string" then
		return nil, ERRORS.boss
	end
	if #value > CONFIG.maxIdLength then
		return nil, ERRORS.boss
	end
	local name = string.lower(trim(value))
	if BOSSES[name] ~= true then
		return nil, ERRORS.boss
	end
	return name, nil
end

local function optionalBoss(value: any): (string?, boolean, string?)
	if value == nil then
		return nil, false, nil
	end
	local name, err = requiredBoss(value)
	if name == nil then
		return nil, true, err or ERRORS.boss
	end
	return name, true, nil
end

local function bossesFromState(state: { [string]: any }): (string?, boolean, string?)
	local first, sawFirst, firstErr = optionalBoss(state.bossId)
	if firstErr ~= nil then
		return nil, true, firstErr
	end
	local second, sawSecond, secondErr = optionalBoss(state.boss)
	if secondErr ~= nil then
		return nil, true, secondErr
	end
	if sawFirst and sawSecond and first ~= second then
		return nil, true, ERRORS.disagree
	end
	if first ~= nil then
		return first, true, nil
	end
	if second ~= nil then
		return second, true, nil
	end
	return nil, false, nil
end

local function storedId(key: string): boolean
	if #key == 0 or #key > CONFIG.maxIdLength then
		return false
	end
	if trim(key) ~= key then
		return false
	end
	return true
end

local function clientId(value: any): (string?, string?)
	if type(value) ~= "string" then
		return nil, ERRORS.mechanic
	end
	if #value > CONFIG.maxIdLength then
		return nil, ERRORS.mechanic
	end
	local name = trim(value)
	if name == "" or #name > CONFIG.maxIdLength then
		return nil, ERRORS.mechanic
	end
	return name, nil
end

local function readFlags(value: any): (Flags?, string?)
	if value == nil then
		return {}, nil
	end
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local copy: Flags = {}
	local count = 0
	for key, flag in pairs(value) do
		count += 1
		if count > CONFIG.mechanicCap then
			return nil, ERRORS.state
		end
		if type(key) ~= "string" or not storedId(key) then
			return nil, ERRORS.state
		end
		if type(flag) ~= "boolean" then
			return nil, ERRORS.state
		end
		copy[key] = flag
	end
	return copy, nil
end

local function readHits(value: any): (Flags?, string?)
	if value == nil then
		return {}, nil
	end
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local copy: Flags = {}
	local count = 0
	for key, hits in pairs(value) do
		count += 1
		if count > CONFIG.mechanicCap then
			return nil, ERRORS.state
		end
		if type(key) ~= "string" or not storedId(key) then
			return nil, ERRORS.state
		end
		local number = finite(hits)
		if number == nil or number < 0 or number ~= math.floor(number) then
			return nil, ERRORS.state
		end
		copy[key] = true
	end
	return copy, nil
end

local function inspect(state: any): (Inspected?, string?)
	if state == nil then
		return {
			bossId = nil,
			sawBoss = false,
			mechanics = {},
			hits = {},
		}, nil
	end
	if type(state) ~= "table" then
		return nil, ERRORS.state
	end
	local bossId, sawBoss, bossErr = bossesFromState(state)
	if bossErr ~= nil then
		return nil, bossErr
	end
	local mechanics, mechanicErr = readFlags(state.mechanics)
	if mechanics == nil then
		return nil, mechanicErr or ERRORS.state
	end
	local hits, hitErr = readHits(state.hits)
	if hits == nil then
		return nil, hitErr or ERRORS.state
	end
	return {
		bossId = bossId,
		sawBoss = sawBoss,
		mechanics = mechanics,
		hits = hits,
	}, nil
end

local function addName(allowed: Flags, accepted: number, name: string): (number?, string?)
	if name == "" or #name > CONFIG.maxIdLength then
		return nil, ERRORS.allow
	end
	if allowed[name] == true then
		return accepted, nil
	end
	if accepted >= CONFIG.allowCap then
		return nil, ERRORS.allow
	end
	allowed[name] = true
	return accepted + 1, nil
end

-- Array strings are trimmed. A set key that is true is trimmed too.
-- A string key whose value is a table is a boss bucket, and only when
-- that key is a boss id. Any other shape fails the whole list.
local function readList(list: any): (Flags?, string?)
	if type(list) ~= "table" then
		return nil, ERRORS.allow
	end
	local allowed: Flags = {}
	local accepted = 0
	local walked = 0
	for key, value in pairs(list) do
		walked += 1
		if walked > CONFIG.allowCap then
			return nil, ERRORS.allow
		end
		local absent = type(key) == "string" and value == false
		if not absent then
			if type(key) == "number" then
				local finiteKey = finite(key)
				local badKey = finiteKey == nil
					or finiteKey < 1
					or finiteKey > CONFIG.allowCap
					or finiteKey ~= math.floor(finiteKey)
				if badKey or type(value) ~= "string" or #value > CONFIG.maxIdLength then
					return nil, ERRORS.allow
				end
				local nextCount, err = addName(allowed, accepted, trim(value))
				if nextCount == nil then
					return nil, err or ERRORS.allow
				end
				accepted = nextCount
			elseif type(key) == "string" and value == true then
				if #key > CONFIG.maxIdLength then
					return nil, ERRORS.allow
				end
				local nextCount, err = addName(allowed, accepted, trim(key))
				if nextCount == nil then
					return nil, err or ERRORS.allow
				end
				accepted = nextCount
			elseif type(key) == "string" and type(value) == "table" then
				if #key > CONFIG.maxIdLength then
					return nil, ERRORS.allow
				end
				local bucket = string.lower(trim(key))
				if bucket ~= key or BOSSES[bucket] ~= true then
					return nil, ERRORS.allow
				end
			else
				return nil, ERRORS.allow
			end
		end
	end
	return allowed, nil
end

-- A table at allowlist[bossId] is that boss's list. Otherwise the
-- whole table is one flat list for the boss the caller already chose.
local function allowFor(bossId: string, allowlist: any): (Flags?, string?)
	if type(allowlist) ~= "table" then
		return nil, ERRORS.allow
	end
	local keyed = allowlist[bossId]
	if type(keyed) == "table" then
		return readList(keyed)
	end
	return readList(allowlist)
end

local function union(mechanics: Flags, hits: Flags): (number?, Flags?, string?)
	local seen: Flags = {}
	local count = 0
	local function add(key: string): string?
		if seen[key] == true then
			return nil
		end
		count += 1
		if count > CONFIG.mechanicCap then
			return ERRORS.state
		end
		seen[key] = true
		return nil
	end
	for key in pairs(mechanics) do
		local err = add(key)
		if err ~= nil then
			return nil, nil, err
		end
	end
	for key in pairs(hits) do
		local err = add(key)
		if err ~= nil then
			return nil, nil, err
		end
	end
	return count, seen, nil
end

local function accept(
	bossId: string,
	mechanicId: any,
	allowlist: any,
	record: Inspected
): (string?, string?)
	local allowed, allowErr = allowFor(bossId, allowlist)
	if allowed == nil then
		return nil, allowErr or ERRORS.allow
	end
	local name, nameErr = clientId(mechanicId)
	if name == nil then
		return nil, nameErr or ERRORS.mechanic
	end
	if allowed[name] ~= true then
		return nil, ERRORS.catalog
	end
	local count, seen, capErr = union(record.mechanics, record.hits)
	if seen == nil or count == nil then
		return nil, capErr or ERRORS.state
	end
	if seen[name] ~= true and count >= CONFIG.mechanicCap then
		return nil, ERRORS.cap
	end
	return name, nil
end

-- The check order is boss, mechanic id, state, allowlist, then the cap.
local function screen(bossId: any, mechanicId: any, allowlist: any, state: any): (string?, string?)
	local boss, bossErr = requiredBoss(bossId)
	if boss == nil then
		return nil, bossErr or ERRORS.boss
	end
	local name, nameErr = clientId(mechanicId)
	if name == nil then
		return nil, nameErr or ERRORS.mechanic
	end
	local record, stateErr = inspect(state)
	if record == nil then
		return nil, stateErr or ERRORS.state
	end
	if record.sawBoss and record.bossId ~= boss then
		return nil, ERRORS.disagree
	end
	local accepted, acceptErr = accept(boss, name, allowlist, record)
	if accepted == nil then
		return nil, acceptErr or ERRORS.mechanic
	end
	return accepted, nil
end

function RaidPracticeGuard.boss(wing: any): (boolean, string?, string?)
	local index = wholeBetween(wing, 1, CONFIG.maxWing)
	if index == nil then
		return false, nil, ERRORS.wing
	end
	local wings = Raids.WINGS
	if type(wings) ~= "table" then
		return false, nil, ERRORS.wing
	end
	local row = wings[index]
	if type(row) ~= "table" then
		return false, nil, ERRORS.wing
	end
	local id = row.id
	if type(id) ~= "string" or #id > CONFIG.maxIdLength then
		return false, nil, ERRORS.boss
	end
	local name = string.lower(trim(id))
	if name == "" or BOSSES[name] ~= true then
		return false, nil, ERRORS.boss
	end
	return true, name, nil
end

function RaidPracticeGuard.difficulty(value: any): (boolean, string?, string?)
	if type(value) ~= "string" then
		return false, nil, ERRORS.difficulty
	end
	if #value > CONFIG.maxIdLength then
		return false, nil, ERRORS.difficulty
	end
	local name = string.lower(trim(value))
	if DIFFICULTIES[name] ~= true then
		return false, nil, ERRORS.difficulty
	end
	return true, name, nil
end

function RaidPracticeGuard.phase(difficulty: any, phase: any): (boolean, number?, string?)
	local ok, name, diffErr = RaidPracticeGuard.difficulty(difficulty)
	if ok ~= true or name == nil then
		return false, nil, diffErr or ERRORS.difficulty
	end
	local limit = CONFIG.phases
	if name == "shardbreaker" then
		limit = CONFIG.shardbreakerPhases
	end
	local step = wholeBetween(phase, 1, limit)
	if step == nil then
		return false, nil, ERRORS.phase
	end
	return true, step, nil
end

function RaidPracticeGuard.start(
	wing: any,
	difficulty: any,
	phase: any
): (boolean, Opening?, string?)
	local okBoss, bossId, bossErr = RaidPracticeGuard.boss(wing)
	if okBoss ~= true or bossId == nil then
		return false, nil, bossErr or ERRORS.wing
	end
	local okDiff, name, diffErr = RaidPracticeGuard.difficulty(difficulty)
	if okDiff ~= true or name == nil then
		return false, nil, diffErr or ERRORS.difficulty
	end
	local okPhase, step, phaseErr = RaidPracticeGuard.phase(name, phase)
	if okPhase ~= true or step == nil then
		return false, nil, phaseErr or ERRORS.phase
	end
	return true, {
		bossId = bossId,
		difficulty = name,
		phase = step,
	}, nil
end

function RaidPracticeGuard.mechanic(
	bossId: any,
	mechanicId: any,
	allowlist: any,
	state: any
): (boolean, string?, string?)
	local name, err = screen(bossId, mechanicId, allowlist, state)
	if name == nil then
		return false, nil, err or ERRORS.mechanic
	end
	return true, name, nil
end

function RaidPracticeGuard.toggle(
	bossId: any,
	mechanicId: any,
	enabled: any,
	allowlist: any,
	state: any
): (boolean, Switch?, string?)
	local boss, bossErr = requiredBoss(bossId)
	if boss == nil then
		return false, nil, bossErr or ERRORS.boss
	end
	local named, nameErr = clientId(mechanicId)
	if named == nil then
		return false, nil, nameErr or ERRORS.mechanic
	end
	if type(enabled) ~= "boolean" then
		return false, nil, ERRORS.enabled
	end
	local name, err = screen(boss, named, allowlist, state)
	if name == nil then
		return false, nil, err or ERRORS.mechanic
	end
	return true, {
		mechanicId = name,
		enabled = enabled,
	}, nil
end

function RaidPracticeGuard.hit(
	state: any,
	mechanicId: any,
	allowlist: any
): (boolean, string?, string?)
	local named, nameErr = clientId(mechanicId)
	if named == nil then
		return false, nil, nameErr or ERRORS.mechanic
	end
	local record, stateErr = inspect(state)
	if record == nil then
		return false, nil, stateErr or ERRORS.state
	end
	if record.sawBoss ~= true or record.bossId == nil then
		return false, nil, ERRORS.state
	end
	local name, acceptErr = accept(record.bossId, named, allowlist, record)
	if name == nil then
		return false, nil, acceptErr or ERRORS.mechanic
	end
	if record.mechanics[name] == false then
		return false, nil, ERRORS.off
	end
	return true, name, nil
end

function RaidPracticeGuard.damage(amount: any): (boolean, number?, string?)
	local number = finite(amount)
	if number == nil or number < 0 then
		return false, nil, ERRORS.damage
	end
	if number > CONFIG.maxDamage then
		return false, nil, ERRORS.ceiling
	end
	return true, number, nil
end

return RaidPracticeGuard
