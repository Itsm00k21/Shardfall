--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Crafting = require("../src/ReplicatedStorage/Shared/Crafting")
local CraftingLevel = require("../src/ReplicatedStorage/Shared/CraftingLevel")
local Drops = require("../src/ReplicatedStorage/Shared/Drops")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
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
		expect(crawler.heartwood).toBeNil()

		local elite = Drops.roll("root_brute", zeroRng())
		expect(elite.heartwood).toEqual(1)
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
end)
