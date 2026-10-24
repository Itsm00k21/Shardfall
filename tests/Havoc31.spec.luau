--!strict

--[[
	Havoc audit of #455 (DP32) and the results-return re-entry (DP36).

	Run Again must mint a server-unique id that still pays after forget.
	The results clock must send the player home and clear that run.
	Run Again must wait until the previous payout has settled.
	A heartbeat during the return save must not start another save.
	A failed return save keeps the run seated for the next try.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Loot = require("../src/server/WaveArena/Loot")
local RunResults = require("../src/ReplicatedStorage/Shared/RunResults")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")
local WaveArenaHost = require("../src/ServerScriptService/ShardfallServer/WaveArenaHost")
-- Load the arena modules on this thread. The first require from inside a
-- coroutine yields in Lune, which would look like the save yield.
require("../src/server/WaveArena")
require("../src/server/WaveArena/Settle")

local GUID = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local function isGuid(id: any): boolean
	return type(id) == "string" and string.match(id, GUID) ~= nil
end

local function withResults(run: () -> ())
	local previous = LaunchGate.SHOW.m12Results
	LaunchGate.SHOW.m12Results = true
	RunResults.reset()
	local ok, err = pcall(run)
	LaunchGate.SHOW.m12Results = previous
	RunResults.reset()
	if not ok then
		error(err, 0)
	end
end

local function ended(ownerId: number, receiptId: string, paid: boolean): any
	return {
		ownerId = ownerId,
		tier = "normal",
		party = 1,
		phase = "results",
		settled = true,
		payoutSettled = paid,
		reason = "clear",
		receiptId = receiptId,
		wavesCleared = 1,
		total = 5,
	}
end

local function purse(id: string, tokens: number): any
	return {
		receiptId = id,
		grantList = {
			{ kind = "purse", tokens = tokens, wave = 1 },
		},
	}
end

describe("Havoc DP31", function()
	it("mints a new run id after forget and the second run pays", function()
		expect(LaunchGate.SHOW.m12Results).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		expect(Schema.template().payoutSettled).toBeNil()
		expect(Schema.template().bestWave).toBeNil()

		withResults(function()
			local data = Schema.template()
			local before = data.shardTokens
			local first = RunResults.again(31, ended(31, "results-a", true), data, nil, 10, false)
			expect(first.started).toEqual(true)
			expect(isGuid(first.runId)).toBeTrue()
			local paid = Loot.commit(data, purse(first.runId, 4))
			expect(paid.tokens).toEqual(4)

			RunResults.forget(31)

			local second = RunResults.again(31, ended(31, "results-b", true), data, nil, 20, false)
			expect(second.started).toEqual(true)
			expect(isGuid(second.runId)).toBeTrue()
			expect(second.runId == first.runId).toBeFalse()
			local again = Loot.commit(data, purse(second.runId, 5))
			expect(again.tokens).toEqual(5)
			expect(data.shardTokens).toEqual(before + 9)
			expect(Schema.VERSION).toEqual(26)
		end)

		local source = fs.readFile("src/ReplicatedStorage/Shared/RunResults.luau")
		expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(source, "GenerateGUID", 1, true) ~= nil).toBeTrue()
	end)

	it("sends the results player home at return time unless a new run started", function()
		local parked = {
			run = {
				phase = "results",
				card = { returnAt = 1 },
			},
			inArena = true,
		}
		expect(RunResults.releaseSeat(parked, 100)).toEqual("stay")
		expect(parked.inArena).toEqual(true)
		expect(parked.run.phase).toEqual("results")

		withResults(function()
			local run = {
				phase = "results",
				reason = "wipe",
				card = { returnAt = 1030 },
			}
			local seat = { run = run, inArena = true }
			expect(RunResults.releaseSeat(seat, 1029.9)).toEqual("stay")
			expect(seat.run).toEqual(run)
			expect(seat.inArena).toEqual(true)
			expect(RunResults.releaseSeat(seat, 1030)).toEqual("hub")
			expect(seat.run).toBeNil()
			expect(seat.inArena).toBeNil()

			local fresh = {
				phase = "fight",
				receiptId = "new-run",
				card = { returnAt = 1 },
				returnAt = 1,
			}
			local kept = { run = fresh, inArena = true }
			expect(RunResults.releaseSeat(kept, 100)).toEqual("keep")
			expect(kept.run).toEqual(fresh)
			expect(kept.inArena).toEqual(true)
		end)

		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "function WaveArenaHost.recall", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "RunResults.releaseSeat", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "Heartbeat", 1, true) ~= nil).toBeTrue()
	end)

	it("refuses Run Again until the previous payout has settled", function()
		withResults(function()
			local data = Schema.template()
			local before = Schema.deepCopy(data)
			local run = ended(31, "unpaid", false)
			run.payoutSettled = nil
			local blocked = RunResults.again(31, run, data, nil, 40, false)
			expect(blocked.ok).toEqual(false)
			expect(blocked.started).toEqual(false)
			expect(blocked.runId).toBeNil()
			expect(blocked.error).toEqual("payout")
			expect(RunResults.markPaid(run, "retry")).toBeFalse()
			expect(run.payoutSettled).toBeNil()
			local still = RunResults.again(31, run, data, nil, 40, false)
			expect(still.error).toEqual("payout")
			expect(still.started).toEqual(false)

			expect(RunResults.markPaid(run, "paid")).toBeTrue()
			expect(run.payoutSettled).toEqual(true)
			local started = RunResults.again(31, run, data, nil, 40, false)
			expect(started.started).toEqual(true)
			expect(started.ok).toEqual(true)
			expect(isGuid(started.runId)).toBeTrue()

			local later = ended(31, "saved-already", false)
			expect(RunResults.markPaid(later, "again")).toBeTrue()
			local resumed = RunResults.again(31, later, data, nil, 42, false)
			expect(resumed.started).toEqual(true)
			expect(resumed.runId == started.runId).toBeFalse()
			expect(data).toEqual(before)
			expect(Schema.VERSION).toEqual(26)
		end)

		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "RunResults.markPaid(run, status)", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, 'RunResults.markPaid(run, "again")', 1, true) ~= nil).toBeTrue()
	end)

	it("does not save again while a results return save is still yielding", function()
		expect(LaunchGate.SHOW.m12Results).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect(Schema.VERSION).toEqual(26)

		local results = LaunchGate.SHOW.m12Results
		local arena = LaunchGate.SHOW.waveArena
		LaunchGate.SHOW.m12Results = true
		LaunchGate.SHOW.waveArena = true
		WaveArenaHost._open(true)
		local player = { UserId = 36 }
		local profile = Schema.template()
		local saves = 0
		local paused = false
		WaveArenaHost._profile(function()
			return profile
		end, function()
			saves += 1
			if not paused then
				paused = true
				coroutine.yield()
			end
			return false
		end)
		local run = {
			phase = "results",
			reason = "clear",
			settled = true,
			receiptId = "recall-yield",
			ownerId = 36,
			grantList = {},
			card = { returnAt = 100 },
		}
		WaveArenaHost._seat(player, run)
		local thread = coroutine.create(function()
			WaveArenaHost.recall(100)
		end)
		local resumed = coroutine.resume(thread)
		local ok, err = pcall(function()
			expect(resumed).toBeTrue()
			expect(coroutine.status(thread)).toEqual("suspended")
			expect(saves).toEqual(1)
			WaveArenaHost.recall(100)
			expect(saves).toEqual(1)
		end)
		if coroutine.status(thread) == "suspended" then
			coroutine.resume(thread)
		end
		WaveArenaHost._seat(player, nil)
		WaveArenaHost._profile(function()
			return nil
		end, function()
			return false
		end)
		WaveArenaHost._open(false)
		LaunchGate.SHOW.m12Results = results
		LaunchGate.SHOW.waveArena = arena
		expect(WaveArenaConfig.enabled).toEqual(false)
		if not ok then
			error(err, 0)
		end
	end)

	it("keeps a results run seated when the return save fails", function()
		local results = LaunchGate.SHOW.m12Results
		local arena = LaunchGate.SHOW.waveArena
		LaunchGate.SHOW.m12Results = true
		LaunchGate.SHOW.waveArena = true
		WaveArenaHost._open(true)
		local player = { UserId = 37 }
		local profile = Schema.template()
		local saves = 0
		WaveArenaHost._profile(function()
			return profile
		end, function()
			saves += 1
			return false
		end)
		WaveArenaHost._seat(player, {
			phase = "results",
			reason = "wipe",
			settled = true,
			receiptId = "recall-retry",
			ownerId = 37,
			grantList = {},
			card = { returnAt = 40 },
		})
		local ok, err = pcall(function()
			WaveArenaHost.recall(40)
			local first = saves
			expect(first).toBeGreaterThan(0)
			WaveArenaHost.recall(40)
			expect(saves).toBeGreaterThan(first)
		end)
		WaveArenaHost._seat(player, nil)
		WaveArenaHost._profile(function()
			return nil
		end, function()
			return false
		end)
		WaveArenaHost._open(false)
		LaunchGate.SHOW.m12Results = results
		LaunchGate.SHOW.waveArena = arena
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		expect(Schema.template().settling).toBeNil()
		if not ok then
			error(err, 0)
		end
	end)
end)
