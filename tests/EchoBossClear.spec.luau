--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CombatMath = require("../src/ReplicatedStorage/Shared/CombatMath")
local EchoBossClear = require("../src/ServerScriptService/ShardfallServer/EchoBossClear")

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

describe("Shared Echo boss clear", function()
	it("waits until every member still in the fight has cleared that boss", function()
		-- Same room, partner's copy still up.
		local waiting = EchoBossClear.seatCleared(1, 1, false, false, false)
		expect(waiting).toEqual(false)
		expect(EchoBossClear.ready({
			{ cleared = true, retrying = false },
			{ cleared = waiting, retrying = false },
		})).toEqual(false)

		-- Both copies are down.
		local killer = EchoBossClear.seatCleared(1, 1, true, true, false)
		local partner = EchoBossClear.seatCleared(1, 1, true, false, false)
		expect(killer).toEqual(true)
		expect(partner).toEqual(true)
		expect(EchoBossClear.ready({
			{ cleared = killer, retrying = false },
			{ cleared = partner, retrying = false },
		})).toEqual(true)

		-- Departed and resolving members are omitted. A held member with
		-- the boss still up is a seat and blocks the reset.
		expect(EchoBossClear.ready({
			{ cleared = true, retrying = false },
		})).toEqual(true)
		expect(EchoBossClear.ready({
			{ cleared = true, retrying = false },
			{ cleared = false, retrying = false },
		})).toEqual(false)

		-- Nobody left is not a clear, so a leave cannot reset by itself.
		expect(EchoBossClear.ready({})).toEqual(false)
	end)

	it("counts an advanced member only from the kill mark", function()
		-- Moved to the next wing after dropping this boss.
		expect(EchoBossClear.seatCleared(1, 2, false, true, false)).toEqual(true)
		-- tuneRaid can jump ahead. That is not a clear of the earlier boss.
		expect(EchoBossClear.seatCleared(1, 2, false, false, false)).toEqual(false)
		-- Still on an earlier wing.
		expect(EchoBossClear.seatCleared(3, 1, true, true, false)).toEqual(false)
		-- Same room trusts the live rig. A mark from before a respawn does not.
		expect(EchoBossClear.seatCleared(2, 2, false, true, false)).toEqual(false)
		expect(EchoBossClear.seatCleared(2, 2, true, false, false)).toEqual(true)
		-- Wipe retry is not a clear, even if the old rig is already gone.
		expect(EchoBossClear.seatCleared(2, 2, true, true, true)).toEqual(false)
		expect(EchoBossClear.ready({
			{ cleared = true, retrying = false },
			{ cleared = true, retrying = true },
		})).toEqual(false)
		expect(EchoBossClear.seatCleared(0, 1, true, true, false)).toEqual(false)
	end)

	it("leaves a standing player at 1 HP when the shrink would zero them", function()
		-- +25% max (125) falls back to 100. Missing 105 does not fit.
		local dropped = CombatMath.syncVitals(20, 125, 100, true)
		expect(dropped).toEqual(0)
		expect(EchoBossClear.floorHp(20, dropped)).toEqual(1)

		-- Missing HP still fits in the unbuffed max.
		local kept = CombatMath.syncVitals(80, 125, 100, true)
		expect(kept).toEqual(55)
		expect(EchoBossClear.floorHp(80, kept)).toEqual(55)

		-- Already down stays down. The floor must not stand a held member up.
		local dead = CombatMath.syncVitals(0, 125, 100, true)
		expect(dead).toEqual(0)
		expect(EchoBossClear.floorHp(0, dead)).toEqual(0)

		-- Undamaged players fill to the new max. That is not a floor.
		local full = CombatMath.syncVitals(125, 125, 100, false)
		expect(full).toEqual(100)
		expect(EchoBossClear.floorHp(125, full)).toEqual(100)
	end)
end)

describe("Shared boss kill wire", function()
	it("resets stacks once from damageEnemy and spares the standing players", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local combat = fs.readFile("src/ServerScriptService/ShardfallServer/CombatService.luau")
		local echo = fs.readFile("src/ReplicatedStorage/Shared/RaidEcho.luau")
		local hits = between(
			dungeon,
			"function DungeonService.damageEnemy",
			"function DungeonService.enemyViews"
		)
		local guardAt = at(hits, "if hp <= 0 then")
		local noteAt = at(hits, "noteEchoBoss(")
		local readyAt = at(hits, "if echoBossReady(")
		local settleAt = at(hits, "settleSharedBoss(")
		local lootAt = at(hits, "PracticeLoot.applyKill")
		expect(guardAt < noteAt).toBeTrue()
		expect(noteAt < readyAt).toBeTrue()
		expect(readyAt < settleAt).toBeTrue()
		expect(settleAt < lootAt).toBeTrue()

		local tail = string.sub(hits, readyAt)
		local elseAt = string.find(tail, "else", 1, true)
		assert(elseAt ~= nil, "missing else")
		local paid = string.sub(tail, 1, elseAt - 1)
		local unpaid =
			string.sub(tail, elseAt, (string.find(tail, "\n\t\tend", elseAt, true) or elseAt) - 1)
		expect(string.find(paid, "settleSharedBoss(", 1, true) ~= nil).toBeTrue()
		expect(string.find(paid, "RaidEchoFight.bossKill", 1, true)).toBeNil()
		expect(string.find(unpaid, "echoBossOwed[fight] = run.roomIndex", 1, true) ~= nil).toBeTrue()
		expect(string.find(unpaid, "reviveHeld(", 1, true) ~= nil).toBeTrue()
		expect(string.find(unpaid, "memberRun.roomIndex == run.roomIndex", 1, true) ~= nil).toBeTrue()
		expect(string.find(unpaid, "settleSharedBoss(", 1, true)).toBeNil()
		expect(string.find(unpaid, "RaidEchoFight.bossKill", 1, true)).toBeNil()
		expect(string.find(unpaid, "bindEcho(", 1, true)).toBeNil()
		local readyBody =
			between(dungeon, "local function echoBossReady", "local function echoStanding")
		expect(string.find(readyBody, "not up and not copyUp", 1, true) ~= nil).toBeTrue()

		local settle = between(dungeon, "local function settleSharedBoss", "local destroyRun")
		local owedAt = at(settle, "echoBossOwed[fight] = nil")
		local snapAt = at(settle, "heldNow(")
		local standAt = at(settle, "echoStanding(")
		local killAt = at(settle, "RaidEchoFight.bossKill")
		local refreshAt = at(settle, "bindEcho(")
		local spareAt = at(settle, "spareEchoFloor(")
		local reviveAt = at(settle, "reviveHeld(")
		expect(owedAt < snapAt).toBeTrue()
		expect(snapAt < standAt).toBeTrue()
		expect(standAt < killAt).toBeTrue()
		expect(killAt < refreshAt).toBeTrue()
		expect(refreshAt < spareAt).toBeTrue()
		expect(spareAt < reviveAt).toBeTrue()
		expect(string.find(settle, "onPlayerDown", 1, true)).toBeNil()
		expect(string.find(settle, "grant(", 1, true)).toBeNil()
		expect(string.find(settle, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(settle, "RaidEchoFight.runEnd", 1, true)).toBeNil()

		-- The down path would fail a cleared run: pullStarted is already false.
		local spare =
			between(combat, "function CombatService.spare", "function CombatService.vitals")
		expect(string.find(spare, "if state.hp > 0 then", 1, true) ~= nil).toBeTrue()
		expect(string.find(spare, "state.hp = 1", 1, true) ~= nil).toBeTrue()
		expect(string.find(spare, "state.hurt = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(spare, "onPlayerDown", 1, true)).toBeNil()
		expect(string.find(spare, "state.hp = state.maxHp", 1, true)).toBeNil()

		local refresh =
			between(combat, "function CombatService.refresh", "function CombatService.revive")
		expect(string.find(refresh, "onPlayerDown", 1, true)).toBeNil()

		local dropped = between(dungeon, "destroyRun = function", "local function grant")
		local departAt = at(dropped, "RaidEchoFight.depart(fight, userId)")
		local forgetAt = at(dropped, "marked[userId] = nil")
		local leaveReady = at(dropped, "echoBossReady(fight, owed)")
		local leaveSettle = at(dropped, "settleSharedBoss(fight, nil)")
		local homeAt = at(dropped, "sendHeldHome(fight)")
		expect(departAt < forgetAt).toBeTrue()
		expect(forgetAt < leaveReady).toBeTrue()
		expect(leaveReady < leaveSettle).toBeTrue()
		expect(leaveSettle < homeAt).toBeTrue()
		expect(
			string.find(dropped, "if shared and echoBossReady(fight, owed) then", 1, true) ~= nil
		).toBeTrue()

		-- No second stack, and the pure rules module does not reset or grant.
		local rules = fs.readFile("src/ServerScriptService/ShardfallServer/EchoBossClear.luau")
		expect(string.find(rules, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(rules, "RaidEcho.reset", 1, true)).toBeNil()
		expect(string.find(echo, "function RaidEcho.reset", 1, true) ~= nil).toBeTrue()
	end)
end)
