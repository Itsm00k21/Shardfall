--!strict

--[[
	Boss health: Kevin's clip had Grandmother Gnarl (flat 220 HP) die to one
	131 hit. Bosses now size to the run owner's weapon so a Normal fight
	takes 30-45s, with a per-level floor.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local DungeonConfig = require("../src/ReplicatedStorage/Shared/DungeonConfig")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")

local GNARL = Dungeons.enemy("grandmother_gnarl").maxHealth

describe("Boss health", function()
	it("reads expected weapon DPS with crits", function()
		expect(DungeonConfig.playerDps({ damage = 100, attackSpeed = 1.2, critChance = 0.2, critDamage = 1.5 })).toBeCloseTo(132, 3)
		expect(DungeonConfig.playerDps(nil)).toEqual(0)
		expect(DungeonConfig.playerDps({ damage = 0 / 0, attackSpeed = 1 })).toEqual(0)
	end)

	it("lands the Normal fight inside the 30-45s band for weak and strong builds", function()
		for _, dps in ipairs({ 60, 131, 250, 900 }) do
			local hp = DungeonConfig.bossHealth(GNARL, dps, 3)
			local seconds = DungeonConfig.fightSeconds(hp, dps)
			expect(seconds >= DungeonConfig.BOSS_FIGHT_MIN).toBeTrue()
			expect(seconds <= DungeonConfig.BOSS_FIGHT_MAX).toBeTrue()
		end
	end)

	it("no longer drops to one 131 hit", function()
		local hp = DungeonConfig.bossHealth(GNARL, 131 * 0.9, 3)
		expect(hp > 131 * 10).toBeTrue()
	end)

	it("keeps a level floor for unarmed starts", function()
		expect(DungeonConfig.bossHealth(GNARL, 0, 1)).toEqual(GNARL)
		expect(DungeonConfig.bossHealth(GNARL, 0, 5)).toEqual(GNARL + 4 * DungeonConfig.BOSS_HP_PER_LEVEL)
	end)

	it("is wired into boss spawns and drops the 'then' stutter", function()
		local src = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(src, "DungeonConfig.bossHealth(health, run.bossDps, run.bossLevel)", 1, true) ~= nil).toBeTrue()
		expect(string.find(src, "Slam, then", 1, true)).toEqual(nil)
	end)
end)
