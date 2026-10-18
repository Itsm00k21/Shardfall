--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
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
	return {
		level = 20,
		xp = 40,
		classId = "warden",
		classXp = { warden = 1800 },
		shardTokens = 10,
		gold = 250,
		shardRolls = 3,
		inventory = {
			sword = {
				uid = "sword",
				name = "Practice Blade",
				rarity = "Common",
				kind = "Weapon",
			},
		},
		pets = {
			pup = { uid = "pup", name = "Shard Pup", rarity = "Common" },
		},
		equipped = { weapon = "sword", pet = "pup" },
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	}
end

local function boot()
	local world = GuiFake.world()
	local MenuHub = world.load("MenuHub")
	local HudShell = world.load("HudShell")
	local hub = MenuHub.start(world.playerGui, {
		invoke = function()
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
	})
	hub.setProfile(profile())
	HudShell.start(world.playerGui, {
		onHero = function()
			hub.toggle("hero")
		end,
		onBag = function()
			hub.toggle("bag")
		end,
		onPets = function()
			hub.toggle("pets")
		end,
		onRoll = function()
			hub.toggle("roll")
		end,
		onShop = function()
			hub.toggle("shop")
		end,
		onSettings = function()
			hub.toggle("settings")
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

describe("PadWalk", function()
	it("throws when a layout is asked for LayoutOrder", function()
		local world = GuiFake.world()
		local MenuHub = world.load("MenuHub")
		local hub = MenuHub.start(world.playerGui, {
			invoke = function()
				return { ok = true }
			end,
			onDim = function() end,
		})
		hub.setProfile(profile())
		local _, _, list = pageList(world, "hero")
		local layout = list:FindFirstChildOfClass("UIListLayout")
		expect(layout ~= nil).toBeTrue()
		local before = GuiFake.invalidReads
		local ok, err = pcall(function()
			return layout.LayoutOrder
		end)
		expect(ok).toEqual(false)
		expect(string.find(tostring(err), "LayoutOrder is not a valid member of UIListLayout", 1, true) ~= nil).toBeTrue()
		expect(GuiFake.invalidReads).toEqual(before + 1)
		local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
		local close = GuiFake.findNamed(screen, "Close")
		local readOk = pcall(function()
			return close.LayoutOrder
		end)
		expect(readOk).toEqual(true)
	end)

	it("opens every rail panel with a list layout and zero handler errors", function()
		GuiFake.invalidReads = 0
		local world, hub = boot()
		for _, panel in ipairs(PANELS) do
			local screen, page, list = pageList(world, panel.page)
			expect(list:FindFirstChildOfClass("UIListLayout") ~= nil).toBeTrue()
			local errors = 0
			local ok = xpcall(function()
				GuiFake.activate(railButton(world, panel.button))
			end, function()
				errors += 1
				return "handler"
			end)
			expect(ok).toEqual(true)
			expect(errors).toEqual(0)
			expect(hub.isOpen()).toEqual(true)
			expect(screen.Enabled).toEqual(true)
			expect(page.Visible).toEqual(true)
		end
		expect(GuiFake.invalidReads).toEqual(0)
	end)
end)
