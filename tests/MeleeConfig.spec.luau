--!strict

--[[
	MeleeConfig: Kevin's Oct 19 playtest said every melee hit needed the
	player about half a body length away. Reach is now 7-8 studs from the
	root to the target's edge with a 100 degree front cone, all in config.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CombatMath = require("../src/ReplicatedStorage/Shared/CombatMath")
local MeleeConfig = require("../src/ReplicatedStorage/Shared/MeleeConfig")

describe("MeleeConfig", function()
	it("gives unarmed and every melee weapon a comfortable reach", function()
		expect(MeleeConfig.reach("unarmed") >= 7).toBeTrue()
		for _, kind in ipairs({ "unarmed", "dagger", "sword", "greatsword", "hammer" }) do
			local reach = MeleeConfig.reach(kind)
			expect(reach >= 7 and reach <= 10).toBeTrue()
			expect(MeleeConfig.coneDeg(kind)).toEqual(100)
		end
		expect(MeleeConfig.reach("sword")).toEqual(8)
		expect(MeleeConfig.reach("nonsense")).toEqual(MeleeConfig.DEFAULT_REACH)
	end)

	it("turns the 100 degree cone into a dot threshold", function()
		expect(MeleeConfig.minDot("sword")).toEqual(0.643)
	end)

	it("is what CombatMath uses for melee loadouts", function()
		expect(CombatMath.UNARMED.range).toEqual(MeleeConfig.reach("unarmed"))
		expect(CombatMath.UNARMED.minDot).toEqual(MeleeConfig.minDot("unarmed"))
		for _, kind in ipairs({ "dagger", "sword", "greatsword", "hammer" }) do
			expect(CombatMath.STYLES[kind].range).toEqual(MeleeConfig.reach(kind))
			expect(CombatMath.STYLES[kind].minDot).toEqual(MeleeConfig.minDot(kind))
		end
	end)

	it("clamps the target radius", function()
		expect(MeleeConfig.targetRadius(4, 2)).toEqual(2)
		expect(MeleeConfig.targetRadius(40, 40)).toEqual(MeleeConfig.MAX_TARGET_RADIUS)
		expect(MeleeConfig.targetRadius(0 / 0, nil)).toEqual(0)
	end)
end)

describe("Melee reach in play terms", function()
	local sword = CombatMath.STYLES.sword

	it("hits a small enemy 7.5 studs ahead and misses at 9", function()
		expect(CombatMath.hitsMelee(0, 0, 0, -1, 0, -7.5, sword.range, sword.minDot, 1)).toBeTrue()
		expect(CombatMath.hitsMelee(0, 0, 0, -1, 0, -9.5, sword.range, sword.minDot, 1)).toBeFalse()
	end)

	it("measures to a big enemy's edge, not its centre", function()
		-- A boss 6 studs wide (radius 3) centred 10.5 studs away is 7.5 to the edge.
		expect(CombatMath.hitsMelee(0, 0, 0, -1, 0, -10.5, sword.range, sword.minDot, 3)).toBeTrue()
		expect(CombatMath.hitsMelee(0, 0, 0, -1, 0, -10.5, sword.range, sword.minDot)).toBeFalse()
	end)

	it("keeps a 100 degree front cone and never whiffs when hugging", function()
		local at40 = math.rad(40)
		local at60 = math.rad(60)
		expect(CombatMath.hitsMelee(0, 0, 0, -1, math.sin(at40) * 6, -math.cos(at40) * 6, sword.range, sword.minDot, 0)).toBeTrue()
		expect(CombatMath.hitsMelee(0, 0, 0, -1, math.sin(at60) * 6, -math.cos(at60) * 6, sword.range, sword.minDot, 0)).toBeFalse()
		-- Behind but touching: still a hit.
		expect(CombatMath.hitsMelee(0, 0, 0, -1, 0, 2.5, sword.range, sword.minDot, 0)).toBeTrue()
	end)

	it("auto-target range uses the same edge distance", function()
		local picked = CombatMath.nearestInRange(0, 0, { { x = 0, z = 10, radius = 3 } }, sword.range)
		expect(picked ~= nil).toBeTrue()
		expect(CombatMath.nearestInRange(0, 0, { { x = 0, z = 10 } }, sword.range)).toBeNil()
	end)

	it("feeds each enemy's radius to the swing test on the server", function()
		local combat = fs.readFile("src/ServerScriptService/ShardfallServer/CombatService.luau")
		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(combat, "offense.minDot,\n\t\t\t\tenemy.radius", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "MeleeConfig.targetRadius(enemy.part.Size.X, enemy.part.Size.Z)", 1, true) ~= nil).toBeTrue()
	end)
end)
