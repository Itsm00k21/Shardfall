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
		expect(labelText(screen, "Roll")).toEqual(HubStyle.CRACK_ONE)
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
		local crackPet = false
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and string.find(child.Text, HubStyle.CRACK_PET, 1, true) ~= nil then
				crackPet = true
			end
		end
		expect(crackPet).toBeTrue()
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
					if node.Visible == false or node.Enabled == false then
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
				Position = { X = x, Y = y, Z = 0 },
			}, false)
		end
		local function place(button: any, x: number, y: number)
			button.AbsolutePosition = world.vector2(x, y)
			button.AbsoluteSize = world.vector2(40, 36)
		end
		hub.open("roll")
		local screen = screenOf(world)
		expect(labelText(screen, "Title")).toEqual("Roll")
		expect(GuiFake.findNamed(screen, "PadRing").Parent).toEqual(tabButton(screen, "roll"))
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
		place(tabButton(screen, "roll"), 0, 0)
		place(tabButton(screen, "shop"), 0, 400)
		place(tabButton(screen, "settings"), 360, 0)
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
		expect(ring.Parent).toEqual(tabButton(screen, "settings"))
		hub.close()
		expect(GuiFake.findNamed(screen, "PadRing")).toBeNil()
		hub.open("roll")
		screen = screenOf(world)
		expect(GuiFake.findNamed(screen, "PadRing").Parent).toEqual(tabButton(screen, "roll"))
		press("DPadDown", true)
		ring = GuiFake.findNamed(screen, "PadRing")
		expect(ring.Parent).toEqual(tabButton(screen, "shop"))
		press("ButtonA", true)
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
		expect(GuiFake.findNamed(screen, "PadRing").Parent).toEqual(tabButton(screen, "hero"))
		stick(0.1, 0.2)
		expect(GuiFake.findNamed(screen, "PadRing").Parent).toEqual(tabButton(screen, "hero"))
		stick(0, -0.8)
		ring = GuiFake.findNamed(screen, "PadRing")
		expect(ring.Parent).toEqual(tabButton(screen, "bag"))
		local stepped = ring.Parent
		stick(0, -0.9)
		expect(ring.Parent).toEqual(stepped)
		stick(0, 0)
		stick(0, -0.8)
		expect(ring.Parent).toEqual(tabButton(screen, "pets"))
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
		expect(GuiFake.findNamed(screenOf(world), "PadRing").Parent).toEqual(tabButton(screenOf(world), "roll"))
		press("DPadDown")
		local openRing = GuiFake.findNamed(screenOf(world), "PadRing")
		expect(openRing.Parent).toEqual(tabButton(screenOf(world), "shop"))
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
		press("DPadDown")
		press("DPadDown")
		ring = GuiFake.findNamed(screen, "PadRing")
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
		expect(ring.Parent).toEqual(tabButton(screen, "roll"))
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
end)
