--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local EchoVitals = require("../src/ServerScriptService/ShardfallServer/EchoVitals")
local RaidEcho = require("../src/ReplicatedStorage/Shared/RaidEcho")
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

local function wipedStory(): RaidEchoFight.Fight
	local fight = RaidEchoFight.open("story", false, "1")
	RaidEchoFight.notePull(fight, "twins")
	RaidEchoFight.setAlive(fight, "1", false)
	RaidEchoFight.setAlive(fight, "1", true)
	return fight
end

-- Percent of the unbuffed max, then the heal hook once.
local function healOnce(baseMax: number, fraction: number, floorAtLeastOne: boolean): number
	local fight = wipedStory()
	local raw = math.floor(baseMax * fraction)
	if floorAtLeastOne then
		raw = math.max(1, raw)
	end
	local scaled = RaidEchoFight.applyBase(fight, "1", "healing", raw)
	return EchoVitals.heal(raw, scaled)
end

-- The bug: percent of the already-echoed max, then the heal hook again.
local function healTwice(baseMax: number, fraction: number, floorAtLeastOne: boolean): number
	local fight = wipedStory()
	local echoed = RaidEchoFight.applyBase(fight, "1", "maxHp", baseMax)
	local raw = math.floor(echoed * fraction)
	if floorAtLeastOne then
		raw = math.max(1, raw)
	end
	local scaled = RaidEchoFight.applyBase(fight, "1", "healing", raw)
	return EchoVitals.heal(raw, scaled)
end

describe("Story Echo percent heals", function()
	it("applies one wipe to a percent of the unbuffed max", function()
		local step = 1 + RaidEcho.CONFIG.perWipe
		local baseMax = 1000
		local healFraction = 0.22
		local shieldFraction = 0.2
		local springFraction = 0.3

		local heal = healOnce(baseMax, healFraction, true)
		local shield = healOnce(baseMax, shieldFraction, false)
		local spring = healOnce(baseMax, springFraction, true)
		local rawHeal = math.max(1, math.floor(baseMax * healFraction))
		local rawShield = math.floor(baseMax * shieldFraction)
		local rawSpring = math.max(1, math.floor(baseMax * springFraction))
		expect(heal).toEqual(math.floor(rawHeal * step + 0.5))
		expect(shield).toEqual(math.floor(rawShield * step + 0.5))
		expect(spring).toEqual(math.floor(rawSpring * step + 0.5))

		expect(heal).toBeLessThan(healTwice(baseMax, healFraction, true))
		expect(shield).toBeLessThan(healTwice(baseMax, shieldFraction, false))
		expect(spring).toBeLessThan(healTwice(baseMax, springFraction, true))

		-- A flat heal is not a percent of max. The hook still scales it once.
		local fight = wipedStory()
		local flat = 40
		local scaled = RaidEchoFight.applyBase(fight, "1", "healing", flat)
		expect(EchoVitals.heal(flat, scaled)).toEqual(math.floor(flat * step + 0.5))
		expect(fight.bases["1"].healing).toEqual(flat)
	end)

	it("reads skill percents from the loadout max and the spring from the same max", function()
		local classes = fs.readFile("src/ServerScriptService/ShardfallServer/ClassService.luau")
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local combat = fs.readFile("src/ServerScriptService/ShardfallServer/CombatService.luau")
		local cast = between(classes, "function ClassService.cast", "function ClassService.onHit")
		local mods = between(classes, "function ClassService.mods", "function ClassService.select")
		local door = between(
			dungeon,
			"function DungeonService.chooseDoor",
			"function DungeonService.action"
		)
		local spring = between(door, 'picked.id == "spring"', 'picked.id == "shrine"')

		local loadoutAt = at(cast, "local offense, vitality = CombatMath.loadout(profile)")
		local healAt = at(cast, "baseMax * tuned.heal")
		local shieldAt = at(cast, "baseMax * tuned.shield")
		local hookAt = at(cast, "CombatService.healAmount")
		expect(loadoutAt < healAt).toBeTrue()
		expect(healAt < hookAt).toBeTrue()
		expect(healAt < shieldAt).toBeTrue()
		expect(string.find(cast, "vitality.maxHealth", 1, true) ~= nil).toBeTrue()
		expect(string.find(cast, "CombatService.vitals", 1, true)).toBeNil()
		expect(string.find(cast, "RaidEcho", 1, true)).toBeNil()
		expect(string.find(cast, "math.floor(healed * 0.15)", 1, true) ~= nil).toBeTrue()
		expect(string.find(cast, "maxHp * tuned.heal", 1, true)).toBeNil()
		expect(string.find(cast, "maxHp * tuned.shield", 1, true)).toBeNil()
		-- Damage ratios still use the published bar. That is not a heal percent.
		expect(string.find(mods, "CombatService.vitals", 1, true) ~= nil).toBeTrue()

		expect(string.find(spring, "CombatMath.loadout", 1, true) ~= nil).toBeTrue()
		expect(string.find(spring, "vitality.maxHealth", 1, true) ~= nil).toBeTrue()
		expect(string.find(spring, "baseMax * 0.3", 1, true) ~= nil).toBeTrue()
		expect(string.find(spring, "CombatService.healAmount", 1, true) ~= nil).toBeTrue()
		expect(string.find(spring, "CombatService.vitals", 1, true)).toBeNil()
		expect(string.find(door, "maxHp * 0.3", 1, true)).toBeNil()

		local strike = between(combat, "local function strikeEnemy", "local function launch")
		expect(string.find(strike, "heal(player, hit.healed", 1, true) ~= nil).toBeTrue()
		expect(string.find(strike, "healAmount", 1, true)).toBeNil()
	end)
end)

describe("Held Story members", function()
	it("comes back on a boss kill without a second stack", function()
		local fight = RaidEchoFight.open("story", false, "1")
		RaidEchoFight.backfill(fight, "2")
		RaidEchoFight.notePull(fight, "twins")
		expect(RaidEchoFight.setAlive(fight, "2", false)).toBeNil()
		expect(fight.state.stacks).toEqual(0)
		expect(fight.members["2"].alive).toEqual(false)

		local killed = RaidEchoFight.bossKill(fight)
		expect(killed.ok).toEqual(true)
		expect(fight.state.stacks).toEqual(0)
		expect(RaidEchoFight.setAlive(fight, "2", true)).toBeNil()
		expect(fight.state.stacks).toEqual(0)
		expect(fight.members["2"].alive).toEqual(true)
		expect(fight.pullStarted).toEqual(false)

		-- Leaving the last living player must not be recorded as another wipe.
		local ended = RaidEchoFight.open("story", false, "1")
		RaidEchoFight.backfill(ended, "2")
		RaidEchoFight.notePull(ended, "sapwell")
		RaidEchoFight.setAlive(ended, "2", false)
		RaidEchoFight.depart(ended, "1")
		local living, party = RaidEchoFight.counts(ended)
		expect(living).toEqual(0)
		expect(party).toEqual(1)
		local trap = RaidEchoFight.setAlive(ended, "2", false)
		assert(trap ~= nil)
		expect(trap.added).toEqual(true)
		expect(ended.state.stacks).toEqual(1)

		local home = RaidEchoFight.open("story", false, "9")
		RaidEchoFight.backfill(home, "8")
		RaidEchoFight.notePull(home, "galecrown")
		RaidEchoFight.setAlive(home, "8", false)
		RaidEchoFight.depart(home, "9")
		RaidEchoFight.depart(home, "8")
		local reset = RaidEchoFight.runEnd(home)
		expect(reset.ok).toEqual(true)
		expect(home.state.stacks).toEqual(0)
	end)

	it("revives on the boss kill and sends held members home on run end", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local hits = between(
			dungeon,
			"function DungeonService.damageEnemy",
			"function DungeonService.enemyViews"
		)
		local downedAt = at(hits, "if hp <= 0 then")
		local returnAt = at(hits, "return false")
		local noteAt = at(hits, "noteEchoBoss(")
		local readyAt = at(hits, "if echoBossReady(")
		local settleAt = at(hits, "settleSharedBoss(")
		local lootAt = at(hits, "PracticeLoot.applyKill")
		expect(downedAt < returnAt).toBeTrue()
		expect(returnAt < noteAt).toBeTrue()
		expect(noteAt < readyAt).toBeTrue()
		expect(readyAt < settleAt).toBeTrue()
		expect(settleAt < lootAt).toBeTrue()

		local settle = between(dungeon, "local function settleSharedBoss", "local destroyRun")
		local snapAt = at(settle, "heldNow(")
		local killAt = at(settle, "RaidEchoFight.bossKill")
		local refreshAt = at(settle, "bindEcho(")
		local spareAt = at(settle, "spareEchoFloor(")
		local reviveAt = at(settle, "reviveHeld(")
		expect(snapAt < killAt).toBeTrue()
		expect(killAt < refreshAt).toBeTrue()
		expect(refreshAt < spareAt).toBeTrue()
		expect(spareAt < reviveAt).toBeTrue()

		local down = between(
			dungeon,
			"function DungeonService.onPlayerDown",
			"function DungeonService.backfill"
		)
		local aliveBefore = string.find(down, "RaidEchoFight.setAlive", 1, true)
		local stillUp = string.find(down, "CombatService.vitals(player) > 0", 1, true)
		expect(stillUp ~= nil and aliveBefore ~= nil and stillUp < aliveBefore).toBeTrue()

		local revive = between(dungeon, "local function reviveHeld", "local destroyRun")
		expect(string.find(revive, "CombatService.revive", 1, true) ~= nil).toBeTrue()
		expect(string.find(revive, "RaidEchoFight.setAlive", 1, true) ~= nil).toBeTrue()
		expect(string.find(revive, ", true)", 1, true) ~= nil).toBeTrue()
		expect(string.find(revive, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(revive, "retryPull", 1, true)).toBeNil()
		expect(string.find(revive, "grant(", 1, true)).toBeNil()
		expect(string.find(revive, "finish(", 1, true)).toBeNil()
		expect(string.find(revive, "hubCFrame", 1, true)).toBeNil()

		local home = between(dungeon, "local function sendHeldHome", "destroyRun = function")
		local departAt = at(dungeon, "RaidEchoFight.depart(fight, userId)")
		local homeAt = at(dungeon, "sendHeldHome(fight)")
		local endAt = at(dungeon, "RaidEchoFight.runEnd(fight)")
		expect(departAt < homeAt).toBeTrue()
		expect(homeAt < endAt).toBeTrue()
		expect(string.find(home, "hubCFrame", 1, true) ~= nil).toBeTrue()
		expect(string.find(home, "CombatService.revive", 1, true) ~= nil).toBeTrue()
		expect(string.find(home, "memberRun.resolving = true", 1, true) ~= nil).toBeTrue()
		expect(string.find(home, "RaidEchoFight.setAlive", 1, true)).toBeNil()
		expect(string.find(home, "RaidEcho.wipe", 1, true)).toBeNil()
		expect(string.find(home, "grant(", 1, true)).toBeNil()
		expect(string.find(home, "finish(", 1, true)).toBeNil()
		expect(string.find(home, "bossKill", 1, true)).toBeNil()
	end)
end)

describe("Reserved Echo arrival", function()
	it("joins a matching pull from the server and keeps mismatches apart", function()
		local raid = fs.readFile("src/ServerScriptService/ShardfallServer/RaidService.luau")
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local launch = between(raid, "local function launch", "local function startQueue")
		local receive = between(raid, "function RaidService.receive", "return RaidService")
		local host = between(
			dungeon,
			"function DungeonService.echoHost",
			"function DungeonService.isPractice"
		)

		local holdAt = at(launch, "DungeonService.holdEchoJoin(player, true)")
		local enterAt = at(launch, "DungeonService.enter")
		local tuneAt = at(launch, "DungeonService.tuneRaid")
		local hostAt = at(launch, "DungeonService.echoHost")
		local fillAt = at(launch, "DungeonService.backfill")
		expect(hostAt < holdAt).toBeTrue()
		expect(holdAt < enterAt).toBeTrue()
		expect(enterAt < tuneAt).toBeTrue()
		expect(tuneAt < fillAt).toBeTrue()
		local afterTune = string.sub(launch, tuneAt)
		local hostAfter = string.find(afterTune, "DungeonService.echoHost", 1, true)
		local fillAfter = string.find(afterTune, "DungeonService.backfill", 1, true)
		expect(hostAfter ~= nil and fillAfter ~= nil and hostAfter < fillAfter).toBeTrue()
		expect(string.find(launch, "practice ~= true", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "ProfileLoad.hopOnArrival", 1, true) ~= nil).toBeTrue()
		expect(string.find(launch, "payload", 1, true)).toBeNil()
		expect(string.find(launch, "TeleportData", 1, true)).toBeNil()
		expect(string.find(launch, "GetJoinData", 1, true)).toBeNil()

		expect(string.find(receive, "ProfileLoad.hopOnArrival", 1, true) ~= nil).toBeTrue()
		expect(string.find(receive, "startQueue", 1, true) ~= nil).toBeTrue()
		expect(string.find(receive, "payload.host", 1, true)).toBeNil()
		expect(string.find(receive, "TeleportData.host", 1, true)).toBeNil()
		expect(string.find(receive, "RaidService.queue", 1, true)).toBeNil()
		expect(string.find(receive, "TeleportAsync", 1, true)).toBeNil()
		expect(string.find(receive, "ReserveServer(", 1, true)).toBeNil()

		expect(string.find(host, "otherRun.practice ~= true", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "fight.practice ~= true", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "otherRun.difficulty == difficulty", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "echoJoinHold", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "GetJoinData", 1, true)).toBeNil()
		expect(string.find(host, "TeleportData", 1, true)).toBeNil()
		expect(string.find(dungeon, "function DungeonService.backfill", 1, true) ~= nil).toBeTrue()
	end)
end)
