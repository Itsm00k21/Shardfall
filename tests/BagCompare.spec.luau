--!strict

--[[
	Bag detail pane (Kevin, Oct 22 clip). The header names the item worn in
	the selected item's slot, the worn item reads "Equipped", stat marks
	use the shown values ("=" equal, "+" higher, "-" lower), and UPGRADE
	shows the server's answer as a toast plus a repaint.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local BagCompare = require("../src/ReplicatedStorage/Shared/BagCompare")
local Economy = require("../src/ReplicatedStorage/Shared/Economy")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local GuiFake = require("./GuiFake")

local function weapon(uid: string, name: string, rarity: string, stats: { number }, upgrade: number?)
	return {
		uid = uid,
		name = name,
		rarity = rarity,
		kind = "Weapon",
		templateId = uid,
		quality = 0.5,
		upgrade = upgrade,
		stats = {
			{ id = "damage", value = stats[1] },
			{ id = "attack_speed", value = stats[2] },
			{ id = "crit_chance", value = stats[3] },
			{ id = "crit_damage", value = stats[4] },
		},
	}
end

local function profile(worn: string)
	return {
		level = 20,
		xp = 0,
		classId = "warden",
		classXp = { warden = 1800 },
		shardTokens = 0,
		gold = 5000,
		shardRolls = 0,
		inventory = {
			staff = weapon("staff", "Mycelium Staff", "Rare", { 28, 1.15, 0.118, 2.4 }, 1),
			night = weapon("night", "Nightstriker", "Epic", { 40, 1.3, 0.2, 2.0 }, 2),
			-- Same shown attack speed and crit as the staff, off by float noise.
			mace = weapon("mace", "Mace", "Rare", { 20, 1.1500001, 0.1180001, 2.4 }, 0),
		},
		pets = {},
		equipped = { weapon = worn, armor = {} },
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	}
end

local function open(worn: string, invoke: any?)
	local world = GuiFake.world()
	local MenuHub = world.load("MenuHub")
	local calls = { invokes = {}, toasts = {} }
	local hub = MenuHub.start(world.playerGui, {
		invoke = function(name: string, ...: any)
			table.insert(calls.invokes, { name, ... })
			if invoke ~= nil then
				return invoke(name, ...)
			end
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
		onToast = function(message: string)
			table.insert(calls.toasts, message)
		end,
	})
	hub.setProfile(profile(worn))
	hub.open("bag")
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
	return hub, screen, calls
end

local function cardFor(screen: any, name: string): any
	for _, node in ipairs(screen:GetDescendants()) do
		if node.Name == "Card" then
			for _, child in ipairs(node:GetChildren()) do
				if child:IsA("TextLabel") and child.Text == name then
					return node
				end
			end
		end
	end
	return nil
end

local function select(screen: any, name: string)
	local card = cardFor(screen, name)
	expect(card ~= nil).toBeTrue()
	GuiFake.activate(card)
end

local function pane(screen: any): { string }
	local list = GuiFake.findNamed(screen, "Compare")
	local rows = {}
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			table.insert(rows, { child.LayoutOrder, child.Text })
		end
	end
	table.sort(rows, function(a, b)
		return a[1] < b[1]
	end)
	local out = {}
	for _, row in ipairs(rows) do
		table.insert(out, (string.gsub(row[2], "^%s+", "")))
	end
	return out
end

local function has(rows: { string }, text: string): boolean
	for _, row in ipairs(rows) do
		if row == text then
			return true
		end
	end
	return false
end

local function upgradeButton(screen: any): any
	local list = GuiFake.findNamed(screen, "Compare")
	for _, child in ipairs(list:GetDescendants()) do
		if child:IsA("TextButton") and string.find(child.Text, "UPGRADE", 1, true) ~= nil then
			return child
		end
	end
	return nil
end

describe("Bag detail compare", function()
	it("says Equipped for the worn item and names it for the others", function()
		local _, screen = open("mace")
		select(screen, "Mace")
		local rows = pane(screen)
		expect(has(rows, "Equipped")).toBeTrue()
		expect(has(rows, "EQUIPPED")).toBeTrue()
		expect(has(rows, "Nothing equipped to compare.")).toBeFalse()
		select(screen, "Mycelium Staff")
		rows = pane(screen)
		expect(has(rows, "Compared with Mace (equipped)")).toBeTrue()
		expect(has(rows, "EQUIP")).toBeTrue()
	end)

	it("refreshes every stat row when the selection changes", function()
		local _, screen = open("mace")
		select(screen, "Mycelium Staff")
		local rows = pane(screen)
		expect(has(rows, "Mycelium Staff  +1")).toBeTrue()
		expect(has(rows, "Damage  28  +")).toBeTrue()
		select(screen, "Nightstriker")
		rows = pane(screen)
		expect(has(rows, "Nightstriker  +2")).toBeTrue()
		expect(has(rows, "Damage  40  +")).toBeTrue()
		expect(has(rows, "Attack Speed  1.30  +")).toBeTrue()
		expect(has(rows, "Crit Chance  20.0%  +")).toBeTrue()
		expect(has(rows, "Crit Damage  2.00  -")).toBeTrue()
		expect(has(rows, "Damage  28  +")).toBeFalse()
		expect(has(rows, "UPGRADE  1,280")).toBeTrue()
	end)

	it("marks equal shown values with = instead of a red minus", function()
		local _, screen = open("mace")
		select(screen, "Mycelium Staff")
		local rows = pane(screen)
		expect(has(rows, "Attack Speed  1.15  =")).toBeTrue()
		expect(has(rows, "Crit Chance  11.8%  =")).toBeTrue()
		expect(has(rows, "Crit Damage  2.40  =")).toBeTrue()
		expect(has(rows, "Damage  28  +")).toBeTrue()
		select(screen, "Nightstriker")
		local label = nil
		for _, child in ipairs(GuiFake.findNamed(screen, "Compare"):GetChildren()) do
			if child:IsA("TextLabel") and child.Text == "Crit Damage  2.00  -" then
				label = child
			end
		end
		expect(label ~= nil).toBeTrue()
	end)

	it("compares shown values in the pure helper", function()
		expect(BagCompare.mark("attack_speed", 1.15, 1.1500001)).toEqual("=")
		expect(BagCompare.mark("attack_speed", 1.2, 1.15)).toEqual("+")
		expect(BagCompare.mark("damage", 20, 28)).toEqual("-")
		expect(BagCompare.equippedUid({ equipped = { weapon = "a" } }, { kind = "Weapon", uid = "b" })).toEqual("a")
	end)
end)

describe("Bag UPGRADE", function()
	it("sends the selected uid, applies the new profile, and toasts", function()
		local next = profile("mace")
		next.gold = 5000 - 1280
		next.inventory.night.upgrade = 3
		local _, screen, calls = open("mace", function(name: string, uid: string)
			if name == "UpgradeGear" then
				return { ok = true, note = "Nightstriker +3", profile = next }
			end
			return { ok = true }
		end)
		select(screen, "Nightstriker")
		local button = upgradeButton(screen)
		expect(button ~= nil).toBeTrue()
		GuiFake.activate(button)
		local sent = calls.invokes[#calls.invokes]
		expect(sent[1]).toEqual("UpgradeGear")
		expect(sent[2]).toEqual("night")
		expect(calls.toasts[#calls.toasts]).toEqual("Upgraded Nightstriker +3")
		local rows = pane(screen)
		expect(has(rows, "Nightstriker  +3")).toBeTrue()
		expect(has(rows, "UPGRADE  2,048")).toBeTrue()
		expect(has(rows, "Upgraded Nightstriker +3")).toBeTrue()
	end)

	it("toasts the price when the server refuses for gold", function()
		local _, screen, calls = open("mace", function(name: string)
			if name == "UpgradeGear" then
				return { ok = false, error = "Not enough gold." }
			end
			return { ok = true }
		end)
		select(screen, "Nightstriker")
		GuiFake.activate(upgradeButton(screen))
		expect(calls.toasts[#calls.toasts]).toEqual("Need 1,280 gold")
		local rows = pane(screen)
		expect(has(rows, "Need 1,280 gold")).toBeTrue()
		expect(has(rows, "Nightstriker  +2")).toBeTrue()
	end)

	it("passes other refusals through and survives a thrown remote", function()
		local _, screen, calls = open("mace", function(name: string)
			if name == "UpgradeGear" then
				error("boom")
			end
			return { ok = true }
		end)
		select(screen, "Mycelium Staff")
		GuiFake.activate(upgradeButton(screen))
		expect(calls.toasts[#calls.toasts]).toEqual("Could not upgrade that.")
		expect(BagCompare.refusal("Needs boss bark.", {})).toEqual("Needs boss bark.")
	end)
end)

describe("Forge upgrade on the server data", function()
	it("charges nothing when it refuses", function()
		local data = { gold = 299, materials = {}, inventory = {} }
		local item = { uid = "a", name = "A", upgrade = 1 }
		local done, reason = Economy.upgrade(item, data)
		expect(done).toBeFalse()
		expect(reason).toEqual("Not enough gold.")
		expect(data.gold).toEqual(299)
		expect(item.upgrade).toEqual(1)
		local deep = { uid = "b", name = "B", upgrade = 7 }
		local rich = { gold = 100000, materials = {}, inventory = {} }
		done, reason = Economy.upgrade(deep, rich)
		expect(done).toBeFalse()
		expect(reason).toEqual("Needs boss bark.")
		expect(rich.gold).toEqual(100000)
		expect(deep.upgrade).toEqual(7)
		local capped = { uid = "c", name = "C", upgrade = 10 }
		done = Economy.upgrade(capped, rich)
		expect(done).toBeFalse()
		expect(rich.gold).toEqual(100000)
	end)

	it("charges once and levels only the item passed", function()
		local staff = { uid = "staff", name = "Mycelium Staff", upgrade = 1 }
		local mace = { uid = "mace", name = "Mace", upgrade = 0 }
		local data = { gold = 1000, materials = {}, inventory = { staff = staff, mace = mace } }
		local done, note = Economy.upgrade(data.inventory.staff, data)
		expect(done).toBeTrue()
		expect(note).toEqual("Mycelium Staff +2")
		expect(data.gold).toEqual(700)
		expect(staff.upgrade).toEqual(2)
		expect(mace.upgrade).toEqual(0)
	end)
end)
