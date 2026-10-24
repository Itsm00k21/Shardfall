--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = require("./oneInventoryOff")(framework.it)
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")
local GuiFake = require("./GuiFake")

local PANELS = {
	{ button = "Hero", page = "hero" },
	{ button = "Bag", page = "bag" },
	{ button = "Pets", page = "pets" },
	{ button = "Roll", page = "roll" },
	{ button = "Shop", page = "shop" },
	{ button = "Settings", page = "settings" },
}

local function profile()
	local inventory = {}
	for index = 1, 24 do
		local uid = "item" .. tostring(index)
		inventory[uid] = {
			uid = uid,
			name = "Blade " .. tostring(index),
			rarity = "Common",
			kind = "Weapon",
		}
	end
	return {
		level = 20,
		xp = 40,
		classId = "warden",
		classXp = { warden = 1800 },
		shardTokens = 10,
		gold = 250,
		shardRolls = 3,
		sinceEpic = 2,
		sinceLegendary = 4,
		inventory = inventory,
		pets = {
			pup = { uid = "pup", name = "Shard Pup", rarity = "Common" },
		},
		equipped = { weapon = "item1", pet = "pup" },
		consumables = { [Materials.TONIC_ID] = 1 },
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	}
end

local function hooks()
	return {
		invoke = function()
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
	}
end

local function boot()
	local world = GuiFake.world()
	local MenuHub = world.load("MenuHub")
	local HudShell = world.load("HudShell")
	local hub = MenuHub.start(world.playerGui, hooks())
	hub.setProfile(profile())
	HudShell.start(world.playerGui, {
		onHero = function()
			hub.open("hero")
		end,
		onBag = function()
			hub.open("bag")
		end,
		onPets = function()
			hub.open("pets")
		end,
		onRoll = function()
			hub.open("roll")
		end,
		onShop = function()
			hub.open("shop")
		end,
		onSettings = function()
			hub.open("settings")
		end,
	})
	return world, hub
end

local function railButton(world, name: string): any
	local rail = GuiFake.findNamed(world.playerGui, "ShardfallRail")
	return GuiFake.findNamed(rail, name)
end

local function pageList(world, pageId: string): any
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
	local page = GuiFake.findNamed(screen, "Body"):FindFirstChild(pageId, false)
	return screen, page, page:FindFirstChild("List")
end

local function sameChildren(left: { any }, right: { any }): boolean
	if #left ~= #right then
		return false
	end
	for index, child in ipairs(left) do
		if right[index] ~= child then
			return false
		end
	end
	return true
end

local function snapshot(list: any): { any }
	local copy = {}
	for _, child in ipairs(list:GetChildren()) do
		table.insert(copy, child)
	end
	return copy
end

describe("MenuSpeed", function()
	it("shows each rail panel within 0.2s and does not rebuild it on the next open", function()
		expect(UiTheme.MOTION.panel <= 0.15).toBeTrue()
		expect(UiTheme.MOTION.panel > 0).toBeTrue()
		for _, panel in ipairs(PANELS) do
			local world, hub = boot()
			local button = railButton(world, panel.button)
			local started = os.clock()
			GuiFake.activate(button)
			local elapsed = os.clock() - started
			expect(elapsed < 0.2).toBeTrue()
			local screen, page, list = pageList(world, panel.page)
			local host = GuiFake.findNamed(screen, "Panel")
			expect(screen.Enabled).toEqual(true)
			expect(host.Visible).toEqual(true)
			expect(page.Visible).toEqual(true)
			expect(#snapshot(list) > 0).toBeTrue()
			local first = snapshot(list)
			local again = os.clock()
			GuiFake.activate(button)
			expect(os.clock() - again < 0.2).toBeTrue()
			expect(sameChildren(first, snapshot(list))).toBeTrue()
			hub.close()
			GuiFake.activate(button)
			expect(page.Visible).toEqual(true)
			expect(sameChildren(first, snapshot(list))).toBeTrue()
		end
	end)

	it("rebuilds the bag when the gear changes and leaves it when nothing changed", function()
		local world, hub = boot()
		GuiFake.activate(railButton(world, "Bag"))
		local _, _, list = pageList(world, "bag")
		local first = snapshot(list)
		hub.close()
		hub.open("bag")
		expect(sameChildren(first, snapshot(list))).toBeTrue()
		hub.close()
		local nextProfile = profile()
		nextProfile.inventory.extra = {
			uid = "extra",
			name = "Extra Blade",
			rarity = "Rare",
			kind = "Weapon",
		}
		hub.setProfile(nextProfile)
		hub.open("bag")
		local _, page = pageList(world, "bag")
		expect(page.Visible).toEqual(true)
		expect(sameChildren(first, snapshot(list))).toBeFalse()
	end)

	it("opens on the same frame as the tap and keeps motion at or under 0.15s", function()
		local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local applyAt = string.find(source, "function hubFn.apply", 1, true)
		local enabledAt = string.find(source, "hubState.screen.Enabled = state.open", applyAt :: number, true)
		local showAt = string.find(source, "hubFn.show(hubFn.pageFor(state))", applyAt :: number, true)
		expect(enabledAt ~= nil and showAt ~= nil and (enabledAt :: number) < (showAt :: number)).toBeTrue()
		local shown = string.find(source, "function hubFn.show", 1, true)
		local ensured = string.find(source, "hubFn.ensure(id)", shown :: number, true)
		local noted = string.find(source, "hubFn.noteView(id)", shown :: number, true)
		expect(ensured ~= nil and noted ~= nil and (ensured :: number) < (noted :: number)).toBeTrue()
		local opened = string.find(source, "function hubFn.open(id: string)", 1, true)
		local toggled = string.find(source, "function hubFn.toggle", opened :: number, true)
		local body = string.sub(source, opened :: number, (toggled :: number) - 1)
		expect(string.find(body, "hubFn.paint()", 1, true)).toBeNil()
		expect(string.find(body, "task.wait", 1, true)).toBeNil()
		expect(string.find(body, "task.delay", 1, true)).toBeNil()
		expect(string.find(body, "WaitForChild", 1, true)).toBeNil()
		expect(string.find(source, "if length > 0.15 then", 1, true) ~= nil).toBeTrue()
	end)
end)
