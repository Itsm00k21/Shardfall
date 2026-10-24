--!strict

--[[
	Phase 1.7: the live draw matches the config. 100,000 seeded rolls
	through RarityConfig.pick land each Rev 2 tier within tolerance of
	its configured chance, and the Legendary pity (150) guarantees a
	Legendary by roll 150 every time. Seeded, so the run is the same on
	every machine.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local RollConfig = require("../src/ReplicatedStorage/Shared/RollConfig")
local V1 = require("../src/ReplicatedStorage/Shared/Config/Rarities")

local ROLLS = 100000
local TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- 32-bit LCG (Numerical Recipes constants). Exact in doubles.
local function seeded(seed: number)
	local state = seed % 4294967296
	local rng = {}
	function rng.nextNumber(_self): number
		state = (state * 1664525 + 1013904223) % 4294967296
		return state / 4294967296
	end
	function rng.nextInteger(self, min: number, max: number): number
		return min + math.floor(self:nextNumber() * (max - min + 1))
	end
	return rng
end

-- Sequential, rarest first: each tier's 1-in-N, Common takes the rest.
local function expected(): { [string]: number }
	local out = {}
	local remaining = 1
	for index = #TIERS, 2, -1 do
		local name = TIERS[index]
		local tier = (V1.TIERS :: any)[name]
		assert(tier ~= nil, name)
		local oneIn = tier.oneIn
		out[name] = remaining / oneIn
		remaining -= out[name]
	end
	out.Common = remaining
	return out
end

describe("Roll odds (Phase 1.7)", function()
	it("rolls only the five Rev 2 tiers, 1/2 1/4 1/15 1/100 1/1000", function()
		local want = { Uncommon = 4, Rare = 15, Epic = 100, Legendary = 1000 }
		for name, oneIn in pairs(want) do
			expect(RarityConfig.effectiveOneIn(name, 1)).toEqual(oneIn)
		end
		local pool = Pools.get("verdant_armory")
		local present = RarityConfig.present(pool)
		for _, name in ipairs(present) do
			expect(table.find(TIERS, name) ~= nil).toBeTrue()
		end
		expect(RarityConfig.rolls("Mythic")).toEqual(false)
		expect(RarityConfig.rolls("Secret")).toEqual(false)
		local sum = 0
		local wanted = expected()
		for _, name in ipairs(TIERS) do
			local chance = RarityConfig.tierChance(name)
			assert(chance ~= nil, name)
			expect(math.abs(chance - wanted[name]) < 1e-12).toBeTrue()
			sum += chance
		end
		expect(math.abs(sum - 1) < 1e-12).toBeTrue()
	end)

	it("lands each tier within tolerance of config over 100k seeded rolls", function()
		local pool = Pools.get("verdant_armory")
		local rng = seeded(20261022)
		local counts = {}
		for _, name in ipairs(TIERS) do
			counts[name] = 0
		end
		for _ = 1, ROLLS do
			-- Fresh counters each roll: natural odds, no pity, luck x1.
			local rarity = RarityConfig.pick(pool, 1, { sinceLegendary = 0 }, rng :: any)
			expect(counts[rarity] ~= nil).toBeTrue()
			counts[rarity] += 1
		end
		for _, name in ipairs(TIERS) do
			local p = RarityConfig.tierChance(name) :: number
			local seen = counts[name] / ROLLS
			-- Five standard errors, plus a hair for the rarest tier.
			local tolerance = 5 * math.sqrt(p * (1 - p) / ROLLS) + 0.0001
			if math.abs(seen - p) > tolerance then
				error(string.format("%s: saw %.5f, config %.5f (tol %.5f)", name, seen, p, tolerance))
			end
			expect(counts[name] > 0).toBeTrue()
		end
	end)

	it("guarantees a Legendary by roll 150 with live pity across 100k rolls", function()
		local pool = Pools.get("verdant_armory")
		local rng = seeded(7)
		local counters = { sinceLegendary = 0 }
		local gap = 0
		local longest = 0
		local legendaries = 0
		for _ = 1, ROLLS do
			local rarity, _fired, floor = RarityConfig.pick(pool, 1, counters, rng :: any)
			RarityConfig.advance(counters, rarity, floor)
			gap += 1
			if rarity == "Legendary" then
				legendaries += 1
				longest = math.max(longest, gap)
				gap = 0
				expect(counters.sinceLegendary).toEqual(0)
			end
			expect(counters.sinceLegendary < RollConfig.LEGENDARY_PITY).toBeTrue()
		end
		expect(longest <= RollConfig.LEGENDARY_PITY).toBeTrue()
		-- With pity, Legendary comes far more often than the bare 1/1000.
		expect(legendaries > ROLLS / 1000 * 3).toBeTrue()
	end)

	it("forces Legendary on roll 150 even when every draw misses", function()
		local pool = Pools.get("verdant_armory")
		local miss = {
			nextNumber = function(_self)
				return 0.9999
			end,
			nextInteger = function(_self, min, _max)
				return min
			end,
		}
		for _ = 1, 3 do
			local counters = { sinceLegendary = 0 }
			for roll = 1, RollConfig.LEGENDARY_PITY do
				local rarity, fired, floor = RarityConfig.pick(pool, 1, counters, miss :: any)
				RarityConfig.advance(counters, rarity, floor)
				if roll < RollConfig.LEGENDARY_PITY then
					expect(rarity).toEqual("Common")
					expect(fired).toEqual(false)
				else
					expect(rarity).toEqual("Legendary")
					expect(fired).toEqual(true)
				end
			end
			expect(counters.sinceLegendary).toEqual(0)
		end
	end)

	it("soft pity lifts the Legendary rate after roll 100", function()
		local pool = Pools.get("verdant_armory")
		local rng = seeded(99)
		local hits = 0
		local trials = 20000
		for _ = 1, trials do
			-- Roll 125: base 0.1% + 25 x 2% soft bonus = 50.1%.
			local rarity = RarityConfig.pick(pool, 1, { sinceLegendary = 124 }, rng :: any)
			if rarity == "Legendary" then
				hits += 1
			end
		end
		local seen = hits / trials
		expect(math.abs(seen - (0.001 + 0.5)) < 0.02).toBeTrue()
	end)
end)
