--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

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
	it("rolls only the 5 V1 tiers and the percents sum to 1", function()
		local odds = RarityConfig.disclose(ladderPool(), 1)
		local sum = 0
		local seen = {}
		for _, row in ipairs(odds.rarities) do
			sum += row.chance
			seen[row.rarity] = row
			local line = RarityConfig.formatLine(row)
			expect(string.find(line, "1 in", 1, true)).toBeNil()
			expect(string.find(line, "%", 1, true) ~= nil).toBeTrue()
		end
		expect(math.abs(sum - 1) < 1e-9).toBeTrue()
		-- Mythic and Secret are parked (LaunchGate.extraTiers off).
		expect(seen.Mythic).toBeNil()
		expect(seen.Secret).toBeNil()
		expect(#odds.rarities).toEqual(5)
		expect(seen.Common.oneIn).toEqual(2)
		expect(seen.Legendary.oneIn).toEqual(1000)
		-- Rarest first: Legendary 1/1000, Epic 1/100 of the rest, ...
		expect(math.abs(seen.Legendary.chance - 0.001) < 1e-12).toBeTrue()
		expect(math.abs(seen.Epic.chance - 0.999 * 0.01) < 1e-12).toBeTrue()
		expect(math.abs(seen.Rare.chance - 0.999 * 0.99 / 15) < 1e-12).toBeTrue()
		expect(math.abs(seen.Uncommon.chance - 0.999 * 0.99 * (14 / 15) / 4) < 1e-12).toBeTrue()
		expect(math.abs(seen.Common.chance - 0.999 * 0.99 * (14 / 15) * 0.75) < 1e-12).toBeTrue()
		expect(string.find(odds.notice, RarityConfig.ROUNDING_NOTE, 1, true) ~= nil).toBeTrue()
		expect(string.find(odds.notice, "Epic", 1, true)).toBeNil()
	end)

	it("prints the real percent from the disclosed chance", function()
		expect(RarityConfig.formatLine({ rarity = "Rare", chance = 0.02, oneIn = 10 })).toEqual("Rare  2%")
		local odds = RarityConfig.disclose(ladderPool(), 1)
		local shown = {}
		local shownSum = 0
		for _, row in ipairs(odds.rarities) do
			local line = RarityConfig.formatLine(row)
			local rarity, percentText = string.match(line, "^(%S+)  ([%d%.]+)%%$")
			expect(rarity).toEqual(row.rarity)
			local percent = tonumber(percentText)
			assert(percent ~= nil)
			shownSum += percent
			shown[row.rarity] = line
			expect(math.abs(percent - row.chance * 100) <= 0.55).toBeTrue()
		end
		expect(math.abs(shownSum - 100) <= 1).toBeTrue()
		expect(shown.Common).toEqual("Common  69%")
		expect(shown.Uncommon).toEqual("Uncommon  23%")
		expect(shown.Rare).toEqual("Rare  6.6%")
		expect(shown.Epic).toEqual("Epic  1.00%")
		expect(shown.Legendary).toEqual("Legendary  0.10%")
		local live = RarityConfig.disclose(Pools.get("verdant_armory"), 1)
		local liveSum = 0
		for _, row in ipairs(live.rarities) do
			local _, percentText = string.match(RarityConfig.formatLine(row), "^(%S+)  ([%d%.]+)%%$")
			expect(percentText ~= nil).toBeTrue()
			liveSum += tonumber(percentText) or 0
		end
		expect(math.abs(liveSum - 100) <= 1).toBeTrue()
	end)

	it("shows the real percent on the reveal, and a parked tier by name only", function()
		expect(RarityConfig.revealText("Rare")).toEqual("Rare · 6.6%")
		expect(RarityConfig.revealText("Legendary")).toEqual("Legendary · 0.10%")
		expect(RarityConfig.revealText("Common")).toEqual("Common · 69%")
		expect(RarityConfig.revealText("Mythic")).toEqual("Mythic")
		expect(RarityConfig.revealText("Secret")).toEqual("Secret")
		expect(RarityConfig.rolls("Mythic")).toEqual(false)
		expect(RarityConfig.rolls("Legendary")).toEqual(true)
		local total = 0
		for _, id in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
			total += RarityConfig.tierChance(id) or 0
		end
		expect(math.abs(total - 1) < 1e-12).toBeTrue()
	end)

	it("halves the 1-in thresholds when luck is x2", function()
		local odds = RarityConfig.disclose(ladderPool(), 2)
		for _, row in ipairs(odds.rarities) do
			if row.rarity == "Epic" then
				expect(row.oneIn).toEqual(50)
			end
			if row.rarity == "Legendary" then
				expect(row.oneIn).toEqual(500)
			end
		end
	end)

	it("uses the spec luck formula and drops paid terms when the switch is off", function()
		expect(RarityConfig.luckMultiplier({})).toEqual(1)
		-- The 10th-roll x2 milestone is parked: a 10th roll is plain x1.
		expect(RarityConfig.luckMultiplier({ shardRolls = 9 })).toEqual(1)
		expect(RarityConfig.luckMultiplier({ shardRolls = 9, milestone = true })).toEqual(2)
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
		})).toEqual(1 + 0.25)
		expect(RarityConfig.luckMultiplier({
			shardRolls = 9,
			luckBoost = 25,
			vip = true,
			paidLuck = true,
			milestone = true,
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
		expect(RarityConfig.luckFromProfile(stored)).toEqual(1 + 0.8)
		expect(RarityConfig.luckFromProfile(stored)).toEqual(
			RarityConfig.luckMultiplier({ shardLuck = 80, shardRolls = 9 })
		)
	end)

	it("parks the 10th-roll x2 luck milestone by default", function()
		expect(LaunchGate.on("luckMilestone")).toEqual(false)
		expect(RarityConfig.milestoneOn()).toEqual(false)
		for rolls = 0, 30 do
			expect(RarityConfig.bonusLabel(rolls)).toEqual("")
			expect(RarityConfig.luckFromProfile({ shardRolls = rolls })).toEqual(1)
		end
		local notice = RarityConfig.disclose(ladderPool(), 1).notice
		expect(string.find(notice, "x2", 1, true)).toBeNil()
		-- The profile's counters are read, never written.
		local profile = { shardRolls = 9, sinceLegendary = 42 }
		RarityConfig.luckFromProfile(profile)
		expect(profile.shardRolls).toEqual(9)
		expect(profile.sinceLegendary).toEqual(42)
	end)

	it("shows x2 luck on the 10th roll and the Legendary pity counter", function()
		LaunchGate.SHOW.luckMilestone = true
		local labels = {
			RarityConfig.bonusLabel(0),
			RarityConfig.bonusLabel(8),
			RarityConfig.bonusLabel(9),
			RarityConfig.bonusLabel(19),
		}
		local luck = RarityConfig.luckFromProfile({ shardRolls = 9 })
		LaunchGate.SHOW.luckMilestone = false
		expect(labels[1]).toEqual("x2 Luck in 10")
		expect(labels[2]).toEqual("x2 Luck in 2")
		expect(labels[3]).toEqual("x2 Luck Ready")
		expect(labels[4]).toEqual("x2 Luck Ready")
		expect(luck).toEqual(2)
		expect(RarityConfig.pityLine(20)).toEqual("Legendary pity 20/150")
		expect(RarityConfig.pityLine(-3)).toEqual("Legendary pity 0/150")
		expect((RarityConfig :: any).EPIC_PITY).toBeNil()
	end)

	it("forces Legendary+ at 150 only, rarest-first otherwise", function()
		local pool = ladderPool()
		local miss = scripted(0.5)
		local common, triggered = RarityConfig.pick(pool, 1, { sinceLegendary = 0 }, miss)
		expect(common).toEqual("Common")
		expect(triggered).toEqual(false)

		-- An old save's sinceEpic at the old 50 does nothing.
		local oldEpic, oldOn, oldFloor =
			RarityConfig.pick(pool, 1, { sinceEpic = 49, sinceLegendary = 0 }, scripted(0.5))
		expect(oldEpic).toEqual("Common")
		expect(oldOn).toEqual(false)
		expect(oldFloor).toBeNil()

		local legendary = RarityConfig.pick(pool, 1, { sinceLegendary = 149 }, scripted(0.5))
		expect(legendary).toEqual("Legendary")

		-- Mythic/Secret rows stay in the pool but never roll.
		local top = RarityConfig.pick(pool, 1, { sinceLegendary = 0 }, scripted(0))
		expect(top).toEqual("Legendary")
	end)

	it("adds soft pity from roll 101 and leaves rolls up to 100 alone", function()
		local pool = ladderPool()
		-- 0.03 misses 1/1000 but lands inside 1/1000 + 2% * 2 (roll 102).
		expect(RarityConfig.pick(pool, 1, { sinceLegendary = 99 }, scripted(0.03))).toEqual("Rare")
		expect(RarityConfig.pick(pool, 1, { sinceLegendary = 101 }, scripted(0.03))).toEqual("Legendary")
		local _, forced = RarityConfig.pick(pool, 1, { sinceLegendary = 101 }, scripted(0.03))
		expect(forced).toEqual(false)
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
		local _, early, earlyFloor = RarityConfig.pick(pool, huge, { sinceLegendary = 148 }, scripted(0.99))
		expect(early).toEqual(false)
		expect(earlyFloor).toBeNil()
		local atLegend, legendOn, legendFloor =
			RarityConfig.pick(pool, 1, { sinceEpic = 30, sinceLegendary = 149 }, scripted(0.5))
		expect(atLegend).toEqual("Legendary")
		expect(legendOn).toEqual(true)
		expect(legendFloor).toEqual("Legendary")
	end)

	it("resets the Legendary counter on Legendary+ and leaves sinceEpic as saved", function()
		local pity: any = { sinceEpic = 99, sinceLegendary = 40 }
		RarityConfig.advance(pity, "Epic", nil)
		expect(pity.sinceEpic).toEqual(99)
		expect(pity.sinceLegendary).toEqual(41)

		pity = { sinceEpic = 10, sinceLegendary = 149 }
		RarityConfig.advance(pity, "Legendary", "Legendary")
		expect(pity.sinceEpic).toEqual(10)
		expect(pity.sinceLegendary).toEqual(0)

		pity = { sinceLegendary = 3 }
		RarityConfig.advance(pity, "Rare", nil)
		expect(pity.sinceEpic).toBeNil()
		expect(pity.sinceLegendary).toEqual(4)

		-- An owned legacy Mythic still counts as Legendary or better.
		pity = { sinceLegendary = 70 }
		RarityConfig.advance(pity, "Mythic", nil)
		expect(pity.sinceLegendary).toEqual(0)
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
