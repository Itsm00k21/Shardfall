--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RollMath = require("../src/ReplicatedStorage/Shared/RollMath")
local Traits = require("../src/ReplicatedStorage/Shared/Traits")

local function context(uid: string, luck: number)
	return { luck = luck, uid = uid, now = 1_700_000_000 }
end

-- Always walks to the first positive-weight entry, and always rolls the
-- minimum trait value. Pity tests use this so they do not depend on chance.
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

local function seededRng(seed: number)
	local state = seed
	local function nextWord()
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		if state == 0 then
			state = 1
		end
		return state
	end
	return {
		nextNumber = function()
			return nextWord() / 4294967296
		end,
		nextInteger = function(_self, min, max)
			local span = max - min + 1
			return min + (nextWord() % span)
		end,
	}
end

local function starter()
	local pool = Pools.get(Pools.DEFAULT_POOL_ID)
	assert(pool ~= nil, "starter pool missing")
	return pool
end

describe("RollMath odds", function()
	it("marks the starter pool as placeholder and explains pity", function()
		local odds = RollMath.odds(starter(), 0)
		expect(odds.placeholder).toBeTrue()
		expect(string.find(odds.notice, "PLACEHOLDER", 1, true) ~= nil).toBeTrue()
		expect(string.find(odds.notice, "pity", 1, true) ~= nil).toBeTrue()
		expect(odds.pityLegendaryAt).toEqual(50)
	end)

	it("publishes chances that sum to 1 and match the weights at 0 luck", function()
		local pool = starter()
		local odds = RollMath.odds(pool, 0)
		local sum = 0
		local byId = {}
		for _, entry in ipairs(odds.entries) do
			sum += entry.chance
			byId[entry.templateId] = entry
		end
		expect(sum).toBeCloseTo(1, 1e-12)

		local weightSum = 0
		for _, entry in ipairs(pool.entries) do
			weightSum += entry.weight
		end
		expect(weightSum).toEqual(10000)
		expect(byId.vinewood_sword.chance).toBeCloseTo(1000 / 10000, 1e-12)
		expect(byId.unnamed_grove.chance).toBeCloseTo(2 / 10000, 1e-12)
		expect(RollMath.formatChance(byId.vinewood_sword.chance)).toEqual("10.00%")
		expect(RollMath.formatChance(byId.unnamed_grove.chance)).toEqual("0.020%")
	end)

	it("publishes rarity totals as the sum of those weights", function()
		local pool = starter()
		local odds = RollMath.odds(pool, 0)
		local weightByRarity: { [string]: number } = {}
		local weightSum = 0
		for _, entry in ipairs(pool.entries) do
			weightSum += entry.weight
			weightByRarity[entry.rarity] = (weightByRarity[entry.rarity] or 0) + entry.weight
		end
		expect(#odds.rarities).toEqual(7)
		for _, row in ipairs(odds.rarities) do
			local weight = weightByRarity[row.rarity]
			assert(weight ~= nil, row.rarity)
			expect(row.chance).toBeCloseTo(weight / weightSum, 1e-12)
			expect(row.chance).toBeGreaterThan(0)
		end
		local function rarityChance(rarity: string): number
			for _, row in ipairs(odds.rarities) do
				if row.rarity == rarity then
					return row.chance
				end
			end
			error(rarity)
		end
		-- Not a 60 / 30 / 9 / 0.9 curve. Common is 60% because Splinter is 35%
		-- and Wooden Sword is 25%. Secret stays visible at 0.020%, not 0%.
		expect(rarityChance("Common")).toBeCloseTo(0.60, 1e-12)
		expect(rarityChance("Uncommon")).toBeCloseTo(0.25, 1e-12)
		expect(rarityChance("Rare")).toBeCloseTo(0.10, 1e-12)
		expect(rarityChance("Epic")).toBeCloseTo(0.04, 1e-12)
		expect(rarityChance("Legendary")).toBeCloseTo(0.008, 1e-12)
		expect(rarityChance("Mythic")).toBeCloseTo(0.0018, 1e-12)
		expect(rarityChance("Secret")).toBeCloseTo(0.0002, 1e-12)
		expect(RollMath.formatChance(rarityChance("Common"))).toEqual("60.00%")
		expect(RollMath.formatChance(rarityChance("Uncommon"))).toEqual("25.00%")
		expect(RollMath.formatChance(rarityChance("Secret"))).toEqual("0.020%")
	end)

	it(
		"sums to 100% with luck, a boost, and an active pity roll, and lists no empty outcome",
		function()
			local pool = starter()
			local boosted = RollMath.odds(pool, 0, { rollsSinceLegendary = 0, luckBoost = 25 })
			local earned = RollMath.odds(pool, 25)
			expect(boosted.luck).toEqual(25)
			expect(boosted.luckBoost).toEqual(25)
			local boostedSum = 0
			for _, entry in ipairs(boosted.entries) do
				boostedSum += entry.chance
				expect(entry.chance).toBeGreaterThan(0)
				expect(entry.name ~= "").toBeTrue()
				expect(entry.kind ~= "Nothing").toBeTrue()
			end
			expect(boostedSum).toBeCloseTo(1, 1e-12)
			expect(#boosted.entries).toEqual(#earned.entries)
			local function chanceOf(odds, templateId: string): number
				for _, entry in ipairs(odds.entries) do
					if entry.templateId == templateId then
						return entry.chance
					end
				end
				error(templateId)
			end
			expect(chanceOf(boosted, "vinewood_sword")).toBeCloseTo(
				chanceOf(earned, "vinewood_sword"),
				1e-12
			)
			expect(string.find(boosted.notice, "Luck Boost", 1, true) ~= nil).toBeTrue()

			local pity = RollMath.odds(pool, 25, {
				rollsSinceLegendary = pool.pityLegendaryAt - 1,
				luckBoost = 25,
			})
			expect(pity.pityActive).toBeTrue()
			local pitySum = 0
			for _, entry in ipairs(pity.entries) do
				pitySum += entry.chance
				expect(entry.chance).toBeGreaterThan(0)
				local legendary = entry.rarity == "Legendary"
					or entry.rarity == "Mythic"
					or entry.rarity == "Secret"
				expect(legendary).toBeTrue()
			end
			expect(pitySum).toBeCloseTo(1, 1e-12)
			expect(#pity.entries).toBeLessThan(#boosted.entries)
			expect(string.find(pity.notice, "pity", 1, true) ~= nil).toBeTrue()
		end
	)

	it("shifts the disclosed odds at 25 Shard Luck without changing the table", function()
		local odds = RollMath.odds(starter(), 25)
		local function formatted(rarity: string): string
			for _, row in ipairs(odds.rarities) do
				if row.rarity == rarity then
					return RollMath.formatChance(row.chance)
				end
			end
			error(rarity)
		end
		expect(formatted("Common")).toEqual("57.05%")
		expect(formatted("Uncommon")).toEqual("25.70%")
		expect(formatted("Rare")).toEqual("11.12%")
		expect(formatted("Epic")).toEqual("4.81%")
		expect(formatted("Legendary")).toEqual("1.04%")
		expect(formatted("Mythic")).toEqual("0.253%")
		expect(formatted("Secret")).toEqual("0.030%")
		local plain = RollMath.odds(starter(), 0)
		local function chanceOf(odds, templateId: string): number
			for _, entry in ipairs(odds.entries) do
				if entry.templateId == templateId then
					return entry.chance
				end
			end
			error(templateId)
		end
		expect(chanceOf(odds, "vinewood_sword")).toBeLessThan(chanceOf(plain, "vinewood_sword"))
		expect(chanceOf(odds, "unnamed_grove")).toBeGreaterThan(chanceOf(plain, "unnamed_grove"))
	end)

	it("describes pity as a count up toward the guarantee", function()
		expect(RollMath.pityText(0, 50)).toEqual("Pity 0 / 50 toward Legendary")
		expect(RollMath.pityText(7, 50)).toEqual("Pity 7 / 50 toward Legendary")
		expect(RollMath.pityText(8, 50)).toEqual("Pity 8 / 50 toward Legendary")
		expect(RollMath.pityText(18, 50)).toEqual("Pity 18 / 50 toward Legendary")
		expect(RollMath.pityText(50, 50)).toEqual("Pity 50 / 50 toward Legendary")
		expect(RollMath.pityText(-3, 50)).toEqual("Pity 0 / 50 toward Legendary")
	end)

	it("keeps the starter weights easy to read as percents", function()
		local sum = 0
		for _, entry in ipairs(starter().entries) do
			sum += entry.weight
			expect(Rarities.INDEX[entry.rarity] ~= nil).toBeTrue()
		end
		expect(sum).toEqual(10000)
	end)

	it("shifts chance toward rarer tiers as Shard Luck rises", function()
		local plain = RollMath.odds(starter(), 0)
		local lucky = RollMath.odds(starter(), 200)
		local function chanceOf(odds, templateId)
			for _, entry in ipairs(odds.entries) do
				if entry.templateId == templateId then
					return entry.chance
				end
			end
			error("missing " .. templateId)
		end
		expect(chanceOf(lucky, "unnamed_grove")).toBeGreaterThan(chanceOf(plain, "unnamed_grove"))
		expect(chanceOf(lucky, "vinewood_sword")).toBeLessThan(chanceOf(plain, "vinewood_sword"))

		local function averageRank(odds)
			local total = 0
			for _, row in ipairs(odds.rarities) do
				total += row.chance * Rarities.rank(row.rarity)
			end
			return total
		end
		expect(averageRank(lucky)).toBeGreaterThan(averageRank(plain))
	end)

	it("treats negative luck as zero", function()
		local plain = RollMath.odds(starter(), 0)
		local negative = RollMath.odds(starter(), -50)
		expect(#plain.entries).toEqual(#negative.entries)
		for index, entry in ipairs(plain.entries) do
			expect(negative.entries[index].chance).toBeCloseTo(entry.chance, 1e-12)
		end
	end)

	it("omits a zero-weight entry from the disclosed table", function()
		local odds = RollMath.odds({
			id = "tiny",
			name = "Tiny",
			pityLegendaryAt = 10,
			placeholder = false,
			entries = {
				{
					templateId = "real",
					name = "Real",
					rarity = "Common",
					weight = 1,
					kind = "Material",
				},
				{
					templateId = "gone",
					name = "Gone",
					rarity = "Rare",
					weight = 0,
					kind = "Weapon",
				},
			},
		}, 0)
		expect(#odds.entries).toEqual(1)
		expect(odds.entries[1].templateId).toEqual("real")
		expect(odds.placeholder).toBeFalse()
	end)
end)

describe("RollMath rolls", function()
	it("picks the first positive entry when the rng returns 0", function()
		local pity = { rollsSinceLegendary = 0, totalRolls = 0 }
		local result = RollMath.roll(starter(), pity, context("uid-1", 0), zeroRng())
		expect(result.item.templateId).toEqual("vinewood_sword")
		expect(result.item.uid).toEqual("uid-1")
		expect(result.item.kind).toEqual("Weapon")
		expect(result.item.weaponType).toEqual("sword")
		expect(result.item.quality).toEqual(0)
		expect(result.item.stats[1].id).toEqual("damage")
		expect(result.item.stats[1].value).toEqual(10)
		expect(result.item.stats[1].min).toEqual(10)
		expect(result.item.stats[1].max).toEqual(14)
		expect(#result.item.traits).toEqual(0)
		expect(result.pityTriggered).toBeFalse()
		expect(pity.rollsSinceLegendary).toEqual(1)
		expect(pity.totalRolls).toEqual(1)
	end)

	it("guarantees Legendary or better on the pity roll and then resets", function()
		local pity = { rollsSinceLegendary = 0, totalRolls = 0 }
		local rng = zeroRng()
		for n = 1, 49 do
			local result = RollMath.roll(starter(), pity, context("n" .. n, 0), rng)
			expect(result.pityTriggered).toBeFalse()
			expect(Rarities.isLegendaryOrBetter(result.item.rarity)).toBeFalse()
		end
		expect(pity.rollsSinceLegendary).toEqual(49)

		local forced = RollMath.roll(starter(), pity, context("pity", 0), rng)
		expect(forced.pityTriggered).toBeTrue()
		expect(Rarities.isLegendaryOrBetter(forced.item.rarity)).toBeTrue()
		-- zeroRng selects the first Legendary-or-better row.
		expect(forced.item.templateId).toEqual("antlerbrand")
		expect(pity.rollsSinceLegendary).toEqual(0)
		expect(pity.totalRolls).toEqual(50)
	end)

	it("does not let one pool's pity advance another pool", function()
		local left = { rollsSinceLegendary = 0, totalRolls = 0 }
		local right = { rollsSinceLegendary = 4, totalRolls = 4 }
		RollMath.roll(starter(), left, context("a", 0), zeroRng())
		expect(left.rollsSinceLegendary).toEqual(1)
		expect(right.rollsSinceLegendary).toEqual(4)
		expect(right.totalRolls).toEqual(4)
	end)

	it("resets pity on a natural Legendary without marking it forced", function()
		local pool = {
			id = "only_legend",
			name = "Only",
			pityLegendaryAt = 50,
			placeholder = true,
			entries = {
				{
					templateId = "oath",
					name = "Oath",
					rarity = "Legendary",
					weight = 1,
					kind = "Weapon",
				},
			},
		}
		local pity = { rollsSinceLegendary = 10, totalRolls = 10 }
		local result = RollMath.roll(pool, pity, context("legend", 0), zeroRng())
		expect(result.pityTriggered).toBeFalse()
		expect(result.item.rarity).toEqual("Legendary")
		expect(pity.rollsSinceLegendary).toEqual(0)
	end)

	it("rolls weapon traits, pet traits, and none for materials", function()
		local function rollKind(kind: string, rarity: string)
			local pool = {
				id = "one",
				name = "One",
				pityLegendaryAt = 100,
				entries = {
					{
						templateId = "item",
						name = "Item",
						rarity = rarity,
						weight = 1,
						kind = kind,
					},
				},
			}
			local pity = { rollsSinceLegendary = 0, totalRolls = 0 }
			return RollMath.roll(pool, pity, context("item", 0), zeroRng())
		end

		expect(#rollKind("Material", "Secret").item.traits).toEqual(0)
		expect(#rollKind("Pet", "Common").item.traits).toEqual(0)
		local pet = rollKind("Pet", "Secret")
		expect(#pet.item.traits).toEqual(3)
		expect(pet.item.traits[1].id).toEqual("bonus_pet_damage")
		expect(#rollKind("Armor", "Rare").item.traits).toEqual(1)

		local rare = rollKind("Weapon", "Rare")
		expect(#rare.item.traits).toEqual(1)
		expect(rare.item.traits[1].id).toEqual("lifesteal")
		expect(rare.item.traits[1].display).toEqual("2.0%")

		local legendary = rollKind("Weapon", "Legendary")
		expect(#legendary.item.traits).toEqual(2)

		local secret = rollKind("Weapon", "Secret")
		expect(#secret.item.traits).toEqual(3)
		local seen = {}
		for _, trait in ipairs(secret.item.traits) do
			expect(seen[trait.id] == nil).toBeTrue()
			seen[trait.id] = true
			expect(Traits.isKnown(trait.id)).toBeTrue()
		end
	end)

	it("follows a fixed weight split for a two-entry pool", function()
		local pool = {
			id = "split",
			name = "Split",
			pityLegendaryAt = 100,
			entries = {
				{ templateId = "a", name = "A", rarity = "Common", weight = 1, kind = "Material" },
				{ templateId = "b", name = "B", rarity = "Rare", weight = 3, kind = "Material" },
			},
		}
		local function rollAt(number)
			local pity = { rollsSinceLegendary = 0, totalRolls = 0 }
			local rng = {
				nextNumber = function()
					return number
				end,
				nextInteger = function(_self, min, _max)
					return min
				end,
			}
			return RollMath.roll(pool, pity, context("x", 0), rng).item.templateId
		end
		-- total weight 4. [0, 0.25) is A, the rest is B.
		expect(rollAt(0)).toEqual("a")
		expect(rollAt(0.249)).toEqual("a")
		expect(rollAt(0.25)).toEqual("b")
		expect(rollAt(0.999)).toEqual("b")
	end)

	it("mints a fern stag at the bottom of its pet ranges", function()
		local item = RollMath.mint("fern_stag", { uid = "stag", now = 0 }, zeroRng())
		expect(item.quality).toEqual(0)
		expect(item.kind).toEqual("Pet")
		expect(item.weaponType).toBeNil()
		expect(#item.traits).toEqual(1)
		expect(item.traits[1].id).toEqual("bonus_pet_damage")
		expect(item.traits[1].display).toEqual("5.0%")
		expect(item.stats[1].id).toEqual("pet_damage")
		expect(item.stats[1].value).toBeCloseTo(5 * 1.35, 1e-9)
	end)
end)

describe("RollMath distribution", function()
	it("matches the disclosed odds across many rolls when pity cannot fire", function()
		local source = starter()
		local pool = {
			id = source.id,
			name = source.name,
			pityLegendaryAt = 100000000,
			placeholder = true,
			entries = source.entries,
		}
		local rolls = 20000
		local rng = seededRng(0x5EED1234)
		local pity = { rollsSinceLegendary = 0, totalRolls = 0 }
		local counts: { [string]: number } = {}
		for n = 1, rolls do
			local result = RollMath.roll(pool, pity, context("d" .. n, 0), rng)
			local id = result.item.templateId
			counts[id] = (counts[id] or 0) + 1
		end
		expect(pity.totalRolls).toEqual(rolls)

		local odds = RollMath.odds(pool, 0)
		for _, entry in ipairs(odds.entries) do
			local got = (counts[entry.templateId] or 0) / rolls
			local se = math.sqrt(entry.chance * (1 - entry.chance) / rolls)
			local margin = math.max(6 * se, 1 / rolls)
			local delta = math.abs(got - entry.chance)
			if delta > margin then
				error(
					string.format(
						"%s rate %.6f outside %.6f ± %.6f",
						entry.templateId,
						got,
						entry.chance,
						margin
					)
				)
			end
		end
	end)
end)
