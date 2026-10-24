--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local DungeonAdvance = require("../src/ServerScriptService/ShardfallServer/DungeonAdvance")
local RateLimiter = require("../src/ServerScriptService/ShardfallServer/RateLimiter")

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

local function at(source: string, needle: string, startAt: number?): number
	local found = string.find(source, needle, startAt or 1, true)
	assert(found ~= nil, "missing " .. needle)
	return found
end

local function rooms(count: number): { {} }
	local list = {}
	for _ = 1, count do
		table.insert(list, {})
	end
	return list
end

type Session = {
	player: {},
	run: any,
	runs: { [any]: any },
	advance: () -> string,
	spawned: () -> number,
}

local function session(roomCount: number, endless: boolean): Session
	local player = {}
	local run = {
		cleared = true,
		resolving = false,
		advanceAt = 10,
		offer = { { id = "spring" } },
		roomIndex = 1,
		placeIndex = 1,
		wave = 1,
		dungeon = {
			endless = endless,
			rooms = rooms(roomCount),
		},
	}
	local runs: { [any]: any } = { [player] = run }
	local spawned = 0
	local function advance(): string
		return DungeonAdvance.advance(runs[player], function()
			return runs[player]
		end, function()
			coroutine.yield("teleport")
		end, function(_kind: string)
			spawned += 1
		end)
	end
	return {
		player = player,
		run = run,
		runs = runs,
		advance = advance,
		spawned = function()
			return spawned
		end,
	}
end

-- Fire `count` advances before any of them resume past the stream yield.
local function burst(open: Session, count: number): { string }
	local threads = {}
	local results = {}
	for index = 1, count do
		threads[index] = coroutine.create(open.advance)
		local ok, value = coroutine.resume(threads[index])
		if not ok then
			error(tostring(value))
		end
		results[index] = value
	end
	for index = 1, count do
		if coroutine.status(threads[index]) == "suspended" then
			local ok, value = coroutine.resume(threads[index])
			if not ok then
				error(tostring(value))
			end
			results[index] = value
		end
	end
	return results
end

describe("Dungeon advance latch", function()
	it("advances one room when advance fires four times in one frame", function()
		local open = session(8, false)
		local results = burst(open, 4)
		local spawned = 0
		for _, result in ipairs(results) do
			if result == "spawned" then
				spawned += 1
			end
		end
		expect(spawned).toEqual(1)
		expect(open.spawned()).toEqual(1)
		expect(open.run.roomIndex).toEqual(2)
		expect(open.run.placeIndex).toEqual(2)
		expect(open.run.cleared).toEqual(false)
		expect(open.run.advanceAt).toBeNil()
		expect(open.run.offer).toBeNil()
		expect(results[1]).toEqual("spawned")
		expect(results[2]).toEqual("uncleared")
		expect(results[3]).toEqual("uncleared")
		expect(results[4]).toEqual("uncleared")
	end)

	it("advances one wave when advance fires four times in one frame", function()
		local open = session(1, true)
		local results = burst(open, 4)
		expect(results[1]).toEqual("spawned")
		expect(results[2]).toEqual("uncleared")
		expect(open.run.wave).toEqual(2)
		expect(open.spawned()).toEqual(1)
	end)

	it("spawns nothing when the player leaves during the teleport", function()
		local open = session(8, false)
		local thread = coroutine.create(open.advance)
		local started, yielded = coroutine.resume(thread)
		if not started then
			error(tostring(yielded))
		end
		expect(yielded).toEqual("teleport")
		expect(open.spawned()).toEqual(0)
		-- leave() marks the run ending before its own stream yield.
		open.run.resolving = true
		local resumed, outcome = coroutine.resume(thread)
		if not resumed then
			error(tostring(outcome))
		end
		expect(outcome).toEqual("bail")
		expect(open.spawned()).toEqual(0)

		local dropped = session(8, false)
		local leaving = coroutine.create(dropped.advance)
		local again, pause = coroutine.resume(leaving)
		if not again then
			error(tostring(pause))
		end
		expect(pause).toEqual("teleport")
		dropped.runs[dropped.player] = nil
		local done, after = coroutine.resume(leaving)
		if not done then
			error(tostring(after))
		end
		expect(after).toEqual("bail")
		expect(dropped.spawned()).toEqual(0)
	end)

	it("does not step past the last room", function()
		local open = session(1, false)
		expect(open.advance()).toEqual("last")
		expect(open.run.roomIndex).toEqual(1)
		expect(open.run.placeIndex).toEqual(1)
		expect(open.run.wave).toEqual(1)
		expect(open.run.cleared).toEqual(true)
		expect(open.run.advanceAt).toEqual(10)
		expect(open.run.offer).toEqual({ { id = "spring" } })
		expect(open.spawned()).toEqual(0)
		expect(open.advance()).toEqual("last")
	end)

	it("leaves the run untouched when the last room rejects", function()
		local open = session(1, false)
		local offer = open.run.offer
		table.freeze(open.run)
		expect(open.advance()).toEqual("last")
		expect(open.run.cleared).toEqual(true)
		expect(open.run.resolving).toEqual(false)
		expect(open.run.advanceAt).toEqual(10)
		expect(open.run.offer).toEqual(offer)
		expect(open.run.roomIndex).toEqual(1)
		expect(open.run.placeIndex).toEqual(1)
		expect(open.run.wave).toEqual(1)
		expect(open.spawned()).toEqual(0)
		expect(open.advance()).toEqual("last")

		local uncleared = session(1, false)
		uncleared.run.cleared = false
		table.freeze(uncleared.run)
		expect(uncleared.advance()).toEqual("uncleared")
		expect(uncleared.run.roomIndex).toEqual(1)

		local latch = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonAdvance.luau")
		local claim = between(latch, "local function begin", "function DungeonAdvance.live")
		local lastAt = at(claim, 'return "last"')
		local clearCleared = at(claim, "run.cleared = false")
		local clearAt = at(claim, "run.advanceAt = nil")
		local clearOffer = at(claim, "run.offer = nil")
		local waveAt = at(claim, "run.wave += 1")
		expect(lastAt < clearCleared).toBeTrue()
		expect(lastAt < clearAt).toBeTrue()
		expect(lastAt < clearOffer).toBeTrue()
		expect(lastAt < waveAt).toBeTrue()
	end)

	it("refuses a door while the run is ending or is not the current run", function()
		local run = {
			resolving = false,
			offer = { { id = "treasure" } },
		}
		expect(DungeonAdvance.live(run, run)).toEqual(true)
		expect(DungeonAdvance.live(nil, run)).toEqual(false)
		expect(DungeonAdvance.live({}, run)).toEqual(false)
		run.resolving = true
		expect(DungeonAdvance.live(run, run)).toEqual(false)
		expect(DungeonAdvance.live(nil, nil)).toEqual(false)

		local latch = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonAdvance.luau")
		local live = between(latch, "function DungeonAdvance.live", "function DungeonAdvance.advance")
		expect(string.find(live, "current == run", 1, true) ~= nil).toBeTrue()
		expect(string.find(live, "run.resolving ~= true", 1, true) ~= nil).toBeTrue()

		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local door = between(
			dungeon,
			"function DungeonService.chooseDoor",
			"function DungeonService.action"
		)
		local guardAt = at(door, "DungeonAdvance.live(runs[player], run)")
		local offerAt = at(door, "run.offer = nil")
		local goldAt = at(door, "Rootvault.TREASURE_GOLD")
		local mutateAt = at(door, "DataService.mutate")
		expect(guardAt < offerAt).toBeTrue()
		expect(guardAt < goldAt).toBeTrue()
		expect(guardAt < mutateAt).toBeTrue()
		expect(offerAt < goldAt).toBeTrue()
	end)

	it("clears the latch before the stream and checks the run before spawning", function()
		local latch = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonAdvance.luau")
		local claim = between(latch, "local function begin", "function DungeonAdvance.live")
		local step = between(latch, "function DungeonAdvance.advance", "return DungeonAdvance")
		local clearedCheck = at(claim, "run.cleared ~= true")
		local clearCleared = at(claim, "run.cleared = false")
		local clearAt = at(claim, "run.advanceAt = nil")
		local clearOffer = at(claim, "run.offer = nil")
		local waveAt = at(claim, "run.wave += 1")
		local roomAt = at(claim, "run.roomIndex += 1")
		expect(clearedCheck < clearCleared).toBeTrue()
		expect(clearCleared < clearAt).toBeTrue()
		expect(clearAt < clearOffer).toBeTrue()
		expect(clearOffer < waveAt).toBeTrue()
		expect(clearOffer < roomAt).toBeTrue()

		local beginAt = at(step, "begin(run)")
		local teleportAt = at(step, "teleport()")
		local liveAt = at(step, "DungeonAdvance.live")
		local spawnAt = at(step, "spawn(kind)")
		expect(beginAt < teleportAt).toBeTrue()
		expect(teleportAt < liveAt).toBeTrue()
		expect(liveAt < spawnAt).toBeTrue()

		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local advance = between(
			dungeon,
			"function DungeonService.advance",
			"function DungeonService.leave"
		)
		local callAt = at(advance, "DungeonAdvance.advance(")
		local serviceTeleport = at(advance, "teleport(")
		local waveSpawn = at(advance, "spawnWave(")
		local roomSpawn = at(advance, "spawnRoom(")
		expect(callAt < serviceTeleport).toBeTrue()
		expect(serviceTeleport < waveSpawn).toBeTrue()
		expect(serviceTeleport < roomSpawn).toBeTrue()
		expect(string.find(advance, "run.roomIndex += 1", 1, true)).toBeNil()
		expect(string.find(advance, "run.wave += 1", 1, true)).toBeNil()

		local leave = between(
			dungeon,
			"function DungeonService.leave",
			"function DungeonService.startDailyBoss"
		)
		local ending = at(leave, "run.resolving = true")
		local hubTeleport = at(leave, "pcall(teleport, player, hubCFrame())", ending)
		local destroyAt = at(leave, "destroyRun(", ending)
		expect(ending < hubTeleport).toBeTrue()
		expect(hubTeleport < destroyAt).toBeTrue()
	end)

	it("allows two Dungeon remotes in a burst and drops the third", function()
		local userId = 880021
		expect(RateLimiter.take(userId, "Dungeon")).toEqual(true)
		expect(RateLimiter.take(userId, "Dungeon")).toEqual(true)
		expect(RateLimiter.take(userId, "Dungeon")).toEqual(false)
		local limiter = fs.readFile("src/ServerScriptService/ShardfallServer/RateLimiter.luau")
		expect(string.find(limiter, "Dungeon = { capacity = 2, perSecond = 1 }", 1, true) ~= nil).toBeTrue()
		expect(string.find(limiter, "Dungeon = { capacity = 4", 1, true)).toBeNil()
	end)
end)
