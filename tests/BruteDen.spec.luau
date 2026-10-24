--!strict

--[[
	Brute Den playtest tune. Config owns the sprite count, the sprite
	damage, and the room-clear heal. The server applies that heal only
	when Rootvault's den empties.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local BruteDen = require("../src/ReplicatedStorage/Shared/Config/BruteDen")
local Config = require("../src/ReplicatedStorage/Shared/Config/Index")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function countKind(enemies: { string }, kind: string): number
	local count = 0
	for _, id in ipairs(enemies) do
		if id == kind then
			count += 1
		end
	end
	return count
end

describe("Brute Den config", function()
	it("keeps the den tune in Config and under the old sprite pressure", function()
		expect(Config.BruteDen == BruteDen).toBeTrue()
		expect(Schema.VERSION).toEqual(26)
		expect(LaunchGate.SHOW.bruteDen).toBeNil()
		expect((BruteDen :: any).enabled).toBeNil()

		local ok, err = BruteDen.validate(BruteDen)
		expect(ok).toBeTrue()
		expect(err).toBeNil()

		expect(BruteDen.DUNGEON_ID).toEqual(Dungeons.ROOTVAULT_ID)
		expect(BruteDen.ROOM_ID).toEqual("den")
		expect(BruteDen.THORN_COUNT).toEqual(1)
		-- Was 11. Still a whole hit, and strictly less.
		expect(BruteDen.THORN_DAMAGE).toEqual(8)
		expect(BruteDen.THORN_DAMAGE < 11).toBeTrue()
		-- Spring door is 30% of the same unbuffed max. This stays under it.
		expect(BruteDen.CLEAR_HEAL).toEqual(0.2)
		expect(BruteDen.CLEAR_HEAL < 0.3).toBeTrue()

		local sprite = Dungeons.enemy(BruteDen.THORN_KIND)
		assert(sprite ~= nil)
		expect(sprite.damage).toEqual(BruteDen.THORN_DAMAGE)
		expect(sprite.maxHealth).toEqual(40)
		local brute = Dungeons.enemy(BruteDen.BRUTE_KIND)
		assert(brute ~= nil)
		expect(brute.damage).toEqual(14)
		expect(brute.maxHealth).toEqual(78)

		local dungeon = Dungeons.get(Dungeons.ROOTVAULT_ID)
		assert(dungeon ~= nil)
		local den = nil
		local elsewhere = 0
		for _, room in ipairs(dungeon.rooms) do
			local sprites = countKind(room.enemies, BruteDen.THORN_KIND)
			if room.id == BruteDen.ROOM_ID then
				den = room
				expect(room.name).toEqual("Brute Den")
				expect(room.enemies).toEqual(BruteDen.enemies())
				expect(sprites).toEqual(BruteDen.THORN_COUNT)
				expect(countKind(room.enemies, BruteDen.BRUTE_KIND)).toEqual(1)
			else
				elsewhere += sprites
			end
		end
		expect(den ~= nil).toBeTrue()
		expect(elsewhere).toEqual(0)

		local piled = {
			DUNGEON_ID = BruteDen.DUNGEON_ID,
			ROOM_ID = BruteDen.ROOM_ID,
			BRUTE_KIND = BruteDen.BRUTE_KIND,
			THORN_KIND = BruteDen.THORN_KIND,
			THORN_COUNT = 2,
			THORN_DAMAGE = BruteDen.THORN_DAMAGE,
			CLEAR_HEAL = BruteDen.CLEAR_HEAL,
		}
		local countOk, countWhy = BruteDen.validate(piled)
		expect(countOk).toBeFalse()
		expect(countWhy).toEqual("THORN_COUNT")

		local oldDamage = {
			DUNGEON_ID = BruteDen.DUNGEON_ID,
			ROOM_ID = BruteDen.ROOM_ID,
			BRUTE_KIND = BruteDen.BRUTE_KIND,
			THORN_KIND = BruteDen.THORN_KIND,
			THORN_COUNT = BruteDen.THORN_COUNT,
			THORN_DAMAGE = 11,
			CLEAR_HEAL = BruteDen.CLEAR_HEAL,
		}
		local damageOk, damageWhy = BruteDen.validate(oldDamage)
		expect(damageOk).toBeFalse()
		expect(damageWhy).toEqual("THORN_DAMAGE")

		local springSized = {
			DUNGEON_ID = BruteDen.DUNGEON_ID,
			ROOM_ID = BruteDen.ROOM_ID,
			BRUTE_KIND = BruteDen.BRUTE_KIND,
			THORN_KIND = BruteDen.THORN_KIND,
			THORN_COUNT = BruteDen.THORN_COUNT,
			THORN_DAMAGE = BruteDen.THORN_DAMAGE,
			CLEAR_HEAL = 0.3,
		}
		local healOk, healWhy = BruteDen.validate(springSized)
		expect(healOk).toBeFalse()
		expect(healWhy).toEqual("CLEAR_HEAL")

		local dungeons = fs.readFile("src/ReplicatedStorage/Shared/Dungeons.luau")
		expect(string.find(dungeons, "damage = BruteDen.THORN_DAMAGE", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeons, "enemies = BruteDen.enemies()", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeons, '{ "root_brute", "thorn_sprite" }', 1, true)).toBeNil()
	end)
end)

describe("Brute Den room-clear heal", function()
	it("restores a modest share of the unbuffed max only when the den clears", function()
		-- Starter bar is 100. 20% is 20, under the spring's 30.
		expect(BruteDen.clearHeal(100)).toEqual(20)
		expect(BruteDen.clearHeal(99)).toEqual(19)
		expect(BruteDen.clearHeal(250)).toEqual(50)
		-- Floor would be 0; a positive max still heals 1.
		expect(BruteDen.clearHeal(1)).toEqual(1)
		expect(BruteDen.clearHeal(3)).toEqual(1)
		expect(BruteDen.clearHeal(0)).toEqual(0)
		expect(BruteDen.clearHeal(-10)).toEqual(0)
		expect(BruteDen.clearHeal(0 / 0)).toEqual(0)
		expect(BruteDen.clearHeal(math.huge)).toEqual(0)
		expect(BruteDen.clearHeal("100")).toEqual(0)
		expect(BruteDen.clearHeal(nil)).toEqual(0)

		expect(BruteDen.applies(Dungeons.ROOTVAULT_ID, "den")).toBeTrue()
		expect(BruteDen.applies(Dungeons.ROOTVAULT_ID, "canopy")).toBeFalse()
		expect(BruteDen.applies(Dungeons.ROOTVAULT_ID, "thicket")).toBeFalse()
		expect(BruteDen.applies(Dungeons.ROOTVAULT_ID, "heart")).toBeFalse()
		expect(BruteDen.applies(Dungeons.HEARTWOOD_ID, "den")).toBeFalse()
		expect(BruteDen.applies(Dungeons.WAVES_ID, "den")).toBeFalse()

		local service = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local bodyStart = string.find(service, "local function healDenClear", 1, true)
		local bodyEnd = string.find(service, "local function beginAdvance", 1, true)
		assert(bodyStart ~= nil and bodyEnd ~= nil and bodyEnd > bodyStart)
		local body = string.sub(service, bodyStart, bodyEnd - 1)
		expect(string.find(body, "BruteDen.applies", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "BruteDen.clearHeal", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "CombatMath.loadout", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "CombatService.healAmount", 1, true) ~= nil).toBeTrue()
		expect(string.find(body, "DataService.mutate", 1, true)).toBeNil()
		expect(string.find(body, "0.2", 1, true)).toBeNil()
		expect(string.find(body, "schemaVersion", 1, true)).toBeNil()

		local waveAt = string.find(service, "Wave %d clear. Next wave", 1, true)
		local bossAt = string.find(service, "elseif run.roomIndex >= #run.dungeon.rooms then", 1, true)
		local roomClear = string.find(service, "Room clear. Next room", 1, true)
		assert(waveAt ~= nil and bossAt ~= nil and roomClear ~= nil)
		expect(string.find(string.sub(service, waveAt, bossAt), "healDenClear(player, run)", 1, true)).toBeNil()
		local afterBoss = string.sub(service, bossAt, roomClear)
		local finishRel = string.find(afterBoss, "finish(player, true)", 1, true)
		local healRel = string.find(afterBoss, "healDenClear(player, run)", 1, true)
		assert(finishRel ~= nil and healRel ~= nil)
		expect(healRel > finishRel).toBeTrue()
	end)
end)
