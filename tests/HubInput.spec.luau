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

	it("opens Market from the market tab and keeps pets off the bag", function()
		local world, hub = bootHub()
		hub.open("market")
		local screen = screenOf(world)
		expect(labelText(screen, "Title")).toEqual("Market")
		local body = GuiFake.findNamed(screen, "Body")
		expect(body:FindFirstChild("market").Visible).toBeTrue()
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
		for _, tab in ipairs({ "hero", "bag", "pets", "roll", "market" }) do
			hub.open(tab)
			expect(labelText(screenOf(world), "Title") ~= "").toBeTrue()
			local page = GuiFake.findNamed(screenOf(world), "Body"):FindFirstChild(tab)
			expect(page.Visible).toBeTrue()
		end
	end)

	it("moves a gamepad ring through every tab and every button", function()
		local world, hub, calls = bootHub()
		local screen = screenOf(world)
		local function press(key: string, processed: boolean?)
			world.userInput.InputBegan:Fire({
				KeyCode = world.enum.KeyCode[key],
				UserInputType = world.enum.UserInputType.Gamepad1,
				Position = world.vector2(0, 0),
			}, processed == true)
		end
		local function ring(): any
			return GuiFake.findNamed(screen, "PadRing")
		end
		local function focusable(): { any }
			local list = {}
			for _, button in ipairs(GuiFake.buttons(screen)) do
				if button.Name ~= "Backdrop" then
					table.insert(list, button)
				end
			end
			return list
		end
		local function missing(): { string }
			local want = focusable()
			local seen: { [any]: boolean } = {}
			local function mark()
				local current = ring()
				if current ~= nil and current.Parent ~= nil then
					seen[current.Parent] = true
				end
			end
			mark()
			for _ = 1, #want do
				press("DPadDown")
				mark()
			end
			local absent = {}
			for _, button in ipairs(want) do
				if seen[button] ~= true then
					table.insert(absent, tostring(button.Name) .. ":" .. tostring(button.Text))
				end
			end
			return absent
		end
		hub.open("hero")
		local first = ring()
		expect(first ~= nil).toBeTrue()
		expect(first.Parent.Name).toEqual("hero")
		expect(first.Visible).toEqual(false)
		press("DPadDown", true)
		expect(first.Visible).toEqual(true)
		expect(first.Parent.Name).toEqual("bag")
		local stroke = first:FindFirstChild("Ring")
		expect(stroke ~= nil).toBeTrue()
		expect(stroke.Thickness >= 4).toBeTrue()
		expect(stroke.Color.R).toEqual(244)
		expect(stroke.Color.G).toEqual(240)
		expect(stroke.Color.B).toEqual(252)
		local tabs = { "hero", "bag", "pets", "roll", "raids", "market", "pass", "settings" }
		for _, tab in ipairs(tabs) do
			hub.open(tab)
			local absent = missing()
			expect(absent).toEqual({})
		end
		hub.close()
		hub.open("hero")
		local stickParent = nil
		world.userInput.InputChanged:Fire({
			KeyCode = world.enum.KeyCode.Thumbstick1,
			UserInputType = world.enum.UserInputType.Gamepad1,
			Position = { X = 0, Y = -0.85, Z = 0 },
		}, true)
		stickParent = ring().Parent
		expect(stickParent.Name).toEqual("bag")
		world.userInput.InputChanged:Fire({
			KeyCode = world.enum.KeyCode.Thumbstick1,
			UserInputType = world.enum.UserInputType.Gamepad1,
			Position = { X = 0, Y = -0.9, Z = 0 },
		}, false)
		expect(ring().Parent).toEqual(stickParent)
		world.userInput.InputChanged:Fire({
			KeyCode = world.enum.KeyCode.Thumbstick1,
			UserInputType = world.enum.UserInputType.Gamepad1,
			Position = { X = 0, Y = 0, Z = 0 },
		}, false)
		world.userInput.InputChanged:Fire({
			KeyCode = world.enum.KeyCode.Thumbstick1,
			UserInputType = world.enum.UserInputType.Gamepad1,
			Position = { X = 0.9, Y = 0, Z = 0 },
		}, false)
		expect(ring().Visible).toEqual(true)
		hub.close()
		expect(hub.isOpen()).toEqual(false)
		expect(world.binds.ShardfallMenuSink).toBeNil()
		expect(screen.Enabled).toEqual(false)
		hub.open("roll")
		expect(world.binds.ShardfallMenuSink ~= nil).toBeTrue()
		local guard = 0
		while ring().Parent.Name ~= "Quick" and guard < 80 do
			press("DPadDown")
			guard += 1
		end
		expect(ring().Parent.Name).toEqual("Quick")
		press("ButtonA")
		expect(labelText(screen, "Quick")).toEqual("Quick On")
		guard = 0
		while ring().Parent.Name ~= "Roll" and guard < 80 do
			press("DPadDown")
			guard += 1
		end
		expect(ring().Parent.Name).toEqual("Roll")
		local beforeRoll = #rolled(calls)
		press("ButtonA")
		expect(#rolled(calls)).toEqual(beforeRoll + 1)
		expect(rolled(calls)[#rolled(calls)][1]).toEqual("RollShard")
		press("ButtonB")
		expect(hub.isOpen()).toEqual(false)
		expect(world.binds.ShardfallMenuSink).toBeNil()
		expect(screen.Enabled).toEqual(false)
		world.userInput.InputBegan:Fire({
			KeyCode = world.enum.KeyCode.B,
			UserInputType = world.enum.UserInputType.Keyboard,
		}, false)
		expect(hub.isOpen()).toEqual(true)
		expect(labelText(screen, "Title")).toEqual("Bag")
		world.userInput.InputBegan:Fire({
			KeyCode = world.enum.KeyCode.Escape,
			UserInputType = world.enum.UserInputType.Keyboard,
		}, false)
		expect(hub.isOpen()).toEqual(false)
	end)

	it("does not close on ButtonB while a hotkey capture is active", function()
		local world, hub = bootHub()
		hub.open("settings")
		local screen = screenOf(world)
		local hotkey = nil
		for _, button in ipairs(GuiFake.buttons(screen)) do
			if string.find(tostring(button.Text), "Hotkey hero", 1, true) ~= nil then
				hotkey = button
			end
		end
		expect(hotkey ~= nil).toBeTrue()
		GuiFake.activate(hotkey)
		local waiting = false
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and string.find(tostring(child.Text), "press a key", 1, true) ~= nil then
				waiting = true
			end
		end
		expect(waiting).toBeTrue()
		world.userInput.InputBegan:Fire({
			KeyCode = world.enum.KeyCode.ButtonB,
			UserInputType = world.enum.UserInputType.Gamepad1,
		}, false)
		expect(hub.isOpen()).toEqual(true)
		expect(screen.Enabled).toEqual(true)
		waiting = false
		for _, child in ipairs(screen:GetDescendants()) do
			if child:IsA("TextButton") and string.find(tostring(child.Text), "press a key", 1, true) ~= nil then
				waiting = true
			end
		end
		expect(waiting).toBeTrue()
	end)

	it("fires each action-bar slot from the d-pad without using attack or dodge", function()
		local world = GuiFake.world()
		local ActionBar = world.load("ActionBar")
		local calls = {}
		local dodges = 0
		local lights = 0
		local heavies = 0
		local menu = false
		local bar = ActionBar.start(world.playerGui, {
			invoke = function(name: string, ...)
				table.insert(calls, { name, ... })
				return { ok = true }
			end,
			menuOpen = function()
				return menu
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
		local screen = GuiFake.findNamed(world.playerGui, "ShardfallActions")
		local function border(index: number): any
			local button = GuiFake.findNamed(screen, "Slot" .. tostring(index))
			return button:FindFirstChild("Border")
		end
		local function pad(key: string)
			world.binds.ShardfallActionBarPad("ShardfallActionBarPad", world.enum.UserInputState.Begin, {
				KeyCode = world.enum.KeyCode[key],
				UserInputType = world.enum.UserInputType.Gamepad1,
			})
		end
		local plain = {
			{ "DPadUp", 1 },
			{ "DPadRight", 2 },
			{ "DPadDown", 3 },
			{ "DPadLeft", 4 },
		}
		for _, pair in ipairs(plain) do
			local before = #calls
			pad(pair[1])
			expect(#calls).toEqual(before + 1)
			expect(calls[#calls][1]).toEqual("UseActionSlot")
			expect(calls[#calls][2]).toEqual(pair[2])
		end
		world.userInput.gamepadModifier = true
		local chord = {
			{ "DPadUp", 5 },
			{ "DPadRight", 6 },
			{ "DPadDown", 7 },
			{ "DPadLeft", 8 },
		}
		for _, pair in ipairs(chord) do
			local before = #calls
			pad(pair[1])
			if pair[2] <= 6 then
				expect(#calls).toEqual(before + 1)
				expect(calls[#calls][1]).toEqual("UseActionSlot")
				expect(calls[#calls][2]).toEqual(pair[2])
			else
				expect(#calls).toEqual(before)
				expect(border(pair[2]).Color.R).toEqual(255)
				expect(border(pair[2]).Color.G).toEqual(255)
				expect(border(pair[2]).Color.B).toEqual(255)
			end
		end
		world.userInput.gamepadModifier = false
		expect(dodges).toEqual(0)
		expect(lights).toEqual(0)
		expect(heavies).toEqual(0)
		menu = true
		local beforeMenu = #calls
		local held = border(8).Color.R
		pad("DPadUp")
		expect(#calls).toEqual(beforeMenu)
		expect(border(8).Color.R).toEqual(held)
		menu = false
		world.binds.ShardfallDodge("ShardfallDodge", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.ButtonY,
			UserInputType = world.enum.UserInputType.Gamepad1,
		})
		expect(dodges).toEqual(1)
		world.binds.ShardfallLight("ShardfallLight", world.enum.UserInputState.Begin, {
			KeyCode = world.enum.KeyCode.ButtonR1,
			UserInputType = world.enum.UserInputType.Gamepad1,
		})
		expect(lights).toEqual(1)
		expect(heavies).toEqual(0)
	end)

end)
