--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Schema = require("../src/ReplicatedStorage/Shared/Schema")

describe("Schema", function()
	it("starts a new profile at version 1 with starter tokens", function()
		local profile = Schema.template()
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.level).toEqual(1)
		expect(profile.shardTokens).toEqual(25)
		expect(profile.shardLuck).toEqual(0)
		expect(profile.gold).toEqual(0)
		expect(profile.ascension).toEqual(0)
		expect(profile.equipped.weapon).toBeNil()
		expect(profile.equipped.pet).toBeNil()
	end)

	it("migrates an empty save without wiping fields that already exist", function()
		local saved = {
			gold = 40,
			inventory = {
				abc = { uid = "abc", name = "Wooden Sword", kind = "Weapon" },
			},
			futureFlag = true,
		}
		local profile, err = Schema.migrate(saved)
		expect(err).toBeNil()
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.gold).toEqual(40)
		expect(profile.shardLuck).toEqual(0)
		expect(profile.shardTokens).toEqual(25)
		expect(profile.inventory.abc.name).toEqual("Wooden Sword")
		expect((saved :: any).futureFlag).toEqual(true)
		expect((profile :: any).futureFlag).toEqual(true)
	end)

	it("fills a missing luck stat on a versioned profile", function()
		local profile = Schema.migrate({
			schemaVersion = 1,
			gold = 3,
			level = 4,
			xp = 10,
		})
		assert(profile ~= nil)
		expect(profile.gold).toEqual(3)
		expect(profile.level).toEqual(4)
		expect(profile.shardLuck).toEqual(0)
		expect(profile.xp).toEqual(10)
	end)

	it("refuses corrupt data and profiles from a newer server", function()
		local _, corrupt = Schema.migrate("nope")
		expect(corrupt).toEqual("corrupt")
		local _, newer = Schema.migrate({ schemaVersion = 99, gold = 1 })
		expect(newer).toEqual("newer")
	end)

	it("clamps bad numbers instead of deleting the profile", function()
		local profile = Schema.migrate({
			schemaVersion = 1,
			gold = -20,
			level = 0,
			shardTokens = "lots",
			shardLuck = -4,
		})
		assert(profile ~= nil)
		expect(profile.gold).toEqual(0)
		expect(profile.level).toEqual(1)
		expect(profile.shardTokens).toEqual(25)
		expect(profile.shardLuck).toEqual(0)
	end)

	it("copies snapshots so the client table is not the live profile", function()
		local profile = Schema.template()
		profile.inventory.abc = {
			uid = "abc",
			templateId = "wooden_sword",
			name = "Wooden Sword",
			kind = "Weapon",
			rarity = "Common",
			traits = {},
			poolId = "starter_shard",
			obtainedAt = 1,
		}
		local snapshot = Schema.snapshot(profile)
		snapshot.inventory.abc.name = "Changed"
		snapshot.gold = 99
		expect(profile.inventory.abc.name).toEqual("Wooden Sword")
		expect(profile.gold).toEqual(0)
		expect(snapshot.xpToNext).toEqual(100)
		expect(Schema.xpToNext(3)).toEqual(300)
	end)

	it("tracks pity per pool and files pets separately from weapons", function()
		local profile = Schema.template()
		local pity = Schema.pityBucket(profile, "starter_shard")
		pity.rollsSinceLegendary = 2
		expect(Schema.pityBucket(profile, "starter_shard").rollsSinceLegendary).toEqual(2)
		expect(Schema.pityBucket(profile, "other").rollsSinceLegendary).toEqual(0)

		Schema.insertItem(profile, {
			uid = "pet-1",
			templateId = "training_pup",
			name = "Training Pup",
			kind = "Pet",
			rarity = "Uncommon",
			traits = {},
			poolId = "starter_shard",
			obtainedAt = 1,
		})
		Schema.insertItem(profile, {
			uid = "wep-1",
			templateId = "wooden_sword",
			name = "Wooden Sword",
			kind = "Weapon",
			rarity = "Common",
			traits = {},
			poolId = "starter_shard",
			obtainedAt = 1,
		})
		expect(Schema.countItems(profile)).toEqual(2)
		expect(profile.pets["pet-1"].name).toEqual("Training Pup")
		expect(profile.inventory["wep-1"].name).toEqual("Wooden Sword")
		local found = Schema.findItem(profile, "wep-1")
		assert(found ~= nil)
		expect(found.kind).toEqual("Weapon")
	end)

	it("clears an equipped id that is not in the bag and keeps one that is", function()
		local missing = Schema.migrate({
			schemaVersion = 1,
			equipped = { weapon = "missing-sword", pet = "missing-pet" },
			inventory = {
				sword = { uid = "sword", name = "Wooden Sword", kind = "Weapon" },
			},
		})
		assert(missing ~= nil)
		expect(missing.equipped.weapon).toBeNil()
		expect(missing.equipped.pet).toBeNil()
		expect(missing.inventory.sword.name).toEqual("Wooden Sword")

		local kept = Schema.migrate({
			schemaVersion = 1,
			equipped = { weapon = "sword", pet = "pup" },
			inventory = {
				sword = { uid = "sword", name = "Wooden Sword", kind = "Weapon" },
			},
			pets = {
				pup = { uid = "pup", name = "Training Pup", kind = "Pet" },
			},
		})
		assert(kept ~= nil)
		expect(kept.equipped.weapon).toEqual("sword")
		expect(kept.equipped.pet).toEqual("pup")
		expect(kept.equipped.armor).toEqual({})
	end)

	it("equips armor into its slot and drops a slot that is not in the bag", function()
		local profile = Schema.template()
		local hood = {
			uid = "hood",
			templateId = "grovewarden_hood",
			name = "Grovewarden Hood",
			kind = "Armor",
			rarity = "Epic",
			slot = "helm",
			setId = "grovewarden",
			traits = {},
			poolId = "verdant_armory",
			obtainedAt = 1,
		}
		Schema.insertItem(profile, hood)
		expect(Schema.equipItem(profile, hood)).toBeNil()
		expect(profile.equipped.armor.helm).toEqual("hood")
		expect(Schema.isEquipped(profile, "hood")).toBeTrue()

		local migrated = Schema.migrate({
			schemaVersion = 1,
			equipped = { armor = { helm = "missing", ring = "nope" } },
			inventory = { hood = hood },
		})
		assert(migrated ~= nil)
		expect(migrated.schemaVersion).toEqual(Schema.VERSION)
		expect(migrated.equipped.armor.helm).toBeNil()
		expect(migrated.equipped.armor.ring).toBeNil()

		local kept = Schema.migrate({
			schemaVersion = 1,
			equipped = { armor = { helm = "hood" } },
			inventory = { hood = hood },
		})
		assert(kept ~= nil)
		expect(kept.equipped.armor.helm).toEqual("hood")
		Schema.clearEquip(kept, "hood")
		expect(kept.equipped.armor.helm).toBeNil()
	end)

	it("fills materials, tonics, and vouchers when migrating an older save", function()
		local profile = Schema.migrate({
			schemaVersion = 2,
			gold = 8,
		})
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.gold).toEqual(8)
		expect(profile.materials.wood).toEqual(0)
		expect(profile.materials.heartwood).toEqual(0)
		expect(profile.consumables.healing_tonic).toEqual(0)
		expect(profile.vouchers.armory).toEqual(0)
		expect(profile.vouchers.pets).toEqual(0)
	end)

	it("stamps star fields onto gear from an older save", function()
		local profile = Schema.migrate({
			schemaVersion = 3,
			inventory = {
				blade = {
					uid = "blade",
					templateId = "nightbriar",
					name = "Nightbriar",
					kind = "Weapon",
					stats = { { id = "damage", value = 10 } },
				},
			},
		})
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.prismTokens).toEqual(0)
		expect(profile.luckBoost).toEqual(0)
		expect(profile.shardTokens).toEqual(Schema.STARTER_TOKENS)
		expect(profile.inventory.blade.stars).toEqual(0)
		expect(profile.inventory.blade.starProgress).toEqual(0)
		expect(profile.inventory.blade.stats[1].baseValue).toEqual(10)
		expect(profile.inventory.blade.stats[1].value).toEqual(10)
	end)

	it("keeps earned Shard Tokens separate from Prism Tokens", function()
		local profile = Schema.migrate({
			schemaVersion = 4,
			shardTokens = 12,
			shardLuck = 25,
		})
		assert(profile ~= nil)
		expect(profile.schemaVersion).toEqual(Schema.VERSION)
		expect(profile.craftingLevel).toEqual(1)
		expect(profile.craftingXp).toEqual(0)
		expect(profile.forgeBoostUntil).toEqual(0)
		expect(profile.shardTokens).toEqual(12)
		expect(profile.prismTokens).toEqual(0)
		expect(profile.luckBoost).toEqual(0)
		expect(profile.shardLuck).toEqual(25)
		profile.prismTokens = 3
		expect(profile.shardTokens).toEqual(12)
	end)
end)
