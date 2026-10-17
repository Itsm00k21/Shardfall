--!strict

--[[
	Guild calendar.

	A guild schedules raid nights. Players RSVP into one role slot.
	Roles are tank, healer, dps, and flex. The same player upserts
	that slot. A full role refuses a new player, and a move into a
	full role is refused with the old slot kept. A full list refuses
	a new entry and does not drop an old one.

	form takes the user ids the caller says are present. It returns
	who attended and a notice flag. It does not send the notice.

	A night is past when its start is strictly before now, and past
	nights prune so the table cannot grow forever. Unix seconds come
	in from the caller. Each call returns a new table and does not
	write its input. Tunables live in CONFIG. Nothing here costs
	Robux. There is no paid RSVP, extra slot, or skip.
]]

local RaidCalendar = {}

local MAX_SAFE = 9007199254740991

local ROLES = table.freeze({
	tank = true,
	healer = true,
	dps = true,
	flex = true,
})

RaidCalendar.CONFIG = table.freeze({
	-- Placeholder. Events kept per guild. A full list refuses a new night.
	maxEvents = 8,
	-- Placeholder. Seats of one role on one night. 3 so a role can fill
	-- while the RSVP list (8) still has room in another role.
	maxRoleSlots = 3,
	-- Placeholder. RSVPs on one night, across every role.
	maxRsvps = 8,
	-- Placeholder cap for a guild id and a raid night id.
	maxIdLength = 64,
	-- Compared after trim and lower. Flex is its own seat.
	roles = ROLES,
})

RaidCalendar.ERRORS = table.freeze({
	rules = "The guild calendar rules are unusable.",
	state = "That guild calendar is unusable.",
	request = "That calendar request is unusable.",
	guild = "That guild id is unusable.",
	id = "That raid night id is unusable.",
	time = "That raid time is unusable.",
	past = "That raid night is already past.",
	missing = "That raid night is not on the calendar.",
	user = "That player id is unusable.",
	role = "That role is unusable.",
	roleFull = "That role is full.",
	full = "That raid night list is full.",
	rsvpsFull = "That RSVP list is full.",
	present = "That attendance list is unusable.",
	skip = "The guild calendar has no paid RSVP, extra slot, or skip.",
})

-- A present field is refused even when the value is false.
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
	paidRsvp = true,
	extraSlot = true,
	buySlot = true,
	skipCap = true,
	paidSlot = true,
	skipPrune = true,
})

export type Seat = {
	userId: number,
	role: string,
}

export type Night = {
	id: string,
	startsAt: number,
	rsvps: { Seat },
	formed: boolean,
	attended: { number },
}

export type GuildNights = {
	guildId: string,
	nights: { Night },
}

export type Store = {
	guilds: { GuildNights },
}

export type Result = {
	ok: boolean,
	persist: boolean,
	state: Store,
	night: Night?,
	attended: { number },
	notice: boolean,
	error: string?,
}

type Limits = {
	maxEvents: number,
	maxRoleSlots: number,
	maxRsvps: number,
	idCap: number,
}

type Ready = {
	limits: Limits,
	now: number,
	state: Store,
	pruned: boolean,
}

local ERRORS = RaidCalendar.ERRORS

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

-- Whole unix seconds in 0..2^53-1. -0 is stored as 0.
local function unix(value: any): number?
	local number = wholeBetween(value, 0, MAX_SAFE)
	if number == nil then
		return nil
	end
	if number == 0 then
		return 0
	end
	return number
end

local function userIdOf(value: any): number?
	return wholeBetween(value, 1, MAX_SAFE)
end

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
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

local function blankStore(): Store
	return {
		guilds = {},
	}
end

local function blankNight(id: string, startsAt: number): Night
	return {
		id = id,
		startsAt = startsAt,
		rsvps = {},
		formed = false,
		attended = {},
	}
end

local function rolesOk(): boolean
	local roles = RaidCalendar.CONFIG.roles
	if type(roles) ~= "table" then
		return false
	end
	local count = 0
	for key, value in pairs(roles) do
		if type(key) ~= "string" or value ~= true then
			return false
		end
		if key ~= "tank" and key ~= "healer" and key ~= "dps" and key ~= "flex" then
			return false
		end
		count += 1
	end
	return count == 4
end

local function rules(): (Limits?, string?)
	local maxEvents = positive(RaidCalendar.CONFIG.maxEvents)
	local maxRoleSlots = positive(RaidCalendar.CONFIG.maxRoleSlots)
	local maxRsvps = positive(RaidCalendar.CONFIG.maxRsvps)
	local idCap = positive(RaidCalendar.CONFIG.maxIdLength)
	if maxEvents == nil or maxRoleSlots == nil or maxRsvps == nil or idCap == nil then
		return nil, ERRORS.rules
	end
	if not rolesOk() then
		return nil, ERRORS.rules
	end
	return {
		maxEvents = maxEvents,
		maxRoleSlots = maxRoleSlots,
		maxRsvps = maxRsvps,
		idCap = idCap,
	},
		nil
end

local function storedLabel(value: any, cap: number): string?
	if type(value) ~= "string" then
		return nil
	end
	if value == "" or value ~= trim(value) or #value > cap then
		return nil
	end
	return value
end

local function storedRole(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	if (RaidCalendar.CONFIG.roles :: any)[value] ~= true then
		return nil
	end
	return value
end

local function readSeat(value: any): (Seat?, string?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.state
	end
	local userId = userIdOf(value.userId)
	local role = storedRole(value.role)
	if userId == nil or role == nil then
		return nil, ERRORS.state
	end
	return {
		userId = userId,
		role = role,
	}, nil
end

local function readSeats(value: any, limits: Limits): ({ Seat }?, string?)
	if value == nil then
		return {}, nil
	end
	local count = arraySize(value)
	if count == nil or count > limits.maxRsvps then
		return nil, ERRORS.state
	end
	local seats = {}
	local seen: { [number]: boolean } = {}
	local perRole: { [string]: number } = {}
	for index = 1, count do
		local seat, seatError = readSeat(value[index])
		if seat == nil then
			return nil, seatError or ERRORS.state
		end
		if seen[seat.userId] == true then
			return nil, ERRORS.state
		end
		seen[seat.userId] = true
		local filled = perRole[seat.role] or 0
		if filled >= limits.maxRoleSlots then
			return nil, ERRORS.state
		end
		perRole[seat.role] = filled + 1
		table.insert(seats, seat)
	end
	return seats, nil
end

local function readAttended(value: any, seats: { Seat }, formed: boolean): ({ number }?, string?)
	if value == nil then
		return {}, nil
	end
	local count = arraySize(value)
	if count == nil then
		return nil, ERRORS.state
	end
	if not formed and count > 0 then
		return nil, ERRORS.state
	end
	local wanted: { [number]: boolean } = {}
	local list = {}
	for index = 1, count do
		local userId = userIdOf(value[index])
		if userId == nil or wanted[userId] == true then
			return nil, ERRORS.state
		end
		wanted[userId] = true
		table.insert(list, userId)
	end
	local expected = {}
	local seated: { [number]: boolean } = {}
	for _, seat in ipairs(seats) do
		seated[seat.userId] = true
		if wanted[seat.userId] == true then
			table.insert(expected, seat.userId)
		end
	end
	if #expected ~= #list then
		return nil, ERRORS.state
	end
	for index, userId in ipairs(expected) do
		if list[index] ~= userId or seated[userId] ~= true then
			return nil, ERRORS.state
		end
	end
	return list, nil
end

local function readNight(value: any, limits: Limits): (Night?, string?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.state
	end
	local id = storedLabel(value.id, limits.idCap)
	local startsAt = unix(value.startsAt)
	if id == nil or startsAt == nil then
		return nil, ERRORS.state
	end
	local seats, seatError = readSeats(value.rsvps, limits)
	if seats == nil then
		return nil, seatError or ERRORS.state
	end
	local formed = false
	if value.formed ~= nil then
		if type(value.formed) ~= "boolean" then
			return nil, ERRORS.state
		end
		formed = value.formed
	end
	local attended, attendedError = readAttended(value.attended, seats, formed)
	if attended == nil then
		return nil, attendedError or ERRORS.state
	end
	return {
		id = id,
		startsAt = startsAt,
		rsvps = seats,
		formed = formed,
		attended = attended,
	},
		nil
end

local function readGuild(value: any, limits: Limits): (GuildNights?, string?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.state
	end
	local guildId = storedLabel(value.guildId, limits.idCap)
	if guildId == nil then
		return nil, ERRORS.state
	end
	local listed = value.nights
	if listed == nil then
		listed = {}
	end
	local count = arraySize(listed)
	if count == nil or count > limits.maxEvents then
		return nil, ERRORS.state
	end
	local nights = {}
	local seen: { [string]: boolean } = {}
	for index = 1, count do
		local night, nightError = readNight(listed[index], limits)
		if night == nil then
			return nil, nightError or ERRORS.state
		end
		if seen[night.id] == true then
			return nil, ERRORS.state
		end
		seen[night.id] = true
		table.insert(nights, night)
	end
	return {
		guildId = guildId,
		nights = nights,
	}, nil
end

local function readStore(value: any, limits: Limits): (Store?, string?)
	if value == nil then
		return blankStore(), nil
	end
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, ERRORS.state
	end
	if value.guilds == nil then
		return blankStore(), nil
	end
	local count = arraySize(value.guilds)
	if count == nil then
		return nil, ERRORS.state
	end
	local guilds = {}
	local seen: { [string]: boolean } = {}
	for index = 1, count do
		local guild, guildError = readGuild(value.guilds[index], limits)
		if guild == nil then
			return nil, guildError or ERRORS.state
		end
		if seen[guild.guildId] == true then
			return nil, ERRORS.state
		end
		seen[guild.guildId] = true
		table.insert(guilds, guild)
	end
	return {
		guilds = guilds,
	}, nil
end

local function parseLabel(value: any, cap: number, message: string): (string?, string?)
	if type(value) ~= "string" then
		return nil, message
	end
	local trimmed = trim(value)
	if trimmed == "" or #trimmed > cap then
		return nil, message
	end
	return trimmed, nil
end

local function parseRole(value: any): (string?, string?)
	if type(value) ~= "string" then
		return nil, ERRORS.role
	end
	local cleaned = string.lower(trim(value))
	if (RaidCalendar.CONFIG.roles :: any)[cleaned] ~= true then
		return nil, ERRORS.role
	end
	return cleaned, nil
end

local function parseStart(value: any, now: number): (number?, string?)
	local startsAt = unix(value)
	if startsAt == nil then
		return nil, ERRORS.time
	end
	if startsAt < now then
		return nil, ERRORS.past
	end
	return startsAt, nil
end

local function readPresent(value: any): ({ [number]: boolean }?, string?)
	local count = arraySize(value)
	if count == nil then
		return nil, ERRORS.present
	end
	local present: { [number]: boolean } = {}
	for index = 1, count do
		local userId = userIdOf(value[index])
		if userId == nil or present[userId] == true then
			return nil, ERRORS.present
		end
		present[userId] = true
	end
	return present, nil
end

local function findGuild(store: Store, guildId: string): GuildNights?
	for _, guild in ipairs(store.guilds) do
		if guild.guildId == guildId then
			return guild
		end
	end
	return nil
end

local function findNight(guild: GuildNights, id: string): Night?
	for _, night in ipairs(guild.nights) do
		if night.id == id then
			return night
		end
	end
	return nil
end

local function findSeat(night: Night, userId: number): number?
	for index, seat in ipairs(night.rsvps) do
		if seat.userId == userId then
			return index
		end
	end
	return nil
end

local function roleCount(night: Night, role: string): number
	local count = 0
	for _, seat in ipairs(night.rsvps) do
		if seat.role == role then
			count += 1
		end
	end
	return count
end

local function attendees(night: Night, present: { [number]: boolean }): { number }
	local list = {}
	for _, seat in ipairs(night.rsvps) do
		if present[seat.userId] == true then
			table.insert(list, seat.userId)
		end
	end
	return list
end

local function sameIds(left: { number }, right: { number }): boolean
	if #left ~= #right then
		return false
	end
	for index, userId in ipairs(left) do
		if right[index] ~= userId then
			return false
		end
	end
	return true
end

local function prune(store: Store, now: number): (Store, boolean)
	local guilds = {}
	local dropped = false
	for _, guild in ipairs(store.guilds) do
		local nights = {}
		for _, night in ipairs(guild.nights) do
			if night.startsAt < now then
				dropped = true
			else
				table.insert(nights, night)
			end
		end
		if #nights == 0 then
			dropped = true
		else
			table.insert(guilds, {
				guildId = guild.guildId,
				nights = nights,
			})
		end
	end
	return {
		guilds = guilds,
	}, dropped
end

local function okResult(
	state: Store,
	persist: boolean,
	night: Night?,
	attended: { number },
	notice: boolean
): Result
	return {
		ok = true,
		persist = persist,
		state = state,
		night = night,
		attended = attended,
		notice = notice,
		error = nil,
	}
end

local function denied(message: string, state: Store?, night: Night?): Result
	local kept = state
	if kept == nil then
		kept = blankStore()
	end
	return {
		ok = false,
		persist = false,
		state = kept,
		night = night,
		attended = {},
		notice = false,
		error = message,
	}
end

local function prepare(state: any, now: any, extra: any): (Ready?, Result?)
	if extra ~= nil then
		return nil, denied(ERRORS.skip, nil, nil)
	end
	local limits, rulesError = rules()
	if limits == nil then
		return nil, denied(rulesError or ERRORS.rules, nil, nil)
	end
	local record, stateError = readStore(state, limits)
	if record == nil then
		return nil, denied(stateError or ERRORS.state, nil, nil)
	end
	local instant = unix(now)
	if instant == nil then
		return nil, denied(ERRORS.time, record, nil)
	end
	local prunedState, dropped = prune(record, instant)
	return {
		limits = limits,
		now = instant,
		state = prunedState,
		pruned = dropped,
	}, nil
end

local function requestOf(value: any, ready: Ready): ({ [string]: any }?, Result?)
	if type(value) ~= "table" or not stringKeyed(value) then
		return nil, denied(ERRORS.request, ready.state, nil)
	end
	if skipField(value) then
		return nil, denied(ERRORS.skip, ready.state, nil)
	end
	return value, nil
end

local function lookup(ready: Ready, guildId: string, id: string): (GuildNights?, Night?)
	local guild = findGuild(ready.state, guildId)
	if guild == nil then
		return nil, nil
	end
	return guild, findNight(guild, id)
end

function RaidCalendar.fresh(): Store
	return blankStore()
end

function RaidCalendar.view(state: any, now: any, extra: any): Result
	local ready, failure = prepare(state, now, extra)
	if failure ~= nil or ready == nil then
		return failure or denied(ERRORS.state, nil, nil)
	end
	return okResult(ready.state, ready.pruned, nil, {}, false)
end

function RaidCalendar.schedule(state: any, request: any, now: any, extra: any): Result
	local ready, failure = prepare(state, now, extra)
	if failure ~= nil or ready == nil then
		return failure or denied(ERRORS.state, nil, nil)
	end
	local body, bad = requestOf(request, ready)
	if body == nil or bad ~= nil then
		return bad or denied(ERRORS.request, ready.state, nil)
	end
	local guildId, guildError = parseLabel(body.guildId, ready.limits.idCap, ERRORS.guild)
	if guildId == nil then
		return denied(guildError or ERRORS.guild, ready.state, nil)
	end
	local id, idError = parseLabel(body.id, ready.limits.idCap, ERRORS.id)
	if id == nil then
		return denied(idError or ERRORS.id, ready.state, nil)
	end
	local guild, night = lookup(ready, guildId, id)
	local startsAt, startError = parseStart(body.startsAt, ready.now)
	if startsAt == nil then
		return denied(startError or ERRORS.time, ready.state, night)
	end
	if night ~= nil and night.startsAt == startsAt then
		return okResult(ready.state, ready.pruned, night, {}, false)
	end
	if night == nil then
		local count = 0
		if guild ~= nil then
			count = #guild.nights
		end
		if count >= ready.limits.maxEvents then
			return denied(ERRORS.full, ready.state, nil)
		end
	end
	if night ~= nil then
		night.startsAt = startsAt
		night.formed = false
		night.attended = {}
		return okResult(ready.state, true, night, {}, false)
	end
	local created = blankNight(id, startsAt)
	if guild == nil then
		local added: GuildNights = {
			guildId = guildId,
			nights = {},
		}
		table.insert(ready.state.guilds, added)
		guild = added
	end
	table.insert(guild.nights, created)
	return okResult(ready.state, true, created, {}, false)
end

function RaidCalendar.rsvp(state: any, request: any, now: any, extra: any): Result
	local ready, failure = prepare(state, now, extra)
	if failure ~= nil or ready == nil then
		return failure or denied(ERRORS.state, nil, nil)
	end
	local body, bad = requestOf(request, ready)
	if body == nil or bad ~= nil then
		return bad or denied(ERRORS.request, ready.state, nil)
	end
	local guildId, guildError = parseLabel(body.guildId, ready.limits.idCap, ERRORS.guild)
	if guildId == nil then
		return denied(guildError or ERRORS.guild, ready.state, nil)
	end
	local id, idError = parseLabel(body.id, ready.limits.idCap, ERRORS.id)
	if id == nil then
		return denied(idError or ERRORS.id, ready.state, nil)
	end
	local userId = userIdOf(body.userId)
	if userId == nil then
		return denied(ERRORS.user, ready.state, nil)
	end
	local role, roleError = parseRole(body.role)
	if role == nil then
		return denied(roleError or ERRORS.role, ready.state, nil)
	end
	local _, night = lookup(ready, guildId, id)
	if night == nil then
		return denied(ERRORS.missing, ready.state, nil)
	end
	local index = findSeat(night, userId)
	if index == nil then
		if roleCount(night, role) >= ready.limits.maxRoleSlots then
			return denied(ERRORS.roleFull, ready.state, night)
		end
		if #night.rsvps >= ready.limits.maxRsvps then
			return denied(ERRORS.rsvpsFull, ready.state, night)
		end
		table.insert(night.rsvps, {
			userId = userId,
			role = role,
		})
		return okResult(ready.state, true, night, {}, false)
	end
	local seat = night.rsvps[index]
	if seat.role == role then
		return okResult(ready.state, ready.pruned, night, {}, false)
	end
	if roleCount(night, role) >= ready.limits.maxRoleSlots then
		return denied(ERRORS.roleFull, ready.state, night)
	end
	seat.role = role
	return okResult(ready.state, true, night, {}, false)
end

function RaidCalendar.form(state: any, request: any, now: any, extra: any): Result
	local ready, failure = prepare(state, now, extra)
	if failure ~= nil or ready == nil then
		return failure or denied(ERRORS.state, nil, nil)
	end
	local body, bad = requestOf(request, ready)
	if body == nil or bad ~= nil then
		return bad or denied(ERRORS.request, ready.state, nil)
	end
	local guildId, guildError = parseLabel(body.guildId, ready.limits.idCap, ERRORS.guild)
	if guildId == nil then
		return denied(guildError or ERRORS.guild, ready.state, nil)
	end
	local id, idError = parseLabel(body.id, ready.limits.idCap, ERRORS.id)
	if id == nil then
		return denied(idError or ERRORS.id, ready.state, nil)
	end
	local present, presentError = readPresent(body.present)
	if present == nil then
		return denied(presentError or ERRORS.present, ready.state, nil)
	end
	local _, night = lookup(ready, guildId, id)
	if night == nil then
		return denied(ERRORS.missing, ready.state, nil)
	end
	local attended = attendees(night, present)
	if night.formed and sameIds(night.attended, attended) then
		return okResult(ready.state, ready.pruned, night, night.attended, false)
	end
	local notice = not night.formed
	night.formed = true
	night.attended = attended
	return okResult(ready.state, true, night, attended, notice)
end

return RaidCalendar
