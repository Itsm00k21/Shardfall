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

	it("bounds ProfileUpdated and PolicyUpdated and skips a nil event", function()
		local client =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local profileWait = 'WaitForChild("ProfileUpdated", REMOTE_WAIT_SECONDS)'
		local policyWait = 'WaitForChild("PolicyUpdated", REMOTE_WAIT_SECONDS)'
		local profileAt = string.find(client, profileWait, 1, true)
		local policyAt = string.find(client, policyWait, 1, true)
		expect(profileAt ~= nil).toBeTrue()
		expect(policyAt ~= nil).toBeTrue()
		expect((profileAt :: number) < (policyAt :: number)).toBeTrue()
		expect(string.find(client, 'WaitForChild%("ProfileUpdated"%)')).toBeNil()
		expect(string.find(client, 'WaitForChild%("PolicyUpdated"%)')).toBeNil()

		local profileConnect = string.find(client, "OnClientEvent", profileAt :: number, true)
		local policyConnect = string.find(client, "OnClientEvent", policyAt :: number, true)
		expect(profileConnect ~= nil and policyConnect ~= nil).toBeTrue()
		local profileGuard = string.sub(client, profileAt :: number, (profileConnect :: number) - 1)
		local policyGuard = string.sub(client, policyAt :: number, (policyConnect :: number) - 1)
		expect(string.find(profileGuard, "profileEvent ~= nil", 1, true) ~= nil).toBeTrue()
		expect(string.find(policyGuard, "policyEvent ~= nil", 1, true) ~= nil).toBeTrue()
		local profileIsa = string.find(profileGuard, ":IsA", 1, true)
		local policyIsa = string.find(policyGuard, ":IsA", 1, true)
		local profileNil = string.find(profileGuard, "profileEvent ~= nil", 1, true)
		local policyNil = string.find(policyGuard, "policyEvent ~= nil", 1, true)
		expect(profileIsa ~= nil and profileNil ~= nil).toBeTrue()
		expect((profileNil :: number) < (profileIsa :: number)).toBeTrue()
		expect(policyIsa ~= nil and policyNil ~= nil).toBeTrue()
		expect((policyNil :: number) < (policyIsa :: number)).toBeTrue()
		local getProfile =
			string.find(client, 'invoke("GetProfile")', policyConnect :: number, true)
		expect(getProfile ~= nil).toBeTrue()
	end)

	it("looks up LoadingTips inside start and returns before the screen", function()
		local hud =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/LoadingHud.luau")
		local startAt = string.find(hud, "function LoadingHud.start", 1, true)
		expect(startAt ~= nil).toBeTrue()
		local before = string.sub(hud, 1, (startAt :: number) - 1)
		expect(string.find(before, "WaitForChild", 1, true)).toBeNil()

		local screenAt = string.find(hud, 'Instance.new("ScreenGui")', startAt :: number, true)
		expect(screenAt ~= nil).toBeTrue()
		local body = string.sub(hud, startAt :: number, (screenAt :: number) - 1)
		local sharedAt = string.find(body, 'WaitForChild("Shared", 15)', 1, true)
		local tipsAt = string.find(body, 'WaitForChild("LoadingTips", 15)', 1, true)
		expect(sharedAt ~= nil and tipsAt ~= nil).toBeTrue()
		expect((sharedAt :: number) < (tipsAt :: number)).toBeTrue()
		local sharedNil = string.find(body, "shared == nil", 1, true)
		local tipsNil = string.find(body, "tipsModule == nil", 1, true)
		expect(sharedNil ~= nil and tipsNil ~= nil).toBeTrue()
		local sharedReturn = string.find(body, "return", sharedNil :: number, true)
		local tipsReturn = string.find(body, "return", tipsNil :: number, true)
		local requireAt = string.find(body, "require(", 1, true)
		expect(sharedReturn ~= nil and tipsReturn ~= nil and requireAt ~= nil).toBeTrue()
		expect((sharedReturn :: number) < (requireAt :: number)).toBeTrue()
		expect((tipsReturn :: number) < (requireAt :: number)).toBeTrue()
	end)
end)
