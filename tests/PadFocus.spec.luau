--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local PadFocus = require("../src/StarterPlayer/StarterPlayerScripts/ShardfallClient/PadFocus")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

describe("PadFocus", function()
	it("walks focus order up and down and wraps", function()
		local entries = {
			{ column = 0, order = 1, x = 0, y = 0, w = 40, h = 40, seq = 1 },
			{ column = 0, order = 2, x = 0, y = 0, w = 40, h = 40, seq = 2 },
			{ column = 2, order = 1, x = 200, y = 0, w = 40, h = 40, seq = 3 },
		}
		expect(PadFocus.step(entries, 1, "down")).toEqual(2)
		expect(PadFocus.step(entries, 2, "down")).toEqual(3)
		expect(PadFocus.step(entries, 3, "down")).toEqual(1)
		expect(PadFocus.step(entries, 1, "up")).toEqual(3)
		expect(PadFocus.step(entries, 1, "down", true)).toEqual(2)
		expect(PadFocus.step(entries, 0, "down")).toEqual(2)
	end)

	it("jumps sideways to the nearest control", function()
		local entries = {
			{ column = 0, order = 1, x = 0, y = 0, w = 40, h = 40, seq = 1 },
			{ column = 0, order = 2, x = 0, y = 80, w = 40, h = 40, seq = 2 },
			{ column = 2, order = 1, x = 200, y = 0, w = 40, h = 40, seq = 3 },
		}
		expect(PadFocus.step(entries, 1, "right")).toEqual(3)
		expect(PadFocus.step(entries, 1, "right", { paid = true })).toEqual(3)
		expect(PadFocus.step(entries, 3, "left")).toEqual(1)
		expect(PadFocus.step(entries, 2, "right")).toEqual(3)
	end)

	it("steps the left stick once per tilt", function()
		local direction, held = PadFocus.stick(0, 0.2, "")
		expect(direction).toBeNil()
		expect(held).toEqual("")
		direction, held = PadFocus.stick(0, -0.8, "")
		expect(direction).toEqual("down")
		expect(held).toEqual("down")
		local again, still = PadFocus.stick(0, -0.9, held)
		expect(again).toBeNil()
		expect(still).toEqual("down")
		local released, clear = PadFocus.stick(0, 0, still)
		expect(released).toBeNil()
		expect(clear).toEqual("")
		local up, upHeld = PadFocus.stick(0, 0.9, "", true)
		expect(up).toEqual("up")
		expect(upHeld).toEqual("up")
		local right = PadFocus.stick(0.9, 0.1, "")
		expect(right).toEqual("right")
		local left = PadFocus.stick(-0.9, 0.1, "")
		expect(left).toEqual("left")
		expect(PadFocus.stick("x", 1, "")).toBeNil()
		expect(PadFocus.stick(0, 0 / 0, "")).toBeNil()
	end)

	it("names the d-pad and keeps the ring readable", function()
		expect(PadFocus.direction("DPadUp")).toEqual("up")
		expect(PadFocus.direction("DPadRight")).toEqual("right")
		expect(PadFocus.direction("DPadDown")).toEqual("down")
		expect(PadFocus.direction("DPadLeft")).toEqual("left")
		expect(PadFocus.direction("ButtonA")).toBeNil()
		expect(PadFocus.direction("ButtonB")).toBeNil()
		expect(PadFocus.direction("ButtonR1")).toBeNil()
		expect(PadFocus.RING >= 4).toBeTrue()
		expect(UiTheme.contrast(PadFocus.RING_RGB, UiTheme.RGB.panel) >= 4.5).toBeTrue()
		expect(UiTheme.contrast(PadFocus.RING_RGB, UiTheme.RGB.body) >= 4.5).toBeTrue()
		expect(UiTheme.contrast(PadFocus.RING_RGB, UiTheme.RGB.header) >= 4.5).toBeTrue()
	end)
end)
