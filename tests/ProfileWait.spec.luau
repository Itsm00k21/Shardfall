--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"

local function unbounded(source: string, name: string): boolean
	local bare = 'WaitForChild("' .. name .. '")'
	return string.find(source, bare, 1, true) ~= nil
end

describe("Profile waits", function()
	it("bounds HavenPrompt, CombatFx, and SetClass so GetProfile can run", function()
		local haven = fs.readFile(CLIENT .. "HavenClient.luau")
		local raids = fs.readFile(CLIENT .. "RaidHud.luau")
		local classes = fs.readFile(CLIENT .. "ClassHud.luau")
		local client = fs.readFile(CLIENT .. "init.client.luau")
		expect(unbounded(haven, "Remotes")).toBeFalse()
		expect(unbounded(haven, "HavenPrompt")).toBeFalse()
		expect(string.find(haven, 'WaitForChild("HavenPrompt", 15)', 1, true) ~= nil).toBeTrue()
		expect(unbounded(raids, "Remotes")).toBeFalse()
		expect(unbounded(raids, "CombatFx")).toBeFalse()
		expect(string.find(raids, 'WaitForChild("CombatFx", 15)', 1, true) ~= nil).toBeTrue()
		expect(unbounded(classes, "SetClass")).toBeFalse()
		expect(string.find(classes, 'WaitForChild("SetClass", 15)', 1, true) ~= nil).toBeTrue()
		local havenAt = string.find(client, "HavenClient.start", 1, true)
		local raidAt = string.find(client, "RaidHud.start", 1, true)
		local classAt = string.find(client, "ClassHud.start", 1, true)
		local profileAt = string.find(client, 'invoke("GetProfile")', 1, true)
		expect(havenAt ~= nil and raidAt ~= nil and classAt ~= nil and profileAt ~= nil).toBeTrue()
		expect((havenAt :: number) < (profileAt :: number)).toBeTrue()
		expect((raidAt :: number) < (profileAt :: number)).toBeTrue()
		expect((classAt :: number) < (profileAt :: number)).toBeTrue()
	end)
end)
