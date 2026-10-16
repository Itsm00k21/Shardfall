--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Loops = require("../src/ReplicatedStorage/Shared/Loops")

describe("Loops", function()
	it("pauses a missed login day and keeps dailies for three days", function()
		local streak, paid = Loops.login(3, 10, 12)
		expect(streak).toEqual(3)
		expect(paid).toEqual(true)
		streak, paid = Loops.login(3, 12, 13)
		expect(streak).toEqual(4)
		expect(Loops.login(4, 13, 13)).toEqual(4)
		local dailies = Loops.rollDailies(1, 2)
		expect(#dailies).toEqual(3)
		dailies[1].born = 1
		local kept = Loops.expire(dailies, 5)
		expect(#kept).toEqual(0)
		local ok, text = Loops.reroll(dailies, 1, 1, 9)
		expect(ok).toEqual(true)
		expect(text ~= "").toEqual(true)
		expect(Loops.reroll(dailies, 1, 1, 3)).toEqual(false)
	end)

	it("pays a bingo line and keeps the premium track off", function()
		local cells = Loops.board()
		expect(Loops.seal(cells, 1)).toEqual(0)
		Loops.seal(cells, 2)
		Loops.seal(cells, 3)
		expect(Loops.seal(cells, 4)).toEqual(1)
		local _xp, tier = Loops.passXp(0, Loops.PASS_XP)
		expect(tier).toEqual(1)
		expect(Loops.premium()).toEqual(false)
		local mult, _, rare = Loops.firstClear(-1, 4)
		expect(mult).toEqual(3)
		expect(rare).toEqual(true)
		mult, _, rare = Loops.firstClear(4, 4)
		expect(mult).toEqual(1)
		expect(rare).toEqual(false)
		local board = { dailies = {}, weekly = {} }
		Loops.refresh(board, 86400 * 3, 1)
		expect(#board.dailies).toEqual(3)
		expect(#board.weekly).toEqual(5)
		expect(Loops.apply(board, board.dailies[1].id, 99) > 0).toEqual(true)
	end)
end)
