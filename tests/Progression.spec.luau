--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Progression = require("../src/ReplicatedStorage/Shared/Progression")

describe("Progression", function()
	it("uses the 1.6 curve and stops at level 20", function()
		expect(Progression.xpToNext(1)).toEqual(100)
		expect(Progression.xpToNext(3)).toEqual(math.floor(100 * (3 ^ 1.6) + 0.5))
		expect(Progression.xpToNext(20)).toEqual(0)
		local data = { level = 19, xp = 0, chests = {} }
		local need = Progression.xpToNext(19)
		Progression.addXp(data, need)
		expect(data.level).toEqual(20)
		expect(data.xp).toEqual(0)
		expect(data.chests.Rare).toEqual(1)
		Progression.addXp(data, 5000)
		expect(data.level).toEqual(20)
	end)

	it("caps stacked XP boosts at +100% and welcomes a long absence", function()
		expect(Progression.boost({ 1, 1, 0.25 })).toEqual(2)
		local rested = { level = 1, xp = 0, restCharges = 2, welcomeCharges = 2, chests = {} }
		Progression.addXp(rested, 10)
		expect(rested.xp).toEqual(20)
		expect(rested.restCharges).toEqual(1)
		local data = { level = 4, xp = 0, lastSeen = 1, chests = {} }
		local back = Progression.applyReturn(data, Progression.WELCOME_GAP + 10)
		expect(back.welcome).toEqual(true)
		expect(back.rest).toEqual(true)
		expect(data.chests.Rare).toEqual(1)
		expect(Progression.recap(1, 4, 2, 41)).toEqual(
			"This session: +3 levels, 2 Epics, 41% to your Relic Set"
		)
		expect(Progression.unlocked(10)[4]).toEqual("hard")
	end)
end)
