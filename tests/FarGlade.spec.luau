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

	it("keeps Mireoak a Waves mini-boss on Gnarl's kit with elite drops", function()
		local oak = Dungeons.enemy("mireoak")
		local gnarl = Dungeons.enemy("grandmother_gnarl")
		assert(oak ~= nil and gnarl ~= nil)
		expect(oak.boss).toEqual(true)
		expect(oak.phase2At).toEqual(gnarl.phase2At)
		expect(oak.safeRadius).toEqual(gnarl.safeRadius)
		expect(oak.maxHealth > gnarl.maxHealth and oak.maxHealth <= gnarl.maxHealth * 1.2).toBeTrue()
		expect(oak.damage <= gnarl.damage + 1).toBeTrue()
		expect(Drops.ENEMIES.mireoak.role).toEqual("elite")
		expect(table.find(Dungeons.FAR_GLADE, "mireoak")).toBeNil()
		expect(table.find(ModelFactory.FIELD_MONSTERS, "mireoak") ~= nil).toBeTrue()
		expect(ModelFactory.partCount("mireoak") <= ModelFactory.MONSTER_BUDGET).toBeTrue()
		local recipe = ModelFactory.recipe("mireoak")
		assert(recipe ~= nil)
		local weak = false
		for _, piece in ipairs(recipe) do
			if piece.name == "WeakSpot" then
				weak = true
			end
		end
		expect(weak).toEqual(true)
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

	it("alternates boss waves: Gnarl on odd fives, Mireoak on tens", function()
		for _, wave in ipairs({ 5, 15, 25 }) do
			local kinds = Dungeons.waveKinds(wave)
			expect(kinds[1]).toEqual("grandmother_gnarl")
			expect(#kinds).toEqual(3)
		end
		for _, wave in ipairs({ 10, 20, 30 }) do
			expect(Dungeons.waveKinds(wave)).toEqual({ "mireoak", "mud_tusk", "seed_flinger" })
		end
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
		local purple = string.find(source, "or Dungeons.LOBS[enemy.kind] == true then", 1, true)
		expect(purple ~= nil).toBeTrue()
	end)
end)

describe("Far Glade wave note", function()
	it("adds one banner line on the first glade wave only", function()
		expect(Dungeons.waveNote(Dungeons.GLADE_FROM_WAVE)).toEqual(
			". Far Glade beasts join. Purple: step out."
		)
		for _, wave in ipairs({ 1, 2, 4, 5, 10 }) do
			expect(Dungeons.waveNote(wave)).toEqual("")
		end
		expect(Dungeons.isBossWave(Dungeons.GLADE_FROM_WAVE)).toEqual(false)
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(source, "text ..= Dungeons.waveNote(run.wave)", 1, true) ~= nil).toBeTrue()
	end)
end)

describe("Far Glade lungers", function()
	it("gives the doc's two lungers a reach past their swing range", function()
		for kind, reach in pairs(Dungeons.LUNGES) do
			local definition = Dungeons.enemy(kind)
			assert(definition ~= nil, kind)
			expect(table.find(Dungeons.FAR_GLADE, kind) ~= nil).toBeTrue()
			expect(definition.style).toEqual("melee")
			expect(reach > definition.range).toBeTrue()
			expect(reach <= 16).toBeTrue()
		end
		expect(Dungeons.LUNGES.vine_crawler).toBeNil()
	end)

	it("ends a lunge just short of the mark and never moves on a point-blank mark", function()
		local x, z = Dungeons.lungeEnd(0, 0, 10, 0)
		expect(x).toEqual(10 - Dungeons.LUNGE_STOP_SHORT)
		expect(z).toEqual(0)
		local sx, sz = Dungeons.lungeEnd(3, 4, 3.5, 4)
		expect(sx).toEqual(3)
		expect(sz).toEqual(4)
		local dx, dz = Dungeons.lungeEnd(0, 0, 0, -8)
		expect(math.abs(dx) < 1e-9).toBeTrue()
		expect(dz).toEqual(-8 + Dungeons.LUNGE_STOP_SHORT)
	end)

	it("wires the lunge into the strike and pauses movement while it lands", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(source, "lungeEnemy(enemy, run, now)", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "if now < (enemy.dashUntil or 0) then", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "(Dungeons.LUNGES[enemy.kind] or enemy.range)", 1, true) ~= nil).toBeTrue()
describe("Far Glade strays", function()
	it("rotates a Far Glade stray per room for the Elite Fight door", function()
		local seen: { [string]: boolean } = {}
		for room = 1, #Dungeons.STRAYS do
			local kind = Dungeons.stray(room)
			expect(table.find(Dungeons.FAR_GLADE, kind) ~= nil).toBeTrue()
			seen[kind] = true
		end
		expect(Dungeons.stray(1)).toEqual(Dungeons.stray(1 + #Dungeons.STRAYS))
		expect(Dungeons.stray(0)).toEqual(Dungeons.stray(1))
		expect(Dungeons.stray(0 / 0)).toEqual(Dungeons.stray(1))
		local count = 0
		for _ in pairs(seen) do
			count += 1
		end
		expect(count).toEqual(#Dungeons.STRAYS)
	end)

	it("spawns the stray before the room so it takes the elite buff, Rootvault only", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local stray = string.find(
			source,
			"spawnEnemy(run, Dungeons.stray(run.roomIndex), SPAWNS[#SPAWNS])",
			1,
			true
		)
		local roomLoop = string.find(source, "for index, kind in ipairs(room.enemies) do", 1, true)
		assert(stray ~= nil and roomLoop ~= nil)
		expect(stray < roomLoop).toBeTrue()
		local guard = string.sub(source, stray - 160, stray)
		expect(string.find(guard, "run.eliteNext and not bossRoom", 1, true) ~= nil).toBeTrue()
		expect(string.find(guard, "Dungeons.ROOTVAULT_ID", 1, true) ~= nil).toBeTrue()
	end)
end)
