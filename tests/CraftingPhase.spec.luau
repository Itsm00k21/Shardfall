--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local fs = require("@lune/fs")

local Crafting = require("../src/ReplicatedStorage/Shared/Crafting")
local CraftingLevel = require("../src/ReplicatedStorage/Shared/CraftingLevel")
local Drops = require("../src/ReplicatedStorage/Shared/Drops")
local ItemBases = require("../src/ReplicatedStorage/Shared/ItemBases")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local Recipes = require("../src/ReplicatedStorage/Shared/Recipes")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

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
		nextInteger = function(_self, min, _max)
			return min
		end,
	}
end

describe("Crafting phase 1", function()
	it("raises the XP curve every level and stops at 100", function()
		expect(CraftingLevel.xpToNext(1)).toEqual(120)
		expect(CraftingLevel.xpToNext(10)).toEqual(3000)
		expect(CraftingLevel.xpToNext(100)).toEqual(0)
		for level = 1, 98 do
			if CraftingLevel.xpToNext(level) >= CraftingLevel.xpToNext(level + 1) then
				error("XP curve is not rising at " .. tostring(level), 2)
			end
		end
		expect(#CraftingLevel.MILESTONES).toEqual(10)
		for index, row in ipairs(CraftingLevel.MILESTONES) do
			expect(row.level).toEqual(index * 10)
		end
		local profile = Schema.template()
		local gained, levels = CraftingLevel.grant(profile, 120, 0)
		expect(gained).toEqual(120)
		expect(levels).toEqual(1)
		expect(profile.craftingLevel).toEqual(2)
		expect(profile.craftingXp).toEqual(0)
		expect(#profile.craftingMilestones).toEqual(0)

		CraftingLevel.grant(profile, 100000000, 0)
		expect(profile.craftingLevel).toEqual(100)
		expect(profile.craftingXp).toEqual(0)
		expect(#profile.craftingMilestones).toEqual(10)
		expect(profile.craftingMilestones[1]).toEqual(10)
		expect(profile.craftingMilestones[10]).toEqual(100)
		expect(CraftingLevel.bonusesAt(10).rollBias).toEqual(0.02)
		expect(CraftingLevel.bonusesAt(30).rarityUp).toEqual(0.02)
		expect(CraftingLevel.bonusesAt(50).masterwork).toEqual(0.05)
		expect(CraftingLevel.bonusesAt(100).masterwork).toEqual(0.15)
		expect(#profile.milestoneTable).toEqual(10)
	end)

	it("levels a crafting bar that is exactly full", function()
		local need = CraftingLevel.xpToNext(2)
		local profile = { craftingLevel = 2, craftingXp = need }
		expect(CraftingLevel.settle(profile)).toEqual(1)
		expect(profile.craftingLevel).toEqual(3)
		expect(profile.craftingXp).toEqual(0)
		local short = { craftingLevel = 2, craftingXp = need - 1 }
		expect(CraftingLevel.settle(short)).toEqual(0)
		expect(short.craftingLevel).toEqual(2)
		local loaded = Schema.reconcile({ craftingLevel = 2, craftingXp = need })
		expect(loaded.craftingLevel).toEqual(3)
		expect(loaded.craftingXp).toEqual(0)
	end)

	it("doubles crafting XP while a Forge Boost is active", function()
		local profile = Schema.template()
		profile.forgeBoostUntil = 500
		local gained = CraftingLevel.grant(profile, 120, 100)
		expect(gained).toEqual(240)
		expect(profile.craftingLevel).toEqual(2)
		expect(profile.craftingXp).toEqual(120)
		expect(CraftingLevel.multiplier(profile.forgeBoostUntil, 500)).toEqual(1)
		expect(CraftingLevel.multiplier(profile.forgeBoostUntil, 499)).toEqual(2)
	end)

	it("drops common, rare, and boss materials, and a rare scroll", function()
		expect(Drops.ENEMIES.vine_crawler.role).toEqual("normal")
		expect(Drops.ENEMIES.root_brute.role).toEqual("elite")
		expect(Drops.ENEMIES.grandmother_gnarl.role).toEqual("boss")

		local crawler = Drops.roll("vine_crawler", zeroRng())
		expect(crawler.verdant_bark).toEqual(1)
		expect(crawler.vine).toEqual(1)
		expect(crawler.wood).toEqual(1)
		expect(crawler.heartwood).toBeNil()

		local bat = Drops.roll("spore_bat", zeroRng())
		expect(bat.verdant_bark).toEqual(1)
		expect(bat.spore).toEqual(1)

		local elite = Drops.roll("root_brute", zeroRng())
		expect(elite.heartwood).toEqual(1)
		expect(elite.bark).toEqual(1)
		expect(elite.scroll_thornbound).toEqual(1)

		local boss = Drops.roll("grandmother_gnarl", zeroRng())
		expect(boss.gnarl_seed).toEqual(1)
		expect(boss.scroll_thornbound).toEqual(1)

		local missed = Drops.roll("root_brute", highRng())
		expect(missed.heartwood).toEqual(1)
		expect(missed.scroll_thornbound).toBeNil()

		local bag = Materials.empty()
		Drops.apply(bag, "root_brute", zeroRng())
		Drops.apply(bag, "root_brute", zeroRng())
		expect(bag.scroll_thornbound).toEqual(1)
		expect(bag.heartwood).toEqual(2)
	end)

	it("crafts the basic weapons at level 1 and gates Thornbound", function()
		local profile = Schema.template()
		profile.materials.verdant_bark = 4
		local summary, reason = Crafting.commit(profile, "iron_sword", nil, zeroRng(), "sword-1", 1)
		expect(reason).toBeNil()
		assert(summary ~= nil)
		expect(summary.xp).toEqual(24)
		local item = profile.inventory["sword-1"]
		assert(item ~= nil)
		expect(item.name).toEqual("Iron Sword")
		expect(item.weaponType).toEqual("sword")
		expect(item.quality).toEqual(0)
		expect(profile.materials.verdant_bark).toEqual(0)
		expect(profile.craftingXp).toEqual(24)

		profile.materials.verdant_bark = 6
		profile.materials.heartwood = 2
		local _, locked = Crafting.commit(profile, "thornbound_blade", nil, zeroRng(), "blade", 1)
		expect(locked).toEqual("Crafting Level 10. Needs a Thornbound Scroll.")
		expect(profile.materials.verdant_bark).toEqual(6)

		profile.materials.scroll_thornbound = 1
		local _, stillLow = Crafting.commit(profile, "thornbound_blade", nil, zeroRng(), "blade", 1)
		expect(stillLow).toEqual("Crafting Level 10.")

		profile.craftingLevel = 10
		profile.materials.scroll_thornbound = 0
		local _, needsScroll =
			Crafting.commit(profile, "thornbound_blade", nil, zeroRng(), "blade", 1)
		expect(needsScroll).toEqual("Needs a Thornbound Scroll.")

		profile.materials.scroll_thornbound = 1
		local crafted, craftReason =
			Crafting.commit(profile, "thornbound_blade", nil, zeroRng(), "blade", 1)
		expect(craftReason).toBeNil()
		assert(crafted ~= nil)
		expect(crafted.xp).toEqual(48)
		expect(profile.inventory.blade.name).toEqual("Thornbound Blade")
		expect(profile.inventory.blade.rarity).toEqual("Rare")
		expect(profile.inventory.blade.quality > 0).toBeTrue()
		expect(profile.materials.scroll_thornbound).toEqual(1)
		expect(profile.materials.heartwood).toEqual(0)
	end)

	it("biases a level 10 roll, procs rarity-up, and adds a Masterwork line", function()
		local biased = Schema.template()
		biased.craftingLevel = 10
		biased.materials.verdant_bark = 4
		local _, reason = Crafting.commit(biased, "iron_sword", nil, zeroRng(), "biased", 1)
		expect(reason).toBeNil()
		local sword = biased.inventory.biased
		expect(sword.rarity).toEqual("Common")
		expect(sword.stats[1].value).toBeCloseTo(10.08, 1e-9)
		expect(sword.quality).toBeCloseTo(0.02, 1e-9)

		local raised = Schema.template()
		raised.craftingLevel = 30
		raised.materials.verdant_bark = 4
		Crafting.commit(raised, "iron_sword", nil, zeroRng(), "raised", 1)
		expect(raised.inventory.raised.rarity).toEqual("Uncommon")
		expect(#raised.inventory.raised.stats).toEqual(4)

		local master = Schema.template()
		master.craftingLevel = 50
		master.materials.verdant_bark = 4
		Crafting.commit(master, "iron_sword", nil, zeroRng(), "master", 1)
		local line = master.inventory.master.stats
		expect(master.inventory.master.rarity).toEqual("Uncommon")
		expect(#line).toEqual(5)
		expect(line[5].id).toEqual("health")
	end)

	it(
		"salvages unequipped gear into realm materials and refuses what is worn or locked",
		function()
			local profile = Schema.template()
			Schema.insertItem(profile, {
				uid = "junk",
				templateId = "vinewood_sword",
				name = "Vinewood Sword",
				kind = "Weapon",
				rarity = "Common",
				traits = {},
				poolId = "verdant_armory",
				obtainedAt = 1,
			})
			local summary, reason = Crafting.salvage(profile, "junk", 1)
			expect(reason).toBeNil()
			assert(summary ~= nil)
			expect(summary.xp).toEqual(8)
			expect(profile.inventory.junk).toBeNil()
			expect(profile.materials.verdant_bark).toEqual(2)
			expect(profile.craftingXp).toEqual(8)

			Schema.insertItem(profile, {
				uid = "worn",
				templateId = "iron_sword",
				name = "Iron Sword",
				kind = "Weapon",
				rarity = "Common",
				traits = {},
				poolId = "craft",
				obtainedAt = 1,
			})
			Schema.equipItem(profile, profile.inventory.worn)
			local _, equipped = Crafting.salvage(profile, "worn", 1)
			expect(equipped).toEqual("Unequip it before salvaging.")
			expect(profile.inventory.worn ~= nil).toBeTrue()

			profile.inventory.locked = {
				uid = "locked",
				templateId = "iron_dagger",
				name = "Iron Dagger",
				kind = "Weapon",
				rarity = "Common",
				locked = true,
				traits = {},
				poolId = "craft",
				obtainedAt = 1,
			}
			local _, held = Crafting.salvage(profile, "locked", 1)
			expect(held).toEqual("That item is locked.")
			expect(profile.inventory.locked.name).toEqual("Iron Dagger")
		end
	)

	it("can obtain every recipe input from a drop table or salvage", function()
		local covered: { [string]: boolean } = {}
		for enemyId in pairs(Drops.ENEMIES) do
			local entries = Drops.entries(enemyId)
			assert(entries ~= nil, enemyId)
			for _, entry in ipairs(entries) do
				covered[entry.id] = true
			end
		end
		for _, base in ipairs(ItemBases.all()) do
			if base.kind == "Weapon" or base.kind == "Armor" then
				for _, rarity in ipairs(Rarities.ORDER) do
					local yield = Crafting.salvageYield({
						templateId = base.id,
						rarity = rarity,
					})
					for materialId, count in pairs(yield) do
						if count > 0 then
							covered[materialId] = true
						end
					end
				end
			end
		end
		for _, recipe in ipairs(Recipes.all()) do
			for materialId, count in pairs(recipe.costs) do
				if count > 0 and covered[materialId] ~= true then
					error(
						recipe.name
							.. " needs "
							.. Materials.displayName(materialId)
							.. ", which is not in a drop table or salvage yield",
						2
					)
				end
			end
			if recipe.scroll ~= nil and covered[recipe.scroll] ~= true then
				error(
					recipe.name
						.. " needs "
						.. Materials.displayName(recipe.scroll)
						.. ", which is not in a drop table or salvage yield",
					2
				)
			end
		end
		expect(covered.vine).toEqual(true)
		expect(covered.wood).toEqual(true)
		expect(covered.spore).toEqual(true)
		expect(covered.bark).toEqual(true)
		expect(covered.gnarl_seed).toEqual(true)
	end)

	it("lists a clear as name x quantity and includes Gnarl's Seed", function()
		local counts: { [string]: number } = {}
		Materials.merge(counts, { wood = 4, vine = 3, spore = 2, bark = 1 })
		Materials.merge(counts, Drops.roll("grandmother_gnarl", zeroRng()))
		local lines = Materials.gainLines(counts)
		local joined = table.concat(lines, "\n")
		expect(string.find(joined, "/", 1, true)).toBeNil()
		local foundSeed = false
		local foundWood = false
		for _, line in ipairs(lines) do
			if line == "Gnarl's Seed x1" then
				foundSeed = true
			end
			if line == "Verdant Wood x4" then
				foundWood = true
			end
		end
		expect(foundSeed).toBeTrue()
		expect(foundWood).toBeTrue()
		expect(Materials.rarityName("verdant_bark")).toEqual("Common")
		expect(Materials.rarityName("heartwood")).toEqual("Rare")
		expect(Materials.rarityName("gnarl_seed")).toEqual("Legendary")
		expect(Materials.rarityName("scroll_thornbound")).toEqual("Epic")
	end)

	it("spells Verdant the same way in player-facing text", function()
		local function walk(dir: string)
			for _, name in ipairs(fs.readDir(dir)) do
				local path = dir .. "/" .. name
				if fs.isDir(path) then
					walk(path)
				elseif string.sub(name, -5) == ".luau" then
					local source = fs.readFile(path)
					if string.find(source, "Verdent", 1, true) ~= nil then
						error("Spell Verdant in " .. path, 2)
					end
					if string.find(source, "Draema", 1, true) ~= nil then
						error("Unexpected name in " .. path, 2)
					end
				end
			end
		end
		walk("src")
		expect(Materials.DEFS.wood.name).toEqual("Verdant Wood")
		expect(Materials.DEFS.verdant_bark.name).toEqual("Verdant Bark")
		expect(Materials.DEFS.wood.realm).toEqual("Verdant Wilds")
		expect(Materials.DEFS.vine.name).toEqual("Living Vine")
	end)
end)
