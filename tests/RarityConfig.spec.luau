--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")

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

describe("RarityConfig", function()
	it("lists every rarity as 1 in N and the percents sum to 1", function()
		local odds = RarityConfig.disclose(ladderPool(), 1)
		local sum = 0
		local mythic = nil
		local secret = nil
		for _, row in ipairs(odds.rarities) do
			sum += row.chance
			local line = RarityConfig.formatLine(row)
			expect(string.find(line, "1 in " .. tostring(row.oneIn), 1, true) ~= nil).toBeTrue()
			if row.rarity == "Mythic" then
				mythic = row
			end
			if row.rarity == "Secret" then
				secret = row
			end
		end
		expect(math.abs(sum - 1) < 1e-9).toBeTrue()
		assert(mythic ~= nil)
		assert(secret ~= nil)
		expect(mythic.oneIn).toEqual(25000)
		expect(secret.oneIn).toEqual(100000)
		for _, row in ipairs(odds.rarities) do
			if row.rarity == "Common" then
				expect(row.oneIn).toEqual(2)
			end
		end
		expect(math.abs(mythic.chance - ((1 - 1 / 100000) * (1 / 25000))) < 1e-12).toBeTrue()
	end)

	it("halves the 1-in thresholds when luck is x2", function()
		local odds = RarityConfig.disclose(ladderPool(), 2)
		for _, row in ipairs(odds.rarities) do
			if row.rarity == "Mythic" then
				expect(row.oneIn).toEqual(12500)
			end
			if row.rarity == "Legendary" then
				expect(row.oneIn).toEqual(1250)
			end
		end
	end)

	it("uses the spec luck formula and drops paid terms when the switch is off", function()
		expect(RarityConfig.luckMultiplier({})).toEqual(1)
		expect(RarityConfig.luckMultiplier({ shardRolls = 9 })).toEqual(2)
		expect(RarityConfig.luckMultiplier({ shardLuck = 100 })).toEqual(2)
		expect(RarityConfig.luckMultiplier({ luckBoost = 25, vip = true })).toEqual(1.25 * 1.2)
		expect(RarityConfig.luckMultiplier({
			shardRolls = 9,
			luckBoost = 25,
			vip = true,
		})).toEqual((1 * 2 + 0.25) * 1.2)
		expect(RarityConfig.luckMultiplier({
			luckBoost = 100,
			vip = true,
			paidLuck = false,
		})).toEqual(1)
		expect(RarityConfig.PAID_LUCK_ENABLED).toEqual(true)
	end)

	it("shows x2 luck on the 10th roll and pity counters", function()
		expect(RarityConfig.bonusLabel(0)).toEqual("x2 Luck in 10")
		expect(RarityConfig.bonusLabel(8)).toEqual("x2 Luck in 2")
		expect(RarityConfig.bonusLabel(9)).toEqual("x2 Luck Ready")
		expect(RarityConfig.bonusLabel(19)).toEqual("x2 Luck Ready")
		expect(RarityConfig.pityLine(4, 20)).toEqual("Epic 4/100 · Legendary 20/1000")
	end)

	it("forces Epic+ at 100 and Legendary+ at 1000, rarest-first otherwise", function()
		local pool = ladderPool()
		local miss = scripted(0.5)
		local common, triggered =
			RarityConfig.pick(pool, 1, { sinceEpic = 0, sinceLegendary = 0 }, miss)
		expect(common).toEqual("Common")
		expect(triggered).toEqual(false)

		local epic =
			RarityConfig.pick(pool, 1, { sinceEpic = 99, sinceLegendary = 0 }, scripted(0.5))
		expect(epic).toEqual("Epic")

		local legendary =
			RarityConfig.pick(pool, 1, { sinceEpic = 0, sinceLegendary = 999 }, scripted(0.5))
		expect(legendary).toEqual("Legendary")

		local secret =
			RarityConfig.pick(pool, 1, { sinceEpic = 99, sinceLegendary = 0 }, scripted(0))
		expect(secret).toEqual("Secret")
	end)

	it("resets the pity counter the granted rarity clears", function()
		local pity = { sinceEpic = 99, sinceLegendary = 40 }
		RarityConfig.advance(pity, "Epic", "Epic")
		expect(pity.sinceEpic).toEqual(0)
		expect(pity.sinceLegendary).toEqual(41)

		pity = { sinceEpic = 10, sinceLegendary = 999 }
		RarityConfig.advance(pity, "Legendary", "Legendary")
		expect(pity.sinceEpic).toEqual(0)
		expect(pity.sinceLegendary).toEqual(0)

		pity = { sinceEpic = 3, sinceLegendary = 3 }
		RarityConfig.advance(pity, "Rare", nil)
		expect(pity.sinceEpic).toEqual(4)
		expect(pity.sinceLegendary).toEqual(4)
	end)

	it("builds a deterministic reel that lands on the server result", function()
		local pool = ladderPool()
		local first = RarityConfig.reel(48271, pool, 1, "The Unnamed Grove", "Secret")
		local second = RarityConfig.reel(48271, pool, 1, "The Unnamed Grove", "Secret")
		expect(#first).toEqual(RarityConfig.REEL_SLOTS)
		expect(RarityConfig.REEL_SLOTS >= 8 and RarityConfig.REEL_SLOTS <= 12).toBeTrue()
		expect(first[#first].name).toEqual("The Unnamed Grove")
		expect(first[#first].rarity).toEqual("Secret")
		for index, slot in ipairs(first) do
			expect(slot.name).toEqual(second[index].name)
			expect(slot.rarity).toEqual(second[index].rarity)
		end
		local other = RarityConfig.reel(7, pool, 1, "The Unnamed Grove", "Secret")
		expect(other[#other].name).toEqual("The Unnamed Grove")
	end)

	it(
		"keeps free rolls available and gates Quick Roll on policy, the switch, and entitlement",
		function()
			expect(RarityConfig.quickAllowed(true, true, true)).toEqual(true)
			expect(RarityConfig.quickAllowed(false, true, true)).toEqual(false)
			expect(RarityConfig.quickAllowed(true, false, true)).toEqual(false)
			expect(RarityConfig.quickAllowed(true, true, false)).toEqual(false)
			expect(RarityConfig.quickDenial(false, true, true)).toEqual(
				"Unavailable in your region"
			)
			expect(RarityConfig.quickDenial(true, false, true)).toEqual("Quick Roll is turned off.")
			expect(RarityConfig.quickEntitled({ quickRoll = true }, 0)).toEqual(true)
			expect(RarityConfig.quickEntitled({ quickRollUntil = 50 }, 40)).toEqual(true)
			expect(RarityConfig.quickEntitled({ quickRollUntil = 50 }, 50)).toEqual(false)
			expect(RarityConfig.cooldown(false)).toEqual(0.6)
			expect(RarityConfig.cooldown(true)).toEqual(1)
		end
	)

	it("times a normal roll at 2.6s and escalates the rare reveals", function()
		expect(math.abs(RarityConfig.cycleSeconds() - 2.6) < 1e-9).toBeTrue()
		local common = RarityConfig.reveal("Common", false)
		expect(common.reel).toEqual(true)
		expect(common.reelSeconds).toEqual(1.45)
		expect(common.shake).toEqual(0)
		local epic = RarityConfig.reveal("Epic", false)
		expect(epic.reelSeconds).toEqual(1.45 + 0.5)
		expect(epic.shake).toEqual(0.3)
		local legendary = RarityConfig.reveal("Legendary", false)
		expect(legendary.cutscene).toEqual(1.5)
		expect(legendary.announce).toEqual(true)
		expect(legendary.crossServer).toEqual(false)
		local mythic = RarityConfig.reveal("Mythic", true)
		expect(mythic.cutscene).toEqual(3)
		expect(mythic.stall).toEqual(true)
		expect(mythic.skipAfter).toEqual(1)
		expect(mythic.crossServer).toEqual(true)
		expect(mythic.quickPop).toEqual(false)
		local quickCommon = RarityConfig.reveal("Common", true)
		expect(quickCommon.toastOnly).toEqual(true)
		expect(quickCommon.reel).toEqual(false)
		local quickRare = RarityConfig.reveal("Rare", true)
		expect(quickRare.quickPop).toEqual(true)
		expect(quickRare.reel).toEqual(false)
	end)

	it("caps particles by graphics tier and keeps roll taps at least 60px", function()
		expect(RarityConfig.particleCap("low", "Rare")).toEqual(30)
		expect(RarityConfig.particleCap("low", "Mythic")).toEqual(0)
		expect(RarityConfig.particleCap("low", "Secret")).toEqual(0)
		expect(RarityConfig.particleCap("med", "Mythic") > 30).toBeTrue()
		expect(
			RarityConfig.particleCap("high", "Legendary")
				> RarityConfig.particleCap("med", "Legendary")
		).toBeTrue()
		expect(RarityConfig.MIN_TAP >= 60).toBeTrue()
	end)
end)
