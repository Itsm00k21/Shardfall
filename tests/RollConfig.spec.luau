--!strict

--[[
	RollConfig: the x10 discount and the free Epic+ pity meter that
	Kevin approved on Oct 19 2026. The math is pure; the server batch is
	checked by a source lock because RollService needs Roblox services.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local RollBatch = require("../src/ReplicatedStorage/Shared/RollBatch")
local RollConfig = require("../src/ReplicatedStorage/Shared/RollConfig")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function ladderPool()
	local entries = {}
	for _, rarity in ipairs(Rarities.ORDER) do
		table.insert(entries, {
			templateId = string.lower(rarity),
			name = rarity .. " Shard",
			rarity = rarity,
			weight = 1,
			kind = "Weapon",
		})
	end
	return { id = "test", entries = entries }
end

local function scripted(value: number)
	return {
		nextNumber = function(_self)
			return value
		end,
		nextInteger = function(_self, min, _max)
			return min
		end,
	}
end

-- The live crack's pity step: pick, then advance, exactly as drawInto.
local function crack(counters: any, rng: any): (string, boolean)
	local rarity, triggered, floor = RarityConfig.pick(ladderPool(), 1, counters, rng)
	RarityConfig.advance(counters, rarity, floor)
	return rarity, triggered
end

local MISS = 0.999

describe("RollConfig discount", function()
	it("prices x10 at exactly 10% less than ten singles", function()
		expect(RollConfig.SINGLE_COST).toEqual(1)
		expect(RollConfig.MULTI_COUNT).toEqual(10)
		expect(RollConfig.cost(1)).toEqual(1)
		expect(RollConfig.cost(10)).toEqual(9)
		expect(RollConfig.multiCost()).toEqual(9)
		local ten = 10 * RollConfig.cost(1)
		expect((ten - RollConfig.cost(10)) / ten).toEqual(RollConfig.MULTI_DISCOUNT)
		expect(RollConfig.savings(10)).toEqual(1)
		expect(RollConfig.discountTag()).toEqual("-10%")
	end)

	it("charges plain singles for any count that is not the x10 press", function()
		for count = 1, 9 do
			expect(RollConfig.cost(count)).toEqual(count)
			expect(RollConfig.savings(count)).toEqual(0)
		end
		expect(RollConfig.cost(0)).toEqual(0)
		expect(RollConfig.cost(-4)).toEqual(0)
		expect(RollConfig.cost(0 / 0)).toEqual(0)
		expect(RollConfig.cost(math.huge)).toEqual(0)
		expect(RollConfig.cost("10")).toEqual(0)
		expect(RollConfig.cost(10.7)).toEqual(9)
	end)

	it("blocks a batch on price, then on Bag room, before anything is spent", function()
		expect(RollConfig.batchBlock(8, 50, 10)).toEqual("Need 9 shards")
		expect(RollConfig.batchBlock(0 / 0, 50, 10)).toEqual("Need 9 shards")
		expect(RollConfig.batchBlock(9, 9, 10)).toEqual("Bag needs 10 free slots.")
		expect(RollConfig.batchBlock(9, -2, 10)).toEqual("Bag needs 10 free slots.")
		expect(RollConfig.batchBlock(9, 10, 10)).toBeNil()
		expect(RollConfig.batchBlock(999, 999, 0)).toEqual("Pick 1 to 10 cracks.")
	end)

	it("makes the client x10 gate agree with the server price", function()
		expect(RollBatch.NEED).toEqual("Need 9 shards")
		expect(RollBatch.block(8, 10)).toEqual("Need 9 shards")
		expect(RollBatch.block(9, 10)).toBeNil()
		expect(RollBatch.block(0, 1)).toBeNil()
	end)

	it("runs x10 as one paid, all-or-nothing server batch", function()
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		local manyAt = string.find(roll, "function RollService.rollMany", 1, true) :: number
		local many = string.sub(roll, manyAt, manyAt + 900)
		expect(string.find(many, "if total == RollConfig.MULTI_COUNT then", 1, true) ~= nil).toBeTrue()
		expect(string.find(many, "return crackBatch(player, poolId, total)", 1, true) ~= nil).toBeTrue()

		local batchAt = string.find(roll, "local function crackBatch", 1, true) :: number
		local batch = string.sub(roll, batchAt, manyAt)
		local priceAt = string.find(batch, "local price = RollConfig.cost(total)", 1, true)
		local blockAt = string.find(batch, "RollConfig.batchBlock(data.shardTokens, free, total)", 1, true)
		local spendAt = string.find(batch, "data.shardTokens -= price", 1, true)
		local drawAt = string.find(batch, "drawInto(data, pool, rng)", 1, true)
		expect(priceAt ~= nil and blockAt ~= nil and spendAt ~= nil and drawAt ~= nil).toBeTrue()
		expect((blockAt :: number) < (spendAt :: number)).toBeTrue()
		expect((spendAt :: number) < (drawAt :: number)).toBeTrue()
		-- The whole batch sits inside one DataService.mutate, which restores
		-- the backup on any returned error, so a failed draw refunds all.
		expect(string.find(batch, "DataService.mutate(player, function(data)", 1, true) ~= nil).toBeTrue()
		expect(string.find(batch, "Currencies.take", 1, true)).toBeNil()
		expect(string.find(batch, "vouchers", 1, true)).toBeNil()

		-- Single cracks check Bag room before they spend too.
		local crackAt = string.find(roll, "local function crack(", 1, true) :: number
		local single = string.sub(roll, crackAt, batchAt)
		local fullAt = string.find(single, 'return "Inventory is full."', 1, true)
		local takeAt = string.find(single, "Currencies.take(data, currency)", 1, true)
		expect(fullAt ~= nil and takeAt ~= nil and (fullAt :: number) < (takeAt :: number)).toBeTrue()
	end)
end)

describe("RollConfig pity", function()
	it("guarantees Epic+ at 50, inside Kevin's 40-50 range", function()
		expect(RollConfig.EPIC_PITY).toEqual(50)
		expect(RarityConfig.EPIC_PITY).toEqual(RollConfig.EPIC_PITY)
		expect(RarityConfig.LEGENDARY_PITY).toEqual(RollConfig.LEGENDARY_PITY)
		expect(RollConfig.EPIC_PITY >= 40 and RollConfig.EPIC_PITY <= 50).toBeTrue()
	end)

	it("counts down Epic+ guaranteed in N and fires on crack 50", function()
		local counters = { sinceEpic = 0, sinceLegendary = 0 }
		local rng = scripted(MISS)
		expect(RollConfig.pityText(counters.sinceEpic)).toEqual("Epic+ guaranteed in 50")
		for step = 1, 49 do
			local rarity, triggered = crack(counters, rng)
			expect(rarity).toEqual("Common")
			expect(triggered).toEqual(false)
			expect(counters.sinceEpic).toEqual(step)
			expect(RollConfig.pityLeft(counters.sinceEpic)).toEqual(50 - step)
		end
		expect(RollConfig.pityText(counters.sinceEpic)).toEqual("Epic+ guaranteed in 1")
		expect(RollConfig.pityFill(counters.sinceEpic)).toEqual(49 / 50)
		local forced, fired = crack(counters, rng)
		expect(fired).toEqual(true)
		expect(Rarities.rank(forced) >= Rarities.rank("Epic")).toBeTrue()
		expect(counters.sinceEpic).toEqual(0)
		expect(counters.sinceLegendary).toEqual(50)
		expect(RollConfig.pityText(counters.sinceEpic)).toEqual("Epic+ guaranteed in 50")
	end)

	it("resets on a natural Epic, and a Legendary resets both meters", function()
		local counters = { sinceEpic = 20, sinceLegendary = 300 }
		-- 1/250 (Epic) passes at 0.0039; rarer checks need smaller draws.
		local epic = crack(counters, scripted(0.0039))
		expect(epic).toEqual("Epic")
		expect(counters.sinceEpic).toEqual(0)
		expect(counters.sinceLegendary).toEqual(301)

		counters.sinceEpic = 33
		local legendary = crack(counters, scripted(0.0003))
		expect(legendary).toEqual("Legendary")
		expect(counters.sinceEpic).toEqual(0)
		expect(counters.sinceLegendary).toEqual(0)
	end)

	it("fires mid-batch: an x10 from 45 forces crack 5, then counts again", function()
		local counters = { sinceEpic = 45, sinceLegendary = 45 }
		local rng = scripted(MISS)
		local firedAt = nil
		for index = 1, RollConfig.MULTI_COUNT do
			local _, fired = crack(counters, rng)
			if fired then
				firedAt = index
			end
		end
		expect(firedAt).toEqual(5)
		expect(counters.sinceEpic).toEqual(5)
	end)

	it("clamps bad counters and never shows 0 left", function()
		expect(RollConfig.pityLeft(nil)).toEqual(50)
		expect(RollConfig.pityLeft(-3)).toEqual(50)
		expect(RollConfig.pityLeft(0 / 0)).toEqual(50)
		expect(RollConfig.pityLeft(80)).toEqual(1)
		expect(RollConfig.pityFill(80)).toEqual(1)
		expect(RollConfig.pityFill(nil)).toEqual(0)
	end)

	it("saves the meter per player in the existing sinceEpic field", function()
		local fresh = Schema.template()
		expect(fresh.sinceEpic).toEqual(0)
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		expect(string.find(roll, "data.sinceEpic = counters.sinceEpic", 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "left = RollConfig.pityLeft(captured.sinceEpic)", 1, true) ~= nil).toBeTrue()
	end)

	it("states the guarantee on the odds sheet, and it is never sold", function()
		local sheet = RarityConfig.disclose(ladderPool(), 1, 12)
		expect(string.find(sheet.notice, "Epic+ guaranteed in 38", 1, true) ~= nil).toBeTrue()
		expect(string.find(sheet.notice, "never sold", 1, true) ~= nil).toBeTrue()
		expect(string.find(sheet.notice, "Epic+ at 50", 1, true) ~= nil).toBeTrue()
		expect(sheet.pityLeft).toEqual(38)
		local plain = RarityConfig.disclose(ladderPool(), 1)
		expect(string.find(plain.notice, "guaranteed in", 1, true)).toBeNil()
		local remotes = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		expect(
			string.find(remotes, "RarityConfig.disclose(pool, luck, if data ~= nil then data.sinceEpic else nil)", 1, true)
				~= nil
		).toBeTrue()
		local config = fs.readFile("src/ReplicatedStorage/Shared/RollConfig.luau")
		expect(string.find(config, "Robux", 1, true) ~= nil).toBeTrue() -- only the "costs Robux" disclaimer
		expect(string.find(config, "MarketplaceService", 1, true)).toBeNil()
	end)
end)
