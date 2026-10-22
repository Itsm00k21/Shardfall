--!strict

--[[
	The join sweep must never destroy our own hub (Kevin, Oct 22: Settings
	opened to nothing). The Roll page's Epic meter reads "Pity 0/50", which
	ClientChrome.legacyReadout flags as a leftover, so the PlayerGui
	ChildAdded text scan destroyed ShardfallHub at every join.
]]

local fs = require("@lune/fs")
local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ClientChrome = require("../src/ReplicatedStorage/Shared/ClientChrome")
local LegacyChrome = require("../src/ReplicatedStorage/Shared/LegacyChrome")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local ShardBoard = require("../src/ReplicatedStorage/Shared/ShardBoard")

local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau"
local HUB = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau"

describe("HubSweep", function()
	it("the live Roll pity text still trips the legacy check (why the guard exists)", function()
		local live = ShardBoard.pityText(0, RarityConfig.EPIC_PITY)
		expect(ClientChrome.legacyReadout(live)).toEqual(true)
	end)

	it("never text-scans our own guis", function()
		expect(LegacyChrome.textScanned("ShardfallHub")).toEqual(false)
		expect(LegacyChrome.textScanned("ShardfallHud")).toEqual(false)
		expect(LegacyChrome.textScanned("ShardfallRoll")).toEqual(false)
		expect(LegacyChrome.textScanned("ResultsGui")).toEqual(true)
		expect(LegacyChrome.textScanned("ScreenGui")).toEqual(true)
	end)

	it("guards both text sweeps in the client with textScanned", function()
		local client = fs.readFile(CLIENT)
		local _, guards = string.gsub(client, "LegacyChrome%.textScanned%(", "")
		expect(guards).toEqual(2)
		local guardAt =
			string.find(client, "if not LegacyChrome.textScanned(child.Name) then", 1, true)
		local scanAt =
			string.find(client, "if child.Parent ~= nil and legacyText(child) then", 1, true)
		expect(guardAt ~= nil and scanAt ~= nil).toBeTrue()
		expect((guardAt :: number) < (scanAt :: number)).toBeTrue()
		expect(
			string.find(client, "host ~= nil and LegacyChrome.textScanned(host.Name)", 1, true)
				~= nil
		).toBeTrue()
	end)

	it("logs a [MenuHub] warning when a page fails to build", function()
		local hub = fs.readFile(HUB)
		expect(string.find(hub, "local ok, err = pcall(painter)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "[MenuHub] page %s failed to build", 1, true) ~= nil).toBeTrue()
	end)
end)
