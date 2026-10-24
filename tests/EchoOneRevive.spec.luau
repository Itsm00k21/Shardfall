--!strict

--[[
	T-098. A downed Story member was fully revived every time a
	teammate's Echo copy died, so one pull could heal them more than
	once. The cap is one full revive per pull.
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

describe("One Story Echo revive per pull", function()
	it("skips a second full revive for the same player in that pull", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local revive = between(dungeon, "local function reviveHeld", "local function noteEchoBoss")

		-- The mark is checked before the heal, and written only after the
		-- player is still on this fight. A leave during the heal does not
		-- spend the one revive.
		local guardAt = at(revive, "seen[userId] == true")
		local healAt = at(revive, "CombatService.revive")
		local aliveAt = at(revive, "RaidEchoFight.setAlive")
		local markAt = at(revive, "marked[userId] = true")
		expect(guardAt < healAt).toBeTrue()
		expect(healAt < aliveAt).toBeTrue()
		expect(aliveAt < markAt).toBeTrue()
		expect(string.find(revive, "echoRevived[fight] = nil", 1, true)).toBeNil()

		-- Server user id only. No client field, no second heal, no loot.
		expect(string.find(revive, "tostring(member.UserId)", 1, true) ~= nil).toBeTrue()
		expect(string.find(revive, "payload", 1, true)).toBeNil()
		local heals = 0
		local from = 1
		while true do
			local found = string.find(revive, "CombatService.revive", from, true)
			if found == nil then
				break
			end
			heals += 1
			from = found + 1
		end
		expect(heals).toEqual(1)
		expect(string.find(revive, "grant(", 1, true)).toBeNil()
		expect(string.find(revive, "finish(", 1, true)).toBeNil()
		expect(string.find(revive, "hubCFrame", 1, true)).toBeNil()
		expect(string.find(revive, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(revive, "retryPull", 1, true)).toBeNil()

		-- Copy-death still offers the one revive. It does not reset stacks.
		local hits = between(
			dungeon,
			"function DungeonService.damageEnemy",
			"function DungeonService.enemyViews"
		)
		local readyAt = at(hits, "if echoBossReady(")
		local tail = string.sub(hits, readyAt)
		local elseAt = string.find(tail, "else", 1, true)
		assert(elseAt ~= nil, "missing else")
		local unpaid =
			string.sub(tail, elseAt, (string.find(tail, "\n\t\tend", elseAt, true) or elseAt) - 1)
		expect(string.find(unpaid, "reviveHeld(", 1, true) ~= nil).toBeTrue()
		expect(string.find(unpaid, "CombatService.revive", 1, true)).toBeNil()
		expect(string.find(unpaid, "RaidEchoFight.bossKill", 1, true)).toBeNil()

		-- The pull-end revive spends the same cap, then the next pull is free.
		local settle = between(dungeon, "local function settleSharedBoss", "local destroyRun")
		local settleRevive = at(settle, "reviveHeld(")
		local settleClear = at(settle, "echoRevived[fight] = nil")
		expect(settleRevive < settleClear).toBeTrue()

		-- A wipe retry is a new pull. The cap clears before anyone is stood up.
		local retry =
			between(dungeon, "local function retryPull", "function DungeonService.onPlayerDown")
		local retryClear = at(retry, "echoRevived[fight] = nil")
		local retryGuard = at(retry, "memberRun.retrying = true")
		expect(retryClear < retryGuard).toBeTrue()

		-- Leaving does not refund the revive. Dropping the fight does.
		local dropped = between(dungeon, "destroyRun = function", "local function grant")
		local departAt = at(dropped, "RaidEchoFight.depart(fight, userId)")
		local homeAt = at(dropped, "sendHeldHome(fight)")
		expect(departAt < homeAt).toBeTrue()
		local departBody = string.sub(dropped, departAt, homeAt - 1)
		expect(string.find(departBody, "echoRevived", 1, true)).toBeNil()
		local release = between(dropped, "if not sharing then", "CombatService.clearShots")
		expect(string.find(release, "echoRevived[fight] = nil", 1, true) ~= nil).toBeTrue()
		expect(string.find(release, "RaidEchoFight.runEnd", 1, true) ~= nil).toBeTrue()
	end)
end)
