--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local UiIcons = require("../src/ReplicatedStorage/Shared/UiIcons")

describe("UiIcons", function()
	it("lists one rbxasset id for every HUD icon", function()
		local needed = {
			"hero",
			"bag",
			"pets",
			"roll",
			"raids",
			"market",
			"pass",
			"settings",
			"attack",
			"heavy",
			"dodge",
			"skill",
			"ult",
			"item",
			"pet",
			"info",
			"class",
			"empty",
		}
		for _, name in ipairs(needed) do
			local id = UiIcons.get(name)
			expect(type(id)).toEqual("string")
			expect(string.sub(id, 1, 8)).toEqual("rbxasset")
			expect(#id > 8).toBeTrue()
			local red, green, blue = UiIcons.tintOf(name)
			expect(red >= 0 and red <= 255).toBeTrue()
			expect(green >= 0 and green <= 255).toBeTrue()
			expect(blue >= 0 and blue <= 255).toBeTrue()
		end
		expect(UiIcons.get("missing")).toEqual(UiIcons.asset.empty)
	end)

	it("drops the roll dev sentence and draws icons plus a stamp", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local hub = fs.readFile(root .. "MenuHub.luau")
		local shell = fs.readFile(root .. "HudShell.luau")
		expect(string.find(hub, "Roll uses the same result for the spin and the card.", 1, true)).toBeNil()
		expect(string.find(hub, "UiIcons", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Choose class", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, "Build.STAMP", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, "UDim.new(1, 0)", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, '"Hero"', 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, '"Bag"', 1, true) ~= nil).toBeTrue()
	end)
end)
