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
			sinceEpic = RarityConfig.EPIC_PITY,
			sinceLegendary = RarityConfig.LEGENDARY_PITY / 2,
		})
		expect(bars.epic).toEqual(1)
		expect(bars.legendary > 0.4 and bars.legendary < 0.6).toBeTrue()
		expect(RollBoard.bars(nil).epic).toEqual(0)
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

	it("shows both server pity bars and leaves the odds sheet alone", function()
		local pool = Pools.get("verdant_armory")
		local base = RollBoard.oddsLines(pool, 0, 0, 0)
		expect(UiRouter.oddsSince(99)).toEqual(0)
		expect(UiRouter.oddsSince(90)).toEqual(0)
		expect(RollBoard.oddsLines(pool, 0, 0, UiRouter.oddsSince(99))).toEqual(base)
		expect(#base > 0).toBeTrue()

		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local paintAt = string.find(hub, "local function paintRoll()", 1, true)
		local rollAt = string.find(hub, "local activeItem", paintAt or 1, true)
		expect(paintAt ~= nil and rollAt ~= nil).toBeTrue()
		local paint = string.sub(hub, paintAt or 1, (rollAt or 1) - 1)
		expect(string.find(paint, "RollHype.pity(sinceEpic, RarityConfig.EPIC_PITY)", 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, "RollHype.pity(sinceLegendary, pityGoal)", 1, true) ~= nil).toBeTrue()
		expect(string.find(paint, 'paintPity("EpicPity"', 1, true) ~= nil).toBeTrue()
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
				'RollBoard.oddsLines(Pools.get("verdant_armory"), luck, boost, oddsSince)',
				1,
				true
			) ~= nil
		).toBeTrue()
		expect(string.find(paint, "sinceEpic +", 1, true)).toBeNil()
		expect(string.find(paint, "serverEpic +=", 1, true)).toBeNil()

		local bodyAt = string.find(hub, "beginRoll = function()", 1, true)
		local invokeAt = string.find(hub, 'hooks.invoke, "RollShard"', bodyAt or 1, true)
		local refusedAt = string.find(hub, "paintReelIdle(RollReveal.reelCaption(result))", invokeAt or 1, true)
		local refused = string.sub(hub, invokeAt or 1, refusedAt or 1)
		expect(string.find(refused, "EpicPity", 1, true)).toBeNil()
		expect(string.find(refused, "sinceEpic", 1, true)).toBeNil()

		local schema = fs.readFile("src/ReplicatedStorage/Shared/Schema.luau")
		expect(string.find(schema, "Schema.VERSION = 23", 1, true) ~= nil).toBeTrue()
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		expect(string.find(roll, "sinceEpic = data.sinceEpic", 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "RarityConfig.pick", 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "data.sinceEpic = counters.sinceEpic", 1, true) ~= nil).toBeTrue()
	end)
end)
