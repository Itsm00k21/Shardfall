--!strict

--[[
	Phase 4.1 / 4.4. Wave tokens, half-up rounding, leave-early, a grant
	that cannot pay twice, and duplicate Fragments. The server flag stays
	off and nothing is written to a profile.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local DevTools = require("../src/ReplicatedStorage/Shared/DevTools")
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Payouts = require("../src/ReplicatedStorage/Shared/Config/Payouts")
local Rarities = require("../src/ReplicatedStorage/Shared/Config/Rarities")
local RollConfig = require("../src/ReplicatedStorage/Shared/RollConfig")

local CLEARS = {
	normal = 11,
	medium = 14,
	hard = 17,
	nightmare = 22,
	insane = 33,
}

-- Waves 1-4. Dying on the boss, from the economy sheet.
local BOSS_FAIL = {
	normal = 6,
	medium = 8,
	hard = 9,
	nightmare = 12,
	insane = 18,
}

-- Running-total deltas. Hard wave 2 is 1, not 2.
local PER_WAVE = {
	normal = { 1, 1, 2, 2, 5 },
	medium = { 1, 2, 2, 3, 6 },
	hard = { 2, 1, 3, 3, 8 },
	nightmare = { 2, 2, 4, 4, 10 },
	insane = { 3, 3, 6, 6, 15 },
}

local function pays(difficulty: string, waves: number): { number }
	local preview = Payouts.preview(difficulty, waves)
	expect(preview.ok).toBeTrue()
	local tokens = {}
	for _, line in ipairs(preview.waves) do
		table.insert(tokens, line.tokens)
	end
	return tokens
end

local function sum(list: { number }): number
	local total = 0
	for _, value in ipairs(list) do
		total += value
	end
	return total
end

describe("Payout tokens", function()
	it("pays every difficulty from the wave table and the multiplier", function()
		expect(Economy.DIFFICULTY_ORDER).toEqual({
			"normal",
			"medium",
			"hard",
			"nightmare",
			"insane",
		})
		expect(Economy.ROUNDING).toEqual("half_up")
		expect(#Economy.WAVES).toEqual(5)
		for _, id in ipairs(Economy.DIFFICULTY_ORDER) do
			local row = Economy.DIFFICULTIES[id]
			local preview = Payouts.preview(id, #Economy.WAVES)
			expect(preview.ok).toBeTrue()
			expect(preview.tokens).toEqual(CLEARS[id])
			expect(preview.baseTokens).toEqual(Economy.NORMAL_CLEAR_TOKENS)
			expect(preview.multiplier).toEqual(row.tokenMultiplier)
			expect(preview.leftEarly).toBeFalse()
			expect(math.floor(preview.baseTokens * row.tokenMultiplier + 0.5)).toEqual(CLEARS[id])
			expect(Payouts.tokensThrough(id, #Economy.WAVES)).toEqual(CLEARS[id])
			expect(pays(id, #Economy.WAVES)).toEqual(PER_WAVE[id])
			expect(sum(PER_WAVE[id])).toEqual(CLEARS[id])
		end
	end)

	it("rounds the running total half up, not each wave", function()
		-- 11 * 1.25 = 13.75 -> 14. 11 * 1.5 = 16.5 -> 17.
		expect(Payouts.tokensThrough("medium", 5)).toEqual(14)
		expect(Payouts.tokensThrough("hard", 5)).toEqual(17)
		-- 6 * 1.25 = 7.5 -> 8. 2 * 1.25 = 2.5 -> 3. 1 * 1.25 = 1.25 -> 1.
		expect(Payouts.tokensThrough("medium", 4)).toEqual(8)
		expect(Payouts.tokensThrough("medium", 2)).toEqual(3)
		expect(Payouts.tokensThrough("medium", 1)).toEqual(1)
		-- Hard wave 2 would be 2 if it were rounded alone. The total through
		-- wave 2 is 3, so this wave adds 1.
		expect(pays("hard", 5)[2]).toEqual(1)
		expect(Payouts.preview(" Hard ", 5).tokens).toEqual(17)
		expect(Payouts.preview("INSANE", 5).tokens).toEqual(33)
	end)

	it("marks the boss wave and refuses a bad difficulty or wave", function()
		local clear = Payouts.preview("normal", 5)
		expect(clear.waves[5].boss).toBeTrue()
		expect(clear.waves[5].tokens).toEqual(5)
		expect(clear.waves[1].boss).toBeFalse()
		expect(Payouts.preview("mythic", 5).ok).toBeFalse()
		expect(Payouts.preview("normal", 6).ok).toBeFalse()
		expect(Payouts.preview("normal", -1).ok).toBeFalse()
		expect(Payouts.preview("normal", 1.5).ok).toBeFalse()
		expect(Payouts.preview("normal", 0 / 0).ok).toBeFalse()
		expect(Payouts.preview("normal", math.huge).ok).toBeFalse()
		expect(Payouts.preview(nil, 5).tokens).toEqual(0)
		expect(Payouts.tokensThrough("nope", 1)).toBeNil()
	end)
end)

describe("Payout leave early", function()
	it("keeps every cleared wave and skips the boss when the run dies there", function()
		for _, id in ipairs(Economy.DIFFICULTY_ORDER) do
			local early = Payouts.preview(id, 4)
			expect(early.ok).toBeTrue()
			expect(early.leftEarly).toBeTrue()
			expect(early.tokens).toEqual(BOSS_FAIL[id])
			expect(early.tokens).toBeLessThan(CLEARS[id])
			expect(#early.waves).toEqual(4)
			for index, line in ipairs(early.waves) do
				expect(line.tokens).toEqual(PER_WAVE[id][index])
			end
		end
		local none = Payouts.preview("normal", 0)
		expect(none.tokens).toEqual(0)
		expect(none.leftEarly).toBeTrue()
		expect(#none.waves).toEqual(0)
	end)

	it("keeps what a leave already earned when the same run is sent again", function()
		local book = Payouts.newBook()
		local wallet = { shardTokens = 10 }
		local function apply(result)
			if result.paid == true then
				wallet.shardTokens += result.tokens
			end
		end
		local leave = Payouts.grant(book, 7, "run-leave", {
			difficulty = "medium",
			wavesCleared = 3,
			tokens = 999,
			fragments = 999,
		})
		expect(leave.ok).toBeTrue()
		expect(leave.paid).toBeTrue()
		expect(leave.already).toBeFalse()
		expect(leave.leftEarly).toBeTrue()
		expect(leave.tokens).toEqual(5)
		expect(leave.totalTokens).toEqual(5)
		apply(leave)
		local retry = Payouts.grant(book, 7, "run-leave", {
			difficulty = "insane",
			wavesCleared = 5,
			tokens = 999,
		})
		expect(retry.ok).toBeTrue()
		expect(retry.paid).toBeFalse()
		expect(retry.already).toBeTrue()
		expect(retry.tokens).toEqual(0)
		expect(retry.fragments).toEqual(0)
		expect(retry.totalTokens).toEqual(5)
		expect(retry.wavesCleared).toEqual(3)
		expect(retry.difficulty).toEqual("medium")
		apply(retry)
		expect(wallet.shardTokens).toEqual(15)
		expect(wallet.fragments).toBeNil()
	end)
end)

describe("Payout grant", function()
	it("pays one run once and a new run id again", function()
		local book = Payouts.newBook()
		local first = Payouts.grant(book, 4, "run-a", { difficulty = "normal", wavesCleared = 5 })
		expect(first.tokens).toEqual(11)
		expect(first.paid).toBeTrue()
		local again = Payouts.grant(book, 4, "run-a", { difficulty = "normal", wavesCleared = 5 })
		expect(again.paid).toBeFalse()
		expect(again.tokens).toEqual(0)
		expect(again.totalTokens).toEqual(11)
		local nextRun =
			Payouts.grant(book, 4, "run-b", { difficulty = "nightmare", wavesCleared = 5 })
		expect(nextRun.paid).toBeTrue()
		expect(nextRun.tokens).toEqual(22)
		local other = Payouts.grant(book, 5, "run-a", {
			difficulty = "normal",
			wavesCleared = 1,
			userId = 4,
		})
		expect(other.paid).toBeTrue()
		expect(other.userId).toEqual(5)
		expect(other.tokens).toEqual(1)
	end)

	it("does not settle a bought, empty, or broken request", function()
		local book = Payouts.newBook()
		local bought = Payouts.grant(book, 4, "run-buy", {
			difficulty = "normal",
			wavesCleared = 5,
			robux = 0,
		})
		expect(bought.ok).toBeFalse()
		expect(bought.paid).toBeFalse()
		expect(bought.error).toEqual(Payouts.ERRORS.paid)
		local after = Payouts.grant(book, 4, "run-buy", { difficulty = "normal", wavesCleared = 5 })
		expect(after.paid).toBeTrue()
		expect(after.tokens).toEqual(11)
		local poisoned = Payouts.grant(book, 4, "run-buy", {
			productId = 1,
			wavesCleared = 5,
			difficulty = "insane",
		})
		expect(poisoned.already).toBeTrue()
		expect(poisoned.tokens).toEqual(0)
		expect(poisoned.totalTokens).toEqual(11)
		local freshBuy = Payouts.grant(book, 4, "run-product", { productId = 1, wavesCleared = 0 })
		expect(freshBuy.ok).toBeFalse()
		expect(freshBuy.error).toEqual(Payouts.ERRORS.paid)
		expect(Payouts.grant(book, 0, "run", { wavesCleared = 0 }).error).toEqual(
			Payouts.ERRORS.user
		)
		expect(Payouts.grant(book, 1.5, "run", { wavesCleared = 0 }).ok).toBeFalse()
		expect(Payouts.grant(book, 4, "", { wavesCleared = 0 }).error).toEqual(Payouts.ERRORS.run)
		expect(Payouts.grant(book, 4, "run", nil).error).toEqual(Payouts.ERRORS.request)
		expect(Payouts.grant(nil, 4, "run", { wavesCleared = 0 }).error).toEqual(
			Payouts.ERRORS.book
		)
		local fresh = Payouts.grant(Payouts.newBook(), 4, "wave-six", {
			difficulty = "normal",
			wavesCleared = 6,
		})
		expect(fresh.ok).toBeFalse()
		expect(fresh.tokens).toEqual(0)
	end)

	it("ignores client amounts and does not write a frozen request", function()
		local request = table.freeze({
			difficulty = "hard",
			wavesCleared = 5,
			tokens = 1,
			fragments = 1,
			multiplier = 100,
			duplicates = table.freeze({
				table.freeze({ id = "roll-1", rarity = "Common" }),
			}),
		})
		local result = Payouts.grant(Payouts.newBook(), 9, "frozen", request)
		expect(result.paid).toBeTrue()
		expect(result.tokens).toEqual(17)
		expect(result.fragments).toEqual(1)
		expect(result.duplicates[1].rarity).toEqual("Common")
	end)
end)

describe("Payout duplicates", function()
	it("converts each V1 rarity at Dust / 5 and folds Mythic and Secret", function()
		expect(Payouts.DUP_AUTO_CONVERT).toEqual(true)
		local expected = { Common = 1, Uncommon = 3, Rare = 10, Epic = 40, Legendary = 200 }
		for _, id in ipairs(Rarities.ORDER) do
			expect(Payouts.duplicateFragments(id)).toEqual(expected[id])
			expect(Payouts.DUP_FRAGMENTS[id]).toEqual(ChestConfig.DUST[id] / 5)
			expect(Payouts.duplicateFragments(" " .. string.lower(id) .. " ")).toEqual(expected[id])
		end
		expect(ChestConfig.DUST.Mythic / 5).toEqual(1000)
		expect(Payouts.duplicateFragments("Mythic")).toEqual(200)
		expect(Payouts.duplicateFragments("secret")).toEqual(200)
		expect(Payouts.DUP_FRAGMENTS.Mythic).toBeNil()
		expect(Payouts.duplicateFragments("Divine")).toBeNil()
		expect(Payouts.duplicateFragments("Rare", false)).toEqual(0)
		expect(Payouts.duplicateFragments("Rare", true)).toEqual(10)
	end)

	it("pays each duplicate once and does not pay them again on retry", function()
		local book = Payouts.newBook()
		local bag = {}
		local grant = Payouts.grant(book, 3, "rolls", {
			wavesCleared = 0,
			duplicates = {
				{ id = "a", rarity = "Common" },
				{ id = "b", rarity = "Common" },
				{ id = "c", rarity = "Epic" },
				{ id = "d", rarity = "Mythic" },
			},
		})
		expect(grant.paid).toBeTrue()
		expect(grant.tokens).toEqual(0)
		expect(grant.fragments).toEqual(1 + 1 + 40 + 200)
		expect(grant.totalFragments).toEqual(242)
		expect(#bag).toEqual(0)
		expect(#grant.duplicates).toEqual(4)
		expect(grant.duplicates[4].rarity).toEqual("Legendary")
		local retry = Payouts.grant(book, 3, "rolls", {
			wavesCleared = 0,
			duplicates = { { id = "e", rarity = "Legendary" } },
		})
		expect(retry.paid).toBeFalse()
		expect(retry.fragments).toEqual(0)
		expect(retry.totalFragments).toEqual(242)
	end)

	it("refuses a repeated id or an unknown rarity without settling the run", function()
		local book = Payouts.newBook()
		local repeated = Payouts.grant(book, 3, "dup", {
			wavesCleared = 0,
			duplicates = {
				{ id = "a", rarity = "Rare" },
				{ id = "a", rarity = "Rare" },
			},
		})
		expect(repeated.ok).toBeFalse()
		expect(repeated.error).toEqual(Payouts.ERRORS.duplicate)
		local unknown = Payouts.grant(book, 3, "dup", {
			wavesCleared = 1,
			difficulty = "normal",
			duplicates = { { id = "a", rarity = "Divine" } },
		})
		expect(unknown.ok).toBeFalse()
		expect(unknown.tokens).toEqual(0)
		local paid = Payouts.grant(book, 3, "dup", {
			wavesCleared = 1,
			difficulty = "normal",
			duplicates = { { id = "a", rarity = "Rare" } },
		})
		expect(paid.paid).toBeTrue()
		expect(paid.tokens).toEqual(1)
		expect(paid.fragments).toEqual(10)
		local bought = Payouts.grant(Payouts.newBook(), 3, "dust", {
			wavesCleared = 0,
			duplicates = { { id = "a", rarity = "Rare", receiptId = "x" } },
		})
		expect(bought.error).toEqual(Payouts.ERRORS.duplicate)
	end)
end)

describe("Payout economy check", function()
	it("shows one clear buys a few rolls, and a Normal clear buys one x10 plus two", function()
		local check = Payouts.economyCheck()
		expect(check.ok).toBeTrue()
		expect(check.error).toBeNil()
		expect(check.fewRolls).toEqual(3)
		expect(check.singleCost).toEqual(RollConfig.SINGLE_COST)
		expect(check.singleCost).toEqual(1)
		expect(check.x10Cost).toEqual(RollConfig.cost(RollConfig.MULTI_COUNT))
		expect(check.x10Cost).toEqual(9)
		expect(#check.rows).toEqual(5)
		local previous = 0
		for index, id in ipairs(Economy.DIFFICULTY_ORDER) do
			local row = check.rows[index]
			expect(row.difficulty).toEqual(id)
			expect(row.tokens).toEqual(CLEARS[id])
			expect(row.singleRolls).toEqual(CLEARS[id])
			expect(row.singleRolls >= check.fewRolls).toBeTrue()
			expect(row.tokens > previous).toBeTrue()
			expect(row.x10s * check.x10Cost + row.leftover).toEqual(row.tokens)
			previous = row.tokens
		end
		expect(check.rows[1].x10s).toEqual(1)
		expect(check.rows[1].leftover).toEqual(2)
		expect(check.rows[1].singleRolls).toEqual(11)
	end)
end)

describe("Payout flag", function()
	it("stays off and the server grant refuses before it can pay", function()
		expect(LaunchGate.SHOW.payouts).toEqual(false)
		expect(LaunchGate.on("payouts")).toEqual(false)
		local closed = Payouts.closed("run", DevTools.offMessage("payouts"))
		expect(closed.ok).toBeFalse()
		expect(closed.paid).toBeFalse()
		expect(closed.tokens).toEqual(0)
		expect(closed.fragments).toEqual(0)
		expect(closed.error).toEqual(
			"Run payouts (Roll Tokens and Fragments) is off (LaunchGate.payouts), so this does nothing yet."
		)
		local server = fs.readFile("src/ServerScriptService/ShardfallServer/PayoutService.luau")
		local gateAt = string.find(server, 'LaunchGate.on("payouts")', 1, true)
		local grantAt = string.find(server, "Payouts.grant(", 1, true)
		local closedAt = string.find(server, "Payouts.closed(", 1, true)
		expect(gateAt ~= nil and closedAt ~= nil and grantAt ~= nil).toBeTrue()
		expect((gateAt :: number) < (grantAt :: number)).toBeTrue()
		expect((closedAt :: number) < (grantAt :: number)).toBeTrue()
		expect(string.find(server, 'DevTools.offMessage("payouts")', 1, true) ~= nil).toBeTrue()
		expect(string.find(server, "DataService", 1, true)).toBeNil()
		expect(string.find(server, "Schema", 1, true)).toBeNil()
		expect(string.find(server, "MarketplaceService", 1, true)).toBeNil()
		local rules = fs.readFile("src/ReplicatedStorage/Shared/Config/Payouts.luau")
		expect(string.find(rules, "DataStore", 1, true)).toBeNil()
		expect(string.find(rules, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(rules, "os.time", 1, true)).toBeNil()
		expect(string.find(rules, "math.random", 1, true)).toBeNil()
	end)
end)
