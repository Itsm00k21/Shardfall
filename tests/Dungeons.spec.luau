--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")

local function zeroRng()
	return {
		nextNumber = function()
			return 0
		end,
		nextInteger = function(_self, min, _max)
			return min
		end,
	}
end

local function highRng()
	return {
		nextNumber = function()
			return 0.99
		end,
		nextInteger = function(_self, _min, max)
			return max
		end,
	}
end

describe("Dungeons", function()
	it("builds Rootvault as four rooms ending in the boss", function()
		local dungeon = Dungeons.get(Dungeons.ROOTVAULT_ID)
		assert(dungeon ~= nil)
		expect(dungeon.ascension).toEqual(0)
		expect(dungeon.implemented).toEqual(true)
		expect(dungeon.realm).toEqual("Verdant Wilds")
		expect(#dungeon.rooms).toEqual(4)
		expect(dungeon.rooms[1].name).toEqual("Choked Thicket")
		expect(dungeon.rooms[4].enemies[1]).toEqual("grandmother_gnarl")
		local boss = Dungeons.enemy("grandmother_gnarl")
		assert(boss ~= nil)
		expect(boss.boss).toEqual(true)
		expect(boss.weakSeconds > 0).toEqual(true)
		expect(Dungeons.isUnlocked(dungeon, 0)).toEqual(true)
	end)

	it("keeps the next realm locked until its ascension and unimplemented after that", function()
		local tide = Dungeons.get("tidecrypt")
		assert(tide ~= nil)
		expect(tide.ascension).toEqual(1)
		expect(tide.implemented).toEqual(false)
		expect(Dungeons.isUnlocked(tide, 0)).toEqual(false)
		expect(Dungeons.isUnlocked(tide, 1)).toEqual(true)
		expect(Dungeons.progressNote(0)).toEqual("Tidecrypt unlocks at Ascension 1.")
		expect(Dungeons.progressNote(1)).toEqual("Tidecrypt is unlocked and not built yet.")
	end)

	it("spaces rooms down the Z axis and flips the boss into phase 2 at half health", function()
		local _, _, z1 = Dungeons.roomOrigin(1)
		local _, _, z2 = Dungeons.roomOrigin(2)
		expect(z2 - z1).toEqual(Dungeons.ROOM_SPACING)
		expect(Dungeons.bossPhase(200, 220, 0.5)).toEqual(1)
		expect(Dungeons.bossPhase(110, 220, 0.5)).toEqual(2)
	end)

	it("rolls placeholder clear rewards, including a voucher and heartwood", function()
		local dungeon = Dungeons.get(Dungeons.ROOTVAULT_ID)
		assert(dungeon ~= nil)
		local lucky = Dungeons.rollClear(dungeon, zeroRng())
		assert(lucky ~= nil)
		expect(lucky.gold).toEqual(45)
		expect(lucky.shardTokens).toEqual(3)
		expect(lucky.materials.wood).toEqual(4)
		expect(lucky.materials.vine).toEqual(3)
		expect(lucky.materials.heartwood).toEqual(1)
		expect(lucky.voucher).toEqual("armory")

		local plain = Dungeons.rollClear(dungeon, highRng())
		assert(plain ~= nil)
		expect(plain.materials.heartwood).toBeNil()
		expect(plain.voucher).toBeNil()
		expect(plain.materials.bark).toEqual(1)
	end)
end)
