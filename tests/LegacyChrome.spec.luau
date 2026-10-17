--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LegacyChrome = require("../src/ReplicatedStorage/Shared/LegacyChrome")

describe("Legacy chrome", function()
	it("keeps Roblox controls and Shardfall guis", function()
		expect(LegacyChrome.shouldDestroy("TouchGui")).toEqual(false)
		expect(LegacyChrome.shouldDestroy("BubbleChat")).toEqual(false)
		expect(LegacyChrome.shouldDestroy("ShardfallHud")).toEqual(false)
		expect(LegacyChrome.shouldDestroy("ShardfallHub")).toEqual(false)
		expect(LegacyChrome.shouldDestroy("ShardfallCombat")).toEqual(false)
	end)

	it("destroys an unknown ScreenGui from the place file", function()
		expect(LegacyChrome.shouldDestroy("DropRates")).toEqual(true)
		expect(LegacyChrome.shouldDestroy("MainUI")).toEqual(true)
		expect(LegacyChrome.shouldDestroy("Abilities")).toEqual(true)
	end)

	it("names the labels that are not in this repo", function()
		local client = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
			.. fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/LoopHud.luau")
			.. fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RollReel.luau")
		for _, label in ipairs(LegacyChrome.ABSENT) do
			expect(string.find(client, label, 1, true)).toBeNil()
		end
		expect(#LegacyChrome.ABSENT >= 6).toBeTrue()
	end)
end)
