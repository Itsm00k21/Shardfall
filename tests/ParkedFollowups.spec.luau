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
end)
