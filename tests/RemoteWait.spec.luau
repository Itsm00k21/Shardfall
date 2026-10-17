--!strict

--[[
	Client remote lookups cannot run under Lune (no DataModel). These
	assertions lock the timeout and the nil check in the two functions
	the bug names. WaitForChild past the budget returns nil; indexing
	that nil is the crash, and an unbounded wait is the stall.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local function between(source: string, fromNeedle: string, toNeedle: string): string
	local from = string.find(source, fromNeedle, 1, true)
	expect(from ~= nil).toBeTrue()
	local to = string.find(source, toNeedle, (from :: number) + #fromNeedle, true)
	expect(to ~= nil).toBeTrue()
	return string.sub(source, from :: number, (to :: number) - 1)
end

describe("Client remote waits", function()
	it("bounds invoke and returns a failure instead of indexing nil", function()
		local client =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local body = between(
			client,
			"local function invoke(name: string, ...: any)",
			"local function remoteError"
		)
		expect(string.find(body, "REMOTE_WAIT_SECONDS", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "WaitForChild(name, REMOTE_WAIT_SECONDS)", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "WaitForChild%(name%)")).toBeNil()
		local nilAt = string.find(body, "remote == nil", 1, true)
		local invokeAt = string.find(body, "InvokeServer", 1, true)
		expect(nilAt ~= nil and invokeAt ~= nil and (nilAt :: number) < (invokeAt :: number)).toBeTrue()
		expect(string.find(body, "ok = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "remote is not available", 1, true) ~= nil).toBeTrue()
	end)

	it("bounds CombatHud.start and returns before building the hud", function()
		local combat =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau")
		local body = between(
			combat,
			"function CombatHud.start(remotes: Instance, callbacks: Callbacks)",
			'screen.Name = "ShardfallCombat"'
		)
		expect(string.find(body, "REMOTE_WAIT_SECONDS", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, 'WaitForChild("Attack", REMOTE_WAIT_SECONDS)', 1, true) ~= nil).toBeTrue()
		expect(string.find(body, 'WaitForChild("Dodge", REMOTE_WAIT_SECONDS)', 1, true) ~= nil).toBeTrue()
		expect(string.find(body, 'WaitForChild("CombatFx", REMOTE_WAIT_SECONDS)', 1, true) ~= nil).toBeTrue()
		expect(string.find(body, 'WaitForChild%("Attack"%)')).toBeNil()
		expect(string.find(body, 'WaitForChild%("Dodge"%)')).toBeNil()
		expect(string.find(body, 'WaitForChild%("CombatFx"%)')).toBeNil()
		local attackNil = string.find(body, "attack == nil", 1, true)
		local dodgeNil = string.find(body, "dodge == nil", 1, true)
		local fxNil = string.find(body, "fx == nil", 1, true)
		local screenAt = string.find(body, "Instance.new", 1, true)
		expect(attackNil ~= nil and dodgeNil ~= nil and fxNil ~= nil).toBeTrue()
		expect(screenAt == nil or (attackNil :: number) < (screenAt :: number)).toBeTrue()
		expect(string.find(body, "return", 1, true) ~= nil).toBeTrue()
		local guard = string.sub(body, attackNil :: number, dodgeNil :: number)
		expect(string.find(guard, "return", 1, true) ~= nil).toBeTrue()
	end)
end)
