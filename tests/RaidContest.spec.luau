--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidContest = require("../src/ReplicatedStorage/Shared/RaidContest")
local RaidMarks = require("../src/ReplicatedStorage/Shared/RaidMarks")

local ERRORS = RaidContest.ERRORS
local REASONS = RaidContest.REASONS

local OPEN = 1700000000
local DAY = 86400
local DURATION = 172800

local function clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = clone(child)
	end
	return copy
end

local function freezeDeep(value: any)
	if type(value) ~= "table" then
		return
	end
	for _, child in pairs(value) do
		freezeDeep(child)
	end
	if not table.isfrozen(value) then
		table.freeze(value)
	end
end

local function opened(raidId: string?, openedAt: number?): any
	local result = RaidContest.open({
		raidId = raidId or "heartwood",
		openedAt = openedAt or OPEN,
	})
	expect(result.ok).toEqual(true)
	expect(result.persist).toEqual(true)
	expect(result.error).toBeNil()
	return result.state
end

local function luaFiles(dir: string): { string }
	local found = {}
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			for _, child in ipairs(luaFiles(path)) do
				table.insert(found, child)
			end
		elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
			table.insert(found, path)
		end
	end
	return found
end

local function mentionsContest(source: string): boolean
	if string.find(source, "Shared.RaidContest", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidContest", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidContest", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidContest")', 1, true) ~= nil then
		return true
	end
	return false
end

describe("RaidContest config", function()
	it("pins 48 hours and the placeholder item level cap", function()
		expect(RaidContest.CONFIG.durationSeconds).toEqual(DURATION)
		expect(RaidContest.CONFIG.durationSeconds).toEqual(48 * 3600)
		expect(RaidContest.CONFIG.itemLevelCap).toEqual(200)
		expect(RaidContest.CONFIG.maxIdLength).toEqual(64)
		expect(RaidContest.DIFFICULTIES.shardbreaker).toEqual(true)
		expect(RaidContest.DIFFICULTIES.story).toBeNil()
		expect(RaidContest.DIFFICULTIES.normal).toBeNil()
		expect(RaidContest.DIFFICULTIES.hard).toBeNil()
		expect(RaidContest.DIFFICULTIES.guided).toBeNil()
		expect(RaidContest.REFUSED.story).toEqual(true)
		expect(RaidContest.REFUSED.normal).toEqual(true)
		expect(RaidContest.REFUSED.hard).toEqual(true)
		expect(RaidContest.REFUSED.fracture).toEqual(true)
		expect(RaidContest.REFUSED.practice).toEqual(true)
		expect(RaidContest.REFUSED.guided).toEqual(true)
		expect(RaidContest.REFUSED.shardbreaker).toBeNil()
		expect(RaidContest.REASONS.window).toEqual("window")
		expect(RaidContest.REASONS.duplicate).toEqual("duplicate")
	end)

	it("freezes the config, the difficulties, and the errors", function()
		expect(function()
			RaidContest.CONFIG.durationSeconds = 86400
		end).toThrow()
		expect(function()
			RaidContest.CONFIG.itemLevelCap = 1
		end).toThrow()
		expect(function()
			RaidContest.DIFFICULTIES.hard = true
		end).toThrow()
		expect(function()
			RaidContest.REFUSED.shardbreaker = true
		end).toThrow()
		expect(function()
			RaidContest.REASONS.window = "open"
		end).toThrow()
		expect(function()
			RaidContest.ERRORS.skip = "fine"
		end).toThrow()
	end)

	it("has no Robux price and does not scale raid marks", function()
		local banned = {
			robux = true,
			premium = true,
			productid = true,
			gamepass = true,
			skip = true,
			price = true,
			power = true,
			doublemarks = true,
			marks = true,
		}
		for key in pairs(RaidContest.CONFIG) do
			expect(banned[string.lower(key)]).toBeNil()
		end
		expect(RaidContest.CONFIG.doubleMarks).toBeNil()
		expect(RaidMarks.CONFIG.doubleMarks).toEqual(false)
	end)

	it("is not required by src and does not reach a service", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidContest.luau")
		local banned = {
			"require(",
			"RaidGuided",
			"RaidMarks",
			"doubleMarks",
			"math.random",
			"os.time",
			"os.clock",
			"Random.new",
			"GetService",
			"DataStoreService",
			"MemoryStoreService",
			"MarketplaceService",
			"DateTime",
			"tick(",
			"task.wait",
		}
		for _, needle in ipairs(banned) do
			expect(string.find(source, needle, 1, true)).toBeNil()
		end
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if
				path ~= "src/ReplicatedStorage/Shared/RaidContest.luau"
				and mentionsContest(fs.readFile(path))
			then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)

describe("RaidContest open", function()
	it("starts an empty contest and ignores a preloaded award", function()
		local ctx = {
			raidId = " Heartwood ",
			openedAt = OPEN,
			statue = true,
			announce = true,
			firstRunId = "nope",
			firstRoster = { 1 },
			credited = { 1 },
			runs = { "nope" },
			durationSeconds = 60,
			itemLevelCap = 1,
			practice = true,
			guided = true,
		}
		local before = clone(ctx)
		local result = RaidContest.open(ctx)
		expect(ctx).toEqual(before)
		expect(result).toEqual({
			ok = true,
			persist = true,
			state = {
				raidId = "Heartwood",
				openedAt = OPEN,
				statue = false,
				announce = false,
				firstRoster = {},
				credited = {},
				runs = {},
			},
		})
		local lowered = RaidContest.open({
			raidId = "heartwood",
			openedAt = OPEN,
		})
		expect(lowered.state.raidId).toEqual("heartwood")
		expect(lowered.state.raidId == result.state.raidId).toEqual(false)
		local capped = RaidContest.gear(result.state, 200, OPEN + 61)
		expect(capped.ok).toEqual(true)
		expect(capped.allowed).toEqual(true)
		expect(capped.cap).toEqual(200)
	end)

	it("refuses a bad open, a bad clock, and a paid skip", function()
		local blank = {
			raidId = "",
			openedAt = 0,
			statue = false,
			announce = false,
			firstRoster = {},
			credited = {},
			runs = {},
		}
		local cases = {
			{ nil, nil, ERRORS.open },
			{ "heartwood", nil, ERRORS.open },
			{ {}, nil, ERRORS.raid },
			{ { raidId = "heartwood" }, nil, ERRORS.time },
			{ { openedAt = OPEN }, nil, ERRORS.raid },
			{ { raidId = "  ", openedAt = OPEN }, nil, ERRORS.raid },
			{ { raidId = "", openedAt = OPEN }, nil, ERRORS.raid },
			{ { raidId = 1, openedAt = OPEN }, nil, ERRORS.raid },
			{ { raidId = string.rep("a", 65), openedAt = OPEN }, nil, ERRORS.raid },
			{ { raidId = "heartwood", openedAt = -1 }, nil, ERRORS.time },
			{ { raidId = "heartwood", openedAt = 1.5 }, nil, ERRORS.time },
			{ { raidId = "heartwood", openedAt = 0 / 0 }, nil, ERRORS.time },
			{ { raidId = "heartwood", openedAt = math.huge }, nil, ERRORS.time },
			{ { raidId = "heartwood", openedAt = "1700000000" }, nil, ERRORS.time },
			{ { raidId = "heartwood", openedAt = OPEN, skip = true }, nil, ERRORS.skip },
			{ { raidId = "heartwood", openedAt = OPEN, waiveCap = false }, nil, ERRORS.skip },
			{ { raidId = "heartwood", openedAt = OPEN, robux = 50 }, nil, ERRORS.skip },
			{ { raidId = "heartwood", openedAt = OPEN }, { durationSeconds = 1 }, ERRORS.skip },
			{ { [1] = "heartwood", raidId = "heartwood", openedAt = OPEN }, nil, ERRORS.open },
		}
		for _, case in ipairs(cases) do
			local result = RaidContest.open(case[1], case[2])
			expect(result.ok).toEqual(false)
			expect(result.persist).toEqual(false)
			expect(result.error).toEqual(case[3])
			expect(result.state).toEqual(blank)
		end
		local longId = RaidContest.open({
			raidId = string.rep("b", 64),
			openedAt = 0,
		})
		expect(longId.ok).toEqual(true)
		expect(longId.state.raidId).toEqual(string.rep("b", 64))
		expect(longId.state.openedAt).toEqual(0)
	end)
end)

describe("RaidContest gear", function()
	it("allows a whole level at or under the cap inside the window", function()
		local state = opened()
		local floor = RaidContest.gear(state, 0, OPEN)
		local cap = RaidContest.gear(state, 200, OPEN + DURATION - 1)
		expect(floor).toEqual({
			ok = true,
			persist = false,
			allowed = true,
			inside = true,
			state = state,
			itemLevel = 0,
			cap = 200,
		})
		expect(cap.ok).toEqual(true)
		expect(cap.allowed).toEqual(true)
		expect(cap.inside).toEqual(true)
		expect(cap.itemLevel).toEqual(200)
		expect(cap.persist).toEqual(false)
		expect(cap.state == state).toEqual(false)
		expect(cap.state).toEqual(state)
	end)

	it("keeps the cap for the whole 48 hours", function()
		local state = opened()
		local atOpen = RaidContest.gear(state, 201, OPEN)
		local atOneDay = RaidContest.gear(state, 201, OPEN + DAY)
		local atLast = RaidContest.gear(state, 201, OPEN + DURATION - 1)
		expect(atOpen.error).toEqual(ERRORS.gear)
		expect(atOpen.allowed).toEqual(false)
		expect(atOpen.inside).toEqual(true)
		expect(atOpen.itemLevel).toEqual(201)
		expect(atOpen.persist).toEqual(false)
		expect(atOneDay.error).toEqual(ERRORS.gear)
		expect(atOneDay.inside).toEqual(true)
		expect(atLast.error).toEqual(ERRORS.gear)
		expect(atLast.ok).toEqual(false)
		expect(atLast.state).toEqual(state)
	end)

	it("allows every finite whole level outside the window", function()
		local state = opened()
		local before = RaidContest.gear(state, 999999, OPEN - 1)
		local atEnd = RaidContest.gear(state, 201, OPEN + DURATION)
		local later = RaidContest.gear(state, 0, OPEN + DURATION + DAY)
		expect(before).toEqual({
			ok = true,
			persist = false,
			allowed = true,
			inside = false,
			state = state,
			itemLevel = 999999,
			cap = 200,
		})
		expect(atEnd.ok).toEqual(true)
		expect(atEnd.allowed).toEqual(true)
		expect(atEnd.inside).toEqual(false)
		expect(atEnd.itemLevel).toEqual(201)
		expect(later.allowed).toEqual(true)
		expect(later.inside).toEqual(false)
		expect(before.state == state).toEqual(false)
	end)

	it("refuses a level that is not a finite whole number", function()
		local state = opened()
		local bad = { -1, 1.5, 200.2, 0 / 0, math.huge, -math.huge, "200", true, {} }
		for _, level in ipairs(bad) do
			local inside = RaidContest.gear(state, level, OPEN)
			local outside = RaidContest.gear(state, level, OPEN + DURATION)
			expect(inside.ok).toEqual(false)
			expect(inside.allowed).toEqual(false)
			expect(inside.error).toEqual(ERRORS.level)
			expect(inside.itemLevel).toEqual(0)
			expect(inside.inside).toEqual(true)
			expect(outside.error).toEqual(ERRORS.level)
			expect(outside.inside).toEqual(false)
			expect(outside.persist).toEqual(false)
		end
		expect(RaidContest.gear(state, nil, OPEN).error).toEqual(ERRORS.level)
		expect(RaidContest.gear(state, 10, OPEN + 0.5).error).toEqual(ERRORS.time)
		expect(RaidContest.gear(state, 10, -1).error).toEqual(ERRORS.time)
		expect(RaidContest.gear(state, 10, nil).error).toEqual(ERRORS.time)
		expect(RaidContest.gear(nil, 10, OPEN).error).toEqual(ERRORS.state)
		expect(RaidContest.gear(nil, 10, OPEN).persist).toEqual(false)
		expect(RaidContest.gear(nil, 10, OPEN).state.raidId).toEqual("")
	end)

	it("does not let Guided or a paid flag waive the cap", function()
		local state = opened()
		local before = clone(state)
		freezeDeep(state)
		local guided = RaidContest.gear(state, 201, OPEN, { guided = true })
		local waive = RaidContest.gear(state, 201, OPEN, { waiveCap = true })
		local skip = RaidContest.gear(state, 0, OPEN, { skip = false })
		expect(guided.error).toEqual(ERRORS.skip)
		expect(guided.allowed).toEqual(false)
		expect(guided.persist).toEqual(false)
		expect(waive.error).toEqual(ERRORS.skip)
		expect(skip.error).toEqual(ERRORS.skip)
		expect(skip.ok).toEqual(false)
		expect(state).toEqual(before)
		local poisoned = clone(state)
		poisoned.waiveCap = true
		local stillCapped = RaidContest.gear(poisoned, 201, OPEN)
		expect(stillCapped.error).toEqual(ERRORS.gear)
		expect(stillCapped.allowed).toEqual(false)
		expect(poisoned.waiveCap).toEqual(true)
	end)
end)

describe("RaidContest clear", function()
	it("gives the first clear the statue, the announcement, and the emblem", function()
		local state = opened("heartwood")
		local roster = { 4, 1, 9 }
		local record = {
			runId = " run-1 ",
			difficulty = " Shardbreaker ",
			practice = false,
			guided = true,
			roster = roster,
		}
		local before = clone(state)
		local recordBefore = clone(record)
		local result = RaidContest.clear(state, record, OPEN)
		expect(state).toEqual(before)
		expect(record).toEqual(recordBefore)
		expect(roster).toEqual({ 4, 1, 9 })
		expect(result).toEqual({
			ok = true,
			persist = true,
			counted = true,
			statue = true,
			announce = true,
			emblem = { 4, 1, 9 },
			runId = "run-1",
			state = {
				raidId = "heartwood",
				openedAt = OPEN,
				statue = true,
				announce = true,
				firstRunId = "run-1",
				firstRoster = { 4, 1, 9 },
				credited = { 4, 1, 9 },
				runs = { "run-1" },
			},
		})
		expect(result.emblem == roster).toEqual(false)
		expect(result.state == state).toEqual(false)
		expect(result.state.guided).toBeNil()
		expect(result.state.firstRoster == roster).toEqual(false)
		for key in pairs(result) do
			local lower = string.lower(tostring(key))
			expect(lower == "robux" or lower == "price" or lower == "marks").toEqual(false)
		end
	end)

	it("emblems only new raiders and does not set the statue again", function()
		local state = opened()
		local first = RaidContest.clear(state, {
			runId = "alpha",
			difficulty = "SHARDBREAKER",
			roster = { 10, 20, 30 },
		}, OPEN)
		expect(first.counted).toEqual(true)
		local firstState = clone(first.state)
		local second = RaidContest.clear(first.state, {
			runId = "beta",
			difficulty = "shardbreaker",
			guided = false,
			roster = { 20, 40, 30 },
		}, OPEN + 10)
		expect(first.state).toEqual(firstState)
		expect(second).toEqual({
			ok = true,
			persist = true,
			counted = true,
			statue = false,
			announce = false,
			emblem = { 40 },
			runId = "beta",
			state = {
				raidId = "heartwood",
				openedAt = OPEN,
				statue = true,
				announce = true,
				firstRunId = "alpha",
				firstRoster = { 10, 20, 30 },
				credited = { 10, 20, 30, 40 },
				runs = { "alpha", "beta" },
			},
		})
		local third = RaidContest.clear(second.state, {
			runId = "gamma",
			difficulty = "shardbreaker",
			roster = { 10, 40 },
		}, OPEN + 20)
		expect(third.ok).toEqual(true)
		expect(third.persist).toEqual(true)
		expect(third.counted).toEqual(true)
		expect(third.statue).toEqual(false)
		expect(third.announce).toEqual(false)
		expect(third.emblem).toEqual({})
		expect(third.state.statue).toEqual(true)
		expect(third.state.announce).toEqual(true)
		expect(third.state.firstRoster).toEqual({ 10, 20, 30 })
		expect(third.state.credited).toEqual({ 10, 20, 30, 40 })
		expect(third.state.runs).toEqual({ "alpha", "beta", "gamma" })
	end)

	it("treats the same run id as a no-op", function()
		local state = opened()
		local first = RaidContest.clear(state, {
			runId = "alpha",
			difficulty = "shardbreaker",
			roster = { 1, 2 },
		}, OPEN)
		local again = RaidContest.clear(first.state, {
			runId = " alpha ",
			difficulty = "story",
			practice = true,
			roster = { 99 },
		}, OPEN + DURATION)
		expect(again).toEqual({
			ok = true,
			persist = false,
			counted = false,
			statue = false,
			announce = false,
			emblem = {},
			runId = "alpha",
			reason = REASONS.duplicate,
			state = first.state,
		})
		expect(again.state == first.state).toEqual(false)
		expect(again.state.credited).toEqual({ 1, 2 })
		local numeric = RaidContest.clear(opened(), {
			runId = 7,
			difficulty = "shardbreaker",
			roster = { 3 },
		}, OPEN)
		local text = RaidContest.clear(numeric.state, {
			runId = "7",
			difficulty = "shardbreaker",
			roster = { 3, 8 },
		}, OPEN + 1)
		expect(numeric.statue).toEqual(true)
		expect(numeric.runId).toEqual(7)
		expect(text.statue).toEqual(false)
		expect(text.counted).toEqual(true)
		expect(text.emblem).toEqual({ 8 })
		expect(text.state.runs).toEqual({ 7, "7" })
		expect(text.state.firstRunId).toEqual(7)
		local replay = RaidContest.clear(text.state, {
			runId = 7,
			difficulty = "shardbreaker",
			roster = { 8 },
		}, OPEN + 2)
		expect(replay.reason).toEqual(REASONS.duplicate)
		expect(replay.persist).toEqual(false)
		expect(replay.state.credited).toEqual({ 3, 8 })
	end)

	it("refuses a missing or unusable run id", function()
		local state = opened()
		local before = clone(state)
		local missing = RaidContest.clear(state, {
			difficulty = "shardbreaker",
			roster = { 1 },
		}, OPEN)
		local blank = RaidContest.clear(state, {
			runId = "  ",
			difficulty = "shardbreaker",
			roster = { 1 },
		}, OPEN)
		local bad = {
			RaidContest.clear(
				state,
				{ runId = "", difficulty = "shardbreaker", roster = { 1 } },
				OPEN
			),
			RaidContest.clear(
				state,
				{ runId = 0, difficulty = "shardbreaker", roster = { 1 } },
				OPEN
			),
			RaidContest.clear(
				state,
				{ runId = -3, difficulty = "shardbreaker", roster = { 1 } },
				OPEN
			),
			RaidContest.clear(
				state,
				{ runId = 1.5, difficulty = "shardbreaker", roster = { 1 } },
				OPEN
			),
			RaidContest.clear(
				state,
				{ runId = true, difficulty = "shardbreaker", roster = { 1 } },
				OPEN
			),
			RaidContest.clear(
				state,
				{ runId = {}, difficulty = "shardbreaker", roster = { 1 } },
				OPEN
			),
			RaidContest.clear(
				state,
				{ runId = string.rep("r", 65), difficulty = "shardbreaker", roster = { 1 } },
				OPEN
			),
		}
		expect(missing.error).toEqual(ERRORS.runId)
		expect(missing.persist).toEqual(false)
		expect(missing.counted).toEqual(false)
		expect(missing.statue).toEqual(false)
		expect(missing.runId).toBeNil()
		expect(blank.error).toEqual(ERRORS.runId)
		for _, result in ipairs(bad) do
			expect(result.error).toEqual(ERRORS.runId)
			expect(result.persist).toEqual(false)
			expect(result.state.statue).toEqual(false)
			expect(result.state.runs).toEqual({})
		end
		expect(state).toEqual(before)
		local longRun = RaidContest.clear(state, {
			runId = string.rep("r", 64),
			difficulty = "shardbreaker",
			roster = { 5 },
		}, OPEN)
		expect(longRun.ok).toEqual(true)
		expect(longRun.state.firstRunId).toEqual(string.rep("r", 64))
	end)

	it("counts Shardbreaker only", function()
		local state = opened()
		local before = clone(state)
		local refused = {
			"story",
			"normal",
			"hard",
			"fracture",
			"practice",
			"guided",
			" Story ",
			"HARD",
			"GUIDED",
			"Fracture 3",
			"fracture-1",
			"fracture1",
			"mythic",
			"shard breaker",
			"",
		}
		for _, difficulty in ipairs(refused) do
			local result = RaidContest.clear(state, {
				runId = "run-" .. difficulty,
				difficulty = difficulty,
				guided = true,
				roster = { 1, 2, 3, 4 },
			}, OPEN)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.difficulty)
			expect(result.counted).toEqual(false)
			expect(result.statue).toEqual(false)
			expect(result.emblem).toEqual({})
			expect(result.persist).toEqual(false)
		end
		local missing = RaidContest.clear(state, {
			runId = "no-difficulty",
			roster = { 1 },
		}, OPEN)
		expect(missing.error).toEqual(ERRORS.difficulty)
		expect(RaidContest.clear(state, {
			runId = "bad-type",
			difficulty = 1,
			roster = { 1 },
		}, OPEN).error).toEqual(ERRORS.difficulty)
		expect(state).toEqual(before)
	end)

	it("refuses practice and still counts a Guided Shardbreaker clear", function()
		local state = opened()
		local practice = RaidContest.clear(state, {
			runId = "grove",
			difficulty = "shardbreaker",
			practice = true,
			roster = { 1, 2, 3, 4 },
		}, OPEN)
		expect(practice.ok).toEqual(false)
		expect(practice.error).toEqual(ERRORS.practice)
		expect(practice.counted).toEqual(false)
		expect(practice.persist).toEqual(false)
		expect(practice.statue).toEqual(false)
		expect(practice.state.runs).toEqual({})
		local flagged = RaidContest.clear(state, {
			runId = "flag",
			difficulty = "story",
			practice = true,
			roster = { 1 },
		}, OPEN)
		expect(flagged.error).toEqual(ERRORS.practice)
		local badFlag = RaidContest.clear(state, {
			runId = "bad-flag",
			difficulty = "shardbreaker",
			practice = "true",
			roster = { 1 },
		}, OPEN)
		expect(badFlag.error).toEqual(ERRORS.practiceFlag)
		expect(RaidContest.clear(state, {
			runId = "number-flag",
			difficulty = "shardbreaker",
			practice = 1,
			roster = { 1 },
		}, OPEN).error).toEqual(ERRORS.practiceFlag)
		local guidedFlag = RaidContest.clear(state, {
			runId = "guided-flag",
			difficulty = "shardbreaker",
			guided = "true",
			roster = { 1 },
		}, OPEN)
		expect(guidedFlag.error).toEqual(ERRORS.guided)
		local guided = RaidContest.clear(state, {
			runId = "guided-clear",
			difficulty = "shardbreaker",
			guided = true,
			roster = { 8 },
		}, OPEN + DURATION - 1)
		expect(guided.counted).toEqual(true)
		expect(guided.statue).toEqual(true)
		expect(guided.announce).toEqual(true)
		expect(guided.emblem).toEqual({ 8 })
		expect(guided.state.guided).toBeNil()
		local stillCapped = RaidContest.gear(guided.state, 201, OPEN + DURATION - 1)
		expect(stillCapped.allowed).toEqual(false)
		expect(stillCapped.error).toEqual(ERRORS.gear)
	end)

	it("counts nothing outside the window", function()
		local state = opened()
		local late = RaidContest.clear(state, {
			runId = "late",
			difficulty = "shardbreaker",
			roster = { 1, 2 },
		}, OPEN + DURATION)
		expect(late).toEqual({
			ok = true,
			persist = false,
			counted = false,
			statue = false,
			announce = false,
			emblem = {},
			runId = "late",
			reason = REASONS.window,
			state = state,
		})
		local early = RaidContest.clear(state, {
			runId = "early",
			difficulty = "shardbreaker",
			roster = { 5 },
		}, OPEN - 1)
		expect(early.reason).toEqual(REASONS.window)
		expect(early.persist).toEqual(false)
		expect(early.counted).toEqual(false)
		expect(early.state.statue).toEqual(false)
		local stillFirst = RaidContest.clear(state, {
			runId = "late",
			difficulty = "shardbreaker",
			roster = { 1, 2 },
		}, OPEN)
		expect(stillFirst.counted).toEqual(true)
		expect(stillFirst.statue).toEqual(true)
		expect(stillFirst.announce).toEqual(true)
		expect(stillFirst.emblem).toEqual({ 1, 2 })
		expect(stillFirst.state.runs).toEqual({ "late" })
		local onTime = RaidContest.clear(opened(), {
			runId = "edge",
			difficulty = "shardbreaker",
			roster = { 6, 7, 8, 9 },
		}, OPEN + DURATION - 1)
		expect(onTime.counted).toEqual(true)
		expect(onTime.statue).toEqual(true)
		expect(onTime.emblem).toEqual({ 6, 7, 8, 9 })
	end)

	it("refuses an empty, duplicate, or non-id roster", function()
		local state = opened()
		expect(RaidContest.clear(state, {
			runId = "empty",
			difficulty = "shardbreaker",
			roster = {},
		}, OPEN).error).toEqual(ERRORS.empty)
		expect(RaidContest.clear(state, {
			runId = "twice",
			difficulty = "shardbreaker",
			roster = { 1, 1 },
		}, OPEN).error).toEqual(ERRORS.duplicate)
		expect(RaidContest.clear(state, {
			runId = "zero",
			difficulty = "shardbreaker",
			roster = { 0 },
		}, OPEN).error).toEqual(ERRORS.userId)
		expect(RaidContest.clear(state, {
			runId = "negative",
			difficulty = "shardbreaker",
			roster = { 1, -2 },
		}, OPEN).error).toEqual(ERRORS.userId)
		expect(RaidContest.clear(state, {
			runId = "fraction",
			difficulty = "shardbreaker",
			roster = { 1.5 },
		}, OPEN).error).toEqual(ERRORS.userId)
		expect(RaidContest.clear(state, {
			runId = "text-id",
			difficulty = "shardbreaker",
			roster = { "1" },
		}, OPEN).error).toEqual(ERRORS.userId)
		expect(RaidContest.clear(state, {
			runId = "member",
			difficulty = "shardbreaker",
			roster = { { userId = 1 } },
		}, OPEN).error).toEqual(ERRORS.userId)
		expect(RaidContest.clear(state, {
			runId = "missing-roster",
			difficulty = "shardbreaker",
		}, OPEN).error).toEqual(ERRORS.roster)
		expect(RaidContest.clear(state, {
			runId = "map",
			difficulty = "shardbreaker",
			roster = { userId = 1 },
		}, OPEN).error).toEqual(ERRORS.roster)
		expect(RaidContest.clear(state, {
			runId = "hole",
			difficulty = "shardbreaker",
			roster = { [1] = 1, [3] = 2 },
		}, OPEN).error).toEqual(ERRORS.roster)
		expect(state.statue).toEqual(false)
		expect(state.runs).toEqual({})
	end)

	it("refuses a paid skip of the window or the first clear", function()
		local state = opened()
		local before = clone(state)
		local extra = RaidContest.clear(state, {
			runId = "paid",
			difficulty = "shardbreaker",
			roster = { 1 },
		}, OPEN + DURATION, { skipWindow = true })
		expect(extra.error).toEqual(ERRORS.skip)
		expect(extra.counted).toEqual(false)
		expect(extra.persist).toEqual(false)
		local fields =
			{ "skip", "waive", "waiveCap", "paid", "robux", "premium", "forceFirst", "price" }
		for _, field in ipairs(fields) do
			local record = {
				runId = "paid-" .. field,
				difficulty = "shardbreaker",
				roster = { 1, 2 },
			}
			record[field] = true
			local result = RaidContest.clear(state, record, OPEN)
			expect(result.error).toEqual(ERRORS.skip)
			expect(result.statue).toEqual(false)
			expect(result.persist).toEqual(false)
		end
		expect(RaidContest.clear(state, { 1, 2, 3 }, OPEN).error).toEqual(ERRORS.record)
		expect(RaidContest.clear(state, "shardbreaker", OPEN).error).toEqual(ERRORS.record)
		expect(RaidContest.clear(state, nil, OPEN).error).toEqual(ERRORS.record)
		expect(state).toEqual(before)
	end)

	it("rejects a broken record without throwing", function()
		local broken = {
			"heartwood",
			4,
			{},
			{
				raidId = " heartwood",
				openedAt = OPEN,
				statue = false,
				announce = false,
				firstRoster = {},
				credited = {},
				runs = {},
			},
			{
				raidId = "heartwood",
				openedAt = OPEN,
				statue = true,
				announce = false,
				firstRoster = {},
				credited = {},
				runs = {},
			},
			{
				raidId = "heartwood",
				openedAt = OPEN,
				statue = false,
				announce = true,
				firstRoster = {},
				credited = {},
				runs = {},
			},
			{
				raidId = "heartwood",
				openedAt = OPEN,
				statue = false,
				announce = false,
				firstRoster = {},
				credited = { 1 },
				runs = {},
			},
			{
				raidId = "heartwood",
				openedAt = OPEN,
				statue = true,
				announce = true,
				firstRunId = "a",
				firstRoster = { 1 },
				credited = { 2 },
				runs = { "a" },
			},
			{
				raidId = "heartwood",
				openedAt = OPEN,
				statue = true,
				announce = true,
				firstRunId = 1,
				firstRoster = { 1 },
				credited = { 1 },
				runs = { "1" },
			},
			{
				raidId = "heartwood",
				openedAt = OPEN,
				statue = true,
				announce = true,
				firstRunId = "a",
				firstRoster = { 1, 2 },
				credited = { 2, 1 },
				runs = { "a" },
			},
			{
				raidId = "heartwood",
				openedAt = 1.5,
				statue = false,
				announce = false,
				firstRoster = {},
				credited = {},
				runs = {},
			},
		}
		local missing = RaidContest.clear(nil, {
			runId = "x",
			difficulty = "shardbreaker",
			roster = { 1 },
		}, OPEN)
		expect(missing.error).toEqual(ERRORS.state)
		expect(missing.persist).toEqual(false)
		expect(RaidContest.gear(nil, 10, OPEN).error).toEqual(ERRORS.state)
		for _, state in ipairs(broken) do
			local cleared = RaidContest.clear(state, {
				runId = "x",
				difficulty = "shardbreaker",
				roster = { 1 },
			}, OPEN)
			local geared = RaidContest.gear(state, 10, OPEN)
			expect(cleared.ok).toEqual(false)
			expect(cleared.error).toEqual(ERRORS.state)
			expect(cleared.persist).toEqual(false)
			expect(cleared.counted).toEqual(false)
			expect(cleared.statue).toEqual(false)
			expect(cleared.state.raidId).toEqual("")
			expect(geared.ok).toEqual(false)
			expect(geared.error).toEqual(ERRORS.state)
			expect(geared.persist).toEqual(false)
			expect(geared.allowed).toEqual(false)
		end
	end)

	it("returns new tables and does not write a frozen input", function()
		local state = opened()
		local record = {
			runId = "frozen",
			difficulty = "shardbreaker",
			practice = false,
			guided = true,
			roster = { 4, 5 },
		}
		local beforeState = clone(state)
		local beforeRecord = clone(record)
		freezeDeep(state)
		freezeDeep(record)
		local result = RaidContest.clear(state, record, OPEN)
		expect(result.ok).toEqual(true)
		expect(result.state == state).toEqual(false)
		expect(result.state.credited == state.credited).toEqual(false)
		expect(result.state.runs == state.runs).toEqual(false)
		expect(result.state.firstRoster == record.roster).toEqual(false)
		expect(result.emblem == record.roster).toEqual(false)
		expect(state).toEqual(beforeState)
		expect(record).toEqual(beforeRecord)
		local other = opened("other-raid")
		expect(other.raidId).toEqual("other-raid")
		expect(other.statue).toEqual(false)
		expect(other.runs).toEqual({})
		local geared = RaidContest.gear(result.state, 200, OPEN)
		expect(geared.persist).toEqual(false)
		expect(geared.state == result.state).toEqual(false)
		expect(geared.state).toEqual(result.state)
	end)
end)
