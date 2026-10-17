--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local BagBoard = require("../src/ReplicatedStorage/Shared/BagBoard")

local function piece(name: string, rarity: string, slot: string, at: number, power: number)
	return {
		uid = name,
		name = name,
		rarity = rarity,
		slot = slot,
		kind = "Weapon",
		obtainedAt = at,
		quality = power / 100,
		stars = 0,
	}
end

describe("BagBoard", function()
	it("filters by rarity, type, and new, then sorts", function()
		local items = {
			piece("Oak", "Common", "sword", 10, 0.1),
			piece("Ash", "Rare", "bow", 30, 0.2),
			piece("Yew", "Rare", "sword", 20, 0.9),
		}
		local filter = BagBoard.defaultFilter()
		filter.rarity = "Rare"
		filter.kind = "sword"
		filter.sort = "newest"
		local rows = BagBoard.rows(items, filter, 0)
		expect(#rows).toEqual(1)
		expect(rows[1].name).toEqual("Yew")
		filter.kind = "All"
		filter.onlyNew = true
		rows = BagBoard.rows(items, filter, 20)
		expect(#rows).toEqual(1)
		expect(rows[1].name).toEqual("Ash")
		expect(BagBoard.isNew(items[1], 10)).toEqual(false)
		expect(BagBoard.isNew(items[2], 10)).toEqual(true)
	end)

	it("compares against the equipped piece and confirms salvage", function()
		local worn = piece("Oak", "Common", "sword", 1, 0.1)
		local better = piece("Yew", "Rare", "sword", 2, 0.8)
		local profile = {
			inventory = { Oak = worn, Yew = better },
			equipped = { weapon = "Oak" },
		}
		local summary = BagBoard.summary(profile, better)
		expect(string.find(summary, "Oak", 1, true) ~= nil).toBeTrue()
		expect(string.find(summary, "+", 1, true) ~= nil).toBeTrue()
		expect(BagBoard.summary(profile, worn)).toEqual("Equipped.")
		expect(BagBoard.confirm("Rare")).toEqual(
			"Salvage every Rare weapon and armor piece that is not locked or equipped?"
		)
	end)
end)
