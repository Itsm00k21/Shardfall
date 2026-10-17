--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ClientChrome = require("../src/ReplicatedStorage/Shared/ClientChrome")
local Keybinds = require("../src/ReplicatedStorage/Shared/Keybinds")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local RollHype = require("../src/ReplicatedStorage/Shared/RollHype")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local UiRouter = require("../src/ReplicatedStorage/Shared/UiRouter")

local HOTKEYS = Keybinds.copyMenu(nil)

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

	it("opens a tab only from a single-letter key name", function()
		local hotkeys = {
			hero = "C",
			bag = "B",
			pets = "P",
			roll = "T",
			raids = "I",
			market = "M",
			pass = "S",
			settings = "L",
		}
		local closed = UiRouter.initial()
		local roll = UiRouter.hotkey(closed, "T", hotkeys)
		expect(roll.open).toEqual(true)
		expect(roll.tab).toEqual("roll")
		local bag = UiRouter.key(roll, "B", hotkeys)
		expect(bag.open).toEqual(true)
		expect(bag.tab).toEqual("bag")
		expect(UiRouter.hotkey(bag, "P", hotkeys).tab).toEqual("pets")
		expect(UiRouter.hotkey(bag, "I", hotkeys).tab).toEqual("raids")
		expect(UiRouter.hotkey(bag, "M", hotkeys).tab).toEqual("market")
		expect(UiRouter.hotkey(bag, "C", hotkeys).tab).toEqual("hero")
		expect(UiRouter.hotkey(closed, "S", hotkeys).tab).toEqual("pass")
		expect(UiRouter.hotkey(closed, "L", hotkeys).tab).toEqual("settings")
		local hero = UiRouter.hotkey(closed, "C", hotkeys)
		for _, name in ipairs({
			"Two",
			"Tab",
			"Space",
			"LeftShift",
			"Backspace",
			"Comma",
			"Period",
			"Minus",
			"Insert",
		}) do
			local stayed = UiRouter.hotkey(closed, name, hotkeys)
			expect(stayed.open).toEqual(false)
			expect(stayed.generation).toEqual(closed.generation)
			local still = UiRouter.key(hero, name, hotkeys)
			expect(still.open).toEqual(true)
			expect(still.tab).toEqual("hero")
			expect(still.generation).toEqual(hero.generation)
		end
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
		expect(string.find(client, "handoffRoll", 1, true)).toBeNil()
		expect(string.find(client, "setDimmed", 1, true)).toBeNil()
		expect(string.find(client, "menuHub.toggle", 1, true) ~= nil).toBeTrue()
	end)

	it("sends Haven stalls to hub tabs and leaves the legacy panels alone", function()
		expect(UiRouter.havenTab("market", nil)).toEqual("market")
		expect(UiRouter.havenTab("craft", nil)).toEqual("bag")
		expect(UiRouter.havenTab("shards", "armory")).toEqual("roll")
		expect(UiRouter.havenTab("armory", nil)).toEqual("roll")
		expect(UiRouter.havenTab("shards", "pets")).toEqual("pets")
		expect(UiRouter.havenTab("pets", nil)).toEqual("pets")
		expect(UiRouter.havenTab("soon", nil)).toBeNil()
		expect(UiRouter.havenTab("rootvault", nil)).toBeNil()
		local client =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		expect(string.find(client, "UiRouter.havenTab", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "menuHub.open(tab)", 1, true) ~= nil).toBeTrue()
		expect(string.find(client, "openPanel", 1, true)).toBeNil()
		local state = UiRouter.open(UiRouter.initial(), UiRouter.havenTab("craft", nil) :: string)
		expect(state.open).toEqual(true)
		expect(state.tab).toEqual("bag")
		state = UiRouter.open(state, UiRouter.havenTab("market", nil) :: string)
		expect(state.tab).toEqual("market")
	end)

	it("uses the live legendary counter, not the pool pity or total rolls", function()
		local counter, goal = UiRouter.legendaryPity({
			sinceLegendary = 12,
			totalRolls = 400,
		}, {
			pity = {
				sinceLegendary = 0,
				rollsSinceLegendary = 49,
				pityLegendaryAt = 50,
				totalRolls = 900,
				legendaryAt = 50,
			},
		})
		expect(counter).toEqual(0)
		expect(goal).toEqual(RarityConfig.LEGENDARY_PITY)
		expect(goal).toEqual(1000)
		local fromProfile = UiRouter.legendaryPity({
			sinceLegendary = 12,
			rollsSinceLegendary = 49,
			totalRolls = 400,
		}, {
			pity = {
				rollsSinceLegendary = 49,
				totalRolls = 400,
			},
		})
		expect(fromProfile).toEqual(12)
		local empty, emptyGoal = UiRouter.legendaryPity(nil, nil)
		expect(empty).toEqual(0)
		expect(emptyGoal).toEqual(1000)
	end)

	it("keeps natural odds until the live guarantee is the next roll", function()
		expect(UiRouter.oddsSince(49)).toEqual(0)
		expect(UiRouter.oddsSince(0)).toEqual(0)
		expect(UiRouter.oddsSince(nil)).toEqual(0)
		expect(UiRouter.oddsSince(RarityConfig.LEGENDARY_PITY - 1)).toEqual(999)
		expect(UiRouter.oddsSince(math.huge)).toEqual(0)
	end)

	it("uses the hype build-up only for a full animation", function()
		local settings = Settings.default()
		local epic = RollHype.tempo("Epic", false)
		local paid = RollHype.tempo("Epic", true)
		expect(epic.buildUp).toEqual(paid.buildUp)
		expect(UiRouter.rollBuildUp(settings, "Epic", false, false, epic)).toEqual(1.2)
		settings.rolls.animation = "short"
		expect(UiRouter.rollBuildUp(settings, "Epic", false, false, epic)).toEqual(0.7)
		settings.rolls.animation = "instant"
		expect(UiRouter.rollBuildUp(settings, "Epic", false, false, epic)).toEqual(0)
		settings.rolls.animation = "full"
		expect(UiRouter.rollBuildUp(settings, "Epic", false, true, epic)).toEqual(0)
		expect(
			UiRouter.rollBuildUp(settings, "Legendary", false, false, RollHype.tempo("Legendary"))
		).toEqual(0)
		settings.rolls.skipAt = "off"
		local secret = RollHype.tempo("Secret", true)
		expect(UiRouter.rollBuildUp(settings, "Secret", true, false, secret)).toEqual(3)
		expect(
			UiRouter.rollBuildUp(settings, "Secret", false, false, RollHype.tempo("Secret", false))
		).toEqual(3)
		local bad = RollHype.tempo("Godly")
		expect(UiRouter.rollBuildUp(settings, "Godly", false, false, bad)).toBeNil()
	end)

	it("toasts the callout and flashes only a new personal best", function()
		local opened = RollHype.fresh(nil)
		expect(opened.ok).toEqual(true)
		local first = RollHype.note(opened.state, { rarity = "Common", paid = true })
		expect(first.ok).toEqual(true)
		local callout, personal = UiRouter.rollShout(first)
		expect(callout).toBeNil()
		expect(personal).toEqual("Common")
		local state = first.state
		for _ = 1, 8 do
			local step = RollHype.note(state, { rarity = "Common" })
			expect(step.ok).toEqual(true)
			state = step.state
		end
		local tenth = RollHype.note(state, { rarity = "Common", paid = false })
		expect(tenth.ok).toEqual(true)
		callout, personal = UiRouter.rollShout(tenth)
		expect(callout).toEqual("10 rolls")
		expect(personal).toBeNil()
		expect(string.find(callout :: string, "Common", 1, true)).toBeNil()
		local card = UiRouter.rollCard(tenth, { name = "Vinewood Sword" })
		expect(card).toEqual({ name = "Vinewood Sword", rarity = "Common" })
		local missed = RollHype.note(tenth.state, { landed = false, rarity = "Legendary" })
		expect(missed.ok).toEqual(true)
		expect(missed.state.best).toEqual("Common")
		expect(UiRouter.rollCard(missed, { name = "Vinewood Sword" })).toBeNil()
		expect(UiRouter.rollShout(missed)).toBeNil()
		local bad = RollHype.note(tenth.state, { rarity = "Godly" })
		expect(bad.ok).toEqual(false)
		expect(UiRouter.rollCard(bad, { name = "Nope", rarity = "Godly" })).toBeNil()
		expect(bad.state.rolls).toEqual(tenth.state.rolls)
	end)

	it("lands the reel on the rolled item and never above it", function()
		local slots = UiRouter.honestSlots({
			{ name = "Crown", rarity = "Legendary" },
			{ name = "Fern", rarity = "Uncommon" },
			{ name = "Myth", rarity = "Mythic" },
			{ name = "Vine", rarity = "Common" },
		}, "Vine", "Common")
		expect(#slots).toEqual(4)
		for _, row in ipairs(slots) do
			expect((Rarities.INDEX[row.rarity] or 99) <= Rarities.INDEX.Common).toBeTrue()
		end
		expect(slots[#slots]).toEqual({ name = "Vine", rarity = "Common" })
		expect(UiRouter.reelCenter(#slots, 0)).toEqual(1)
		expect(UiRouter.reelCenter(#slots, 1)).toEqual(#slots)
		expect(UiRouter.honestSlots(nil, "Vine", "NotARarity")).toEqual({})
	end)

	it("keeps the roll chrome inside a short phone panel", function()
		for _, height in ipairs({ 80, 120, 180, 240, 320, 480 }) do
			local chrome = UiRouter.rollChrome(height)
			expect(chrome.reel >= 0).toBeTrue()
			expect(chrome.button >= 0).toBeTrue()
			expect(chrome.card >= 0).toBeTrue()
			expect(chrome.reel + chrome.button + chrome.card + 20 <= height).toBeTrue()
		end
		local desktop = UiRouter.rollChrome(0)
		expect(desktop.reel).toEqual(68)
		expect(desktop.button).toEqual(72)
		expect(desktop.card).toEqual(112)
	end)

	it("wires RollHype into the roll screen without a paid prompt", function()
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		expect(string.find(hub, "RollHype.note", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "RollHype.pity", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "RollHype.tempo", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "noted.ok", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "near-miss", 1, true)).toBeNil()
		expect(string.find(hub, "Near miss", 1, true)).toBeNil()
		expect(string.find(hub, "Robux", 1, true)).toBeNil()
		expect(string.find(hub, "BuyPrism", 1, true)).toBeNil()
	end)
end)
