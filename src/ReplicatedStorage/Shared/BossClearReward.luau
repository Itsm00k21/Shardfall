--!strict

--[[
	Wave-5 boss clear pay. Server only.

	The amount is Config/Economy BOSS_CLEAR_TOKENS (the boss row, 5 Roll
	Tokens). It is added to shardTokens. The run id is remembered on
	profile.bossClearRuns, a bounded list, so a disconnect and rejoin
	cannot pay the same run twice. A wipe does not grant and does not
	take a grant back.

	commit mutates, then calls persist. The caller tells the client only
	after commit returns saved. persist must not tell the client itself.
	A failed persist puts the wallet and the run list back when nothing
	newer landed during that write.

	A second commit for the same id while persist is still in flight
	does not pay again and does not report saved. A different id that
	lands during that write stays on the profile. The in-flight save
	writes again when it returns if the profile changed, so a snapshot
	taken at the start cannot drop the newer grant, and a failed write
	cannot roll that grant back.

	Nothing here reads a product id or spends Robux. The client cannot
	pass an amount. Waves 1-4 are not paid here. Every tier pays the
	boss row (5). A Hard multiplier does not raise it.

	card() is the RunResults bossClear table. It is built from a commit
	result that already saved. A failed save, an unsaved table, or a
	client claim becomes granted false and 0 tokens.
]]

local Economy = require("./Config/Economy")

local BossClearReward = {}

export type Result = {
	ok: boolean,
	granted: boolean,
	already: boolean,
	tokens: number,
	saved: boolean,
}

export type Card = {
	granted: boolean,
	tokens: number,
}

local function outcome(granted: boolean, already: boolean, tokens: number, saved: boolean): Result
	return {
		ok = saved or already,
		granted = granted,
		already = already,
		tokens = tokens,
		saved = saved,
	}
end

local function refused(): Result
	return outcome(false, false, 0, false)
end

-- Saved before GUID minting. Still loaded. Not minted anymore.
local LEGACY_RUN = "^run%-%d+$"
-- HttpService:GenerateGUID(false). 8-4-4-4-12 hex, no braces.
local GUID_RUN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

function BossClearReward.validId(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	if string.match(id, GUID_RUN) ~= nil then
		return true
	end
	if #id < 5 or #id > 24 then
		return false
	end
	return string.match(id, LEGACY_RUN) ~= nil
end

-- Newest ids, capped, junk dropped. A missing list is empty.
function BossClearReward.remembered(value: any): { string }
	local cap = Economy.BOSS_CLEAR_RUNS
	if type(cap) ~= "number" or cap ~= cap or cap < 1 or cap > 32 then
		cap = 16
	end
	cap = math.floor(cap)
	local clean = {}
	local seen: { [string]: boolean } = {}
	if type(value) ~= "table" then
		return clean
	end
	local index = #value
	local kept = 0
	while index >= 1 and kept < cap do
		local id = value[index]
		if BossClearReward.validId(id) and seen[id] ~= true then
			seen[id] = true
			table.insert(clean, 1, id)
			kept += 1
		end
		index -= 1
	end
	return clean
end

function BossClearReward.seen(profile: any, runId: any): boolean
	if type(profile) ~= "table" or not BossClearReward.validId(runId) then
		return false
	end
	local runs = profile.bossClearRuns
	if type(runs) ~= "table" then
		return false
	end
	for _, id in ipairs(runs) do
		if id == runId then
			return true
		end
	end
	return false
end

local function wallet(profile: any): number
	local raw = profile.shardTokens
	if type(raw) ~= "number" or raw ~= raw or raw >= math.huge or raw <= -math.huge then
		return 0
	end
	if raw < 0 then
		return 0
	end
	return math.floor(raw)
end

local function copyRuns(value: any): { string }
	local copy = {}
	if type(value) ~= "table" then
		return copy
	end
	for _, id in ipairs(value) do
		if type(id) == "string" then
			table.insert(copy, id)
		end
	end
	return copy
end

local function bossTokens(tier: any): number?
	return Economy.bossClearPay(tier)
end

-- RunResults.bossClear. Saved grant only. Unsaved, failed, and a client
-- claim all publish as not granted.
function BossClearReward.card(result: any): Card
	local empty = { granted = false, tokens = 0 }
	if type(result) ~= "table" or result.saved ~= true or result.granted ~= true then
		return empty
	end
	local tokens = result.tokens
	local cap = Economy.BOSS_CLEAR_TOKENS
	if type(tokens) ~= "number" or tokens ~= tokens or tokens < 0 or tokens ~= math.floor(tokens) then
		return empty
	end
	if type(cap) ~= "number" or tokens > cap then
		return empty
	end
	return { granted = true, tokens = tokens }
end

type Pending = {
	tokens: number,
	stamp: number,
	previousTokens: any,
	previousRuns: { string },
}

type Lane = {
	serial: number,
	depth: number,
	pending: { [string]: Pending },
}

-- Session only. Not a profile field, so a save cannot persist it.
-- Weak keys: dropping the profile drops the lane.
local lanes: { [any]: Lane } = setmetatable({} :: { [any]: Lane }, { __mode = "k" })

local FLUSH_LIMIT = 8

local function laneFor(profile: any): Lane
	local lane = lanes[profile]
	if lane == nil then
		lane = {
			serial = 0,
			depth = 0,
			pending = {},
		}
		lanes[profile] = lane
	end
	return lane
end

local function confirm(lane: Lane, stamp: number)
	for id, row in pairs(lane.pending) do
		if row.stamp <= stamp then
			lane.pending[id] = nil
		end
	end
end

-- A failed write with no newer grant puts this profile back. One pending
-- row restores the exact wallet. Several rows give back only what they
-- added, so an outside change made during the write stays.
local function undoPending(profile: any, lane: Lane)
	local only: Pending? = nil
	local count = 0
	local claw = 0
	for _, row in pairs(lane.pending) do
		count += 1
		only = row
		claw += row.tokens
	end
	if count == 1 and only ~= nil then
		profile.shardTokens = only.previousTokens
		profile.bossClearRuns = only.previousRuns
	elseif count > 1 then
		local left = wallet(profile) - claw
		if left < 0 then
			left = 0
		end
		profile.shardTokens = left
		local keep = {}
		local runs = profile.bossClearRuns
		if type(runs) == "table" then
			for _, id in ipairs(runs) do
				if type(id) == "string" and lane.pending[id] == nil then
					table.insert(keep, id)
				end
			end
		end
		profile.bossClearRuns = keep
	end
	lane.pending = {}
end

-- persist may yield. If the profile changes during the call, that write
-- may have copied the older table. Write the current one before reporting
-- saved. A false write undoes the grant only when nothing newer landed.
local function flush(profile: any, lane: Lane, persist: (any) -> boolean): boolean
	local spins = 0
	while spins < FLUSH_LIMIT do
		spins += 1
		local stamp = lane.serial
		local callOk, saved = pcall(persist, profile)
		local stable = lane.serial == stamp
		if callOk and saved == true and stable then
			confirm(lane, stamp)
			return true
		end
		if not stable then
			continue
		end
		undoPending(profile, lane)
		return false
	end
	undoPending(profile, lane)
	return false
end

local function reserved(profile: any, lane: Lane, runId: string, paid: number): boolean
	local previousTokens = profile.shardTokens
	local previousRuns = copyRuns(profile.bossClearRuns)
	local current = wallet(profile)
	local room = Economy.BOSS_CLEAR_TOKEN_CAP - current
	if room < 0 then
		room = 0
	end
	local grant = paid
	if grant > room then
		grant = room
	end
	profile.shardTokens = current + grant
	table.insert(profile.bossClearRuns, runId)
	profile.bossClearRuns = BossClearReward.remembered(profile.bossClearRuns)
	if not BossClearReward.seen(profile, runId) then
		profile.shardTokens = previousTokens
		profile.bossClearRuns = previousRuns
		return false
	end
	lane.serial += 1
	lane.pending[runId] = {
		tokens = grant,
		stamp = lane.serial,
		previousTokens = previousTokens,
		previousRuns = previousRuns,
	}
	return true
end

-- One grant for this run id. persist runs before this returns saved.
-- An in-flight call does not pay again and does not report saved.
-- A table, a Robux field, or an amount on the id is refused.
function BossClearReward.commit(profile: any, runId: any, persist: ((any) -> boolean)?, tier: any): Result
	if type(profile) ~= "table" or type(runId) ~= "string" then
		return refused()
	end
	if not BossClearReward.validId(runId) then
		return refused()
	end
	profile.bossClearRuns = BossClearReward.remembered(profile.bossClearRuns)
	local lane = laneFor(profile)
	if lane.pending[runId] ~= nil then
		if lane.depth > 0 or type(persist) ~= "function" then
			return outcome(false, false, 0, false)
		end
		lane.depth += 1
		local saved = flush(profile, lane, persist)
		lane.depth -= 1
		if saved and lane.pending[runId] == nil and BossClearReward.seen(profile, runId) then
			return outcome(false, true, 0, true)
		end
		return refused()
	end
	if BossClearReward.seen(profile, runId) then
		return outcome(false, true, 0, true)
	end
	local amount = bossTokens(tier)
	if amount == nil then
		return refused()
	end
	if not reserved(profile, lane, runId, amount) then
		return refused()
	end
	local row = lane.pending[runId]
	if row == nil then
		return refused()
	end
	local paid = row.tokens
	if type(persist) ~= "function" then
		undoPending(profile, lane)
		return refused()
	end
	-- The save already running will write this grant before it reports
	-- saved. This call must not tell the client and must not pay twice.
	if lane.depth > 0 then
		return outcome(false, false, 0, false)
	end
	lane.depth += 1
	local saved = flush(profile, lane, persist)
	lane.depth -= 1
	if not saved or lane.pending[runId] ~= nil or not BossClearReward.seen(profile, runId) then
		return refused()
	end
	return outcome(true, false, paid, true)
end

-- Defeat. Tokens already saved stay. The run id is not consumed, and
-- nothing is added. A later clear of a new id can still pay once.
function BossClearReward.wipe(profile: any, runId: any): Result
	if type(profile) ~= "table" then
		return refused()
	end
	return outcome(false, BossClearReward.seen(profile, runId), 0, false)
end

return BossClearReward
