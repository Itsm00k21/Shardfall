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

	it("gives Rootvault a wider floor, a lit crawl, and spread spawns", function()
		local dungeon = Dungeons.get(Dungeons.ROOTVAULT_ID)
		assert(dungeon ~= nil)
		local waves = Dungeons.get(Dungeons.WAVES_ID)
		assert(waves ~= nil)
		local oldArea = 56 * 56
		local area = dungeon.floorSize * dungeon.floorSize
		expect(dungeon.floorSize).toEqual(Dungeons.FLOOR_SIZE)
		expect(waves.floorSize).toEqual(Dungeons.FLOOR_SIZE)
		expect(area >= oldArea * 1.6).toBeTrue()
		expect(area <= oldArea * 2).toBeTrue()
		expect(Dungeons.CORRIDOR_WIDTH >= 16).toBeTrue()
		expect(Dungeons.WALL_HEIGHT > 7).toBeTrue()
		expect(Dungeons.CAMERA_MAX_ZOOM < Dungeons.FLOOR_SIZE / 2 - 8).toBeTrue()
		local half = dungeon.floorSize / 2 - 4
		local margin = Dungeons.FLOOR_SIZE / 2 - math.abs(Dungeons.SPAWN_Z)
		expect(margin > Dungeons.CAMERA_MAX_ZOOM).toBeTrue()
		expect(#Dungeons.ENEMY_SPAWNS >= Dungeons.WAVE_MAX_COUNT).toBeTrue()
		for index, spot in ipairs(Dungeons.ENEMY_SPAWNS) do
			expect(math.abs(spot.x) <= half).toBeTrue()
			expect(math.abs(spot.z) <= half).toBeTrue()
			for other = index + 1, #Dungeons.ENEMY_SPAWNS do
				local nextSpot = Dungeons.ENEMY_SPAWNS[other]
				local dx = spot.x - nextSpot.x
				local dz = spot.z - nextSpot.z
				expect(dx * dx + dz * dz >= 12 * 12).toBeTrue()
			end
		end
		local lights = Dungeons.lightLayout(dungeon.floorSize)
		local torches = 0
		local floors = 0
		for _, light in ipairs(lights) do
			expect(math.abs(light.x) < dungeon.floorSize / 2).toBeTrue()
			expect(math.abs(light.z) < dungeon.floorSize / 2).toBeTrue()
			if light.kind == "torch" then
				torches += 1
			elseif light.kind == "floor" then
				floors += 1
				expect(light.y < 5).toBeTrue()
			end
		end
		expect(torches >= 4).toBeTrue()
		expect(floors >= 2).toBeTrue()
		local night = { ambient = { 48, 42, 72 }, outdoor = { 70, 64, 96 }, brightness = 1.15 }
		local crawl = Dungeons.CRAWL_LIGHT
		expect(crawl.brightness > night.brightness).toBeTrue()
		for channel = 1, 3 do
			expect(crawl.ambient[channel] > night.ambient[channel]).toBeTrue()
			expect(crawl.outdoor[channel] > night.outdoor[channel]).toBeTrue()
		end
		expect(Dungeons.RIM.fillTransparency > 0.7).toBeTrue()
		expect(Dungeons.RIM.outlineTransparency > 0).toBeTrue()
		expect(Dungeons.RIM.outlineTransparency < 0.5).toBeTrue()
		local _, _, roomZ = Dungeons.roomOrigin(1)
		expect(Dungeons.inCrawl(0, roomZ)).toBeTrue()
		expect(Dungeons.inCrawl(0, 30)).toBeFalse()
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
		expect(lucky.gold).toEqual(360)
		local rewards = dungeon.rewards
		assert(rewards ~= nil)
		expect(rewards.gold).toEqual(360)
		local heartwood = Dungeons.get(Dungeons.HEARTWOOD_ID)
		assert(heartwood ~= nil)
		local raidGold = heartwood.rewards
		assert(raidGold ~= nil)
		expect(raidGold.gold).toEqual(480)
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

	it("scales wave count, hit points, and damage, with a boss every fifth wave", function()
		local waves = Dungeons.get(Dungeons.WAVES_ID)
		assert(waves ~= nil)
		expect(waves.endless).toEqual(true)
		expect(waves.implemented).toEqual(true)
		expect(#waves.rooms).toEqual(1)

		expect(Dungeons.waveCount(1)).toEqual(2)
		expect(Dungeons.waveCount(3)).toEqual(3)
		expect(Dungeons.waveCount(20)).toEqual(Dungeons.WAVE_MAX_COUNT)
		expect(#Dungeons.waveKinds(1)).toEqual(2)
		expect(Dungeons.isBossWave(4)).toEqual(false)
		expect(Dungeons.isBossWave(5)).toEqual(true)
		expect(Dungeons.isBossWave(10)).toEqual(true)

		local hp, damage = Dungeons.waveStats(36, 8, 1, false)
		expect(hp).toEqual(36)
		expect(damage).toEqual(8)

		local hp2, damage2 = Dungeons.waveStats(36, 8, 2, false)
		expect(hp2).toEqual(math.floor(36 * (1 + Dungeons.WAVE_HP_PER) + 0.5))
		expect(damage2).toEqual(math.floor(8 * (1 + Dungeons.WAVE_DAMAGE_PER) + 0.5))
		expect(hp2).toBeGreaterThan(hp)
		expect(damage2).toBeGreaterThan(damage)

		local scale = Dungeons.waveMultiplier(5, Dungeons.WAVE_HP_PER) * Dungeons.WAVE_BOSS_HP
		local damageScale = Dungeons.waveMultiplier(5, Dungeons.WAVE_DAMAGE_PER)
			* Dungeons.WAVE_BOSS_DAMAGE
		local bossHp, bossDamage = Dungeons.waveStats(220, 18, 5, true)
		expect(bossHp).toEqual(math.floor(220 * scale + 0.5))
		expect(bossDamage).toEqual(math.floor(18 * damageScale + 0.5))
		local addHp = Dungeons.waveStats(36, 8, 5, false)
		expect(addHp).toBeLessThan(bossHp)

		local kinds = Dungeons.waveKinds(5)
		expect(kinds[1]).toEqual("grandmother_gnarl")
		expect(#kinds).toEqual(3)

		local first = Dungeons.waveReward(1)
		expect(first.gold).toEqual(88)
		expect(first.xp).toEqual(8)
		expect(first.shardTokens).toEqual(0)
		expect(first.materials.wood).toEqual(1)

		local fifth = Dungeons.waveReward(5)
		expect(fifth.gold).toEqual(184)
		expect(Dungeons.waveReward(10).gold).toEqual(304)
		expect(Dungeons.waveReward(20).gold).toEqual(544)
		expect(fifth.shardTokens).toEqual(2)
		expect(fifth.materials.bark).toEqual(1)
		expect(fifth.gold).toBeGreaterThan(first.gold)
	end)
end)
