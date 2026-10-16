--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ClientChrome = require("../src/ReplicatedStorage/Shared/ClientChrome")

describe("Client chrome", function()
	it("replaces the current panels and leaves Roblox core guis alone", function()
		expect(ClientChrome.shouldClear("Shardfall")).toEqual(true)
		expect(ClientChrome.shouldClear("ShardfallCombat")).toEqual(true)
		expect(ClientChrome.shouldClear("ShardfallDebug")).toEqual(true)
		expect(ClientChrome.shouldClear("ShardfallTouch")).toEqual(true)
		expect(ClientChrome.shouldClear("Chat")).toEqual(false)
		expect(ClientChrome.shouldClear("Health")).toEqual(false)
		expect(ClientChrome.legacyReadout("Pity 0/80")).toEqual(true)
		expect(ClientChrome.legacyReadout("Pity 0 / 80 toward Legendary")).toEqual(true)
		expect(ClientChrome.legacyReadout("Pity 0 / 50 toward Legendary")).toEqual(false)
	end)

	it("does not ship the old Pity 0/80 readout", function()
		local ui = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau")
		local reel =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RollReel.luau")
		local thumb =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ThumbBar.luau")
		expect(string.find(ui, "Pity 0/80", 1, true)).toBeNil()
		expect(string.find(reel, "Pity 0/80", 1, true)).toBeNil()
		expect(string.find(ui, "Crack (Shard Token)", 1, true) ~= nil).toBeTrue()
		expect(string.find(thumb, "Toxin", 1, true)).toBeNil()
		expect(string.find(thumb, '"Tonic"', 1, true) ~= nil).toBeTrue()
	end)
end)
