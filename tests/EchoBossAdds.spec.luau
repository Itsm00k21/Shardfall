--!strict

--[[
	T-100. roomBossDown treated a dead boss as a clear while a living add
	shared the room. The Story Echo seat stayed closed, so the shared
	reset fired before the pull was empty. A living foe keeps the seat
	open. When the last add falls, the empty room asks again.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local Loops = require("../src/ReplicatedStorage/Shared/Loops")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

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

describe("Boss-plus-adds Echo seat", function()
	it("stays open while a living add shares the room with a dead boss", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local body = between(dungeon, "local function roomBossDown", "local function echoUp")

		-- Any living foe returns before a dead boss can count as a clear.
		local liveAt = at(body, "if foe.hp > 0 then")
		local liveReturn = at(body, "return false")
		local bossAt = at(body, "if foe.boss then")
		local sawAt = at(body, "if saw then")
		local deadBoss = at(body, "return true")
		local clearedAt = at(body, "return run.cleared == true")
		expect(liveAt < liveReturn).toBeTrue()
		expect(liveReturn < bossAt).toBeTrue()
		expect(bossAt < sawAt).toBeTrue()
		expect(sawAt < deadBoss).toBeTrue()
		expect(deadBoss < clearedAt).toBeTrue()

		-- The early false is the only return inside the loop.
		local loop = string.sub(body, at(body, "for _, foe in pairs(run.enemies)"), sawAt - 1)
		expect(string.find(loop, "return true", 1, true)).toBeNil()
		expect(string.find(loop, "return false", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "grant(", 1, true)).toBeNil()
		expect(string.find(body, "settleSharedBoss", 1, true)).toBeNil()
		expect(string.find(body, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(body, "GetJoinData", 1, true)).toBeNil()

		-- The seat still reads this predicate, so the shared reset waits.
		local ready =
			between(dungeon, "local function echoBossReady", "local function echoStanding")
		local copyAt = at(ready, "not roomBossDown(memberRun)")
		local seatAt = at(ready, "roomBossDown(memberRun),")
		expect(copyAt < seatAt).toBeTrue()
	end)

	it("asks again when the last add empties the room", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local hits = between(
			dungeon,
			"function DungeonService.damageEnemy",
			"function DungeonService.enemyViews"
		)
		local lootAt = at(hits, "PracticeLoot.applyKill")
		local emptyAt = at(hits, "if aliveCount(run) == 0 then")
		local again =
			between(hits, "if aliveCount(run) == 0 then", "if run.dungeon.endless == true then")
		local bossSkip = at(again, "if not enemy.boss and run.echoFight ~= nil then")
		local owedAt = at(again, "echoBossOwed[fight]")
		local readyAt = at(again, "echoBossReady(fight, owed)")
		local settleAt = at(again, "settleSharedBoss(fight, player)")
		expect(lootAt < emptyAt).toBeTrue()
		expect(bossSkip < owedAt).toBeTrue()
		expect(owedAt < readyAt).toBeTrue()
		expect(readyAt < settleAt).toBeTrue()
		expect(string.find(again, "owed == run.roomIndex", 1, true) ~= nil).toBeTrue()

		-- One ask. No second heal, no loot, no hop, no client host.
		expect(string.find(again, "CombatService.revive", 1, true)).toBeNil()
		expect(string.find(again, "grant(", 1, true)).toBeNil()
		expect(string.find(again, "finish(", 1, true)).toBeNil()
		expect(string.find(again, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(again, "TeleportAsync", 1, true)).toBeNil()
		expect(string.find(again, "ReserveServer", 1, true)).toBeNil()
		expect(string.find(again, "GetJoinData", 1, true)).toBeNil()
		expect(string.find(again, "payload", 1, true)).toBeNil()
		expect(string.find(again, "productId", 1, true)).toBeNil()
		expect(string.find(again, "Robux", 1, true)).toBeNil()

		-- The boss-death ask is still the one that runs before loot.
		local firstReady = at(hits, "if echoBossReady(")
		local firstSettle = at(hits, "settleSharedBoss(")
		expect(firstReady < firstSettle).toBeTrue()
		expect(firstSettle < lootAt).toBeTrue()
		expect(lootAt < emptyAt).toBeTrue()
	end)

	it("leaves the schema and the paid switches alone", function()
		expect(Schema.VERSION).toEqual(24)
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		expect(Loops.PASS_PRODUCT_ID).toEqual(0)
		expect(Loops.ARCHIVE_PRODUCT_ID).toEqual(0)
		expect(RarityConfig.PAID_LUCK_ENABLED).toEqual(false)
		expect(ChestConfig.PAID_CHESTS_ENABLED).toEqual(false)
	end)
end)
