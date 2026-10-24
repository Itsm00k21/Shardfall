--!strict

-- Kevin, Oct 22: in a Rootvault run, a skill key or a slot click did
-- nothing at all. Every slot press must reach UseActionSlot or say why it
-- did not (menu open, server refusal, a Lua error), never go quiet. The
-- skill card must also always belong to the slot under the pointer.

local framework = require("./framework")
local describe = framework.describe
local it = require("./oneInventoryOff")(framework.it)
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local GuiFake = require("./GuiFake")

local function profile()
	return {
		level = 12,
		xp = 0,
		classId = "tidecaller",
		classXp = { tidecaller = 1000000 },
		classTalent = {},
		shardTokens = 4,
		gold = 250,
		shardRolls = 0,
		inventory = {},
		pets = {},
		equipped = {},
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	}
end

type Rig = {
	world: any,
	hub: any,
	inventory: { isShown: () -> boolean }?,
	calls: { any },
	toasts: { string },
	reply: any,
	onSkill: () -> (),
}

local function boot(): Rig
	local world = GuiFake.world()
	local MenuHub = world.load("MenuHub")
	local ActionBar = world.load("ActionBar")
	local rig: Rig = {
		world = world,
		hub = nil,
		calls = {},
		toasts = {},
		reply = { ok = false, error = "Skills are for a crawl." },
		onSkill = function() end,
	}
	rig.hub = MenuHub.start(world.playerGui, {
		invoke = function()
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
	})
	rig.hub.setProfile(profile())
	local bar = ActionBar.start(world.playerGui, {
		invoke = function(name: string, ...: any)
			table.insert(rig.calls, { name, ... })
			if type(rig.reply) == "function" then
				return rig.reply()
			end
			return rig.reply
		end,
		-- Same wiring as init.client.luau: the hub, or the full inventory on screen.
		menuOpen = function()
			if rig.hub.isOpen() then
				return true
			end
			local bag = rig.inventory
			return bag ~= nil and bag.isShown()
		end,
		onDodge = function() end,
		onLight = function() end,
		onHeavy = function() end,
		onDodgeChip = function() end,
		onSkill = function()
			rig.onSkill()
		end,
		onToast = function(text: string)
			table.insert(rig.toasts, text)
		end,
		onResult = function() end,
		onRoll = function() end,
		mobile = function()
			return false
		end,
	})
	bar.setProfile(profile())
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallActions")
	for index = 1, 8 do
		local button = GuiFake.findNamed(screen, "Slot" .. tostring(index))
		button.AbsolutePosition = world.vector2((index - 1) * 50, 200)
		button.AbsoluteSize = world.vector2(44, 44)
	end
	return rig
end

-- ContextActionService at one priority: the newest bind (the hub sink,
-- when bound) sees the key first; Pass hands it to the action bar.
local function pressKey(rig: Rig, keyName: string)
	local input = {
		KeyCode = (rig.world.enum.KeyCode :: any)[keyName],
		UserInputType = rig.world.enum.UserInputType.Keyboard,
	}
	local began = rig.world.enum.UserInputState.Begin
	local sink = rig.world.binds.ShardfallMenuSink
	if sink ~= nil then
		local result = sink("ShardfallMenuSink", began, input)
		if result == rig.world.enum.ContextActionResult.Sink then
			return
		end
	end
	rig.world.binds.ShardfallActionBar("ShardfallActionBar", began, input)
end

local function slotButton(rig: Rig, index: number): any
	local screen = GuiFake.findNamed(rig.world.playerGui, "ShardfallActions")
	return GuiFake.findNamed(screen, "Slot" .. tostring(index))
end

local function used(rig: Rig): number
	local count = 0
	for _, call in ipairs(rig.calls) do
		if call[1] == "UseActionSlot" then
			count += 1
		end
	end
	return count
end

local function lastToast(rig: Rig): string?
	return rig.toasts[#rig.toasts]
end

describe("Skill presses", function()
	it("key 1 and a slot click reach UseActionSlot and show the server's reason", function()
		local rig = boot()
		pressKey(rig, "One")
		expect(used(rig)).toEqual(1)
		expect(rig.calls[1][2]).toEqual(1)
		expect(lastToast(rig)).toEqual("Skills are for a crawl.")
		GuiFake.pointerClick(slotButton(rig, 2), rig.world.userInput)
		expect(used(rig)).toEqual(2)
		expect(rig.calls[2][2]).toEqual(2)
		expect(#rig.toasts).toEqual(2)
	end)

	it("an open hub page says to close the menu instead of going quiet", function()
		local rig = boot()
		for _, page in ipairs({ "roll", "hero", "bag", "pets", "shop", "settings" }) do
			rig.hub.open(page)
			expect(rig.hub.isOpen()).toBeTrue()
			local before = #rig.toasts
			pressKey(rig, "One")
			expect(used(rig)).toEqual(0)
			expect(#rig.toasts).toEqual(before + 1)
			expect(lastToast(rig)).toEqual("Close the menu to use skills.")
			GuiFake.pointerClick(slotButton(rig, 1), rig.world.userInput)
			expect(used(rig)).toEqual(0)
			expect(#rig.toasts).toEqual(before + 2)
			rig.hub.close()
		end
		pressKey(rig, "Three")
		expect(used(rig)).toEqual(1)
		expect(rig.calls[1][2]).toEqual(3)
	end)

	it("a shown full inventory says to close the menu instead of casting", function()
		local rig = boot()
		rig.inventory = {
			isShown = function()
				return true
			end,
		}
		pressKey(rig, "One")
		expect(used(rig)).toEqual(0)
		expect(lastToast(rig)).toEqual("Close the menu to use skills.")
		GuiFake.pointerClick(slotButton(rig, 1), rig.world.userInput)
		expect(used(rig)).toEqual(0)
		rig.inventory = {
			isShown = function()
				return false
			end,
		}
		pressKey(rig, "Two")
		expect(used(rig)).toEqual(1)
		expect(rig.calls[1][2]).toEqual(2)
	end)

	it("keys still cast after a roll, a reveal, and closing the hub mid-reveal", function()
		local rig = boot()
		rig.hub.open("roll")
		local hubScreen = GuiFake.findNamed(rig.world.playerGui, "ShardfallHub")
		local roll = GuiFake.findNamed(hubScreen, "Roll")
		GuiFake.emit(roll, "Activated")
		rig.hub.close()
		rig.hub.open("bag")
		rig.hub.close()
		rig.hub.toggle("pets")
		rig.hub.toggle("pets")
		expect(rig.hub.isOpen()).toBeFalse()
		expect(rig.world.binds.ShardfallMenuSink).toBeNil()
		pressKey(rig, "One")
		expect(used(rig)).toEqual(1)
	end)

	it("a hidden hub never holds the action bar", function()
		local rig = boot()
		rig.hub.open("hero")
		local hubScreen = GuiFake.findNamed(rig.world.playerGui, "ShardfallHub")
		hubScreen.Enabled = false
		expect(rig.hub.isOpen()).toBeFalse()
		rig.world.binds.ShardfallActionBar(
			"ShardfallActionBar",
			rig.world.enum.UserInputState.Begin,
			{ KeyCode = rig.world.enum.KeyCode.One }
		)
		expect(used(rig)).toEqual(1)
	end)

	it("a Lua error or a bad reply in a press is reported", function()
		local rig = boot()
		rig.onSkill = function()
			error("boom")
		end
		pressKey(rig, "One")
		expect(lastToast(rig)).toEqual("Could not use that.")
		rig.onSkill = function() end
		rig.reply = function()
			error("remote down")
		end
		local before = #rig.toasts
		pressKey(rig, "Two")
		expect(#rig.toasts).toEqual(before + 1)
		expect(lastToast(rig)).toEqual("Could not use that.")
		rig.reply = "garbage"
		pressKey(rig, "Three")
		expect(lastToast(rig)).toEqual("Could not use that.")
	end)
end)

describe("Skill card", function()
	local function card(rig: Rig): (boolean, string)
		local screen = GuiFake.findNamed(rig.world.playerGui, "ShardfallActions")
		local tooltip = GuiFake.findNamed(screen, "Tooltip")
		local title = GuiFake.findNamed(tooltip, "Title")
		return tooltip.Visible == true, tostring(title.Text)
	end

	it("follows the slot under the pointer, whatever order enter and leave fire", function()
		local rig = boot()
		GuiFake.emit(slotButton(rig, 3), "MouseEnter")
		local shown, title = card(rig)
		expect(shown).toBeTrue()
		expect(title).toEqual("Bubble Ward")
		-- Roblox can fire the new slot's MouseEnter before the old MouseLeave.
		GuiFake.emit(slotButton(rig, 1), "MouseEnter")
		GuiFake.emit(slotButton(rig, 3), "MouseLeave")
		shown, title = card(rig)
		expect(shown).toBeTrue()
		expect(title).toEqual("Tidal Bolt")
		GuiFake.emit(slotButton(rig, 1), "MouseLeave")
		shown = card(rig)
		expect(shown).toBeFalse()
	end)

	it("a held card from one slot never sits on another", function()
		local rig = boot()
		local three = slotButton(rig, 3)
		three.InputBegan:Fire({
			UserInputType = rig.world.enum.UserInputType.MouseButton2,
			KeyCode = rig.world.enum.KeyCode.Unknown,
			Position = rig.world.vector2(120, 210),
		})
		local _, title = card(rig)
		expect(title).toEqual("Bubble Ward")
		-- Mouse down on slot 3, then over slot 1 before release.
		three.InputBegan:Fire({
			UserInputType = rig.world.enum.UserInputType.MouseButton1,
			KeyCode = rig.world.enum.KeyCode.Unknown,
			Position = rig.world.vector2(120, 210),
		})
		GuiFake.emit(slotButton(rig, 1), "MouseEnter")
		local shown = card(rig)
		expect(shown).toBeFalse()
	end)
end)
