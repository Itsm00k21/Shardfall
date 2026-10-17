--!strict

--[[
	Raid Marks. Weekly earning cap, banked unused cap, and clear payouts.

	The server passes a plain record and unix seconds. This module does
	not read players, grant loot, or touch DataStores and remotes. It
	does not read the clock. Pass os.time() as now. Thresholds live in
	CONFIG. Nothing here costs Robux.

	The earning room is 600 per Tuesday week, plus a bank of unused room
	up to 3 weeks (1800). The balance is the wallet. Tuesday 00:00 UTC
	starts a new week key. Reclears pay the same Marks as a first clear.
	Each first-timer adds 10% to the group's per-player grant. An AFK
	removal pays 0 for that clear. A passed vote-kick keeps the grant.
	CONFIG.doubleMarks is false, so an event flag does not multiply.
]]

local RaidMarks = {}

local PAYOUTS = table.freeze({
	story = 25,
	normal = 40,
	hard = 60,
	shardbreaker = 80,
	fracture = 20,
})

RaidMarks.CONFIG = table.freeze({
	weeklyCap = 600,
	bankWeeks = 3,
	weekSeconds = 7 * 86400,
	daySeconds = 86400,
	-- 1970-01-01 was a Thursday. The first Tuesday 00:00 UTC is 5 days later.
	tuesdayOffset = 5 * 86400,
	firstTimerNumerator = 1,
	firstTimerDenominator = 10,
	eventMultiplier = 2,
	doubleMarks = false,
	payouts = PAYOUTS,
})

RaidMarks.REMOVALS = table.freeze({
	afk = true,
	kick = true,
})

RaidMarks.ERRORS = table.freeze({
	time = "Raid time is missing.",
	record = "The Marks record is unusable.",
	amount = "That Mark amount is unusable.",
	cost = "That cost is unusable.",
	short = "Not enough Raid Marks.",
	difficulty = "That difficulty has no Marks payout.",
	removal = "That removal is not a known cause.",
	timers = "That first-timer count is unusable.",
	clock = "Raid time moved backwards.",
	clear = "That clear is unusable.",
	lock = "That lockout flag is unusable.",
})

export type State = {
	balance: number?,
	weekKey: number?,
	earnedThisWeek: number?,
	bankedCap: number?,
}

export type Clear = {
	firstTimers: number?,
	locked: boolean?,
	removal: any,
	event: boolean?,
}

export type Payout = {
	ok: boolean,
	difficulty: string,
	amount: number,
	base: number,
	gross: number,
	firstTimers: number,
	multiplier: number,
	event: boolean,
	locked: boolean,
	reclear: boolean,
	keepMarks: boolean,
	forfeited: boolean,
	error: string?,
}

export type Ledger = {
	ok: boolean,
	balance: number,
	weekKey: number,
	earnedThisWeek: number,
	bankedCap: number,
	granted: number,
	capped: boolean,
	room: number,
	rolled: boolean,
	error: string?,
}

export type Spend = {
	ok: boolean,
	balance: number,
	weekKey: number,
	earnedThisWeek: number,
	bankedCap: number,
	spent: number,
	error: string?,
}

type Record = {
	balance: number,
	weekKey: number,
	earnedThisWeek: number,
	bankedCap: number,
}

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

local function bankMax(): number
	local cap = RaidMarks.CONFIG.weeklyCap
	local weeks = RaidMarks.CONFIG.bankWeeks
	if type(cap) ~= "number" or type(weeks) ~= "number" or cap < 0 or weeks < 0 then
		return 0
	end
	return cap * weeks
end

local function clampBank(banked: number): number
	local limit = bankMax()
	if banked > limit then
		return limit
	end
	if banked < 0 then
		return 0
	end
	return banked
end

local function roomFor(earned: number, banked: number): number
	local cap = RaidMarks.CONFIG.weeklyCap
	if type(cap) ~= "number" then
		return 0
	end
	local room = cap + banked - earned
	if room < 0 then
		return 0
	end
	return room
end

-- Nil becomes 0. A negative becomes 0. Non-finite is corrupt.
local function storedMarks(value: any): (number?, boolean)
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
	return math.floor(number), false
end

-- Below 0 means the profile has never been stamped on this calendar.
-- The schema default is -1. 0 is the stretch before the first Tuesday.
local function storedWeek(value: any): (number?, boolean)
	if value == nil then
		return -1, false
	end
	local number = finite(value)
	if number == nil then
		return nil, true
	end
	return math.floor(number), false
end

local function blankRecord(): Record
	return {
		balance = 0,
		weekKey = -1,
		earnedThisWeek = 0,
		bankedCap = 0,
	}
end

local function readRecord(state: any): (Record?, string?)
	if state == nil then
		return blankRecord(), nil
	end
	if type(state) ~= "table" then
		return nil, RaidMarks.ERRORS.record
	end
	local balance, badBalance = storedMarks(state.balance)
	local weekKey, badWeek = storedWeek(state.weekKey)
	local earned, badEarned = storedMarks(state.earnedThisWeek)
	local banked, badBank = storedMarks(state.bankedCap)
	if
		badBalance
		or badWeek
		or badEarned
		or badBank
		or balance == nil
		or weekKey == nil
		or earned == nil
		or banked == nil
	then
		return nil, RaidMarks.ERRORS.record
	end
	return {
		balance = balance,
		weekKey = weekKey,
		earnedThisWeek = earned,
		bankedCap = banked,
	},
		nil
end

local function copyRecord(record: Record): Record
	return {
		balance = record.balance,
		weekKey = record.weekKey,
		earnedThisWeek = record.earnedThisWeek,
		bankedCap = record.bankedCap,
	}
end

-- Week 1 starts at 1970-01-06 00:00:00 UTC. The reset instant is the new week.
-- Times before that Tuesday are week 0. A bad clock returns nil.
function RaidMarks.weekKey(now: number): number?
	local at = finite(now)
	if at == nil or at < 0 then
		return nil
	end
	local offset = RaidMarks.CONFIG.tuesdayOffset
	local span = RaidMarks.CONFIG.weekSeconds
	if type(offset) ~= "number" or type(span) ~= "number" or span < 1 or offset < 0 then
		return nil
	end
	if at < offset then
		return 0
	end
	return math.floor((at - offset) / span) + 1
end

local function wholeGrant(value: any): number?
	local number = finite(value)
	if number == nil or number < 0 or number ~= math.floor(number) then
		return nil
	end
	return number
end

-- Both sides must ask. The frozen switch defaults off, so a live event flag pays 1x.
local function eventMultiplier(requested: any): number
	if requested ~= true or RaidMarks.CONFIG.doubleMarks ~= true then
		return 1
	end
	local scale = RaidMarks.CONFIG.eventMultiplier
	if type(scale) ~= "number" or scale < 1 or scale ~= math.floor(scale) then
		return 1
	end
	return scale
end

-- Half-up on the final integer. 25 with one first-timer is 28. Scale 2 doubles that.
local function scaledAmount(base: number, firstTimers: number, scale: number): number
	local denom = RaidMarks.CONFIG.firstTimerDenominator
	local numer = RaidMarks.CONFIG.firstTimerNumerator
	if
		type(denom) ~= "number"
		or type(numer) ~= "number"
		or denom < 1
		or numer < 0
		or denom ~= math.floor(denom)
		or numer ~= math.floor(numer)
	then
		return base * scale
	end
	local weight = denom + firstTimers * numer
	local product = base * weight * scale
	return (product + (denom // 2)) // denom
end

local function badPayout(message: string): Payout
	return {
		ok = false,
		difficulty = "",
		amount = 0,
		base = 0,
		gross = 0,
		firstTimers = 0,
		multiplier = 1,
		event = false,
		locked = false,
		reclear = false,
		keepMarks = false,
		forfeited = false,
		error = message,
	}
end

local function knownRemoval(value: any): boolean
	return type(value) == "string" and (RaidMarks.REMOVALS :: any)[value] == true
end

function RaidMarks.payout(difficulty: any, clear: any): Payout
	if type(difficulty) ~= "string" then
		return badPayout(RaidMarks.ERRORS.difficulty)
	end
	local id = string.lower(trim(difficulty))
	local base = (RaidMarks.CONFIG.payouts :: any)[id]
	if type(base) ~= "number" or base < 0 or base ~= math.floor(base) then
		return badPayout(RaidMarks.ERRORS.difficulty)
	end
	if clear == nil then
		clear = {}
	end
	if type(clear) ~= "table" then
		return badPayout(RaidMarks.ERRORS.clear)
	end
	local timers = clear.firstTimers
	if timers == nil then
		timers = 0
	end
	local count = finite(timers)
	if count == nil or count < 0 or count ~= math.floor(count) then
		return badPayout(RaidMarks.ERRORS.timers)
	end
	local locked = clear.locked
	if locked == nil then
		locked = false
	end
	if type(locked) ~= "boolean" then
		return badPayout(RaidMarks.ERRORS.lock)
	end
	local removal = clear.removal
	if removal ~= nil and not knownRemoval(removal) then
		return badPayout(RaidMarks.ERRORS.removal)
	end
	local scale = eventMultiplier(clear.event)
	local gross = scaledAmount(base, count, scale)
	local forfeited = removal == "afk"
	local amount = gross
	if forfeited then
		amount = 0
	end
	return {
		ok = true,
		difficulty = id,
		amount = amount,
		base = base,
		gross = gross,
		firstTimers = count,
		multiplier = scale,
		event = scale > 1,
		locked = locked,
		reclear = locked,
		keepMarks = not forfeited,
		forfeited = forfeited,
		error = nil,
	}
end

-- A key below 0 has no history to bank. A later key refuses. A gap banks the
-- unused room from the stored week, then one fresh cap per fully skipped week.
local function roll(record: Record, key: number): (Record?, boolean, string?)
	local banked = clampBank(record.bankedCap)
	if record.weekKey < 0 then
		local stamped = copyRecord(record)
		stamped.weekKey = key
		stamped.bankedCap = banked
		return stamped, true, nil
	end
	if record.weekKey > key then
		return nil, false, RaidMarks.ERRORS.clock
	end
	if record.weekKey == key then
		local same = copyRecord(record)
		same.bankedCap = banked
		return same, false, nil
	end
	local gap = key - record.weekKey
	local carry = banked + RaidMarks.CONFIG.weeklyCap - record.earnedThisWeek
	if carry < 0 then
		carry = 0
	end
	local skipped = gap - 1
	if skipped > 0 then
		carry += skipped * RaidMarks.CONFIG.weeklyCap
	end
	return {
		balance = record.balance,
		weekKey = key,
		earnedThisWeek = 0,
		bankedCap = clampBank(carry),
	},
		true,
		nil
end

local function failLedger(message: string, record: Record?): Ledger
	local source = record or blankRecord()
	local room = 0
	if record ~= nil then
		room = roomFor(source.earnedThisWeek, source.bankedCap)
	end
	return {
		ok = false,
		balance = source.balance,
		weekKey = source.weekKey,
		earnedThisWeek = source.earnedThisWeek,
		bankedCap = source.bankedCap,
		granted = 0,
		capped = false,
		room = room,
		rolled = false,
		error = message,
	}
end

local function apply(amount: any, state: any, now: any): Ledger
	local record, recordError = readRecord(state)
	if record == nil then
		return failLedger(recordError or RaidMarks.ERRORS.record, nil)
	end
	local at = finite(now)
	local key = if at ~= nil then RaidMarks.weekKey(at) else nil
	if key == nil then
		return failLedger(RaidMarks.ERRORS.time, record)
	end
	local grant = wholeGrant(amount)
	if grant == nil then
		return failLedger(RaidMarks.ERRORS.amount, record)
	end
	local nextRecord, rolled, rollError = roll(record, key)
	if nextRecord == nil then
		return failLedger(rollError or RaidMarks.ERRORS.clock, record)
	end
	local room = roomFor(nextRecord.earnedThisWeek, nextRecord.bankedCap)
	local granted = grant
	if granted > room then
		granted = room
	end
	local capped = granted < grant
	return {
		ok = true,
		balance = nextRecord.balance + granted,
		weekKey = nextRecord.weekKey,
		earnedThisWeek = nextRecord.earnedThisWeek + granted,
		bankedCap = nextRecord.bankedCap,
		granted = granted,
		capped = capped,
		room = room - granted,
		rolled = rolled,
		error = nil,
	}
end

function RaidMarks.earn(amount: number, state: State?, now: number): Ledger
	return apply(amount, state, now)
end

function RaidMarks.settle(state: State?, now: number): Ledger
	return apply(0, state, now)
end

local function failSpend(message: string, record: Record?): Spend
	local source = record or blankRecord()
	return {
		ok = false,
		balance = source.balance,
		weekKey = source.weekKey,
		earnedThisWeek = source.earnedThisWeek,
		bankedCap = source.bankedCap,
		spent = 0,
		error = message,
	}
end

function RaidMarks.canSpend(cost: number, state: State?): Spend
	local record, recordError = readRecord(state)
	if record == nil then
		return failSpend(recordError or RaidMarks.ERRORS.record, nil)
	end
	local price = wholeGrant(cost)
	if price == nil then
		return failSpend(RaidMarks.ERRORS.cost, record)
	end
	if price > record.balance then
		return failSpend(RaidMarks.ERRORS.short, record)
	end
	return {
		ok = true,
		balance = record.balance - price,
		weekKey = record.weekKey,
		earnedThisWeek = record.earnedThisWeek,
		bankedCap = record.bankedCap,
		spent = price,
		error = nil,
	}
end

return RaidMarks
