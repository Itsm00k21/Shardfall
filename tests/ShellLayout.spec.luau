--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ShellLayout = require("../src/ReplicatedStorage/Shared/ShellLayout")

local VIEWPORTS = {
	{ 800, 380, false },
	{ 1280, 720, false },
	{ 844, 390, true },
}

describe("ShellLayout", function()
	it("treats a keyboard as desktop even when touch is also on", function()
		expect(ShellLayout.mobile(true, true)).toBeFalse()
		expect(ShellLayout.mobile(false, true)).toBeFalse()
		expect(ShellLayout.mobile(false, false)).toBeFalse()
		expect(ShellLayout.mobile(true, false)).toBeTrue()
	end)

	it("keeps inventory and the side panel inside the playtest viewports", function()
		for _, row in ipairs(VIEWPORTS) do
			local vx = row[1]
			local vy = row[2]
			local mobile = row[3]
			local bag = ShellLayout.inventory(vx, vy, mobile)
			expect(bag.w > 0 and bag.w <= vx - 16).toBeTrue()
			expect(bag.h > 0 and bag.h <= vy - 16).toBeTrue()
			-- "Inventory" plus Close and + Slots need a few hundred pixels.
			expect(bag.w >= 400).toBeTrue()
			local side = ShellLayout.sidePanel(vx, vy)
			expect(side.w > 0 and side.w <= vx - 24).toBeTrue()
			expect(side.h > 0 and side.h <= vy - 12).toBeTrue()
			expect(side.w >= 240).toBeTrue()
			local thumb = ShellLayout.thumbSize(vx)
			expect(thumb.h >= 44).toBeTrue()
			expect(thumb.w >= 72).toBeTrue()
			for _, entry in ipairs(ShellLayout.THUMBS) do
				expect(ShellLayout.labelFits(entry.label, thumb.w)).toBeTrue()
			end
			expect(ShellLayout.labelFits("Low", thumb.w)).toBeTrue()
			expect(ShellLayout.labelFits("High", thumb.w)).toBeTrue()
		end
		expect(ShellLayout.TITLE_ROW > 0).toBeTrue()
		expect(ShellLayout.HIDE_ROW >= 44).toBeTrue()
		expect(ShellLayout.BANNER_SECONDS >= 3 and ShellLayout.BANNER_SECONDS <= 4).toBeTrue()
		expect(ShellLayout.ZONE_MAX_DISTANCE <= 80).toBeTrue()
		expect(ShellLayout.ZONE_WIDTH_STUDS > 0).toBeTrue()
		expect(ShellLayout.zoneScale(0)).toEqual(1)
		expect(ShellLayout.zoneVisible(0)).toBeTrue()
		expect(ShellLayout.zoneScale(ShellLayout.ZONE_MAX_DISTANCE) < 1).toBeTrue()
		expect(ShellLayout.zoneVisible(ShellLayout.ZONE_MAX_DISTANCE + 1)).toBeFalse()
		expect(ShellLayout.zoneScale(ShellLayout.ZONE_MAX_DISTANCE + 20)).toEqual(0)
	end)

	it("keeps the always-on chrome from stacking on 1280x800 and a phone", function()
		local viewports = {
			{ 1280, 800 },
			{ 1280, 720 },
			{ 844, 390 },
			{ 800, 380 },
		}
		for _, row in ipairs(viewports) do
			local vx = row[1]
			local vy = row[2]
			local health = ShellLayout.healthRect()
			local pet = ShellLayout.petRect()
			local raid = ShellLayout.raidRect()
			local action = ShellLayout.actionBar(vx, vy)
			local market = ShellLayout.marketButton(vx, vy)
			local loop = ShellLayout.loopRect(vx, vy)
			local cue = ShellLayout.cueRect(vx, vy)
			local debugRow = ShellLayout.debugRect(vx, vy)
			local always = { health, pet, raid, action, market, loop, cue, debugRow }
			for i = 1, #always do
				for j = i + 1, #always do
					expect(ShellLayout.overlaps(always[i], always[j])).toBeFalse()
				end
			end
			expect(action.x >= ShellLayout.LEFT_RESERVE).toBeTrue()
			expect(action.h >= 60).toBeTrue()
			expect(action.y + action.h <= vy).toBeTrue()
			local menu = ShellLayout.menuRect(vx, vy)
			local doors = ShellLayout.doorRect(vx, vy)
			local classBox = ShellLayout.classRect(vx, vy)
			local bag = ShellLayout.inventory(vx, vy, false)
			local bagRect = {
				x = 16,
				y = pet.y + pet.h + 8,
				w = bag.w,
				h = bag.h,
			}
			expect(ShellLayout.overlaps(menu, health)).toBeFalse()
			expect(ShellLayout.overlaps(menu, pet)).toBeFalse()
			expect(ShellLayout.overlaps(menu, raid)).toBeFalse()
			expect(ShellLayout.overlaps(menu, action)).toBeFalse()
			expect(ShellLayout.overlaps(menu, market)).toBeFalse()
			expect(ShellLayout.overlaps(menu, loop)).toBeFalse()
			expect(ShellLayout.overlaps(doors, action)).toBeFalse()
			expect(ShellLayout.overlaps(doors, pet)).toBeFalse()
			expect(ShellLayout.overlaps(doors, raid)).toBeFalse()
			expect(ShellLayout.overlaps(doors, loop)).toBeFalse()
			expect(ShellLayout.overlaps(classBox, doors)).toBeFalse()
			expect(ShellLayout.overlaps(classBox, pet)).toBeFalse()
			expect(ShellLayout.overlaps(classBox, raid)).toBeFalse()
			expect(ShellLayout.overlaps(bagRect, action)).toBeFalse()
			expect(ShellLayout.overlaps(bagRect, loop)).toBeFalse()
			expect(ShellLayout.overlaps(bagRect, pet)).toBeFalse()
			expect(menu.h > 0 and doors.h > 0 and classBox.h > 0).toBeTrue()
			local capture = ShellLayout.captureRect(vx, vy)
			expect(ShellLayout.overlaps(capture, health)).toBeFalse()
			expect(ShellLayout.overlaps(capture, action)).toBeFalse()
			expect(capture.w >= 220 and capture.h >= 64).toBeTrue()
		end
	end)
end)
