--!strict

--[[
	Raid Finder. Role check and group forming for Story and Normal.

	The server passes plain tables and unix seconds. This module does
	not read players, queue MemoryStore, reserve servers, or touch
	DataStores and remotes. It does not require RaidLeaver or RaidConduct.
	Pass a cooldown-until and an idle-kick flag in. Thresholds live in
	CONFIG. Nothing here costs Robux.

	Finder accepts Story and Normal only. Hard and Shardbreaker are
	refused. Guided Raids are not in this module. Flex fills a missing
	tank, then a missing healer, then DPS. A party is 4 to 8 players.
	Boss HP scale follows that count. No healer for healerWaitSeconds
	lets the group start with softer boss damage and a Healing Spring
	flag. A missing tank on Story adds one Warden golem per missing
	tank. Normal does not. A fresh flag marks a first-timer. The fresh
	count is for RaidMarks. A mentor has mentorClears and has opted in.
	An idle vote-kick drops queue priority until the next UTC day.
	Story and Normal do not filter on gear score or clear count.
	A cooldown still in the future cannot queue.
]]

local RaidFinder = {}

local roleTargets = {
	[4] = table.freeze({ tank = 1, healer = 1, dps = 2 }),
	[5] = table.freeze({ tank = 1, healer = 1, dps = 3 }),
	[6] = table.freeze({ tank = 1, healer = 1, dps = 4 }),
	[7] = table.freeze({ tank = 1, healer = 1, dps = 5 }),
	[8] = table.freeze({ tank = 1, healer = 1, dps = 6 }),
}

RaidFinder.CONFIG = table.freeze({
	minParty = 4,
	maxParty = 8,
	healerWaitSeconds = 180,
	bossDamage = 1,
	healerlessDamage = 0.85,
	healingSpring = true,
	mentorClears = 10,
	defaultPriority = 0,
	droppedPriority = -1,
	daySeconds = 86400,
	roleTargets = table.freeze(roleTargets),
	hpScale = table.freeze({
		[4] = 0.5,
		[5] = 0.625,
		[6] = 0.75,
		[7] = 0.875,
		[8] = 1,
	}),
	fillOrder = table.freeze({ "tank", "healer", "dps" }),
})

RaidFinder.ROLES = table.freeze({
	tank = true,
	healer = true,
	dps = true,
	flex = true,
})

RaidFinder.DIFFICULTIES = table.freeze({
	story = true,
	normal = true,
})

RaidFinder.REFUSED = table.freeze({
	hard = true,
	shardbreaker = true,
})

-- Same two strings as RaidConduct.IDLE_REASONS. This module does not require it.
RaidFinder.IDLE_REASONS = table.freeze({
	idle = true,
	afk = true,
})

RaidFinder.WARDEN_ID = "warden_golem"

RaidFinder.ERRORS = table.freeze({
	time = "Raid time is missing.",
	clock = "Raid time moved backwards.",
	difficulty = "Pick Story or Normal.",
	guided = "Hard and Shardbreaker are premade. Guided Raids come later.",
	role = "Pick Tank, Healer, DPS, or Flex.",
	cooling = "Raid Finder is cooling down after too many leaves.",
	cooldown = "That cooldown is unusable.",
	party = "The party is unusable.",
	size = "Raid Finder needs 4 to 8 players.",
	member = "That party member is unusable.",
	duplicate = "That player is already in this party.",
	waiting = "That healer wait is unusable.",
	priority = "That queue priority is unusable.",
	clears = "That clear count is unusable.",
	mentor = "That mentor choice is unusable.",
	fresh = "That Fresh Shard flag is unusable.",
	kick = "That kick flag is unusable.",
})

export type Ticket = {
	difficulty: any,
	role: any,
	cooldownUntil: number?,
	gearScore: number?,
	clearCount: number?,
	clears: number?,
}

export type QueueResult = {
	ok: boolean,
	queued: boolean,
	difficulty: string,
	role: string,
	finderBlocked: boolean,
	remainingSeconds: number,
	gearFiltered: boolean,
	clearFiltered: boolean,
	error: string?,
}

export type Member = {
	userId: number?,
	role: any,
	fresh: boolean?,
	clears: number?,
	mentorOptIn: boolean?,
	priority: number?,
	cooldownUntil: number?,
	gearScore: number?,
	clearCount: number?,
}

export type Proposal = {
	difficulty: any,
	waitingSince: number?,
	members: { Member }?,
}

export type Seat = {
	userId: number?,
	role: string,
	filled: string,
	freshShard: boolean,
	mentor: boolean,
	priority: number,
}

export type Counts = {
	tank: number,
	healer: number,
	dps: number,
}

export type FormResult = {
	ok: boolean,
	mayStart: boolean,
	difficulty: string,
	playerCount: number,
	hpScale: number,
	bossDamageScale: number,
	autoScale: boolean,
	healingSpring: boolean,
	waitedSeconds: number,
	healerTimeout: boolean,
	wardenCount: number,
	freshCount: number,
	mentorCount: number,
	targets: Counts,
	filled: Counts,
	seats: { Seat },
	error: string?,
}

export type PriorityRecord = {
	priority: number?,
	priorityDay: number?,
}

export type PriorityResult = {
	ok: boolean,
	priority: number,
	priorityDay: number,
	dropped: boolean,
	error: string?,
}

export type MentorResult = {
	ok: boolean,
	eligible: boolean,
	clears: number,
	optedIn: boolean,
	error: string?,
}

export type FilterResult = {
	ok: boolean,
	difficulty: string,
	gearScore: boolean,
	clearCount: boolean,
	error: string?,
}

type Parsed = {
	userId: number?,
	role: string,
	fresh: boolean,
	clears: number,
	optedIn: boolean,
	priority: number,
}

type StoredPriority = {
	priority: number,
	priorityDay: number,
}

local CONFIG = RaidFinder.CONFIG
local ERRORS = RaidFinder.ERRORS

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

function RaidFinder.dayNumber(now: number): number?
	local at = finite(now)
	if at == nil or at < 0 then
		return nil
	end
	local span = CONFIG.daySeconds
	if type(span) ~= "number" or span <= 0 then
		return nil
	end
	return math.floor(at / span)
end

local function classifyDifficulty(value: any): (string?, string?)
	local name = token(value)
	if name == nil then
		return nil, ERRORS.difficulty
	end
	if RaidFinder.DIFFICULTIES[name] == true then
		return name, nil
	end
	if RaidFinder.REFUSED[name] == true then
		return nil, ERRORS.guided
	end
	return nil, ERRORS.difficulty
end

local function classifyRole(value: any): string?
	local name = token(value)
	if name == nil then
		return nil
	end
	if RaidFinder.ROLES[name] == true then
		return name
	end
	return nil
end

-- Nil becomes 0. A negative becomes 0. Non-finite is corrupt.
local function storedDeadline(value: any): (number?, string?)
	if value == nil then
		return 0, nil
	end
	local number = finite(value)
	if number == nil then
		return nil, ERRORS.cooldown
	end
	if number < 0 then
		return 0, nil
	end
	return number, nil
end

local function readClears(value: any): (number?, string?)
	if value == nil then
		return 0, nil
	end
	local number = finite(value)
	if number == nil then
		return nil, ERRORS.clears
	end
	if number < 0 then
		return 0, nil
	end
	return math.floor(number), nil
end

local function readFlag(value: any, message: string): (boolean?, string?)
	if value == nil then
		return false, nil
	end
	if type(value) == "boolean" then
		return value, nil
	end
	return nil, message
end

-- Nil is the default. Any finite number is kept, including a drop below 0.
local function readPriority(value: any): (number?, string?)
	if value == nil then
		local fallback = CONFIG.defaultPriority
		if type(fallback) ~= "number" then
			return 0, nil
		end
		return fallback, nil
	end
	local number = finite(value)
	if number == nil then
		return nil, ERRORS.priority
	end
	return number, nil
end

local function readUserId(value: any): (number?, string?)
	if value == nil then
		return nil, nil
	end
	local number = finite(value)
	if number == nil or number <= 0 or number ~= math.floor(number) then
		return nil, ERRORS.member
	end
	return number, nil
end

local function blankCounts(): Counts
	return { tank = 0, healer = 0, dps = 0 }
end

local function queueInvalid(
	message: string,
	blocked: boolean,
	difficulty: string?,
	role: string?
): QueueResult
	return {
		ok = false,
		queued = false,
		difficulty = difficulty or "",
		role = role or "",
		finderBlocked = blocked,
		remainingSeconds = 0,
		gearFiltered = false,
		clearFiltered = false,
		error = message,
	}
end

local function formInvalid(message: string, difficulty: string?): FormResult
	local damage = CONFIG.bossDamage
	if type(damage) ~= "number" then
		damage = 1
	end
	return {
		ok = false,
		mayStart = false,
		difficulty = difficulty or "",
		playerCount = 0,
		hpScale = 0,
		bossDamageScale = damage,
		autoScale = false,
		healingSpring = false,
		waitedSeconds = 0,
		healerTimeout = false,
		wardenCount = 0,
		freshCount = 0,
		mentorCount = 0,
		targets = blankCounts(),
		filled = blankCounts(),
		seats = {},
		error = message,
	}
end

local function targetsFor(size: number): Counts?
	local row = CONFIG.roleTargets[size]
	if type(row) ~= "table" then
		return nil
	end
	local tank = row.tank
	local healer = row.healer
	local dps = row.dps
	if type(tank) ~= "number" or type(healer) ~= "number" or type(dps) ~= "number" then
		return nil
	end
	return { tank = tank, healer = healer, dps = dps }
end

local function addFilled(filled: Counts, role: string)
	if role == "tank" then
		filled.tank += 1
	elseif role == "healer" then
		filled.healer += 1
	elseif role == "dps" then
		filled.dps += 1
	end
end

local function roomFor(filled: Counts, targets: Counts, role: string): boolean
	if role == "tank" then
		return filled.tank < targets.tank
	elseif role == "healer" then
		return filled.healer < targets.healer
	elseif role == "dps" then
		return filled.dps < targets.dps
	end
	return false
end

local function overflowRole(): string
	local order = CONFIG.fillOrder
	if type(order) == "table" then
		local last = order[#order]
		if last == "tank" or last == "healer" or last == "dps" then
			return last
		end
	end
	return "dps"
end

local function mentorEligible(clears: number, optedIn: boolean): boolean
	local needed = CONFIG.mentorClears
	if type(needed) ~= "number" then
		return false
	end
	return optedIn == true and clears >= needed
end

local function assign(parsed: { Parsed }, targets: Counts): ({ Seat }, Counts)
	local filled = blankCounts()
	local seats: { Seat } = {}
	local flexSeats: { Seat } = {}
	for index, member in ipairs(parsed) do
		local seat: Seat = {
			role = member.role,
			filled = member.role,
			freshShard = member.fresh,
			mentor = mentorEligible(member.clears, member.optedIn),
			priority = member.priority,
		}
		if member.userId ~= nil then
			seat.userId = member.userId
		end
		if member.role == "flex" then
			table.insert(flexSeats, seat)
		else
			addFilled(filled, member.role)
		end
		seats[index] = seat
	end
	for _, seat in ipairs(flexSeats) do
		local placed = false
		local order = CONFIG.fillOrder
		if type(order) == "table" then
			for _, role in ipairs(order) do
				if roomFor(filled, targets, role) then
					seat.filled = role
					addFilled(filled, role)
					placed = true
					break
				end
			end
		end
		if not placed then
			seat.filled = overflowRole()
			addFilled(filled, seat.filled)
		end
	end
	return seats, filled
end

local function damageFor(autoScale: boolean): number
	if autoScale then
		local cut = CONFIG.healerlessDamage
		if type(cut) == "number" then
			return cut
		end
	end
	local full = CONFIG.bossDamage
	if type(full) == "number" then
		return full
	end
	return 1
end

local function waitLimit(): number
	local limit = CONFIG.healerWaitSeconds
	if type(limit) ~= "number" or limit < 0 then
		return 180
	end
	return limit
end

function RaidFinder.hpScale(players: any): number?
	local count = finite(players)
	if count == nil then
		return nil
	end
	local scale = CONFIG.hpScale[count]
	if type(scale) ~= "number" then
		return nil
	end
	return scale
end

function RaidFinder.filters(difficulty: any): FilterResult
	local name, why = classifyDifficulty(difficulty)
	if name == nil then
		return {
			ok = false,
			difficulty = "",
			gearScore = false,
			clearCount = false,
			error = why or ERRORS.difficulty,
		}
	end
	return {
		ok = true,
		difficulty = name,
		gearScore = false,
		clearCount = false,
	}
end

function RaidFinder.mentor(clears: any, optedIn: any): MentorResult
	local count, countError = readClears(clears)
	if count == nil then
		return {
			ok = false,
			eligible = false,
			clears = 0,
			optedIn = false,
			error = countError or ERRORS.clears,
		}
	end
	local opted, optError = readFlag(optedIn, ERRORS.mentor)
	if opted == nil then
		return {
			ok = false,
			eligible = false,
			clears = count,
			optedIn = false,
			error = optError or ERRORS.mentor,
		}
	end
	return {
		ok = true,
		eligible = mentorEligible(count, opted),
		clears = count,
		optedIn = opted,
	}
end

local function readPriorityRecord(record: any): (StoredPriority?, string?)
	if record == nil then
		local priority = readPriority(nil)
		return { priority = priority or 0, priorityDay = 0 }, nil
	end
	if type(record) ~= "table" then
		return nil, ERRORS.priority
	end
	local priority, priorityError = readPriority(record.priority)
	if priority == nil then
		return nil, priorityError or ERRORS.priority
	end
	local day = record.priorityDay
	local priorityDay = 0
	if day ~= nil then
		local number = finite(day)
		if number == nil then
			return nil, ERRORS.priority
		end
		if number > 0 then
			priorityDay = math.floor(number)
		end
	end
	return { priority = priority, priorityDay = priorityDay }, nil
end

local function readIdle(value: any): (boolean?, string?)
	if value == nil then
		return false, nil
	end
	if type(value) == "boolean" then
		return value, nil
	end
	if type(value) ~= "string" then
		return nil, ERRORS.kick
	end
	local name = token(value)
	if name == nil then
		return nil, ERRORS.kick
	end
	return RaidFinder.IDLE_REASONS[name] == true, nil
end

local function priorityInvalid(message: string, stored: StoredPriority?): PriorityResult
	local priority = 0
	local priorityDay = 0
	if stored ~= nil then
		priority = stored.priority
		priorityDay = stored.priorityDay
	end
	return {
		ok = false,
		priority = priority,
		priorityDay = priorityDay,
		dropped = false,
		error = message,
	}
end

function RaidFinder.priority(record: PriorityRecord?, now: number, idleKick: any): PriorityResult
	local stored, recordError = readPriorityRecord(record)
	if stored == nil then
		return priorityInvalid(recordError or ERRORS.priority)
	end
	local at = finite(now)
	local today = if at ~= nil then RaidFinder.dayNumber(at) else nil
	if at == nil or today == nil then
		return priorityInvalid(ERRORS.time, stored)
	end
	local idle, idleError = readIdle(idleKick)
	if idle == nil then
		return priorityInvalid(idleError or ERRORS.kick, stored)
	end
	local priority = stored.priority
	local priorityDay = stored.priorityDay
	if priorityDay ~= today then
		local restored = CONFIG.defaultPriority
		priority = if type(restored) == "number" then restored else 0
		priorityDay = today
	end
	if idle then
		local dropped = CONFIG.droppedPriority
		priority = if type(dropped) == "number" then dropped else priority
		priorityDay = today
	end
	local floor = CONFIG.droppedPriority
	return {
		ok = true,
		priority = priority,
		priorityDay = priorityDay,
		dropped = type(floor) == "number" and priority == floor,
	}
end

function RaidFinder.canQueue(ticket: Ticket?, now: number): QueueResult
	if type(ticket) ~= "table" then
		return queueInvalid(ERRORS.party, true)
	end
	local difficulty, difficultyError = classifyDifficulty(ticket.difficulty)
	if difficulty == nil then
		return queueInvalid(difficultyError or ERRORS.difficulty, false)
	end
	local role = classifyRole(ticket.role)
	if role == nil then
		return queueInvalid(ERRORS.role, false, difficulty)
	end
	local at = finite(now)
	if at == nil or at < 0 then
		return queueInvalid(ERRORS.time, true, difficulty, role)
	end
	local deadline, coolError = storedDeadline(ticket.cooldownUntil)
	if deadline == nil then
		return queueInvalid(coolError or ERRORS.cooldown, true, difficulty, role)
	end
	if deadline > at then
		return {
			ok = true,
			queued = false,
			difficulty = difficulty,
			role = role,
			finderBlocked = true,
			remainingSeconds = deadline - at,
			gearFiltered = false,
			clearFiltered = false,
			error = ERRORS.cooling,
		}
	end
	return {
		ok = true,
		queued = true,
		difficulty = difficulty,
		role = role,
		finderBlocked = false,
		remainingSeconds = 0,
		gearFiltered = false,
		clearFiltered = false,
	}
end

local function readWait(value: any, now: number): (number?, string?)
	if value == nil then
		return now, nil
	end
	local at = finite(value)
	if at == nil or at < 0 then
		return nil, ERRORS.waiting
	end
	if at > now then
		return nil, ERRORS.clock
	end
	return at, nil
end

function RaidFinder.form(proposal: Proposal?, now: number): FormResult
	if type(proposal) ~= "table" then
		return formInvalid(ERRORS.party)
	end
	local difficulty, difficultyError = classifyDifficulty(proposal.difficulty)
	if difficulty == nil then
		return formInvalid(difficultyError or ERRORS.difficulty)
	end
	local at = finite(now)
	if at == nil or at < 0 then
		return formInvalid(ERRORS.time, difficulty)
	end
	local waiting, waitError = readWait(proposal.waitingSince, at)
	if waiting == nil then
		return formInvalid(waitError or ERRORS.waiting, difficulty)
	end
	local members = proposal.members
	if type(members) ~= "table" then
		return formInvalid(ERRORS.party, difficulty)
	end
	local count = #members
	local minParty = CONFIG.minParty
	local maxParty = CONFIG.maxParty
	if type(minParty) ~= "number" or type(maxParty) ~= "number" then
		return formInvalid(ERRORS.size, difficulty)
	end
	if count < minParty or count > maxParty then
		return formInvalid(ERRORS.size, difficulty)
	end
	local parsed: { Parsed } = {}
	local seen: { [number]: boolean } = {}
	for index = 1, count do
		local member = members[index]
		if type(member) ~= "table" then
			return formInvalid(ERRORS.party, difficulty)
		end
		local role = classifyRole(member.role)
		if role == nil then
			return formInvalid(ERRORS.role, difficulty)
		end
		local userId, userError = readUserId(member.userId)
		if userError ~= nil then
			return formInvalid(userError, difficulty)
		end
		if userId ~= nil then
			if seen[userId] == true then
				return formInvalid(ERRORS.duplicate, difficulty)
			end
			seen[userId] = true
		end
		local deadline, coolError = storedDeadline(member.cooldownUntil)
		if deadline == nil then
			return formInvalid(coolError or ERRORS.cooldown, difficulty)
		end
		if deadline > at then
			return formInvalid(ERRORS.cooling, difficulty)
		end
		local clears, clearsError = readClears(member.clears)
		if clears == nil then
			return formInvalid(clearsError or ERRORS.clears, difficulty)
		end
		local opted, optError = readFlag(member.mentorOptIn, ERRORS.mentor)
		if opted == nil then
			return formInvalid(optError or ERRORS.mentor, difficulty)
		end
		local fresh, freshError = readFlag(member.fresh, ERRORS.fresh)
		if fresh == nil then
			return formInvalid(freshError or ERRORS.fresh, difficulty)
		end
		local priority, priorityError = readPriority(member.priority)
		if priority == nil then
			return formInvalid(priorityError or ERRORS.priority, difficulty)
		end
		parsed[index] = {
			userId = userId,
			role = role,
			fresh = fresh,
			clears = clears,
			optedIn = opted,
			priority = priority,
		}
	end
	local targets = targetsFor(count)
	local scale = RaidFinder.hpScale(count)
	if targets == nil or scale == nil then
		return formInvalid(ERRORS.size, difficulty)
	end
	local seats, filled = assign(parsed, targets)
	local freshCount = 0
	local mentorCount = 0
	for _, seat in ipairs(seats) do
		if seat.freshShard then
			freshCount += 1
		end
		if seat.mentor then
			mentorCount += 1
		end
	end
	local missingTanks = targets.tank - filled.tank
	if missingTanks < 0 then
		missingTanks = 0
	end
	local missingHealers = targets.healer - filled.healer
	if missingHealers < 0 then
		missingHealers = 0
	end
	local waited = at - waiting
	local healerTimeout = waited >= waitLimit()
	local autoScale = missingHealers > 0 and healerTimeout
	local wardenCount = 0
	if difficulty == "story" then
		wardenCount = missingTanks
	end
	local tankOk = missingTanks == 0 or wardenCount >= missingTanks
	local healerOk = missingHealers == 0 or autoScale
	return {
		ok = true,
		mayStart = tankOk and healerOk,
		difficulty = difficulty,
		playerCount = count,
		hpScale = scale,
		bossDamageScale = damageFor(autoScale),
		autoScale = autoScale,
		healingSpring = autoScale and CONFIG.healingSpring == true,
		waitedSeconds = waited,
		healerTimeout = healerTimeout,
		wardenCount = wardenCount,
		freshCount = freshCount,
		mentorCount = mentorCount,
		targets = targets,
		filled = filled,
		seats = seats,
	}
end

return RaidFinder
