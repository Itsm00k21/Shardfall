--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Keybinds = require("../src/ReplicatedStorage/Shared/Keybinds")
local UiSelection = require("../src/ReplicatedStorage/Shared/UiSelection")

describe("UiSelection", function()
	it("clears a click-held selection for mouse, touch and keyboard", function()
		for _, name in ipairs({ "MouseButton1", "MouseMovement", "Touch", "Keyboard", "MouseWheel" }) do
			expect(UiSelection.shouldClear(name, true)).toEqual(true)
		end
	end)

	it("keeps a gamepad selection and ignores no selection", function()
		for _, name in ipairs({ "Gamepad1", "Gamepad2", "Gamepad8" }) do
			expect(UiSelection.shouldClear(name, true)).toEqual(false)
			expect(UiSelection.isGamepad(name)).toEqual(Keybinds.usesGamepad(name))
		end
		expect(UiSelection.shouldClear("MouseButton1", false)).toEqual(false)
		expect(UiSelection.shouldClear(nil, true)).toEqual(true)
		expect(UiSelection.isGamepad("Gamepad9")).toEqual(false)
	end)
end)
