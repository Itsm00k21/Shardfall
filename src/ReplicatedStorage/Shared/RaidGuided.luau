--!strict

--[[
	Guided Raid oath and guide score. Pure rules.

	The server passes plain tables. This module does not read players,
	grant loot, roll loot, or touch saved data, memory queues, and
	remotes. It does not read the clock. Thresholds live in CONFIG.
	Nothing here costs Robux. There is no paid skip of the oath, the
	half-guild rule, or the score.

	Guided is a mode on Hard and Shardbreaker, not its own difficulty.
	Story, Normal, Fracture, and Practice are refused. A party is 4 to
	8. The host guild must fill at least half of this run. That is half
	the roster here, not half of the whole guild. Solo Seekers fill the
	rest, one player per join. Everyone accepts the Oath of the Grove
	with one boolean before a finish counts. A counted finish awards
	CONFIG.guideScore to the host guild and scales guild raid XP by
	CONFIG.guidedPointScale. Raid marks are not multiplied.

	Kicking is refused for the whole run. An AFK removal is not a kick
	and is not decided here. The caller passes that cause. Each call
	returns a new table and does not write its input.
]]

local RaidGuided = {}

local FRACTURE = "fracture"

RaidGuided.CONFIG = table.freeze({
	-- Placeholder award for one counted finish. Not a price.
	guideScore = 1,
	-- Guild raid XP for this clear is multiplied by this. Not raid marks.
	guidedPointScale = 2,
	minParty = 4,
	maxParty = 8,
	-- Placeholder, the same cap the practice guard uses.
	maxIdLength = 64,
})

RaidGuided.DIFFICULTIES = table.freeze({
	hard = true,
	shardbreaker = true,
})

-- Guided is a mode. These ids are not Guided difficulties.
RaidGuided.REFUSED = table.freeze({
	story = true,
	normal = true,
	fracture = true,
	practice = true,
	guided = true,
})

RaidGuided.REASONS = table.freeze({
	party = "party",
	half = "half",
	oath = "oath",
	finished = "finished",
	kick = "kick",
	afk = "afk",
})

RaidGuided.ERRORS = table.freeze({
	rules = "The Guided rules are unusable.",
	state = "The Guided record is unusable.",
	open = "That Guided run is unusable.",
	difficulty = "Guided runs on Hard and Shardbreaker only.",
	practice = "Practice Grove is not a Guided Raid.",
	guild = "That host guild is unusable.",
	player = "That player is unusable.",
	user = "That player id is unusable.",
	duplicate = "That player is already in this run.",
	party = "A Guided party is 4 to 8 players.",
	full = "That Guided run is full.",
	seeker = "A Seeker joins alone, one player per join.",
	host = "Only the host guild can fill a guide slot.",
	half = "The host guild needs at least half this run.",
	oath = "Accept the Oath of the Grove with one boolean.",
	member = "That player is not in this run.",
	points = "That guild raid XP amount is unusable.",
	finish = "That finish is unusable.",
	kick = "Kicking is refused for the whole Guided run.",
	afk = "AFK removal is not a kick.",
	removal = "That removal is not a known cause.",
	finished = "This Guided run already finished.",
})

export type Member = {
	userId: number,
	guildId: string,
	seeker: boolean,
	oath: boolean,
}

export type State = {
	difficulty: string,
	hostGuildId: string,
	members: { Member },
	finished: boolean,
	guideScore: number,
	raidXp: number,
	guidedPoints: number,
}

export type OpenResult = {
	ok: boolean,
	persist: boolean,
	state: State,
	error: string?,
}

export type JoinResult = {
	ok: boolean,
	persist: boolean,
	state: State,
	userId: number,
	seeker: boolean,
	size: number,
	hosts: number,
	seekers: number,
	reason: string?,
	error: string?,
}

export type OathResult = {
	ok: boolean,
	persist: boolean,
	state: State,
	userId: number,
	oath: boolean,
	accepted: number,
	error: string?,
}

export type KickResult = {
	ok: boolean,
	persist: boolean,
	state: State,
	removed: boolean,
	kick: boolean,
	reason: string?,
	error: string?,
}

export type ReleaseResult = {
	ok: boolean,
	persist: boolean,
	state: State,
	userId: number,
	removed: boolean,
	kick: boolean,
	size: number,
	hosts: number,
	seekers: number,
	reason: string?,
	error: string?,
}

export type FinishResult = {
	ok: boolean,
	persist: boolean,
	counted: boolean,
	state: State,
	hostGuildId: string,
	guideScore: number,
	guidedPoints: number,
	guidedPointScale: number,
	raidXp: number,
	marksMultiplier: number,
	reason: string?,
	error: string?,
}

export type ViewResult = {
	ok: boolean,
	persist: boolean,
	state: State,
	difficulty: string,
	hostGuildId: string,
	size: number,
	hosts: number,
	seekers: number,
	half: number,
	accepted: number,
	ready: boolean,
	finished: boolean,
	guideScore: number,
	guidedPoints: number,
	guidedPointScale: number,
	marksMultiplier: number,
	reason: string?,
	error: string?,
}

-- Raid marks stay at one. This is not a CONFIG switch.
local MARKS_MULTIPLIER = 1

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

local function tokenOf(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = string.lower(trim(value))
	if trimmed == "" then
		return nil
	end
	return trimmed
end

local function blankState(): State
	return {
		difficulty = "",
		hostGuildId = "",
		members = {},
		finished = false,
		guideScore = 0,
		raidXp = 0,
		guidedPoints = 0,
	}
end

local function rules(): (number?, number?, number?, number?, number?, string?)
	local score = positive(RaidGuided.CONFIG.guideScore)
	local scale = positive(RaidGuided.CONFIG.guidedPointScale)
	local minParty = positive(RaidGuided.CONFIG.minParty)
	local maxParty = positive(RaidGuided.CONFIG.maxParty)
	local cap = positive(RaidGuided.CONFIG.maxIdLength)
	if score == nil or scale == nil or minParty == nil or maxParty == nil or cap == nil then
		return nil, nil, nil, nil, nil, RaidGuided.ERRORS.rules
	end
	if minParty > maxParty then
		return nil, nil, nil, nil, nil, RaidGuided.ERRORS.rules
	end
	return score, scale, minParty, maxParty, cap, nil
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

local function halfOf(size: number): number
	return math.ceil(size / 2)
end

local function copyMember(member: Member): Member
	return {
		userId = member.userId,
		guildId = member.guildId,
		seeker = member.seeker,
		oath = member.oath,
	}
end

local function copyState(state: State): State
	local members = {}
	for index, member in ipairs(state.members) do
		members[index] = copyMember(member)
	end
	return {
		difficulty = state.difficulty,
		hostGuildId = state.hostGuildId,
		members = members,
		finished = state.finished,
		guideScore = state.guideScore,
		raidXp = state.raidXp,
		guidedPoints = state.guidedPoints,
	}
end

local function counts(state: State): (number, number, number)
	local hosts = 0
	local seekers = 0
	for _, member in ipairs(state.members) do
		if member.seeker then
			seekers += 1
		else
			hosts += 1
		end
	end
	return hosts + seekers, hosts, seekers
end

local function acceptedCount(state: State): number
	local accepted = 0
	for _, member in ipairs(state.members) do
		if member.oath == true then
			accepted += 1
		end
	end
	return accepted
end

local function userIdOf(value: any): number?
	local id = whole(value)
	if id == nil or id <= 0 then
		return nil
	end
	return id
end

local function difficultyOf(value: any, cap: number): (string?, string?)
	if type(value) ~= "string" then
		return nil, RaidGuided.ERRORS.difficulty
	end
	local cleaned = string.lower(trim(value))
	if cleaned == "" or #cleaned > cap then
		return nil, RaidGuided.ERRORS.difficulty
	end
	if RaidGuided.REFUSED[cleaned] == true or string.sub(cleaned, 1, #FRACTURE) == FRACTURE then
		return nil, RaidGuided.ERRORS.difficulty
	end
	if RaidGuided.DIFFICULTIES[cleaned] ~= true then
		return nil, RaidGuided.ERRORS.difficulty
	end
	return cleaned, nil
end

local function hostGuildOf(value: any, cap: number): (string?, string?)
	if type(value) ~= "string" then
		return nil, RaidGuided.ERRORS.guild
	end
	local cleaned = trim(value)
	if cleaned == "" or #cleaned > cap then
		return nil, RaidGuided.ERRORS.guild
	end
	return cleaned, nil
end

local function memberGuildOf(value: any, cap: number): (string?, string?)
	if value == nil then
		return "", nil
	end
	if type(value) ~= "string" then
		return nil, RaidGuided.ERRORS.guild
	end
	local cleaned = trim(value)
	if #cleaned > cap then
		return nil, RaidGuided.ERRORS.guild
	end
	return cleaned, nil
end

local function seekerOf(value: any, hostGuildId: string, guildId: string): (boolean?, string?)
	local inferred = guildId ~= hostGuildId
	if value == nil then
		return inferred, nil
	end
	if type(value) ~= "boolean" then
		return nil, RaidGuided.ERRORS.seeker
	end
	if value == inferred then
		return value, nil
	end
	if inferred then
		return nil, RaidGuided.ERRORS.host
	end
	return nil, RaidGuided.ERRORS.seeker
end

local function groupPayload(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	if value[1] ~= nil then
		return true
	end
	if value.party ~= nil or value.with ~= nil or value.companions ~= nil then
		return true
	end
	return false
end

local function halfReachable(
	hosts: number,
	seekers: number,
	minParty: number,
	maxParty: number
): boolean
	local size = hosts + seekers
	if size > maxParty then
		return false
	end
	local start = if size < minParty then minParty else size
	for finalSize = start, maxParty do
		local hostsThen = hosts + (finalSize - size)
		if hostsThen >= halfOf(finalSize) then
			return true
		end
	end
	return false
end

local function removalKind(cause: any): string
	if type(cause) == "string" then
		local token = tokenOf(cause)
		if token == "afk" or token == "remove" then
			return "afk"
		end
		if token == "kick" or token == "idle" or token == "vote" then
			return "kick"
		end
		return "unknown"
	end
	if type(cause) ~= "table" then
		return "unknown"
	end
	-- Vote markers win. An AFK label cannot turn a kick into a removal.
	if cause.passed == true or cause.spentKick == true then
		return "kick"
	end
	if cause.reason ~= nil or cause.initiatorUserId ~= nil or cause.votes ~= nil then
		return "kick"
	end
	local labeled = tokenOf(cause.removal or cause.cause or cause.kind)
	if labeled == "kick" or labeled == "idle" or labeled == "vote" then
		return "kick"
	end
	if cause.state == "remove" then
		return "afk"
	end
	if labeled == "afk" or labeled == "remove" then
		return "afk"
	end
	return "unknown"
end

local function readMember(
	value: any,
	hostGuildId: string,
	cap: number,
	seen: { [number]: boolean }
): Member?
	if type(value) ~= "table" then
		return nil
	end
	local userId = userIdOf(value.userId)
	if userId == nil or seen[userId] == true then
		return nil
	end
	if type(value.guildId) ~= "string" then
		return nil
	end
	local guildId = trim(value.guildId)
	if guildId ~= value.guildId or #guildId > cap then
		return nil
	end
	if type(value.seeker) ~= "boolean" or type(value.oath) ~= "boolean" then
		return nil
	end
	if value.seeker ~= (guildId ~= hostGuildId) then
		return nil
	end
	seen[userId] = true
	return {
		userId = userId,
		guildId = guildId,
		seeker = value.seeker,
		oath = value.oath,
	}
end

local function readState(
	value: any,
	score: number,
	scale: number,
	minParty: number,
	maxParty: number,
	cap: number
): (State?, string?)
	if type(value) ~= "table" then
		return nil, RaidGuided.ERRORS.state
	end
	if type(value.difficulty) ~= "string" or RaidGuided.DIFFICULTIES[value.difficulty] ~= true then
		return nil, RaidGuided.ERRORS.state
	end
	if type(value.hostGuildId) ~= "string" then
		return nil, RaidGuided.ERRORS.state
	end
	local hostGuildId = trim(value.hostGuildId)
	if hostGuildId == "" or hostGuildId ~= value.hostGuildId or #hostGuildId > cap then
		return nil, RaidGuided.ERRORS.state
	end
	if type(value.finished) ~= "boolean" then
		return nil, RaidGuided.ERRORS.state
	end
	local guideScore = value.guideScore
	local raidXp = value.raidXp
	local guidedPoints = value.guidedPoints
	if whole(guideScore) == nil or whole(raidXp) == nil or whole(guidedPoints) == nil then
		return nil, RaidGuided.ERRORS.state
	end
	local size = arraySize(value.members)
	if size == nil or size > maxParty then
		return nil, RaidGuided.ERRORS.state
	end
	local members = {}
	local seen: { [number]: boolean } = {}
	local accepted = 0
	local hosts = 0
	for index = 1, size do
		local member = readMember(value.members[index], hostGuildId, cap, seen)
		if member == nil then
			return nil, RaidGuided.ERRORS.state
		end
		if member.oath == true then
			accepted += 1
		end
		if member.seeker ~= true then
			hosts += 1
		end
		members[index] = member
	end
	if value.finished then
		if guideScore ~= score or guidedPoints ~= raidXp * scale then
			return nil, RaidGuided.ERRORS.state
		end
		if size < minParty or size > maxParty or hosts < halfOf(size) or accepted ~= size then
			return nil, RaidGuided.ERRORS.state
		end
	elseif guideScore ~= 0 or raidXp ~= 0 or guidedPoints ~= 0 then
		return nil, RaidGuided.ERRORS.state
	end
	return {
		difficulty = value.difficulty,
		hostGuildId = hostGuildId,
		members = members,
		finished = value.finished,
		guideScore = guideScore,
		raidXp = raidXp,
		guidedPoints = guidedPoints,
	},
		nil
end

local function findMember(state: State, userId: number): Member?
	for _, member in ipairs(state.members) do
		if member.userId == userId then
			return member
		end
	end
	return nil
end

local function blockReason(state: State, minParty: number, maxParty: number): string?
	local size, hosts = counts(state)
	if size < minParty or size > maxParty then
		return RaidGuided.REASONS.party
	end
	if hosts < halfOf(size) then
		return RaidGuided.REASONS.half
	end
	if acceptedCount(state) ~= size then
		return RaidGuided.REASONS.oath
	end
	return nil
end

local function gateError(reason: string): string
	if reason == RaidGuided.REASONS.party then
		return RaidGuided.ERRORS.party
	end
	if reason == RaidGuided.REASONS.half then
		return RaidGuided.ERRORS.half
	end
	return RaidGuided.ERRORS.oath
end

local function scaledPoints(raidXp: any, scale: number): number?
	local amount = whole(raidXp)
	if amount == nil then
		return nil
	end
	local points = amount * scale
	if finite(points) == nil or points ~= math.floor(points) then
		return nil
	end
	return points
end

local function openFail(message: string): OpenResult
	return {
		ok = false,
		persist = false,
		state = blankState(),
		error = message,
	}
end

function RaidGuided.open(ctx: any, extra: any): OpenResult
	local _, _, _, _, cap, rulesError = rules()
	if cap == nil then
		return openFail(rulesError or RaidGuided.ERRORS.rules)
	end
	if extra ~= nil or type(ctx) ~= "table" then
		return openFail(RaidGuided.ERRORS.open)
	end
	if ctx.practice ~= nil and type(ctx.practice) ~= "boolean" then
		return openFail(RaidGuided.ERRORS.practice)
	end
	if ctx.practice == true then
		return openFail(RaidGuided.ERRORS.practice)
	end
	if ctx.guided ~= nil and ctx.guided ~= true then
		return openFail(RaidGuided.ERRORS.difficulty)
	end
	local difficulty, difficultyError = difficultyOf(ctx.difficulty, cap)
	if difficulty == nil then
		return openFail(difficultyError or RaidGuided.ERRORS.difficulty)
	end
	local hostGuildId, guildError = hostGuildOf(ctx.hostGuildId, cap)
	if hostGuildId == nil then
		return openFail(guildError or RaidGuided.ERRORS.guild)
	end
	return {
		ok = true,
		persist = true,
		state = {
			difficulty = difficulty,
			hostGuildId = hostGuildId,
			members = {},
			finished = false,
			guideScore = 0,
			raidXp = 0,
			guidedPoints = 0,
		},
		error = nil,
	}
end

local function joinFail(
	message: string,
	state: State,
	userId: number,
	seeker: boolean,
	reason: string?
): JoinResult
	local size, hosts, seekers = counts(state)
	return {
		ok = false,
		persist = false,
		state = state,
		userId = userId,
		seeker = seeker,
		size = size,
		hosts = hosts,
		seekers = seekers,
		reason = reason,
		error = message,
	}
end

function RaidGuided.join(state: any, player: any, extra: any): JoinResult
	local score, scale, minParty, maxParty, cap, rulesError = rules()
	if score == nil or scale == nil or minParty == nil or maxParty == nil or cap == nil then
		return joinFail(rulesError or RaidGuided.ERRORS.rules, blankState(), 0, false, nil)
	end
	local record, stateError = readState(state, score, scale, minParty, maxParty, cap)
	if record == nil then
		return joinFail(stateError or RaidGuided.ERRORS.state, blankState(), 0, false, nil)
	end
	local saved = copyState(record)
	if extra ~= nil or groupPayload(player) then
		return joinFail(RaidGuided.ERRORS.seeker, saved, 0, false, nil)
	end
	if saved.finished then
		return joinFail(RaidGuided.ERRORS.finished, saved, 0, false, nil)
	end
	if type(player) ~= "table" then
		return joinFail(RaidGuided.ERRORS.player, saved, 0, false, nil)
	end
	local userId = userIdOf(player.userId)
	if userId == nil then
		return joinFail(RaidGuided.ERRORS.user, saved, 0, false, nil)
	end
	local guildId, guildError = memberGuildOf(player.guildId, cap)
	if guildId == nil then
		return joinFail(guildError or RaidGuided.ERRORS.guild, saved, userId, false, nil)
	end
	local seeker, seekerError = seekerOf(player.seeker, saved.hostGuildId, guildId)
	if seeker == nil then
		return joinFail(seekerError or RaidGuided.ERRORS.seeker, saved, userId, false, nil)
	end
	if findMember(saved, userId) ~= nil then
		return joinFail(RaidGuided.ERRORS.duplicate, saved, userId, seeker, nil)
	end
	local size, hosts, seekers = counts(saved)
	if size + 1 > maxParty then
		return joinFail(RaidGuided.ERRORS.full, saved, userId, seeker, nil)
	end
	local nextHosts = hosts
	local nextSeekers = seekers
	if seeker then
		nextSeekers += 1
	else
		nextHosts += 1
	end
	if halfReachable(nextHosts, nextSeekers, minParty, maxParty) ~= true then
		return joinFail(RaidGuided.ERRORS.half, saved, userId, seeker, RaidGuided.REASONS.half)
	end
	local members = {}
	for index, member in ipairs(saved.members) do
		members[index] = copyMember(member)
	end
	table.insert(members, {
		userId = userId,
		guildId = guildId,
		seeker = seeker,
		oath = false,
	})
	local nextState: State = {
		difficulty = saved.difficulty,
		hostGuildId = saved.hostGuildId,
		members = members,
		finished = false,
		guideScore = 0,
		raidXp = 0,
		guidedPoints = 0,
	}
	local nextSize, nextHostCount, nextSeekerCount = counts(nextState)
	return {
		ok = true,
		persist = true,
		state = nextState,
		userId = userId,
		seeker = seeker,
		size = nextSize,
		hosts = nextHostCount,
		seekers = nextSeekerCount,
		reason = nil,
		error = nil,
	}
end

local function oathFail(message: string, state: State, userId: number, sworn: boolean): OathResult
	return {
		ok = false,
		persist = false,
		state = state,
		userId = userId,
		oath = sworn,
		accepted = acceptedCount(state),
		error = message,
	}
end

function RaidGuided.oath(state: any, userId: any, accepted: any, text: any): OathResult
	local score, scale, minParty, maxParty, cap, rulesError = rules()
	if score == nil or scale == nil or minParty == nil or maxParty == nil or cap == nil then
		return oathFail(rulesError or RaidGuided.ERRORS.rules, blankState(), 0, false)
	end
	local record, stateError = readState(state, score, scale, minParty, maxParty, cap)
	if record == nil then
		return oathFail(stateError or RaidGuided.ERRORS.state, blankState(), 0, false)
	end
	local saved = copyState(record)
	if text ~= nil or type(accepted) ~= "boolean" then
		return oathFail(RaidGuided.ERRORS.oath, saved, 0, false)
	end
	if saved.finished then
		return oathFail(RaidGuided.ERRORS.finished, saved, 0, false)
	end
	local id = userIdOf(userId)
	if id == nil then
		return oathFail(RaidGuided.ERRORS.user, saved, 0, false)
	end
	if findMember(saved, id) == nil then
		return oathFail(RaidGuided.ERRORS.member, saved, id, false)
	end
	local members = {}
	local changed = false
	for index, member in ipairs(saved.members) do
		local copy = copyMember(member)
		if copy.userId == id and copy.oath ~= accepted then
			copy.oath = accepted
			changed = true
		end
		members[index] = copy
	end
	local nextState: State = {
		difficulty = saved.difficulty,
		hostGuildId = saved.hostGuildId,
		members = members,
		finished = false,
		guideScore = 0,
		raidXp = 0,
		guidedPoints = 0,
	}
	return {
		ok = true,
		persist = changed,
		state = nextState,
		userId = id,
		oath = accepted,
		accepted = acceptedCount(nextState),
		error = nil,
	}
end

local function kickFail(message: string, state: State, reason: string?): KickResult
	return {
		ok = false,
		persist = false,
		state = state,
		removed = false,
		kick = false,
		reason = reason,
		error = message,
	}
end

function RaidGuided.kick(state: any, request: any): KickResult
	local score, scale, minParty, maxParty, cap, rulesError = rules()
	if score == nil or scale == nil or minParty == nil or maxParty == nil or cap == nil then
		return kickFail(rulesError or RaidGuided.ERRORS.rules, blankState(), nil)
	end
	local record, stateError = readState(state, score, scale, minParty, maxParty, cap)
	if record == nil then
		return kickFail(stateError or RaidGuided.ERRORS.state, blankState(), nil)
	end
	local saved = copyState(record)
	local kind = removalKind(request)
	if kind == "afk" then
		return kickFail(RaidGuided.ERRORS.afk, saved, RaidGuided.REASONS.afk)
	end
	return kickFail(RaidGuided.ERRORS.kick, saved, RaidGuided.REASONS.kick)
end

local function releaseFail(
	message: string,
	state: State,
	userId: number,
	reason: string?
): ReleaseResult
	local size, hosts, seekers = counts(state)
	return {
		ok = false,
		persist = false,
		state = state,
		userId = userId,
		removed = false,
		kick = false,
		size = size,
		hosts = hosts,
		seekers = seekers,
		reason = reason,
		error = message,
	}
end

function RaidGuided.release(state: any, userId: any, cause: any): ReleaseResult
	local score, scale, minParty, maxParty, cap, rulesError = rules()
	if score == nil or scale == nil or minParty == nil or maxParty == nil or cap == nil then
		return releaseFail(rulesError or RaidGuided.ERRORS.rules, blankState(), 0, nil)
	end
	local record, stateError = readState(state, score, scale, minParty, maxParty, cap)
	if record == nil then
		return releaseFail(stateError or RaidGuided.ERRORS.state, blankState(), 0, nil)
	end
	local saved = copyState(record)
	local kind = removalKind(cause)
	if kind == "kick" then
		return releaseFail(RaidGuided.ERRORS.kick, saved, 0, RaidGuided.REASONS.kick)
	end
	if kind ~= "afk" then
		return releaseFail(RaidGuided.ERRORS.removal, saved, 0, nil)
	end
	if saved.finished then
		return releaseFail(RaidGuided.ERRORS.finished, saved, 0, nil)
	end
	local id = userIdOf(userId)
	if id == nil then
		return releaseFail(RaidGuided.ERRORS.user, saved, 0, nil)
	end
	if findMember(saved, id) == nil then
		return releaseFail(RaidGuided.ERRORS.member, saved, id, nil)
	end
	local members = {}
	for _, member in ipairs(saved.members) do
		if member.userId ~= id then
			table.insert(members, copyMember(member))
		end
	end
	local nextState: State = {
		difficulty = saved.difficulty,
		hostGuildId = saved.hostGuildId,
		members = members,
		finished = false,
		guideScore = 0,
		raidXp = 0,
		guidedPoints = 0,
	}
	local size, hosts, seekers = counts(nextState)
	return {
		ok = true,
		persist = true,
		state = nextState,
		userId = id,
		removed = true,
		kick = false,
		size = size,
		hosts = hosts,
		seekers = seekers,
		reason = RaidGuided.REASONS.afk,
		error = nil,
	}
end

local function finishShell(
	ok: boolean,
	persist: boolean,
	counted: boolean,
	state: State,
	scale: number,
	reason: string?,
	message: string?
): FinishResult
	-- guideScore and guidedPoints on the result are the delta to add.
	-- A retry keeps the award on state and returns a zero delta.
	return {
		ok = ok,
		persist = persist,
		counted = counted,
		state = state,
		hostGuildId = state.hostGuildId,
		guideScore = if counted then state.guideScore else 0,
		guidedPoints = if counted then state.guidedPoints else 0,
		guidedPointScale = scale,
		raidXp = if counted then state.raidXp else 0,
		marksMultiplier = MARKS_MULTIPLIER,
		reason = reason,
		error = message,
	}
end

function RaidGuided.finish(state: any, raidXp: any, extra: any): FinishResult
	local score, scale, minParty, maxParty, cap, rulesError = rules()
	if score == nil or scale == nil or minParty == nil or maxParty == nil or cap == nil then
		return finishShell(
			false,
			false,
			false,
			blankState(),
			0,
			nil,
			rulesError or RaidGuided.ERRORS.rules
		)
	end
	local record, stateError = readState(state, score, scale, minParty, maxParty, cap)
	if record == nil then
		return finishShell(
			false,
			false,
			false,
			blankState(),
			scale,
			nil,
			stateError or RaidGuided.ERRORS.state
		)
	end
	local saved = copyState(record)
	if extra ~= nil then
		return finishShell(false, false, false, saved, scale, nil, RaidGuided.ERRORS.finish)
	end
	if saved.finished then
		return finishShell(true, false, false, saved, scale, RaidGuided.REASONS.finished, nil)
	end
	local blocked = blockReason(saved, minParty, maxParty)
	if blocked ~= nil then
		return finishShell(false, false, false, saved, scale, blocked, gateError(blocked))
	end
	local points = scaledPoints(raidXp, scale)
	if points == nil then
		return finishShell(false, false, false, saved, scale, nil, RaidGuided.ERRORS.points)
	end
	local amount = whole(raidXp) or 0
	local nextState = copyState(saved)
	nextState.finished = true
	nextState.guideScore = score
	nextState.raidXp = amount
	nextState.guidedPoints = points
	return finishShell(true, true, true, nextState, scale, nil, nil)
end

local function viewFail(message: string, state: State, scale: number): ViewResult
	return {
		ok = false,
		persist = false,
		state = state,
		difficulty = state.difficulty,
		hostGuildId = state.hostGuildId,
		size = 0,
		hosts = 0,
		seekers = 0,
		half = 0,
		accepted = 0,
		ready = false,
		finished = false,
		guideScore = 0,
		guidedPoints = 0,
		guidedPointScale = scale,
		marksMultiplier = MARKS_MULTIPLIER,
		reason = nil,
		error = message,
	}
end

function RaidGuided.view(state: any): ViewResult
	local score, scale, minParty, maxParty, cap, rulesError = rules()
	if score == nil or scale == nil or minParty == nil or maxParty == nil or cap == nil then
		return viewFail(rulesError or RaidGuided.ERRORS.rules, blankState(), 0)
	end
	local record, stateError = readState(state, score, scale, minParty, maxParty, cap)
	if record == nil then
		return viewFail(stateError or RaidGuided.ERRORS.state, blankState(), scale)
	end
	local saved = copyState(record)
	local size, hosts, seekers = counts(saved)
	local blocked = blockReason(saved, minParty, maxParty)
	local reason = blocked
	local ready = blocked == nil and saved.finished ~= true
	if saved.finished then
		reason = RaidGuided.REASONS.finished
		ready = false
	end
	local half = 0
	if size > 0 then
		half = halfOf(size)
	end
	return {
		ok = true,
		persist = false,
		state = saved,
		difficulty = saved.difficulty,
		hostGuildId = saved.hostGuildId,
		size = size,
		hosts = hosts,
		seekers = seekers,
		half = half,
		accepted = acceptedCount(saved),
		ready = ready,
		finished = saved.finished,
		guideScore = saved.guideScore,
		guidedPoints = saved.guidedPoints,
		guidedPointScale = scale,
		marksMultiplier = MARKS_MULTIPLIER,
		reason = reason,
		error = nil,
	}
end

return RaidGuided
