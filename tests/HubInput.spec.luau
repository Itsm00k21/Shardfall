--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local HubPress = require("../src/ReplicatedStorage/Shared/HubPress")
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
		local tabs = { "hero", "bag", "pets", "roll", "raids", "market", "pass", "settings" }
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
			raids = "Raids",
			market = "Market",
			pass = "Shard Pass",
			settings = "Settings",
			hero = "Hero",
		}
		for _, tab in ipairs({ "bag", "pets", "roll", "raids", "market", "pass", "settings", "hero" }) do
			GuiFake.activate(tabButton(screen, tab))
			expect(#rolled(calls)).toEqual(before)
			expect(labelText(screen, "Title")).toEqual(titles[tab])
		end
		GuiFake.activate(tabButton(screen, "pass"))
		local pass = GuiFake.findNamed(screen, "Body"):FindFirstChild("pass", false)
		GuiFake.activate(pass:FindFirstChild("Cta", true))
		expect(hasText(screen, "Daily check is quiet.")).toBeTrue()
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
end)
