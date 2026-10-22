--!strict

--[[
	Spawn clearance: Kevin's clip had Grandmother Gnarl spawn clipped into a
	wall and a slope. Footprints clamp inside the floor, bosses take the open
	BOSS_SPAWN spot, and the built rig steps inward until its box is clear.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local DungeonConfig = require("../src/ReplicatedStorage/Shared/DungeonConfig")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")

describe("Spawn clearance", function()
	it("keeps Gnarl's footprint off every wall from every pad", function()
		local gnarl = Dungeons.enemy("grandmother_gnarl")
		local half = Dungeons.FLOOR_SIZE / 2
		local hx, hz = gnarl.size[1] / 2, gnarl.size[3] / 2
		for _, pad in ipairs(Dungeons.ENEMY_SPAWNS) do
			local x, z = DungeonConfig.insideFloor(pad.x * 2, pad.z * 2, hx, hz, half)
			expect(math.abs(x) + hx <= half - DungeonConfig.SPAWN_MARGIN + 1e-6).toBeTrue()
			expect(math.abs(z) + hz <= half - DungeonConfig.SPAWN_MARGIN + 1e-6).toBeTrue()
		end
	end)

	it("puts the boss spot well inside the floor, away from the player spawn", function()
		local gnarl = Dungeons.enemy("grandmother_gnarl")
		local x, z = DungeonConfig.insideFloor(DungeonConfig.BOSS_SPAWN.x, DungeonConfig.BOSS_SPAWN.z, gnarl.size[1] / 2, gnarl.size[3] / 2, Dungeons.FLOOR_SIZE / 2)
		expect(x).toEqual(DungeonConfig.BOSS_SPAWN.x)
		expect(z).toEqual(DungeonConfig.BOSS_SPAWN.z)
		expect(math.abs(z - Dungeons.SPAWN_Z) >= 20).toBeTrue()
	end)

	it("steps inward and stops at the centre", function()
		local x, z = DungeonConfig.stepInward(10, 0)
		expect(x).toBeCloseTo(10 - DungeonConfig.SPAWN_STEP, 1e-6)
		expect(z).toEqual(0)
		local cx, cz = DungeonConfig.stepInward(1, 1)
		expect(cx).toEqual(0)
		expect(cz).toEqual(0)
		-- Enough tries to walk from the far corner to the middle.
		expect(DungeonConfig.SPAWN_TRIES * DungeonConfig.SPAWN_STEP >= Dungeons.FLOOR_SIZE / 2 * 0.7).toBeTrue()
	end)

	it("tests the built rig's box against solid parts and shifts it", function()
		local src = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(src, "workspace:GetPartBoundsInBox(", 1, true) ~= nil).toBeTrue()
		expect(string.find(src, "clearSpawn(if rigModel ~= nil then rigModel else part, run, offset.X, offset.Z)", 1, true) ~= nil).toBeTrue()
	end)
end)
