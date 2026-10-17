--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local EchoRetry = require("../src/ServerScriptService/ShardfallServer/EchoRetry")
local RunTick = require("../src/ServerScriptService/ShardfallServer/RunTick")
local RaidEchoFight = require("../src/ReplicatedStorage/Shared/RaidEchoFight")

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

local function at(source: string, needle: string): number
	local found = string.find(source, needle, 1, true)
	assert(found ~= nil, "missing " .. needle)
	return found
end

-- One Story down, then `hits` more while the revive has cleared the latch.
-- Returns stacks, retry count, and how many hits were ignored.
local function drive(guard: boolean, hits: number, later: number): (number, number, number)
	local fight = RaidEchoFight.open("story", false, "1")
	RaidEchoFight.notePull(fight, "twins")
	local retrying = false
	local retries = 0
	local ignored = 0
	local function down()
		local action = EchoRetry.decision(retrying, true)
		if action == "ignore" then
			ignored += 1
			return
		end
		RaidEchoFight.setAlive(fight, "1", false)
		if action ~= "retry" then
			return
		end
		retries += 1
		if guard then
			retrying = true
		end
		-- Revive clears the wipe latch. This is the yield window.
		RaidEchoFight.setAlive(fight, "1", true)
		local pending = hits
		hits = 0
		for _ = 1, pending do
			down()
		end
		retrying = false
	end
	down()
	for _ = 1, later do
		down()
	end
	return fight.state.stacks, retries, ignored
end

describe("Echo retry window", function()
	it("ignores a down while the guard is up", function()
		expect(EchoRetry.blocked(true)).toEqual(true)
		expect(EchoRetry.blocked(false)).toEqual(false)
		expect(EchoRetry.decision(true, true)).toEqual("ignore")
		expect(EchoRetry.decision(true, false)).toEqual("ignore")
		expect(EchoRetry.decision(false, true)).toEqual("retry")
		expect(EchoRetry.decision(false, false)).toEqual("down")
		expect(EchoRetry.beforeYield()).toEqual({ "guard", "clearShots", "despawn" })
	end)

	it("counts one stack when hits land after the latch clears", function()
		local unguardedStacks, unguardedRetries, unguardedIgnored = drive(false, 3, 0)
		expect(unguardedStacks).toEqual(4)
		expect(unguardedRetries).toEqual(4)
		expect(unguardedIgnored).toEqual(0)

		local stacks, retries, ignored = drive(true, 3, 0)
		expect(stacks).toEqual(1)
		expect(retries).toEqual(1)
		expect(ignored).toEqual(3)

		local laterStacks, laterRetries, laterIgnored = drive(true, 5, 1)
		expect(laterStacks).toEqual(2)
		expect(laterRetries).toEqual(2)
		expect(laterIgnored).toEqual(5)
	end)

	it("does not add a stack for a party hit while the other member is still retrying", function()
		local fight = RaidEchoFight.open("story", false, "1")
		RaidEchoFight.backfill(fight, "2")
		RaidEchoFight.notePull(fight, "twins")
		RaidEchoFight.setAlive(fight, "1", false)
		local wiped = RaidEchoFight.setAlive(fight, "2", false)
		assert(wiped ~= nil)
		expect(wiped.added).toEqual(true)
		expect(fight.state.stacks).toEqual(1)

		local guard = { ["1"] = true, ["2"] = true }
		RaidEchoFight.setAlive(fight, "1", true)
		RaidEchoFight.setAlive(fight, "2", true)
		expect(fight.latched).toEqual(false)

		local retries = 0
		local function hit(id: string)
			if EchoRetry.blocked(guard[id] == true) then
				return
			end
			RaidEchoFight.setAlive(fight, id, false)
			local living = RaidEchoFight.counts(fight)
			if EchoRetry.decision(false, living == 0) == "retry" then
				retries += 1
			end
		end
		hit("1")
		hit("2")
		hit("1")
		expect(fight.state.stacks).toEqual(1)
		expect(retries).toEqual(0)
		expect(fight.latched).toEqual(false)

		guard["1"] = false
		guard["2"] = false
		hit("1")
		expect(fight.state.stacks).toEqual(1)
		expect(retries).toEqual(0)
		local again = RaidEchoFight.setAlive(fight, "2", false)
		assert(again ~= nil)
		expect(again.added).toEqual(true)
		expect(fight.state.stacks).toEqual(2)
	end)

	it("clears the room before the stream yield and guards onPlayerDown", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local quiet = between(dungeon, "local function quietRoom", "local function pullMember")
		local pull = between(dungeon, "local function pullMember", "local function retryPull")
		local retry =
			between(dungeon, "local function retryPull", "function DungeonService.onPlayerDown")
		local down = between(
			dungeon,
			"function DungeonService.onPlayerDown",
			"function DungeonService.backfill"
		)

		expect(string.find(quiet, "CombatService.clearShots", 1, true) ~= nil).toBeTrue()
		expect(string.find(quiet, "clearEnemies", 1, true) ~= nil).toBeTrue()
		expect(string.find(quiet, "teleport", 1, true)).toBeNil()
		expect(string.find(quiet, "RequestStreamAroundAsync", 1, true)).toBeNil()
		expect(string.find(quiet, "grant(", 1, true)).toBeNil()

		local pullAlive = at(pull, "RaidEchoFight.setAlive")
		local pullTeleport = at(pull, "teleport(")
		local pullSpawn = at(pull, "spawnRoom(")
		expect(pullAlive < pullTeleport).toBeTrue()
		expect(pullTeleport < pullSpawn).toBeTrue()
		expect(string.find(pull, "grant(", 1, true)).toBeNil()
		expect(string.find(pull, "Drops.apply", 1, true)).toBeNil()

		local guardAt = at(retry, "memberRun.retrying = true")
		local quietAt = at(retry, "pcall(quietRoom")
		local pullAt = at(retry, "pcall(pullMember")
		expect(guardAt < quietAt).toBeTrue()
		expect(quietAt < pullAt).toBeTrue()
		expect(string.find(retry, "grant(", 1, true)).toBeNil()
		expect(string.find(retry, "finish(", 1, true)).toBeNil()

		local blockedAt = at(down, "EchoRetry.blocked")
		local aliveAt = at(down, "RaidEchoFight.setAlive")
		local practiceAt = at(down, "run.practice ~= true")
		local decisionAt = at(down, "EchoRetry.decision")
		local retryAt = at(down, "retryPull(")
		expect(blockedAt < aliveAt).toBeTrue()
		expect(practiceAt < retryAt).toBeTrue()
		expect(decisionAt < retryAt).toBeTrue()
		expect(string.find(down, "aliveCount", 1, true)).toBeNil()
	end)
end)

describe("Dungeon tick isolation", function()
	it("keeps the other players moving and does not grant", function()
		local function step(id: string)
			if id == "b" then
				error("nan CFrame")
			end
		end
		local first = RunTick.sweep({ "a", "b", "c" }, step, nil)
		expect(first.completed).toEqual({ "a", "c" })
		expect(first.failed).toEqual({ "b" })
		expect(first.destroyed).toEqual({ "b" })
		expect(first.granted).toEqual({})
		expect(#first.warnings).toEqual(1)
		expect(string.find(first.warnings[1], "nan CFrame", 1, true) ~= nil).toBeTrue()

		local second = RunTick.sweep({ "b" }, step, first.seen)
		expect(second.completed).toEqual({})
		expect(second.failed).toEqual({ "b" })
		expect(second.destroyed).toEqual({ "b" })
		expect(second.granted).toEqual({})
		expect(#second.warnings).toEqual(0)
	end)

	it("warns once and leaves a resolving run to finish", function()
		local warnNow, destroy = RunTick.fault(false, true, false)
		expect(warnNow).toEqual(true)
		expect(destroy).toEqual(true)
		local again, destroyAgain = RunTick.fault(true, true, false)
		expect(again).toEqual(false)
		expect(destroyAgain).toEqual(true)
		local midFinish, leaveIt = RunTick.fault(false, true, true)
		expect(midFinish).toEqual(true)
		expect(leaveIt).toEqual(false)
		local noRun, noDestroy = RunTick.fault(false, false, false)
		expect(noRun).toEqual(true)
		expect(noDestroy).toEqual(false)
	end)

	it("wraps each player without a per-frame closure and does not pay on a fault", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local heart = between(dungeon, "local function onHeartbeat", "local function reject")
		local fault = between(dungeon, "local function faultPlayer", "local function onHeartbeat")
		expect(string.find(heart, "pcall(tickOne,", 1, true) ~= nil).toBeTrue()
		expect(string.find(heart, "pcall(tickRestart,", 1, true) ~= nil).toBeTrue()
		expect(string.find(heart, "pcall(tickHub,", 1, true) ~= nil).toBeTrue()
		expect(string.find(heart, "pcall(function", 1, true)).toBeNil()
		expect(string.find(heart, "faultPlayer", 1, true) ~= nil).toBeTrue()
		expect(string.find(fault, "RunTick.fault", 1, true) ~= nil).toBeTrue()
		expect(string.find(fault, "destroyRun", 1, true) ~= nil).toBeTrue()
		expect(string.find(fault, "resolving = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(fault, "grant(", 1, true)).toBeNil()
		expect(string.find(fault, "finish(", 1, true)).toBeNil()
		expect(string.find(fault, "PracticeLoot", 1, true)).toBeNil()
		expect(string.find(fault, "Drops.apply", 1, true)).toBeNil()
	end)
end)
