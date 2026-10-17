--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local HeroBoard = require("../src/ReplicatedStorage/Shared/HeroBoard")

describe("HeroBoard", function()
	it("scores power and fills stat bars from the loadout", function()
		local bare = HeroBoard.power(nil)
		expect(bare > 0).toBeTrue()
		local armed = HeroBoard.power({
			inventory = {
				sword = {
					uid = "sword",
					kind = "Weapon",
					stats = {
						{ id = "damage", value = 40 },
					},
				},
			},
			equipped = { weapon = "sword" },
		})
		expect(armed > bare).toBeTrue()
		local bars = HeroBoard.bars(nil)
		expect(#bars).toEqual(3)
		for _, bar in ipairs(bars) do
			expect(bar.fill >= 0 and bar.fill <= 1).toBeTrue()
		end
	end)
end)
