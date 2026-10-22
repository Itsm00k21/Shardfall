--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local RollBoard = require("../src/ReplicatedStorage/Shared/RollBoard")
local UiRouter = require("../src/ReplicatedStorage/Shared/UiRouter")

describe("RollBoard", function()
	it("fills pity, lists odds, and scales the celebration", function()
		local bars = RollBoard.bars({
			sinceEpic = 50,
			sinceLegendary = RarityConfig.LEGENDARY_PITY / 2,
		})
		-- Legendary is the only pity bar; an old Epic counter is ignored.
		expect((bars :: any).epic).toBeNil()
		expect(bars.legendary > 0.4 and bars.legendary < 0.6).toBeTrue()
		expect(RollBoard.bars(nil).legendary).toEqual(0)
		local lines = RollBoard.oddsLines(Pools.get("verdant_armory"), 0, 0, 0)
		expect(#lines > 0).toBeTrue()
		expect(string.find(lines[1], "%", 1, true) ~= nil).toBeTrue()
		expect(RollBoard.celebrationScale("Common")).toEqual(1)
		expect(RollBoard.celebrationScale("Legendary") > RollBoard.celebrationScale("Rare")).toBeTrue()
		expect(RollBoard.celebrationScale("Secret") > RollBoard.celebrationScale("Legendary")).toBeTrue()
	end)

	it("stops auto-roll at a rarity and keeps the last ten", function()
		expect(RollBoard.shouldRollAgain(true, "Rare", "Uncommon", 3)).toEqual(true)
		expect(RollBoard.shouldRollAgain(true, "Rare", "Rare", 3)).toEqual(false)
		expect(RollBoard.shouldRollAgain(true, "Rare", "Legendary", 3)).toEqual(false)
		expect(RollBoard.shouldRollAgain(true, "Off", "Legendary", 3)).toEqual(true)
		expect(RollBoard.shouldRollAgain(false, "Off", "Common", 3)).toEqual(false)
		expect(RollBoard.shouldRollAgain(true, "Rare", "Common", 0)).toEqual(false)
		expect(RollBoard.shouldRollAgain(true, "mythic", "Legendary", 3)).toEqual(false)
		expect(RollBoard.shouldRollAgain(true, "nope", "Common", 3)).toEqual(false)
		expect(RollBoard.shouldRollAgain(true, "", "Common", 3)).toEqual(true)
		local items = {}
		for index = 1, 12 do
			table.insert(
				items,
				{ name = tostring(index), obtainedAt = index, uid = tostring(index) }
			)
		end
		local recent = RollBoard.history(items, RollBoard.HISTORY)
		expect(#recent).toEqual(10)
		expect(recent[1].name).toEqual("12")
		expect(recent[10].name).toEqual("3")
	end)

	it("pulses near a full bar and flashes only when that bar clears", function()
		expect(RollBoard.NEAR).toEqual(0.9)
		expect(RollBoard.pulse(0.9)).toEqual(true)
		expect(RollBoard.pulse(1)).toEqual(true)
		expect(RollBoard.pulse(0.899)).toEqual(false)
		expect(RollBoard.pulse(0)).toEqual(false)
		expect(RollBoard.pulse(-1)).toEqual(false)
		expect(RollBoard.pulse(0 / 0)).toEqual(false)
		expect(RollBoard.pulse(math.huge)).toEqual(false)
		expect(RollBoard.pulse("0.9")).toEqual(false)

		expect(RollBoard.payoff(0, "Epic", "Epic")).toEqual(true)
		expect(RollBoard.payoff(0, "Legendary", "Epic")).toEqual(true)
		expect(RollBoard.payoff(0, "Secret", "Legendary")).toEqual(true)
		expect(RollBoard.payoff(0, "Rare", "Epic")).toEqual(false)
		expect(RollBoard.payoff(0, "Epic", "Legendary")).toEqual(false)
		expect(RollBoard.payoff(1, "Epic", "Epic")).toEqual(false)
		expect(RollBoard.payoff(0, nil, "Epic")).toEqual(false)
		expect(RollBoard.payoff(0, "Godly", "Epic")).toEqual(false)
		expect(RollBoard.payoff(0, "Epic", "Godly")).toEqual(false)
	end)

	it("shows disclose odds that add up to 100 and match the draw", function()
		local pool = Pools.get("verdant_armory")
		local luck = RarityConfig.luckFromProfile({
			shardLuck = 0,
			luckBoost = 0,
			vip = true,
		})
		local disclosed = RarityConfig.disclose(pool, luck)
		local lines = RollBoard.oddsLines(pool, 0, 0, 0)
		expect(#lines).toEqual(#disclosed.rarities)
		local sum = 0
		for index, text in ipairs(lines) do
			local row = disclosed.rarities[index]
			expect(text).toEqual(RarityConfig.formatLine(row))
			sum += row.chance
			expect(string.find(text, "(0.0%)", 1, true)).toBeNil()
			expect(string.find(text, "(0.00%)", 1, true)).toBeNil()
			expect(string.find(text, "(0.0000%)", 1, true)).toBeNil()
		end
		expect(math.abs(sum - 1) < 1e-9).toBeTrue()
	end)

	it("matches the server odds for a stored luck boost and vip", function()
		local pool = Pools.get("verdant_armory")
		local profile = {
			shardLuck = 50,
			luckBoost = 25,
			shardRolls = 9,
			vip = true,
		}
		local function sheet(odds: any): { string }
			local expected = {}
			for _, row in ipairs(odds.rarities) do
				table.insert(expected, RarityConfig.formatLine(row))
			end
			return expected
		end
		local serverLuck = RarityConfig.luckFromProfile(profile)
		expect(serverLuck).toEqual((1 + 0.5) * 2)
		local lines = RollBoard.oddsLines(pool, profile, 999, 99)
		expect(lines).toEqual(sheet(RarityConfig.disclose(pool, serverLuck)))
		local plain = {
			shardLuck = 50,
			luckBoost = 0,
			shardRolls = 9,
			vip = false,
		}
		expect(lines).toEqual(RollBoard.oddsLines(pool, plain, 0, 0))
		expect(serverLuck).toEqual(RarityConfig.luckFromProfile(plain))
		local paidLuck = RarityConfig.luckMultiplier({
			shardLuck = 50,
			luckBoost = 25,
			shardRolls = 9,
			vip = true,
			paidLuck = true,
		})
		expect(paidLuck).toEqual((1 + 0.5) * 2 + 0.25)
		local paidLines = sheet(RarityConfig.disclose(pool, paidLuck))
		local same = #paidLines == #lines
		if same then
			for index, line in ipairs(lines) do
				if line ~= paidLines[index] then
					same = false
				end
			end
		end
		expect(same).toEqual(false)
	end)

	it("shows the one Legendary pity bar and leaves the odds sheet alone", function()
		local pool = Pools.get("verdant_armory")
		local base = RollBoard.oddsLines(pool, 0, 0, 0)
		expect(UiRouter.oddsSince(99)).toEqual(0)
		expect(UiRouter.oddsSince(90)).toEqual(0)
		expect(RollBoard.oddsLines(pool, 0, 0, UiRouter.oddsSince(99))).toEqual(base)
		expect(#base > 0).toBeTrue()

		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local paintAt = string.find(hub, "function hubFn.paintRoll()", 1, true)
		local rollAt = string.find(hub, "hubState.activeItem", paintAt or 1, true)
		expect(paintAt ~= nil and rollAt ~= nil).toBeTrue()
		local paint = string.sub(hub, paintAt or 1, (rollAt or 1) - 1)
		expect(string.find(paint, "EPIC_PITY", 1, true)).toBeNil()
		expect(string.find(paint, "RollHype.pity(sinceLegendary, pityGoal)", 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, '"EpicPity"', 1, true)).toBeNil()
		expect(string.find(paint, '"LegendaryPity"', 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, "RollBoard.payoff", 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, "RollBoard.pulse", 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, "UDim2.fromScale(target, 1)", 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, 'animate == "flash"', 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, 'animate == "pulse"', 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, "UiTheme.MIN_TEXT", 1, true) ~= nil).toBeTrue()
		expect(
			string.find(
				paint,
				'RollBoard.oddsLines(Pools.get("verdant_armory"), hubState.profile, 0, oddsSince)',
				1,
				true
			) ~= nil
		).toBeTrue()
		expect(string.find(paint, "sinceEpic +", 1, true)).toBeNil()
		expect(string.find(paint, "serverEpic +=", 1, true)).toBeNil()

		local bodyAt = string.find(hub, "beginRoll = function()", 1, true)
		local invokeAt = string.find(hub, 'hooks.invoke, "RollShard"', bodyAt or 1, true)
		local refusedAt =
			string.find(hub, "paintReelIdle(RollReveal.reelCaption(result))", invokeAt or 1, true)
		local refused = string.sub(hub, invokeAt or 1, refusedAt or 1)
		expect(string.find(refused, "EpicPity", 1, true)).toBeNil()
		expect(string.find(refused, "sinceEpic", 1, true)).toBeNil()

		local schema = fs.readFile("src/ReplicatedStorage/Shared/Schema.luau")
		expect(string.find(schema, "Schema.VERSION = 26", 1, true) ~= nil).toBeTrue()
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		expect(string.find(roll, "sinceEpic = data.sinceEpic", 1, true)).toBeNil()
		expect(string.find(roll, "RarityConfig.pick", 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "data.sinceEpic = counters.sinceEpic", 1, true)).toBeNil()
		expect(string.find(roll, "sinceLegendary = data.sinceLegendary", 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "Schema.pityBucket", 1, true)).toBeNil()
		expect(string.find(roll, "bucket.rollsSinceLegendary", 1, true)).toBeNil()
	end)

	it("never prints 0.0% for Epic or Legendary, prints real %, and matches the reel", function()
		local function assertSheet(poolId: string, luck: any)
			local pool = Pools.get(poolId)
			assert(pool ~= nil, poolId)
			local multiplier = RarityConfig.luckFromProfile(
				if type(luck) == "table" then luck else { shardLuck = luck }
			)
			local disclosed = RarityConfig.disclose(pool, multiplier)
			local lines = RollBoard.oddsLines(pool, luck, 0, 0)
			expect(#lines).toEqual(#disclosed.rarities)
			local sum = 0
			local seen = {}
			for index, row in ipairs(disclosed.rarities) do
				local text = lines[index]
				expect(text).toEqual(RarityConfig.formatLine(row))
				sum += row.chance
				seen[row.rarity] = text
				expect(string.find(text, "0.0%", 1, true)).toBeNil()
			end
			expect(math.abs(sum - 1) < 1e-9).toBeTrue()
			-- Parked tiers (Mythic/Secret) are not on the sheet.
			expect(seen.Mythic).toBeNil()
			expect(seen.Secret).toBeNil()
			for _, rarity in ipairs({ "Epic", "Legendary" }) do
				local text = seen[rarity]
				assert(text ~= nil, rarity)
				expect(string.find(text, "1 in", 1, true)).toBeNil()
				expect(string.find(text, " 0.00%", 1, true)).toBeNil()
				local shown = string.match(text, "([%d%.]+)%%$")
				local value = tonumber(shown)
				assert(value ~= nil, text)
				expect(value > 0).toBeTrue()
			end
		end
		assertSheet("verdant_armory", 0)
		assertSheet("verdant_pets", 0)
		assertSheet("verdant_armory", {
			shardLuck = 0,
			luckBoost = 0,
			shardRolls = 0,
			vip = true,
		})
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local reel =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RollReel.luau")
		expect(
			string.find(
				hub,
				"RollBoard.oddsLines(infoPool, hubState.profile, 0, UiRouter.oddsSince(legendaryCount))",
				1,
				true
			) ~= nil
		).toBeTrue()
		expect(
			string.find(
				hub,
				'RollBoard.oddsLines(Pools.get("verdant_armory"), hubState.profile, 0, oddsSince)',
				1,
				true
			) ~= nil
		).toBeTrue()
		expect(
			string.find(
				hub,
				"RollBoard.oddsLines(Pools.get(hubFn.rollPoolId()), hubState.profile, 0, oddsSince)",
				1,
				true
			) ~= nil
		).toBeTrue()
		expect(string.find(reel, "label.Text = RarityConfig.formatLine(row)", 1, true) ~= nil).toBeTrue()
	end)
end)
