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
	A failed persist puts the wallet and the run list back.

	Nothing here reads a product id or spends Robux. The client cannot
	pass an amount. Waves 1-4 are not paid here.
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

function BossClearReward.validId(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	if #id < 5 or #id > 24 then
		return false
	end
	return string.match(id, "^run%-%d+$") ~= nil
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

local function bossTokens(): number?
	local ok = Economy.validate()
	if ok ~= true then
		return nil
	end
	return Economy.BOSS_CLEAR_TOKENS
end

-- One grant for this run id. persist runs before this returns. A second
-- call does not pay and does not call persist. A table, a Robux field,
-- or an amount on the id is refused.
function BossClearReward.commit(profile: any, runId: any, persist: ((any) -> boolean)?): Result
	if type(profile) ~= "table" or type(runId) ~= "string" then
		return refused()
	end
	if not BossClearReward.validId(runId) then
		return refused()
	end
	profile.bossClearRuns = BossClearReward.remembered(profile.bossClearRuns)
	if BossClearReward.seen(profile, runId) then
		return outcome(false, true, 0, true)
	end
	local amount = bossTokens()
	if amount == nil then
		return refused()
	end
	local previousTokens = profile.shardTokens
	local previousRuns = copyRuns(profile.bossClearRuns)
	local current = wallet(profile)
	local room = Economy.BOSS_CLEAR_TOKEN_CAP - current
	if room < 0 then
		room = 0
	end
	local paid = amount
	if paid > room then
		paid = room
	end
	profile.shardTokens = current + paid
	table.insert(profile.bossClearRuns, runId)
	profile.bossClearRuns = BossClearReward.remembered(profile.bossClearRuns)
	local function revert()
		profile.shardTokens = previousTokens
		profile.bossClearRuns = previousRuns
	end
	if type(persist) ~= "function" then
		revert()
		return refused()
	end
	local callOk, saved = pcall(persist, profile)
	if not callOk or saved ~= true then
		revert()
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
