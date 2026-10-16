--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local function atLeast(rarity: string, floor: string): boolean
	return Rarities.rank(rarity) >= Rarities.rank(floor)
end

local function profile()
	local data = Schema.template()
	ChestConfig.ensure(data)
	return data
end

local function rng(numberValue: number)
	return {
		nextNumber = function()
			return numberValue
		end,
		nextInteger = function(_self, min)
			return min
		end,
	}
end

local function uidFactory()
	local n = 0
	return function()
		n += 1
		return "chest-uid-" .. tostring(n)
	end
end

describe("ChestConfig", function()
	it("keeps each chest row at 100 and a floor of zero below it", function()
		for _, tier in ipairs(ChestConfig.TIERS) do
			local chances = ChestConfig.chances(tier, 1, nil)
			local sum = 0
			for _, rarity in ipairs(ChestConfig.TIERS) do
				sum += chances[rarity] * 100
			end
			expect(math.abs(sum - 100) < 1e-6).toBeTrue()
		end
		local common = ChestConfig.chances("Common", 1, nil)
		expect(math.abs(common.Common * 100 - 70) < 1e-6).toBeTrue()
		expect(math.abs(common.Epic * 100 - 0.5) < 1e-6).toBeTrue()
		local rare = ChestConfig.chances("Rare", 1, nil)
		expect(rare.Common).toEqual(0)
		expect(rare.Uncommon).toEqual(0)
		expect(math.abs(rare.Rare * 100 - 80) < 1e-6).toBeTrue()
		expect(math.abs(rare.Mythic * 100 - 0.2) < 1e-6).toBeTrue()
		expect(ChestConfig.chances("Mythic", 1, nil).Mythic).toEqual(1)
	end)

	it("moves luck only inside the allowed rarities", function()
		local plain = ChestConfig.chances("Epic", 1, nil)
		local lucky = ChestConfig.chances("Epic", 2, nil)
		expect(plain.Common).toEqual(0)
		expect(lucky.Common).toEqual(0)
		expect(lucky.Rare).toEqual(0)
		expect(lucky.Mythic > plain.Mythic).toBeTrue()
		expect(lucky.Epic < plain.Epic).toBeTrue()
		local line = ChestConfig.oddsLines("Legendary", 1)[5]
		expect(string.find(line, "Legendary", 1, true) ~= nil).toBeTrue()
		expect(string.find(line, "%", 1, true) ~= nil).toBeTrue()
	end)

	it("sells Uncommon, Rare, and Epic for keys and never Legendary or Mythic", function()
		expect(ChestConfig.KEY_SHOP.Uncommon).toEqual(40)
		expect(ChestConfig.KEY_SHOP.Rare).toEqual(150)
		expect(ChestConfig.KEY_SHOP.Epic).toEqual(600)
		expect(ChestConfig.forSale("Legendary")).toEqual(false)
		expect(ChestConfig.forSale("Mythic")).toEqual(false)
		expect(ChestConfig.forSale("Common")).toEqual(false)
		local data = profile()
		data.shardKeys = 40
		local bought = ChestConfig.buyWithKeys(data, "Uncommon")
		expect(bought.tier).toEqual("Uncommon")
		expect(data.chests.Uncommon).toEqual(1)
		expect(data.shardKeys).toEqual(0)
		local _, denied = ChestConfig.buyWithKeys(data, "Legendary")
		expect(denied).toEqual("That chest is not sold.")
		local pitch = ChestConfig.bundlePitch()
		expect(string.find(pitch, "Legendary and Mythic chests are not sold.", 1, true) ~= nil).toBeTrue()
		expect(string.find(pitch, "BUY NOW", 1, true) == nil).toBeTrue()
		expect(ChestConfig.PAID_CHESTS_ENABLED).toEqual(true)
	end)

	it("merges 5 chests into the next tier and makes Mythic only that way", function()
		local data = profile()
		data.chests.Legendary = 5
		data.materials.gnarl_seed = 2
		local merged = ChestConfig.merge(data, "Legendary")
		expect(merged.to).toEqual("Mythic")
		expect(data.chests.Legendary).toEqual(0)
		expect(data.chests.Mythic).toEqual(1)
		expect(data.materials.gnarl_seed).toEqual(0)
		local _, mythic = ChestConfig.merge(data, "Mythic")
		expect(mythic).toEqual("That chest cannot be merged.")
		local _, short = ChestConfig.merge(data, "Common")
		expect(short).toEqual("Merge needs 5 chests.")
	end)

	it("guarantees Epic+ after 20 Rare chests and Legendary after 15 Epic chests", function()
		local data = profile()
		data.chests.Rare = 1
		data.rareChestsSinceEpic = 19
		local opened = ChestConfig.open(data, "Rare", 1, rng(0), 1000, uidFactory())
		expect(opened.ok).toEqual(true)
		expect(atLeast(opened.results[1].rarity, "Epic")).toBeTrue()
		expect(data.rareChestsSinceEpic).toEqual(0)

		data.chests.Epic = 1
		data.epicChestsSinceLegendary = 14
		local epic = ChestConfig.open(data, "Epic", 1, rng(0), 1000, uidFactory())
		expect(atLeast(epic.results[1].rarity, "Legendary")).toBeTrue()
		expect(data.epicChestsSinceLegendary).toEqual(0)

		data.chests.Rare = 1
		data.rareChestsSinceEpic = 18
		local early = ChestConfig.open(data, "Rare", 1, rng(0), 1000, uidFactory())
		expect(early.results[1].rarity).toEqual("Rare")
		expect(data.rareChestsSinceEpic).toEqual(19)
	end)

	it("turns a duplicate into dust and materials, and dust buys a chosen shard", function()
		local data = profile()
		data.chests.Common = 1
		local first = ChestConfig.open(data, "Common", 1, rng(0), 1000, uidFactory())
		expect(first.results[1].kind).toEqual("item")
		data.chests.Common = 1
		local second = ChestConfig.open(data, "Common", 1, rng(0), 1000, uidFactory())
		expect(second.results[1].kind).toEqual("dust")
		expect(second.results[1].dust).toEqual(ChestConfig.DUST[second.results[1].rarity])
		expect(data.shardDust >= 5).toBeTrue()

		data.chestDuplicates = "star"
		data.chests.Common = 1
		local starred = ChestConfig.open(data, "Common", 1, rng(0), 1000, uidFactory())
		expect(starred.results[1].kind).toEqual("star")
		expect(starred.results[1].stars >= 1).toBeTrue()

		data.shardDust = 2000
		local catalog = ChestConfig.dustCatalog(data)
		expect(#catalog > 0).toBeTrue()
		local epic = nil
		for _, row in ipairs(catalog) do
			if row.rarity == "Epic" then
				epic = row
				break
			end
		end
		assert(epic ~= nil)
		expect(epic.cost).toEqual(2000)
		local bought = ChestConfig.buyDustShard(data, epic.templateId, rng(0), 1000, uidFactory())
		expect(bought.ok).toEqual(true)
		expect(bought.rarity).toEqual("Epic")
		expect(data.shardDust).toEqual(0)
		local mythicTry =
			ChestConfig.buyDustShard(data, "unnamed_grove", rng(0), 1000, uidFactory())
		expect(mythicTry.ok).toEqual(false)
	end)

	it("claims a daily common chest and an epic on the 7th day", function()
		local data = profile()
		local first = ChestConfig.claimLogin(data, 86400 * 10)
		expect(first[1].tier).toEqual("Common")
		expect(data.loginStreak).toEqual(1)
		expect(data.shardKeys).toEqual(5)
		local _, again = ChestConfig.claimLogin(data, 86400 * 10)
		expect(again).toEqual("Daily login is already claimed.")
		for day = 11, 16 do
			ChestConfig.claimLogin(data, 86400 * day)
		end
		expect(data.loginStreak).toEqual(7)
		expect(data.chests.Epic).toEqual(1)
		expect(data.chests.Common).toEqual(7)
	end)

	it("drops a common chest from verdant enemies and pays the boss ladder", function()
		local data = profile()
		expect(ChestConfig.enemyDrop(data, "vine_crawler", rng(0.5))).toBeNil()
		local drop = ChestConfig.enemyDrop(data, "vine_crawler", rng(0.01))
		expect(drop.tier).toEqual("Common")
		expect(data.chests.Common).toEqual(1)
		expect(ChestConfig.enemyDrop(data, "grandmother_gnarl", rng(0))).toBeNil()
		local kills = ChestConfig.bossKill(data, 86400 * 3)
		expect(kills[1].tier).toEqual("Rare")
		expect(kills[2].tier).toEqual("Epic")
		expect(kills[3].tier).toEqual("Legendary")
		local again = ChestConfig.bossKill(data, 86400 * 3 + 100)
		expect(#again).toEqual(1)
		expect(again[1].tier).toEqual("Rare")
	end)

	it("opens many into a grid and holds a Mythic choice", function()
		local data = profile()
		data.chests.Common = 4
		local opened = ChestConfig.open(data, "Common", 4, rng(0), 1000, uidFactory())
		expect(#opened.results).toEqual(4)
		expect(opened.bestIndex >= 1).toBeTrue()
		expect(ChestConfig.playFullReveal("Common", "Rare", true)).toEqual(false)
		expect(ChestConfig.playFullReveal("Common", "Legendary", true)).toEqual(true)
		expect(ChestConfig.playFullReveal("Epic", "Epic", false)).toEqual(true)
		expect(ChestConfig.OPEN_SECONDS.Common).toEqual(1.5)
		expect(ChestConfig.OPEN_SECONDS.Rare).toEqual(2.2)
		expect(ChestConfig.OPEN_SECONDS.Epic).toEqual(2.8)
		expect(ChestConfig.OPEN_SECONDS.Legendary).toEqual(3.5)
		expect(ChestConfig.OPEN_SECONDS.Mythic).toEqual(4)
		expect(ChestConfig.REEL_SECONDS.Common).toEqual(1)
		expect(ChestConfig.REEL_SECONDS.Rare).toEqual(1.4)

		data.chests.Mythic = 1
		local mythic = ChestConfig.open(data, "Mythic", 1, rng(0), 1000, uidFactory())
		expect(#mythic.pending.options).toEqual(3)
		expect(#mythic.results).toEqual(0)
		expect(data.chests.Mythic).toEqual(0)
		local chosen = ChestConfig.choose(data, 2, rng(0), 1000, uidFactory())
		expect(chosen.ok).toEqual(true)
		expect(chosen.results[1].rarity).toEqual("Mythic")
		expect(data.pendingChest).toBeNil()
	end)

	it("refuses the later hooks", function()
		expect(ChestConfig.later("realmChests").ok).toEqual(false)
		expect(ChestConfig.later("keyShardSocket").ok).toEqual(false)
		expect(ChestConfig.later("crackedChests").ok).toEqual(false)
		expect(ChestConfig.later("partyChests").ok).toEqual(false)
		expect(ChestConfig.later("upgradeGamble").ok).toEqual(false)
		expect(ChestConfig.later("nope").error).toEqual("Unknown chest hook.")
	end)
end)
