--!strict

--[[
	Stage A. Gold owns item.upgrade. An automatic duplicate feeds stars
	and never writes item.upgrade or item.level. ★5 records gearEssence.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Accept = require("../src/server/GearLevels/Accept")
local Dev = require("../src/server/GearLevels/Dev")
local Economy = require("../src/ReplicatedStorage/Shared/Economy")
local GearLevels = require("../src/ReplicatedStorage/Shared/Config/GearLevels")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Stars = require("../src/ReplicatedStorage/Shared/Stars")

local function piece(uid: string, upgrade: number?): any
	return {
		uid = uid,
		templateId = "bramble_fang",
		name = "Bramble Fang",
		kind = "Weapon",
		rarity = "Uncommon",
		upgrade = upgrade,
		stats = { { id = "damage", value = 12 } },
	}
end

local function profile(): any
	return {
		gold = 500,
		inventory = {},
		pets = {},
		equipped = { weapon = nil, pet = nil, armor = {}, accessories = {} },
	}
end

describe("GearLevels config", function()
	it("uses the forge cap for every rarity", function()
		expect(GearLevels.capFor("Common")).toEqual(Economy.UPGRADE_MAX)
		expect(GearLevels.capFor("Uncommon")).toEqual(10)
		expect(GearLevels.capFor("Rare")).toEqual(10)
		expect(GearLevels.capFor("Epic")).toEqual(10)
		expect(GearLevels.capFor("Legendary")).toEqual(10)
		expect(GearLevels.capFor("Mythic")).toEqual(10)
		expect(GearLevels.capFor(nil)).toEqual(10)
		expect(GearLevels.PER_LEVEL).toEqual(0.08)
	end)

	it("reads a missing upgrade as +0 and scales from there", function()
		expect(GearLevels.storedUpgrade(nil)).toEqual(0)
		expect(GearLevels.storedUpgrade("nope")).toEqual(0)
		expect(GearLevels.storedUpgrade(-4)).toEqual(0)
		expect(GearLevels.storedUpgrade(10.9)).toEqual(10)
		expect(GearLevels.storedUpgrade(99)).toEqual(10)
		expect(GearLevels.multiplier(nil, "Common")).toEqual(1)
		expect(GearLevels.multiplier(0, "Legendary")).toEqual(1)
		expect(GearLevels.multiplier(1, "Common")).toBeCloseTo(1.08)
		expect(GearLevels.multiplier(10, "Common")).toBeCloseTo(1.8)
		expect(GearLevels.levelText("Bramble Fang", 3, 4)).toEqual("Bramble Fang ★3 -> ★4")
		expect(GearLevels.levelText("Bramble Fang", 4, 4)).toBeNil()
	end)

	it("records the same overflow ladder as duplicate fragments", function()
		expect(GearLevels.essenceFor("Common")).toEqual(1)
		expect(GearLevels.essenceFor("Uncommon")).toEqual(3)
		expect(GearLevels.essenceFor("Rare")).toEqual(10)
		expect(GearLevels.essenceFor("Epic")).toEqual(40)
		expect(GearLevels.essenceFor("Legendary")).toEqual(200)
		expect(GearLevels.essenceFor("Mythic")).toEqual(200)
		expect(GearLevels.essenceFor("Secret")).toEqual(200)
		expect(GearLevels.essenceFor("nope")).toEqual(0)
	end)

	it("keeps the live gold curve", function()
		expect(Economy.upgradeCost(0)).toEqual(150)
		expect(Economy.upgradeCost(1)).toEqual(300)
		local gold, mats = Economy.upgradeCost(7)
		expect(gold).toEqual(math.floor(500 * (1.6 ^ 7) + 0.5))
		expect(mats).toEqual(1)
	end)
end)

describe("GearLevels duplicates", function()
	it("does nothing to the profile while the flag is off", function()
		local data = profile()
		local owned = piece("a", 2)
		data.inventory.a = owned
		local incoming = piece("new", nil)
		local landing = Accept.accept(data, incoming, false, GearLevels)
		expect(landing.merged).toEqual(false)
		expect(landing.oldLevel).toBeNil()
		expect(landing.newLevel).toBeNil()
		expect(landing.levelText).toBeNil()
		expect(owned.upgrade).toEqual(2)
		expect(owned.level).toBeNil()
		expect(incoming.level).toBeNil()
		expect(data.gearEssence).toBeNil()
		expect(data.gold).toEqual(500)
	end)

	it("feeds one star and takes no bag slot", function()
		local data = profile()
		local owned = piece("a", 2)
		data.inventory.a = owned
		local incoming = piece("incoming", nil)
		incoming.quality = 1
		local landing = Accept.accept(data, incoming, true, GearLevels, nil, Stars)
		expect(landing.action).toEqual("star")
		expect(landing.merged).toEqual(true)
		expect(landing.oldLevel).toEqual(0)
		expect(landing.newLevel).toEqual(1)
		expect(landing.levelText).toEqual("Bramble Fang ★0 -> ★1")
		expect(landing.essence).toEqual(0)
		expect(owned.upgrade).toEqual(2)
		expect(owned.stars).toEqual(1)
		expect(owned.level).toBeNil()
		expect(owned.uid).toEqual("a")
		expect(owned.stats[1].value).toBeCloseTo(12 * 1.08)
		expect(owned.stats[1].baseValue).toEqual(12)
		expect(data.inventory.incoming).toBeNil()
		expect(data.gold).toEqual(500)
		expect(data.gearEssence).toBeNil()
	end)

	it("leaves a +10 forge upgrade alone and still feeds a star", function()
		local data = profile()
		local owned = piece("a", 10)
		data.inventory.a = owned
		local incoming = piece("incoming", nil)
		incoming.quality = 1
		local landing = Accept.accept(data, incoming, true, GearLevels, nil, Stars)
		expect(landing.action).toEqual("star")
		expect(landing.newLevel).toEqual(1)
		expect(owned.upgrade).toEqual(10)
		expect(owned.stars).toEqual(1)
		expect(data.gearEssence).toBeNil()
	end)

	it("does not merge a different item", function()
		local data = profile()
		data.inventory.a = piece("a", 1)
		local incoming = { templateId = "other", name = "Other", uid = "n" }
		local landing = Accept.accept(data, incoming, true, GearLevels, nil, Stars)
		expect(landing.action).toEqual("insert")
		expect(landing.merged).toEqual(false)
		expect(landing.oldLevel).toBeNil()
		expect(incoming.level).toBeNil()
		expect(incoming.upgrade).toBeNil()
		expect(data.inventory.n).toBeNil()
		expect(data.inventory.a.upgrade).toEqual(1)
	end)

	it("turns a duplicate of a five-star piece into essence", function()
		local data = profile()
		local owned = piece("a", 4)
		owned.stars = 5
		data.inventory.a = owned
		local incoming = piece("incoming", nil)
		incoming.quality = 1
		local landing = Accept.accept(data, incoming, true, GearLevels, nil, Stars)
		expect(landing.action).toEqual("essence")
		expect(landing.oldLevel).toEqual(5)
		expect(landing.newLevel).toEqual(5)
		expect(landing.essence).toEqual(3)
		expect(landing.levelText).toBeNil()
		expect(owned.upgrade).toEqual(4)
		expect(owned.stars).toEqual(5)
		expect(owned.stats[1].value).toEqual(12)
		expect(owned.level).toBeNil()
		expect(data.gearEssence).toEqual(3)
		expect(data.inventory.incoming).toBeNil()
		expect(data.gold).toEqual(500)
	end)

	it("lets a hook replace the essence record", function()
		local data = profile()
		local owned = piece("a", 1)
		owned.stars = 5
		data.inventory.a = owned
		local seen = 0
		Accept.accept(data, piece("incoming", nil), true, GearLevels, function(saved, amount)
			seen = amount
			saved.gearEssence = 7
		end, Stars)
		expect(seen).toEqual(3)
		expect(data.gearEssence).toEqual(7)
		expect(owned.upgrade).toEqual(1)
	end)

	it("prefers the equipped copy, then the lowest star count", function()
		local data = profile()
		data.inventory.a = piece("a", 9)
		data.inventory.b = piece("b", 1)
		data.inventory.a.stars = 0
		data.inventory.b.stars = 2
		data.equipped.weapon = "b"
		local incoming = piece("incoming", nil)
		incoming.quality = 1
		Accept.accept(data, incoming, true, GearLevels, nil, Stars)
		expect(data.inventory.b.stars).toEqual(3)
		expect(data.inventory.a.stars).toEqual(0)
		expect(data.inventory.b.upgrade).toEqual(1)
		expect(data.inventory.a.upgrade).toEqual(9)

		data.inventory.b.stars = 5
		local again = piece("again", nil)
		again.quality = 1
		Accept.accept(data, again, true, GearLevels, nil, Stars)
		expect(data.inventory.a.stars).toEqual(1)
		expect(data.inventory.b.stars).toEqual(5)

		local plain = profile()
		plain.inventory.a = piece("a", 0)
		plain.inventory.b = piece("b", 0)
		plain.inventory.a.stars = 2
		plain.inventory.b.stars = 0
		local third = piece("third", nil)
		third.quality = 1
		Accept.accept(plain, third, true, GearLevels, nil, Stars)
		expect(plain.inventory.b.stars).toEqual(1)
		expect(plain.inventory.a.stars).toEqual(2)
	end)

	it("merges a pet the same way and leaves the other copy", function()
		local data = profile()
		data.pets.p = {
			uid = "p",
			templateId = "rift_hound",
			name = "Rift Hound",
			kind = "Pet",
			rarity = "Rare",
			upgrade = 0,
		}
		data.pets.q = {
			uid = "q",
			templateId = "rift_hound",
			name = "Rift Hound",
			kind = "Pet",
			rarity = "Rare",
			upgrade = 3,
		}
		local incoming = { templateId = "rift_hound", name = "Rift Hound", uid = "incoming", quality = 1 }
		local landing = Accept.accept(data, incoming, true, GearLevels, nil, Stars)
		expect(landing.newLevel).toEqual(1)
		expect(data.pets.p.stars).toEqual(1)
		expect(data.pets.q.stars == nil or data.pets.q.stars == 0).toEqual(true)
		expect(data.pets.p.upgrade).toEqual(0)
		expect(data.pets.q.upgrade).toEqual(3)
		expect(data.pets.q.uid).toEqual("q")
	end)

	it("migrates essence on a copy and does not add a level", function()
		local raw = {
			gold = 9,
			gearEssence = 4.8,
			inventory = {
				a = piece("a", 6),
			},
		}
		local copy, err = Accept.migrate(raw)
		expect(err).toBeNil()
		expect(raw.gearEssence).toEqual(4.8)
		expect(raw.inventory.a.level).toBeNil()
		expect(copy.gearEssence).toEqual(4)
		expect(copy.inventory.a.upgrade).toEqual(6)
		expect(copy.inventory.a.level).toBeNil()
		copy.inventory.a.upgrade = 1
		expect(raw.inventory.a.upgrade).toEqual(6)
		local blank, blankErr = Accept.migrate({ gold = 1 })
		expect(blankErr).toBeNil()
		expect(blank.gearEssence).toEqual(0)
		expect(Accept.migrate("no")).toBeNil()
	end)
end)

describe("GearLevels dev buttons", function()
	it("grants a +0 piece, then a free upgrade, without a second row", function()
		local data = profile()
		local bases = {
			{ id = "bramble_fang", name = "Bramble Fang", kind = "Weapon", rarity = "Uncommon" },
		}
		local ok, text = Dev.grantDupe(data, bases, GearLevels, 100, Stars)
		expect(ok).toEqual(true)
		expect(text).toEqual("Granted Bramble Fang at ★0.")
		expect(data.inventory["dev-dupe-1"].level).toBeNil()
		expect(data.inventory["dev-dupe-1"].upgrade).toBeNil()
		expect(data.inventory["dev-dupe-1"].stars).toBeNil()
		local again, line = Dev.grantDupe(data, bases, GearLevels, 100, Stars)
		expect(again).toEqual(true)
		expect(line).toEqual("Bramble Fang ★0 -> ★1.")
		expect(data.inventory["dev-dupe-1"].upgrade).toBeNil()
		expect(data.inventory["dev-dupe-1"].stars).toEqual(1)
		expect(data.inventory["dev-dupe-1"].level).toBeNil()
		local count = 0
		for _ in pairs(data.inventory) do
			count += 1
		end
		expect(count).toEqual(1)
		expect(data.gold).toEqual(500)
	end)

	it("fills empty rows and does not edit the piece that was already there", function()
		local data = profile()
		local kept = piece("keep", 4)
		kept.name = "Kept"
		data.inventory.keep = kept
		local bases = {
			{ id = "other", name = "Other", kind = "Weapon", rarity = "Common" },
		}
		local ok, text = Dev.fillBag(data, bases, 3)
		expect(ok).toEqual(true)
		expect(text).toEqual("Filled the Bag with 2. Now 3/3.")
		expect(data.inventory.keep.name).toEqual("Kept")
		expect(data.inventory.keep.upgrade).toEqual(4)
		expect(data.inventory.keep.level).toBeNil()
		expect(data.inventory["devfill-1"].level).toBeNil()
		expect(data.inventory["devfill-1"].upgrade).toBeNil()
		expect(data.gold).toEqual(500)
	end)
end)

describe("GearLevels save", function()
	it("keeps schema 26 and does not invent item.level", function()
		expect(Schema.VERSION).toEqual(26)
		local fresh = Schema.template()
		expect(fresh.schemaVersion).toEqual(26)
		expect(fresh.gearEssence).toEqual(0)
		expect(fresh.equipLoadout.weapon).toEqual("")
		local raw = {
			schemaVersion = 26,
			gold = 5,
			equipped = { weapon = "abc", pet = nil, armor = {}, accessories = {} },
			inventory = {
				abc = piece("abc", 4),
			},
		}
		local untouched = Schema.deepCopy(raw)
		local migrated = Schema.migrate(Schema.deepCopy(raw))
		expect(untouched.inventory.abc.level).toBeNil()
		expect(untouched.equipLoadout).toBeNil()
		expect(untouched.gearEssence).toBeNil()
		expect(migrated.schemaVersion).toEqual(26)
		expect(migrated.inventory.abc.upgrade).toEqual(4)
		expect(migrated.inventory.abc.level).toBeNil()
		expect(migrated.gearEssence).toEqual(0)
		expect(migrated.equipped.weapon).toEqual("abc")
		expect(migrated.gold).toEqual(5)
		expect(migrated.equipLoadout.weapon).toEqual("")
		local stored = Schema.deepCopy(raw)
		stored.equipLoadout = { weapon = "abc", skill1 = "thorn_bash" }
		local kept = Schema.migrate(stored)
		expect(kept.equipLoadout.weapon).toEqual("abc")
		expect(kept.equipLoadout.skill1).toEqual("thorn_bash")
		expect(kept.inventory.abc.level).toBeNil()
		expect(raw.equipLoadout).toBeNil()
		local shot = Schema.snapshot(kept)
		expect(shot.gearEssence).toEqual(0)
		expect(shot.equipLoadout.weapon).toEqual("abc")
		expect(shot.equipLoadout.skill1).toEqual("thorn_bash")
	end)

	it("leaves the roll needles in place", function()
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		local manyAt = string.find(roll, "function RollService.rollMany", 1, true) :: number
		local batchAt = string.find(roll, "local function crackBatch", 1, true) :: number
		local batch = string.sub(roll, batchAt, manyAt)
		local blockAt = string.find(batch, "RollConfig.batchBlock(data.shardTokens, free, total)", 1, true)
		local spendAt = string.find(batch, "data.shardTokens -= price", 1, true)
		local drawAt = string.find(batch, "drawInto(data, pool, rng)", 1, true)
		expect(blockAt ~= nil and spendAt ~= nil and drawAt ~= nil).toBeTrue()
		expect((blockAt :: number) < (spendAt :: number)).toBeTrue()
		expect((spendAt :: number) < (drawAt :: number)).toBeTrue()
		local crackAt = string.find(roll, "local function crack(", 1, true) :: number
		local single = string.sub(roll, crackAt, batchAt)
		local fullAt = string.find(single, 'return "Inventory is full."', 1, true)
		local takeAt = string.find(single, "Currencies.take(data, currency)", 1, true)
		expect(fullAt ~= nil and takeAt ~= nil and (fullAt :: number) < (takeAt :: number)).toBeTrue()
		expect(string.find(roll, 'LaunchGate.on("gearLevels")', 1, true) ~= nil).toBeTrue()
	end)
end)
