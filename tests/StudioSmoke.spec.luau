--!strict

--[[
	The Studio smoke in ops/studio-smoke. Market and Pass stay off the
	rail. Key M opens nothing. The RimShop prompt opens Shop, and the
	status line is the Gold shop. A new profile's bar is empty, so keys
	1-8 do not call UseActionSlot until slot 1 is filled.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local UiRouter = require("../src/ReplicatedStorage/Shared/UiRouter")
local GuiFake = require("./GuiFake")

local GOLD_SHOP = "Gold shop. A Healing Tonic and a bag slot."
local RAIL = { "Hero", "Bag", "Pets", "Roll", "Shop", "Settings" }

local function wardenProfile()
	local data = Schema.template()
	data.classId = "warden"
	data.classXp = { warden = 0 }
	return data
end

local function bootHub(world)
	local MenuHub = world.load("MenuHub")
	local hub = MenuHub.start(world.playerGui, {
		invoke = function()
			return { ok = true }
		end,
		onDim = function() end,
	})
	hub.setProfile(wardenProfile())
	return hub
end

local function hidden(root: any, name: string): boolean
	local node = GuiFake.findNamed(root, name)
	if node == nil then
		return true
	end
	return node.Visible == false
end

local function pressKey(world, bind: string, key: string)
	world.binds[bind](bind, world.enum.UserInputState.Begin, {
		KeyCode = world.enum.KeyCode[key],
		UserInputType = world.enum.UserInputType.Keyboard,
	})
end

local function useCalls(calls: { any }): { any }
	local list = {}
	for _, call in ipairs(calls) do
		if call[1] == "UseActionSlot" then
			table.insert(list, call)
		end
	end
	return list
end

describe("Studio smoke", function()
	it("hides rail Market and rail Pass", function()
		local world = GuiFake.world()
		local HudShell = world.load("HudShell")
		HudShell.start(world.playerGui, {
			onHero = function() end,
			onBag = function() end,
			onRoll = function() end,
			onPets = function() end,
			onShop = function() end,
			onSettings = function() end,
		})
		local railGui = world.playerGui:FindFirstChild("ShardfallRail")
		local rail = GuiFake.findNamed(railGui, "Rail")
		expect(hidden(rail, "Market")).toBeTrue()
		expect(hidden(rail, "Pass")).toBeTrue()
		local names = {}
		for _, child in ipairs(rail:GetChildren()) do
			if child:IsA("TextButton") then
				table.insert(names, child.Name)
				expect(child.Visible).toBeTrue()
			end
		end
		expect(names).toEqual(RAIL)
	end)

	it("leaves the hub closed when key M is pressed", function()
		local world = GuiFake.world()
		bootHub(world)
		local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
		expect(screen.Enabled).toBeFalse()
		world.userInput.InputBegan:Fire({
			KeyCode = world.enum.KeyCode.M,
			UserInputType = world.enum.UserInputType.Keyboard,
		}, false)
		expect(screen.Enabled).toBeFalse()
		local header = GuiFake.findNamed(screen, "Header")
		expect(header:FindFirstChild("Title").Text == "Market").toBeFalse()
	end)

	it("opens Shop from the RimShop prompt, titled Gold shop", function()
		expect(UiRouter.havenTab("market")).toEqual("shop")
		local world = GuiFake.world()
		local hub = bootHub(world)
		local tab = UiRouter.havenTab("market")
		expect(tab).toEqual("shop")
		hub.open(tab :: string)
		local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
		expect(screen.Enabled).toBeTrue()
		local header = GuiFake.findNamed(screen, "Header")
		expect(header:FindFirstChild("Title").Text).toEqual("Shop")
		local tabs = GuiFake.findNamed(screen, "Tabs")
		expect(tabs:FindFirstChild("market").Visible).toBeFalse()
		local client = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local marker = 'if kind == "market" then'
		local at = string.find(client, marker, 1, true)
		expect(at ~= nil).toBeTrue()
		local window = string.sub(client, at :: number, (at :: number) + 180)
		expect(string.find(window, GOLD_SHOP, 1, true) ~= nil).toBeTrue()
	end)

	it("fills an empty starter slot before key 1 uses it", function()
		local fresh = Schema.template()
		expect(fresh.classId).toEqual("")
		expect(ActionSlots.barFor(fresh.actionBars, "").slots[1].kind).toEqual("empty")

		local world = GuiFake.world()
		local ActionBar = world.load("ActionBar")
		local calls = {}
		local menuOpen = false
		local bar = ActionBar.start(world.playerGui, {
			invoke = function(name: string, ...)
				table.insert(calls, { name, ... })
				return { ok = false, error = "Skills are for a crawl." }
			end,
			menuOpen = function()
				return menuOpen
			end,
			onDodge = function() end,
			onLight = function() end,
			onHeavy = function() end,
			onSkill = function() end,
			onToast = function() end,
			onResult = function() end,
			onRoll = function() end,
			mobile = function()
				return false
			end,
		})
		bar.setProfile(fresh)
		for _, key in ipairs(ActionSlots.KEYS) do
			pressKey(world, "ShardfallActionBar", key)
		end
		expect(#useCalls(calls)).toEqual(0)

		local picked = Schema.template()
		picked.classId = "warden"
		expect(ActionSlots.barFor(picked.actionBars, "warden").slots[1].kind).toEqual("skill")
		bar.setProfile(picked)
		menuOpen = true
		pressKey(world, "ShardfallActionBar", "One")
		expect(#useCalls(calls)).toEqual(0)
		menuOpen = false
		pressKey(world, "ShardfallActionBar", "One")
		local used = useCalls(calls)
		expect(#used).toEqual(1)
		expect(used[1][2]).toEqual(1)
	end)
end)
