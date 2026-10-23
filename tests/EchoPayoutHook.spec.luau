--!strict

--[[
	Phase 4 hookups. The payouts switch stays off, so run end does not
	grant or write a profile. Schema stays 26. Product ids stay 0.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

describe("Phase 4 payout hooks", function()
	it("keeps payouts off and grants only behind the flag", function()
		expect(LaunchGate.on("payouts")).toEqual(false)
		expect(LaunchGate.SHOW.payouts).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
		local boot = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local gate = string.find(boot, 'LaunchGate.on("payouts")', 1, true)
		local load = string.find(boot, "require(script.PayoutService)", 1, true)
		expect(gate ~= nil and load ~= nil and (gate :: number) < (load :: number)).toBeTrue()
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(dungeon, "PayoutService).grant(", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "data.shardTokens += payout.tokens", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "if payout.paid == true then", 1, true) ~= nil).toBeTrue()
		local hookAt = string.find(dungeon, "local function echoRunPayout", 1, true)
		expect(hookAt ~= nil).toBeTrue()
		local hook = string.sub(dungeon, hookAt :: number, (hookAt :: number) + 1800)
		expect(string.find(hook, "fragments", 1, true) == nil).toBeTrue()
	end)
end)
