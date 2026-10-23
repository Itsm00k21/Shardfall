--!strict

--[[
	Phase 0.8 hookups. Both switches stay off. Call sites sit after the
	mutate returns, never inside it, and rollPaid stays quiet.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Analytics = require("../src/ReplicatedStorage/Shared/Config/Analytics")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

local function has(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

describe("Phase 0.8 analytics hooks", function()
	it("keeps both switches off and starts only behind the flag", function()
		expect(LaunchGate.on("analytics")).toEqual(false)
		expect(Analytics.ENABLED).toEqual(false)
		local boot = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local gate = string.find(boot, 'LaunchGate.on("analytics")', 1, true)
		local start = string.find(boot, "AnalyticsService.start()", 1, true)
		expect(gate ~= nil and start ~= nil and (gate :: number) < (start :: number)).toBeTrue()
		local debug = fs.readFile("src/ServerScriptService/ShardfallServer/DebugService.luau")
		local printAt = string.find(debug, 'action == "analytics"', 1, true)
		local apply = string.find(debug, "DebugTools.apply(data, action)", 1, true)
		expect(printAt ~= nil and apply ~= nil and (printAt :: number) < (apply :: number)).toBeTrue()
		expect(has(debug, "printRecent()")).toBeTrue()
	end)

	it("records the listed call sites after a successful mutate", function()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(has(dungeon, '"dungeon_enter"')).toBeTrue()
		expect(has(dungeon, '"wave_enter"')).toBeTrue()
		expect(has(dungeon, '"wave_clear"')).toBeTrue()
		expect(has(dungeon, '"dungeon_clear"')).toBeTrue()
		expect(has(dungeon, '"dungeon_leave"')).toBeTrue()
		expect(has(dungeon, '"wave_leave"')).toBeTrue()
		expect(has(dungeon, '"second_run"')).toBeTrue()
		expect(has(dungeon, '"cleared_wave_1"')).toBeTrue()
		expect(has(dungeon, '"finished_first_run"')).toBeTrue()
		expect(has(dungeon, '"entered_gate"')).toBeTrue()

		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		local paidAt = string.find(roll, "function RollService.rollPaid", 1, true)
		expect(paidAt ~= nil).toBeTrue()
		expect(has(string.sub(roll, 1, paidAt :: number), '"roll_x1"')).toBeTrue()
		expect(has(string.sub(roll, 1, paidAt :: number), '"roll_x10"')).toBeTrue()
		expect(has(string.sub(roll, 1, paidAt :: number), '"second_roll"')).toBeTrue()
		expect(string.find(string.sub(roll, paidAt :: number), "AnalyticsService", 1, true) == nil).toBeTrue()

		local inventory = fs.readFile("src/ServerScriptService/ShardfallServer/InventoryService.luau")
		expect(has(inventory, '"first_equip"')).toBeTrue()
		local onboard = fs.readFile("src/ServerScriptService/ShardfallServer/OnboardingService.luau")
		expect(has(onboard, '"tutorial"')).toBeTrue()
		local loop = fs.readFile("src/ServerScriptService/ShardfallServer/LoopService.luau")
		expect(has(loop, '"daily"')).toBeTrue()
		expect(has(loop, "Economy.QUEST_GOLD * finished")).toBeTrue()
		local craft = fs.readFile("src/ServerScriptService/ShardfallServer/CraftService.luau")
		expect(has(craft, '"forge"')).toBeTrue()
		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		expect(has(remotes, '"gold_shop"')).toBeTrue()
	end)
end)
