--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Stats = require("../src/ReplicatedStorage/Shared/Stats")

local function rngAt(alpha: number)
	return {
		nextNumber = function()
			return alpha
		end,
		nextInteger = function(_self, min: number, _max: number)
			return min
		end,
	}
end

local SWORD = {
	{ id = "damage", min = 10, max = 14 },
	{ id = "attack_speed", min = 1, max = 2 },
}

describe("Stats", function()
	it("keeps a minimum roll at the bottom of the scaled range", function()
		local rolled, quality = Stats.roll(SWORD, "Common", "sword", rngAt(0))
		expect(quality).toEqual(0)
		expect(rolled[1].value).toEqual(10)
		expect(rolled[1].min).toEqual(10)
		expect(rolled[1].max).toEqual(14)
		expect(rolled[1].roll).toEqual(0)
		expect(Stats.formatQuality(quality)).toEqual("0%")
	end)

	it("treats a full alpha as a perfect roll", function()
		local rolled, quality = Stats.roll(SWORD, "Common", "sword", rngAt(1))
		expect(quality).toEqual(1)
		expect(rolled[1].value).toEqual(14)
		expect(rolled[2].value).toEqual(2)
		expect(Stats.formatQuality(quality)).toEqual("100%")
	end)

	it("scores the middle of every range as 50%", function()
		local rolled, quality = Stats.roll(SWORD, "Common", nil, rngAt(0.5))
		expect(quality).toBeCloseTo(0.5, 1e-12)
		expect(rolled[1].value).toBeCloseTo(12, 1e-12)
		expect(Stats.formatQuality(quality)).toEqual("50%")
		expect(Stats.formatQuality(0.924)).toEqual("92%")
		expect(Stats.formatQuality(0.925)).toEqual("93%")
	end)

	it("scales both ends by rarity and by an explicit class weight", function()
		local minValue, maxValue = Stats.scaledBounds(10, 14, "Rare", 1)
		expect(minValue).toBeCloseTo(10 * 1.35, 1e-12)
		expect(maxValue).toBeCloseTo(14 * 1.35, 1e-12)

		local weightedMin, weightedMax = Stats.scaledBounds(10, 14, "Common", 2)
		expect(weightedMin).toEqual(20)
		expect(weightedMax).toEqual(28)

		local rolled = Stats.roll(SWORD, "Rare", "sword", rngAt(0))
		expect(rolled[1].min).toBeCloseTo(10 * Stats.RARITY_SCALE.Rare, 1e-12)
		expect(rolled[1].value).toEqual(rolled[1].min)
		expect(rolled[1].value).toBeGreaterThan(10)
	end)

	it("rolls pet damage inside the rarity-scaled range and scores quality", function()
		local fern = {
			{ id = "pet_damage", min = 5, max = 8 },
			{ id = "pet_health", min = 24, max = 42 },
			{ id = "attack_speed", min = 0.55, max = 0.85 },
			{ id = "crit_chance", min = 0.03, max = 0.07 },
		}
		local low, lowQuality = Stats.roll(fern, "Rare", "pet", rngAt(0))
		expect(lowQuality).toEqual(0)
		expect(low[1].id).toEqual("pet_damage")
		expect(low[1].name).toEqual("Pet Damage")
		expect(low[1].min).toBeCloseTo(5 * 1.35, 1e-12)
		expect(low[1].value).toEqual(low[1].min)
		expect(Stats.formatQuality(lowQuality)).toEqual("0%")
		expect(Stats.classWeight("pet", "pet_damage")).toEqual(1)
		expect(Stats.classWeight("pet", "pet_health")).toEqual(1)

		local high, highQuality = Stats.roll(fern, "Rare", "pet", rngAt(1))
		expect(highQuality).toEqual(1)
		expect(high[1].value).toBeCloseTo(8 * 1.35, 1e-12)
		expect(high[1].max).toBeCloseTo(8 * 1.35, 1e-12)
		expect(Stats.formatQuality(highQuality)).toEqual("100%")
		expect(Stats.formatValue(high[1])).toEqual("11")
	end)

	it("leaves every live class weight at 1 until a class exists", function()
		for _, weaponType in ipairs(Stats.WEAPON_TYPES) do
			for statId in pairs(Stats.DEFS) do
				expect(Stats.classWeight(weaponType, statId)).toEqual(1)
			end
		end
		expect(Stats.classWeight(nil, "damage")).toEqual(1)
		expect(Stats.classWeight("wand", "damage")).toEqual(1)
	end)

	it("formats flat, percent, and multiplier stats", function()
		expect(Stats.formatValue({
			id = "damage",
			name = "Damage",
			value = 11.4,
			min = 10,
			max = 14,
			unit = "flat",
			roll = 0,
		})).toEqual("11")
		expect(Stats.formatValue({
			id = "crit_chance",
			name = "Crit Chance",
			value = 0.056,
			min = 0.03,
			max = 0.07,
			unit = "percent",
			roll = 0,
		})).toEqual("5.6%")
	end)
end)
