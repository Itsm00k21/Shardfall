--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Pools = require("../src/ReplicatedStorage/Shared/Pools")
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
			expect(string.find(line, "  1 in ", 1, true) ~= nil).toBeTrue()
			expect(string.find(line, "%)", 1, true) ~= nil).toBeTrue()
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
		expect(string.find(odds.notice, RarityConfig.ROUNDING_NOTE, 1, true) ~= nil).toBeTrue()
	end)

	it("prints one 1-in and one percent from the disclosed chance", function()
		expect(RarityConfig.formatLine({ rarity = "Rare", chance = 0.02, oneIn = 10 })).toEqual(
			"Rare  1 in 50  (2%)"
		)
		local odds = RarityConfig.disclose(ladderPool(), 1)
		local shownSum = 0
		for _, row in ipairs(odds.rarities) do
			local line = RarityConfig.formatLine(row)
			local rarity, oneInText, percentText =
				string.match(line, "^(%S+)  1 in (%d+)  %(([%d%.]+)%%%)")
			expect(rarity).toEqual(row.rarity)
			local oneIn = tonumber(oneInText)
			local percent = tonumber(percentText)
			assert(oneIn ~= nil and percent ~= nil)
			shownSum += percent
			expect(math.abs(percent - row.chance * 100) <= 0.55).toBeTrue()
			expect(oneIn).toEqual(math.max(1, math.floor((100 / percent) + 0.5)))
		end
		expect(math.abs(shownSum - 100) <= 1).toBeTrue()
		local live = RarityConfig.disclose(Pools.get("verdant_armory"), 1)
		local liveSum = 0
		for _, row in ipairs(live.rarities) do
			local _, _, percentText = string.match(
				RarityConfig.formatLine(row),
				"^(%S+)  1 in (%d+)  %(([%d%.]+)%%%)"
			)
			expect(percentText ~= nil).toBeTrue()
			liveSum += tonumber(percentText) or 0
		end
		expect(math.abs(liveSum - 100) <= 1).toBeTrue()
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
		expect(RarityConfig.luckMultiplier({ luckBoost = 25, vip = true })).toEqual(1)
		expect(RarityConfig.luckMultiplier({
			luckBoost = 25,
			vip = true,
			paidLuck = true,
		})).toEqual(1.25)
		expect(RarityConfig.luckMultiplier({
			shardRolls = 9,
			luckBoost = 25,
			vip = true,
			paidLuck = true,
		})).toEqual(1 * 2 + 0.25)
		expect(RarityConfig.luckMultiplier({
			luckBoost = 100,
			vip = true,
			paidLuck = false,
		})).toEqual(1)
		expect(RarityConfig.PAID_LUCK_ENABLED).toEqual(false)
	end)

	it("exploit: vip does not change luck", function()
		local function same(input: any)
			local withVip = {}
			local withoutVip = {}
			if type(input) == "table" then
				for key, value in pairs(input) do
					withVip[key] = value
					withoutVip[key] = value
				end
			end
			withVip.vip = true
			withoutVip.vip = false
			expect(RarityConfig.luckMultiplier(withVip)).toEqual(
				RarityConfig.luckMultiplier(withoutVip)
			)
		end
		same({})
		same({ shardLuck = 100 })
		same({ shardRolls = 9 })
		same({ luckBoost = 25, paidLuck = true })
		same({ shardLuck = 100, luckBoost = 50, shardRolls = 9, paidLuck = true })
		same({ shardLuck = 100, luckBoost = 50, shardRolls = 9, paidLuck = false })
		expect((RarityConfig :: any).VIP_MULT).toBeNil()

		local stored = {
			shardLuck = 80,
			luckBoost = 25,
			shardRolls = 9,
			vip = true,
		}
		local plain = {
			shardLuck = 80,
			luckBoost = 25,
			shardRolls = 9,
			vip = false,
		}
		expect(RarityConfig.luckFromProfile(stored)).toEqual(RarityConfig.luckFromProfile(plain))
		expect(RarityConfig.luckFromProfile(stored)).toEqual((1 + 0.8) * 2)
		expect(RarityConfig.luckFromProfile(stored)).toEqual(
			RarityConfig.luckMultiplier({ shardLuck = 80, shardRolls = 9 })
		)
	end)

	it("shows x2 luck on the 10th roll and pity counters", function()
		expect(RarityConfig.bonusLabel(0)).toEqual("x2 Luck in 10")
		expect(RarityConfig.bonusLabel(8)).toEqual("x2 Luck in 2")
		expect(RarityConfig.bonusLabel(9)).toEqual("x2 Luck Ready")
		expect(RarityConfig.bonusLabel(19)).toEqual("x2 Luck Ready")
		expect(RarityConfig.pityLine(4, 20)).toEqual("Epic 4/50 · Legendary 20/1000")
	end)

	it("forces Epic+ at 50 and Legendary+ at 1000, rarest-first otherwise", function()
		local pool = ladderPool()
		local miss = scripted(0.5)
		local common, triggered =
			RarityConfig.pick(pool, 1, { sinceEpic = 0, sinceLegendary = 0 }, miss)
		expect(common).toEqual("Common")
		expect(triggered).toEqual(false)

		local dry =
			RarityConfig.pick(pool, 1, { sinceEpic = 48, sinceLegendary = 48 }, scripted(0.5))
		expect(dry).toEqual("Common")

		local epic =
			RarityConfig.pick(pool, 1, { sinceEpic = 49, sinceLegendary = 0 }, scripted(0.5))
		expect(epic).toEqual("Epic")

		local legendary =
			RarityConfig.pick(pool, 1, { sinceEpic = 0, sinceLegendary = 999 }, scripted(0.5))
		expect(legendary).toEqual("Legendary")

		local secret =
			RarityConfig.pick(pool, 1, { sinceEpic = 49, sinceLegendary = 0 }, scripted(0))
		expect(secret).toEqual("Secret")
	end)

	it("does not give a paid roll an earlier pity floor", function()
		local pool = ladderPool()
		local huge = RarityConfig.luckMultiplier({
			shardLuck = 10000,
			luckBoost = 10000,
			vip = true,
			paidLuck = true,
			shardRolls = 9,
		})
		local _, early, earlyFloor =
			RarityConfig.pick(pool, huge, { sinceEpic = 48, sinceLegendary = 998 }, scripted(0.5))
		expect(early).toEqual(false)
		expect(earlyFloor).toBeNil()
		local atEpic, epicOn, epicFloor =
			RarityConfig.pick(pool, huge, { sinceEpic = 49, sinceLegendary = 0 }, scripted(0.5))
		expect(epicOn).toEqual(true)
		expect(epicFloor).toEqual("Epic")
		expect(Rarities.INDEX[atEpic] >= Rarities.INDEX.Epic).toBeTrue()
		local atLegend, legendOn, legendFloor =
			RarityConfig.pick(pool, 1, { sinceEpic = 30, sinceLegendary = 999 }, scripted(0.5))
		expect(atLegend).toEqual("Legendary")
		expect(legendOn).toEqual(true)
		expect(legendFloor).toEqual("Legendary")
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
