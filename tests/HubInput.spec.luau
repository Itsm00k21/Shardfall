--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local HubPress = require("../src/ReplicatedStorage/Shared/HubPress")
local HubStyle = require("../src/ReplicatedStorage/Shared/HubStyle")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
local RollBatch = require("../src/ReplicatedStorage/Shared/RollBatch")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")
local GuiFake = require("./GuiFake")

local function rgb(name: string): { number }
	return UiTheme.RGB[name]
end

local function sameColor(color: any, name: string): boolean
	local row = rgb(name)
	return type(color) == "table" and color.R == row[1] and color.G == row[2] and color.B == row[3]
end

local function profile()
	local settings = Settings.default()
	return {
		level = 20,
		xp = 0,
		classId = "warden",
		classXp = { warden = 1800 },
		shardTokens = 0,
		gold = 0,
		shardRolls = 0,
		inventory = {
			sword = {
				uid = "sword",
				name = "Practice Blade",
				rarity = "Common",
				kind = "Weapon",
			},
		},
		pets = {},
		equipped = {},
		consumables = { [Materials.TONIC_ID] = 1 },
		actionBars = ActionSlots.fresh(),
		uiSettings = settings,
	}
end

local function hooks(calls: { any })
	return {
		invoke = function(name: string, ...: any)
			table.insert(calls, { name, ... })
			if name == "RollShard" or name == "RollShards" then
				return { ok = false, error = "stub" }
			end
			return { ok = true }
		end,
		onBag = function()
			table.insert(calls, { "onBag" })
		end,
		onMarket = function()
			table.insert(calls, { "onMarket" })
		end,
		onDim = function() end,
	}
end

local function bootHub()
	local world = GuiFake.world()
	local MenuHub = world.load("MenuHub")
	local calls = {}
	local hub = MenuHub.start(world.playerGui, hooks(calls))
	hub.setProfile(profile())
	return world, hub, calls
end

local function screenOf(world): any
	return GuiFake.findNamed(world.playerGui, "ShardfallHub")
end

local function labelText(root: any, name: string): string
	local node = GuiFake.findNamed(root, name)
	if node == nil then
		return ""
	end
	return tostring(node.Text)
end

local function hasText(root: any, text: string): boolean
	for _, child in ipairs(root:GetDescendants()) do
		if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text == text then
			return true
		end
	end
	return false
end

local function tabButton(screen: any, id: string): any
	local tabs = GuiFake.findNamed(screen, "Tabs")
	return tabs:FindFirstChild(id, false)
end

local function rolled(calls: { any }): { any }
	local list = {}
	for _, call in ipairs(calls) do
		if call[1] == "RollShard" or call[1] == "RollShards" then
			table.insert(list, call)
		end
	end
	return list
end

describe("HubInput", function()
	it("gives every open-tab button a click handler and no invisible cover", function()
		local world, hub = bootHub()
		local screen = screenOf(world)
		local tabs = { "hero", "bag", "pets", "roll", "shop", "settings" }
		for _, tab in ipairs(tabs) do
			hub.open(tab)
			expect(HubPress.blocker(GuiFake.covers(screen))).toEqual(nil)
			local dead = {}
			for _, button in ipairs(GuiFake.buttons(screen)) do
				local activated = GuiFake.connections(button, "Activated")
				local click = GuiFake.connections(button, "MouseButton1Click")
				local began = GuiFake.connections(button, "InputBegan")
				if activated + click + began < 1 then
					table.insert(dead, tostring(button.Name) .. ":" .. tostring(button.Text))
				end
			end
			expect(dead).toEqual({})
		end
	end)

	it("keeps each bag card's equip and lock inside the card", function()
		local world, hub = bootHub()
		hub.open("bag")
		local screen = screenOf(world)
		expect(HubPress.blocker(GuiFake.covers(screen))).toEqual(nil)
		local bag = GuiFake.findNamed(screen, "Body"):FindFirstChild("bag", false)
		local actions = bag:FindFirstChild("Actions", true)
		expect(actions ~= nil).toBeTrue()
		expect(actions.BackgroundTransparency < 1).toBeTrue()
		local card = bag:FindFirstChild("Card", true)
		expect(card ~= nil).toBeTrue()
		expect(card.ClipsDescendants).toBeTrue()
		expect(card:FindFirstChild("Equip", false) ~= nil).toBeTrue()
		expect(card:FindFirstChild("Lock", false) ~= nil).toBeTrue()
		local named = false
		local icon = false
		for _, child in ipairs(card:GetChildren()) do
			if child:IsA("TextLabel") and child.Text == "Practice Blade" then
				named = true
			end
			if child:IsA("ImageLabel") then
				icon = true
			end
		end
		expect(named).toBeTrue()
		expect(icon).toBeTrue()
		local layout = bag:FindFirstChild("Cards", true):FindFirstChildOfClass("UIGridLayout")
		expect(layout.CellSize.Y.Offset >= 188).toBeTrue()
		expect(labelText(screen, "Capacity")).toEqual("Capacity: 1/100")
		expect(GuiFake.findNamed(screen, "EquipBest") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "Worn") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "Weapons"):FindFirstChild("Icon") ~= nil).toBeTrue()
	end)

	it("keeps each roll control on its own action", function()
		local world, hub, calls = bootHub()
		hub.open("roll")
		local screen = screenOf(world)
		local info = GuiFake.findNamed(screen, "Info")
		GuiFake.activate(info)
		expect(hasText(screen, "Luck  0")).toBeTrue()
		expect(sameColor(GuiFake.findNamed(screen, "GearShards").BackgroundColor3, "header")).toBeTrue()
		expect(sameColor(GuiFake.findNamed(screen, "Info").BackgroundColor3, "button")).toBeTrue()
		local before = #rolled(calls)
		GuiFake.activate(GuiFake.findNamed(screen, "TimesTen"))
		expect(#rolled(calls)).toEqual(before)
		expect(labelText(screen, "Milestone")).toEqual(RollBatch.NEED)
		expect(hasText(screen, "Luck  0")).toBeTrue()
		expect(sameColor(GuiFake.findNamed(screen, "GearShards").BackgroundColor3, "header")).toBeTrue()
		GuiFake.activate(GuiFake.findNamed(screen, "Quick"))
		expect(labelText(screen, "Quick")).toEqual("Quick On")
		expect(hasText(screen, "Luck  0")).toBeTrue()
		expect(#rolled(calls)).toEqual(before)
		GuiFake.activate(GuiFake.findNamed(screen, "Stop"))
		expect(string.find(labelText(screen, "Stop"), "Uncommon", 1, true) ~= nil).toBeTrue()
		expect(#rolled(calls)).toEqual(before)
		GuiFake.activate(GuiFake.findNamed(screen, "JunkMode"))
		expect(labelText(screen, "JunkMode")).toEqual("Junk  keep")
		GuiFake.activate(GuiFake.findNamed(screen, "JunkBelow"))
		expect(labelText(screen, "JunkBelow")).toEqual("Below  Epic")
		expect(hasText(screen, "Luck  0")).toBeTrue()
		GuiFake.activate(GuiFake.findNamed(screen, "PetShards"))
		expect(hasText(screen, "Luck  0")).toBeFalse()
		expect(sameColor(GuiFake.findNamed(screen, "PetShards").BackgroundColor3, "button")).toBeTrue()
		expect(sameColor(GuiFake.findNamed(screen, "GearShards").BackgroundColor3, "header")).toBeTrue()
		expect(#rolled(calls)).toEqual(before)
		GuiFake.activate(GuiFake.findNamed(screen, "GearShards"))
		expect(sameColor(GuiFake.findNamed(screen, "GearShards").BackgroundColor3, "button")).toBeTrue()
		expect(sameColor(GuiFake.findNamed(screen, "PetShards").BackgroundColor3, "header")).toBeTrue()
		GuiFake.activate(GuiFake.findNamed(screen, "Auto"))
		expect(labelText(screen, "Auto")).toEqual("Auto On")
		local rolls = rolled(calls)
		expect(#rolls).toEqual(before + 1)
		expect(rolls[#rolls][1]).toEqual("RollShard")
	end)

	it("switches hub tabs without cracking a shard", function()
		local world, hub, calls = bootHub()
		hub.open("hero")
		local screen = screenOf(world)
		local before = #rolled(calls)
		local titles = {
			bag = "Bag",
			pets = "Pets",
			roll = "Roll",
			shop = "Shop",
			settings = "Settings",
			hero = "Hero",
		}
		for _, tab in ipairs({ "bag", "pets", "roll", "shop", "settings", "hero" }) do
			GuiFake.activate(tabButton(screen, tab))
			expect(#rolled(calls)).toEqual(before)
			expect(labelText(screen, "Title")).toEqual(titles[tab])
		end
		expect(tabButton(screen, "raids").Visible).toBeFalse()
		expect(tabButton(screen, "market").Visible).toBeFalse()
		expect(tabButton(screen, "pass").Visible).toBeFalse()
		GuiFake.activate(tabButton(screen, "shop"))
		expect(hasText(screen, "  Healing Tonic  40 Gold")).toBeTrue()
		expect(hasText(screen, "  Bag slot  250 Gold")).toBeTrue()
		expect(hasText(screen, "  Pet slot  400 Gold")).toBeFalse()
		expect(hasText(screen, "Robux")).toBeFalse()
	end)

	it("fires action slots, Lock, T, and the key binds as themselves", function()
		local world = GuiFake.world()
		local ActionBar = world.load("ActionBar")
		local calls = {}
		local toasts = {}
		local rolledOpen = 0
		local dodges = 0
		local lights = 0
		local bar = ActionBar.start(world.playerGui, {
			invoke = function(name: string, ...)
				table.insert(calls, { name, ... })
				return { ok = true }
			end,
			menuOpen = function()
				return false
			end,
			onDodge = function()
				dodges += 1
			end,
			onLight = function()
				lights += 1
			end,
			onHeavy = function() end,
			onSkill = function() end,
			onToast = function(text: string)
				table.insert(toasts, text)
			end,
			onResult = function() end,
			onRoll = function()
				rolledOpen += 1
			end,
			mobile = function()
				return false
			end,
		})
		bar.setProfile(profile())
		local screen = GuiFake.findNamed(world.playerGui, "ShardfallActions")
		expect(screen ~= nil).toBeTrue()
		for index = 1, 8 do
			local button = GuiFake.findNamed(screen, "Slot" .. tostring(index))
			expect(button ~= nil).toBeTrue()
			expect(GuiFake.connections(button, "InputBegan") > 0).toBeTrue()
			button.AbsolutePosition = world.vector2((index - 1) * 50, 200)
			button.AbsoluteSize = world.vector2(44, 44)
			local before = #calls
			GuiFake.pointerClick(button, world.userInput)
			if index <= 6 then
				expect(#calls).toEqual(before + 1)
				expect(calls[#calls][1]).toEqual("UseActionSlot")
				expect(calls[#calls][2]).toEqual(index)
			else
				expect(#calls).toEqual(before)
			end
		end
		local lock = GuiFake.findNamed(screen, "Lock")
		local beforeLock = #calls
		GuiFake.activate(lock)
		expect(calls[#calls][1]).toEqual("SetActionBar")
		expect(#calls).toEqual(beforeLock + 1)
		local rollKey = GuiFake.findNamed(screen, "RollKey")
		expect(rollKey.Text).toEqual("T")
		GuiFake.activate(rollKey)
		expect(rolledOpen).toEqual(1)
		local dodgeBefore = dodges
		world.binds.ShardfallDodge("ShardfallDodge", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.LeftShift,
			UserInputType = world.enum.UserInputType.Keyboard,
		})
		expect(dodges).toEqual(dodgeBefore + 1)
		local useBefore = #calls
		world.binds.ShardfallActionBar("ShardfallActionBar", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.One,
			UserInputType = world.enum.UserInputType.Keyboard,
		})
		expect(calls[#calls][1]).toEqual("UseActionSlot")
		expect(calls[#calls][2]).toEqual(1)
		expect(#calls).toEqual(useBefore + 1)
		world.binds.ShardfallActionBar("ShardfallActionBar", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.Eight,
			UserInputType = world.enum.UserInputType.Keyboard,
		})
		expect(#calls).toEqual(useBefore + 1)
		if world.binds.ShardfallLight ~= nil then
			local lightBefore = lights
			world.binds.ShardfallLight("ShardfallLight", world.enum.UserInputState.Begin, {
				KeyCode = world.enum.KeyCode.ButtonR1,
				UserInputType = world.enum.UserInputType.Gamepad1,
			})
			expect(lights).toEqual(lightBefore + 1)
		end
	end)

	it("keeps on-screen combat quiet while the hub is open", function()
		local world = GuiFake.world()
		local ActionBar = world.load("ActionBar")
		local calls = {}
		local open = true
		local dodges = 0
		local lights = 0
		local heavies = 0
		local bar = ActionBar.start(world.playerGui, {
			invoke = function(name: string, ...)
				table.insert(calls, { name, ... })
				return { ok = true }
			end,
			menuOpen = function()
				return open
			end,
			onDodge = function()
				dodges += 1
			end,
			onLight = function()
				lights += 1
			end,
			onHeavy = function()
				heavies += 1
			end,
			onSkill = function() end,
			onToast = function() end,
			onResult = function() end,
			onRoll = function() end,
			mobile = function()
				return true
			end,
		})
		bar.setProfile(profile())
		local screen = GuiFake.findNamed(world.playerGui, "ShardfallActions")
		local slot = GuiFake.findNamed(screen, "Slot1")
		slot.AbsolutePosition = world.vector2(0, 200)
		slot.AbsoluteSize = world.vector2(44, 44)
		GuiFake.pointerClick(slot, world.userInput)
		GuiFake.activate(GuiFake.findNamed(screen, "Heavy"))
		GuiFake.activate(GuiFake.findNamed(screen, "Swing"))
		GuiFake.activate(GuiFake.findNamed(screen, "Dodge"))
		expect(#calls).toEqual(0)
		expect(dodges).toEqual(0)
		expect(lights).toEqual(0)
		expect(heavies).toEqual(0)
		open = false
		GuiFake.pointerClick(slot, world.userInput)
		expect(calls[#calls][1]).toEqual("UseActionSlot")
		expect(calls[#calls][2]).toEqual(1)
		GuiFake.activate(GuiFake.findNamed(screen, "Heavy"))
		GuiFake.activate(GuiFake.findNamed(screen, "Swing"))
		GuiFake.activate(GuiFake.findNamed(screen, "Dodge"))
		expect(heavies).toEqual(1)
		expect(lights).toEqual(1)
		expect(dodges).toEqual(1)
	end)

	it("paints the roll, bag, and pets mockup structure", function()
		local world, hub, calls = bootHub()
		hub.open("roll")
		local screen = screenOf(world)
		expect(GuiFake.findNamed(screen, "Pedestal") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "OddsBars") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "CrackRow") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "ShardCount") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "EpicBar") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "LegendaryBar") ~= nil).toBeTrue()
		expect(labelText(screen, "Roll")).toEqual("Earn shards")
		expect(labelText(screen, "TimesTen")).toEqual(HubStyle.CRACK_TEN)
		expect(labelText(screen, "ShardCount")).toEqual(HubStyle.shardCount(0))
		for _, button in ipairs(GuiFake.buttons(screen)) do
			expect(string.find(tostring(button.Text), "x100", 1, true)).toBeNil()
		end
		local before = #rolled(calls)
		GuiFake.activate(GuiFake.findNamed(screen, "Auto"))
		expect(labelText(screen, "Auto")).toEqual("Auto On")
		expect(#rolled(calls)).toEqual(before + 1)
		hub.open("bag")
		screen = screenOf(world)
		expect(GuiFake.findNamed(screen, "Pills") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "Slot1") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "Slot8") ~= nil).toBeTrue()
		GuiFake.activate(GuiFake.findNamed(screen, "Card"))
		local upgrade = false
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and string.find(child.Text, "UPGRADE", 1, true) ~= nil then
				upgrade = true
			end
		end
		expect(upgrade).toBeTrue()
		hub.open("pets")
		screen = screenOf(world)
		expect(GuiFake.findNamed(screen, "PetList") ~= nil).toBeTrue()
		expect(GuiFake.findNamed(screen, "PetDetail") ~= nil).toBeTrue()
		local crackRow = false
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and string.find(child.Text, "Crack a Pet Shard", 1, true) ~= nil then
				crackRow = true
			end
		end
		expect(crackRow).toBeTrue()
	end)

	it("cracks one shard when a tap begins, ends, and activates", function()
		local world, hub, calls = bootHub()
		local data = profile()
		data.shardTokens = 4
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		local button = GuiFake.findNamed(screen, "Roll")
		local before = #rolled(calls)
		local input = {
			UserInputType = world.enum.UserInputType.MouseButton1,
			KeyCode = world.enum.KeyCode.Unknown,
		}
		button.InputBegan:Fire(input)
		button.InputEnded:Fire(input)
		GuiFake.emit(button, "Activated")
		local rolls = rolled(calls)
		expect(#rolls).toEqual(before + 1)
		expect(rolls[#rolls][1]).toEqual("RollShard")
	end)

	it("cracks once from Activated alone", function()
		local world, hub, calls = bootHub()
		local data = profile()
		data.shardTokens = 2
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		local button = GuiFake.findNamed(screen, "Roll")
		local before = #rolled(calls)
		GuiFake.emit(button, "Activated")
		local rolls = rolled(calls)
		expect(#rolls).toEqual(before + 1)
		expect(rolls[#rolls][1]).toEqual("RollShard")
	end)

	it("cracks again after a drag leaves the pointer flag set", function()
		local world, hub, calls = bootHub()
		local data = profile()
		data.shardTokens = 4
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		local button = GuiFake.findNamed(screen, "Roll")
		local pointer = {
			UserInputType = world.enum.UserInputType.MouseButton1,
			KeyCode = world.enum.KeyCode.Unknown,
		}
		button.InputBegan:Fire(pointer)
		button.InputEnded:Fire(pointer)
		local key = {
			UserInputType = world.enum.UserInputType.Keyboard,
			KeyCode = world.enum.KeyCode.Return,
		}
		button.InputBegan:Fire(key)
		GuiFake.emit(button, "Activated")
		local rolls = rolled(calls)
		expect(#rolls).toEqual(2)
		expect(rolls[1][1]).toEqual("RollShard")
		expect(rolls[2][1]).toEqual("RollShard")
	end)

	it("cracks again when a pointer press never activates", function()
		local world, hub, calls = bootHub()
		local data = profile()
		data.shardTokens = 4
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		local button = GuiFake.findNamed(screen, "Roll")
		local pointer = {
			UserInputType = world.enum.UserInputType.MouseButton1,
			KeyCode = world.enum.KeyCode.Unknown,
		}
		button.InputBegan:Fire(pointer)
		button.InputEnded:Fire(pointer)
		require("@lune/task").wait(0.9)
		GuiFake.emit(button, "Activated")
		local rolls = rolled(calls)
		expect(#rolls).toEqual(2)
		expect(rolls[1][1]).toEqual("RollShard")
		expect(rolls[2][1]).toEqual("RollShard")
	end)

	it("shows a shop refusal and repaints the Gold line", function()
		local world = GuiFake.world()
		local MenuHub = world.load("MenuHub")
		local calls = {}
		local hub = MenuHub.start(world.playerGui, {
			invoke = function(name: string, offerId: any)
				table.insert(calls, { name, offerId })
				if name == "BuyGoldShop" and offerId == "bag" then
					return { ok = false, error = "You need more Gold." }
				end
				if name == "BuyGoldShop" and offerId == "tonic" then
					return {
						ok = true,
						profile = {
							gold = 0,
							shardTokens = 0,
							inventory = {},
							pets = {},
							equipped = {},
						},
					}
				end
				return { ok = true }
			end,
			onBag = function() end,
			onMarket = function() end,
			onDim = function() end,
			onToast = function(message: string)
				table.insert(calls, { "toast", message })
			end,
		})
		local data = profile()
		data.gold = 40
		hub.setProfile(data)
		hub.open("shop")
		local screen = screenOf(world)
		local broke = nil
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and child.Text == "  Bag slot  250 Gold" then
				broke = child
			end
		end
		expect(broke ~= nil).toBeTrue()
		GuiFake.activate(broke)
		expect(hasText(screen, "You need more Gold.")).toBeTrue()
		expect(hasText(screen, "Gold  40")).toBeTrue()
		expect(calls[#calls][1]).toEqual("toast")
		expect(calls[#calls][2]).toEqual("You need more Gold.")
		local tonic = nil
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and child.Text == "  Healing Tonic  40 Gold" then
				tonic = child
			end
		end
		expect(tonic ~= nil).toBeTrue()
		GuiFake.activate(tonic)
		expect(hasText(screen, "Gold  0")).toBeTrue()
		expect(hasText(screen, "You need more Gold.")).toBeFalse()
		expect(hasText(screen, "  Healing Tonic  40 Gold")).toBeTrue()
	end)

	it("toasts a fixed sentence when a shop buy throws", function()
		local world = GuiFake.world()
		local MenuHub = world.load("MenuHub")
		local toasts = {}
		local hub = MenuHub.start(world.playerGui, {
			invoke = function(name: string)
				if name == "BuyGoldShop" then
					error("raw boom from BuyGoldShop")
				end
				return { ok = true }
			end,
			onBag = function() end,
			onMarket = function() end,
			onDim = function() end,
			onToast = function(message: string)
				table.insert(toasts, message)
			end,
		})
		hub.setProfile(profile())
		hub.open("shop")
		local screen = screenOf(world)
		local bag = nil
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and child.Text == "  Bag slot  250 Gold" then
				bag = child
			end
		end
		expect(bag ~= nil).toBeTrue()
		GuiFake.activate(bag)
		expect(toasts[#toasts]).toEqual("Could not buy that.")
		expect(hasText(screen, "Could not buy that.")).toBeTrue()
		expect(hasText(screen, "raw boom from BuyGoldShop")).toBeFalse()
	end)

	it("says why a crack with no shards does nothing", function()
		local world, hub, calls = bootHub()
		hub.open("roll")
		local screen = screenOf(world)
		local before = #rolled(calls)
		GuiFake.activate(GuiFake.findNamed(screen, "Roll"))
		expect(#rolled(calls)).toEqual(before)
		expect(hasText(screen, "You need a Shard Token to crack a shard.")).toBeTrue()
		expect(labelText(screen, "Milestone")).toEqual("You need a Shard Token to crack a shard.")
	end)

	it("opens the Gold shop from the shop tab and keeps pets off the bag", function()
		local world, hub = bootHub()
		hub.open("shop")
		local screen = screenOf(world)
		expect(labelText(screen, "Title")).toEqual("Shop")
		local body = GuiFake.findNamed(screen, "Body")
		expect(body:FindFirstChild("shop").Visible).toBeTrue()
		expect(body:FindFirstChild("market").Visible).toBeFalse()
		expect(body:FindFirstChild("pass").Visible).toBeFalse()
		hub.open("pets")
		screen = screenOf(world)
		expect(body:FindFirstChild("pets").Visible).toBeTrue()
		expect(body:FindFirstChild("bag").Visible).toBeFalse()
		expect(body:FindFirstChild("roll").Visible).toBeFalse()
		expect(hasText(screen, "Crack a Fire Shard")).toBeFalse()
		local function shownText(text: string): boolean
			for _, child in ipairs(screen:GetDescendants()) do
				if not (child:IsA("TextLabel") or child:IsA("TextButton")) then
					continue
				end
				if string.find(child.Text, text, 1, true) == nil then
					continue
				end
				local node = child
				local visible = true
				while node ~= nil do
					if node:IsA("GuiObject") and node.Visible == false then
						visible = false
						break
					end
					if node:IsA("LayerCollector") and node.Enabled == false then
						visible = false
						break
					end
					node = node.Parent
				end
				if visible then
					return true
				end
			end
			return false
		end
		expect(shownText("Practice Blade")).toBeFalse()
		expect(shownText("Salvage  Common")).toBeFalse()
		expect(shownText("Crack a Pet Shard")).toBeTrue()
	end)

	it("keeps Equip and Lock inside the bag card", function()
		local world, hub = bootHub()
		hub.open("bag")
		local screen = screenOf(world)
		local card = GuiFake.findNamed(screen, "Card")
		local equip = card:FindFirstChild("Equip")
		local lock = card:FindFirstChild("Lock")
		expect(equip ~= nil and equip.Parent == card).toBeTrue()
		expect(lock ~= nil and lock.Parent == card).toBeTrue()
		local function box(node)
			local pos = node.AbsolutePosition
			local size = node.AbsoluteSize
			return pos.X, pos.Y, size.X, size.Y
		end
		local ex, ey, ew, eh = box(equip)
		local lx, ly, lw, lh = box(lock)
		local overlaps = ex < lx + lw and lx < ex + ew and ey < ly + lh and ly < ey + eh
		expect(overlaps).toEqual(false)
		local styled = false
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and string.find(child.Text, "Open full bag", 1, true) ~= nil then
				expect(child:FindFirstChildOfClass("UICorner") ~= nil).toBeTrue()
				styled = true
			end
		end
		expect(styled).toBeTrue()
		for _, tab in ipairs({ "hero", "bag", "pets", "roll", "shop" }) do
			hub.open(tab)
			expect(labelText(screenOf(world), "Title") ~= "").toBeTrue()
			local page = GuiFake.findNamed(screenOf(world), "Body"):FindFirstChild(tab)
			expect(page.Visible).toBeTrue()
		end
	end)

	it("moves PadRing after a gamepad step and runs the focused button", function()
		local world, hub = bootHub()
		local ActionBar = world.load("ActionBar")
		local slots = {}
		local dodges = 0
		local lights = 0
		local heavies = 0
		local bar = ActionBar.start(world.playerGui, {
			invoke = function(name: string, ...)
				table.insert(slots, { name, ... })
				return { ok = true }
			end,
			menuOpen = function()
				return hub.isOpen()
			end,
			onDodge = function()
				dodges += 1
			end,
			onLight = function()
				lights += 1
			end,
			onHeavy = function()
				heavies += 1
			end,
			onSkill = function() end,
			onToast = function() end,
			onResult = function() end,
			onRoll = function() end,
			mobile = function()
				return false
			end,
		})
		bar.setProfile(profile())
		local function press(key: string, processed: boolean?)
			world.userInput.InputBegan:Fire({
				KeyCode = world.enum.KeyCode[key],
				UserInputType = world.enum.UserInputType.Gamepad1,
				Position = { X = 0, Y = 0, Z = 0 },
			}, processed == true)
		end
		local function stick(x: number, y: number)
			world.userInput.InputChanged:Fire({
				KeyCode = world.enum.KeyCode.Thumbstick1,
				UserInputType = world.enum.UserInputType.Gamepad1,
				Position = vector.create(x, y, 0),
			}, false)
		end
		local function place(button: any, x: number, y: number)
			button.AbsolutePosition = world.vector2(x, y)
			button.AbsoluteSize = world.vector2(40, 36)
		end
		hub.open("roll")
		local screen = screenOf(world)
		expect(labelText(screen, "Title")).toEqual("Roll")
		expect(GuiFake.findNamed(screen, "Tabs").Visible).toEqual(false)
		expect(GuiFake.findNamed(screen, "PadRing").Parent.Name).toEqual("Close")
		expect(GuiFake.findNamed(screen, "PadRing").Parent.Parent.Name).toEqual("Header")
		expect(tabButton(screen, "raids").Visible).toEqual(false)
		expect(tabButton(screen, "market").Visible).toEqual(false)
		expect(tabButton(screen, "pass").Visible).toEqual(false)
		local stacked = 0
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("GuiButton") and child.Visible ~= false then
				place(child, 0, stacked * 48)
				stacked += 1
			end
		end
		local crack = GuiFake.findNamed(screen, "Roll")
		place(GuiFake.findNamed(screen, "PadRing").Parent, 0, 0)
		place(crack, 360, 0)
		press("DPadRight", true)
		local ring = GuiFake.findNamed(screen, "PadRing")
		expect(ring ~= nil).toBeTrue()
		expect(ring:IsA("UIStroke")).toBeTrue()
		expect(ring:IsA("GuiObject")).toEqual(false)
		expect(ring.Thickness).toEqual(4)
		expect(ring.Color.R).toEqual(244)
		expect(ring.Color.G).toEqual(240)
		expect(ring.Color.B).toEqual(252)
		expect(ring.BorderStrokePosition).toEqual(world.enum.BorderStrokePosition.Inner)
		expect(ring.Enabled).toEqual(true)
		expect(ring.Parent).toEqual(crack)
		hub.close()
		expect(GuiFake.findNamed(screen, "PadRing")).toBeNil()
		hub.open("roll")
		screen = screenOf(world)
		expect(GuiFake.findNamed(screen, "PadRing").Parent.Name).toEqual("Close")
		press("ButtonR1")
		expect(labelText(screen, "Title")).toEqual("Shop")
		local banned = { raids = true, market = true, pass = true }
		for _ = 1, 40 do
			press("DPadDown")
			local parent = ring.Parent
			expect(parent ~= nil and banned[parent.Name] ~= true).toBeTrue()
		end
		world.userInput.InputBegan:Fire({
			KeyCode = world.enum.KeyCode.Unknown,
			UserInputType = world.enum.UserInputType.MouseButton1,
			Position = { X = 0, Y = 0, Z = 0 },
		}, false)
		expect(ring.Parent).toBeNil()
		expect(GuiFake.findNamed(screen, "PadRing")).toBeNil()
		press("DPadDown")
		expect(ring.Parent ~= nil).toBeTrue()
		world.userInput.InputBegan:Fire({
			KeyCode = world.enum.KeyCode.F13,
			UserInputType = world.enum.UserInputType.Keyboard,
		}, false)
		expect(ring.Parent).toBeNil()
		hub.close()
		hub.open("hero")
		screen = screenOf(world)
		expect(GuiFake.findNamed(screen, "PadRing").Parent.Name).toEqual("Close")
		stick(0.1, 0.2)
		expect(GuiFake.findNamed(screen, "PadRing").Parent.Name).toEqual("Close")
		stick(0, -0.8)
		ring = GuiFake.findNamed(screen, "PadRing")
		expect(ring.Parent.Name ~= "Close").toBeTrue()
		local stepped = ring.Parent
		stick(0, -0.9)
		expect(ring.Parent).toEqual(stepped)
		stick(0, 0)
		stick(0, -0.8)
		expect(ring.Parent ~= stepped).toBeTrue()
		press("ButtonB")
		expect(hub.isOpen()).toEqual(false)
		expect(GuiFake.findNamed(screen, "PadRing")).toBeNil()
		expect(world.binds.ShardfallMenuSink).toBeNil()
		press("ButtonA")
		expect(hub.isOpen()).toEqual(false)
		local before = #slots
		world.binds.ShardfallActionBarPad("ShardfallActionBarPad", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.DPadUp,
			UserInputType = world.enum.UserInputType.Gamepad1,
		})
		expect(#slots).toEqual(before + 1)
		expect(slots[#slots][1]).toEqual("UseActionSlot")
		expect(slots[#slots][2]).toEqual(1)
		world.binds.ShardfallLight("ShardfallLight", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.ButtonR1,
			UserInputType = world.enum.UserInputType.Gamepad1,
		})
		expect(lights).toEqual(1)
		world.binds.ShardfallDodge("ShardfallDodge", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.ButtonY,
			UserInputType = world.enum.UserInputType.Gamepad1,
		})
		expect(dodges).toEqual(1)
		local actionScreen = GuiFake.findNamed(world.playerGui, "ShardfallActions")
		GuiFake.activate(GuiFake.findNamed(actionScreen, "Heavy"))
		expect(heavies).toEqual(1)
		press("ButtonX")
		expect(hub.isOpen()).toEqual(false)
		expect(heavies).toEqual(1)
		local combat = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau")
		local heavyAt = string.find(combat, "Keybinds.GAMEPAD.heavy", 1, true)
		expect(heavyAt ~= nil).toBeTrue()
		local swingAt = string.find(combat, "CombatHud.swing(true)", heavyAt :: number, true)
		expect(swingAt ~= nil).toBeTrue()
		hub.open("roll")
		expect(world.binds.ShardfallMenuSink ~= nil).toBeTrue()
		local openBefore = #slots
		world.binds.ShardfallActionBarPad("ShardfallActionBarPad", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.DPadDown,
			UserInputType = world.enum.UserInputType.Gamepad1,
		})
		expect(#slots).toEqual(openBefore)
		expect(GuiFake.findNamed(screenOf(world), "PadRing").Parent.Name).toEqual("Close")
		press("DPadDown")
		local openRing = GuiFake.findNamed(screenOf(world), "PadRing")
		expect(openRing.Parent.Name ~= "Close").toBeTrue()
		local quick = nil
		for _ = 1, 48 do
			press("DPadDown")
			if openRing.Parent ~= nil and openRing.Parent.Name == "Quick" then
				quick = openRing.Parent
				break
			end
		end
		expect(quick ~= nil).toBeTrue()
		press("ButtonA")
		expect(hasText(screenOf(world), "Quick On")).toBeTrue()
		hub.open("roll")
		local rollButton = nil
		openRing = GuiFake.findNamed(screenOf(world), "PadRing")
		if openRing == nil or openRing.Parent == nil or openRing.Parent.Name ~= "Roll" then
			for _ = 1, 48 do
				press("DPadDown")
				openRing = GuiFake.findNamed(screenOf(world), "PadRing")
				if openRing ~= nil and openRing.Parent ~= nil and openRing.Parent.Name == "Roll" then
					rollButton = openRing.Parent
					break
				end
			end
		else
			rollButton = openRing.Parent
		end
		expect(rollButton ~= nil).toBeTrue()
		local beforeRolls = #slots
		press("ButtonA")
		expect(hasText(screenOf(world), "You need a Shard Token to crack a shard.")).toBeTrue()
		expect(#slots).toEqual(beforeRolls)
		local firedOk = pcall(function()
			rollButton.Activated:Fire()
		end)
		expect(firedOk).toEqual(false)
		hub.open("settings")
		screen = screenOf(world)
		ring = GuiFake.findNamed(screen, "PadRing")
		for _ = 1, 12 do
			if ring.Parent ~= nil and ring.Parent.Parent ~= nil and ring.Parent.Parent.Name == "List" then
				break
			end
			press("DPadDown")
		end
		expect(ring.Parent.Parent.Name).toEqual("List")
		local list = ring.Parent.Parent
		local row = ring.Parent
		list.AbsolutePosition = world.vector2(0, 0)
		list.AbsoluteSize = world.vector2(200, 100)
		list.CanvasPosition = world.vector2(0, 0)
		row.AbsolutePosition = world.vector2(0, 400)
		row.AbsoluteSize = world.vector2(80, 40)
		press("DPadDown")
		press("DPadUp")
		expect(list.CanvasPosition.Y).toEqual(340)
	end)

	it("cracks one shard when ButtonA lands on the focused Roll button", function()
		local world, hub, calls = bootHub()
		local data = profile()
		data.shardTokens = 3
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		local ring = GuiFake.findNamed(screen, "PadRing")
		expect(ring.Parent.Name).toEqual("Close")
		expect(ring.Enabled).toEqual(true)
		local function press(key: string)
			world.userInput.InputBegan:Fire({
				KeyCode = world.enum.KeyCode[key],
				UserInputType = world.enum.UserInputType.Gamepad1,
				Position = { X = 0, Y = 0, Z = 0 },
			}, false)
		end
		local rollButton = nil
		for _ = 1, 48 do
			press("DPadDown")
			if ring.Parent ~= nil and ring.Parent.Name == "Roll" then
				rollButton = ring.Parent
				break
			end
		end
		expect(rollButton ~= nil).toBeTrue()
		expect(ring.Enabled).toEqual(true)
		expect(ring.Parent).toEqual(rollButton)
		local before = #rolled(calls)
		press("ButtonA")
		local rolls = rolled(calls)
		expect(#rolls).toEqual(before + 1)
		expect(rolls[#rolls][1]).toEqual("RollShard")
		GuiFake.emit(rollButton, "Activated")
		expect(#rolled(calls)).toEqual(before + 1)
		local firedOk = pcall(function()
			rollButton.Activated:Fire()
		end)
		expect(firedOk).toEqual(false)
		expect(#rolled(calls)).toEqual(before + 1)
	end)

	it("drops padPress and padTarget when a rebuilt list destroys its rows", function()
		local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local clearAt = string.find(source, "function hubFn.clear(host: Instance)", 1, true)
		expect(clearAt ~= nil).toBeTrue()
		local nextFn = string.find(source, "\n\tfunction hubFn.", (clearAt :: number) + 1, true)
		local body = string.sub(source, clearAt :: number, (nextFn :: number) - 1)
		local pressAt = string.find(body, "hubState.padPress[node] = nil", 1, true)
		local targetAt = string.find(body, "hubState.padTarget = nil", 1, true)
		local descendAt = string.find(body, "GetDescendants()", 1, true)
		local destroyAt = string.find(body, "child:Destroy()", 1, true)
		expect(pressAt ~= nil).toBeTrue()
		expect(targetAt ~= nil).toBeTrue()
		expect(descendAt ~= nil).toBeTrue()
		expect(destroyAt ~= nil).toBeTrue()
		expect((pressAt :: number) < (destroyAt :: number)).toBeTrue()
		expect((targetAt :: number) < (destroyAt :: number)).toBeTrue()
		expect((descendAt :: number) < (destroyAt :: number)).toBeTrue()

		local world, hub = bootHub()
		local data = profile()
		data.pets = {
			ember = {
				uid = "ember",
				name = "Ember",
				rarity = "Common",
			},
		}
		hub.setProfile(data)
		hub.open("pets")
		local screen = screenOf(world)
		local function press(key: string)
			world.userInput.InputBegan:Fire({
				KeyCode = world.enum.KeyCode[key],
				UserInputType = world.enum.UserInputType.Gamepad1,
				Position = { X = 0, Y = 0, Z = 0 },
			}, false)
		end
		local ring = GuiFake.findNamed(screen, "PadRing")
		expect(ring.Parent.Name).toEqual("Close")
		local card = nil
		for _ = 1, 48 do
			press("DPadDown")
			if ring.Parent ~= nil and ring.Parent.Name == "PetCard" then
				card = ring.Parent
				break
			end
		end
		expect(card ~= nil).toBeTrue()
		expect(ring.Parent).toEqual(card)
		hub.setProfile(data)
		expect(card.Parent).toBeNil()
		screen = screenOf(world)
		local fresh = GuiFake.findNamed(screen, "PetCard")
		expect(fresh ~= nil and fresh ~= card and fresh.Parent ~= nil).toBeTrue()
		ring = GuiFake.findNamed(screen, "PadRing")
		expect(ring.Parent ~= card).toBeTrue()
		expect(ring.Parent.Name).toEqual("Close")
	end)

	it("clears restColor and keeps PadRing when a rebuilt page drops its rows", function()
		local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local clearAt = string.find(source, "function hubFn.clear(host: Instance)", 1, true)
		expect(clearAt ~= nil).toBeTrue()
		local nextFn = string.find(source, "\n\tfunction hubFn.", (clearAt :: number) + 1, true)
		local body = string.sub(source, clearAt :: number, (nextFn :: number) - 1)
		local colorAt = string.find(body, "hubState.restColor[node] = nil", 1, true)
		local releaseAt = string.find(body, "hubFn.padUnparent()", 1, true)
		local destroyAt = string.find(body, "child:Destroy()", 1, true)
		expect(colorAt ~= nil).toBeTrue()
		expect(releaseAt ~= nil).toBeTrue()
		expect(destroyAt ~= nil).toBeTrue()
		expect((colorAt :: number) < (destroyAt :: number)).toBeTrue()
		expect((releaseAt :: number) < (destroyAt :: number)).toBeTrue()

		local world, hub = bootHub()
		local data = profile()
		hub.setProfile(data)
		hub.open("bag")
		local screen = screenOf(world)
		local function press(key: string)
			world.userInput.InputBegan:Fire({
				KeyCode = world.enum.KeyCode[key],
				UserInputType = world.enum.UserInputType.Gamepad1,
				Position = { X = 0, Y = 0, Z = 0 },
			}, false)
		end
		local function inside(root: any, node: any): boolean
			local current = node
			while current ~= nil do
				if current == root then
					return true
				end
				current = current.Parent
			end
			return false
		end
		local function ringCount(root: any): number
			local total = 0
			for _, child in ipairs(root:GetDescendants()) do
				if child.Name == "PadRing" then
					total += 1
				end
			end
			return total
		end
		local bag = GuiFake.findNamed(screen, "Body"):FindFirstChild("bag", false)
		local equip = bag:FindFirstChild("Equip", true)
		local close = GuiFake.findNamed(screen, "Header"):FindFirstChild("Close", false)
		expect(equip ~= nil).toBeTrue()
		expect(close ~= nil).toBeTrue()
		equip.BackgroundColor3 = { R = 1, G = 2, B = 3 }
		GuiFake.emit(equip, "MouseLeave")
		expect(sameColor(equip.BackgroundColor3, "header")).toBeTrue()
		close.BackgroundColor3 = { R = 1, G = 2, B = 3 }
		GuiFake.emit(close, "MouseLeave")
		expect(sameColor(close.BackgroundColor3, "close")).toBeTrue()

		local ring = GuiFake.findNamed(screen, "PadRing")
		expect(ring.Parent.Name).toEqual("Close")
		local card = nil
		for _ = 1, 48 do
			press("DPadDown")
			if ring.Parent ~= nil and inside(bag, ring.Parent) then
				card = ring.Parent
				break
			end
		end
		expect(card ~= nil).toBeTrue()
		expect(ring.Parent).toEqual(card)
		expect(ring.Enabled).toEqual(true)
		local nested = nil
		for _, child in ipairs(card:GetChildren()) do
			if child ~= ring then
				nested = child
				break
			end
		end
		expect(nested ~= nil).toBeTrue()
		local destroyed = false
		local destroy = ring.Destroy
		rawset(ring, "Destroy", function(self)
			destroyed = true
			destroy(self)
		end)
		equip.BackgroundColor3 = { R = 1, G = 2, B = 3 }
		hub.setProfile(data)
		expect(card.Parent).toBeNil()
		local cardOk = pcall(function()
			card.Parent = screen
		end)
		expect(cardOk).toEqual(false)
		expect(card.Parent).toBeNil()
		expect(nested.Parent).toBeNil()
		local nestedOk = pcall(function()
			nested.Parent = card
		end)
		expect(nestedOk).toEqual(false)
		expect(nested.Parent).toBeNil()
		expect(destroyed).toEqual(false)
		expect(GuiFake.findNamed(card, "PadRing")).toBeNil()
		GuiFake.emit(equip, "MouseLeave")
		expect(sameColor(equip.BackgroundColor3, "body")).toBeTrue()
		expect(sameColor(equip.BackgroundColor3, "header")).toEqual(false)
		screen = screenOf(world)
		close = GuiFake.findNamed(screen, "Header"):FindFirstChild("Close", false)
		close.BackgroundColor3 = { R = 1, G = 2, B = 3 }
		GuiFake.emit(close, "MouseLeave")
		expect(sameColor(close.BackgroundColor3, "close")).toBeTrue()
		local found = {}
		for _, child in ipairs(screen:GetDescendants()) do
			if child.Name == "PadRing" then
				table.insert(found, child)
			end
		end
		expect(#found).toEqual(1)
		expect(found[1]).toEqual(ring)
		expect(ring.Parent ~= nil and ring.Parent ~= card).toBeTrue()
		expect(inside(screen, ring)).toBeTrue()
		expect(ringCount(card)).toEqual(0)
		press("DPadDown")
		expect(ring.Enabled).toEqual(true)
		expect(ring.Parent ~= nil and ring.Parent ~= card).toBeTrue()
		expect(inside(screen, ring.Parent)).toBeTrue()
		expect(GuiFake.findNamed(screen, "PadRing")).toEqual(ring)
		expect(ringCount(screen)).toEqual(1)
	end)

	it("keeps the roll panel open across three cracks", function()
		local world, hub, calls = bootHub()
		local data = profile()
		data.shardTokens = 6
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		local button = GuiFake.findNamed(screen, "Roll")
		local backdrop = GuiFake.findNamed(screen, "Backdrop")
		local panel = GuiFake.findNamed(screen, "Panel")
		local pointer = {
			UserInputType = world.enum.UserInputType.MouseButton1,
			KeyCode = world.enum.KeyCode.Unknown,
		}
		for _ = 1, 3 do
			button.InputBegan:Fire(pointer)
			GuiFake.emit(backdrop, "Activated")
			button.InputEnded:Fire(pointer)
			GuiFake.emit(button, "Activated")
			expect(screen.Enabled).toEqual(true)
			expect(panel.Visible).toEqual(true)
		end
		expect(#rolled(calls)).toEqual(3)
		GuiFake.emit(backdrop, "Activated")
		expect(screen.Enabled).toEqual(false)
		expect(panel.Visible).toEqual(false)
	end)

	it("skips a reveal without spending a second shard", function()
		local world = GuiFake.world()
		local MenuHub = world.load("MenuHub")
		local calls = {}
		local landed = profile()
		landed.shardTokens = 36
		local hub = MenuHub.start(world.playerGui, {
			invoke = function(name: string, ...: any)
				table.insert(calls, { name, ... })
				if name == "RollShard" or name == "RollShards" then
					return {
						ok = true,
						item = {
							uid = "vine-1",
							name = "Vinewood Sword",
							rarity = "Rare",
							templateId = "vinewood_sword",
							kind = "Weapon",
						},
						rarity = "Rare",
						fillerSeed = 1,
						pity = { sinceEpic = 1, sinceLegendary = 1 },
						currency = "shard",
						profile = landed,
					}
				end
				return { ok = true }
			end,
			onBag = function() end,
			onMarket = function() end,
			onDim = function() end,
		})
		local data = profile()
		data.shardTokens = 37
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		local button = GuiFake.findNamed(screen, "Roll")
		local pointer = {
			UserInputType = world.enum.UserInputType.MouseButton1,
			KeyCode = world.enum.KeyCode.Unknown,
		}
		button.InputBegan:Fire(pointer)
		button.InputEnded:Fire(pointer)
		GuiFake.emit(button, "Activated")
		expect(#rolled(calls)).toEqual(1)
		expect(GuiFake.findNamed(screen, "Name").Text).toEqual("")
		expect(labelText(screen, "ShardCount")).toEqual(HubStyle.shardCount(36))
		expect(labelText(screen, "ShardTokens")).toEqual(HubStyle.shardCount(36))
		expect(button:GetAttribute("CrackLocked")).toEqual(true)
		expect(screen.Enabled).toEqual(true)
		button.InputBegan:Fire(pointer)
		button.InputEnded:Fire(pointer)
		GuiFake.emit(button, "Activated")
		expect(#rolled(calls)).toEqual(1)
		expect(GuiFake.findNamed(screen, "Name").Text).toEqual("Vinewood Sword")
		expect(screen.Enabled).toEqual(true)
		expect(GuiFake.findNamed(screen, "Panel").Visible).toEqual(true)
	end)

	it("keeps the last shard count when a snapshot omits the field", function()
		local world, hub = bootHub()
		local data = profile()
		data.shardTokens = 37
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		expect(labelText(screen, "ShardCount")).toEqual(HubStyle.shardCount(37))
		local dropped = profile()
		dropped.shardTokens = nil
		hub.setProfile(dropped)
		screen = screenOf(world)
		expect(labelText(screen, "ShardCount")).toEqual(HubStyle.shardCount(37))
		expect(labelText(screen, "ShardTokens")).toEqual(HubStyle.shardCount(37))
	end)

	it("shows how to earn shards when the wallet is empty", function()
		local world, hub, calls = bootHub()
		local data = profile()
		data.shardTokens = 0
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		local empty = GuiFake.findNamed(screen, "EmptyShards")
		expect(empty ~= nil).toBeTrue()
		expect(string.find(string.lower(empty.Text), "dungeon", 1, true) ~= nil).toBeTrue()
		expect(string.find(string.lower(empty.Text), "daily", 1, true) ~= nil).toBeTrue()
		local button = GuiFake.findNamed(screen, "Roll")
		expect(button.Text).toEqual("Earn shards")
		local before = #rolled(calls)
		local pointer = {
			UserInputType = world.enum.UserInputType.MouseButton1,
			KeyCode = world.enum.KeyCode.Unknown,
		}
		button.InputBegan:Fire(pointer)
		button.InputEnded:Fire(pointer)
		GuiFake.emit(button, "Activated")
		expect(#rolled(calls)).toEqual(before)
	end)

	it("places the pity count clear of the lock at phone and desktop widths", function()
		local world, hub = bootHub()
		local data = profile()
		data.shardTokens = 4
		hub.setProfile(data)
		local function check(width: number, height: number)
			local screen = screenOf(world)
			screen.AbsoluteSize = { X = width, Y = height }
			screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
			hub.setProfile(data)
			screen = screenOf(world)
			local progress = GuiFake.findNamed(screen, "Progress")
			expect(progress ~= nil).toBeTrue()
			local meters = 0
			for _, host in ipairs(progress:GetChildren()) do
				if host:IsA("Frame") and (host.Name == "EpicPity" or host.Name == "LegendaryPity") then
					meters += 1
					local lock = host:FindFirstChild("Lock")
					local count = host:FindFirstChild("PityCount")
					local tier = host:FindFirstChild("Tier")
					expect(lock ~= nil).toBeTrue()
					expect(count ~= nil).toBeTrue()
					expect(tier ~= nil).toBeTrue()
					expect(string.sub(count.Text, 1, 4)).toEqual("Pity")
					expect(count.Position.X.Offset >= lock.Position.X.Offset + lock.Size.X.Offset).toBeTrue()
					expect(tier.Position.X.Offset + tier.Size.X.Offset <= lock.Position.X.Offset).toBeTrue()
					expect(count.Position.X.Offset + count.Size.X.Offset <= host.Size.X.Offset).toBeTrue()
				end
			end
			expect(meters).toEqual(2)
			local odds = progress:FindFirstChild("Odds")
			expect(odds ~= nil).toBeTrue()
			local oddsText = ""
			for _, child in ipairs(odds:GetChildren()) do
				if child:IsA("TextLabel") then
					oddsText = child.Text
				end
			end
			expect(oddsText).toEqual("Odds")
		end
		check(1280, 800)
		check(390, 844)
		local screen = screenOf(world)
		local note = GuiFake.findNamed(screen, "Rounding")
		expect(note ~= nil).toBeTrue()
		expect(string.find(note.Text, "rounded", 1, true) ~= nil).toBeTrue()
	end)

	it("flips Equip before the remote returns and rolls back on a reject", function()
		local function start(mode: string): (any, any, { any }, { string })
			local world = GuiFake.world()
			local MenuHub = world.load("MenuHub")
			local calls = {}
			local seen = { "" }
			local hub = MenuHub.start(world.playerGui, {
				invoke = function(name: string, ...: any)
					table.insert(calls, { name, ... })
					if name == "EquipItem" then
						local button = GuiFake.findNamed(world.playerGui, "Equip")
						seen[1] = if button ~= nil then button.Text else ""
						if mode == "reject" then
							return { ok = false, error = "no" }
						end
						local landed = profile()
						landed.equipped = { weapon = "sword" }
						return { ok = true, profile = landed }
					end
					return { ok = true }
				end,
				onBag = function() end,
				onMarket = function() end,
				onDim = function() end,
			})
			return world, hub, calls, seen
		end
		local world, hub, calls, seen = start("ok")
		hub.setProfile(profile())
		hub.open("bag")
		local screen = screenOf(world)
		local button = GuiFake.findNamed(screen, "Equip")
		expect(button.Text).toEqual("Equip")
		GuiFake.emit(button, "Activated")
		expect(seen[1]).toEqual("Equipped")
		expect(#calls).toEqual(1)
		expect(calls[1][1]).toEqual("EquipItem")
		expect(GuiFake.findNamed(screenOf(world), "Equip").Text).toEqual("Equipped")

		local rejectedWorld, rejectedHub, rejectedCalls, rejectedSeen = start("reject")
		rejectedHub.setProfile(profile())
		rejectedHub.open("bag")
		local rejected = GuiFake.findNamed(screenOf(rejectedWorld), "Equip")
		GuiFake.emit(rejected, "Activated")
		expect(rejectedSeen[1]).toEqual("Equipped")
		expect(#rejectedCalls).toEqual(1)
		expect(GuiFake.findNamed(screenOf(rejectedWorld), "Equip").Text).toEqual("Equip")
		expect(string.find(labelText(screenOf(rejectedWorld), "Milestone"), "Could not equip", 1, true) ~= nil).toBeTrue()
	end)

	it("hides the hub tab column and gives the page that width", function()
		local world, hub = bootHub()
		hub.open("bag")
		local screen = screenOf(world)
		local tabs = GuiFake.findNamed(screen, "Tabs")
		expect(tabs.Visible).toEqual(false)
		local body = GuiFake.findNamed(screen, "Body")
		local panel = GuiFake.findNamed(screen, "Panel")
		expect(body.Position.X.Offset).toEqual(8)
		expect(body.Size.X.Offset >= panel.Size.X.Offset - 16).toBeTrue()
	end)

	it("walks skip, the starter shards, the first crack, equip, the tonic, and an upgrade", function()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local calls = {}
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function(name: string, action: string)
			table.insert(calls, { name, action })
			return { ok = true }
		end)
		OnboardHud.setProfile({
			onboardDone = false,
			onboardStep = "open",
		})
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		local skip = GuiFake.findNamed(onboard, "Skip")
		expect(skip.Text).toEqual("Skip intro")
		expect(skip.Parent.Visible).toEqual(true)
		GuiFake.activate(skip)
		expect(calls[1][1]).toEqual("Onboard")
		expect(calls[1][2]).toEqual("skip")
		OnboardHud.setProfile({
			onboardDone = true,
			onboardStep = "haven",
		})
		expect(skip.Parent.Visible).toEqual(false)

		local MenuHub = world.load("MenuHub")
		local hub = MenuHub.start(world.playerGui, {
			invoke = function(name: string, ...)
				table.insert(calls, { name, ... })
				return { ok = true }
			end,
			onBag = function() end,
			onMarket = function() end,
			onDim = function() end,
			onToast = function() end,
		})
		local data = profile()
		data.shardTokens = 10
		data.gold = 400
		hub.setProfile(data)
		hub.open("roll")
		local screen = screenOf(world)
		expect(labelText(screen, "ShardCount")).toEqual(HubStyle.shardCount(10))
		GuiFake.emit(GuiFake.findNamed(screen, "Roll"), "Activated")
		expect(calls[#calls][1]).toEqual("RollShard")

		hub.open("bag")
		screen = screenOf(world)
		GuiFake.activate(GuiFake.findNamed(screen, "Equip"))
		expect(calls[#calls][1]).toEqual("EquipItem")
		expect(calls[#calls][2]).toEqual("sword")

		hub.open("shop")
		local tonic = nil
		for _, child in ipairs(screenOf(world):GetDescendants()) do
			if child:IsA("TextButton") and child.Text == "  Healing Tonic  40 Gold" then
				tonic = child
			end
		end
		expect(tonic ~= nil).toBeTrue()
		GuiFake.activate(tonic)
		expect(calls[#calls][1]).toEqual("BuyGoldShop")
		expect(calls[#calls][2]).toEqual("tonic")

		hub.open("bag")
		screen = screenOf(world)
		GuiFake.activate(GuiFake.findNamed(screen, "Card"))
		local upgrade = nil
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and string.find(child.Text, "UPGRADE", 1, true) ~= nil then
				upgrade = child
			end
		end
		expect(upgrade ~= nil).toBeTrue()
		GuiFake.activate(upgrade)
		expect(calls[#calls][1]).toEqual("UpgradeGear")
		expect(calls[#calls][2]).toEqual("sword")
	end)

	it("drives a gamepad from Close through Roll, Bag, Forge, Pets, and the Gold shop", function()
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
		local MenuHub = world.load("MenuHub")
		local calls = {}
		local hub = MenuHub.start(world.playerGui, hooks(calls))
		local data = profile()
		data.shardTokens = 10
		data.gold = 400
		data.pets = {
			ember = {
				uid = "ember",
				name = "Ember",
				rarity = "Common",
			},
		}
		hub.setProfile(data)
		hub.open("hero")
		local screen = screenOf(world)
		expect(GuiFake.findNamed(screen, "Tabs").Visible).toEqual(false)
		local function press(key: string)
			world.userInput.InputBegan:Fire({
				KeyCode = world.enum.KeyCode[key],
				UserInputType = world.enum.UserInputType.Gamepad1,
				Position = { X = 0, Y = 0, Z = 0 },
			}, false)
		end
		local function ring(): any
			return GuiFake.findNamed(world.playerGui, "PadRing")
		end
		local banned = { raids = true, market = true, pass = true }
		local function seek(match: (any) -> boolean): any
			for _ = 1, 120 do
				local stroke = ring()
				local parent = if stroke ~= nil then stroke.Parent else nil
				if parent ~= nil then
					expect(banned[parent.Name] ~= true).toBeTrue()
					if
						parent:IsA("TextButton")
						and string.find(parent.Text, "Salvage", 1, true) ~= nil
					then
						error("PadRing landed on Salvage", 0)
					end
					if match(parent) then
						return parent
					end
				end
				press("DPadDown")
			end
			return nil
		end
		local function countOf(name: string): number
			local total = 0
			for _, call in ipairs(calls) do
				if call[1] == name then
					total += 1
				end
			end
			return total
		end
		local function onRail(label: string): (any) -> boolean
			return function(button)
				return button.Name == label
					and button.Parent ~= nil
					and button.Parent.Name == "Rail"
			end
		end
		local stroke = ring()
		expect(stroke ~= nil and stroke.Parent ~= nil and stroke.Parent.Name == "Close").toBeTrue()
		expect(stroke.Enabled).toEqual(true)
		local rollRail = seek(onRail("Roll"))
		expect(rollRail ~= nil).toBeTrue()
		expect(rollRail.Visible).toEqual(true)
		expect(rollRail.Parent.Visible).toEqual(true)
		expect(countOf("RollShard")).toEqual(0)
		press("ButtonA")
		expect(labelText(screenOf(world), "Title")).toEqual("Roll")
		expect(countOf("RollShard")).toEqual(0)
		expect(hub.isOpen()).toEqual(true)
		local crack = seek(function(button)
			return button.Name == "Roll" and button.Parent ~= nil and button.Parent.Name == "roll"
		end)
		expect(crack ~= nil).toBeTrue()
		expect(ring().Parent).toEqual(crack)
		press("ButtonA")
		expect(countOf("RollShard")).toEqual(1)
		expect(rolled(calls)[1][1]).toEqual("RollShard")
		GuiFake.emit(crack, "Activated")
		expect(countOf("RollShard")).toEqual(1)
		local firedOk = pcall(function()
			crack.Activated:Fire()
		end)
		expect(firedOk).toEqual(false)
		expect(countOf("RollShard")).toEqual(1)
		local bagRail = seek(onRail("Bag"))
		expect(bagRail ~= nil).toBeTrue()
		press("ButtonA")
		expect(labelText(screenOf(world), "Title")).toEqual("Bag")
		expect(countOf("UpgradeGear")).toEqual(0)
		local card = seek(function(button)
			return button.Name == "Card"
		end)
		expect(card ~= nil).toBeTrue()
		press("ButtonA")
		local forge = seek(function(button)
			return button:IsA("TextButton") and string.find(button.Text, "UPGRADE", 1, true) ~= nil
		end)
		expect(forge ~= nil).toBeTrue()
		expect(ring().Parent).toEqual(forge)
		press("ButtonA")
		expect(countOf("UpgradeGear")).toEqual(1)
		expect(calls[#calls][1]).toEqual("UpgradeGear")
		expect(calls[#calls][2]).toEqual("sword")
		local petsRail = seek(onRail("Pets"))
		expect(petsRail ~= nil).toBeTrue()
		press("ButtonA")
		expect(labelText(screenOf(world), "Title")).toEqual("Pets")
		local petCard = seek(function(button)
			return button.Name == "PetCard"
		end)
		expect(petCard ~= nil).toBeTrue()
		press("ButtonA")
		expect(petCard.Parent).toBeNil()
		local shopRail = seek(onRail("Shop"))
		expect(shopRail ~= nil).toBeTrue()
		press("ButtonA")
		expect(labelText(screenOf(world), "Title")).toEqual("Shop")
		expect(countOf("BuyGoldShop")).toEqual(0)
		expect(hasText(screenOf(world), "  Healing Tonic  40 Gold")).toBeTrue()
		expect(hasText(screenOf(world), "  Bag slot  250 Gold")).toBeTrue()
		local tonic = seek(function(button)
			return button:IsA("TextButton") and button.Text == "  Healing Tonic  40 Gold"
		end)
		expect(tonic ~= nil).toBeTrue()
		press("ButtonA")
		local slot = seek(function(button)
			return button:IsA("TextButton") and button.Text == "  Bag slot  250 Gold"
		end)
		expect(slot ~= nil).toBeTrue()
		press("ButtonA")
		local buys = {}
		for _, call in ipairs(calls) do
			if call[1] == "BuyGoldShop" then
				table.insert(buys, call[2])
			end
		end
		expect(buys).toEqual({ "tonic", "bag" })
		press("ButtonB")
		expect(hub.isOpen()).toEqual(false)
		expect(ring()).toBeNil()
		press("ButtonA")
		expect(hub.isOpen()).toEqual(false)
		press("DPadDown")
		expect(hub.isOpen()).toEqual(false)
	end)

	-- E-007 same-frame rail press is not registered. On the Bag rail button,
	-- ButtonA runs padPress → UiRouter.switch once, and a mouse Activated
	-- in that same turn runs the HudShell rail callback once (counts 1 and
	-- 1). The mouse path is menuHub.toggle, so the hub closes. Left out of
	-- this run. No src/ change until Ghost picks one handler.
end)
