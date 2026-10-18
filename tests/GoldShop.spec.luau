--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local GoldShop = require("../src/ReplicatedStorage/Shared/GoldShop")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function purse(gold: number)
	local data = Schema.template()
	data.gold = gold
	data.consumables = { [Materials.TONIC_ID] = 0 }
	return data
end

describe("GoldShop", function()
	it("sells a tonic, a bag slot, and a pet slot for Gold", function()
		local ids = {}
		for _, offer in ipairs(GoldShop.offers()) do
			table.insert(ids, offer.id)
			expect(offer.price > 0).toBeTrue()
		end
		expect(ids).toEqual({ "tonic", "bag", "pet" })
		local data = purse(1000)
		expect(GoldShop.apply(data, "tonic", { paid = true })).toBeNil()
		expect(data.gold).toEqual(960)
		expect(data.consumables[Materials.TONIC_ID]).toEqual(1)
		expect(GoldShop.apply(data, "bag")).toBeNil()
		expect(data.inventoryBonus).toEqual(1)
		expect(data.gold).toEqual(710)
		expect(GoldShop.petCap(data)).toEqual(3)
		expect(GoldShop.apply(data, "pet")).toBeNil()
		expect(data.petSlotBonus).toEqual(1)
		expect(GoldShop.petCap(data)).toEqual(4)
		expect(data.gold).toEqual(310)
	end)

	it("refuses a short purse, a full stack, and an unknown offer", function()
		local broke = purse(10)
		expect(GoldShop.apply(broke, "tonic")).toEqual("You need more Gold.")
		expect(broke.gold).toEqual(10)
		expect(broke.consumables[Materials.TONIC_ID]).toEqual(0)
		local full = purse(5000)
		full.consumables[Materials.TONIC_ID] = Materials.TONIC_CAP
		expect(GoldShop.apply(full, "tonic")).toEqual("You cannot carry more tonics.")
		expect(full.gold).toEqual(5000)
		full.inventoryBonus = GoldShop.BAG_BONUS_CAP
		expect(GoldShop.apply(full, "bag")).toEqual("Your bag cannot grow more.")
		full.petSlotBonus = GoldShop.PET_BONUS_CAP
		expect(GoldShop.apply(full, "pet")).toEqual("You cannot equip more pets.")
		expect(GoldShop.apply(full, "nope")).toEqual("That is not for sale.")
		expect(GoldShop.apply(full, 1)).toEqual("That is not for sale.")
		local weird = purse(100)
		weird.gold = 0 / 0
		expect(GoldShop.apply(weird, "tonic")).toEqual("You need more Gold.")
	end)
end)
