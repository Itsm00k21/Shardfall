--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local RollBoard = require("../src/ReplicatedStorage/Shared/RollBoard")

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
end)
