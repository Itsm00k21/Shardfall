--!strict

-- Milestone 0.3: the Config index loads every area, and the new V1 data
-- keeps the numbers Kevin approved. The full validation test is 0.4.

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Config = require("../src/ReplicatedStorage/Shared/Config/Index")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local ItemBases = require("../src/ReplicatedStorage/Shared/ItemBases")
local Rootvault = require("../src/ReplicatedStorage/Shared/Rootvault")

local function idsMatchKeys(list: { [string]: any })
	local count = 0
	for key, row in pairs(list) do
		expect(type(row.id)).toEqual("string")
		expect(row.id).toEqual(key)
		count += 1
	end
	expect(count > 0).toBeTrue()
end

describe("Config index", function()
	it("loads all nine areas", function()
		expect(#Config.AREAS).toEqual(9)
		for _, area in ipairs(Config.AREAS) do
			expect(type((Config :: any)[area])).toEqual("table")
		end
	end)

	it("re-exports the existing modules instead of copying them", function()
		expect(Config.Items).toEqual(ItemBases)
		expect(Config.Dungeons == Dungeons).toBeTrue()
		expect(Config.Enemies == Dungeons.ENEMIES).toBeTrue()
		expect(Config.Live.Difficulties == Rootvault.DIFFICULTIES).toBeTrue()
	end)

	it("gives every new entry an id that matches its key", function()
		idsMatchKeys(Config.Rarities.TIERS)
		idsMatchKeys(Config.Rarities.PITY)
		idsMatchKeys(Config.Elements.LIST)
		idsMatchKeys(Config.Economy.DIFFICULTIES)
		idsMatchKeys(Config.Strings.LIST)
		idsMatchKeys(Config.Enemies)
	end)
end)

describe("Config V1 rarities", function()
	it("is the 5-tier rev 2 ladder with Legendary pity 150", function()
		local tiers = Config.Rarities.TIERS
		expect(Config.Rarities.ORDER).toEqual({ "Common", "Uncommon", "Rare", "Epic", "Legendary" })
		local oneIn = {}
		for rank, id in ipairs(Config.Rarities.ORDER) do
			expect(tiers[id].rank).toEqual(rank)
			table.insert(oneIn, tiers[id].oneIn)
		end
		expect(oneIn).toEqual({ 2, 4, 15, 100, 1000 })
		expect(Config.Rarities.PITY.legendary.hard).toEqual(150)
		expect(Config.Rarities.PITY.legendary.softFrom).toEqual(100)
		-- Kevin, Oct 22: no Epic pity in V1.
		expect(Config.Rarities.PITY.epic).toBeNil()
	end)

	it("keeps tier ids that already exist on the live ladder", function()
		for _, id in ipairs(Config.Rarities.ORDER) do
			expect(Config.Live.Rarities.INDEX[id] ~= nil).toBeTrue()
		end
		for id in pairs(Config.Rarities.FOLD) do
			expect(Config.Live.Rarities.INDEX[id] ~= nil).toBeTrue()
		end
	end)
end)

describe("Config V1 economy", function()
	it("pays 11 Roll Tokens for a Normal clear", function()
		local total = 0
		for _, wave in ipairs(Config.Economy.WAVES) do
			total += wave.tokens
		end
		expect(total).toEqual(Config.Economy.NORMAL_CLEAR_TOKENS)
		expect(total).toEqual(11)
	end)

	it("keeps Hard on the Core Loop and still lists the parked rows", function()
		local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
		expect(Config.Economy.DIFFICULTY_ORDER).toEqual({
			"normal",
			"medium",
			"hard",
			"nightmare",
			"insane",
		})
		local hard = Config.Economy.DIFFICULTIES.hard
		expect(hard.levelGate).toEqual(5)
		expect(hard.hpMultiplier).toEqual(2)
		expect(hard.damageMultiplier).toEqual(1.5)
		expect(hard.tokenMultiplier).toEqual(2)
		expect(hard.fragmentMultiplier).toEqual(2)
		expect(math.floor(Config.Economy.NORMAL_CLEAR_TOKENS * hard.tokenMultiplier + 0.5)).toEqual(22)
		expect(Config.Economy.DIFFICULTIES.normal.tokenMultiplier).toEqual(1)
		expect(Config.Economy.DIFFICULTIES.medium.tokenMultiplier).toEqual(1.25)
		expect(Config.Economy.DIFFICULTIES.medium.levelGate).toEqual(5)
		expect(Config.Economy.DIFFICULTIES.nightmare.tokenMultiplier).toEqual(2)
		expect(Config.Economy.DIFFICULTIES.nightmare.levelGate).toEqual(15)
		expect(Config.Economy.DIFFICULTIES.insane.tokenMultiplier).toEqual(3)
		expect(Config.Economy.DIFFICULTIES.insane.levelGate).toEqual(20)
		expect(LaunchGate.on("extraDifficulties")).toEqual(false)
		expect(Config.Live.Difficulties.hard.hp).toEqual(hard.hpMultiplier)
		expect(Config.Live.Difficulties.hard.level).toEqual(hard.levelGate)
	end)
end)
