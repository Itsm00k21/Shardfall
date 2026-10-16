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
end)
