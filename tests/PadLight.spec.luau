--!strict

--[[
	PadLight is pure. ActionBar and MenuHub do not run under Lune.
	The source lock checks the closed-menu bind and that ButtonR1 is
	not added to the gamepad map the hub sinks.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local PadLight = require("../src/ReplicatedStorage/Shared/PadLight")
local Keybinds = require("../src/ReplicatedStorage/Shared/Keybinds")

local BAR = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau"
local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau"
local BINDS = "src/ReplicatedStorage/Shared/Keybinds.luau"

local NOT_LIGHT = {
	"ButtonX",
	"ButtonY",
	"ButtonA",
	"ButtonB",
	"ButtonL1",
	"ButtonL2",
	"ButtonR2",
	"DPadUp",
	"DPadRight",
	"DPadDown",
	"DPadLeft",
	"R",
	"LeftShift",
	"MouseButton1",
	"Touch",
	"",
}

describe("PadLight", function()
	it("fires ButtonR1 only while the menu is closed", function()
		expect(PadLight.KEY).toEqual("ButtonR1")
		expect(PadLight.fire("ButtonR1", false)).toEqual(true)
		expect(PadLight.fire("ButtonR1", nil)).toEqual(true)
		expect(PadLight.fire("ButtonR1", true)).toEqual(false)
		expect(PadLight.fire(nil, false)).toEqual(false)
		expect(PadLight.fire(nil, true)).toEqual(false)
		for _, key in ipairs(NOT_LIGHT) do
			expect(PadLight.fire(key, false)).toEqual(false)
			expect(PadLight.fire(key, nil)).toEqual(false)
			expect(PadLight.fire(key, true)).toEqual(false)
		end
	end)

	it("ignores a third argument, including paid", function()
		local paid = { paid = true, productId = 0, robux = 0, cost = 0, skip = true }
		expect(PadLight.fire("ButtonR1", false, { paid = true })).toEqual(true)
		expect(PadLight.fire("ButtonR1", true, paid)).toEqual(false)
		expect(PadLight.fire("ButtonX", false, paid)).toEqual(false)
		expect(PadLight.fire("ButtonR1", false, true)).toEqual(true)
		expect(PadLight.fire("ButtonR1", nil, paid)).toEqual(true)
	end)

	it("does not write its arguments", function()
		local key = { name = "ButtonR1", paid = true }
		local menu = { open = false, paid = false }
		local extra = { paid = true, productId = 0, robux = 0, cost = 0, skip = false }
		table.freeze(key)
		table.freeze(menu)
		table.freeze(extra)
		expect(PadLight.fire(key, menu, extra)).toEqual(false)
		expect(PadLight.fire("ButtonR1", false, extra)).toEqual(true)
		expect(key.name).toEqual("ButtonR1")
		expect(key.paid).toEqual(true)
		expect(menu.open).toEqual(false)
		expect(menu.paid).toEqual(false)
		expect(extra.paid).toEqual(true)
		expect(extra.productId).toEqual(0)
		expect(extra.robux).toEqual(0)
		expect(extra.cost).toEqual(0)
		expect(extra.skip).toEqual(false)
	end)

	it("does not use a clock, rng, or services", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/PadLight.luau")
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		expect(string.find(source, "tick(", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "Random.new", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
	end)

	it("binds the bumper without taking the hub tab key", function()
		local bar = fs.readFile(BAR)
		local client = fs.readFile(CLIENT)
		local binds = fs.readFile(BINDS)
		expect(string.find(bar, "ShardfallLight", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "PadLight.fire", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "PadLight.KEY", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "callbacks.onLight", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "CombatStage.swing()", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "CombatHud.swing(false)", 1, true) ~= nil).toBeTrue()
		expect(Keybinds.GAMEPAD.heavy).toEqual("ButtonX")
		expect(Keybinds.GAMEPAD.dodge).toEqual("ButtonY")
		expect(Keybinds.GAMEPAD.light).toBeNil()
		local sink = Keybinds.sinkNames()
		local seen: { [string]: boolean } = {}
		for _, name in ipairs(sink) do
			seen[name] = true
		end
		expect(seen.ButtonR1).toBeNil()
		expect(seen.ButtonX).toEqual(true)
		expect(seen.ButtonY).toEqual(true)
		expect(string.find(binds, 'light = "ButtonR1"', 1, true)).toBeNil()
	end)
end)
