--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

describe("UiTheme", function()
	it("keeps padding, type, and taps on one scale", function()
		expect(UiTheme.PAD >= 8).toBeTrue()
		expect(UiTheme.MIN_TEXT >= 14).toBeTrue()
		expect(UiTheme.CORNER > 0).toBeTrue()
		expect(UiTheme.TAP >= 64).toBeTrue()
		expect(UiTheme.STROKE >= 1).toBeTrue()
		expect(UiTheme.labelWidth("Vault") >= 64).toBeTrue()
		expect(UiTheme.labelWidth("Materials") > UiTheme.labelWidth("Gold")).toBeTrue()
	end)

	it("lifts a dark red so it can sit on the odds panel", function()
		local red, green, blue = UiTheme.lift(230, 64, 78)
		local luma = 0.2126 * (red / 255) + 0.7152 * (green / 255) + 0.0722 * (blue / 255)
		expect(luma >= 0.62).toBeTrue()
		local keepR, keepG, keepB = UiTheme.lift(255, 196, 64)
		expect(keepR).toEqual(255)
		expect(keepG).toEqual(196)
		expect(keepB).toEqual(64)
	end)
end)
