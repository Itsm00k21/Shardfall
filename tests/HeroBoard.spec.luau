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

	it("lays out the redesigned hero sheet with real stat values (A1)", function()
		local tiles = HeroBoard.tiles(nil)
		expect(#tiles).toEqual(8)
		local seen = {}
		for _, tile in ipairs(tiles) do
			expect(type(tile.value)).toEqual("string")
			expect(#tile.value > 0).toBeTrue()
			expect(type(tile.art)).toEqual("string")
			seen[tile.id] = tile
		end
		local bars = HeroBoard.bars(nil)
		expect(string.find(bars[2].label, seen.health.value, 1, true) ~= nil).toBeTrue()
		expect(seen.level.value).toEqual("1")
		expect(HeroBoard.tiles({ level = 7 })[8].value).toEqual("7")
		for _, width in ipairs({ 248, 264, 459, 480, 828 }) do
			local sheet = HeroBoard.sheet(width)
			expect(sheet.statCols * sheet.tileW + (sheet.statCols - 1) * HeroBoard.GAP <= width).toBeTrue()
			expect(sheet.skillCols * sheet.skillW + (sheet.skillCols - 1) * HeroBoard.GAP <= width).toBeTrue()
			expect(sheet.tileW >= 100).toBeTrue()
			expect(sheet.skillW >= 72).toBeTrue()
			expect(sheet.crest + sheet.avatarW + 24 < width).toBeTrue()
		end
		expect(HeroBoard.sheet(264).statCols).toEqual(2)
		expect(HeroBoard.sheet(828).statCols).toEqual(4)
	end)
end)
