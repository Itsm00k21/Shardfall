--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ClientChrome = require("../src/ReplicatedStorage/Shared/ClientChrome")
local UiRouter = require("../src/ReplicatedStorage/Shared/UiRouter")

local HOTKEYS = {
	hero = "C",
	bag = "B",
	pets = "P",
	roll = "R",
	raids = "I",
	market = "M",
}

describe("UiRouter", function()
	it("matches the hub tab order", function()
		expect(#UiRouter.TABS).toEqual(#ClientChrome.TABS)
		for index, tab in ipairs(ClientChrome.TABS) do
			expect(UiRouter.TABS[index]).toEqual(tab.id)
		end
	end)

	it("switches off Hero on the first inner-tab click", function()
		local state = UiRouter.open(UiRouter.initial(), "hero")
		expect(state.tab).toEqual("hero")
		expect(state.dim).toEqual(UiRouter.DIM)
		expect(state.blocked).toEqual(true)
		state = UiRouter.switch(state, "bag")
		expect(state.tab).toEqual("bag")
		expect(UiRouter.top(state)).toEqual("bag")
		state = UiRouter.switch(state, "pets")
		expect(state.tab).toEqual("pets")
		expect(state.open).toEqual(true)
		expect(state.dim).toEqual(UiRouter.DIM)
		for _, tab in ipairs(UiRouter.TABS) do
			state = UiRouter.switch(state, tab)
			expect(state.tab).toEqual(tab)
			expect(state.dim).toEqual(UiRouter.DIM)
		end
	end)

	it("clears the dim on close and puts it back on the next open", function()
		local state = UiRouter.open(UiRouter.initial(), "hero")
		expect(state.dim).toEqual(UiRouter.DIM)
		state = UiRouter.close(state)
		expect(state.open).toEqual(false)
		expect(state.dim).toEqual(0)
		expect(state.blocked).toEqual(false)
		state = UiRouter.open(state, "hero")
		expect(state.open).toEqual(true)
		expect(state.dim).toEqual(UiRouter.DIM)
		expect(state.tab).toEqual("hero")
	end)

	it("releases the dim for the roll reveal and restores it when the menu returns", function()
		local state = UiRouter.open(UiRouter.initial(), "roll")
		expect(state.dim).toEqual(UiRouter.DIM)
		state = UiRouter.rollHandoff(state)
		expect(state.open).toEqual(false)
		expect(state.dim).toEqual(0)
		expect(state.rollAway).toEqual(true)
		expect(state.blocked).toEqual(false)
		state = UiRouter.open(state, "roll")
		expect(state.dim).toEqual(UiRouter.DIM)
		expect(state.rollAway).toEqual(false)
		expect(state.open).toEqual(true)
	end)

	it("keeps a rapid double-click on one tab and one dim", function()
		local state = UiRouter.open(UiRouter.initial(), "hero")
		state = UiRouter.switch(state, "bag")
		local once = state.generation
		state = UiRouter.switch(state, "bag")
		expect(state.tab).toEqual("bag")
		expect(state.dim).toEqual(UiRouter.DIM)
		expect(state.open).toEqual(true)
		expect(state.generation > once).toBeTrue()
		state = UiRouter.toggle(state, "bag")
		expect(state.open).toEqual(false)
		expect(state.dim).toEqual(0)
		state = UiRouter.toggle(state, "bag")
		state = UiRouter.toggle(state, "bag")
		expect(state.open).toEqual(false)
		expect(state.dim).toEqual(0)
	end)

	it("lets a hotkey change tabs while the menu is open", function()
		local state = UiRouter.open(UiRouter.initial(), "hero")
		state = UiRouter.key(state, "B", HOTKEYS)
		expect(state.open).toEqual(true)
		expect(state.tab).toEqual("bag")
		expect(state.dim).toEqual(UiRouter.DIM)
		state = UiRouter.key(state, "P", HOTKEYS)
		expect(state.tab).toEqual("pets")
		state = UiRouter.key(state, "Escape", HOTKEYS)
		expect(state.open).toEqual(false)
		expect(state.dim).toEqual(0)
	end)

	it("closes the top modal with Esc or B before the menu", function()
		local state = UiRouter.open(UiRouter.initial(), "bag")
		state = UiRouter.push(state, "sets")
		state = UiRouter.push(state, "class")
		expect(UiRouter.top(state)).toEqual("class")
		expect(state.dim).toEqual(UiRouter.DIM)
		state = UiRouter.key(state, "ButtonB", HOTKEYS)
		expect(UiRouter.top(state)).toEqual("sets")
		expect(state.open).toEqual(true)
		expect(state.dim).toEqual(UiRouter.DIM)
		state = UiRouter.key(state, "Escape", HOTKEYS)
		expect(state.tab).toEqual("bag")
		expect(state.open).toEqual(true)
		state = UiRouter.pop(state)
		expect(state.open).toEqual(false)
		expect(state.dim).toEqual(0)
	end)

	it("cycles tabs with the shoulder buttons", function()
		local state = UiRouter.open(UiRouter.initial(), "hero")
		state = UiRouter.shoulder(state, 1)
		expect(state.tab).toEqual("bag")
		state = UiRouter.shoulder(state, 1)
		expect(state.tab).toEqual("pets")
		state = UiRouter.shoulder(state, -1)
		expect(state.tab).toEqual("bag")
		state = UiRouter.open(state, "hero")
		state = UiRouter.shoulder(state, -1)
		expect(state.tab).toEqual("settings")
		local closed = UiRouter.close(state)
		expect(UiRouter.shoulder(closed, 1).open).toEqual(false)
	end)

	it("does not fade the hub panel or let the shell own the dim", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local hub = fs.readFile(root .. "MenuHub.luau")
		local shell = fs.readFile(root .. "HudShell.luau")
		local client = fs.readFile(root .. "init.client.luau")
		expect(string.find(hub, "CanvasGroup", 1, true)).toBeNil()
		expect(string.find(hub, "GroupTransparency", 1, true)).toBeNil()
		expect(string.find(hub, "UiRouter", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "handoffRoll", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "ButtonL1", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "backdrop.Modal", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "1 - state.dim", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, "GroupTransparency = 0.45", 1, true)).toBeNil()
		expect(string.find(shell, "setDimmed", 1, true)).toBeNil()
		expect(string.find(client, "handoffRoll", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "setDimmed", 1, true)).toBeNil()
		expect(string.find(client, "menuHub.toggle", 1, true) ~= nil).toBeTrue()
	end)
end)
