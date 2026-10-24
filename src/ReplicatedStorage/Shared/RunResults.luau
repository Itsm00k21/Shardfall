--!strict

--[[
	M12 results payload and Run Again. Server only.

	LaunchGate.m12Results ships false. While it is off, apply() leaves the
	arena card alone and again() does not start a run.

	The loot list is the grants this server recorded on the run. A client
	table of loot, tokens, rewards, xp, or a best wave is not read.
	bestWave lives in memory for this session, per player and tier.
	Nothing here writes the profile. schemaVersion stays 26.

	Run Again starts at most one run for a burst in one frame. The same
	ended run does not start a second time. A different run inside
	results.runAgainGap is refused. The player must own that ended run,
	must not be mid-teleport, and must still be allowed on its tier.
]]

local BossClearReward = require("./BossClearReward")
local Economy = require("./Config/Economy")
local HardMode = require("./HardMode")
local LaunchGate = require("./LaunchGate")
local Progression = require("./Progression")
local Rarities = require("./Rarities")
local RollConfig = require("./RollConfig")
local WaveArenaConfig = require("./Config/WaveArenaConfig")

local RunResults = {}

local BANNED = { robux = true, productId = true, price = true, cost = true }
local PLAYABLE = { clear = true, wipe = true, timeout = true }

local bestWaves: { [string]: number } = {}
local books: { [string]: any } = {}

local function enabled(): boolean
	return LaunchGate.on("m12Results")
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function whole(value: any, fallback: number): number
	if not finite(value) then
		return fallback
	end
	local n = math.floor(value)
	if n < 0 then
		return 0
	end
	return n
end

local function idKey(value: any): string?
	if type(value) == "number" and finite(value) and value > 0 then
		return tostring(math.floor(value))
	end
	if type(value) == "string" and value ~= "" and #value <= 64 then
		return value
	end
	return nil
end

local function bannedKey(row: any): string?
	if type(row) ~= "table" then
		return nil
	end
	for key, value in pairs(row) do
		if BANNED[key] == true then
			return "robux"
		end
		if type(value) == "table" then
			local found = bannedKey(value)
			if found ~= nil then
				return found
			end
		end
	end
	return nil
end

function RunResults.check(results: any): (boolean, string?)
	if type(results) ~= "table" then
		return false, "config"
	end
	local robbed = bannedKey(results)
	if robbed ~= nil then
		return false, robbed
	end
	if results.autoReturn ~= 30 then
		return false, "autoReturn"
	end
	if results.soloCountdown ~= 3 then
		return false, "soloCountdown"
	end
	if results.runAgainGap ~= 1 then
		return false, "runAgainGap"
	end
	if results.frameMs ~= 50 then
		return false, "frameMs"
	end
	if type(results.frameMs) ~= "number" or results.frameMs >= results.runAgainGap * 1000 then
		return false, "frameMs"
	end
	if results.hardLevel ~= 5 then
		return false, "hardLevel"
	end
	local names = results.lootNames
	if type(names) ~= "table" then
		return false, "name"
	end
	if names.shard_chip ~= "Shard Chip" or names.boss_core ~= "Boss Core" then
		return false, "name"
	end
	return true, nil
end

function RunResults.validate(): (boolean, string?)
	local ok, err = RunResults.check(WaveArenaConfig.results)
	if not ok then
		return false, err
	end
	if #WaveArenaConfig.waves ~= 5 then
		return false, "waves"
	end
	if WaveArenaConfig.boss.deathHold ~= 1.5 then
		return false, "deathHold"
	end
	if WaveArenaConfig.timeout ~= 480 then
		return false, "timeout"
	end
	local hard = Economy.DIFFICULTIES.hard
	if type(hard) ~= "table" or WaveArenaConfig.results.hardLevel ~= hard.levelGate then
		return false, "hardLevel"
	end
	local names = WaveArenaConfig.results.lootNames
	for _, drop in pairs(WaveArenaConfig.loot.drops) do
		if type(drop) ~= "table" or type(names[drop.id]) ~= "string" or names[drop.id] == "" then
			return false, "name"
		end
	end
	return true, nil
end

local function timings(): any?
	if RunResults.check(WaveArenaConfig.results) ~= true then
		return nil
	end
	return WaveArenaConfig.results
end

function RunResults.stay(reason: any): boolean
	if not enabled() then
		return false
	end
	return PLAYABLE[reason] == true
end

function RunResults.account(profile: any): any
	if type(profile) ~= "table" then
		return nil
	end
	return {
		level = profile.level,
		xp = profile.xp,
		shardTokens = profile.shardTokens,
	}
end

local function bookOf(key: string): any
	local found = books[key]
	if found == nil then
		found = { consumed = {}, serial = 0 }
		books[key] = found
	end
	return found
end

function RunResults.reset()
	table.clear(bestWaves)
	table.clear(books)
end

function RunResults.forget(userId: any)
	local key = idKey(userId)
	if key == nil then
		return
	end
	books[key] = nil
	local prefix = key .. ":"
	for saved in pairs(bestWaves) do
		if string.sub(saved, 1, #prefix) == prefix then
			bestWaves[saved] = nil
		end
	end
end

function RunResults.release(userId: any, resultsId: any)
	local key = idKey(userId)
	if key == nil or type(resultsId) ~= "string" then
		return
	end
	local book = books[key]
	if type(book) ~= "table" or type(book.consumed) ~= "table" then
		return
	end
	local minted = book.consumed[resultsId]
	if minted == nil or minted ~= book.liveId then
		return
	end
	book.consumed[resultsId] = nil
	book.liveId = nil
	book.frameNow = nil
	book.lastStart = nil
end

local function tierOf(run: any): string
	if type(run) == "table" and type(run.tier) == "string" and run.tier ~= "" then
		return string.lower(run.tier)
	end
	return "normal"
end

local function reasonOf(run: any): string
	if type(run) == "table" and type(run.reason) == "string" then
		return run.reason
	end
	return "wipe"
end

local function nameOf(id: string, names: any): string
	if type(names) == "table" and type(names[id]) == "string" and names[id] ~= "" then
		return names[id]
	end
	return id
end

local function itemsOf(run: any, names: any): { any }
	local merged: { [string]: any } = {}
	local order: { string } = {}
	local list = if type(run) == "table" and type(run.grantList) == "table" then run.grantList else {}
	for _, grant in ipairs(list) do
		if type(grant) == "table" and grant.kind == "drop" and grant.where == "bag" and type(grant.dropId) == "string" then
			local id = grant.dropId
			if id ~= "" then
				local rarity = "Common"
				if type(grant.rarity) == "string" and Rarities.INDEX[grant.rarity] ~= nil then
					rarity = grant.rarity
				end
				local slot = id .. "\0" .. rarity
				local row = merged[slot]
				if row == nil then
					row = {
						id = id,
						name = nameOf(id, names),
						tier = rarity,
						count = 0,
						hardOnly = grant.hardOnly == true,
					}
					merged[slot] = row
					table.insert(order, slot)
				end
				row.count += 1
			end
		end
	end
	local items = {}
	for _, slot in ipairs(order) do
		table.insert(items, merged[slot])
	end
	return items
end

local function noteBest(run: any): (number, boolean)
	local reached = 0
	if type(run) == "table" then
		reached = whole(run.wavesCleared, 0)
	end
	local owner = if type(run) == "table" then idKey(run.ownerId) else nil
	if owner == nil then
		return reached, reached > 0
	end
	local key = owner .. ":" .. tierOf(run)
	local prior = bestWaves[key] or 0
	local best = math.max(prior, reached)
	local fresh = reached > prior
	bestWaves[key] = best
	return best, fresh
end

local function personal(profile: any): (number, number, number, number)
	local level = 1
	local xp = 0
	local tokens = 0
	if type(profile) == "table" then
		level = math.max(1, whole(profile.level, 1))
		xp = whole(profile.xp, 0)
		tokens = whole(profile.shardTokens, 0)
	end
	local need = Progression.xpToNext(level)
	local frac = 1
	if type(need) == "number" and need > 0 then
		frac = math.clamp(xp / need, 0, 1)
	end
	local ready = 0
	local cost = RollConfig.SINGLE_COST
	if type(cost) == "number" and cost > 0 then
		ready = math.floor(tokens / cost)
	end
	-- This run does not grant account XP. The bar reads the saved level.
	return ready, 0, level, frac
end

local function wallet(run: any, profile: any): any
	if type(profile) == "table" then
		return profile
	end
	if type(run) == "table" and type(run.account) == "table" then
		return run.account
	end
	return nil
end

-- _request is the client table. Loot, tokens, rewards, xp, and best wave
-- in it are not read. Grants already on the run are the loot list.
function RunResults.payload(run: any, profile: any, _request: any, now: any): any?
	if not enabled() or type(run) ~= "table" then
		return nil
	end
	local numbers = timings()
	if numbers == nil then
		return nil
	end
	local reason = reasonOf(run)
	local waves = whole(run.wavesCleared, 0)
	local total = whole(run.total, #WaveArenaConfig.waves)
	local cleared = waves >= total and reason ~= "wipe"
	local outcome = if cleared then "cleared" else "wiped"
	local best, fresh = noteBest(run)
	local tier = tierOf(run)
	local row = Economy.DIFFICULTIES[tier]
	local multiplier = 1
	if type(row) == "table" and finite(row.tokenMultiplier) then
		multiplier = row.tokenMultiplier
	end
	local ready, gained, level, frac = personal(wallet(run, profile))
	local clock = if finite(now) then now else os.clock()
	return {
		wavesCleared = waves,
		bestWave = best,
		newBest = fresh,
		tier = tier,
		total = total,
		kills = whole(run.kills, 0),
		seconds = if finite(run.seconds) then run.seconds else 0,
		outcome = outcome,
		multiplier = multiplier,
		rollsReady = ready,
		xp = gained,
		levelAfter = level,
		xpFrac = frac,
		bossClear = BossClearReward.card(run.bossGrant),
		returnAt = clock + numbers.autoReturn,
		loot = itemsOf(run, numbers.lootNames),
	}
end

function RunResults.apply(card: any, run: any, profile: any): boolean
	local fields = RunResults.payload(run, profile, nil, os.clock())
	if fields == nil or type(card) ~= "table" then
		return false
	end
	card.bestWave = fields.bestWave
	card.newBest = fields.newBest
	card.tier = fields.tier
	card.total = fields.total
	card.kills = fields.kills
	card.seconds = fields.seconds
	card.outcome = fields.outcome
	card.multiplier = fields.multiplier
	card.rollsReady = fields.rollsReady
	card.xp = fields.xp
	card.levelAfter = fields.levelAfter
	card.xpFrac = fields.xpFrac
	card.bossClear = fields.bossClear
	card.returnAt = fields.returnAt
	if type(card.loot) ~= "table" then
		card.loot = {}
	end
	card.loot.items = fields.loot
	return true
end

function RunResults.refresh(card: any, run: any, profile: any)
	if not enabled() or type(profile) ~= "table" then
		return
	end
	if type(run) == "table" then
		run.account = RunResults.account(profile)
	end
	if type(card) ~= "table" then
		return
	end
	local ready, gained, level, frac = personal(profile)
	card.rollsReady = ready
	card.xp = gained
	card.levelAfter = level
	card.xpFrac = frac
end

local function refuse(reason: string): any
	return { ok = false, error = reason, started = false }
end

local function sameFrame(book: any, now: number, window: number): boolean
	return book.liveId ~= nil and finite(book.frameNow) and now >= book.frameNow and now - book.frameNow < window
end

-- _request is ignored. A loot or reward claim cannot change the profile
-- or the run that gets started.
function RunResults.again(userId: any, run: any, profile: any, _request: any, now: any, teleporting: any): any
	if not enabled() then
		return { ok = true, noop = true, started = false }
	end
	local numbers = timings()
	if numbers == nil then
		return refuse("config")
	end
	local key = idKey(userId)
	if key == nil then
		return refuse("owner")
	end
	local book = bookOf(key)
	local window = numbers.frameMs / 1000
	if finite(now) and sameFrame(book, now, window) then
		return {
			ok = true,
			started = false,
			duplicate = true,
			runId = book.liveId,
			countdown = numbers.soloCountdown,
		}
	end
	if teleporting == true then
		return refuse("teleport")
	end
	if type(run) ~= "table" then
		return refuse("state")
	end
	local owner = idKey(run.ownerId)
	if owner == nil or owner ~= key then
		return refuse("owner")
	end
	if run.phase ~= "results" or run.settled ~= true or PLAYABLE[run.reason] ~= true then
		return refuse("state")
	end
	local resultsId = run.receiptId
	if type(resultsId) ~= "string" or resultsId == "" then
		return refuse("state")
	end
	local existing = book.consumed[resultsId]
	if existing ~= nil then
		return {
			ok = true,
			started = false,
			duplicate = true,
			runId = existing,
			countdown = numbers.soloCountdown,
		}
	end
	if type(run.party) == "number" and run.party > 1 then
		return refuse("party")
	end
	if type(profile) ~= "table" then
		return refuse("eligible")
	end
	local accepted = HardMode.accept(profile.level, tierOf(run))
	if accepted == nil then
		return refuse("eligible")
	end
	if not finite(now) then
		return refuse("rate")
	end
	if finite(book.lastStart) and now - book.lastStart < numbers.runAgainGap then
		return refuse("rate")
	end
	book.serial += 1
	local runId = string.format("m12-%s-%d", key, book.serial)
	book.consumed[resultsId] = runId
	book.liveId = runId
	book.frameNow = now
	book.lastStart = now
	return {
		ok = true,
		started = true,
		duplicate = false,
		runId = runId,
		tier = accepted,
		countdown = numbers.soloCountdown,
	}
end

return RunResults
