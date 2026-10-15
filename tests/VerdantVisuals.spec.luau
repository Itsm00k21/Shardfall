--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ModelFactory = require("../src/ReplicatedStorage/Shared/ModelFactory")
local VerdantLook = require("../src/ReplicatedStorage/Shared/VerdantLook")
local VerdantScatter = require("../src/ReplicatedStorage/Shared/VerdantScatter")

local function sameSpots(left: { VerdantScatter.Spot }, right: { VerdantScatter.Spot }): boolean
	if #left ~= #right then
		return false
	end
	for index, spot in ipairs(left) do
		local other = right[index]
		if
			spot.kind ~= other.kind
			or spot.x ~= other.x
			or spot.z ~= other.z
			or spot.y ~= other.y
			or spot.yaw ~= other.yaw
			or spot.scale ~= other.scale
		then
			return false
		end
	end
	return true
end

describe("Verdant visuals", function()
	it("builds every monster and tree from a bounded part recipe", function()
		expect(#ModelFactory.TREES >= 4).toBeTrue()
		for _, kind in ipairs(ModelFactory.MONSTERS) do
			local count = ModelFactory.partCount(kind)
			expect(count > 0).toBeTrue()
			expect(count <= ModelFactory.MONSTER_BUDGET).toBeTrue()
			local recipe = ModelFactory.recipe(kind)
			assert(recipe ~= nil)
			for _, piece in ipairs(recipe) do
				expect(piece.collide == nil or piece.collide == false).toBeTrue()
				if piece.lod == "small" then
					expect(piece.size[1] <= 2.5 and piece.size[2] <= 2.5 and piece.size[3] <= 2.5).toBeTrue()
				end
			end
		end
		for _, kind in ipairs(ModelFactory.TREES) do
			expect(ModelFactory.partCount(kind) >= 4).toBeTrue()
		end
		local boss = ModelFactory.scaleOf("grandmother_gnarl")
		expect(boss >= 4 and boss <= 6).toBeTrue()
		expect(ModelFactory.scaleOf("vine_crawler") < 2).toBeTrue()
		expect(ModelFactory.partCount("grandmother_gnarl")).toEqual(
			#(ModelFactory.layout("grandmother_gnarl", 1) :: any)
		)
		expect(ModelFactory.barLift("grandmother_gnarl") > ModelFactory.barLift("vine_crawler")).toBeTrue()
	end)

	it("keeps limb motion deterministic", function()
		local pitch, bob = ModelFactory.motion("spore_bat", "wing", 0.2, true)
		local againPitch, againBob = ModelFactory.motion("spore_bat", "wing", 0.2, true)
		expect(pitch).toEqual(againPitch)
		expect(bob).toEqual(againBob)
		local idle = ModelFactory.motion("spore_bat", "wing", 0.2, false)
		expect(math.abs(pitch) > math.abs(idle)).toBeTrue()
		local _, floatBob = ModelFactory.motion("thorn_sprite", "float", 0.4, false)
		expect(floatBob ~= 0).toBeTrue()
		local segment = ModelFactory.motion("vine_crawler", "segment", 0.2, true)
		expect(segment ~= pitch).toBeTrue()
	end)

	it("scatters the same forest from the same seed and stays inside the budget", function()
		local half = 28
		local first = VerdantScatter.room(9189, half, "wild")
		local second = VerdantScatter.room(9189, half, "wild")
		expect(sameSpots(first, second)).toBeTrue()
		expect(sameSpots(first, VerdantScatter.room(200, half, "wild"))).toBeFalse()
		expect(VerdantScatter.partTotal(first) <= VerdantScatter.ROOM_BUDGET).toBeTrue()
		expect(VerdantScatter.partTotal(first) > 20).toBeTrue()

		local seen: { [string]: boolean } = {}
		for _, spot in ipairs(first) do
			seen[spot.kind] = true
			expect(math.abs(spot.x) >= VerdantScatter.PATH_HALF).toBeTrue()
			expect(spot.y >= VerdantScatter.FEET_Y).toBeTrue()
			local spawn = spot.x * spot.x + (spot.z + 16) * (spot.z + 16)
			expect(spawn >= 64).toBeTrue()
			local portal = spot.x * spot.x + (spot.z - 18) * (spot.z - 18)
			expect(portal >= 64).toBeTrue()
			for _, desc in
				ipairs(
					ModelFactory.compose(spot.kind, spot.x, spot.y, spot.z, spot.yaw, spot.scale)
				)
			do
				expect(desc.collide).toBeFalse()
				if desc.lod == "small" then
					expect(desc.shadow).toBeFalse()
				end
			end
		end
		for _, kind in ipairs(ModelFactory.TREES) do
			expect(seen[kind]).toBeTrue()
		end

		local arena = VerdantScatter.room(4000, half, "arena")
		expect(VerdantScatter.partTotal(arena) <= VerdantScatter.ROOM_BUDGET).toBeTrue()
		local rings = 0
		for _, spot in ipairs(arena) do
			if spot.kind == "root_ring" then
				rings += 1
			end
			if spot.kind ~= "root_ring" then
				expect(spot.x * spot.x + spot.z * spot.z >= 12 * 12).toBeTrue()
			end
		end
		expect(rings >= 4).toBeTrue()
		print(
			string.format(
				"[Shardfall] Verdant parts wild=%d arena=%d bossPieces=%d",
				VerdantScatter.partTotal(first),
				VerdantScatter.partTotal(arena),
				ModelFactory.partCount("grandmother_gnarl")
			)
		)
	end)

	it("keeps Haven dressing under budget and off the walk tops", function()
		local parts = VerdantScatter.haven()
		expect(#parts <= VerdantScatter.HAVEN_BUDGET).toBeTrue()
		expect(#parts >= 20).toBeTrue()
		local lanterns = 0
		local banners = 0
		local motes = 0
		for _, desc in ipairs(parts) do
			expect(desc.collide).toBeFalse()
			if desc.lod == "small" then
				expect(desc.shadow).toBeFalse()
			end
			if desc.name == "Lantern" or desc.name == "LanternPost" then
				lanterns += 1
			elseif desc.name == "Banner" then
				banners += 1
			elseif desc.particle == "fireflies" then
				motes += 1
			end
		end
		expect(lanterns >= 6).toBeTrue()
		expect(banners >= 4).toBeTrue()
		expect(motes >= 4).toBeTrue()
		local look = VerdantLook.PRESET
		expect(look.atmosphere.density > 0).toBeTrue()
		expect(look.colorCorrection.saturation > 0).toBeTrue()
		expect(look.bloom.intensity > 0).toBeTrue()
		expect(look.sunRays.intensity > 0).toBeTrue()
		expect(VerdantLook.MARKERS.sapling).toEqual("tree_pine")
		expect(VerdantLook.MARKERS.saplingCount).toEqual(3)
		expect(VerdantLook.MARKERS.slam.name).toEqual("RootSlam")
		expect(VerdantLook.MARKERS.spore.name).toEqual("SporeCloud")
		print(string.format("[Shardfall] Haven dressing parts=%d", #parts))
	end)
end)
