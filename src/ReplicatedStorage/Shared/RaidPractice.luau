--!strict

--[[
	Practice Grove. A free, lootless sandbox for one unlocked boss.

	The server passes plain tables. This module does not read players,
	grant loot, or touch saved data, MemoryStore, and remotes. It does
	not load Raids, RaidService, DungeonService, RaidEcho, RaidMarks,
	RaidLuck, RaidLeaderboard, or RaidRecap. It has no RNG and it does
	not read the clock. Thresholds live in CONFIG. Nothing here costs
	Robux. Cost is 0.

	Boss ids are twins, sapwell, galecrown, and awakened. Difficulties
	are story, normal, hard, and shardbreaker. Fracture and guided are
	not difficulties. Every boss has 3 phases, and Shardbreaker has 4.

	fresh, jump, setSlow, toggle, note, and rewards return a new table
	and do not write the input. scale returns 0.75 or 1. Store state
	only when ok == true. A failure returns a copy. Phase jumps and
	slow do not reset the record. Dummies are a flag, not a boss.
	A practice session is not a clear, a lockout, a Marks payout, or
	a leaderboard row.
]]

local RaidPractice = {}

RaidPractice.CONFIG = table.freeze({
	-- Guild raid prep: slow time to 0.75x. Off is always 1.
	slowScale = 0.75,
	-- Every boss has 3 phases. Shardbreaker has 4.
	phases = 3,
	shardbreakerPhases = 4,
})

RaidPractice.BOSSES = table.freeze({
	twins = true,
	sapwell = true,
	galecrown = true,
	awakened = true,
})

-- Fracture and guided are not difficulties in this module.
RaidPractice.DIFFICULTIES = table.freeze({
	story = true,
	normal = true,
	hard = true,
	shardbreaker = true,
})

RaidPractice.ERRORS = table.freeze({
	state = "That practice record is unusable.",
	ctx = "That practice start is unusable.",
	boss = "That boss has no grove.",
	difficulty = "That difficulty has no grove.",
	unlocked = "That boss is still locked.",
	unlock = "That unlock flag is unusable.",
	dummies = "That dummy flag is unusable.",
	phase = "That phase is not in this grove.",
	slow = "That slow flag is unusable.",
	mechanic = "That mechanic is unusable.",
	enabled = "That mechanic switch is unusable.",
	event = "That practice note is unusable.",
	kind = "That note is not damage, a death, or a hit.",
	damage = "That damage amount is unusable.",
	death = "That death note is unusable.",
	hit = "That mechanic hit is unusable.",
	disagree = "Those fields disagree.",
})

export type State = {
	bossId: string,
	difficulty: string,
	phase: number,
	slow: boolean,
	dummies: boolean,
	mechanics: { [string]: boolean },
	damage: number,
	deaths: number,
	hits: { [string]: number },
}

export type Started = {
	ok: boolean,
	state: State,
	cost: number,
	error: string?,
}

export type Jumped = {
	ok: boolean,
	state: State,
	phase: number,
	error: string?,
}

export type Slowed = {
	ok: boolean,
	state: State,
	slow: boolean,
	scale: number,
	error: string?,
}

export type Toggled = {
	ok: boolean,
	state: State,
	mechanicId: string,
	enabled: boolean,
	error: string?,
}

export type Noted = {
	ok: boolean,
	state: State,
	kind: string,
	damage: number,
	deaths: number,
	mechanicId: string,
	hits: number,
	error: string?,
}

export type Loot = {
	ok: boolean,
	cost: number,
	clear: boolean,
	lockout: boolean,
	leaderboard: boolean,
	gear: { any },
	marks: number,
	dust: number,
	materials: { [string]: number },
	pets: { any },
	titles: { any },
	cosmetics: { any },
	error: string?,
}

local KINDS: { [string]: string } = {
	damage = "damage",
	death = "death",
	dead = "death",
	hit = "hit",
	hits = "hit",
	mechanic = "hit",
}

local CONFIG = RaidPractice.CONFIG
local OFF_SCALE = 1

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

local function whole(value: any, minimum: number): number?
	local number = finite(value)
	if number == nil or number < minimum or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function slowNumber(): number
	local number = finite(CONFIG.slowScale)
	if number == nil or number <= 0 then
		return 0.75
	end
	return number
end

local function phaseLimit(difficulty: string): number
	local raw = CONFIG.phases
	local fallback = 3
	if difficulty == "shardbreaker" then
		raw = CONFIG.shardbreakerPhases
		fallback = 4
	end
	local number = whole(raw, 1)
	if number == nil then
		return fallback
	end
	return number
end

local function shell(): State
	return {
		bossId = "",
		difficulty = "",
		phase = 1,
		slow = false,
		dummies = true,
		mechanics = {},
		damage = 0,
		deaths = 0,
		hits = {},
	}
end

local function pack(state: State): State
	return {
		bossId = state.bossId,
		difficulty = state.difficulty,
		phase = state.phase,
		slow = state.slow,
		dummies = state.dummies,
		mechanics = table.clone(state.mechanics),
		damage = state.damage,
		deaths = state.deaths,
		hits = table.clone(state.hits),
	}
end

local function knownToken(
	value: any,
	allowed: { [string]: boolean },
	message: string
): (string?, boolean, string?)
	if value == nil then
		return nil, false, nil
	end
	local name = token(value)
	if name == nil or allowed[name] ~= true then
		return nil, true, message
	end
	return name, true, nil
end

local function oneKnown(
	primary: any,
	alias: any,
	allowed: { [string]: boolean },
	message: string
): (string?, string?)
	local first, sawFirst, firstErr = knownToken(primary, allowed, message)
	if firstErr ~= nil then
		return nil, firstErr
	end
	local second, sawSecond, secondErr = knownToken(alias, allowed, message)
	if secondErr ~= nil then
		return nil, secondErr
	end
	if sawFirst and sawSecond and first ~= second then
		return nil, RaidPractice.ERRORS.disagree
	end
	if first ~= nil then
		return first, nil
	end
	if second ~= nil then
		return second, nil
	end
	return nil, message
end

local function readBoss(primary: any, alias: any): (string?, string?)
	return oneKnown(primary, alias, RaidPractice.BOSSES, RaidPractice.ERRORS.boss)
end

local function readDifficulty(value: any): (string?, string?)
	local name, _, diffErr =
		knownToken(value, RaidPractice.DIFFICULTIES, RaidPractice.ERRORS.difficulty)
	if diffErr ~= nil or name == nil then
		return nil, diffErr or RaidPractice.ERRORS.difficulty
	end
	return name, nil
end

local function readFlags(value: any): ({ [string]: boolean }?, string?)
	if value == nil then
		return {}, nil
	end
	if type(value) ~= "table" then
		return nil, RaidPractice.ERRORS.state
	end
	local copy: { [string]: boolean } = {}
	for key, flag in pairs(value) do
		if type(key) ~= "string" or trim(key) ~= key or key == "" then
			return nil, RaidPractice.ERRORS.state
		end
		if type(flag) ~= "boolean" then
			return nil, RaidPractice.ERRORS.state
		end
		copy[key] = flag
	end
	return copy, nil
end

local function readHitMap(value: any): ({ [string]: number }?, string?)
	if value == nil then
		return {}, nil
	end
	if type(value) ~= "table" then
		return nil, RaidPractice.ERRORS.state
	end
	local copy: { [string]: number } = {}
	for key, count in pairs(value) do
		if type(key) ~= "string" or trim(key) ~= key or key == "" then
			return nil, RaidPractice.ERRORS.state
		end
		local hits = whole(count, 0)
		if hits == nil then
			return nil, RaidPractice.ERRORS.state
		end
		copy[key] = hits
	end
	return copy, nil
end

local function readState(state: any): (State?, string?)
	if type(state) ~= "table" then
		return nil, RaidPractice.ERRORS.state
	end
	local bossId, bossErr = readBoss(state.bossId, state.boss)
	if bossId == nil then
		return nil, bossErr or RaidPractice.ERRORS.state
	end
	local difficulty, diffErr = readDifficulty(state.difficulty)
	if difficulty == nil then
		return nil, diffErr or RaidPractice.ERRORS.state
	end
	if state.phase == nil then
		return nil, RaidPractice.ERRORS.state
	end
	local phase = whole(state.phase, 1)
	if phase == nil or phase > phaseLimit(difficulty) then
		return nil, RaidPractice.ERRORS.state
	end
	local slow = state.slow
	if slow == nil then
		slow = false
	end
	if type(slow) ~= "boolean" then
		return nil, RaidPractice.ERRORS.state
	end
	local dummies = state.dummies
	if dummies == nil then
		dummies = true
	end
	if type(dummies) ~= "boolean" then
		return nil, RaidPractice.ERRORS.state
	end
	local mechanics, mechanicErr = readFlags(state.mechanics)
	if mechanics == nil then
		return nil, mechanicErr or RaidPractice.ERRORS.state
	end
	local damage = state.damage
	if damage == nil then
		damage = 0
	end
	local dealt = finite(damage)
	if dealt == nil or dealt < 0 then
		return nil, RaidPractice.ERRORS.state
	end
	local deaths = state.deaths
	if deaths == nil then
		deaths = 0
	end
	local died = whole(deaths, 0)
	if died == nil then
		return nil, RaidPractice.ERRORS.state
	end
	local hits, hitErr = readHitMap(state.hits)
	if hits == nil then
		return nil, hitErr or RaidPractice.ERRORS.state
	end
	return {
		bossId = bossId,
		difficulty = difficulty,
		phase = phase,
		slow = slow,
		dummies = dummies,
		mechanics = mechanics,
		damage = dealt,
		deaths = died,
		hits = hits,
	},
		nil
end

local function failStart(message: string): Started
	return {
		ok = false,
		state = shell(),
		cost = 0,
		error = message,
	}
end

local function failJump(message: string, state: State?): Jumped
	local copy = if state == nil then shell() else pack(state)
	return {
		ok = false,
		state = copy,
		phase = copy.phase,
		error = message,
	}
end

local function failSlow(message: string, state: State?): Slowed
	local copy = if state == nil then shell() else pack(state)
	return {
		ok = false,
		state = copy,
		slow = copy.slow,
		scale = if copy.slow then slowNumber() else OFF_SCALE,
		error = message,
	}
end

local function failToggle(message: string, state: State?): Toggled
	local copy = if state == nil then shell() else pack(state)
	return {
		ok = false,
		state = copy,
		mechanicId = "",
		enabled = false,
		error = message,
	}
end

local function failNote(message: string, state: State?): Noted
	local copy = if state == nil then shell() else pack(state)
	return {
		ok = false,
		state = copy,
		kind = "",
		damage = copy.damage,
		deaths = copy.deaths,
		mechanicId = "",
		hits = 0,
		error = message,
	}
end

local function emptyLoot(ok: boolean, message: string?): Loot
	return {
		ok = ok,
		cost = 0,
		clear = false,
		lockout = false,
		leaderboard = false,
		gear = {},
		marks = 0,
		dust = 0,
		materials = {},
		pets = {},
		titles = {},
		cosmetics = {},
		error = message,
	}
end

local function readUnlocked(value: any): (boolean?, string?)
	if type(value) ~= "boolean" then
		return nil, RaidPractice.ERRORS.unlock
	end
	if value ~= true then
		return nil, RaidPractice.ERRORS.unlocked
	end
	return true, nil
end

local function readDummies(value: any): (boolean?, string?)
	if value == nil then
		return true, nil
	end
	if type(value) ~= "boolean" then
		return nil, RaidPractice.ERRORS.dummies
	end
	return value, nil
end

local function mechanicKey(value: any): (string?, string?)
	if type(value) ~= "string" then
		return nil, RaidPractice.ERRORS.mechanic
	end
	local trimmed = trim(value)
	if trimmed == "" then
		return nil, RaidPractice.ERRORS.mechanic
	end
	return trimmed, nil
end

local function takeMechanic(found: string?, saw: boolean, value: any): (string?, boolean, string?)
	if value == nil then
		return found, saw, nil
	end
	local key, keyErr = mechanicKey(value)
	if key == nil then
		return nil, true, keyErr or RaidPractice.ERRORS.mechanic
	end
	if found ~= nil and found ~= key then
		return nil, true, RaidPractice.ERRORS.disagree
	end
	return key, true, nil
end

local function oneMechanic(primary: any, alias: any, extra: any): (string?, boolean, string?)
	local found: string? = nil
	local saw = false
	local err: string? = nil
	found, saw, err = takeMechanic(found, saw, primary)
	if err ~= nil then
		return nil, true, err
	end
	found, saw, err = takeMechanic(found, saw, alias)
	if err ~= nil then
		return nil, true, err
	end
	found, saw, err = takeMechanic(found, saw, extra)
	if err ~= nil then
		return nil, true, err
	end
	return found, saw, nil
end

local function takeAmount(found: number?, saw: boolean, value: any): (number?, boolean, string?)
	if value == nil then
		return found, saw, nil
	end
	local number = finite(value)
	if number == nil or number < 0 then
		return nil, true, RaidPractice.ERRORS.damage
	end
	if found ~= nil and found ~= number then
		return nil, true, RaidPractice.ERRORS.disagree
	end
	return number, true, nil
end

local function oneAmount(primary: any, alias: any): (number?, boolean, string?)
	local found: number? = nil
	local saw = false
	local err: string? = nil
	found, saw, err = takeAmount(found, saw, primary)
	if err ~= nil then
		return nil, true, err
	end
	found, saw, err = takeAmount(found, saw, alias)
	if err ~= nil then
		return nil, true, err
	end
	return found, saw, nil
end

local function mappedKind(value: any): (string?, boolean, string?)
	if value == nil then
		return nil, false, nil
	end
	local name = token(value)
	if name == nil then
		return nil, true, RaidPractice.ERRORS.kind
	end
	local mapped = KINDS[name]
	if mapped == nil then
		return nil, true, RaidPractice.ERRORS.kind
	end
	return mapped, true, nil
end

local function oneKind(primary: any, alias: any): (string?, string?)
	local first, sawFirst, firstErr = mappedKind(primary)
	if firstErr ~= nil then
		return nil, firstErr
	end
	local second, sawSecond, secondErr = mappedKind(alias)
	if secondErr ~= nil then
		return nil, secondErr
	end
	if sawFirst and sawSecond and first ~= second then
		return nil, RaidPractice.ERRORS.disagree
	end
	if not sawFirst and not sawSecond then
		return nil, nil
	end
	if first ~= nil then
		return first, nil
	end
	return second, nil
end

local function readDeath(value: any): (boolean?, boolean, string?)
	if value == nil then
		return nil, false, nil
	end
	if type(value) ~= "boolean" then
		return nil, true, RaidPractice.ERRORS.death
	end
	return value, true, nil
end

local function addDamage(current: number, extra: number): number?
	local total = current + extra
	if total ~= total or total == math.huge or total == -math.huge then
		return nil
	end
	return total
end

local function addOne(current: number): number?
	local total = current + 1
	if total ~= total or total == math.huge or total <= current then
		return nil
	end
	return total
end

local function signalCount(damageSeen: boolean, deathSeen: boolean, hitSeen: boolean): number
	local count = 0
	if damageSeen then
		count += 1
	end
	if deathSeen then
		count += 1
	end
	if hitSeen then
		count += 1
	end
	return count
end

-- kind is damage, death, or hit. The amount is damage only.
-- mechanicId is set for a hit. death true means one death.
local function readEvent(event: any): (string?, number?, string?, string?)
	if type(event) ~= "table" then
		return nil, nil, nil, RaidPractice.ERRORS.event
	end
	local kind, kindErr = oneKind(event.kind, event.note)
	if kindErr ~= nil then
		return nil, nil, nil, kindErr
	end
	local amount, damageSeen, damageErr = oneAmount(event.damage, event.amount)
	if damageErr ~= nil then
		return nil, nil, nil, damageErr
	end
	local death, deathSeen, deathErr = readDeath(event.death)
	if deathErr ~= nil then
		return nil, nil, nil, deathErr
	end
	local mechanicId, hitSeen, hitErr = oneMechanic(event.mechanicId, event.mechanic, event.hit)
	if hitErr ~= nil then
		return nil, nil, nil, hitErr
	end
	if kind == nil then
		if deathSeen and death ~= true then
			return nil, nil, nil, RaidPractice.ERRORS.death
		end
		local signals = signalCount(damageSeen, death == true, hitSeen)
		if signals == 0 then
			return nil, nil, nil, RaidPractice.ERRORS.event
		end
		if signals ~= 1 then
			return nil, nil, nil, RaidPractice.ERRORS.disagree
		end
		if damageSeen then
			return "damage", amount, nil, nil
		end
		if death == true then
			return "death", nil, nil, nil
		end
		return "hit", nil, mechanicId, nil
	end
	if kind == "damage" then
		if deathSeen or hitSeen then
			return nil, nil, nil, RaidPractice.ERRORS.disagree
		end
		if not damageSeen or amount == nil then
			return nil, nil, nil, RaidPractice.ERRORS.damage
		end
		return "damage", amount, nil, nil
	end
	if kind == "death" then
		if damageSeen or hitSeen or death == false then
			return nil, nil, nil, RaidPractice.ERRORS.disagree
		end
		return "death", nil, nil, nil
	end
	if damageSeen or deathSeen then
		return nil, nil, nil, RaidPractice.ERRORS.disagree
	end
	if mechanicId == nil then
		return nil, nil, nil, RaidPractice.ERRORS.hit
	end
	return "hit", nil, mechanicId, nil
end

function RaidPractice.fresh(ctx: any): Started
	if type(ctx) ~= "table" then
		return failStart(RaidPractice.ERRORS.ctx)
	end
	local bossId, bossErr = readBoss(ctx.bossId, ctx.boss)
	if bossId == nil then
		return failStart(bossErr or RaidPractice.ERRORS.boss)
	end
	local difficulty, diffErr = readDifficulty(ctx.difficulty)
	if difficulty == nil then
		return failStart(diffErr or RaidPractice.ERRORS.difficulty)
	end
	local unlocked, unlockErr = readUnlocked(ctx.unlocked)
	if unlocked ~= true then
		return failStart(unlockErr or RaidPractice.ERRORS.unlocked)
	end
	local dummies, dummyErr = readDummies(ctx.dummies)
	if dummies == nil then
		return failStart(dummyErr or RaidPractice.ERRORS.dummies)
	end
	return {
		ok = true,
		state = {
			bossId = bossId,
			difficulty = difficulty,
			phase = 1,
			slow = false,
			dummies = dummies,
			mechanics = {},
			damage = 0,
			deaths = 0,
			hits = {},
		},
		cost = 0,
		error = nil,
	}
end

function RaidPractice.jump(state: any, phase: any): Jumped
	local parsed, stateErr = readState(state)
	if parsed == nil then
		return failJump(stateErr or RaidPractice.ERRORS.state, nil)
	end
	local step = whole(phase, 1)
	if step == nil or step > phaseLimit(parsed.difficulty) then
		return failJump(RaidPractice.ERRORS.phase, parsed)
	end
	local copy = pack(parsed)
	copy.phase = step
	return {
		ok = true,
		state = copy,
		phase = step,
		error = nil,
	}
end

function RaidPractice.setSlow(state: any, on: any): Slowed
	local parsed, stateErr = readState(state)
	if parsed == nil then
		return failSlow(stateErr or RaidPractice.ERRORS.state, nil)
	end
	if type(on) ~= "boolean" then
		return failSlow(RaidPractice.ERRORS.slow, parsed)
	end
	local copy = pack(parsed)
	copy.slow = on
	local speed = if on then slowNumber() else OFF_SCALE
	return {
		ok = true,
		state = copy,
		slow = on,
		scale = speed,
		error = nil,
	}
end

-- 0.75 when slow is on, otherwise 1. A record that does not parse returns 1.
function RaidPractice.scale(state: any): number
	local parsed, _stateErr = readState(state)
	if parsed == nil or parsed.slow ~= true then
		return OFF_SCALE
	end
	return slowNumber()
end

function RaidPractice.toggle(state: any, mechanicId: any, enabled: any): Toggled
	local parsed, stateErr = readState(state)
	if parsed == nil then
		return failToggle(stateErr or RaidPractice.ERRORS.state, nil)
	end
	local key, keyErr = mechanicKey(mechanicId)
	if key == nil then
		return failToggle(keyErr or RaidPractice.ERRORS.mechanic, parsed)
	end
	if type(enabled) ~= "boolean" then
		return failToggle(RaidPractice.ERRORS.enabled, parsed)
	end
	local copy = pack(parsed)
	copy.mechanics[key] = enabled
	return {
		ok = true,
		state = copy,
		mechanicId = key,
		enabled = enabled,
		error = nil,
	}
end

function RaidPractice.note(state: any, event: any): Noted
	local parsed, stateErr = readState(state)
	if parsed == nil then
		return failNote(stateErr or RaidPractice.ERRORS.state, nil)
	end
	local kind, amount, mechanicId, eventErr = readEvent(event)
	if kind == nil then
		return failNote(eventErr or RaidPractice.ERRORS.event, parsed)
	end
	local copy = pack(parsed)
	local hitCount = 0
	local hitId = mechanicId or ""
	if kind == "damage" then
		local total = addDamage(copy.damage, amount or 0)
		if total == nil then
			return failNote(RaidPractice.ERRORS.damage, parsed)
		end
		copy.damage = total
	elseif kind == "death" then
		local total = addOne(copy.deaths)
		if total == nil then
			return failNote(RaidPractice.ERRORS.death, parsed)
		end
		copy.deaths = total
	else
		local previous = copy.hits[hitId] or 0
		local total = addOne(previous)
		if total == nil then
			return failNote(RaidPractice.ERRORS.hit, parsed)
		end
		copy.hits[hitId] = total
		hitCount = total
	end
	return {
		ok = true,
		state = copy,
		kind = kind,
		damage = copy.damage,
		deaths = copy.deaths,
		mechanicId = hitId,
		hits = hitCount,
		error = nil,
	}
end

function RaidPractice.rewards(state: any): Loot
	local parsed, stateErr = readState(state)
	if parsed == nil then
		return emptyLoot(false, stateErr or RaidPractice.ERRORS.state)
	end
	return emptyLoot(true, nil)
end

return RaidPractice
