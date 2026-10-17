--!strict

--[[
	Raid leaderboard. Fastest clear per difficulty and party size.

	The server passes plain tables. This module does not read players,
	roll loot, filter text, or touch DataStores, MemoryStore, and remotes.
	It does not require RaidConduct, Raids, or RaidRecap. It has no RNG.
	Thresholds live in CONFIG. Nothing here costs Robux.

	Beta keeps Normal live and Story off. Hard and Shardbreaker are
	known and off. A clear under floorSeconds is refused. Practice is
	refused. The same runId already on the board is a no-op.

	Credit skips an AFK removal and a passed vote-kick. Pass removal
	"afk", the string "remove", or the RaidConduct.afk result whose
	state is "remove". Pass "kick", or a tally whose passed is true.
	Sort by duration, then earlier clear, then lower runId. Trim to topN.
]]

local RaidLeaderboard = {}

RaidLeaderboard.CONFIG = table.freeze({
	topN = 10,
	-- Placeholder. A full clear is designed at 20–30 minutes. This floor
	-- only rejects a clear that is too fast to be a real Heartwood run.
	floorSeconds = 300,
	minParty = 4,
	maxParty = 8,
	live = table.freeze({
		normal = true,
	}),
})

-- Story is known and switched off. Fracture is not a fastest-clear board.
RaidLeaderboard.DIFFICULTIES = table.freeze({
	story = true,
	normal = true,
	hard = true,
	shardbreaker = true,
})

RaidLeaderboard.REMOVALS = table.freeze({
	afk = true,
	kick = true,
})

-- RaidConduct.afk uses this state when the 90s removal fires.
RaidLeaderboard.AFK_STATE = "remove"

RaidLeaderboard.PRESENT_STATES = table.freeze({
	ok = true,
	warning = true,
	paused = true,
})

RaidLeaderboard.ERRORS = table.freeze({
	board = "That leaderboard is unusable.",
	record = "That clear is unusable.",
	runId = "That run id is unusable.",
	practice = "Practice runs are not ranked.",
	practiceFlag = "That practice flag is unusable.",
	difficulty = "That difficulty has no leaderboard.",
	disabled = "That leaderboard is not live.",
	time = "That clear time is unusable.",
	floor = "That clear is under the sanity floor.",
	size = "A ranked clear needs 4 to 8 players.",
	sizeMatch = "That party size does not match the roster.",
	roster = "That roster is unusable.",
	userId = "That player id is unusable.",
	duplicate = "That player is listed twice.",
	removal = "That removal is not a known cause.",
	removalTwice = "That removal is listed twice.",
	absent = "That removal is not on the roster.",
	empty = "Nobody from that roster finished the clear.",
	key = "Name the difficulty and the party size.",
})

export type RunId = number | string

export type Entry = {
	runId: RunId,
	difficulty: string,
	size: number,
	duration: number,
	clearedAt: number?,
	roster: { number },
}

export type Board = {
	entries: { Entry },
}

export type SubmitResult = {
	ok: boolean,
	accepted: boolean,
	duplicate: boolean,
	trimmed: boolean,
	board: Board,
	entry: Entry?,
	error: string?,
}

export type BestResult = {
	ok: boolean,
	found: boolean,
	entry: Entry?,
	error: string?,
}

export type RankResult = {
	ok: boolean,
	found: boolean,
	rank: number?,
	difficulty: string?,
	size: number?,
	entry: Entry?,
	error: string?,
}

local CONFIG = RaidLeaderboard.CONFIG

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

local function whole(value: any): number?
	local number = finite(value)
	if number == nil or number < 0 or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function userIdOf(value: any): number?
	local id = whole(value)
	if id == nil or id <= 0 then
		return nil
	end
	return id
end

local function dense(value: { any }): boolean
	local count = 0
	local maxIndex = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
			return false
		end
		count += 1
		if key > maxIndex then
			maxIndex = key
		end
	end
	return count == maxIndex
end

local function topN(): number
	local value = whole(CONFIG.topN)
	if value == nil or value < 1 then
		return 10
	end
	return value
end

local function floorSeconds(): number
	local value = finite(CONFIG.floorSeconds)
	if value == nil or value < 0 then
		return 300
	end
	return value
end

local function partyBounds(): (number, number)
	local minParty = whole(CONFIG.minParty)
	local maxParty = whole(CONFIG.maxParty)
	if minParty == nil or minParty < 1 then
		minParty = 4
	end
	if maxParty == nil or maxParty < minParty then
		maxParty = 8
	end
	return minParty, maxParty
end

local function isLive(difficulty: string): boolean
	local live = CONFIG.live
	if type(live) ~= "table" then
		return difficulty == "normal"
	end
	return live[difficulty] == true
end

local function readRunId(value: any): (RunId?, string?)
	if type(value) == "number" then
		local id = whole(value)
		if id == nil or id <= 0 then
			return nil, RaidLeaderboard.ERRORS.runId
		end
		return id, nil
	end
	if type(value) ~= "string" then
		return nil, RaidLeaderboard.ERRORS.runId
	end
	local trimmed = trim(value)
	if trimmed == "" then
		return nil, RaidLeaderboard.ERRORS.runId
	end
	return trimmed, nil
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

local function runIdBefore(left: RunId, right: RunId): boolean
	local leftNumber = type(left) == "number"
	local rightNumber = type(right) == "number"
	if leftNumber ~= rightNumber then
		return leftNumber
	end
	return left < right
end

local function before(left: Entry, right: Entry): boolean
	if left.duration ~= right.duration then
		return left.duration < right.duration
	end
	local leftAt = left.clearedAt
	local rightAt = right.clearedAt
	if leftAt ~= rightAt then
		if leftAt == nil then
			return false
		end
		if rightAt == nil then
			return true
		end
		return leftAt < rightAt
	end
	return runIdBefore(left.runId, right.runId)
end

local function canonical(left: Entry, right: Entry): boolean
	if left.difficulty ~= right.difficulty then
		return left.difficulty < right.difficulty
	end
	if left.size ~= right.size then
		return left.size < right.size
	end
	return before(left, right)
end

local function copyEntry(entry: Entry): Entry
	local copy: Entry = {
		runId = entry.runId,
		difficulty = entry.difficulty,
		size = entry.size,
		duration = entry.duration,
		roster = table.clone(entry.roster),
	}
	if entry.clearedAt ~= nil then
		copy.clearedAt = entry.clearedAt
	end
	return copy
end

local function blank(): Board
	return { entries = {} }
end

local function publish(entries: { Entry }): Board
	local list: { Entry } = {}
	for _, entry in ipairs(entries) do
		table.insert(list, copyEntry(entry))
	end
	table.sort(list, canonical)
	return { entries = list }
end

-- "" means the player stayed. "afk" and "kick" are left off the row.
-- nil plus a message is a bad cause.
local function readRemoval(value: any): (string?, string?)
	if value == nil then
		return "", nil
	end
	if type(value) == "table" then
		if value.ok ~= nil and type(value.ok) ~= "boolean" then
			return nil, RaidLeaderboard.ERRORS.removal
		end
		if value.ok == false then
			return nil, RaidLeaderboard.ERRORS.removal
		end
		if value.passed ~= nil and type(value.passed) ~= "boolean" then
			return nil, RaidLeaderboard.ERRORS.removal
		end
		local state = nil
		if value.state ~= nil then
			state = token(value.state)
			if state == nil then
				return nil, RaidLeaderboard.ERRORS.removal
			end
		end
		if state == RaidLeaderboard.AFK_STATE then
			return "afk", nil
		end
		if state ~= nil and RaidLeaderboard.PRESENT_STATES[state] ~= true then
			return nil, RaidLeaderboard.ERRORS.removal
		end
		if value.passed == true then
			return "kick", nil
		end
		if state == nil and value.passed == nil then
			return nil, RaidLeaderboard.ERRORS.removal
		end
		return "", nil
	end
	local name = token(value)
	if name == RaidLeaderboard.AFK_STATE then
		return "afk", nil
	end
	if name ~= nil and RaidLeaderboard.REMOVALS[name] == true then
		return name, nil
	end
	return nil, RaidLeaderboard.ERRORS.removal
end

local function readIdList(value: any): ({ number }?, string?)
	if type(value) ~= "table" or not dense(value) then
		return nil, RaidLeaderboard.ERRORS.roster
	end
	local list: { number } = {}
	local seen: { [number]: boolean } = {}
	for _, raw in ipairs(value) do
		local id = nil
		if type(raw) == "table" then
			id = userIdOf(raw.userId)
			if id == nil then
				return nil, RaidLeaderboard.ERRORS.userId
			end
		elseif type(raw) == "number" then
			id = userIdOf(raw)
			if id == nil then
				return nil, RaidLeaderboard.ERRORS.userId
			end
		else
			return nil, RaidLeaderboard.ERRORS.roster
		end
		if seen[id] == true then
			return nil, RaidLeaderboard.ERRORS.duplicate
		end
		seen[id] = true
		table.insert(list, id)
	end
	return list, nil
end

local function hasUserField(value: any): boolean
	return type(value) == "table" and value.userId ~= nil
end

local function removalKind(value: { any }): (string?, string?)
	if next(value) == nil then
		return "empty", nil
	end
	if not dense(value) then
		return "map", nil
	end
	local sawUser = false
	local sawPlain = false
	for _, item in ipairs(value) do
		if hasUserField(item) then
			sawUser = true
		else
			sawPlain = true
		end
	end
	if sawUser and sawPlain then
		return nil, RaidLeaderboard.ERRORS.removal
	end
	if sawUser then
		return "list", nil
	end
	return "map", nil
end

local function excludeCause(cause: string): boolean
	return cause == "afk" or cause == "kick"
end

local function readRemovalItem(entry: any): (number?, string?, string?)
	if type(entry) ~= "table" then
		return nil, nil, RaidLeaderboard.ERRORS.removal
	end
	local id = userIdOf(entry.userId)
	if id == nil then
		return nil, nil, RaidLeaderboard.ERRORS.userId
	end
	local raw = entry.removal
	if raw == nil then
		raw = entry.cause
	elseif entry.cause ~= nil then
		local left, leftErr = readRemoval(entry.removal)
		local right, rightErr = readRemoval(entry.cause)
		if left == nil or right == nil or left ~= right then
			return nil, nil, leftErr or rightErr or RaidLeaderboard.ERRORS.removal
		end
	end
	if raw == nil and (entry.state ~= nil or entry.passed ~= nil or entry.ok ~= nil) then
		raw = entry
	end
	if raw == nil then
		return nil, nil, RaidLeaderboard.ERRORS.removal
	end
	local cause, causeErr = readRemoval(raw)
	if cause == nil then
		return nil, nil, causeErr or RaidLeaderboard.ERRORS.removal
	end
	return id, cause, nil
end

local function markExcluded(
	excluded: { [number]: boolean },
	present: { [number]: boolean },
	id: number,
	cause: string
): string?
	if present[id] ~= true then
		return RaidLeaderboard.ERRORS.absent
	end
	if excluded[id] ~= nil then
		return RaidLeaderboard.ERRORS.removalTwice
	end
	excluded[id] = excludeCause(cause)
	return nil
end

local function readRemovals(
	value: any,
	present: { [number]: boolean }
): ({ [number]: boolean }?, string?)
	local excluded: { [number]: boolean } = {}
	if value == nil then
		return excluded, nil
	end
	if type(value) ~= "table" then
		return nil, RaidLeaderboard.ERRORS.removal
	end
	local kind, kindErr = removalKind(value)
	if kind == nil then
		return nil, kindErr or RaidLeaderboard.ERRORS.removal
	end
	if kind == "empty" then
		return excluded, nil
	end
	if kind == "list" then
		for _, item in ipairs(value) do
			local id, cause, itemErr = readRemovalItem(item)
			if id == nil or cause == nil then
				return nil, itemErr or RaidLeaderboard.ERRORS.removal
			end
			local marked = markExcluded(excluded, present, id, cause)
			if marked ~= nil then
				return nil, marked
			end
		end
		return excluded, nil
	end
	for key, raw in pairs(value) do
		local id = nil
		if type(key) == "number" then
			id = userIdOf(key)
		end
		if id == nil then
			return nil, RaidLeaderboard.ERRORS.userId
		end
		if type(raw) == "table" and raw.userId ~= nil and userIdOf(raw.userId) ~= id then
			return nil, RaidLeaderboard.ERRORS.removal
		end
		local cause, causeErr = readRemoval(raw)
		if cause == nil then
			return nil, causeErr or RaidLeaderboard.ERRORS.removal
		end
		local marked = markExcluded(excluded, present, id, cause)
		if marked ~= nil then
			return nil, marked
		end
	end
	return excluded, nil
end

local function readOptionalInstant(value: any): (number?, string?)
	if value == nil then
		return nil, nil
	end
	local number = finite(value)
	if number == nil or number < 0 then
		return nil, RaidLeaderboard.ERRORS.time
	end
	return number, nil
end

local function oneInstant(primary: any, alias: any): (number?, string?)
	local first, firstErr = readOptionalInstant(primary)
	if firstErr ~= nil then
		return nil, firstErr
	end
	local second, secondErr = readOptionalInstant(alias)
	if secondErr ~= nil then
		return nil, secondErr
	end
	if first ~= nil and second ~= nil and first ~= second then
		return nil, RaidLeaderboard.ERRORS.time
	end
	if first ~= nil then
		return first, nil
	end
	return second, nil
end

local function readDuration(value: any): (number?, string?)
	if value == nil then
		return nil, nil
	end
	local number = finite(value)
	if number == nil or number < 0 then
		return nil, RaidLeaderboard.ERRORS.time
	end
	return number, nil
end

local function readClock(record: { [string]: any }): (number?, number?, string?)
	local startAt, startErr = oneInstant(record.start, record.startedAt)
	if startErr ~= nil then
		return nil, nil, startErr
	end
	local endAt, endErr = oneInstant(record["end"], record.endedAt)
	if endErr ~= nil then
		return nil, nil, endErr
	end
	local duration, durationErr = readDuration(record.duration)
	if durationErr ~= nil then
		return nil, nil, durationErr
	end
	local length = nil
	local clearedAt = nil
	if startAt ~= nil and endAt ~= nil then
		if endAt < startAt then
			return nil, nil, RaidLeaderboard.ERRORS.time
		end
		local computed = endAt - startAt
		if duration ~= nil and duration ~= computed then
			return nil, nil, RaidLeaderboard.ERRORS.time
		end
		length = computed
		clearedAt = endAt
	elseif startAt ~= nil or (endAt ~= nil and duration == nil) then
		return nil, nil, RaidLeaderboard.ERRORS.time
	elseif duration == nil then
		return nil, nil, RaidLeaderboard.ERRORS.time
	else
		length = duration
		clearedAt = endAt
	end
	if length <= 0 then
		return nil, nil, RaidLeaderboard.ERRORS.time
	end
	if length < floorSeconds() then
		return nil, nil, RaidLeaderboard.ERRORS.floor
	end
	return length, clearedAt, nil
end

local function readSize(value: any): (number?, string?)
	if value == nil then
		return nil, nil
	end
	local size = whole(value)
	local minParty, maxParty = partyBounds()
	if size == nil or size < minParty or size > maxParty then
		return nil, RaidLeaderboard.ERRORS.size
	end
	return size, nil
end

local function readPractice(value: any): (boolean?, string?)
	if value == nil then
		return false, nil
	end
	if type(value) ~= "boolean" then
		return nil, RaidLeaderboard.ERRORS.practiceFlag
	end
	return value, nil
end

local function readDifficulty(value: any): (string?, string?)
	local name = token(value)
	if name == nil or RaidLeaderboard.DIFFICULTIES[name] ~= true then
		return nil, RaidLeaderboard.ERRORS.difficulty
	end
	if not isLive(name) then
		return nil, RaidLeaderboard.ERRORS.disabled
	end
	return name, nil
end

local function hasRun(entries: { Entry }, id: RunId): boolean
	for _, entry in ipairs(entries) do
		if sameRun(entry.runId, id) then
			return true
		end
	end
	return false
end

local function readStoredRoster(value: any): ({ number }?, string?)
	local roster, rosterErr = readIdList(value)
	if roster == nil then
		return nil, rosterErr or RaidLeaderboard.ERRORS.board
	end
	table.sort(roster)
	return roster, nil
end

local function readStoredEntry(value: any, seen: { [string]: boolean }): (Entry?, string?)
	if type(value) ~= "table" then
		return nil, RaidLeaderboard.ERRORS.board
	end
	local runId = readRunId(value.runId)
	if runId == nil then
		return nil, RaidLeaderboard.ERRORS.board
	end
	local key = runKey(runId)
	if seen[key] == true then
		return nil, RaidLeaderboard.ERRORS.board
	end
	local difficulty = token(value.difficulty)
	if difficulty == nil or RaidLeaderboard.DIFFICULTIES[difficulty] ~= true then
		return nil, RaidLeaderboard.ERRORS.board
	end
	local size = whole(value.size)
	local minParty, maxParty = partyBounds()
	if size == nil or size < minParty or size > maxParty then
		return nil, RaidLeaderboard.ERRORS.board
	end
	local duration = finite(value.duration)
	if duration == nil or duration <= 0 then
		return nil, RaidLeaderboard.ERRORS.board
	end
	local clearedAt = nil
	if value.clearedAt ~= nil then
		local at = finite(value.clearedAt)
		if at == nil or at < 0 then
			return nil, RaidLeaderboard.ERRORS.board
		end
		clearedAt = at
	end
	local roster = readStoredRoster(value.roster)
	if roster == nil or #roster == 0 or #roster > size then
		return nil, RaidLeaderboard.ERRORS.board
	end
	seen[key] = true
	local entry: Entry = {
		runId = runId,
		difficulty = difficulty,
		size = size,
		duration = duration,
		roster = roster,
	}
	if clearedAt ~= nil then
		entry.clearedAt = clearedAt
	end
	return entry, nil
end

local function readBoard(board: any): ({ Entry }?, string?)
	if board == nil then
		return {}, nil
	end
	if type(board) ~= "table" then
		return nil, RaidLeaderboard.ERRORS.board
	end
	local entries = board.entries
	if entries == nil then
		if board[1] ~= nil then
			return nil, RaidLeaderboard.ERRORS.board
		end
		return {}, nil
	end
	if type(entries) ~= "table" or not dense(entries) then
		return nil, RaidLeaderboard.ERRORS.board
	end
	local list: { Entry } = {}
	local seen: { [string]: boolean } = {}
	for _, raw in ipairs(entries) do
		local entry, entryErr = readStoredEntry(raw, seen)
		if entry == nil then
			return nil, entryErr or RaidLeaderboard.ERRORS.board
		end
		table.insert(list, entry)
	end
	return list, nil
end

local function failSubmit(board: Board, message: string): SubmitResult
	return {
		ok = false,
		accepted = false,
		duplicate = false,
		trimmed = false,
		board = board,
		error = message,
	}
end

local function insertEntry(entries: { Entry }, incoming: Entry): (boolean, { Entry })
	local nextEntries: { Entry } = {}
	local bucket: { Entry } = {}
	for _, entry in ipairs(entries) do
		if entry.difficulty == incoming.difficulty and entry.size == incoming.size then
			table.insert(bucket, entry)
		else
			table.insert(nextEntries, entry)
		end
	end
	table.insert(bucket, incoming)
	table.sort(bucket, before)
	local limit = topN()
	local placed = false
	for index, entry in ipairs(bucket) do
		if index <= limit then
			table.insert(nextEntries, entry)
			if entry == incoming then
				placed = true
			end
		end
	end
	return placed, nextEntries
end

local function buildEntry(record: { [string]: any }, entries: { Entry }): (Entry?, string?, boolean)
	local runId, runErr = readRunId(record.runId)
	if runId == nil then
		return nil, runErr or RaidLeaderboard.ERRORS.runId, false
	end
	if hasRun(entries, runId) then
		return nil, nil, true
	end
	local practice, practiceErr = readPractice(record.practice)
	if practice == nil then
		return nil, practiceErr or RaidLeaderboard.ERRORS.practiceFlag, false
	end
	if practice then
		return nil, RaidLeaderboard.ERRORS.practice, false
	end
	local difficulty, difficultyErr = readDifficulty(record.difficulty)
	if difficulty == nil then
		return nil, difficultyErr or RaidLeaderboard.ERRORS.difficulty, false
	end
	local duration, clearedAt, timeErr = readClock(record)
	if duration == nil then
		return nil, timeErr or RaidLeaderboard.ERRORS.time, false
	end
	local roster, rosterErr = readIdList(record.roster)
	if roster == nil then
		return nil, rosterErr or RaidLeaderboard.ERRORS.roster, false
	end
	local size, sizeErr = readSize(record.size)
	if sizeErr ~= nil then
		return nil, sizeErr, false
	end
	if size == nil then
		local minParty, maxParty = partyBounds()
		if #roster < minParty or #roster > maxParty then
			return nil, RaidLeaderboard.ERRORS.size, false
		end
		size = #roster
	elseif size ~= #roster then
		return nil, RaidLeaderboard.ERRORS.sizeMatch, false
	end
	local present: { [number]: boolean } = {}
	for _, id in ipairs(roster) do
		present[id] = true
	end
	local excluded, removalErr = readRemovals(record.removals, present)
	if excluded == nil then
		return nil, removalErr or RaidLeaderboard.ERRORS.removal, false
	end
	local credited: { number } = {}
	for _, id in ipairs(roster) do
		if excluded[id] ~= true then
			table.insert(credited, id)
		end
	end
	if #credited == 0 then
		return nil, RaidLeaderboard.ERRORS.empty, false
	end
	table.sort(credited)
	local entry: Entry = {
		runId = runId,
		difficulty = difficulty,
		size = size,
		duration = duration,
		roster = credited,
	}
	if clearedAt ~= nil then
		entry.clearedAt = clearedAt
	end
	return entry, nil, false
end

function RaidLeaderboard.submit(board: any, record: any): SubmitResult
	local entries, boardErr = readBoard(board)
	if entries == nil then
		return failSubmit(blank(), boardErr or RaidLeaderboard.ERRORS.board)
	end
	if type(record) ~= "table" then
		return failSubmit(publish(entries), RaidLeaderboard.ERRORS.record)
	end
	local incoming, incomingErr, duplicate = buildEntry(record, entries)
	if duplicate then
		return {
			ok = true,
			accepted = false,
			duplicate = true,
			trimmed = false,
			board = publish(entries),
		}
	end
	if incoming == nil then
		return failSubmit(publish(entries), incomingErr or RaidLeaderboard.ERRORS.record)
	end
	local placed, nextEntries = insertEntry(entries, incoming)
	local stored = nil
	if placed then
		stored = copyEntry(incoming)
	end
	return {
		ok = true,
		accepted = placed,
		duplicate = false,
		trimmed = not placed,
		board = publish(nextEntries),
		entry = stored,
	}
end

local function contains(entry: Entry, id: number): boolean
	for _, member in ipairs(entry.roster) do
		if member == id then
			return true
		end
	end
	return false
end

local function bestEntry(entries: { Entry }, id: number): Entry?
	local best = nil
	for _, entry in ipairs(entries) do
		if contains(entry, id) and (best == nil or before(entry, best)) then
			best = entry
		end
	end
	return best
end

local function failBest(message: string): BestResult
	return {
		ok = false,
		found = false,
		error = message,
	}
end

function RaidLeaderboard.personalBest(board: any, userId: any): BestResult
	local id = userIdOf(userId)
	if id == nil then
		return failBest(RaidLeaderboard.ERRORS.userId)
	end
	local entries, boardErr = readBoard(board)
	if entries == nil then
		return failBest(boardErr or RaidLeaderboard.ERRORS.board)
	end
	local best = bestEntry(entries, id)
	if best == nil then
		return {
			ok = true,
			found = false,
		}
	end
	return {
		ok = true,
		found = true,
		entry = copyEntry(best),
	}
end

local function bucket(entries: { Entry }, difficulty: string, size: number): { Entry }
	local list: { Entry } = {}
	for _, entry in ipairs(entries) do
		if entry.difficulty == difficulty and entry.size == size then
			table.insert(list, entry)
		end
	end
	table.sort(list, before)
	return list
end

local function failRank(message: string): RankResult
	return {
		ok = false,
		found = false,
		error = message,
	}
end

local function rankResult(entry: Entry, rank: number): RankResult
	return {
		ok = true,
		found = true,
		rank = rank,
		difficulty = entry.difficulty,
		size = entry.size,
		entry = copyEntry(entry),
	}
end

local function rankOn(entries: { Entry }, id: number, difficulty: string, size: number): RankResult
	local list = bucket(entries, difficulty, size)
	local best = nil
	local bestRank = nil
	for index, entry in ipairs(list) do
		if contains(entry, id) and (best == nil or before(entry, best)) then
			best = entry
			bestRank = index
		end
	end
	if best == nil or bestRank == nil then
		return {
			ok = true,
			found = false,
		}
	end
	return rankResult(best, bestRank)
end

function RaidLeaderboard.rankOf(board: any, userId: any, difficulty: any?, size: any?): RankResult
	local id = userIdOf(userId)
	if id == nil then
		return failRank(RaidLeaderboard.ERRORS.userId)
	end
	local entries, boardErr = readBoard(board)
	if entries == nil then
		return failRank(boardErr or RaidLeaderboard.ERRORS.board)
	end
	if difficulty == nil and size == nil then
		local best = bestEntry(entries, id)
		if best == nil then
			return {
				ok = true,
				found = false,
			}
		end
		return rankOn(entries, id, best.difficulty, best.size)
	end
	if difficulty == nil or size == nil then
		return failRank(RaidLeaderboard.ERRORS.key)
	end
	local name = token(difficulty)
	if name == nil or RaidLeaderboard.DIFFICULTIES[name] ~= true then
		return failRank(RaidLeaderboard.ERRORS.difficulty)
	end
	local party = whole(size)
	local minParty, maxParty = partyBounds()
	if party == nil or party < minParty or party > maxParty then
		return failRank(RaidLeaderboard.ERRORS.size)
	end
	return rankOn(entries, id, name, party)
end

return RaidLeaderboard
