--!strict

--[[
	Clip 9 fix batch (Oct 23): manual bulk salvage, the intro and goals over
	the open Bag, collapsible intro and goals, goal ticking, the
	auto-salvage popover, the Bag detail scroll, and the Pets list.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local GearHooks = require("../src/ReplicatedStorage/Shared/GearHooks")
local GearSalvage = require("../src/ReplicatedStorage/Shared/GearSalvage")
local HubStyle = require("../src/ReplicatedStorage/Shared/HubStyle")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Onboarding = require("../src/ReplicatedStorage/Shared/Onboarding")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local GuiFake = require("./GuiFake")

local function sword(uid: string, rarity: string, extra: { [string]: any }?): { [string]: any }
	local item: { [string]: any } = {
		uid = uid,
		templateId = "iron_sword",
		name = "Iron Sword " .. uid,
		kind = "Weapon",
		rarity = rarity,
		traits = {},
		poolId = "dev",
		obtainedAt = 1,
		locked = false,
	}
	if extra ~= nil then
		for key, value in pairs(extra) do
			item[key] = value
		end
	end
	return item
end

local function bag(): any
	local data = Schema.template()
	data.inventory = {}
	data.pets = {}
	Schema.insertItem(data, sword("c1", "Common") :: any)
	Schema.insertItem(data, sword("c2", "Common") :: any)
	Schema.insertItem(data, sword("u1", "Uncommon") :: any)
	Schema.insertItem(data, sword("r1", "Rare") :: any)
	Schema.insertItem(data, sword("e1", "Epic") :: any)
	Schema.insertItem(data, sword("worn", "Common") :: any)
	Schema.insertItem(data, sword("held", "Common", { locked = true }) :: any)
	Schema.insertItem(data, sword("fav", "Uncommon", { favorite = true }) :: any)
	data.equipped = data.equipped or {}
	data.equipped.weapon = "worn"
	data.gearEssence = 0
	return data
end

local function withFlag(fn: () -> ())
	local previous = LaunchGate.SHOW.gearSalvage
	LaunchGate.SHOW.gearSalvage = true
	GearSalvage._reset()
	local ok, err = pcall(fn)
	LaunchGate.SHOW.gearSalvage = previous
	GearSalvage._reset()
	if not ok then
		error(err, 0)
	end
end

local function server(profile: any)
	local calls = {}
	local function invoke(action: string, payload: any): any
		table.insert(calls, { action, payload })
		local result = GearSalvage.applyAction(profile, 42, action, payload, 100)
		if type(result) == "table" then
			result.profile = profile
		end
		return result
	end
	return invoke, calls
end

local function mountBar(profile: any, invoke: any, tabName: any)
	local world = GuiFake.world()
	local GearBar = world.load("GearBar")
	local parent = world.playerGui
	local statuses = {}
	local handle = GearBar.mount(parent, {
		invoke = invoke,
		getProfile = function()
			return profile
		end,
		onChanged = function() end,
		onStatus = function(text: string, kind: string)
			table.insert(statuses, { text, kind })
		end,
		getTab = function()
			if type(tabName) == "function" then
				return tabName()
			end
			return tabName
		end,
	})
	return handle, parent, statuses
end

local function count(list: { any }, action: string): number
	local n = 0
	for _, call in ipairs(list) do
		if call[1] == action then
			n += 1
		end
	end
	return n
end

describe("Clip 9: manual bulk salvage", function()
	it(
		"names the picker rows and estimates like the server, never counting protected gear",
		function()
			expect(GearHooks.bulkTitle("Common")).toEqual("Salvage all Common")
			expect(GearHooks.bulkTitle("Uncommon")).toEqual("Salvage all Uncommon and below")
			expect(GearHooks.bulkTitle("Rare")).toEqual("Salvage all Rare and below")
			expect(GearHooks.bulkLine(0, 0)).toEqual("Nothing to salvage")
			expect(GearHooks.bulkLine(1, 2)).toEqual("1 item · +2 Essence")
			withFlag(function()
				local profile = bag()
				for _, cap in ipairs(GearHooks.BULK_CAPS) do
					local n, gain = GearHooks.bulkEstimate(profile, cap)
					local plan = GearSalvage.plan(profile, cap)
					expect(n).toEqual(if plan ~= nil then plan.count else 0)
					expect(gain).toEqual(if plan ~= nil then plan.gain else 0)
				end
				-- c1, c2 only: worn (equipped) and held (locked) stay.
				expect((GearHooks.bulkEstimate(profile, "Common"))).toEqual(2)
				-- + u1; fav (favorite) stays.
				expect((GearHooks.bulkEstimate(profile, "Uncommon"))).toEqual(3)
				expect((GearHooks.bulkEstimate(profile, "Rare"))).toEqual(4)
			end)
		end
	)

	it("shows Salvage… on Weapons and Armor and hides it elsewhere and in Select mode", function()
		withFlag(function()
			local profile = bag()
			local invoke = server(profile)
			local _, parent = mountBar(profile, invoke, "weapons")
			local button = GuiFake.findNamed(parent, "BulkSalvage")
			expect(button.Text).toEqual("Salvage…")
			expect(button.Visible).toBeTrue()
			GuiFake.activate(GuiFake.findNamed(parent, "SelectMode"))
			expect(button.Visible).toBeFalse()
			local _, other = mountBar(profile, invoke, "pets")
			expect(GuiFake.findNamed(other, "BulkSalvage").Visible).toBeFalse()
		end)
	end)

	it("hides Select off Weapons and Armor and leaves Select mode on a tab switch", function()
		withFlag(function()
			local profile = bag()
			local invoke = server(profile)
			local where = "weapons"
			local handle, parent = mountBar(profile, invoke, function()
				return where
			end)
			local select = GuiFake.findNamed(parent, "SelectMode")
			expect(select.Visible).toBeTrue()
			GuiFake.activate(select)
			expect(select.Text).toEqual("Done")
			where = "pets"
			handle.refresh()
			expect(select.Visible).toBeFalse()
			expect(GuiFake.findNamed(parent, "BulkSalvage").Visible).toBeFalse()
			where = "weapons"
			handle.refresh()
			expect(select.Visible).toBeTrue()
			expect(select.Text).toEqual("Select")
		end)
	end)

	it(
		"fills each row from the server preview, then confirms and salvages only safe gear",
		function()
			withFlag(function()
				local profile = bag()
				local invoke, calls = server(profile)
				local _, parent = mountBar(profile, invoke, "armor")
				GuiFake.activate(GuiFake.findNamed(parent, "BulkSalvage"))
				local picker = GuiFake.findNamed(parent, "BulkPicker")
				expect(picker.Visible).toBeTrue()
				expect(count(calls, "preview")).toEqual(3)
				local common = GuiFake.findNamed(picker, "BulkCommon")
				local uncommon = GuiFake.findNamed(picker, "BulkUncommon")
				local rare = GuiFake.findNamed(picker, "BulkRare")
				expect(common:GetAttribute("Server")).toEqual(true)
				expect(common.Text).toEqual(
					"Salvage all Common\n" .. GearHooks.bulkLine(2, common:GetAttribute("Gain"))
				)
				expect(uncommon:GetAttribute("Count")).toEqual(3)
				expect(rare:GetAttribute("Count")).toEqual(4)
				expect(string.find(rare.Text, "Salvage all Rare and below", 1, true) ~= nil).toBeTrue()
				-- Tap a row: a fresh preview, then the confirm with its numbers.
				GuiFake.activate(uncommon)
				expect(picker.Visible).toBeFalse()
				local confirm = GuiFake.findNamed(parent, "SalvageConfirm")
				expect(confirm.Visible).toBeTrue()
				local text = GuiFake.findNamed(confirm, "Text").Text
				expect(
					string.find(text, "Salvage all Uncommon and below: salvage 3 pieces", 1, true)
						~= nil
				).toBeTrue()
				expect(count(calls, "confirm")).toEqual(0)
				expect(profile.inventory.c1 ~= nil).toBeTrue()
				GuiFake.activate(GuiFake.findNamed(confirm, "ConfirmSalvage"))
				expect(count(calls, "confirm")).toEqual(1)
				expect(profile.inventory.c1).toBeNil()
				expect(profile.inventory.c2).toBeNil()
				expect(profile.inventory.u1).toBeNil()
				-- Protected and higher gear stays.
				expect(profile.inventory.worn ~= nil).toBeTrue()
				expect(profile.inventory.held ~= nil).toBeTrue()
				expect(profile.inventory.fav ~= nil).toBeTrue()
				expect(profile.inventory.r1 ~= nil).toBeTrue()
				expect(profile.inventory.e1 ~= nil).toBeTrue()
				expect(profile.gearEssence > 0).toBeTrue()
			end)
		end
	)

	it("cancel deletes nothing, and an empty row says so without a preview", function()
		withFlag(function()
			local profile = bag()
			profile.inventory.c1 = nil
			profile.inventory.c2 = nil
			local invoke, calls = server(profile)
			local _, parent, statuses = mountBar(profile, invoke, "weapons")
			GuiFake.activate(GuiFake.findNamed(parent, "BulkSalvage"))
			local picker = GuiFake.findNamed(parent, "BulkPicker")
			local common = GuiFake.findNamed(picker, "BulkCommon")
			expect(common:GetAttribute("Count")).toEqual(0)
			expect(string.find(common.Text, "Nothing to salvage", 1, true) ~= nil).toBeTrue()
			local before = #calls
			GuiFake.activate(common)
			expect(#calls).toEqual(before)
			expect(statuses[#statuses][1]).toEqual("Salvage all Common: nothing to salvage.")
			GuiFake.activate(GuiFake.findNamed(picker, "BulkRare"))
			GuiFake.activate(GuiFake.findNamed(parent, "CancelSalvage"))
			expect(count(calls, "confirm")).toEqual(0)
			expect(profile.inventory.r1 ~= nil).toBeTrue()
		end)
	end)
end)

describe("Clip 9: auto-salvage chip and popover", function()
	it("keeps one chip width on and off", function()
		withFlag(function()
			local profile = bag()
			local invoke = server(profile)
			local handle, parent = mountBar(profile, invoke, "weapons")
			local chip = GuiFake.findNamed(parent, "AutoSalvage")
			local off = chip.Size.X.Offset
			profile.autoSalvage = true
			profile.autoSalvageRarity = "Uncommon"
			handle.refresh()
			expect(chip:GetAttribute("AutoOn")).toBeTrue()
			expect(chip.Size.X.Offset).toEqual(off)
			profile.autoSalvageRarity = "Common"
			handle.refresh()
			expect(chip.Size.X.Offset).toEqual(off)
		end)
	end)

	it("shows one plain cap line and no warning or Lower button", function()
		withFlag(function()
			local profile = bag()
			local invoke = server(profile)
			local _, parent = mountBar(profile, invoke, "weapons")
			GuiFake.activate(GuiFake.findNamed(parent, "AutoSalvage"))
			local popover = GuiFake.findNamed(parent, "AutoPopover")
			expect(popover.Visible).toBeTrue()
			expect(GuiFake.findNamed(popover, "AutoCapNote").Text).toEqual(
				GearHooks.capNote(profile)
			)
			for _, node in ipairs(popover:GetDescendants()) do
				if node:IsA("TextLabel") or node:IsA("TextButton") then
					expect(string.find(node.Text, "saved cap", 1, true)).toBeNil()
					expect(string.find(node.Text, "Lower cap", 1, true)).toBeNil()
				end
			end
		end)
	end)
end)

describe("Clip 9: goals tick from the save", function()
	it("marks nothing done on the open step or an unknown step", function()
		for _, goal in ipairs(Onboarding.goals("open")) do
			expect(goal.done).toBeFalse()
		end
		for _, goal in ipairs(Onboarding.goals("nope")) do
			expect(goal.done).toBeFalse()
		end
		local done, total = Onboarding.goalCount(Onboarding.goals("open"))
		expect(done).toEqual(0)
		expect(total).toEqual(5)
	end)

	it("ticks Choose a class once the profile has one, on any step", function()
		local goals = Onboarding.goals("open", { classId = "warden" })
		expect(goals[1].id).toEqual("class")
		expect(goals[1].done).toBeTrue()
		for index = 2, #goals do
			expect(goals[index].done).toBeFalse()
		end
		expect(Onboarding.goals("class", { classId = "" })[1].done).toBeFalse()
		expect(Onboarding.goals("class", {})[1].done).toBeFalse()
		local dodge = Onboarding.goals("dodge", { classId = "warden" })
		expect(dodge[1].done).toBeTrue()
		expect(dodge[2].done).toBeTrue()
		expect(dodge[3].done).toBeFalse()
		expect((Onboarding.goalCount(dodge))).toEqual(2)
	end)

	it("names the pill after the step, or the next goal when the step's own is done", function()
		expect(Onboarding.pillText("class")).toEqual("Shardfall: Choose a class")
		expect(Onboarding.pillText("dodge")).toEqual("Shardfall: Dodge")
		local goals = Onboarding.goals("class", { classId = "warden" })
		expect(Onboarding.pillText("class", goals)).toEqual("Shardfall: Keep swinging")
	end)
end)

describe("Clip 9: intro card layout", function()
	it("keeps the card small and off the screen center on every tested view", function()
		for _, view in ipairs({ { 1280, 720 }, { 1482, 669 }, { 844, 390 }, { 1920, 1080 } }) do
			local vx, vy = view[1], view[2]
			local layout = HudLayout.onboard(vx, vy)
			local card = layout.card
			expect(card.w <= 340).toBeTrue()
			expect(card.h <= 140).toBeTrue()
			local cx, cy = vx / 2, vy / 2
			local inside = cx >= card.x
				and cx <= card.x + card.w
				and cy >= card.y
				and cy <= card.y + card.h
			expect(inside).toBeFalse()
			expect(card.x + card.w <= vx / 2).toBeTrue()
			expect(layout.pill.w <= card.w).toBeTrue()
			expect(layout.goalsTab.x + layout.goalsTab.w <= vx).toBeTrue()
			expect(layout.collapse.x + layout.collapse.w <= card.w).toBeTrue()
		end
	end)
end)

describe("Clip 9: collapsible intro and live cover", function()
	local function start()
		local world = GuiFake.world()
		world.playerGui.Parent = world.player
		local OnboardHud = world.load("OnboardHud")
		OnboardHud.start(function()
			return { ok = true }
		end)
		local onboard = GuiFake.findNamed(world.playerGui, "ShardfallOnboard")
		return world, OnboardHud, onboard
	end

	it("folds the card into the pill and the goals into the tab, and back", function()
		local _, OnboardHud, onboard = start()
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		local card = GuiFake.findNamed(onboard, "Continue").Parent
		local pill = GuiFake.findNamed(onboard, "IntroPill")
		local goals = GuiFake.findNamed(onboard, "OnboardGoals")
		local tab = GuiFake.findNamed(onboard, "GoalsTab")
		expect(card.Visible).toBeTrue()
		expect(pill.Visible).toBeFalse()
		expect(goals.Visible).toBeTrue()
		expect(GuiFake.findNamed(onboard, "GoalsHeader").Text).toEqual("Goals 0/5")
		GuiFake.activate(GuiFake.findNamed(onboard, "Collapse"))
		expect(card.Visible).toBeFalse()
		expect(pill.Visible).toBeTrue()
		expect(string.find(pill.Text, "Shardfall: Choose a class", 1, true) ~= nil).toBeTrue()
		GuiFake.activate(GuiFake.findNamed(onboard, "GoalsCollapse"))
		expect(goals.Visible).toBeFalse()
		expect(tab.Visible).toBeTrue()
		expect(string.find(tab.Text, "Goals 0/5", 1, true) ~= nil).toBeTrue()
		-- A profile push keeps the session's choice.
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "swing", classId = "warden" })
		expect(card.Visible).toBeFalse()
		expect(pill.Visible).toBeTrue()
		expect(tab.Visible).toBeTrue()
		expect(string.find(tab.Text, "Goals 1/5", 1, true) ~= nil).toBeTrue()
		GuiFake.activate(pill)
		expect(card.Visible).toBeTrue()
		expect(pill.Visible).toBeFalse()
		GuiFake.activate(tab)
		expect(goals.Visible).toBeTrue()
		expect(tab.Visible).toBeFalse()
	end)

	it("Skip still dismisses for good, pill and tab included", function()
		local _, OnboardHud, onboard = start()
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		OnboardHud.setCollapsed(true, true)
		GuiFake.activate(GuiFake.findNamed(onboard, "Skip"))
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		expect(GuiFake.findNamed(onboard, "IntroPill").Visible).toBeFalse()
		expect(GuiFake.findNamed(onboard, "GoalsTab").Visible).toBeFalse()
		expect(GuiFake.findNamed(onboard, "OnboardGoals").Visible).toBeFalse()
		OnboardHud.setCollapsed(false, false)
	end)

	it("stays hidden over an open menu even when a profile push lands", function()
		local world, OnboardHud, onboard = start()
		OnboardHud.setCollapsed(false, false)
		local bagOpen = false
		OnboardHud.coverWhen("inventory", function()
			return bagOpen
		end)
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		local card = GuiFake.findNamed(onboard, "Continue").Parent
		expect(card.Visible).toBeTrue()
		bagOpen = true
		-- A stale "closed" from the old callback cannot uncover it.
		OnboardHud.setCovered("inventory", false)
		expect(card.Visible).toBeFalse()
		OnboardHud.setProfile({ onboardDone = false, onboardStep = "class" })
		expect(card.Visible).toBeFalse()
		expect(GuiFake.findNamed(onboard, "OnboardGoals").Visible).toBeFalse()
		expect(GuiFake.findNamed(onboard, "IntroPill").Visible).toBeFalse()
		-- The menu closes with no callback: the Heartbeat recheck shows it.
		bagOpen = false
		local heartbeat = world.runService.Heartbeat
		heartbeat:_emit(0.25)
		expect(card.Visible).toBeTrue()
		OnboardHud.coverWhen("inventory", function()
			return false
		end)
	end)

	it("reads real visibility through ancestors and the ScreenGui", function()
		local world, OnboardHud = start()
		local gui = world.new("ScreenGui")
		gui.Parent = world.playerGui
		local frame = world.new("Frame")
		frame.Parent = gui
		local inner = world.new("Frame")
		inner.Parent = frame
		expect(OnboardHud.shown(inner)).toBeTrue()
		frame.Visible = false
		expect(OnboardHud.shown(inner)).toBeFalse()
		frame.Visible = true
		gui.Enabled = false
		expect(OnboardHud.shown(inner)).toBeFalse()
	end)
end)

describe("Clip 9: Bag detail scroll", function()
	it("starts the detail at the top on every pick and every reopen", function()
		withFlag(function()
			local profile = bag()
			local world = GuiFake.world()
			local InventoryHud = world.load("InventoryHud")
			local controller = InventoryHud.start(world.playerGui, {
				onGear = function(action: string, payload: any): any
					return GearSalvage.applyAction(profile, 42, action, payload, 100)
				end,
			})
			controller.setProfile(profile)
			controller.open()
			expect(controller.isShown()).toBeTrue()
			local screen = GuiFake.findNamed(world.playerGui, "ShardfallInventory")
			local root = GuiFake.findNamed(screen, "Inventory")
			local detail = GuiFake.findNamed(root, "Detail")
			local grid = GuiFake.findNamed(root, "Grid")
			local card = grid:FindFirstChild("c1")
			expect(card ~= nil).toBeTrue()
			GuiFake.activate(card)
			detail.CanvasPosition = { X = 0, Y = 420 }
			-- The same card again.
			GuiFake.activate(grid:FindFirstChild("c1"))
			expect(detail.CanvasPosition.Y).toEqual(0)
			detail.CanvasPosition = { X = 0, Y = 420 }
			controller.close()
			expect(controller.isShown()).toBeFalse()
			controller.open()
			expect(detail.CanvasPosition.Y).toEqual(0)
		end)
	end)
end)

describe("Clip 9: Pets list", function()
	it("opens the detail on the equipped pet unless the player picked one", function()
		local cards = { { uid = "a" }, { uid = "b" }, { uid = "c" } }
		expect(HubStyle.petDefault(cards, "c", nil, nil)).toEqual(3)
		expect(HubStyle.petDefault(cards, "c", 2, nil)).toEqual(2)
		expect(HubStyle.petDefault(cards, "c", 2, "a")).toEqual(1)
		expect(HubStyle.petDefault(cards, "zz", nil, nil)).toEqual(1)
		expect(HubStyle.petDefault({}, "c", nil, nil)).toEqual(1)
	end)
end)
