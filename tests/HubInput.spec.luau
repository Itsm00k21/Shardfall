--!strict

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
		button.Activated:Fire()
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
		button.Activated:Fire()
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
		button.Activated:Fire()
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
		task.wait(0.9)
		button.Activated:Fire()
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
end)
