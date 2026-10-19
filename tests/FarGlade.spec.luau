--!strict

local fs = require("@lune/fs")
local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Drops = require("../src/ReplicatedStorage/Shared/Drops")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Loops = require("../src/ReplicatedStorage/Shared/Loops")
local ModelFactory = require("../src/ReplicatedStorage/Shared/ModelFactory")

describe("Far Glade enemies", function()
	it("defines each field enemy with a rig, drops, and a doc name", function()
		local names = {
			mud_tusk = "Mud Tusk",
			hedge_lurker = "Hedge Lurker",
			seed_flinger = "Seed Flinger",
			sap_mouth = "Sap Mouth",
			mite_cloud = "Mite Cloud",
		}
		expect(#Dungeons.FAR_GLADE).toEqual(5)
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

describe("Far Glade in Waves", function()
	it("keeps waves 1-2 on the Rootvault trio and rotates the glade in from wave 3", function()
		local rootTrio = { vine_crawler = true, spore_bat = true, root_brute = true }
		for wave = 1, Dungeons.GLADE_FROM_WAVE - 1 do
			for _, kind in ipairs(Dungeons.waveKinds(wave)) do
				expect(rootTrio[kind]).toEqual(true)
			end
		end
		local seen: { [string]: boolean } = {}
		for wave = Dungeons.GLADE_FROM_WAVE, 16 do
			if not Dungeons.isBossWave(wave) then
				local kinds = Dungeons.waveKinds(wave)
				expect(#kinds).toEqual(Dungeons.waveCount(wave))
				local brutes = 0
				for _, kind in ipairs(kinds) do
					expect(Dungeons.enemy(kind) ~= nil).toBeTrue()
					seen[kind] = true
					if kind == "root_brute" then
						brutes += 1
					end
				end
				expect(brutes <= math.ceil(#kinds / 8)).toBeTrue()
			end
		end
		for _, kind in ipairs(Dungeons.FAR_GLADE) do
			expect(seen[kind]).toEqual(true)
		end
	end)

	it("leaves boss waves as Gnarl plus two adds", function()
		local kinds = Dungeons.waveKinds(10)
		expect(kinds[1]).toEqual("grandmother_gnarl")
		expect(#kinds).toEqual(3)
	end)
end)

describe("Far Glade daily", function()
	it("rolls as a daily and finishes after four glade kills", function()
		local dailies = Loops.rollDailies(8, 4)
		local glade = nil
		for _, quest in ipairs(dailies) do
			if quest.id == "glade" then
				glade = quest
			end
		end
		assert(glade ~= nil)
		expect(glade.goal).toEqual(4)
		local data = { dailies = dailies }
		expect(Loops.apply(data, "glade", 3)).toEqual(0)
		expect(Loops.apply(data, "glade", 1)).toEqual(1)
		expect(glade.done).toEqual(true)
		expect(Loops.apply(data, "glade", 1)).toEqual(0)
	end)

	it("stays out of the weekly list", function()
		for _, row in ipairs(Loops.WEEKLY) do
			expect(row.id ~= "glade").toBeTrue()
		end
	end)

	it("counts only paying Far Glade kills on the server", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local at = string.find(source, 'LoopService.progress(player, "glade", 1)', 1, true)
		assert(at ~= nil)
		local guard = string.sub(source, at - 200, at)
		expect(string.find(guard, "PracticeLoot.pays", 1, true) ~= nil).toBeTrue()
		expect(string.find(guard, "Dungeons.FAR_GLADE", 1, true) ~= nil).toBeTrue()
	end)
end)

describe("Far Glade lobbers", function()
	it("marks only the doc's lobbers, all of them projectile Far Glade kinds", function()
		local count = 0
		for kind, on in pairs(Dungeons.LOBS) do
			expect(on).toEqual(true)
			expect(table.find(Dungeons.FAR_GLADE, kind) ~= nil).toBeTrue()
			local definition = Dungeons.enemy(kind)
			assert(definition ~= nil, kind)
			expect(definition.style).toEqual("projectile")
			count += 1
		end
		expect(count).toEqual(2)
		expect(Dungeons.LOBS.spore_bat).toBeNil()
	end)

	it("lands a lob on the purple mark instead of firing a shot", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(
			string.find(
				source,
				'enemy.style == "projectile" and Dungeons.LOBS[enemy.kind] ~= true',
				1,
				true
			) ~= nil
		).toBeTrue()
		local purple = string.find(
			source,
			'elseif Dungeons.LOBS[enemy.kind] == true then\n\t\tcolorName = "purple"',
			1,
			true
		)
		expect(purple ~= nil).toBeTrue()
	end)
end)
