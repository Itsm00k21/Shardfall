--!strict

--[[
	Havoc audit of #455 (DP32).

	Run Again must mint a server-unique id that still pays after forget.
	The results clock must send the player home and clear that run.
	Run Again must wait until the previous payout has settled.
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
end)
