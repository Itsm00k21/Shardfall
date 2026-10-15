--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Crafting = require("../src/ReplicatedStorage/Shared/Crafting")
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

local function give(profile, id: string, count: number)
	profile.materials[id] = count
end

describe("Crafting", function()
	it("refuses a craft that is short on materials and spends nothing", function()
		local profile = Schema.template()
		give(profile, "wood", 4)
		local _, reason = Crafting.commit(profile, "briar_edge", nil, zeroRng(), "new", 1)
		expect(reason).toEqual("Need Living Vine (0/2).")
		expect(profile.materials.wood).toEqual(4)
		expect(Schema.countItems(profile)).toEqual(0)
	end)

	it("crafts a tonic and spends the listed materials", function()
		local profile = Schema.template()
		give(profile, "spore", 2)
		give(profile, "vine", 1)
		local summary, reason = Crafting.commit(profile, "healing_tonic", nil, zeroRng(), "new", 1)
		expect(reason).toBeNil()
		assert(summary ~= nil)
		expect(summary.consumable).toEqual("healing_tonic")
		expect(profile.consumables.healing_tonic).toEqual(1)
		expect(profile.materials.spore).toEqual(1)
		expect(profile.materials.vine).toEqual(0)
	end)

	it("mints a weapon at the bottom of its stat range", function()
		local profile = Schema.template()
		give(profile, "wood", 4)
		give(profile, "vine", 2)
		local summary, reason =
			Crafting.commit(profile, "briar_edge", nil, zeroRng(), "dagger-1", 5)
		expect(reason).toBeNil()
		assert(summary ~= nil)
		local item = profile.inventory["dagger-1"]
		assert(item ~= nil)
		expect(item.name).toEqual("Thorn Dagger")
		expect(item.weaponType).toEqual("dagger")
		expect(item.quality).toEqual(0)
		expect(item.stats[1].id).toEqual("damage")
		expect(item.stats[1].value).toEqual(6)
		expect(item.poolId).toEqual("craft")
		expect(profile.materials.wood).toEqual(0)
	end)

	it("does not reroll a common and does not spend heartwood", function()
		local profile = Schema.template()
		give(profile, "heartwood", 1)
		give(profile, "spore", 2)
		Schema.insertItem(profile, {
			uid = "sword",
			templateId = "vinewood_sword",
			name = "Vinewood Sword",
			kind = "Weapon",
			rarity = "Common",
			traits = {},
			poolId = "verdant_armory",
			obtainedAt = 1,
		})
		local _, reason = Crafting.commit(profile, "wild_resin", "sword", zeroRng(), "unused", 1)
		expect(reason).toEqual("That item cannot hold a trait.")
		expect(profile.materials.heartwood).toEqual(1)
		expect(#profile.inventory.sword.traits).toEqual(0)
	end)

	it("rerolls one trait and leaves the other in place", function()
		local profile = Schema.template()
		give(profile, "heartwood", 1)
		give(profile, "spore", 2)
		Schema.insertItem(profile, {
			uid = "hood",
			templateId = "grovewarden_hood",
			name = "Grovewarden Hood",
			kind = "Armor",
			rarity = "Legendary",
			slot = "helm",
			traits = {
				{
					id = "gold_find",
					name = "Gold Find",
					value = 0.1,
					unit = "percent",
					display = "10.0%",
				},
				{
					id = "lifesteal",
					name = "Lifesteal",
					value = 0.05,
					unit = "percent",
					display = "5.0%",
				},
			},
			poolId = "verdant_armory",
			obtainedAt = 1,
		})
		local summary, reason =
			Crafting.commit(profile, "wild_resin", "hood", zeroRng(), "unused", 1)
		expect(reason).toBeNil()
		assert(summary ~= nil)
		expect(summary.rerolled).toEqual(true)
		expect(profile.inventory.hood.traits[1].id).toEqual("chain_lightning")
		expect(profile.inventory.hood.traits[2].id).toEqual("lifesteal")
		expect(profile.materials.heartwood).toEqual(0)
		expect(profile.materials.spore).toEqual(0)
	end)

	it("rejects an unknown recipe", function()
		local _, reason = Crafting.commit(Schema.template(), "not_a_recipe", nil, zeroRng(), "x", 1)
		expect(reason).toEqual("Unknown recipe.")
	end)
end)
