--!strict

local fs = require("@lune/fs")

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

	it("keeps the combat buttons off the 2x4 bar on a landscape phone", function()
		local views = {
			{ 390, 844 },
			{ 844, 390 },
		}
		for _, view in ipairs(views) do
			local vx = view[1]
			local vy = view[2]
			local cluster = CombatCluster.place(vx, vy)
			local paid = CombatCluster.place(vx, vy, { paid = true })
			expect(paid.attack.x).toEqual(cluster.attack.x)
			expect(paid.dodge.y).toEqual(cluster.dodge.y)
			expect(paid.jump.w).toEqual(cluster.jump.w)
			expect(paid.heavy.x).toEqual(cluster.heavy.x)
			local bar = ActionSlots.placement(vx, vy, true)
			local block = { x = bar.x, y = bar.y, w = bar.w, h = bar.h }
			local joy = ActionSlots.joystick(vy)
			local named = {
				{ "attack", cluster.attack },
				{ "dodge", cluster.dodge },
				{ "jump", cluster.jump },
				{ "heavy", cluster.heavy },
			}
			for index, row in ipairs(named) do
				inside(row[2], vx, vy)
				clearOf(row[2], block)
				clearOf(row[2], joy)
				for other = index + 1, #named do
					expect(ActionSlots.overlaps(row[2], named[other][2])).toEqual(false)
				end
			end
		end
		local wide = CombatCluster.place(1024, 768, nil, true)
		local wideBar = ActionSlots.placement(1024, 768, true)
		clearOf(wide.attack, { x = wideBar.x, y = wideBar.y, w = wideBar.w, h = wideBar.h })
		clearOf(wide.dodge, { x = wideBar.x, y = wideBar.y, w = wideBar.w, h = wideBar.h })
		clearOf(wide.jump, { x = wideBar.x, y = wideBar.y, w = wideBar.w, h = wideBar.h })
		inside(wide.attack, 1024, 768)
		local barSource =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau")
		expect(
			string.find(barSource, "CombatCluster.place(size.X, size.Y, nil, mobile)", 1, true) ~= nil
		).toBeTrue()
		expect(string.find(barSource, "size.Y < 500", 1, true) ~= nil).toBeTrue()
	end)
end)
