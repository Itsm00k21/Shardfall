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
		expect(gameplay.dodge).toEqual("LeftShift")
		expect(Keybinds.display(gameplay.dodge)).toEqual("Shift")
		expect(gameplay.interact).toEqual("F")
		expect(gameplay.slot1).toEqual("One")
		expect(Keybinds.display(gameplay.slot1)).toEqual("1")
		expect(gameplay.slot2).toEqual("Two")
		expect(Keybinds.display(gameplay.slot2)).toEqual("2")
		expect(gameplay.slot8).toEqual("Eight")
		expect(Keybinds.display(gameplay.slot8)).toEqual("8")
		expect(gameplay.attack).toBeNil()
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
		expect(warning).toBeNil()
		expect(kept.roll).toEqual("E")
		local shift, shiftWarning = Keybinds.assign(Keybinds.copyMenu(nil), "hero", "Q")
		expect(shiftWarning).toBeNil()
		expect(shift.hero).toEqual("Q")
	end)

	it("refuses a tab on a combat key, Shift, or a skill key", function()
		local fresh = Keybinds.copyMenu(nil)
		local cases = {
			{ "F", "F is already interact" },
			{ "R", "R is already heavy" },
			{ "Shift", "Shift is already dodge" },
			{ "LeftShift", "Shift is already dodge" },
			{ "1", "1 is already slot1" },
			{ "2", "2 is already slot2" },
			{ "8", "8 is already slot8" },
			{ "One", "1 is already slot1" },
			{ "ButtonX", "ButtonX is already heavy" },
		}
		for _, pair in ipairs(cases) do
			local kept, warning = Keybinds.assign(fresh, "roll", pair[1])
			expect(warning).toEqual(pair[2])
			expect(kept.roll).toEqual("T")
			expect(#Keybinds.conflicts(Keybinds.gameplay(kept))).toEqual(0)
		end
		local shared, sharedWarning = Keybinds.assign(fresh, "hero", "M")
		expect(sharedWarning).toBeNil()
		expect(shared.hero).toEqual("M")
		expect(shared.market).toEqual("C")
		expect(shared.hero ~= shared.market).toBeTrue()
		expect(#Keybinds.conflicts(Keybinds.gameplay(shared))).toEqual(0)
		local clean = Keybinds.sanitize({
			hero = "Q",
			bag = "e",
			pets = "F",
			roll = "R",
			raids = "1",
			market = "Shift",
		})
		expect(clean.hero).toEqual("Q")
		expect(clean.bag).toEqual("E")
		expect(clean.pets).toEqual("P")
		expect(clean.roll).toEqual("T")
		expect(clean.raids).toEqual("I")
		expect(clean.market).toEqual("M")
		expect(#Keybinds.conflicts(Keybinds.gameplay(clean))).toEqual(0)
		local stacked = Keybinds.sanitize({
			hero = "Z",
			bag = "Z",
			pets = "Z",
			roll = "Z",
			raids = "Z",
			market = "Z",
		})
		expect(stacked.hero).toEqual("Z")
		expect(#Keybinds.conflicts(Keybinds.gameplay(stacked))).toEqual(0)
		local seenLetter: { [string]: boolean } = {}
		for _, field in ipairs(Keybinds.MENU_ORDER) do
			expect(seenLetter[stacked[field]]).toBeNil()
			seenLetter[stacked[field]] = true
			expect(Keybinds.owner(stacked[field])).toBeNil()
		end
		local doubled = Keybinds.copyMenu(nil)
		doubled.hero = "B"
		doubled.bag = "B"
		local repaired, repairWarning = Keybinds.assign(doubled, "roll", "B")
		expect(repairWarning).toBeNil()
		expect(repaired.roll).toEqual("B")
		expect(#Keybinds.conflicts(Keybinds.gameplay(repaired))).toEqual(0)
	end)

	it("reads combat, the rail, and the menu sink from the same table", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local combat = fs.readFile(root .. "CombatHud.luau")
		local shell = fs.readFile(root .. "HudShell.luau")
		local bar = fs.readFile(root .. "ActionBar.luau")
		local hub = fs.readFile(root .. "MenuHub.luau")
		local inventory = fs.readFile(root .. "InventoryHud.luau")
		expect(string.find(combat, "Keybinds.COMBAT.heavy", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "KeyCode.R", 1, true)).toBeNil()
		expect(string.find(combat, "KeyCode.Q", 1, true)).toBeNil()
		expect(string.find(shell, "Keybinds.COMBAT.attack", 1, true)).toBeNil()
		expect(string.find(shell, "Keybinds.MENU", 1, true) ~= nil).toBeTrue()
		expect(string.find(shell, "KeyCode.E", 1, true)).toBeNil()
		expect(string.find(shell, "KeyCode.F", 1, true)).toBeNil()
		expect(string.find(shell, "KeyCode.Two", 1, true)).toBeNil()
		expect(string.find(shell, "KeyCode.One", 1, true)).toBeNil()
		expect(string.find(shell, "Keybinds.ALIAS", 1, true)).toBeNil()
		expect(string.find(shell, "Keybinds.display(Keybinds.COMBAT.skill1)", 1, true)).toBeNil()
		expect(string.find(bar, "ContextActionService", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "ActionSlots.KEYS", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "Keybinds.COMBAT.dodge", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "Keybinds.GAMEPAD.heavy", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "KeyCode.ButtonX", 1, true)).toBeNil()
		expect(string.find(hub, "Keybinds.sinkNames", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "Keybinds.assign", 1, true) ~= nil).toBeTrue()
		expect(string.find(inventory, "KeyCode.I", 1, true)).toBeNil()
		local sink = Keybinds.sinkNames()
		local seen: { [string]: boolean } = {}
		for _, name in ipairs(sink) do
			expect(seen[name]).toBeNil()
			seen[name] = true
		end
		expect(seen.R).toEqual(true)
		expect(seen.E).toBeNil()
		expect(seen.Q).toBeNil()
		expect(seen.F).toEqual(true)
		expect(seen.One).toEqual(true)
		expect(seen.Two).toEqual(true)
		expect(seen.Three).toEqual(true)
		expect(seen.Eight).toEqual(true)
		expect(seen.LeftShift).toEqual(true)
		expect(seen.RightShift).toEqual(true)
		expect(seen.ButtonX).toEqual(true)
		expect(seen.W).toEqual(true)
		expect(seen.A).toEqual(true)
		expect(seen.S).toEqual(true)
		expect(seen.D).toEqual(true)
		expect(seen.Space).toEqual(true)
		expect(seen.C).toBeNil()
		expect(seen.B).toBeNil()
		expect(seen.P).toBeNil()
		expect(seen.T).toBeNil()
		expect(seen.I).toBeNil()
		expect(seen.M).toBeNil()
	end)
end)
