--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidEcho = require("../src/ReplicatedStorage/Shared/RaidEcho")
local RaidEchoFight = require("../src/ReplicatedStorage/Shared/RaidEchoFight")
local PracticeLoot = require("../src/ReplicatedStorage/Shared/PracticeLoot")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function pull(fight: RaidEchoFight.Fight, bossId: string)
	RaidEchoFight.notePull(fight, bossId)
end

local function down(fight: RaidEchoFight.Fight, userId: string): RaidEcho.WipeResult?
	return RaidEchoFight.setAlive(fight, userId, false)
end

local function up(fight: RaidEchoFight.Fight, userId: string)
	RaidEchoFight.setAlive(fight, userId, true)
end

local function wipeOnce(fight: RaidEchoFight.Fight, userId: string): RaidEcho.WipeResult?
	local result = down(fight, userId)
	up(fight, userId)
	return result
end

local function step(): number
	return 1 + RaidEcho.CONFIG.perWipe
end

local function between(source: string, startText: string, endText: string): string
	local startAt = string.find(source, startText, 1, true)
	assert(startAt ~= nil, "missing " .. startText)
	local endAt = string.find(source, endText, startAt + #startText, 1, true)
	assert(endAt ~= nil, "missing " .. endText)
	return string.sub(source, startAt, endAt - 1)
end

local function heartwoodKill(practice: boolean): PracticeLoot.KillContext
	return {
		practice = practice,
		enemyKind = "grandmother_gnarl",
		boss = true,
		dungeonId = "heartwood",
		difficulty = "story",
		roomId = "awakened",
		floorChest = "Rare",
		now = 1_700_000_000,
		rng = {
			nextNumber = function()
				return 0
			end,
			nextInteger = function(_self, min: number, _max: number)
				return min
			end,
		},
		roll = 1,
	}
end

describe("Raid echo wipe detection", function()
	it("counts one whole-party death after the boss pull", function()
		local fight = RaidEchoFight.open("story", false, "1")
		expect(fight.state.stacks).toEqual(0)
		local early = down(fight, "1")
		assert(early ~= nil)
		expect(early.ok).toEqual(true)
		expect(early.reason).toEqual("pull")
		expect(early.counted).toEqual(false)
		expect(fight.state.stacks).toEqual(0)
		up(fight, "1")

		pull(fight, "twins")
		local counted = down(fight, "1")
		assert(counted ~= nil)
		expect(counted.counted).toEqual(true)
		expect(counted.added).toEqual(true)
		expect(fight.state.stacks).toEqual(1)
		local repeatDown = down(fight, "1")
		expect(repeatDown).toBeNil()
		expect(fight.state.stacks).toEqual(1)

		up(fight, "1")
		local again = down(fight, "1")
		assert(again ~= nil)
		expect(again.added).toEqual(true)
		expect(fight.state.stacks).toEqual(2)
	end)

	it("does not count a partial death or an enemy tally", function()
		local fight = RaidEchoFight.open("story", false, "1")
		RaidEchoFight.backfill(fight, "2")
		pull(fight, "twins")
		expect(down(fight, "1")).toBeNil()
		expect(fight.state.stacks).toEqual(0)
		local living, party = RaidEchoFight.counts(fight)
		expect(living).toEqual(1)
		expect(party).toEqual(2)
		local wiped = down(fight, "2")
		assert(wiped ~= nil)
		expect(wiped.counted).toEqual(true)
		expect(wiped.stacks).toEqual(1)
		expect(fight.state.stacks).toEqual(1)
	end)
end)

describe("Raid echo per-boss reset", function()
	it("clears stacks on that boss kill and on run end", function()
		local fight = RaidEchoFight.open("story", false, "1")
		pull(fight, "twins")
		wipeOnce(fight, "1")
		expect(fight.state.stacks).toEqual(1)
		expect(fight.bossId).toEqual("twins")

		local killed = RaidEchoFight.bossKill(fight)
		expect(killed.ok).toEqual(true)
		expect(killed.reason).toEqual("kill")
		expect(killed.cleared).toEqual(true)
		expect(fight.state.stacks).toEqual(0)
		expect(fight.pullStarted).toEqual(false)

		pull(fight, "sapwell")
		expect(fight.state.stacks).toEqual(0)
		wipeOnce(fight, "1")
		expect(fight.state.stacks).toEqual(1)
		expect(fight.bossId).toEqual("sapwell")

		local ended = RaidEchoFight.runEnd(fight)
		expect(ended.reason).toEqual("end")
		expect(ended.cleared).toEqual(true)
		expect(fight.state.stacks).toEqual(0)
		expect(fight.pullStarted).toEqual(false)
	end)
end)

describe("Raid echo apply", function()
	it("scales damage, healing, and max HP from the unbuffed base", function()
		local fight = RaidEchoFight.open("story", false, "1")
		pull(fight, "twins")
		wipeOnce(fight, "1")
		local damage = RaidEchoFight.applyBase(fight, "1", "damage", 200)
		local healing = RaidEchoFight.applyBase(fight, "1", "healing", 80)
		local maxHp = RaidEchoFight.applyBase(fight, "1", "maxHp", 1000)
		expect(damage).toEqual(math.floor(200 * step() + 0.5))
		expect(healing).toEqual(math.floor(80 * step() + 0.5))
		expect(maxHp).toEqual(math.floor(1000 * step()))
		expect(fight.bases["1"].damage).toEqual(200)
		expect(fight.bases["1"].healing).toEqual(80)
		expect(fight.bases["1"].maxHp).toEqual(1000)

		local damageAgain = RaidEchoFight.applyBase(fight, "1", "damage", 200)
		local healingAgain = RaidEchoFight.reapply(fight, "1", "healing")
		local maxAgain = RaidEchoFight.reapply(fight, "1", "maxHp")
		expect(damageAgain).toEqual(damage)
		expect(healingAgain).toEqual(healing)
		expect(maxAgain).toEqual(maxHp)
		expect(fight.bases["1"].damage).toEqual(200)
		expect(fight.bases["1"].maxHp).toEqual(1000)

		local compounded = math.floor(damage * step() + 0.5)
		expect(damageAgain).toBeLessThan(compounded)
		wipeOnce(fight, "1")
		local raised = RaidEchoFight.reapply(fight, "1", "maxHp")
		expect(raised).toEqual(math.floor(1000 * (1 + 2 * RaidEcho.CONFIG.perWipe)))
		expect(fight.bases["1"].maxHp).toEqual(1000)
		expect(raised).toBeGreaterThan(maxHp)
	end)

	it("pays nothing on Normal even when stacks are stored", function()
		local fight = RaidEchoFight.open("normal", false, "1")
		fight.state = { stacks = 5 }
		pull(fight, "twins")
		local wiped = down(fight, "1")
		assert(wiped ~= nil)
		expect(wiped.reason).toEqual("difficulty")
		expect(fight.state.stacks).toEqual(5)
		expect(RaidEchoFight.applyBase(fight, "1", "damage", 100)).toEqual(100)
		expect(RaidEchoFight.applyBase(fight, "1", "healing", 40)).toEqual(40)
		expect(RaidEchoFight.applyBase(fight, "1", "maxHp", 1000)).toEqual(1000)
		expect(RaidEchoFight.chip(fight.state, "normal")).toBeNil()
	end)
end)

describe("Raid echo backfill", function()
	it("inherits the party's current stacks", function()
		local fight = RaidEchoFight.open("story", false, "1")
		pull(fight, "galecrown")
		wipeOnce(fight, "1")
		wipeOnce(fight, "1")
		expect(fight.state.stacks).toEqual(2)
		local shared = fight.state
		local same = RaidEchoFight.backfill(fight, "9")
		expect(same).toEqual(fight)
		expect(fight.state).toEqual(shared)
		expect(fight.state.stacks).toEqual(2)
		expect(fight.members["9"].alive).toEqual(true)

		local joined = RaidEchoFight.applyBase(fight, "9", "damage", 80)
		local host = RaidEchoFight.applyBase(fight, "1", "damage", 80)
		expect(joined).toEqual(host)
		expect(joined).toEqual(math.floor(80 * (1 + 2 * RaidEcho.CONFIG.perWipe) + 0.5))

		expect(down(fight, "1")).toBeNil()
		expect(fight.state.stacks).toEqual(2)
		local wiped = down(fight, "9")
		assert(wiped ~= nil)
		expect(wiped.added).toEqual(true)
		expect(fight.state.stacks).toEqual(3)
		expect(RaidEchoFight.reapply(fight, "9", "damage")).toEqual(
			math.floor(80 * (1 + 3 * RaidEcho.CONFIG.perWipe) + 0.5)
		)
	end)
end)

describe("Raid echo practice", function()
	it("adds nothing", function()
		local fight = RaidEchoFight.open("story", true, "1")
		pull(fight, "awakened")
		local wiped = down(fight, "1")
		assert(wiped ~= nil)
		expect(wiped.reason).toEqual("practice")
		expect(wiped.counted).toEqual(false)
		expect(wiped.added).toEqual(false)
		expect(fight.state.stacks).toEqual(0)
		expect(RaidEchoFight.chip(fight.state, "story")).toBeNil()
		fight.state = { stacks = 4 }
		expect(RaidEchoFight.applyBase(fight, "1", "damage", 100)).toEqual(100)
		expect(RaidEchoFight.applyBase(fight, "1", "healing", 50)).toEqual(50)
		expect(RaidEchoFight.applyBase(fight, "1", "maxHp", 900)).toEqual(900)
	end)
end)

describe("Raid echo chip", function()
	it("shows Echo +X% only while the bonus is above zero", function()
		local fight = RaidEchoFight.open("story", false, "1")
		expect(RaidEchoFight.chip(fight.state, "story")).toBeNil()
		pull(fight, "twins")
		wipeOnce(fight, "1")
		local view = RaidEcho.bonus(fight.state, "story")
		local pct = math.floor(view.bonus * 100 + 0.5)
		expect(RaidEchoFight.chip(fight.state, "story")).toEqual(string.format("Echo +%d%%", pct))
		expect(pct).toEqual(math.floor(RaidEcho.CONFIG.perWipe * 100 + 0.5))
		RaidEchoFight.bossKill(fight)
		expect(RaidEchoFight.chip(fight.state, "story")).toBeNil()
	end)
end)

describe("Practice Grove loot gate", function()
	it("a Heartwood boss kill in damageEnemy cannot pay drops or chests", function()
		expect(PracticeLoot.pays(true)).toEqual(false)
		local practice = Schema.template()
		practice.level = 20
		local landed, chests = PracticeLoot.applyKill(practice, heartwoodKill(true))
		expect(landed).toEqual({})
		expect(chests).toEqual({})
		expect(practice.chests.Rare).toEqual(0)
		expect(practice.chests.Epic).toEqual(0)
		expect(practice.chests.Legendary).toEqual(0)
		expect(practice.raidMarks).toEqual(0)

		local live = Schema.template()
		live.level = 20
		local paid, labels = PracticeLoot.applyKill(live, heartwoodKill(false))
		expect(#labels > 0).toBeTrue()
		local paidAny = false
		for _, count in pairs(paid) do
			if type(count) == "number" and count > 0 then
				paidAny = true
			end
		end
		expect(paidAny).toBeTrue()

		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local body = between(
			dungeon,
			"function DungeonService.damageEnemy",
			"function DungeonService.enemyViews"
		)
		expect(string.find(body, "Drops.apply", 1, true)).toBeNil()
		expect(string.find(body, "ChestConfig.enemyDrop", 1, true)).toBeNil()
		expect(string.find(body, "ChestConfig.bossKill", 1, true)).toBeNil()
		local gate = "if PracticeLoot.pays(run.practice == true) then"
		local gateAt = string.find(body, gate, 1, true)
		local killAt = string.find(body, "PracticeLoot.applyKill", 1, true)
		expect(gateAt ~= nil and killAt ~= nil and gateAt < killAt).toBeTrue()
		local beforeGate = string.sub(body, 1, (gateAt :: number) - 1)
		expect(string.find(beforeGate, "PracticeLoot.applyKill", 1, true)).toBeNil()
		expect(string.find(beforeGate, "Drops.apply", 1, true)).toBeNil()
		expect(string.find(beforeGate, "ChestConfig.enemyDrop", 1, true)).toBeNil()
		expect(string.find(beforeGate, "ChestConfig.bossKill", 1, true)).toBeNil()
	end)
end)

describe("Raid echo wire", function()
	it("hooks the live fight and the hud chip", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local hud =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RaidHud.luau")
		local fight = fs.readFile("src/ReplicatedStorage/Shared/RaidEchoFight.luau")
		local down = between(
			dungeon,
			"function DungeonService.onPlayerDown",
			"function DungeonService.backfill"
		)
		expect(string.find(down, "aliveCount", 1, true)).toBeNil()
		expect(string.find(down, "RaidEchoFight.setAlive", 1, true) ~= nil).toBeTrue()
		expect(string.find(down, "retryPull", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "RaidEchoFight.bossKill", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "RaidEchoFight.runEnd", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "RaidEchoFight.applyBase", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, '"damage"', 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, '"healing"', 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, '"maxHp"', 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "run.echo * 0.05", 1, true)).toBeNil()
		expect(string.find(dungeon, "data.raidEcho", 1, true)).toBeNil()
		local backfill =
			between(dungeon, "function DungeonService.backfill", "function DungeonService.start")
		expect(string.find(backfill, "run.echoFight = hostRun.echoFight", 1, true) ~= nil).toBeTrue()
		expect(string.find(backfill, "RaidEchoFight.backfill", 1, true) ~= nil).toBeTrue()
		expect(string.find(backfill, "RaidEcho.fresh", 1, true)).toBeNil()
		expect(string.find(fight, "RaidEcho.wipe", 1, true) ~= nil).toBeTrue()
		expect(string.find(fight, "RaidEcho.reset", 1, true) ~= nil).toBeTrue()
		expect(string.find(fight, "RaidEcho.apply", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, 'chip.Name = "EchoChip"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "run.echoLabel", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "echoLabel", 1, true) ~= nil).toBeTrue()
	end)
end)
