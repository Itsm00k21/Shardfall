--!strict

--[[
	Phase 0.1 playtest follow-ups (Kevin, Oct 21): parked starter goals,
	place-file results panel, and its respawned copies.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ClientChrome = require("../src/ReplicatedStorage/Shared/ClientChrome")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local LegacyChrome = require("../src/ReplicatedStorage/Shared/LegacyChrome")
local StarterGoals = require("../src/ReplicatedStorage/Shared/StarterGoals")
local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Onboarding = require("../src/ReplicatedStorage/Shared/Onboarding")
local PracticeLoot = require("../src/ReplicatedStorage/Shared/PracticeLoot")
local Progression = require("../src/ReplicatedStorage/Shared/Progression")
local RollMath = require("../src/ReplicatedStorage/Shared/RollMath")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function chestTotal(data: any): number
	local total = 0
	for _, count in pairs(data.chests or {}) do
		total += count
	end
	return total
end

describe("Parked follow-ups", function()
	it("hides starter goals whose system is parked", function()
		expect(LaunchGate.on("forgeCraft")).toEqual(false)
		expect(LaunchGate.on("guilds")).toEqual(false)
		expect(StarterGoals.reachable("forge")).toEqual(false)
		expect(StarterGoals.reachable("guild")).toEqual(false)
		expect(StarterGoals.reachable("rolls")).toEqual(true)
		expect(StarterGoals.reachable("rootvault")).toEqual(true)
		expect(StarterGoals.reachable("level")).toEqual(true)
		local opened = StarterGoals.fresh() :: any
		local shown = StarterGoals.show(opened.state, {
			forge = 0,
			rootvault = 0,
			rolls = 0,
			level = 1,
			guild = false,
		}) :: any
		expect(shown.ok).toEqual(true)
		local ids = {}
		for _, goal in ipairs(shown.goals) do
			table.insert(ids, goal.id)
		end
		-- The save keeps all five goals. Only the tracker window skips parked ones.
		expect(ids).toEqual({ "rolls", "rootvault", "level" })
		expect(#StarterGoals.ORDER).toEqual(5)
		LaunchGate.SHOW.guilds = true
		expect(StarterGoals.reachable("guild")).toEqual(true)
		LaunchGate.SHOW.guilds = false
	end)

	it("flags the old results panel text, not our clear card", function()
		expect(ClientChrome.legacyReadout("Items Collected")).toEqual(true)
		expect(ClientChrome.legacyReadout("Do not unanchor this chest")).toEqual(true)
		expect(ClientChrome.legacyReadout("Materials")).toEqual(false)
		expect(ClientChrome.legacyReadout("Verdant Bark x1")).toEqual(false)
		expect(ClientChrome.legacyReadout("Rootvault cleared")).toEqual(false)
	end)

	it("treats a StarterGui twin as a place copy, but keeps Roblox controls", function()
		expect(LegacyChrome.isPlaceCopy("Shardfall", true)).toEqual(true)
		expect(LegacyChrome.isPlaceCopy("ResultsGui", true)).toEqual(true)
		expect(LegacyChrome.isPlaceCopy("TouchGui", true)).toEqual(false)
		expect(LegacyChrome.isPlaceCopy("ShardfallHud", false)).toEqual(false)
	end)

	it("declares waveArena off", function()
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(LaunchGate.on("waveArena")).toEqual(false)
	end)

	it("grants no chest from play while chests are parked", function()
		expect(LaunchGate.on("chests")).toEqual(false)
		local data = Schema.template()
		ChestConfig.ensure(data)
		data.chests.Common = 2 -- an owned chest stays put
		local keys = data.shardKeys
		expect(ChestConfig.grantSource(data, "clear", 0)).toBeNil()
		expect(ChestConfig.grantSource(data, "room", 0)).toBeNil()
		expect(#ChestConfig.bossKill(data, 86400 * 3)).toEqual(0)
		expect(data.shardKeys).toEqual(keys + 8 + 2 + 10)
		local _landed, bits = PracticeLoot.applyKill(data, {
			practice = false,
			enemyKind = "grandmother_gnarl",
			boss = true,
			dungeonId = Dungeons.ROOTVAULT_ID,
			difficulty = "nightmare",
			roomId = "boss",
			floorChest = "Rare",
			now = 86400 * 4,
			rng = RollMath.defaultRng(),
			roll = 0.5,
			claim = "run:boss",
		})
		for _, bit in ipairs(bits) do
			expect(string.find(string.lower(bit), "chest", 1, true)).toBeNil()
		end
		Onboarding.starter(data)
		data.level = 4
		data.xp = 0
		Progression.addXp(data, 100000)
		expect(chestTotal(data)).toEqual(2)
		expect(data.chests.Common).toEqual(2)
	end)
end)
