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
			local jumpX = vx - 80
			local jumpY = vy - 80
			local slots = HudLayout.skills(vx, vy, jumpX, jumpY, 70, 44)
			expect(#slots).toEqual(5)
			for _, slot in ipairs(slots) do
				expect(slot.x + slot.w <= jumpX).toBeTrue()
				expect(slot.x >= 0).toBeTrue()
				expect(slot.y >= 0).toBeTrue()
			end
		end
	end)
end)
