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
		expect(profile.schemaVersion).toEqual(1)
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
end)
