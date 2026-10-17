--!strict

--[[
	Raid conduct. AFK warnings and vote-kick rules.

	The server passes plain tables and the current time. This module does
	not read players, grant loot, roll queues, or touch DataStores and
	remotes. Thresholds live in CONFIG. Nothing here costs Robux.

	AFK: no input for warnSeconds outside a cutscene is a warning. At
	removeSeconds the player is removed, rewards not yet granted are
	forfeited, and a backfill is flagged. Combat does not pause the clock.
	Call again after the warning; this does not remember that it already
	warned.

	Vote-kick: ceil(3/4) of the whole group must vote yes, and the target
	does not vote. A reason is required. Closed during a Guided Raid,
	during combat, for the first voteLockSeconds of the raid, and for
	voteLockSeconds after the target's joinedAt when that field is set.
	Opening a vote spends the initiator's one kick for that UTC day.
	Resolving a vote never forfeits Marks. An idle reason drops queue
	priority only when the vote passes.
]]

local RaidConduct = {}

RaidConduct.CONFIG = table.freeze({
	warnSeconds = 60,
	removeSeconds = 90,
	voteLockSeconds = 120,
	voteNumerator = 3,
	voteDenominator = 4,
	kicksPerDay = 1,
	daySeconds = 86400,
	maxReasonLength = 80,
})

RaidConduct.IDLE_REASONS = table.freeze({
	idle = true,
	afk = true,
})

RaidConduct.ERRORS = table.freeze({
	time = "Raid time is missing.",
	afkTime = "AFK check is missing a time.",
	guided = "Kicking is disabled in a Guided Raid.",
	combat = "Vote-kick is closed during combat.",
	early = "Vote-kick is closed for the first 2 minutes.",
	joined = "Vote-kick is closed for a player who just joined.",
	initiator = "You are not in this raid.",
	target = "That player is not in this raid.",
	selfKick = "You cannot kick yourself.",
	short = "Not enough players to reach a vote.",
	reason = "A reason is required.",
	reasonLong = "That reason is too long.",
	daily = "You already used your kick today.",
})

export type AfkState = "ok" | "warning" | "remove" | "paused" | "invalid"

export type AfkInput = {
	now: number,
	lastInputAt: number,
	inCutscene: boolean?,
}

export type AfkResult = {
	ok: boolean,
	state: AfkState,
	idleSeconds: number,
	forfeitRewards: boolean,
	queueBackfill: boolean,
	keepMarks: boolean,
	error: string?,
}

export type Member = number | {
	userId: number,
	joinedAt: number?,
}

export type VoteRequest = {
	now: number,
	raidStartedAt: number,
	inCombat: boolean?,
	guided: boolean?,
	initiatorUserId: number,
	targetUserId: number,
	reason: any,
	members: { Member },
	votes: { [number]: boolean }?,
	kickDay: number?,
	kickCount: number?,
}

export type VoteResult = {
	ok: boolean,
	passed: boolean,
	spentKick: boolean,
	needed: number,
	yesCount: number,
	eligible: number,
	groupSize: number,
	keepMarks: boolean,
	dropQueuePriority: boolean,
	forfeitRewards: boolean,
	queueBackfill: boolean,
	kickDay: number,
	kickCount: number,
	error: string?,
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

local function echoNumber(value: any): number
	local number = finite(value)
	if number == nil then
		return 0
	end
	return number
end

local function userId(value: any): number?
	local id = finite(value)
	if id == nil or id <= 0 or id ~= math.floor(id) then
		return nil
	end
	return id
end

function RaidConduct.dayNumber(now: number): number?
	local at = finite(now)
	if at == nil or at < 0 then
		return nil
	end
	return math.floor(at / RaidConduct.CONFIG.daySeconds)
end

-- ceil(groupSize * 3/4). The target is included in the group size and
-- cannot vote, so a group smaller than 4 can never reach it.
function RaidConduct.votesNeeded(groupSize: number): number
	local size = finite(groupSize)
	if size == nil or size < 1 then
		return 0
	end
	local whole = math.floor(size)
	local numerator = RaidConduct.CONFIG.voteNumerator
	local denominator = RaidConduct.CONFIG.voteDenominator
	if
		type(numerator) ~= "number"
		or type(denominator) ~= "number"
		or denominator < 1
		or numerator < 1
	then
		return whole
	end
	return (whole * numerator + denominator - 1) // denominator
end

function RaidConduct.normalizeReason(reason: any): (string?, boolean)
	if type(reason) ~= "string" then
		return nil, false
	end
	local trimmed = trim(reason)
	if trimmed == "" or #trimmed > RaidConduct.CONFIG.maxReasonLength then
		return nil, false
	end
	local idle = RaidConduct.IDLE_REASONS[string.lower(trimmed)] == true
	return trimmed, idle
end

local function afkResult(
	ok: boolean,
	state: AfkState,
	idleSeconds: number,
	forfeitRewards: boolean,
	queueBackfill: boolean,
	keepMarks: boolean,
	message: string?
): AfkResult
	return {
		ok = ok,
		state = state,
		idleSeconds = idleSeconds,
		forfeitRewards = forfeitRewards,
		queueBackfill = queueBackfill,
		keepMarks = keepMarks,
		error = message,
	}
end

function RaidConduct.afk(input: AfkInput?): AfkResult
	if type(input) ~= "table" then
		return afkResult(false, "invalid", 0, false, false, true, RaidConduct.ERRORS.afkTime)
	end
	local now = finite(input.now)
	local lastInputAt = finite(input.lastInputAt)
	if now == nil or lastInputAt == nil then
		return afkResult(false, "invalid", 0, false, false, true, RaidConduct.ERRORS.afkTime)
	end
	local idle = now - lastInputAt
	if idle < 0 then
		idle = 0
	end
	if input.inCutscene == true then
		return afkResult(true, "paused", idle, false, false, true, nil)
	end
	if idle >= RaidConduct.CONFIG.removeSeconds then
		return afkResult(true, "remove", idle, true, true, false, nil)
	end
	if idle >= RaidConduct.CONFIG.warnSeconds then
		return afkResult(true, "warning", idle, false, false, true, nil)
	end
	return afkResult(true, "ok", idle, false, false, true, nil)
end

type Roster = {
	ids: { number },
	joinedAt: { [number]: number },
	size: number,
}

local function rosterOf(members: any): Roster
	local ids = {}
	local seen: { [number]: boolean } = {}
	local joinedAt: { [number]: number } = {}
	if type(members) == "table" then
		for _, entry in ipairs(members) do
			local rawId = entry
			local rawJoined = nil
			if type(entry) == "table" then
				rawId = entry.userId
				rawJoined = entry.joinedAt
			end
			local id = userId(rawId)
			if id ~= nil and seen[id] ~= true then
				seen[id] = true
				table.insert(ids, id)
				local at = finite(rawJoined)
				if at ~= nil then
					joinedAt[id] = at
				end
			end
		end
	end
	return {
		ids = ids,
		joinedAt = joinedAt,
		size = #ids,
	}
end

local function voteShell(request: any): VoteResult
	local kickDay = 0
	local kickCount = 0
	if type(request) == "table" then
		kickDay = echoNumber(request.kickDay)
		kickCount = echoNumber(request.kickCount)
	end
	return {
		ok = false,
		passed = false,
		spentKick = false,
		needed = 0,
		yesCount = 0,
		eligible = 0,
		groupSize = 0,
		keepMarks = true,
		dropQueuePriority = false,
		forfeitRewards = false,
		queueBackfill = false,
		kickDay = kickDay,
		kickCount = kickCount,
		error = nil,
	}
end

local function fail(request: any, message: string, roster: Roster?): VoteResult
	local result = voteShell(request)
	result.error = message
	if roster ~= nil then
		result.groupSize = roster.size
		result.needed = RaidConduct.votesNeeded(roster.size)
		result.eligible = math.max(0, roster.size - 1)
	end
	return result
end

local function reasonMessage(reason: any): (string?, string?, boolean)
	if type(reason) ~= "string" then
		return RaidConduct.ERRORS.reason, nil, false
	end
	local trimmed = trim(reason)
	if trimmed == "" then
		return RaidConduct.ERRORS.reason, nil, false
	end
	if #trimmed > RaidConduct.CONFIG.maxReasonLength then
		return RaidConduct.ERRORS.reasonLong, nil, false
	end
	local text, idle = RaidConduct.normalizeReason(trimmed)
	return nil, text, idle
end

-- Nil means the stored counter is corrupt and the kick must be refused.
local function usedKicks(request: any, today: number): number?
	if type(request) ~= "table" then
		return 0
	end
	if request.kickDay ~= nil and finite(request.kickDay) == nil then
		return nil
	end
	if request.kickCount ~= nil and finite(request.kickCount) == nil then
		return nil
	end
	local day = finite(request.kickDay)
	if day == nil or day ~= today then
		return 0
	end
	local count = finite(request.kickCount)
	if count == nil or count < 0 then
		return 0
	end
	return math.floor(count)
end

type Prepared = {
	roster: Roster,
	needed: number,
	eligible: number,
	targetId: number,
	idle: boolean,
	today: number,
}

local function prepare(request: any): (Prepared?, VoteResult?)
	if type(request) ~= "table" then
		return nil, fail(request, RaidConduct.ERRORS.time, nil)
	end
	local now = finite(request.now)
	local startedAt = finite(request.raidStartedAt)
	local today = if now ~= nil then RaidConduct.dayNumber(now) else nil
	if now == nil or startedAt == nil or today == nil then
		return nil, fail(request, RaidConduct.ERRORS.time, nil)
	end
	local roster = rosterOf(request.members)
	if request.guided == true then
		return nil, fail(request, RaidConduct.ERRORS.guided, roster)
	end
	if request.inCombat == true then
		return nil, fail(request, RaidConduct.ERRORS.combat, roster)
	end
	if now < startedAt + RaidConduct.CONFIG.voteLockSeconds then
		return nil, fail(request, RaidConduct.ERRORS.early, roster)
	end
	local initiatorId = userId(request.initiatorUserId)
	local targetId = userId(request.targetUserId)
	local present: { [number]: boolean } = {}
	for _, id in ipairs(roster.ids) do
		present[id] = true
	end
	if initiatorId == nil or present[initiatorId] ~= true then
		return nil, fail(request, RaidConduct.ERRORS.initiator, roster)
	end
	if targetId == nil or present[targetId] ~= true then
		return nil, fail(request, RaidConduct.ERRORS.target, roster)
	end
	if initiatorId == targetId then
		return nil, fail(request, RaidConduct.ERRORS.selfKick, roster)
	end
	local joinedAt = roster.joinedAt[targetId]
	if joinedAt ~= nil and now < joinedAt + RaidConduct.CONFIG.voteLockSeconds then
		return nil, fail(request, RaidConduct.ERRORS.joined, roster)
	end
	local needed = RaidConduct.votesNeeded(roster.size)
	local eligible = roster.size - 1
	if needed <= 0 or needed > eligible then
		return nil, fail(request, RaidConduct.ERRORS.short, roster)
	end
	local why, text, idle = reasonMessage(request.reason)
	if why ~= nil or text == nil then
		return nil, fail(request, why or RaidConduct.ERRORS.reason, roster)
	end
	return {
		roster = roster,
		needed = needed,
		eligible = eligible,
		targetId = targetId,
		idle = idle,
		today = today,
	},
		nil
end

local function countYes(votes: any, roster: Roster, targetId: number): number
	if type(votes) ~= "table" then
		return 0
	end
	local yes = 0
	for _, id in ipairs(roster.ids) do
		if id ~= targetId and votes[id] == true then
			yes += 1
		end
	end
	return yes
end

function RaidConduct.openVote(request: VoteRequest?): VoteResult
	local prepared, blocked = prepare(request)
	if prepared == nil then
		if blocked ~= nil then
			return blocked
		end
		return fail(request, RaidConduct.ERRORS.time, nil)
	end
	local used = usedKicks(request, prepared.today)
	if used == nil or used >= RaidConduct.CONFIG.kicksPerDay then
		return fail(request, RaidConduct.ERRORS.daily, prepared.roster)
	end
	local opened = voteShell(request)
	opened.ok = true
	opened.passed = false
	opened.spentKick = true
	opened.needed = prepared.needed
	opened.eligible = prepared.eligible
	opened.groupSize = prepared.roster.size
	opened.kickDay = prepared.today
	opened.kickCount = used + 1
	opened.keepMarks = true
	opened.dropQueuePriority = false
	opened.forfeitRewards = false
	opened.queueBackfill = false
	return opened
end

function RaidConduct.tally(request: VoteRequest?): VoteResult
	local prepared, blocked = prepare(request)
	if prepared == nil then
		if blocked ~= nil then
			return blocked
		end
		return fail(request, RaidConduct.ERRORS.time, nil)
	end
	local ballots = nil
	if type(request) == "table" then
		ballots = request.votes
	end
	local yes = countYes(ballots, prepared.roster, prepared.targetId)
	local passed = yes >= prepared.needed
	local result = voteShell(request)
	result.ok = true
	result.passed = passed
	result.spentKick = false
	result.needed = prepared.needed
	result.yesCount = yes
	result.eligible = prepared.eligible
	result.groupSize = prepared.roster.size
	result.keepMarks = true
	result.forfeitRewards = false
	result.queueBackfill = false
	result.dropQueuePriority = passed and prepared.idle
	return result
end

return RaidConduct
