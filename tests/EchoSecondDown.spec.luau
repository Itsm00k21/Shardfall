--!strict

--[[
	T-111. After the one Story Echo revive is spent, a second down stays
	at 0 HP. That player cannot swing, so their still-up boss copy must
	not hold the shared reset for the rest of the pull.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

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

describe("Story Echo second down", function()
	it("does not let a spent revive hold the shared reset at 0 HP", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local ready =
			between(dungeon, "local function echoBossReady", "local function echoStanding")

		-- A first down still seats a living copy. The spent skip is the next continue.
		local seatAt = at(ready, "if not up and not copyUp then")
		local insertAt = at(ready, "table.insert(seats")
		expect(seatAt < insertAt).toBeTrue()
		local gate = string.sub(ready, seatAt, insertAt - 1)
		local firstContinue = string.find(gate, "continue", 1, true)
		assert(firstContinue ~= nil, "missing continue")
		local skip = string.sub(gate, firstContinue + #"continue")
		local vitalsAt = at(skip, "CombatService.vitals(member) <= 0")
		local spentAt = at(skip, "reviveSpent(fight, userId)")
		local skipContinue = at(skip, "continue")
		expect(vitalsAt < skipContinue).toBeTrue()
		expect(spentAt < skipContinue).toBeTrue()
		expect(string.find(skip, "CombatService.revive", 1, true)).toBeNil()
		expect(string.find(skip, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(skip, "RaidEchoFight.bossKill", 1, true)).toBeNil()
		expect(string.find(skip, "grant(", 1, true)).toBeNil()

		-- Same cap reviveHeld writes. No second heal in the check.
		local cap = between(dungeon, "local function reviveSpent", "local function echoBossReady")
		expect(string.find(cap, "echoRevived[fight]", 1, true) ~= nil).toBeTrue()
		expect(string.find(cap, "seen[userId] == true", 1, true) ~= nil).toBeTrue()
		expect(string.find(cap, "CombatService.revive", 1, true)).toBeNil()
		expect(string.find(cap, "RaidEcho.wipe", 1, true)).toBeNil()

		local down = between(
			dungeon,
			"function DungeonService.onPlayerDown",
			"function DungeonService.backfill"
		)
		local retryAt = at(down, "retryPull(")
		local holdAt = at(down, "EchoRetry.hold")
		local releaseAt = at(down, "settleSharedBoss(fight, nil)")
		local finishAt = at(down, "finish(")
		expect(retryAt < holdAt).toBeTrue()
		expect(holdAt < releaseAt).toBeTrue()
		expect(releaseAt < finishAt).toBeTrue()

		-- A full party down still retries. The release stays on the hold path.
		local retryBody = string.sub(down, retryAt, holdAt - 1)
		expect(string.find(retryBody, "return", 1, true) ~= nil).toBeTrue()
		expect(string.find(retryBody, "settleSharedBoss", 1, true)).toBeNil()

		local holdBody = string.sub(down, holdAt, finishAt - 1)
		expect(string.find(holdBody, "echoBossOwed[fight]", 1, true) ~= nil).toBeTrue()
		expect(string.find(holdBody, "CombatService.vitals(player) <= 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(holdBody, "reviveSpent(fight, tostring(player.UserId))", 1, true) ~= nil).toBeTrue()
		expect(string.find(holdBody, "echoBossReady(fight, owed)", 1, true) ~= nil).toBeTrue()
		expect(string.find(holdBody, "CombatService.revive", 1, true)).toBeNil()
		expect(string.find(holdBody, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(holdBody, "grant(", 1, true)).toBeNil()
		expect(string.find(holdBody, "finish(", 1, true)).toBeNil()
		expect(
			string.find(holdBody, 'pushRun(player, "Down. The pull continues.")', 1, true) ~= nil
		).toBeTrue()
	end)
end)
