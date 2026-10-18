--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local CombatCluster = require("../src/ReplicatedStorage/Shared/CombatCluster")

local function inside(rect, width, height)
	expect(rect.x >= 0).toBeTrue()
	expect(rect.y >= 0).toBeTrue()
	expect(rect.w > 0).toBeTrue()
	expect(rect.h > 0).toBeTrue()
	expect(rect.x + rect.w <= width).toBeTrue()
	expect(rect.y + rect.h <= height).toBeTrue()
end

local function clearOf(rect, block)
	expect(ActionSlots.overlaps(rect, block)).toEqual(false)
end

describe("CombatCluster", function()
	it("puts a large attack with smaller dodge and jump at the bottom-right", function()
		local desktop = CombatCluster.place(1280, 720)
		local bar = ActionSlots.placement(1280, 720, false)
		local block = { x = bar.x, y = bar.y, w = bar.w, h = bar.h }
		inside(desktop.attack, 1280, 720)
		inside(desktop.dodge, 1280, 720)
		inside(desktop.jump, 1280, 720)
		expect(desktop.attack.w > desktop.dodge.w).toBeTrue()
		expect(desktop.attack.h > desktop.jump.h).toBeTrue()
		expect(desktop.attack.x + desktop.attack.w >= desktop.dodge.x + desktop.dodge.w).toBeTrue()
		expect(desktop.attack.y + desktop.attack.h >= 720 - 24).toBeTrue()
		clearOf(desktop.attack, block)
		clearOf(desktop.dodge, block)
		clearOf(desktop.jump, block)
		local paid = CombatCluster.place(1280, 720, { paid = true, robux = 50 })
		expect(paid.attack.x).toEqual(desktop.attack.x)
		expect(paid.dodge.y).toEqual(desktop.dodge.y)
		expect(paid.jump.w).toEqual(desktop.jump.w)

		local phone = CombatCluster.place(390, 844)
		local phoneBar = ActionSlots.placement(390, 844, true)
		local phoneBlock = { x = phoneBar.x, y = phoneBar.y, w = phoneBar.w, h = phoneBar.h }
		inside(phone.attack, 390, 844)
		inside(phone.dodge, 390, 844)
		inside(phone.jump, 390, 844)
		expect(phone.attack.w > phone.dodge.w).toBeTrue()
		clearOf(phone.attack, phoneBlock)
		clearOf(phone.dodge, phoneBlock)
		clearOf(phone.jump, phoneBlock)
		clearOf(phone.attack, ActionSlots.joystick(844))
		clearOf(phone.dodge, ActionSlots.joystick(844))
		clearOf(phone.jump, ActionSlots.joystick(844))
	end)

	it("marks a new item slot and clears it once the slot has been seen", function()
		local profile = {
			inventory = {
				blade = { uid = "blade", obtainedAt = 10 },
			},
		}
		local slot = { kind = "item", id = "blade" }
		expect(ActionSlots.unseen(slot, profile, 0)).toBeTrue()
		expect(ActionSlots.unseen(slot, profile, 10)).toBeFalse()
		expect(ActionSlots.unseen({ kind = "skill", id = "slash" }, profile, 0)).toBeFalse()
		expect(ActionSlots.unseen(slot, profile, { paid = true })).toBeTrue()
	end)
end)
