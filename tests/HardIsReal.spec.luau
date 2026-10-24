--!strict

--[[
	Hard is real only when the hardMode flag is on and the arena
	multipliers apply. The flag ships off. schemaVersion stays 26.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")
local PartyGather = require("../src/ReplicatedStorage/Shared/Config/PartyGather")
local HardMode = require("../src/ReplicatedStorage/Shared/HardMode")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Progression = require("../src/ReplicatedStorage/Shared/Progression")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Gather = require("../src/server/PartyGather")
local WaveArena = require("../src/server/WaveArena")

local function withHard(on: boolean, run: () -> ())
	local previous = LaunchGate.SHOW.hardMode
	LaunchGate.SHOW.hardMode = on
	local ok, err = pcall(run)
	LaunchGate.SHOW.hardMode = previous
	if not ok then
		error(err, 0)
	end
end

local function listed(ids: { string }, id: string): boolean
	return table.find(ids, id) ~= nil
end

local function onPad(userId: number, name: string, level: number): any
	return {
		userId = userId,
		name = name,
		level = level,
		levelKnown = true,
		x = PartyGather.pad.x,
		y = PartyGather.pad.y + 3,
		z = PartyGather.pad.z,
		friendKnown = true,
		friendOfLeader = true,
	}
end

local function partyOptions(): any
	return {
		launchGate = { parties = true },
		config = PartyGather,
	}
end

local function arenaOptions(tier: string): any
	local config = table.clone(WaveArenaConfig)
	config.enabled = true
	local player = table.clone(WaveArenaConfig.player)
	player.range = 200
	player.damage = 10000
	player.interval = 0
	config.player = player
	return {
		launchGate = { waveArena = true },
		config = config,
		tier = tier,
	}
end

local function eventOf(events: { any }, kind: string): any
	for _, event in ipairs(events) do
		if event.kind == kind then
			return event
		end
	end
	return nil
end

describe("Arena Hard multipliers", function()
	it("validates the Core Loop row and rejects a paid or weakened copy", function()
		local ok, why = WaveArenaConfig.validate()
		expect(ok).toEqual(true)
		expect(why).toEqual("")
		local hard = WaveArenaConfig.hard
		local econ = Economy.DIFFICULTIES.hard
		expect(hard.hpMultiplier).toEqual(2)
		expect(hard.damageMultiplier).toEqual(1.5)
		expect(hard.tokenMultiplier).toEqual(2)
		expect(hard.fragmentMultiplier).toEqual(2)
		expect(hard.clearHeal).toEqual(0.1)
		expect(hard.hpMultiplier).toEqual(econ.hpMultiplier)
		expect(hard.damageMultiplier).toEqual(econ.damageMultiplier)
		expect(hard.tokenMultiplier).toEqual(econ.tokenMultiplier)
		expect(hard.fragmentMultiplier).toEqual(econ.fragmentMultiplier)
		expect(econ.levelGate).toEqual(5)
		local weak = {
			hard = {
				hpMultiplier = 1,
				damageMultiplier = 1.5,
				tokenMultiplier = 2,
				fragmentMultiplier = 2,
			},
		}
		expect(WaveArenaConfig.validate(weak)).toEqual(false)
		local paid = {
			hard = {
				hpMultiplier = 2,
				damageMultiplier = 1.5,
				tokenMultiplier = 2,
				fragmentMultiplier = 2,
				robux = 1,
			},
		}
		expect(WaveArenaConfig.validate(paid)).toEqual(false)
		local springSized = {
			hard = {
				hpMultiplier = 2,
				damageMultiplier = 1.5,
				tokenMultiplier = 2,
				fragmentMultiplier = 2,
				clearHeal = 0.2,
			},
		}
		local healOk, healWhy = WaveArenaConfig.validate(springSized)
		expect(healOk).toEqual(false)
		expect(healWhy).toEqual("hard clear heal is 10%")
		expect(Schema.VERSION).toEqual(26)
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(LaunchGate.SHOW.parties).toEqual(false)
	end)
end)

describe("Hard is real", function()
	it("is false while the flag is off, even though the multipliers apply", function()
		expect(LaunchGate.on("hardMode")).toEqual(false)
		expect(HardMode.applies(WaveArenaConfig.hard)).toEqual(true)
		expect(HardMode.isHardReal()).toEqual(false)
		expect(HardMode.applies({
			hpMultiplier = 1,
			damageMultiplier = 1.5,
			tokenMultiplier = 2,
			fragmentMultiplier = 2,
		})).toEqual(false)
		expect(HardMode.applies(nil)).toEqual(false)
		expect(listed(Progression.unlocked(20), "hard")).toEqual(false)
	end)

	it("is true only when the flag is on and the multipliers apply", function()
		withHard(true, function()
			expect(HardMode.applies(WaveArenaConfig.hard)).toEqual(true)
			expect(HardMode.isHardReal()).toEqual(true)
			expect(listed(Progression.unlocked(5), "hard")).toEqual(true)
			expect(listed(Progression.unlocked(4), "hard")).toEqual(false)
			expect(Progression.UNLOCKS[3].id).toEqual("hard")
		end)
		expect(HardMode.isHardReal()).toEqual(false)
		expect(listed(Progression.unlocked(20), "hard")).toEqual(false)
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
	end)

	it("scales the arena fight and purse only while Hard is real", function()
		local baseHp = WaveArenaConfig.chaser.hp
		local baseDamage = WaveArenaConfig.chaser.damage
		local baseTokens = WaveArenaConfig.loot.waveTokens[1]
		local baseFragments = WaveArenaConfig.loot.drops.chaser.fragments
		local hard = WaveArenaConfig.hard

		withHard(false, function()
			local options = arenaOptions("hard")
			local run = WaveArena.enter(options)
			expect(run ~= nil).toBeTrue()
			expect(run.tier).toEqual("normal")
			expect(run.enemies[1].hp).toEqual(baseHp)
			expect(run.enemies[1].damage).toEqual(baseDamage)
			local _, events = WaveArena.skip(run, options)
			local purse = eventOf(events, "wavePurse")
			local drop = eventOf(events, "drop")
			expect(purse.tokens).toEqual(baseTokens)
			expect(drop.fragments).toEqual(baseFragments)
		end)

		withHard(true, function()
			local options = arenaOptions("hard")
			local run = WaveArena.enter(options)
			expect(run.tier).toEqual("hard")
			expect(run.enemies[1].hp).toEqual(baseHp * hard.hpMultiplier)
			expect(run.enemies[1].damage).toEqual(baseDamage * hard.damageMultiplier)
			local _, events = WaveArena.skip(run, options)
			local purse = eventOf(events, "wavePurse")
			local drop = eventOf(events, "drop")
			expect(purse.tokens).toEqual(baseTokens * hard.tokenMultiplier)
			expect(drop.fragments).toEqual(baseFragments * hard.fragmentMultiplier)
		end)

		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "HardMode.isHardReal()", 1, true) ~= nil).toBeTrue()
		expect(string.find(host, "HardMode.sessionTier(player.UserId)", 1, true) ~= nil).toBeTrue()
	end)

	it("restores 10% of max HP when a Hard wave clears", function()
		withHard(true, function()
			local options = arenaOptions("hard")
			local run = WaveArena.enter(options)
			expect(run ~= nil).toBeTrue()
			expect(run.tier).toEqual("hard")
			expect(WaveArenaConfig.hard.clearHeal).toEqual(0.1)
			run.player.hp = 100
			WaveArena.skip(run, options)
			local restored = math.floor(run.player.maxHp * WaveArenaConfig.hard.clearHeal)
			expect(restored).toEqual(20)
			expect(run.player.hp).toEqual(100 + restored)
		end)
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
	end)

	it("leaves a Normal clear on the HP it already had", function()
		local function woundedClear(tier: string): any
			local options = arenaOptions(tier)
			local run = WaveArena.enter(options)
			expect(run ~= nil).toBeTrue()
			run.player.hp = 100
			WaveArena.skip(run, options)
			return run
		end

		withHard(true, function()
			local normal = woundedClear("normal")
			expect(normal.tier).toEqual("normal")
			expect(normal.player.hp).toEqual(100)
		end)

		withHard(false, function()
			local run = woundedClear("hard")
			expect(run.tier).toEqual("normal")
			expect(run.player.hp).toEqual(100)
		end)

		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
	end)
end)

describe("Per-player party tier", function()
	it("refuses Hard for every member while Hard is not real", function()
		withHard(false, function()
			local options = partyOptions()
			local state = Gather.new(PartyGather)
			Gather.observe(state, onPad(1, "Ada", 10), 0, options)
			Gather.observe(state, onPad(2, "Bea", 10), 1, options)
			local leader = Gather.setTier(state, 1, "Hard", options)
			expect(leader[1].reason).toEqual("closed")
			local other = Gather.setTier(state, 2, "Hard", options)
			expect(other[1].reason).toEqual("closed")
			expect(state.tier).toEqual("Normal")
			expect(state.members[1].tier).toEqual("Normal")
			expect(state.members[2].tier).toEqual("Normal")
			expect(Gather.setTier(state, 2, "Normal", options)[1].tier).toEqual("Normal")
			expect(Gather.setTier(state, 9, "Normal", options)[1].reason).toEqual("member")
		end)
	end)

	it("lets each member pick, and the run is Hard only when all of them are", function()
		withHard(true, function()
			local options = partyOptions()
			local state = Gather.new(PartyGather)
			Gather.observe(state, onPad(1, "Ada", 10), 0, options)
			Gather.observe(state, onPad(2, "Bea", 10), 1, options)
			local other = Gather.setTier(state, 2, "Hard", options)
			expect(other[1].userId).toEqual(2)
			expect(other[1].tier).toEqual("Hard")
			expect(other[1].reason).toBeNil()
			expect(state.members[2].tier).toEqual("Hard")
			expect(state.members[1].tier).toEqual("Normal")
			expect(state.tier).toEqual("Normal")
			Gather.setTier(state, 1, "Hard", options)
			expect(state.members[1].tier).toEqual("Hard")
			expect(state.tier).toEqual("Hard")
			Gather.setTier(state, 1, "Normal", options)
			expect(state.members[1].tier).toEqual("Normal")
			expect(state.members[2].tier).toEqual("Hard")
			expect(state.tier).toEqual("Normal")
			local low = Gather.new(PartyGather)
			Gather.observe(low, onPad(3, "Cal", 4), 0, options)
			expect(Gather.setTier(low, 3, "Hard", options)[1].reason).toEqual("level")
			expect(low.tier).toEqual("Normal")
		end)
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.SHOW.parties).toEqual(false)
	end)

	it("defaults a qualifying joiner to the party tier and names who kept Normal", function()
		withHard(true, function()
			local options = partyOptions()
			local state = Gather.new(PartyGather)
			Gather.observe(state, onPad(1, "Ada", 10), 0, options)
			Gather.setTier(state, 1, "Hard", options)
			expect(state.tier).toEqual("Hard")
			Gather.observe(state, onPad(2, "Bea", 10), 1, options)
			expect(state.members[2].tier).toEqual("Hard")
			expect(state.members[2].name).toEqual("Bea")
			expect(state.tier).toEqual("Hard")

			local quiet = Gather.new(PartyGather)
			Gather.observe(quiet, onPad(1, "Ada", 10), 0, options)
			Gather.observe(quiet, onPad(2, "Bea", 10), 1, options)
			expect(quiet.members[1].tier).toEqual("Normal")
			expect(quiet.members[2].tier).toEqual("Normal")
			expect(quiet.tier).toEqual("Normal")

			local held = Gather.new(PartyGather)
			Gather.observe(held, onPad(1, "Ada", 10), 0, options)
			Gather.setTier(held, 1, "Hard", options)
			Gather.observe(held, onPad(3, "Cal", 4), 2, options)
			expect(held.members[2].tier).toEqual("Normal")
			expect(held.tier).toEqual("Normal")
			local locked = Gather.tick(held, PartyGather.party.countdown, options)
			expect(locked[1].kind).toEqual("lock")
			expect(locked[1].tier).toEqual("Normal")
			expect(locked[1].keptNormal).toEqual("Cal")

			local solo = Gather.new(PartyGather)
			Gather.observe(solo, onPad(1, "Ada", 10), 0, options)
			Gather.setTier(solo, 1, "Hard", options)
			local hardLock = Gather.tick(solo, PartyGather.party.countdown, options)
			expect(hardLock[1].kind).toEqual("lock")
			expect(hardLock[1].tier).toEqual("Hard")
			expect(hardLock[1].keptNormal).toBeNil()

			local closed = Gather.new(PartyGather)
			Gather.observe(closed, onPad(1, "Ada", 10), 0, options)
			Gather.setTier(closed, 1, "Hard", options)
			expect(closed.members[1].tier).toEqual("Hard")
			LaunchGate.SHOW.hardMode = false
			local closedLock = Gather.tick(closed, PartyGather.party.countdown, options)
			expect(closedLock[1].tier).toEqual("Normal")
			expect(closedLock[1].keptNormal).toBeNil()
			LaunchGate.SHOW.hardMode = true
		end)
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.SHOW.parties).toEqual(false)
	end)
end)

describe("Hard snapshot", function()
	it("keeps the Hard snapshot when the flag or tier flips mid-run", function()
		local baseHp = WaveArenaConfig.chaser.hp
		local baseTokens = WaveArenaConfig.loot.waveTokens[1]
		local hard = WaveArenaConfig.hard
		local healed = math.floor(WaveArenaConfig.player.hp * hard.clearHeal)

		withHard(true, function()
			local options = arenaOptions("hard")
			local run = WaveArena.enter(options)
			expect(run ~= nil).toBeTrue()
			expect(run.hardReal).toEqual(true)
			expect(run.tier).toEqual("hard")
			expect(run.enemies[1].hp).toEqual(baseHp * hard.hpMultiplier)
			LaunchGate.SHOW.hardMode = false
			run.tier = "normal"
			expect(HardMode.isHardReal()).toEqual(false)
			expect(run.hardReal).toEqual(true)
			expect(WaveArena.hud(run, options).isHardReal).toEqual(true)
			run.player.hp = 100
			local _, events = WaveArena.skip(run, options)
			local purse = eventOf(events, "wavePurse")
			expect(purse.tokens).toEqual(baseTokens * hard.tokenMultiplier)
			expect(run.enemies[1].hp).toEqual(baseHp * hard.hpMultiplier)
			expect(run.player.hp).toEqual(100 + healed)
			expect(run.hardReal).toEqual(true)
		end)

		withHard(false, function()
			local options = arenaOptions("hard")
			local run = WaveArena.enter(options)
			expect(run.hardReal).toEqual(false)
			expect(run.tier).toEqual("normal")
			expect(run.enemies[1].hp).toEqual(baseHp)
			LaunchGate.SHOW.hardMode = true
			run.tier = "hard"
			expect(HardMode.isHardReal()).toEqual(true)
			expect(run.hardReal).toEqual(false)
			expect(WaveArena.hud(run, options).isHardReal).toEqual(false)
			run.player.hp = 100
			local _, events = WaveArena.skip(run, options)
			local purse = eventOf(events, "wavePurse")
			expect(purse.tokens).toEqual(baseTokens)
			expect(run.enemies[1].hp).toEqual(baseHp)
			expect(run.player.hp).toEqual(100)
			expect(run.hardReal).toEqual(false)
		end)

		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(Economy.bossClearPay("hard")).toEqual(Economy.BOSS_CLEAR_TOKENS)
		expect(Economy.BOSS_CLEAR_TOKENS).toEqual(5)
	end)
end)
