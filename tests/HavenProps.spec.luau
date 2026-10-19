--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Haven = require("../src/ReplicatedStorage/Shared/Haven")
local HavenProps = require("../src/ReplicatedStorage/Shared/HavenProps")
local PropAssets = require("../src/ReplicatedStorage/Shared/PropAssets")

local function far(spot, x: number, z: number, gap: number): boolean
	return math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2) >= gap
end

describe("HavenProps", function()
	it("keeps every crystal on the plaza and off the central pedestal", function()
		for _, spot in ipairs(HavenProps.SPOTS) do
			local r = math.sqrt(spot.x ^ 2 + spot.z ^ 2)
			expect(r).toBeLessThan(Haven.PLAZA_RADIUS - 4)
			expect(r).toBeGreaterThan(14)
			expect(PropAssets[spot.kind] ~= nil).toBeTrue()
		end
	end)
	it("stays clear of the spawn and the stations", function()
		local keep = {
			{ Haven.SPAWN.x, Haven.SPAWN.z, 12 },
			{ Haven.ARMORY.x, Haven.ARMORY.z, 12 },
			{ Haven.ARMORY.x, Haven.ARMORY.z + 6, 10 },
			{ Haven.SHRINE.x, Haven.SHRINE.z, 10 },
			{ Haven.GROVE.x, Haven.GROVE.z, 12 },
			{ Haven.SHOP.x, Haven.SHOP.z, 12 },
		}
		for _, spot in ipairs(HavenProps.SPOTS) do
			for _, k in ipairs(keep) do
				expect(far(spot, k[1], k[2], k[3])).toBeTrue()
			end
		end
	end)
	it("leaves the district bridge lanes open", function()
		for _, district in pairs(Haven.DISTRICTS) do
			local lane = math.atan2(district.z, district.x)
			for _, spot in ipairs(HavenProps.SPOTS) do
				local d = math.abs(math.atan2(spot.z, spot.x) - lane)
				if d > math.pi then
					d = 2 * math.pi - d
				end
				expect(math.deg(d)).toBeGreaterThan(12)
			end
		end
	end)
	it("scales a mesh to the target height", function()
		expect(HavenProps.scaleFor({ X = 2, Y = 4, Z = 2 }, 10)).toBeCloseTo(2.5)
		expect(HavenProps.scaleFor({ X = 2, Y = 0, Z = 2 }, 10)).toEqual(1)
	end)
end)
