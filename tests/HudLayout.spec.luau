--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")

describe("Hud layout", function()
	it("keeps the shell inside 1280, 1920, and 844", function()
		local views = {
			{ 1280, 800 },
			{ 1920, 1080 },
			{ 844, 390 },
		}
		for _, view in ipairs(views) do
			local vx = view[1]
			local vy = view[2]
			local margin = 16
			local face = HudLayout.portrait(margin)
			local health = HudLayout.health(margin)
			local pills = HudLayout.pills(vx, margin)
			local rail = HudLayout.rail(vy, margin, 6, 64)
			local toast = HudLayout.toast(vx, margin)
			local hub = HudLayout.hub(vx, vy, margin)
			local empty = HudLayout.bottomLeftEmpty(vx, vy)
			expect(face.x >= margin).toBeTrue()
			expect(health.x >= face.x + face.w).toBeTrue()
			expect(pills.x + pills.w <= vx - margin + 0.01).toBeTrue()
			expect(pills.y >= margin).toBeTrue()
			expect(rail.x >= margin).toBeTrue()
			expect(toast.y >= health.y + health.h).toBeTrue()
			expect(hub.x >= 0 and hub.y >= margin).toBeTrue()
			expect(hub.x + hub.w <= vx).toBeTrue()
			expect(hub.y + hub.h <= vy).toBeTrue()
			expect(empty.x).toEqual(0)
			local body = HudLayout.hubBody(hub.w, hub.h)
			local tabs = HudLayout.tabColumn(hub.w, hub.h)
			expect(tabs.x >= 0 and tabs.y >= 0).toBeTrue()
			expect(tabs.x + tabs.w <= hub.w).toBeTrue()
			expect(body.x >= tabs.x + tabs.w).toBeTrue()
			expect(body.x + body.w <= hub.w).toBeTrue()
			expect(body.y + body.h <= hub.h).toBeTrue()
			expect(body.w >= 44 and body.h >= 44).toBeTrue()
			local grid = HudLayout.cardGrid(body.w, body.h, 8)
			expect(grid.cellW >= 44).toBeTrue()
			expect(grid.cellH >= 44).toBeTrue()
			expect(grid.columns >= 1).toBeTrue()
			local span = grid.columns * grid.cellW + (grid.columns - 1) * grid.gap
			expect(span <= body.w + 0.01).toBeTrue()
			local railFit = HudLayout.railFit(vy, margin, 7, 64, 44)
			expect(railFit.button >= 44).toBeTrue()
			expect(railFit.x >= margin).toBeTrue()
			expect(railFit.y + railFit.h <= vy).toBeTrue()
			local jumpX = vx - 80
			local jumpY = vy - 80
			local slots = HudLayout.skills(vx, vy, jumpX, jumpY, 70, 44)
			expect(#slots).toEqual(5)
			for _, slot in ipairs(slots) do
				expect(slot.x + slot.w <= jumpX).toBeTrue()
				expect(slot.x >= 0).toBeTrue()
				expect(slot.y >= 0).toBeTrue()
			end
			local stamp = HudLayout.stamp(vy, margin, false, false)
			expect(stamp ~= nil).toBeTrue()
			if stamp ~= nil then
				expect(stamp.x >= margin).toBeTrue()
				expect(stamp.y + stamp.h <= vy).toBeTrue()
			end
			expect(HudLayout.stamp(vy, margin, true, false)).toBeNil()
			expect(HudLayout.stamp(vy, margin, true, true) ~= nil).toBeTrue()
		end
	end)

	it("keeps the stamp off the rail at 1280x720 and 844x390", function()
		expect(HudLayout.breakpoint(844, 390)).toEqual("phone")
		expect(HudLayout.breakpoint(1024, 768)).toEqual("tablet")
		expect(HudLayout.breakpoint(1280, 720)).toEqual("console")
		expect(HudLayout.breakpoint(1920, 1080)).toEqual("pc")
		local views = {
			{ 1280, 720 },
			{ 844, 390 },
		}
		for _, view in ipairs(views) do
			local margin = 16
			local rail = HudLayout.railFit(view[2], margin, 7, 64, 44)
			expect(rail.button >= 44).toBeTrue()
			local stamp = HudLayout.stamp(view[2], margin, false, false, rail.x + rail.w + 12)
			expect(stamp ~= nil).toBeTrue()
			if stamp ~= nil then
				local railRect = { x = rail.x, y = rail.y, w = rail.w, h = rail.h }
				expect(HudLayout.overlaps(railRect, stamp)).toEqual(false)
				expect(stamp.x + stamp.w <= view[1]).toBeTrue()
				expect(stamp.y + stamp.h <= view[2]).toBeTrue()
			end
		end
	end)
end)
