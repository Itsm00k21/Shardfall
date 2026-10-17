--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Keybinds = require("../src/ReplicatedStorage/Shared/Keybinds")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local UiRouter = require("../src/ReplicatedStorage/Shared/UiRouter")

describe("Keybinds", function()
	it("keeps gameplay keys and menu keys from sharing a letter", function()
		local fresh = Settings.default().controls.hotkeys
		local gameplay = Keybinds.gameplay(fresh)
		expect(gameplay.heavy).toEqual("R")
		expect(gameplay.roll).toEqual("T")
		expect(gameplay.attack).toEqual("E")
		expect(gameplay.dodge).toEqual("Q")
		expect(gameplay.skill1).toEqual("LeftShift")
		expect(gameplay.skill2).toEqual("Two")
		expect(gameplay.ult).toEqual("F")
		expect(gameplay.hero).toEqual("C")
		expect(gameplay.bag).toEqual("B")
		expect(gameplay.pets).toEqual("P")
		expect(gameplay.raids).toEqual("I")
		expect(gameplay.market).toEqual("M")
		expect(#Keybinds.conflicts(gameplay)).toEqual(0)
		expect(#Keybinds.conflicts(Keybinds.COMBAT)).toEqual(0)
		expect(#Keybinds.conflicts(Keybinds.copyMenu(nil))).toEqual(0)
		local broken = Keybinds.gameplay({
			hero = "C",
			bag = "B",
			pets = "P",
			roll = "R",
			raids = "I",
			market = "M",
		})
		expect(#Keybinds.conflicts(broken) > 0).toBeTrue()
	end)

	it("does not open the Roll tab from the heavy attack", function()
		local hotkeys = Settings.normalize({
			controls = { hotkeys = { roll = "R" } },
		}).controls.hotkeys
		expect(hotkeys.roll).toEqual("T")
		local state = UiRouter.key(UiRouter.initial(), "R", hotkeys)
		expect(state.open).toEqual(false)
		state = UiRouter.key(state, "T", hotkeys)
		expect(state.open).toEqual(true)
		expect(state.tab).toEqual("roll")
	end)

	it("swaps a menu letter that is taken and refuses a combat letter", function()
		local swapped, swapWarning = Keybinds.assign(Keybinds.copyMenu(nil), "roll", "B")
		expect(swapWarning).toBeNil()
		expect(swapped.roll).toEqual("B")
		expect(swapped.bag).toEqual("T")
		expect(#Keybinds.conflicts(Keybinds.gameplay(swapped))).toEqual(0)
		local kept, warning = Keybinds.assign(Keybinds.copyMenu(nil), "roll", "E")
		expect(warning).toEqual("E is already attack")
		expect(kept.roll).toEqual("T")
		local shift, shiftWarning = Keybinds.assign(Keybinds.copyMenu(nil), "hero", "Q")
		expect(shiftWarning).toEqual("Q is already dodge")
		expect(shift.hero).toEqual("C")
	end)

	it("reads combat, the rail, and the menu sink from the same table", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local combat = fs.readFile(root .. "CombatHud.luau")
		local shell = fs.readFile(root .. "HudShell.luau")
		local hub = fs.readFile(root .. "MenuHub.luau")
		local inventory = fs.readFile(root .. "InventoryHud.luau")
		expect(string.find(combat, "Keybinds.COMBAT.heavy", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "KeyCode.R", 1, true)).toBeNil()
		expect(string.find(combat, "KeyCode.Q", 1, true)).toBeNil()
		expect(string.find(shell, "Keybinds.COMBAT.attack", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, "Keybinds.MENU", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, "KeyCode.E", 1, true)).toBeNil()
		expect(string.find(shell, "KeyCode.F", 1, true)).toBeNil()
		expect(string.find(shell, "KeyCode.Two", 1, true)).toBeNil()
		expect(string.find(hub, "Keybinds.sinkNames", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Keybinds.assign", 1, true) ~= nil).toBeTrue()
		expect(string.find(inventory, "KeyCode.I", 1, true)).toBeNil()
		local sink = Keybinds.sinkNames(nil)
		local seen: { [string]: boolean } = {}
		for _, name in ipairs(sink) do
			expect(seen[name]).toBeNil()
			seen[name] = true
		end
		expect(seen.R).toEqual(true)
		expect(seen.T).toEqual(true)
		expect(seen.E).toEqual(true)
		expect(seen.Q).toEqual(true)
		expect(seen.F).toEqual(true)
		expect(seen.Two).toEqual(true)
		expect(seen.LeftShift).toEqual(true)
		expect(seen.C).toEqual(true)
		expect(seen.B).toEqual(true)
		expect(seen.P).toEqual(true)
		expect(seen.I).toEqual(true)
		expect(seen.M).toEqual(true)
	end)
end)
