--!strict

--[[
	Phase 4.1 / 4.4 run payouts. Pure. No players, remotes, or saves.

	Roll Tokens come from Config/Economy. A clear pays the sum of the
	cleared wave bases times the difficulty multiplier, rounded half up
	(13.75 -> 14, 16.5 -> 17). Each wave pays the difference from the
	rounded total through the previous wave, so the waves add up to the
	rounded clear. Do not round a wave on its own: Hard's second wave
	base is 1 x 1.5, and the pay is 1, because the running total moves
	from 2 to 3. Per-wave rounding would make a Hard clear 18, not 17.

	Leaving early keeps that running total and nothing after it. Dying
	on the boss is waves 1-4 (Normal 6, Medium 8, Hard 9, Nightmare 12,
	Insane 18).

	Duplicates become Fragments from DUP_FRAGMENTS (Dust / 5).
	Mythic and Secret fold into Legendary. They take no bag slot.

	grant is the only function that records a payout. The first call for
	a player and a run id settles it. A retry, a leave, or a second call
	with a higher wave count pays 0. Amounts on the request are ignored.
	A Robux, product, or receipt field refuses the call and does not
	settle the run. Nothing here costs Robux.

	Phase 4.4: economyCheck compares a full clear with the roll cost.
	A few rolls means at least FEW_ROLLS singles. The flag that turns
	the server grant on lives in LaunchGate and stays off.
]]

local Economy = require("./Economy")
local Rarities = require("./Rarities")
local RollConfig = require("../RollConfig")

local Payouts = {}

Payouts.FEW_ROLLS = 3
Payouts.MAX_DUPLICATES = 20

-- Sheet rev 2 section 5. Live Shard Dust / 5. Not a save field.
Payouts.DUP_FRAGMENTS = table.freeze({
	Common = 1,
	Uncommon = 3,
	Rare = 10,
	Epic = 40,
	Legendary = 200,
})

-- Duplicates convert on their own and take no bag slot.
Payouts.DUP_AUTO_CONVERT = true

Payouts.ERRORS = table.freeze({
	book = "That payout book is unusable.",
	user = "That player id is unusable.",
	run = "That run id is unusable.",
	request = "That payout request is unusable.",
	paid = "Run rewards cannot be bought.",
	difficulty = "That difficulty has no token payout.",
	waves = "That wave count is unusable.",
	duplicate = "That duplicate is unusable.",
	config = "Payout config is missing a number.",
})

export type WaveLine = {
	wave: number,
	boss: boolean,
	base: number,
	tokens: number,
}

export type DuplicateLine = {
	id: string,
	rarity: string,
	fragments: number,
}

export type Preview = {
	ok: boolean,
	difficulty: string,
	wavesCleared: number,
	waveCount: number,
	multiplier: number,
	baseTokens: number,
	tokens: number,
	waves: { WaveLine },
	leftEarly: boolean,
	error: string?,
}

export type Grant = {
	ok: boolean,
	paid: boolean,
	already: boolean,
	userId: number,
	runId: string,
	difficulty: string,
	wavesCleared: number,
	tokens: number,
	fragments: number,
	totalTokens: number,
	totalFragments: number,
	leftEarly: boolean,
	waves: { WaveLine },
	duplicates: { DuplicateLine },
	error: string?,
}

export type EconomyRow = {
	difficulty: string,
	tokens: number,
	singleRolls: number,
	x10s: number,
	leftover: number,
}

export type EconomyCheck = {
	ok: boolean,
	fewRolls: number,
	singleCost: number,
	x10Cost: number,
	rows: { EconomyRow },
	error: string?,
}

type Settlement = {
	userId: number,
	runId: string,
	difficulty: string,
	wavesCleared: number,
	tokens: number,
	fragments: number,
	leftEarly: boolean,
	waves: { WaveLine },
	duplicates: { DuplicateLine },
}

export type Book = {
	runs: { [string]: Settlement },
}

local BANNED = { "robux", "productId", "receiptId" }

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

local function bought(row: any): boolean
	if type(row) ~= "table" then
		return false
	end
	for _, key in ipairs(BANNED) do
		if row[key] ~= nil then
			return true
		end
	end
	return false
end

local function positiveInt(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value < 1 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function userIdOf(value: any): number?
	local whole = positiveInt(value)
	if whole == nil or whole > 1000000000000000 then
		return nil
	end
	return whole
end

local function runIdOf(value: any): string?
	if type(value) ~= "string" or value == "" or #value > 64 then
		return nil
	end
	return value
end

local function difficultyOf(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local id = string.lower(trim(value))
	if Economy.DIFFICULTIES[id] == nil then
		return nil
	end
	return id
end

local function wavesOf(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < 0 or value ~= math.floor(value) or value > #Economy.WAVES then
		return nil
	end
	return value
end

local function multiplierOf(id: string): number?
	local row = Economy.DIFFICULTIES[id]
	if type(row) ~= "table" then
		return nil
	end
	local multiplier = row.tokenMultiplier
	if
		type(multiplier) ~= "number"
		or multiplier ~= multiplier
		or multiplier == math.huge
		or multiplier <= 0
	then
		return nil
	end
	return multiplier
end

local function waveBase(index: number): number?
	local wave = Economy.WAVES[index]
	if type(wave) ~= "table" then
		return nil
	end
	local tokens = wave.tokens
	if
		type(tokens) ~= "number"
		or tokens ~= tokens
		or tokens < 0
		or tokens ~= math.floor(tokens)
	then
		return nil
	end
	return tokens
end

-- Half up. Quarter multipliers (1, 1.25, 1.5, 2, 3) use integer math so
-- 13.75 and 16.5 do not drift. Any other multiplier uses floor(n + 0.5).
local function halfUp(base: number, multiplier: number): number?
	if Economy.ROUNDING ~= "half_up" then
		return nil
	end
	local quarters = multiplier * 4
	if quarters ~= quarters or quarters == math.huge then
		return nil
	end
	local nearest = math.floor(quarters + 0.5)
	if nearest >= 0 and math.abs(quarters - nearest) < 1e-6 then
		return (base * nearest + 2) // 4
	end
	return math.floor(base * multiplier + 0.5)
end

local function tierOf(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local name = string.lower(trim(value))
	if name == "" then
		return nil
	end
	for _, id in ipairs(Rarities.ORDER) do
		if string.lower(id) == name then
			return id
		end
	end
	for folded, tier in pairs(Rarities.FOLD) do
		if
			string.lower(folded) == name
			and type(tier) == "string"
			and Rarities.TIERS[tier] ~= nil
		then
			return tier
		end
	end
	return nil
end

local function fragmentAmount(tier: string, autoConvert: boolean): number?
	if autoConvert ~= true then
		return 0
	end
	local amounts = Payouts.DUP_FRAGMENTS
	if type(amounts) ~= "table" then
		return nil
	end
	local amount = amounts[tier]
	if
		type(amount) ~= "number"
		or amount ~= amount
		or amount < 0
		or amount ~= math.floor(amount)
	then
		return nil
	end
	return amount
end

local function sequenceLength(list: { any }): number?
	local count = 0
	for index in ipairs(list) do
		count = index
	end
	local seen = 0
	for _ in pairs(list) do
		seen += 1
	end
	if seen ~= count then
		return nil
	end
	return count
end

local function copyWaves(lines: { WaveLine }): { WaveLine }
	local copy = {}
	for _, line in ipairs(lines) do
		table.insert(copy, {
			wave = line.wave,
			boss = line.boss,
			base = line.base,
			tokens = line.tokens,
		})
	end
	return copy
end

local function copyDuplicates(lines: { DuplicateLine }): { DuplicateLine }
	local copy = {}
	for _, line in ipairs(lines) do
		table.insert(copy, {
			id = line.id,
			rarity = line.rarity,
			fragments = line.fragments,
		})
	end
	return copy
end

local function badPreview(message: string): Preview
	return {
		ok = false,
		difficulty = "",
		wavesCleared = 0,
		waveCount = #Economy.WAVES,
		multiplier = 0,
		baseTokens = 0,
		tokens = 0,
		waves = {},
		leftEarly = false,
		error = message,
	}
end

function Payouts.preview(difficulty: any, wavesCleared: any): Preview
	local id = difficultyOf(difficulty)
	if id == nil then
		return badPreview(Payouts.ERRORS.difficulty)
	end
	local cleared = wavesOf(wavesCleared)
	if cleared == nil then
		return badPreview(Payouts.ERRORS.waves)
	end
	local multiplier = multiplierOf(id)
	if multiplier == nil then
		return badPreview(Payouts.ERRORS.config)
	end
	local lines = {}
	local previous = 0
	local base = 0
	for index = 1, cleared do
		local wave = Economy.WAVES[index]
		local tokens = waveBase(index)
		if tokens == nil or type(wave) ~= "table" then
			return badPreview(Payouts.ERRORS.config)
		end
		base += tokens
		local total = halfUp(base, multiplier)
		if total == nil or total < previous then
			return badPreview(Payouts.ERRORS.config)
		end
		table.insert(lines, {
			wave = index,
			boss = wave.boss == true,
			base = tokens,
			tokens = total - previous,
		})
		previous = total
	end
	return {
		ok = true,
		difficulty = id,
		wavesCleared = cleared,
		waveCount = #Economy.WAVES,
		multiplier = multiplier,
		baseTokens = base,
		tokens = previous,
		waves = lines,
		leftEarly = cleared < #Economy.WAVES,
		error = nil,
	}
end

function Payouts.tokensThrough(difficulty: any, wavesCleared: any): (number?, string?)
	local preview = Payouts.preview(difficulty, wavesCleared)
	if preview.ok ~= true then
		return nil, preview.error
	end
	return preview.tokens, nil
end

function Payouts.duplicateFragments(rarity: any, autoConvert: boolean?): number?
	local tier = tierOf(rarity)
	if tier == nil then
		return nil
	end
	local convert = if autoConvert == nil
		then Payouts.DUP_AUTO_CONVERT == true
		else autoConvert == true
	return fragmentAmount(tier, convert)
end

local function readDuplicates(value: any): ({ DuplicateLine }?, number?, string?)
	if value == nil then
		return {}, 0, nil
	end
	if type(value) ~= "table" then
		return nil, nil, Payouts.ERRORS.duplicate
	end
	local count = sequenceLength(value)
	if count == nil or count > Payouts.MAX_DUPLICATES then
		return nil, nil, Payouts.ERRORS.duplicate
	end
	local lines = {}
	local seen: { [string]: boolean } = {}
	local total = 0
	local convert = Payouts.DUP_AUTO_CONVERT == true
	for _, entry in ipairs(value) do
		if type(entry) ~= "table" or bought(entry) then
			return nil, nil, Payouts.ERRORS.duplicate
		end
		local id = entry.id
		if type(id) ~= "string" or id == "" or #id > 64 or seen[id] == true then
			return nil, nil, Payouts.ERRORS.duplicate
		end
		seen[id] = true
		local tier = tierOf(entry.rarity)
		if tier == nil then
			return nil, nil, Payouts.ERRORS.duplicate
		end
		local amount = fragmentAmount(tier, convert)
		if amount == nil then
			return nil, nil, Payouts.ERRORS.config
		end
		total += amount
		table.insert(lines, { id = id, rarity = tier, fragments = amount })
	end
	return lines, total, nil
end

local function quote(request: any): (Preview?, { DuplicateLine }?, number?, string?)
	if type(request) ~= "table" then
		return nil, nil, nil, Payouts.ERRORS.request
	end
	if bought(request) then
		return nil, nil, nil, Payouts.ERRORS.paid
	end
	local cleared = wavesOf(request.wavesCleared)
	if cleared == nil then
		return nil, nil, nil, Payouts.ERRORS.waves
	end
	local preview: Preview
	if request.difficulty == nil and cleared == 0 then
		preview = {
			ok = true,
			difficulty = "",
			wavesCleared = 0,
			waveCount = #Economy.WAVES,
			multiplier = 0,
			baseTokens = 0,
			tokens = 0,
			waves = {},
			leftEarly = true,
			error = nil,
		}
	else
		local counted = Payouts.preview(request.difficulty, cleared)
		if counted.ok ~= true then
			return nil, nil, nil, counted.error or Payouts.ERRORS.difficulty
		end
		preview = counted
	end
	local lines, fragments, dupError = readDuplicates(request.duplicates)
	if dupError ~= nil or lines == nil or fragments == nil then
		return nil, nil, nil, dupError or Payouts.ERRORS.duplicate
	end
	return preview, lines, fragments, nil
end

local function emptyGrant(userId: number, runId: string, message: string?): Grant
	return {
		ok = message == nil,
		paid = false,
		already = false,
		userId = userId,
		runId = runId,
		difficulty = "",
		wavesCleared = 0,
		tokens = 0,
		fragments = 0,
		totalTokens = 0,
		totalFragments = 0,
		leftEarly = false,
		waves = {},
		duplicates = {},
		error = message,
	}
end

local function fromSettlement(saved: Settlement, paid: boolean): Grant
	return {
		ok = true,
		paid = paid,
		already = not paid,
		userId = saved.userId,
		runId = saved.runId,
		difficulty = saved.difficulty,
		wavesCleared = saved.wavesCleared,
		tokens = if paid then saved.tokens else 0,
		fragments = if paid then saved.fragments else 0,
		totalTokens = saved.tokens,
		totalFragments = saved.fragments,
		leftEarly = saved.leftEarly,
		waves = copyWaves(saved.waves),
		duplicates = copyDuplicates(saved.duplicates),
		error = nil,
	}
end

function Payouts.newBook(): Book
	return { runs = {} }
end

function Payouts.closed(runId: any, message: string): Grant
	local id = if type(runId) == "string" then runId else ""
	local result = emptyGrant(0, id, message)
	result.ok = false
	return result
end

local function bookRuns(book: any): { [string]: Settlement }?
	if type(book) ~= "table" or type(book.runs) ~= "table" then
		return nil
	end
	return book.runs
end

function Payouts.grant(book: any, userId: any, runId: any, request: any): Grant
	local runs = bookRuns(book)
	if runs == nil then
		return emptyGrant(0, "", Payouts.ERRORS.book)
	end
	local user = userIdOf(userId)
	if user == nil then
		return emptyGrant(0, "", Payouts.ERRORS.user)
	end
	local id = runIdOf(runId)
	if id == nil then
		return emptyGrant(user, "", Payouts.ERRORS.run)
	end
	local key = string.format("%d\0%s", user, id)
	local saved = runs[key]
	if saved ~= nil then
		return fromSettlement(saved, false)
	end
	local preview, lines, fragments, reason = quote(request)
	if preview == nil or lines == nil or fragments == nil then
		return emptyGrant(user, id, reason or Payouts.ERRORS.request)
	end
	local settlement: Settlement = {
		userId = user,
		runId = id,
		difficulty = preview.difficulty,
		wavesCleared = preview.wavesCleared,
		tokens = preview.tokens,
		fragments = fragments,
		leftEarly = preview.leftEarly,
		waves = copyWaves(preview.waves),
		duplicates = copyDuplicates(lines),
	}
	runs[key] = settlement
	return fromSettlement(settlement, true)
end

local function badCheck(message: string): EconomyCheck
	return {
		ok = false,
		fewRolls = Payouts.FEW_ROLLS,
		singleCost = 0,
		x10Cost = 0,
		rows = {},
		error = message,
	}
end

-- Full clear versus the live roll cost. ok means every difficulty pays
-- at least FEW_ROLLS singles and each clear pays more than the one below.
function Payouts.economyCheck(): EconomyCheck
	local single = positiveInt(RollConfig.SINGLE_COST)
	local batchCount = positiveInt(RollConfig.MULTI_COUNT)
	local batchCost = if batchCount ~= nil then positiveInt(RollConfig.cost(batchCount)) else nil
	if single == nil or batchCost == nil then
		return badCheck(Payouts.ERRORS.config)
	end
	local rows = {}
	local previous = 0
	local healthy = true
	for _, id in ipairs(Economy.DIFFICULTY_ORDER) do
		local preview = Payouts.preview(id, #Economy.WAVES)
		if preview.ok ~= true then
			return badCheck(preview.error or Payouts.ERRORS.config)
		end
		local singles = preview.tokens // single
		if preview.tokens <= previous or singles < Payouts.FEW_ROLLS then
			healthy = false
		end
		previous = preview.tokens
		table.insert(rows, {
			difficulty = id,
			tokens = preview.tokens,
			singleRolls = singles,
			x10s = preview.tokens // batchCost,
			leftover = preview.tokens % batchCost,
		})
	end
	return {
		ok = healthy,
		fewRolls = Payouts.FEW_ROLLS,
		singleCost = single,
		x10Cost = batchCost,
		rows = rows,
		error = if healthy then nil else Payouts.ERRORS.config,
	}
end

return table.freeze(Payouts)
