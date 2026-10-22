--!strict

--[[
	Clear-card loot grid: drops stack by name ("Verdant Bark x5"), the grid
	never grows past MAX_ROWS (Continue stays on the card), and the voucher
	line appears once.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ResultsGrid = require("../src/ReplicatedStorage/Shared/ResultsGrid")

describe("Results grid", function()
	it("stacks repeated drops by name", function()
		local tiles = ResultsGrid.merge({
			{ name = "Verdant Bark", count = 1 },
			{ name = "Spore Cap", count = 2 },
			{ name = "Verdant Bark", count = 1 },
			"Verdant Bark: 1",
			"Verdant Bark x2",
		})
		expect(#tiles).toEqual(2)
		expect(tiles[1].name).toEqual("Verdant Bark")
		expect(tiles[1].count).toEqual(5)
		expect(ResultsGrid.countText(tiles[1].count)).toEqual("x5")
		expect(tiles[2].count).toEqual(2)
	end)

	it("never exceeds two rows and folds the rest into +N", function()
		for _, n in ipairs({ 1, 5, 10, 14, 30 }) do
			local place = ResultsGrid.layout(308, n)
			expect(place.rows <= ResultsGrid.MAX_ROWS).toBeTrue()
			expect(place.shown + place.more).toEqual(n)
			expect(place.cols * (place.tile + ResultsGrid.GAP) - ResultsGrid.GAP <= 308).toBeTrue()
		end
		expect(ResultsGrid.layout(308, 30).more > 0).toBeTrue()
		expect(ResultsGrid.layout(308, 0).height).toEqual(0)
	end)

	it("writes the voucher once and the grid sits above Continue", function()
		expect(ResultsGrid.voucherLine("armory")).toEqual("Voucher  one free Armory crack")
		local hud = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau")
		local _, count = string.gsub(hud, "one free Armory crack", "")
		expect(count).toEqual(0)
		expect(string.find(hud, "paintLoot(payload.materials)", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, 'dismiss.LayoutOrder = 4', 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, 'lootGrid.LayoutOrder = 3', 1, true) ~= nil).toBeTrue()
	end)
end)
