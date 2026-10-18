--!strict

--[[
	RollBatch is pure and the Roll tab does not run under Lune. The
	source lock checks that x10 asks before it invokes, and that a
	wide caption hides the shard stone.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RollBatch = require("../src/ReplicatedStorage/Shared/RollBatch")

local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

describe("RollBatch", function()
	it("says Need 10 shards when a batch is short", function()
		expect(RollBatch.NEED).toEqual("Need 10 shards")
		expect(RollBatch.block(0, 10)).toEqual("Need 10 shards")
		expect(RollBatch.block(9, 10)).toEqual("Need 10 shards")
		expect(RollBatch.block(-3, 10)).toEqual("Need 10 shards")
		expect(RollBatch.block(nil, 10)).toEqual("Need 10 shards")
		expect(RollBatch.block("0", 10)).toEqual("Need 10 shards")
		expect(RollBatch.block(0 / 0, 10)).toEqual("Need 10 shards")
		expect(RollBatch.block(math.huge, 12)).toEqual("Need 10 shards")
		expect(RollBatch.block(10, 10)).toBeNil()
		expect(RollBatch.block(11, 10)).toBeNil()
		expect(RollBatch.block(0, 1)).toBeNil()
		expect(RollBatch.block(0, 9)).toBeNil()
		expect(RollBatch.block(0, nil)).toBeNil()
		expect(RollBatch.block(0, 10, { paid = true, cost = 25 })).toEqual(RollBatch.block(0, 10))
		expect(RollBatch.block(10, 10, true)).toBeNil()
	end)

	it("is what x10 checks before the invoke", function()
		local hub = fs.readFile(HUB)
		local pressAt = string.find(hub, 'if id == "TimesTen" then', 1, true)
		expect(pressAt ~= nil).toBeTrue()
		local second = string.find(hub, 'if id == "TimesTen" then', (pressAt or 1) + 1, true)
		expect(second ~= nil).toBeTrue()
		local press = string.sub(hub, second or 1, (second or 1) + 700)
		local blockAt = string.find(press, "RollBatch.block(hubFn.tokenCount(), 10)", 1, true)
		local beginAt = string.find(press, "hubFn.beginRoll()", 1, true)
		expect(blockAt ~= nil and beginAt ~= nil and (blockAt :: number) < (beginAt :: number)).toBeTrue()
		expect(string.find(press, "hubFn.paintReelIdle(why)", 1, true) ~= nil).toBeTrue()
		expect(string.find(press, "hubFn.showMilestone(why)", 1, true) ~= nil).toBeTrue()
		expect(string.find(press, '"RollShards"', 1, true)).toBeNil()
		local idleAt = string.find(hub, "hubFn.paintReelIdle = function(caption: string)", 1, true)
		expect(idleAt ~= nil).toBeTrue()
		local idle = string.sub(hub, idleAt or 1, (idleAt or 1) + 700)
		expect(string.find(idle, "shardStone.Visible = not wide", 1, true) ~= nil).toBeTrue()
		local restAt = string.find(hub, "hubFn.restShard = function()\n", 1, true)
		expect(restAt ~= nil).toBeTrue()
		local rest = string.sub(hub, restAt or 1, (restAt or 1) + 500)
		expect(string.find(rest, "shardStone.Visible = true", 1, true) ~= nil).toBeTrue()
	end)
end)
