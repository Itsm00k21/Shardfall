--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Drops = require("../src/ReplicatedStorage/Shared/Drops")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local ModelFactory = require("../src/ReplicatedStorage/Shared/ModelFactory")

describe("Far Glade enemies", function()
	it("defines each field enemy with a rig, drops, and a doc name", function()
		local names =
			{ mud_tusk = "Mud Tusk", hedge_lurker = "Hedge Lurker", seed_flinger = "Seed Flinger" }
		expect(#Dungeons.FAR_GLADE).toEqual(3)
		for index, kind in ipairs(Dungeons.FAR_GLADE) do
			expect(ModelFactory.FIELD_MONSTERS[index]).toEqual(kind)
			local definition = Dungeons.enemy(kind)
			assert(definition ~= nil, kind)
			expect(definition.name).toEqual(names[kind])
			expect(definition.boss).toEqual(false)
			local count = ModelFactory.partCount(kind)
			expect(count > 0).toBeTrue()
			expect(count <= ModelFactory.MONSTER_BUDGET).toBeTrue()
			expect(ModelFactory.layout(kind, 1) ~= nil).toBeTrue()
			local drop = Drops.ENEMIES[kind]
			assert(drop ~= nil, kind)
			expect(drop.realm).toEqual("verdant")
			expect(drop.role).toEqual("normal")
			expect(Drops.entries(kind) ~= nil).toBeTrue()
		end
	end)

	it("sits between the Rootvault normals and the elite brute", function()
		local bat = Dungeons.enemy("spore_bat")
		local brute = Dungeons.enemy("root_brute")
		assert(bat ~= nil and brute ~= nil)
		for _, kind in ipairs(Dungeons.FAR_GLADE) do
			local definition = Dungeons.enemy(kind)
			assert(definition ~= nil)
			expect(definition.maxHealth >= bat.maxHealth).toBeTrue()
			expect(definition.maxHealth < brute.maxHealth).toBeTrue()
			expect(definition.damage < brute.damage).toBeTrue()
			-- Damage per second stays under the brute's slow heavy swing plus margin.
			expect(definition.damage * definition.attackSpeed <= 9).toBeTrue()
		end
		local flinger = Dungeons.enemy("seed_flinger")
		assert(flinger ~= nil)
		expect(flinger.style).toEqual("projectile")
		expect(flinger.projectileSpeed > 0).toBeTrue()
	end)

	it("keeps the Far Glade out of the Rootvault rooms", function()
		local rootvault = Dungeons.get(Dungeons.ROOTVAULT_ID)
		assert(rootvault ~= nil)
		for _, room in ipairs(rootvault.rooms) do
			for _, kind in ipairs(room.enemies) do
				expect(table.find(Dungeons.FAR_GLADE, kind)).toEqual(nil)
			end
		end
	end)
end)
