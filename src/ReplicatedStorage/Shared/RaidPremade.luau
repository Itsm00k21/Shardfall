--!strict

--[[
	Premade board. Party Finder style listings for the Guild Plaza.

	The server passes plain tables and unix seconds. This module does
	not read players, filter title text, queue MemoryStore, or touch
	DataStores and remotes. It does not require RaidFinder, RaidLeaver,
	or Raids. Role names match RaidFinder. The caller filters a title
	with TextService and keeps that string. Thresholds live in CONFIG.
	Nothing here costs Robux.

	A listing is Story, Normal, Hard, or Shardbreaker. Guided is refused.
	Tags are one or more of Learning, Farm, Speedrun, and Achievement.
	A required clear count is optional and defaults to 0. The party is
	4 to 8, with one role slot per seat. Story and Normal refuse a
	gear-score requirement. A stored gear score on Hard or Shardbreaker
	is not a join filter. A tank, healer, or DPS takes an open slot of
	that role, then an open flex slot. Flex takes the first open slot.
	One active listing per host. The listing closes when the host leaves.
	It expires once listingSeconds have elapsed, including that instant.
	Pass os.time(). This module does not read the clock. A RaidLeaver
	Finder cooldown is ignored.
]]

local RaidPremade = {}

RaidPremade.CONFIG = table.freeze({
	minParty = 4,
	maxParty = 8,
	listingSeconds = 1800,
	minClears = 0,
})

RaidPremade.DIFFICULTIES = table.freeze({
	story = true,
	normal = true,
	hard = true,
	shardbreaker = true,
})

-- Story and Normal cannot carry a gear-score requirement. Hard and
-- Shardbreaker may store one. canJoin does not compare it.
RaidPremade.GEAR_FREE = table.freeze({
	story = true,
	normal = true,
})

RaidPremade.REFUSED = table.freeze({
	guided = true,
})

-- Same four names as RaidFinder.ROLES. This module does not require it.
RaidPremade.ROLES = table.freeze({
	tank = true,
	healer = true,
	dps = true,
	flex = true,
})

-- Same four labels as Raids.TAGS, compared after trim and lowercase.
RaidPremade.TAGS = table.freeze({
	learning = true,
	farm = true,
	speedrun = true,
	achievement = true,
})

RaidPremade.ERRORS = table.freeze({
	time = "Raid time is missing.",
	clock = "Raid time moved backwards.",
	created = "That listing has no time.",
	difficulty = "Pick Story, Normal, Hard, or Shardbreaker.",
	guided = "Guided Raids are not on the premade board.",
	guidedFlag = "That guided flag is unusable.",
	tag = "Pick at least one tag: Learning, Farm, Speedrun, or Achievement.",
	tagUnknown = "That tag is not on the premade board.",
	tagDuplicate = "That tag is listed twice.",
	clears = "That clear count is unusable.",
	short = "That player does not have enough clears.",
	gear = "Story and Normal cannot require a gear score.",
	gearValue = "That gear score is unusable.",
	size = "A premade listing needs 4 to 8 players.",
	slots = "Those role slots are unusable.",
	slotCount = "The role slots have to match the party size.",
	role = "Pick Tank, Healer, DPS, or Flex.",
	fit = "That party does not fit these slots.",
	slot = "There is no open slot for that role.",
	full = "That listing is full.",
	expired = "That listing has expired.",
	closed = "That listing is closed.",
	host = "That host is unusable.",
	hostSeat = "The host has to take a slot.",
	taken = "That host already has a listing.",
	member = "That party member is unusable.",
	player = "That player is unusable.",
	duplicate = "That player is already in this listing.",
	absent = "That player is not in this listing.",
	listing = "That listing is unusable.",
	board = "That board is unusable.",
	flag = "That closed flag is unusable.",
})

export type Member = {
	userId: number,
	role: string,
	slot: number,
	filled: string,
}

export type Listing = {
	hostUserId: number,
	difficulty: string,
	tags: { string },
	requiredClears: number,
	partySize: number,
	slots: { string },
	gearScore: number?,
	createdAt: number,
	expiresAt: number,
	closed: boolean,
	members: { Member },
}

export type ValidateResult = {
	ok: boolean,
	listing: Listing?,
	error: string?,
}

export type OpenResult = {
	ok: boolean,
	listing: Listing?,
	error: string?,
}

export type JoinResult = {
	ok: boolean,
	allowed: boolean,
	role: string,
	slot: number?,
	filled: string?,
	listing: Listing?,
	error: string?,
}

export type DepartResult = {
	ok: boolean,
	closed: boolean,
	hostLeft: boolean,
	listing: Listing?,
	error: string?,
}

export type StatusResult = {
	ok: boolean,
	full: boolean,
	expired: boolean,
	closed: boolean,
	active: boolean,
	openCount: number,
	partySize: number,
	memberCount: number,
	error: string?,
}

type Pending = {
	userId: number,
	role: string,
}

local CONFIG = RaidPremade.CONFIG
local ERRORS = RaidPremade.ERRORS

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

local function listingSeconds(): number
	local span = CONFIG.listingSeconds
	if type(span) ~= "number" or span ~= span or span < 0 or span == math.huge then
		return 1800
	end
	return span
end

local function partyBounds(): (number, number)
	local minParty = CONFIG.minParty
	local maxParty = CONFIG.maxParty
	if type(minParty) ~= "number" then
		minParty = 4
	end
	if type(maxParty) ~= "number" then
		maxParty = 8
	end
	return minParty, maxParty
end

local function classifyDifficulty(value: any): (string?, string?)
	local name = token(value)
	if name == nil then
		return nil, ERRORS.difficulty
	end
	if RaidPremade.REFUSED[name] == true then
		return nil, ERRORS.guided
	end
	if RaidPremade.DIFFICULTIES[name] == true then
		return name, nil
	end
	return nil, ERRORS.difficulty
end

local function classifyRole(value: any): string?
	local name = token(value)
	if name == nil then
		return nil
	end
	if RaidPremade.ROLES[name] == true then
		return name
	end
	return nil
end

local function readNow(now: any): (number?, string?)
	local at = finite(now)
	if at == nil or at < 0 then
		return nil, ERRORS.time
	end
	return at, nil
end

local function readId(value: any, message: string): (number?, string?)
	local number = finite(value)
	if number == nil or number <= 0 or number ~= math.floor(number) then
		return nil, message
	end
	return number, nil
end

-- Nil becomes 0. Anything that is not a non-negative integer is unusable.
local function readClears(value: any): (number?, string?)
	if value == nil then
		return 0, nil
	end
	local number = finite(value)
	local floorMin = CONFIG.minClears
	if type(floorMin) ~= "number" then
		floorMin = 0
	end
	if number == nil or number < floorMin or number ~= math.floor(number) then
		return nil, ERRORS.clears
	end
	return number, nil
end

local function readClosed(value: any): (boolean?, string?)
	if value == nil then
		return false, nil
	end
	if type(value) == "boolean" then
		return value, nil
	end
	return nil, ERRORS.flag
end

local function readGuided(value: any): string?
	if value == nil or value == false then
		return nil
	end
	if value == true then
		return ERRORS.guided
	end
	return ERRORS.guidedFlag
end

local function readTags(value: any): ({ string }?, string?)
	local source = value
	if type(value) == "string" then
		source = { value }
	end
	if type(source) ~= "table" then
		return nil, ERRORS.tag
	end
	local tags = {}
	local seen: { [string]: boolean } = {}
	for index, entry in ipairs(source) do
		local name = token(entry)
		if name == nil then
			return nil, ERRORS.tag
		end
		if RaidPremade.TAGS[name] ~= true then
			return nil, ERRORS.tagUnknown
		end
		if seen[name] == true then
			return nil, ERRORS.tagDuplicate
		end
		seen[name] = true
		tags[index] = name
	end
	if #tags < 1 then
		return nil, ERRORS.tag
	end
	return tags, nil
end

local function readGear(value: any, difficulty: string): (number?, string?)
	if value == nil then
		return nil, nil
	end
	local number = finite(value)
	if number == nil or number < 0 or number ~= math.floor(number) then
		return nil, ERRORS.gearValue
	end
	if RaidPremade.GEAR_FREE[difficulty] == true then
		return nil, ERRORS.gear
	end
	return number, nil
end

local function readPartySize(value: any): (number?, string?)
	local number = finite(value)
	local minParty, maxParty = partyBounds()
	if number == nil or number ~= math.floor(number) or number < minParty or number > maxParty then
		return nil, ERRORS.size
	end
	return number, nil
end

local function readSlots(value: any, partySize: number): ({ string }?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.slots
	end
	if #value ~= partySize then
		return nil, ERRORS.slotCount
	end
	local slots = {}
	for index = 1, partySize do
		local role = classifyRole(value[index])
		if role == nil then
			return nil, ERRORS.role
		end
		slots[index] = role
	end
	return slots, nil
end

local function readCreated(value: any, now: number): (number?, string?)
	if value == nil then
		return nil, ERRORS.created
	end
	local at = finite(value)
	if at == nil or at < 0 then
		return nil, ERRORS.created
	end
	if at > now then
		return nil, ERRORS.clock
	end
	return at, nil
end

-- Exact role first, then a flex slot. A flex player takes the first open seat.
local function pickSlot(slots: { string }, used: { [number]: boolean }, role: string): number?
	if role ~= "flex" then
		for index, slotRole in ipairs(slots) do
			if used[index] ~= true and slotRole == role then
				return index
			end
		end
		for index, slotRole in ipairs(slots) do
			if used[index] ~= true and slotRole == "flex" then
				return index
			end
		end
		return nil
	end
	for index in ipairs(slots) do
		if used[index] ~= true then
			return index
		end
	end
	return nil
end

local function seatAll(slots: { string }, pending: { Pending }): ({ Member }?, string?)
	local used: { [number]: boolean } = {}
	local seated: { Member } = {}
	for index, member in ipairs(pending) do
		local slotIndex = pickSlot(slots, used, member.role)
		if slotIndex == nil then
			return nil, ERRORS.fit
		end
		used[slotIndex] = true
		seated[index] = {
			userId = member.userId,
			role = member.role,
			slot = slotIndex,
			filled = slots[slotIndex],
		}
	end
	return seated, nil
end

local function readMembers(
	value: any,
	hostUserId: number,
	slots: { string }
): ({ Member }?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.member
	end
	local count = #value
	if count > #slots then
		return nil, ERRORS.fit
	end
	local pending: { Pending } = {}
	local seen: { [number]: boolean } = {}
	local foundHost = false
	for index = 1, count do
		local row = value[index]
		if type(row) ~= "table" then
			return nil, ERRORS.member
		end
		local userId, userError = readId(row.userId, ERRORS.member)
		if userId == nil then
			return nil, userError
		end
		if seen[userId] == true then
			return nil, ERRORS.duplicate
		end
		seen[userId] = true
		local role = classifyRole(row.role)
		if role == nil then
			return nil, ERRORS.role
		end
		if userId == hostUserId then
			foundHost = true
		end
		pending[index] = { userId = userId, role = role }
	end
	if not foundHost then
		return nil, ERRORS.hostSeat
	end
	return seatAll(slots, pending)
end

local function readListing(draft: any, now: number): (Listing?, string?)
	if type(draft) ~= "table" then
		return nil, ERRORS.listing
	end
	local guidedError = readGuided(draft.guided)
	if guidedError ~= nil then
		return nil, guidedError
	end
	local difficulty, difficultyError = classifyDifficulty(draft.difficulty)
	if difficulty == nil then
		return nil, difficultyError or ERRORS.difficulty
	end
	local tags, tagError = readTags(draft.tags)
	if tags == nil then
		return nil, tagError or ERRORS.tag
	end
	local requiredClears, clearsError = readClears(draft.requiredClears)
	if requiredClears == nil then
		return nil, clearsError or ERRORS.clears
	end
	local gearScore, gearError = readGear(draft.gearScore, difficulty)
	if gearError ~= nil then
		return nil, gearError
	end
	local partySize, sizeError = readPartySize(draft.partySize)
	if partySize == nil then
		return nil, sizeError or ERRORS.size
	end
	local slots, slotError = readSlots(draft.slots, partySize)
	if slots == nil then
		return nil, slotError or ERRORS.slots
	end
	local hostUserId, hostError = readId(draft.hostUserId, ERRORS.host)
	if hostUserId == nil then
		return nil, hostError or ERRORS.host
	end
	local createdAt, createdError = readCreated(draft.createdAt, now)
	if createdAt == nil then
		return nil, createdError or ERRORS.created
	end
	local closed, closedError = readClosed(draft.closed)
	if closed == nil then
		return nil, closedError or ERRORS.flag
	end
	local members, memberError = readMembers(draft.members, hostUserId, slots)
	if members == nil then
		return nil, memberError or ERRORS.member
	end
	local listing: Listing = {
		hostUserId = hostUserId,
		difficulty = difficulty,
		tags = tags,
		requiredClears = requiredClears,
		partySize = partySize,
		slots = slots,
		createdAt = createdAt,
		expiresAt = createdAt + listingSeconds(),
		closed = closed,
		members = members,
	}
	if gearScore ~= nil then
		listing.gearScore = gearScore
	end
	return listing, nil
end

local function invalidListing(message: string): ValidateResult
	return { ok = false, error = message }
end

function RaidPremade.validate(draft: any, now: number): ValidateResult
	local at, timeError = readNow(now)
	if at == nil then
		return invalidListing(timeError or ERRORS.time)
	end
	local listing, why = readListing(draft, at)
	if listing == nil then
		return invalidListing(why or ERRORS.listing)
	end
	return { ok = true, listing = listing }
end

local function isExpired(listing: Listing, now: number): boolean
	return now >= listing.expiresAt
end

local function blankStatus(message: string): StatusResult
	return {
		ok = false,
		full = false,
		expired = false,
		closed = false,
		active = false,
		openCount = 0,
		partySize = 0,
		memberCount = 0,
		error = message,
	}
end

function RaidPremade.status(listing: any, now: number): StatusResult
	local checked = RaidPremade.validate(listing, now)
	if checked.ok ~= true or checked.listing == nil then
		return blankStatus(checked.error or ERRORS.listing)
	end
	local row = checked.listing
	local openCount = row.partySize - #row.members
	if openCount < 0 then
		openCount = 0
	end
	local expired = isExpired(row, now)
	local full = openCount == 0
	return {
		ok = true,
		full = full,
		expired = expired,
		closed = row.closed,
		active = row.closed ~= true and expired ~= true,
		openCount = openCount,
		partySize = row.partySize,
		memberCount = #row.members,
	}
end

local function denyJoin(message: string, role: string): JoinResult
	return {
		ok = true,
		allowed = false,
		role = role,
		error = message,
	}
end

local function invalidJoin(message: string): JoinResult
	return {
		ok = false,
		allowed = false,
		role = "",
		error = message,
	}
end

local function readPlayer(player: any): (Pending?, number?, string?)
	if type(player) ~= "table" then
		return nil, nil, ERRORS.player
	end
	local userId, userError = readId(player.userId, ERRORS.player)
	if userId == nil then
		return nil, nil, userError or ERRORS.player
	end
	local role = classifyRole(player.role)
	if role == nil then
		return nil, nil, ERRORS.role
	end
	local clears, clearsError = readClears(player.clears)
	if clears == nil then
		return nil, nil, clearsError or ERRORS.clears
	end
	return { userId = userId, role = role }, clears, nil
end

local function usedSlots(listing: Listing): { [number]: boolean }
	local used: { [number]: boolean } = {}
	for _, member in ipairs(listing.members) do
		used[member.slot] = true
	end
	return used
end

local function evaluate(listing: any, player: any, now: number): (JoinResult, Listing?, Pending?)
	local at, timeError = readNow(now)
	if at == nil then
		return invalidJoin(timeError or ERRORS.time), nil, nil
	end
	local row, why = readListing(listing, at)
	if row == nil then
		return invalidJoin(why or ERRORS.listing), nil, nil
	end
	local pending, clears, playerError = readPlayer(player)
	if pending == nil or clears == nil then
		return invalidJoin(playerError or ERRORS.player), nil, nil
	end
	if row.closed == true then
		return denyJoin(ERRORS.closed, pending.role), row, pending
	end
	if isExpired(row, at) then
		return denyJoin(ERRORS.expired, pending.role), row, pending
	end
	for _, member in ipairs(row.members) do
		if member.userId == pending.userId then
			return denyJoin(ERRORS.duplicate, pending.role), row, pending
		end
	end
	if clears < row.requiredClears then
		return denyJoin(ERRORS.short, pending.role), row, pending
	end
	local openCount = row.partySize - #row.members
	if openCount <= 0 then
		return denyJoin(ERRORS.full, pending.role), row, pending
	end
	local slotIndex = pickSlot(row.slots, usedSlots(row), pending.role)
	if slotIndex == nil then
		return denyJoin(ERRORS.slot, pending.role), row, pending
	end
	local filled = row.slots[slotIndex]
	if filled == nil then
		return denyJoin(ERRORS.slot, pending.role), row, pending
	end
	return {
		ok = true,
		allowed = true,
		role = pending.role,
		slot = slotIndex,
		filled = filled,
	},
		row,
		pending
end

function RaidPremade.canJoin(listing: any, player: any, now: number): JoinResult
	local result = evaluate(listing, player, now)
	return result
end

local function rawMembers(listing: Listing): { Pending }
	local rows: { Pending } = {}
	for index, member in ipairs(listing.members) do
		rows[index] = { userId = member.userId, role = member.role }
	end
	return rows
end

local function draftFrom(listing: Listing, members: { Pending }, closed: boolean): any
	local draft: any = {
		hostUserId = listing.hostUserId,
		difficulty = listing.difficulty,
		tags = listing.tags,
		requiredClears = listing.requiredClears,
		partySize = listing.partySize,
		slots = listing.slots,
		createdAt = listing.createdAt,
		expiresAt = listing.expiresAt,
		closed = closed,
		members = members,
	}
	if listing.gearScore ~= nil then
		draft.gearScore = listing.gearScore
	end
	return draft
end

function RaidPremade.join(listing: any, player: any, now: number): JoinResult
	local result, row, pending = evaluate(listing, player, now)
	if result.allowed ~= true or row == nil or pending == nil then
		return result
	end
	local at = readNow(now)
	if at == nil then
		return invalidJoin(ERRORS.time)
	end
	local members = rawMembers(row)
	table.insert(members, { userId = pending.userId, role = pending.role })
	local nextListing, why = readListing(draftFrom(row, members, false), at)
	if nextListing == nil then
		return invalidJoin(why or ERRORS.listing)
	end
	local seated = nextListing.members[#nextListing.members]
	if seated == nil then
		return invalidJoin(ERRORS.listing)
	end
	return {
		ok = true,
		allowed = true,
		role = pending.role,
		slot = seated.slot,
		filled = seated.filled,
		listing = nextListing,
	}
end

local function invalidDepart(message: string): DepartResult
	return {
		ok = false,
		closed = false,
		hostLeft = false,
		error = message,
	}
end

function RaidPremade.depart(listing: any, userId: any, now: number): DepartResult
	local at, timeError = readNow(now)
	if at == nil then
		return invalidDepart(timeError or ERRORS.time)
	end
	local row, why = readListing(listing, at)
	if row == nil then
		return invalidDepart(why or ERRORS.listing)
	end
	local id, idError = readId(userId, ERRORS.player)
	if id == nil then
		return invalidDepart(idError or ERRORS.player)
	end
	if row.closed == true then
		if id == row.hostUserId then
			local copy = readListing(draftFrom(row, rawMembers(row), true), at)
			if copy == nil then
				return invalidDepart(ERRORS.listing)
			end
			return {
				ok = true,
				closed = true,
				hostLeft = true,
				listing = copy,
			}
		end
		return {
			ok = false,
			closed = true,
			hostLeft = false,
			error = ERRORS.closed,
		}
	end
	local found = false
	for _, member in ipairs(row.members) do
		if member.userId == id then
			found = true
			break
		end
	end
	if not found then
		return invalidDepart(ERRORS.absent)
	end
	if id == row.hostUserId then
		local closedListing = readListing(draftFrom(row, rawMembers(row), true), at)
		if closedListing == nil then
			return invalidDepart(ERRORS.listing)
		end
		return {
			ok = true,
			closed = true,
			hostLeft = true,
			listing = closedListing,
		}
	end
	local remaining: { Pending } = {}
	for _, member in ipairs(row.members) do
		if member.userId ~= id then
			table.insert(remaining, { userId = member.userId, role = member.role })
		end
	end
	local nextListing, nextError = readListing(draftFrom(row, remaining, false), at)
	if nextListing == nil then
		return invalidDepart(nextError or ERRORS.listing)
	end
	return {
		ok = true,
		closed = false,
		hostLeft = false,
		listing = nextListing,
	}
end

function RaidPremade.open(board: any, draft: any, now: number): OpenResult
	local checked = RaidPremade.validate(draft, now)
	if checked.ok ~= true or checked.listing == nil then
		return { ok = false, error = checked.error or ERRORS.listing }
	end
	local listing = checked.listing
	if listing.closed == true then
		return { ok = false, error = ERRORS.closed }
	end
	local at = readNow(now)
	if at == nil then
		return { ok = false, error = ERRORS.time }
	end
	if isExpired(listing, at) then
		return { ok = false, error = ERRORS.expired }
	end
	if board == nil then
		return { ok = true, listing = listing }
	end
	if type(board) ~= "table" then
		return { ok = false, error = ERRORS.board }
	end
	for _, entry in ipairs(board) do
		local row, why = readListing(entry, at)
		if row == nil then
			return { ok = false, error = why or ERRORS.board }
		end
		local active = row.closed ~= true and isExpired(row, at) ~= true
		if active and row.hostUserId == listing.hostUserId then
			return { ok = false, error = ERRORS.taken }
		end
	end
	return { ok = true, listing = listing }
end

return RaidPremade
