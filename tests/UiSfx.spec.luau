--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local UiMotion = require("../src/ReplicatedStorage/Shared/UiMotion")
local UiSfx = require("../src/ReplicatedStorage/Shared/UiSfx")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

describe("UiSfx", function()
	it("gives every action a sound and follows the UI volume", function()
		local actions = { "open", "close", "tab", "press", "confirm", "toast" }
		for _, action in ipairs(actions) do
			local id = UiSfx.clip(action)
			expect(string.sub(id, 1, 11)).toEqual("rbxasset://")
		end
		expect(UiSfx.volume(1, 0.5)).toEqual(0.5)
		expect(UiSfx.volume(0, 1)).toEqual(0)
		expect(UiSfx.volume(1, 2)).toEqual(1)
		expect(UiMotion.panel(false)).toEqual(UiTheme.MOTION.panel)
		expect(UiTheme.MOTION.panel).toEqual(0.15)
		expect(UiTheme.MOTION.open).toEqual(0.26)
		expect(UiMotion.panel(true)).toEqual(0)
		expect(UiMotion.reduced({ camera = { flash = "reduced" } })).toEqual(true)
		expect(UiMotion.reduced({ camera = { flash = "normal" } })).toEqual(false)
	end)
end)
